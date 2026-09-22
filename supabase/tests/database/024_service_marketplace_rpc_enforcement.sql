-- EP-03-01: Service Marketplace RPC Enforcement
--
-- Validates the 7 marketplace RPCs (EP-03-01 Plan §14.2 + the approved D5-guard
-- deviation):
--   - Authorization: anon cannot call the 6 gated RPCs (42501); anon CAN call
--     service_listing_get on published listings; anon/anon-visibility returns
--     an identical PLT004 for drafts and unknown ids (no enumeration oracle).
--   - Validation: PLT003/PLT004/PLT005 paths for create/update/get/list_mine.
--   - Trade gate: unverified entities cannot publish (PLT005); verified
--     publishers get status/published_at/is_trade_verified_cache atomically.
--   - State machine: published accepts description-only updates; archived/
--     reported immutable; paused -> published re-publish; service_role-only
--     'reported' moderation.
--   - FTS: search_vector recomputed by trigger (title change + profession
--     change, including industry_id parity).
--   - Favorites: idempotent toggle, no self-favorite, published-only targets.
--   - list_mine: owner scope + keyset pagination (has_more/next_cursor).
--   - D5 guard (approved deviation): direct authenticated writes to publish
--     state raise PLT002; view_count/avg_rating/review_count/search_vector
--     remain 42501 (zero column grants).
--   - service_role can call all 7 RPCs (claims required for auth.uid()).
--   - Envelope {success, code, message, data} with PLT000 on success.

begin;
set search_path to extensions, public;
select plan(116);

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

select set_config('test.prof1',
  (select id::text from public.professions where slug = 'legal-consultant'), true);
select set_config('test.prof2',
  (select id::text from public.professions where slug = 'software-engineer'), true);
select set_config('test.prof3',
  (select id::text from public.professions where slug = 'notary-public'), true);

insert into public.professions (industry_id, slug, name, is_active)
select i.id, 'test-marketplace-inactive-prof', 'Test Marketplace Inactive Prof', false
  from public.industries i
 where i.slug = 'legal'
on conflict (slug) do nothing;

select set_config('test.inactive_prof',
  (select id::text from public.professions where slug = 'test-marketplace-inactive-prof'), true);

insert into public.financial_supported_currencies (currency_code, name, decimal_places, is_active)
values ('ZZZ', 'Test Zulu', 2, false)
on conflict (currency_code) do update set is_active = false;

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved'),
       (current_setting('test.b')::uuid, current_setting('test.prof1')::uuid, 'unverified'),
       (current_setting('test.a')::uuid, current_setting('test.prof2')::uuid, 'unverified')
on conflict (entity_id, profession_id) do nothing;

-- Fixture listings via the RPCs (A is verified on prof1; B is not).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.l1', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Corporate Legal Advisory',
  'Advisory and compliance support for corporate clients across borders.',
  'fixed', 1000, 5000)->'data'->>'id'), true);

select set_config('test.l2', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Tax Compliance Support',
  'End-to-end tax filing and compliance support for growing businesses.',
  'hourly', 50, null, 'USD', 'published')->'data'->>'id'), true);

select set_config('test.l4', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Corporate Legal Drafting',
  'Drafting of corporate agreements, contracts and legal documentation.',
  'custom')->'data'->>'id'), true);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.l3', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Business Contract Review',
  'Review of business contracts with detailed risk notes and recommendations.',
  'fixed', 200)->'data'->>'id'), true);

-- ─── 1. Authorization: anon ───────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok($$ select public.service_listing_create(null::uuid, null::text, null::text, null::text) $$,
  '42501', null, 'anon cannot call service_listing_create');
select throws_ok($$ select public.service_listing_update(null::uuid) $$,
  '42501', null, 'anon cannot call service_listing_update');
select throws_ok($$ select public.service_listing_publish(null::uuid) $$,
  '42501', null, 'anon cannot call service_listing_publish');
select throws_ok($$ select public.service_listing_unpublish(null::uuid) $$,
  '42501', null, 'anon cannot call service_listing_unpublish');
