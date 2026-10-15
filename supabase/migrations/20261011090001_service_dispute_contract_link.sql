-- =============================================================================
-- EP-03-17: Service-Engagement Dispute Linkage & Contract-Scoped Filing
-- -----------------------------------------------------------------------------
-- Migration: 20261011090001_service_dispute_contract_link.sql
-- Depends on: 20260829120005_dispute_resolution_schema.sql (dispute_cases,
--             dispute_place/release_escrow_hold DEFINER helpers, dispute_*
--             RPCs, envelope vocabulary)
--             20260829120006_dispute_withdraw_definer.sql (dispute_withdraw
--             DEFINER, dispute_file plain-read fix)
--             20260923090001_service_contract_schema.sql (service_contracts
--             lifecycle, 'disputed' status, contract_events audit)
--             20261006090001_contract_escrow_linkage.sql (release gate,
--             linkage guards)
--
-- PURPOSE
--   Bind dispute_cases to service_contracts so service engagements can be
--   disputed with or without a funded escrow. Adds a nullable
--   dispute_cases.contract_id FK, relaxes dispute_cases.escrow_id to nullable
--   (either escrow_id OR contract_id must be present), and provides a thin
--   contract-scoped filing RPC plus read wrappers. Contract freeze/unfreeze
--   is enforced server-side; the client only mirrors frozen state.
--
-- EXECUTION MODEL
--   - service_dispute_file / service_dispute_get /
--     service_dispute_list_for_contract are SECURITY INVOKER (RLS applies
--     inside every body); no new escrow/ledger DML beyond the existing
--     dispute_place_escrow_hold DEFINER helper.
--   - service_dispute_contract_freeze is an INVOKER trigger helper: the
--     trigger fires on INSERT by an authenticated contract participant, and
--     `authenticated` already holds UPDATE on service_contracts with
--     participant RLS (20260923090001:191-216), so no DEFINER is required.
--   - service_dispute_contract_unfreeze is SECURITY DEFINER with pinned
--     search_path = pg_catalog, public: it fires on status transitions
--     performed by dispute_withdraw (itself DEFINER) and dispute_resolve
--     (service_role). Narrowly scoped to one contract status restore plus
--     one contract_events row; validates the restored status against an
--     allowlist and never moves funds.
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT003/
--     PLT004/PLT005/PLT999 per the 20260829100004 vocabulary.
--   - Idempotent: IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE
--     throughout. No DDL on any frozen CHECK vocabulary, ledger table, or
--     existing RPC signature.
--
-- GRANT STRATEGY
--   - GRANT INSERT(contract_id) ON dispute_cases TO authenticated (additive;
--     the frozen column grant list is preserved, not replaced).
--   - service_dispute_file / service_dispute_get /
--     service_dispute_list_for_contract: REVOKE FROM public, anon then GRANT
--     EXECUTE TO authenticated, service_role. anon receives 42501.
--   - Trigger helpers: REVOKE EXECUTE FROM public, anon, authenticated
--     (invoked by triggers only, never called directly).
-- =============================================================================

-- =============================================================================
-- SECTION 1: dispute_cases.contract_id + nullable escrow_id + indexes
-- =============================================================================
alter table public.dispute_cases
  add column if not exists contract_id uuid
  references public.service_contracts(id) on delete restrict;

-- Unfunded contracts carry escrow_id IS NULL until EP-03-11 links escrow.
-- Relax NOT NULL; the new CHECK below preserves "at least one anchor".
alter table public.dispute_cases
  alter column escrow_id drop not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'dispute_cases_escrow_or_contract_anchor'
       and conrelid = 'public.dispute_cases'::regclass
  ) then
    alter table public.dispute_cases
      add constraint dispute_cases_escrow_or_contract_anchor
      check (escrow_id is not null or contract_id is not null);
  end if;
end;
$$;

create index if not exists dispute_cases_contract_idx
  on public.dispute_cases (contract_id)
  where contract_id is not null;

create unique index if not exists dispute_cases_one_open_per_contract_idx
  on public.dispute_cases (contract_id)
  where contract_id is not null
    and status in ('open', 'under_review');

comment on column public.dispute_cases.contract_id is
  'Nullable link to the disputed service_contract. NULL for legacy escrow-only disputes; non-null for EP-03-17 service engagements. Either escrow_id or contract_id must be present.';

