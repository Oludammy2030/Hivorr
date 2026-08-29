-- =============================================================================
-- EP-02-05: Dispute Resolution Schema & Server-Side Rules
-- -----------------------------------------------------------------------------
-- Migration: 20260829120005_dispute_resolution_schema.sql
-- Depends on: 20260819090001_enforcement_foundation.sql (platform_* helpers)
--             20260819090003_foundational_rpcs.sql (platform_audit_log_add)
--             20260829100004_financial_integrity_schema.sql (financial_* tables)
--             20260821090002_entity_core_tables.sql (entities, entity_profiles)
--
-- EXECUTION MODEL
--   5 RPCs are SECURITY INVOKER (RLS applies inside the body). 3 functions are
--   SECURITY DEFINER with a pinned search_path = pg_catalog, public:
--     - dispute_place_escrow_hold, dispute_release_escrow_hold (internal helpers):
--       required because `authenticated` has no UPDATE grant on financial_escrow.
--       Narrowly scoped (one escrow state transition + audit write), named with
--       the `dispute_` prefix (no `financial_%` SECURITY DEFINER conflict with
--       013), and validate the caller is a party to the escrow (service_role is
--       trusted and bypasses the party check).
--     - dispute_withdraw: required because `authenticated` has no UPDATE grant on
--       dispute_cases (status is server-controlled per SV-18/FV-18). It re-uses
--       the DEFINER release-escrow-hold helper and only flips its own case to
--       `withdrawn`; filer-scoping is enforced inside the body.
--
-- ENVELOPE CONTRACT
--   Every RPC returns {success, code, message, data}.
--   PLT000 success; PLT001 auth; PLT003 validation; PLT004 not found; PLT005 conflict.
--
-- DISPUTE STATE MACHINE
--   open -> under_review -> resolved -> closed (terminal)
--   open -> withdrawn (terminal)
--   Escrow effects: open => escrow disputed (hold placed); resolved => escrow
--   released/refunded per outcome; withdrawn/dismissed => escrow hold released
--   (disputed -> funded) with no balance movement.
--
-- ESCROW-DISPUTE INTEGRATION
--   `dispute_file` places the hold via dispute_place_escrow_hold (escrow
--   funded/partially_released -> disputed). `dispute_resolve` performs escrow
--   transitions + double-entry financial movements INLINE (it does NOT call
--   financial_escrow_release/refund, which reject the `disputed` source state)
--   and runs as service_role (the only role granted EXECUTE on dispute_resolve).
--   `dispute_withdraw` / `dispute_resolve (dismissed)` release the hold via
--   dispute_release_escrow_hold (escrow disputed -> funded).
--
-- SECURITY POSTURE
--   All 4 tables default-deny; party-scoped RLS; anon zero grants; status and
--   resolution timestamps are server-controlled (not writable by authenticated);
--   evidence/resolutions/audit are immutable (no UPDATE/DELETE to any client role);
--   Realtime excludes all 4 tables; no client-side code is created.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SECTION 1: dispute_cases
-- -----------------------------------------------------------------------------
create table if not exists public.dispute_cases (
  id                    uuid primary key default gen_random_uuid(),
  escrow_id             uuid not null
                        references public.financial_escrow(id) on delete restrict,
  filer_entity_id       uuid not null
                        references public.entities(id) on delete restrict,
  counterparty_entity_id uuid not null
                        references public.entities(id) on delete restrict,
  dispute_type          text not null
                        check (dispute_type in
                          ('service_quality', 'non_delivery',
                           'milestone_disagreement', 'fraud', 'other')),
  status                text not null default 'open'
                        check (status in
                          ('open', 'under_review', 'resolved', 'closed', 'withdrawn')),
  reason                text not null
                        check (char_length(btrim(reason)) between 10 and 2000),
  desired_outcome       text
                        check (desired_outcome is null or desired_outcome in
                          ('release_to_payee', 'refund_to_payer', 'split', 'other')),
  priority              text not null default 'medium'
                        check (priority in ('low', 'medium', 'high', 'critical')),
  filed_at             timestamptz not null default now(),
  resolved_at          timestamptz,
  closed_at            timestamptz,
  withdrawn_at         timestamptz,
  metadata              jsonb not null default '{}'::jsonb,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  created_by           uuid default auth.uid()
);

