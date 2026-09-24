-- EP-03-01: Service Marketplace Schema Posture
--
-- Validates the 3 new marketplace tables (EP-03-01 Plan §14.1, adjusted for the
-- approved D5-guard deviation):
--   - All 3 tables exist; RLS enabled on all 3.
--   - anon has zero INSERT/UPDATE/DELETE grants on the 3 tables (public
--     SELECT on service_listings / service_listing_media is RLS-scoped to
--     published rows per the plan's SECURITY INVOKER read decision).
--   - search_vector / avg_rating / review_count / view_count have zero client
--     column grants.
--   - APPROVED DEVIATION: status / published_at / is_trade_verified_cache DO
--     carry authenticated UPDATE+INSERT column grants (SECURITY INVOKER RPCs
--     need them) and are protected by the service_listings_guard_publish_state
--     D5 trigger instead (direct writes raise PLT002 — behavioral proof in 024).
--   - CHECK vocabularies (slug, published_at semantics, media path parity,
--     mime allowlist), unique constraints, named indexes incl. GIN, triggers.
--   - No service_% SECURITY DEFINER; exactly 7 service_% RPCs.
--   - Realtime excludes all 3 tables; comments present.
--   - service-listing-media bucket provisioned with 4 storage.objects policies.
--   - EXECUTE posture: anon receives only service_listing_get.

begin;
set search_path to extensions, public;
select plan(30);

-- ─── 0. All 3 tables exist ────────────────────────────────────────────────────
select has_table('public', 'service_listings', 'service_listings exists');
select has_table('public', 'service_listing_media', 'service_listing_media exists');
select has_table('public', 'service_favorites', 'service_favorites exists');

-- ─── 1. RLS enabled on all 3 ──────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('service_listings', 'service_listing_media', 'service_favorites')
      and c.relrowsecurity),
  3,
  'RLS enabled on all 3 marketplace tables'
);

-- ─── 2. anon has zero write grants on the 3 tables ────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name in ('service_listings', 'service_listing_media', 'service_favorites')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'anon has no INSERT/UPDATE/DELETE grants on the marketplace tables'
);

-- ─── 3. Server-computed columns have zero client grants (search_vector/view_count) ─
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_listings'
      and column_name in ('search_vector', 'view_count')
      and privilege_type in ('INSERT', 'UPDATE')),
  0,
  'search_vector/view_count are not client-writable'
);

-- ─── 3b. avg_rating/review_count have authenticated UPDATE for reveal cache (EP-03-03 deviation) ─
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_listings'
      and column_name in ('avg_rating', 'review_count')
      and privilege_type = 'UPDATE'),
  2,
  'avg_rating/review_count have authenticated UPDATE grants for reveal cache (EP-03-03 approved deviation, mirrors financial_balances)'
);

-- ─── 4. Guarded publish columns carry UPDATE grants (approved deviation) ──────
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_listings'
      and column_name in ('status', 'published_at', 'is_trade_verified_cache')
      and privilege_type = 'UPDATE'),
  3,
  'status/published_at/is_trade_verified_cache have authenticated UPDATE grants (D5 guard protects them)'
);

-- ─── 5. Guarded publish columns carry INSERT grants (create path) ─────────────
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_listings'
      and column_name in ('status', 'published_at', 'is_trade_verified_cache')
      and privilege_type = 'INSERT'),
  3,
  'guarded publish columns have authenticated INSERT grants (service_listing_create path)'
);

-- ─── 6. Slug format CHECK ─────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_listings'::regclass
      and contype = 'c'
      and conname = 'service_listings_slug_format'),
  1,
  'service_listings slug format CHECK exists'
);

-- ─── 7. published_at semantics CHECK ──────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_listings'::regclass
      and contype = 'c'
      and conname = 'service_listings_published_at_semantics'),
  1,
  'published_at NOT NULL iff published CHECK exists'
);

-- ─── 8. UNIQUE (entity_id, slug) ──────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_listings'::regclass
      and contype = 'u'
      and conname = 'service_listings_entity_slug_key'),
  1,
  'UNIQUE (entity_id, slug) constraint exists'
);

-- ─── 9. service_favorites UNIQUE (entity_id, listing_id) ──────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_favorites'::regclass
      and contype = 'u'
      and conname = 'service_favorites_entity_listing_key'),
  1,
  'UNIQUE (entity_id, listing_id) favorite constraint exists'
);

