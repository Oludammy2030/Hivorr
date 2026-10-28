-- EP-03-17: Service Dispute RPC Enforcement
--
-- Validates service_dispute_file / service_dispute_get /
-- service_dispute_list_for_contract plus the freeze/unfreeze triggers:
--   - Authorization: anon cannot call any (42501); non-participant reads as
--     identical PLT004 (no enumeration oracle); authenticated cannot call
--     dispute_resolve (42501).
--   - Validation: null/bad params (PLT003), unknown/stranger contract (PLT004),
--     duplicate active dispute (PLT005), bad status filter (PLT003).
--   - Unfunded flow: file freezes contract only (escrow NULL), verify blocked
--     (PLT005), withdraw restores pre-dispute status.
--   - Funded flow: file freezes contract + escrow, release gate reports
--     disputed, service_role dismissed resolve releases both holds with no
--     fund movement and restores the contract.
--   - Regression: legacy escrow-only dispute_file still works and leaves
--     contract linkage NULL; envelope stays {success,code,message,data}.

begin;
set search_path to extensions, public;
select plan(44);

-- ─── 0. Fixtures ─────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('test.b', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('test.c', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'svcdisp-a@example.com'),
       (current_setting('test.b')::uuid, 'svcdisp-b@example.com'),
       (current_setting('test.c')::uuid, 'svcdisp-c@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active')
on conflict (id) do nothing;

insert into public.entity_profiles (entity_id, legal_name, display_name)
values (current_setting('test.b')::uuid, 'Beta Client Ltd', 'Beta Client Ltd')
on conflict (entity_id) do nothing;

insert into public.kyc_tiers (tier_code, name, cashout_limit)
values ('tier_1', 'Tier 1', 100000)
on conflict (tier_code) do update set cashout_limit = 100000, name = 'Tier 1';

-- These accounts are identity-verified; trade verification remains separate.
insert into public.entity_kyc_levels (entity_id, tier_code, status)
values (current_setting('test.a')::uuid, 'tier_1', 'active'),
       (current_setting('test.b')::uuid, 'tier_1', 'active'),
       (current_setting('test.c')::uuid, 'tier_1', 'active')
on conflict (entity_id) do update
  set tier_code = excluded.tier_code, status = excluded.status;

select set_config('test.prof1',
  (select id::text from public.professions limit 1), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- Financial profiles for payer B + payee A, then fund B.
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok($$ select public.financial_profile_create() $$, 'fixture: payer B financial profile');
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.financial_profile_create() $$, 'fixture: payee A financial profile');

set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'service_role', true);
select public.financial_deposit_record(current_setting('test.b')::uuid, 'NGN', 100000, 'Beta Client Ltd');

-- Published listing owned by A.
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.l1', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Service Dispute Linkage Fixture Offering',
  'Fixture listing for contract-anchored dispute tests with sufficient descriptive length.',
  'fixed', 10000, 50000)->'data'->>'id'), true);
select public.service_listing_publish(current_setting('test.l1')::uuid);

-- Unfunded contract: B offers, A accepts (escrow stays NULL).
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.cu', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 20000, 'NGN',
  '[{"milestone_number":1,"title":"Unfunded milestone work","amount":20000}]'::jsonb
)->'data'->'contract'->>'id'), true);
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select public.service_contract_accept(current_setting('test.cu')::uuid);

-- Funded contract: B offers, A accepts, service_role funds + links escrow.
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.cf', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 30000, 'NGN',
  '[{"milestone_number":1,"title":"Funded milestone work","amount":30000}]'::jsonb
)->'data'->'contract'->>'id'), true);
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select public.service_contract_accept(current_setting('test.cf')::uuid);

set role postgres;
select set_config('test.mu', (select id::text from public.contract_milestones
  where contract_id = current_setting('test.cu')::uuid and milestone_number = 1), true);
select set_config('test.mf', (select id::text from public.contract_milestones
  where contract_id = current_setting('test.cf')::uuid and milestone_number = 1), true);

set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('test.ef',
  (select public.financial_escrow_create(current_setting('test.b')::uuid, current_setting('test.a')::uuid, 'NGN', 30000,
    '[{"milestone_number":1,"title":"Funded milestone work","amount":30000}]'::jsonb)->'data'->>'escrow_id'), true);
select public.financial_escrow_fund(current_setting('test.ef')::uuid);
select set_config('test.efm', (select id::text from public.financial_escrow_milestones
  where escrow_id = current_setting('test.ef')::uuid limit 1), true);
select public.service_contract_link_escrow(
  current_setting('test.cf')::uuid, current_setting('test.ef')::uuid,
  jsonb_build_array(jsonb_build_object(
    'contract_milestone_id', current_setting('test.mf'),
    'escrow_milestone_id', current_setting('test.efm'))));

