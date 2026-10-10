-- EP-03-16: Service Earnings Visibility Enforcement
--
-- Validates the read-only earnings RPCs against real rows (TIP §7.1, DoD §7):
--   - anon cannot call either RPC (42501).
--   - bad currency -> PLT003; limit outside [1,50] -> PLT005; bad cursor ->
--     PLT005; bad filter type -> PLT003; unknown/non-participant contract ->
--     PLT004 (no oracle).
--   - Payee summary: lifetime_earned from inbound escrow_release rows,
--     release_count, completed_contracts, 6 month buckets, per-currency
--     balances; stranger sees zeros with 6 buckets.
--   - History: caller-touching rows only (A sees 1 release row, B sees
--     fund + release), directions in/out/self, type filters, keyset
--     pagination without overlap, frozen flag after dispute.
--
-- Fixtures: A (professional, trade-verified) publishes a listing; B (client)
-- offers a 30000 NGN contract and A accepts; postgres seeds profiles,
-- balances, a funded escrow (B -> A), and fund + release ledger rows in the
-- exact EP-02-04 shapes (release stored under payer entity_id).

begin;
set search_path to extensions, public;
select plan(35);

-- ─── 0. Fixtures ───────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
select set_config('test.b', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
select set_config('test.c', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'earn-a@example.com'),
       (current_setting('test.b')::uuid, 'earn-b@example.com'),
       (current_setting('test.c')::uuid, 'earn-c@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active')
on conflict (id) do nothing;

select set_config('test.prof1',
  (select id::text from public.professions limit 1), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- Listing + contract as A (professional) / B (client).
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.l1', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Earnings Visibility Fixture Service',
  'Read-only earnings aggregation fixture with milestone escrow linkage and ledger coverage.',
  'fixed', 10000, 30000)->'data'->>'id'), true);

select public.service_listing_publish(current_setting('test.l1')::uuid);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select set_config('test.c1', (select public.service_contract_offer(
  current_setting('test.l1')::uuid,
  30000,
  'NGN',
  '[{"milestone_number": 1, "title": "First earning milestone", "amount": 10000},
    {"milestone_number": 2, "title": "Second earning milestone", "amount": 10000},
    {"milestone_number": 3, "title": "Third earning milestone", "amount": 10000}]'::jsonb,
  null)->'data'->'contract'->>'id'), true);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select public.service_contract_accept(current_setting('test.c1')::uuid);

-- Ledger fixtures as postgres (exact EP-02-04 shapes).
set role postgres;

insert into public.financial_profiles (entity_id, default_currency)
values (current_setting('test.a')::uuid, 'NGN'),
       (current_setting('test.b')::uuid, 'NGN')
on conflict (entity_id) do nothing;

select set_config('test.pa',
  (select id::text from public.financial_profiles where entity_id = current_setting('test.a')::uuid), true);
select set_config('test.pb',
  (select id::text from public.financial_profiles where entity_id = current_setting('test.b')::uuid), true);

insert into public.financial_balances
  (financial_profile_id, entity_id, currency_code, available_balance, held_balance)
values (current_setting('test.pa')::uuid, current_setting('test.a')::uuid, 'NGN', 10000, 0),
       (current_setting('test.pb')::uuid, current_setting('test.b')::uuid, 'NGN', 70000, 20000)
on conflict (entity_id, currency_code) do update
  set available_balance = excluded.available_balance,
      held_balance = excluded.held_balance;

insert into public.financial_escrow
  (financial_profile_id, payer_entity_id, payee_entity_id, currency_code,
   total_amount, released_amount, status)
values (current_setting('test.pb')::uuid, current_setting('test.b')::uuid,
        current_setting('test.a')::uuid, 'NGN', 30000, 10000, 'funded')
returning id;

select set_config('test.e1', (select id::text from public.financial_escrow
  where payer_entity_id = current_setting('test.b')::uuid
    and payee_entity_id = current_setting('test.a')::uuid
  order by created_at desc limit 1), true);

update public.service_contracts
   set escrow_id = current_setting('test.e1')::uuid
 where id = current_setting('test.c1')::uuid;

