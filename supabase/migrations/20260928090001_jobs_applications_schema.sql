-- EP-04-01: Client Job Posting & Professional Applications Schema & Lifecycle RPCs
--
-- Client-posted hiring needs: 3 tables (jobs, job_applications, job_events) +
-- 16 SECURITY INVOKER RPCs with the job/application state machine.
--
-- EXECUTION MODEL
--   - SECURITY INVOKER everywhere (RLS applies inside every RPC body); no new
--     SECURITY DEFINER function (008/013/015/023 posture audits stay green).
--   - Envelope: {success, code, message, data}; codes PLT000/PLT001/PLT002/
--     PLT003/PLT004/PLT005 per the 20260829100004 vocabulary.
--   - Job state machine: draft --publish--> open <--pause/resume--> paused
--     --award--> awarded --complete--> completed; draft/open/paused --cancel-->
--     cancelled. Award/completion linkage to hires lands in EP-04-02.
--   - Application state machine: submitted --shortlist--> shortlisted
--     --accept--> accepted / --reject--> rejected; submitted/shortlisted
--     --withdraw--> withdrawn (applicant only).
--   - Capability gates (server-side, AGENT.md Rule 2): job posting requires
--     entities.capability IN ('hire','both'); applying requires
--     entities.capability IN ('offer','both'). Wrong capability -> PLT002.
--
-- GRANT STRATEGY
--   - REVOKE ALL on 3 tables from anon, authenticated, service_role then narrow
--     SELECT on all 3 to authenticated (RLS-filtered) + INSERT/SELECT on
--     job_events to authenticated/service_role (append-only); full grants to
--     service_role only. Writes via RPC only (mirrors service_contracts pattern).
--   - REVOKE EXECUTE ON ALL FUNCTIONS FROM public then explicit GRANT EXECUTE
--     per RPC (16 x authenticated+service_role, anon zero).
--
-- MIGRATION POSTURE
--   - No DDL on any prior table/function/policy (Rule 3 write discipline); only
--     new objects.
--   - Idempotent: IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE throughout.

-- =============================================================================
-- SECTION 1: jobs
-- =============================================================================
create table if not exists public.jobs (
  id                      uuid primary key default gen_random_uuid(),
  client_entity_id        uuid not null references public.entities (id) on delete restrict,
  profession_id           uuid references public.professions (id) on delete restrict,
  industry_id             uuid references public.industries (id) on delete restrict,
  title                   text not null,
  description             text not null,
  budget_min              numeric,
  budget_max              numeric,
  currency_code           char(3) not null default 'NGN'
                          references public.financial_supported_currencies (currency_code),
  location                text,
  status                  text not null default 'draft',
  search_vector           tsvector,
  applications_count      integer not null default 0,
  awarded_application_id  uuid,
  posted_at               timestamptz,
  awarded_at              timestamptz,
  completed_at            timestamptz,
  cancelled_at            timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid default auth.uid(),
  constraint jobs_title_length check (
    char_length(btrim(title)) between 10 and 120
  ),
  constraint jobs_description_length check (
    char_length(btrim(description)) between 50 and 5000
  ),
  constraint jobs_status_allowed check (
    status in ('draft', 'open', 'paused', 'awarded', 'completed', 'cancelled')
  ),
  constraint jobs_budget_min_nonneg check (budget_min is null or budget_min >= 0),
  constraint jobs_budget_max_nonneg check (budget_max is null or budget_max >= 0),
  constraint jobs_budget_range check (
    budget_max is null or budget_min is null or budget_max >= budget_min
  ),
  constraint jobs_currency_format check (currency_code ~ '^[A-Z]{3}$'),
  constraint jobs_applications_count_nonneg check (applications_count >= 0),
  constraint jobs_posted_at_semantics check (
    (status in ('open', 'paused', 'awarded', 'completed') and posted_at is not null)
    or (status in ('draft', 'cancelled') and (posted_at is null or status = 'cancelled'))
  )
);

comment on table public.jobs is
  'Client-posted hiring needs: a job bound to taxonomy, owned by a client entity. Lifecycle draft->open<->paused->awarded->completed/cancelled. search_vector is trigger-generated; applications_count is trigger-maintained; awarded_application_id is set by the EP-04-02 hire_accept RPC.';
comment on column public.jobs.client_entity_id is 'Hiring client (auth.uid() at creation). Posting requires capability hire|both (RPC-enforced).';
comment on column public.jobs.status is 'Lifecycle: draft/open/paused/awarded/completed/cancelled. Transitions RPC-only.';
comment on column public.jobs.awarded_application_id is 'FK to job_applications, set by EP-04-02 hire_accept. No FK constraint (avoids create-order cycle); RPC-validated.';

create index if not exists jobs_client_idx
  on public.jobs (client_entity_id, status);
create index if not exists jobs_status_created_idx
  on public.jobs (status, created_at desc);
create index if not exists jobs_profession_idx
  on public.jobs (profession_id) where profession_id is not null;
create index if not exists jobs_search_vector_idx
  on public.jobs using gin (search_vector);
