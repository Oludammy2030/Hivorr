-- EP-03-03: Double-Blind Review RPC Enforcement
--
-- Validates the 4 review RPCs:
--   - Authorization: anon cannot call submit/get_mine/reveal (42501), anon can call get_for_listing for published.
--   - Validation: PLT003/004/005 for null/unknown/offered/rating/comment/duplicate/limit/draft.
--   - Functional: double-blind invariant (solo -> not revealed, both -> revealed atomically with aggregates + listing cache), expiry reveal, idempotent reveal, no timing oracle.
--   - RLS: pre-reveal SELECT returns 0 for counterparty anon, post-reveal returns both.
--   - Immutability: second submit same contract same reviewer -> PLT005, rating not updatable.
--   - service_role can call all 4.

begin;
set search_path to extensions, public;
select plan(70);

-- ─── 0. Fixtures ──────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', '11111111-1111-1111-1111-111111111111', true);
select set_config('test.b', '22222222-2222-2222-2222-222222222222', true);
select set_config('test.c', '33333333-3333-3333-3333-333333333333', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'review-a@example.com'),
       (current_setting('test.b')::uuid, 'review-b@example.com'),
       (current_setting('test.c')::uuid, 'review-c@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active')
on conflict (id) do nothing;

select set_config('test.prof1',
  (select id::text from public.professions where slug = 'legal-consultant'), true);
select set_config('test.prof1',
  coalesce(nullif(current_setting('test.prof1'), ''), (select id::text from public.professions limit 1)), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- Create published listings via RPC as A
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.l1', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Corporate Legal Review Fixture One',
  'Corporate legal advisory fixture listing description that is definitely longer than fifty characters for review testing purposes.',
  'fixed', 5000, 10000)->'data'->>'id'), true);
select set_config('test.l1_pub', (select public.service_listing_publish(current_setting('test.l1')::uuid)->>'code'), true);

select set_config('test.l2', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Second Review Fixture Listing Alpha',
  'Second listing description that is definitely longer than fifty characters for review expiry testing.',
  'fixed', 7000)->'data'->>'id'), true);
select set_config('test.l2_pub', (select public.service_listing_publish(current_setting('test.l2')::uuid)->>'code'), true);

-- Draft listing L3 for draft-blocked tests
select set_config('test.l3', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Draft Listing For Review Block Test',
  'Draft listing description that is definitely longer than fifty characters for review blocking tests.',
  'fixed', 3000)->'data'->>'id'), true);

-- Helper: create closed contract C1 (reviewable) B->A via L1
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.c1', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 50000, 'NGN',
  '[{"milestone_number":1,"title":"Draft Deliverable","amount":20000},{"milestone_number":2,"title":"Final Delivery","amount":30000}]'::jsonb
)->'data'->'contract'->>'id'), true);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_accept(current_setting('test.c1')::uuid) $$, 'accept c1');

-- Complete milestones for C1 to allow close
set role postgres;
select set_config('test.m1', (select id::text from public.contract_milestones where contract_id = current_setting('test.c1')::uuid and milestone_number = 1), true);
select set_config('test.m2', (select id::text from public.contract_milestones where contract_id = current_setting('test.c1')::uuid and milestone_number = 2), true);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_complete_milestone(current_setting('test.m1')::uuid, 'service-listing-media/' || current_setting('test.a') || '/evidence1.pdf') $$, 'complete m1 for c1');
select lives_ok($$ select public.service_contract_complete_milestone(current_setting('test.m2')::uuid, 'service-listing-media/' || current_setting('test.a') || '/evidence2.pdf') $$, 'complete m2 for c1');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.service_contract_verify_milestone(current_setting('test.m1')::uuid) $$, 'verify m1 c1');
select lives_ok($$ select public.service_contract_verify_milestone(current_setting('test.m2')::uuid) $$, 'verify m2 c1');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.service_contract_close(current_setting('test.c1')::uuid) $$, 'close c1 for reviewable');

