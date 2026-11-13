-- Partner governance (CP-014): the organisation register, lifecycle and
-- representatives. Isolation and RLS for the partner audience are CP-015.
--
-- Applications, agreements and scopes exist in the schema but are not exposed
-- by this slice; the register and representatives come first.

set local lock_timeout = '5s';

insert into admin.permissions (key, namespace, description, sensitivity) values
  ('admin.partner.read', 'admin.partner', 'Read partner organisations and representatives', 'sensitive'),
  ('admin.partner.manage', 'admin.partner', 'Create, activate, suspend or terminate a partner organisation', 'critical')
on conflict (key) do nothing;

insert into admin.role_permissions (role_id, permission_key)
select r.id, p.key
  from admin.roles r
  join admin.permissions p on p.key in ('admin.partner.read', 'admin.partner.manage')
 where r.key in ('founder', 'partner_manager')
on conflict do nothing;

create function admin.list_partner_organisations(
  p_actor_user_id uuid
)
returns table (
  id uuid,
  legal_name text,
  trading_name text,
  category text,
  country text,
  status text,
  representatives bigint,
  agreements bigint,
  created_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.partner.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.partner.manage')
  ) then
    raise exception 'partner_read_forbidden' using errcode = '42501';
  end if;

  return query
    select o.id, o.legal_name, o.trading_name, o.category, o.country, o.status,
           (select count(*) from admin.partner_representatives r
             where r.organisation_id = o.id and r.effective_to is null),
           (select count(*) from admin.partner_agreements a
             where a.organisation_id = o.id),
           o.created_at
      from admin.partner_organisations o
     order by (o.status = 'active') desc, o.legal_name;
end;
$$;

revoke all on function admin.list_partner_organisations(uuid) from public;
grant execute on function admin.list_partner_organisations(uuid) to hivorr_api;

