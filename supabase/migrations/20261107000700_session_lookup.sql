-- Pre-auth session lookup. A session token is presented before the API knows
-- which account it belongs to, so this narrow security-definer function returns
-- only the session and the owning account/user identifiers. All other reads
-- remain behind RLS and the transaction-scoped identity context.

create or replace function identity.find_session(p_token_hash text)
returns table (
  session_id uuid,
  user_id uuid,
  account_id uuid,
  audience text,
  environment text,
  expires_at timestamptz,
  idle_expires_at timestamptz,
  revoked_at timestamptz,
  mfa_satisfied_at timestamptz,
  email text
)
language sql
security definer
set search_path = identity, pg_temp
as $$
  select s.id, s.user_id, u.account_id, s.audience, s.environment,
         s.expires_at, s.idle_expires_at, s.revoked_at, s.mfa_satisfied_at,
         u.email
  from identity.sessions s
  join identity.users u on u.id = s.user_id
  where s.refresh_token_hash = p_token_hash
  limit 1
$$;

revoke all on function identity.find_session(text) from public;
grant execute on function identity.find_session(text) to hivorr_api;
