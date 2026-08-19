-- EP-01-05: Security Posture Audit
--
-- SQL audit assertions verifying the enforcement posture: RLS enabled
-- everywhere, no anon table grants, narrowed authenticated grants,
-- default-deny privileges, hardened SECURITY DEFINER usage, and Realtime
-- exclusion (EP-01-05 Plan §14.4).

begin;
set search_path to extensions, public;
select plan(19);

-- ─── Tables exist ───────────────────────────────────────────────────────────
select has_table('public', 'platform_audit_log', 'platform_audit_log exists');
select has_table('public', 'platform_demo_records', 'platform_demo_records exists');

-- ─── RLS enabled on every created table ─────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('platform_audit_log', 'platform_demo_records')
      and c.relrowsecurity),
  2,
  'RLS enabled on all tables created by this task'
);

-- ─── Default-deny privileges ────────────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name like 'platform\_%'
      and grantee = 'anon'),
  0,
  'anon has zero table grants on platform tables'
);

select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'platform_audit_log'
      and grantee = 'authenticated'),
  0,
  'authenticated has zero grants on platform_audit_log (RPC-only path)'
);

select is(
  (select string_agg(privilege_type, ',' order by privilege_type)
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'platform_demo_records'
      and grantee = 'authenticated'),
  'INSERT,SELECT,UPDATE',
  'authenticated demo_records grants are minimal (no DELETE)'
);

set role anon;

select throws_ok(
  'create table public.platform_should_fail(id int)',
  '42501',
  NULL,
  'anon cannot create objects in public schema (behavioral check)'
);

set role postgres;

select is(
  (select count(*)::int
     from pg_default_acl d
     join pg_namespace n on n.oid = d.defaclnamespace
    where n.nspname = 'public'
      and d.defaclacl::text like any (array['%anon=%', '%authenticated=%'])),
  0,
  'no default privileges granted to anon/authenticated in public schema'
);

-- ─── SECURITY DEFINER hardening ─────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'platform\_%'
      and p.prosecdef),
  1,
  'exactly one SECURITY DEFINER platform function (platform_audit_log_add)'
);

select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'platform_audit_log_add'
      and p.prosecdef
      and p.proconfig @> array['search_path=pg_catalog, public']),
  1,
  'security-definer function pins search_path = pg_catalog, public'
);

-- ─── Execute grants: anon receives only the health probe ────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'platform\_%'
      and grantee = 'anon'),
  1,
  'anon can execute exactly one platform function'
);

select is(
  (select routine_name
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'platform\_%'
      and grantee = 'anon'),
  'platform_health',
  'the anon-executable function is platform_health'
);

-- ─── Realtime exclusion ─────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename like 'platform\_%'),
  0,
  'reference tables are excluded from the supabase_realtime publication'
);

-- ─── Trigger and policy surface ─────────────────────────────────────────────
select has_trigger(
  'public',
  'platform_demo_records',
  'platform_demo_records_set_updated_at',
  'platform_demo_records has the updated_at trigger'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_audit_log'),
  0,
  'platform_audit_log has zero policies (default-deny)'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_demo_records'),
  3,
  'platform_demo_records has exactly three RLS policies'
);

select is(
  (select string_agg(policyname, ',' order by policyname)
     from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_demo_records'),
  'platform_demo_records_authenticated_insert,platform_demo_records_authenticated_select,platform_demo_records_authenticated_update',
  'policy names follow the <table>_<role>_<op> convention'
);

-- ─── Helper and constraint surface ──────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'platform_is_authenticated',
        'platform_current_user_id',
        'platform_set_updated_at',
        'platform_raise_error',
        'platform_validate_payload'
      )),
  5,
  'all five platform helper functions exist'
);

select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'platform_demo_records'
      and indexname = 'platform_demo_records_owner_title_key'),
  1,
  'owner-title uniqueness constraint exists (PLT005 conflict source)'
);

select * from finish();
rollback;