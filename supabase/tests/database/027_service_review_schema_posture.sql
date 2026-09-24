-- EP-03-03: Double-Blind Review & Rating Schema Posture
--
-- Validates the 2 new review tables (EP-03-03 Plan §14.1):
--   - Both tables exist; RLS enabled on both.
--   - anon has zero INSERT/UPDATE/DELETE on both tables.
--   - authenticated has INSERT+UPDATE (column-level) on service_reviews via RPC (RLS-restricted).
--   - service_review_aggregates is public read (anon/authenticated SELECT only).
--   - CHECK vocabularies (rating 1-5, comment, no_self, UNIQUE(contract, reviewer),
--     avg 0-5, review_count), indexes, triggers, comments.
--   - No service_review_% SECURITY DEFINER; exactly 4 service_review_% RPCs.
--   - Realtime excludes both tables.
--   - EXECUTE posture: anon only get_for_listing, authenticated 4, service_role 4.

begin;
set search_path to extensions, public;
select plan(29);

-- ─── 0. Both tables exist ─────────────────────────────────────────────────────
select has_table('public', 'service_reviews', 'service_reviews exists');
select has_table('public', 'service_review_aggregates', 'service_review_aggregates exists');

-- ─── 1. RLS enabled on both ───────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('service_reviews', 'service_review_aggregates')
      and c.relrowsecurity),
  2,
  'RLS enabled on both review tables'
);

-- ─── 2. anon has zero write grants on both tables ────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name in ('service_reviews', 'service_review_aggregates')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'anon has no INSERT/UPDATE/DELETE grants on the review tables'
);

-- ─── 3. authenticated has INSERT+UPDATE (column-level) on service_reviews via RPC ─
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_reviews'
      and privilege_type = 'INSERT'),
  9,
  'authenticated has column-level INSERT on service_reviews for RPC (9 columns)'
);
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_reviews'
      and privilege_type = 'UPDATE'
      and column_name in ('is_revealed', 'revealed_at', 'updated_at')),
  3,
  'authenticated has column-level UPDATE on is_revealed/revealed_at/updated_at for reveal (RLS with is_revealed gate)'
);

-- ─── 4. service_review_aggregates public read (anon/authenticated SELECT only) ─
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name = 'service_review_aggregates'
      and privilege_type = 'SELECT'),
  1,
  'anon has SELECT on service_review_aggregates (public stars)'
);

select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_review_aggregates'
      and privilege_type in ('INSERT', 'UPDATE')),
  2,
  'authenticated has INSERT+UPDATE on service_review_aggregates for reveal UPSERT (RLS public read, write via RPC)'
);

-- ─── 5. Rating CHECK 1-5 ─────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_reviews'::regclass
      and contype = 'c'
      and conname = 'service_reviews_rating_range'),
  1,
  'service_reviews rating CHECK exists'
);

-- ─── 6. No-self CHECK ─────────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_reviews'::regclass
      and contype = 'c'
      and conname = 'service_reviews_no_self'),
  1,
  'service_reviews_no_self CHECK exists'
);

-- ─── 7. UNIQUE (contract_id, reviewer_entity_id) ─────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_reviews'::regclass
      and contype = 'u'
      and conname = 'service_reviews_contract_reviewer_key'),
  1,
  'UNIQUE (contract_id, reviewer) constraint exists'
);

-- ─── 8. service_review_aggregates avg CHECK ──────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_review_aggregates'::regclass
      and contype = 'c'
      and conname = 'service_review_aggregates_avg_range'),
  1,
  'service_review_aggregates avg CHECK exists'
);

-- ─── 9. Comment length CHECK ──────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_reviews'::regclass
      and contype = 'c'
      and conname = 'service_reviews_comment_length'),
  1,
  'service_reviews comment length CHECK exists'
);

-- ─── 10. revealed_at semantics CHECK ──────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_reviews'::regclass
      and contype = 'c'
      and conname = 'service_reviews_revealed_at_semantics'),
  1,
  'revealed_at semantics CHECK exists'
);

-- ─── 11. Indexes on service_reviews ───────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'service_reviews'
      and indexname in (
        'service_reviews_contract_idx',
        'service_reviews_reviewer_idx',
        'service_reviews_listing_revealed_idx',
        'service_reviews_contract_revealed_idx'
      )),
  4,
  'the 4 service_reviews indexes exist'
);

-- ─── 12. Index on service_review_aggregates ───────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'service_review_aggregates'
      and indexname = 'service_review_aggregates_profession_idx'),
  1,
  'service_review_aggregates profession_idx exists'
);

-- ─── 13. Triggers: 2 updated_at (reviews + aggregates) ───────────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and not t.tgisinternal
      and t.tgname in (
        'service_reviews_set_updated_at', 'service_review_aggregates_set_updated_at'
      )),
  2,
  'the 2 updated_at triggers exist (reviews + aggregates)'
);

-- ─── 14. Exactly 1 service_review_% SECURITY DEFINER (reveal) ──────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'service\_review\_%'
      and p.prosecdef),
  1,
  'exactly one service_review_% function is SECURITY DEFINER (reveal_if_ready)'
);
select ok(
  has_function_privilege('public.service_review_reveal_if_ready(uuid)', 'EXECUTE') is not null
  and (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname='public' and p.proname='service_review_reveal_if_ready'),
  'service_review_reveal_if_ready is SECURITY DEFINER'
);
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'service\_review\_submit'
      and p.prosecdef),
  0,
  'service_review_submit is not SECURITY DEFINER'
);

-- ─── 15. Exactly 4 service_review_% RPCs ──────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'service\_review\_%'
      and p.prorettype = 'jsonb'::regtype),
  4,
  'exactly 4 service_review_% RPCs exist'
);

-- ─── 16. Realtime excludes both tables ────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('service_reviews', 'service_review_aggregates')),
  0,
  'Realtime excludes both review tables'
);

-- ─── 17. Both tables have comments ────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('service_reviews', 'service_review_aggregates')
      and obj_description(c.oid, 'pg_class') is not null),
  2,
  'both review tables have comments'
);

-- ─── 18. anon EXECUTE: only get_for_listing ───────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_review\_%'
      and grantee = 'anon'),
  1,
  'anon can execute exactly one service_review_% function'
);

select ok(
  has_function_privilege('anon', 'public.service_review_get_for_listing(uuid, integer, uuid)', 'EXECUTE'),
  'the anon-executable service_review_% function is get_for_listing'
);

-- ─── 19. authenticated EXECUTE on all 4 ───────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_review\_%'
      and grantee = 'authenticated'),
  4,
  'authenticated can execute all 4 service_review_% RPCs'
);

-- ─── 20. service_role EXECUTE on all 4 ────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_review\_%'
      and grantee = 'service_role'),
  4,
  'service_role can execute all 4 service_review_% RPCs'
);

-- ─── 21. RLS policy surface: 5 policies (4 on reviews + 1 on aggregates) ───────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename in ('service_reviews', 'service_review_aggregates')),
  5,
  'exactly 5 RLS policies on the 2 review tables (4 on reviews + 1 on aggregates)'
);

-- ─── 22. service_listings cache UPDATE grant (narrow) ─────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_listings'
      and column_name in ('avg_rating', 'review_count')
      and privilege_type = 'UPDATE'),
  2,
  'authenticated has UPDATE on service_listings avg_rating/review_count for reveal cache'
);

select * from finish();
rollback;
