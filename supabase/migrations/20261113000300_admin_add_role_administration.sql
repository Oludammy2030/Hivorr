-- Role administration (CP-012): read the catalogue, assign a seeded role and
-- revoke an assignment.
--
-- Roles are collections of permissions; an assignment carries a scope and an
-- optional expiry. Custom roles are deliberately not supported yet: the seeded
-- catalogue is the reviewed surface.
--
-- Two rules are enforced in the database rather than the client:
--   * an administrator cannot change their own assignments (privilege
--     self-escalation), and
--   * the last active holder of admin.role.manage cannot be removed.

set local lock_timeout = '5s';

-- Platform-scoped permission check for one actor id. Mirrors
-- admin.actor_has_platform_permission, which depends on request context.
create function admin.actor_holds_platform_permission(
  p_actor_user_id uuid,
  p_permission text
)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select
    (
      exists (
        select 1
          from admin.role_assignments ra
          join admin.role_permissions rp on rp.role_id = ra.role_id
         where ra.user_id = p_actor_user_id
           and ra.scope_type = 'platform'
           and ra.revoked_at is null
           and (ra.expires_at is null or ra.expires_at > now())
           and rp.permission_key = p_permission
      )
      or exists (
        select 1
          from admin.permission_grants pg
         where pg.user_id = p_actor_user_id
           and pg.scope_type = 'platform'
           and pg.revoked_at is null
           and (pg.expires_at is null or pg.expires_at > now())
           and pg.permission_key = p_permission
      )
    )
    and not exists (
      select 1
        from admin.access_denials ad
       where ad.user_id = p_actor_user_id
         and ad.permission_key = p_permission
         and (ad.scope_type is null or ad.scope_type = 'platform')
         and (ad.expires_at is null or ad.expires_at > now())
    )
$$;

comment on function admin.actor_holds_platform_permission(uuid, text) is
  'True when the actor holds a permission at platform scope and no platform denial removes it.';

revoke all on function admin.actor_holds_platform_permission(uuid, text) from public;
grant execute on function admin.actor_holds_platform_permission(uuid, text) to hivorr_api;

create function admin.list_roles(
  p_actor_user_id uuid,
  p_environment text
)
returns table (
  key text,
  name text,
  description text,
  system boolean,
  permissions text[],
  active_assignments bigint
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.manage')
  ) then
    raise exception 'role_read_forbidden' using errcode = '42501';
  end if;

  return query
    select r.key,
           r.name,
           r.description,
           r.system,
           coalesce(
             (
               select array_agg(rp.permission_key order by rp.permission_key)
                 from admin.role_permissions rp
                where rp.role_id = r.id
             ),
             '{}'::text[]
           ),
           (
             select count(*)
               from admin.role_assignments ra
              where ra.role_id = r.id
                and ra.revoked_at is null
                and (ra.expires_at is null or ra.expires_at > now())
           )
      from admin.roles r
     order by r.name;
end;
$$;

comment on function admin.list_roles(uuid, text) is
  'The governance role catalogue with its permission keys and active assignment count.';

revoke all on function admin.list_roles(uuid, text) from public;
grant execute on function admin.list_roles(uuid, text) to hivorr_api;

create function admin.list_role_assignments(
  p_actor_user_id uuid,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  role_key text,
  role_name text,
  scope_type text,
  scope_id uuid,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz,
  granted_by uuid,
  reason text
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.manage')
  ) then
    raise exception 'role_read_forbidden' using errcode = '42501';
  end if;

  return query
    select ra.id, ra.user_id, u.email, u.display_name, r.key, r.name,
           ra.scope_type, ra.scope_id, ra.expires_at, ra.revoked_at,
           ra.created_at, ra.granted_by, ra.reason
      from admin.role_assignments ra
      join admin.roles r on r.id = ra.role_id
      join identity.users u on u.id = ra.user_id
     order by (ra.revoked_at is null) desc, ra.created_at desc, ra.id desc;
end;
$$;

comment on function admin.list_role_assignments(uuid, text) is
  'Every role assignment with the holder, the role, the scope and its lifecycle fields.';

revoke all on function admin.list_role_assignments(uuid, text) from public;
grant execute on function admin.list_role_assignments(uuid, text) to hivorr_api;

