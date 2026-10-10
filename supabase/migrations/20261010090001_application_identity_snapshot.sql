-- Hivorr Applications — applicant identity snapshot (Phase 4 limitation fix).
--
-- Problem: the client inbox needs each applicant's display identity, but
-- `application_list_for_job` projected `job_applications` columns only, forcing
-- one `portfolio_public_profile_get` RPC per applicant (N+1). A read-path JOIN
-- is NOT an option: `entity_profiles` SELECT is self-scoped
-- (`entity_id = auth.uid()`, `20260821090003`), so an INVOKER list function
-- running as the job owner would see NULL for applicants' rows, and widening
-- that policy would expose full profile rows (incl. `legal_name`/phone) to job
-- owners. A new SECURITY DEFINER reader is rejected: the posture suites allow
-- exactly one (`portfolio_public_profile_get`).
--
-- Fix: snapshot whitelisted identity columns at submit time. `application_submit`
-- runs as the applicant (INVOKER), so reading the applicant's OWN profile +
-- OWN approved profession is RLS-legal and consent-implied (they applied).
-- Reads then ride the existing owner-scoped SELECTs for free:
-- `application_list_for_job` (explicit list, extended below), `job_get`
-- `applications[]` and the submit response (`to_jsonb`, whole-row — automatic).
--
-- Snapshot semantics (deliberate): point-in-time at submission, never refreshed.
-- A later name/profession change does not rewrite history; the client keeps the
-- repository fallback for rows with NULL snapshots (pre-migration rows, missing
-- profile at submit). Only whitelisted public fields are stored — never
-- `legal_name`, phone, documents, or verification metadata.
--
-- RLS/posture impact: none. No policy, grant, or DEFINER change; signatures are
-- unchanged so existing EXECUTE grants persist across CREATE OR REPLACE.

-- ─── 1. Snapshot columns ─────────────────────────────────────────────────────
alter table public.job_applications
  add column if not exists applicant_display_name text,
  add column if not exists applicant_avatar_path text,
  add column if not exists applicant_profession_name text,
  add column if not exists applicant_profession_slug text;

comment on column public.job_applications.applicant_display_name is
  'Snapshot of entity_profiles.display_name at submission (applicant self-read by application_submit). Whitelisted public handle — never legal_name. NULL for pre-migration rows.';
comment on column public.job_applications.applicant_avatar_path is
  'Snapshot of entity_profiles.avatar_path at submission (public avatars bucket path). NULL when the applicant has no avatar or the row predates the snapshot.';
comment on column public.job_applications.applicant_profession_name is
  'Snapshot of the primary APPROVED profession display name at submission (same is_primary-first ordering as portfolio_public_profile_get). NULL when unapproved — trust accuracy preserved.';
comment on column public.job_applications.applicant_profession_slug is
  'Snapshot of the primary approved profession slug at submission (public profile route segment). NULL when unapproved.';

-- ─── 2. Backfill existing rows (migration runs as owner: RLS bypassed) ───────
update public.job_applications a
   set applicant_display_name = nullif(btrim(ep.display_name), ''),
       applicant_avatar_path = nullif(ep.avatar_path, ''),
       applicant_profession_name = prof.profession_name,
       applicant_profession_slug = prof.profession_slug
  from public.entity_profiles ep
  left join lateral (
    select p.name as profession_name, p.slug as profession_slug
      from public.entity_professions epr
      join public.professions p on p.id = epr.profession_id
     where epr.entity_id = a.professional_entity_id
       and epr.trade_verification_status = 'approved'
     order by epr.is_primary desc, epr.created_at
     limit 1
  ) prof on true
 where ep.entity_id = a.professional_entity_id
   and a.applicant_display_name is null;

-- ─── 3. application_submit: snapshot identity (self-read, RLS-legal) ─────────
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
      applicant_profession_name, applicant_profession_slug
    ) values (
      p_job_id, v_actor, v_job.client_entity_id, btrim(p_cover_note),
      p_quoted_amount, v_currency, p_duration_days, 'submitted',
      v_display_name, v_avatar_path,
      v_profession_name, v_profession_slug
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

-- ─── 4. application_list_for_job: project the snapshot ───────────────────────
-- Signature unchanged (grants persist). job_get applications[] and the submit
-- response select whole rows, so they carry the snapshot with no change here.
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

comment on function public.application_submit(uuid, text, numeric, char(3), int) is
  'SECURITY INVOKER, VOLATILE. Professional (capability offer|both) applies to an open job. Self-apply and duplicates blocked (PLT005). Snapshots whitelisted applicant identity (display_name/avatar + primary approved profession) from the applicant''s own profile rows; point-in-time, never refreshed. Increments applications_count via trigger.';
comment on function public.application_list_for_job(uuid, text, int, uuid) is
  'SECURITY INVOKER, STABLE. Owner-scoped application list for one job with optional status filter + keyset pagination. Projects the submit-time applicant identity snapshot (no profile JOIN — entity_profiles is self-scoped under RLS).';