comment on table public.dispute_cases is
  'Dispute cases linking a marketplace escrow to the two parties; drives the dispute state machine.';

create index if not exists dispute_cases_escrow_idx
  on public.dispute_cases (escrow_id);
create index if not exists dispute_cases_filer_idx
  on public.dispute_cases (filer_entity_id, status);
create index if not exists dispute_cases_counterparty_idx
  on public.dispute_cases (counterparty_entity_id, status);
create index if not exists dispute_cases_status_idx
  on public.dispute_cases (status);
create index if not exists dispute_cases_filed_at_idx
  on public.dispute_cases (filed_at desc);
create unique index if not exists dispute_cases_one_open_per_escrow_idx
  on public.dispute_cases (escrow_id)
  where status in ('open', 'under_review');

-- -----------------------------------------------------------------------------
-- SECTION 2: dispute_evidence (immutable)
-- -----------------------------------------------------------------------------
create table if not exists public.dispute_evidence (
  id            uuid primary key default gen_random_uuid(),
  case_id       uuid not null
                references public.dispute_cases(id) on delete cascade,
  submitted_by  uuid not null
                references public.entities(id) on delete restrict,
  evidence_type text not null
                check (evidence_type in ('document', 'screenshot', 'description', 'photo')),
  title         text not null
                check (char_length(btrim(title)) between 1 and 255),
  description   text
                check (description is null or char_length(description) <= 2000),
  file_url      text,
  file_metadata jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  created_by    uuid default auth.uid()
);

comment on table public.dispute_evidence is
  'Immutable evidence submissions by either dispute party. No UPDATE/DELETE grants.';

create index if not exists dispute_evidence_case_idx
  on public.dispute_evidence (case_id, created_at);
create index if not exists dispute_evidence_submitted_by_idx
  on public.dispute_evidence (submitted_by);

-- -----------------------------------------------------------------------------
-- SECTION 3: dispute_resolutions (immutable)
-- -----------------------------------------------------------------------------
create table if not exists public.dispute_resolutions (
  id                   uuid primary key default gen_random_uuid(),
  case_id              uuid not null unique
                       references public.dispute_cases(id) on delete restrict,
  resolved_by          uuid
                       references public.entities(id) on delete set null,
  resolution_type      text not null
                       check (resolution_type in
                         ('release_to_payee', 'refund_to_payer', 'split', 'dismissed')),
  reasoning            text not null
                       check (char_length(btrim(reasoning)) between 10 and 5000),
  payer_refund_amount  numeric not null default 0 check (payer_refund_amount >= 0),
  payee_release_amount numeric not null default 0 check (payee_release_amount >= 0),
  notes                text,
  resolved_at          timestamptz not null default now(),
  created_at           timestamptz not null default now(),
  created_by           uuid default auth.uid()
);

comment on table public.dispute_resolutions is
  'Immutable binding resolution decisions. INSERT only by service_role; no UPDATE/DELETE.';

create index if not exists dispute_resolutions_case_key
  on public.dispute_resolutions (case_id);

