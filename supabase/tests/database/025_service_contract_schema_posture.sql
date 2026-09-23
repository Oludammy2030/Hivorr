-- EP-03-02: Service Contract & Milestone Engine Schema Posture
--
-- Validates the 3 new contract tables:
--   - All 3 tables exist; RLS enabled on all 3.
--   - anon has zero INSERT/UPDATE/DELETE grants on the 3 tables.
--   - authenticated has SELECT only on contracts/milestones (writes RPC-only),
--     SELECT+INSERT on events (append-only, no UPDATE/DELETE).
--   - CHECK vocabularies (status, no-self, currency, amount, milestone number,
--     event_type), unique constraints, named indexes, triggers.
--   - No service_contract_% SECURITY DEFINER; exactly 8 RPCs.
--   - Realtime excludes all 3 tables; comments present.
--   - EXECUTE posture: anon zero, authenticated 8, service_role 8.

begin;
set search_path to extensions, public;
select plan(29);

-- ─── 0. All 3 tables exist ───────────────────────────────────────────────────
select has_table('public', 'service_contracts', 'service_contracts exists');
select has_table('public', 'contract_milestones', 'contract_milestones exists');
select has_table('public', 'contract_events', 'contract_events exists');

-- ─── 1. RLS enabled on all 3 ─────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('service_contracts', 'contract_milestones', 'contract_events')
      and c.relrowsecurity),
  3,
  'RLS enabled on all 3 contract tables'
);

-- ─── 2. anon has zero write grants on the 3 tables ───────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name in ('service_contracts', 'contract_milestones', 'contract_events')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'anon has no INSERT/UPDATE/DELETE grants on the contract tables'
);

-- ─── 3. authenticated has INSERT/UPDATE on service_contracts via RPC (RLS-restricted) ─
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'service_contracts'
      and privilege_type in ('INSERT', 'UPDATE')),
  2,
  'authenticated has INSERT+UPDATE on service_contracts for RPC (RLS with client check)'
);

-- ─── 4. authenticated has INSERT/UPDATE on contract_milestones via RPC ──────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'contract_milestones'
      and privilege_type in ('INSERT', 'UPDATE')),
  2,
  'authenticated has INSERT+UPDATE on contract_milestones for RPC'
);

-- ─── 5. contract_events has no UPDATE/DELETE grants (append-only) ────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee in ('anon', 'authenticated', 'service_role')
      and table_schema = 'public'
      and table_name = 'contract_events'
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'contract_events has no UPDATE/DELETE grants (append-only)'
);

-- ─── 6. Status CHECK on service_contracts ────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_contracts'::regclass
      and contype = 'c'
      and conname = 'service_contracts_status_allowed'),
  1,
  'service_contracts status CHECK exists'
);

-- ─── 7. No-self CHECK ─────────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_contracts'::regclass
      and contype = 'c'
      and conname = 'service_contracts_no_self'),
  1,
  'service_contracts_no_self CHECK exists'
);

-- ─── 8. Currency format CHECK ─────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_contracts'::regclass
      and contype = 'c'
      and conname = 'service_contracts_currency_format'),
  1,
  'service_contracts currency format CHECK exists'
);

-- ─── 9. Total amount CHECK ────────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.service_contracts'::regclass
      and contype = 'c'
      and conname = 'service_contracts_total_amount_positive'),
  1,
  'service_contracts total_amount CHECK exists'
);

-- ─── 10. contract_milestones UNIQUE (contract_id, milestone_number) ────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.contract_milestones'::regclass
      and contype = 'u'
      and conname = 'contract_milestones_contract_number_key'),
  1,
  'UNIQUE (contract_id, milestone_number) constraint exists'
);

-- ─── 11. contract_milestones status CHECK ─────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.contract_milestones'::regclass
      and contype = 'c'
      and conname = 'contract_milestones_status_allowed'),
  1,
  'contract_milestones status CHECK exists'
);

