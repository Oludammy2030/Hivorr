-- Identity spine: accounts, users, credentials, memberships, grants, sessions,
-- devices, MFA factors, recovery codes, and one-time tokens.
--
-- RLS policies and the transaction-scoped identity context are added in
-- EP-01-025. Until then these tables are accessible only through the service
-- layer with the hivorr_api role; no client has a database credential.

create table identity.accounts (
  id uuid primary key default platform.uuidv7(),
  status text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  legal_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table identity.accounts is
  'Legal/billing party. Owns the wallet and activity records. One owner user at MVP.';

create table identity.users (
  id uuid primary key default platform.uuidv7(),
  account_id uuid not null references identity.accounts (id) on delete restrict,
  email text not null,
  phone text,
  display_name text,
  status text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  email_verified_at timestamptz,
  phone_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table identity.users is
  'Credential holder that can sign in. A user belongs to an account through identity.memberships.';

create unique index users_email_unique on identity.users (lower(email));
create unique index users_phone_unique on identity.users (phone) where phone is not null;
create index users_account_idx on identity.users (account_id);

create table identity.credentials (
  user_id uuid primary key references identity.users (id) on delete cascade,
  password_hash text not null,
  password_updated_at timestamptz not null default now(),
  failed_attempts integer not null default 0 check (failed_attempts >= 0),
  locked_until timestamptz,
  created_at timestamptz not null default now()
);

comment on table identity.credentials is
  'Argon2id password hash and lockout state. The hash is never returned to a client.';

create table identity.memberships (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete restrict,
  account_id uuid not null references identity.accounts (id) on delete restrict,
  role text not null default 'member' check (role in ('owner', 'member')),
  created_at timestamptz not null default now(),
  unique (user_id, account_id)
);

create unique index memberships_one_owner
  on identity.memberships (account_id)
  where role = 'owner';

create index memberships_user_idx on identity.memberships (user_id);

create table identity.grants (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  grant_type text not null check (grant_type in ('admin', 'staff', 'partner', 'platform_engineering')),
  scope text not null,
  environment text not null check (environment in ('development', 'test', 'staging', 'production')),
  granted_by uuid references identity.users (id) on delete set null,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table identity.grants is
  'Orthogonal privileged grants. A grant never activates an activity and never implies another grant.';

create unique index grants_active_unique
  on identity.grants (user_id, grant_type, scope, environment)
  where revoked_at is null;

create index grants_user_idx on identity.grants (user_id);

create table identity.devices (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  name text,
  fingerprint_hash text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index devices_user_fingerprint_unique
  on identity.devices (user_id, fingerprint_hash)
  where fingerprint_hash is not null;

create table identity.sessions (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  device_id uuid references identity.devices (id) on delete set null,
  audience text not null check (audience in ('app', 'control', 'staff', 'partner')),
  environment text not null check (environment in ('development', 'test', 'staging', 'production')),
  refresh_token_hash text not null unique,
  issued_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  idle_expires_at timestamptz not null,
  expires_at timestamptz not null,
  mfa_satisfied_at timestamptz,
  revoked_at timestamptz,
  revoked_reason text
);

comment on table identity.sessions is
  'Server-side session per device. Audience and environment bind the session to one portal and one backend.';

create index sessions_user_idx on identity.sessions (user_id);
create index sessions_active_idx on identity.sessions (user_id, expires_at)
  where revoked_at is null;

create table identity.mfa_factors (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  factor_type text not null check (factor_type in ('totp', 'webauthn')),
  label text,
  secret_ciphertext text not null,
  key_version text not null,
  confirmed_at timestamptz,
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table identity.mfa_factors is
  'MFA factor secrets are encrypted at the application layer; the database stores ciphertext only.';

create index mfa_factors_user_idx on identity.mfa_factors (user_id);

create table identity.recovery_codes (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  code_hash text not null unique,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index recovery_codes_user_idx on identity.recovery_codes (user_id);

create table identity.tokens (
  id uuid primary key default platform.uuidv7(),
  user_id uuid not null references identity.users (id) on delete cascade,
  purpose text not null check (purpose in (
    'email_verification',
    'phone_verification',
    'password_reset',
    'account_invite'
  )),
  token_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index tokens_user_purpose_idx on identity.tokens (user_id, purpose);

create or replace function platform.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger accounts_touch_updated_at
before update on identity.accounts
for each row execute function platform.touch_updated_at();

create trigger users_touch_updated_at
before update on identity.users
for each row execute function platform.touch_updated_at();

grant select, insert, update on identity.accounts to hivorr_api;
grant select, insert, update on identity.users to hivorr_api;
grant select, insert, update on identity.credentials to hivorr_api;
grant select, insert, update on identity.memberships to hivorr_api;
grant select, insert, update on identity.grants to hivorr_api;
grant select, insert, update on identity.devices to hivorr_api;
grant select, insert, update on identity.sessions to hivorr_api;
grant select, insert, update on identity.mfa_factors to hivorr_api;
grant select, insert, update, delete on identity.recovery_codes to hivorr_api;
grant select, insert, update, delete on identity.tokens to hivorr_api;
