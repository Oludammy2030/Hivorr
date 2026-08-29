-- EP-02-03: Verification Schema Posture
--
-- Security-posture audit for the 5 new verification tables and 6 RPCs
-- (EP-02-03 Plan §14.1). Mirrors the EP-01-06 posture-audit pattern (008):
-- RLS enabled everywhere, anon zero grants, verification-column ACLs, triggers
-- present, no SECURITY DEFINER verification function, Realtime exclusion,
-- comments, and seed integrity. Must pass with zero failures.

begin;
set search_path to extensions, public;
select plan(20);

-- ─── All five new tables exist ────────────────────────────────────────────────
select has_table('public', 'kyc_tiers', 'kyc_tiers exists');
select has_table('public', 'entity_kyc_levels', 'entity_kyc_levels exists');
select has_table('public', 'verification_submissions', 'verification_submissions exists');
select has_table('public', 'verification_reviews', 'verification_reviews exists');
select has_table('public', 'verification_audit_trail', 'verification_audit_trail exists');

-- ─── RLS enabled on all five new tables ───────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in (
        'kyc_tiers','entity_kyc_levels','verification_submissions',
        'verification_reviews','verification_audit_trail')
      and c.relrowsecurity),
  5,
  'RLS enabled on all five verification tables'
);

-- ─── Zero anon grants on the five new tables (default-deny) ───────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee = 'anon'
      and table_name in (
        'kyc_tiers','entity_kyc_levels','verification_submissions',
        'verification_reviews','verification_audit_trail')),
  0,
  'anon has zero table grants on the five new tables'
);

-- ─── verification_submissions privileged columns excluded from client WRITE ────
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where table_schema = 'public'
      and table_name = 'verification_submissions'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE')
      and column_name in ('status','reviewed_at','reviewed_by')),
  0,
  'verification_submissions.status/reviewed_at/reviewed_by not writable by authenticated'
);

-- ─── entity_kyc_levels not writable by authenticated ──────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where table_schema = 'public'
      and table_name = 'entity_kyc_levels'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE')),
  0,
  'entity_kyc_levels not INSERT/UPDATE writable by authenticated'
);

-- ─── verification_reviews immutable: no UPDATE/DELETE to any client role ────────
-- (the table owner postgres inherently holds all privileges; we exclude it and
--  assert no anon/authenticated/service_role may UPDATE or DELETE these rows)
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'verification_reviews'
      and grantee in ('anon', 'authenticated', 'service_role')
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'verification_reviews has no UPDATE/DELETE grant to any client role'
);

-- ─── verification_audit_trail immutable: no UPDATE/DELETE to any client role ────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'verification_audit_trail'
      and grantee in ('anon', 'authenticated', 'service_role')
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'verification_audit_trail has no UPDATE/DELETE grant to any client role'
);

-- ─── Triggers present on the three mutable tables ─────────────────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and t.tgname like '%_set_updated_at'
      and c.relname in (
        'kyc_tiers','entity_kyc_levels','verification_submissions',
        'verification_reviews','verification_audit_trail')),
  3,
  'updated_at trigger present on the three mutable verification tables'
);

-- ─── No new SECURITY DEFINER verification function ─────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.proname like 'verification_%'),
  0,
  'no verification_* function is SECURITY DEFINER'
);

-- ─── Realtime excludes all five new tables ────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in (
        'kyc_tiers','entity_kyc_levels','verification_submissions',
        'verification_reviews','verification_audit_trail')),
  0,
  'Realtime excludes all five verification tables'
);

-- ─── Comments present on all five tables ──────────────────────────────────────
select isnt(
  obj_description('public.kyc_tiers'::regclass), null, 'kyc_tiers has a comment');
select isnt(
  obj_description('public.entity_kyc_levels'::regclass), null, 'entity_kyc_levels has a comment');
select isnt(
  obj_description('public.verification_submissions'::regclass), null, 'verification_submissions has a comment');
select isnt(
  obj_description('public.verification_reviews'::regclass), null, 'verification_reviews has a comment');
select isnt(
  obj_description('public.verification_audit_trail'::regclass), null, 'verification_audit_trail has a comment');

-- ─── KYC tiers seeded (4 rows) ────────────────────────────────────────────────
select is(
  (select count(*)::int from public.kyc_tiers),
  4,
  'kyc_tiers seeded with 4 tiers'
);

select * from finish();
rollback;