select throws_ok($$ select public.service_listing_list_mine() $$,
  '42501', null, 'anon cannot call service_listing_list_mine');
select throws_ok($$ select public.service_favorite_toggle(null::uuid) $$,
  '42501', null, 'anon cannot call service_favorite_toggle');

select is(
  (select public.service_listing_get(current_setting('test.l2')::uuid)->>'code'),
  'PLT000',
  'anon can call service_listing_get on a published listing'
);
select is(
  (select count(*)::int from public.service_listings where status = 'published'),
  1,
  'anon direct SELECT sees exactly the 1 published listing'
);
select is(
  (select count(*)::int from public.service_listings where status <> 'published'),
  0,
  'anon direct SELECT sees zero draft/paused listings (RLS public branch)'
);
select throws_ok($$ select public.service_listing_get(current_setting('test.l1')::uuid) $$,
  'P0001', 'PLT004: Listing not found.',
  'anon get on a draft returns PLT004');
select throws_ok($$ select public.service_listing_get('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', 'PLT004: Listing not found.',
  'anon get on an unknown id returns the identical PLT004 (no enumeration oracle)');

-- ─── 2. Validation: authenticated (entity A) ──────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok($$ select public.service_listing_create(
  null::uuid, 'Valid Title Length', 'A description that is definitely longer than fifty characters.', 'fixed', 100) $$,
  'P0001', null, 'create with null profession id rejected (PLT003)');
select throws_ok($$ select public.service_listing_create(
  '99999999-9999-9999-9999-999999999999'::uuid, 'Valid Title Length', 'A description that is definitely longer than fifty characters.', 'fixed', 100) $$,
  'P0001', null, 'create with unknown profession rejected (PLT004)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.inactive_prof')::uuid, 'Valid Title Length', 'A description that is definitely longer than fifty characters.', 'fixed', 100) $$,
  'P0001', null, 'create with inactive profession rejected (PLT004)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Short', 'A description that is definitely longer than fifty characters.', 'fixed', 100) $$,
  'P0001', null, 'create with short title rejected (PLT003)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Valid Title Length', 'Too short.', 'fixed', 100) $$,
  'P0001', null, 'create with short description rejected (PLT003)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Valid Title Length', 'A description that is definitely longer than fifty characters.', 'fixed', 500, 100) $$,
  'P0001', null, 'create with price_min > price_max rejected (PLT003)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Valid Title Length', 'A description that is definitely longer than fifty characters.', 'fixed') $$,
  'P0001', null, 'create with fixed pricing but no price_min rejected (PLT003)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Valid Title Length', 'A description that is definitely longer than fifty characters.', 'fixed', 100, null, 'XYZ') $$,
  'P0001', null, 'create with unknown currency rejected (PLT003)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Valid Title Length', 'A description that is definitely longer than fifty characters.', 'fixed', 100, null, 'ZZZ') $$,
  'P0001', null, 'create with inactive currency rejected (PLT003)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Valid Title Length', 'A description that is definitely longer than fifty characters.', 'fixed', 100, null, 'NGN', 'archived') $$,
  'P0001', null, 'create with invalid initial status rejected (PLT003)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, '----------', 'A description that is definitely longer than fifty characters.', 'fixed', 100) $$,
  'P0001', null, 'create with symbol-only title (empty slug) rejected (PLT003)');
select throws_ok($$ select public.service_listing_get(null::uuid) $$,
  'P0001', null, 'get with null id rejected (PLT003)');
select throws_ok($$ select public.service_listing_update(current_setting('test.l4')::uuid) $$,
  'P0001', null, 'update with no fields rejected (PLT003)');
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l4')::uuid, p_pricing_type => 'weird') $$,
  'P0001', null, 'update with invalid pricing type rejected (PLT003)');
select throws_ok($$ select public.service_listing_list_mine(p_status => 'bogus') $$,
  'P0001', null, 'list_mine with invalid status filter rejected (PLT003)');
select throws_ok($$ select public.service_listing_list_mine(p_limit => 0) $$,
  'P0001', null, 'list_mine with limit 0 rejected (PLT003)');
