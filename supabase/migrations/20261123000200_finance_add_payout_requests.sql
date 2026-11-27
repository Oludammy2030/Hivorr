-- Payout request and eligibility record (EP-02-053, first increment).
--
-- This migration adds the durable request row and its reads only. It does not
-- move money, call a provider or approve anything:
--
--   * an account owner may insert a request against one of its own payout
--     destinations, in `REQUESTED` only;
--   * the owner may read its own requests;
--   * no update, delete or status transition is granted. Execution, the
--     reserve/reversal postings and the manual-payout maker-checker arrive in
--     later increments, through security-definer functions.
--
-- The status vocabulary is the approved `PAYOUT_STATES` contract. `APPROVED`
-- exists for the manual path; the automatic path will move `REQUESTED` to
-- `RESERVED` when execution lands.

set local lock_timeout = '5s';

create table finance.payout_requests (
  id uuid primary key default platform.uuidv7(),
  reference text not null unique check (reference ~ '^PAY-[A-Z0-9]{10,24}$'),
  account_id uuid not null references identity.accounts (id) on delete restrict,
  payout_account_id uuid not null
    references finance.payout_accounts (id) on delete restrict,
  amount numeric(20, 4) not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  status text not null default 'REQUESTED' check (status in (
    'REQUESTED',
    'APPROVED',
    'RESERVED',
    'PROCESSING',
    'PAID',
    'FAILED',
    'CANCELLED'
  )),
  idempotency_key text not null check (
    length(btrim(idempotency_key)) between 8 and 200
  ),
  requested_by uuid not null references identity.users (id) on delete restrict,
  approved_by uuid references identity.users (id) on delete restrict,
  provider text,
  provider_reference text,
  failure_code text,
  failure_message text,
  journal_entry_id uuid
    references finance.journal_entries (id) on delete restrict,
  reversal_entry_id uuid
    references finance.journal_entries (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (account_id, idempotency_key),
  check (approved_by is null or approved_by <> requested_by),
  check (
    status <> 'PAID'
    or (provider_reference is not null and completed_at is not null)
  ),
  check (status <> 'FAILED' or failure_code is not null)
);

comment on table finance.payout_requests is
  'A payout request and its eligibility record. The row starts in REQUESTED; no status transition is granted until execution and manual approval land.';

comment on column finance.payout_requests.payout_account_id is
  'The bound, verified destination. The account number remains encrypted in finance.payout_accounts.';

comment on column finance.payout_requests.idempotency_key is
  'Client key, unique per account. A replay returns the existing request; a changed amount or destination is a conflict.';

comment on column finance.payout_requests.status is
  'Approved PAYOUT_STATES. APPROVED is reserved for the manual maker-checker path; the automatic path will use REQUESTED -> RESERVED -> PROCESSING -> PAID/FAILED.';

create index payout_requests_account_idx
  on finance.payout_requests (account_id, created_at desc);

create index payout_requests_status_idx
  on finance.payout_requests (status, created_at)
  where status in ('REQUESTED', 'APPROVED', 'RESERVED', 'PROCESSING');

alter table finance.payout_requests enable row level security;

create policy payout_requests_select on finance.payout_requests
  for select to hivorr_api
  using (account_id = platform.current_account_id());

create policy payout_requests_insert on finance.payout_requests
  for insert to hivorr_api
  with check (
    account_id = platform.current_account_id()
    and requested_by = platform.current_user_id()
    and status = 'REQUESTED'
    and approved_by is null
    and provider is null
    and provider_reference is null
    and journal_entry_id is null
    and reversal_entry_id is null
    and completed_at is null
  );

grant select, insert on finance.payout_requests to hivorr_api;