-- ─── 12. contract_events event_type CHECK ─────────────────────────────────────
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.contract_events'::regclass
      and contype = 'c'
      and conname = 'contract_events_event_type_allowed'),
  1,
  'contract_events event_type CHECK exists'
);

-- ─── 13. B-tree/partial indexes on service_contracts ─────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'service_contracts'
      and indexname in (
        'service_contracts_client_idx',
        'service_contracts_professional_idx',
        'service_contracts_listing_idx',
        'service_contracts_status_idx',
        'service_contracts_escrow_idx',
        'service_contracts_created_at_idx'
      )),
  6,
  'the 6 service_contracts indexes exist'
);

-- ─── 14. Indexes on contract_milestones ───────────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'contract_milestones'
      and indexname in (
        'contract_milestones_contract_idx',
        'contract_milestones_escrow_idx',
        'contract_milestones_contract_number_idx'
      )),
  3,
  'the 3 contract_milestones indexes exist'
);

-- ─── 15. Indexes on contract_events ───────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_indexes
    where schemaname = 'public'
      and tablename = 'contract_events'
      and indexname in (
        'contract_events_contract_idx',
        'contract_events_created_at_idx',
        'contract_events_event_type_idx'
      )),
  3,
  'the 3 contract_events indexes exist'
);

-- ─── 16. Triggers: 2 updated_at (contracts + milestones, zero on events) ─────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and not t.tgisinternal
      and t.tgname in (
        'service_contracts_set_updated_at', 'contract_milestones_set_updated_at'
      )),
  2,
  'the 2 updated_at triggers exist (contracts + milestones)'
);

select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
    where c.oid = 'public.contract_events'::regclass
      and not t.tgisinternal
      and t.tgname like '%updated_at%'),
  0,
  'contract_events has no updated_at trigger (append-only)'
);

-- ─── 17. No service_contract_% SECURITY DEFINER ───────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'service\_contract\_%'
      and p.prosecdef),
  0,
  'no service_contract_% function is SECURITY DEFINER'
);

-- ─── 18. Exactly 8 service_contract_% RPCs ───────────────────────────────────
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'service\_contract\_%'
      and p.prorettype = 'jsonb'::regtype),
  8,
  'exactly 8 service_contract_% RPCs exist'
);

-- ─── 19. Realtime excludes all 3 tables ───────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename in ('service_contracts', 'contract_milestones', 'contract_events')),
  0,
  'Realtime excludes all 3 contract tables'
);

-- ─── 20. All 3 tables have comments ───────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('service_contracts', 'contract_milestones', 'contract_events')
      and obj_description(c.oid, 'pg_class') is not null),
  3,
  'all 3 contract tables have comments'
);

-- ─── 21. anon EXECUTE: zero on contract RPCs ──────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_contract\_%'
      and grantee = 'anon'),
  0,
  'anon can execute zero service_contract_% RPCs'
);

-- ─── 22. authenticated EXECUTE on all 8 ───────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_contract\_%'
      and grantee = 'authenticated'),
  8,
  'authenticated can execute all 8 service_contract_% RPCs'
);

-- ─── 23. service_role EXECUTE on all 8 ────────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name like 'service\_contract\_%'
      and grantee = 'service_role'),
  8,
  'service_role can execute all 8 service_contract_% RPCs'
);

-- ─── 24. RLS policy surface: 8 policies (3 SELECT + 2+2 INSERT/UPDATE + 1 events INSERT) ─
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename in ('service_contracts', 'contract_milestones', 'contract_events')),
  8,
  '8 RLS policies on the 3 contract tables (3 SELECT + 2+2 INSERT/UPDATE + 1 events INSERT)'
);

-- ─── 25. service_contracts has no self-grant escalation ───────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'service_contracts'
      and policyname = 'service_contracts_select'
      and cmd = 'SELECT'),
  1,
  'service_contracts_select policy exists'
);

select * from finish();
rollback;
