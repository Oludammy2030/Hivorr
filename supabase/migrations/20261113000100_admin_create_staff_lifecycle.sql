-- Staff lifecycle (CP-010, first slice).
--
-- Invitations are created from the control portal and accepted by the future
-- staff member on the main portal. Acceptance creates the identity account and
-- the staff profile in one transaction. Suspension and offboarding revoke
-- sessions immediately; offboarding also revokes grants, role assignments and
-- department membership.
--
-- The API role has no table privileges here: every read and write goes through
-- a SECURITY DEFINER function that re-checks the caller's platform permission
-- with `platform.current_user_id()`.

create table admin.staff_invites (
  id uuid primary key default platform.uuidv7(),
  email text not null,
  department_key text references admin.departments (key) on delete set null,
  job_title text,
  token_hash text not null unique,
  invited_by uuid references identity.users (id) on delete set null,
  reason text not null,
  expires_at timestamptz not null default now() + interval '7 days',
  consumed_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint staff_invites_reason_length check (length(trim(reason)) >= 5)
);

comment on table admin.staff_invites is
  'Single-use staff invitation. The token is stored only as a hash; acceptance creates the identity account and staff profile.';

create unique index staff_invites_pending_email
  on admin.staff_invites (lower(email))
  where consumed_at is null and revoked_at is null;

create index staff_invites_expiry_idx on admin.staff_invites (expires_at)
  where consumed_at is null and revoked_at is null;

alter table admin.staff_invites enable row level security;
alter table admin.staff_invites force row level security;
revoke all on admin.staff_invites from public;

-- ---------------------------------------------------------------------------
-- Staff directory
-- ---------------------------------------------------------------------------

create or replace function admin.list_staff(
  p_query text,
  p_status text,
  p_limit integer
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  job_title text,
  department_key text,
  department_name text,
  engagement_status text,
  started_on date,
  ended_on date,
  confirmed_factors bigint,
  created_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 200));
  v_query text := coalesce(p_query, '');
  v_status text := coalesce(p_status, '');
begin
  if not admin.actor_has_platform_permission('admin.user.read') then
    raise exception 'staff_directory_forbidden' using errcode = '42501';
  end if;

  return query
    select s.id,
           s.user_id,
           u.email,
           u.display_name,
           s.job_title,
           d.key,
           d.name,
           s.engagement_status,
           s.started_on,
           s.ended_on,
           (select count(*) from identity.mfa_factors f
             where f.user_id = u.id and f.confirmed_at is not null),
           s.created_at
      from admin.staff_profiles s
      join identity.users u on u.id = s.user_id
      left join admin.departments d on d.id = s.department_id
     where (v_query = ''
            or u.email ilike '%' || v_query || '%'
            or coalesce(u.display_name, '') ilike '%' || v_query || '%'
            or coalesce(s.job_title, '') ilike '%' || v_query || '%')
       and (v_status = '' or s.engagement_status = v_status)
     order by s.created_at desc, s.id desc
     limit v_limit;
end;
$$;

revoke all on function admin.list_staff(text, text, integer) from public;
grant execute on function admin.list_staff(text, text, integer) to hivorr_api;

-- ---------------------------------------------------------------------------
-- Invitations
-- ---------------------------------------------------------------------------

create or replace function admin.create_staff_invite(
  p_email text,
  p_department_key text,
  p_job_title text,
  p_token_hash text,
  p_reason text,
  p_expires_at timestamptz
)
returns table (
  id uuid,
  email text,
  department_key text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_id uuid;
begin
  if not admin.actor_has_platform_permission('admin.user.manage') then
    raise exception 'staff_invite_forbidden' using errcode = '42501';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'staff_invite_email_invalid' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) < 5 then
    raise exception 'staff_invite_reason_required' using errcode = '22023';
  end if;
  if p_department_key is not null and not exists (
    select 1 from admin.departments d
     where d.key = p_department_key and d.status = 'active'
  ) then
    raise exception 'staff_invite_department_invalid' using errcode = '22023';
  end if;
  if exists (
    select 1 from identity.users u where lower(u.email) = v_email
  ) then
    raise exception 'staff_invite_email_exists' using errcode = '23505';
  end if;

  insert into admin.staff_invites
    (email, department_key, job_title, token_hash, invited_by, reason, expires_at)
  values
    (v_email, p_department_key, nullif(trim(coalesce(p_job_title, '')), ''),
     p_token_hash, platform.current_user_id(), trim(p_reason),
     coalesce(p_expires_at, now() + interval '7 days'))
  returning admin.staff_invites.id into v_id;

  return query
    select i.id, i.email, i.department_key, i.expires_at
      from admin.staff_invites i
     where i.id = v_id;
end;
$$;

revoke all on function admin.create_staff_invite(text, text, text, text, text, timestamptz) from public;
grant execute on function admin.create_staff_invite(text, text, text, text, text, timestamptz) to hivorr_api;

