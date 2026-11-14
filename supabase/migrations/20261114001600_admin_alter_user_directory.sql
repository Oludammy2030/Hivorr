-- Directory search escaping (F-A-03).
--
-- `admin.list_users` interpolated the caller's query into an `ilike` pattern
-- without escaping the pattern metacharacters, so `%` and `_` in the search term
-- acted as wildcards: `%@hivorr.com` matched every address and `_` forced a full
-- scan. The query was parameterised, so there was no injection, but a caller
-- could enumerate with patterns and force work the page limit did not bound.
--
-- The term is now escaped before it becomes a pattern, and the pattern is used
-- with an explicit ESCAPE clause. An empty query still means "no filter", which
-- is checked before the pattern is used.

set local lock_timeout = '5s';

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
  v_pattern text;
begin
  if not admin.actor_has_platform_permission('admin.user.read') then
    raise exception 'user_directory_forbidden' using errcode = '42501';
  end if;

  -- Escape the wildcard characters so the search term is matched literally.
  v_pattern := '%' || replace(
    replace(replace(v_query, '\', '\\'), '%', '\%'),
    '_', '\_'
  ) || '%';

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
            or u.email ilike v_pattern escape '\'
            or coalesce(u.display_name, '') ilike v_pattern escape '\')
       and (v_status = '' or u.status = v_status)
       and (p_before is null or (u.created_at, u.id) < (p_before, p_before_id))
     order by u.created_at desc, u.id desc
     limit v_limit;
end;
$$;

comment on function admin.list_users(text, text, timestamptz, uuid, integer) is
  'Bounded, capability-gated user directory. Search terms are escaped so % and _ match literally.';

revoke all on function admin.list_users(text, text, timestamptz, uuid, integer) from public;
grant execute on function admin.list_users(text, text, timestamptz, uuid, integer) to hivorr_api;
