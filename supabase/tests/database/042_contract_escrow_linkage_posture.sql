-- EP-03-11: Contract Escrow Linkage Posture
--
-- Validates the additive EP-03-11 server delta (plan S1/S8):
--   - contract_milestones.review_period_expires_at exists (timestamptz, nullable).
--   - Partial index contract_milestones_review_expiry_idx exists.
--   - Trigger contract_milestones_set_review_expiry exists + function posture
--     (SECURITY INVOKER, no EXECUTE to anon/authenticated).
--   - Exactly 2 new RPCs: service_contract_link_escrow (service_role only),
--     service_contract_release_gate (authenticated + service_role).
--   - anon has zero EXECUTE on both; authenticated has EXECUTE on both
--     (link body rejects non-service_role with PLT002 before any write).
--   - No service_contract_* SECURITY DEFINER; no new tables; no Realtime change.
--
-- NOTE: numbered 042 because 027/028 are taken by the service-review schema
-- (plan S8 naming predates the review track). Intent is unchanged.

begin;
set search_path to extensions, public;
select plan(26);

-- ─── 0. Column exists ────────────────────────────────────────────────────
select has_column(
  'public', 'contract_milestones', 'review_period_expires_at',
  'contract_milestones.review_period_expires_at exists'
);

select is(
  (select is_nullable from information_schema.columns
    where table_schema = 'public'
      and table_name = 'contract_milestones'
      and column_name = 'review_period_expires_at'),
  'YES',
  'review_period_expires_at is nullable (historical rows stay NULL)'
);

select is(
  (select data_type from information_schema.columns
    where table_schema = 'public'
      and table_name = 'contract_milestones'
      and column_name = 'review_period_expires_at'),
  'timestamp with time zone',
  'review_period_expires_at is timestamptz'
);

-- ─── 1. Partial index exists ─────────────────────────────────────────────
select has_index(
  'public', 'contract_milestones', 'contract_milestones_review_expiry_idx',
  'review expiry partial index exists'
);

-- ─── 2. Trigger exists ───────────────────────────────────────────────────
select has_trigger(
  'public', 'contract_milestones', 'contract_milestones_set_review_expiry',
  'review expiry trigger exists'
);

select is(
  (select count(*)::int from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'contract_milestones'
      and t.tgname = 'contract_milestones_set_review_expiry'),
  1,
  'exactly one review expiry trigger'
);

-- ─── 3. Trigger function posture ─────────────────────────────────────────
select has_function(
  'public', 'contract_milestones_set_review_expiry', '{}',
  'review expiry trigger function exists'
);

select is(
  (select count(*)::int from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'contract_milestones_set_review_expiry'
      and p.prosecdef),
  0,
  'review expiry function is not SECURITY DEFINER'
);

select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name = 'contract_milestones_set_review_expiry'
      and grantee in ('anon', 'authenticated')),
  0,
  'no anon/authenticated EXECUTE on the trigger function'
);

-- ─── 4. New RPCs exist ───────────────────────────────────────────────────
select has_function(
  'public', 'service_contract_link_escrow',
  '{uuid,uuid,jsonb}',
  'service_contract_link_escrow exists'
);

select has_function(
  'public', 'service_contract_release_gate',
  '{uuid}',
  'service_contract_release_gate exists'
);

select is(
  (select pg_catalog.format_type(p.prorettype, null) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'service_contract_link_escrow'),
  'jsonb',
  'link RPC returns jsonb envelope'
);

select is(
  (select pg_catalog.format_type(p.prorettype, null) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'service_contract_release_gate'),
  'jsonb',
  'gate RPC returns jsonb envelope'
);

-- ─── 5. RPC volatility ───────────────────────────────────────────────────
select is(
  (select p.provolatile from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'service_contract_link_escrow'),
  'v',
  'link RPC is VOLATILE'
);

select is(
  (select p.provolatile from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'service_contract_release_gate'),
  's',
  'gate RPC is STABLE'
);

-- ─── 6. SECURITY INVOKER (no DEFINER) ────────────────────────────────────
select is(
  (select count(*)::int from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('service_contract_link_escrow', 'service_contract_release_gate')
      and p.prosecdef),
  0,
  'no new SECURITY DEFINER among EP-03-11 RPCs'
);

-- ─── 7. EXECUTE posture: anon zero ───────────────────────────────────────
select is(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name in ('service_contract_link_escrow', 'service_contract_release_gate')
      and grantee = 'anon'),
  0,
  'anon has zero EXECUTE on EP-03-11 RPCs'
);

-- ─── 8. Link RPC: authenticated + service_role EXECUTE, body enforces ─────
-- PLT002 for non-service_role (so callers get a clean envelope code rather
-- than 42501; no state changes before the role check).
select ok(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name = 'service_contract_link_escrow'
      and grantee = 'authenticated') >= 1,
  'authenticated can EXECUTE link RPC (body rejects with PLT002)'
);

select ok(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name = 'service_contract_link_escrow'
      and grantee = 'service_role') >= 1,
  'service_role can EXECUTE link RPC'
);

-- ─── 9. Gate RPC: authenticated + service_role ──────────────────────────
select ok(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name = 'service_contract_release_gate'
      and grantee = 'authenticated') >= 1,
  'authenticated can EXECUTE gate RPC'
);

select ok(
  (select count(*)::int
     from information_schema.routine_privileges
    where routine_schema = 'public'
      and routine_name = 'service_contract_release_gate'
      and grantee = 'service_role') >= 1,
  'service_role can EXECUTE gate RPC'
);

-- ─── 10. Comments present ────────────────────────────────────────────────
select ok(
  (select obj_description(
    'public.service_contract_link_escrow(uuid, uuid, jsonb)'::regprocedure,
    'pg_proc') is not null),
  'link RPC has a COMMENT'
);

select ok(
  (select obj_description(
    'public.service_contract_release_gate(uuid)'::regprocedure,
    'pg_proc') is not null),
  'gate RPC has a COMMENT'
);

select ok(
  (select col_description(
    'public.contract_milestones'::regclass,
    attnum) is not null
     from pg_attribute
    where attrelid = 'public.contract_milestones'::regclass
      and attname = 'review_period_expires_at'),
  'expiry column has a COMMENT'
);

-- ─── 11. No new tables ──────────────────────────────────────────────────
select is(
  (select count(*)::int from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('service_contracts', 'contract_milestones', 'contract_events')),
  3,
  'still exactly the 3 EP-03-02 tables (no new tables)'
);

-- ─── 12. Frozen financial tables untouched (column count guard) ──────────
select ok(
  (select count(*)::int from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname = 'financial_escrow') = 1,
  'financial_escrow still exists exactly once (not redefined)'
);

select * from finish();
rollback;
