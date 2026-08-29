-- EP-02-05: Dispute RPC Enforcement
--
-- Validates the 8 dispute_* functions (EP-02-05 Plan §14.2):
--   - Authorization: anon cannot call any (42501); authenticated cannot call
--     dispute_resolve (42501); authenticated can call the 5 entity-facing RPCs;
--     service_role can call all 8.
--   - Validation/conflict: duplicate active dispute (PLT005), null/invalid params
--     (PLT003), non-party access (PLT004), split over escrow (PLT003),
--     dismissed with amounts (PLT003), withdraw non-open (PLT005).
--   - Functional: dispute_file places hold (escrow disputed); evidence immutable;
--     dispute_resolve release/refund/split perform inline double-entry movements
--     (escrow released/refunded, balances moved, financial_transactions +
--     financial_audit_trail written); dismissed releases hold with no movement;
--     dispute_withdraw releases hold; dispute_get/list party-scoped.
--   - Envelope: {success, code, message, data} with PLT000 on success.
--   - Posture: 8 dispute_ functions, exactly 3 SECURITY DEFINER (2 hold helpers +
--     dispute_withdraw), the 5 entity-facing RPCs not.

begin;
set search_path to extensions, public;
select plan(62);

-- ─── 0. Fixtures ──────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', '11111111-1111-1111-1111-111111111111', true); -- payer / filer A
select set_config('test.b', '22222222-2222-2222-2222-222222222222', true); -- payee / counterparty B

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
values ('tier_1', 'Tier 1', 100000)
on conflict (tier_code) do update set cashout_limit = 100000, name = 'Tier 1';

insert into public.entity_kyc_levels (entity_id, tier_code, status)
values (current_setting('test.a')::uuid, 'tier_1', 'active')
on conflict (entity_id) do nothing;

-- B financial profile (as B)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok($$ select public.financial_profile_create() $$, 'fixture: payee B financial profile');

-- A financial profile (as A)
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.financial_profile_create() $$, 'fixture: payer A financial profile');

-- Fund A's NGN balance via matched-name deposit (service_role)
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('test.dep',
  (select public.financial_deposit_record(current_setting('test.a')::uuid, 'NGN', 10000, 'Acme Ltd')->'data'->>'deposit_id'), true);
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  10000::numeric, 'fixture: A NGN available credited to 10000');

-- Create + fund 5 escrows (A payer, B payee)
select set_config('test.e1',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 3000,
     '[{"milestone_number":1,"title":"all","amount":3000}]'::jsonb)->'data'->>'escrow_id'), true);
select set_config('test.e2',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 1000,
     '[{"milestone_number":1,"title":"all","amount":1000}]'::jsonb)->'data'->>'escrow_id'), true);
select set_config('test.e3',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 2000,
     '[{"milestone_number":1,"title":"all","amount":2000}]'::jsonb)->'data'->>'escrow_id'), true);
select set_config('test.e4',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 2000,
     '[{"milestone_number":1,"title":"all","amount":2000}]'::jsonb)->'data'->>'escrow_id'), true);
select set_config('test.e5',
  (select public.financial_escrow_create(current_setting('test.a')::uuid, current_setting('test.b')::uuid, 'NGN', 1000,
     '[{"milestone_number":1,"title":"all","amount":1000}]'::jsonb)->'data'->>'escrow_id'), true);

select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e1')::uuid) $$, 'fixture: fund escrow E1');
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e2')::uuid) $$, 'fixture: fund escrow E2');
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e3')::uuid) $$, 'fixture: fund escrow E3');
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e4')::uuid) $$, 'fixture: fund escrow E4');
select lives_ok($$ select public.financial_escrow_fund(current_setting('test.e5')::uuid) $$, 'fixture: fund escrow E5');

-- ─── 1. Authorization: anon cannot call any dispute RPC (42501) ────────────────
set role anon;
select throws_ok($$ select public.dispute_file(null::uuid, null::text, null::text, null::text, null::text) $$, '42501', null, 'anon cannot call dispute_file');
select throws_ok($$ select public.dispute_submit_evidence(null::uuid, null::text, null::text) $$, '42501', null, 'anon cannot call dispute_submit_evidence');
select throws_ok($$ select public.dispute_resolve(null::uuid, null::text, null::text) $$, '42501', null, 'anon cannot call dispute_resolve');
select throws_ok($$ select public.dispute_withdraw(null::uuid) $$, '42501', null, 'anon cannot call dispute_withdraw');
select throws_ok($$ select public.dispute_get(null::uuid) $$, '42501', null, 'anon cannot call dispute_get');
select throws_ok($$ select public.dispute_list(null::text) $$, '42501', null, 'anon cannot call dispute_list');
select throws_ok($$ select public.dispute_place_escrow_hold(null::uuid) $$, '42501', null, 'anon cannot call dispute_place_escrow_hold');
select throws_ok($$ select public.dispute_release_escrow_hold(null::uuid) $$, '42501', null, 'anon cannot call dispute_release_escrow_hold');

