-- Case spine (CP-016): create, read, triage and work one case.
--
-- The case tables existed since CP-006. This migration adds the narrow
-- functions the control portal uses: a typed register, an append-only timeline,
-- assignment and status changes. Evidence, decisions and approvals are later
-- packages.

set local lock_timeout = '5s';

create function admin.case_view(p_case_id uuid)
returns table (
  id uuid,
  reference text,
  case_type text,
  title text,
  description text,
  priority text,
  severity text,
  status text,
  queue_key text,
  assignee_id uuid,
  assignee_name text,
  assignee_email text,
  department_name text,
  created_at timestamptz,
  updated_at timestamptz,
  closed_at timestamptz
)
language sql
security definer
stable
set search_path = ''
as $$
  select c.id, c.reference, c.case_type, c.title, c.description, c.priority,
         c.severity, c.status, c.queue_key, c.assignee_id,
         a.display_name, a.email, d.name, c.created_at, c.updated_at,
         c.closed_at
    from admin.cases c
    left join identity.users a on a.id = c.assignee_id
    left join admin.departments d on d.id = c.department_id
   where c.id = p_case_id;
$$;

revoke all on function admin.case_view(uuid) from public;
grant execute on function admin.case_view(uuid) to hivorr_api;

create function admin.create_case(
  p_actor_user_id uuid,
  p_case_type text,
  p_title text,
  p_description text,
  p_priority text,
  p_severity text,
  p_queue_key text,
  p_reason text
)
returns table (
  id uuid,
  reference text,
  case_type text,
  title text,
  description text,
  priority text,
  severity text,
  status text,
  queue_key text,
  assignee_id uuid,
  assignee_name text,
  assignee_email text,
  department_name text,
  created_at timestamptz,
  updated_at timestamptz,
  closed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := platform.uuidv7();
  v_reference text := 'CASE-' || upper(substr(replace(platform.uuidv7()::text, '-', ''), 24, 9));
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign') then
    raise exception 'case_work_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'case_reason_required' using errcode = '22023';
  end if;

  if p_title is null or length(btrim(p_title)) < 3 then
    raise exception 'case_title_required' using errcode = '22023';
  end if;

  if p_case_type is null or p_case_type not in (
    'support', 'complaint', 'dispute', 'investigation', 'incident',
    'verification_review', 'financial_exception', 'security_incident',
    'staff_conduct', 'partner_conduct'
  ) then
    raise exception 'case_type_invalid' using errcode = '22023';
  end if;

  if p_priority is null or p_priority not in ('low', 'normal', 'high', 'urgent') then
    raise exception 'case_priority_invalid' using errcode = '22023';
  end if;

  insert into admin.cases as c
    (id, reference, case_type, title, description, priority, severity,
     queue_key, created_by)
  values
    (v_id, v_reference, p_case_type, btrim(p_title),
     nullif(btrim(coalesce(p_description, '')), ''), p_priority,
     coalesce(nullif(p_severity, ''), 'medium'),
     nullif(btrim(coalesce(p_queue_key, '')), ''), p_actor_user_id);

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (v_id, 'created', p_actor_user_id, 'Case created');

  return query select * from admin.case_view(v_id);
end;
$$;

revoke all on function admin.create_case(uuid, text, text, text, text, text, text, text) from public;
grant execute on function admin.create_case(uuid, text, text, text, text, text, text, text) to hivorr_api;

create function admin.list_cases(
  p_actor_user_id uuid,
  p_status text,
  p_type text,
  p_query text
)
returns table (
  id uuid,
  reference text,
  case_type text,
  title text,
  description text,
  priority text,
  severity text,
  status text,
  queue_key text,
  assignee_id uuid,
  assignee_name text,
  assignee_email text,
  department_name text,
  created_at timestamptz,
  updated_at timestamptz,
  closed_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_status text := coalesce(p_status, '');
  v_type text := coalesce(p_type, '');
  v_query text := lower(coalesce(p_query, ''));
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign')
  ) then
    raise exception 'case_read_forbidden' using errcode = '42501';
  end if;

  return query
    select c.id, c.reference, c.case_type, c.title, c.description, c.priority,
           c.severity, c.status, c.queue_key, c.assignee_id,
           a.display_name, a.email, d.name, c.created_at, c.updated_at,
           c.closed_at
      from admin.cases c
      left join identity.users a on a.id = c.assignee_id
      left join admin.departments d on d.id = c.department_id
     where (v_status = '' or c.status = v_status)
       and (v_type = '' or c.case_type = v_type)
       and (
         v_query = ''
         or lower(c.reference) like '%' || v_query || '%'
         or lower(c.title) like '%' || v_query || '%'
       )
     order by (c.status not in ('CLOSED', 'ARCHIVED')) desc,
              c.created_at desc;
end;
$$;

revoke all on function admin.list_cases(uuid, text, text, text) from public;
grant execute on function admin.list_cases(uuid, text, text, text) to hivorr_api;

create function admin.list_case_events(
  p_actor_user_id uuid,
  p_case_id uuid
)
returns table (
  id uuid,
  event_type text,
  summary text,
  actor_name text,
  actor_email text,
  occurred_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign')
  ) then
    raise exception 'case_read_forbidden' using errcode = '42501';
  end if;

  return query
    select e.id, e.event_type, e.summary, u.display_name, u.email,
           e.occurred_at
      from admin.case_events e
      left join identity.users u on u.id = e.actor_user_id
     where e.case_id = p_case_id
     order by e.occurred_at, e.id;
end;
$$;

revoke all on function admin.list_case_events(uuid, uuid) from public;
grant execute on function admin.list_case_events(uuid, uuid) to hivorr_api;

create function admin.add_case_event(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_event_type text,
  p_summary text
)
returns table (
  id uuid,
  event_type text,
  summary text,
  actor_name text,
  actor_email text,
  occurred_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign') then
    raise exception 'case_work_forbidden' using errcode = '42501';
  end if;

  if p_summary is null or length(btrim(p_summary)) < 3 then
    raise exception 'case_event_required' using errcode = '22023';
  end if;

  if not exists (select 1 from admin.cases c where c.id = p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (p_case_id, coalesce(nullif(p_event_type, ''), 'note'),
          p_actor_user_id, btrim(p_summary))
  returning admin.case_events.id into v_id;

  return query
    select e.id, e.event_type, e.summary, u.display_name, u.email,
           e.occurred_at
      from admin.case_events e
      left join identity.users u on u.id = e.actor_user_id
     where e.id = v_id;
end;
$$;

revoke all on function admin.add_case_event(uuid, uuid, text, text) from public;
grant execute on function admin.add_case_event(uuid, uuid, text, text) to hivorr_api;

create function admin.assign_case(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_email text,
  p_queue_key text
)
returns table (
  id uuid,
  reference text,
  case_type text,
  title text,
  description text,
  priority text,
  severity text,
  status text,
  queue_key text,
  assignee_id uuid,
  assignee_name text,
  assignee_email text,
  department_name text,
  created_at timestamptz,
  updated_at timestamptz,
  closed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign') then
    raise exception 'case_work_forbidden' using errcode = '42501';
  end if;

  if not exists (select 1 from admin.cases c where c.id = p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  if p_email is not null and length(btrim(p_email)) > 0 then
    select u.id into v_user_id
      from identity.users u
     where lower(u.email) = lower(btrim(p_email))
       and u.status = 'active'
     limit 1;

    if v_user_id is null then
      raise exception 'case_assignee_not_found' using errcode = 'P0002';
    end if;
  end if;

  update admin.cases c
     set assignee_id = v_user_id,
         queue_key = nullif(btrim(coalesce(p_queue_key, '')), ''),
         updated_at = now()
   where c.id = p_case_id;

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (
    p_case_id,
    'assigned',
    p_actor_user_id,
    case
      when v_user_id is null then 'Case unassigned'
      else 'Case assigned'
    end
  );

  return query select * from admin.case_view(p_case_id);
end;
$$;

revoke all on function admin.assign_case(uuid, uuid, text, text) from public;
grant execute on function admin.assign_case(uuid, uuid, text, text) to hivorr_api;

create function admin.set_case_status(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_status text,
  p_reason text
)
returns table (
  id uuid,
  reference text,
  case_type text,
  title text,
  description text,
  priority text,
  severity text,
  status text,
  queue_key text,
  assignee_id uuid,
  assignee_name text,
  assignee_email text,
  department_name text,
  created_at timestamptz,
  updated_at timestamptz,
  closed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign') then
    raise exception 'case_work_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'case_reason_required' using errcode = '22023';
  end if;

  if p_status is null or p_status not in (
    'TRIAGED', 'OPEN', 'INVESTIGATING', 'PENDING_INFORMATION', 'ESCALATED',
    'REVIEW', 'DECIDED', 'ACTION_PENDING', 'CLOSED', 'REOPENED', 'ARCHIVED'
  ) then
    raise exception 'case_status_invalid' using errcode = '22023';
  end if;

  if not exists (select 1 from admin.cases c where c.id = p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  update admin.cases c
     set status = p_status,
         closed_at = case when p_status = 'CLOSED' then now() else c.closed_at end,
         updated_at = now()
   where c.id = p_case_id;

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (p_case_id, 'status_changed', p_actor_user_id,
          'Status changed to ' || p_status || ': ' || btrim(p_reason));

  return query select * from admin.case_view(p_case_id);
end;
$$;

revoke all on function admin.set_case_status(uuid, uuid, text, text) from public;
grant execute on function admin.set_case_status(uuid, uuid, text, text) to hivorr_api;
