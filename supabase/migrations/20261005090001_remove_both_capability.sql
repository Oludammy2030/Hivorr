-- Unified Account: eradicate the `both` capability value.
--
-- Product decision: there is no `both` anymore. One Hivorr account holds one
-- switchable focus — `hire` (Explore: hire + discover services) or `offer`
-- (Earn: offer professional services) — freely changeable at any time via the
-- Explore/Earn launcher (`entity_onboarding_status_update`). Earned state is
-- never lost on switch: professional `entity_roles` rows, profession bindings,
-- credentials, verification approvals, listings, jobs, contracts, escrow and
-- reviews all key off `entities(id)` and survive a focus change; only the
-- focus-gated writes (job_create needs hire, application_submit needs offer)
-- follow the current focus.
--
--   1. Remaps every existing `both` row to `offer` (the earned professional
--      state; hiring is one launcher tap away). The completion stamp stays
--      valid: `both` could only complete via the offer-path proofs, which are
--      exactly the `offer` completion requirements.
--   2. Narrows entities_capability_allowed CHECK to hire | offer.
--   3. entity_onboarding_status_update: vocabulary hire | offer (PLT003 on
--      `both`/unknown), completion branch for `offer` only.
--   4. job_create gate: capability = hire. application_submit gate:
--      capability = offer. (Previously hire|both / offer|both.)
--   5. manage_user_list filter: hire | offer | professional (= offer) |
--      client (= hire). The `both` exact filter is rejected (PLT003).
--   6. Refreshes all affected comments (columns, constraints, functions).
--
-- SECURITY INVOKER throughout (no new SECURITY DEFINER). Grants are preserved:
-- CREATE OR REPLACE keeps existing EXECUTE grants, so no grant rebase here.

-- ─── 1. Remap + narrow the vocabulary ───────────────────────────────────────
select set_config('platform.rpc_invocation', 'on', false);

update public.entities
   set capability = 'offer'
 where capability = 'both';

alter table public.entities
  drop constraint entities_capability_allowed;

alter table public.entities
  add constraint entities_capability_allowed check (
    capability is null or capability in ('hire', 'offer')
  );

select set_config('platform.rpc_invocation', 'off', false);

comment on column public.entities.capability is
  'Switchable account focus (hire | offer), persisted server-side. NULL means onboarding not yet started. hire = Explore (hire professionals, discover services); offer = Earn (verified professional services). Changed any time via entity_onboarding_status_update — earned roles, bindings, credentials and history survive a switch.';
comment on constraint entities_capability_allowed on public.entities is
  'Capability vocabulary is hire | offer only. There is no both value: multi-activity use is achieved by switching focus, never by a combined value. Mirrors the client EntityCapability model.';

-- ─── 2. Onboarding status update: hire | offer vocabulary ───────────────────
create or replace function public.entity_onboarding_status_update(
  p_capability text default null,
  p_completed boolean default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_row public.entities;
  v_resolved_capability text;
  v_audit_details jsonb := '{}'::jsonb;
  v_changed boolean := false;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_capability is null and p_completed is null then
    perform public.platform_raise_error('PLT003', 'Provide a capability or a completion flag.');
  end if;

  -- Validate capability vocabulary
  if p_capability is not null then
    if nullif(btrim(p_capability), '') is null then
      perform public.platform_raise_error('PLT003', 'Capability cannot be empty.');
    end if;
    if btrim(p_capability) not in ('hire', 'offer') then
      perform public.platform_raise_error('PLT003', 'Invalid capability value.');
    end if;
    v_audit_details := v_audit_details || jsonb_build_object('capability', btrim(p_capability));
    v_changed := true;
  end if;

  -- Server-side step verification before stamping completion
  if p_completed then
    if not exists (
      select 1 from public.entity_profiles p where p.entity_id = auth.uid()
    ) then
      perform public.platform_raise_error('PLT003', 'Complete your profile before finishing onboarding.');
    end if;

    select coalesce(p_capability, e.capability) into v_resolved_capability
      from public.entities e where e.id = auth.uid();

    if v_resolved_capability is null then
      perform public.platform_raise_error('PLT003', 'Choose your capability before finishing onboarding.');
    end if;

    v_resolved_capability := btrim(v_resolved_capability);

    if v_resolved_capability = 'offer' then
      if not exists (
        select 1 from public.entity_roles r
         where r.entity_id = auth.uid() and r.role = 'professional' and r.is_active
      ) then
        perform public.platform_raise_error('PLT003', 'Activate the professional role before finishing onboarding.');
      end if;
      if not exists (
        select 1 from public.entity_professions b where b.entity_id = auth.uid()
      ) then
        perform public.platform_raise_error('PLT003', 'Bind at least one profession before finishing onboarding.');
      end if;
      if not exists (
        select 1 from public.entity_credentials c
         where c.entity_id = auth.uid() and c.kind = 'identity_document'
      ) then
        perform public.platform_raise_error('PLT003', 'Submit an identity document before finishing onboarding.');
      end if;
      if not exists (
        select 1 from public.entity_credentials c
         where c.entity_id = auth.uid() and c.kind = 'trade_proof'
      ) then
        perform public.platform_raise_error('PLT003', 'Submit trade proof before finishing onboarding.');
      end if;
    end if;

    v_audit_details := v_audit_details || jsonb_build_object('completed_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'));
    v_changed := true;
  end if;

  perform set_config('platform.rpc_invocation', 'on', true);

  update public.entities
     set capability = coalesce(p_capability, capability),
         onboarding_completed_at = case
           when p_completed then now()
           when p_completed is false then null
           else onboarding_completed_at
         end
   where id = auth.uid()
   returning * into v_row;

  if not found then
    perform public.platform_raise_error('PLT004', 'Entity not found.');
  end if;

  perform public.platform_audit_log_add(
    'entity_onboarding_status_update',
    'entities',
    v_audit_details
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Onboarding status updated.',
    'data', jsonb_build_object(
      'capability', v_row.capability,
      'onboarding_completed_at', v_row.onboarding_completed_at
    )
  );