create function admin.assign_role(
  p_actor_user_id uuid,
  p_user_email text,
  p_role_key text,
  p_scope_type text,
  p_scope_id uuid,
  p_expires_at timestamptz,
  p_reason text,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  role_key text,
  role_name text,
  scope_type text,
  scope_id uuid,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz,
  granted_by uuid,
  reason text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_role_id uuid;
  v_assignment_id uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.manage') then
    raise exception 'role_manage_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 3 then
    raise exception 'role_reason_required' using errcode = '22023';
  end if;

  if p_scope_type is null or p_scope_type not in ('platform', 'department', 'organisation') then
    raise exception 'invalid_role_scope' using errcode = '22023';
  end if;

  if (p_scope_type = 'platform' and p_scope_id is not null)
     or (p_scope_type <> 'platform' and p_scope_id is null) then
    raise exception 'invalid_role_scope' using errcode = '22023';
  end if;

  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'invalid_role_expiry' using errcode = '22023';
  end if;

  if p_scope_type = 'department' and not exists (
    select 1 from admin.departments d
     where d.id = p_scope_id and d.status = 'active'
  ) then
    raise exception 'invalid_role_scope' using errcode = '22023';
  end if;

  if p_scope_type = 'organisation' and not exists (
    select 1 from admin.partner_organisations o
     where o.id = p_scope_id and o.status in ('applicant', 'active')
  ) then
    raise exception 'invalid_role_scope' using errcode = '22023';
  end if;

  select u.id into v_user_id
    from identity.users u
   where lower(u.email) = lower(p_user_email)
     and u.status <> 'closed'
   limit 1;

  if v_user_id is null then
    raise exception 'role_user_not_found' using errcode = 'P0002';
  end if;

  if v_user_id = p_actor_user_id then
    raise exception 'self_role_change_forbidden' using errcode = '42501';
  end if;

  select r.id into v_role_id
    from admin.roles r
   where r.key = p_role_key
   limit 1;

  if v_role_id is null then
    raise exception 'role_not_found' using errcode = 'P0002';
  end if;

  insert into admin.role_assignments as ra
    (user_id, role_id, scope_type, scope_id, granted_by, reason, expires_at)
  values
    (v_user_id, v_role_id, p_scope_type, p_scope_id, p_actor_user_id,
     btrim(p_reason), p_expires_at)
  returning ra.id into v_assignment_id;

  return query
    select ra.id, ra.user_id, u.email, u.display_name, r.key, r.name,
           ra.scope_type, ra.scope_id, ra.expires_at, ra.revoked_at,
           ra.created_at, ra.granted_by, ra.reason
      from admin.role_assignments ra
      join admin.roles r on r.id = ra.role_id
      join identity.users u on u.id = ra.user_id
     where ra.id = v_assignment_id;
end;
$$;

comment on function admin.assign_role(uuid, text, text, text, uuid, timestamptz, text, text) is
  'Assign a seeded role at platform, department or organisation scope. Refuses self-assignment.';

revoke all on function admin.assign_role(uuid, text, text, text, uuid, timestamptz, text, text) from public;
grant execute on function admin.assign_role(uuid, text, text, text, uuid, timestamptz, text, text) to hivorr_api;

create function admin.revoke_role(
  p_actor_user_id uuid,
  p_assignment_id uuid,
  p_reason text,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  role_key text,
  role_name text,
  scope_type text,
  scope_id uuid,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz,
  granted_by uuid,
  reason text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_revoked_id uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.manage') then
    raise exception 'role_manage_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 3 then
    raise exception 'role_reason_required' using errcode = '22023';
  end if;

  select ra.user_id into v_user_id
    from admin.role_assignments ra
   where ra.id = p_assignment_id
     and ra.revoked_at is null;

  if v_user_id is null then
    raise exception 'role_assignment_not_found' using errcode = 'P0002';
  end if;

  if v_user_id = p_actor_user_id then
    raise exception 'self_role_change_forbidden' using errcode = '42501';
  end if;

  if exists (
    select 1
      from admin.role_assignments ra
      join admin.role_permissions rp on rp.role_id = ra.role_id
     where ra.id = p_assignment_id
       and rp.permission_key = 'admin.role.manage'
  ) and not exists (
    select 1
      from admin.role_assignments ra
      join admin.role_permissions rp on rp.role_id = ra.role_id
     where ra.id <> p_assignment_id
       and ra.revoked_at is null
       and (ra.expires_at is null or ra.expires_at > now())
       and rp.permission_key = 'admin.role.manage'
  ) and not exists (
    select 1
      from admin.permission_grants pg
     where pg.revoked_at is null
       and (pg.expires_at is null or pg.expires_at > now())
       and pg.permission_key = 'admin.role.manage'
  ) then
    raise exception 'last_role_manager' using errcode = '23514';
  end if;

  update admin.role_assignments ra
     set revoked_at = now()
   where ra.id = p_assignment_id
  returning ra.id into v_revoked_id;

  return query
    select ra.id, ra.user_id, u.email, u.display_name, r.key, r.name,
           ra.scope_type, ra.scope_id, ra.expires_at, ra.revoked_at,
           ra.created_at, ra.granted_by, ra.reason
      from admin.role_assignments ra
      join admin.roles r on r.id = ra.role_id
      join identity.users u on u.id = ra.user_id
     where ra.id = p_assignment_id;
end;
$$;

comment on function admin.revoke_role(uuid, uuid, text, text) is
  'Revoke a role assignment. Refuses self-revocation and removal of the last role manager.';

revoke all on function admin.revoke_role(uuid, uuid, text, text) from public;
grant execute on function admin.revoke_role(uuid, uuid, text, text) to hivorr_api;

-- Scope targets for the assignment form. Departments and partner
-- organisations are listed from their owning tables rather than trusted from
-- the request, so an assignment can only point at a real active target.
create function admin.list_role_scope_targets(
  p_actor_user_id uuid,
  p_scope_type text
)
returns table (
  id uuid,
  name text
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.manage')
  ) then
    raise exception 'role_read_forbidden' using errcode = '42501';
  end if;

  if p_scope_type = 'department' then
    return query
      select d.id, d.name
        from admin.departments d
       where d.status = 'active'
       order by d.name;
  elsif p_scope_type = 'organisation' then
    return query
      select o.id, coalesce(o.trading_name, o.legal_name)
        from admin.partner_organisations o
       where o.status in ('applicant', 'active')
       order by coalesce(o.trading_name, o.legal_name);
  else
    raise exception 'invalid_role_scope' using errcode = '22023';
  end if;
end;
$$;

comment on function admin.list_role_scope_targets(uuid, text) is
  'Active departments or partner organisations that a role assignment may target.';

revoke all on function admin.list_role_scope_targets(uuid, text) from public;
grant execute on function admin.list_role_scope_targets(uuid, text) to hivorr_api;
