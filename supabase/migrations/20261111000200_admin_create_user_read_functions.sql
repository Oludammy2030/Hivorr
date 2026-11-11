-- Governance platform-permission check and the scoped user directory read
-- (CP-004).
--
-- `identity.users` is protected by FORCE ROW LEVEL SECURITY scoped to the
-- caller's account. A platform directory cannot be produced by reading it under
-- the actor's own identity context. This function is the narrow, audited
-- exception: it checks a platform-scoped governance permission inside the
-- database, then returns the bounded directory fields the control portal needs.
--
-- Search path is empty and every name is schema-qualified, per the database
-- rules. Only hivorr_api may execute it.

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
         and (ad.expires_at is null or ad.expires_at > now())
    )
$$;

revoke all on function admin.actor_has_platform_permission(text) from public;
grant execute on function admin.actor_has_platform_permission(text) to hivorr_api;

create or replace function admin.list_users(
  p_query text,
  p_status text,
  p_before timestamptz,
  p_before_id uuid,
  p_limit integer
)
returns table (
  id uuid,
  account_id uuid,
  email text,
  display_name text,
  status text,
  email_verified_at timestamptz,
  created_at timestamptz,
  confirmed_factors bigint
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 101));
  v_query text := coalesce(p_query, '');
  v_status text := coalesce(p_status, '');
begin
  if not admin.actor_has_platform_permission('admin.user.read') then
    raise exception 'user_directory_forbidden' using errcode = '42501';
  end if;

  return query
    select u.id,
           u.account_id,
           u.email,
           u.display_name,
           u.status,
           u.email_verified_at,
           u.created_at,
           (select count(*)
              from identity.mfa_factors f
             where f.user_id = u.id
               and f.confirmed_at is not null) as confirmed_factors
      from identity.users u
     where (v_query = ''
            or u.email ilike '%' || v_query || '%'
            or coalesce(u.display_name, '') ilike '%' || v_query || '%')
       and (v_status = '' or u.status = v_status)
       and (p_before is null or (u.created_at, u.id) < (p_before, p_before_id))
     order by u.created_at desc, u.id desc
     limit v_limit;
end;
$$;

revoke all on function admin.list_users(text, text, timestamptz, uuid, integer) from public;
grant execute on function admin.list_users(text, text, timestamptz, uuid, integer) to hivorr_api;