-- Legacy escrow (no contract) for the escrow-only regression path.
select set_config('test.el',
  (select public.financial_escrow_create(current_setting('test.b')::uuid, current_setting('test.a')::uuid, 'NGN', 5000,
    '[{"milestone_number":1,"title":"Legacy escrow work","amount":5000}]'::jsonb)->'data'->>'escrow_id'), true);
select public.financial_escrow_fund(current_setting('test.el')::uuid);

-- ─── 1. anon cannot call the new RPCs (42501) ────────────────────────────────
set role anon;
select throws_ok($$ select public.service_dispute_file(null::uuid, null::text, null::text) $$,
  '42501', null, 'anon cannot call service_dispute_file');
select throws_ok($$ select public.service_dispute_get(null::uuid) $$,
  '42501', null, 'anon cannot call service_dispute_get');
select throws_ok($$ select public.service_dispute_list_for_contract(null::uuid, null::text) $$,
  '42501', null, 'anon cannot call service_dispute_list_for_contract');

-- ─── 2. Validation: authenticated ────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok($$ select public.service_dispute_file(null::uuid, 'fraud', 'Reasonable dispute reason text.') $$,
  'P0001', null, 'null contract rejected (PLT003)');
select throws_ok($$ select public.service_dispute_file(current_setting('test.cu')::uuid, 'bribery', 'Reasonable dispute reason text.') $$,
  'P0001', null, 'unknown dispute type rejected (PLT003)');
select throws_ok($$ select public.service_dispute_file(current_setting('test.cu')::uuid, 'fraud', 'short') $$,
  'P0001', null, 'short reason rejected (PLT003)');
select throws_ok($$ select public.service_dispute_file('99999999-9999-9999-9999-999999999999'::uuid, 'fraud', 'Reasonable dispute reason text.') $$,
  'P0001', null, 'unknown contract rejected (PLT004)');

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ select public.service_dispute_file(current_setting('test.cu')::uuid, 'fraud', 'Reasonable dispute reason text here.') $$,
  'P0001', null, 'stranger cannot file (PLT004, no oracle)');

-- ─── 3. Unfunded flow: B files on the unfunded contract ──────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.case1',
  (select public.service_dispute_file(current_setting('test.cu')::uuid, 'non_delivery',
    'The professional stopped responding after accepting the contract terms.')->'data'->>'id'), true);

select is(
  (select status from public.service_contracts where id = current_setting('test.cu')::uuid),
  'disputed', 'unfunded file freezes the contract');
select ok(
  (select (to_jsonb(d)->>'escrow_id') is null from public.dispute_cases d where d.id = current_setting('test.case1')::uuid),
  'unfunded case carries escrow_id NULL');
select is(
  (select metadata->>'pre_dispute_status' from public.dispute_cases where id = current_setting('test.case1')::uuid),
  'active', 'pre-dispute status captured in metadata');

select throws_ok($$ select public.service_contract_verify_milestone(current_setting('test.mu')::uuid) $$,
  'P0001', null, 'milestone verify blocked while disputed (PLT005)');
select throws_ok($$ select public.service_dispute_file(current_setting('test.cu')::uuid, 'fraud', 'A second dispute attempt with enough text.') $$,
  'P0001', null, 'duplicate active dispute rejected (PLT005)');

select lives_ok($$ select public.service_dispute_get(current_setting('test.case1')::uuid) $$,
  'service_dispute_get returns the unfunded case');
select is(
  (select public.service_dispute_get(current_setting('test.case1')::uuid)->'data'->'contract'->>'id'),
  current_setting('test.cu'), 'service_dispute_get joins the contract summary');

select lives_ok($$ select public.service_dispute_list_for_contract(current_setting('test.cu')::uuid, null::text) $$,
  'service_dispute_list_for_contract returns rows');
select is(
  (select jsonb_array_length(public.service_dispute_list_for_contract(current_setting('test.cu')::uuid, null::text)->'data'->'disputes')),
  1, 'exactly one dispute listed for the contract');
select throws_ok($$ select public.service_dispute_list_for_contract(current_setting('test.cu')::uuid, 'bogus') $$,
  'P0001', null, 'bad status filter rejected (PLT003)');

select lives_ok($$ select public.dispute_withdraw(current_setting('test.case1')::uuid) $$,
  'filer withdraws the unfunded dispute');
select is(
  (select status from public.service_contracts where id = current_setting('test.cu')::uuid),
  'active', 'withdraw restores the pre-dispute contract status');
select is(
  (select status from public.dispute_cases where id = current_setting('test.case1')::uuid),
  'withdrawn', 'case withdrawn');

-- Re-file on the restored contract, then resolve dismissed (unfunded path:
-- zero amounts, no fund movement, contract restored via trigger).
select set_config('test.case1b',
  (select public.service_dispute_file(current_setting('test.cu')::uuid, 'service_quality',
    'A second unfunded filing for resolve-path coverage purposes.')->'data'->>'id'), true);
