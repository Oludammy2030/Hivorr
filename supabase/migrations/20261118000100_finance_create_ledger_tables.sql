-- Ledger and financial integrity foundation (EP-02-030).
--
-- The ledger is the source of truth for Hivorr's internal obligations:
--
--   finance.ledger_accounts     one account per owner, kind and currency
--   finance.journal_entries     append-only entry header
--   finance.postings            append-only debit/credit lines
--   finance.provider_references provider identifiers linked to an entry
--   finance.escrow_accounts     internal escrow reservation metadata
--   finance.payout_accounts     bound destination accounts (encrypted)
--   finance.limits              effective-dated financial limits
--   finance.reconciliation_runs provider-vs-ledger settlement runs
--   finance.reconciliation_items differences found by a run
--
-- Deliberate omissions, because the rule is not decided yet:
--   * no mutable balance column anywhere; wallet figures are derived views;
--   * no fee, split, commission, refund or escrow-release calculation;
--   * no marketplace transaction flow and no foreign key into a transaction
--     table that does not exist yet;
--   * no currency is enabled by default (currency model is still open).
--
-- Money is numeric(20, 4) with an explicit currency. Corrections are reversing
-- entries; update and delete are refused by trigger, not only by grant.
--
-- Bank details: finance.payout_accounts stores only an AES-256-GCM ciphertext
-- envelope (account_number_ciphertext), the key version (encryption_key_id), the
-- last four digits for display and an HMAC-SHA256 fingerprint for uniqueness and
-- lookup. The plaintext account number never enters the database, an audit
-- summary, a log or an API projection. Encryption and decryption happen in the
-- API process with a key from the managed secret store; the fingerprint key is
-- separate from the encryption key.
--
-- This migration creates the schema and its reads only. Posting, escrow,
-- idempotency, limit and reconciliation write paths arrive in EP-02-031 to
-- EP-02-056, so no application role receives insert, update or delete here.
-- Scoped administrator reads arrive with the audited read functions in
-- EP-02-056; a blanket policy would be an unaudited bulk read.

-- destructive-approved: the truncate guards below only create triggers that
-- reject TRUNCATE on ledger tables; no row, table or column is destroyed.

set local lock_timeout = '5s';

create table finance.ledger_accounts (
  id uuid primary key default platform.uuidv7(),
  kind text not null check (kind in (
    'user_wallet',
    'escrow',
    'platform_clearing',
    'fee_revenue',
    'payout_payable',
    'commission_payable',
    'adjustment'
  )),
  owner_type text not null check (owner_type in ('account', 'activity', 'platform')),
  owner_id uuid,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (kind = 'user_wallet' and owner_type = 'account' and owner_id is not null)
    or (kind = 'escrow' and owner_type = 'activity' and owner_id is not null)
    or (
      kind in (
        'platform_clearing',
        'fee_revenue',
        'payout_payable',
        'commission_payable',
        'adjustment'
      )
      and owner_type = 'platform'
      and owner_id is null
    )
  )
);

comment on table finance.ledger_accounts is
  'Ledger account per owner, kind and currency. No balance is stored here; balances are derived from postings.';

comment on column finance.ledger_accounts.kind is
  'Approved account kinds from ARCHITECTURE.md 9.10 and PAYMENT-WALLET-ESCROW-ARCHITECTURE.md 2.';

comment on column finance.ledger_accounts.owner_id is
  'Account id for user_wallet, activity record id for escrow, null for platform accounts.';

create unique index ledger_accounts_owned_idx
  on finance.ledger_accounts (kind, owner_type, owner_id, currency)
  where owner_type <> 'platform';

create unique index ledger_accounts_platform_idx
  on finance.ledger_accounts (kind, currency)
  where owner_type = 'platform';

create index ledger_accounts_owner_account_idx
  on finance.ledger_accounts (owner_id, currency)
  where owner_type = 'account';

create index ledger_accounts_owner_activity_idx
  on finance.ledger_accounts (owner_id)
  where owner_type = 'activity';

