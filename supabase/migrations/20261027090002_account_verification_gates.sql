-- ─────────────────────────────────────────────────────────────────────────────
-- Account Verification Gates & Business Lifecycle Fixes
--
--   1. Grant the admin review RPC the membership column privilege it already
--      has an RLS policy for (business approval previously failed for
--      authenticated admins because the table privilege was missing).
--   2. Business rejection now propagates `rejected` to a still-pending
--      business (approval already propagated). Reviewed rows are immutable.
--   3. Freeze business identity fields once evidence is submitted/approved so
--      an approved name/CAC cannot be silently mutated without re-review.
--   4. Atomic business creation (business + representative membership in one
--      transaction), replacing the client create-then-join sequence.
--   5. Business submissions respect the review lifecycle (no duplicate
--      pending/in-review submission, no submission after approval).
--   6. Identity gate on job applications, preserving all existing trade,
--      capability, currency, duplicate and snapshot behavior.
--   7. Identity gate on service publishing, preserving all existing owner,
--      state, profession and trade checks.
--   8. The create-with-published initial-state path enforces the same identity
--      gate as the publish RPC.
--
-- No status is ever set from the client. Review decisions remain admin-only.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Admin review RPC privilege ───────────────────────────────────────────────
-- RLS policy `business_memberships_admin_all` already restricts writes to
-- platform admins; this grants the column the approval RPC sets.
grant update (is_authorized) on table public.business_memberships to authenticated;

-- 2. Rejection propagates to the business lane ────────────────────────────────
-- Preserves the original admin/service_role resolution, reviewed-state guard,
-- D5 GUC escape, immutable decision rows and audit shape. The only additive
-- behavior is the business status propagation at the end.
create or replace function public.verification_review_reject(
  p_submission_id uuid,
  p_notes text default null,
  p_requires_resubmission boolean default false
)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_sub public.verification_submissions;
  v_cred public.entity_credentials;
  v_reviewer uuid;
  v_row public.verification_submissions;
  v_final_status text;
  v_business_id uuid;
begin
  -- Authorization: admin (authenticated) or service_role (backward compat)
  if current_user = 'service_role' then
    v_reviewer := null;
  elsif v_actor is not null then
    if not public.is_platform_admin(v_actor) then
      perform public.platform_raise_error('PLT002', 'Admin access required.');
    end if;
    v_reviewer := v_actor;
  else
    v_reviewer := null;
  end if;

  if p_submission_id is null then
    perform public.platform_raise_error('PLT003', 'Submission id is required.');
  end if;

  select * into v_sub
    from public.verification_submissions
   where id = p_submission_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Submission not found.');
  end if;

  if v_sub.status in ('approved', 'rejected', 'requires_resubmission') then
    perform public.platform_raise_error('PLT005', 'Submission has already been reviewed.');
  end if;

  -- Determine final status
  v_final_status := case
    when p_requires_resubmission then 'requires_resubmission'
    else 'rejected'
  end;

  -- Set GUC to pass D5 guard triggers
  perform set_config('platform.rpc_invocation', 'on', true);

  update public.verification_submissions
     set status = v_final_status,
         reviewed_at = now(),
         reviewed_by = v_reviewer,
         decision_notes = nullif(btrim(p_notes), ''),
         updated_at = now()
   where id = p_submission_id
   returning * into v_row;

  insert into public.verification_reviews (submission_id, entity_id, reviewer_id, decision, decision_notes)
  values (p_submission_id, v_sub.entity_id, v_reviewer, v_final_status, nullif(btrim(p_notes), ''));

  insert into public.verification_audit_trail (
    entity_id, event_type, subject_type, subject_id, from_state, to_state, actor_id, details
  ) values (
    v_sub.entity_id,
    case when v_final_status = 'requires_resubmission' then 'review_resubmitted' else 'review_rejected' end,
    'submission', p_submission_id, v_sub.status, v_final_status, v_reviewer,
    jsonb_build_object('submission_type', v_sub.submission_type)
  );

  -- Business lane: reject a still-pending business. Never downgrade an
  -- already-approved business (no cross-grant; approval rules unchanged).
  if v_sub.submission_type = 'business_verification' then
    select * into v_cred
      from public.entity_credentials
     where id = v_sub.credential_id;

    if v_cred.business_id is not null then
      update public.businesses
         set verification_status = 'rejected',
             updated_at = now()
       where id = v_cred.business_id
         and verification_status = 'pending'
      returning id into v_business_id;

      if v_business_id is not null then
        insert into public.verification_audit_trail (
          entity_id, event_type, subject_type, subject_id, to_state, actor_id, details
        ) values (
          v_sub.entity_id, 'business_status_propagated', 'business', v_business_id,
          'rejected', v_reviewer,
          jsonb_build_object('submission_id', p_submission_id)
        );
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', case when v_final_status = 'requires_resubmission'
      then 'Submission requires resubmission.'
      else 'Submission rejected.' end,
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.verification_review_reject(uuid, text, boolean) is
  'Rejects or requires resubmission. Admin-gated: authenticated callers must be active platform admins. service_role remains for backward compat. Sets platform.rpc_invocation to pass D5 guard triggers. Business verification rejection moves a still-pending business to rejected; never downgrades an approved business and never propagates KYC or trade-gate state. Audit-logged.';