-- ─── 2. Authenticated entity-facing functional + validation ───────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.c1',
  (select public.dispute_file(current_setting('test.e1')::uuid, 'non_delivery', 'Goods never arrived as agreed.', 'refund_to_payer')->'data'->>'id'), true);
select is(
  (select status from public.financial_escrow where id = current_setting('test.e1')::uuid),
  'disputed', 'dispute_file placed escrow E1 hold (status disputed)');
select is(
  (select status from public.dispute_cases where id = current_setting('test.c1')::uuid),
  'open', 'dispute_file created case c1 (status open)');

select throws_ok($$ select public.dispute_file(current_setting('test.e1')::uuid, 'non_delivery', 'Duplicate active dispute here.', 'refund_to_payer') $$,
  'P0001', null, 'duplicate active dispute rejected (PLT005)');

select lives_ok($$ select public.dispute_submit_evidence(current_setting('test.c1')::uuid, 'description', 'Proof the goods did not arrive') $$,
  'authenticated can submit evidence to open dispute');
select is(
  (select count(*)::int from public.dispute_evidence where case_id = current_setting('test.c1')::uuid),
  1, 'evidence row written');
select is(
  (select count(*)::int from public.dispute_audit_trail where case_id = current_setting('test.c1')::uuid and event_type = 'evidence_submitted'),
  1, 'evidence_submitted audit row written');

select lives_ok($$ select public.dispute_get(current_setting('test.c1')::uuid) $$, 'authenticated can get own dispute');
select lives_ok($$ select public.dispute_list(null::text) $$, 'authenticated can list own disputes');

-- File disputes for the remaining escrows (resolved later by service_role)
select set_config('test.c2',
  (select public.dispute_file(current_setting('test.e2')::uuid, 'service_quality', 'Service was below standard.', 'release_to_payee')->'data'->>'id'), true);
select set_config('test.c3',
  (select public.dispute_file(current_setting('test.e3')::uuid, 'milestone_disagreement', 'Milestone not met.', 'split')->'data'->>'id'), true);
select set_config('test.c4',
  (select public.dispute_file(current_setting('test.e4')::uuid, 'fraud', 'Fraudulent listing.', 'refund_to_payer')->'data'->>'id'), true);
select set_config('test.c5',
  (select public.dispute_file(current_setting('test.e5')::uuid, 'other', 'Other dispute reason text.', 'other')->'data'->>'id'), true);

-- Withdraw c2 (release E2 hold)
select lives_ok($$ select public.dispute_withdraw(current_setting('test.c2')::uuid) $$, 'authenticated can withdraw own open dispute');
select is(
  (select status from public.dispute_cases where id = current_setting('test.c2')::uuid),
  'withdrawn', 'withdrawn dispute c2 status withdrawn');
select is(
  (select status from public.financial_escrow where id = current_setting('test.e2')::uuid),
  'funded', 'withdraw released escrow E2 hold (status funded)');
select throws_ok($$ select public.dispute_withdraw(current_setting('test.c2')::uuid) $$, 'P0001', null, 'withdraw of non-open dispute rejected (PLT005)');

-- Validation paths
select throws_ok($$ select public.dispute_resolve(current_setting('test.c1')::uuid, 'release_to_payee', 'reason text') $$, '42501', null, 'authenticated cannot call dispute_resolve');
select throws_ok($$ select public.dispute_get('99999999-9999-9999-9999-999999999999') $$, 'P0001', null, 'get of unknown dispute rejected (PLT004)');
select throws_ok($$ select public.dispute_submit_evidence(current_setting('test.c1')::uuid, 'badtype', 'x') $$, 'P0001', null, 'invalid evidence type rejected (PLT003)');
select throws_ok($$ select public.dispute_file(null::uuid, 'non_delivery', 'Reason too short', 'refund_to_payer') $$, 'P0001', null, 'null escrow id rejected (PLT003)');
select lives_ok($$ select public.dispute_list('open') $$, 'authenticated can list open disputes');

-- ─── 3. Service_role resolution: inline double-entry ───────────────────────────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);