create table finance.journal_entries (
  id uuid primary key default platform.uuidv7(),
  kind text not null check (kind in (
    'deposit',
    'withdrawal',
    'escrow_hold',
    'escrow_release',
    'escrow_refund',
    'payout',
    'payout_reversal',
    'adjustment',
    'reversal'
  )),
  reference text not null check (length(btrim(reference)) between 3 and 64),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  activity_id text check (activity_id in (
    'market.buy',
    'services.hire',
    'errands.request',
    'market.sell',
    'services.offer',
    'logistics.provide'
  )),
  idempotency_key text check (
    idempotency_key is null
    or length(btrim(idempotency_key)) between 8 and 200
  ),
  reverses_entry_id uuid references finance.journal_entries (id) on delete restrict,
  created_by uuid references identity.users (id) on delete restrict,
  correlation_id text,
  created_at timestamptz not null default now(),
  check ((kind = 'reversal') = (reverses_entry_id is not null)),
  check (reverses_entry_id is null or reverses_entry_id <> id)
);

comment on table finance.journal_entries is
  'Append-only journal entry header. Correction is a reversal entry, never an update or delete.';

comment on column finance.journal_entries.activity_id is
  'Optional activity attribution so a statement can be read per activity without fragmenting the balance.';

comment on column finance.journal_entries.reverses_entry_id is
  'Set only when kind = reversal; points at the entry being corrected.';

create unique index journal_entries_reference_idx
  on finance.journal_entries (reference);

create unique index journal_entries_idempotency_idx
  on finance.journal_entries (idempotency_key)
  where idempotency_key is not null;

create index journal_entries_activity_idx
  on finance.journal_entries (activity_id, created_at)
  where activity_id is not null;

create index journal_entries_reverses_idx
  on finance.journal_entries (reverses_entry_id)
  where reverses_entry_id is not null;

create table finance.postings (
  id uuid primary key default platform.uuidv7(),
  entry_id uuid not null references finance.journal_entries (id) on delete restrict,
  ledger_account_id uuid not null references finance.ledger_accounts (id) on delete restrict,
  direction text not null check (direction in ('debit', 'credit')),
  amount numeric(20, 4) not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  activity_id text check (activity_id in (
    'market.buy',
    'services.hire',
    'errands.request',
    'market.sell',
    'services.offer',
    'logistics.provide'
  )),
  created_at timestamptz not null default now()
);

comment on table finance.postings is
  'Append-only debit/credit lines. Every entry must balance to zero per currency before the transaction commits.';

comment on column finance.postings.direction is
  'debit increases the account; credit decreases it. Entry balance is sum(debit) - sum(credit) = 0.';

create index postings_entry_idx on finance.postings (entry_id);
create index postings_account_idx
  on finance.postings (ledger_account_id, created_at);
create index postings_activity_idx
  on finance.postings (activity_id)
  where activity_id is not null;

create function private.reject_ledger_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'financial_record_append_only' using errcode = '42501';
end;
$$;

create function private.reject_ledger_truncate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'financial_record_append_only' using errcode = '42501';
end;
$$;

create function private.validate_posting()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry_currency text;
  v_account_currency text;
  v_account_active boolean;
begin
  select currency into v_entry_currency
    from finance.journal_entries
   where id = new.entry_id;

  if not found then
    raise exception 'journal_entry_missing' using errcode = '23503';
  end if;

  if new.currency <> v_entry_currency then
    raise exception 'posting_currency_mismatch' using errcode = '23514';
  end if;

  select currency, is_active into v_account_currency, v_account_active
    from finance.ledger_accounts
   where id = new.ledger_account_id;

  if not found then
    raise exception 'ledger_account_missing' using errcode = '23503';
  end if;

  if not v_account_active then
    raise exception 'ledger_account_inactive' using errcode = '23514';
  end if;

  if new.currency <> v_account_currency then
    raise exception 'ledger_account_currency_mismatch' using errcode = '23514';
  end if;

  return new;
end;
$$;

create function private.assert_journal_entry_balanced()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry_id uuid;
  v_posting_count integer;
  v_total numeric;