grant execute on function public.verification_review_reject(uuid, text, boolean) to authenticated, service_role;

-- 3. Freeze submitted/approved business identity fields ───────────────────────
-- Names and CAC are member-editable while the business is being prepared or
-- after a rejection, but not once evidence is queued or the business is
-- approved. SECURITY DEFINER so the check cannot be bypassed by RLS visibility.
create or replace function public.businesses_freeze_identity_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- service_role/trusted jobs have no end-user identity; admin review never
  -- edits identity fields (it only moves verification_status).
  if auth.uid() is not null then
    if old.verification_status = 'approved'
       or exists (
         select 1
           from public.verification_submissions vs
           join public.entity_credentials ec on ec.id = vs.credential_id
          where ec.business_id = old.id
            and vs.submission_type = 'business_verification'
            and vs.status in ('pending', 'in_review', 'approved')
       ) then
      if new.trading_name is distinct from old.trading_name
         or new.registered_legal_name is distinct from old.registered_legal_name
         or new.cac_number is distinct from old.cac_number then
        perform public.platform_raise_error(
          'PLT002',
          'Business identity fields cannot be changed after submission. Contact support if the registered details are wrong.'
        );
      end if;
    end if;
  end if;
  return new;
end;
$$;

comment on function public.businesses_freeze_identity_fields() is
  'Freezes businesses.trading_name/registered_legal_name/cac_number once the business is approved or has a pending/in-review/approved business_verification submission. Editing remains possible before submission and after rejection; admins move only verification_status.';

drop trigger if exists businesses_freeze_identity_fields_update on public.businesses;
create trigger businesses_freeze_identity_fields_update
  before update on public.businesses
  for each row
  execute function public.businesses_freeze_identity_fields();

-- Business-wide active verification check. SECURITY DEFINER so the duplicate
-- guard sees submissions queued by any member of the business (the caller can
-- only read their own submission rows under RLS). The membership/admin check
-- prevents the boolean from becoming a cross-business probe.
create or replace function public.business_has_active_verification(
  p_business_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
      from public.verification_submissions vs
      join public.entity_credentials ec on ec.id = vs.credential_id
     where ec.business_id = p_business_id
       and vs.submission_type = 'business_verification'
       and vs.status in ('pending', 'in_review')
  )
  and (
    public.is_platform_admin(auth.uid())
    or exists (
      select 1
        from public.business_memberships bm
       where bm.business_id = p_business_id
         and bm.entity_id = auth.uid()
    )
  );
$$;

comment on function public.business_has_active_verification(uuid) is
  'True when the business has a pending/in-review business_verification submission. Returns false for callers who are neither a business member nor a platform admin.';

revoke execute on function public.business_has_active_verification(uuid) from public, anon;
grant execute on function public.business_has_active_verification(uuid) to authenticated, service_role;