create or replace function admin.accept_staff_invite(
  p_token_hash text,
  p_password_hash text,
  p_display_name text
)
returns table (
  user_id uuid,
  account_id uuid,
  staff_profile_id uuid,
  email text,
  department_key text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite admin.staff_invites%rowtype;
  v_user_id uuid := platform.uuidv7();
  v_account_id uuid := platform.uuidv7();
  v_profile_id uuid := platform.uuidv7();
begin
  select * into v_invite
    from admin.staff_invites i
   where i.token_hash = p_token_hash
     and i.consumed_at is null
     and i.revoked_at is null
     and i.expires_at > now()
   for update;

  if not found then
    raise exception 'staff_invite_invalid' using errcode = 'P0002';
  end if;
  if exists (
    select 1 from identity.users u where lower(u.email) = lower(v_invite.email)
  ) then
    raise exception 'staff_invite_email_exists' using errcode = '23505';
  end if;

  insert into identity.accounts (id) values (v_account_id);
  insert into identity.users (id, account_id, email, display_name)
  values (v_user_id, v_account_id, lower(v_invite.email),
          nullif(trim(coalesce(p_display_name, '')), ''));
  insert into identity.credentials (user_id, password_hash)
  values (v_user_id, p_password_hash);
  insert into identity.memberships (user_id, account_id, role)
  values (v_user_id, v_account_id, 'owner');

  insert into admin.staff_profiles
    (id, user_id, job_title, department_id, engagement_status, started_on)
  values (
    v_profile_id,
    v_user_id,
    v_invite.job_title,
    (select d.id from admin.departments d where d.key = v_invite.department_key),
    'active',
    current_date
  );

  if v_invite.department_key is not null then
    insert into admin.department_members
      (department_id, user_id, membership_role, created_by)
    values (
      (select d.id from admin.departments d where d.key = v_invite.department_key),
      v_user_id,
      'member',
      v_invite.invited_by
    );
  end if;

  update admin.staff_invites
     set consumed_at = now()
   where id = v_invite.id;

  return query
    select v_user_id, v_account_id, v_profile_id, lower(v_invite.email),
           v_invite.department_key;
end;
$$;

revoke all on function admin.accept_staff_invite(text, text, text) from public;
grant execute on function admin.accept_staff_invite(text, text, text) to hivorr_api;

-- ---------------------------------------------------------------------------
-- Status and department changes
-- ---------------------------------------------------------------------------

create or replace function admin.set_staff_status(
  p_user_id uuid,
  p_status text,
  p_reason text
)
returns table (
  user_id uuid,
  engagement_status text,
  sessions_revoked bigint,
  grants_revoked bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_revoked_sessions bigint := 0;
  v_revoked_grants bigint := 0;
begin
  if not admin.actor_has_platform_permission('admin.user.manage') then
    raise exception 'staff_status_forbidden' using errcode = '42501';
  end if;
  if p_status not in ('active', 'suspended', 'leave', 'offboarded') then
    raise exception 'staff_status_invalid' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) < 5 then
    raise exception 'staff_status_reason_required' using errcode = '22023';
  end if;
  if not exists (
    select 1 from admin.staff_profiles s where s.user_id = p_user_id
  ) then
    raise exception 'staff_not_found' using errcode = 'P0002';
  end if;

  update admin.staff_profiles s
     set engagement_status = p_status,
         ended_on = case when p_status = 'offboarded' then current_date else s.ended_on end
   where s.user_id = p_user_id;

  if p_status in ('suspended', 'offboarded') then
    update identity.sessions sess
       set revoked_at = now(),
           revoked_reason = 'staff_' || p_status
     where sess.user_id = p_user_id
       and sess.revoked_at is null;
    get diagnostics v_revoked_sessions = row_count;
  end if;

  if p_status = 'offboarded' then
    update identity.grants g
       set revoked_at = now()
     where g.user_id = p_user_id
       and g.revoked_at is null;
    get diagnostics v_revoked_grants = row_count;

    update admin.role_assignments ra
       set revoked_at = now()
     where ra.user_id = p_user_id
       and ra.revoked_at is null;

    update admin.department_members dm
       set effective_to = now()
     where dm.user_id = p_user_id
       and dm.effective_to is null;
  end if;

  return query
    select p_user_id, p_status, v_revoked_sessions, v_revoked_grants;
end;
$$;

revoke all on function admin.set_staff_status(uuid, text, text) from public;
grant execute on function admin.set_staff_status(uuid, text, text) to hivorr_api;

create or replace function admin.set_staff_department(
  p_user_id uuid,
  p_department_key text,
  p_reason text
)
returns table (
  user_id uuid,
  department_key text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_department_id uuid;
begin
  if not admin.actor_has_platform_permission('admin.user.manage') then
    raise exception 'staff_department_forbidden' using errcode = '42501';
  end if;
  if p_reason is null or length(trim(p_reason)) < 5 then
    raise exception 'staff_department_reason_required' using errcode = '22023';
  end if;
  if p_department_key is not null then
    select d.id into v_department_id
      from admin.departments d
     where d.key = p_department_key and d.status = 'active';
    if v_department_id is null then
      raise exception 'staff_department_invalid' using errcode = '22023';
    end if;
  end if;

  update admin.staff_profiles s
     set department_id = v_department_id
   where s.user_id = p_user_id;
  if not found then
    raise exception 'staff_not_found' using errcode = 'P0002';
  end if;

  update admin.department_members dm
     set effective_to = now()
   where dm.user_id = p_user_id and dm.effective_to is null;

  if v_department_id is not null then
    insert into admin.department_members
      (department_id, user_id, membership_role, created_by)
    values (v_department_id, p_user_id, 'member', platform.current_user_id());
  end if;

  return query select p_user_id, p_department_key;
end;
$$;

revoke all on function admin.set_staff_department(uuid, text, text) from public;
grant execute on function admin.set_staff_department(uuid, text, text) to hivorr_api;
