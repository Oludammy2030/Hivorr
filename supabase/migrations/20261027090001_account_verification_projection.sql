-- ─────────────────────────────────────────────────────────────────────────────
-- Account Verification Projection (unified status + eligibility)
--
-- Extends verification_status_get additively:
--   - latest_submissions now carries decision_notes, credential title and
--     business context (business_id / trading name)
--   - latest submissions are grouped by
--     (submission_type, profession_id, business_id) so two businesses never
--     collapse into one review lane
--   - businesses[] lists the caller's memberships with role/authorization,
--     business review state and the latest business submission
--   - eligibility{} exposes server-computed hints (RPCs still enforce)
--
-- The existing fields and their shapes are unchanged. Self-scoped for
-- authenticated callers; service_role may pass any p_entity_id.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.verification_status_get(
  p_entity_id uuid default null
)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_target uuid;
  v_tier_code text;
  v_tier_status text;
  v_daily numeric;
  v_weekly numeric;
  v_monthly numeric;
  v_cashout numeric;
  v_identity_verified boolean;
  v_trade jsonb;
  v_latest jsonb;
  v_businesses jsonb;
  v_pending integer;
  v_total integer;
  v_eligibility jsonb;
begin
  if v_actor is null then
    if p_entity_id is null then
      perform public.platform_raise_error('PLT003', 'Entity id is required for admin query.');
    end if;
    v_target := p_entity_id;
  else
    if p_entity_id is not null and p_entity_id <> v_actor then
      perform public.platform_raise_error('PLT004', 'Cannot view another entity''s verification status.');
    end if;
    v_target := v_actor;
  end if;

  select kt.tier_code, ekl.status, kt.daily_limit, kt.weekly_limit, kt.monthly_limit, kt.cashout_limit
    into v_tier_code, v_tier_status, v_daily, v_weekly, v_monthly, v_cashout
    from public.entity_kyc_levels ekl
    join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
   where ekl.entity_id = v_target;

  if not found then
    v_tier_code := 'tier_0';
    v_tier_status := 'unassigned';
    v_daily := 0; v_weekly := 0; v_monthly := 0; v_cashout := 0;
  end if;

  v_identity_verified := (v_tier_status = 'active' and v_tier_code >= 'tier_1');

  -- Per-profession trade statuses (existing contract).
  select jsonb_agg(
    jsonb_build_object(
      'profession_id', ep.profession_id,
      'trade_verification_status', ep.trade_verification_status,
      'professional_display_name', ep.professional_display_name
    )
  )
    into v_trade
    from public.entity_professions ep
   where ep.entity_id = v_target;

  -- Latest submission per review lane. Trade rows carry the credential's
  -- profession binding; business rows additionally carry business_id so two
  -- businesses never collapse into one lane. Identity rows have neither.
  select coalesce(jsonb_agg(latest.entry order by latest.submitted_at desc, latest.id desc), '[]'::jsonb)
    into v_latest
    from (
      select distinct on (vs.submission_type, ec.profession_id, ec.business_id)
        jsonb_build_object(
          'submission_type', vs.submission_type,
          'profession_id', ec.profession_id,
          'business_id', ec.business_id,
          'business_trading_name', b.trading_name,
          'status', vs.status,
          'submitted_at', vs.submitted_at,
          'reviewed_at', vs.reviewed_at,
          'decision_notes', vs.decision_notes,
          'credential_title', ec.title
        ) as entry,
        vs.submission_type,
        ec.profession_id,
        ec.business_id,
        vs.submitted_at,
        vs.id
        from public.verification_submissions vs
        left join public.entity_credentials ec on ec.id = vs.credential_id
        left join public.businesses b on b.id = ec.business_id
       where vs.entity_id = v_target
       order by vs.submission_type, ec.profession_id, ec.business_id, vs.submitted_at desc, vs.id desc
    ) latest;

  -- Businesses the caller belongs to, with membership + latest business
  -- submission. Active/approved lanes outrank historical rejections so a
  -- fresh resubmission is not hidden behind the prior rejection. RLS keeps
  -- this to the caller's own memberships.
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'business_id', b.id,
      'trading_name', b.trading_name,
      'registered_legal_name', b.registered_legal_name,
      'cac_number', b.cac_number,
      'verification_status', b.verification_status,
      'role', bm.role,
      'is_authorized', bm.is_authorized,
      'latest_submission', (
        select jsonb_build_object(
          'status', vs2.status,
          'submitted_at', vs2.submitted_at,
          'reviewed_at', vs2.reviewed_at,
          'decision_notes', vs2.decision_notes
        )
        from public.verification_submissions vs2
        join public.entity_credentials ec2 on ec2.id = vs2.credential_id
        where vs2.entity_id = v_target
          and ec2.business_id = b.id
          and vs2.submission_type = 'business_verification'
        order by
          case
            when vs2.status = 'approved' then 2
            when vs2.status in ('pending', 'in_review') then 1
            else 0
          end desc,
          vs2.submitted_at desc,
          vs2.id desc
        limit 1
      )
    )
    order by b.id
  ), '[]'::jsonb)
    into v_businesses
    from public.business_memberships bm
    join public.businesses b on b.id = bm.business_id
   where bm.entity_id = v_target;

  select count(*) into v_pending
    from public.verification_submissions vs
   where vs.entity_id = v_target and vs.status in ('pending', 'in_review');

  select count(*) into v_total
    from public.verification_submissions vs
   where vs.entity_id = v_target;

  -- Server-computed eligibility hints. The write RPCs re-check these; the
  -- flags exist so the UI can gate without inferring approval.
  select jsonb_build_object(
    'identity_verified', v_identity_verified,
    'can_post_personal_job', exists (
      select 1 from public.entities e
       where e.id = v_target and e.capability = 'hire'
    ),
    'professional_eligibility', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'profession_id', ep.profession_id,
          'trade_approved', ep.trade_verification_status = 'approved',
          'eligible_to_apply', v_identity_verified and ep.trade_verification_status = 'approved',
          'eligible_to_publish', v_identity_verified and ep.trade_verification_status = 'approved'
        )
      )
      from public.entity_professions ep
      where ep.entity_id = v_target
    ), '[]'::jsonb),
    'business_eligibility', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'business_id', b.id,
          'approved', b.verification_status = 'approved',
          'authorized', coalesce(bm.is_authorized, false),
          'can_hire', b.verification_status = 'approved' and coalesce(bm.is_authorized, false),
          'can_manage', coalesce(bm.role = 'representative', false)
        )
        order by b.id
      )
      from public.business_memberships bm
      join public.businesses b on b.id = bm.business_id
      where bm.entity_id = v_target
    ), '[]'::jsonb)
  ) into v_eligibility;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Verification status retrieved.',
    'data', jsonb_build_object(
      'entity_id', v_target,
      'kyc', jsonb_build_object(
        'tier_code', v_tier_code,
        'status', v_tier_status,
        'limits', jsonb_build_object(
          'daily', v_daily,
          'weekly', v_weekly,
          'monthly', v_monthly,
          'cashout', v_cashout
        )
      ),
      'identity_verified', v_identity_verified,
      'trade_verifications', coalesce(v_trade, '[]'::jsonb),
      'latest_submissions', v_latest,
      'businesses', v_businesses,
      'eligibility', v_eligibility,
      'pending_submissions', v_pending,
      'total_submissions', v_total
    )
  );
end;
$$;

comment on function public.verification_status_get(uuid) is
  'Aggregated verification status for an entity. Self-scoped for authenticated (cross-entity id raises PLT004); service_role may pass any p_entity_id. Returns KYC tier + limits, identity_verified flag, per-profession trade statuses (each with the proposed professional_display_name), latest persisted submission per review lane (submission_type + profession_id + business_id) with decision notes and business context, the caller''s businesses with membership/authorization and latest business submission, server-computed eligibility hints, and submission counts. SECURITY INVOKER; STABLE.';

grant execute on function public.verification_status_get(uuid) to authenticated, service_role;
