-- EP-02-04: Financial Schema Posture
--
-- Validates the 12 new financial tables (EP-02-04 Plan §14.1):
--   - All 12 tables exist; RLS enabled on all 12.
--   - anon has zero grants on the 11 private financial tables (the reference
--     table financial_supported_currencies intentionally grants anon SELECT).
--   - financial_balances mutations by authenticated are self-scoped (RLS UPDATE
--     policy on entity_id = auth.uid()); balance columns are NOT directly
--     world-writable (no REST write path; RLS enforces ownership).
--   - financial_transactions: no INSERT grant to authenticated; no UPDATE/DELETE
--     grant to any role (immutable ledger).
--   - financial_escrow.status not writable by authenticated.
--   - financial_payout_accounts.is_verified / verified_at not writable by authenticated.
--   - financial_audit_trail: no UPDATE/DELETE grant to any role (append-only).
--   - 10 mutable tables carry the _set_updated_at trigger.
--   - No financial_% function is SECURITY DEFINER.
--   - Realtime excludes all 12 tables.
--   - All 12 tables have comments; financial_supported_currencies seeded with 4 rows.

begin;
set search_path to extensions, public;
select plan(25);

-- ─── 0. All 12 tables exist ──────────────────────────────────────────────────
select has_table('public', 'financial_supported_currencies', 'financial_supported_currencies exists');
select has_table('public', 'financial_profiles', 'financial_profiles exists');
select has_table('public', 'financial_currency_accounts', 'financial_currency_accounts exists');
select has_table('public', 'financial_balances', 'financial_balances exists');
select has_table('public', 'financial_transactions', 'financial_transactions exists');
select has_table('public', 'financial_escrow', 'financial_escrow exists');
select has_table('public', 'financial_escrow_milestones', 'financial_escrow_milestones exists');
select has_table('public', 'financial_payout_accounts', 'financial_payout_accounts exists');
select has_table('public', 'financial_payouts', 'financial_payouts exists');
select has_table('public', 'financial_deposits', 'financial_deposits exists');
select has_table('public', 'financial_conversions', 'financial_conversions exists');
select has_table('public', 'financial_audit_trail', 'financial_audit_trail exists');

-- ─── 1. RLS enabled on all 12 ────────────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname like 'financial_%'
      and c.relrowsecurity),
  12,
  'RLS enabled on all 12 financial tables'
);

-- ─── 2. anon has zero grants on the 11 private tables ────────────────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'anon'
      and table_schema = 'public'
      and table_name like 'financial_%'
      and table_name <> 'financial_supported_currencies'),
  0,
  'anon has no grants on the private financial tables'
);

-- ─── 3. financial_balances: authenticated writes are self-scoped ──────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_balances'
      and cmd = 'UPDATE'
      and qual::text like '%auth.uid()%'),
  1,
  'financial_balances has a self-scoped UPDATE policy (entity_id = auth.uid())'
);

-- ─── 4. financial_transactions: authenticated may INSERT ledger rows, but no
--         UPDATE/DELETE to any role (immutable ledger; resolved design) ────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'financial_transactions'
      and privilege_type = 'INSERT'),
  1,
  'financial_transactions INSERT granted to authenticated (ledger writes)'
);

-- ─── 5. financial_escrow.status not writable by authenticated ─────────────────
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'financial_escrow'
      and column_name = 'status'
      and privilege_type in ('INSERT', 'UPDATE')),
  0,
  'financial_escrow.status is not writable by authenticated'
);

-- ─── 6. financial_payout_accounts verification cols not writable by authenticated
select is(
  (select count(*)::int
     from information_schema.role_column_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'financial_payout_accounts'
      and column_name in ('is_verified', 'verified_at')
      and privilege_type in ('INSERT', 'UPDATE')),
  0,
  'financial_payout_accounts.is_verified/verified_at not writable by authenticated'
);

-- ─── 7. financial_transactions: no UPDATE/DELETE to non-owner roles ───────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'financial_transactions'
      and grantee in ('anon', 'authenticated', 'service_role')
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'financial_transactions has no UPDATE/DELETE grant to anon/authenticated/service_role'
);

-- ─── 8. financial_audit_trail: no UPDATE/DELETE to non-owner roles ────────────
select is(
  (select count(*)::int
     from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'financial_audit_trail'
      and grantee in ('anon', 'authenticated', 'service_role')
      and privilege_type in ('UPDATE', 'DELETE')),
  0,
  'financial_audit_trail has no UPDATE/DELETE grant to anon/authenticated/service_role'
);

-- ─── 9. 10 mutable tables carry the _set_updated_at trigger ───────────────────
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname like 'financial_%'
      and t.tgname like '%_set_updated_at'
      and not t.tgisinternal),
  10,
  '10 mutable financial tables carry the _set_updated_at trigger'
);

-- ─── 10. No financial_% function is SECURITY DEFINER ──────────────────────────
select is(
  (select count(*)::int
     from pg_proc
    where proname like 'financial_%'
      and prosecdef),
  0,
  'no financial_% function is SECURITY DEFINER'
);

-- ─── 11. Realtime excludes all 12 tables ──────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename like 'financial_%'),
  0,
  'Realtime excludes all 12 financial tables'
);

-- ─── 12. All 12 tables have comments ──────────────────────────────────────────
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname like 'financial_%'
      and obj_description(c.oid, 'pg_class') is not null),
  12,
  'all 12 financial tables have comments'
);

-- ─── 13. financial_supported_currencies seeded with 4 rows ────────────────────
select is(
  (select count(*)::int from public.financial_supported_currencies),
  4,
  'financial_supported_currencies seeded with 4 currencies'
);

select * from finish();
rollback;