begin
  if tg_table_name = 'journal_entries' then
    v_entry_id := new.id;
  elsif tg_op = 'DELETE' then
    v_entry_id := old.entry_id;
  else
    v_entry_id := new.entry_id;
  end if;

  select count(*)::integer,
         coalesce(sum(case direction when 'debit' then amount else -amount end), 0)
    into v_posting_count, v_total
    from finance.postings
   where entry_id = v_entry_id;

  if v_posting_count < 2 then
    raise exception 'journal_entry_requires_two_postings' using errcode = '23514';
  end if;

  if v_total <> 0 then
    raise exception 'journal_entry_unbalanced' using errcode = '23514';
  end if;

  return null;
end;
$$;

create trigger postings_validate
before insert or update
on finance.postings
for each row execute function private.validate_posting();

create constraint trigger postings_balance
after insert or update or delete
on finance.postings
deferrable initially deferred
for each row execute function private.assert_journal_entry_balanced();

create constraint trigger journal_entries_balance
after insert
on finance.journal_entries
deferrable initially deferred
for each row execute function private.assert_journal_entry_balanced();

create trigger journal_entries_no_mutation
before update or delete
on finance.journal_entries
for each row execute function private.reject_ledger_mutation();

create trigger postings_no_mutation
before update or delete
on finance.postings
for each row execute function private.reject_ledger_mutation();

create trigger journal_entries_no_truncate
before truncate
on finance.journal_entries
for each statement execute function private.reject_ledger_truncate();

create trigger postings_no_truncate
before truncate
on finance.postings
for each statement execute function private.reject_ledger_truncate();

create table finance.provider_references (
  id uuid primary key default platform.uuidv7(),
  provider text not null check (provider ~ '^[a-z][a-z0-9_-]{1,39}$'),
  provider_reference text not null check (
    length(btrim(provider_reference)) between 1 and 200
  ),
  direction text not null check (direction in ('deposit', 'payout', 'refund')),
  status text not null check (
    status in ('received', 'verified', 'posted', 'failed', 'reversed')
  ),
  amount numeric(20, 4) not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  journal_entry_id uuid references finance.journal_entries (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_reference),
  check (status <> 'posted' or journal_entry_id is not null)
);

comment on table finance.provider_references is
  'Provider identifier for a deposit, payout or refund, traceable to the journal entry it produced.';

create index provider_references_entry_idx
  on finance.provider_references (journal_entry_id)
  where journal_entry_id is not null;

create index provider_references_status_idx
  on finance.provider_references (provider, status, created_at);

create table finance.escrow_accounts (
  id uuid primary key default platform.uuidv7(),
  ledger_account_id uuid not null unique
    references finance.ledger_accounts (id) on delete restrict,
  payer_account_id uuid not null references identity.accounts (id) on delete restrict,
  activity_id text not null check (activity_id in (
    'market.buy',
    'services.hire',
    'errands.request'
  )),
  activity_ref uuid not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  state text not null default 'held' check (state in (
    'held',
    'released',
    'refunded',
    'disputed',
    'cancelled'
  )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (activity_id, activity_ref, currency),
  check ((state in ('released', 'refunded', 'cancelled')) = (resolved_at is not null))
);

comment on table finance.escrow_accounts is
  'Internal escrow reservation metadata. The held amount is derived from postings; no amount is stored here. Transitions and release policy are EP-02-033 and BD-D03.';

comment on column finance.escrow_accounts.activity_id is
  'Escrow is reserved against one activity: Buy, Hire or Errand.';

create index escrow_accounts_payer_idx
  on finance.escrow_accounts (payer_account_id, currency);

create function private.validate_escrow_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind text;
  v_owner_id uuid;
  v_currency text;
begin
  select kind, owner_id, currency
    into v_kind, v_owner_id, v_currency
    from finance.ledger_accounts
   where id = new.ledger_account_id;

  if not found then
    raise exception 'ledger_account_missing' using errcode = '23503';
  end if;

  if v_kind <> 'escrow' then
    raise exception 'escrow_ledger_account_kind_invalid' using errcode = '23514';
  end if;

  if v_owner_id <> new.activity_ref then
    raise exception 'escrow_ledger_account_owner_mismatch' using errcode = '23514';
  end if;

  if v_currency <> new.currency then
    raise exception 'escrow_ledger_account_currency_mismatch' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger escrow_accounts_validate
before insert or update of ledger_account_id, activity_ref, currency
on finance.escrow_accounts
for each row execute function private.validate_escrow_account();

create table finance.payout_accounts (
  id uuid primary key default platform.uuidv7(),
  account_id uuid not null references identity.accounts (id) on delete restrict,
  bank_code text not null check (bank_code ~ '^[0-9]{3,10}$'),
  bank_name text not null check (length(btrim(bank_name)) between 1 and 120),
  account_name text not null check (length(btrim(account_name)) between 1 and 160),
  account_name_normalized text not null check (
    length(btrim(account_name_normalized)) between 1 and 160
  ),
  account_number_ciphertext bytea not null check (
    octet_length(account_number_ciphertext) >= 28
  ),
  encryption_key_id text not null check (
    length(btrim(encryption_key_id)) between 1 and 120
  ),
  account_number_last4 text not null check (account_number_last4 ~ '^[0-9]{4}$'),
  account_number_fingerprint text not null check (
    account_number_fingerprint ~ '^[0-9a-f]{64}$'
  ),
  status text not null default 'pending' check (status in (
    'pending',
    'verified',
    'rejected',
    'disabled'
  )),
  provider_reference text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'verified' or verified_at is not null)
);