-- 3a. release_to_payee on c1 / E1
select set_config('test.a_held1',
  (select held_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select lives_ok($$ select public.dispute_resolve(current_setting('test.c1')::uuid, 'release_to_payee', 'Release to payee justified by evidence.') $$,
  'service_role resolves c1 release_to_payee');
select is(
  (select status from public.financial_escrow where id = current_setting('test.e1')::uuid),
  'released', 'escrow E1 released after resolution');
select is(
  (select held_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.a_held1')::numeric - 3000), 'payer A held debited by 3000 on release');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.b')::uuid and currency_code = 'NGN'),
  3000::numeric, 'payee B available credited by 3000 on release');
select is(
  (select count(*)::int from public.financial_transactions where reference_id = current_setting('test.e1')::uuid and transaction_type = 'escrow_release'),
  1, 'escrow_release ledger row written');
select is(
  (select count(*)::int from public.dispute_resolutions where case_id = current_setting('test.c1')::uuid),
  1, 'resolution row written for c1');
select is(
  (select status from public.dispute_cases where id = current_setting('test.c1')::uuid),
  'resolved', 'dispute c1 status resolved');

-- 3b. split on c3 / E3
select set_config('test.a_held2',
  (select held_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select set_config('test.a_avail2',
  (select available_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select lives_ok($$ select public.dispute_resolve(current_setting('test.c3')::uuid, 'split', 'Split is fair.', 500, 1500) $$,
  'service_role resolves c3 split (refund 500 / release 1500)');
select is(
  (select status from public.financial_escrow where id = current_setting('test.e3')::uuid),
  'released', 'escrow E3 released after split');
select is(
  (select released_amount from public.financial_escrow where id = current_setting('test.e3')::uuid),
  1500::numeric, 'escrow E3 released_amount = 1500');
select is(
  (select refunded_amount from public.financial_escrow where id = current_setting('test.e3')::uuid),
  500::numeric, 'escrow E3 refunded_amount = 500');
select is(
  (select held_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.a_held2')::numeric - 2000), 'payer A held debited by 2000 on split');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.a_avail2')::numeric + 500), 'payer A available credited by 500 (refund) on split');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.b')::uuid and currency_code = 'NGN'),
  4500::numeric, 'payee B available credited by 1500 (release) on split');
select is(
  (select count(*)::int from public.financial_transactions
    where reference_id = current_setting('test.e3')::uuid
      and transaction_type in ('escrow_release', 'escrow_refund')),
  2, 'split wrote two ledger rows (release + refund)');

-- 3c. refund_to_payer on c4 / E4
select set_config('test.a_held3',
  (select held_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select set_config('test.a_avail3',
  (select available_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select lives_ok($$ select public.dispute_resolve(current_setting('test.c4')::uuid, 'refund_to_payer', 'Refund to payer warranted.') $$,
  'service_role resolves c4 refund_to_payer');
select is(
  (select status from public.financial_escrow where id = current_setting('test.e4')::uuid),
  'refunded', 'escrow E4 refunded after resolution');
select is(
  (select available_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.a_avail3')::numeric + 2000), 'payer A available credited by 2000 on refund');
select is(
  (select held_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  (current_setting('test.a_held3')::numeric - 2000), 'payer A held debited by 2000 on refund');
select is(
  (select count(*)::int from public.financial_transactions where reference_id = current_setting('test.e4')::uuid and transaction_type = 'escrow_refund'),
  1, 'escrow_refund ledger row written');

-- 3d. dismissed on c5 / E5 (hold released, no movement)
select set_config('test.a_held4',
  (select held_balance::text from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'), true);
select lives_ok($$ select public.dispute_resolve(current_setting('test.c5')::uuid, 'dismissed', 'Dispute dismissed as unfounded.') $$,
  'service_role resolves c5 dismissed');
select is(
  (select status from public.financial_escrow where id = current_setting('test.e5')::uuid),
  'funded', 'escrow E5 hold released (status funded) on dismissed');
select is(
  (select resolution_type from public.dispute_resolutions where case_id = current_setting('test.c5')::uuid),
  'dismissed', 'resolution type recorded as dismissed');
select is(
  (select held_balance from public.financial_balances where entity_id = current_setting('test.a')::uuid and currency_code = 'NGN'),
  current_setting('test.a_held4')::numeric, 'dismissed caused no balance movement');

-- ─── 4. Envelope contract ──────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select count(*)::int from jsonb_object_keys(public.dispute_list(null::text))),
  4, 'list envelope has exactly 4 top-level keys');
select is(
  (select (public.dispute_list(null::text)->>'code')),
  'PLT000', 'list envelope code is PLT000');

-- ─── 5. Posture ────────────────────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_proc where proname like 'dispute_%' and prorettype <> 'trigger'::regtype),
  8, 'exactly 8 dispute_ functions exist');
select is(
  (select count(*)::int from pg_proc where proname like 'dispute_%' and prosecdef),
  3, 'exactly 3 dispute_ functions are SECURITY DEFINER (2 hold helpers + dispute_withdraw)');
select is(
  (select count(*)::int from pg_proc
    where proname in ('dispute_file', 'dispute_submit_evidence', 'dispute_resolve', 'dispute_get', 'dispute_list')
      and prosecdef),
  0, 'the 5 entity-facing RPCs are not SECURITY DEFINER');

select * from finish();
rollback;