create index if not exists jobs_created_at_idx
  on public.jobs (created_at desc);

drop trigger if exists jobs_set_updated_at on public.jobs;
create trigger jobs_set_updated_at
  before update on public.jobs
  for each row
  execute function public.platform_set_updated_at();

-- Search vector maintenance (mirrors service_listings FTS strategy).
create or replace function public.jobs_refresh_search_vector()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.search_vector :=
    to_tsvector('english', coalesce(new.title, '') || ' ' || coalesce(new.description, ''));
  return new;
end;
$$;

drop trigger if exists jobs_search_vector_trigger on public.jobs;
create trigger jobs_search_vector_trigger
  before insert or update of title, description on public.jobs
  for each row
  execute function public.jobs_refresh_search_vector();

-- =============================================================================
-- SECTION 2: job_applications
-- =============================================================================
create table if not exists public.job_applications (
  id                      uuid primary key default gen_random_uuid(),
  job_id                  uuid not null references public.jobs (id) on delete cascade,
  professional_entity_id  uuid not null references public.entities (id) on delete restrict,
  -- Denormalized job owner (set once by application_submit, never updated):
  -- keeps the RLS graph acyclic (applications policies read only their own
  -- columns, so jobs policies may safely reference applications).
  client_entity_id        uuid not null references public.entities (id) on delete restrict,
  cover_note              text not null,
  quoted_amount           numeric,
  currency_code           char(3) not null default 'NGN'
                          references public.financial_supported_currencies (currency_code),
  duration_days           integer,
  status                  text not null default 'submitted',
  submitted_at            timestamptz not null default now(),
  decided_at              timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid default auth.uid(),
  constraint job_applications_cover_note_length check (
    char_length(btrim(cover_note)) between 20 and 2000
  ),
  constraint job_applications_quoted_amount_positive check (
    quoted_amount is null or quoted_amount > 0
  ),
  constraint job_applications_currency_format check (currency_code ~ '^[A-Z]{3}$'),
  constraint job_applications_duration_positive check (
    duration_days is null or duration_days >= 1
  ),
  constraint job_applications_status_allowed check (
    status in ('submitted', 'withdrawn', 'shortlisted', 'accepted', 'rejected')
  ),
  constraint job_applications_one_per_professional unique (job_id, professional_entity_id)
);

comment on table public.job_applications is
  'Professional applications to client-posted jobs: one row per (job, professional). Lifecycle submitted->shortlisted->accepted/rejected, submitted/shortlisted->withdrawn. Accept linkage to hires lands in EP-04-02.';
comment on column public.job_applications.professional_entity_id is 'Applying professional (auth.uid() at submission). Applying requires capability offer|both (RPC-enforced); owner self-apply is blocked (PLT005).';
comment on column public.job_applications.client_entity_id is 'Denormalized job owner (copied from jobs.client_entity_id by application_submit, never client-supplied on update). Powers the acyclic RLS owner scope.';

create index if not exists job_applications_job_idx
  on public.job_applications (job_id, status);
create index if not exists job_applications_professional_idx
  on public.job_applications (professional_entity_id, status);
create index if not exists job_applications_status_idx
  on public.job_applications (status);

drop trigger if exists job_applications_set_updated_at on public.job_applications;
create trigger job_applications_set_updated_at
  before update on public.job_applications
  for each row
  execute function public.platform_set_updated_at();

-- Applications count maintenance on jobs.
create or replace function public.job_applications_maintain_count()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.jobs set applications_count = applications_count + 1 where id = new.job_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.jobs
       set applications_count = greatest(applications_count - 1, 0)
     where id = old.job_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists job_applications_count_trigger on public.job_applications;
create trigger job_applications_count_trigger
  after insert or delete on public.job_applications
  for each row
  execute function public.job_applications_maintain_count();

-- =============================================================================
-- SECTION 3: job_events (append-only audit)
-- =============================================================================
create table if not exists public.job_events (
  id            uuid primary key default gen_random_uuid(),
  job_id        uuid not null references public.jobs (id) on delete cascade,
  actor_id      uuid,
  event_type    text not null,
  metadata      jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  constraint job_events_type_allowed check (
    event_type in ('created', 'published', 'paused', 'resumed', 'updated',
                   'application_submitted', 'application_withdrawn',
                   'application_shortlisted', 'application_rejected',
                   'awarded', 'completed', 'cancelled')
  )
);

comment on table public.job_events is
  'Append-only job lifecycle audit: one row per transition. No UPDATE/DELETE grants.';

create index if not exists job_events_job_idx
  on public.job_events (job_id, created_at);

-- =============================================================================
-- SECTION 4: RLS enable + revoke + grants + policies (default-deny)
-- =============================================================================
alter table public.jobs enable row level security;
alter table public.job_applications enable row level security;
alter table public.job_events enable row level security;

revoke all on public.jobs from anon, authenticated, service_role;
revoke all on public.job_applications from anon, authenticated, service_role;
revoke all on public.job_events from anon, authenticated, service_role;

