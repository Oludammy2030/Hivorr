-- Verification review integration and the immutable decision record (EP-02-015).
--
-- A submitted lane opens a typed `verification_review` case and a queue row, so
-- the control portal sees it without a second queue. The reviewer decision then
-- applies the lane transition, the KYC tier effect and the decision record in one
-- transaction.
--
-- The decision row is append-only from EP-02-010; this migration adds what the
-- task requires it to carry: the prior and next lane state and the evidence
-- references the reviewer saw.
--
-- No subject path can approve: the decision function still requires
-- `admin.verification.review`, and the subject-side service never calls it.

set local lock_timeout = '5s';

alter table profile.verification_submissions
  add column requested_kyc_tier text
    check (requested_kyc_tier is null or requested_kyc_tier in ('tier_1', 'tier_2', 'tier_3'));

comment on column profile.verification_submissions.requested_kyc_tier is
  'The tier the subject asks for on the kyc lane. Null on every other lane; the reviewer approves or rejects it.';

alter table profile.verification_decisions
  add column from_state text not null default 'UNDER_REVIEW'
    check (from_state in (
      'NOT_STARTED', 'DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'EXPIRED'
    )),
  add column to_state text not null default 'APPROVED'
    check (to_state in (
      'NOT_STARTED', 'DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'EXPIRED'
    )),
  add column evidence_ids uuid[] not null default '{}',
  add column admin_case_id uuid references admin.cases (id) on delete set null;

comment on column profile.verification_decisions.from_state is
  'The lane state the reviewer saw before deciding.';
comment on column profile.verification_decisions.to_state is
  'The lane state this decision produced.';
comment on column profile.verification_decisions.evidence_ids is
  'The evidence references that were on the attempt when the decision was taken.';

comment on column profile.verification_decisions.admin_case_id is
  'The control-portal review case this decision closed. The lane case stays in case_id.';