select throws_ok($$ select public.service_listing_list_mine(p_limit => 101) $$,
  'P0001', null, 'list_mine with limit 101 rejected (PLT003)');

-- ─── 3. Trade gate + ownership ────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select throws_ok($$ select public.service_listing_publish(current_setting('test.l3')::uuid) $$,
  'P0001', 'PLT005: Trade verification required. Complete verification before publishing.',
  'unverified entity cannot publish (trade gate)');
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Business Contract Review Live',
  'A description that is definitely longer than fifty characters.', 'fixed', 200, null, 'NGN', 'published') $$,
  'P0001', 'PLT005: Trade verification required. Complete verification before publishing.',
  'unverified entity cannot create a published listing');

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select public.service_listing_publish(current_setting('test.l1')::uuid)->>'code'),
  'PLT000',
  'verified entity can publish a draft'
);

set role postgres;
select is(
  (select status from public.service_listings where id = current_setting('test.l1')::uuid),
  'published',
  'publish sets status=published'
);
select ok(
  (select published_at is not null from public.service_listings where id = current_setting('test.l1')::uuid),
  'publish sets published_at'
);
select is(
  (select is_trade_verified_cache from public.service_listings where id = current_setting('test.l1')::uuid),
  true,
  'publish flips is_trade_verified_cache=true atomically'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.service_listing_publish(current_setting('test.l1')::uuid) $$,
  'P0001', 'PLT005: Listing is not in a publishable state.',
  'publishing an already published listing rejected (PLT005)');

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l1')::uuid, p_description => 'A different description that is definitely longer than fifty chars.') $$,
  'P0001', 'PLT004: Listing not found.',
  'non-owner update rejected with PLT004 (no oracle)');
select throws_ok($$ select public.service_listing_publish(current_setting('test.l1')::uuid) $$,
  'P0001', 'PLT004: Listing not found.',
  'non-owner publish rejected with PLT004 (no oracle)');
select is(
  (select public.service_listing_get(current_setting('test.l3')::uuid)->>'code'),
  'PLT000',
  'owner can read their own draft via get'
);
select is(
  (select public.service_listing_get(current_setting('test.l1')::uuid)->>'code'),
  'PLT000',
  'authenticated non-owner can read a published listing via get'
);
select throws_ok($$ select public.service_listing_get(current_setting('test.l4')::uuid) $$,
  'P0001', 'PLT004: Listing not found.',
  'non-owner get on a foreign draft returns PLT004');

-- ─── 4. FTS + media ───────────────────────────────────────────────────────────
set role postgres;
select is(
  (select search_vector @@ to_tsquery('english', 'legal & drafting')
     from public.service_listings where id = current_setting('test.l4')::uuid),
  true,
  'search_vector matches title terms after create (trigger-generated)'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok($$ select public.service_listing_update(
  current_setting('test.l4')::uuid, p_title => 'Corporate Legal Drafting Services') $$,
  'owner title update on draft succeeds');

set role postgres;
select is(
  (select search_vector @@ to_tsquery('english', 'corporate & services')
     from public.service_listings where id = current_setting('test.l4')::uuid),
  true,
  'search_vector recomputed after title change'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select lives_ok($$ select public.service_listing_update(
  current_setting('test.l4')::uuid, p_profession_id => current_setting('test.prof2')::uuid) $$,
  'owner can move a draft to another bound profession');

set role postgres;
select is(
  (select l.industry_id = p.industry_id
     from public.service_listings l
     join public.professions p on p.slug = 'software-engineer'
    where l.id = current_setting('test.l4')::uuid),
  true,
  'industry_id re-derived from the new profession (parity trigger)'
);
select is(
  (select search_vector @@ to_tsquery('english', 'engineer')
     from public.service_listings where id = current_setting('test.l4')::uuid),
  true,
  'search_vector includes the new profession name'
);
select is(
  (select search_vector @@ to_tsquery('english', 'consultant')
     from public.service_listings where id = current_setting('test.l4')::uuid),
  false,
  'old profession name dropped from search_vector after rebind'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Corporate Legal Advisory',
  'A description that is definitely longer than fifty characters.', 'fixed', 100) $$,
  'P0001', 'PLT005: A listing with this title already exists.',
  'duplicate title (slug) per entity rejected (PLT005)');

set role postgres;
select throws_ok($$ insert into public.service_listing_media (
    listing_id, entity_id, storage_path, mime_type
  ) values (
    current_setting('test.l1')::uuid, current_setting('test.a')::uuid,
    'service-listing-media/99999999-9999-9999-9999-999999999999/x.jpg', 'image/jpeg'
  ) $$,
  '23514', null, 'media storage_path owner-prefix CHECK rejects foreign entity prefix');

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ insert into public.service_listing_media (
    listing_id, entity_id, storage_path, mime_type
  ) values (
    current_setting('test.l3')::uuid, current_setting('test.a')::uuid,
    'service-listing-media/' || current_setting('test.a') || '/x.jpg', 'image/jpeg'
  ) $$,
  '42501', null, 'media INSERT on a listing owned by another entity rejected (RLS)');
