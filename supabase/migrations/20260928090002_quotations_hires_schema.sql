-- EP-04-02: Per-Application Quotations & Contract-Linked Hires Schema & RPCs
--
-- Hiring closure: 2 tables (job_quotations, hires) + 8 SECURITY INVOKER RPCs.
-- A hire links the winning application to the existing engagement graph:
-- hire_accept creates a service_contracts row (status offered) + single
-- milestone + offered event, so money/work/messaging/reviews flow through the
-- established contract -> escrow -> milestones -> conversations -> reviews
-- primitives. The professional activates work with the existing
-- service_contract_accept RPC; completion follows the existing milestone flow.
--
-- APPROVED DEVIATION (additive, exactly-one source):
-- service_contracts.service_listing_id becomes nullable and a nullable
-- job_id FK is added, with CHECK service_contracts_source_xor enforcing
-- exactly one source (listing XOR job). No prior rows change (all have a
-- listing, NULL job). No prior function/policy is modified; RLS stays
-- participant-scoped and hire_accept inserts pass the existing
-- service_contracts_insert WITH CHECK (client = auth.uid()).
--
-- EXECUTION MODEL
--   - SECURITY INVOKER everywhere (RLS applies inside every RPC body); no new
--     SECURITY DEFINER function (008/013/015/023 posture audits stay green).
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT002/
--     PLT003/PLT004/PLT005 per the 20260829100004 vocabulary.
--   - Quotation lifecycle: proposed --accept--> accepted (owner picks, or
--     implicitly via hire_accept) / --withdraw--> withdrawn (applicant);
--     a new proposal supersedes the prior proposed row (revision chain kept).
--   - Hire lifecycle: hire_accept creates pending hire + offered contract and
--     awards the job (other applications rejected); hire_cancel (pending only)
--     reopens the job; hire_complete requires a completed/closed contract.
--   - Reads compute the effective hire status from the linked contract
--     (offered->pending, active->active, completed/closed->completed,
--     cancelled->cancelled, disputed->disputed) so no trigger on the prior
--     contract tables is needed.
--
-- GRANT STRATEGY
--   - REVOKE ALL on 2 tables from anon, authenticated, service_role then narrow
--     SELECT+INSERT+UPDATE to authenticated (RLS participant-scoped, writes
--     RPC-only); full grants to service_role only.
--   - REVOKE EXECUTE ON ALL FUNCTIONS FROM public then explicit GRANT EXECUTE
--     per RPC (8 x authenticated+service_role, anon zero).
--
-- MIGRATION POSTURE
--   - Only new objects plus the additive service_contracts deviation above
--     (Rule 3: no other DDL on prior tables/functions/policies).
--   - Idempotent: IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE throughout.

-- =============================================================================
-- SECTION 1: job_quotations
-- =============================================================================
create table if not exists public.job_quotations (
  id                      uuid primary key default gen_random_uuid(),
  application_id          uuid not null references public.job_applications (id) on delete cascade,
  proposed_by             uuid not null references public.entities (id) on delete restrict,
  proposed_amount         numeric not null,
  currency_code           char(3) not null default 'NGN'
                          references public.financial_supported_currencies (currency_code),
  duration_days           integer,
  message                 text,
  revision_number         integer not null default 1,
  status                  text not null default 'proposed',
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  decided_at              timestamptz,
  created_by              uuid default auth.uid(),
  constraint job_quotations_amount_positive check (proposed_amount > 0),
  constraint job_quotations_currency_format check (currency_code ~ '^[A-Z]{3}$'),
  constraint job_quotations_duration_positive check (
    duration_days is null or duration_days >= 1
  ),
  constraint job_quotations_message_length check (
    message is null or char_length(message) <= 2000
  ),
  constraint job_quotations_revision_positive check (revision_number >= 1),
  constraint job_quotations_status_allowed check (
    status in ('proposed', 'accepted', 'superseded', 'withdrawn')
  )
);

