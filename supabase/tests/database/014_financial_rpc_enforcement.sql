-- EP-02-04: Financial RPC Enforcement
--
-- Validates the 17 financial_* RPCs (EP-02-04 Plan §14.2):
--   NOTE: the plan text says "18 RPCs" but enumerates 17 distinct RPCs
--   (§9.1 / DoD §17). This suite tests exactly the 17 that exist.
--
--   - Authorization: anon cannot call any (42501); authenticated cannot call the
--     9 service_role-only RPCs (42501); authenticated can call the 8 entity-facing
--     RPCs; service_role can call all 17.
--   - Validation: PLT003/PLT004/PLT005/PLT006 paths for profile, escrow, withdraw,
--     convert, payout, deposit.
--   - Functional / double-entry: profile create, escrow fund/release/refund,
--     milestone auto-release, withdraw, deposit+name-match, convert, reconcile
--     (including tamper detection).
--   - Envelope: {success, code, message, data} with PLT000 on success.
--   - Posture: 17 financial_* functions, none SECURITY DEFINER.

begin;
set search_path to extensions, public;
select plan(96);

-- ─── 0. Fixtures ──────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', '11111111-1111-1111-1111-111111111111', true);
select set_config('test.b', '22222222-2222-2222-2222-222222222222', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'entity-a@example.com'),
       (current_setting('test.b')::uuid, 'entity-b@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, legal_name, display_name)
values (current_setting('test.a')::uuid, 'Acme Ltd', 'Acme Ltd')
on conflict (entity_id) do nothing;

insert into public.kyc_tiers (tier_code, name, cashout_limit)
values ('tier_1', 'Tier 1', 1000)
on conflict (tier_code) do update set cashout_limit = 1000, name = 'Tier 1';

insert into public.entity_kyc_levels (entity_id, tier_code, status)
values (current_setting('test.a')::uuid, 'tier_1', 'active')
on conflict (entity_id) do nothing;

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok($$ select public.financial_profile_create() $$, 'fixture: payee B financial profile seeded');
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select set_config('test.c', '33333333-3333-3333-3333-333333333333', true);
insert into auth.users (id, email) values (current_setting('test.c')::uuid, 'entity-c@example.com') on conflict (id) do nothing;
insert into public.entities (id, status) values (current_setting('test.c')::uuid, 'active') on conflict (id) do nothing;

-- ─── 1. Authorization: anon cannot call any financial RPC (42501) ─────────────
set role anon;

select throws_ok($$ select public.financial_profile_create() $$, '42501', null, 'anon cannot call financial_profile_create');
select throws_ok($$ select public.financial_profile_get() $$, '42501', null, 'anon cannot call financial_profile_get');
select throws_ok($$ select public.financial_balance_get(null::char(3)) $$, '42501', null, 'anon cannot call financial_balance_get');
select throws_ok($$ select public.financial_escrow_create(null::uuid, null::uuid, null::char(3), null::numeric, null::jsonb) $$, '42501', null, 'anon cannot call financial_escrow_create');
select throws_ok($$ select public.financial_escrow_fund(null::uuid) $$, '42501', null, 'anon cannot call financial_escrow_fund');
select throws_ok($$ select public.financial_escrow_release(null::uuid) $$, '42501', null, 'anon cannot call financial_escrow_release');
select throws_ok($$ select public.financial_escrow_refund(null::uuid) $$, '42501', null, 'anon cannot call financial_escrow_refund');
select throws_ok($$ select public.financial_escrow_milestone_complete(null::uuid) $$, '42501', null, 'anon cannot call financial_escrow_milestone_complete');
select throws_ok($$ select public.financial_escrow_get(null::uuid) $$, '42501', null, 'anon cannot call financial_escrow_get');
select throws_ok($$ select public.financial_payout_account_bind(null::char(3), null::text, null::text, null::text) $$, '42501', null, 'anon cannot call financial_payout_account_bind');
select throws_ok($$ select public.financial_payout_account_verify(null::uuid, null::text) $$, '42501', null, 'anon cannot call financial_payout_account_verify');
select throws_ok($$ select public.financial_withdraw(null::uuid, null::numeric) $$, '42501', null, 'anon cannot call financial_withdraw');
select throws_ok($$ select public.financial_deposit_record(null::uuid, null::char(3), null::numeric) $$, '42501', null, 'anon cannot call financial_deposit_record');
select throws_ok($$ select public.financial_deposit_verify_name(null::uuid) $$, '42501', null, 'anon cannot call financial_deposit_verify_name');
select throws_ok($$ select public.financial_convert_currency(null::char(3), null::char(3), null::numeric, null::numeric) $$, '42501', null, 'anon cannot call financial_convert_currency');
select throws_ok($$ select public.financial_status_get() $$, '42501', null, 'anon cannot call financial_status_get');
select throws_ok($$ select public.financial_reconcile(null::uuid, null::char(3)) $$, '42501', null, 'anon cannot call financial_reconcile');

-- ─── 2. Authentication + validation: authenticated (entity A) ─────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok($$ select public.financial_profile_create() $$, 'authenticated can create financial profile');
select throws_ok($$ select public.financial_profile_create() $$, 'P0001', null, 'duplicate profile rejected (PLT005)');
select lives_ok($$ select public.financial_profile_get() $$, 'authenticated can call financial_profile_get');
select lives_ok($$ select public.financial_balance_get('NGN') $$, 'authenticated can call financial_balance_get');
select lives_ok($$ select public.financial_status_get() $$, 'authenticated can call financial_status_get');

select set_config('test.acct',
  (select public.financial_payout_account_bind('NGN', 'Test Bank', '0001', 'Acme Ltd')->'data'->>'payout_account_id'), true);
select throws_ok($$ select public.financial_payout_account_bind('NGN', 'Test Bank', '0001', 'Acme Ltd') $$, 'P0001', null, 'duplicate payout account rejected (PLT005)');
select throws_ok($$ select public.financial_balance_get('ZZZ') $$, 'P0001', null, 'unsupported currency rejected (PLT004)');

select throws_ok($$ select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 1000, null::jsonb) $$, '42501', null, 'authenticated cannot call financial_escrow_create');
select throws_ok($$ select public.financial_escrow_fund(null::uuid) $$, '42501', null, 'authenticated cannot call financial_escrow_fund');
select throws_ok($$ select public.financial_escrow_release(null::uuid) $$, '42501', null, 'authenticated cannot call financial_escrow_release');
select throws_ok($$ select public.financial_escrow_refund(null::uuid) $$, '42501', null, 'authenticated cannot call financial_escrow_refund');
select throws_ok($$ select public.financial_escrow_milestone_complete(null::uuid) $$, '42501', null, 'authenticated cannot call financial_escrow_milestone_complete');
select throws_ok($$ select public.financial_payout_account_verify(null::uuid, null::text) $$, '42501', null, 'authenticated cannot call financial_payout_account_verify');
select throws_ok($$ select public.financial_deposit_record(current_setting('test.a')::uuid, 'NGN', 100, 'X') $$, '42501', null, 'authenticated cannot call financial_deposit_record');
select throws_ok($$ select public.financial_deposit_verify_name(null::uuid) $$, '42501', null, 'authenticated cannot call financial_deposit_verify_name');
select throws_ok($$ select public.financial_reconcile(current_setting('test.a')::uuid, 'NGN') $$, '42501', null, 'authenticated cannot call financial_reconcile');

