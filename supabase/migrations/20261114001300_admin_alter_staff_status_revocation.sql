-- Staff status revocation, completed (F-B-01, F-B-02).
--
-- Offboarding revoked identity grants and role assignments but not individual
-- permission grants, so a governance permission granted outside a role survived
-- the offboarding. It also had no self-change guard and no protection for the
-- last holder of the permissions that administer authority, unlike role
-- administration (CP-012) and account governance (CP-013).
--
-- Three rules are added here:
--   * offboarding revokes admin.permission_grants as well;
--   * an operator cannot change their own staff status, in either direction;
--   * suspending or offboarding the last platform holder of a governance
--     administration permission is refused, because it would remove the
--     authority needed to undo the change.
--
-- The return shape gains `permission_grants_revoked`, so the caller can report
-- what was actually withdrawn instead of folding it into an identity count.

set local lock_timeout = '5s';

drop function if exists admin.set_staff_status(uuid, text, text);

create function admin.set_staff_status(
  p_user_id uuid,
  p_status text,
  p_reason text
)
returns table (
  user_id uuid,
  engagement_status text,
  sessions_revoked bigint,
  grants_revoked bigint,
  permission_grants_revoked bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := platform.current_user_id();
  v_revoked_sessions bigint := 0;
  v_revoked_grants bigint := 0;
  v_revoked_permission_grants bigint := 0;
  v_permission text;
  v_target_holds boolean;
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

  if p_user_id = v_actor then
    raise exception 'self_staff_change_forbidden' using errcode = '42501';
  end if;

  -- Suspension and offboarding both withdraw authority. Neither may leave the
  -- portal without a platform holder of the permissions that administer it.
  if p_status in ('suspended', 'offboarded') then
    foreach v_permission in array array[
      'admin.user.manage',
      'admin.role.manage',
      'admin.grant.manage'
    ] loop
      v_target_holds := exists (
        select 1
          from admin.role_assignments ra
          join admin.role_permissions rp on rp.role_id = ra.role_id
         where ra.user_id = p_user_id
           and ra.scope_type = 'platform'
           and ra.revoked_at is null
           and (ra.expires_at is null or ra.expires_at > now())
           and rp.permission_key = v_permission
        union
        select 1
          from admin.permission_grants pg
         where pg.user_id = p_user_id
           and pg.scope_type = 'platform'
           and pg.revoked_at is null
           and (pg.expires_at is null or pg.expires_at > now())
           and pg.permission_key = v_permission
      );

      if v_target_holds
         and admin.platform_permission_holders(v_permission) <= 1 then
        raise exception 'last_staff_manager' using errcode = '23514';
      end if;
    end loop;
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

    -- Individual governance grants were the gap: a permission held outside a
    -- role outlived the offboarding.
    update admin.permission_grants pg
       set revoked_at = now()
     where pg.user_id = p_user_id
       and pg.revoked_at is null;
    get diagnostics v_revoked_permission_grants = row_count;

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
    select p_user_id, p_status, v_revoked_sessions, v_revoked_grants,
           v_revoked_permission_grants;
end;
$$;

comment on function admin.set_staff_status(uuid, text, text) is
  'Suspends, reactivates, sends on leave or offboards one staff member. Offboarding revokes sessions, identity grants, individual permission grants and role assignments. Refuses self-change and the last platform holder of a governance administration permission.';

revoke all on function admin.set_staff_status(uuid, text, text) from public;
grant execute on function admin.set_staff_status(uuid, text, text) to hivorr_api;
