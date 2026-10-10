-- EP-03-16: Service Earnings Visibility Posture
--
-- Validates the additive EP-03-16 server delta (TIP §7.1/S1–S2):
--   - Exactly 2 new RPCs: service_earnings_summary (STABLE, INVOKER),
--     service_transaction_history (STABLE, INVOKER).
--   - authenticated + service_role hold EXECUTE on both; anon and PUBLIC hold
--     none (earnings are never anonymous).
--   - No SECURITY DEFINER among service_earning* functions; no new tables;
--     the two supporting ledger indexes exist.
--   - One additive participant RLS policy
--     (financial_transactions_earnings_select, source/destination =
--     auth.uid()); no other policy or table change.
--   - No Realtime change (no new tables to publish).

begin;
set search_path to extensions, public;
select plan(20);

-- ─── 0. Functions exist ────────────────────────────────────────────────────
select has_function(
  'public', 'service_earnings_summary', array['character'],
  'service_earnings_summary(char) exists'
);

select has_function(
  'public', 'service_transaction_history',
  array['character', 'jsonb', 'integer', 'jsonb'],
  'service_transaction_history(char, jsonb, integer, jsonb) exists'
);

-- ─── 1. Volatility: STABLE (read-only aggregations) ────────────────────────
select is(
  (select provolatile::text from pg_proc
    where proname = 'service_earnings_summary'
      and pg_function_is_visible(oid)),
  's',
  'service_earnings_summary is STABLE'
);

select is(
  (select provolatile::text from pg_proc
    where proname = 'service_transaction_history'
      and pg_function_is_visible(oid)),
  's',
  'service_transaction_history is STABLE'
);

-- ─── 2. Security: INVOKER (no DEFINER) ─────────────────────────────────────
select is(
  (select prosecdef from pg_proc
    where proname = 'service_earnings_summary'
      and pg_function_is_visible(oid)),
  false,
  'service_earnings_summary is SECURITY INVOKER'
);

select is(
  (select prosecdef from pg_proc
    where proname = 'service_transaction_history'
      and pg_function_is_visible(oid)),
  false,
  'service_transaction_history is SECURITY INVOKER'
);

select is(
  (select count(*)::int from pg_proc
    where proname like 'service_earning%' and prosecdef),
  0,
  'no service_earning* function is SECURITY DEFINER'
);

-- ─── 3. EXECUTE grants: authenticated + service_role only ──────────────────
select ok(
  has_function_privilege(
    'authenticated',
    'public.service_earnings_summary(character)', 'execute'),
  'authenticated has EXECUTE on service_earnings_summary'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.service_earnings_summary(character)', 'execute'),
  'service_role has EXECUTE on service_earnings_summary'
);

select ok(
  not has_function_privilege(
    'anon', 'public.service_earnings_summary(character)', 'execute'),
  'anon has no EXECUTE on service_earnings_summary'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.service_transaction_history(character, jsonb, integer, jsonb)',
    'execute'),
  'authenticated has EXECUTE on service_transaction_history'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.service_transaction_history(character, jsonb, integer, jsonb)',
    'execute'),
  'service_role has EXECUTE on service_transaction_history'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.service_transaction_history(character, jsonb, integer, jsonb)',
    'execute'),
  'anon has no EXECUTE on service_transaction_history'
);

select ok(
  not has_function_privilege(
    'public', 'public.service_earnings_summary(character)', 'execute'),
  'no PUBLIC execute grant on service_earnings_summary'
);

select ok(
  not has_function_privilege(
    'public',
    'public.service_transaction_history(character, jsonb, integer, jsonb)',
    'execute'),
  'no PUBLIC execute grant on service_transaction_history'
);

-- ─── 4. Supporting ledger indexes exist ────────────────────────────────────
select has_index(
  'public', 'financial_transactions',
  'financial_transactions_entity_currency_created_idx',
  'entity/currency/cursor ledger index exists'
);

select has_index(
  'public', 'financial_transactions',
  'financial_transactions_destination_currency_idx',
  'destination/currency ledger index exists'
);

-- ─── 5. No new tables ──────────────────────────────────────────────────────
select is(
  (select count(*)::int from information_schema.tables
    where table_schema = 'public'
      and table_name like 'service_earning%'),
  0,
  'no service_earning* tables created (read-only over existing ledger)'
);

-- ─── 6. Participant ledger visibility policy (approved RLS note) ───────────
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_transactions'
      and policyname = 'financial_transactions_earnings_select'),
  1,
  'financial_transactions_earnings_select policy exists'
);

select ok(
  (select qual like '%destination_entity_id = auth.uid()%'
     and qual like '%source_entity_id = auth.uid()%'
     and qual not like '%true%'
    from pg_policies
   where schemaname = 'public'
     and tablename = 'financial_transactions'
     and policyname = 'financial_transactions_earnings_select'),
  'earnings policy is participant-scoped (source/destination = auth.uid())'
);

select * from finish();
rollback;