comment on table finance.payout_accounts is
  'Bound, pre-verified payout destination. The account number is stored only as an AES-256-GCM ciphertext envelope; the plaintext is never persisted or projected.';

comment on column finance.payout_accounts.account_number_ciphertext is
  'AES-256-GCM ciphertext with a versioned key. Encrypt and decrypt in the API process only; never log the ciphertext or the plaintext.';

comment on column finance.payout_accounts.encryption_key_id is
  'Key version used for this ciphertext, resolved from the managed secret store.';

comment on column finance.payout_accounts.account_number_fingerprint is
  'HMAC-SHA256 of the normalised account number under a separate key. Used for uniqueness and lookup; not reversible.';

comment on column finance.payout_accounts.account_name_normalized is
  'Case-folded, whitespace-normalised account name used for payer-name and name-enquiry comparison.';

comment on column finance.payout_accounts.account_number_last4 is
  'The only account-number material allowed in a projection or an audit summary.';

create unique index payout_accounts_active_idx
  on finance.payout_accounts (account_id, bank_code, account_number_fingerprint)
  where status <> 'disabled';

create index payout_accounts_account_idx
  on finance.payout_accounts (account_id, status);

create table finance.limits (
  id uuid primary key default platform.uuidv7(),
  tier text check (tier ~ '^tier_[0-9]{1,2}$'),
  account_id uuid references identity.accounts (id) on delete restrict,
  limit_type text not null check (limit_type in (
    'deposit',
    'withdrawal',
    'payout',
    'wallet_balance'
  )),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  amount numeric(20, 4) not null check (amount >= 0),
  period text not null check (period in (
    'per_transaction',
    'daily',
    'weekly',
    'monthly'
  )),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_by uuid references identity.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  check ((tier is null) <> (account_id is null)),
  check (effective_to is null or effective_to > effective_from)
);

comment on table finance.limits is
  'Effective-dated financial limits per KYC tier or per account override. The numbers are configuration, never code. tier_0 has no positive limit (EP-02-035).';

comment on column finance.limits.tier is
  'Tier key such as tier_1. The ladder itself is still open; this column does not invent it.';

create unique index limits_scope_idx on finance.limits (
  coalesce(tier, ''),
  coalesce(account_id, '00000000-0000-0000-0000-000000000000'::uuid),
  limit_type,
  period,
  currency,
  effective_from
);

create index limits_account_idx
  on finance.limits (account_id, effective_from)
  where account_id is not null;

create index limits_tier_idx
  on finance.limits (tier, effective_from)
  where tier is not null;