-- 4. Atomic business creation ────────────────────────────────────────────────
create or replace function public.business_create(
  p_trading_name text,
  p_registered_legal_name text,
  p_cac_number text default null
)
returns jsonb
language plpgsql
security invoker
volatile
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_trading_name text := nullif(btrim(p_trading_name), '');
  v_legal_name text := nullif(btrim(p_registered_legal_name), '');
  v_cac_number text := nullif(btrim(coalesce(p_cac_number, '')), '');
  v_business_id uuid;
  v_membership_id uuid;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if v_trading_name is null or v_legal_name is null then
    perform public.platform_raise_error('PLT003', 'Trading name and registered legal name are required.');
  end if;

  insert into public.businesses (
    trading_name, registered_legal_name, cac_number, created_by
  ) values (
    v_trading_name, v_legal_name, v_cac_number, v_actor
  )
  returning id into v_business_id;

  insert into public.business_memberships (business_id, entity_id, role)
  values (v_business_id, v_actor, 'representative')
  returning id into v_membership_id;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Business created.',
    'data', jsonb_build_object(
      'business_id', v_business_id,
      'membership_id', v_membership_id,
      'trading_name', v_trading_name,
      'registered_legal_name', v_legal_name,
      'cac_number', v_cac_number,
      'verification_status', 'pending'
    )
  );
exception
  when unique_violation then
    perform public.platform_raise_error('PLT002', 'A business with this CAC number already exists.');
end;
$$;

comment on function public.business_create(text, text, text) is
  'Creates a pending business and the caller''s representative membership atomically. Starts unverified; status moves only through the review RPCs.';

revoke execute on function public.business_create(text, text, text) from public, anon;
grant execute on function public.business_create(text, text, text) to authenticated;

-- 5. Business submissions respect the review lifecycle ───────────────────────
-- Preserves the existing kind/type coherence, ownership, dedup, audit and
-- return shape. Adds: an approved business needs no further evidence, and a
-- business with a pending/in-review submission cannot queue another one.
create or replace function public.verification_submit(
  p_credential_id uuid,
  p_submission_type text default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_cred public.entity_credentials;
  v_sub_type text;
  v_row public.verification_submissions;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_credential_id is null then
    perform public.platform_raise_error('PLT003', 'Credential id is required.');
  end if;

  select * into v_cred
    from public.entity_credentials
   where id = p_credential_id;

  if not found then
    perform public.platform_raise_error('PLT004', 'Credential not found.');
  end if;

  if v_cred.entity_id <> v_actor then
    perform public.platform_raise_error('PLT004', 'Credential does not belong to this entity.');
  end if;

  v_sub_type := coalesce(nullif(btrim(p_submission_type), ''), v_cred.kind);

  -- Kind default: a business document queues to the business lane when the
  -- caller omits the type (mirrors kind-derived defaults elsewhere).
  if v_sub_type = 'business_document' then
    v_sub_type := 'business_verification';
  end if;

  if v_sub_type not in ('identity_document', 'trade_proof', 'certification', 'business_verification') then
    perform public.platform_raise_error('PLT003', 'Invalid submission type.');
  end if;

  -- Coherence: the business lane only carries business documents, and a
  -- business_verification submission always resolves from one.
  if v_sub_type = 'business_verification' and v_cred.kind <> 'business_document' then
    perform public.platform_raise_error('PLT003', 'Business verification requires a business document credential.');
  end if;
  if v_cred.kind = 'business_document' and v_sub_type <> 'business_verification' then
    perform public.platform_raise_error('PLT003', 'Business documents submit to business verification only.');
  end if;

  -- Business lane lifecycle: once approved, no further evidence is needed;
  -- while a submission is under review, do not queue another one.
  if v_sub_type = 'business_verification' and v_cred.business_id is not null then
    if exists (
      select 1 from public.businesses b
       where b.id = v_cred.business_id
         and b.verification_status = 'approved'
    ) then
      perform public.platform_raise_error('PLT005', 'This business is already verified.');
    end if;

    if public.business_has_active_verification(v_cred.business_id) then
      perform public.platform_raise_error('PLT005', 'A business verification submission is already under review.');
    end if;
  end if;

  -- Dedup: one active submission per credential
  if exists (
    select 1 from public.verification_submissions vs
     where vs.credential_id = p_credential_id
       and vs.status in ('pending', 'in_review')
  ) then
    perform public.platform_raise_error('PLT005', 'An active submission already exists for this credential.');
  end if;

  begin
    insert into public.verification_submissions (entity_id, credential_id, submission_type, priority)
    values (v_actor, p_credential_id, v_sub_type, 5)
    returning * into v_row;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'An active submission already exists for this credential.');
    when foreign_key_violation then
      perform public.platform_raise_error('PLT004', 'Credential not found.');
  end;

  -- Authoritative verification audit trail (insert policy is self-scoped)
  insert into public.verification_audit_trail (
    entity_id, event_type, subject_type, subject_id, to_state, actor_id, details
  ) values (
    v_actor, 'submission_created', 'submission', v_row.id, 'pending', v_actor,
    jsonb_build_object('submission_type', v_sub_type, 'credential_id', p_credential_id)
  );

  -- General platform audit (authenticated context guarantees auth.uid() is set)
  perform public.platform_audit_log_add(
    'verification_submit', 'verification_submissions',
    jsonb_build_object('submission_type', v_sub_type, 'credential_id', p_credential_id)
  );

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Verification submission queued.',
    'data', to_jsonb(v_row)
  );