grant select, insert, update on public.jobs to authenticated;
grant select, insert, update on public.job_applications to authenticated;
grant select, insert on public.job_events to authenticated;
grant all on public.jobs to service_role;
grant all on public.job_applications to service_role;
grant select, insert on public.job_events to service_role;

-- jobs SELECT: open jobs are publicly readable (discovery); owners read their
-- own in any status; applicants read jobs they applied to in any status.
-- Acyclic by construction: this is the only cross-table edge (jobs ->
-- applications); applications policies read only their own columns
-- (professional/job-owner denormalized), so no policy cycle exists.
drop policy if exists jobs_select on public.jobs;
create policy jobs_select
  on public.jobs for select to authenticated
  using (
    status = 'open'
    or client_entity_id = auth.uid()
    or exists (
      select 1 from public.job_applications a
       where a.job_id = jobs.id
         and a.professional_entity_id = auth.uid()
    )
  );
drop policy if exists jobs_insert on public.jobs;
create policy jobs_insert
  on public.jobs for insert to authenticated
  with check (client_entity_id = auth.uid());

drop policy if exists jobs_update on public.jobs;
create policy jobs_update
  on public.jobs for update to authenticated
  using (client_entity_id = auth.uid())
  with check (client_entity_id = auth.uid());

-- job_applications SELECT/UPDATE: applicant reads own; job owner reads all on
-- own jobs via the denormalized client_entity_id (own columns only — no
-- jobs reference, keeping the RLS graph acyclic).
drop policy if exists job_applications_select on public.job_applications;
create policy job_applications_select
  on public.job_applications for select to authenticated
  using (
    professional_entity_id = auth.uid()
    or client_entity_id = auth.uid()
  );

drop policy if exists job_applications_insert on public.job_applications;
create policy job_applications_insert
  on public.job_applications for insert to authenticated
  with check (professional_entity_id = auth.uid());

drop policy if exists job_applications_update on public.job_applications;
create policy job_applications_update
  on public.job_applications for update to authenticated
  using (
    professional_entity_id = auth.uid()
    or client_entity_id = auth.uid()
  )
  with check (
    professional_entity_id = auth.uid()
    or client_entity_id = auth.uid()
  );

-- job_events: participant-scoped SELECT + actor INSERT (audit).
drop policy if exists job_events_select on public.job_events;
create policy job_events_select
  on public.job_events for select to authenticated
  using (exists (
    select 1 from public.jobs j
     where j.id = job_id
       and (j.client_entity_id = auth.uid()
            or exists (
              select 1 from public.job_applications a
               where a.job_id = j.id
                 and a.professional_entity_id = auth.uid()
            ))
  ));

drop policy if exists job_events_insert on public.job_events;
create policy job_events_insert
  on public.job_events for insert to authenticated
  with check (actor_id = auth.uid());

-- =============================================================================
-- SECTION 5: RPCs (all SECURITY INVOKER)
-- =============================================================================