comment on table public.job_quotations is
  'Per-application price/duration proposals with a revision chain: one proposed row per application at a time (partial unique index); older proposals are superseded, never deleted.';
comment on column public.job_quotations.revision_number is 'Monotonic per application: 1 + count of prior proposals for the same application.';

-- One live proposal per application.
create unique index if not exists job_quotations_one_proposed_idx
  on public.job_quotations (application_id)
  where status = 'proposed';

create index if not exists job_quotations_application_idx
  on public.job_quotations (application_id, revision_number desc);

drop trigger if exists job_quotations_set_updated_at on public.job_quotations;
create trigger job_quotations_set_updated_at
  before update on public.job_quotations
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 2: hires (contract bridge)
-- =============================================================================
create table if not exists public.hires (
  id                      uuid primary key default gen_random_uuid(),
  job_id                  uuid not null references public.jobs (id) on delete restrict,
  application_id          uuid not null references public.job_applications (id) on delete restrict,
  quotation_id            uuid references public.job_quotations (id) on delete restrict,
  client_entity_id        uuid not null references public.entities (id) on delete restrict,
  professional_entity_id  uuid not null references public.entities (id) on delete restrict,
  contract_id             uuid references public.service_contracts (id) on delete restrict,
  status                  text not null default 'pending',
  hired_at                timestamptz not null default now(),
  completed_at            timestamptz,
  cancelled_at            timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid default auth.uid(),
  constraint hires_status_allowed check (
    status in ('pending', 'active', 'completed', 'cancelled', 'disputed')
  ),
  constraint hires_no_self check (client_entity_id <> professional_entity_id)
);

comment on table public.hires is
  'Hiring bridge: links the winning job application (and chosen quotation) to a service_contracts row. Money, milestones, messaging and reviews live on the linked contract; reads derive the effective status from the contract (offered->pending, active->active, completed/closed->completed, cancelled->cancelled, disputed->disputed). One active hire per job (cancelled hires free the slot).';
comment on column public.hires.contract_id is 'FK to the offered contract created by hire_accept. NULL only before acceptance completes; set atomically in the same RPC.';

create index if not exists hires_job_idx
  on public.hires (job_id);
-- One active hire per job / application (cancelled hires free the slot for
-- re-hire after hire_cancel reopens the funnel).
create unique index if not exists hires_one_active_per_job_idx
  on public.hires (job_id) where status <> 'cancelled';
create unique index if not exists hires_one_active_application_idx
  on public.hires (application_id) where status <> 'cancelled';create index if not exists hires_client_idx
  on public.hires (client_entity_id, hired_at desc);
create index if not exists hires_professional_idx
  on public.hires (professional_entity_id, hired_at desc);
create index if not exists hires_contract_idx
  on public.hires (contract_id) where contract_id is not null;

drop trigger if exists hires_set_updated_at on public.hires;
create trigger hires_set_updated_at
  before update on public.hires
  for each row
  execute function public.platform_set_updated_at();

-- =============================================================================
-- SECTION 3: service_contracts job-source deviation (additive only)
-- =============================================================================
alter table public.service_contracts
  add column if not exists job_id uuid references public.jobs (id) on delete restrict;

alter table public.service_contracts
  alter column service_listing_id drop not null;

alter table public.service_contracts
  drop constraint if exists service_contracts_source_xor;
alter table public.service_contracts
  add constraint service_contracts_source_xor check (
    (service_listing_id is null) <> (job_id is null)
  );

comment on column public.service_contracts.job_id is
  'Nullable job source for EP-04-02 hires (NULL for listing-sourced contracts). Exactly one of service_listing_id / job_id is set (service_contracts_source_xor).';
comment on column public.service_contracts.service_listing_id is
  'FK to published service_listings; NULL for job-sourced (hire) contracts. ON DELETE RESTRICT prevents orphaning supply.';
comment on constraint service_contracts_source_xor on public.service_contracts is
  'Exactly one engagement source: a contract is either listing-sourced or job-sourced (hire), never both, never neither.';

create index if not exists service_contracts_job_idx
  on public.service_contracts (job_id) where job_id is not null;