create function admin.create_partner_organisation(
  p_actor_user_id uuid,
  p_legal_name text,
  p_trading_name text,
  p_category text,
  p_country text,
  p_reason text
)
returns table (
  id uuid,
  legal_name text,
  trading_name text,
  category text,
  country text,
  status text,
  representatives bigint,
  agreements bigint,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.partner.manage') then
    raise exception 'partner_manage_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'partner_reason_required' using errcode = '22023';
  end if;

  if p_legal_name is null or length(btrim(p_legal_name)) < 2 then
    raise exception 'partner_name_required' using errcode = '22023';
  end if;

  insert into admin.partner_organisations as o
    (legal_name, trading_name, category, country)
  values
    (btrim(p_legal_name), nullif(btrim(coalesce(p_trading_name, '')), ''),
     nullif(btrim(coalesce(p_category, '')), ''),
     nullif(btrim(coalesce(p_country, '')), ''))
  returning o.id into v_id;

  return query
    select o.id, o.legal_name, o.trading_name, o.category, o.country, o.status,
           0::bigint, 0::bigint, o.created_at
      from admin.partner_organisations o
     where o.id = v_id;
end;
$$;

revoke all on function admin.create_partner_organisation(uuid, text, text, text, text, text) from public;
grant execute on function admin.create_partner_organisation(uuid, text, text, text, text, text) to hivorr_api;

create function admin.set_partner_status(
  p_actor_user_id uuid,
  p_organisation_id uuid,
  p_status text,
  p_reason text
)
returns table (
  id uuid,
  legal_name text,
  trading_name text,
  category text,
  country text,
  status text,
  representatives bigint,
  agreements bigint,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.partner.manage') then
    raise exception 'partner_manage_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'partner_reason_required' using errcode = '22023';
  end if;

  if p_status is null or p_status not in ('active', 'suspended', 'terminated') then
    raise exception 'partner_status_invalid' using errcode = '22023';
  end if;

  select o.status into v_status
    from admin.partner_organisations o
   where o.id = p_organisation_id
   for update;

  if v_status is null then
    raise exception 'partner_not_found' using errcode = 'P0002';
  end if;

  if v_status = 'terminated' then
    raise exception 'partner_state_invalid' using errcode = '23514';
  end if;

  if p_status = 'active' and v_status not in ('applicant', 'suspended') then
    raise exception 'partner_state_invalid' using errcode = '23514';
  end if;

  if p_status = 'suspended' and v_status <> 'active' then
    raise exception 'partner_state_invalid' using errcode = '23514';
  end if;

  update admin.partner_organisations o
     set status = p_status, updated_at = now()
   where o.id = p_organisation_id;

  return query
    select o.id, o.legal_name, o.trading_name, o.category, o.country, o.status,
           (select count(*) from admin.partner_representatives r
             where r.organisation_id = o.id and r.effective_to is null),
           (select count(*) from admin.partner_agreements a
             where a.organisation_id = o.id),
           o.created_at
      from admin.partner_organisations o
     where o.id = p_organisation_id;
end;
$$;

revoke all on function admin.set_partner_status(uuid, uuid, text, text) from public;
grant execute on function admin.set_partner_status(uuid, uuid, text, text) to hivorr_api;

create function admin.list_partner_representatives(
  p_actor_user_id uuid,
  p_organisation_id uuid
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  representative_role text,
  effective_from timestamptz,
  effective_to timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  if not (
    admin.actor_holds_platform_permission(p_actor_user_id, 'admin.partner.read')
    or admin.actor_holds_platform_permission(p_actor_user_id, 'admin.partner.manage')
  ) then
    raise exception 'partner_read_forbidden' using errcode = '42501';
  end if;

  return query
    select r.id, r.user_id, u.email, u.display_name, r.representative_role,
           r.effective_from, r.effective_to
      from admin.partner_representatives r
      join identity.users u on u.id = r.user_id
     where r.organisation_id = p_organisation_id
     order by (r.effective_to is null) desc, u.email;
end;
$$;

revoke all on function admin.list_partner_representatives(uuid, uuid) from public;
grant execute on function admin.list_partner_representatives(uuid, uuid) to hivorr_api;

create function admin.add_partner_representative(
  p_actor_user_id uuid,
  p_organisation_id uuid,
  p_email text,
  p_role text,
  p_reason text
)
returns table (
  id uuid,
  user_id uuid,
  email text,
  display_name text,
  representative_role text,
  effective_from timestamptz,
  effective_to timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_id uuid;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.partner.manage') then
    raise exception 'partner_manage_forbidden' using errcode = '42501';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'partner_reason_required' using errcode = '22023';
  end if;

  if p_role is null or p_role not in ('owner', 'admin', 'member', 'viewer') then
    raise exception 'partner_role_invalid' using errcode = '22023';
  end if;

  if not exists (
    select 1 from admin.partner_organisations o
     where o.id = p_organisation_id and o.status <> 'terminated'
  ) then
    raise exception 'partner_not_found' using errcode = 'P0002';
  end if;

  select u.id into v_user_id
    from identity.users u
   where lower(u.email) = lower(p_email)
     and u.status = 'active'
   limit 1;

  if v_user_id is null then
    raise exception 'partner_user_not_found' using errcode = 'P0002';
  end if;

  insert into admin.partner_representatives as r
    (organisation_id, user_id, representative_role, created_by)
  values
    (p_organisation_id, v_user_id, p_role, p_actor_user_id)
  returning r.id into v_id;

  return query
    select r.id, r.user_id, u.email, u.display_name, r.representative_role,
           r.effective_from, r.effective_to
      from admin.partner_representatives r
      join identity.users u on u.id = r.user_id
     where r.id = v_id;
end;
$$;

revoke all on function admin.add_partner_representative(uuid, uuid, text, text, text) from public;
grant execute on function admin.add_partner_representative(uuid, uuid, text, text, text) to hivorr_api;
