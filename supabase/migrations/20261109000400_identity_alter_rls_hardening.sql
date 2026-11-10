-- RLS hardening and private policy helpers (EP-01-025).
--
-- The transaction-scoped helpers move to the `private` schema, which is never
-- exposed to a client. The `platform` names remain as security-definer
-- wrappers so every existing policy and service call keeps its contract.
--
-- Profile tables gain FORCE ROW LEVEL SECURITY, matching the identity tables.
-- Profile policies are recreated with explicit roles: select for API and
-- readonly, insert/update for API only.

create or replace function private.current_account_id()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('hivorr.account_id', true), '')::uuid
$$;

create or replace function private.current_user_id()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('hivorr.user_id', true), '')::uuid
$$;

create or replace function private.set_identity_context(
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

revoke all on function private.current_account_id() from public;
revoke all on function private.current_user_id() from public;
revoke all on function private.set_identity_context(uuid, uuid) from public;

comment on function private.current_account_id() is
  'Reads the transaction-scoped account id. Null outside an identity context.';
comment on function private.current_user_id() is
  'Reads the transaction-scoped user id. Null outside an identity context.';
comment on function private.set_identity_context(uuid, uuid) is
  'Sets the account and user for the current transaction only.';

create or replace function platform.current_account_id()
returns uuid
language sql
stable
security definer
set search_path = private, pg_temp
as $$
  select private.current_account_id()
$$;

create or replace function platform.current_user_id()
returns uuid
language sql
stable
security definer
set search_path = private, pg_temp
as $$
  select private.current_user_id()
$$;

create or replace function platform.set_identity_context(
  account_id uuid,
  user_id uuid
)
returns void
language plpgsql
security definer
set search_path = private, pg_temp
as $$
begin
  perform private.set_identity_context(account_id, user_id);
end;
$$;

alter table profile.profiles force row level security;
alter table profile.activity_activations force row level security;

drop policy if exists profiles_select on profile.profiles;
drop policy if exists profiles_insert on profile.profiles;
drop policy if exists profiles_update on profile.profiles;
drop policy if exists activity_activations_select on profile.activity_activations;
drop policy if exists activity_activations_insert on profile.activity_activations;
drop policy if exists activity_activations_update on profile.activity_activations;

create policy profiles_select on profile.profiles
  for select to hivorr_api, hivorr_readonly
  using (account_id = platform.current_account_id());
create policy profiles_insert on profile.profiles
  for insert to hivorr_api
  with check (account_id = platform.current_account_id());
create policy profiles_update on profile.profiles
  for update to hivorr_api
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

create policy activity_activations_select on profile.activity_activations
  for select to hivorr_api, hivorr_readonly
  using (account_id = platform.current_account_id());
create policy activity_activations_insert on profile.activity_activations
  for insert to hivorr_api
  with check (account_id = platform.current_account_id());
create policy activity_activations_update on profile.activity_activations
  for update to hivorr_api
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

-- Security-definer functions run as the table owner. FORCE RLS applies to that
-- owner as well, so the owner needs a read policy on exactly the tables its
-- narrow functions touch. The migration owner already has DDL rights; this is
-- not a capability granted to an application role.
create policy users_definer_select on identity.users
  for select to hivorr_migrator, postgres using (true);
create policy credentials_definer_select on identity.credentials
  for select to hivorr_migrator, postgres using (true);
create policy sessions_definer_select on identity.sessions
  for select to hivorr_migrator, postgres using (true);
create policy devices_definer_select on identity.devices
  for select to hivorr_migrator, postgres using (true);
create policy mfa_challenges_definer_select on identity.mfa_challenges
  for select to hivorr_migrator, postgres using (true);
create policy refresh_tokens_definer_select on identity.refresh_tokens
  for select to hivorr_migrator, postgres using (true);
create policy grants_definer_select on identity.grants
  for select to hivorr_migrator, postgres using (true);