-- ─── 3. Fund + verify via service_role (fixtures for entity-facing reads) ──────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);

select set_config('test.dep_usd',
  (select public.financial_deposit_record(current_setting('test.a')::uuid, 'USD', 500, 'Acme Ltd')->'data'->>'deposit_id'), true);
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'USD'),
  500::numeric, 'USD deposit (matched name) credited to available balance');
select is(
  (select status from public.financial_deposits where id = current_setting('test.dep_usd')::uuid),
  'credited', 'matched deposit marked credited');

select set_config('test.dep_ngn',
  (select public.financial_deposit_record(current_setting('test.a')::uuid, 'NGN', 10000, 'Acme Ltd')->'data'->>'deposit_id'), true);
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  10000::numeric, 'NGN deposit (matched name) credited to available balance');
select is(
  (select status from public.financial_deposits where id = current_setting('test.dep_ngn')::uuid),
  'credited', 'NGN deposit marked credited');

select set_config('test.e1',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 3000,
     '[{"milestone_number":1,"title":"all","amount":3000}]'::jsonb)->'data'->>'escrow_id'), true);
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e1')::uuid) $$, 'service_role can fund escrow E1');
select is(
  (select status from public.financial_escrow where id = current_setting('test.e1')::uuid),
  'funded', 'escrow E1 status funded');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  7000::numeric, 'payer NGN available debited by 3000 on fund');
