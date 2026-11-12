-- Staff lifecycle (CP-010, existing-account slice).
--
-- Invitations only onboard people who do not yet have a Hivorr account. Staff
-- who already signed up on the main portal need a way to become staff without
-- a second email address or a second account. This function attaches the staff
-- profile and the initial department membership to an existing identity user.
--
-- The API role has no table privileges here: the function re-checks the
-- caller's platform permission with `platform.current_user_id()`.

create or replace function admin.attach_staff_profile(
  p_email text,
  p_job_title text,
  p_department_key text,
  p_reason text
)
returns table (
  user_id uuid,
  staff_profile_id uuid,
  email text,
  department_key text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_user_id uuid;
  v_profile_id uuid := platform.uuidv7();
  v_department_id uuid;
begin
  if not admin.actor_has_platform_permission('admin.user.manage') then
    raise exception 'staff_attach_forbidden' using errcode = '42501';
  end if;
  if v_email = '' then
    raise exception 'staff_attach_email_required' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) < 5 then
    raise exception 'staff_attach_reason_required' using errcode = '22023';
  end if;

  select u.id into v_user_id
    from identity.users u
   where lower(u.email) = v_email;
  if v_user_id is null then
    raise exception 'staff_attach_user_not_found' using errcode = 'P0002';
  end if;
  if exists (
    select 1 from admin.staff_profiles s where s.user_id = v_user_id
  ) then
    raise exception 'staff_attach_profile_exists' using errcode = '23505';
  end if;

  if p_department_key is not null then
    select d.id into v_department_id
      from admin.departments d
     where d.key = p_department_key and d.status = 'active';
    if v_department_id is null then
      raise exception 'staff_attach_department_invalid' using errcode = '22023';
    end if;
  end if;

  insert into admin.staff_profiles
    (id, user_id, job_title, department_id, engagement_status, started_on)
  values (
    v_profile_id,
    v_user_id,
    nullif(trim(coalesce(p_job_title, '')), ''),
    v_department_id,
    'active',
    current_date
  );

  update admin.department_members dm
     set effective_to = now()
   where dm.user_id = v_user_id
     and dm.effective_to is null;

  if v_department_id is not null then
    insert into admin.department_members
      (department_id, user_id, membership_role, created_by)
    values (v_department_id, v_user_id, 'member', platform.current_user_id());
  end if;

  return query
    select v_user_id, v_profile_id, v_email, p_department_key;
end;
$$;

revoke all on function admin.attach_staff_profile(text, text, text, text) from public;
grant execute on function admin.attach_staff_profile(text, text, text, text) to hivorr_api;
