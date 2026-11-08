-- MFA challenges and hardened MFA lookups.
--
-- A privileged sign-in proves the password first and then holds a short-lived,
-- single-use challenge instead of a session. The challenge is bound to one
-- portal and one environment so a code verified for one portal cannot be
-- replayed against another. The row stores only a hash of the challenge token.

create table identity.mfa_challenges (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  challenge_hash text not null unique,
  audience text not null check (audience in ('app', 'control', 'staff', 'partner')),
  environment text not null check (environment in ('development', 'test', 'staging', 'production')),
  device_name text,
  attempts integer not null default 0 check (attempts >= 0),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table identity.mfa_challenges is
  'Short-lived single-use proof of password for a privileged sign-in. It is exchanged for a session only after a TOTP or recovery code succeeds.';

create index mfa_challenges_user_idx on identity.mfa_challenges (user_id);
create index mfa_challenges_live_idx
  on identity.mfa_challenges (expires_at)
  where consumed_at is null;

-- Pre-auth challenge lookup. The caller has no session yet, so this narrow
-- security-definer function returns the challenge and the owning account. All
-- other reads stay behind RLS and the transaction-scoped identity context.
create or replace function identity.find_mfa_challenge(p_challenge_hash text)
returns table (
  challenge_id uuid,
  user_id uuid,
  account_id uuid,
  audience text,
  environment text,
  device_name text,
  attempts integer,
  expires_at timestamptz,
  consumed_at timestamptz
)
language sql
security definer
set search_path = identity, pg_temp
as $$
  select c.id, c.user_id, u.account_id, c.audience, c.environment,
         c.device_name, c.attempts, c.expires_at, c.consumed_at
  from identity.mfa_challenges c
  join identity.users u on u.id = c.user_id
  where c.challenge_hash = p_challenge_hash
  limit 1
$$;

revoke all on function identity.find_mfa_challenge(text) from public;
grant execute on function identity.find_mfa_challenge(text) to hivorr_api;

alter table identity.mfa_challenges enable row level security;
alter table identity.mfa_challenges force row level security;

create policy mfa_challenges_select on identity.mfa_challenges
  for select to hivorr_api
  using (user_id = platform.current_user_id());

create policy mfa_challenges_insert on identity.mfa_challenges
  for insert to hivorr_api
  with check (user_id = platform.current_user_id());

create policy mfa_challenges_update on identity.mfa_challenges
  for update to hivorr_api
  using (user_id = platform.current_user_id())
  with check (user_id = platform.current_user_id());

grant select, insert, update on identity.mfa_challenges to hivorr_api;
