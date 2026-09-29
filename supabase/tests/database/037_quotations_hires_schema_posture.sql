-- EP-04-02: Quotations & Hires Schema Posture
--
-- Validates the 2 new tables plus the additive service_contracts deviation:
--   - job_quotations + hires exist; RLS enabled on both.
--   - anon has zero INSERT/UPDATE/DELETE grants on both.
--   - authenticated has SELECT+INSERT+UPDATE on both (writes RPC-only).
--   - CHECK vocabularies (amount, currency, status, revision, no-self),
--     one-per-job / one-application uniques, one-proposed partial index,
--     named indexes, updated_at triggers.
--   - No quotation/hire SECURITY DEFINER; exactly 3 quotation_% + 5 hire_%
--     RPCs.
--   - Deviation: service_contracts.job_id exists, service_listing_id is
--     nullable, service_contracts_source_xor CHECK + job index exist.
--   - Realtime excludes both tables; comments present.
--   - EXECUTE posture: anon zero, authenticated 8, service_role 8.

begin;
set search_path to extensions, public;
select plan(31);

-- ─── 0. Both tables exist ──────────────────────────────────────────────────
select has_table('public', 'job_quotations', 'job_quotations exists');
select has_table('public', 'hires', 'hires exists');

-- ─── 1. RLS enabled on both ────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('job_quotations', 'hires')
      and c.relrowsecurity),
  2,
  'RLS enabled on both hiring tables'
);

-- ─── 2. anon has zero write grants ─────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name in ('job_quotations', 'hires')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'anon has no INSERT/UPDATE/DELETE grants on the hiring tables'
);

-- ─── 3. authenticated INSERT+UPDATE on job_quotations ──────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'job_quotations'
      and privilege_type in ('INSERT', 'UPDATE')),
  2,
  'authenticated has INSERT+UPDATE on job_quotations for RPC'
);

-- ─── 4. authenticated INSERT+UPDATE on hires ───────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'hires'
      and privilege_type in ('INSERT', 'UPDATE')),
  2,
  'authenticated has INSERT+UPDATE on hires for RPC'
);

-- ─── 5-8. job_quotations CHECKs ────────────────────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_quotations'::regclass and contype = 'c'
      and conname = 'job_quotations_amount_positive'),
  1, 'job_quotations amount CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_quotations'::regclass and contype = 'c'
      and conname = 'job_quotations_currency_format'),
  1, 'job_quotations currency CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_quotations'::regclass and contype = 'c'
      and conname = 'job_quotations_status_allowed'),
  1, 'job_quotations status CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_quotations'::regclass and contype = 'c'
      and conname = 'job_quotations_revision_positive'),
  1, 'job_quotations revision CHECK exists'
);

-- ─── 9-10. hires CHECKs ────────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.hires'::regclass and contype = 'c'
      and conname = 'hires_status_allowed'),
  1, 'hires status CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.hires'::regclass and contype = 'c'
      and conname = 'hires_no_self'),
  1, 'hires no-self CHECK exists'
);

-- ─── 11-12. hires one-active partial uniques ─────────────────────────────────
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'hires'
      and indexname = 'hires_one_active_per_job_idx'),
  1, 'hires one-active-per-job partial UNIQUE exists'
);
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'hires'
      and indexname = 'hires_one_active_application_idx'),
  1, 'hires one-active-application partial UNIQUE exists'
);

-- ─── 13. One-proposed partial unique index ─────────────────────────────────
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'job_quotations'
      and indexname = 'job_quotations_one_proposed_idx'),
  1,
  'the one-proposed partial unique index exists'
);

-- ─── 14. job_quotations indexes (2) ────────────────────────────────────────
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'job_quotations'
      and indexname in (
        'job_quotations_one_proposed_idx',
        'job_quotations_application_idx'
      )),
  2,
  'the 2 job_quotations indexes exist'
);

-- ─── 15. hires indexes (6) ─────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'hires'
      and indexname in (
        'hires_job_idx',
        'hires_client_idx',
        'hires_professional_idx',
        'hires_contract_idx',
        'hires_one_active_per_job_idx',
        'hires_one_active_application_idx'
      )),
  6,
  'the 6 hires indexes exist'
);

-- ─── 16. updated_at triggers on both ───────────────────────────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and not t.tgisinternal
      and t.tgname in ('job_quotations_set_updated_at', 'hires_set_updated_at')),
  2,
  'the 2 updated_at triggers exist (quotations + hires)'
);

-- ─── 17. No quotation/hire SECURITY DEFINER ────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.proname like 'quotation\_%' or p.proname like 'hire\_%')
      and p.prosecdef),
  0,
  'no quotation/hire function is SECURITY DEFINER'
);

-- ─── 18. Exactly 3 quotation_% RPCs ────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'quotation\_%'
      and p.prorettype = 'jsonb'::regtype),
  3,
  'exactly 3 quotation_% RPCs exist'
);

-- ─── 19. Exactly 5 hire_% RPCs ─────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'hire\_%'
      and p.prorettype = 'jsonb'::regtype),
  5,
  'exactly 5 hire_% RPCs exist'
);

-- ─── 20. Deviation: service_contracts.job_id column exists ─────────────────
select is(
  (select count(*)::int
     from information_schema.columns
    where table_schema = 'public'
      and table_name = 'service_contracts'
      and column_name = 'job_id'),
  1,
  'service_contracts.job_id column exists'
);

-- ─── 21. Deviation: service_listing_id is nullable ─────────────────────────
select is(
  (select is_nullable from information_schema.columns
    where table_schema = 'public'
      and table_name = 'service_contracts'
      and column_name = 'service_listing_id'),
  'YES',
  'service_contracts.service_listing_id is nullable'
);

-- ─── 22. Deviation: exactly-one-source CHECK ───────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.service_contracts'::regclass and contype = 'c'
      and conname = 'service_contracts_source_xor'),
  1,
  'service_contracts source XOR CHECK exists'
);

-- ─── 23. Deviation: job index on service_contracts ─────────────────────────
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'service_contracts'
      and indexname = 'service_contracts_job_idx'),
  1,
  'the service_contracts job index exists'
);

-- ─── 24. Realtime excludes both tables ─────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('job_quotations', 'hires')),
  0,
  'Realtime excludes both hiring tables'
);

-- ─── 25. Both tables have comments ─────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('job_quotations', 'hires')
      and obj_description(c.oid, 'pg_class') is not null),
  2,
  'both hiring tables have comments'
);

-- ─── 26. anon EXECUTE: zero ────────────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and (routine_name like 'quotation\_%' or routine_name like 'hire\_%')
      and grantee = 'anon'),
  0,
  'anon can execute zero hiring RPCs'
);

-- ─── 27. authenticated EXECUTE on all 8 ────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and (routine_name like 'quotation\_%' or routine_name like 'hire\_%')
      and grantee = 'authenticated'),
  8,
  'authenticated can execute all 8 hiring RPCs'
);

-- ─── 28. service_role EXECUTE on all 8 ─────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and (routine_name like 'quotation\_%' or routine_name like 'hire\_%')
      and grantee = 'service_role'),
  8,
  'service_role can execute all 8 hiring RPCs'
);

-- ─── 29. RLS policy surface: 6 policies ────────────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename in ('job_quotations', 'hires')),
  6,
  '6 RLS policies on the 2 hiring tables (3 + 3)'
);

select * from finish();
rollback;
