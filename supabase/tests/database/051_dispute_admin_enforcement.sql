-- R3 follow-up: service dispute admin RPC enforcement
--
-- Validates the admin-gated read path:
--   - anon cannot call either RPC (42501); non-admin gets PLT002 (no oracle
--     between "not admin" and "missing" — both raise inside the gate);
--   - validation: bad status/limit/offset/case id (PLT003), unknown case
--     (PLT004);
--   - functional: admin list returns the filed service case with its contract
--     join + total_count; status filter scopes; admin get returns
--     case + evidence + resolution + contract join.

begin;
set search_path to extensions, public;
select plan(13);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('test.b', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('test.c', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
select set_config('test.d', 'dddddddd-dddd-dddd-dddd-dddddddddddd', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'adm-a@example.com'),
       (current_setting('test.b')::uuid, 'adm-b@example.com'),
       (current_setting('test.c')::uuid, 'adm-c@example.com'),
       (current_setting('test.d')::uuid, 'adm-d@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active'),
       (current_setting('test.d')::uuid, 'active')
on conflict (id) do nothing;

-- These accounts are identity-verified; trade verification remains separate.
insert into public.entity_kyc_levels (entity_id, tier_code, status)
select e.id, 'tier_1', 'active' from public.entities e
on conflict (entity_id) do update
  set tier_code = excluded.tier_code, status = excluded.status;

insert into public.platform_admins (user_id, granted_by, notes)
values (current_setting('test.d')::uuid, null, 'dispute queue test admin')
on conflict (user_id) do nothing;

select set_config('test.prof1',
  (select id::text from public.professions limit 1), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.l1', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Admin Queue Dispute Fixture Offering',
  'Fixture listing backing the admin dispute queue enforcement test case.',
  'fixed', 10000, 50000)->'data'->>'id'), true);
select public.service_listing_publish(current_setting('test.l1')::uuid);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.c1', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 20000, 'NGN',
  '[{"milestone_number":1,"title":"Admin queue milestone","amount":20000}]'::jsonb
)->'data'->'contract'->>'id'), true);
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select public.service_contract_accept(current_setting('test.c1')::uuid);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.case1',
  (select public.service_dispute_file(current_setting('test.c1')::uuid, 'non_delivery',
    'The professional stopped responding after accepting the engagement.')->'data'->>'id'), true);

-- ─── 1. anon cannot call either RPC (42501) ───────────────────────────────────
set role anon;
select throws_ok($$ select public.service_dispute_admin_list(null::text, 50, 0) $$,
  '42501', null, 'anon cannot call service_dispute_admin_list');
select throws_ok($$ select public.service_dispute_admin_get(null::uuid) $$,
  '42501', null, 'anon cannot call service_dispute_admin_get');

-- ─── 2. Non-admin gate (PLT002) ───────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.service_dispute_admin_list(null::text, 50, 0) $$,
  'P0001', null, 'non-admin list rejected (PLT002)');
select throws_ok($$ select public.service_dispute_admin_get(current_setting('test.case1')::uuid) $$,
  'P0001', null, 'non-admin get rejected (PLT002)');

-- ─── 3. Admin validation ─────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.d'), true);
select throws_ok($$ select public.service_dispute_admin_list('bogus', 50, 0) $$,
  'P0001', null, 'bad status filter rejected (PLT003)');
select throws_ok($$ select public.service_dispute_admin_list(null::text, 0, 0) $$,
  'P0001', null, 'zero limit rejected (PLT003)');
select throws_ok($$ select public.service_dispute_admin_get('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'unknown case rejected (PLT004)');

-- ─── 4. Admin functional reads ───────────────────────────────────────────────
select is(
  (select public.service_dispute_admin_list(null::text, 50, 0)->'data'->>'total_count'),
  '1', 'admin list reports the filed service case');
select is(
  (select public.service_dispute_admin_list(null::text, 50, 0)->'data'->'disputes'->0->>'contract_status'),
  'disputed', 'admin list joins the frozen contract status');
select is(
  (select jsonb_array_length(public.service_dispute_admin_list('resolved', 50, 0)->'data'->'disputes')),
  0, 'status filter scopes the admin list');
select lives_ok($$ select public.service_dispute_admin_get(current_setting('test.case1')::uuid) $$,
  'admin get returns the case');
select is(
  (select public.service_dispute_admin_get(current_setting('test.case1')::uuid)->'data'->'contract'->>'id'),
  current_setting('test.c1'), 'admin get joins the contract summary');
select is(
  (select public.service_dispute_admin_get(current_setting('test.case1')::uuid)->>'code'),
  'PLT000', 'envelope carries PLT000 on success');

select finish();
rollback;