-- -----------------------------------------------------------------------------
-- SECTION 4: dispute_audit_trail (append-only)
-- -----------------------------------------------------------------------------
create table if not exists public.dispute_audit_trail (
  id           uuid primary key default gen_random_uuid(),
  case_id      uuid not null
               references public.dispute_cases(id) on delete cascade,
  entity_id    uuid
               references public.entities(id) on delete set null,
  event_type   text not null
               check (event_type in
                 ('case_filed', 'escrow_hold_placed', 'evidence_submitted',
                  'status_under_review', 'case_resolved', 'case_withdrawn',
                  'escrow_hold_released', 'case_closed', 'financial_release',
                  'financial_refund', 'financial_split')),
  subject_type text
               check (subject_type in
                 ('dispute_case', 'dispute_evidence', 'dispute_resolution', 'escrow_hold')),
  subject_id   uuid,
  from_state   text,
  to_state     text,
  actor_id     uuid,
  details      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

comment on table public.dispute_audit_trail is
  'Authoritative immutable dispute audit log (append-only, no UPDATE/DELETE).';

create index if not exists dispute_audit_trail_case_idx
  on public.dispute_audit_trail (case_id, created_at);
create index if not exists dispute_audit_trail_created_at_idx
  on public.dispute_audit_trail (created_at desc);
create index if not exists dispute_audit_trail_subject_idx
  on public.dispute_audit_trail (subject_type, subject_id);

-- -----------------------------------------------------------------------------
-- SECTION 5: updated_at trigger (single mutable table: dispute_cases)
-- -----------------------------------------------------------------------------
create trigger dispute_cases_set_updated_at before update on public.dispute_cases
  for each row execute function public.platform_set_updated_at();

-- -----------------------------------------------------------------------------
-- SECTION 6: RLS enable + revoke + grants + party-scoped policies (default-deny)
-- -----------------------------------------------------------------------------
alter table public.dispute_cases enable row level security;
alter table public.dispute_evidence enable row level security;
alter table public.dispute_resolutions enable row level security;
alter table public.dispute_audit_trail enable row level security;

-- Revoke all blanket privileges (mirrors enforcement_foundation pattern)
revoke all on
  public.dispute_cases,
  public.dispute_evidence,
  public.dispute_resolutions,
  public.dispute_audit_trail
from anon, authenticated, service_role;

-- dispute_cases: self read/insert (auth, limited cols); full (service_role)
grant select on public.dispute_cases to authenticated;
grant insert (escrow_id, filer_entity_id, counterparty_entity_id, dispute_type, reason, desired_outcome, priority)
  on public.dispute_cases to authenticated;
grant select, insert, update on public.dispute_cases to service_role;

-- dispute_evidence: self read (party) / insert (limited, self); read/insert (service_role)
grant select on public.dispute_evidence to authenticated;
grant insert (case_id, submitted_by, evidence_type, title, description, file_url, file_metadata)
  on public.dispute_evidence to authenticated;
grant select, insert on public.dispute_evidence to service_role;

-- dispute_resolutions: self read (party); read/insert (service_role). NO auth insert.
grant select on public.dispute_resolutions to authenticated;
grant select, insert on public.dispute_resolutions to service_role;

-- dispute_audit_trail: self read (party) / insert (self); read/insert (service_role)
grant select on public.dispute_audit_trail to authenticated;
grant insert (case_id, entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details)
  on public.dispute_audit_trail to authenticated;
grant select, insert on public.dispute_audit_trail to service_role;

-- Self-scoped RLS policies (service_role bypasses RLS; these constrain anon/authenticated)
create policy dispute_cases_select on public.dispute_cases
  for select to authenticated
  using (filer_entity_id = auth.uid() or counterparty_entity_id = auth.uid());
create policy dispute_cases_insert on public.dispute_cases
  for insert to authenticated
  with check (filer_entity_id = auth.uid());

create policy dispute_evidence_select on public.dispute_evidence
  for select to authenticated
  using (exists (
    select 1 from public.dispute_cases c
     where c.id = case_id
       and (c.filer_entity_id = auth.uid() or c.counterparty_entity_id = auth.uid())
  ));
create policy dispute_evidence_insert on public.dispute_evidence
  for insert to authenticated
  with check (submitted_by = auth.uid());

create policy dispute_resolutions_select on public.dispute_resolutions
  for select to authenticated
  using (exists (
    select 1 from public.dispute_cases c
     where c.id = case_id
       and (c.filer_entity_id = auth.uid() or c.counterparty_entity_id = auth.uid())
  ));

create policy dispute_audit_trail_select on public.dispute_audit_trail
  for select to authenticated
  using (exists (
    select 1 from public.dispute_cases c
     where c.id = case_id
       and (c.filer_entity_id = auth.uid() or c.counterparty_entity_id = auth.uid())
  ));
create policy dispute_audit_trail_insert on public.dispute_audit_trail
  for insert to authenticated
  with check (entity_id = auth.uid());

-- =============================================================================
-- SECTION 7: Internal SECURITY DEFINER helpers (escrow hold lifecycle)
-- =============================================================================

-- 7.1 dispute_place_escrow_hold ----------------------------------------------
create or replace function public.dispute_place_escrow_hold(p_escrow_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_escrow public.financial_escrow;
  v_case_id uuid;
begin
  if p_escrow_id is null then
    perform public.platform_raise_error('PLT003', 'Escrow id is required.');
  end if;

  select * into v_escrow from public.financial_escrow where id = p_escrow_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;

  -- Authenticated callers must be a party; service_role (no auth.uid) is trusted.
  if v_actor is not null then
    if v_actor not in (v_escrow.payer_entity_id, v_escrow.payee_entity_id) then
      perform public.platform_raise_error('PLT003', 'Not authorized to place a hold on this escrow.');
    end if;
  end if;

  if v_escrow.status not in ('funded', 'partially_released') then
    perform public.platform_raise_error('PLT005', 'Escrow is not in a state that can be disputed.');
  end if;

  select id into v_case_id
    from public.dispute_cases
   where escrow_id = p_escrow_id and status in ('open', 'under_review')
   limit 1;

  update public.financial_escrow
     set status = 'disputed', updated_at = now()
   where id = v_escrow.id;

  insert into public.dispute_audit_trail (case_id, entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details)
  values (v_case_id, v_actor, 'escrow_hold_placed', 'escrow_hold', v_escrow.id, v_escrow.status, 'disputed', v_actor,
    jsonb_build_object('escrow_id', v_escrow.id));
end;
$$;

-- 7.2 dispute_release_escrow_hold --------------------------------------------
create or replace function public.dispute_release_escrow_hold(p_escrow_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_escrow public.financial_escrow;
  v_case_id uuid;
begin
  if p_escrow_id is null then
    perform public.platform_raise_error('PLT003', 'Escrow id is required.');
  end if;

  select * into v_escrow from public.financial_escrow where id = p_escrow_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;

  if v_actor is not null then
    if v_actor not in (v_escrow.payer_entity_id, v_escrow.payee_entity_id) then
      perform public.platform_raise_error('PLT003', 'Not authorized to release a hold on this escrow.');
    end if;
  end if;

  if v_escrow.status <> 'disputed' then
    perform public.platform_raise_error('PLT005', 'Escrow is not in a disputed state.');
  end if;

  select id into v_case_id
    from public.dispute_cases
   where escrow_id = p_escrow_id and status in ('open', 'under_review')
   limit 1;

  update public.financial_escrow
     set status = 'funded', updated_at = now()
   where id = v_escrow.id;

  insert into public.dispute_audit_trail (case_id, entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details)
  values (v_case_id, v_actor, 'escrow_hold_released', 'escrow_hold', v_escrow.id, 'disputed', 'funded', v_actor,
    jsonb_build_object('escrow_id', v_escrow.id));
end;
$$;

-- =============================================================================
-- SECTION 8: RPCs
-- =============================================================================

-- 8.1 dispute_file --------------------------------------------------------
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

   -- Plain read (no FOR UPDATE): `authenticated` lacks UPDATE grant on
   -- financial_escrow. The lock + validation + state transition are performed
   -- inside the SECURITY DEFINER helper dispute_place_escrow_hold.
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

-- 8.2 dispute_submit_evidence ------------------------------------------------
create or replace function public.dispute_submit_evidence(
  p_case_id uuid,
  p_evidence_type text,
  p_title text,
  p_description text default null,
  p_file_url text default null,
  p_file_metadata jsonb default '{}'
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.dispute_cases;
  v_evidence_type text := nullif(btrim(p_evidence_type), '');
  v_title text := nullif(btrim(p_title), '');
  v_description text := nullif(btrim(p_description), '');
  v_file_url text := nullif(btrim(p_file_url), '');
  v_evidence_id uuid;
  v_row public.dispute_evidence;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_case_id is null then
    perform public.platform_raise_error('PLT003', 'Case id is required.');
  end if;
  if v_evidence_type is null or v_evidence_type not in
     ('document', 'screenshot', 'description', 'photo') then
    perform public.platform_raise_error('PLT003', 'Evidence type is invalid.');
  end if;
  if v_title is null or char_length(v_title) < 1 or char_length(v_title) > 255 then
    perform public.platform_raise_error('PLT003', 'Evidence title must be 1 to 255 characters.');
  end if;
  if v_description is not null and char_length(v_description) > 2000 then
    perform public.platform_raise_error('PLT003', 'Evidence description must be 2000 characters or fewer.');
  end if;

  select * into v_case from public.dispute_cases where id = p_case_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Dispute case not found.');
  end if;
  if v_actor not in (v_case.filer_entity_id, v_case.counterparty_entity_id) then
    perform public.platform_raise_error('PLT004', 'Not authorized to access this dispute.');
  end if;
  if v_case.status not in ('open', 'under_review') then
    perform public.platform_raise_error('PLT005', 'Evidence may only be submitted for an open or under-review dispute.');
  end if;

  insert into public.dispute_evidence (case_id, submitted_by, evidence_type, title, description, file_url, file_metadata)
  values (p_case_id, v_actor, v_evidence_type, v_title, v_description, v_file_url, coalesce(p_file_metadata, '{}'::jsonb))
  returning id into v_evidence_id;

  insert into public.dispute_audit_trail (case_id, entity_id, event_type, subject_type, subject_id, actor_id, details)
  values (p_case_id, v_actor, 'evidence_submitted', 'dispute_evidence', v_evidence_id, v_actor,
    jsonb_build_object('evidence_type', v_evidence_type));

  perform public.platform_audit_log_add('dispute_submit_evidence', 'dispute_evidence',
    jsonb_build_object('case_id', p_case_id, 'evidence_id', v_evidence_id));

  select * into v_row from public.dispute_evidence where id = v_evidence_id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Evidence submitted.',
    'data', to_jsonb(v_row)
  );
end;
$$;

-- 8.3 dispute_resolve -------------------------------------------------------
-- service_role only. Performs inline double-entry financial movements and escrow
-- state transitions. Runs as service_role (full grants on financial_* tables).
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

-- 8.4 dispute_withdraw -------------------------------------------------------
-- SECURITY DEFINER: body does `UPDATE dispute_cases SET status='withdrawn'`, but
-- `authenticated` has no UPDATE grant on dispute_cases (status is server-controlled
-- per SV-18/FV-18). Filer-scoping is enforced inside the body. (See header note.)
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

-- 8.5 dispute_get ------------------------------------------------------------
create or replace function public.dispute_get(p_case_id uuid)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.dispute_cases;
  v_evidence jsonb;
  v_resolution jsonb;
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

  select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb)
    into v_evidence
    from public.dispute_evidence t
   where t.case_id = v_case.id;

  select to_jsonb(t) into v_resolution
    from public.dispute_resolutions t
   where t.case_id = v_case.id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Dispute retrieved.',
    'data', jsonb_build_object('case', to_jsonb(v_case), 'evidence', v_evidence, 'resolution', v_resolution)
  );
end;
$$;

-- 8.6 dispute_list -----------------------------------------------------------
create or replace function public.dispute_list(p_status text default null)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_status text := nullif(btrim(p_status), '');
  v_rows jsonb;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if v_status is not null and v_status not in ('open', 'under_review', 'resolved', 'closed', 'withdrawn') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.filed_at desc), '[]'::jsonb)
    into v_rows
    from public.dispute_cases t
   where (filer_entity_id = v_actor or counterparty_entity_id = v_actor)
     and (v_status is null or status = v_status);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Disputes listed.',
    'data', jsonb_build_object('disputes', v_rows)
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- SECTION 9: EXECUTE grants (revoke from public pseudo-role, then grant)
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema public from public;

