-- Business profile on the account (EP-02-010, decision 16.4 #5).
--
-- Founder decision, 27 November 2026: a business is a verified profile on the
-- account — not a second account, not a second login. One account carries at
-- most one business, and the account's existing `identity.memberships` rows are
-- its members; there is no second membership model.
--
-- The business has no status column of its own. The `business` verification lane
-- case is the state (`profile.verification_cases`), so the review outcome cannot
-- drift between two stores. "A new business starts PENDING" is the lane case
-- starting at NOT_STARTED and moving through SUBMITTED.
--
-- The legal name is stored and must never be projected publicly; the trading name
-- is the public one. That separation is a policy rule for the read model, not a
-- database constraint.

set local lock_timeout = '5s';

create table profile.businesses (
  id uuid primary key default platform.uuidv7(),
  account_id uuid not null unique references identity.accounts (id) on delete cascade,
  trading_name text not null check (length(btrim(trading_name)) between 1 and 120),
  legal_name text not null check (length(btrim(legal_name)) between 1 and 160),
  registration_number text not null check (
    length(btrim(registration_number)) between 2 and 80
  ),
  jurisdiction text check (
    jurisdiction is null or length(btrim(jurisdiction)) between 2 and 80
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table profile.businesses is
  'The account''s business profile: trading name, registered legal name and registration number. One per account; members are the account''s identity.memberships rows. State lives in the business verification lane case, not here.';

comment on column profile.businesses.legal_name is
  'Registered legal name. Never projected publicly; the trading name is the public one.';

alter table profile.businesses enable row level security;
alter table profile.businesses force row level security;

revoke all on profile.businesses from public;

create policy businesses_select on profile.businesses
  for select using (account_id = platform.current_account_id());
create policy businesses_insert on profile.businesses
  for insert with check (account_id = platform.current_account_id());
create policy businesses_update on profile.businesses
  for update
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

grant select, insert, update on profile.businesses to hivorr_api;
grant select on profile.businesses to hivorr_readonly;
