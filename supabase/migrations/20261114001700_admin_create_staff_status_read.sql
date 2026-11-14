-- Staff status read for the audit before-state (F-B-03).
--
-- The service read the previous engagement status with a direct select on
-- `admin.staff_profiles`. That table is protected by RLS with the policy
-- `staff_profiles_select_self`, so for any target other than the caller the read
-- returned no rows and the audit row recorded a change from nothing.
--
-- This function is the narrow, capability-gated read: one column, one user,
-- behind the same permission that authorises the change itself.

create function admin.staff_status_of(
  p_actor_user_id uuid,
  p_user_id uuid
)
returns text
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_status text;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.user.manage') then
    raise exception 'staff_status_forbidden' using errcode = '42501';
  end if;

  select s.engagement_status into v_status
    from admin.staff_profiles s
   where s.user_id = p_user_id;

  if v_status is null then
    raise exception 'staff_not_found' using errcode = 'P0002';
  end if;

  return v_status;
end;
$$;

comment on function admin.staff_status_of(uuid, uuid) is
  'The current engagement status of one staff member, for the audit before-state. Refuses without admin.user.manage.';

revoke all on function admin.staff_status_of(uuid, uuid) from public;
grant execute on function admin.staff_status_of(uuid, uuid) to hivorr_api;
