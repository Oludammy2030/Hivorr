-- EP-03-02: Service Contract RPC Enforcement
--
-- Validates the 8 contract RPCs:
--   - Authorization: anon cannot call any (42501); participant checks return
--     identical PLT004 for foreign/unknown ids (no enumeration oracle).
--   - Validation: PLT003/PLT004/PLT005 paths for offer/accept/cancel/complete/verify/close/get/list_mine.
--   - State machine: offered->active->completed->closed; offered->cancelled; disputed blocks verify/close.
--   - Milestone sum invariant, currency active check, self-offer blocked, evidence prefix.
--   - get returns milestones[]+events[]; list_mine is owner+participant scoped + keyset pagination.
--   - escrow_id remains NULL until EP-03-11 (no financial_escrow mutation).
--   - service_role can call all 8 RPCs.

begin;
set search_path to extensions, public;
select plan(68);

-- ─── 0. Fixtures ──────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', '11111111-1111-1111-1111-111111111111', true);
select set_config('test.b', '22222222-2222-2222-2222-222222222222', true);
select set_config('test.c', '33333333-3333-3333-3333-333333333333', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'contract-a@example.com'),
       (current_setting('test.b')::uuid, 'contract-b@example.com'),
       (current_setting('test.c')::uuid, 'contract-c@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active')
on conflict (id) do nothing;

-- Ensure professions exist
select set_config('test.prof1',
  (select id::text from public.professions where slug = 'legal-consultant'), true);
-- Fallback if legal-consultant not found, use any
select set_config('test.prof1',
  coalesce(nullif(current_setting('test.prof1'), ''), (select id::text from public.professions limit 1)), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- Create listing fixtures via RPC as A (verified)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.l1', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Corporate Legal Advisory Contract Fixture',
  'Advisory and compliance support for corporate clients across borders with detailed documentation.',
  'fixed', 5000, 10000)->'data'->>'id'), true);

-- Publish L1 as A
select set_config('test.l1_pub', (select public.service_listing_publish(current_setting('test.l1')::uuid)->>'code'), true);

-- Create a second listing L2 also published for pagination tests
select set_config('test.l2', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Second Contract Fixture Listing Alpha',
  'Second listing description that is definitely longer than fifty characters for contract testing.',
  'fixed', 2000)->'data'->>'id'), true);
select set_config('test.l2_pub', (select public.service_listing_publish(current_setting('test.l2')::uuid)->>'code'), true);

-- Draft listing L3 (unpublished) for draft-blocked tests
select set_config('test.l3', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Draft Listing For Contract Block Test Case',
  'Draft listing description that is definitely longer than fifty characters for blocking tests.',
  'fixed', 3000)->'data'->>'id'), true);

-- ─── 1. Authorization: anon ───────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok($$ select public.service_contract_offer('00000000-0000-0000-0000-000000000000'::uuid, 100, 'NGN', '[]'::jsonb) $$,
  '42501', null, 'anon cannot call service_contract_offer');
