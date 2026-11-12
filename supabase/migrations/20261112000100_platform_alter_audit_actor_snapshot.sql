-- Audit actor snapshot and capability (audit enrichment).
--
-- `actor_role_keys` is the role set held when the action was recorded. It is a
-- snapshot, not a join against current assignments. Existing rows keep an empty
-- array because the historical role was never captured and cannot be invented.
--
-- `platform.resolve_audit_actor` is the narrow, security-definer lookup used by
-- the audit writer before sign-in context exists. It returns only the display
-- name, email and active role keys for one user.

set local lock_timeout = '5s';

alter table platform.audit_log
  add column actor_display_name text,
  add column actor_email text,
  add column actor_role_keys text[] not null default '{}'::text[],
  add column capability text;

comment on column platform.audit_log.actor_display_name is
  'Display name snapshot at the time of the action.';
comment on column platform.audit_log.actor_email is
  'Email snapshot at the time of the action.';
comment on column platform.audit_log.actor_role_keys is
  'Governance role keys held when the action was recorded. Empty for historical and system rows.';
comment on column platform.audit_log.capability is
  'The capability that authorised the action, when the action was a governed operation.';

create or replace function platform.resolve_audit_actor(p_user_id uuid)
returns table (
  display_name text,
  email text,
  role_keys text[]
)
language sql
security definer
stable
set search_path = ''
as $$
  select
    u.display_name,
    u.email,
    coalesce(
      (
        select array_agg(r.key order by r.key)
          from admin.role_assignments ra
          join admin.roles r on r.id = ra.role_id
         where ra.user_id = u.id
           and ra.revoked_at is null
           and (ra.expires_at is null or ra.expires_at > now())
      ),
      '{}'::text[]
    )
  from identity.users u
  where u.id = p_user_id
$$;

revoke all on function platform.resolve_audit_actor(uuid) from public;
grant execute on function platform.resolve_audit_actor(uuid) to hivorr_api;