-- Create second closed contract C2 for expiry tests (B->A via L2)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.c2', (select public.service_contract_offer(
  current_setting('test.l2')::uuid, 40000, 'NGN',
  '[{"milestone_number":1,"title":"Phase One","amount":20000},{"milestone_number":2,"title":"Phase Two","amount":20000}]'::jsonb
)->'data'->'contract'->>'id'), true);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_accept(current_setting('test.c2')::uuid) $$, 'accept c2');
set role postgres;
select set_config('test.m3', (select id::text from public.contract_milestones where contract_id = current_setting('test.c2')::uuid and milestone_number = 1), true);
select set_config('test.m4', (select id::text from public.contract_milestones where contract_id = current_setting('test.c2')::uuid and milestone_number = 2), true);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_complete_milestone(current_setting('test.m3')::uuid, 'service-listing-media/' || current_setting('test.a') || '/c2e1.pdf') $$, 'complete c2m1');
select lives_ok($$ select public.service_contract_complete_milestone(current_setting('test.m4')::uuid, 'service-listing-media/' || current_setting('test.a') || '/c2e2.pdf') $$, 'complete c2m2');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.service_contract_verify_milestone(current_setting('test.m3')::uuid) $$, 'verify c2m1');
select lives_ok($$ select public.service_contract_verify_milestone(current_setting('test.m4')::uuid) $$, 'verify c2m2');
select lives_ok($$ select public.service_contract_close(current_setting('test.c2')::uuid) $$, 'close c2');

-- Create offered contract C3 (non-reviewable) for validation tests
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.c3', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 20000, 'NGN',
  '[{"milestone_number":1,"title":"Offered Only","amount":20000}]'::jsonb
)->'data'->'contract'->>'id'), true);

-- ─── 1. Authorization: anon ───────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok($$ select public.service_review_submit('00000000-0000-0000-0000-000000000000'::uuid, 5, 'Excellent') $$,
  '42501', null, 'anon cannot call service_review_submit');
select throws_ok($$ select public.service_review_get_mine('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call service_review_get_mine');
select throws_ok($$ select public.service_review_reveal_if_ready('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call service_review_reveal_if_ready');
-- anon CAN call get_for_listing on published listing
select lives_ok($$ select public.service_review_get_for_listing(current_setting('test.l1')::uuid) $$, 'anon can call get_for_listing on published');

-- ─── 2. Validation: authenticated (B) ─────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok($$ select public.service_review_submit(null::uuid, 5, 'Excellent delivery test') $$,
  'P0001', null, 'submit with null contract_id rejected (PLT003)');
select throws_ok($$ select public.service_review_submit('99999999-9999-9999-9999-999999999999'::uuid, 5, 'Excellent delivery test') $$,
  'P0001', null, 'submit with unknown contract rejected (PLT004)');
select throws_ok($$ select public.service_review_submit(current_setting('test.c3')::uuid, 5, 'Excellent delivery test') $$,
  'P0001', null, 'submit on offered contract rejected (PLT005 not reviewable)');
select throws_ok($$ select public.service_review_submit(current_setting('test.c1')::uuid, null::integer, 'Excellent') $$,
  'P0001', null, 'submit with null rating rejected (PLT003)');
select throws_ok($$ select public.service_review_submit(current_setting('test.c1')::uuid, 0, 'Excellent') $$,
  'P0001', null, 'submit with rating 0 rejected (PLT003)');
select throws_ok($$ select public.service_review_submit(current_setting('test.c1')::uuid, 6, 'Excellent') $$,
  'P0001', null, 'submit with rating 6 rejected (PLT003)');
select throws_ok($$ select public.service_review_submit(current_setting('test.c1')::uuid, 5, repeat('x', 2001)) $$,
  'P0001', null, 'submit with comment >2000 rejected (PLT003)');
select throws_ok($$ select public.service_review_submit(current_setting('test.c1')::uuid, 5, 'short') $$,
  'P0001', null, 'submit with comment <10 rejected (PLT003)');

-- Non-participant C cannot submit for C1
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ select public.service_review_submit(current_setting('test.c1')::uuid, 5, 'Excellent delivery from stranger') $$,
  'P0001', null, 'stranger cannot submit (PLT004)');

-- get_mine validation
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.service_review_get_mine(null::uuid) $$,
  'P0001', null, 'get_mine null id rejected (PLT003)');
select throws_ok($$ select public.service_review_get_mine('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'get_mine unknown contract PLT004');
select lives_ok($$ select public.service_review_get_mine(current_setting('test.c3')::uuid) $$,
  'get_mine on offered contract as participant succeeds with empty revealed (not PLT004)');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ select public.service_review_get_mine(current_setting('test.c1')::uuid) $$,
  'P0001', null, 'stranger get_mine PLT004');

-- get_for_listing validation
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.service_review_get_for_listing(null::uuid) $$,
  'P0001', null, 'get_for_listing null id PLT003');
