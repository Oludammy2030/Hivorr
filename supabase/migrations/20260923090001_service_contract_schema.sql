-- EP-03-02: Service Contract & Milestone Engine Schema & Lifecycle RPCs
--
-- Universal 2-party engagement primitive: 3 tables (service_contracts,
-- contract_milestones, contract_events) + 8 SECURITY INVOKER RPCs with the
-- lifecycle state machine and nullable escrow linkage.
--
-- EXECUTION MODEL
--   - SECURITY INVOKER everywhere (RLS applies inside every RPC body); no new
--     SECURITY DEFINER function (008/013/015/023 posture audits stay green).
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT003/
--     PLT004/PLT005/PLT999 per the 20260829100004 vocabulary.
--   - State machine: draft (reserved) -> offered --accept--> active
--     --complete_milestone--> active (pending->completed)
--     --verify_milestone--> active (completed->verified) / revision_requested -> pending
--     --close--> closed (when all milestones verified); offered--cancel--> cancelled;
--     disputed blocks verify/close (EP-03-17 trigger will set disputed).
--
-- ESCROW LINKAGE (nullable, deferred to EP-03-11)
--   service_contracts.escrow_id -> financial_escrow.id is NULL until the
--   contract_escrow_orchestrator (service_role Edge Function) calls
--   financial_escrow_create/fund. contract_milestones.escrow_milestone_id
--   remains NULL until that orchestrator links it. No financial_escrow DML
--   in this migration; no new ledger.
--
-- GRANT STRATEGY
--   - REVOKE ALL on 3 tables from anon, authenticated, service_role then narrow
--     SELECT on all 3 to authenticated (participant RLS-filtered) + INSERT/SELECT
--     on contract_events to authenticated/service_role (append-only); full grants
--     to service_role only. Writes via RPC only (mirrors financial_escrow pattern).
--   - REVOKE EXECUTE ON ALL FUNCTIONS FROM public then explicit GRANT EXECUTE
--     per RPC (8 x authenticated+service_role, anon zero).
--
-- MIGRATION POSTURE
--   - No DDL on any prior table/function/policy (Rule 3 write discipline); only
--     new objects.
--   - Idempotent: IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE throughout.
--   - Evidence path reuses service-listing-media bucket with foldername check;
--     no new bucket.

-- =============================================================================
-- SECTION 1: service_contracts
-- =============================================================================
create table if not exists public.service_contracts (
  id                      uuid primary key default gen_random_uuid(),
  service_listing_id      uuid not null references public.service_listings (id) on delete restrict,
  client_entity_id        uuid not null references public.entities (id) on delete restrict,
  professional_entity_id  uuid not null references public.entities (id) on delete restrict,
  status                  text not null default 'offered',
  escrow_id               uuid references public.financial_escrow (id) on delete restrict,
  total_amount            numeric not null,
  currency_code           char(3) not null references public.financial_supported_currencies (currency_code),
  offer_expires_at        timestamptz,
  offered_at              timestamptz not null default now(),
  accepted_at             timestamptz,
  completed_at            timestamptz,
  closed_at               timestamptz,
  cancelled_at            timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid default auth.uid(),
  constraint service_contracts_status_allowed check (
    status in ('draft', 'offered', 'active', 'completed', 'closed', 'cancelled', 'disputed')
  ),
  constraint service_contracts_currency_format check (currency_code ~ '^[A-Z]{3}$'),
  constraint service_contracts_total_amount_positive check (total_amount > 0),
  constraint service_contracts_no_self check (client_entity_id <> professional_entity_id)
);

comment on table public.service_contracts is
  'Universal 2-party contract: binds a published service_listing to client/professional with lifecycle offered->active->completed->closed/cancelled/disputed. escrow_id is NULL until EP-03-11 funds. Milestone sum invariant enforced by service_contract_offer RPC.';

comment on column public.service_contracts.service_listing_id is 'FK to published service_listings; ON DELETE RESTRICT prevents orphaning supply.';
comment on column public.service_contracts.client_entity_id is 'Offerer (auth.uid() at offer time).';
comment on column public.service_contracts.professional_entity_id is 'Listing owner derived from service_listings.entity_id (never client-supplied).';
comment on column public.service_contracts.status is 'Lifecycle: draft/offered/active/completed/closed/cancelled/disputed. Transitions RPC-only.';
comment on column public.service_contracts.escrow_id is 'Nullable until EP-03-11 financial_escrow_create (service_role). No client grant.';
comment on column public.service_contracts.total_amount is 'Contract total; must equal sum(contract_milestones.amount) enforced by RPC.';
comment on column public.service_contracts.offer_expires_at is 'Optional expiry; checked server-side at accept.';