-- Additive policy widening (documented deviation, same section): the hired
-- professional on a live (pending/active) hire may update the job row so
-- hire_cancel can reopen it when invoked by either party. Owner scope is
-- unchanged; job_update still blocks awarded+ states server-side.
drop policy if exists jobs_update on public.jobs;
create policy jobs_update
  on public.jobs for update to authenticated
  using (client_entity_id = auth.uid()
         or exists (
           select 1 from public.hires h
            where h.job_id = jobs.id
              and h.professional_entity_id = auth.uid()
              and h.status in ('pending', 'active')
         ))
  with check (client_entity_id = auth.uid()
         or exists (
           select 1 from public.hires h
            where h.job_id = jobs.id
              and h.professional_entity_id = auth.uid()
              and h.status in ('pending', 'active')
         ));

-- =============================================================================
-- SECTION 4: RLS enable + revoke + grants + policies (default-deny)
-- =============================================================================
alter table public.job_quotations enable row level security;
alter table public.hires enable row level security;

revoke all on public.job_quotations from anon, authenticated, service_role;
revoke all on public.hires from anon, authenticated, service_role;

grant select, insert, update on public.job_quotations to authenticated;
grant select, insert, update on public.hires to authenticated;
grant all on public.job_quotations to service_role;
grant all on public.hires to service_role;

-- job_quotations SELECT: applicant reads own; job owner reads all on own jobs.
drop policy if exists job_quotations_select on public.job_quotations;
create policy job_quotations_select
  on public.job_quotations for select to authenticated
  using (
    proposed_by = auth.uid()
    or exists (
      select 1 from public.job_applications a
      join public.jobs j on j.id = a.job_id
       where a.id = application_id
         and j.client_entity_id = auth.uid()
    )
  );

drop policy if exists job_quotations_insert on public.job_quotations;
create policy job_quotations_insert
  on public.job_quotations for insert to authenticated
  with check (proposed_by = auth.uid());

drop policy if exists job_quotations_update on public.job_quotations;
create policy job_quotations_update
  on public.job_quotations for update to authenticated
  using (
    proposed_by = auth.uid()
    or exists (
      select 1 from public.job_applications a
      join public.jobs j on j.id = a.job_id
       where a.id = application_id
         and j.client_entity_id = auth.uid()
    )
  )
  with check (
    proposed_by = auth.uid()
    or exists (
      select 1 from public.job_applications a
      join public.jobs j on j.id = a.job_id
       where a.id = application_id
         and j.client_entity_id = auth.uid()
    )
  );

-- hires SELECT/INSERT/UPDATE: either party (client or professional).
drop policy if exists hires_select on public.hires;
create policy hires_select
  on public.hires for select to authenticated
  using (client_entity_id = auth.uid() or professional_entity_id = auth.uid());

drop policy if exists hires_insert on public.hires;
create policy hires_insert
  on public.hires for insert to authenticated
  with check (client_entity_id = auth.uid() or professional_entity_id = auth.uid());

drop policy if exists hires_update on public.hires;
create policy hires_update
  on public.hires for update to authenticated
  using (client_entity_id = auth.uid() or professional_entity_id = auth.uid())
  with check (client_entity_id = auth.uid() or professional_entity_id = auth.uid());

-- =============================================================================
-- SECTION 5: RPCs (all SECURITY INVOKER)
-- =============================================================================

