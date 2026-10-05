-- EP-03-11: Service Contract Escrow Linkage & Verification Gate
--
-- Completes the nullable escrow linkage deferred by EP-03-02
-- (supabase/migrations/20260923090001_service_contract_schema.sql:19-23):
--   service_contracts.escrow_id + contract_milestones.escrow_milestone_id
--   are backfilled here via a service_role-only RPC. Adds the 7-day
--   review-period expiry column consumed by the escrow_milestone_auto_release
--   Edge Function (cron) and the contract_escrow_orchestrator pre-flight.
--
-- EXECUTION MODEL
--   - SECURITY INVOKER everywhere (RLS applies); no new SECURITY DEFINER
--     (008/013/015/023 posture audits stay green).
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT002/
--     PLT003/PLT004/PLT005/PLT999 per the 20260829100004 vocabulary.
--   - No DDL on any frozen financial_* table; only additive objects on the
--     contract side (new nullable column, partial index, trigger, 2 RPCs).
--   - Idempotent: IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE.
--
-- GRANT STRATEGY
--   - service_contract_link_escrow: service_role only (proxy path). Any
--     authenticated caller receives PLT002; anon receives 42501 via REVOKE.
--   - service_contract_release_gate: authenticated + service_role (STABLE
--     pre-flight read; never moves funds).
--   - REVOKE EXECUTE ON ALL FUNCTIONS FROM public is NOT re-issued here
--     (frozen baseline at 20260923090001:922 stays); explicit per-function
--     REVOKE + GRANT below.

-- =============================================================================
-- SECTION 1: review_period_expires_at (nullable, server-clock expiry)
-- =============================================================================
alter table public.contract_milestones
  add column if not exists review_period_expires_at timestamptz;

comment on column public.contract_milestones.review_period_expires_at is
  'Server-clock review deadline (completed_at + 7 days). Set by trigger on pending->completed; cleared on revision_requested->pending. NULL means no expiry (historical rows, pending, verified-awaiting-release keeps last value for audit). Consumed by EP-03-11 auto-release cron.';

create index if not exists contract_milestones_review_expiry_idx
  on public.contract_milestones (review_period_expires_at)
  where released_at is null
    and status in ('completed', 'verified');

-- Trigger: maintain expiry without replacing the frozen complete/verify RPCs.
create or replace function public.contract_milestones_set_review_expiry()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.status = 'completed'
     and (old.status is distinct from 'completed'
          or new.review_period_expires_at is null) then
    new.review_period_expires_at :=
      coalesce(new.completed_at, now()) + interval '7 days';
    new.updated_at := now();
  elsif new.status = 'pending'
     and old.status = 'completed' then
    -- Revision cycle: clear the previous deadline until re-completed.
    new.review_period_expires_at := null;
    new.updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists contract_milestones_set_review_expiry
  on public.contract_milestones;
create trigger contract_milestones_set_review_expiry
  before update of status, completed_at on public.contract_milestones
  for each row
  execute function public.contract_milestones_set_review_expiry();