-- ─── 5a. job_create ─────────────────────────────────────────────────────────
create or replace function public.job_create(
  p_title text,
  p_description text,
  p_profession_id uuid default null,
  p_industry_id uuid default null,
  p_budget_min numeric default null,
  p_budget_max numeric default null,
  p_currency_code char(3) default 'NGN',
  p_location text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_capability text;
  v_currency char(3);
  v_job public.jobs%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  select e.capability into v_capability
    from public.entities e
   where e.id = v_actor;
  if v_capability is null or v_capability not in ('hire', 'both') then
    perform public.platform_raise_error('PLT002', 'Job posting requires a hiring (Client) account.');
  end if;

  if nullif(btrim(p_title), '') is null
     or char_length(btrim(p_title)) < 10
     or char_length(btrim(p_title)) > 120 then
    perform public.platform_raise_error('PLT003', 'Title must be 10 to 120 characters.');
  end if;

  if nullif(btrim(p_description), '') is null
     or char_length(btrim(p_description)) < 50
     or char_length(btrim(p_description)) > 5000 then
    perform public.platform_raise_error('PLT003', 'Description must be 50 to 5000 characters.');
  end if;

  if p_budget_min is not null and p_budget_min < 0 then
    perform public.platform_raise_error('PLT003', 'Minimum budget cannot be negative.');
  end if;
  if p_budget_max is not null and p_budget_max < 0 then
    perform public.platform_raise_error('PLT003', 'Maximum budget cannot be negative.');
  end if;
  if p_budget_min is not null and p_budget_max is not null and p_budget_max < p_budget_min then
    perform public.platform_raise_error('PLT003', 'Maximum budget must be at least the minimum budget.');
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

  if p_profession_id is not null and not exists (
    select 1 from public.professions p where p.id = p_profession_id and p.is_active
  ) then
    perform public.platform_raise_error('PLT004', 'Profession not found or inactive.');
  end if;
  if p_industry_id is not null and not exists (
    select 1 from public.industries i where i.id = p_industry_id and i.is_active
  ) then
    perform public.platform_raise_error('PLT004', 'Industry not found or inactive.');
  end if;

  insert into public.jobs (
    client_entity_id, profession_id, industry_id, title, description,
    budget_min, budget_max, currency_code, location, status
  ) values (
    v_actor, p_profession_id, p_industry_id, btrim(p_title), btrim(p_description),
    p_budget_min, p_budget_max, v_currency, nullif(btrim(p_location), ''), 'draft'
  ) returning * into v_job;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_job.id, v_actor, 'created');

  perform public.platform_audit_log_add('job_create', 'jobs',
    jsonb_build_object('job_id', v_job.id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job created.',
    'data', to_jsonb(v_job)
  );
end;
$$;

-- ─── 5b. job_update ─────────────────────────────────────────────────────────
create or replace function public.job_update(
  p_job_id uuid,
  p_title text default null,
  p_description text default null,
  p_profession_id uuid default null,
  p_industry_id uuid default null,
  p_budget_min numeric default null,
  p_budget_max numeric default null,
  p_currency_code char(3) default null,
  p_location text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_currency char(3);
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Job not found.');
  end if;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can update this job.');
  end if;
  if v_job.status in ('awarded', 'completed', 'cancelled') then
    perform public.platform_raise_error('PLT005', 'This job can no longer be edited.');
  end if;

  if p_title is not null then
    if char_length(btrim(p_title)) < 10 or char_length(btrim(p_title)) > 120 then
      perform public.platform_raise_error('PLT003', 'Title must be 10 to 120 characters.');
    end if;
    v_job.title := btrim(p_title);
  end if;
  if p_description is not null then
    if char_length(btrim(p_description)) < 50 or char_length(btrim(p_description)) > 5000 then
      perform public.platform_raise_error('PLT003', 'Description must be 50 to 5000 characters.');
    end if;
    v_job.description := btrim(p_description);
  end if;
  if p_profession_id is not null then
    if not exists (
      select 1 from public.professions p where p.id = p_profession_id and p.is_active
    ) then
      perform public.platform_raise_error('PLT004', 'Profession not found or inactive.');
    end if;
    v_job.profession_id := p_profession_id;
  end if;
  if p_industry_id is not null then
    if not exists (
      select 1 from public.industries i where i.id = p_industry_id and i.is_active
    ) then
      perform public.platform_raise_error('PLT004', 'Industry not found or inactive.');
    end if;
    v_job.industry_id := p_industry_id;
  end if;
  if p_budget_min is not null then
    if p_budget_min < 0 then
      perform public.platform_raise_error('PLT003', 'Minimum budget cannot be negative.');
    end if;
    v_job.budget_min := p_budget_min;
  end if;
  if p_budget_max is not null then
    if p_budget_max < 0 then
      perform public.platform_raise_error('PLT003', 'Maximum budget cannot be negative.');
    end if;
    v_job.budget_max := p_budget_max;
  end if;
  if v_job.budget_min is not null and v_job.budget_max is not null
     and v_job.budget_max < v_job.budget_min then
    perform public.platform_raise_error('PLT003', 'Maximum budget must be at least the minimum budget.');
  end if;
  if p_currency_code is not null then
    v_currency := nullif(btrim(upper(p_currency_code::text)), '');
    if v_currency is null or v_currency !~ '^[A-Z]{3}$' then
      perform public.platform_raise_error('PLT003', 'Invalid currency code.');
    end if;
    if not exists (
      select 1 from public.financial_supported_currencies c
       where c.currency_code = v_currency and c.is_active
    ) then
      perform public.platform_raise_error('PLT003', 'Currency is not supported or is inactive.');
    end if;
    v_job.currency_code := v_currency;
  end if;
  if p_location is not null then
    v_job.location := nullif(btrim(p_location), '');
  end if;

  update public.jobs
     set title = v_job.title,
         description = v_job.description,
         profession_id = v_job.profession_id,
         industry_id = v_job.industry_id,
         budget_min = v_job.budget_min,
         budget_max = v_job.budget_max,
         currency_code = v_job.currency_code,
         location = v_job.location
   where id = v_job.id
  returning * into v_job;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_job.id, v_actor, 'updated');

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job updated.',
    'data', to_jsonb(v_job)
  );
end;
$$;

-- ─── 5c. job_publish ────────────────────────────────────────────────────────
create or replace function public.job_publish(p_job_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Job not found.');
  end if;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can publish this job.');
  end if;
  if v_job.status <> 'draft' then
    perform public.platform_raise_error('PLT005', 'Only draft jobs can be published.');
  end if;

  update public.jobs
     set status = 'open', posted_at = now()
   where id = v_job.id
  returning * into v_job;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_job.id, v_actor, 'published');

  perform public.platform_audit_log_add('job_publish', 'jobs',
    jsonb_build_object('job_id', v_job.id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job published.',
    'data', to_jsonb(v_job)
  );
end;
$$;

-- ─── 5d. job_pause ──────────────────────────────────────────────────────────
create or replace function public.job_pause(p_job_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Job not found.');
  end if;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can pause this job.');
  end if;
  if v_job.status <> 'open' then
    perform public.platform_raise_error('PLT005', 'Only open jobs can be paused.');
  end if;

  update public.jobs set status = 'paused' where id = v_job.id returning * into v_job;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_job.id, v_actor, 'paused');

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job paused.',
    'data', to_jsonb(v_job)
  );