set role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok($$ select public.dispute_resolve(current_setting('test.case1b')::uuid, 'dismissed', 'No funds were ever held; closing the case.') $$,
  'service_role resolves the unfunded case as dismissed');
select is(
  (select status from public.dispute_cases where id = current_setting('test.case1b')::uuid),
  'resolved', 'unfunded case resolved');
select is(
  (select status from public.service_contracts where id = current_setting('test.cu')::uuid),
  'active', 'resolve restores the unfunded contract');
select is(
  (select resolution_type from public.dispute_resolutions where case_id = current_setting('test.case1b')::uuid),
  'dismissed', 'unfunded resolution recorded as dismissed');

-- ─── 4. Funded flow: A files on the funded contract ──────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.case2',
  (select public.service_dispute_file(current_setting('test.cf')::uuid, 'milestone_disagreement',
    'The milestone was marked complete without delivering the agreed scope.')->'data'->>'id'), true);

select is(
  (select status from public.service_contracts where id = current_setting('test.cf')::uuid),
  'disputed', 'funded file freezes the contract');
select is(
  (select status from public.financial_escrow where id = current_setting('test.ef')::uuid),
  'disputed', 'funded file freezes the escrow');

select lives_ok($$ select public.service_contract_release_gate(current_setting('test.mf')::uuid) $$,
  'release gate evaluates while disputed');
select is(
  ((select public.service_contract_release_gate(current_setting('test.mf')::uuid)->'data'->>'eligible')::boolean),
  false, 'release gate refuses while disputed');

select lives_ok($$ select public.service_dispute_get(current_setting('test.case2')::uuid) $$,
  'service_dispute_get returns the funded case');

select throws_ok($$ select public.dispute_resolve(current_setting('test.case2')::uuid, 'dismissed', 'Nope, not authorized here.') $$,
  '42501', null, 'authenticated cannot call dispute_resolve');

set role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok($$ select public.dispute_resolve(current_setting('test.case2')::uuid, 'dismissed', 'Dispute dismissed as unfounded after review.') $$,
  'service_role resolves the funded case as dismissed');
select is(
  (select status from public.service_contracts where id = current_setting('test.cf')::uuid),
  'active', 'resolve restores the funded contract');
select is(
  (select status from public.financial_escrow where id = current_setting('test.ef')::uuid),
  'funded', 'dismissed releases the escrow hold with no movement');
select is(
  (select resolution_type from public.dispute_resolutions where case_id = current_setting('test.case2')::uuid),
  'dismissed', 'resolution recorded as dismissed');

-- ─── 5. Legacy regression + R4 legacy-linked freeze ─────────────────────────
-- c_legacy binds the legacy escrow to an engagement BEFORE the legacy filing,
-- proving a legacy escrow-only file still freezes the linked contract (R4).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.cl', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 5000, 'NGN',
  '[{"milestone_number":1,"title":"Legacy linked work","amount":5000}]'::jsonb
)->'data'->'contract'->>'id'), true);
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select public.service_contract_accept(current_setting('test.cl')::uuid);

set role postgres;
select set_config('test.ml', (select id::text from public.contract_milestones
  where contract_id = current_setting('test.cl')::uuid and milestone_number = 1), true);
select set_config('test.elm', (select id::text from public.financial_escrow_milestones
  where escrow_id = current_setting('test.el')::uuid limit 1), true);

set role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select is(
  (select public.service_contract_link_escrow(
    current_setting('test.cl')::uuid, current_setting('test.el')::uuid,
    jsonb_build_array(jsonb_build_object(
      'contract_milestone_id', current_setting('test.ml'),
      'escrow_milestone_id', current_setting('test.elm'))))->>'code'),
  'PLT000', 'legacy escrow linked to its engagement');

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.case3',
  (select public.dispute_file(current_setting('test.el')::uuid, 'service_quality',
    'Legacy escrow dispute path still functions correctly here.', null::text)->'data'->>'id'), true);
select ok(
  (select (to_jsonb(d)->>'contract_id') is null from public.dispute_cases d where d.id = current_setting('test.case3')::uuid),
  'legacy escrow-only case carries contract_id NULL');
select is(
  (select status from public.service_contracts where id = current_setting('test.cl')::uuid),
  'disputed', 'R4: legacy file freezes the linked contract');
select is(
  (select status from public.financial_escrow where id = current_setting('test.el')::uuid),
  'disputed', 'R4: legacy file freezes the linked escrow');
select lives_ok($$ select public.dispute_withdraw(current_setting('test.case3')::uuid) $$,
  'legacy case withdraws');
select is(
  (select status from public.service_contracts where id = current_setting('test.cl')::uuid),
  'active', 'R4: legacy withdraw restores the linked contract');

select is(
  (select public.service_dispute_get(current_setting('test.case2')::uuid)->>'code'),
  'PLT000', 'envelope carries PLT000 on success');

select finish();
rollback;
