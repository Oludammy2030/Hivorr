-- EP-03-17: Service Dispute Schema Posture
--
-- Validates the additive contract-linkage objects:
--   - dispute_cases.contract_id nullable FK -> service_contracts(id)
--   - escrow_id relaxed to nullable with escrow-or-contract anchor CHECK
--   - contract + one-open-per-contract indexes
--   - INSERT(contract_id) grant to authenticated (frozen column list preserved)
--   - service_dispute_file / service_dispute_get /
--     service_dispute_list_for_contract exist, INVOKER, granted to
--     authenticated + service_role, denied to anon
--   - freeze trigger (INVOKER) + unfreeze trigger (DEFINER, pinned search_path)
--   - no new financial_% DEFINER; dispute/contract tables stay out of Realtime

begin;
set search_path to extensions, public;
select plan(24);

-- ─── 1. Column + FK + nullability ───────────────────────────────────────────
select has_column('public', 'dispute_cases', 'contract_id', 'dispute_cases.contract_id exists');

select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.dispute_cases'::regclass
      and contype = 'f'
      and confrelid = 'public.service_contracts'::regclass),
  1, 'one FK from dispute_cases to service_contracts');

select is(
  (select is_nullable::text from information_schema.columns
    where table_schema = 'public' and table_name = 'dispute_cases'
      and column_name = 'escrow_id'),
  'YES', 'dispute_cases.escrow_id is nullable (unfunded disputes)');

select is(
  (select is_nullable::text from information_schema.columns
    where table_schema = 'public' and table_name = 'dispute_cases'
      and column_name = 'contract_id'),
  'YES', 'dispute_cases.contract_id is nullable (escrow-only rows)');

select ok(
  (select count(*)::int from pg_constraint
    where conname = 'dispute_cases_escrow_or_contract_anchor'
      and conrelid = 'public.dispute_cases'::regclass) = 1,
  'escrow-or-contract anchor CHECK exists');

-- ─── 2. Indexes ─────────────────────────────────────────────────────────────
select ok(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'dispute_cases'
      and indexname = 'dispute_cases_contract_idx') = 1,
  'dispute_cases_contract_idx exists');

select ok(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'dispute_cases'
      and indexname = 'dispute_cases_one_open_per_contract_idx') = 1,
  'one-open-per-contract partial unique index exists');

select ok(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and tablename = 'dispute_cases'
      and indexname = 'dispute_cases_one_open_per_escrow_idx') = 1,
  'legacy one-open-per-escrow index preserved');

-- ─── 3. Column grant (additive) ─────────────────────────────────────────────
select is(
  (select count(*)::int from information_schema.role_column_grants
    where table_schema = 'public' and table_name = 'dispute_cases'
      and column_name = 'contract_id' and grantee = 'authenticated'
      and privilege_type = 'INSERT'),
  1, 'authenticated holds INSERT(contract_id)');

select is(
  (select count(*)::int from information_schema.role_column_grants
    where table_schema = 'public' and table_name = 'dispute_cases'
      and column_name = 'metadata' and grantee = 'authenticated'
      and privilege_type = 'INSERT'),
  1, 'authenticated holds INSERT(metadata) for pre-dispute status');

-- ─── 4. New RPCs exist + execution model ────────────────────────────────────
select has_function('public', 'service_dispute_file', array['uuid', 'text', 'text', 'text', 'text'],
  'service_dispute_file exists');
select has_function('public', 'service_dispute_get', array['uuid'],
  'service_dispute_get exists');
select has_function('public', 'service_dispute_list_for_contract', array['uuid', 'text'],
  'service_dispute_list_for_contract exists');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('service_dispute_file', 'service_dispute_get', 'service_dispute_list_for_contract')
      and p.prosecdef),
  0, 'all three new RPCs are SECURITY INVOKER (zero DEFINER)');

-- ─── 5. Grants: anon denied, authenticated + service_role allowed ───────────
select is(
  (select count(*)::int from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('service_dispute_file', 'service_dispute_get', 'service_dispute_list_for_contract')
      and grantee = 'anon'),
  0, 'anon holds zero EXECUTE on the new RPCs');

select is(
  (select count(*)::int from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('service_dispute_file', 'service_dispute_get', 'service_dispute_list_for_contract')
      and grantee = 'authenticated' and privilege_type = 'EXECUTE'),
  3, 'authenticated holds EXECUTE on all three new RPCs');

select is(
  (select count(*)::int from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('service_dispute_file', 'service_dispute_get', 'service_dispute_list_for_contract')
      and grantee = 'service_role' and privilege_type = 'EXECUTE'),
  3, 'service_role holds EXECUTE on all three new RPCs');

-- ─── 6. Triggers ────────────────────────────────────────────────────────────
select ok(
  (select count(*)::int from pg_trigger
    where tgname = 'service_dispute_contract_freeze') = 1,
  'freeze trigger exists on dispute_cases');

select ok(
  (select count(*)::int from pg_trigger
    where tgname = 'service_dispute_contract_unfreeze') = 1,
  'unfreeze trigger exists on dispute_cases');

select is(
  (select prosecdef from pg_proc where proname = 'service_dispute_contract_freeze'),
  false, 'freeze helper is SECURITY INVOKER');

select is(
  (select prosecdef from pg_proc where proname = 'service_dispute_contract_unfreeze'),
  true, 'unfreeze helper is SECURITY DEFINER');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'financial_%' and p.prosecdef),
  0, 'no financial_% SECURITY DEFINER introduced');

-- ─── 7. Realtime + documentation ────────────────────────────────────────────
select is(
  (select count(*)::int from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename in ('dispute_cases', 'dispute_evidence', 'dispute_resolutions',
                        'dispute_audit_trail', 'service_contracts', 'contract_events')),
  0, 'dispute/contract tables stay out of supabase_realtime');

select ok(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('service_dispute_file', 'service_dispute_get', 'service_dispute_list_for_contract')
      and obj_description(p.oid, 'pg_proc') is not null) = 3,
  'all three new RPCs carry COMMENTs');

select finish();
rollback;