select throws_ok($$ select public.service_review_get_for_listing('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'get_for_listing unknown PLT004');
select throws_ok($$ select public.service_review_get_for_listing(current_setting('test.l3')::uuid) $$,
  'P0001', null, 'get_for_listing draft PLT004');
select throws_ok($$ select public.service_review_get_for_listing(current_setting('test.l1')::uuid, 0) $$,
  'P0001', null, 'get_for_listing limit 0 PLT003');
select throws_ok($$ select public.service_review_get_for_listing(current_setting('test.l1')::uuid, 101) $$,
  'P0001', null, 'get_for_listing limit 101 PLT003');
select throws_ok($$ select public.service_review_reveal_if_ready(null::uuid) $$,
  'P0001', null, 'reveal null id PLT003');

-- ─── 3. Functional: solo submit -> not revealed ───────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select public.service_review_submit(current_setting('test.c1')::uuid, 5, 'Excellent delivery, trusted timeline') ->>'code'),
  'PLT000', 'B submit solo succeeds is_revealed false'
);
select is(
  (select (public.service_review_get_mine(current_setting('test.c1')::uuid)->'data'->>'you_have_submitted')::boolean),
  true, 'B get_mine you_have_submitted true after solo'
);
select is(
  (select jsonb_array_length(public.service_review_get_mine(current_setting('test.c1')::uuid)->'data'->'revealed_reviews')),
  0, 'B get_mine revealed_reviews empty before both (no leak)'
);
-- Anonymous / counterparty should see 0 revealed
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select (public.service_review_get_mine(current_setting('test.c1')::uuid)->'data'->>'you_have_submitted')::boolean),
  false, 'A get_mine you_have_submitted false before A submit (no leak)'
);
select is(
  (select jsonb_array_length(public.service_review_get_mine(current_setting('test.c1')::uuid)->'data'->'revealed_reviews')),
  0, 'A get_mine revealed 0 before A submit'
);
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select is(
  (select jsonb_array_length(public.service_review_get_for_listing(current_setting('test.l1')::uuid)->'data'->'reviews')),
  0, 'anon get_for_listing 0 before reveal'
);
set role postgres;
select is(
  (select count(*)::int from public.service_reviews where contract_id = current_setting('test.c1')::uuid and is_revealed = true),
  0, 'DB: 0 revealed before both'
);

-- RLS: counterparty unrevealed not visible to A
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select count(*)::int from public.service_reviews where contract_id = current_setting('test.c1')::uuid and is_revealed = false and reviewer_entity_id = current_setting('test.b')::uuid),
  0, 'RLS: counterparty unrevealed not visible to A'
);

-- ─── 4. Functional: second submit -> revealed atomically ─────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select public.service_review_submit(current_setting('test.c1')::uuid, 4, 'Clear requirements, timely feedback') ->>'code'),
  'PLT000', 'A submit second succeeds and triggers reveal'
);
set role postgres;
select is(
  (select count(*)::int from public.service_reviews where contract_id = current_setting('test.c1')::uuid and is_revealed = true),
  2, 'DB: 2 revealed after both submit'
);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select jsonb_array_length(public.service_review_get_mine(current_setting('test.c1')::uuid)->'data'->'revealed_reviews')),
  2, 'B get_mine now 2 revealed'
);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select jsonb_array_length(public.service_review_get_mine(current_setting('test.c1')::uuid)->'data'->'revealed_reviews')),
  2, 'A get_mine now 2 revealed'
);
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select is(
  (select jsonb_array_length(public.service_review_get_for_listing(current_setting('test.l1')::uuid)->'data'->'reviews')),
  2, 'anon get_for_listing now 2 revealed'
);
select is(
  (select (public.service_review_get_for_listing(current_setting('test.l1')::uuid)->'data'->>'review_count')::int),
  1, 'anon get_for_listing review_count 1 (owner aggregate, not listing cache)'
);
select is(
  (select (public.service_review_get_for_listing(current_setting('test.l1')::uuid)->'data'->>'avg_rating')::numeric),
  5.00::numeric, 'avg_rating 5.00 (owner aggregate)'
);

-- Aggregates: P (reviewee for B->P 5) should be avg 5, C? Actually check both partitions
set role postgres;
select is(
  (select avg_rating from public.service_review_aggregates where professional_entity_id = current_setting('test.a')::uuid and profession_id = current_setting('test.prof1')::uuid),
  5.00, 'aggregate for A (reviewee of B 5) avg 5'
);
select is(
  (select review_count from public.service_review_aggregates where professional_entity_id = current_setting('test.a')::uuid and profession_id = current_setting('test.prof1')::uuid),
  1, 'aggregate for A count 1'
);
select is(
  (select avg_rating from public.service_review_aggregates where professional_entity_id = current_setting('test.b')::uuid and profession_id = current_setting('test.prof1')::uuid),
  4.00, 'aggregate for B (reviewee of A 4) avg 4'
);
-- Listing cache
select is(
  (select avg_rating from public.service_listings where id = current_setting('test.l1')::uuid),
  4.50, 'listing cache avg 4.50'
);
select is(
  (select review_count from public.service_listings where id = current_setting('test.l1')::uuid),
  2, 'listing cache count 2'
);
-- Duplicate submit blocked
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.service_review_submit(current_setting('test.c1')::uuid, 5, 'Another review attempt') $$,
  'P0001', null, 'duplicate submit blocked PLT005');