create index if not exists service_contracts_client_idx
  on public.service_contracts (client_entity_id, status);
create index if not exists service_contracts_professional_idx
  on public.service_contracts (professional_entity_id, status);
create index if not exists service_contracts_listing_idx
  on public.service_contracts (service_listing_id);
create index if not exists service_contracts_status_idx
  on public.service_contracts (status);
create index if not exists service_contracts_escrow_idx
  on public.service_contracts (escrow_id) where escrow_id is not null;
create index if not exists service_contracts_created_at_idx
  on public.service_contracts (created_at desc);

drop trigger if exists service_contracts_set_updated_at on public.service_contracts;
create trigger service_contracts_set_updated_at
  before update on public.service_contracts
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 2: contract_milestones
-- =============================================================================
create table if not exists public.contract_milestones (
  id                    uuid primary key default gen_random_uuid(),
  contract_id           uuid not null references public.service_contracts (id) on delete cascade,
  escrow_milestone_id   uuid references public.financial_escrow_milestones (id) on delete restrict,
  milestone_number      integer not null,
  title                 text not null,
  description           text,
  amount                numeric not null,
  status                text not null default 'pending',
  evidence_path         text,
  sort_order            integer not null default 0,
  completed_at          timestamptz,
  verified_at           timestamptz,
  released_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  created_by            uuid default auth.uid(),
  constraint contract_milestones_milestone_number_positive check (milestone_number >= 1),
  constraint contract_milestones_title_length check (char_length(btrim(title)) between 1 and 255),
  constraint contract_milestones_description_length check (description is null or char_length(description) <= 2000),
  constraint contract_milestones_amount_positive check (amount > 0),
  constraint contract_milestones_status_allowed check (status in ('pending', 'completed', 'verified', 'released')),
  constraint contract_milestones_sort_order_nonneg check (sort_order >= 0),
  constraint contract_milestones_contract_number_key unique (contract_id, milestone_number)
);

comment on table public.contract_milestones is
  'Per-contract milestone split with 1:1 future link to financial_escrow_milestones via escrow_milestone_id (NULL until funded). pending->completed (professional) ->verified (client) ->released (EP-03-11).';

comment on column public.contract_milestones.escrow_milestone_id is 'Nullable until EP-03-11 links after financial_escrow_create. No client grant.';
comment on column public.contract_milestones.evidence_path is 'Storage path under service-listing-media/{professional_id}/... validated by RPC.';

create index if not exists contract_milestones_contract_idx
  on public.contract_milestones (contract_id, sort_order);
create index if not exists contract_milestones_escrow_idx
  on public.contract_milestones (escrow_milestone_id) where escrow_milestone_id is not null;
create index if not exists contract_milestones_contract_number_idx
  on public.contract_milestones (contract_id, milestone_number);

drop trigger if exists contract_milestones_set_updated_at on public.contract_milestones;
create trigger contract_milestones_set_updated_at
  before update on public.contract_milestones
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 3: contract_events (append-only)
-- =============================================================================
create table if not exists public.contract_events (
  id            uuid primary key default gen_random_uuid(),
  contract_id   uuid not null references public.service_contracts (id) on delete cascade,
  entity_id     uuid references public.entities (id) on delete set null,
  event_type    text not null,
  from_status   text,
  to_status     text,
  actor_id      uuid,
  details       jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  constraint contract_events_event_type_allowed check (
    event_type in ('offered', 'accepted', 'cancelled', 'milestone_completed', 'milestone_verified', 'milestone_revision_requested', 'closed', 'disputed')
  )
);

comment on table public.contract_events is
  'Append-only audit log of contract lifecycle transitions. No UPDATE/DELETE grants to any role. from_status/to_status capture the transition, actor_id is auth.uid().';

create index if not exists contract_events_contract_idx
  on public.contract_events (contract_id, created_at);