insert into public.financial_transactions
  (financial_profile_id, entity_id, transaction_type, currency_code, amount,
   source_entity_id, destination_entity_id, debit_balance_type, credit_balance_type,
   reference_type, reference_id, description)
values
  (current_setting('test.pb')::uuid, current_setting('test.b')::uuid, 'escrow_fund', 'NGN', 30000,
   current_setting('test.b')::uuid, current_setting('test.b')::uuid, 'available', 'held',
   'escrow', current_setting('test.e1')::uuid, 'Escrow funded'),
  (current_setting('test.pb')::uuid, current_setting('test.b')::uuid, 'escrow_release', 'NGN', 10000,
   current_setting('test.b')::uuid, current_setting('test.a')::uuid, 'held', 'available',
   'escrow', current_setting('test.e1')::uuid, 'Milestone released');

-- ─── 1. anon cannot call either RPC (42501) ────────────────────────────────
set role anon;

select throws_ok(
  $$ select public.service_earnings_summary('NGN') $$,
  '42501', null,
  'anon service_earnings_summary is denied'
);

select throws_ok(
  $$ select public.service_transaction_history('NGN', '{}'::jsonb, 20, null) $$,
  '42501', null,
  'anon service_transaction_history is denied'
);

-- ─── 2. Validation errors ──────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok(
  $$ select public.service_earnings_summary('XX') $$,
  'P0001', 'PLT003: Currency is not supported.',
  'unsupported currency fails PLT003'
);

select throws_ok(
  $$ select public.service_transaction_history('NGN', '{"type":"bogus"}'::jsonb, 20, null) $$,
  'P0001', 'PLT003: Invalid history filter type.',
  'invalid filter type fails PLT003'
);

select throws_ok(
  $$ select public.service_transaction_history('NGN', '{}'::jsonb, 0, null) $$,
  'P0001', 'PLT005: Limit must be between 1 and 50.',
  'limit 0 fails PLT005'
);

select throws_ok(
  $$ select public.service_transaction_history('NGN', '{}'::jsonb, 51, null) $$,
  'P0001', 'PLT005: Limit must be between 1 and 50.',
  'limit 51 fails PLT005'
);

select throws_ok(
  $$ select public.service_transaction_history('NGN', '{}'::jsonb, 20, '{"created_at":"not-a-date"}'::jsonb) $$,
  'P0001', 'PLT005: Invalid pagination cursor.',
  'malformed cursor fails PLT005'
);

select throws_ok(
  $$ select public.service_transaction_history(
       'NGN',
       '{"contract_id":"00000000-0000-0000-0000-000000000000"}'::jsonb, 20, null) $$,
  'P0001', 'PLT004: Contract not found.',
  'unknown contract filter fails PLT004'
);

-- ─── 3. Payee (A) summary ──────────────────────────────────────────────────
select is(
  (select public.service_earnings_summary('NGN')->>'code'),
  'PLT000',
  'A summary returns PLT000'
);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'available_balance')::numeric),
  10000::numeric,
  'A available_balance is 10000'
);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'lifetime_earned')::numeric),
  10000::numeric,
  'A lifetime_earned is 10000 (inbound release, not payer-side row)'
);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'release_count')::int),
  1,
  'A release_count is 1'
);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'completed_contracts')::int),
  1,
  'A completed_contracts is 1'
);

select is(
  (select jsonb_array_length(public.service_earnings_summary('NGN')->'data'->'monthly')),
  6,
  'A monthly has 6 buckets'
);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'frozen_count')::int),
  0,
  'A frozen_count is 0 before dispute'
);

-- ─── 4. Payer (B) summary ──────────────────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'lifetime_earned')::numeric),
  0::numeric,
  'B lifetime_earned is 0 (payer releases are not earnings)'
);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'held_balance')::numeric),
  20000::numeric,
  'B held_balance is 20000'
);

-- ─── 5. Stranger (C) sees zeros ────────────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);

select is(
  (select public.service_earnings_summary('NGN')->>'code'),
  'PLT000',
  'C summary returns PLT000'
);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'lifetime_earned')::numeric),
  0::numeric,
  'C lifetime_earned is 0 (no cross-user leakage)'
);