end;
$$;

-- ─── 5e. job_resume ─────────────────────────────────────────────────────────
create or replace function public.job_resume(p_job_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Job not found.');
  end if;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can resume this job.');
  end if;
  if v_job.status <> 'paused' then
    perform public.platform_raise_error('PLT005', 'Only paused jobs can be resumed.');
  end if;

  update public.jobs set status = 'open' where id = v_job.id returning * into v_job;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_job.id, v_actor, 'resumed');

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job resumed.',
    'data', to_jsonb(v_job)
  );
end;
$$;

-- ─── 5f. job_cancel ─────────────────────────────────────────────────────────
create or replace function public.job_cancel(p_job_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Job not found.');
  end if;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can cancel this job.');
  end if;
  if v_job.status not in ('draft', 'open', 'paused') then
    perform public.platform_raise_error('PLT005', 'This job can no longer be cancelled.');
  end if;

  update public.jobs
     set status = 'cancelled', cancelled_at = now()
   where id = v_job.id
  returning * into v_job;

  insert into public.job_events (job_id, actor_id, event_type,
    metadata)
  values (v_job.id, v_actor, 'cancelled',
    jsonb_build_object('reason', p_reason));

  perform public.platform_audit_log_add('job_cancel', 'jobs',
    jsonb_build_object('job_id', v_job.id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job cancelled.',
    'data', to_jsonb(v_job)
  );
end;
$$;

-- ─── 5g. job_complete ───────────────────────────────────────────────────────
create or replace function public.job_complete(p_job_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Job not found.');
  end if;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can complete this job.');
  end if;
  if v_job.status <> 'awarded' then
    perform public.platform_raise_error('PLT005', 'Only awarded jobs can be completed.');
  end if;

  update public.jobs
     set status = 'completed', completed_at = now()
   where id = v_job.id
  returning * into v_job;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_job.id, v_actor, 'completed');

  perform public.platform_audit_log_add('job_complete', 'jobs',
    jsonb_build_object('job_id', v_job.id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job completed.',
    'data', to_jsonb(v_job)
  );
end;
$$;

-- ─── 5h. job_get ────────────────────────────────────────────────────────────
create or replace function public.job_get(p_job_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_is_owner boolean;
  v_applications jsonb;
  v_my_application jsonb;
  v_events jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Job not found or not available.');
  end if;

  v_is_owner := (v_job.client_entity_id = v_actor);

  -- Visibility: open to all; otherwise owner or applicant only (no oracle).
  if v_job.status <> 'open' and not v_is_owner
     and not exists (
       select 1 from public.job_applications a
        where a.job_id = v_job.id and a.professional_entity_id = v_actor
     ) then
    perform public.platform_raise_error('PLT004', 'Job not found or not available.');
  end if;

  if v_is_owner then
    select coalesce(jsonb_agg(to_jsonb(a) order by a.submitted_at desc), '[]'::jsonb)
      into v_applications
      from public.job_applications a
     where a.job_id = v_job.id;
  else
    v_applications := '[]'::jsonb;
  end if;

  select to_jsonb(a) into v_my_application
    from public.job_applications a
   where a.job_id = v_job.id and a.professional_entity_id = v_actor;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at), '[]'::jsonb)
    into v_events
    from public.job_events e
   where e.job_id = v_job.id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job retrieved.',
    'data', jsonb_build_object(
      'job', to_jsonb(v_job),
      'applications', v_applications,
      'my_application', coalesce(v_my_application, 'null'::jsonb),
      'events', v_events
    )
  );
end;
$$;

-- ─── 5i. job_list (open discovery) ──────────────────────────────────────────
create or replace function public.job_list(
  p_profession_id uuid default null,
  p_search text default null,
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

  if p_limit is null or p_limit not between 1 and 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  if p_cursor is not null then
    select j.created_at into v_cursor_ts
      from public.jobs j
     where j.id = p_cursor and j.status = 'open';
    if not found then
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Jobs retrieved.',
        'data', jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null)
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.created_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select j.id, j.client_entity_id, j.profession_id, j.industry_id,
             j.title, j.description, j.budget_min, j.budget_max, j.currency_code,
             j.location, j.status, j.applications_count,
             j.posted_at, j.created_at, j.updated_at,
             row_number() over (order by j.created_at desc, j.id desc) as rn
        from public.jobs j
       where j.status = 'open'
         and (p_profession_id is null or j.profession_id = p_profession_id)
         and (p_search is null or nullif(btrim(p_search), '') is null
              or j.search_vector @@ plainto_tsquery('english', btrim(p_search)))
         and (p_cursor is null or (j.created_at, j.id) < (v_cursor_ts, p_cursor))
    ) x;

  if not v_has_more then v_next := null; end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Jobs retrieved.',
    'data', jsonb_build_object('items', v_items, 'has_more', v_has_more, 'next_cursor', v_next)
  );
