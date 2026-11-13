-- Assignable staff for the role picker (CP-012 follow-up).
--
-- A governance role should go to a person who has actually joined the
-- organisation, not to an arbitrary account typed into a field. This read model
-- lists only staff profiles with an active engagement and an active account.
--
-- It is gated by admin.role.manage rather than admin.user.read so a role manager
-- does not gain the wider staff directory by accident.

set local lock_timeout = '5s';

create function admin.list_assignable_staff(
  p_actor_user_id uuid
)
returns table (
  user_id uuid,
  email text,
  display_name text,
  department_key text,
  department_name text
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.role.manage') then
    raise exception 'role_manage_forbidden' using errcode = '42501';
  end if;

  return query
    select u.id, u.email, u.display_name, d.key, d.name
      from admin.staff_profiles s
      join identity.users u on u.id = s.user_id
      left join admin.departments d on d.id = s.department_id
     where s.engagement_status = 'active'
       and u.status = 'active'
     order by coalesce(u.display_name, u.email);
end;
$$;

comment on function admin.list_assignable_staff(uuid) is
  'Active staff an administrator may assign a governance role to.';

revoke all on function admin.list_assignable_staff(uuid) from public;
grant execute on function admin.list_assignable_staff(uuid) to hivorr_api;
