-- =============================================================================
-- EP-03-17 R4 follow-up: null-escrow tolerance for withdraw/resolve
-- -----------------------------------------------------------------------------
-- Migration: 20261013090004_dispute_unfunded_tolerance.sql
-- Depends on: 20260829120005_dispute_resolution_schema.sql (dispute_resolve)
--             20260829120006_dispute_withdraw_definer.sql (dispute_withdraw)
--             20261013090001_service_dispute_contract_link.sql (nullable
--             escrow_id, contract freeze/unfreeze triggers)
--
-- PURPOSE
--   The frozen `dispute_withdraw` / `dispute_resolve` bodies were written
--   against the pre-EP-03-17 invariant `dispute_cases.escrow_id NOT NULL`:
--   withdraw unconditionally releases the escrow hold (PLT003 on NULL), and
--   resolve unconditionally fetches the escrow row (PLT004 on NULL). Unfunded
--   service disputes therefore could never be withdrawn or resolved. This
--   migration makes both functions null-escrow-tolerant with the smallest
--   possible delta (following the 20260829120006 precedent of CREATE OR
--   REPLACE over the frozen bodies):
--     - withdraw: skips the hold release when escrow_id IS NULL (the
--       contract unfreeze still fires through the trigger);
--     - resolve: requires zero amounts when escrow_id IS NULL (no held funds
--       can move), skips the escrow fetch/movements, and still records the
--       resolution + flips the case (the contract unfreeze still fires).
--   No signature, grant, vocabulary, or funded-path behavior changes.
-- =============================================================================

-- 1. dispute_withdraw: skip the hold release for unfunded cases -------------
create or replace function public.dispute_withdraw(p_case_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.dispute_cases;
  v_row public.dispute_cases;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_case_id is null then
    perform public.platform_raise_error('PLT003', 'Case id is required.');
  end if;

  select * into v_case from public.dispute_cases where id = p_case_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Dispute case not found.');
  end if;
  if v_actor <> v_case.filer_entity_id then
    perform public.platform_raise_error('PLT003', 'Only the filer may withdraw a dispute.');
  end if;
  if v_case.status <> 'open' then
    perform public.platform_raise_error('PLT005', 'Only an open dispute may be withdrawn.');
  end if;

  -- EP-03-17 R4: unfunded service disputes hold no escrow — nothing to release.
  if v_case.escrow_id is not null then
    perform public.dispute_release_escrow_hold(v_case.escrow_id);
  end if;

  update public.dispute_cases
     set status = 'withdrawn', withdrawn_at = now(), updated_at = now()
   where id = v_case.id;

  insert into public.dispute_audit_trail (case_id, entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details)
  values (v_case.id, v_actor, 'case_withdrawn', 'dispute_case', v_case.id, 'open', 'withdrawn', v_actor,
    jsonb_build_object('escrow_id', v_case.escrow_id, 'contract_id', v_case.contract_id));

  perform public.platform_audit_log_add('dispute_withdraw', 'dispute_cases',
    jsonb_build_object('case_id', v_case.id));

  select * into v_row from public.dispute_cases where id = v_case.id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Dispute withdrawn.',
    'data', to_jsonb(v_row)
  );
end;
$$;

