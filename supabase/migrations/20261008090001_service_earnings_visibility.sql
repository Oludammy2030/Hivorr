-- EP-03-16: Financial Reporting & Earnings Visibility System
--
-- Read-only, server-truth earnings aggregation over the EP-02-04 immutable
-- ledger. Two SECURITY INVOKER RPCs, zero new tables, zero writes:
--
--   - `service_earnings_summary(p_currency_code)` — per-currency available /
--     held / pending (from `financial_balances`), lifetime earned + release
--     count + completed contracts (from `financial_transactions`), disputed
--     escrow count (from `financial_escrow`), and 6 trailing month buckets.
--   - `service_transaction_history(p_currency_code, p_filters, p_limit,
--     p_cursor)` — keyset-paginated `(created_at DESC, id DESC)` ledger read
--     scoped to rows touching the caller, with per-row contract attribution
--     via the EP-03-02/EP-03-11 `service_contracts.escrow_id` linkage.
--
-- Ledger-shape note (verified against `20260829100004` §16.5–16.8): release
-- rows are stored with `entity_id = payer` and
-- `destination_entity_id = payee`, so earned classification MUST predicate on
-- `destination_entity_id` + `transaction_type = 'escrow_release'` — never on
-- `entity_id` alone. `reference_type` is constrained to
-- `('escrow','payout','deposit','conversion','system')`; there is no
-- `milestone_release` reference type.
--
-- RLS note (approved deviation from TIP §10, project-lead 2026-10-10):
-- `financial_transactions_select` is `entity_id`-scoped only, so an INVOKER
-- read can never see counterparty release rows (payee earnings read zero —
-- proven by pgTAP 046). The additive `financial_transactions_earnings_select`
-- policy below extends visibility to rows where the caller is the source or
-- destination, mirroring the existing participant-scoped
-- `financial_escrow_select` (`payer OR payee`) philosophy. Stranger rows stay
-- hidden (046 leakage matrix). Direct REST reads gain only the caller's own
-- money movements — self/party-scoped per the permission matrix. SECURITY
-- INVOKER posture is preserved (no DEFINER).
--
-- Envelope `{success, code, message, data}` with PLT000/001/003/004/005/999
-- via `platform_raise_error`, mirroring `financial_balance_get` and
-- `service_contract_get`. Identical PLT004 for unknown vs non-participant
-- contracts (no existence oracle).
--
-- =============================================================================
-- SECTION 1: Supporting indexes (IF NOT EXISTS; no table rewrite)
-- =============================================================================
create index if not exists financial_transactions_entity_currency_created_idx
  on public.financial_transactions (entity_id, currency_code, created_at desc, id desc);

create index if not exists financial_transactions_destination_currency_idx
  on public.financial_transactions (destination_entity_id, currency_code, created_at desc, id desc);

create index if not exists financial_transactions_source_currency_idx
  on public.financial_transactions (source_entity_id, currency_code, created_at desc);

-- =============================================================================
-- SECTION 2: service_earnings_summary
-- =============================================================================
create or replace function public.service_earnings_summary(p_currency_code char(3))
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_currency char(3) := nullif(btrim(p_currency_code), '');
  v_available numeric := 0;
  v_held numeric := 0;
  v_pending numeric := 0;
  v_lifetime_earned numeric := 0;
  v_release_count integer := 0;
  v_completed_contracts integer := 0;
  v_withdrawn numeric := 0;
  v_frozen_count integer := 0;
  v_monthly jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if v_currency is null or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_currency
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;

  select coalesce(b.available_balance, 0), coalesce(b.held_balance, 0), coalesce(b.pending_balance, 0)
    into v_available, v_held, v_pending
    from public.financial_balances b
   where b.entity_id = v_actor and b.currency_code = v_currency;

  -- Earned = inbound escrow releases (payee side; see header note).
  select coalesce(sum(t.amount), 0), count(*)::int,
         count(distinct t.reference_id)::int
    into v_lifetime_earned, v_release_count, v_completed_contracts
    from public.financial_transactions t
   where t.destination_entity_id = v_actor
     and t.transaction_type = 'escrow_release'
     and t.currency_code = v_currency;

  select coalesce(sum(t.amount), 0)
    into v_withdrawn
    from public.financial_transactions t
   where t.transaction_type = 'withdrawal'
     and t.currency_code = v_currency
     and (t.entity_id = v_actor or t.source_entity_id = v_actor);

  select count(*)::int
    into v_frozen_count
    from public.financial_escrow e
   where e.currency_code = v_currency
     and e.status = 'disputed'
     and (e.payer_entity_id = v_actor or e.payee_entity_id = v_actor);

  -- Trailing 6 calendar-month buckets (oldest first); honest zeros included.
  select coalesce(jsonb_agg(
           jsonb_build_object(
             'month', to_char(m, 'YYYY-MM-DD'),
             'earned', coalesce(s.earned, 0),
             'count', coalesce(s.cnt, 0)
           ) order by m), '[]'::jsonb)
    into v_monthly
    from (
      select date_trunc('month', now()) - (interval '1 month' * gs.i) as m
        from generate_series(0, 5) gs(i)
    ) months
    left join lateral (
      select sum(t.amount) as earned, count(*)::int as cnt
        from public.financial_transactions t
       where t.destination_entity_id = v_actor
         and t.transaction_type = 'escrow_release'
         and t.currency_code = v_currency
         and date_trunc('month', t.created_at) = months.m
    ) s on true;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Earnings summary retrieved.',
    'data', jsonb_build_object(
      'currency_code', v_currency,
      'available_balance', v_available,
      'held_balance', v_held,
      'pending_balance', v_pending,
      'lifetime_earned', v_lifetime_earned,
      'release_count', v_release_count,
      'completed_contracts', v_completed_contracts,
      'total_withdrawn', v_withdrawn,
      'frozen_count', v_frozen_count,
      'monthly', v_monthly
    )
  );
