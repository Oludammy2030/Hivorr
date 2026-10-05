-- Professional Verification Queue: admin metrics RPC (Phase 2).
--
-- Adds `verification_review_metrics_get`, the backend source for the three
-- deferred dashboard cards (avg verification time, approved today, rejection
-- rate). Definitions follow the founder-approved plan:
--
--   - avg_verification_seconds: avg(reviewed_at − submitted_at) over
--     submissions decided (approved/rejected) in the trailing `p_days`.
--   - approved_today: `verification_reviews` with decision = 'approved' and
--     created_at >= date_trunc('day', now()) (UTC day boundary).
--   - rejection_rate: rejected / (approved + rejected) over the trailing
--     `p_days`. `requires_resubmission` is EXCLUDED from both sides
--     (founder decision: resubmission is neither approval nor rejection).
--
-- OUTPUT CONTRACT (asserted in supabase/tests/database/039):
--   verification_review_metrics_get -> data {
--     pending_total, in_review_total, avg_verification_seconds,
--     approved_today, decided_total, rejected_total, rejection_rate,
--     period_days
--   }
--
-- Security posture mirrors `verification_review_queue_get`: SECURITY INVOKER,
-- body gate on `is_platform_admin()`, EXECUTE to authenticated + service_role
-- only. Read-only (STABLE): no writes, no D5-guard interaction.

create or replace function public.verification_review_metrics_get(
  p_days int default 30,
  p_submission_type text default null
)
returns jsonb
language plpgsql
security invoker
stable
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_period_start timestamptz;
  v_day_start timestamptz := date_trunc('day', now());
  v_pending_total int := 0;
  v_in_review_total int := 0;
  v_avg_seconds double precision := null;
  v_approved_today int := 0;
  v_decided_total int := 0;
  v_rejected_total int := 0;
  v_rejection_rate double precision := null;
begin
  if v_actor is null or not public.is_platform_admin(v_actor) then
    perform public.platform_raise_error('PLT002', 'Admin access required.');
  end if;

  if p_days is null or p_days < 1 or p_days > 365 then
    perform public.platform_raise_error('PLT003', 'Invalid period (1-365 days).');
  end if;

  if p_submission_type is not null and p_submission_type not in (
    'trade_proof', 'identity_document', 'certification'
  ) then
    perform public.platform_raise_error('PLT003', 'Invalid submission type filter.');
  end if;

  v_period_start := now() - (p_days || ' days')::interval;

  -- Live queue depth (same predicate family as the queue RPC).
  select count(*) into v_pending_total
    from public.verification_submissions vs
   where vs.status = 'pending'
     and (p_submission_type is null or vs.submission_type = p_submission_type);

  select count(*) into v_in_review_total
    from public.verification_submissions vs
   where vs.status = 'in_review'
     and (p_submission_type is null or vs.submission_type = p_submission_type);

  -- Mean time-to-decision over the trailing window (decided rows only).
  select avg(extract(epoch from (vs.reviewed_at - vs.submitted_at)))
    into v_avg_seconds
    from public.verification_submissions vs
   where vs.status in ('approved', 'rejected')
     and vs.reviewed_at is not null
     and vs.reviewed_at >= v_period_start
     and (p_submission_type is null or vs.submission_type = p_submission_type);

  -- Approvals since the UTC day boundary (decision records are immutable).
  select count(*) into v_approved_today
    from public.verification_reviews vr
    join public.verification_submissions vs on vs.id = vr.submission_id
   where vr.decision = 'approved'
     and vr.created_at >= v_day_start
     and (p_submission_type is null or vs.submission_type = p_submission_type);

  -- Trailing-window decision totals (resubmission excluded by definition).
  select count(*) into v_decided_total
    from public.verification_reviews vr
    join public.verification_submissions vs on vs.id = vr.submission_id
   where vr.decision in ('approved', 'rejected')
     and vr.created_at >= v_period_start
     and (p_submission_type is null or vs.submission_type = p_submission_type);

  select count(*) into v_rejected_total
    from public.verification_reviews vr
    join public.verification_submissions vs on vs.id = vr.submission_id
   where vr.decision = 'rejected'
     and vr.created_at >= v_period_start
     and (p_submission_type is null or vs.submission_type = p_submission_type);

  if v_decided_total > 0 then
    v_rejection_rate := v_rejected_total::double precision / v_decided_total::double precision;
  end if;

  return jsonb_build_object(
    'success', true,
    'code', 'PLT000',
    'message', 'Review metrics retrieved.',
    'data', jsonb_build_object(
      'pending_total', v_pending_total,
      'in_review_total', v_in_review_total,
      'avg_verification_seconds', v_avg_seconds,
      'approved_today', v_approved_today,
      'decided_total', v_decided_total,
      'rejected_total', v_rejected_total,
      'rejection_rate', v_rejection_rate,
      'period_days', p_days
    )
  );
end;
$$;

comment on function public.verification_review_metrics_get(int, text) is
  'Admin verification throughput metrics for the Professional Verification Queue dashboard. Admin-gated. Trailing-window means exclude requires_resubmission by definition. Canonical output shape asserted by test 039.';

grant execute on function public.verification_review_metrics_get(int, text) to authenticated, service_role;
