-- Case evidence metadata (CP-017).
--
-- The binary object lives in private R2 storage; this database row carries the
-- integrity hash and metadata. Originals are immutable: a correction records a
-- supersede link and marks the old row superseded. Every read is recorded on
-- the case timeline.

set local lock_timeout = '5s';

create function admin.list_case_evidence(
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
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign')
  ) then
    raise exception 'case_read_forbidden' using errcode = '42501';
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

create function admin.add_case_evidence(
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

create function admin.supersede_case_evidence(
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

create function admin.record_evidence_access(
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
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign')
  ) then
    raise exception 'case_read_forbidden' using errcode = '42501';
  end if;

  select e.case_id, e.file_name into v_case_id, v_file_name
    from admin.case_evidence e
   where e.id = p_evidence_id;

  if v_case_id is null then
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