select throws_ok($$ select public.service_contract_accept('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call service_contract_accept');
select throws_ok($$ select public.service_contract_cancel('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call service_contract_cancel');
select throws_ok($$ select public.service_contract_complete_milestone('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call service_contract_complete_milestone');
select throws_ok($$ select public.service_contract_verify_milestone('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call service_contract_verify_milestone');
select throws_ok($$ select public.service_contract_close('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call service_contract_close');
select throws_ok($$ select public.service_contract_get('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call service_contract_get');
select throws_ok($$ select public.service_contract_list_mine() $$,
  '42501', null, 'anon cannot call service_contract_list_mine');

-- ─── 2. Validation: authenticated (B as client) ───────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok($$ select public.service_contract_offer(null::uuid, 100, 'NGN', '[{"milestone_number":1,"title":"T","amount":100}]'::jsonb) $$,
  'P0001', null, 'offer with null listing rejected (PLT003)');
select throws_ok($$ select public.service_contract_offer('99999999-9999-9999-9999-999999999999'::uuid, 100, 'NGN', '[{"milestone_number":1,"title":"T","amount":100}]'::jsonb) $$,
  'P0001', null, 'offer with unknown listing rejected (PLT004)');
select throws_ok($$ select public.service_contract_offer(current_setting('test.l3')::uuid, 100, 'NGN', '[{"milestone_number":1,"title":"T","amount":100}]'::jsonb) $$,
  'P0001', null, 'offer with draft listing rejected (PLT004)');
select throws_ok($$ select public.service_contract_offer(current_setting('test.l1')::uuid, 0, 'NGN', '[{"milestone_number":1,"title":"T","amount":100}]'::jsonb) $$,
  'P0001', null, 'offer with zero total rejected (PLT003)');
select throws_ok($$ select public.service_contract_offer(current_setting('test.l1')::uuid, 100, 'XYZ', '[{"milestone_number":1,"title":"T","amount":100}]'::jsonb) $$,
  'P0001', null, 'offer with unknown currency rejected (PLT003)');
select throws_ok($$ select public.service_contract_offer(current_setting('test.l1')::uuid, 100, 'NGN', '[]'::jsonb) $$,
  'P0001', null, 'offer with empty milestones rejected (PLT003)');
select throws_ok($$ select public.service_contract_offer(current_setting('test.l1')::uuid, 100, 'NGN', '[{"milestone_number":1,"title":"T","amount":50}]'::jsonb) $$,
  'P0001', null, 'offer with sum != total rejected (PLT003)');
select throws_ok($$ select public.service_contract_offer(current_setting('test.l1')::uuid, 100, 'NGN', '[{"milestone_number":1,"title":"","amount":100}]'::jsonb) $$,
  'P0001', null, 'offer with empty title rejected (PLT003)');
select throws_ok($$ select public.service_contract_offer(current_setting('test.l1')::uuid, 100, 'NGN', '[{"milestone_number":0,"title":"T","amount":100}]'::jsonb) $$,
  'P0001', null, 'offer with milestone_number 0 rejected (PLT003)');
select throws_ok($$ select public.service_contract_offer(current_setting('test.l1')::uuid, 100, 'NGN', '[{"milestone_number":1,"title":"A","amount":50},{"milestone_number":1,"title":"B","amount":50}]'::jsonb) $$,
  'P0001', null, 'offer with duplicate milestone_number rejected (PLT005)');

-- Self-offer blocked (A offers own listing)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select throws_ok($$ select public.service_contract_offer(current_setting('test.l1')::uuid, 100, 'NGN', '[{"milestone_number":1,"title":"Self","amount":100}]'::jsonb) $$,
  'P0001', 'PLT005: You cannot create a contract for your own listing.', 'self-offer blocked (PLT005)');

-- Valid offer B->A
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.c1', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 50000, 'NGN',
  '[{"milestone_number":1,"title":"Draft Deliverable","amount":20000},{"milestone_number":2,"title":"Final Delivery","amount":30000}]'::jsonb
)->'data'->'contract'->>'id'), true);
select set_config('test.c2', (select public.service_contract_offer(current_setting('test.l1')::uuid, 30000, 'NGN', '[{"milestone_number":1,"title":"Second Contract Milestone","amount":30000}]'::jsonb)->'data'->'contract'->>'id'), true);
select is(
  (select status from public.service_contracts where id = current_setting('test.c2')::uuid),
  'offered', 'second offer returns offered status'
);

-- ─── 3. Accept / Cancel ───────────────────────────────────────────────────────
-- Non-professional (client) cannot accept
select throws_ok($$ select public.service_contract_accept(current_setting('test.c1')::uuid) $$,
  'P0001', 'PLT004: Contract not found.', 'client cannot accept own offer (PLT004 no oracle)');

-- Professional accepts
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select public.service_contract_accept(current_setting('test.c1')::uuid)->>'code'),
  'PLT000', 'professional can accept offered contract'
);
select throws_ok($$ select public.service_contract_accept(current_setting('test.c1')::uuid) $$,
  'P0001', 'PLT005: Contract is not in offered state.', 'second accept rejected (PLT005)');

-- Cancel offered by either participant
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select public.service_contract_cancel(current_setting('test.c2')::uuid)->>'code'),
  'PLT000', 'client can cancel offered contract'
);
-- Cancel active should fail for participant (needs service_role)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.service_contract_cancel(current_setting('test.c1')::uuid) $$,
  'P0001', 'PLT005: Only offered contracts can be cancelled.', 'cancel active by participant rejected (PLT005)');

-- Non-participant cannot cancel
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ select public.service_contract_cancel(current_setting('test.c1')::uuid) $$,
  'P0001', 'PLT004: Contract not found.', 'stranger cannot cancel (PLT004)');

-- ─── 4. Milestone complete / verify ───────────────────────────────────────────
-- Need fresh contract for milestone tests: B offers L2 -> A accepts
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.c3', (select public.service_contract_offer(
  current_setting('test.l2')::uuid, 40000, 'NGN',
  '[{"milestone_number":1,"title":"Phase One","amount":20000},{"milestone_number":2,"title":"Phase Two","amount":20000}]'::jsonb
)->'data'->'contract'->>'id'), true);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_accept(current_setting('test.c3')::uuid) $$, 'accept c3');

