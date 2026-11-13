-- Approval and maker-checker (CP-020).
--
-- One typed approval flow, not a general workflow engine. The tables existed
-- since CP-006; this migration adds the permissions and the narrow functions
-- that create, list and decide a request.
--
-- The first wired action is account closure. The requester can never approve,
-- the approver must hold `admin.approval.decide` at platform scope, and the
-- closure executes only when the request is approved.

set local lock_timeout = '5s';

insert into admin.permissions (key, namespace, description, sensitivity) values
  ('admin.approval.read', 'admin.approval', 'Read approval requests and their history', 'sensitive'),
  ('admin.approval.decide', 'admin.approval', 'Approve or reject a sensitive request', 'critical')
on conflict (key) do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in ('admin.approval.read', 'admin.approval.decide')
 where r.key in ('founder', 'governance_admin')
on conflict do nothing;

create function admin.request_approval(
  p_actor_user_id uuid,
  p_action_type text,
  p_target_type text,
  p_target_id text,
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
  v_reference text := 'APR-' || upper(substr(replace(v_request_id::text, '-', ''), 24, 9));
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.manage') then
    raise exception 'approval_request_forbidden' using errcode = '42501';
  end if;

  if p_action_type is null or p_action_type <> 'account.closure' then
    raise exception 'approval_action_unsupported' using errcode = '22023';
  end if;

  if p_target_type is null or p_target_type <> 'user' then
    raise exception 'approval_target_unsupported' using errcode = '22023';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'approval_reason_required' using errcode = '22023';
  end if;

  if not exists (
    select 1 from identity.users u where u.id = p_target_id::uuid
  ) then
    raise exception 'approval_target_not_found' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from admin.approval_requests ar
     where ar.action_type = p_action_type
       and ar.target_id = p_target_id
       and ar.status = 'pending'
  ) then
    raise exception 'approval_already_pending' using errcode = '23505';
  end if;

  insert into admin.approval_requests
    (id, reference, action_type, target_type, target_id, risk_level,
     requester_user_id, reason)
  values
    (v_request_id, v_reference, p_action_type, p_target_type, p_target_id, 'high',
     p_actor_user_id, btrim(p_reason));

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

revoke all on function admin.request_approval(uuid, text, text, text, text) from public;
grant execute on function admin.request_approval(uuid, text, text, text, text) to hivorr_api;

create function admin.list_approval_requests(
  p_actor_user_id uuid
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
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.approval.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.approval.decide')
  ) then
    raise exception 'approval_read_forbidden' using errcode = '42501';
  end if;

  return query
    select ar.id, ar.reference, ar.action_type, ar.target_type, ar.target_id,
           ar.status, ar.reason, ar.requester_user_id, u.display_name, u.email,
           ar.created_at, ar.decided_at
      from admin.approval_requests ar
      join identity.users u on u.id = ar.requester_user_id
     order by (ar.status = 'pending') desc, ar.created_at desc;
end;
$$;

revoke all on function admin.list_approval_requests(uuid) from public;
grant execute on function admin.list_approval_requests(uuid) to hivorr_api;

create function admin.decide_approval(
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
