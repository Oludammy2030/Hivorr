-- Typed dispute record (EP-02-036).
--
-- Disputes belong to the admin module, as the database rules and the schema
-- comment already state ("Admin roles, review queues, moderation, configuration,
-- audit access, disputes"). The record links a dispute case to the parties, the
-- activity record and an optional escrow reservation.
--
-- Deliberately absent: resolved, refunded, rejected and closed states. Those are
-- BD-D03 outcomes. The only statuses are procedural, and the only transitions are
-- between work states. No refund or release is triggered.
--
-- The table has no grants and no policies. Every read and write goes through the
-- permission-checked functions below, which is the same pattern as the rest of
-- the case spine. Evidence attaches to the case through CP-017; metadata is read
-- through `admin.list_case_evidence`, and an individual access is recorded by
-- `admin.record_evidence_access`. Signed object URLs remain `EP-02-012`.

set local lock_timeout = '5s';

create table admin.disputes (
  id uuid primary key default platform.uuidv7(),
  reference text not null unique,
  case_id uuid not null unique references admin.cases (id) on delete restrict,
  escrow_id uuid references finance.escrow_accounts (id) on delete restrict,
  activity_id text not null check (activity_id in (
    'market.buy',
    'services.hire',
    'errands.request',
    'market.sell',
    'services.offer',
    'logistics.provide'
  )),
  activity_ref uuid not null,
  opened_by_account_id uuid not null references identity.accounts (id) on delete restrict,
  respondent_account_id uuid references identity.accounts (id) on delete restrict,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  claimed_amount numeric(20, 4) not null check (claimed_amount > 0),
  status text not null default 'OPENED' check (status in (
    'OPENED',
    'UNDER_REVIEW',
    'AWAITING_EVIDENCE'
  )),
  opened_by_user_id uuid not null references identity.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    respondent_account_id is null
    or respondent_account_id <> opened_by_account_id
  )
);

comment on table admin.disputes is
  'Typed dispute detail behind an admin case. Procedural statuses only; outcomes are BD-D03.';

comment on column admin.disputes.status is
  'OPENED, UNDER_REVIEW or AWAITING_EVIDENCE. No resolved/closed state exists.';

create index disputes_activity_idx
  on admin.disputes (activity_id, activity_ref);
create index disputes_opened_by_idx
  on admin.disputes (opened_by_account_id, created_at);
create index disputes_respondent_idx
  on admin.disputes (respondent_account_id, created_at)
  where respondent_account_id is not null;
create index disputes_status_idx
  on admin.disputes (status, created_at);

alter table admin.disputes enable row level security;
alter table admin.disputes force row level security;
revoke all on admin.disputes from public;

create function admin.dispute_view(
  p_actor_user_id uuid,
  p_dispute_id uuid
)
returns table (
  id uuid,
  reference text,
  case_id uuid,
  case_reference text,
  case_status text,
  escrow_id uuid,
  activity_id text,
  activity_ref uuid,
  opened_by_account_id uuid,
  respondent_account_id uuid,
  currency text,
  claimed_amount numeric,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.dispute.resolve')
  ) then
    raise exception 'dispute_read_forbidden' using errcode = '42501';
  end if;

  return query
    select d.id, d.reference, d.case_id, c.reference, c.status, d.escrow_id,
           d.activity_id, d.activity_ref, d.opened_by_account_id,
           d.respondent_account_id, d.currency, d.claimed_amount::numeric,
           d.status, d.created_at, d.updated_at
      from admin.disputes d
      join admin.cases c on c.id = d.case_id
     where d.id = p_dispute_id;
end;
$$;

revoke all on function admin.dispute_view(uuid, uuid) from public;
grant execute on function admin.dispute_view(uuid, uuid) to hivorr_api;

create function admin.list_disputes(
  p_actor_user_id uuid,
  p_case_id uuid default null
)
returns table (
  id uuid,
  reference text,
  case_id uuid,
  case_reference text,
  case_status text,
  escrow_id uuid,
  activity_id text,
  activity_ref uuid,
  opened_by_account_id uuid,
  respondent_account_id uuid,
  currency text,
  claimed_amount numeric,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.dispute.resolve')
  ) then
    raise exception 'dispute_read_forbidden' using errcode = '42501';
  end if;

  return query
    select d.id, d.reference, d.case_id, c.reference, c.status, d.escrow_id,
           d.activity_id, d.activity_ref, d.opened_by_account_id,
           d.respondent_account_id, d.currency, d.claimed_amount::numeric,
           d.status, d.created_at, d.updated_at
      from admin.disputes d
      join admin.cases c on c.id = d.case_id
     where p_case_id is null or d.case_id = p_case_id
     order by d.created_at desc, d.id desc;
end;
$$;

revoke all on function admin.list_disputes(uuid, uuid) from public;
grant execute on function admin.list_disputes(uuid, uuid) to hivorr_api;