comment on column public.dispute_cases.escrow_id is
  'Linked financial_escrow. Nullable since EP-03-17: unfunded contracts dispute with escrow_id IS NULL until EP-03-11 links escrow. Either escrow_id or contract_id must be present.';

-- Additive column grants: the frozen INSERT column list
-- (20260829120005:220-221) is preserved; contract_id is appended. metadata is
-- appended so service_dispute_file can persist pre_dispute_status for the
-- unfreeze trigger (server-written at file time, never client-updated after:
-- authenticated holds no UPDATE on dispute_cases).
grant insert (contract_id) on public.dispute_cases to authenticated;
grant insert (metadata) on public.dispute_cases to authenticated;

-- =============================================================================
-- SECTION 2: freeze helper + trigger (INVOKER — participant UPDATE grant)
-- =============================================================================
create or replace function public.service_dispute_contract_freeze()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_contract_id uuid := new.contract_id;
  v_from text;
begin
  -- R4 hardening: a legacy escrow-only filing (dispute_file) against an
  -- escrow already linked to a service engagement must freeze that engagement
  -- too, otherwise the contract stays writable while its funds are held.
  if v_contract_id is null and new.escrow_id is not null then
    select id into v_contract_id
      from public.service_contracts
     where escrow_id = new.escrow_id
     limit 1;
  end if;

  if v_contract_id is null then
    return new;
  end if;

  select status into v_from
    from public.service_contracts
   where id = v_contract_id;

  if not found then
    -- Defensive: the FK guarantees presence for contract-anchored rows; a
    -- reverse-linked row that vanished concurrently must not fail the filing.
    if new.contract_id is not null then
      perform public.platform_raise_error('PLT004', 'Contract not found.');
    end if;
    return new;
  end if;

  if v_from = 'disputed' then
    return new;
  end if;

  update public.service_contracts
     set status = 'disputed',
         updated_at = now()
   where id = v_contract_id;

  insert into public.contract_events
    (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
  values
    (v_contract_id, v_actor, 'disputed',
     v_from, 'disputed', v_actor,
     jsonb_build_object(
       'case_id', new.id,
       'escrow_id', new.escrow_id,
       'via', case when new.contract_id is not null then 'service' else 'legacy' end));

  return new;
end;
$$;

drop trigger if exists service_dispute_contract_freeze on public.dispute_cases;
create trigger service_dispute_contract_freeze
  after insert on public.dispute_cases
  for each row
  execute function public.service_dispute_contract_freeze();

revoke execute on function public.service_dispute_contract_freeze() from public, anon, authenticated;

comment on function public.service_dispute_contract_freeze() is
  'SECURITY INVOKER trigger. On dispute_cases INSERT, transitions the linked service_contract to disputed + appends contract_events(disputed). Contract-anchored rows use contract_id directly; legacy escrow-only rows resolve the engagement through the linked escrow (R4). Skips unlinked rows and already-disputed contracts.';

-- =============================================================================
-- SECTION 3: unfreeze helper + trigger (DEFINER — fires inside withdraw/resolve)
-- =============================================================================
create or replace function public.service_dispute_contract_unfreeze()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_restored text;
  v_pre text;
  v_contract_id uuid := new.contract_id;
begin
  -- R4 hardening: legacy escrow-only rows carry no contract_id; resolve the
  -- engagement through the linked escrow exactly like the freeze trigger.
  if v_contract_id is null and new.escrow_id is not null then
    select id into v_contract_id
      from public.service_contracts
     where escrow_id = new.escrow_id
     limit 1;
  end if;

  if v_contract_id is null then
    return new;
  end if;

  if old.status not in ('open', 'under_review') then
    return new;
  end if;

  if new.status not in ('withdrawn', 'resolved', 'closed') then
    return new;
  end if;

  v_pre := nullif(new.metadata ->> 'pre_dispute_status', '');

  if v_pre is null then
    -- Legacy rows predate the metadata anchor: fall back to the freeze
    -- event's from_status for the same engagement.
    select from_status into v_pre
      from public.contract_events
     where contract_id = v_contract_id
       and event_type = 'disputed'
       and to_status = 'disputed'
     order by created_at desc
     limit 1;
  end if;

  if v_pre in ('draft', 'offered', 'active', 'completed') then
    v_restored := v_pre;
  else
    v_restored := 'active';
  end if;

  update public.service_contracts
     set status = v_restored,
         updated_at = now()
   where id = v_contract_id
     and status = 'disputed';

  if found then
    insert into public.contract_events
      (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
    values
      (v_contract_id, new.filer_entity_id, 'disputed',
       'disputed', v_restored, new.filer_entity_id,
       jsonb_build_object(
         'case_id', new.id,
         'unfrozen', true,
         'dispute_status', new.status,
         'escrow_id', new.escrow_id,
         'via', case when new.contract_id is not null then 'service' else 'legacy' end));
  end if;

  return new;
end;
$$;

drop trigger if exists service_dispute_contract_unfreeze on public.dispute_cases;
create trigger service_dispute_contract_unfreeze
  after update of status on public.dispute_cases
  for each row
  execute function public.service_dispute_contract_unfreeze();

revoke execute on function public.service_dispute_contract_unfreeze() from public, anon, authenticated;

comment on function public.service_dispute_contract_unfreeze() is
  'SECURITY DEFINER trigger (pinned search_path). On dispute_cases status open/under_review -> withdrawn/resolved/closed, restores the linked service_contract from disputed to its pre-dispute status (metadata.pre_dispute_status allowlist, freeze-event fallback for legacy rows, default active) + appends contract_events. Never moves funds.';

-- =============================================================================
-- SECTION 4: service_dispute_file (INVOKER, VOLATILE)
-- =============================================================================
create or replace function public.service_dispute_file(
  p_contract_id uuid,
  p_dispute_type text,
  p_reason text,
  p_desired_outcome text default null,
  p_priority text default 'medium'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_contract public.service_contracts%rowtype;
  v_escrow public.financial_escrow%rowtype;
  v_escrow_id uuid := null;
  v_dispute_type text := nullif(btrim(p_dispute_type), '');
  v_reason text := nullif(btrim(p_reason), '');
  v_desired text := nullif(btrim(p_desired_outcome), '');
  v_priority text := coalesce(nullif(btrim(p_priority), ''), 'medium');
  v_counterparty uuid;
  v_case_id uuid;
  v_case public.dispute_cases%rowtype;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
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

  select * into v_contract
    from public.service_contracts
   where id = p_contract_id
   for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;
  if v_actor not in (v_contract.client_entity_id, v_contract.professional_entity_id) then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;
  if v_contract.status in ('disputed', 'closed', 'cancelled') then
    perform public.platform_raise_error('PLT005', 'Contract is not in a disputable state.');
  end if;

  v_escrow_id := v_contract.escrow_id;

  if v_escrow_id is not null then
    select * into v_escrow from public.financial_escrow where id = v_escrow_id;
    if not found then
      perform public.platform_raise_error('PLT004', 'Contract not found.');
    end if;
    if v_escrow.status not in ('funded', 'partially_released') then
      perform public.platform_raise_error('PLT005', 'Escrow is not in a disputable state.');
    end if;
  end if;

  v_counterparty := case
    when v_actor = v_contract.client_entity_id then v_contract.professional_entity_id
    else v_contract.client_entity_id
  end;

  begin
    insert into public.dispute_cases
      (escrow_id, contract_id, filer_entity_id, counterparty_entity_id,
       dispute_type, reason, desired_outcome, priority, metadata)
    values
      (v_escrow_id, p_contract_id, v_actor, v_counterparty,
       v_dispute_type, v_reason, v_desired, v_priority,
       jsonb_build_object(
         'pre_dispute_status', v_contract.status,
         'escrow_id', v_escrow_id,
         'service_listing_id', v_contract.service_listing_id))
    returning id into v_case_id;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'An active dispute already exists for this contract.');
  end;

  if v_escrow_id is not null then
    perform public.dispute_place_escrow_hold(v_escrow_id);
  end if;

  insert into public.dispute_audit_trail
    (case_id, entity_id, event_type, subject_type, subject_id, to_state, actor_id, details)
  values
    (v_case_id, v_actor, 'case_filed', 'dispute_case', v_case_id, 'open', v_actor,
     jsonb_build_object(
       'contract_id', p_contract_id,
       'escrow_id', v_escrow_id,
       'dispute_type', v_dispute_type));

  perform public.platform_audit_log_add('service_dispute_file', 'dispute_cases',
    jsonb_build_object('case_id', v_case_id, 'contract_id', p_contract_id));

  select * into v_case from public.dispute_cases where id = v_case_id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Service dispute filed.',
    'data', to_jsonb(v_case)
  );
end;
$$;

-- =============================================================================
-- SECTION 5: service_dispute_get (INVOKER, STABLE) — case + contract summary
-- =============================================================================
create or replace function public.service_dispute_get(p_case_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.dispute_cases%rowtype;
  v_evidence jsonb;
  v_resolution jsonb;
  v_contract jsonb;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_case_id is null then
    perform public.platform_raise_error('PLT003', 'Case id is required.');
  end if;

  select * into v_case
    from public.dispute_cases
   where id = p_case_id
     and (filer_entity_id = v_actor or counterparty_entity_id = v_actor);
  if not found then
    perform public.platform_raise_error('PLT004', 'Dispute case not found.');
  end if;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at), '[]'::jsonb)
    into v_evidence
    from public.dispute_evidence e
   where e.case_id = v_case.id;

  select to_jsonb(r) into v_resolution
    from public.dispute_resolutions r
   where r.case_id = v_case.id;

  if v_case.contract_id is not null then
    select jsonb_build_object(
             'id', c.id,
             'status', c.status,
             'escrow_id', c.escrow_id,
             'total_amount', c.total_amount,
             'currency_code', c.currency_code,
             'service_listing_id', c.service_listing_id,
             'listing_title', s.title)
      into v_contract
      from public.service_contracts c
      left join public.service_listings s on s.id = c.service_listing_id
     where c.id = v_case.contract_id;
  else
    v_contract := null;
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Service dispute retrieved.',
    'data', jsonb_build_object(
      'case', to_jsonb(v_case),
      'evidence', coalesce(v_evidence, '[]'::jsonb),
      'resolution', v_resolution,
      'contract', v_contract)
  );
