-- Transaction-scoped identity context and row-level security.
--
-- The service layer sets the account and user for the transaction. RLS is
-- defence in depth: a missing or wrong context fails closed. A security-definer
-- pre-auth lookup is the only path that reads a credential without a session.

create or replace function platform.current_account_id()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('hivorr.account_id', true), '')::uuid
$$;

create or replace function platform.current_user_id()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('hivorr.user_id', true), '')::uuid
$$;

create or replace function platform.set_identity_context(
  account_id uuid,
  user_id uuid
)
returns void
language plpgsql
as $$
begin
  perform set_config('hivorr.account_id', account_id::text, true);
  perform set_config('hivorr.user_id', user_id::text, true);
end;
$$;

revoke all on function platform.current_account_id() from public;
revoke all on function platform.current_user_id() from public;
revoke all on function platform.set_identity_context(uuid, uuid) from public;
grant execute on function platform.current_account_id() to hivorr_api;
grant execute on function platform.current_user_id() to hivorr_api;
grant execute on function platform.set_identity_context(uuid, uuid) to hivorr_api;

-- Narrow pre-auth lookup used only by the sign-in and password-reset flows.
-- It returns one credential for the supplied email and no other user's data.
create or replace function identity.find_login_credential(p_email text)
returns table (
  user_id uuid,
  account_id uuid,
  password_hash text,
  user_status text,
  locked_until timestamptz
)
language sql
security definer
set search_path = identity, pg_temp
as $$
  select u.id, u.account_id, c.password_hash, u.status, c.locked_until
  from identity.users u
  join identity.credentials c on c.user_id = u.id
  where lower(u.email) = lower(p_email)
    and u.status <> 'closed'
  limit 1
$$;

revoke all on function identity.find_login_credential(text) from public;
grant execute on function identity.find_login_credential(text) to hivorr_api;

alter table identity.accounts enable row level security;
alter table identity.accounts force row level security;
alter table identity.users enable row level security;
alter table identity.users force row level security;
alter table identity.credentials enable row level security;
alter table identity.credentials force row level security;
alter table identity.memberships enable row level security;
alter table identity.memberships force row level security;
alter table identity.grants enable row level security;
alter table identity.grants force row level security;
alter table identity.devices enable row level security;
alter table identity.devices force row level security;
alter table identity.sessions enable row level security;
alter table identity.sessions force row level security;
alter table identity.mfa_factors enable row level security;
alter table identity.mfa_factors force row level security;
alter table identity.recovery_codes enable row level security;
alter table identity.recovery_codes force row level security;
alter table identity.tokens enable row level security;
alter table identity.tokens force row level security;

create policy accounts_select on identity.accounts
  for select to hivorr_api
  using (id = platform.current_account_id());

create policy accounts_insert on identity.accounts
  for insert to hivorr_api
  with check (id = platform.current_account_id());

create policy accounts_update on identity.accounts
  for update to hivorr_api
  using (id = platform.current_account_id())
  with check (id = platform.current_account_id());

create policy users_select on identity.users
  for select to hivorr_api
  using (account_id = platform.current_account_id());

create policy users_insert on identity.users
  for insert to hivorr_api
  with check (account_id = platform.current_account_id());

create policy users_update on identity.users
  for update to hivorr_api
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

create policy credentials_select on identity.credentials
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy credentials_insert on identity.credentials
  for insert to hivorr_api
  with check (user_id = platform.current_user_id());

create policy credentials_update on identity.credentials
  for update to hivorr_api
  using (user_id = platform.current_user_id())
  with check (user_id = platform.current_user_id());

create policy memberships_select on identity.memberships
  for select to hivorr_api
  using (account_id = platform.current_account_id());

create policy memberships_insert on identity.memberships
  for insert to hivorr_api
  with check (account_id = platform.current_account_id());

create policy memberships_update on identity.memberships
  for update to hivorr_api
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

create policy grants_select on identity.grants
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy devices_select on identity.devices
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy devices_insert on identity.devices
  for insert to hivorr_api
  with check (user_id = platform.current_user_id());

create policy devices_update on identity.devices
  for update to hivorr_api
  using (user_id = platform.current_user_id())
  with check (user_id = platform.current_user_id());

create policy sessions_select on identity.sessions
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy sessions_insert on identity.sessions
  for insert to hivorr_api
  with check (user_id = platform.current_user_id());

create policy sessions_update on identity.sessions
  for update to hivorr_api
  using (user_id = platform.current_user_id())
  with check (user_id = platform.current_user_id());

create policy mfa_factors_select on identity.mfa_factors
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy mfa_factors_insert on identity.mfa_factors
  for insert to hivorr_api
  with check (user_id = platform.current_user_id());

create policy mfa_factors_update on identity.mfa_factors
  for update to hivorr_api
  using (user_id = platform.current_user_id())
  with check (user_id = platform.current_user_id());

create policy recovery_codes_select on identity.recovery_codes
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy recovery_codes_insert on identity.recovery_codes
  for insert to hivorr_api
  with check (user_id = platform.current_user_id());

create policy recovery_codes_update on identity.recovery_codes
  for update to hivorr_api
  using (user_id = platform.current_user_id())
  with check (user_id = platform.current_user_id());

create policy recovery_codes_delete on identity.recovery_codes
  for delete to hivorr_api
  using (user_id = platform.current_user_id());

create policy tokens_select on identity.tokens
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy tokens_insert on identity.tokens
  for insert to hivorr_api
  with check (user_id = platform.current_user_id());

create policy tokens_update on identity.tokens
  for update to hivorr_api
  using (user_id = platform.current_user_id())
  with check (user_id = platform.current_user_id());

create policy tokens_delete on identity.tokens
  for delete to hivorr_api
  using (user_id = platform.current_user_id());
