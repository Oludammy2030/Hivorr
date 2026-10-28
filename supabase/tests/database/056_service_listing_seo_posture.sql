-- EP-03-19: Public Listing SEO Posture (anon published-only surface)
--
-- Thin verification companion for the SEO routes `/s/:slug/:id`,
-- `/s/:industrySlug`, `/c/:slug/:id` (redirect). No schema change here —
-- this test pins the privacy invariant the routes depend on:
--   - anon `service_listing_get` succeeds on published, returns the identical
--     PLT004 on draft and unknown ids (no enumeration oracle);
--   - anon direct SELECT sees published rows only;
--   - anon `service_ranking_search` runs (the anon browse fix) and surfaces the
--     published fixture while never returning the draft fixture;
--   - anon cannot see media of an unpublished parent;
--   - anon cannot call gated listing writes (create/publish).
-- Mirrors the assertions in 024_service_marketplace_rpc_enforcement.sql §1.

begin;
set search_path to extensions, public;
select plan(9);

-- ─── Fixtures (isolated ids; published + draft via the canonical RPCs) ──────
set role postgres;

select set_config('test.seo_a', '33333333-3333-3333-3333-333333333333', true);
insert into auth.users (id, email)
values (current_setting('test.seo_a')::uuid, 'seo-a@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.seo_a')::uuid, 'active')
on conflict (id) do nothing;

-- The SEO fixture account is identity-verified; trade verification is separate.
insert into public.entity_kyc_levels (entity_id, tier_code, status)
values (current_setting('test.seo_a')::uuid, 'tier_1', 'active')
on conflict (entity_id) do update
  set tier_code = excluded.tier_code, status = excluded.status;

select set_config('test.seo_prof',
  (select id::text from public.professions where slug = 'legal-consultant'), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.seo_a')::uuid, current_setting('test.seo_prof')::uuid, 'approved')
on conflict (entity_id, profession_id) do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.seo_a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.seo_pub', (select public.service_listing_create(
  current_setting('test.seo_prof')::uuid,
  'SEO Posture Published Listing',
  'A published listing body long enough to satisfy the fifty character minimum for tests.',
  'fixed', 1000, 2000)->'data'->>'id'), true);
select public.service_listing_publish(current_setting('test.seo_pub')::uuid);

select set_config('test.seo_draft', (select public.service_listing_create(
  current_setting('test.seo_prof')::uuid,
  'SEO Posture Draft Listing',
  'A draft listing body long enough to satisfy the fifty character minimum for tests.',
  'fixed', 1000, 2000)->'data'->>'id'), true);

-- ─── Anon SEO surface ────────────────────────────────────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);

select is(
  (select public.service_listing_get(current_setting('test.seo_pub')::uuid)->>'code'),
  'PLT000',
  'anon service_listing_get succeeds on a published listing'
);
select throws_ok($$ select public.service_listing_get(current_setting('test.seo_draft')::uuid) $$,
  'P0001', 'PLT004: Listing not found.',
  'anon get on a draft returns PLT004');
select throws_ok($$ select public.service_listing_get('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', 'PLT004: Listing not found.',
  'anon get on an unknown id returns the identical PLT004');
select is(
  (select count(*)::int from public.service_listings
    where id in (current_setting('test.seo_pub')::uuid, current_setting('test.seo_draft')::uuid)
      and status <> 'published'),
  0,
  'anon direct SELECT sees zero unpublished SEO fixtures (RLS public branch)');
select is(
  (select count(*)::int from public.service_listing_media m
    join public.service_listings l on l.id = m.listing_id
    where m.listing_id = current_setting('test.seo_draft')::uuid),
  0,
  'anon sees zero media rows for the unpublished parent');
select throws_ok($$ select public.service_listing_create(null::uuid, null::text, null::text, null::text) $$,
  '42501', null, 'anon cannot call service_listing_create');
select throws_ok($$ select public.service_listing_publish(null::uuid) $$,
  '42501', null, 'anon cannot call service_listing_publish');
select is(
  (select count(*)::int
    from jsonb_array_elements(
      (public.service_ranking_search(p_query=>'Posture Published', p_limit=>50)->'data'->'items')) e
    where e->>'id' = current_setting('test.seo_pub')),
  1,
  'anon service_ranking_search runs and surfaces the published fixture (anon browse fix)');
select is(
  (select count(*)::int
    from jsonb_array_elements(
      (public.service_ranking_search(p_limit=>50)->'data'->'items')) e
    where e->>'id' = current_setting('test.seo_draft')),
  0,
  'anon service_ranking_search never surfaces the draft fixture');

select * from finish();
rollback;