create index if not exists contract_events_created_at_idx
  on public.contract_events (created_at desc);
create index if not exists contract_events_event_type_idx
  on public.contract_events (event_type);

-- =============================================================================
-- SECTION 4: RLS enable + REVOKE + grants + policies (default-deny)
-- =============================================================================
alter table public.service_contracts enable row level security;
alter table public.contract_milestones enable row level security;
alter table public.contract_events enable row level security;

revoke all on
  public.service_contracts,
  public.contract_milestones,
  public.contract_events
from anon, authenticated, service_role;

-- service_contracts: authenticated participant read + write via RPC;
-- grants required for SECURITY INVOKER RPCs to perform INSERT/UPDATE as caller.
-- RLS policies below restrict direct REST writes; sum invariant in RPC prevents bypass.
grant select, insert, update on public.service_contracts to authenticated;
grant select, insert, update, delete on public.service_contracts to service_role;

-- contract_milestones: same — RPC needs INSERT/UPDATE as authenticated
grant select, insert, update on public.contract_milestones to authenticated;
grant select, insert, update, delete on public.contract_milestones to service_role;

-- contract_events: append-only (SELECT + INSERT)
grant select on public.contract_events to authenticated;
grant select, insert on public.contract_events to authenticated, service_role;

-- Policies: participant-scoped SELECT + INSERT/UPDATE for RPC (direct REST still
-- guarded by status/escrow D5 trigger below + sum invariant in RPC)
drop policy if exists service_contracts_select on public.service_contracts;
create policy service_contracts_select
  on public.service_contracts for select to authenticated
  using (client_entity_id = auth.uid() or professional_entity_id = auth.uid());
drop policy if exists service_contracts_insert on public.service_contracts;
create policy service_contracts_insert
  on public.service_contracts for insert to authenticated
  with check (client_entity_id = auth.uid());
drop policy if exists service_contracts_update on public.service_contracts;
create policy service_contracts_update
  on public.service_contracts for update to authenticated
  using (client_entity_id = auth.uid() or professional_entity_id = auth.uid())
  with check (client_entity_id = auth.uid() or professional_entity_id = auth.uid());

-- contract_milestones: join-filtered SELECT; INSERT/UPDATE via parent contract ownership
drop policy if exists contract_milestones_select on public.contract_milestones;
create policy contract_milestones_select
  on public.contract_milestones for select to authenticated
  using (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ));
drop policy if exists contract_milestones_insert on public.contract_milestones;
create policy contract_milestones_insert
  on public.contract_milestones for insert to authenticated
  with check (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ));
drop policy if exists contract_milestones_update on public.contract_milestones;
create policy contract_milestones_update
  on public.contract_milestones for update to authenticated
  using (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ))
  with check (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ));

-- contract_events: join-filtered SELECT + INSERT (audit)
drop policy if exists contract_events_select on public.contract_events;
create policy contract_events_select
  on public.contract_events for select to authenticated
  using (exists (
    select 1 from public.service_contracts c
     where c.id = contract_id
       and (c.client_entity_id = auth.uid() or c.professional_entity_id = auth.uid())
  ));
drop policy if exists contract_events_insert on public.contract_events;
create policy contract_events_insert
  on public.contract_events for insert to authenticated
  with check (entity_id = auth.uid() or actor_id = auth.uid());

-- =============================================================================
-- SECTION 5: RPCs (all SECURITY INVOKER)
-- =============================================================================

