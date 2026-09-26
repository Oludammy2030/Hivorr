-- EP-03-06: Platform Config & Ranking Posture
--
-- Validates the new platform_config table (EP-03-06 Plan §7.2):
--   - Table exists; RLS enabled; anon has zero write grants; authenticated
--     has SELECT only; service_role has column-level UPDATE/INSERT/DELETE.
--   - CHECK vocabularies (key format, value is object, required weight keys,
--     range 0..1, sum 0.999..1.001, priors), indexes, trigger, comments.
--   - service_listings GIN retained + new ranking partial index exists.
--   - Exactly 1 SECURITY DEFINER among service_% RPCs (reveal), ranking RPCs
--     remain INVOKER; exactly 21 service_% RPCs (19 prior +2 new: weights_get + ranking_search).
--   - Realtime excludes platform_config.
--   - EXECUTE posture: anon can execute ranking_search + listing_get + review_get_for_listing (3), authenticated 21.

begin;
set search_path to extensions, public;
select plan(26);

-- ─── 0. platform_config exists ──────────────────────────────────────────────
select has_table('public', 'platform_config', 'platform_config exists');

-- ─── 1. RLS enabled ─────────────────────────────────────────────────────────
select is(
  (select c.relrowsecurity::int
     from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='platform_config'),
  1,
  'RLS enabled on platform_config'
);

-- ─── 2. anon has zero write grants ──────────────────────────────────────────
select is(
  (select count(*)::int from information_schema.role_table_grants
    where grantee='anon' and table_schema='public' and table_name='platform_config'
      and privilege_type in ('INSERT','UPDATE','DELETE')),
  0,
  'anon has no INSERT/UPDATE/DELETE on platform_config'
);

-- ─── 3. authenticated has SELECT only (no write) ───────────────────────────
select is(
  (select count(*)::int from information_schema.role_table_grants
    where grantee='authenticated' and table_schema='public' and table_name='platform_config'
      and privilege_type in ('INSERT','UPDATE','DELETE')),
  0,
  'authenticated has no INSERT/UPDATE/DELETE on platform_config'
);
select is(
  (select count(*)::int from information_schema.role_table_grants
    where grantee='authenticated' and table_schema='public' and table_name='platform_config'
      and privilege_type='SELECT'),
  1,
  'authenticated has SELECT on platform_config'
);

-- ─── 4. service_role has SELECT + column-level UPDATE/INSERT/DELETE ─────────
select is(
  (select count(*)::int from information_schema.role_table_grants
    where grantee='service_role' and table_schema='public' and table_name='platform_config'
      and privilege_type='SELECT'),
  1,
  'service_role has SELECT on platform_config'
);
select is(
  (select count(*)::int from information_schema.role_column_grants
    where grantee='service_role' and table_schema='public' and table_name='platform_config'
      and column_name in ('value','description') and privilege_type='UPDATE'),
  2,
  'service_role has column-level UPDATE(value,description) on platform_config'
);

-- ─── 5. CHECK key format ────────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid='public.platform_config'::regclass and contype='c' and conname='platform_config_key_format'),
  1,
  'platform_config key format CHECK exists'
);

-- ─── 6. CHECK value is object ───────────────────────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid='public.platform_config'::regclass and contype='c' and conname='platform_config_value_is_object'),
  1,
  'platform_config value is_object CHECK exists'
);

-- ─── 7. CHECK required weight keys ──────────────────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid='public.platform_config'::regclass and contype='c' and conname='platform_config_weights_required_keys'),
  1,
  'platform_config weights_required_keys CHECK exists'
);

-- ─── 8. CHECK weight range + sum ────────────────────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid='public.platform_config'::regclass and contype='c' and conname in ('platform_config_weights_range','platform_config_weights_sum')),
  2,
  'platform_config weight range/sum CHECKs exist'
);

-- ─── 9. seed row service_ranking_weights ────────────────────────────────────
select is(
  (select count(*)::int from public.platform_config where key='service_ranking_weights'),
  1,
  'seed row service_ranking_weights exists'
);
select ok(
  (select (value->>'w_verify')::numeric between 0 and 1 from public.platform_config where key='service_ranking_weights'),
  'seed w_verify in 0..1'
);
select ok(
  (select (value->>'w_verify')::numeric + (value->>'w_rating')::numeric + (value->>'w_completion')::numeric + (value->>'w_recency')::numeric + (value->>'w_relevance')::numeric + (value->>'w_activity')::numeric between 0.999 and 1.001 from public.platform_config where key='service_ranking_weights'),
  'seed weight sum ~1.0'
);

-- ─── 10. GIN(search_vector) retained ────────────────────────────────────────
select is(
  (select count(*)::int from pg_indexes where schemaname='public' and tablename='service_listings' and indexname='service_listings_search_vector_gin'),
  1,
  'GIN(search_vector) still exists'
);

-- ─── 11. New ranking partial index ──────────────────────────────────────────
select is(
  (select count(*)::int from pg_indexes where schemaname='public' and tablename='service_listings' and indexname='service_listings_published_ranking_idx'),
  1,
  'service_listings_published_ranking_idx exists'
);

-- ─── 12. Additive entities.last_seen_at column ──────────────────────────────
select has_column('public','entities','last_seen_at', 'entities.last_seen_at exists');
select is(
  (select count(*)::int from pg_indexes where schemaname='public' and tablename='entities' and indexname='entities_last_seen_at_idx'),
  1,
  'entities_last_seen_at_idx exists'
);

-- ─── 13. Exactly 1 service_% SECURITY DEFINER (reveal) ─────────────────────
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'service\_%' and p.prosecdef),
  1,
  'exactly one service_% function is SECURITY DEFINER'
);

-- ─── 14. Exactly 21 service_% RPCs (19 prior +2 new) ────────────────────────
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'service\_%' and p.prorettype='jsonb'::regtype),
  21,
  'exactly 21 service_% RPCs exist (19 prior + weights_get + ranking_search)'
);

-- ─── 15. Realtime excludes platform_config ──────────────────────────────────
select is(
  (select count(*)::int from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='platform_config'),
  0,
  'Realtime excludes platform_config'
);

-- ─── 16. Anon EXECUTE: 4 functions (listing_get + review_get_for_listing + ranking_search + weights_get) ──
select is(
  (select count(*)::int from information_schema.routine_privileges where routine_schema='public' and routine_name like 'service\_%' and grantee='anon'),
  4,
  'anon can execute exactly four service_% functions (listing_get + review_get_for_listing + ranking_search + weights_get)'
);
select ok(
  has_function_privilege('anon', 'public.service_ranking_search(uuid, text, jsonb, jsonb, integer)', 'EXECUTE'),
  'anon can execute service_ranking_search'
);
select ok(
  has_function_privilege('anon', 'public.service_ranking_weights_get()', 'EXECUTE'),
  'anon can execute service_ranking_weights_get'
);

-- ─── 17. Comments not null ──────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='platform_config' and obj_description(c.oid,'pg_class') is not null),
  1,
  'platform_config has table comment'
);

-- ─── 18. RLS policies on platform_config ────────────────────────────────────
select is(
  (select count(*)::int from pg_policies where schemaname='public' and tablename='platform_config'),
  5,
  'exactly 5 RLS policies on platform_config (2 select + insert/update/delete service_role)'
);

select * from finish();
rollback;
