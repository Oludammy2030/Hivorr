-- Identity Phase 4: job-business linkage + client identity snapshots.
--
-- Records hiring "as a business" and freezes the client's role identity at
-- engagement time (founder-approved identity audit, Phase 4):
--   - `jobs.business_id` (nullable FK, SET NULL): the business the job is
--     posted for, or NULL for personal hiring. Set once at creation from an
--     explicit `p_business_id`; never client-mutated after.
--   - `jobs.client_display_name` / `jobs.client_business_name`: point-in-time
--     snapshots written by job_create from the poster's OWN rows (RLS-legal
--     self-reads) — the applicant has no profile read on the client, so
--     snapshotting at create is the only clean path.
--   - `job_applications.client_display_name` / `client_business_id` /
--     `client_business_name`: copied from the job row by application_submit
--     (mirrors the applicant-side snapshot precedent, 20261010090001).
--   - job_create validates the business link: unknown/foreign/non-member →
--     PLT004 (no oracle); known-but-unverified → PLT005; unauthorized
--     representative → PLT005. Untyped-personal posting is untouched.

-- ─── 1. Columns ──────────────────────────────────────────────────────────────
alter table public.jobs
  add column if not exists business_id uuid references public.businesses (id) on delete set null;

alter table public.jobs
  add column if not exists client_display_name text;

alter table public.jobs
  add column if not exists client_business_name text;

create index if not exists jobs_business_idx
  on public.jobs (business_id) where business_id is not null;

comment on column public.jobs.business_id is
  'Hiring business (identity audit Phase 4): set once at creation from p_business_id; NULL = personal hiring. Verified + authorized-representative enforced by job_create; preserved SET NULL so business deletion never destroys jobs.';
comment on column public.jobs.client_display_name is
  'Point-in-time snapshot of the poster display name at creation (self-read; never legal_name). Copied onto applications by application_submit.';
comment on column public.jobs.client_business_name is
  'Point-in-time snapshot of the hiring business trading name at creation; NULL for personal hiring. Copied onto applications by application_submit.';

alter table public.job_applications
  add column if not exists client_display_name text;

alter table public.job_applications
  add column if not exists client_business_id uuid references public.businesses (id) on delete set null;

alter table public.job_applications
  add column if not exists client_business_name text;

comment on column public.job_applications.client_display_name is
  'Submit-time snapshot of the client display name, copied from the job row (the applicant has no profile read on the client). Point-in-time, never refreshed.';
comment on column public.job_applications.client_business_id is
  'Submit-time snapshot of the hiring business id, copied from the job row; NULL for personal hiring. SET NULL preserves applications if the business row is removed.';
comment on column public.job_applications.client_business_name is
  'Submit-time snapshot of the hiring business trading name, copied from the job row; NULL for personal hiring.';

-- ─── 2. job_create: business link + client snapshots ─────────────────────────
drop function if exists public.job_create(text, text, uuid, uuid, numeric, numeric, char(3), text);

create or replace function public.job_create(
  p_title text,
  p_description text,
  p_profession_id uuid default null,
  p_industry_id uuid default null,
  p_budget_min numeric default null,
  p_budget_max numeric default null,
  p_currency_code char(3) default 'NGN',
  p_location text default null,
  p_business_id uuid default null
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
  v_business public.businesses%rowtype;
  v_client_display text;
  v_client_business text;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  select e.capability into v_capability
    from public.entities e
   where e.id = v_actor;
  if v_capability is null or v_capability <> 'hire' then
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

  -- Identity Phase 4: optional hiring-as-business. Unknown, foreign, or
  -- non-member businesses read as PLT004 (no oracle); unverified businesses
  -- and unauthorized representatives read as PLT005 guidance.
  v_business := null;
  if p_business_id is not null then
    select * into v_business
      from public.businesses b
     where b.id = p_business_id;
    if not found then
      perform public.platform_raise_error('PLT004', 'Business not found.');
    end if;
    if not exists (
      select 1 from public.business_memberships m
       where m.business_id = p_business_id and m.entity_id = v_actor
    ) then
      perform public.platform_raise_error('PLT004', 'Business not found.');
    end if;
    if v_business.verification_status <> 'approved' then
      perform public.platform_raise_error('PLT005', 'Business verification required to hire for this business.');
    end if;
    if not exists (
      select 1 from public.business_memberships m
       where m.business_id = p_business_id
         and m.entity_id = v_actor
         and m.role = 'representative'
         and m.is_authorized = true
    ) then
      perform public.platform_raise_error('PLT005', 'Representative authorization required to hire for this business.');
    end if;
  end if;

  -- Client snapshots: self-reads (RLS-legal for the poster). The applicant
  -- has no profile read on the client, so freezing here is the only clean
  -- path; applications copy these verbatim at submit.
  select nullif(btrim(ep.display_name), '')
    into v_client_display
    from public.entity_profiles ep
   where ep.entity_id = v_actor;
  if v_business.id is not null then
    v_client_business := v_business.trading_name;
  else
    v_client_business := null;
  end if;

  insert into public.jobs (
    client_entity_id, profession_id, industry_id, title, description,
    budget_min, budget_max, currency_code, location, status,
    business_id, client_display_name, client_business_name
  ) values (
    v_actor, p_profession_id, p_industry_id, btrim(p_title), btrim(p_description),
    p_budget_min, p_budget_max, v_currency, nullif(btrim(p_location), ''), 'draft',
    p_business_id, v_client_display, v_client_business
  ) returning * into v_job;

  insert into public.job_events (job_id, actor_id, event_type)
  values (v_job.id, v_actor, 'created');

  perform public.platform_audit_log_add('job_create', 'jobs',
    jsonb_build_object('job_id', v_job.id, 'business_id', p_business_id));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Job created.',
    'data', to_jsonb(v_job)
  );