end;
$$;

comment on function public.verification_submit(uuid, text) is
  'Queues a verification submission for an owned credential. Kind/type coherence enforced; one active submission per credential. Business lane additionally blocks resubmission while another business submission is pending/in_review and blocks submission for an already-approved business. Audit-logged.';

grant execute on function public.verification_submit(uuid, text) to authenticated, service_role;

-- 6. Job applications require verified identity + existing trade rules ────────
-- Preserves the current function verbatim (capability, open job, self-apply,
-- typed-job trade gate, cover-note/currency/duration validation, duplicate
-- check, identity snapshot, job event, audit, return shape) and adds a single
-- identity gate. SECURITY INVOKER as before.
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

  -- Identity gate (unified account): a professional must have an
  -- admin-verified identity before applying. Trade approval remains a
  -- separate, profession-scoped requirement below.
  if not exists (
    select 1
      from public.entity_kyc_levels ekl
      join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
     where ekl.entity_id = v_actor
       and ekl.status = 'active'
       and kt.tier_code >= 'tier_1'
  ) then
    perform public.platform_raise_error('PLT005', 'Identity verification required before applying.');
  end if;

  select * into v_job from public.jobs j where j.id = p_job_id;
  if not found or v_job.status <> 'open' then
    perform public.platform_raise_error('PLT004', 'Job not found or not available.');
  end if;

  if v_job.client_entity_id = v_actor then
    perform public.platform_raise_error('PLT005', 'You cannot apply to your own job.');
  end if;

  -- Typed jobs require an approved trade binding for the job's profession.
  -- Untyped jobs keep the legacy capability-only trade behavior.
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
  'SECURITY INVOKER, VOLATILE. Professional (capability offer) applies to an open job. Requires an admin-verified identity (PLT005, unified account) and, for typed jobs, an approved trade binding for the job profession (PLT005). Self-apply and duplicates blocked (PLT005). Snapshots whitelisted applicant identity (display_name/avatar + primary approved profession) plus the job''s client identity snapshot; never legal_name/documents.';

grant execute on function public.application_submit(uuid, text, numeric, char(3), int) to authenticated, service_role;