select is(
  (select jsonb_array_length(
     public.service_transaction_history('NGN', '{}'::jsonb, 20, null)->'data'->'items')),
  0,
  'C history is empty (no cross-user leakage)'
);

select throws_ok(
  (select format(
    $$ select public.service_transaction_history('NGN', '{"contract_id": "%s"}'::jsonb, 20, null) $$,
    current_setting('test.c1'))),
  'P0001', 'PLT004: Contract not found.',
  'C contract filter on foreign contract fails PLT004'
);

-- ─── 6. History visibility + directions ────────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select is(
  (select jsonb_array_length(
     public.service_transaction_history('NGN', '{}'::jsonb, 20, null)->'data'->'items')),
  1,
  'A history has 1 row (release only; fund row is payer-side)'
);

select is(
  (select public.service_transaction_history('NGN', '{}'::jsonb, 20, null)
     ->'data'->'items'->0->>'direction'),
  'in',
  'A release row direction is in'
);

select is(
  (select public.service_transaction_history('NGN', '{}'::jsonb, 20, null)
     ->'data'->'items'->0->>'contract_id'),
  current_setting('test.c1'),
  'A release row carries the contract attribution'
);

select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select is(
  (select jsonb_array_length(
     public.service_transaction_history('NGN', '{}'::jsonb, 20, null)->'data'->'items')),
  2,
  'B history has 2 rows (fund + release)'
);

select is(
  (select jsonb_array_length(
     public.service_transaction_history('NGN', '{"type":"earned"}'::jsonb, 20, null)->'data'->'items')),
  0,
  'B earned filter is empty (payer side)'
);

select is(
  (select jsonb_array_length(
     public.service_transaction_history('NGN', '{"type":"fund_locked"}'::jsonb, 20, null)->'data'->'items')),
  1,
  'B fund_locked filter has 1 row'
);

select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select is(
  (select jsonb_array_length(
     public.service_transaction_history('NGN', '{"type":"earned"}'::jsonb, 20, null)->'data'->'items')),
  1,
  'A earned filter has 1 row'
);

-- ─── 7. Keyset pagination without overlap ──────────────────────────────────
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);

select ok(
  (select (public.service_transaction_history('NGN', '{}'::jsonb, 1, null)->'data'->>'has_more')::boolean),
  'B first page of 1 has_more is true'
);

select is(
  (select jsonb_array_length(
     public.service_transaction_history(
       'NGN', '{}'::jsonb, 1,
       (select public.service_transaction_history('NGN', '{}'::jsonb, 1, null)->'data'->'next_cursor')
     )->'data'->'items')),
  1,
  'B second page via cursor has 1 row'
);

select ok(
  not (select (public.service_transaction_history(
       'NGN', '{}'::jsonb, 1,
       (select public.service_transaction_history('NGN', '{}'::jsonb, 1, null)->'data'->'next_cursor')
     )->'data'->>'has_more')::boolean),
  'B second page has_more is false'
);

select is(
  (select public.service_transaction_history(
       'NGN', '{}'::jsonb, 1,
       (select public.service_transaction_history('NGN', '{}'::jsonb, 1, null)->'data'->'next_cursor')
     )->'data'->'items'->0->>'id'),
  (select public.service_transaction_history('NGN', '{}'::jsonb, 20, null)
     ->'data'->'items'->1->>'id'),
  'B cursor page matches the second row of the full page (no overlap)'
);

-- ─── 8. Dispute freeze surfaces ────────────────────────────────────────────
set role postgres;
update public.financial_escrow
   set status = 'disputed', updated_at = now()
 where id = current_setting('test.e1')::uuid;

set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);

select is(
  (select (public.service_earnings_summary('NGN')->'data'->>'frozen_count')::int),
  1,
  'A frozen_count is 1 after dispute'
);

select is(
  (select jsonb_array_length(
     public.service_transaction_history('NGN', '{"type":"frozen"}'::jsonb, 20, null)->'data'->'items')),
  1,
  'A frozen filter has 1 row after dispute'
);

select is(
  (select public.service_transaction_history('NGN', '{}'::jsonb, 20, null)
     ->'data'->'items'->0->>'escrow_status'),
  'disputed',
  'A history row flags the disputed escrow status'
);

select * from finish();
rollback;