-- ─── 10. Media storage_path owner-prefix CHECK ────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_listing_media'::regclass
      and contype = 'c'
      and conname = 'service_listing_media_storage_path_owner_prefix'),
  1,
  'storage_path owner-prefix CHECK exists'
);

-- ─── 11. Media mime allowlist CHECK ───────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_listing_media'::regclass
      and contype = 'c'
      and conname = 'service_listing_media_mime_allowed'),
  1,
  'mime_type allowlist CHECK exists'
);

-- ─── 12. B-tree / partial indexes on service_listings ─────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'service_listings'
      and indexname in (
        'service_listings_entity_idx', 'service_listings_profession_idx',
        'service_listings_industry_idx', 'service_listings_status_published_idx',
        'service_listings_currency_idx', 'service_listings_published_at_idx'
      )),
  6,
  'the 6 b-tree/partial service_listings indexes exist'
);

-- ─── 13. GIN(search_vector) ───────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'service_listings'
      and indexname = 'service_listings_search_vector_gin'),
  1,
  'GIN(search_vector) index exists'
);

-- ─── 14. Triggers (2 updated_at + search_vector + D5 guard) ───────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and not t.tgisinternal
      and t.tgname in (
        'service_listings_set_updated_at', 'service_listings_search_vector_tg',
        'service_listings_guard_publish_state', 'service_listing_media_set_updated_at'
      )),
  4,
  'the 4 named marketplace triggers exist (2 updated_at + search_vector + D5 guard)'
);

-- ─── 15. Exactly 1 service_% SECURITY DEFINER (service_review_reveal_if_ready) ─────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'service\_%'
      and p.prosecdef),
  1,
  'exactly one service_% function is SECURITY DEFINER (service_review_reveal_if_ready, approved deviation for double-blind count)'
);
select ok(
  (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='service_review_reveal_if_ready'),
  'service_review_reveal_if_ready is SECURITY DEFINER'
);

-- ─── 16. Exactly 19 service_% RPCs (7 marketplace + 8 contract + 4 review) ─────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'service\_%'
      and p.prorettype <> 'trigger'::regtype),
  19,
  'exactly 19 service_% RPCs exist (7 listing + 8 contract + 4 review)'
);

-- ─── 17. Realtime excludes all 3 tables ───────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('service_listings', 'service_listing_media', 'service_favorites')),
  0,
  'Realtime excludes all 3 marketplace tables'
);

-- ─── 18. All 3 tables have comments ───────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('service_listings', 'service_listing_media', 'service_favorites')
      and obj_description(c.oid, 'pg_class') is not null),
  3,
  'all 3 marketplace tables have comments'
);

-- ─── 19. service-listing-media bucket provisioned ─────────────────────────────
select is(
  (select count(*)::int
     from storage.buckets
    where id = 'service-listing-media'
      and public is true
      and file_size_limit = 10485760
      and allowed_mime_types @> '{image/jpeg,image/png,image/webp,application/pdf}'),
  1,
  'service-listing-media bucket exists (public, 10 MiB, 4 mime types)'
);

-- ─── 20. 4 storage.objects policies for the bucket ────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'storage'
      and policyname like 'service\_listing\_media\_%'),
  4,
  '4 storage.objects policies exist for service-listing-media'
);

-- ─── 21. anon EXECUTE: service_listing_get + service_review_get_for_listing ──────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_%'
      and grantee = 'anon'),
  2,
  'anon can execute exactly two service_% functions (listing_get + review_get_for_listing)'
);

-- ─── 22. authenticated EXECUTE on all 19 ──────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_%'
      and grantee = 'authenticated'),
  19,
  'authenticated can execute all 19 service_% RPCs (7 marketplace + 8 contract + 4 review)'
);

-- ─── 23. service_role EXECUTE on all 19 ───────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_%'
      and grantee = 'service_role'),
  19,
  'service_role can execute all 19 service_% RPCs'
);

-- ─── 24. The anon-executable RPCs are service_listing_get + review_get_for_listing ─
select ok(
  has_function_privilege('anon', 'public.service_listing_get(uuid)', 'EXECUTE')
  and has_function_privilege('anon', 'public.service_review_get_for_listing(uuid, integer, uuid)', 'EXECUTE'),
  'the anon-executable service_% functions are service_listing_get + review_get_for_listing'
);

-- ─── 25. RLS policy surface: 4 + 4 + 3 ────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename in ('service_listings', 'service_listing_media', 'service_favorites')),
  11,
  'exactly 11 RLS policies on the 3 marketplace tables (4+4+3)'
);

select * from finish();
rollback;
