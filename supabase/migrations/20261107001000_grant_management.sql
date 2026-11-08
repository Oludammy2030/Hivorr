-- Privileged grant management.
--
-- Grants are orthogonal to activities and never activate one. Only a caller
-- holding an active `admin.grant.manage` grant in the target environment may
-- create or revoke grants; only `admin.grant.read` or `admin.grant.manage` may
-- list them. Every function re-checks the actor inside the database, so the
-- service-layer check is defence in depth rather than the only control.
--
-- The first grant is deliberately not seeded by a migration. An operator
-- creates it out of band (see BACKEND_ENVIRONMENT_SETUP.md), which keeps a
-- founder identity out of the migration history and out of source control.

create or replace function identity.actor_has_grant(
  p_actor_user_id uuid,
  p_scope text,
  p_environment text
)
returns boolean
language sql
security definer
stable
set search_path = identity, pg_temp
as $$
  select exists (
    select 1 from identity.grants
    where user_id = p_actor_user_id
      and scope = p_scope
      and environment = p_environment
      and revoked_at is null
      and (expires_at is null or expires_at > now())
  )
$$;

revoke all on function identity.actor_has_grant(uuid, text, text) from public;

create or replace function identity.grant_scope_is_valid(
  p_grant_type text,
  p_scope text
)
returns boolean
language sql
immutable
as $$
  select case p_grant_type
    when 'admin' then p_scope in ('admin.audit.read', 'admin.grant.read', 'admin.grant.manage')
    when 'staff' then p_scope = 'staff.support.handle'
    when 'partner' then p_scope = 'partner.referral.read'
    when 'platform_engineering' then p_scope = 'platform.engineering'
    else false
  end
$$;

revoke all on function identity.grant_scope_is_valid(text, text) from public;
grant execute on function identity.grant_scope_is_valid(text, text) to hivorr_api;

create or replace function identity.list_grants(
  p_actor_user_id uuid,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  grant_type text,
  scope text,
  environment text,
  granted_by uuid,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = identity, pg_temp
as $$
begin
  if not (
    identity.actor_has_grant(p_actor_user_id, 'admin.grant.read', p_environment)
    or identity.actor_has_grant(p_actor_user_id, 'admin.grant.manage', p_environment)
  ) then
    raise exception 'grant_read_forbidden' using errcode = '42501';
  end if;

  return query
    select g.id, g.user_id, u.email, g.grant_type, g.scope, g.environment,
           g.granted_by, g.expires_at, g.revoked_at, g.created_at
    from identity.grants g
    join identity.users u on u.id = g.user_id
    where g.environment = p_environment
    order by g.created_at desc;
end;
$$;

revoke all on function identity.list_grants(uuid, text) from public;
grant execute on function identity.list_grants(uuid, text) to hivorr_api;

create or replace function identity.create_grant(
  p_actor_user_id uuid,
  p_email text,
  p_grant_type text,
  p_scope text,
  p_environment text,
  p_expires_at timestamptz
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  grant_type text,
  scope text,
  environment text,
  granted_by uuid,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = identity, pg_temp
as $$
declare
  v_user_id uuid;
  v_grant_id uuid;
begin
  if not identity.actor_has_grant(p_actor_user_id, 'admin.grant.manage', p_environment) then
    raise exception 'grant_manage_forbidden' using errcode = '42501';
  end if;

  if not identity.grant_scope_is_valid(p_grant_type, p_scope) then
    raise exception 'invalid_grant_scope' using errcode = '22023';
  end if;

  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'invalid_grant_expiry' using errcode = '22023';
  end if;

  select u.id into v_user_id
  from identity.users u
  where lower(u.email) = lower(p_email) and u.status <> 'closed'
  limit 1;

  if v_user_id is null then
    raise exception 'grant_user_not_found' using errcode = 'P0002';
  end if;

  insert into identity.grants
    (user_id, grant_type, scope, environment, granted_by, expires_at)
  values
    (v_user_id, p_grant_type, p_scope, p_environment, p_actor_user_id, p_expires_at)
  returning identity.grants.id into v_grant_id;

  return query
    select g.id, g.user_id, u.email, g.grant_type, g.scope, g.environment,
           g.granted_by, g.expires_at, g.revoked_at, g.created_at
    from identity.grants g
    join identity.users u on u.id = g.user_id
    where g.id = v_grant_id;
end;
$$;

revoke all on function identity.create_grant(uuid, text, text, text, text, timestamptz) from public;
grant execute on function identity.create_grant(uuid, text, text, text, text, timestamptz) to hivorr_api;

create or replace function identity.revoke_grant(
  p_actor_user_id uuid,
  p_grant_id uuid,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  grant_type text,
  scope text,
  environment text,
  granted_by uuid,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = identity, pg_temp
as $$
declare
  v_revoked_id uuid;
begin
  if not identity.actor_has_grant(p_actor_user_id, 'admin.grant.manage', p_environment) then
    raise exception 'grant_manage_forbidden' using errcode = '42501';
  end if;

  if exists (
    select 1 from identity.grants g
    where g.id = p_grant_id
      and g.scope = 'admin.grant.manage'
      and g.environment = p_environment
      and g.revoked_at is null
  ) and (
    select count(*) from identity.grants g
    where g.scope = 'admin.grant.manage'
      and g.environment = p_environment
      and g.revoked_at is null
      and (g.expires_at is null or g.expires_at > now())
  ) <= 1 then
    raise exception 'last_grant_manage' using errcode = '23514';
  end if;

  update identity.grants g
  set revoked_at = now()
  where g.id = p_grant_id
    and g.environment = p_environment
    and g.revoked_at is null
  returning g.id into v_revoked_id;

  if v_revoked_id is null then
    raise exception 'grant_not_found' using errcode = 'P0002';
  end if;

  return query
    select g.id, g.user_id, u.email, g.grant_type, g.scope, g.environment,
           g.granted_by, g.expires_at, g.revoked_at, g.created_at
    from identity.grants g
    join identity.users u on u.id = g.user_id
    where g.id = v_revoked_id;
end;
$$;

revoke all on function identity.revoke_grant(uuid, uuid, text) from public;
grant execute on function identity.revoke_grant(uuid, uuid, text) to hivorr_api;
