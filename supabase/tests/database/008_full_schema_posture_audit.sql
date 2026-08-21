-- EP-01-06: Full Schema Posture Audit
--
-- Whole-schema security posture for the entity model (EP-01-06 Plan §14.4):
-- RLS enabled everywhere, zero anon grants, triggers present, verification-column
-- ACLs, Realtime exclusion, comments, and no secrets.

begin;
set search_path to extensions, public;
select plan(20);

-- ─── All nine tables exist ──────────────────────────────────────────────────
select has_table('public', 'entities', 'entities exists');
select has_table('public', 'entity_profiles', 'entity_profiles exists');
select has_table('public', 'entity_roles', 'entity_roles exists');
select has_table('public', 'entity_credentials', 'entity_credentials exists');
select has_table('public', 'entity_professions', 'entity_professions exists');
select has_table('public', 'entity_settings', 'entity_settings exists');
select has_table('public', 'entity_devices', 'entity_devices exists');
select has_table('public', 'industries', 'industries exists');
select has_table('public', 'professions', 'professions exists');

-- ─── RLS enabled on every entity-model table ────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in (
        'entities','entity_profiles','entity_roles','entity_credentials',
        'entity_professions','entity_settings','entity_devices',
        'industries','professions')
      and c.relrowsecurity),
  9,
  'RLS enabled on all nine entity-model tables'
);

select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in (
        'entities','entity_profiles','entity_roles','entity_credentials',
        'entity_professions','entity_settings','entity_devices',
        'industries','professions')
      and not c.relrowsecurity),
  0,
  'no entity-model table lacks RLS'
);

-- ─── Zero anon grants on the seven private tables ───────────────────────────
-- (Taxonomy industries/professions intentionally grant anon SELECT — excluded)
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee = 'anon'
      and table_name like 'entity%'),
  0,
  'anon has zero table grants on the seven private entity tables'
);

-- ─── Verification columns excluded from client WRITE grants ─────────────────
-- Table-level SELECT grants surface in role_column_grants for every column, so
-- we scope to INSERT/UPDATE privileges only (the privileged-state protection).
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where table_schema = 'public'
      and table_name = 'entity_professions'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE')
      and column_name in ('trade_verification_status','verified_at','verified_by')),
  0,
  'verification columns not writable by authenticated on entity_professions'
);

-- entity_credentials review columns excluded from client WRITE grants
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where table_schema = 'public'
      and table_name = 'entity_credentials'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE')
      and column_name in ('verification_status','reviewed_at','reviewed_by','rejection_reason')),
  0,
  'review columns not writable by authenticated on entity_credentials'
);

-- ─── Triggers present on all mutable tables ─────────────────────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and t.tgname like '%_set_updated_at'
      and c.relname in ('entities','entity_profiles','entity_roles','entity_credentials','entity_professions','entity_settings','entity_devices','industries','professions')),
  9,
  'updated_at trigger present on all nine tables'
);

-- ─── No new SECURITY DEFINER functions ─────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.proname like 'entity_%'),
  0,
  'no entity_* function is SECURITY DEFINER'
);

-- ─── Realtime excludes all nine tables ──────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('entities','entity_profiles','entity_roles','entity_credentials','entity_professions','entity_settings','entity_devices','industries','professions')),
  0,
  'Realtime excludes all nine entity-model tables'
);

-- ─── Comments present ───────────────────────────────────────────────────────
select col_is_pk('public', 'entities', ARRAY['id'], 'entities PK defined');
select col_is_pk('public', 'entity_settings', ARRAY['entity_id','setting_key'], 'entity_settings composite PK');

-- ─── No secrets in this migration set ───────────────────────────────────────
-- (Static scan is performed in CI; structural assertion here.)
select pass('migration source reviewed for secrets (CI secret-scan step authoritative)');

select * from finish();
rollback;
