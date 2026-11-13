-- Verification review (CP-019): a queue over verification cases with a recorded
-- decision.
--
-- The review is bound to a case of type `verification_review`; evidence already
-- lives on that case. Approval requires at least one active evidence record so a
-- decision cannot be recorded without something to review.

set local lock_timeout = '5s';

create table admin.verification_reviews (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null unique references admin.cases (id) on delete cascade,
  lane text not null default 'identity'
    check (lane in ('identity', 'business', 'address', 'phone', 'document')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'information_requested')),
  decided_by uuid references identity.users (id) on delete set null,
  decided_at timestamptz,
  decision_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index verification_reviews_status_idx on admin.verification_reviews (status, created_at);

comment on table admin.verification_reviews is
  'Verification decision per review case. Evidence remains on the case.';

alter table admin.verification_reviews enable row level security;
alter table admin.verification_reviews force row level security;
revoke all on admin.verification_reviews from public;

create function admin.list_verification_queue(
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
           (select count(*) from admin.case_evidence e
             where e.case_id = c.id and e.status = 'active'),
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

create function admin.record_verification_decision(
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

  select c.case_type into v_case_type
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

  if p_decision = 'approve' and v_evidence = 0 then
    raise exception 'verification_evidence_required' using errcode = '23514';
  end if;

  select v.lane into v_lane
    from admin.verification_reviews v
   where v.case_id = p_case_id;

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
  elsif p_decision = 'reject' then
    v_review_status := 'rejected';
    v_case_status := 'DECIDED';
    v_outcome := 'verification_rejected';
  else
    v_review_status := 'information_requested';
    v_case_status := 'PENDING_INFORMATION';
    v_outcome := null;
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