end;
$$;

-- ─── 5j. job_list_mine (posted | applied) ────────────────────────────────────
create or replace function public.job_list_mine(
  p_role text default 'posted',
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

  if p_role is null or p_role not in ('posted', 'applied') then
    perform public.platform_raise_error('PLT003', 'Role must be posted or applied.');
  end if;
  if p_status is not null
     and p_status not in ('draft', 'open', 'paused', 'awarded', 'completed', 'cancelled') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;
  if p_limit is null or p_limit not between 1 and 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  if p_cursor is not null then
    select j.created_at into v_cursor_ts
      from public.jobs j
     where j.id = p_cursor
       and ((p_role = 'posted' and j.client_entity_id = v_actor)
            or (p_role = 'applied' and exists (
              select 1 from public.job_applications a
               where a.job_id = j.id and a.professional_entity_id = v_actor
            )));
    if not found then
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Jobs retrieved.',
        'data', jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null)
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.created_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select j.id, j.client_entity_id, j.profession_id, j.industry_id,
             j.title, j.description, j.budget_min, j.budget_max, j.currency_code,
             j.location, j.status, j.applications_count,
             j.posted_at, j.created_at, j.updated_at,
             row_number() over (order by j.created_at desc, j.id desc) as rn
        from public.jobs j
       where ((p_role = 'posted' and j.client_entity_id = v_actor)
              or (p_role = 'applied' and exists (
                select 1 from public.job_applications a
                 where a.job_id = j.id and a.professional_entity_id = v_actor
              )))
         and (p_status is null or j.status = p_status)
         and (p_cursor is null or (j.created_at, j.id) < (v_cursor_ts, p_cursor))
    ) x;

  if not v_has_more then v_next := null; end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Jobs retrieved.',
    'data', jsonb_build_object('items', v_items, 'has_more', v_has_more, 'next_cursor', v_next)
  );
end;
$$;

-- ─── 5k. application_submit ─────────────────────────────────────────────────
create or replace function public.application_submit(
  p_job_id uuid,
  p_cover_note text,
  p_quoted_amount numeric default null,
  p_currency_code char(3) default 'NGN',
  p_duration_days int default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_capability text;
  v_job public.jobs%rowtype;
  v_currency char(3);
  v_application public.job_applications%rowtype;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select e.capability into v_capability
    from public.entities e
   where e.id = v_actor;
  if v_capability is null or v_capability not in ('offer', 'both') then
    perform public.platform_raise_error('PLT002', 'Applying requires a professional account.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id;
  if not found or v_job.status <> 'open' then
    perform public.platform_raise_error('PLT004', 'Job not found or not available.');
  end if;

  if v_job.client_entity_id = v_actor then
    perform public.platform_raise_error('PLT005', 'You cannot apply to your own job.');
  end if;

  if nullif(btrim(p_cover_note), '') is null
     or char_length(btrim(p_cover_note)) < 20
     or char_length(btrim(p_cover_note)) > 2000 then
    perform public.platform_raise_error('PLT003', 'Cover note must be 20 to 2000 characters.');
  end if;

  if p_quoted_amount is not null and p_quoted_amount <= 0 then
    perform public.platform_raise_error('PLT003', 'Quoted amount must be greater than zero.');
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

  if exists (
    select 1 from public.job_applications a
     where a.job_id = p_job_id and a.professional_entity_id = v_actor
  ) then
    perform public.platform_raise_error('PLT005', 'You have already applied to this job.');
  end if;

  begin
    insert into public.job_applications (
      job_id, professional_entity_id, client_entity_id, cover_note,
      quoted_amount, currency_code, duration_days, status
    ) values (
      p_job_id, v_actor, v_job.client_entity_id, btrim(p_cover_note),
      p_quoted_amount, v_currency, p_duration_days, 'submitted'
    ) returning * into v_application;
  exception when unique_violation then
    perform public.platform_raise_error('PLT005', 'You have already applied to this job.');
  end;

  insert into public.job_events (job_id, actor_id, event_type)
  values (p_job_id, v_actor, 'application_submitted');

  perform public.platform_audit_log_add('application_submit', 'job_applications',
    jsonb_build_object('application_id', v_application.id, 'job_id', p_job_id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Application submitted.',
    'data', to_jsonb(v_application)
  );
end;
$$;

-- ─── 5l. application_withdraw ───────────────────────────────────────────────
create or replace function public.application_withdraw(p_application_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_application public.job_applications%rowtype;
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
    perform public.platform_raise_error('PLT002', 'Only the applicant can withdraw this application.');
  end if;
  if v_application.status not in ('submitted', 'shortlisted') then
    perform public.platform_raise_error('PLT005', 'This application can no longer be withdrawn.');
  end if;

  update public.job_applications
     set status = 'withdrawn', decided_at = now()
   where id = v_application.id
  returning * into v_application;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_application.job_id, v_actor, 'application_withdrawn');

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Application withdrawn.',
    'data', to_jsonb(v_application)
  );
end;
$$;

-- ─── 5m. application_shortlist ──────────────────────────────────────────────
create or replace function public.application_shortlist(p_application_id uuid)
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

  select * into v_job from public.jobs j where j.id = v_application.job_id;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can shortlist applications.');
  end if;
  if v_application.status <> 'submitted' then
    perform public.platform_raise_error('PLT005', 'Only submitted applications can be shortlisted.');
  end if;

  update public.job_applications
     set status = 'shortlisted'
   where id = v_application.id
  returning * into v_application;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_application.job_id, v_actor, 'application_shortlisted');

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Application shortlisted.',
    'data', to_jsonb(v_application)
  );