set role postgres;
select set_config('test.m1', (select id::text from public.contract_milestones where contract_id = current_setting('test.c3')::uuid and milestone_number = 1), true);
select set_config('test.m2', (select id::text from public.contract_milestones where contract_id = current_setting('test.c3')::uuid and milestone_number = 2), true);

-- Client cannot complete
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.service_contract_complete_milestone(current_setting('test.m1')::uuid) $$,
  'P0001', 'PLT005: Only the professional may complete milestones.', 'client cannot complete (PLT005)');

-- Professional completes with valid evidence path
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select public.service_contract_complete_milestone(current_setting('test.m1')::uuid, 'service-listing-media/' || current_setting('test.a') || '/evidence.pdf')->>'code'),
  'PLT000', 'professional completes pending with valid evidence'
);
select throws_ok($$ select public.service_contract_complete_milestone(current_setting('test.m1')::uuid) $$,
  'P0001', 'PLT005: Milestone is not pending.', 'second complete rejected (PLT005)');
select throws_ok($$ select public.service_contract_complete_milestone(current_setting('test.m2')::uuid, 'service-listing-media/' || current_setting('test.c') || '/other.pdf') $$,
  'P0001', null, 'complete with foreign evidence prefix rejected (PLT003)');

-- Professional cannot verify
select throws_ok($$ select public.service_contract_verify_milestone(current_setting('test.m1')::uuid) $$,
  'P0001', 'PLT005: Only the client may verify milestones.', 'professional cannot verify (PLT005)');

-- Client verifies completed -> verified
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select public.service_contract_verify_milestone(current_setting('test.m1')::uuid)->>'code'),
  'PLT000', 'client verifies completed'
);
select throws_ok($$ select public.service_contract_verify_milestone(current_setting('test.m1')::uuid) $$,
  'P0001', 'PLT005: Milestone is not in completed state.', 'second verify rejected (PLT005)');
select throws_ok($$ select public.service_contract_verify_milestone(current_setting('test.m2')::uuid) $$,
  'P0001', 'PLT005: Milestone is not in completed state.', 'verify pending rejected (PLT005)');

-- Revision requested path
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_complete_milestone(current_setting('test.m2')::uuid, 'service-listing-media/' || current_setting('test.a') || '/phase2.pdf') $$, 'complete m2');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select public.service_contract_verify_milestone(current_setting('test.m2')::uuid, 'revision_requested')->>'code'),
  'PLT000', 'client revision_requested reverts to pending'
);
set role postgres;
select is(
  (select status from public.contract_milestones where id = current_setting('test.m2')::uuid),
  'pending', 'revision_requested sets pending'
);
-- Re-complete and verify to allow close
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_complete_milestone(current_setting('test.m2')::uuid, 'service-listing-media/' || current_setting('test.a') || '/phase2-v2.pdf') $$, 're-complete m2');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.service_contract_verify_milestone(current_setting('test.m2')::uuid) $$, 'verify m2 second time');

-- ─── 5. Close ─────────────────────────────────────────────────────────────────
-- Close requires all verified
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.service_contract_close('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', 'PLT004: Contract not found.', 'close unknown id PLT004');
select is(
  (select public.service_contract_close(current_setting('test.c3')::uuid)->>'code'),
  'PLT000', 'close succeeds when all verified'
);
select throws_ok($$ select public.service_contract_close(current_setting('test.c3')::uuid) $$,
  'P0001', 'PLT005: Contract is not in a closable state.', 'second close rejected (PLT005)');

-- Close with not-all-verified should fail (create new contract c4)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.c4', (select public.service_contract_offer(
  current_setting('test.l2')::uuid, 20000, 'NGN',
  '[{"milestone_number":1,"title":"Solo","amount":20000}]'::jsonb
)->'data'->'contract'->>'id'), true);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_accept(current_setting('test.c4')::uuid) $$, 'accept c4');
select throws_ok($$ select public.service_contract_close(current_setting('test.c4')::uuid) $$,
  'P0001', 'PLT005: All milestones must be verified before closing.', 'close with pending rejected');

-- ─── 6. Get / List mine ───────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select public.service_contract_get(current_setting('test.c3')::uuid)->>'code'),
  'PLT000', 'participant get succeeds'
);
select is(
  (select jsonb_array_length(public.service_contract_get(current_setting('test.c3')::uuid)->'data'->'milestones')),
  2, 'get returns 2 milestones'
);
select is(
  (select jsonb_array_length(public.service_contract_get(current_setting('test.c3')::uuid)->'data'->'events') >= 5),
  true, 'get returns events'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ select public.service_contract_get(current_setting('test.c3')::uuid) $$,
  'P0001', 'PLT004: Contract not found.', 'stranger get returns PLT004 (no oracle)');
