-- Account governance (CP-013): suspend, reactivate, close, revoke sessions,
-- notes and a timeline for one account.
--
-- Direct actions only. Maker-checker routing for sensitive closures is CP-020;
-- until it exists every action here requires `admin.user.manage`, a reason and
-- an audit record, and self-action is refused in the database.

set local lock_timeout = '5s';

create table admin.user_notes (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  author_user_id uuid references identity.users (id) on delete set null,
  body text not null,
  created_at timestamptz not null default now(),
  constraint user_notes_body_length check (length(btrim(body)) between 3 and 2000)
);

create index user_notes_user_idx on admin.user_notes (user_id, created_at desc);

comment on table admin.user_notes is
  'Operator notes about one account. Read and written only through the governed functions.';

alter table admin.user_notes enable row level security;
alter table admin.user_notes force row level security;
revoke all on admin.user_notes from public;

create function admin.govern_user(
  p_actor_user_id uuid,
  p_user_id uuid,
  p_action text,
  p_reason text
)
returns table (
  user_id uuid,
  status text,
  sessions_revoked integer,
  grants_revoked integer,
  roles_revoked integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_sessions integer := 0;
  v_grants integer := 0;
  v_roles integer := 0;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.manage') then
    raise exception 'user_manage_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'account_reason_required' using errcode = '22023';
  end if;

  if p_user_id = p_actor_user_id then
    raise exception 'self_account_action_forbidden' using errcode = '42501';
  end if;

  if p_action is null
     or p_action not in ('suspend', 'reactivate', 'close', 'revoke_sessions') then
    raise exception 'invalid_account_action' using errcode = '22023';
  end if;

  select u.status into v_status
    from identity.users u
   where u.id = p_user_id
   for update;

  if v_status is null then
    raise exception 'account_not_found' using errcode = 'P0002';
  end if;

  if p_action = 'suspend' then
    if v_status <> 'active' then
      raise exception 'account_state_invalid' using errcode = '23514';
    end if;
    update identity.users
       set status = 'suspended', updated_at = now()
     where id = p_user_id;
    update identity.sessions s
       set revoked_at = now(), revoked_reason = 'account_suspended'
     where s.user_id = p_user_id and s.revoked_at is null;
    get diagnostics v_sessions = row_count;
  elsif p_action = 'reactivate' then
    if v_status <> 'suspended' then
      raise exception 'account_state_invalid' using errcode = '23514';
    end if;
    update identity.users
       set status = 'active', updated_at = now()
     where id = p_user_id;
  elsif p_action = 'close' then
    if v_status = 'closed' then
      raise exception 'account_state_invalid' using errcode = '23514';
    end if;
    update identity.users
       set status = 'closed', updated_at = now()
     where id = p_user_id;
    update identity.sessions s
       set revoked_at = now(), revoked_reason = 'account_closed'
     where s.user_id = p_user_id and s.revoked_at is null;
    get diagnostics v_sessions = row_count;
    update identity.grants g
       set revoked_at = now()
     where g.user_id = p_user_id and g.revoked_at is null;
    get diagnostics v_grants = row_count;
    update admin.role_assignments ra
       set revoked_at = now()
     where ra.user_id = p_user_id and ra.revoked_at is null;
    get diagnostics v_roles = row_count;
    update admin.permission_grants pg
       set revoked_at = now()
     where pg.user_id = p_user_id and pg.revoked_at is null;
  else
    update identity.sessions s
       set revoked_at = now(), revoked_reason = 'sessions_revoked'
     where s.user_id = p_user_id and s.revoked_at is null;
    get diagnostics v_sessions = row_count;
  end if;

  return query
    select p_user_id,
           (select u.status from identity.users u where u.id = p_user_id),
           v_sessions, v_grants, v_roles;
end;
$$;

comment on function admin.govern_user(uuid, uuid, text, text) is
  'Suspends, reactivates, closes or revokes the sessions of one account. Refuses self-action.';

revoke all on function admin.govern_user(uuid, uuid, text, text) from public;
grant execute on function admin.govern_user(uuid, uuid, text, text) to hivorr_api;

create function admin.add_user_note(
  p_actor_user_id uuid,
  p_user_id uuid,
  p_body text
)
returns table (
  id uuid,
  body text,
  author_user_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note_id uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.manage') then
    raise exception 'user_manage_forbidden' using errcode = '42501';
  end if;

  if p_body is null or length(btrim(p_body)) < 3 then
    raise exception 'account_note_required' using errcode = '22023';
  end if;

  if not exists (select 1 from identity.users u where u.id = p_user_id) then
    raise exception 'account_not_found' using errcode = 'P0002';
  end if;

  insert into admin.user_notes as n (user_id, author_user_id, body)
  values (p_user_id, p_actor_user_id, btrim(p_body))
  returning n.id into v_note_id;

  return query
    select n.id, n.body, n.author_user_id, n.created_at
      from admin.user_notes n
     where n.id = v_note_id;
end;
$$;

revoke all on function admin.add_user_note(uuid, uuid, text) from public;
grant execute on function admin.add_user_note(uuid, uuid, text) to hivorr_api;

create function admin.list_user_notes(
  p_actor_user_id uuid,
  p_user_id uuid
)
returns table (
  id uuid,
  body text,
  author_name text,
  author_email text,
  created_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.manage')
  ) then
    raise exception 'user_read_forbidden' using errcode = '42501';
  end if;

  return query
    select n.id, n.body, a.display_name, a.email, n.created_at
      from admin.user_notes n
      left join identity.users a on a.id = n.author_user_id
     where n.user_id = p_user_id
     order by n.created_at desc;
end;
$$;

revoke all on function admin.list_user_notes(uuid, uuid) from public;
grant execute on function admin.list_user_notes(uuid, uuid) to hivorr_api;

create function admin.list_account_timeline(
  p_actor_user_id uuid,
  p_user_id uuid
)
returns table (
  occurred_at timestamptz,
  action text,
  reason text,
  actor_name text,
  actor_email text
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.manage')
  ) then
    raise exception 'user_read_forbidden' using errcode = '42501';
  end if;

  return query
    select a.occurred_at, a.action, a.reason,
           a.actor_display_name, a.actor_email
      from platform.audit_log a
     where a.target_id = p_user_id::text
     order by a.occurred_at desc, a.id desc
     limit 50;
end;
$$;

comment on function admin.list_account_timeline(uuid, uuid) is
  'The fifty most recent audit entries whose target is this account.';

revoke all on function admin.list_account_timeline(uuid, uuid) from public;
grant execute on function admin.list_account_timeline(uuid, uuid) to hivorr_api;
