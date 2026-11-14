-- Access denials (F-A-02): the negative of a role assignment.
--
-- A denial removes one governance permission from one person, in one scope,
-- until it expires or an operator revokes it. It is never deleted: revocation
-- records who removed it, when and why, so the row and the audit trail agree.
--
-- Two rules are enforced in the database rather than the client:
--   * an operator cannot deny or un-deny their own authority, in either
--     direction, because revoking a denial against yourself is self-elevation;
--   * a platform denial cannot remove the last platform holder of a governance
--     administration permission, which would lock the portal out of its own
--     administration.
--
-- Denials cover governance permissions only. The identity grant scopes
-- (staff.support.handle, partner.referral.read, platform.engineering) are not
-- admin permissions and are removed by revoking the grant.

set local lock_timeout = '5s';

alter table admin.access_denials
  add column created_by uuid references identity.users (id) on delete set null,
  add column revoked_at timestamptz,
  add column revoked_by uuid references identity.users (id) on delete set null,
  add column revoked_reason text;

alter table admin.access_denials
  add constraint access_denials_revocation_shape check (
    (revoked_at is null and revoked_by is null and revoked_reason is null)
    or (revoked_at is not null and revoked_reason is not null)
  );

comment on column admin.access_denials.created_by is
  'The operator who recorded the denial.';
comment on column admin.access_denials.revoked_at is
  'When the denial stopped applying. A revoked denial is kept for history.';
comment on column admin.access_denials.revoked_reason is
  'Why the denial was lifted. Required once revoked_at is set.';

-- One active denial per person, permission and scope. A revoked row does not
-- block a later denial for the same target.
create unique index access_denials_active_unique
  on admin.access_denials (
    user_id,
    permission_key,
    coalesce(scope_type, ''),
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where revoked_at is null;

-- Every active-denial lookup honours revocation and expiry from now on.
drop index if exists access_denials_user_idx;
create index access_denials_user_active_idx
  on admin.access_denials (user_id, permission_key)
  where revoked_at is null;

-- Both permission checks must ignore a revoked denial, or a lifted denial would
-- keep denying authority.
create or replace function admin.actor_has_platform_permission(
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
         where ra.user_id = platform.current_user_id()
           and ra.scope_type = 'platform'
           and ra.revoked_at is null
           and (ra.expires_at is null or ra.expires_at > now())
           and rp.permission_key = p_permission
      )
      or exists (
        select 1
          from admin.permission_grants pg
         where pg.user_id = platform.current_user_id()
           and pg.scope_type = 'platform'
           and pg.revoked_at is null
           and (pg.expires_at is null or pg.expires_at > now())
           and pg.permission_key = p_permission
      )
    )
    and not exists (
      select 1
        from admin.access_denials ad
       where ad.user_id = platform.current_user_id()
         and ad.permission_key = p_permission
         and (ad.scope_type is null or ad.scope_type = 'platform')
         and ad.revoked_at is null
         and (ad.expires_at is null or ad.expires_at > now())
    )
$$;

create or replace function admin.actor_holds_platform_permission(
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
         and ad.revoked_at is null
         and (ad.expires_at is null or ad.expires_at > now())
    )
$$;

