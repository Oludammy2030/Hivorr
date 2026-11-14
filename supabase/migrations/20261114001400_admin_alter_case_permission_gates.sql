-- Case permission gates corrected (F-C-02, F-C-03).
--
-- Two functions checked the wrong permission, so a role could exercise an
-- authority it was never granted, and the permission that names the action
-- authorised nothing:
--
--   * evidence was readable with `admin.case.read`, so the support and
--     operations roles could read evidence metadata although
--     `admin.evidence.read` — critical sensitivity — had deliberately not been
--     granted to them;
--   * requesting a case decision was gated by `admin.case.assign`, although the
--     request carries the outcome and is therefore the recommendation that
--     `admin.case.recommend` names.
--
-- Signatures are unchanged; only the gate inside each function moves.

set local lock_timeout = '5s';

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

comment on function admin.list_case_evidence(uuid, uuid) is
  'Evidence metadata for one case. Requires admin.evidence.read, not admin.case.read.';

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

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (v_case_id, 'evidence_accessed', p_actor_user_id,
          'Evidence accessed: ' || v_file_name ||
          coalesce(' (' || nullif(btrim(p_purpose), '') || ')', ''));
end;
$$;

revoke all on function admin.record_evidence_access(uuid, uuid, text) from public;
grant execute on function admin.record_evidence_access(uuid, uuid, text) to hivorr_api;

create or replace function admin.request_case_decision(
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
  -- The request carries the outcome, so it is a recommendation. Assignment is
  -- not the authority to recommend.
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.recommend') then
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

comment on function admin.request_case_decision(uuid, uuid, text, text) is
  'Request a case decision. Requires admin.case.recommend, because the request carries the outcome.';

revoke all on function admin.request_case_decision(uuid, uuid, text, text) from public;
grant execute on function admin.request_case_decision(uuid, uuid, text, text) to hivorr_api;
