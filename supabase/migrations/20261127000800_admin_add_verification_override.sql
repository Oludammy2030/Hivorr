-- Verification override with dual control (EP-02-016).
--
-- A decided lane is normally final. Correcting one is an approval request that a
-- second authorised operator must approve; the requester can never approve it
-- (the approvals spine already enforces that) and a rejection changes nothing.
--
-- The override deliberately steps past the transition table — that is what an
-- override is — but only inside this function, through a transaction-local
-- marker the trigger checks. Nothing else can set it.
--
-- Both actors are recorded: the requester on the approval request and in the
-- decision row, the approver as `decided_by`, with the prior and next state.

set local lock_timeout = '5s';

alter table admin.approval_requests
  add column requested_state text
    check (requested_state is null or requested_state in ('APPROVED', 'REJECTED'));

comment on column admin.approval_requests.requested_state is
  'The state a verification override asks for. Null for every other action type.';

alter table profile.verification_decisions
  add column requested_by uuid references identity.users (id) on delete set null;

comment on column profile.verification_decisions.requested_by is
  'The operator who requested an override. Null for an ordinary reviewer decision.';

-- The only bypass: a transaction-local marker set by the override function.
create or replace function profile.enforce_verification_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.state is distinct from old.state
     and coalesce(current_setting('app.verification_override', true), '') <> 'on'
     and not profile.verification_transition_allowed(old.state, new.state) then
    raise exception 'verification_transition_invalid: % -> %', old.state, new.state
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function admin.request_verification_override(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_requested_state text,
  p_reason text
)
returns table (
  id uuid,
  reference text,
  action_type text,
  target_type text,
  target_id text,
  status text,
  reason text,
  requester_user_id uuid,
  requester_name text,
  requester_email text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid := platform.uuidv7();
  v_reference text := 'APR-' || upper(substr(replace(platform.uuidv7()::text, '-', ''), 24, 9));
  v_case_type text;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.verification.review') then
    raise exception 'approval_request_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'approval_reason_required' using errcode = '22023';
  end if;

  if p_requested_state is null or p_requested_state not in ('APPROVED', 'REJECTED') then
    raise exception 'approval_override_state_invalid' using errcode = '22023';
  end if;

  select c.case_type into v_case_type
    from admin.cases c
   where c.id = p_case_id;

  if v_case_type is null then
    raise exception 'approval_target_not_found' using errcode = 'P0002';
  end if;

  if v_case_type <> 'verification_review' then
    raise exception 'approval_target_unsupported' using errcode = '22023';
  end if;

  if exists (
    select 1 from admin.approval_requests ar
     where ar.action_type = 'verification_override'
       and ar.target_id = p_case_id::text
       and ar.status = 'pending'
  ) then
    raise exception 'approval_already_pending' using errcode = '23505';
  end if;

  insert into admin.approval_requests
    (id, reference, action_type, target_type, target_id, risk_level,
     requester_user_id, reason, requested_state)
  values
    (v_request_id, v_reference, 'verification_override', 'verification_case',
     p_case_id::text, 'high', p_actor_user_id, btrim(p_reason), p_requested_state);

  insert into admin.approval_steps
    (request_id, stage, required_permission, status)
  values
    (v_request_id, 1, 'admin.approval.decide', 'pending');

  return query
    select ar.id, ar.reference, ar.action_type, ar.target_type, ar.target_id,
           ar.status, ar.reason, ar.requester_user_id, u.display_name, u.email,
           ar.created_at
      from admin.approval_requests ar
      join identity.users u on u.id = ar.requester_user_id
     where ar.id = v_request_id;
end;
$$;

revoke all on function admin.request_verification_override(uuid, uuid, text, text) from public;
grant execute on function admin.request_verification_override(uuid, uuid, text, text) to hivorr_api;

create or replace function admin.decide_approval(
  p_actor_user_id uuid,
  p_request_id uuid,
  p_decision text,
  p_reason text
)
returns table (
  id uuid,
  reference text,
  action_type text,
  target_type text,
  target_id text,
  status text,
  reason text,
  requester_user_id uuid,
  requester_name text,
  requester_email text,
  created_at timestamptz,
  decided_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request admin.approval_requests%rowtype;
  v_step_id uuid;
  v_lane_case_id uuid;
  v_override_account uuid;
  v_override_lane text;
  v_from_state text;
  v_override_submission uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.approval.decide') then
    raise exception 'approval_decide_forbidden' using errcode = '42501';
  end if;

  if p_decision is null or p_decision not in ('approve', 'reject') then
    raise exception 'approval_decision_invalid' using errcode = '22023';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'approval_reason_required' using errcode = '22023';
  end if;

  select * into v_request
    from admin.approval_requests ar
   where ar.id = p_request_id
   for update;

  if v_request.id is null then
    raise exception 'approval_not_found' using errcode = 'P0002';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'approval_already_decided' using errcode = '23514';
  end if;

  if v_request.requester_user_id = p_actor_user_id then
    raise exception 'approval_self_decision_forbidden' using errcode = '42501';
  end if;

  select s.id into v_step_id
    from admin.approval_steps s
   where s.request_id = p_request_id
     and s.status = 'pending'
   order by s.stage
   limit 1;

  if v_step_id is null then
    raise exception 'approval_step_missing' using errcode = 'P0002';
  end if;

  insert into admin.approval_decisions
    (request_id, step_id, decision, decided_by, reason)
  values
    (p_request_id, v_step_id, p_decision, p_actor_user_id, btrim(p_reason));

  if p_decision = 'reject' then
    update admin.approval_steps s
       set status = 'rejected', decided_by = p_actor_user_id,
           decided_at = now(), reason = btrim(p_reason)
     where s.id = v_step_id;
    update admin.approval_requests ar
       set status = 'rejected', decided_at = now(), updated_at = now()
     where ar.id = p_request_id;
  else
    if v_request.action_type = 'account.closure' then
      if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.manage') then
        raise exception 'approval_action_permission_required' using errcode = '42501';
      end if;
      perform 1
        from admin.govern_user(
          p_actor_user_id,
          v_request.target_id::uuid,
          'close',
          v_request.reason
        ) g;
    elsif v_request.action_type = 'verification_override' then
      if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.verification.review') then
        raise exception 'approval_action_permission_required' using errcode = '42501';
      end if;

      if v_request.requested_state is null then
        raise exception 'approval_override_state_missing' using errcode = '22023';
      end if;

      -- The request targets the review case; the lane case is reached through
      -- the submission it was opened for.
      select s.case_id
        into v_lane_case_id
        from admin.cases c
        join profile.verification_submissions s on s.id = c.subject_id::uuid
       where c.id = v_request.target_id::uuid
         and c.subject_type = 'verification_submission';

      if v_lane_case_id is null then
        raise exception 'verification_case_not_found' using errcode = 'P0002';
      end if;

      select c2.account_id, c2.lane, c2.state
        into v_override_account, v_override_lane, v_from_state
        from profile.verification_cases c2
       where c2.id = v_lane_case_id
       for update;

      select s.id into v_override_submission
        from profile.verification_submissions s
       where s.account_id = v_override_account
         and s.lane = v_override_lane
       order by s.created_at desc
       limit 1;

      -- The marker is transaction-local; the trigger honours it only here.
      perform set_config('app.verification_override', 'on', true);
      update profile.verification_cases c
         set state = v_request.requested_state,
             state_changed_at = now(),
             updated_at = now()
       where c.id = v_lane_case_id;

      if v_override_submission is not null then
        update profile.verification_submissions s
           set state = v_request.requested_state,
               decided_at = now(),
               updated_at = now()
         where s.id = v_override_submission;
      end if;
      perform set_config('app.verification_override', 'off', true);

      insert into profile.verification_decisions
        (case_id, admin_case_id, submission_id, account_id, lane, decision,
         reason_code, reason, decided_by, decided_at, from_state, to_state,
         evidence_ids, requested_by)
      values
        (v_lane_case_id, v_request.target_id::uuid, v_override_submission,
         v_override_account, v_override_lane,
         v_request.requested_state, 'verification_override', btrim(p_reason),
         p_actor_user_id, now(), v_from_state, v_request.requested_state,
         coalesce(
           (select array_agg(e.id order by e.uploaded_at)
              from profile.verification_evidence e
             where e.submission_id = v_override_submission),
           '{}'::uuid[]
         ),
         v_request.requester_user_id);
    else
      raise exception 'approval_action_unsupported' using errcode = '22023';
    end if;

    update admin.approval_steps s
       set status = 'approved', decided_by = p_actor_user_id,
           decided_at = now(), reason = btrim(p_reason)
     where s.id = v_step_id;
    update admin.approval_requests ar
       set status = 'approved', decided_at = now(), updated_at = now()
     where ar.id = p_request_id;
  end if;

  return query
    select ar.id, ar.reference, ar.action_type, ar.target_type, ar.target_id,
           ar.status, ar.reason, ar.requester_user_id, u.display_name, u.email,
           ar.created_at, ar.decided_at
      from admin.approval_requests ar
      join identity.users u on u.id = ar.requester_user_id
     where ar.id = p_request_id;
end;
$$;

revoke all on function admin.decide_approval(uuid, uuid, text, text) from public;
grant execute on function admin.decide_approval(uuid, uuid, text, text) to hivorr_api;