select lives_ok($$ insert into public.service_listing_media (
    listing_id, entity_id, storage_path, mime_type
  ) values (
    current_setting('test.l1')::uuid, current_setting('test.a')::uuid,
    'service-listing-media/' || current_setting('test.a') || '/cover.jpg', 'image/jpeg'
  ) $$,
  'media INSERT on own listing succeeds');

set role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select is(
  (select jsonb_array_length(public.service_listing_get(current_setting('test.l1')::uuid)->'data'->'media')),
  1,
  'service_listing_get assembles the media array for anon'
);

-- ─── 5. Update state rules (owner A) ──────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok($$ select public.service_listing_update(
  current_setting('test.l2')::uuid, p_title => 'Tax Compliance Support Renamed') $$,
  'P0001', 'PLT005: Unpublish the listing before changing pricing or taxonomy.',
  'title change on a published listing rejected (PLT005)');
select is(
  (select public.service_listing_update(
    current_setting('test.l2')::uuid,
    p_description => 'Updated end-to-end tax filing and compliance support description.')->>'code'),
  'PLT000',
  'description change on a published listing succeeds'
);
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l2')::uuid, p_price_min => 999) $$,
  'P0001', 'PLT005: Unpublish the listing before changing pricing or taxonomy.',
  'price change on a published listing rejected (PLT005)');
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l4')::uuid, p_price_min => 500, p_price_max => 100) $$,
  'P0001', null, 'update with price_min > price_max rejected (PLT003)');
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l4')::uuid, p_profession_id => '99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'update to unknown profession rejected (PLT004)');
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l4')::uuid, p_profession_id => current_setting('test.inactive_prof')::uuid) $$,
  'P0001', null, 'update to inactive profession rejected (PLT004)');
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l4')::uuid, p_profession_id => current_setting('test.prof3')::uuid) $$,
  'P0001', 'PLT005: Bind this profession to your profile before creating a listing.',
  'update to an unbound profession rejected (PLT005)');
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l4')::uuid, p_currency_code => 'XYZ') $$,
  'P0001', null, 'update to unknown currency rejected (PLT003)');
select throws_ok($$ select public.service_listing_update(
  '99999999-9999-9999-9999-999999999999'::uuid, p_title => 'Valid Title Length') $$,
  'P0001', null, 'update of an unknown listing rejected (PLT004)');

-- ─── 6. Unpublish state machine ───────────────────────────────────────────────
select is(
  (select public.service_listing_unpublish(current_setting('test.l1')::uuid)->>'code'),
  'PLT000',
  'owner can unpublish a published listing'
);

set role postgres;
select is(
  (select status from public.service_listings where id = current_setting('test.l1')::uuid),
  'paused',
  'unpublish sets status=paused'
);
select ok(
  (select published_at is null from public.service_listings where id = current_setting('test.l1')::uuid),
  'unpublish clears published_at'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.service_listing_unpublish(current_setting('test.l1')::uuid) $$,
  'P0001', 'PLT005: Only published listings can be unpublished.',
  'unpublishing a paused listing rejected (PLT005)');
