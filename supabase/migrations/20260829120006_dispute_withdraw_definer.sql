-- =============================================================================
-- EP-02-05 (follow-up): dispute_withdraw SECURITY DEFINER + dispute_file FOR UPDATE fix
-- -----------------------------------------------------------------------------
-- Migration: 20260829120006_dispute_withdraw_definer.sql
-- Fixes applied to 20260829120005_dispute_resolution_schema.sql:
--   1. dispute_file: remove `for update` on its financial_escrow read. The lock
--      + state transition belong to the SECURITY DEFINER helper
--      dispute_place_escrow_hold; authenticated has no UPDATE grant on
--      financial_escrow, so `for update` failed under SECURITY INVOKER.
--   2. dispute_withdraw: security invoker -> security definer
--      (set search_path = pg_catalog, public). Its body does
--      `UPDATE dispute_cases SET status='withdrawn'`, but `authenticated` has
--      no UPDATE grant on dispute_cases (status is server-controlled, SV-18/FV-18).
--      Filer-scoping is enforced inside the body.
-- Idempotent (create or replace); safe to re-apply after a full reset.
-- =============================================================================

-- 1. dispute_file: plain read, no FOR UPDATE --------------------------------
create or replace function public.dispute_file(
  p_escrow_id uuid,
  p_dispute_type text,
  p_reason text,
  p_desired_outcome text,
  p_priority text default 'medium'
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_escrow public.financial_escrow;
  v_dispute_type text := nullif(btrim(p_dispute_type), '');
  v_reason text := nullif(btrim(p_reason), '');
  v_desired text := nullif(btrim(p_desired_outcome), '');
  v_priority text := coalesce(nullif(btrim(p_priority), ''), 'medium');
  v_counterparty uuid;
  v_case_id uuid;
  v_case public.dispute_cases;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_escrow_id is null then
    perform public.platform_raise_error('PLT003', 'Escrow id is required.');
  end if;
  if v_dispute_type is null or v_dispute_type not in
     ('service_quality', 'non_delivery', 'milestone_disagreement', 'fraud', 'other') then
    perform public.platform_raise_error('PLT003', 'Dispute type is invalid.');
  end if;
  if v_reason is null or char_length(v_reason) < 10 or char_length(v_reason) > 2000 then
    perform public.platform_raise_error('PLT003', 'Reason must be between 10 and 2000 characters.');
  end if;
  if v_desired is not null and v_desired not in
     ('release_to_payee', 'refund_to_payer', 'split', 'other') then
    perform public.platform_raise_error('PLT003', 'Desired outcome is invalid.');
  end if;
  if v_priority not in ('low', 'medium', 'high', 'critical') then
    perform public.platform_raise_error('PLT003', 'Priority is invalid.');
  end if;

  -- Plain read (no FOR UPDATE): authenticated lacks UPDATE grant on
  -- financial_escrow. Lock + validation + state transition happen inside the
  -- SECURITY DEFINER helper dispute_place_escrow_hold.
  select * into v_escrow from public.financial_escrow where id = p_escrow_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;
  if v_actor not in (v_escrow.payer_entity_id, v_escrow.payee_entity_id) then
    perform public.platform_raise_error('PLT003', 'Only a party to the escrow may file a dispute.');
  end if;
  if v_escrow.status not in ('funded', 'partially_released') then
    perform public.platform_raise_error('PLT005', 'Escrow is not in a disputable state.');
  end if;

  v_counterparty := case
    when v_actor = v_escrow.payer_entity_id then v_escrow.payee_entity_id
    else v_escrow.payer_entity_id
  end;

  begin
    insert into public.dispute_cases
      (escrow_id, filer_entity_id, counterparty_entity_id, dispute_type, reason, desired_outcome, priority)
    values
      (p_escrow_id, v_actor, v_counterparty, v_dispute_type, v_reason, v_desired, v_priority)
    returning id into v_case_id;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'An active dispute already exists for this escrow.');
  end;

  -- Place the escrow hold (SECURITY DEFINER helper).
  perform public.dispute_place_escrow_hold(p_escrow_id);

  insert into public.dispute_audit_trail (case_id, entity_id, event_type, subject_type, subject_id, to_state, actor_id, details)
  values (v_case_id, v_actor, 'case_filed', 'dispute_case', v_case_id, 'open', v_actor,
    jsonb_build_object('escrow_id', p_escrow_id, 'dispute_type', v_dispute_type));

  perform public.platform_audit_log_add('dispute_file', 'dispute_cases',
    jsonb_build_object('case_id', v_case_id, 'escrow_id', p_escrow_id));

  select * into v_case from public.dispute_cases where id = v_case_id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Dispute filed.',
    'data', to_jsonb(v_case)
  );
end;
$$;

-- 2. dispute_withdraw: SECURITY DEFINER -------------------------------------
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

  perform public.dispute_release_escrow_hold(v_case.escrow_id);

  update public.dispute_cases
     set status = 'withdrawn', withdrawn_at = now(), updated_at = now()
   where id = v_case.id;

  insert into public.dispute_audit_trail (case_id, entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details)
  values (v_case.id, v_actor, 'case_withdrawn', 'dispute_case', v_case.id, 'open', 'withdrawn', v_actor,
    jsonb_build_object('escrow_id', v_case.escrow_id));

  perform public.platform_audit_log_add('dispute_withdraw', 'dispute_cases',
    jsonb_build_object('case_id', v_case.id));

  select * into v_row from public.dispute_cases where id = v_case.id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Dispute withdrawn.',
    'data', to_jsonb(v_row)
  );
end;
$$;

-- 3. Refresh comments to match the corrected execution model -----------------
comment on function public.dispute_file(uuid, text, text, text, text) is
  'File a dispute against an escrow; places an automatic escrow hold (via DEFINER helper). Self-scoped (party); SECURITY INVOKER; VOLATILE. EXECUTE granted to authenticated, service_role.';
comment on function public.dispute_withdraw(uuid) is
  'Withdraw an open dispute; releases the escrow hold. Filer-scoped; SECURITY DEFINER (updates server-controlled status); VOLATILE. EXECUTE granted to authenticated, service_role.';