create function admin.open_dispute(
  p_actor_user_id uuid,
  p_case_id uuid,
  p_activity_id text,
  p_activity_ref uuid,
  p_opened_by_account_id uuid,
  p_respondent_account_id uuid,
  p_currency text,
  p_claimed_amount numeric,
  p_escrow_id uuid,
  p_reason text
)
returns table (
  id uuid,
  reference text,
  case_id uuid,
  case_reference text,
  case_status text,
  escrow_id uuid,
  activity_id text,
  activity_ref uuid,
  opened_by_account_id uuid,
  respondent_account_id uuid,
  currency text,
  claimed_amount numeric,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := platform.uuidv7();
  v_reference text :=
    'DSP-' || upper(substr(replace(platform.uuidv7()::text, '-', ''), 24, 9));
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.dispute.resolve')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign')
  ) then
    raise exception 'dispute_write_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'case_reason_required' using errcode = '22023';
  end if;

  if not exists (select 1 from admin.cases c where c.id = p_case_id) then
    raise exception 'case_not_found' using errcode = 'P0002';
  end if;

  if p_activity_id is null or p_activity_id not in (
    'market.buy', 'services.hire', 'errands.request',
    'market.sell', 'services.offer', 'logistics.provide'
  ) then
    raise exception 'dispute_activity_invalid' using errcode = '22023';
  end if;

  if p_currency is null or p_currency !~ '^[A-Z]{3}$' then
    raise exception 'dispute_currency_invalid' using errcode = '22023';
  end if;

  if p_claimed_amount is null
     or p_claimed_amount <= 0
     or p_claimed_amount >= 10000000000000000
     or p_claimed_amount <> round(p_claimed_amount, 4) then
    raise exception 'dispute_amount_invalid' using errcode = '22023';
  end if;

  insert into admin.disputes
    (id, reference, case_id, escrow_id, activity_id, activity_ref,
     opened_by_account_id, respondent_account_id, currency, claimed_amount,
     opened_by_user_id)
  values
    (v_id, v_reference, p_case_id, p_escrow_id, p_activity_id, p_activity_ref,
     p_opened_by_account_id, p_respondent_account_id, p_currency,
     p_claimed_amount, p_actor_user_id);

  insert into admin.case_events (case_id, event_type, actor_user_id, summary)
  values (p_case_id, 'dispute_opened', p_actor_user_id,
          'Dispute opened: ' || v_reference);

  return query select * from admin.dispute_view(p_actor_user_id, v_id);
end;
$$;

revoke all on function admin.open_dispute(
  uuid, uuid, text, uuid, uuid, uuid, text, numeric, uuid, text
) from public;
grant execute on function admin.open_dispute(
  uuid, uuid, text, uuid, uuid, uuid, text, numeric, uuid, text
) to hivorr_api;

create function admin.set_dispute_status(
  p_actor_user_id uuid,
  p_dispute_id uuid,
  p_status text,
  p_reason text
)
returns table (
  id uuid,
  reference text,
  case_id uuid,
  case_reference text,
  case_status text,
  escrow_id uuid,
  activity_id text,
  activity_ref uuid,
  opened_by_account_id uuid,
  respondent_account_id uuid,
  currency text,
  claimed_amount numeric,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case_id uuid;
  v_current text;
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.dispute.resolve')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign')
  ) then
    raise exception 'dispute_write_forbidden' using errcode = '42501';
  end if;

  if p_status is null or p_status not in (
    'OPENED', 'UNDER_REVIEW', 'AWAITING_EVIDENCE'
  ) then
    raise exception 'dispute_status_invalid' using errcode = '22023';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'case_reason_required' using errcode = '22023';
  end if;

  select d.case_id, d.status into v_case_id, v_current
    from admin.disputes d
   where d.id = p_dispute_id
   for update;

  if v_case_id is null then
    raise exception 'dispute_not_found' using errcode = 'P0002';
  end if;

  if v_current <> p_status and not (
    (v_current = 'OPENED' and p_status in ('UNDER_REVIEW', 'AWAITING_EVIDENCE'))
    or (v_current = 'UNDER_REVIEW' and p_status = 'AWAITING_EVIDENCE')
    or (v_current = 'AWAITING_EVIDENCE' and p_status = 'UNDER_REVIEW')
  ) then
    raise exception 'dispute_status_transition_invalid' using errcode = '22023';
  end if;

  if v_current <> p_status then
    update admin.disputes d
       set status = p_status,
           updated_at = now()
     where d.id = p_dispute_id;

    insert into admin.case_events (case_id, event_type, actor_user_id, summary)
    values (v_case_id, 'dispute_status_changed', p_actor_user_id,
            'Dispute ' || p_dispute_id || ': ' || v_current || ' -> ' || p_status);
  end if;

  return query select * from admin.dispute_view(p_actor_user_id, p_dispute_id);
end;
$$;

revoke all on function admin.set_dispute_status(uuid, uuid, text, text) from public;
grant execute on function admin.set_dispute_status(uuid, uuid, text, text) to hivorr_api;

-- Evidence access through a dispute. The evidence must belong to the dispute's
-- case; a mismatch is reported as not found, not as a confirmation. The access is
-- then recorded by the CP-017 function, which writes a case event. The signed
-- object URL is issued elsewhere (`EP-02-012`).
create function admin.record_dispute_evidence_access(
  p_actor_user_id uuid,
  p_dispute_id uuid,
  p_evidence_id uuid,
  p_purpose text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dispute_case uuid;
  v_evidence_case uuid;
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.case.assign')
  ) then
    raise exception 'dispute_read_forbidden' using errcode = '42501';
  end if;

  select d.case_id into v_dispute_case
    from admin.disputes d
   where d.id = p_dispute_id;

  if v_dispute_case is null then
    raise exception 'dispute_not_found' using errcode = 'P0002';
  end if;

  select e.case_id into v_evidence_case
    from admin.case_evidence e
   where e.id = p_evidence_id;

  if v_evidence_case is null or v_evidence_case <> v_dispute_case then
    raise exception 'evidence_not_found' using errcode = 'P0002';
  end if;

  perform admin.record_evidence_access(p_actor_user_id, p_evidence_id, p_purpose);
end;
$$;

revoke all on function admin.record_dispute_evidence_access(uuid, uuid, uuid, text) from public;
grant execute on function admin.record_dispute_evidence_access(uuid, uuid, uuid, text) to hivorr_api;