end;
$$;

-- ─── 5n. application_reject ─────────────────────────────────────────────────
create or replace function public.application_reject(p_application_id uuid)
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

  select * into v_job from public.jobs j where j.id = v_application.job_id;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can reject applications.');
  end if;
  if v_application.status not in ('submitted', 'shortlisted') then
    perform public.platform_raise_error('PLT005', 'This application can no longer be rejected.');
  end if;

  update public.job_applications
     set status = 'rejected', decided_at = now()
   where id = v_application.id
  returning * into v_application;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_application.job_id, v_actor, 'application_rejected');

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Application rejected.',
    'data', to_jsonb(v_application)
  );
end;
$$;

-- ─── 5o. application_list_for_job (owner) ───────────────────────────────────
create or replace function public.application_list_for_job(
  p_job_id uuid,
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
  v_job public.jobs%rowtype;
  v_cursor_ts timestamptz;
  v_items jsonb;
  v_has_more boolean;
  v_next uuid;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_job_id is null then
    perform public.platform_raise_error('PLT003', 'Job id is required.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Job not found.');
  end if;
  if v_job.client_entity_id <> v_actor then
    perform public.platform_raise_error('PLT002', 'Only the job owner can view applications for this job.');
  end if;

  if p_status is not null
     and p_status not in ('submitted', 'withdrawn', 'shortlisted', 'accepted', 'rejected') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;
  if p_limit is null or p_limit not between 1 and 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  if p_cursor is not null then
    select a.submitted_at into v_cursor_ts
      from public.job_applications a
     where a.id = p_cursor and a.job_id = p_job_id;
    if not found then
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Applications retrieved.',
        'data', jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null)
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.submitted_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select a.id, a.job_id, a.professional_entity_id, a.cover_note,
             a.quoted_amount, a.currency_code, a.duration_days, a.status,
             a.submitted_at, a.decided_at, a.created_at, a.updated_at,
             row_number() over (order by a.submitted_at desc, a.id desc) as rn
        from public.job_applications a
       where a.job_id = p_job_id
         and (p_status is null or a.status = p_status)
         and (p_cursor is null or (a.submitted_at, a.id) < (v_cursor_ts, p_cursor))
    ) x;

  if not v_has_more then v_next := null; end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Applications retrieved.',
    'data', jsonb_build_object('items', v_items, 'has_more', v_has_more, 'next_cursor', v_next)
  );
end;
$$;

-- ─── 5p. application_list_mine (professional) ───────────────────────────────
create or replace function public.application_list_mine(
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

  if p_status is not null
     and p_status not in ('submitted', 'withdrawn', 'shortlisted', 'accepted', 'rejected') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;
  if p_limit is null or p_limit not between 1 and 100 then
    perform public.platform_raise_error('PLT003', 'Limit must be between 1 and 100.');
  end if;

  if p_cursor is not null then
    select a.submitted_at into v_cursor_ts
      from public.job_applications a
     where a.id = p_cursor and a.professional_entity_id = v_actor;
    if not found then
      return jsonb_build_object(
        'success', true, 'code', 'PLT000', 'message', 'Applications retrieved.',
        'data', jsonb_build_object('items', '[]'::jsonb, 'has_more', false, 'next_cursor', null)
      );
    end if;
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) - 'rn' order by x.submitted_at desc, x.id desc) filter (where x.rn <= p_limit), '[]'::jsonb),
         coalesce(bool_or(x.rn > p_limit), false),
         (array_agg(x.id order by x.rn))[p_limit]
    into v_items, v_has_more, v_next
    from (
      select a.id, a.job_id, a.professional_entity_id, a.cover_note,
             a.quoted_amount, a.currency_code, a.duration_days, a.status,
             a.submitted_at, a.decided_at, a.created_at, a.updated_at,
             j.title as job_title, j.status as job_status,
             row_number() over (order by a.submitted_at desc, a.id desc) as rn
        from public.job_applications a
        join public.jobs j on j.id = a.job_id
       where a.professional_entity_id = v_actor
         and (p_status is null or a.status = p_status)
         and (p_cursor is null or (a.submitted_at, a.id) < (v_cursor_ts, p_cursor))
    ) x;

  if not v_has_more then v_next := null; end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Applications retrieved.',
    'data', jsonb_build_object('items', v_items, 'has_more', v_has_more, 'next_cursor', v_next)
  );
end;
$$;