-- 2. dispute_resolve: zero-amount, movement-free path for unfunded cases ------
create or replace function public.dispute_resolve(
  p_case_id uuid,
  p_resolution_type text,
  p_reasoning text,
  p_payer_refund_amount numeric default 0,
  p_payee_release_amount numeric default 0,
  p_notes text default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_resolver uuid := auth.uid();
  v_case public.dispute_cases;
  v_escrow public.financial_escrow;
  v_resolution_type text := nullif(btrim(p_resolution_type), '');
  v_reasoning text := nullif(btrim(p_reasoning), '');
  v_refund numeric := coalesce(p_payer_refund_amount, 0);
  v_release numeric := coalesce(p_payee_release_amount, 0);
  v_remaining numeric;
  v_payer_bal public.financial_balances;
  v_resolution_id uuid;
  v_row public.dispute_resolutions;
begin
  if p_case_id is null then
    perform public.platform_raise_error('PLT003', 'Case id is required.');
  end if;
  if v_resolution_type is null or v_resolution_type not in
     ('release_to_payee', 'refund_to_payer', 'split', 'dismissed') then
    perform public.platform_raise_error('PLT003', 'Resolution type is invalid.');
  end if;
  if v_reasoning is null or char_length(v_reasoning) < 10 or char_length(v_reasoning) > 5000 then
    perform public.platform_raise_error('PLT003', 'Resolution reasoning must be 10 to 5000 characters.');
  end if;
  if v_refund < 0 or v_release < 0 then
    perform public.platform_raise_error('PLT003', 'Resolution amounts must be non-negative.');
  end if;

  select * into v_case from public.dispute_cases where id = p_case_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Dispute case not found.');
  end if;
  if v_case.status not in ('open', 'under_review') then
    perform public.platform_raise_error('PLT005', 'Dispute is not in a resolvable state.');
  end if;

  -- EP-03-17 R4: unfunded service disputes hold no escrow, so no fund movement
  -- is possible. Zero-amount outcomes of any type are recorded; the contract
  -- unfreeze fires through the trigger.
  if v_case.escrow_id is null then
    if v_refund <> 0 or v_release <> 0 then
      perform public.platform_raise_error('PLT003', 'An unfunded dispute must not specify financial amounts.');
    end if;

    insert into public.dispute_resolutions (case_id, resolved_by, resolution_type, reasoning, payer_refund_amount, payee_release_amount, notes)
    values (v_case.id, v_resolver, v_resolution_type, v_reasoning, 0, 0, nullif(btrim(p_notes), ''))
    returning id into v_resolution_id;

    update public.dispute_cases
       set status = 'resolved', resolved_at = now(), updated_at = now()
     where id = v_case.id;

    insert into public.dispute_audit_trail (case_id, entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details)
    values (v_case.id, v_resolver, 'case_resolved', 'dispute_case', v_case.id, v_case.status, 'resolved', v_resolver,
      jsonb_build_object('resolution_type', v_resolution_type, 'contract_id', v_case.contract_id));

    select * into v_row from public.dispute_resolutions where id = v_resolution_id;

    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Dispute resolved.',
      'data', to_jsonb(v_row)
    );
  end if;

  select * into v_escrow from public.financial_escrow where id = v_case.escrow_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Linked escrow not found.');
  end if;

  v_remaining := v_escrow.total_amount - v_escrow.released_amount - v_escrow.refunded_amount;

  -- Validate amounts per resolution type.
  if v_resolution_type = 'dismissed' then
    if v_refund <> 0 or v_release <> 0 then
      perform public.platform_raise_error('PLT003', 'A dismissed dispute must not specify financial amounts.');
    end if;
    perform public.dispute_release_escrow_hold(v_escrow.id);
  elsif v_resolution_type = 'release_to_payee' then
    v_release := v_remaining;
    v_refund := 0;
  elsif v_resolution_type = 'refund_to_payer' then
    v_refund := v_remaining;
    v_release := 0;
  elsif v_resolution_type = 'split' then
    if (v_refund + v_release) > v_remaining then
      perform public.platform_raise_error('PLT003', 'Split amounts exceed the escrow balance.');
    end if;
    if (v_refund + v_release) <= 0 then
      perform public.platform_raise_error('PLT003', 'Split must allocate a positive amount.');
    end if;
  end if;

  -- Inline double-entry financial movement (release/refund/split).
  if v_resolution_type in ('release_to_payee', 'refund_to_payer', 'split') then
    select * into v_payer_bal
      from public.financial_balances
     where entity_id = v_escrow.payer_entity_id and currency_code = v_escrow.currency_code
     for update;
    if not found then
      insert into public.financial_balances (financial_profile_id, entity_id, currency_code)
      values (v_escrow.financial_profile_id, v_escrow.payer_entity_id, v_escrow.currency_code)
      on conflict do nothing;
      select * into v_payer_bal
        from public.financial_balances
       where entity_id = v_escrow.payer_entity_id and currency_code = v_escrow.currency_code
       for update;
    end if;

    if v_release > 0 then
      insert into public.financial_transactions
        (financial_profile_id, entity_id, transaction_type, currency_code, amount,
         source_entity_id, destination_entity_id, debit_balance_type, credit_balance_type,
         reference_type, reference_id, description)
      values
        (v_escrow.financial_profile_id, v_escrow.payer_entity_id, 'escrow_release', v_escrow.currency_code, v_release,
         v_escrow.payer_entity_id, v_escrow.payee_entity_id, 'held', 'available',
         'escrow', v_escrow.id, 'Dispute resolved: release to payee');

      update public.financial_balances
         set held_balance = held_balance - v_release,
             last_transaction_at = now(), updated_at = now()
       where id = v_payer_bal.id;

      insert into public.financial_balances (financial_profile_id, entity_id, currency_code, available_balance, held_balance, last_transaction_at)
      values (v_escrow.payee_entity_id, v_escrow.payee_entity_id, v_escrow.currency_code, v_release, 0, now())
      on conflict (entity_id, currency_code) do update set
        available_balance = financial_balances.available_balance + excluded.available_balance,
        last_transaction_at = now(), updated_at = now();

      insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, from_state, to_state, amount, currency_code, details)
      values (v_escrow.payee_entity_id, 'financial_release', 'escrow', v_escrow.id, 'disputed', 'released', v_release, v_escrow.currency_code,
        jsonb_build_object('case_id', v_case.id));
    end if;

    if v_refund > 0 then
      insert into public.financial_transactions
        (financial_profile_id, entity_id, transaction_type, currency_code, amount,
         source_entity_id, destination_entity_id, debit_balance_type, credit_balance_type,
         reference_type, reference_id, description)
      values
        (v_escrow.financial_profile_id, v_escrow.payer_entity_id, 'escrow_refund', v_escrow.currency_code, v_refund,
         v_escrow.payer_entity_id, v_escrow.payer_entity_id, 'held', 'available',
         'escrow', v_escrow.id, 'Dispute resolved: refund to payer');

      update public.financial_balances
         set held_balance = held_balance - v_refund,
             available_balance = available_balance + v_refund,
             last_transaction_at = now(), updated_at = now()
       where id = v_payer_bal.id;

      insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, from_state, to_state, amount, currency_code, details)
      values (v_escrow.payer_entity_id, 'financial_refund', 'escrow', v_escrow.id, 'disputed', 'refunded', v_refund, v_escrow.currency_code,
        jsonb_build_object('case_id', v_case.id));
    end if;

    if v_resolution_type = 'split' then
      update public.financial_escrow
         set released_amount = released_amount + v_release,
             refunded_amount = refunded_amount + v_refund,
             status = 'released', released_at = now(), updated_at = now()
       where id = v_escrow.id;
    elsif v_resolution_type = 'release_to_payee' then
      update public.financial_escrow
         set released_amount = released_amount + v_release,
             status = 'released', released_at = now(), updated_at = now()
       where id = v_escrow.id;
    elsif v_resolution_type = 'refund_to_payer' then
      update public.financial_escrow
         set refunded_amount = refunded_amount + v_refund,
             status = 'refunded', refunded_at = now(), updated_at = now()
       where id = v_escrow.id;
    end if;
  end if;

  insert into public.dispute_resolutions (case_id, resolved_by, resolution_type, reasoning, payer_refund_amount, payee_release_amount, notes)
  values (v_case.id, v_resolver, v_resolution_type, v_reasoning, v_refund, v_release, nullif(btrim(p_notes), ''))
  returning id into v_resolution_id;

  update public.dispute_cases
     set status = 'resolved', resolved_at = now(), updated_at = now()
   where id = v_case.id;

  insert into public.dispute_audit_trail (case_id, entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details)
  values (v_case.id, v_resolver, 'case_resolved', 'dispute_case', v_case.id, v_case.status, 'resolved', v_resolver,
    jsonb_build_object('resolution_type', v_resolution_type));

  select * into v_row from public.dispute_resolutions where id = v_resolution_id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Dispute resolved.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.dispute_withdraw(uuid) is
  'Withdraw an open dispute; releases the escrow hold when funded (skipped for unfunded service disputes). Filer-scoped; SECURITY DEFINER (updates server-controlled status); VOLATILE. EXECUTE granted to authenticated, service_role.';

comment on function public.dispute_resolve(uuid, text, text, numeric, numeric, text) is
  'Resolve a dispute with inline double-entry movements when funded; records a zero-amount resolution without fund movement when unfunded. Status transitions are server-controlled; VOLATILE. EXECUTE granted to service_role only.';