end;
$$;

comment on function public.entity_onboarding_status_update(text, boolean) is
  'Authoritative onboarding state mutation. Capability vocabulary is hire | offer (PLT003 on both/unknown); switching focus is a plain capability write and never destroys earned roles, bindings or credentials. Completion stamped only after server-side step verification (profile, capability, and for offer: professional role + profession binding + identity document + trade proof). p_completed = false clears the stamp (re-onboarding intent). Audit-logged. Guarded by entities_guard_onboarding_state — direct PATCH is blocked.';

-- ─── 3. job_create gate: hire focus ─────────────────────────────────────────
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

comment on function public.job_create(text, text, uuid, uuid, numeric, numeric, char(3), text) is
  'SECURITY INVOKER, VOLATILE. Hiring client (capability hire, PLT002 otherwise) creates a draft job with budget/currency/taxonomy validation. Inserts job + created event.';

comment on column public.jobs.client_entity_id is
  'Hiring client (auth.uid() at creation). Posting requires capability hire (RPC-enforced). Switch focus to hire via the launcher to post.';

-- ─── 4. application_submit gate: offer focus ─────────────────────────────────
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
  if v_capability is null or v_capability <> 'offer' then
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

comment on function public.application_submit(uuid, text, numeric, char(3), int) is
  'SECURITY INVOKER, VOLATILE. Professional (capability offer) applies to an open job. Self-apply and duplicates blocked (PLT005). Increments applications_count via trigger.';

comment on column public.job_applications.professional_entity_id is
  'Applying professional (auth.uid() at submission). Applying requires capability offer (RPC-enforced); owner self-apply is blocked (PLT005). Switch focus to offer via the launcher to apply.';

-- ─── 5. manage_user_list filter: hire | offer | professional | client ───────
create or replace function public.manage_user_list(
  p_search text default null,
  p_status text default null,
  p_offset int default 0,
  p_limit int default 20,
  p_capability text default null
)
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_users jsonb;
  v_total_count int;
  v_term text;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_status is not null and p_status not in ('active', 'suspended', 'deactivated', 'deleted') then
    perform public.platform_raise_error('PLT003', 'Invalid status filter.');
  end if;

  if p_capability is not null and p_capability not in ('hire', 'offer', 'professional', 'client') then
    perform public.platform_raise_error('PLT003', 'Invalid capability filter.');
  end if;

  if p_offset < 0 or p_limit < 1 or p_limit > 100 then
    perform public.platform_raise_error('PLT003', 'Invalid pagination bounds.');
  end if;

  v_term := nullif(btrim(coalesce(p_search, '')), '');

  select count(*) into v_total_count
    from public.entities e
    left join public.entity_profiles ep on ep.entity_id = e.id
   where (p_status is null or e.status = p_status)
     and (
       p_capability is null
       or (p_capability = 'hire' and e.capability = 'hire')
       or (p_capability = 'offer' and e.capability = 'offer')
       or (p_capability = 'professional' and e.capability = 'offer')
       or (p_capability = 'client' and e.capability = 'hire')
     )
     and (v_term is null
          or ep.display_name ilike '%' || v_term || '%'
          or ep.legal_name ilike '%' || v_term || '%');

  select coalesce(jsonb_agg(entry), '[]'::jsonb)
    into v_users
    from (
      select jsonb_build_object(
        'id', e.id,
        'display_name', ep.display_name,
        'legal_name', ep.legal_name,
        'avatar_path', ep.avatar_path,
        'status', e.status,
        'capability', e.capability,
        'roles', coalesce(
          (select array_agg(er.role order by er.role)
             from public.entity_roles er
            where er.entity_id = e.id and er.is_active),
          array[]::text[]),
        'kyc_tier', (select k.tier_code
                       from public.entity_kyc_levels k
                      where k.entity_id = e.id
                      order by k.assigned_at desc
                      limit 1),
        'is_admin', public.is_platform_admin(e.id),
        'onboarding_completed', e.onboarding_completed_at is not null,
        'created_at', e.created_at
      ) as entry
      from public.entities e
      left join public.entity_profiles ep on ep.entity_id = e.id
     where (p_status is null or e.status = p_status)
       and (
         p_capability is null
         or (p_capability = 'hire' and e.capability = 'hire')
         or (p_capability = 'offer' and e.capability = 'offer')
         or (p_capability = 'professional' and e.capability = 'offer')
         or (p_capability = 'client' and e.capability = 'hire')
       )
       and (v_term is null
            or ep.display_name ilike '%' || v_term || '%'
            or ep.legal_name ilike '%' || v_term || '%')
     order by e.created_at desc
     limit p_limit offset p_offset
    ) sub;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'User directory retrieved.',
    'data', jsonb_build_object(
      'users', v_users,
      'total_count', v_total_count
    )
  );
end;
$$;

comment on function public.manage_user_list(text, text, int, int, text) is
  'Paginated admin user directory with capability filter. Supports case-insensitive search on display/legal name, entity status filter, and capability filter (hire | offer | professional | client) where professional = offer and client = hire. Row includes capability. Admin-gated. Pagination 1..100.';
