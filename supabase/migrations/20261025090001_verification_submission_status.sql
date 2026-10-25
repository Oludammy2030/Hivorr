-- ─────────────────────────────────────────────────────────────────────────────
-- Professional-visible review state (identity + trade, independently)
--
-- `verification_status_get` previously exposed only aggregate counters, while
-- `entity_professions.trade_verification_status` only stores
-- `unverified | pending | approved` and `entity_kyc_levels` only the final
-- identity decision. That made it impossible for a client to tell "under
-- review" from "not submitted" (or "rejected" from "never submitted") after a
-- refresh/sign-in, and a trade submission must not mutate either authority.
--
-- This projection reads the existing 5-state review source of truth
-- (`verification_submissions`) and returns the latest row per
-- `(submission_type, profession_id)` lane. It is read-only and self-scoped;
-- approval/rejection rules and the bid gate are unchanged.
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
  v_pending integer;
  v_total integer;
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
  -- profession binding; identity documents have no profession.
  select coalesce(jsonb_agg(latest.entry), '[]'::jsonb)
    into v_latest
    from (
      select distinct on (vs.submission_type, ec.profession_id)
        jsonb_build_object(
          'submission_type', vs.submission_type,
          'profession_id', ec.profession_id,
          'status', vs.status,
          'submitted_at', vs.submitted_at,
          'reviewed_at', vs.reviewed_at
        ) as entry,
        vs.submission_type,
        ec.profession_id,
        vs.submitted_at,
        vs.id
        from public.verification_submissions vs
        left join public.entity_credentials ec on ec.id = vs.credential_id
       where vs.entity_id = v_target
       order by vs.submission_type, ec.profession_id, vs.submitted_at desc, vs.id desc
    ) latest;

  select count(*) into v_pending
    from public.verification_submissions vs
   where vs.entity_id = v_target and vs.status in ('pending', 'in_review');

  select count(*) into v_total
    from public.verification_submissions vs
   where vs.entity_id = v_target;

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
      'pending_submissions', v_pending,
      'total_submissions', v_total
    )
  );
end;
$$;

comment on function public.verification_status_get(uuid) is
  'Aggregated verification status for an entity. Self-scoped for authenticated (cross-entity id raises PLT004); service_role may pass any p_entity_id. Returns KYC tier + limits, identity_verified flag, per-profession trade statuses (each with the proposed professional_display_name), latest persisted submission per review lane (latest_submissions), and submission counts. SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';

grant execute on function public.verification_status_get(uuid) to authenticated, service_role;