select throws_ok($$ select public.service_listing_unpublish(
  current_setting('test.l2')::uuid, p_reason => 'reported') $$,
  'P0001', 'PLT002: Only the service role can report listings.',
  'authenticated caller cannot set reported (PLT002)');
select throws_ok($$ select public.service_listing_unpublish('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'unpublish of an unknown listing rejected (PLT004)');

set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);
select is(
  (select public.service_listing_unpublish(
    current_setting('test.l2')::uuid, p_reason => 'reported')->>'code'),
  'PLT000',
  'service_role can report (moderate) a published listing'
);

set role postgres;
select is(
  (select status from public.service_listings where id = current_setting('test.l2')::uuid),
  'reported',
  'reported moderation sets status=reported'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.service_listing_update(
  current_setting('test.l2')::uuid,
  p_description => 'A description that is definitely longer than fifty characters.') $$,
  'P0001', 'PLT005: Archived or reported listings cannot be updated.',
  'reported listing is immutable for the owner (PLT005)');
select is(
  (select public.service_listing_publish(current_setting('test.l1')::uuid)->>'code'),
  'PLT000',
  'paused listing can be re-published'
);

-- ─── 7. Favorites ─────────────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select public.service_favorite_toggle(current_setting('test.l1')::uuid)->'data'->>'favorited'),
  'true',
  'fan can favorite a published listing'
);
set role postgres;
select is(
  (select count(*)::int from public.service_favorites
    where entity_id = current_setting('test.b')::uuid
      and listing_id = current_setting('test.l1')::uuid),
  1,
  'favorite row inserted'
);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select public.service_favorite_toggle(current_setting('test.l1')::uuid)->'data'->>'favorited'),
  'false',
  'second toggle removes the favorite (idempotent)'
);
set role postgres;
select is(
  (select count(*)::int from public.service_favorites
    where entity_id = current_setting('test.b')::uuid
      and listing_id = current_setting('test.l1')::uuid),
  0,
  'favorite row deleted'
);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.service_favorite_toggle(current_setting('test.l1')::uuid) $$,
  'P0001', 'PLT005: You cannot favorite your own listing.',
  'self-favorite rejected (PLT005)');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select throws_ok($$ select public.service_favorite_toggle(current_setting('test.l3')::uuid) $$,
  'P0001', 'PLT005: Only published listings can be favorited.',
  'favoriting own draft rejected (PLT005)');
select throws_ok($$ select public.service_favorite_toggle('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'favoriting an unknown listing rejected (PLT004)');
select throws_ok($$ select public.service_favorite_toggle(current_setting('test.l4')::uuid) $$,
  'P0001', 'PLT004: Listing not found.',
  'favoriting a foreign draft returns PLT004 (invisible)');

-- ─── 8. list_mine: owner scope + keyset pagination ────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is((select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Employment Agreement Preparation',
  'Preparation of employment agreements and contractor documentation.', 'fixed', 300)->>'code'),
  'PLT000', 'fixture listing l5 created');
select is((select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Intellectual Property Audit Support',
  'IP portfolio audit support with detailed filing recommendations included.', 'fixed', 400)->>'code'),
  'PLT000', 'fixture listing l6 created');
select is((select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Regulatory Filing Assistance',
  'Assistance with regulatory filings and statutory compliance deadlines.', 'fixed', 250)->>'code'),
  'PLT000', 'fixture listing l7 created');