-- Entity-facing RPCs (authenticated + service_role)
grant execute on function public.dispute_file(uuid, text, text, text, text) to authenticated, service_role;
grant execute on function public.dispute_submit_evidence(uuid, text, text, text, text, jsonb) to authenticated, service_role;
grant execute on function public.dispute_withdraw(uuid) to authenticated, service_role;
grant execute on function public.dispute_get(uuid) to authenticated, service_role;
grant execute on function public.dispute_list(text) to authenticated, service_role;

-- Admin/system RPC (service_role only)
grant execute on function public.dispute_resolve(uuid, text, text, numeric, numeric, text) to service_role;

-- Internal helpers (authenticated + service_role; caller-validated internally)
grant execute on function public.dispute_place_escrow_hold(uuid) to authenticated, service_role;
grant execute on function public.dispute_release_escrow_hold(uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- SECTION 10: function comments (documentation)
-- -----------------------------------------------------------------------------
comment on function public.dispute_place_escrow_hold(uuid) is
  'SECURITY DEFINER helper: transition escrow funded/partially_released -> disputed (place hold). Validates caller is a party (service_role trusted). Writes dispute_audit_trail.';
comment on function public.dispute_release_escrow_hold(uuid) is
  'SECURITY DEFINER helper: transition escrow disputed -> funded (release hold). Validates caller is a party (service_role trusted). Writes dispute_audit_trail.';
comment on function public.dispute_file(uuid, text, text, text, text) is
  'File a dispute against an escrow; places an automatic escrow hold. Self-scoped (party); SECURITY INVOKER; VOLATILE. EXECUTE granted to authenticated, service_role.';
comment on function public.dispute_submit_evidence(uuid, text, text, text, text, jsonb) is
  'Submit immutable evidence for an open/under-review dispute. Party-scoped; SECURITY INVOKER; VOLATILE. EXECUTE granted to authenticated, service_role.';
comment on function public.dispute_resolve(uuid, text, text, numeric, numeric, text) is
  'Resolve a dispute with a binding financial outcome (release/refund/split/dismiss). service_role only; SECURITY INVOKER; VOLATILE. Inline double-entry.';
comment on function public.dispute_withdraw(uuid) is
  'Withdraw an open dispute; releases the escrow hold. Filer-scoped; SECURITY DEFINER (updates server-controlled status); VOLATILE. EXECUTE granted to authenticated, service_role.';
comment on function public.dispute_get(uuid) is
  'Retrieve a dispute case with evidence and resolution. Party-scoped; SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';
comment on function public.dispute_list(text) is
  'List disputes for the authenticated entity (party-scoped, optional status filter). SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';

-- -----------------------------------------------------------------------------
-- SECTION 11: Realtime exclusion (guarded, idempotent)
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in (
         'dispute_cases', 'dispute_evidence', 'dispute_resolutions', 'dispute_audit_trail'
       )
  ) then
    alter publication supabase_realtime drop table
      public.dispute_cases, public.dispute_evidence, public.dispute_resolutions, public.dispute_audit_trail;
  end if;
end;
$$;