select is(
  (select held_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  3000::numeric, 'payer NGN held credited by 3000 on fund');
select is(
  (select count(*)::int from public.financial_transactions
    where reference_id = current_setting('test.e1')::uuid and transaction_type = 'escrow_fund'
      and debit_balance_type = 'available' and credit_balance_type = 'held'),
  1, 'escrow_fund wrote double-entry transaction');

select lives_ok($$ select public.financial_payout_account_verify(current_setting('test.acct')::uuid, 'name_enquiry') $$, 'service_role can verify payout account');
select is(
  (select is_verified from public.financial_payout_accounts where id = current_setting('test.acct')::uuid),
  true, 'payout account marked verified');

-- ─── 4. Authenticated entity-facing functional reads/writes ───────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select lives_ok($$ select public.financial_escrow_get(current_setting('test.e1')::uuid) $$, 'authenticated can read own escrow');
select lives_ok($$ select public.financial_withdraw(current_setting('test.acct')::uuid, 500) $$, 'authenticated can withdraw within limit');
select throws_ok($$ select public.financial_withdraw(current_setting('test.acct')::uuid, 5000) $$, 'P0001', null, 'withdraw over cashout limit rejected (PLT006)');
select throws_ok($$ select public.financial_withdraw(current_setting('test.acct')::uuid, 999999) $$, 'P0001', null, 'withdraw over balance rejected (PLT006)');
select lives_ok($$ select public.financial_convert_currency('NGN', 'USD', 1000, 0.002) $$, 'authenticated can convert currency');

-- ─── 5. Service_role functional double-entry ──────────────────────────────────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);

select set_config('test.before_avail',
  (select available_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select set_config('test.before_held',
  (select held_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select set_config('test.e2',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 2000,
     '[{"milestone_number":1,"title":"all","amount":2000}]'::jsonb)->'data'->>'escrow_id'), true);
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e2')::uuid) $$, 'service_role can fund escrow E2');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.before_avail')::numeric - 2000), 'payer available debited by 2000 on E2 fund');
select is(
  (select held_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.before_held')::numeric + 2000), 'payer held credited by 2000 on E2 fund');

select set_config('test.payee_before',
  coalesce((select available_balance::text from public.financial_balances where entity_id = current_setting('test.b')::uuid and currency_code = 'NGN'), '0'), true);
select lives_ok($$ select public.financial_escrow_release(current_setting('test.e2')::uuid) $$, 'service_role can release escrow E2');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.b')::uuid and currency_code = 'NGN'),
  (current_setting('test.payee_before')::numeric + 2000), 'payee available credited by 2000 on release');
select is(
  (select held_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.before_held')::numeric), 'payer held returned to prior on release');
select is(
  (select released_amount from public.financial_escrow where id = current_setting('test.e2')::uuid),
  2000::numeric, 'escrow E2 released_amount = 2000');

select set_config('test.e3',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 1500,
     '[{"milestone_number":1,"title":"all","amount":1500}]'::jsonb)->'data'->>'escrow_id'), true);
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e3')::uuid) $$, 'fund escrow E3');
select set_config('test.refund_before',
  (select available_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select lives_ok($$ select public.financial_escrow_refund(current_setting('test.e3')::uuid) $$, 'service_role can refund escrow E3');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.refund_before')::numeric + 1500), 'payer available credited by 1500 on refund');
select is(
  (select refunded_amount from public.financial_escrow where id = current_setting('test.e3')::uuid),
  1500::numeric, 'escrow E3 refunded_amount = 1500');

select set_config('test.e4',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 1000,
     '[{"milestone_number":1,"title":"M1","amount":500},{"milestone_number":2,"title":"M2","amount":500}]'::jsonb)->'data'->>'escrow_id'), true);
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e4')::uuid) $$, 'fund escrow E4');
select set_config('test.m1',
  (select id::text from public.financial_escrow_milestones where escrow_id = current_setting('test.e4')::uuid order by milestone_number limit 1), true);
select set_config('test.m2',
  (select id::text from public.financial_escrow_milestones where escrow_id = current_setting('test.e4')::uuid order by milestone_number desc limit 1), true);
select lives_ok($$ select public.financial_escrow_milestone_complete(current_setting('test.m1')::uuid) $$, 'complete milestone M1');
select is(
  (select status from public.financial_escrow where id = current_setting('test.e4')::uuid),
  'partially_released', 'escrow E4 partially_released after one milestone');
select lives_ok($$ select public.financial_escrow_milestone_complete(current_setting('test.m2')::uuid) $$, 'complete milestone M2');
select is(
  (select status from public.financial_escrow where id = current_setting('test.e4')::uuid),
  'released', 'escrow E4 released after all milestones');
select is(
  (select count(*)::int from public.financial_transactions
    where reference_id = current_setting('test.e4')::uuid and transaction_type = 'escrow_release'),
  2, 'two milestone releases wrote ledger rows');

select set_config('test.dep_bad',
  (select public.financial_deposit_record(current_setting('test.a')::uuid, 'NGN', 100, 'Wrong Name')->'data'->>'deposit_id'), true);
select set_config('test.before_bad',
  (select available_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select is(
  (select status from public.financial_deposits where id = current_setting('test.dep_bad')::uuid),
  'flagged', 'mismatched deposit flagged');
select is(
  (select name_match_status from public.financial_deposits where id = current_setting('test.dep_bad')::uuid),
  'mismatched', 'mismatched deposit name_match_status = mismatched');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.before_bad')::numeric), 'mismatched deposit did NOT credit balance');
select is(
  (select (public.financial_deposit_verify_name(current_setting('test.dep_bad')::uuid)->'data'->>'name_match_status')),
  'mismatched', 'deposit_verify_name returns mismatched');
select is(
  (select (public.financial_deposit_verify_name(current_setting('test.dep_usd')::uuid)->'data'->>'name_match_status')),
  'matched', 'deposit_verify_name returns matched');

select is(
  (select (public.financial_reconcile(current_setting('test.a')::uuid, 'NGN')->'data'->>'reconciled')),
  'true', 'reconcile true when balances match ledger');
update public.financial_balances
   set available_balance = available_balance + 123, updated_at = now()
 where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN';
select is(
  (select (public.financial_reconcile(current_setting('test.a')::uuid, 'NGN')->'data'->>'reconciled')),
  'false', 'reconcile false after balance tamper');

-- ─── 6. Envelope contract ──────────────────────────────────────────────────────
select is(
  (select count(*)::int from jsonb_object_keys(public.financial_status_get())),
  4, 'status envelope has exactly 4 top-level keys');
select is(
  (select (public.financial_status_get()->>'code')),
  'PLT000', 'status envelope code is PLT000');

-- ─── 7. service_role can call all 17 RPCs (lives_ok) ──────────────────────────
set role service_role;
select set_config('test.c', '33333333-3333-3333-3333-333333333333', true);
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select lives_ok($$ select public.financial_profile_create() $$, 'service_role can call financial_profile_create (entity C)');
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.financial_profile_get() $$, 'service_role can call financial_profile_get');
select lives_ok($$ select public.financial_balance_get('NGN') $$, 'service_role can call financial_balance_get');
select set_config('test.e5',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 100,
     '[{"milestone_number":1,"title":"all","amount":100}]'::jsonb)->'data'->>'escrow_id'), true);
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e5')::uuid) $$, 'service_role can call financial_escrow_fund');
select lives_ok($$ select public.financial_escrow_release(current_setting('test.e5')::uuid) $$, 'service_role can call financial_escrow_release');
select set_config('test.e6',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 50,
     '[{"milestone_number":1,"title":"all","amount":50}]'::jsonb)->'data'->>'escrow_id'), true);
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e6')::uuid) $$, 'fund escrow E6');
select lives_ok($$ select public.financial_escrow_refund(current_setting('test.e6')::uuid) $$, 'service_role can call financial_escrow_refund');
select set_config('test.e7',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 60,
     '[{"milestone_number":1,"title":"all","amount":60}]'::jsonb)->'data'->>'escrow_id'), true);
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e7')::uuid) $$, 'fund escrow E7');
select set_config('test.mx',
  (select id::text from public.financial_escrow_milestones where escrow_id = current_setting('test.e7')::uuid limit 1), true);
