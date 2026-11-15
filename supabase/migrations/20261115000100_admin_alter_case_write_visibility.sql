-- Case write visibility and department on creation (follow-ups 25 and 26).
--
-- The reads were scoped in `20261114001500`, but the write paths still acted on
-- any case id. A caller who knew an id they could not see could append to its
-- timeline, reassign it, change its status, attach evidence or supersede it.
-- Each write now applies the same predicate and answers not-found for a case the
-- actor cannot see.
--
-- `create_case` also files the case in the creator's department. Before this, a
-- new case always landed in the unfiled pool, which only a case assigner could
-- see. The department is the creator's earliest active membership; a creator with
-- no department still creates into the unfiled pool, which is the triage case
-- the visibility rule already describes.

set local lock_timeout = '5s';

create or replace function admin.create_case(
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
  v_department_id uuid;
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

  -- File the case where its creator works. Earliest membership wins when the
  -- creator belongs to more than one department.
  select dm.department_id into v_department_id
    from admin.department_members dm
   where dm.user_id = p_actor_user_id
     and dm.effective_to is null
   order by dm.created_at, dm.department_id
   limit 1;

  insert into admin.cases as c
    (id, reference, case_type, title, description, priority, severity,
     queue_key, department_id, created_by)
  values
    (v_id, v_reference, p_case_type, btrim(p_title),
     nullif(btrim(coalesce(p_description, '')), ''), p_priority,
     coalesce(nullif(p_severity, ''), 'medium'),
     nullif(btrim(coalesce(p_queue_key, '')), ''), v_department_id,
     p_actor_user_id);

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (v_id, 'created', p_actor_user_id, 'Case created');

  return query select * from admin.case_view(v_id);
end;
$$;

revoke all on function admin.create_case(uuid, text, text, text, text, text, text, text) from public;
grant execute on function admin.create_case(uuid, text, text, text, text, text, text, text) to hivorr_api;

create or replace function admin.add_case_event(
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

  if not admin.case_visible_to(p_actor_user_id, p_case_id) then
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

create or replace function admin.assign_case(
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

  if not admin.case_visible_to(p_actor_user_id, p_case_id) then
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

create or replace function admin.set_case_status(
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

  if not admin.case_visible_to(p_actor_user_id, p_case_id) then
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

create or replace function admin.add_case_evidence(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_storage_key text,
  p_file_name text,
  p_mime_type text,
  p_size_bytes bigint,
  p_sha256 text,
  p_classification text,
  p_reason text
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
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign') then
    raise exception 'case_work_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'case_reason_required' using errcode = '22023';
  end if;

  if p_storage_key is null or length(btrim(p_storage_key)) < 3 then
    raise exception 'evidence_storage_key_required' using errcode = '22023';
  end if;

  if p_file_name is null or length(btrim(p_file_name)) < 1 then
    raise exception 'evidence_file_name_required' using errcode = '22023';
  end if;

  if p_sha256 is not null and p_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'evidence_hash_invalid' using errcode = '22023';
  end if;

  if p_size_bytes is not null and p_size_bytes < 0 then
    raise exception 'evidence_size_invalid' using errcode = '22023';
  end if;

  if p_classification is not null
     and p_classification not in ('standard', 'sensitive', 'critical') then
    raise exception 'evidence_classification_invalid' using errcode = '22023';
  end if;

  if not exists (select 1 from admin.cases c where c.id = p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  if not admin.case_visible_to(p_actor_user_id, p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  insert into admin.case_evidence as e
    (case_id, storage_key, file_name, mime_type, size_bytes, sha256,
     classification, uploaded_by)
  values
    (p_case_id, btrim(p_storage_key), btrim(p_file_name),
     nullif(btrim(coalesce(p_mime_type, '')), ''), p_size_bytes,
     nullif(lower(p_sha256), ''),
     coalesce(nullif(p_classification, ''), 'sensitive'), p_actor_user_id)
  returning e.id into v_id;

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (p_case_id, 'evidence_added', p_actor_user_id,
          'Evidence added: ' || btrim(p_file_name));

  return query
    select e.id, e.file_name, e.mime_type, e.size_bytes, e.sha256,
           e.classification, e.status, e.supersedes_id,
           u.display_name, u.email, e.uploaded_at
      from admin.case_evidence e
      left join identity.users u on u.id = e.uploaded_by
     where e.id = v_id;
end;
$$;

revoke all on function admin.add_case_evidence(uuid, uuid, text, text, text, bigint, text, text, text) from public;
grant execute on function admin.add_case_evidence(uuid, uuid, text, text, text, bigint, text, text, text) to hivorr_api;

create or replace function admin.supersede_case_evidence(
  p_actor_user_id uuid,
  p_evidence_id uuid,
  p_replacement_id uuid,
  p_reason text
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
set search_path = ''
as $$
declare
  v_case_id uuid;
  v_replacement_case uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign') then
    raise exception 'case_work_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'case_reason_required' using errcode = '22023';
  end if;

  select e.case_id into v_case_id
    from admin.case_evidence e
   where e.id = p_evidence_id and e.status = 'active';

  if v_case_id is null then
    raise exception 'evidence_not_found' using errcode = 'P0002';
  end if;

  if not admin.case_visible_to(p_actor_user_id, v_case_id) then
    raise exception 'evidence_not_found' using errcode = 'P0002';
  end if;

  select e.case_id into v_replacement_case
    from admin.case_evidence e
   where e.id = p_replacement_id and e.status = 'active';

  if v_replacement_case is null or v_replacement_case <> v_case_id then
    raise exception 'evidence_replacement_invalid' using errcode = '22023';
  end if;

  if p_evidence_id = p_replacement_id then
    raise exception 'evidence_replacement_invalid' using errcode = '22023';
  end if;

  update admin.case_evidence e
     set status = 'superseded'
   where e.id = p_evidence_id;

  update admin.case_evidence e
     set supersedes_id = p_evidence_id
   where e.id = p_replacement_id;

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (v_case_id, 'evidence_superseded', p_actor_user_id,
          'Evidence superseded: ' || btrim(p_reason));

  return query
    select e.id, e.file_name, e.mime_type, e.size_bytes, e.sha256,
           e.classification, e.status, e.supersedes_id,
           u.display_name, u.email, e.uploaded_at
      from admin.case_evidence e
      left join identity.users u on u.id = e.uploaded_by
     where e.id = p_replacement_id;
end;
$$;

revoke all on function admin.supersede_case_evidence(uuid, uuid, uuid, text) from public;
grant execute on function admin.supersede_case_evidence(uuid, uuid, uuid, text) to hivorr_api;