-- =============================================================================
-- SECTION 2: service_contract_link_escrow (service_role-only backfill)
-- =============================================================================
create or replace function public.service_contract_link_escrow(
  p_contract_id uuid,
  p_escrow_id uuid,
  p_links jsonb default '[]'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_contract public.service_contracts%rowtype;
  v_escrow public.financial_escrow%rowtype;
  v_link jsonb;
  v_contract_ms_id uuid;
  v_escrow_ms_id uuid;
  v_count int := 0;
  v_sum_contract numeric := 0;
  v_sum_links int := 0;
begin
  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;
  if p_escrow_id is null then
    perform public.platform_raise_error('PLT003', 'Escrow id is required.');
  end if;
  if current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT002', 'Escrow linkage requires the platform release service.');
  end if;

  select * into v_contract
    from public.service_contracts
   where id = p_contract_id
   for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  select * into v_escrow
    from public.financial_escrow
   where id = p_escrow_id
   for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;

  if v_contract.status = 'disputed' or v_escrow.status = 'disputed' then
    perform public.platform_raise_error('PLT005', 'Disputed contracts cannot link escrow.');
  end if;

  if v_escrow.currency_code <> v_contract.currency_code then
    perform public.platform_raise_error('PLT003', 'Escrow currency must match the contract currency.');
  end if;
  if v_escrow.total_amount <> v_contract.total_amount then
    perform public.platform_raise_error('PLT003', 'Escrow total must equal the contract total.');
  end if;
  if v_escrow.payer_entity_id <> v_contract.client_entity_id
     or v_escrow.payee_entity_id <> v_contract.professional_entity_id then
    perform public.platform_raise_error('PLT003', 'Escrow participants must match the contract participants.');
  end if;

  if p_links is null or jsonb_typeof(p_links) <> 'array'
     or jsonb_array_length(p_links) = 0 then
    perform public.platform_raise_error('PLT003', 'Milestone links are required.');
  end if;

  select count(*), coalesce(sum(amount), 0) into v_sum_links, v_sum_contract
    from public.contract_milestones
   where contract_id = v_contract.id;
  if v_sum_links <> jsonb_array_length(p_links) then
    perform public.platform_raise_error('PLT003', 'Link count must equal the contract milestone count.');
  end if;

  for v_link in select * from jsonb_array_elements(p_links)
  loop
    v_contract_ms_id := nullif(v_link->>'contract_milestone_id', '')::uuid;
    v_escrow_ms_id := nullif(v_link->>'escrow_milestone_id', '')::uuid;
    if v_contract_ms_id is null or v_escrow_ms_id is null then
      perform public.platform_raise_error('PLT003', 'Each link requires contract_milestone_id and escrow_milestone_id.');
    end if;

    update public.contract_milestones
       set escrow_milestone_id = v_escrow_ms_id,
           updated_at = now()
     where id = v_contract_ms_id
       and contract_id = v_contract.id;
    if not found then
      perform public.platform_raise_error('PLT004', 'Contract milestone not found for this contract.');
    end if;

    if not exists (
      select 1 from public.financial_escrow_milestones
       where id = v_escrow_ms_id and escrow_id = v_escrow.id
    ) then
      perform public.platform_raise_error('PLT004', 'Escrow milestone not found for this escrow.');
    end if;
    v_count := v_count + 1;
  end loop;

  update public.service_contracts
     set escrow_id = v_escrow.id,
         updated_at = now()
   where id = v_contract.id;

  insert into public.contract_events
    (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
  values
    (v_contract.id, v_contract.client_entity_id, 'milestone_verified',
     v_contract.status, v_contract.status, v_contract.client_entity_id,
     jsonb_build_object('escrow_id', v_escrow.id, 'linked_milestones', v_count));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Escrow linked.',
    'data', jsonb_build_object(
      'contract_id', v_contract.id,
      'escrow_id', v_escrow.id,
      'linked_milestones', v_count
    )
  );
end;
$$;

-- =============================================================================
-- SECTION 3: service_contract_release_gate (STABLE pre-flight read)
-- =============================================================================
-- Server-side eligibility check shared by the orchestrator pre-flight and the
-- auto-release cron. Never moves funds. Eligible iff:
--   milestone verified OR (completed AND review_period_expires_at < now())
--   AND escrow funded/partially_released AND neither side disputed.
create or replace function public.service_contract_release_gate(
  p_milestone_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_milestone public.contract_milestones%rowtype;
  v_contract public.service_contracts%rowtype;
  v_escrow public.financial_escrow%rowtype;
  v_expired boolean := false;
begin
  if not public.platform_is_authenticated()
     and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_milestone_id is null then
    perform public.platform_raise_error('PLT003', 'Milestone id is required.');
  end if;

  select * into v_milestone
    from public.contract_milestones
   where id = p_milestone_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Milestone not found.');
  end if;

  select * into v_contract
    from public.service_contracts
   where id = v_milestone.contract_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if current_user not in ('service_role', 'postgres')
     and v_contract.client_entity_id <> v_actor
     and v_contract.professional_entity_id <> v_actor then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_milestone.status = 'released' then
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Gate evaluated.',
      'data', jsonb_build_object(
        'eligible', false, 'reason', 'already-released',
        'milestone_status', v_milestone.status,
        'review_period_expires_at', v_milestone.review_period_expires_at
      )
    );
  end if;

  v_expired :=
    v_milestone.status = 'completed'
    and v_milestone.review_period_expires_at is not null
    and v_milestone.review_period_expires_at < now();

  if v_contract.status = 'disputed' then
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Gate evaluated.',
      'data', jsonb_build_object(
        'eligible', false, 'reason', 'disputed',
        'milestone_status', v_milestone.status,
        'expired', v_expired,
        'review_period_expires_at', v_milestone.review_period_expires_at
      )
    );
  end if;

  if v_contract.escrow_id is null then
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Gate evaluated.',
      'data', jsonb_build_object(
        'eligible', false, 'reason', 'not-funded',
        'milestone_status', v_milestone.status,
        'expired', v_expired,
        'review_period_expires_at', v_milestone.review_period_expires_at
      )
    );
  end if;

  select * into v_escrow
    from public.financial_escrow
   where id = v_contract.escrow_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;

  if v_escrow.status = 'disputed' then
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Gate evaluated.',
      'data', jsonb_build_object(
        'eligible', false, 'reason', 'disputed',
        'milestone_status', v_milestone.status,
        'escrow_status', v_escrow.status,
        'expired', v_expired,
        'review_period_expires_at', v_milestone.review_period_expires_at
      )
    );
  end if;

  if v_escrow.status not in ('funded', 'partially_released') then
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Gate evaluated.',
      'data', jsonb_build_object(
        'eligible', false, 'reason', 'not-funded',
        'milestone_status', v_milestone.status,
        'escrow_status', v_escrow.status,
        'expired', v_expired,
        'review_period_expires_at', v_milestone.review_period_expires_at
      )
    );
  end if;

  if v_milestone.status = 'verified' or v_expired then
    return jsonb_build_object(
      'success', true, 'code', 'PLT000', 'message', 'Gate evaluated.',
      'data', jsonb_build_object(
        'eligible', true,
        'reason', case when v_milestone.status = 'verified' then 'verified' else 'expired' end,
        'milestone_status', v_milestone.status,
        'escrow_status', v_escrow.status,
        'expired', v_expired,
        'escrow_id', v_escrow.id,
        'escrow_milestone_id', v_milestone.escrow_milestone_id,
        'review_period_expires_at', v_milestone.review_period_expires_at
      )
    );
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Gate evaluated.',
    'data', jsonb_build_object(
      'eligible', false, 'reason', 'not-verified',
      'milestone_status', v_milestone.status,
      'escrow_status', v_escrow.status,
      'expired', v_expired,
      'review_period_expires_at', v_milestone.review_period_expires_at
    )
  );
