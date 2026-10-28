-- Identity Phase 1c: approved-trade gate on application_submit (Rule 2).
--
-- Validates that typed jobs require an approved trade binding for the job's
-- profession, untyped jobs keep capability-only behavior, and wrong-profession
-- approvals do not satisfy the gate:
--   - 3 publishes + 1 approved-apply + 1 submitted-state + 1 unapproved-denied +
--   - 1 untyped-allowed + 1 wrong-profession-denied + 1 no-phantom-row = 9.

begin;
set search_path to extensions, public;
select plan(9);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'f1f1f1f1-1111-4111-8111-111111111111', true);
select set_config('test.b', 'f2f2f2f2-2222-4222-8222-222222222222', true);
select set_config('test.c', 'f3f3f3f3-3333-4333-8333-333333333333', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'gate-client@example.com'),
       (current_setting('test.b')::uuid, 'gate-approved@example.com'),
       (current_setting('test.c')::uuid, 'gate-pending@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active')
on conflict (id) do nothing;

-- These accounts are identity-verified; trade verification remains separate.
insert into public.entity_kyc_levels (entity_id, tier_code, status)
select e.id, 'tier_1', 'active' from public.entities e
on conflict (entity_id) do update
  set tier_code = excluded.tier_code, status = excluded.status;

select set_config('platform.rpc_invocation', 'on', true);
update public.entities set capability = 'hire'
 where id = current_setting('test.a')::uuid;
update public.entities set capability = 'offer'
 where id in (current_setting('test.b')::uuid, current_setting('test.c')::uuid);
select set_config('platform.rpc_invocation', '', true);

insert into public.industries (id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000091', 'gate-trade', 'Gate Trade', true)
on conflict (id) do nothing;

insert into public.professions (id, industry_id, slug, name, is_active)
values ('ffffffff-0000-0000-0000-000000000092', 'ffffffff-0000-0000-0000-000000000091', 'gate-fixer', 'Gate Fixer', true),
       ('ffffffff-0000-0000-0000-000000000093', 'ffffffff-0000-0000-0000-000000000091', 'gate-other', 'Gate Other', true)
on conflict (id) do nothing;

-- B holds an approved binding for the typed profession only.
insert into public.entity_professions (entity_id, profession_id, is_primary, trade_verification_status)
values (current_setting('test.b')::uuid, 'ffffffff-0000-0000-0000-000000000092', true, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- A posts three jobs: typed P1, untyped, typed P2.
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.j1', (select (public.job_create(
  'Fix the kitchen sink urgently today',
  'Kitchen sink drainage is blocked and the faucet leaks continuously. Need a certified plumber with own tools this week.',
  'ffffffff-0000-0000-0000-000000000092', null, 5000, 20000, 'NGN', 'Lagos'
)->'data'->>'id')), true);
select set_config('test.j2', (select (public.job_create(
  'Help moving boxes this weekend',
  'Need an extra pair of hands moving packed boxes from the apartment to a van on Saturday morning.',
  null, null, 5000, 20000, 'NGN', 'Lagos'
)->'data'->>'id')), true);
select set_config('test.j3', (select (public.job_create(
  'Paint the living room walls',
  'Two-coat repaint of the living room walls including ceiling edges. Paint supplied by the homeowner.',
  'ffffffff-0000-0000-0000-000000000093', null, 5000, 20000, 'NGN', 'Lagos'
)->'data'->>'id')), true);

select lives_ok($$ select public.job_publish(current_setting('test.j1')::uuid) $$,
  'owner publishes typed job J1');
select lives_ok($$ select public.job_publish(current_setting('test.j2')::uuid) $$,
  'owner publishes untyped job J2');
select lives_ok($$ select public.job_publish(current_setting('test.j3')::uuid) $$,
  'owner publishes typed job J3 (other profession)');

-- ─── 1. Approved professional applies to the typed job ───────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select lives_ok(
  $$ select public.application_submit(
    current_setting('test.j1')::uuid,
    'Certified gate plumber with own tools, available this week for the typed job.'
  ) $$,
  'approved binding for the job profession applies cleanly (PLT000)'
);
select is(
  (select status from public.job_applications
    where job_id = current_setting('test.j1')::uuid
      and professional_entity_id = current_setting('test.b')::uuid),
  'submitted',
  'approved application lands submitted'
);

-- ─── 2. Unbound professional denied on the typed job ─────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);

select throws_ok(
  $$ select public.application_submit(
    current_setting('test.j1')::uuid,
    'Eager gate plumber without approval, available this week for the job.'
  ) $$,
  'P0001', 'PLT005: Trade verification required for this profession. Complete approval to apply.',
  'unapproved applicant denied on typed job with guidance'
);

-- ─── 3. Untyped job keeps capability-only behavior ───────────────────────────
select lives_ok(
  $$ select public.application_submit(
    current_setting('test.j2')::uuid,
    'Extra hands for the weekend move, strong back and own transport ready.'
  ) $$,
  'unapproved applicant still applies to untyped jobs (PLT000)'
);

-- ─── 4. Wrong-profession approval does not satisfy the gate ──────────────────
select throws_ok(
  $$ select public.application_submit(
    current_setting('test.j3')::uuid,
    'Gate plumber approved elsewhere tries the painting job this week now.'
  ) $$,
  'P0001', 'PLT005: Trade verification required for this profession. Complete approval to apply.',
  'approval for another profession denied on typed job'
);
select is(
  (select count(*)::int from public.job_applications
    where job_id = current_setting('test.j1')::uuid
      and professional_entity_id = current_setting('test.c')::uuid),
  0,
  'denied submit leaves no phantom application row'
);

select * from finish();
rollback;