end;
$$;

-- =============================================================================
-- SECTION 6: service_dispute_list_for_contract (INVOKER, STABLE)
-- =============================================================================
create or replace function public.service_dispute_list_for_contract(
  p_contract_id uuid,
  p_status text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_contract public.service_contracts%rowtype;
  v_items jsonb;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;
  if p_status is not null and p_status not in
     ('open', 'under_review', 'resolved', 'closed', 'withdrawn') then
    perform public.platform_raise_error('PLT003', 'Status filter is invalid.');
  end if;

  select * into v_contract
    from public.service_contracts
   where id = p_contract_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;
  if v_actor not in (v_contract.client_entity_id, v_contract.professional_entity_id) then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  select coalesce(jsonb_agg(to_jsonb(d) order by d.filed_at desc, d.id desc), '[]'::jsonb)
    into v_items
    from public.dispute_cases d
   where d.contract_id = p_contract_id
     and (p_status is null or d.status = p_status)
     and (d.filer_entity_id = v_actor or d.counterparty_entity_id = v_actor);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Service disputes listed.',
    'data', jsonb_build_object('disputes', v_items)
  );
end;
$$;

-- =============================================================================
-- SECTION 7: GRANTs + COMMENTs + Realtime posture
-- =============================================================================
revoke execute on function public.service_dispute_file(uuid, text, text, text, text) from public, anon;
grant execute on function public.service_dispute_file(uuid, text, text, text, text) to authenticated, service_role;