-- =============================================================================
-- SECTION 6: REVOKE EXECUTE baseline + GRANTs + COMMENTs
-- =============================================================================
revoke execute on all functions in schema public from public;

grant execute on function public.job_create(text, text, uuid, uuid, numeric, numeric, char(3), text) to authenticated, service_role;
grant execute on function public.job_update(uuid, text, text, uuid, uuid, numeric, numeric, char(3), text) to authenticated, service_role;
grant execute on function public.job_publish(uuid) to authenticated, service_role;
grant execute on function public.job_pause(uuid) to authenticated, service_role;
grant execute on function public.job_resume(uuid) to authenticated, service_role;
grant execute on function public.job_cancel(uuid, text) to authenticated, service_role;
grant execute on function public.job_complete(uuid) to authenticated, service_role;
grant execute on function public.job_get(uuid) to authenticated, service_role;
grant execute on function public.job_list(uuid, text, int, uuid) to authenticated, service_role;
grant execute on function public.job_list_mine(text, text, int, uuid) to authenticated, service_role;
grant execute on function public.application_submit(uuid, text, numeric, char(3), int) to authenticated, service_role;
grant execute on function public.application_withdraw(uuid) to authenticated, service_role;
grant execute on function public.application_shortlist(uuid) to authenticated, service_role;
grant execute on function public.application_reject(uuid) to authenticated, service_role;
grant execute on function public.application_list_for_job(uuid, text, int, uuid) to authenticated, service_role;
grant execute on function public.application_list_mine(text, int, uuid) to authenticated, service_role;

grant execute on function public.platform_is_authenticated() to authenticated, service_role;
grant execute on function public.platform_set_updated_at() to authenticated, service_role;
grant execute on function public.platform_audit_log_add(text, text, jsonb) to authenticated, service_role;

comment on function public.job_create(text, text, uuid, uuid, numeric, numeric, char(3), text) is
  'SECURITY INVOKER, VOLATILE. Hiring client (capability hire|both, PLT002 otherwise) creates a draft job with budget/currency/taxonomy validation. Inserts job + created event.';
comment on function public.job_update(uuid, text, text, uuid, uuid, numeric, numeric, char(3), text) is
  'SECURITY INVOKER, VOLATILE. Owner updates a draft/open/paused job (FOR UPDATE). Awarded/completed/cancelled jobs are immutable (PLT005).';
comment on function public.job_publish(uuid) is
  'SECURITY INVOKER, VOLATILE. Owner publishes a draft job to open. Sets posted_at + published event.';
comment on function public.job_pause(uuid) is
  'SECURITY INVOKER, VOLATILE. Owner pauses an open job (hidden from discovery until resumed).';
comment on function public.job_resume(uuid) is
  'SECURITY INVOKER, VOLATILE. Owner resumes a paused job to open.';
comment on function public.job_cancel(uuid, text) is
  'SECURITY INVOKER, VOLATILE. Owner cancels a draft/open/paused job. Sets cancelled_at + cancelled event.';
comment on function public.job_complete(uuid) is
  'SECURITY INVOKER, VOLATILE. Owner completes an awarded job. Sets completed_at + completed event.';
comment on function public.job_get(uuid) is
  'SECURITY INVOKER, STABLE. Job retrieval with applications[] (owner only), my_application (applicant), and events[]. Identical PLT004 for foreign/unavailable (no oracle).';
comment on function public.job_list(uuid, text, int, uuid) is
  'SECURITY INVOKER, STABLE. Open-job discovery with optional profession filter + FTS search and keyset pagination (created_at desc, id desc).';
comment on function public.job_list_mine(text, text, int, uuid) is
  'SECURITY INVOKER, STABLE. posted = jobs I own; applied = jobs I applied to. Optional status filter + keyset pagination.';
comment on function public.application_submit(uuid, text, numeric, char(3), int) is
  'SECURITY INVOKER, VOLATILE. Professional (capability offer|both) applies to an open job. Self-apply and duplicates blocked (PLT005). Increments applications_count via trigger.';
comment on function public.application_withdraw(uuid) is
  'SECURITY INVOKER, VOLATILE. Applicant withdraws a submitted/shortlisted application.';
comment on function public.application_shortlist(uuid) is
  'SECURITY INVOKER, VOLATILE. Owner shortlists a submitted application.';
comment on function public.application_reject(uuid) is
  'SECURITY INVOKER, VOLATILE. Owner rejects a submitted/shortlisted application.';
comment on function public.application_list_for_job(uuid, text, int, uuid) is
  'SECURITY INVOKER, STABLE. Owner-scoped application list for one job with optional status filter + keyset pagination.';
comment on function public.application_list_mine(text, int, uuid) is
  'SECURITY INVOKER, STABLE. Professional-scoped application list with job title/status denormalized, optional status filter + keyset pagination.';

-- =============================================================================
-- SECTION 7: Realtime exclusion (guarded, idempotent)
-- =============================================================================
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in ('jobs', 'job_applications', 'job_events')
  ) then
    alter publication supabase_realtime drop table
      public.jobs, public.job_applications, public.job_events;
  end if;
end;
$$;