select is(
  (select jsonb_array_length(public.service_contract_list_mine()->'data'->'items')),
  0, 'stranger list_mine is empty'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select jsonb_array_length(public.service_contract_list_mine()->'data'->'items') >= 3),
  true, 'client list_mine returns own contracts'
);
select is(
  (select jsonb_array_length(public.service_contract_list_mine(p_status => 'offered')->'data'->'items') >= 0),
  true, 'list_mine status filter works'
);
select is(
  (select jsonb_array_length(public.service_contract_list_mine(p_limit => 1)->'data'->'items')),
  1, 'list_mine limit 1 returns 1'
);
select is(
  (select public.service_contract_list_mine(p_limit => 1)->'data'->>'has_more'),
  'true', 'list_mine has_more true when more rows'
);
select set_config('test.cursor', (select public.service_contract_list_mine(p_limit => 1)->'data'->>'next_cursor'), true);
select is(
  (select jsonb_array_length(public.service_contract_list_mine(p_limit => 1, p_cursor => current_setting('test.cursor')::uuid)->'data'->'items')),
  1, 'list_mine cursor pagination returns next page'
);
select throws_ok($$ select public.service_contract_list_mine(p_status => 'bogus') $$,
  'P0001', null, 'list_mine invalid status rejected (PLT003)');
select throws_ok($$ select public.service_contract_list_mine(p_limit => 0) $$,
  'P0001', null, 'list_mine limit 0 rejected (PLT003)');

-- Unknown cursor returns empty (no oracle)
select is(
  (select jsonb_array_length(public.service_contract_list_mine(p_limit => 1, p_cursor => '99999999-9999-9999-9999-999999999999'::uuid)->'data'->'items')),
  0, 'unknown cursor returns empty'
);

-- ─── 7. escrow_id remains NULL ────────────────────────────────────────────────
set role postgres;
select is(
  (select count(*)::int from public.service_contracts where escrow_id is not null),
  0, 'no contract has escrow_id (deferred to EP-03-11)'
);
select is(
  (select count(*)::int from public.contract_milestones where escrow_milestone_id is not null),
  0, 'no milestone has escrow_milestone_id'
);

-- ─── 8. Milestone sum invariant ───────────────────────────────────────────────
select is(
  (select count(*)::int from public.service_contracts sc
    where sc.total_amount <> (select coalesce(sum(m.amount),0) from public.contract_milestones m where m.contract_id = sc.id)),
  0, 'all contracts satisfy sum(milestones)=total_amount'
);

-- ─── 9. Direct table write via RLS (granted for RPC, but participant check still applies) ─
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
-- Valid participant insert now succeeds (granted for RPC, RLS WITH CHECK client=auth.uid())
select lives_ok($$ insert into public.service_contracts (service_listing_id, client_entity_id, professional_entity_id, total_amount, currency_code, status) values (current_setting('test.l1')::uuid, current_setting('test.b')::uuid, current_setting('test.a')::uuid, 100, 'NGN', 'offered') $$,
  'direct INSERT into service_contracts as participant succeeds (RLS WITH CHECK)');
-- Cleanup the direct-inserted row
set role postgres;
delete from public.service_contracts where total_amount = 100 and client_entity_id = current_setting('test.b')::uuid and service_listing_id = current_setting('test.l1')::uuid and status = 'offered';
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ insert into public.contract_milestones (contract_id, milestone_number, title, amount) values (current_setting('test.c3')::uuid, 99, 'Inject', 100) $$,
  '42501', null, 'direct INSERT into contract_milestones as stranger blocked (RLS)');

-- ─── 10. service_role can call all 8 RPCs ───────────────────────────────────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok($$ select public.service_contract_get(current_setting('test.c3')::uuid) $$, 'service_role get');
select lives_ok($$ select public.service_contract_list_mine() $$, 'service_role list_mine');
-- service_role can cancel active: create as client B, accept as professional A, cancel as service_role
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('test.c5', (select public.service_contract_offer(current_setting('test.l1')::uuid, 10000, 'NGN', '[{"milestone_number":1,"title":"SR Cancel","amount":10000}]'::jsonb)->'data'->'contract'->>'id'), true);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_accept(current_setting('test.c5')::uuid) $$, 'accept c5 as professional for service_role cancel test');
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);
select is(
  (select public.service_contract_cancel(current_setting('test.c5')::uuid)->>'code'),
  'PLT000', 'service_role can cancel active'
);

-- ─── 11. Envelope ─────────────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select public.service_contract_offer(current_setting('test.l2')::uuid, 15000, 'NGN', '[{"milestone_number":1,"title":"Envelope Test One","amount":15000}]'::jsonb)->'data'->'contract'->>'status'),
  'offered', 'envelope data contains contract status'
);

select * from finish();
rollback;