revoke execute on function public.service_dispute_get(uuid) from public, anon;
grant execute on function public.service_dispute_get(uuid) to authenticated, service_role;

revoke execute on function public.service_dispute_list_for_contract(uuid, text) from public, anon;
grant execute on function public.service_dispute_list_for_contract(uuid, text) to authenticated, service_role;

comment on function public.service_dispute_file(uuid, text, text, text, text) is
  'File a service-engagement dispute against a service_contract; resolves escrow server-side, places the escrow hold when funded (via DEFINER helper), freezes the contract via trigger. Participant-scoped; SECURITY INVOKER; VOLATILE. EXECUTE granted to authenticated, service_role.';

comment on function public.service_dispute_get(uuid) is
  'Retrieve a dispute case with ordered evidence, optional resolution, and joined service-contract summary. Participant-scoped; SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';

comment on function public.service_dispute_list_for_contract(uuid, text) is
  'List dispute cases for one service_contract with optional status filter. Participant-scoped; SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';

-- Dispute tables stay out of supabase_realtime (no publication change for a column addition).
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('dispute_cases', 'dispute_evidence', 'dispute_resolutions', 'dispute_audit_trail',
                         'service_contracts', 'contract_milestones', 'contract_events')
  ) then
    raise exception 'EP-03-17 guard: dispute/contract tables must not be in supabase_realtime';
  end if;
end;
$$;
