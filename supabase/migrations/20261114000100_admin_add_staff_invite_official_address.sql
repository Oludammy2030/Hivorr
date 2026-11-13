-- Staff lifecycle (CP-010, official-address slice).
--
-- A staff invitation has two addresses:
--
--   * `email`          the official company address Hivorr created for the
--                      person, for example firstname.lastname@hivorr.com. This
--                      becomes the identity account and every later work
--                      message targets it.
--   * `delivery_email` the personal address from the application, used only to
--                      deliver the invitation itself.
--
-- Acceptance never asks for an email, so the account can only ever be created
-- with the official address: a personal address cannot be used to register.

set local lock_timeout = '5s';

alter table admin.staff_invites
  add column delivery_email text;

update admin.staff_invites
   set delivery_email = email
 where delivery_email is null;

alter table admin.staff_invites
  alter column delivery_email set not null;

alter table admin.staff_invites
  add constraint staff_invites_delivery_email_format
  check (delivery_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');

comment on column admin.staff_invites.email is
  'Official company address that becomes the identity account on acceptance.';
comment on column admin.staff_invites.delivery_email is
  'Personal address the invitation is sent to. Never becomes an identity.';

-- ---------------------------------------------------------------------------
-- Invitations
-- ---------------------------------------------------------------------------

-- The signature changes, so the previous definition is removed rather than
-- overloaded: a stale five-argument call must fail loudly, not pick the old
-- meaning of `email`.
drop function if exists admin.create_staff_invite(text, text, text, text, text, timestamptz);

create or replace function admin.create_staff_invite(
  p_email text,
  p_delivery_email text,
  p_department_key text,
  p_job_title text,
  p_token_hash text,
  p_reason text,
  p_expires_at timestamptz,
  p_work_domain text
)
returns table (
  id uuid,
  email text,
  delivery_email text,
  department_key text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_delivery_email text := lower(trim(coalesce(p_delivery_email, '')));
  v_domain text := lower(trim(coalesce(p_work_domain, '')));
  v_id uuid;
begin
  if not admin.actor_has_platform_permission('admin.user.manage') then
    raise exception 'staff_invite_forbidden' using errcode = '42501';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'staff_invite_email_invalid' using errcode = '22023';
  end if;
  if v_domain = ''
     or right(v_email, length(v_domain) + 1) <> '@' || v_domain then
    raise exception 'staff_invite_email_not_official' using errcode = '22023';
  end if;
  if v_delivery_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'staff_invite_delivery_email_invalid' using errcode = '22023';
  end if;
  if p_reason is null or length(trim(p_reason)) < 5 then
    raise exception 'staff_invite_reason_required' using errcode = '22023';
  end if;
  if p_department_key is not null and not exists (
    select 1 from admin.departments d
     where d.key = p_department_key and d.status = 'active'
  ) then
    raise exception 'staff_invite_department_invalid' using errcode = '22023';
  end if;
  if exists (
    select 1 from identity.users u where lower(u.email) = v_email
  ) then
    raise exception 'staff_invite_email_exists' using errcode = '23505';
  end if;

  insert into admin.staff_invites
    (email, delivery_email, department_key, job_title, token_hash, invited_by,
     reason, expires_at)
  values
    (v_email, v_delivery_email, p_department_key,
     nullif(trim(coalesce(p_job_title, '')), ''),
     p_token_hash, platform.current_user_id(), trim(p_reason),
     coalesce(p_expires_at, now() + interval '7 days'))
  returning admin.staff_invites.id into v_id;

  return query
    select i.id, i.email, i.delivery_email, i.department_key, i.expires_at
      from admin.staff_invites i
     where i.id = v_id;
end;
$$;

revoke all on function admin.create_staff_invite(text, text, text, text, text, text, timestamptz, text) from public;
grant execute on function admin.create_staff_invite(text, text, text, text, text, text, timestamptz, text) to hivorr_api;

-- The invitation page reads this before any session exists. The caller must
-- already hold the single-use token, and the row only exists while the
-- invitation is pending, so this reveals nothing a token holder could not learn
-- by completing acceptance.
create or replace function admin.get_staff_invite(p_token_hash text)
returns table (
  email text,
  job_title text,
  department_key text,
  expires_at timestamptz
)
language sql
security definer
stable
set search_path = ''
as $$
  select i.email, i.job_title, i.department_key, i.expires_at
    from admin.staff_invites i
   where i.token_hash = p_token_hash
     and i.consumed_at is null
     and i.revoked_at is null
     and i.expires_at > now();
$$;

revoke all on function admin.get_staff_invite(text) from public;
grant execute on function admin.get_staff_invite(text) to hivorr_api;