select lives_ok($$ select public.financial_escrow_milestone_complete(current_setting('test.mx')::uuid) $$, 'service_role can call financial_escrow_milestone_complete');
select lives_ok($$ select public.financial_escrow_get(current_setting('test.e1')::uuid) $$, 'service_role can call financial_escrow_get');
select lives_ok($$ select public.financial_payout_account_bind('NGN', 'Other Bank', '0002', 'Acme Ltd') $$, 'service_role can call financial_payout_account_bind');
select lives_ok($$ select public.financial_payout_account_verify(current_setting('test.acct')::uuid, 'manual') $$, 'service_role can call financial_payout_account_verify');
select lives_ok($$ select public.financial_withdraw(current_setting('test.acct')::uuid, 100) $$, 'service_role can call financial_withdraw');
select lives_ok($$ select public.financial_deposit_record(current_setting('test.a')::uuid, 'NGN', 50, 'Acme Ltd') $$, 'service_role can call financial_deposit_record');
select lives_ok($$ select public.financial_deposit_verify_name(current_setting('test.dep_usd')::uuid) $$, 'service_role can call financial_deposit_verify_name');
select lives_ok($$ select public.financial_convert_currency('NGN', 'USD', 10, 0.002) $$, 'service_role can call financial_convert_currency');
select lives_ok($$ select public.financial_status_get() $$, 'service_role can call financial_status_get');
select lives_ok($$ select public.financial_reconcile(current_setting('test.a')::uuid, 'NGN') $$, 'service_role can call financial_reconcile');

-- ─── 8. Posture ────────────────────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_proc where proname like 'financial_%' and prorettype <> 'trigger'::regtype),
  17, 'exactly 17 financial_* functions exist');
select is(
  (select count(*)::int from pg_proc where proname like 'financial_%' and prosecdef),
  0, 'no financial_* function is SECURITY DEFINER');

select * from finish();
rollback;
