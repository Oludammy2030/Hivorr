-- Access/refresh token split with a rotating refresh chain.
--
-- The access token is short-lived and used for every authenticated request. The
-- refresh token is long-lived, scoped to the auth endpoints by its cookie path,
-- and rotates on every use. Each refresh belongs to one session (the family).
-- Reusing an already-spent refresh token outside a short retry window revokes
-- the whole session, which is the standard refresh-reuse defence.

alter table identity.sessions add column access_token_hash text;
alter table identity.sessions add column access_expires_at timestamptz;

update identity.sessions
set access_token_hash = refresh_token_hash,
    access_expires_at = least(expires_at, now() + interval '15 minutes')
where access_token_hash is null;

alter table identity.sessions alter column access_token_hash set not null;
alter table identity.sessions alter column access_expires_at set not null;

create unique index sessions_access_token_hash_unique
  on identity.sessions (access_token_hash);

create table identity.refresh_tokens (
  id uuid primary key default platform.uuidv7(),
  session_id uuid not null references identity.sessions (id) on delete cascade,
  token_hash text not null unique,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  replaced_by uuid references identity.refresh_tokens (id) on delete set null
);

comment on table identity.refresh_tokens is
  'Rotating refresh-token chain. A reused token outside the retry window revokes its session.';

create index refresh_tokens_session_idx
  on identity.refresh_tokens (session_id);

insert into identity.refresh_tokens (session_id, token_hash, expires_at)
select id, refresh_token_hash, expires_at from identity.sessions;

alter table identity.refresh_tokens enable row level security;
alter table identity.refresh_tokens force row level security;

create policy refresh_tokens_select on identity.refresh_tokens
  for select to hivorr_api
  using (
    session_id in (
      select id from identity.sessions
      where user_id = platform.current_user_id()
    )
  );

create policy refresh_tokens_insert on identity.refresh_tokens
  for insert to hivorr_api
  with check (
    session_id in (
      select id from identity.sessions
      where user_id = platform.current_user_id()
    )
  );

create policy refresh_tokens_update on identity.refresh_tokens
  for update to hivorr_api
  using (
    session_id in (
      select id from identity.sessions
      where user_id = platform.current_user_id()
    )
  )
  with check (
    session_id in (
      select id from identity.sessions
      where user_id = platform.current_user_id()
    )
  );

grant select, insert, update on identity.refresh_tokens to hivorr_api;

-- Authenticated request lookup by access token. Replaces the earlier lookup by
-- refresh hash, so a refresh token can never be used as an access credential.
create or replace function identity.find_session_by_access(p_token_hash text)
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
  where s.access_token_hash = p_token_hash
  limit 1
$$;

revoke all on function identity.find_session_by_access(text) from public;
grant execute on function identity.find_session_by_access(text) to hivorr_api;

-- Pre-auth refresh lookup. It returns the token's session and owning account
-- only; the caller must still lock and validate the row inside a transaction.
create or replace function identity.find_refresh_token(p_token_hash text)
returns table (
  refresh_id uuid,
  session_id uuid,
  user_id uuid,
  account_id uuid,
  audience text,
  environment text,
  email text,
  token_expires_at timestamptz,
  session_expires_at timestamptz,
  session_idle_expires_at timestamptz,
  session_revoked_at timestamptz,
  used_at timestamptz,
  replaced_by uuid
)
language sql
security definer
set search_path = identity, pg_temp
as $$
  select r.id, r.session_id, s.user_id, u.account_id, s.audience, s.environment,
         u.email, r.expires_at, s.expires_at, s.idle_expires_at, s.revoked_at,
         r.used_at, r.replaced_by
  from identity.refresh_tokens r
  join identity.sessions s on s.id = r.session_id
  join identity.users u on u.id = s.user_id
  where r.token_hash = p_token_hash
  limit 1
$$;

revoke all on function identity.find_refresh_token(text) from public;
grant execute on function identity.find_refresh_token(text) to hivorr_api;

-- The old lookup accepted a refresh token as an access credential. Retire it.
drop function if exists identity.find_session(text);
