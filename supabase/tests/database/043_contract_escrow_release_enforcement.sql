-- EP-03-11: Contract Escrow Release Enforcement
--
-- Validates the verify-before-release gate + linkage authorization (plan S8):
--   - anon cannot call link/gate (42501).
--   - authenticated link attempt fails PLT002 (service_role-only).
--   - gate: NULL id -> PLT003; unknown id -> PLT004; stranger -> PLT004.
--   - gate on a pending milestone (unfunded, unlinked) -> eligible=false,
--     reason=not-funded (never moves funds; read-only pre-flight).
--   - Trigger: completing a milestone sets review_period_expires_at =
--     completed_at + 7 days; revision cycle clears it.
--
-- Fixtures mirror 026 (verified listing -> offered contract) so the gate
-- exercises real rows. No financial_escrow DML here (service_role funding is
-- covered by the Dart integration seam + staging E2E).
--
-- NOTE: numbered 043 because 027/028 are taken by the service-review schema.

begin;
set search_path to extensions, public;
select plan(20);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('test.b', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('test.c', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'escrow-a@example.com'),
       (current_setting('test.b')::uuid, 'escrow-b@example.com'),
       (current_setting('test.c')::uuid, 'escrow-c@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active')
on conflict (id) do nothing;

select set_config('test.prof1',
  (select id::text from public.professions limit 1), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- Listing + contract fixtures as A (professional) / B (client).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.l1', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Escrow Linkage Verification Fixture Service',
  'Verification-gated escrow release fixture with full milestone coverage and evidence handling.',
  'fixed', 10000, 30000)->'data'->>'id'), true);

select public.service_listing_publish(current_setting('test.l1')::uuid);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select set_config('test.c1', (select public.service_contract_offer(
  current_setting('test.l1')::uuid,
  30000,
  'NGN',
  '[{"milestone_number": 1, "title": "First verified milestone", "amount": 10000},
    {"milestone_number": 2, "title": "Second verified milestone", "amount": 10000},
    {"milestone_number": 3, "title": "Third verified milestone", "amount": 10000}]'::jsonb,
  null)->'data'->'contract'->>'id'), true);

select set_config('test.m1', (select id::text from public.contract_milestones
  where contract_id = current_setting('test.c1')::uuid and milestone_number = 1), true);

-- Accept as A so the contract is active.
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select public.service_contract_accept(current_setting('test.c1')::uuid);

-- ─── 1. anon cannot call the new RPCs (42501) ────────────────────────────
set role anon;
select throws_ok(
  $$ select public.service_contract_link_escrow(
    '00000000-0000-0000-0000-000000000000'::uuid,
    '00000000-0000-0000-0000-000000000000'::uuid, '[]'::jsonb) $$,
  '42501', null, 'anon cannot call link RPC'
);

select throws_ok(
  $$ select public.service_contract_release_gate(
    '00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call gate RPC'
);

-- ─── 2. Authenticated link attempt -> PLT002 ──────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $$ select public.service_contract_link_escrow(
    current_setting('test.c1')::uuid,
    '00000000-0000-0000-0000-000000000000'::uuid,
    '[]'::jsonb) $$,
  'P0001', 'PLT002: Escrow linkage requires the platform release service.',
  'authenticated link attempt fails PLT002 (service_role-only)'
);

-- ─── 3. Gate validation ──────────────────────────────────────────────────
select throws_ok(
  $$ select public.service_contract_release_gate(null) $$,
  'P0001', 'PLT003: Milestone id is required.',
  'gate with NULL id returns PLT003'
);

select throws_ok(
  $$ select public.service_contract_release_gate(
    '00000000-0000-0000-0000-000000000000'::uuid) $$,
  'P0001', 'PLT004: Milestone not found.',
  'gate with unknown id returns PLT004'
);

-- Stranger (C) sees identical PLT004 (no oracle: RLS hides the milestone row,
-- so the stranger probe is indistinguishable from the unknown-id probe).
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok(
  format(
    'select public.service_contract_release_gate(%L::uuid)',
    current_setting('test.m1')
  ),
  'P0001', 'PLT004: Milestone not found.',
  'stranger gate probe returns PLT004'
);