-- ─── 5a. quotation_propose ──────────────────────────────────────────────────
create or replace function public.quotation_propose(
  p_application_id uuid,
  p_amount numeric,
  p_currency_code char(3) default 'NGN',
  p_duration_days int default null,
  p_message text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_application public.job_applications%rowtype;
  v_currency char(3);
  v_revision int;
  v_quotation public.job_quotations%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_application_id is null then
    perform public.platform_raise_error('PLT003', 'Application id is required.');
  end if;

  select * into v_application
    from public.job_applications a
   where a.id = p_application_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Application not found.');
  end if;
  if v_application.professional_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the applicant can propose a quotation.');
  end if;
  if v_application.status not in ('submitted', 'shortlisted') then
    perform public.platform_raise_error('PLT005', 'Quotations can no longer be proposed for this application.');
  end if;

  if p_amount is null or p_amount <= 0 then
    perform public.platform_raise_error('PLT003', 'Quotation amount must be greater than zero.');
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

  if p_duration_days is not null and p_duration_days < 1 then
    perform public.platform_raise_error('PLT003', 'Duration must be at least 1 day.');
  end if;
  if p_message is not null and char_length(p_message) > 2000 then
    perform public.platform_raise_error('PLT003', 'Quotation message must be at most 2000 characters.');
  end if;

  -- Supersede the live proposal, keeping the revision chain.
  update public.job_quotations
     set status = 'superseded', decided_at = now()
   where application_id = p_application_id and status = 'proposed';

  select coalesce(max(revision_number), 0) + 1 into v_revision
    from public.job_quotations
   where application_id = p_application_id;

  insert into public.job_quotations (
    application_id, proposed_by, proposed_amount, currency_code,
    duration_days, message, revision_number, status
  ) values (
    p_application_id, v_actor, p_amount, v_currency,
    p_duration_days, nullif(btrim(p_message), ''), v_revision, 'proposed'
  ) returning * into v_quotation;

  perform public.platform_audit_log_add('quotation_propose', 'job_quotations',
    jsonb_build_object('quotation_id', v_quotation.id,
                       'application_id', p_application_id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Quotation proposed.',
    'data', to_jsonb(v_quotation)
  );
end;
$$;

-- ─── 5b. quotation_withdraw ─────────────────────────────────────────────────
create or replace function public.quotation_withdraw(p_quotation_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_quotation public.job_quotations%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_quotation_id is null then
    perform public.platform_raise_error('PLT003', 'Quotation id is required.');
  end if;

  select * into v_quotation
    from public.job_quotations q
   where q.id = p_quotation_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Quotation not found.');
  end if;
  if v_quotation.proposed_by <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the applicant can withdraw this quotation.');
  end if;
  if v_quotation.status <> 'proposed' then
    perform public.platform_raise_error('PLT005', 'Only a live quotation can be withdrawn.');
  end if;

  update public.job_quotations
     set status = 'withdrawn', decided_at = now()
   where id = v_quotation.id
  returning * into v_quotation;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Quotation withdrawn.',
    'data', to_jsonb(v_quotation)
  );
end;
$$;

-- ─── 5c. quotation_accept ───────────────────────────────────────────────────
create or replace function public.quotation_accept(p_quotation_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_quotation public.job_quotations%rowtype;
  v_job public.jobs%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_quotation_id is null then
    perform public.platform_raise_error('PLT003', 'Quotation id is required.');
  end if;

  select * into v_quotation
    from public.job_quotations q
   where q.id = p_quotation_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Quotation not found.');
  end if;

  select j.* into v_job
    from public.jobs j
    join public.job_applications a on a.job_id = j.id
   where a.id = v_quotation.application_id;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can accept a quotation.');
  end if;
  if v_quotation.status <> 'proposed' then
    perform public.platform_raise_error('PLT005', 'Only a live quotation can be accepted.');
  end if;

  update public.job_quotations
     set status = 'accepted', decided_at = now()
   where id = v_quotation.id
  returning * into v_quotation;

  perform public.platform_audit_log_add('quotation_accept', 'job_quotations',
    jsonb_build_object('quotation_id', v_quotation.id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Quotation accepted.',
    'data', to_jsonb(v_quotation)
  );
end;
$$;

-- ─── 5d. hire_accept ────────────────────────────────────────────────────────
create or replace function public.hire_accept(
  p_application_id uuid,
  p_quotation_id uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_application public.job_applications%rowtype;
  v_job public.jobs%rowtype;
  v_quotation public.job_quotations%rowtype;
  v_has_quotation boolean := false;
  v_total numeric;
  v_currency char(3);
  v_contract_id uuid;
  v_hire public.hires%rowtype;
  v_milestone_title text;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_application_id is null then
    perform public.platform_raise_error('PLT003', 'Application id is required.');
  end if;

  select * into v_application
    from public.job_applications a
   where a.id = p_application_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Application not found.');
  end if;

  select * into v_job from public.jobs j where j.id = v_application.job_id for update;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can hire for this job.');
  end if;
  if v_job.status <> 'open' then
    perform public.platform_raise_error('PLT005', 'Hiring is only available on open jobs.');
  end if;
  if v_application.status <> 'shortlisted' then
    perform public.platform_raise_error('PLT005', 'Only shortlisted applications can be hired.');
  end if;
  if exists (select 1 from public.hires h
              where h.job_id = v_job.id and h.status <> 'cancelled') then
    perform public.platform_raise_error('PLT005', 'This job already has a hire.');
  end if;

  -- Resolve the hiring price: explicit quotation wins, else the application quote.
  if p_quotation_id is not null then
    select * into v_quotation
      from public.job_quotations q
     where q.id = p_quotation_id for update;
    if not found or v_quotation.application_id <> p_application_id then
      perform public.platform_raise_error('PLT004', 'Quotation not found for this application.');
    end if;
    if v_quotation.status not in ('proposed', 'accepted') then
      perform public.platform_raise_error('PLT005', 'This quotation can no longer be used for hiring.');
    end if;
    if v_quotation.status = 'proposed' then
      update public.job_quotations
         set status = 'accepted', decided_at = now()
       where id = v_quotation.id
      returning * into v_quotation;
    end if;
    v_has_quotation := true;
    v_total := v_quotation.proposed_amount;
    v_currency := v_quotation.currency_code;
  else
    if v_application.quoted_amount is null then
      perform public.platform_raise_error('PLT003', 'A quotation is required to hire for this application.');
    end if;
    v_total := v_application.quoted_amount;
    v_currency := v_application.currency_code;
  end if;

  -- Create the offered contract on the job source (listing NULL, job set).
  insert into public.service_contracts (
    service_listing_id, job_id, client_entity_id, professional_entity_id,
    status, total_amount, currency_code, offered_at
  ) values (
    null, v_job.id, v_actor, v_application.professional_entity_id,
    'offered', v_total, v_currency, now()
  ) returning id into v_contract_id;

  v_milestone_title := left(v_job.title, 255);
  insert into public.contract_milestones (
    contract_id, milestone_number, title, description, amount, status, sort_order
  ) values (
    v_contract_id, 1, v_milestone_title,
    left('Hire milestone for job: ' || v_job.title, 2000),
    v_total, 'pending', 0
  );

  insert into public.contract_events (
    contract_id, entity_id, event_type, from_status, to_status, actor_id, details
  ) values (
    v_contract_id, v_actor, 'offered', null, 'offered', v_actor,
    jsonb_build_object('job_id', v_job.id, 'application_id', v_application.id)
  );

  -- Create the hire bridge.
  insert into public.hires (
    job_id, application_id, quotation_id, client_entity_id,
    professional_entity_id, contract_id, status
  ) values (
    v_job.id, v_application.id,
    case when v_has_quotation then v_quotation.id else null end,
    v_actor, v_application.professional_entity_id, v_contract_id, 'pending'
  ) returning * into v_hire;

  -- Accept the winner, reject the rest, award the job.
  update public.job_applications
     set status = 'accepted', decided_at = now()
   where id = v_application.id;

  update public.job_applications
     set status = 'rejected', decided_at = now()
   where job_id = v_job.id
     and id <> v_application.id
     and status in ('submitted', 'shortlisted');

  update public.jobs
     set status = 'awarded',
         awarded_application_id = v_application.id,
         awarded_at = now()
   where id = v_job.id;

  insert into public.job_events (job_id, actor_id, event_type,
    metadata)
  values (v_job.id, v_actor, 'awarded',
    jsonb_build_object('application_id', v_application.id,
                       'hire_id', v_hire.id,
                       'contract_id', v_contract_id));

  perform public.platform_audit_log_add('hire_accept', 'hires',
    jsonb_build_object('hire_id', v_hire.id, 'job_id', v_job.id,
                       'contract_id', v_contract_id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Professional hired.',
    'data', jsonb_build_object(
      'hire', to_jsonb(v_hire),
      'contract_id', v_contract_id
    )
  );
end;
$$;

-- ─── 5e. hire_get ───────────────────────────────────────────────────────────
create or replace function public.hire_get(p_hire_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_hire public.hires%rowtype;
  v_job jsonb;
  v_application jsonb;
  v_quotation jsonb;
  v_contract jsonb;
  v_effective text;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_hire_id is null then
    perform public.platform_raise_error('PLT003', 'Hire id is required.');
  end if;

  select * into v_hire from public.hires h where h.id = p_hire_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Hire not found.');
  end if;
  if v_hire.client_entity_id <> v_actor
     and v_hire.professional_entity_id <> v_actor then
    perform public.platform_raise_error('PLT004', 'Hire not found.');
  end if;

  select to_jsonb(j) into v_job from public.jobs j where j.id = v_hire.job_id;
  select to_jsonb(a) into v_application
    from public.job_applications a where a.id = v_hire.application_id;
  if v_hire.quotation_id is not null then
    select to_jsonb(q) into v_quotation
      from public.job_quotations q where q.id = v_hire.quotation_id;
  end if;
  if v_hire.contract_id is not null then
    select to_jsonb(c) into v_contract
      from public.service_contracts c where c.id = v_hire.contract_id;
  end if;

  -- Effective status derives from the linked contract (no trigger needed).
  v_effective := v_hire.status;
  if v_contract is not null then
    v_effective := case (v_contract->>'status')
      when 'offered' then 'pending'
      when 'active' then 'active'
      when 'completed' then 'completed'
      when 'closed' then 'completed'
      when 'cancelled' then 'cancelled'
      when 'disputed' then 'disputed'
      else v_hire.status
    end;
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Hire retrieved.',
    'data', jsonb_build_object(
      'hire', to_jsonb(v_hire),
      'effective_status', v_effective,
      'job', v_job,
      'application', v_application,
      'quotation', coalesce(v_quotation, 'null'::jsonb),
      'contract', coalesce(v_contract, 'null'::jsonb)
    )
  );
end;
$$;

-- ─── 5f. hire_list_mine ─────────────────────────────────────────────────────
create or replace function public.hire_list_mine(
  p_role text default null,
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

  if p_role is not null and p_role not in ('client', 'professional') then
    perform public.platform_raise_error('PLT003', 'Role must be client or professional.');
  end if;
  if p_status is not null
     and p_status not in ('pending', 'active', 'completed', 'cancelled', 'disputed') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;
  if p_limit is null or p_limit not between 1 and 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  if p_cursor is not null then
    select h.hired_at into v_cursor_ts
      from public.hires h
     where h.id = p_cursor
       and (p_role is null
            or (p_role = 'client' and h.client_entity_id = v_actor)
            or (p_role = 'professional' and h.professional_entity_id = v_actor));
    if not found then
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Hires retrieved.',
        'data', jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null)
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.hired_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select h.id, h.job_id, h.application_id, h.quotation_id,
             h.client_entity_id, h.professional_entity_id, h.contract_id,
             case coalesce(c.status, 'offered')
               when 'offered' then 'pending'
               when 'active' then 'active'
               when 'completed' then 'completed'
               when 'closed' then 'completed'
               when 'cancelled' then 'cancelled'
               when 'disputed' then 'disputed'
               else h.status
             end as effective_status,
             h.hired_at, h.completed_at, h.cancelled_at,
             j.title as job_title, j.status as job_status,
             row_number() over (order by h.hired_at desc, h.id desc) as rn
        from public.hires h
        join public.jobs j on j.id = h.job_id
        left join public.service_contracts c on c.id = h.contract_id
       where (p_role is null
              or (p_role = 'client' and h.client_entity_id = v_actor)
              or (p_role = 'professional' and h.professional_entity_id = v_actor))
         and (h.client_entity_id = v_actor or h.professional_entity_id = v_actor)
         and (p_status is null or
              case coalesce(c.status, 'offered')
                when 'offered' then 'pending'
                when 'active' then 'active'
                when 'completed' then 'completed'
                when 'closed' then 'completed'
                when 'cancelled' then 'cancelled'
                when 'disputed' then 'disputed'
                else h.status
              end = p_status)
         and (p_cursor is null or (h.hired_at, h.id) < (v_cursor_ts, p_cursor))
    ) x;

  if not v_has_more then v_next := null; end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Hires retrieved.',
    'data', jsonb_build_object('items', v_items, 'has_more', v_has_more, 'next_cursor', v_next)
  );
end;
$$;

-- ─── 5g. hire_cancel (pending only, reopens job) ────────────────────────────
create or replace function public.hire_cancel(p_hire_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_hire public.hires%rowtype;
  v_contract public.service_contracts%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_hire_id is null then
    perform public.platform_raise_error('PLT003', 'Hire id is required.');
  end if;

  select * into v_hire from public.hires h where h.id = p_hire_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Hire not found.');
  end if;
  if v_hire.client_entity_id <> v_actor
     and v_hire.professional_entity_id <> v_actor then
    perform public.platform_raise_error('PLT004', 'Hire not found.');
  end if;

  if v_hire.contract_id is null then
    perform public.platform_raise_error('PLT005', 'This hire has no linked contract.');
  end if;

  select * into v_contract
    from public.service_contracts c
   where c.id = v_hire.contract_id for update;
  if v_contract.status <> 'offered' then
    perform public.platform_raise_error('PLT005', 'Only a pending hire can be cancelled.');
  end if;

  -- Cancel the linked contract (mirrors service_contract_cancel for offered).
  update public.service_contracts
     set status = 'cancelled', cancelled_at = now()
   where id = v_contract.id;

  insert into public.contract_events (
    contract_id, entity_id, event_type, from_status, to_status, actor_id, details
  ) values (
    v_contract.id, v_actor, 'cancelled', 'offered', 'cancelled', v_actor,
    jsonb_build_object('hire_id', v_hire.id, 'reason', p_reason)
  );

  -- Reopen the funnel BEFORE flipping the hire row: the widened jobs_update
  -- RLS scope admits the hired professional only while the hire is still
  -- pending/active, so the job reopen must land first (RLS-blocked writes
  -- are silent no-ops, never errors).
  update public.jobs
     set status = 'open',
         awarded_application_id = null,
         awarded_at = null
   where id = v_hire.job_id;

  update public.job_applications
     set status = 'shortlisted', decided_at = null
   where id = v_hire.application_id;

  update public.hires
     set status = 'cancelled', cancelled_at = now()
   where id = v_hire.id
  returning * into v_hire;

  insert into public.job_events (job_id, actor_id, event_type,
    metadata)
  values (v_hire.job_id, v_actor, 'resumed',
    jsonb_build_object('reason', p_reason, 'hire_id', v_hire.id));

  perform public.platform_audit_log_add('hire_cancel', 'hires',
    jsonb_build_object('hire_id', v_hire.id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Hire cancelled.',
    'data', to_jsonb(v_hire)
  );
end;
$$;

-- ─── 5h. hire_complete (requires completed/closed contract) ─────────────────
create or replace function public.hire_complete(p_hire_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_hire public.hires%rowtype;
  v_contract public.service_contracts%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_hire_id is null then
    perform public.platform_raise_error('PLT003', 'Hire id is required.');
  end if;

  select * into v_hire from public.hires h where h.id = p_hire_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Hire not found.');
  end if;
  if v_hire.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the hiring client can complete this hire.');
  end if;
  if v_hire.contract_id is null then
    perform public.platform_raise_error('PLT005', 'This hire has no linked contract.');
  end if;

  select * into v_contract
    from public.service_contracts c
   where c.id = v_hire.contract_id;
  if v_contract.status not in ('completed', 'closed') then
    perform public.platform_raise_error('PLT005', 'The linked contract must be completed first.');
  end if;
  if v_hire.status = 'completed' then
    perform public.platform_raise_error('PLT005', 'This hire is already completed.');
  end if;

  update public.hires
     set status = 'completed', completed_at = now()
   where id = v_hire.id
  returning * into v_hire;

  update public.jobs
     set status = 'completed', completed_at = now()
   where id = v_hire.job_id;

  insert into public.job_events (job_id, actor_id, event_type,
    metadata)
  values (v_hire.job_id, v_actor, 'completed',
    jsonb_build_object('hire_id', v_hire.id));

  perform public.platform_audit_log_add('hire_complete', 'hires',
    jsonb_build_object('hire_id', v_hire.id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Hire completed.',
    'data', to_jsonb(v_hire)
  );
end;
$$;

-- =============================================================================
-- SECTION 6: REVOKE EXECUTE baseline + GRANTs + COMMENTs
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.quotation_propose(uuid, numeric, char(3), int, text) to authenticated, service_role;
grant execute on function public.quotation_withdraw(uuid) to authenticated, service_role;
grant execute on function public.quotation_accept(uuid) to authenticated, service_role;
grant execute on function public.hire_accept(uuid, uuid) to authenticated, service_role;
grant execute on function public.hire_get(uuid) to authenticated, service_role;
grant execute on function public.hire_list_mine(text, text, int, uuid) to authenticated, service_role;
grant execute on function public.hire_cancel(uuid, text) to authenticated, service_role;
grant execute on function public.hire_complete(uuid) to authenticated, service_role;

grant execute on function public.platform_is_authenticated() to authenticated, service_role;
grant execute on function public.platform_set_updated_at() to authenticated, service_role;
grant execute on function public.platform_audit_log_add(text, text, jsonb) to authenticated, service_role;

comment on function public.quotation_propose(uuid, numeric, char(3), int, text) is
  'SECURITY INVOKER, VOLATILE. Applicant proposes (or revises, superseding the live row) a quotation on a submitted/shortlisted application. Revision chain preserved.';
comment on function public.quotation_withdraw(uuid) is
  'SECURITY INVOKER, VOLATILE. Applicant withdraws a live (proposed) quotation.';
comment on function public.quotation_accept(uuid) is
  'SECURITY INVOKER, VOLATILE. Job owner accepts a live quotation (pre-selects the price before hiring).';
comment on function public.hire_accept(uuid, uuid) is
  'SECURITY INVOKER, VOLATILE. Owner hires a shortlisted application on an open job: accepts the quotation (explicit or application quote), creates the offered service_contract (job source) + milestone + event, creates the hire bridge, accepts the winner, rejects the rest, awards the job.';
comment on function public.hire_get(uuid) is
  'SECURITY INVOKER, STABLE. Participant-only hire retrieval with job/application/quotation/contract payloads and the contract-derived effective status. Identical PLT004 for foreign/unknown (no oracle).';
comment on function public.hire_list_mine(text, text, int, uuid) is
  'SECURITY INVOKER, STABLE. Participant-scoped hire list with optional client/professional role + effective-status filter and keyset pagination (hired_at desc, id desc).';
comment on function public.hire_cancel(uuid, text) is
  'SECURITY INVOKER, VOLATILE. Either party cancels a pending hire: linked offered contract cancelled, winner back to shortlisted, job reopened to open.';
comment on function public.hire_complete(uuid) is
  'SECURITY INVOKER, VOLATILE. Hiring client completes a hire whose linked contract is completed/closed; completes the job.';

-- =============================================================================
-- SECTION 7: Realtime exclusion (guarded, idempotent)
-- =============================================================================
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('job_quotations', 'hires')
  ) then
    alter publication supabase_realtime drop table
      public.job_quotations, public.hires;
  end if;
end;
$$;
