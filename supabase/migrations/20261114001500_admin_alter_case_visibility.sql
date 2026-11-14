-- Case visibility scope (F-C-01).
--
-- Until now any holder of `admin.case.read` could read every case. That made
-- the role catalogue's "within an assigned queue" untrue and let a support
-- officer open investigations, staff-conduct and security-incident cases.
--
-- The visibility rule, applied to every case read:
--
--   * the case is assigned to the actor, or
--   * the case belongs to a department where the actor is an active member, or
--   * the actor opened the case, or
--   * the case has neither an assignee nor a department and the actor holds
--     `admin.case.read` or `admin.case.assign` — an unassigned pool nobody
--     could otherwise triage.
--
-- The rule keys on department membership rather than `queue_key` because
-- `queue_key` is free text with nothing mapping it to people, while
-- `department_members` is maintained and already ends on offboarding.
--
-- An invisible case answers `P0002`, not `FORBIDDEN`: a refusal that confirms
-- existence is itself a disclosure.
--
-- `admin.case_view(uuid)` stays as an internal helper for `create_case`, but
-- `hivorr_api` loses EXECUTE: it took no actor and checked no permission, so it
-- must not be callable directly. Definer functions still reach it.

set local lock_timeout = '5s';

create function admin.case_visible_to(
  p_actor_user_id uuid,
  p_case_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
      from admin.cases c
     where c.id = p_case_id
       and (
         c.assignee_id = p_actor_user_id
         or c.created_by = p_actor_user_id
         or exists (
           select 1
             from admin.department_members dm
            where dm.department_id = c.department_id
              and dm.user_id = p_actor_user_id
              and dm.effective_to is null
         )
         or (
           c.department_id is null
           and c.assignee_id is null
           and (
             admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
             or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign')
           )
         )
       )
  )
$$;

comment on function admin.case_visible_to(uuid, uuid) is
  'True when the actor may see the case: assigned to them, in one of their departments, or unassigned and unscoped for a case assigner.';

revoke all on function admin.case_visible_to(uuid, uuid) from public;

-- Internal helper only. `create_case` calls it; no client may.
revoke execute on function admin.case_view(uuid) from hivorr_api;

create or replace function admin.list_cases(
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
       and admin.case_visible_to(p_actor_user_id, c.id)
     order by (c.status not in ('CLOSED', 'ARCHIVED')) desc,
              c.created_at desc;
end;
$$;

revoke all on function admin.list_cases(uuid, text, text, text) from public;
grant execute on function admin.list_cases(uuid, text, text, text) to hivorr_api;

create or replace function admin.list_case_events(
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

  if not admin.case_visible_to(p_actor_user_id, p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
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

create or replace function admin.list_case_evidence(
  p_actor_user_id uuid,
  p_case_id uuid
)
returns table (
  id uuid,
  file_name text,
  mime_type text,
  size_bytes bigint,
  sha256 text,
  classification text,
  status text,
  supersedes_id uuid,
  uploaded_by_name text,
  uploaded_by_email text,
  uploaded_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.evidence.read') then
    raise exception 'evidence_read_forbidden' using errcode = '42501';
  end if;

  if not admin.case_visible_to(p_actor_user_id, p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  return query
    select e.id, e.file_name, e.mime_type, e.size_bytes, e.sha256,
           e.classification, e.status, e.supersedes_id,
           u.display_name, u.email, e.uploaded_at
      from admin.case_evidence e
      left join identity.users u on u.id = e.uploaded_by
     where e.case_id = p_case_id
     order by (e.status = 'active') desc, e.uploaded_at desc;
end;
$$;

revoke all on function admin.list_case_evidence(uuid, uuid) from public;
grant execute on function admin.list_case_evidence(uuid, uuid) to hivorr_api;

create or replace function admin.record_evidence_access(
  p_actor_user_id uuid,
  p_evidence_id uuid,
  p_purpose text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case_id uuid;
  v_file_name text;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.evidence.read') then
    raise exception 'evidence_read_forbidden' using errcode = '42501';
  end if;

  select e.case_id, e.file_name into v_case_id, v_file_name
    from admin.case_evidence e
   where e.id = p_evidence_id;

  if v_case_id is null then
    raise exception 'evidence_not_found' using errcode = 'P0002';
  end if;

  if not admin.case_visible_to(p_actor_user_id, v_case_id) then
    raise exception 'evidence_not_found' using errcode = 'P0002';
  end if;

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (v_case_id, 'evidence_accessed', p_actor_user_id,
          'Evidence accessed: ' || v_file_name ||
          coalesce(' (' || nullif(btrim(p_purpose), '') || ')', ''));
end;
$$;

revoke all on function admin.record_evidence_access(uuid, uuid, text) from public;
grant execute on function admin.record_evidence_access(uuid, uuid, text) to hivorr_api;
