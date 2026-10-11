-- Identity Phase 1c: approved-trade gate on application_submit (Rule 2).
--
-- Closes the unverified-bidding bypass: an `offer` capability alone no
-- longer suffices to bid on a typed job. When the job carries a
-- profession_id, the applicant must hold an `approved` trade binding for
-- that exact profession, else PLT005 with guidance. Untyped jobs
-- (profession_id null) keep the legacy capability-only behavior, and the
-- pre-existing capability/self/duplicate checks are untouched.
--
-- Mirrors the service_listing_publish trade gate vocabulary
-- (PLT005 'Trade verification required ...'); client surfaces the message
-- as guidance toward the requirements flow. No approval-revocation path
-- exists, so a plain EXISTS check is sufficient (no lock ordering change).

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

comment on function public.application_submit(uuid, text, numeric, char(3), int) is
  'SECURITY INVOKER, VOLATILE. Professional (capability offer|both) applies to an open job. Typed jobs additionally require an approved trade binding for the job profession (PLT005, Rule 2). Self-apply and duplicates blocked (PLT005). Snapshots whitelisted applicant identity (display_name/avatar + primary approved profession) from the applicant''s own profile rows; point-in-time, never refreshed. Increments applications_count via trigger.';

grant execute on function public.application_submit(uuid, text, numeric, char(3), int) to authenticated, service_role;