select is(
  (select jsonb_array_length(public.service_listing_list_mine()->'data'->'items')),
  6,
  'list_mine returns all 6 of A own listings (any status)'
);
select is(
  (select jsonb_array_length(
    public.service_listing_list_mine(p_status => 'published')->'data'->'items')),
  1,
  'list_mine status filter returns only published'
);
select is(
  (select jsonb_array_length(
    public.service_listing_list_mine(p_status => 'reported')->'data'->'items')),
  1,
  'list_mine status filter returns only reported'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select jsonb_array_length(public.service_listing_list_mine()->'data'->'items')),
  1,
  'list_mine is owner-scoped (each entity sees only its own listings)'
);

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select jsonb_array_length(
    public.service_listing_list_mine(p_limit => 2)->'data'->'items')),
  2,
  'page 1 returns exactly the limit'
);
select is(
  (select public.service_listing_list_mine(p_limit => 2)->'data'->>'has_more'),
  'true',
  'page 1 reports has_more'
);
select set_config('test.cursor',
  (select public.service_listing_list_mine(p_limit => 2)->'data'->>'next_cursor'), true);
select is(
  (select jsonb_array_length(
    public.service_listing_list_mine(p_limit => 2, p_cursor => current_setting('test.cursor')::uuid)->'data'->'items')),
  2,
  'page 2 (cursor) returns exactly the limit'
);
select is(
  (select public.service_listing_list_mine(
    p_limit => 2, p_cursor => current_setting('test.cursor')::uuid)->'data'->>'has_more'),
  'true',
  'page 2 reports has_more'
);
select set_config('test.cursor2',
  (select public.service_listing_list_mine(
    p_limit => 2, p_cursor => current_setting('test.cursor')::uuid)->'data'->>'next_cursor'), true);
select is(
  (select jsonb_array_length(
    public.service_listing_list_mine(p_limit => 2, p_cursor => current_setting('test.cursor2')::uuid)->'data'->'items')),
  2,
  'page 3 (cursor) returns the remaining rows'
);
select is(
  (select public.service_listing_list_mine(
    p_limit => 2, p_cursor => current_setting('test.cursor2')::uuid)->'data'->>'has_more'),
  'false',
  'page 3 reports has_more=false'
);
select is(
  (select public.service_listing_list_mine(
    p_limit => 2, p_cursor => current_setting('test.cursor2')::uuid)->'data'->>'next_cursor'),
  null,
  'page 3 returns next_cursor=null'
);
select is(
  (select jsonb_array_length(
    public.service_listing_list_mine(
      p_limit => 2, p_cursor => '99999999-9999-9999-9999-999999999999'::uuid)->'data'->'items')),
  0,
  'unknown cursor returns an empty page (no oracle)'
);

-- ─── 9. D5 guard: publish state is RPC-only (approved deviation) ──────────────
select set_config('platform.rpc_invocation', '', true);

select throws_ok($$ update public.service_listings
    set status = 'published'
   where id = current_setting('test.l4')::uuid
     and entity_id = current_setting('test.a')::uuid $$,
  'P0001', 'PLT002: Listing publish state may only be changed through the service listing RPCs.',
  'D5 guard blocks direct status=published UPDATE');
select throws_ok($$ update public.service_listings
    set is_trade_verified_cache = false
   where id = current_setting('test.l4')::uuid
     and entity_id = current_setting('test.a')::uuid $$,
  'P0001', 'PLT002: Listing publish state may only be changed through the service listing RPCs.',
  'D5 guard blocks direct is_trade_verified_cache UPDATE');
select throws_ok($$ update public.service_listings
    set published_at = now()
   where id = current_setting('test.l4')::uuid
     and entity_id = current_setting('test.a')::uuid $$,
  'P0001', 'PLT002: Listing publish state may only be changed through the service listing RPCs.',
  'D5 guard blocks direct published_at UPDATE');
select throws_ok($$ insert into public.service_listings (
    entity_id, profession_id, slug, title, description, pricing_type, price_min, status
  ) values (
    current_setting('test.a')::uuid, current_setting('test.prof1')::uuid,
    'guard-direct-insert', 'Guard Direct Insert Probe',
    'A description that is definitely longer than fifty characters.',
    'fixed', 10, 'published'
  ) $$,
  'P0001', 'PLT002: Listing publish state may only be changed through the service listing RPCs.',
  'D5 guard blocks direct INSERT with status=published');