-- A submitted lane opens the control-portal review. Security definer because a
-- subject has no case-management permission; the function verifies the submission
-- belongs to the account and is submitted before writing anything.
create function admin.open_verification_review(
  p_actor_user_id uuid,
  p_account_id uuid,
  p_submission_id uuid,
  p_title text
)
returns table (case_id uuid, reference text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case_id uuid := platform.uuidv7();
  v_reference text := 'CASE-' || upper(substr(replace(platform.uuidv7()::text, '-', ''), 24, 9));
  v_submission record;
begin
  select s.id, s.account_id, s.lane, s.state
    into v_submission
    from profile.verification_submissions s
   where s.id = p_submission_id
     and s.account_id = p_account_id
   for update;

  if v_submission.id is null then
    raise exception 'verification_submission_not_found' using errcode = 'P0002';
  end if;

  if v_submission.state <> 'SUBMITTED' then
    raise exception 'verification_submission_not_submitted' using errcode = '23514';
  end if;

  insert into admin.cases
    (id, reference, case_type, title, description, status, priority, severity,
     subject_type, subject_id, created_by)
  values
    (v_case_id, v_reference, 'verification_review',
     coalesce(p_title, v_submission.lane || ' verification'),
     'Opened from a lane submission.',
     'OPEN', 'normal', 'medium',
     'verification_submission', p_submission_id::text, p_actor_user_id);

  insert into admin.verification_reviews (case_id, lane, status)
  values (v_case_id, v_submission.lane, 'pending');

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (v_case_id, 'verification_submitted', p_actor_user_id,
          'Lane ' || v_submission.lane || ' submitted for review');

  return query select v_case_id, v_reference;
end;
$$;

comment on function admin.open_verification_review(uuid, uuid, uuid, text) is
  'Opens a verification_review case and queue row for a submitted lane attempt. Called by the subject service; the account and submission are re-checked.';

revoke all on function admin.open_verification_review(uuid, uuid, uuid, text) from public;
grant execute on function admin.open_verification_review(uuid, uuid, uuid, text) to hivorr_api;

-- Extend the reviewer decision: the lane and the tier move with the decision.
create or replace function admin.record_verification_decision(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_decision text,
  p_reason text
)
returns table (
  case_id uuid,
  reference text,
  title text,
  lane text,
  review_status text,
  case_status text,
  priority text,
  subject_type text,
  subject_id text,
  assignee_email text,
  evidence_count bigint,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case_type text;
  v_evidence bigint;
  v_review_status text;
  v_case_status text;
  v_outcome text;
  v_lane text;
  v_subject_type text;
  v_subject_id text;
  v_submission_id uuid;
  v_submission_state text;
  v_lane_case_id uuid;
  v_account_id uuid;
  v_requested_tier text;
  v_next_state text;
  v_decision text;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.verification.review') then
    raise exception 'verification_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'verification_reason_required' using errcode = '22023';
  end if;

  if p_decision is null
     or p_decision not in ('approve', 'reject', 'request_information') then
    raise exception 'verification_decision_invalid' using errcode = '22023';
  end if;

  select c.case_type, c.subject_type, c.subject_id
    into v_case_type, v_subject_type, v_subject_id
    from admin.cases c
   where c.id = p_case_id
   for update;

  if v_case_type is null then
    raise exception 'verification_case_not_found' using errcode = 'P0002';
  end if;

  if v_case_type <> 'verification_review' then
    raise exception 'verification_case_invalid' using errcode = '22023';
  end if;

  select count(*) into v_evidence
    from admin.case_evidence e
   where e.case_id = p_case_id and e.status = 'active';

  select v.lane into v_lane
    from admin.verification_reviews v
   where v.case_id = p_case_id;

  -- A lane submission carries its own evidence; the control-portal case evidence
  -- is not used for it. Resolve the attempt when the case points at one.
  if v_subject_type = 'verification_submission' and v_subject_id is not null then
    select s.id, s.state, s.case_id, s.account_id, s.requested_kyc_tier
      into v_submission_id, v_submission_state, v_lane_case_id, v_account_id, v_requested_tier
      from profile.verification_submissions s
     where s.id = v_subject_id::uuid
     for update;

    if v_submission_id is null then
      raise exception 'verification_submission_not_found' using errcode = 'P0002';
    end if;

    if v_submission_state <> 'UNDER_REVIEW' then
      raise exception 'verification_submission_not_under_review' using errcode = '23514';
    end if;
  end if;

  if p_decision = 'approve' and v_submission_id is null and v_evidence = 0 then
    raise exception 'verification_evidence_required' using errcode = '23514';
  end if;

  insert into admin.verification_reviews
    (case_id, lane, status, decided_by, decided_at, decision_reason)
  values
    (p_case_id, coalesce(v_lane, 'identity'),
     case p_decision
       when 'approve' then 'approved'
       when 'reject' then 'rejected'
       else 'information_requested'
     end,
     p_actor_user_id, now(), btrim(p_reason))
  on conflict on constraint verification_reviews_case_id_key do update
    set status = excluded.status,
        decided_by = excluded.decided_by,
        decided_at = excluded.decided_at,
        decision_reason = excluded.decision_reason,
        updated_at = now();

  if p_decision = 'approve' then
    v_review_status := 'approved';
    v_case_status := 'DECIDED';
    v_outcome := 'verification_approved';
    v_next_state := 'APPROVED';
    v_decision := 'APPROVED';
  elsif p_decision = 'reject' then
    v_review_status := 'rejected';
    v_case_status := 'DECIDED';
    v_outcome := 'verification_rejected';
    v_next_state := 'REJECTED';
    v_decision := 'REJECTED';
  else
    v_review_status := 'information_requested';
    v_case_status := 'PENDING_INFORMATION';
    v_outcome := null;
    -- The shared state set has no information-requested state; the attempt is
    -- rejected with a reason so the lane reopens for resubmission.
    v_next_state := 'REJECTED';
    v_decision := 'REJECTED';
  end if;

  if v_submission_id is not null then
    update profile.verification_submissions s
       set state = v_next_state,
           decided_at = now(),
           reason_code = case
             when p_decision = 'request_information' then 'information_required'
             else null
           end,
           updated_at = now()
     where s.id = v_submission_id;

    update profile.verification_cases c
       set state = v_next_state,
           reason_code = case
             when p_decision = 'request_information' then 'information_required'
             else null
           end,
           state_changed_at = now(),
           updated_at = now()
     where c.account_id = v_account_id
       and c.lane = v_lane;

    insert into profile.verification_decisions
      (case_id, admin_case_id, submission_id, account_id, lane, decision,
       reason_code, reason, decided_by, decided_at, from_state, to_state,
       evidence_ids)
    values
      (v_lane_case_id, p_case_id, v_submission_id, v_account_id, v_lane, v_decision,
       case when p_decision = 'request_information' then 'information_required'
            else 'reviewer_decision' end,
       btrim(p_reason), p_actor_user_id, now(),
       v_submission_state, v_next_state,
       coalesce(
         (select array_agg(e.id order by e.uploaded_at)
            from profile.verification_evidence e
           where e.submission_id = v_submission_id),
         '{}'::uuid[]
       ));

    if v_lane = 'kyc' and p_decision = 'approve' and v_requested_tier is not null then
      perform 1 from identity.set_kyc_tier(
        p_actor_user_id, v_account_id, v_requested_tier, btrim(p_reason)
      );
    end if;
  end if;

  update admin.cases c
     set status = v_case_status,
         outcome = v_outcome,
         closure_reason = btrim(p_reason),
         closed_at = case when v_case_status = 'DECIDED' then now() else c.closed_at end,
         updated_at = now()
   where c.id = p_case_id;

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (p_case_id, 'verification_' || v_review_status, p_actor_user_id,
          'Verification decision: ' || v_review_status || ' — ' || btrim(p_reason));

  return query
    select q.* from admin.list_verification_queue(p_actor_user_id, '') q
     where q.case_id = p_case_id;
end;
$$;

revoke all on function admin.record_verification_decision(uuid, uuid, text, text) from public;
grant execute on function admin.record_verification_decision(uuid, uuid, text, text) to hivorr_api;

-- The queue's evidence count follows the case's subject: a lane submission keeps
-- its evidence in profile, a control-portal case keeps it on the case.
create or replace function admin.list_verification_queue(
  p_actor_user_id uuid,
  p_status text
)
returns table (
  case_id uuid,
  reference text,
  title text,
  lane text,
  review_status text,
  case_status text,
  priority text,
  subject_type text,
  subject_id text,
  assignee_email text,
  evidence_count bigint,
  created_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_status text := coalesce(p_status, '');
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.verification.review') then
    raise exception 'verification_forbidden' using errcode = '42501';
  end if;

  return query
    select c.id, c.reference, c.title,
           coalesce(v.lane, 'identity'),
           coalesce(v.status, 'pending'),
           c.status, c.priority, c.subject_type, c.subject_id,
           a.email,
           case
             when c.subject_type = 'verification_submission' and c.subject_id is not null then
               (select count(*) from profile.verification_evidence e2
                 where e2.submission_id = c.subject_id::uuid)
             else
               (select count(*) from admin.case_evidence e
                 where e.case_id = c.id and e.status = 'active')
           end,
           c.created_at
      from admin.cases c
      left join admin.verification_reviews v on v.case_id = c.id
      left join identity.users a on a.id = c.assignee_id
     where c.case_type = 'verification_review'
       and (v_status = '' or coalesce(v.status, 'pending') = v_status)
     order by
       case coalesce(v.status, 'pending')
         when 'pending' then 0
         when 'information_requested' then 1
         else 2
       end,
       c.created_at;
end;
$$;

revoke all on function admin.list_verification_queue(uuid, text) from public;
grant execute on function admin.list_verification_queue(uuid, text) to hivorr_api;