end;
$$;

-- =============================================================================
-- SECTION 3: service_transaction_history
-- =============================================================================
create or replace function public.service_transaction_history(
  p_currency_code char(3),
  p_filters jsonb default '{}'::jsonb,
  p_limit integer default 20,
  p_cursor jsonb default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_currency char(3) := nullif(btrim(p_currency_code), '');
  v_filters jsonb := coalesce(p_filters, '{}'::jsonb);
  v_limit integer := coalesce(p_limit, 20);
  v_type text := lower(nullif(btrim(v_filters->>'type'), ''));
  v_contract_id uuid;
  v_date_from timestamptz;
  v_date_to timestamptz;
  v_cursor_ts timestamptz;
  v_cursor_id uuid;
  v_rows jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if v_currency is null or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_currency
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;

  if v_limit is null or v_limit < 1 or v_limit > 50 then
    perform public.platform_raise_error('PLT005', 'Limit must be between 1 and 50.');
  end if;

  if v_type is null or v_type = '' then v_type := 'all'; end if;
  if v_type not in ('all', 'earned', 'withdrawn', 'fund_locked', 'frozen') then
    perform public.platform_raise_error('PLT003', 'Invalid history filter type.');
  end if;

  -- Optional contract scoping: participant-only, identical PLT004 otherwise.
  if nullif(btrim(v_filters->>'contract_id'), '') is not null then
    begin
      v_contract_id := (v_filters->>'contract_id')::uuid;
    exception when others then
      perform public.platform_raise_error('PLT004', 'Contract not found.');
    end;
    if not exists (
      select 1 from public.service_contracts c
       where c.id = v_contract_id
         and (c.client_entity_id = v_actor or c.professional_entity_id = v_actor
              or current_user in ('service_role', 'postgres'))
    ) then
      perform public.platform_raise_error('PLT004', 'Contract not found.');
    end if;
  end if;

  -- Optional date window.
  if nullif(btrim(v_filters->>'date_from'), '') is not null then
    begin
      v_date_from := (v_filters->>'date_from')::timestamptz;
    exception when others then
      perform public.platform_raise_error('PLT003', 'Invalid date_from filter.');
    end;
  end if;
  if nullif(btrim(v_filters->>'date_to'), '') is not null then
    begin
      v_date_to := (v_filters->>'date_to')::timestamptz;
    exception when others then
      perform public.platform_raise_error('PLT003', 'Invalid date_to filter.');
    end;
  end if;

  -- Optional keyset cursor.
  if p_cursor is not null then
    begin
      v_cursor_ts := (p_cursor->>'created_at')::timestamptz;
      v_cursor_id := (p_cursor->>'id')::uuid;
    exception when others then
      perform public.platform_raise_error('PLT005', 'Invalid pagination cursor.');
    end;
    if v_cursor_ts is null or v_cursor_id is null then
      perform public.platform_raise_error('PLT005', 'Invalid pagination cursor.');
    end if;
  end if;

  with scoped as (
    select t.id, t.transaction_type, t.currency_code, t.amount,
           t.source_entity_id, t.destination_entity_id,
           t.reference_type, t.reference_id, t.description, t.created_at,
           case
             when t.destination_entity_id = v_actor
                  and t.source_entity_id is distinct from v_actor then 'in'
             when t.source_entity_id = v_actor
                  and t.destination_entity_id is distinct from v_actor then 'out'
             else 'self'
           end as direction,
           c.id as contract_id, c.status as contract_status,
           e.status as escrow_status
      from public.financial_transactions t
      left join public.service_contracts c
        on c.escrow_id = t.reference_id
       and t.reference_type = 'escrow'
       and (c.client_entity_id = v_actor or c.professional_entity_id = v_actor
            or current_user in ('service_role', 'postgres'))
      left join public.financial_escrow e
        on e.id = t.reference_id
       and t.reference_type = 'escrow'
       and (e.payer_entity_id = v_actor or e.payee_entity_id = v_actor
            or current_user in ('service_role', 'postgres'))
     where t.currency_code = v_currency
       and (t.entity_id = v_actor
            or t.source_entity_id = v_actor
            or t.destination_entity_id = v_actor)
       and (v_cursor_ts is null or (t.created_at, t.id) < (v_cursor_ts, v_cursor_id))
       and (v_contract_id is null or c.id = v_contract_id)
       and (v_date_from is null or t.created_at >= v_date_from)
       and (v_date_to is null or t.created_at <= v_date_to)
       and (
         v_type = 'all'
         or (v_type = 'earned' and t.transaction_type = 'escrow_release'
             and t.destination_entity_id = v_actor)
         or (v_type = 'withdrawn' and t.transaction_type = 'withdrawal'
             and (t.entity_id = v_actor or t.source_entity_id = v_actor))
         or (v_type = 'fund_locked' and t.transaction_type = 'escrow_fund'
             and (t.entity_id = v_actor or t.source_entity_id = v_actor))
         or (v_type = 'frozen' and e.status = 'disputed')
       )
     order by t.created_at desc, t.id desc
     limit v_limit + 1
  ), kept as (
    select * from scoped order by created_at desc, id desc limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', k.id,
           'transaction_type', k.transaction_type,
           'currency_code', k.currency_code,
           'amount', k.amount,
           'direction', k.direction,
           'source_entity_id', k.source_entity_id,
           'destination_entity_id', k.destination_entity_id,
           'reference_type', k.reference_type,
           'reference_id', k.reference_id,
           'description', k.description,
           'created_at', k.created_at,
           'contract_id', k.contract_id,
           'contract_status', k.contract_status,
           'escrow_status', k.escrow_status
         ) order by k.created_at desc, k.id desc), '[]'::jsonb),
         (select count(*)::int > v_limit from scoped),
         (select jsonb_build_object(
                   'created_at', max(kept.created_at),
                   'id', (array_agg(kept.id order by kept.created_at desc, kept.id desc))[1]
                 ) from kept)
    into v_rows, v_has_more, v_next_cursor
    from kept k;

  if jsonb_array_length(coalesce(v_rows, '[]'::jsonb)) = 0 then
    v_next_cursor := null;
  end if;
  if not v_has_more then
    v_next_cursor := null;
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Transaction history retrieved.',
    'data', jsonb_build_object(
      'currency_code', v_currency,
      'items', coalesce(v_rows, '[]'::jsonb),
      'count', jsonb_array_length(coalesce(v_rows, '[]'::jsonb)),
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
end;
$$;

comment on function public.service_earnings_summary(char) is
  'EP-03-16 read-only earnings aggregate (STABLE, SECURITY INVOKER). Per-currency balances + server-computed lifetime earned from inbound escrow_release rows + 6 month buckets + disputed count. Client renders verbatim and never recomputes settlement (AGENT.md Rule 4).';

comment on function public.service_transaction_history(char, jsonb, integer, jsonb) is
  'EP-03-16 read-only ledger read (STABLE, SECURITY INVOKER). Rows touching the caller only (entity/source/destination), keyset (created_at, id) pagination, contract attribution via service_contracts.escrow_id, disputed flag via financial_escrow join. Server order is authoritative; clients render verbatim.';

-- =============================================================================
-- SECTION 4: EXECUTE grants (revoke from public pseudo-role, then grant —
-- mirrors EP-02-04 §17; WITHOUT this, anon inherits EXECUTE via PUBLIC)
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.service_earnings_summary(char(3))
  to authenticated, service_role;

grant execute on function public.service_transaction_history(char(3), jsonb, integer, jsonb)
  to authenticated, service_role;

-- =============================================================================
-- SECTION 5: Participant ledger visibility (see RLS note above)
-- =============================================================================
drop policy if exists financial_transactions_earnings_select
  on public.financial_transactions;

create policy financial_transactions_earnings_select
  on public.financial_transactions
  for select to authenticated
  using (
    destination_entity_id = auth.uid()
    or source_entity_id = auth.uid()
  );

comment on policy financial_transactions_earnings_select
  on public.financial_transactions is
  'EP-03-16: participant leg of the ledger read model. Combined with the
   entity-scoped financial_transactions_select, authenticated callers see
   exactly the rows where they are the entity, source, or destination —
   i.e. their own money movements, never strangers'' rows. Consumed by the
   SECURITY INVOKER service_earnings_summary / service_transaction_history
   RPCs; direct REST reads gain no additional parties.';