-- The read model: every denial with its target, scope and lifecycle.
create function admin.list_access_denials(
  p_actor_user_id uuid,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  permission_key text,
  scope_type text,
  scope_id uuid,
  reason text,
  expires_at timestamptz,
  created_at timestamptz,
  created_by uuid,
  revoked_at timestamptz,
  revoked_reason text
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
    raise exception 'denial_read_forbidden' using errcode = '42501';
  end if;

  return query
    select ad.id, ad.user_id, u.email, u.display_name, ad.permission_key,
           ad.scope_type, ad.scope_id, ad.reason, ad.expires_at, ad.created_at,
           ad.created_by, ad.revoked_at, ad.revoked_reason
      from admin.access_denials ad
      join identity.users u on u.id = ad.user_id
     order by (ad.revoked_at is null) desc, ad.created_at desc, ad.id desc;
end;
$$;

comment on function admin.list_access_denials(uuid, text) is
  'Every access denial with its target, scope, reason and lifecycle fields.';

revoke all on function admin.list_access_denials(uuid, text) from public;
grant execute on function admin.list_access_denials(uuid, text) to hivorr_api;

-- The number of people who hold a permission at platform scope and are not
-- already denied it. Used by the lockout guard.
create function admin.platform_permission_holders(
  p_permission text
)
returns integer
language sql
security definer
stable
set search_path = ''
as $$
  select count(*)
    from (
      select ra.user_id as user_id
        from admin.role_assignments ra
        join admin.role_permissions rp on rp.role_id = ra.role_id
       where ra.scope_type = 'platform'
         and ra.revoked_at is null
         and (ra.expires_at is null or ra.expires_at > now())
         and rp.permission_key = p_permission
      union
      select pg.user_id
        from admin.permission_grants pg
       where pg.scope_type = 'platform'
         and pg.revoked_at is null
         and (pg.expires_at is null or pg.expires_at > now())
         and pg.permission_key = p_permission
    ) holders
   where not exists (
     select 1
       from admin.access_denials ad
      where ad.user_id = holders.user_id
        and ad.permission_key = p_permission
        and (ad.scope_type is null or ad.scope_type = 'platform')
        and ad.revoked_at is null
        and (ad.expires_at is null or ad.expires_at > now())
   )
$$;

revoke all on function admin.platform_permission_holders(text) from public;

create function admin.create_access_denial(
  p_actor_user_id uuid,
  p_user_email text,
  p_permission_key text,
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
  permission_key text,
  scope_type text,
  scope_id uuid,
  reason text,
  expires_at timestamptz,
  created_at timestamptz,
  created_by uuid,
  revoked_at timestamptz,
  revoked_reason text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_denial_id uuid;
  v_target_holds boolean;
  v_holders integer;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.manage') then
    raise exception 'denial_manage_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 3 then
    raise exception 'denial_reason_required' using errcode = '22023';
  end if;

  if p_scope_type is null or p_scope_type not in ('platform', 'department', 'organisation') then
    raise exception 'invalid_denial_scope' using errcode = '22023';
  end if;

  if (p_scope_type = 'platform' and p_scope_id is not null)
     or (p_scope_type <> 'platform' and p_scope_id is null) then
    raise exception 'invalid_denial_scope' using errcode = '22023';
  end if;

  if p_expires_at is not null and p_expires_at <= now() then
    raise exception 'invalid_denial_expiry' using errcode = '22023';
  end if;

  if not exists (select 1 from admin.permissions p where p.key = p_permission_key) then
    raise exception 'denial_permission_not_found' using errcode = 'P0002';
  end if;

  if p_scope_type = 'department' and not exists (
    select 1 from admin.departments d
     where d.id = p_scope_id and d.status = 'active'
  ) then
    raise exception 'invalid_denial_scope' using errcode = '22023';
  end if;

  if p_scope_type = 'organisation' and not exists (
    select 1 from admin.partner_organisations o
     where o.id = p_scope_id and o.status in ('applicant', 'active')
  ) then
    raise exception 'invalid_denial_scope' using errcode = '22023';
  end if;

  select u.id into v_user_id
    from identity.users u
   where lower(u.email) = lower(p_user_email)
     and u.status <> 'closed'
   limit 1;

  if v_user_id is null then
    raise exception 'denial_user_not_found' using errcode = 'P0002';
  end if;

  -- Denying yourself is a self-change; un-denying yourself would be elevation,
  -- which is refused by revoke_access_denial for the same reason.
  if v_user_id = p_actor_user_id then
    raise exception 'self_denial_forbidden' using errcode = '42501';
  end if;

  -- A platform denial must not empty the last seat of the permissions that
  -- administer authority itself.
  if p_scope_type = 'platform'
     and p_permission_key in ('admin.role.manage', 'admin.grant.manage') then
    v_holders := admin.platform_permission_holders(p_permission_key);
    v_target_holds := exists (
      select 1
        from admin.role_assignments ra
        join admin.role_permissions rp on rp.role_id = ra.role_id
       where ra.user_id = v_user_id
         and ra.scope_type = 'platform'
         and ra.revoked_at is null
         and (ra.expires_at is null or ra.expires_at > now())
         and rp.permission_key = p_permission_key
      union
      select 1
        from admin.permission_grants pg
       where pg.user_id = v_user_id
         and pg.scope_type = 'platform'
         and pg.revoked_at is null
         and (pg.expires_at is null or pg.expires_at > now())
         and pg.permission_key = p_permission_key
    );
    if v_target_holds and v_holders <= 1 then
      raise exception 'last_permission_holder' using errcode = '23514';
    end if;
  end if;

  insert into admin.access_denials as ad
    (user_id, permission_key, scope_type, scope_id, reason, expires_at, created_by)
  values
    (v_user_id, p_permission_key, p_scope_type, p_scope_id, btrim(p_reason),
     p_expires_at, p_actor_user_id)
  returning ad.id into v_denial_id;

  return query
    select ad.id, ad.user_id, u.email, u.display_name, ad.permission_key,
           ad.scope_type, ad.scope_id, ad.reason, ad.expires_at, ad.created_at,
           ad.created_by, ad.revoked_at, ad.revoked_reason
      from admin.access_denials ad
      join identity.users u on u.id = ad.user_id
     where ad.id = v_denial_id;
end;
$$;

comment on function admin.create_access_denial(uuid, text, text, text, uuid, timestamptz, text, text) is
  'Deny a governance permission for one person in one scope. Refuses self-change and removal of the last platform administrator.';

revoke all on function admin.create_access_denial(uuid, text, text, text, uuid, timestamptz, text, text) from public;
grant execute on function admin.create_access_denial(uuid, text, text, text, uuid, timestamptz, text, text) to hivorr_api;

create function admin.revoke_access_denial(
  p_actor_user_id uuid,
  p_denial_id uuid,
  p_reason text,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  permission_key text,
  scope_type text,
  scope_id uuid,
  reason text,
  expires_at timestamptz,
  created_at timestamptz,
  created_by uuid,
  revoked_at timestamptz,
  revoked_reason text
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
    raise exception 'denial_manage_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 3 then
    raise exception 'denial_reason_required' using errcode = '22023';
  end if;

  select ad.user_id into v_user_id
    from admin.access_denials ad
   where ad.id = p_denial_id
     and ad.revoked_at is null;

  if v_user_id is null then
    raise exception 'denial_not_found' using errcode = 'P0002';
  end if;

  -- Lifting a denial against yourself restores your own authority. Refuse it.
  if v_user_id = p_actor_user_id then
    raise exception 'self_denial_forbidden' using errcode = '42501';
  end if;

  update admin.access_denials ad
     set revoked_at = now(),
         revoked_by = p_actor_user_id,
         revoked_reason = btrim(p_reason)
   where ad.id = p_denial_id
   returning ad.id into v_revoked_id;

  return query
    select ad.id, ad.user_id, u.email, u.display_name, ad.permission_key,
           ad.scope_type, ad.scope_id, ad.reason, ad.expires_at, ad.created_at,
           ad.created_by, ad.revoked_at, ad.revoked_reason
      from admin.access_denials ad
      join identity.users u on u.id = ad.user_id
     where ad.id = v_revoked_id;
end;
$$;

comment on function admin.revoke_access_denial(uuid, uuid, text, text) is
  'Lift an access denial, recording who lifted it and why. Refuses self-change.';

revoke all on function admin.revoke_access_denial(uuid, uuid, text, text) from public;
grant execute on function admin.revoke_access_denial(uuid, uuid, text, text) to hivorr_api;
