-- Partner isolation (CP-015): a partner user can read only the organisations
-- they represent.
--
-- The read model is keyed by the authenticated user, never by a client-supplied
-- organisation id, so there is no parameter to tamper with. Control endpoints
-- stay behind the `control` audience and are refused to a partner session.

set local lock_timeout = '5s';

create function admin.list_own_partner_organisations(
  p_user_id uuid
)
returns table (
  organisation_id uuid,
  legal_name text,
  trading_name text,
  status text,
  representative_role text,
  effective_from timestamptz
)
language sql
security definer
stable
set search_path = ''
as $$
  select o.id, o.legal_name, o.trading_name, o.status,
         r.representative_role, r.effective_from
    from admin.partner_representatives r
    join admin.partner_organisations o on o.id = r.organisation_id
   where r.user_id = p_user_id
     and r.effective_to is null
     and o.status <> 'terminated'
   order by o.legal_name;
$$;

comment on function admin.list_own_partner_organisations(uuid) is
  'The organisations a partner user currently represents. Self-scoped by user id.';

revoke all on function admin.list_own_partner_organisations(uuid) from public;
grant execute on function admin.list_own_partner_organisations(uuid) to hivorr_api;
