-- EP-04-01: Jobs & Applications Schema Posture
--
-- Validates the 3 new jobs tables:
--   - All 3 tables exist; RLS enabled on all 3.
--   - anon has zero INSERT/UPDATE/DELETE grants on the 3 tables.
--   - authenticated has SELECT+INSERT+UPDATE on jobs/job_applications
--     (writes RPC-only, RLS-restricted), SELECT+INSERT on job_events
--     (append-only, no UPDATE/DELETE).
--   - CHECK vocabularies (status, title/description length, budget range,
--     currency, cover note, quoted amount, event_type), unique constraints,
--     named indexes, triggers.
--   - No jobs/application SECURITY DEFINER; exactly 10 job_% + 6
--     application_% RPCs.
--   - Realtime excludes all 3 tables; comments present.
--   - EXECUTE posture: anon zero, authenticated 16, service_role 16.

begin;
set search_path to extensions, public;
select plan(37);

-- ─── 0. All 3 tables exist ─────────────────────────────────────────────────
select has_table('public', 'jobs', 'jobs exists');
select has_table('public', 'job_applications', 'job_applications exists');
select has_table('public', 'job_events', 'job_events exists');

-- ─── 1. RLS enabled on all 3 ───────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('jobs', 'job_applications', 'job_events')
      and c.relrowsecurity),
  3,
  'RLS enabled on all 3 jobs tables'
);

-- ─── 2. anon has zero write grants on the 3 tables ─────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name in ('jobs', 'job_applications', 'job_events')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'anon has no INSERT/UPDATE/DELETE grants on the jobs tables'
);

-- ─── 3. authenticated has INSERT/UPDATE on jobs via RPC (RLS-restricted) ───
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'jobs'
      and privilege_type in ('INSERT', 'UPDATE')),
  2,
  'authenticated has INSERT+UPDATE on jobs for RPC'
);

-- ─── 4. authenticated has INSERT/UPDATE on job_applications via RPC ────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'job_applications'
      and privilege_type in ('INSERT', 'UPDATE')),
  2,
  'authenticated has INSERT+UPDATE on job_applications for RPC'
);

-- ─── 5. job_events has no UPDATE/DELETE grants (append-only) ───────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee in ('anon', 'authenticated', 'service_role')
      and table_schema = 'public'
      and table_name = 'job_events'
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'job_events has no UPDATE/DELETE grants (append-only)'
);

-- ─── 6-11. jobs CHECK constraints ──────────────────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.jobs'::regclass and contype = 'c'
      and conname = 'jobs_title_length'),
  1, 'jobs title CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.jobs'::regclass and contype = 'c'
      and conname = 'jobs_description_length'),
  1, 'jobs description CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.jobs'::regclass and contype = 'c'
      and conname = 'jobs_status_allowed'),
  1, 'jobs status CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.jobs'::regclass and contype = 'c'
      and conname = 'jobs_budget_range'),
  1, 'jobs budget range CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.jobs'::regclass and contype = 'c'
      and conname = 'jobs_currency_format'),
  1, 'jobs currency format CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.jobs'::regclass and contype = 'c'
      and conname = 'jobs_applications_count_nonneg'),
  1, 'jobs applications count CHECK exists'
);

-- ─── 12-15. job_applications CHECKs + unique ───────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_applications'::regclass and contype = 'c'
      and conname = 'job_applications_cover_note_length'),
  1, 'job_applications cover note CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_applications'::regclass and contype = 'c'
      and conname = 'job_applications_quoted_amount_positive'),
  1, 'job_applications quoted amount CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_applications'::regclass and contype = 'c'
      and conname = 'job_applications_status_allowed'),
  1, 'job_applications status CHECK exists'
);
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_applications'::regclass and contype = 'u'
      and conname = 'job_applications_one_per_professional'),
  1, 'job_applications one-per-professional UNIQUE exists'
);

-- ─── 16b. job_applications owner denormalization ───────────────────────────
select is(
  (select count(*)::int
     from information_schema.columns
    where table_schema = 'public'
      and table_name = 'job_applications'
      and column_name = 'client_entity_id'),
  1,
  'job_applications.client_entity_id column exists (acyclic RLS owner scope)'
);