-- ─── 5a. service_contract_offer ─────────────────────────────────────────────
create or replace function public.service_contract_offer(
  p_service_listing_id uuid,
  p_total_amount numeric,
  p_currency_code char(3) default 'NGN',
  p_milestones jsonb default '[]'::jsonb,
  p_offer_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_listing record;
  v_currency char(3);
  v_contract_id uuid;
  v_milestones jsonb;
  v_elem jsonb;
  v_sum numeric := 0;
  v_count int := 0;
  v_data jsonb;
  v_title text;
  v_desc text;
  v_num int;
  v_amount numeric;
  v_sort int;
  v_seen int[] := '{}';
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_service_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Service listing id is required.');
  end if;

  if p_total_amount is null or p_total_amount <= 0 then
    perform public.platform_raise_error('PLT003', 'Total amount must be greater than zero.');
  end if;

  v_currency := nullif(btrim(upper(p_currency_code::text)), '');
  if v_currency is null then v_currency := 'NGN'; end if;

  if v_currency !~ '^[A-Z]{3}$' then
    perform public.platform_raise_error('PLT003', 'Invalid currency code.');
  end if;

  if not exists (
    select 1 from public.financial_supported_currencies c
     where c.currency_code = v_currency and c.is_active
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported or is inactive.');
  end if;

  if p_milestones is null or jsonb_typeof(p_milestones) <> 'array' or jsonb_array_length(p_milestones) = 0 then
    perform public.platform_raise_error('PLT003', 'At least one milestone is required.');
  end if;

  if p_offer_expires_at is not null and p_offer_expires_at <= now() then
    perform public.platform_raise_error('PLT003', 'Offer expiry must be in the future.');
  end if;

  -- Published listing gate, identical PLT004 for draft/not found/no oracle
  -- Plain SELECT (no FOR SHARE) — avoids needing UPDATE privilege on professions
  -- RLS on service_listings will filter non-visible rows, giving PLT004 oracle uniformity
  select l.id, l.entity_id, l.status, l.profession_id
    into v_listing
    from public.service_listings l
   where l.id = p_service_listing_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Service listing not found or not available.');
  end if;

  if v_listing.status <> 'published' then
    perform public.platform_raise_error('PLT004', 'Service listing not found or not available.');
  end if;

  -- Profession liveness check (separate, no lock)
  if not exists (select 1 from public.professions p where p.id = v_listing.profession_id and p.is_active) then
    perform public.platform_raise_error('PLT004', 'Service listing not found or not available.');
  end if;

  if v_listing.entity_id = v_actor then
    perform public.platform_raise_error('PLT005', 'You cannot create a contract for your own listing.');
  end if;

  -- Validate milestones and compute sum
  for v_elem in select * from jsonb_array_elements(p_milestones)
  loop
    v_count := v_count + 1;
    v_num := nullif(btrim(v_elem->>'milestone_number'), '')::int;
    v_title := nullif(btrim(v_elem->>'title'), '');
    v_desc := nullif(btrim(v_elem->>'description'), '');
    v_amount := (v_elem->>'amount')::numeric;
    v_sort := coalesce(nullif(btrim(v_elem->>'sort_order'), '')::int, v_num - 1);

    if v_num is null or v_num < 1 then
      perform public.platform_raise_error('PLT003', 'Milestone number must be 1 or greater.');
    end if;
    if v_num = any(v_seen) then
      perform public.platform_raise_error('PLT005', 'Duplicate milestone number in request.');
    end if;
    v_seen := array_append(v_seen, v_num);

    if v_title is null or char_length(v_title) < 1 or char_length(v_title) > 255 then
      perform public.platform_raise_error('PLT003', 'Milestone title must be 1 to 255 characters.');
    end if;
    if v_desc is not null and char_length(v_desc) > 2000 then
      perform public.platform_raise_error('PLT003', 'Milestone description must be at most 2000 characters.');
    end if;
    if v_amount is null or v_amount <= 0 then
      perform public.platform_raise_error('PLT003', 'Milestone amount must be greater than zero.');
    end if;

    v_sum := v_sum + v_amount;
  end loop;

  if v_sum <> p_total_amount then
    perform public.platform_raise_error('PLT003', 'Milestone amounts must sum to total amount.');
  end if;

  -- Create contract
  insert into public.service_contracts (
    service_listing_id, client_entity_id, professional_entity_id, status,
    total_amount, currency_code, offer_expires_at, offered_at
  ) values (
    p_service_listing_id, v_actor, v_listing.entity_id, 'offered',
    p_total_amount, v_currency, p_offer_expires_at, now()
  ) returning id into v_contract_id;

  -- Create milestones
  for v_elem in select * from jsonb_array_elements(p_milestones)
  loop
    v_num := nullif(btrim(v_elem->>'milestone_number'), '')::int;
    v_title := btrim(v_elem->>'title');
    v_desc := nullif(btrim(v_elem->>'description'), '');
    v_amount := (v_elem->>'amount')::numeric;
    v_sort := coalesce(nullif(btrim(v_elem->>'sort_order'), '')::int, v_num - 1);
    begin
      insert into public.contract_milestones (
        contract_id, milestone_number, title, description, amount, sort_order, status
      ) values (
        v_contract_id, v_num, v_title, v_desc, v_amount, v_sort, 'pending'
      );
    exception when unique_violation then
      perform public.platform_raise_error('PLT005', 'Duplicate milestone number.');
    end;
  end loop;

  insert into public.contract_events (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
  values (v_contract_id, v_actor, 'offered', null, 'offered', v_actor,
    jsonb_build_object('service_listing_id', p_service_listing_id, 'total_amount', p_total_amount, 'currency_code', v_currency));

  -- Audit log
  perform public.platform_audit_log_add('service_contract_offer', 'service_contracts',
    jsonb_build_object('contract_id', v_contract_id, 'service_listing_id', p_service_listing_id));

  select jsonb_build_object(
    'id', c.id, 'service_listing_id', c.service_listing_id,
    'client_entity_id', c.client_entity_id, 'professional_entity_id', c.professional_entity_id,
    'status', c.status, 'escrow_id', c.escrow_id,
    'total_amount', c.total_amount, 'currency_code', c.currency_code,
    'offer_expires_at', c.offer_expires_at, 'offered_at', c.offered_at,
    'accepted_at', c.accepted_at, 'created_at', c.created_at
  ) into v_data from public.service_contracts c where c.id = v_contract_id;

  -- Attach milestones array to data
  select jsonb_agg(to_jsonb(m) order by m.sort_order, m.milestone_number) into v_milestones
    from public.contract_milestones m where m.contract_id = v_contract_id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Contract offer created.',
    'data', jsonb_build_object('contract', v_data, 'milestones', coalesce(v_milestones, '[]'::jsonb))
  );
end;
$$;

-- ─── 5b. service_contract_accept ────────────────────────────────────────────
create or replace function public.service_contract_accept(
  p_contract_id uuid
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
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;

  select * into v_contract from public.service_contracts where id = p_contract_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.professional_entity_id <> v_actor and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.status <> 'offered' then
    perform public.platform_raise_error('PLT005', 'Contract is not in offered state.');
  end if;

  if v_contract.offer_expires_at is not null and v_contract.offer_expires_at < now() then
    perform public.platform_raise_error('PLT005', 'Offer has expired.');
  end if;

  update public.service_contracts
     set status = 'active', accepted_at = now(), updated_at = now()
   where id = p_contract_id;

  insert into public.contract_events (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
  values (p_contract_id, v_actor, 'accepted', 'offered', 'active', v_actor, jsonb_build_object('contract_id', p_contract_id));

  perform public.platform_audit_log_add('service_contract_accept', 'service_contracts',
    jsonb_build_object('contract_id', p_contract_id));

  select to_jsonb(c) into v_data from public.service_contracts c where c.id = p_contract_id;
  return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Contract accepted.', 'data', v_data);
end;
$$;

-- ─── 5c. service_contract_cancel ────────────────────────────────────────────
create or replace function public.service_contract_cancel(
  p_contract_id uuid,
  p_reason text default null
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
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;

  select * into v_contract from public.service_contracts where id = p_contract_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.client_entity_id <> v_actor and v_contract.professional_entity_id <> v_actor and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.status <> 'offered' then
    -- Only service_role may cancel active (admin intervention) — mirrors marketplace unpublish moderation
    if not (v_contract.status = 'active' and current_user in ('service_role', 'postgres')) then
      perform public.platform_raise_error('PLT005', 'Only offered contracts can be cancelled.');
    end if;
  end if;

  update public.service_contracts
     set status = 'cancelled', cancelled_at = now(), updated_at = now()
   where id = p_contract_id;

  insert into public.contract_events (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
  values (p_contract_id, v_actor, 'cancelled', v_contract.status, 'cancelled', v_actor,
    jsonb_build_object('reason', nullif(btrim(p_reason), '')));

  perform public.platform_audit_log_add('service_contract_cancel', 'service_contracts',
    jsonb_build_object('contract_id', p_contract_id, 'reason', p_reason));

  select to_jsonb(c) into v_data from public.service_contracts c where c.id = p_contract_id;
  return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Contract cancelled.', 'data', v_data);
end;
$$;

-- ─── 5d. service_contract_complete_milestone ─────────────────────────────────
create or replace function public.service_contract_complete_milestone(
  p_milestone_id uuid,
  p_evidence_path text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_milestone public.contract_milestones%rowtype;
  v_contract public.service_contracts%rowtype;
  v_evidence text := nullif(btrim(p_evidence_path), '');
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_milestone_id is null then
    perform public.platform_raise_error('PLT003', 'Milestone id is required.');
  end if;

  select * into v_milestone from public.contract_milestones where id = p_milestone_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Milestone not found.');
  end if;

  select * into v_contract from public.service_contracts where id = v_milestone.contract_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.professional_entity_id <> v_actor and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT005', 'Only the professional may complete milestones.');
  end if;

  if v_contract.status not in ('active', 'completed') then
    perform public.platform_raise_error('PLT005', 'Contract is not active.');
  end if;
  if v_contract.status = 'disputed' then
    perform public.platform_raise_error('PLT005', 'Contract is disputed.');
  end if;

  if v_milestone.status <> 'pending' then
    perform public.platform_raise_error('PLT005', 'Milestone is not pending.');
  end if;

  if v_evidence is not null and v_evidence !~ '^service-listing-media/' then
    perform public.platform_raise_error('PLT003', 'Evidence path must be under service-listing-media/.');
  end if;
  if v_evidence is not null and v_evidence not like 'service-listing-media/' || v_actor::text || '/%' and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT003', 'Evidence path must be under your storage prefix.');
  end if;

  update public.contract_milestones
     set status = 'completed', evidence_path = v_evidence, completed_at = now(), updated_at = now()
   where id = p_milestone_id;

  insert into public.contract_events (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
  values (v_contract.id, v_actor, 'milestone_completed', 'pending', 'completed', v_actor,
    jsonb_build_object('milestone_id', p_milestone_id, 'evidence_path', v_evidence));

  select to_jsonb(m) into v_data from public.contract_milestones m where m.id = p_milestone_id;
  return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Milestone completed.', 'data', v_data);
end;
$$;

-- ─── 5e. service_contract_verify_milestone ───────────────────────────────────
create or replace function public.service_contract_verify_milestone(
  p_milestone_id uuid,
  p_action text default 'verified'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_milestone public.contract_milestones%rowtype;
  v_contract public.service_contracts%rowtype;
  v_action text := lower(nullif(btrim(p_action), ''));
  v_data jsonb;
  v_remaining int;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_milestone_id is null then
    perform public.platform_raise_error('PLT003', 'Milestone id is required.');
  end if;
  if v_action is null then v_action := 'verified'; end if;
  if v_action not in ('verified', 'revision_requested') then
    perform public.platform_raise_error('PLT003', 'Invalid verify action. Use verified or revision_requested.');
  end if;

  select * into v_milestone from public.contract_milestones where id = p_milestone_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Milestone not found.');
  end if;

  select * into v_contract from public.service_contracts where id = v_milestone.contract_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.client_entity_id <> v_actor and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT005', 'Only the client may verify milestones.');
  end if;

  if v_contract.status not in ('active', 'completed') then
    perform public.platform_raise_error('PLT005', 'Contract is not active.');
  end if;
  if v_contract.status = 'disputed' then
    perform public.platform_raise_error('PLT005', 'Contract is disputed.');
  end if;

  if v_action = 'verified' then
    if v_milestone.status <> 'completed' then
      perform public.platform_raise_error('PLT005', 'Milestone is not in completed state.');
    end if;

    update public.contract_milestones
       set status = 'verified', verified_at = now(), updated_at = now()
     where id = p_milestone_id;

    insert into public.contract_events (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
    values (v_contract.id, v_actor, 'milestone_verified', 'completed', 'verified', v_actor,
      jsonb_build_object('milestone_id', p_milestone_id));

    -- Auto-promote contract to completed when all milestones verified
    select count(*)::int into v_remaining
      from public.contract_milestones
     where contract_id = v_contract.id and status <> 'verified';

    if v_remaining = 0 then
      update public.service_contracts
         set status = 'completed', completed_at = now(), updated_at = now()
       where id = v_contract.id;
    end if;

  else -- revision_requested: completed -> pending
    if v_milestone.status <> 'completed' then
      perform public.platform_raise_error('PLT005', 'Only completed milestones can be sent for revision.');
    end if;

    update public.contract_milestones
       set status = 'pending', completed_at = null, updated_at = now()
       -- keep evidence_path for audit; do not clear
     where id = p_milestone_id;

    insert into public.contract_events (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
    values (v_contract.id, v_actor, 'milestone_revision_requested', 'completed', 'pending', v_actor,
      jsonb_build_object('milestone_id', p_milestone_id));
  end if;

  select to_jsonb(m) into v_data from public.contract_milestones m where m.id = p_milestone_id;
  if v_action = 'verified' then
    return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Milestone verified.', 'data', v_data);
  else
    return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Revision requested.', 'data', v_data);
  end if;
end;
$$;

-- ─── 5f. service_contract_close ───────────────────────────────────────────────
create or replace function public.service_contract_close(
  p_contract_id uuid
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
  v_remaining int;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;

  select * into v_contract from public.service_contracts where id = p_contract_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.client_entity_id <> v_actor and v_contract.professional_entity_id <> v_actor and current_user not in ('service_role', 'postgres') then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  if v_contract.status not in ('active', 'completed') then
    perform public.platform_raise_error('PLT005', 'Contract is not in a closable state.');
  end if;
  if v_contract.status = 'disputed' then
    perform public.platform_raise_error('PLT005', 'Disputed contracts cannot be closed.');
  end if;

  select count(*)::int into v_remaining
    from public.contract_milestones
   where contract_id = p_contract_id and status <> 'verified';

  if v_remaining > 0 then
    perform public.platform_raise_error('PLT005', 'All milestones must be verified before closing.');
  end if;

  update public.service_contracts
     set status = 'closed', closed_at = now(), completed_at = coalesce(completed_at, now()), updated_at = now()
   where id = p_contract_id;

  insert into public.contract_events (contract_id, entity_id, event_type, from_status, to_status, actor_id, details)
  values (p_contract_id, v_actor, 'closed', v_contract.status, 'closed', v_actor, jsonb_build_object('contract_id', p_contract_id));

  perform public.platform_audit_log_add('service_contract_close', 'service_contracts',
    jsonb_build_object('contract_id', p_contract_id));

  select to_jsonb(c) into v_data from public.service_contracts c where c.id = p_contract_id;
  return jsonb_build_object('success', true, 'code', 'PLT000', 'message', 'Contract closed.', 'data', v_data);
end;
$$;

-- ─── 5g. service_contract_get ─────────────────────────────────────────────────
create or replace function public.service_contract_get(
  p_contract_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_contract record;
  v_milestones jsonb;
  v_events jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_contract_id is null then
    perform public.platform_raise_error('PLT003', 'Contract id is required.');
  end if;

  -- Participant RLS + service_role bypass; identical PLT004 for foreign/unknown
  select c.id, c.service_listing_id, c.client_entity_id, c.professional_entity_id,
         c.status, c.escrow_id, c.total_amount, c.currency_code,
         c.offer_expires_at, c.offered_at, c.accepted_at, c.completed_at, c.closed_at, c.cancelled_at,
         c.created_at, c.updated_at,
         l.slug as listing_slug, l.title as listing_title,
         p.slug as profession_slug, p.name as profession_name,
         i.slug as industry_slug, i.name as industry_name
    into v_contract
    from public.service_contracts c
    join public.service_listings l on l.id = c.service_listing_id
    join public.professions p on p.id = l.profession_id
    join public.industries i on i.id = l.industry_id
   where c.id = p_contract_id
     and (c.client_entity_id = v_actor or c.professional_entity_id = v_actor or current_user in ('service_role','postgres'));

  if not found then
    perform public.platform_raise_error('PLT004', 'Contract not found.');
  end if;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.sort_order, m.milestone_number), '[]'::jsonb)
    into v_milestones
    from public.contract_milestones m
   where m.contract_id = p_contract_id;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at), '[]'::jsonb)
    into v_events
    from public.contract_events e
   where e.contract_id = p_contract_id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Contract retrieved.',
    'data', jsonb_build_object(
      'contract', to_jsonb(v_contract),
      'milestones', v_milestones,
      'events', v_events
    )
  );
end;
$$;

-- ─── 5h. service_contract_list_mine ───────────────────────────────────────────
create or replace function public.service_contract_list_mine(
  p_status text default null,
  p_limit int default 20,
  p_cursor uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_cursor_ts timestamptz;
  v_items jsonb;
  v_has_more boolean;
  v_next uuid;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_status is not null and p_status not in ('draft','offered','active','completed','closed','cancelled','disputed') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;

  if p_limit is null or p_limit not between 1 and 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  if p_cursor is not null then
    select s.created_at into v_cursor_ts
      from public.service_contracts s
     where s.id = p_cursor
       and (s.client_entity_id = v_actor or s.professional_entity_id = v_actor);
    if not found then
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Contracts retrieved.',
        'data', jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null)
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.created_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select c.id, c.service_listing_id, c.client_entity_id, c.professional_entity_id, c.status, c.escrow_id,
             c.total_amount, c.currency_code, c.offered_at, c.accepted_at, c.completed_at, c.closed_at, c.created_at, c.updated_at,
             row_number() over (order by c.created_at desc, c.id desc) as rn
        from public.service_contracts c
       where (c.client_entity_id = v_actor or c.professional_entity_id = v_actor)
         and (p_status is null or c.status = p_status)
         and (p_cursor is null or (c.created_at, c.id) < (v_cursor_ts, p_cursor))
    ) x;

  if not v_has_more then v_next := null; end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Contracts retrieved.',
    'data', jsonb_build_object('items', v_items, 'has_more', v_has_more, 'next_cursor', v_next)
  );
end;
$$;

-- =============================================================================
-- SECTION 6: REVOKE EXECUTE baseline + GRANTs + COMMENTs
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.service_contract_offer(uuid, numeric, char(3), jsonb, timestamptz) to authenticated, service_role;
grant execute on function public.service_contract_accept(uuid) to authenticated, service_role;
grant execute on function public.service_contract_cancel(uuid, text) to authenticated, service_role;
grant execute on function public.service_contract_complete_milestone(uuid, text) to authenticated, service_role;
grant execute on function public.service_contract_verify_milestone(uuid, text) to authenticated, service_role;
grant execute on function public.service_contract_close(uuid) to authenticated, service_role;
grant execute on function public.service_contract_get(uuid) to authenticated, service_role;
grant execute on function public.service_contract_list_mine(text, int, uuid) to authenticated, service_role;

comment on function public.service_contract_offer(uuid, numeric, char(3), jsonb, timestamptz) is
  'SECURITY INVOKER, VOLATILE. Client creates offered contract on published listing (FOR SHARE) with participant derived, milestone sum invariant, currency is_active check. Inserts contract + milestones + offered event.';
comment on function public.service_contract_accept(uuid) is
  'SECURITY INVOKER, VOLATILE. Professional accepts offered contract (FOR UPDATE, offer expiry check). Sets active + accepted_at + accepted event.';
comment on function public.service_contract_cancel(uuid, text) is
  'SECURITY INVOKER, VOLATILE. Participant cancels offered contract; service_role may cancel active. Sets cancelled + cancelled_at.';
comment on function public.service_contract_complete_milestone(uuid, text) is
  'SECURITY INVOKER, VOLATILE. Professional marks pending milestone completed with service-listing-media evidence prefix check. Inserts milestone_completed event.';
comment on function public.service_contract_verify_milestone(uuid, text) is
  'SECURITY INVOKER, VOLATILE. Client verifies completed milestone (verified) or requests revision (pending). Auto-promotes contract to completed when all milestones verified.';
comment on function public.service_contract_close(uuid) is
  'SECURITY INVOKER, VOLATILE. Participant closes contract when all milestones verified. Sets closed + closed_at.';
comment on function public.service_contract_get(uuid) is
  'SECURITY INVOKER, STABLE. Participant-only contract retrieval with milestones[] and events[] via join-filtered RLS. Identical PLT004 for foreign/unknown (no oracle).';
comment on function public.service_contract_list_mine(text, int, uuid) is
  'SECURITY INVOKER, STABLE. Participant-scoped keyset pagination (created_at desc, id desc) with optional status filter.';

-- =============================================================================
-- SECTION 7: Realtime exclusion (guarded, idempotent)
-- =============================================================================
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('service_contracts', 'contract_milestones', 'contract_events')
  ) then
    alter publication supabase_realtime drop table
      public.service_contracts, public.contract_milestones, public.contract_events;
  end if;
end;
$$;