-- 7. Service publishing requires verified identity + existing trade rules ─────
-- Preserves the owner/state/profession/trade checks, D5 GUC, published_at and
-- return shape; adds one identity gate.
create or replace function public.service_listing_publish(
  p_listing_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_profession_id uuid;
  v_status text;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_listing_id is null then
    perform public.platform_raise_error('PLT003', 'Listing id is required.');
  end if;

  select l.status, l.profession_id
    into v_status, v_profession_id
    from public.service_listings l
   where l.id = p_listing_id
     and l.entity_id = v_actor
   for update;

  if not found then
    perform public.platform_raise_error('PLT004', 'Listing not found.');
  end if;

  if v_status not in ('draft', 'paused') then
    perform public.platform_raise_error('PLT005', 'Listing is not in a publishable state.');
  end if;

  -- Identity gate (unified account): professional services are only
  -- publishable by an admin-verified identity.
  if not exists (
    select 1
      from public.entity_kyc_levels ekl
      join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
     where ekl.entity_id = v_actor
       and ekl.status = 'active'
       and kt.tier_code >= 'tier_1'
  ) then
    perform public.platform_raise_error('PLT005', 'Identity verification required to publish services.');
  end if;

  if not exists (
    select 1 from public.professions p
     where p.id = v_profession_id
       and p.is_active
  ) then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  perform 1
    from public.entity_professions ep
   where ep.entity_id = v_actor
     and ep.profession_id = v_profession_id
     and ep.trade_verification_status = 'approved'
   for update;

  if not found then
    perform public.platform_raise_error('PLT005', 'Trade verification required. Complete verification before publishing.');
  end if;

  perform set_config('platform.rpc_invocation', 'on', true);

  update public.service_listings
     set status = 'published',
         published_at = now(),
         is_trade_verified_cache = true
   where id = p_listing_id
     and entity_id = v_actor;

  select jsonb_build_object(
           'id', l.id, 'entity_id', l.entity_id, 'profession_id', l.profession_id,
           'industry_id', l.industry_id, 'slug', l.slug, 'title', l.title,
           'description', l.description, 'status', l.status,
           'pricing_type', l.pricing_type, 'price_min', l.price_min,
           'price_max', l.price_max, 'currency_code', l.currency_code,
           'is_trade_verified_cache', l.is_trade_verified_cache,
           'avg_rating', l.avg_rating, 'review_count', l.review_count,
           'view_count', l.view_count, 'published_at', l.published_at,
           'created_at', l.created_at, 'updated_at', l.updated_at
         )
    into v_data
    from public.service_listings l
   where l.id = p_listing_id;

  if public.platform_is_authenticated() then
    perform public.platform_audit_log_add(
      'service_listing_publish', 'service_listings',
      jsonb_build_object('listing_id', p_listing_id)
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listing published.',
    'data', v_data
  );
end;
$$;

comment on function public.service_listing_publish(uuid) is
  'Security invoker, owner-only. draft/paused -> published after re-checking identity (active tier_1+) and the trade gate (entity_professions approved, profession active) under row locks. Sets published_at and is_trade_verified_cache under platform.rpc_invocation (D5 guard). Audit-logged.';

grant execute on function public.service_listing_publish(uuid) to authenticated, service_role;

-- 8. Create-with-published requires the same identity gate ───────────────────
-- Preserves validation, slug derivation, trade-gate error precedence, D5 GUC,
-- and return shape; adds the unified-account identity check to the shortcut
-- that inserts a listing already in `published` state.
create or replace function public.service_listing_create(
  p_profession_id uuid,
  p_title text,
  p_description text,
  p_pricing_type text,
  p_price_min numeric default null,
  p_price_max numeric default null,
  p_currency_code char(3) default 'NGN',
  p_status text default 'draft'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_title text;
  v_description text;
  v_slug text;
  v_status text;
  v_is_verified boolean;
  v_id uuid;
  v_data jsonb;
begin
  if not public.platform_is_authenticated() then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if p_profession_id is null then
    perform public.platform_raise_error('PLT003', 'Profession id is required.');
  end if;

  if nullif(btrim(p_title), '') is null
     or char_length(btrim(p_title)) not between 10 and 120 then
    perform public.platform_raise_error('PLT003', 'Title must be between 10 and 120 characters.');
  end if;

  if nullif(btrim(p_description), '') is null
     or char_length(btrim(p_description)) not between 50 and 5000 then
    perform public.platform_raise_error('PLT003', 'Description must be between 50 and 5000 characters.');
  end if;

  if p_pricing_type not in ('fixed', 'hourly', 'custom', 'per_milestone') then
    perform public.platform_raise_error('PLT003', 'Invalid pricing type.');
  end if;

  if p_price_min is not null and p_price_min < 0 then
    perform public.platform_raise_error('PLT003', 'Minimum price must be zero or greater.');
  end if;

  if p_price_max is not null and p_price_min is null then
    perform public.platform_raise_error('PLT003', 'Minimum price is required when a maximum price is provided.');
  end if;

  if p_price_max is not null and p_price_max < p_price_min then
    perform public.platform_raise_error('PLT003', 'Maximum price must be greater than or equal to the minimum price.');
  end if;

  if p_pricing_type <> 'custom' and p_price_min is null then
    perform public.platform_raise_error('PLT003', 'Minimum price is required for this pricing type.');
  end if;

  if p_status not in ('draft', 'published') then
    perform public.platform_raise_error('PLT003', 'Invalid initial status.');
  end if;

  if not exists (
    select 1 from public.financial_supported_currencies c
     where c.currency_code = p_currency_code
       and c.is_active
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;

  if not exists (
    select 1 from public.professions p
     where p.id = p_profession_id
       and p.is_active
  ) then
    perform public.platform_raise_error('PLT004', 'Profession not found.');
  end if;

  if not exists (
    select 1 from public.entity_professions ep
     where ep.entity_id = v_actor
       and ep.profession_id = p_profession_id
  ) then
    perform public.platform_raise_error('PLT005', 'Bind this profession to your profile before creating a listing.');
  end if;

  v_title := btrim(p_title);
  v_description := btrim(p_description);
  v_slug := btrim(regexp_replace(regexp_replace(lower(v_title), '[^a-z0-9]+', '-', 'g'), '-+', '-', 'g'), '-');
  v_slug := btrim(left(v_slug, 140), '-');
  if nullif(v_slug, '') is null then
    perform public.platform_raise_error('PLT003', 'Title must contain letters or numbers.');
  end if;

  if p_status = 'published' then
    -- Identity gate (unified account): publishing is a restricted action.
    if not exists (
      select 1
        from public.entity_kyc_levels ekl
        join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
       where ekl.entity_id = v_actor
         and ekl.status = 'active'
         and kt.tier_code >= 'tier_1'
    ) then
      perform public.platform_raise_error('PLT005', 'Identity verification required to publish services.');
    end if;

    if not exists (
      select 1 from public.entity_professions ep
       where ep.entity_id = v_actor
         and ep.profession_id = p_profession_id
         and ep.trade_verification_status = 'approved'
    ) then
      perform public.platform_raise_error('PLT005', 'Trade verification required. Complete verification before publishing.');
    end if;
    v_is_verified := true;
  else
    v_is_verified := exists (
      select 1 from public.entity_professions ep
       where ep.entity_id = v_actor
         and ep.profession_id = p_profession_id
         and ep.trade_verification_status = 'approved'
    );
  end if;
  v_status := p_status;

  perform set_config('platform.rpc_invocation', 'on', true);

  begin
    insert into public.service_listings (
      entity_id, profession_id, slug, title, description, status,
      pricing_type, price_min, price_max, currency_code,
      is_trade_verified_cache, published_at
    ) values (
      v_actor, p_profession_id, v_slug, v_title, v_description, v_status,
      p_pricing_type, p_price_min, p_price_max, p_currency_code,
      v_is_verified, case when v_status = 'published' then now() else null end
    )
    returning id into v_id;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'A listing with this title already exists.');
  end;

  select jsonb_build_object(
           'id', l.id, 'entity_id', l.entity_id, 'profession_id', l.profession_id,
           'industry_id', l.industry_id, 'slug', l.slug, 'title', l.title,
           'description', l.description, 'status', l.status,
           'pricing_type', l.pricing_type, 'price_min', l.price_min,
           'price_max', l.price_max, 'currency_code', l.currency_code,
           'is_trade_verified_cache', l.is_trade_verified_cache,
           'avg_rating', l.avg_rating, 'review_count', l.review_count,
           'view_count', l.view_count, 'published_at', l.published_at,
           'created_at', l.created_at, 'updated_at', l.updated_at
         )
    into v_data
    from public.service_listings l
   where l.id = v_id;

  if public.platform_is_authenticated() then
    perform public.platform_audit_log_add(
      'service_listing_create', 'service_listings',
      jsonb_build_object('listing_id', v_id, 'status', v_status)
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Listing created.',
    'data', v_data
  );
end;
$$;

comment on function public.service_listing_create(uuid, text, text, text, numeric, numeric, char(3), text) is
  'Security invoker. Creates a draft (default) or, after the identity and trade gates pass for the bound profession, a published listing. Validates profession (active), currency (active), pricing and title; slug is derived from the title. Publish-state columns are written under platform.rpc_invocation (D5 guard). Audit-logged.';

grant execute on function public.service_listing_create(uuid, text, text, text, numeric, numeric, char(3), text) to authenticated, service_role;
