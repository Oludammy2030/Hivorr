-- EP-02-05: Dispute Schema Posture
--
-- Validates the 4 new dispute tables (EP-02-05 Plan §14.1):
--   - All 4 tables exist; RLS enabled on all 4.
--   - anon has zero grants on all 4 tables.
--   - dispute_cases.status/resolved_at/closed_at/withdrawn_at not writable by authenticated.
--   - dispute_evidence / dispute_resolutions / dispute_audit_trail: no UPDATE/DELETE
--     grant to any client role (immutable / append-only).
--   - 1 mutable table (dispute_cases) carries the _set_updated_at trigger.
--   - Exactly 3 dispute_% functions are SECURITY DEFINER (2 hold helpers + dispute_withdraw);
--     the other 5 RPCs are not.
--   - No financial_% function is SECURITY DEFINER (013 regression guard).
--   - Realtime excludes all 4 tables.
--   - All 4 tables have comments; partial unique index exists; exactly 8 dispute_ functions.

begin;
set search_path to extensions, public;
select plan(19);

-- ─── 0. All 4 tables exist ────────────────────────────────────────────────────
select has_table('public', 'dispute_cases', 'dispute_cases exists');
select has_table('public', 'dispute_evidence', 'dispute_evidence exists');
select has_table('public', 'dispute_resolutions', 'dispute_resolutions exists');
select has_table('public', 'dispute_audit_trail', 'dispute_audit_trail exists');

-- ─── 1. RLS enabled on all 4 ──────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname like 'dispute_%'
      and c.relrowsecurity),
  4,
  'RLS enabled on all 4 dispute tables'
);

-- ─── 2. anon has zero grants on all 4 tables ──────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name like 'dispute_%'),
  0,
  'anon has no grants on the dispute tables'
);

-- ─── 3. dispute_cases server-controlled columns not writable by authenticated ──
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'dispute_cases'
      and column_name in ('status', 'resolved_at', 'closed_at', 'withdrawn_at')
      and privilege_type in ('INSERT', 'UPDATE')),
  0,
  'dispute_cases.status/resolved_at/closed_at/withdrawn_at not writable by authenticated'
);

-- ─── 4. dispute_evidence: no UPDATE/DELETE to any client role ──────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'dispute_evidence'
      and grantee in ('anon', 'authenticated', 'service_role')
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'dispute_evidence has no UPDATE/DELETE grant to anon/authenticated/service_role'
);

-- ─── 5. dispute_resolutions: no UPDATE/DELETE to any client role ──────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'dispute_resolutions'
      and grantee in ('anon', 'authenticated', 'service_role')
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'dispute_resolutions has no UPDATE/DELETE grant to anon/authenticated/service_role'
);

-- ─── 6. dispute_audit_trail: no UPDATE/DELETE to any client role ──────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'dispute_audit_trail'
      and grantee in ('anon', 'authenticated', 'service_role')
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'dispute_audit_trail has no UPDATE/DELETE grant to anon/authenticated/service_role'
);

-- ─── 7. Exactly 1 mutable table carries the _set_updated_at trigger ────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'dispute_cases'
      and t.tgname = 'dispute_cases_set_updated_at'
      and not t.tgisinternal),
  1,
  'dispute_cases carries the _set_updated_at trigger'
);

-- ─── 8. Exactly 3 dispute_% functions are SECURITY DEFINER ─────────────────────
select is(
  (select count(*)::int
     from pg_proc
    where proname like 'dispute_%' and prosecdef),
  3,
  'exactly 3 dispute_% functions are SECURITY DEFINER (2 hold helpers + dispute_withdraw)'
);

-- ─── 9. No financial_% function is SECURITY DEFINER (013 regression) ───────────
select is(
  (select count(*)::int
     from pg_proc
    where proname like 'financial_%' and prosecdef),
  0,
  'no financial_% function is SECURITY DEFINER'
);

-- ─── 10. Realtime excludes all 4 dispute tables ───────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename like 'dispute_%'),
  0,
  'Realtime excludes all 4 dispute tables'
);

-- ─── 11. All 4 tables have comments ───────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname like 'dispute_%'
      and obj_description(c.oid, 'pg_class') is not null),
  4,
  'all 4 dispute tables have comments'
);

-- ─── 12. Partial unique index prevents concurrent active disputes ─────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and indexname = 'dispute_cases_one_open_per_escrow_idx'),
  1,
  'partial unique index dispute_cases_one_open_per_escrow_idx exists'
);

-- ─── 13. Exactly 8 dispute_ functions exist ───────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc
    where proname like 'dispute_%' and prorettype <> 'trigger'::regtype),
  8,
  'exactly 8 dispute_ functions exist (6 RPCs + 2 helpers)'
);

-- ─── 14. Exactly 5 RPCs are NOT SECURITY DEFINER (dispute_withdraw is DEFINER) ─
select is(
  (select count(*)::int
     from pg_proc
    where proname in ('dispute_file', 'dispute_submit_evidence', 'dispute_resolve',
                      'dispute_get', 'dispute_list')
      and prosecdef),
  0,
  'the 5 client RPCs (file/submit_evidence/resolve/get/list) are not SECURITY DEFINER'
);

-- ─── 15. dispute_withdraw IS SECURITY DEFINER (approved deviation) ─────────────
select is(
  (select count(*)::int
     from pg_proc
    where proname = 'dispute_withdraw' and prosecdef),
  1,
  'dispute_withdraw is SECURITY DEFINER (updates server-controlled status)'
);

select * from finish();
rollback;