-- ─── 16. job_events type CHECK ─────────────────────────────────────────────
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.job_events'::regclass and contype = 'c'
      and conname = 'job_events_type_allowed'),
  1, 'job_events type CHECK exists'
);

-- ─── 17. jobs indexes (5) ──────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'jobs'
      and indexname in (
        'jobs_client_idx',
        'jobs_status_created_idx',
        'jobs_profession_idx',
        'jobs_search_vector_idx',
        'jobs_created_at_idx'
      )),
  5,
  'the 5 jobs indexes exist'
);

-- ─── 18. job_applications indexes (3) ──────────────────────────────────────
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'job_applications'
      and indexname in (
        'job_applications_job_idx',
        'job_applications_professional_idx',
        'job_applications_status_idx'
      )),
  3,
  'the 3 job_applications indexes exist'
);

-- ─── 19. job_events index (1) ──────────────────────────────────────────────
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'job_events'
      and indexname = 'job_events_job_idx'),
  1,
  'the job_events index exists'
);

-- ─── 20. updated_at triggers on jobs + job_applications ────────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and not t.tgisinternal
      and t.tgname in ('jobs_set_updated_at', 'job_applications_set_updated_at')),
  2,
  'the 2 updated_at triggers exist (jobs + job_applications)'
);

-- ─── 21. search vector trigger ─────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
    where c.oid = 'public.jobs'::regclass
      and not t.tgisinternal
      and t.tgname = 'jobs_search_vector_trigger'),
  1,
  'the jobs search vector trigger exists'
);

-- ─── 22. applications count trigger ────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
    where c.oid = 'public.job_applications'::regclass
      and not t.tgisinternal
      and t.tgname = 'job_applications_count_trigger'),
  1,
  'the job_applications count trigger exists'
);

-- ─── 23. job_events has no updated_at trigger (append-only) ────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
    where c.oid = 'public.job_events'::regclass
      and not t.tgisinternal
      and t.tgname like '%updated_at%'),
  0,
  'job_events has no updated_at trigger (append-only)'
);

-- ─── 24. No jobs/application SECURITY DEFINER ──────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.proname like 'job\_%' or p.proname like 'application\_%')
      and p.prosecdef),
  0,
  'no job/application function is SECURITY DEFINER'
);

-- ─── 25. Exactly 10 job_% RPCs ─────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'job\_%'
      and p.prorettype = 'jsonb'::regtype),
  10,
  'exactly 10 job_% RPCs exist'
);

-- ─── 26. Exactly 6 application_% RPCs ──────────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'application\_%'
      and p.prorettype = 'jsonb'::regtype),
  6,
  'exactly 6 application_% RPCs exist'
);

-- ─── 27. Realtime excludes all 3 tables ────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('jobs', 'job_applications', 'job_events')),
  0,
  'Realtime excludes all 3 jobs tables'
);

-- ─── 28. All 3 tables have comments ────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('jobs', 'job_applications', 'job_events')
      and obj_description(c.oid, 'pg_class') is not null),
  3,
  'all 3 jobs tables have comments'
);

-- ─── 29. anon EXECUTE: zero on jobs RPCs ───────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and (routine_name like 'job\_%' or routine_name like 'application\_%')
      and grantee = 'anon'),
  0,
  'anon can execute zero jobs RPCs'
);

-- ─── 30. authenticated EXECUTE on all 16 ───────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and (routine_name like 'job\_%' or routine_name like 'application\_%')
      and grantee = 'authenticated'),
  16,
  'authenticated can execute all 16 jobs RPCs'
);

-- ─── 31. service_role EXECUTE on all 16 ────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and (routine_name like 'job\_%' or routine_name like 'application\_%')
      and grantee = 'service_role'),
  16,
  'service_role can execute all 16 jobs RPCs'
);

-- ─── 32. RLS policy surface: 8 policies ────────────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename in ('jobs', 'job_applications', 'job_events')),
  8,
  '8 RLS policies on the 3 jobs tables (3 + 3 + 2)'
);

-- ─── 33. jobs_select policy exists ─────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'jobs'
      and policyname = 'jobs_select'
      and cmd = 'SELECT'),
  1,
  'jobs_select policy exists'
);

select * from finish();
rollback;
