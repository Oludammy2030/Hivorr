-- Recovery token lookups (EP-01-031).
--
-- Password reset and email verification run before a session exists. A narrow
-- security-definer lookup returns only the user/account for a valid, unexpired,
-- unconsumed token. The service then sets the identity context and consumes the
-- token through the normal RLS policies, so the write path is still scoped.
--
-- The token value is never stored: only its SHA-256 hash is.

create policy tokens_definer_select on identity.tokens
  for select to hivorr_migrator, postgres using (true);

create or replace function identity.find_password_reset_token(p_token_hash text)
returns table (user_id uuid, account_id uuid, email text)
language sql
security definer
stable
set search_path = identity, pg_temp
as $$
  select t.user_id, u.account_id, u.email
  from identity.tokens t
  join identity.users u on u.id = t.user_id
  where t.token_hash = p_token_hash
    and t.purpose = 'password_reset'
    and t.consumed_at is null
    and t.expires_at > now()
  limit 1
$$;

revoke all on function identity.find_password_reset_token(text) from public;
grant execute on function identity.find_password_reset_token(text) to hivorr_api;

create or replace function identity.find_email_verification_token(p_token_hash text)
returns table (user_id uuid, account_id uuid, email text)
language sql
security definer
stable
set search_path = identity, pg_temp
as $$
  select t.user_id, u.account_id, u.email
  from identity.tokens t
  join identity.users u on u.id = t.user_id
  where t.token_hash = p_token_hash
    and t.purpose = 'email_verification'
    and t.consumed_at is null
    and t.expires_at > now()
  limit 1
$$;

revoke all on function identity.find_email_verification_token(text) from public;
grant execute on function identity.find_email_verification_token(text) to hivorr_api;
