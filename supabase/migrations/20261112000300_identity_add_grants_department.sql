-- Grants are organised by department (area).
--
-- `department_id` is chosen when a grant is created. It is nullable only so
-- grants issued before this migration remain readable; the control portal shows
-- them under "Unassigned" until an administrator records the department.
--
-- The department catalogue lives in `admin.departments`. Departments carry
-- scope and reporting responsibility, never authority: a grant still decides
-- what a user may do.

set local lock_timeout = '5s';

alter table identity.grants
  add column department_id uuid references admin.departments (id) on delete restrict;

create index grants_department_idx on identity.grants (department_id);

comment on column identity.grants.department_id is
  'The department or area that owns this grant. Null for grants issued before departments existed.';

insert into admin.departments (key, name, description) values
  ('financial', 'Financial', 'Ledger, reconciliation, payments and financial exceptions.'),
  ('operations', 'Operations', 'Activity operations, dispatch, partners and service levels.'),
  ('customer_care', 'Customer Care', 'Support cases, customer context and account assistance.'),
  ('governance', 'Governance', 'Roles, grants, audit and compliance oversight.')
on conflict (key) do nothing;

-- The grant read model now carries the holder's name and the owning department.
-- The return shape changes, so the function is replaced rather than altered.
drop function if exists identity.list_grants(uuid, text);

create function identity.list_grants(
  p_actor_user_id uuid,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  grant_type text,
  scope text,
  environment text,
  granted_by uuid,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz,
  department_key text,
  department_name text
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
    select g.id, g.user_id, u.email, u.display_name, g.grant_type, g.scope,
           g.environment, g.granted_by, g.expires_at, g.revoked_at, g.created_at,
           d.key, d.name
    from identity.grants g
    join identity.users u on u.id = g.user_id
    left join admin.departments d on d.id = g.department_id
    where g.environment = p_environment
    order by g.created_at desc, g.id desc;
end;
$$;

comment on function identity.list_grants(uuid, text) is
  'Grant read model: holder name and email, grant type, scope, status fields and the owning department.';

revoke all on function identity.list_grants(uuid, text) from public;
grant execute on function identity.list_grants(uuid, text) to hivorr_api;

-- Record the department on an existing grant. Used for the historical rows that
-- predate departments, and for a deliberate re-homing of a grant.
create function identity.set_grant_department(
  p_actor_user_id uuid,
  p_grant_id uuid,
  p_department_key text,
  p_environment text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  grant_type text,
  scope text,
  environment text,
  granted_by uuid,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz,
  department_key text,
  department_name text
)
language plpgsql
security definer
set search_path = identity, pg_temp
as $$
declare
  v_department_id uuid;
  v_grant_id uuid;
begin
  if not identity.actor_has_grant(p_actor_user_id, 'admin.grant.manage', p_environment) then
    raise exception 'grant_manage_forbidden' using errcode = '42501';
  end if;

  select d.id into v_department_id
  from admin.departments d
  where d.key = p_department_key
    and d.status = 'active'
  limit 1;

  if v_department_id is null then
    raise exception 'department_not_found' using errcode = 'P0002';
  end if;

  update identity.grants g
  set department_id = v_department_id
  where g.id = p_grant_id
    and g.environment = p_environment
    and g.revoked_at is null
  returning g.id into v_grant_id;

  if v_grant_id is null then
    raise exception 'grant_not_found' using errcode = 'P0002';
  end if;

  return query
    select g.id, g.user_id, u.email, u.display_name, g.grant_type, g.scope,
           g.environment, g.granted_by, g.expires_at, g.revoked_at, g.created_at,
           d.key, d.name
    from identity.grants g
    join identity.users u on u.id = g.user_id
    left join admin.departments d on d.id = g.department_id
    where g.id = v_grant_id;
end;
$$;

revoke all on function identity.set_grant_department(uuid, uuid, text, text) from public;
grant execute on function identity.set_grant_department(uuid, uuid, text, text) to hivorr_api;

-- The department catalogue for the grant screen. Gated by the same capability
-- as the grant read so the list never becomes an unmetered directory.
create function admin.list_departments(
  p_actor_user_id uuid,
  p_environment text
)
returns table (
  key text,
  name text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (
    identity.actor_has_grant(p_actor_user_id, 'admin.grant.read', p_environment)
    or identity.actor_has_grant(p_actor_user_id, 'admin.grant.manage', p_environment)
  ) then
    raise exception 'grant_read_forbidden' using errcode = '42501';
  end if;

  return query
    select d.key, d.name
    from admin.departments d
    where d.status = 'active'
    order by d.name;
end;
$$;

revoke all on function admin.list_departments(uuid, text) from public;
grant execute on function admin.list_departments(uuid, text) to hivorr_api;