end;
$$;

comment on function public.job_create(text, text, uuid, uuid, numeric, numeric, char(3), text, uuid) is
  'SECURITY INVOKER, VOLATILE. Hiring client (capability hire, PLT002 otherwise) creates a draft job with budget/currency/taxonomy validation. Optional p_business_id hires as a verified business (authorized representative, PLT004/PLT005 otherwise) and snapshots the client display + business names onto the job for engagement history. Inserts job + created event.';

grant execute on function public.job_create(text, text, uuid, uuid, numeric, numeric, char(3), text, uuid) to authenticated, service_role;

-- ─── 3. application_submit: copy the client snapshots ────────────────────────
-- NOTE: full replacement of the Phase 1c version; the sole delta is the
-- client_* insert (plus comment). Trade gate and snapshot logic otherwise
-- byte-identical.
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
  v_display_name text;
  v_avatar_path text;
  v_profession_name text;
  v_profession_slug text;
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

  -- Identity audit Phase 1c (AGENT.md Rule 2): typed jobs require an
  -- approved trade binding for the job's profession. Untyped jobs keep the
  -- legacy capability-only behavior.
  if v_job.profession_id is not null
     and not exists (
       select 1 from public.entity_professions epr
        where epr.entity_id = v_actor
          and epr.profession_id = v_job.profession_id
          and epr.trade_verification_status = 'approved'
     ) then
    perform public.platform_raise_error('PLT005', 'Trade verification required for this profession. Complete approval to apply.');
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

  -- Identity snapshot: self-reads (RLS-legal for the applicant). Missing
  -- profile row yields NULLs and the client falls back to the public-profile
  -- read path; never legal_name/phone/documents.
  select nullif(btrim(ep.display_name), ''), nullif(ep.avatar_path, '')
    into v_display_name, v_avatar_path
    from public.entity_profiles ep
   where ep.entity_id = v_actor;

  select prof.profession_name, prof.profession_slug
    into v_profession_name, v_profession_slug
    from (
      select p.name as profession_name, p.slug as profession_slug
        from public.entity_professions epr
        join public.professions p on p.id = epr.profession_id
       where epr.entity_id = v_actor
         and epr.trade_verification_status = 'approved'
       order by epr.is_primary desc, epr.created_at
       limit 1
    ) prof;

  begin
    insert into public.job_applications (
      job_id, professional_entity_id, client_entity_id, cover_note,
      quoted_amount, currency_code, duration_days, status,
      applicant_display_name, applicant_avatar_path,
      applicant_profession_name, applicant_profession_slug,
      client_display_name, client_business_id, client_business_name
    ) values (
      p_job_id, v_actor, v_job.client_entity_id, btrim(p_cover_note),
      p_quoted_amount, v_currency, p_duration_days, 'submitted',
      v_display_name, v_avatar_path,
      v_profession_name, v_profession_slug,
      v_job.client_display_name, v_job.business_id, v_job.client_business_name
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

comment on function public.application_submit(uuid, text, numeric, char(3), int) is
  'SECURITY INVOKER, VOLATILE. Professional (capability offer|both) applies to an open job. Typed jobs additionally require an approved trade binding for the job profession (PLT005, Rule 2). Self-apply and duplicates blocked (PLT005). Snapshots whitelisted applicant identity (display_name/avatar + primary approved profession) from the applicant''s own profile rows plus the job''s client identity snapshot (display + business); point-in-time, never refreshed. Increments applications_count via trigger.';

grant execute on function public.application_submit(uuid, text, numeric, char(3), int) to authenticated, service_role;

-- ─── 4. application_list_for_job: project the client snapshots ───────────────
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
             a.applicant_display_name, a.applicant_avatar_path,
             a.applicant_profession_name, a.applicant_profession_slug,
             a.client_display_name, a.client_business_id, a.client_business_name,
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

comment on function public.application_list_for_job(uuid, text, int, uuid) is
  'SECURITY INVOKER, STABLE. Owner-scoped application list for one job with optional status filter + keyset pagination. Projects the submit-time applicant AND client identity snapshots (no profile JOIN — entity_profiles is self-scoped under RLS).';
