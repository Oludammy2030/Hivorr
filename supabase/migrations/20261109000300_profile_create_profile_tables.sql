-- Shared profile and activity activation state (EP-01-024).
--
-- One profile per account, shared by every activity (matrix §5-§6). One
-- activation row per account and activity; activating twice is a no-op through
-- the unique constraint. The permitted transitions are enforced by EP-01-033,
-- so this migration constrains the state set, not the transition graph.
--
-- RLS uses the transaction-scoped identity context from migration 006. The
-- account filter is indexed so the policy does not fall back to a scan.

create table profile.profiles (
  account_id uuid primary key references identity.accounts (id) on delete cascade,
  display_name text,
  avatar_url text,
  bio text,
  locale text,
  timezone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table profile.profiles is
  'The account''s shared presentation: display name, avatar, bio, locale and timezone. One per account, shared by every activity.';

create table profile.activity_activations (
  id uuid primary key default platform.uuidv7(),
  account_id uuid not null references identity.accounts (id) on delete cascade,
  activity_id text not null check (activity_id in (
    'market.buy',
    'services.hire',
    'errands.request',
    'market.sell',
    'services.offer',
    'logistics.provide'
  )),
  state text not null default 'INACTIVE' check (state in (
    'INACTIVE',
    'ACTIVE',
    'RESTRICTED',
    'SUSPENDED'
  )),
  activated_at timestamptz,
  deactivated_at timestamptz,
  state_changed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, activity_id)
);

comment on table profile.activity_activations is
  'One row per account and activity. State is INACTIVE, ACTIVE, RESTRICTED or SUSPENDED; activating twice is a no-op.';

create index activity_activations_account_state_idx
  on profile.activity_activations (account_id, state);
create index activity_activations_activity_state_idx
  on profile.activity_activations (activity_id, state);

alter table profile.profiles enable row level security;
alter table profile.activity_activations enable row level security;

create policy profiles_select on profile.profiles
  for select using (account_id = platform.current_account_id());
create policy profiles_insert on profile.profiles
  for insert with check (account_id = platform.current_account_id());
create policy profiles_update on profile.profiles
  for update
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

create policy activity_activations_select on profile.activity_activations
  for select using (account_id = platform.current_account_id());
create policy activity_activations_insert on profile.activity_activations
  for insert with check (account_id = platform.current_account_id());
create policy activity_activations_update on profile.activity_activations
  for update
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

grant usage on schema profile to hivorr_readonly;

grant select, insert, update on profile.profiles to hivorr_api;
grant select, insert, update on profile.activity_activations to hivorr_api;
grant select on profile.profiles to hivorr_readonly;
grant select on profile.activity_activations to hivorr_readonly;

-- The readonly role evaluates the same RLS policy expressions.
grant execute on function platform.current_account_id() to hivorr_readonly;