select throws_ok($$ update public.service_listings
    set view_count = 5
   where id = current_setting('test.l4')::uuid
     and entity_id = current_setting('test.a')::uuid $$,
  '42501', null, 'view_count has no authenticated UPDATE grant (42501)');
select throws_ok($$ update public.service_listings
    set avg_rating = 4
   where id = current_setting('test.l4')::uuid
     and entity_id = current_setting('test.a')::uuid $$,
  '42501', null, 'avg_rating has no authenticated UPDATE grant (42501)');
select throws_ok($$ update public.service_listings
    set review_count = 9
   where id = current_setting('test.l4')::uuid
     and entity_id = current_setting('test.a')::uuid $$,
  '42501', null, 'review_count has no authenticated UPDATE grant (42501)');
select throws_ok($$ update public.service_listings
    set search_vector = to_tsvector('english', 'injected')
   where id = current_setting('test.l4')::uuid
     and entity_id = current_setting('test.a')::uuid $$,
  '42501', null, 'search_vector has no authenticated UPDATE grant (42501)');
select throws_ok($$ delete from public.service_listings
   where id = current_setting('test.l4')::uuid $$,
  '42501', null, 'authenticated has no DELETE grant on service_listings (42501)');
select lives_ok($$ update public.service_listings
    set title = 'Corporate Legal Drafting Services Extended'
   where id = current_setting('test.l4')::uuid
     and entity_id = current_setting('test.a')::uuid $$,
  'direct owner UPDATE of mutable fields (title) remains allowed');
select lives_ok($$ insert into public.service_listings (
    entity_id, profession_id, slug, title, description, pricing_type, price_min
  ) values (
    current_setting('test.a')::uuid, current_setting('test.prof1')::uuid,
    'guard-direct-draft', 'Guard Direct Draft Probe',
    'A description that is definitely longer than fifty characters.',
    'fixed', 10
  ) $$,
  'direct INSERT of a draft (default state) remains allowed');
select is(
  (select count(*)::int from public.service_listings where slug = 'guard-direct-draft'),
  1,
  'the direct draft INSERT landed (status defaulted to draft)'
);

-- ─── 10. service_role can call all 7 RPCs (claims required) ───────────────────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);

select lives_ok($$ select public.service_listing_get(current_setting('test.l4')::uuid) $$,
  'service_role can call service_listing_get');
select lives_ok($$ select public.service_listing_list_mine() $$,
  'service_role can call service_listing_list_mine');
select set_config('test.srl', (select public.service_listing_create(
  current_setting('test.prof1')::uuid, 'Service Role Created Listing',
  'A description that is definitely longer than fifty characters.',
  'fixed', 100)->'data'->>'id'), true);
select lives_ok($$ select public.service_listing_update(
  current_setting('test.srl')::uuid,
  p_description => 'An updated description that is definitely longer than fifty chars.') $$,
  'service_role can call service_listing_update');
select is(
  (select public.service_listing_publish(current_setting('test.srl')::uuid)->>'code'),
  'PLT000',
  'service_role can call service_listing_publish'
);
select is(
  (select public.service_listing_unpublish(current_setting('test.srl')::uuid)->>'code'),
  'PLT000',
  'service_role can call service_listing_unpublish'
);
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.service_favorite_toggle(current_setting('test.l1')::uuid) $$,
  'service_role can call service_favorite_toggle');

-- ─── 11. Envelope + audit ─────────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select is(
  (select public.service_listing_get(current_setting('test.l1')::uuid)->'data'->>'profession_slug'),
  'legal-consultant',
  'get data carries profession_slug'
);
select is(
  (select public.service_listing_get(current_setting('test.l1')::uuid)->'data'->>'industry_slug'),
  'legal',
  'get data carries industry_slug'
);
select is(
  (select jsonb_array_length(
    public.service_listing_get(current_setting('test.l1')::uuid)->'data'->'media')),
  1,
  'get data carries the media array'
);

set role postgres;
select is(
  (select count(*)::int >= 1 from public.platform_audit_log
    where action = 'service_listing_publish'),
  true,
  'publish events are audit-logged'
);

select * from finish();
rollback;
