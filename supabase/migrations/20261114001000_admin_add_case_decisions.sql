-- Case decisions through the approval primitive (CP-018 + CP-020 wiring).
--
-- A case cannot reach DECIDED on one person's authority. The working operator
-- requests a decision; a second administrator holding admin.case.approve and
-- admin.approval.decide records it. The outcome is stored on the case and the
-- timeline.

set local lock_timeout = '5s';

alter table admin.approval_requests
  add column if not exists payload jsonb not null default '{}'::jsonb;

comment on column admin.approval_requests.payload is
  'Action-specific data captured with the request, such as a case outcome.';

create function admin.request_case_decision(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_outcome text,
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
  v_request_id uuid := platform.uuidv7();
  v_reference text := 'APR-' || upper(substr(replace(platform.uuidv7()::text, '-', ''), 24, 9));
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign') then
    raise exception 'case_work_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'case_reason_required' using errcode = '22023';
  end if;

  if p_outcome is null or length(btrim(p_outcome)) < 3 then
    raise exception 'case_outcome_required' using errcode = '22023';
  end if;

  if not exists (select 1 from admin.cases c where c.id = p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from admin.approval_requests ar
     where ar.action_type = 'case.decision'
       and ar.target_id = p_case_id::text
       and ar.status = 'pending'
  ) then
    raise exception 'approval_already_pending' using errcode = '23505';
  end if;

  insert into admin.approval_requests
    (id, reference, action_type, target_type, target_id, risk_level,
     requester_user_id, reason, payload)
  values
    (v_request_id, v_reference, 'case.decision', 'case', p_case_id::text,
     'high', p_actor_user_id, btrim(p_reason),
     jsonb_build_object('outcome', btrim(p_outcome)));

  insert into admin.approval_steps (request_id, stage, required_permission, status)
  values (v_request_id, 1, 'admin.approval.decide', 'pending');

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (p_case_id, 'decision_requested', p_actor_user_id,
          'Decision requested: ' || btrim(p_outcome));

  return query
    select ar.id, ar.reference, ar.action_type, ar.target_type, ar.target_id,
           ar.status, ar.reason, ar.requester_user_id, u.display_name, u.email,
           ar.created_at, ar.decided_at
      from admin.approval_requests ar
      join identity.users u on u.id = ar.requester_user_id
     where ar.id = v_request_id;
end;
$$;

revoke all on function admin.request_case_decision(uuid, uuid, text, text) from public;
grant execute on function admin.request_case_decision(uuid, uuid, text, text) to hivorr_api;

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
  v_outcome text;
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

    if v_request.action_type = 'case.decision' then
      insert into admin.case_events (case_id, event_type, actor_user_id, summary)
      values (v_request.target_id::uuid, 'decision_rejected', p_actor_user_id,
              'Decision rejected: ' || btrim(p_reason));
    end if;
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
    elsif v_request.action_type = 'case.decision' then
      if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.approve') then
        raise exception 'approval_action_permission_required' using errcode = '42501';
      end if;

      v_outcome := v_request.payload->>'outcome';

      update admin.cases c
         set status = 'DECIDED',
             outcome = v_outcome,
             closure_reason = btrim(p_reason),
             updated_at = now()
       where c.id = v_request.target_id::uuid;

      insert into admin.case_events (case_id, event_type, actor_user_id, summary)
      values (v_request.target_id::uuid, 'decision_recorded', p_actor_user_id,
              'Decision recorded: ' || coalesce(v_outcome, '—'));
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