create table finance.reconciliation_runs (
  id uuid primary key default platform.uuidv7(),
  provider text not null check (provider ~ '^[a-z][a-z0-9_-]{1,39}$'),
  period_start timestamptz not null,
  period_end timestamptz not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  provider_total numeric(20, 4) not null,
  ledger_total numeric(20, 4) not null,
  difference numeric(20, 4) generated always as (
    provider_total - ledger_total
  ) stored,
  status text not null check (status in (
    'running',
    'matched',
    'mismatch',
    'resolved'
  )),
  owner_user_id uuid references identity.users (id) on delete restrict,
  notes text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (provider, period_start, period_end, currency),
  check (period_end > period_start),
  check ((status = 'running') = (completed_at is null))
);

comment on table finance.reconciliation_runs is
  'Provider-vs-ledger settlement comparison. A non-zero difference is an incident with a named owner, not a rounding note.';

create table finance.reconciliation_items (
  id uuid primary key default platform.uuidv7(),
  run_id uuid not null references finance.reconciliation_runs (id) on delete restrict,
  provider_reference text,
  journal_entry_id uuid references finance.journal_entries (id) on delete restrict,
  item_type text not null check (item_type in (
    'missing_in_ledger',
    'missing_at_provider',
    'amount_mismatch',
    'duplicate',
    'other'
  )),
  provider_amount numeric(20, 4),
  ledger_amount numeric(20, 4),
  difference numeric(20, 4) generated always as (
    coalesce(provider_amount, 0) - coalesce(ledger_amount, 0)
  ) stored,
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (provider_reference is not null or journal_entry_id is not null)
);

comment on table finance.reconciliation_items is
  'One difference found by a reconciliation run, with optional resolution. Items are evidence and are not deleted.';

create index reconciliation_items_run_idx
  on finance.reconciliation_items (run_id, created_at);

create index reconciliation_items_entry_idx
  on finance.reconciliation_items (journal_entry_id)
  where journal_entry_id is not null;

alter table finance.ledger_accounts enable row level security;
alter table finance.journal_entries enable row level security;
alter table finance.postings enable row level security;
alter table finance.provider_references enable row level security;
alter table finance.escrow_accounts enable row level security;
alter table finance.payout_accounts enable row level security;
alter table finance.limits enable row level security;
alter table finance.reconciliation_runs enable row level security;
alter table finance.reconciliation_items enable row level security;

create policy ledger_accounts_select on finance.ledger_accounts
  for select to hivorr_api
  using (
    owner_type = 'account'
    and owner_id = platform.current_account_id()
  );

create policy postings_select on finance.postings
  for select to hivorr_api
  using (
    exists (
      select 1
        from finance.ledger_accounts a
       where a.id = finance.postings.ledger_account_id
         and a.owner_type = 'account'
         and a.owner_id = platform.current_account_id()
    )
  );

create policy journal_entries_select on finance.journal_entries
  for select to hivorr_api
  using (
    exists (
      select 1
        from finance.postings p
        join finance.ledger_accounts a on a.id = p.ledger_account_id
       where p.entry_id = finance.journal_entries.id
         and a.owner_type = 'account'
         and a.owner_id = platform.current_account_id()
    )
  );

create policy provider_references_select on finance.provider_references
  for select to hivorr_api
  using (
    journal_entry_id is not null
    and exists (
      select 1
        from finance.journal_entries je
       where je.id = finance.provider_references.journal_entry_id
    )
  );

create policy escrow_accounts_select on finance.escrow_accounts
  for select to hivorr_api
  using (payer_account_id = platform.current_account_id());

create policy payout_accounts_select on finance.payout_accounts
  for select to hivorr_api
  using (account_id = platform.current_account_id());

create policy limits_select on finance.limits
  for select to hivorr_api
  using (
    platform.current_account_id() is not null
    and (
      account_id = platform.current_account_id()
      or (account_id is null and tier is not null)
    )
  );

grant select on finance.ledger_accounts to hivorr_api;
grant select on finance.journal_entries to hivorr_api;
grant select on finance.postings to hivorr_api;
grant select on finance.provider_references to hivorr_api;
grant select on finance.escrow_accounts to hivorr_api;
grant select on finance.payout_accounts to hivorr_api;
grant select on finance.limits to hivorr_api;