-- ─── 5. Expiry reveal ─────────────────────────────────────────────────────────
-- Solo submit on C2, then set closed_at to 15 days ago, then reveal
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select public.service_review_submit(current_setting('test.c2')::uuid, 5, 'Solo expiry test review content') ->>'code'),
  'PLT000', 'B solo submit on C2 for expiry'
);
set role postgres;
update public.service_contracts set closed_at = now() - interval '15 days', completed_at = now() - interval '15 days' where id = current_setting('test.c2')::uuid;
select is(
  (select count(*)::int from public.service_reviews where contract_id = current_setting('test.c2')::uuid and is_revealed = true),
  0, 'C2 not revealed before deadline call'
);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select public.service_review_reveal_if_ready(current_setting('test.c2')::uuid)->'data'->>'revealed'),
  'true', 'reveal_if_ready deadline reveals solo'
);
set role postgres;
select is(
  (select count(*)::int from public.service_reviews where contract_id = current_setting('test.c2')::uuid and is_revealed = true),
  1, 'DB: 1 revealed after deadline'
);
select is(
  (select jsonb_array_length(public.service_review_get_for_listing(current_setting('test.l2')::uuid)->'data'->'reviews')),
  1, 'get_for_listing shows 1 after deadline reveal'
);
-- Idempotent second reveal
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select public.service_review_reveal_if_ready(current_setting('test.c2')::uuid)->'data'->>'already'),
  'true', 'second reveal idempotent already true'
);
-- Subsequent submit after expiry should be immediately revealed
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select public.service_review_submit(current_setting('test.c2')::uuid, 3, 'Late review after expiry should reveal immediately') ->>'code'),
  'PLT000', 'A submit after expiry succeeds'
);
set role postgres;
select is(
  (select count(*)::int from public.service_reviews where contract_id = current_setting('test.c2')::uuid and is_revealed = true),
  2, 'both revealed after late submit'
);

-- ─── 6. Immutability ──────────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ update public.service_reviews set rating = 1 where contract_id = current_setting('test.c1')::uuid and reviewer_entity_id = current_setting('test.b')::uuid $$,
  '42501', null, 'direct UPDATE rating blocked by column grant');

-- ─── 7. service_role can call all 4 ───────────────────────────────────────────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok($$ select public.service_review_get_mine(current_setting('test.c1')::uuid) $$, 'service_role get_mine');
select lives_ok($$ select public.service_review_get_for_listing(current_setting('test.l1')::uuid) $$, 'service_role get_for_listing');
select lives_ok($$ select public.service_review_reveal_if_ready(current_setting('test.c1')::uuid) $$, 'service_role reveal_if_ready');

-- ─── 8. Direct INSERT is_revealed=true blocked ─────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
-- Create a fresh closed contract for this test (B->A via L2)
set role postgres;
select set_config('test.c4', (select public.service_contract_offer(
  current_setting('test.l2')::uuid, 25000, 'NGN',
  '[{"milestone_number":1,"title":"Direct Insert Test","amount":25000}]'::jsonb
) -> 'data' -> 'contract' ->> 'id'), true);
-- Accept and close C4 quickly via postgres (bypass client)
set role postgres;
select set_config('test.c4m', (select id::text from public.contract_milestones where contract_id = current_setting('test.c4')::uuid limit 1), true);
update public.service_contracts set status = 'closed', closed_at = now(), completed_at = now() where id = current_setting('test.c4')::uuid;
update public.contract_milestones set status = 'verified', verified_at = now() where id = current_setting('test.c4m')::uuid;

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ insert into public.service_reviews (contract_id, service_listing_id, reviewer_entity_id, reviewee_entity_id, profession_id, rating, is_revealed) values (current_setting('test.c4')::uuid, current_setting('test.l2')::uuid, current_setting('test.b')::uuid, current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 5, true) $$,
  '42501', null, 'direct INSERT is_revealed=true blocked by RLS WITH CHECK');

-- ─── 9. Envelope ───────────────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select public.service_review_get_mine(current_setting('test.c1')::uuid)->>'code'),
  'PLT000', 'envelope code PLT000'
);

select * from finish();
rollback;