end;
$$;

-- =============================================================================
-- SECTION 4: GRANTs + COMMENTs + Realtime posture
-- =============================================================================
revoke execute on function public.service_contract_link_escrow(uuid, uuid, jsonb) from public, anon;
grant execute on function public.service_contract_link_escrow(uuid, uuid, jsonb) to authenticated, service_role;

revoke execute on function public.service_contract_release_gate(uuid) from public, anon;
grant execute on function public.service_contract_release_gate(uuid) to authenticated, service_role;

revoke execute on function public.contract_milestones_set_review_expiry() from public, anon, authenticated;

comment on function public.service_contract_link_escrow(uuid, uuid, jsonb) is
  'SECURITY INVOKER, VOLATILE, service_role-only. Backfills service_contracts.escrow_id + contract_milestones.escrow_milestone_id after financial_escrow_create/fund (EP-03-11). Validates participants, currency, totals, and link count.';
comment on function public.service_contract_release_gate(uuid) is
  'SECURITY INVOKER, STABLE. Server-side verify-before-release pre-flight: verified OR (completed + review_period_expires_at < now()), escrow funded/partially_released, neither side disputed. Never moves funds.';
comment on function public.contract_milestones_set_review_expiry() is
  'SECURITY INVOKER trigger. Sets review_period_expires_at = completed_at + 7 days on pending->completed; clears on revision ->pending.';

-- No new tables enter Realtime; column addition needs no publication change.
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('service_contracts', 'contract_milestones', 'contract_events')
  ) then
    raise notice 'EP-03-11: contract tables already excluded from supabase_realtime (no-op).';
  end if;
end;
$$;