-- ─── 4. Gate on pending unfunded milestone -> not-funded ─────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select (public.service_contract_release_gate(
    current_setting('test.m1')::uuid)->'data'->>'eligible')),
  'false',
  'pending unfunded milestone is not eligible'
);

select is(
  (select (public.service_contract_release_gate(
    current_setting('test.m1')::uuid)->'data'->>'reason')),
  'not-funded',
  'pending unfunded reason is not-funded'
);

select is(
  (select (public.service_contract_release_gate(
    current_setting('test.m1')::uuid)->'data'->>'milestone_status')),
  'pending',
  'gate echoes pending milestone status'
);

-- Professional view of the same gate agrees (participant, no oracle split).
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select (public.service_contract_release_gate(
    current_setting('test.m1')::uuid)->'data'->>'reason')),
  'not-funded',
  'professional gate agrees: not-funded'
);

-- ─── 5. Complete M1 as professional -> expiry set ────────────────────────
select public.service_contract_complete_milestone(
  current_setting('test.m1')::uuid,
  'service-listing-media/' || current_setting('test.a') || '/c1/m1-evidence.pdf');

select ok(
  (select review_period_expires_at is not null
     from public.contract_milestones
    where id = current_setting('test.m1')::uuid),
  'completing a milestone sets review_period_expires_at'
);

select ok(
  (select review_period_expires_at >
     (select completed_at from public.contract_milestones
       where id = current_setting('test.m1')::uuid)
     from public.contract_milestones
    where id = current_setting('test.m1')::uuid),
  'expiry is after completed_at (7-day window)'
);

-- Gate on completed-but-unexpired, unfunded -> still not eligible, not-verified.
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select (public.service_contract_release_gate(
    current_setting('test.m1')::uuid)->'data'->>'eligible')),
  'false',
  'completed unexpired unfunded milestone is not eligible'
);

select is(
  (select (public.service_contract_release_gate(
    current_setting('test.m1')::uuid)->'data'->>'reason')),
  'not-funded',
  'escrow linkage is checked before verification state (fail-closed order)'
);

-- ─── 6. Revision cycle clears the deadline ───────────────────────────────
select public.service_contract_verify_milestone(
  current_setting('test.m1')::uuid, 'revision_requested');

select is(
  (select status from public.contract_milestones
    where id = current_setting('test.m1')::uuid),
  'pending',
  'revision_requested returns milestone to pending'
);

select is(
  (select review_period_expires_at from public.contract_milestones
    where id = current_setting('test.m1')::uuid),
  null,
  'revision cycle clears review_period_expires_at until re-completed'
);

-- Gate back to pending -> not-funded again (stable, no side effects).
select is(
  (select (public.service_contract_release_gate(
    current_setting('test.m1')::uuid)->'data'->>'reason')),
  'not-funded',
  'post-revision gate is not-funded again'
);

-- ─── 7. Link RPC guards (service_role path shape, no escrow fixture) ─────
-- Authenticated callers never reach the escrow checks (PLT002 first).
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select throws_ok(
  $$ select public.service_contract_link_escrow(
    current_setting('test.c1')::uuid,
    '00000000-0000-0000-0000-000000000000'::uuid,
    '[]'::jsonb) $$,
  'P0001', 'PLT002: Escrow linkage requires the platform release service.',
  'professional link attempt also fails PLT002'
);

-- ─── 8. Gate never mutates ───────────────────────────────────────────────
select is(
  (select count(*)::int from public.contract_events
    where contract_id = current_setting('test.c1')::uuid
      and event_type = 'milestone_released'),
  0,
  'gate probes append no milestone_released events'
);

select is(
  (select status from public.contract_milestones
    where id = current_setting('test.m1')::uuid),
  'pending',
  'gate probes change no milestone status'
);

select * from finish();
rollback;
