-- Audit actor role scope (audit enrichment).
--
-- A governance role is assigned at platform, department, organisation, activity,
-- case, team or queue scope. The audit row snapshots the role key, but without
-- the scope two holders of the same role are indistinguishable to a reader.
-- `actor_role_scopes` is that snapshot: [{roleKey, scopeType, scopeId}].
--
-- `platform.resolve_audit_actor` now accepts the actor id as text so a
-- background actor with a non-UUID identifier resolves to an empty snapshot
-- instead of raising a cast error inside the caller's transaction.

set local lock_timeout = '5s';

alter table platform.audit_log
  add column actor_role_scopes jsonb not null default '[]'::jsonb;

comment on column platform.audit_log.actor_role_scopes is
  'Role key and assignment scope held when the action was recorded. Empty for historical and system rows.';

drop function if exists platform.resolve_audit_actor(uuid);

create function platform.resolve_audit_actor(p_actor_id text)
returns table (
  display_name text,
  email text,
  role_keys text[],
  role_scopes jsonb
)
language sql
security definer
stable
set search_path = ''
as $$
  select
    u.display_name,
    u.email,
    coalesce(assignment_roles.role_keys, '{}'::text[]),
    coalesce(assignment_roles.role_scopes, '[]'::jsonb)
  from identity.users u
  left join lateral (
    select
      array_agg(role.key order by role.key) as role_keys,
      jsonb_agg(
        jsonb_build_object(
          'roleKey', role.key,
          'scopeType', held.scope_type,
          'scopeId', held.scope_id
        )
        order by role.key, held.scope_type, held.scope_id
      ) as role_scopes
    from admin.role_assignments held
    join admin.roles role on role.id = held.role_id
    where held.user_id = u.id
      and held.revoked_at is null
      and (held.expires_at is null or held.expires_at > now())
  ) assignment_roles on true
  where u.id::text = p_actor_id
$$;

comment on function platform.resolve_audit_actor(text) is
  'Narrow audit-writer lookup: display name, email, active role keys and their assignment scopes for one actor id.';

revoke all on function platform.resolve_audit_actor(text) from public;
grant execute on function platform.resolve_audit_actor(text) to hivorr_api;
