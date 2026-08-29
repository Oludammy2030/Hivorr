-- =============================================================================
-- EP-02-04: Financial Integrity Database Schema & Server-Side Enforcement
-- -----------------------------------------------------------------------------
-- Migration: 20260829100004_financial_integrity_schema.sql
-- Depends on: 20260819090001_enforcement_foundation.sql (platform_* helpers)
--             20260819090003_foundational_rpcs.sql (platform_audit_log_add)
--             20260829090003_verification_admin_review_schema.sql
--                  (verification_limits_get, kyc_tiers, entity_kyc_levels)
--             20260821090002_entity_core_tables.sql (entities, entity_profiles)
--
-- EXECUTION MODEL
--   All 18 financial_* RPCs are SECURITY INVOKER. RLS applies inside the body.
--   Entity-facing RPCs are self-scoped via auth.uid(). System/internal RPCs are
--   EXECUTE-granted to service_role only and operate on explicit entity ids.
--
-- ENVELOPE CONTRACT
--   Every RPC returns {success, code, message, data}.
--   PLT000 success; PLT001 auth; PLT003 validation; PLT004 not found;
--   PLT005 conflict; PLT006 insufficient funds (new); PLT999 internal.
--
-- DOUBLE-ENTRY MODEL
--   Every balance mutation writes a financial_transactions row (immutable ledger)
--   plus the matching balance UPDATEs, all inside one function = one transaction.
--
-- RESOLVED DESIGN NOTE (vs. original plan §8.3)
--   Per EP-02-04 implementation decision, `authenticated` IS granted UPDATE on
--   financial_balances balance columns so entity-facing write RPCs (withdraw,
--   convert_currency) can debit/credit balances when invoked by the client JWT.
--   This is safe because there is no REST write path on these tables and RLS
--   self-scopes every write to entity_id = auth.uid(). This mirrors the EP-01
--   entity_profiles pattern (authenticated may UPDATE own rows).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SECTION 1: financial_supported_currencies (reference table)
-- -----------------------------------------------------------------------------
create table if not exists public.financial_supported_currencies (
  currency_code   char(3) primary key check (currency_code ~ '^[A-Z]{3}$'),
  name            text not null check (char_length(btrim(name)) between 1 and 255),
  symbol          text,
  decimal_places  integer not null default 2 check (decimal_places >= 0),
  is_active       boolean not null default true,
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  created_by      uuid default auth.uid()
);

comment on table public.financial_supported_currencies is
  'Reference registry of ISO 4217 currencies supported by the financial engine.';

create index if not exists financial_supported_currencies_active_sort_idx
  on public.financial_supported_currencies (is_active, sort_order);

-- Idempotent seed
insert into public.financial_supported_currencies (currency_code, name, symbol, decimal_places)
values
  ('NGN', 'Nigerian Naira', '₦', 2),
  ('GHS', 'Ghanaian Cedi', '₵', 2),
  ('USD', 'US Dollar', '$', 2),
  ('GBP', 'British Pound', '£', 2)
on conflict (currency_code) do nothing;

-- -----------------------------------------------------------------------------
-- SECTION 2: financial_profiles
-- -----------------------------------------------------------------------------
create table if not exists public.financial_profiles (
  id              uuid primary key default gen_random_uuid(),
  entity_id       uuid not null unique
                  references public.entities(id) on delete cascade,
  status          text not null default 'active'
                  check (status in ('active', 'suspended', 'closed')),
  default_currency char(3) not null default 'NGN'
                  references public.financial_supported_currencies(currency_code),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  created_by      uuid default auth.uid()
);

comment on table public.financial_profiles is
  'Unified per-entity financial identity (one per entity).';

create index if not exists financial_profiles_entity_id_key
  on public.financial_profiles (entity_id);

-- -----------------------------------------------------------------------------
-- SECTION 3: financial_currency_accounts
-- -----------------------------------------------------------------------------
create table if not exists public.financial_currency_accounts (
  id                       uuid primary key default gen_random_uuid(),
  financial_profile_id     uuid not null
                           references public.financial_profiles(id) on delete cascade,
  entity_id                uuid not null
                           references public.entities(id) on delete cascade,
  currency_code            char(3) not null
                           references public.financial_supported_currencies(currency_code),
  account_status           text not null default 'pending'
                           check (account_status in ('pending', 'active', 'suspended', 'closed')),
  receiving_account_number text,
  receiving_bank_name      text,
  provider_reference       text,
  activated_at             timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  created_by               uuid default auth.uid(),
  unique (entity_id, currency_code)
);

comment on table public.financial_currency_accounts is
  'Currency-specific receiving accounts (one per entity per currency).';

create index if not exists financial_currency_accounts_entity_currency_key
  on public.financial_currency_accounts (entity_id, currency_code);
create index if not exists financial_currency_accounts_entity_status_idx
  on public.financial_currency_accounts (entity_id, account_status);

-- -----------------------------------------------------------------------------
-- SECTION 4: financial_balances
-- -----------------------------------------------------------------------------
create table if not exists public.financial_balances (
  id                uuid primary key default gen_random_uuid(),
  financial_profile_id uuid not null
                      references public.financial_profiles(id) on delete cascade,
  entity_id         uuid not null
                      references public.entities(id) on delete cascade,
  currency_code     char(3) not null
                      references public.financial_supported_currencies(currency_code),
  available_balance numeric not null default 0 check (available_balance >= 0),
  held_balance      numeric not null default 0 check (held_balance >= 0),
  pending_balance   numeric not null default 0 check (pending_balance >= 0),
  total_deposited   numeric not null default 0 check (total_deposited >= 0),
  total_withdrawn   numeric not null default 0 check (total_withdrawn >= 0),
  last_transaction_at timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  unique (entity_id, currency_code)
);

comment on table public.financial_balances is
  'Per-entity per-currency balances. All three buckets are non-negative (invariant).';

create index if not exists financial_balances_entity_currency_key
  on public.financial_balances (entity_id, currency_code);
create index if not exists financial_balances_entity_idx
  on public.financial_balances (entity_id);

-- -----------------------------------------------------------------------------
-- SECTION 5: financial_transactions (immutable double-entry ledger)
-- -----------------------------------------------------------------------------
create table if not exists public.financial_transactions (
  id                uuid primary key default gen_random_uuid(),
  financial_profile_id uuid not null
                      references public.financial_profiles(id) on delete restrict,
  entity_id         uuid not null
                      references public.entities(id) on delete restrict,
  transaction_type  text not null
                      check (transaction_type in
                        ('escrow_fund', 'escrow_release', 'escrow_refund',
                         'deposit', 'withdrawal', 'conversion_debit',
                         'conversion_credit', 'fee', 'adjustment')),
  currency_code     char(3) not null
                      references public.financial_supported_currencies(currency_code),
  amount            numeric not null check (amount > 0),
  source_entity_id  uuid references public.entities(id) on delete restrict,
  destination_entity_id uuid references public.entities(id) on delete restrict,
  debit_balance_type  text check (debit_balance_type in ('available', 'held', 'pending')),
  credit_balance_type text check (credit_balance_type in ('available', 'held', 'pending')),
  reference_type    text check (reference_type in ('escrow', 'payout', 'deposit', 'conversion', 'system')),
  reference_id      uuid,
  description       text check (char_length(description) <= 500),
  created_at        timestamptz not null default now(),
  created_by        uuid default auth.uid()
);

comment on table public.financial_transactions is
  'Immutable double-entry ledger. No UPDATE/DELETE grants to any role.';

create index if not exists financial_transactions_entity_created_idx
  on public.financial_transactions (entity_id, created_at desc);
create index if not exists financial_transactions_reference_idx
  on public.financial_transactions (reference_type, reference_id);
create index if not exists financial_transactions_source_idx
  on public.financial_transactions (source_entity_id);
create index if not exists financial_transactions_destination_idx
  on public.financial_transactions (destination_entity_id);

-- -----------------------------------------------------------------------------
-- SECTION 6: financial_escrow
-- -----------------------------------------------------------------------------
create table if not exists public.financial_escrow (
  id                uuid primary key default gen_random_uuid(),
  financial_profile_id uuid not null
                      references public.financial_profiles(id) on delete restrict,
  payer_entity_id   uuid not null
                      references public.entities(id) on delete restrict,
  payee_entity_id   uuid not null
                      references public.entities(id) on delete restrict,
  currency_code     char(3) not null
                      references public.financial_supported_currencies(currency_code),
  total_amount      numeric not null check (total_amount > 0),
  released_amount   numeric not null default 0 check (released_amount >= 0),
  refunded_amount   numeric not null default 0 check (refunded_amount >= 0),
  status            text not null default 'created'
                      check (status in
                        ('created', 'funded', 'partially_released',
                         'released', 'refunded', 'cancelled', 'disputed')),
  funded_at         timestamptz,
  released_at       timestamptz,
  refunded_at       timestamptz,
  external_reference text,
  metadata          jsonb not null default '{}'::jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  check (released_amount + refunded_amount <= total_amount)
);

comment on table public.financial_escrow is
  'Escrow records with lifecycle state machine (see plan §5.4).';

create index if not exists financial_escrow_payer_idx
  on public.financial_escrow (payer_entity_id, status);
create index if not exists financial_escrow_payee_idx
  on public.financial_escrow (payee_entity_id, status);
create index if not exists financial_escrow_status_idx
  on public.financial_escrow (status);

-- -----------------------------------------------------------------------------
-- SECTION 7: financial_escrow_milestones
-- -----------------------------------------------------------------------------
create table if not exists public.financial_escrow_milestones (
  id                uuid primary key default gen_random_uuid(),
  escrow_id         uuid not null
                      references public.financial_escrow(id) on delete cascade,
  milestone_number  integer not null check (milestone_number >= 1),
  title             text not null check (char_length(btrim(title)) between 1 and 255),
  description       text,
  amount            numeric not null check (amount > 0),
  status            text not null default 'pending'
                      check (status in ('pending', 'completed', 'released')),
  completed_at      timestamptz,
  released_at       timestamptz,
  sort_order        integer not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  unique (escrow_id, milestone_number)
);

comment on table public.financial_escrow_milestones is
  'Milestone-based release conditions per escrow.';

create index if not exists financial_escrow_milestones_escrow_idx
  on public.financial_escrow_milestones (escrow_id, sort_order);
create index if not exists financial_escrow_milestones_escrow_number_key
  on public.financial_escrow_milestones (escrow_id, milestone_number);

-- -----------------------------------------------------------------------------
-- SECTION 8: financial_payout_accounts
-- -----------------------------------------------------------------------------
create table if not exists public.financial_payout_accounts (
  id                uuid primary key default gen_random_uuid(),
  entity_id         uuid not null
                      references public.entities(id) on delete cascade,
  currency_code     char(3) not null
                      references public.financial_supported_currencies(currency_code),
  bank_name         text not null check (char_length(btrim(bank_name)) between 1 and 255),
  account_number    text not null check (char_length(btrim(account_number)) between 1 and 50),
  account_name      text not null check (char_length(btrim(account_name)) between 1 and 255),
  is_verified       boolean not null default false,
  verified_at       timestamptz,
  verification_method text,
  is_default        boolean not null default false,
  status            text not null default 'pending'
                      check (status in ('pending', 'active', 'deactivated')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  unique (entity_id, currency_code, account_number)
);

comment on table public.financial_payout_accounts is
  'Bound bank accounts with ownership verification.';

create index if not exists financial_payout_accounts_entity_idx
  on public.financial_payout_accounts (entity_id, status);
create index if not exists financial_payout_accounts_entity_currency_key
  on public.financial_payout_accounts (entity_id, currency_code, account_number);

-- -----------------------------------------------------------------------------
-- SECTION 9: financial_payouts
-- -----------------------------------------------------------------------------
create table if not exists public.financial_payouts (
  id                uuid primary key default gen_random_uuid(),
  entity_id         uuid not null
                      references public.entities(id) on delete restrict,
  payout_account_id uuid not null
                      references public.financial_payout_accounts(id) on delete restrict,
  currency_code     char(3) not null
                      references public.financial_supported_currencies(currency_code),
  amount            numeric not null check (amount > 0),
  fee               numeric not null default 0 check (fee >= 0),
  net_amount        numeric not null check (net_amount >= 0),
  status            text not null default 'pending'
                      check (status in ('pending', 'processing', 'completed', 'failed')),
  external_reference text,
  completed_at      timestamptz,
  failure_reason    text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid()
);

comment on table public.financial_payouts is
  'Withdrawal records to bound payout accounts.';

create index if not exists financial_payouts_entity_status_idx
  on public.financial_payouts (entity_id, status);
create index if not exists financial_payouts_payout_account_idx
  on public.financial_payouts (payout_account_id);

-- -----------------------------------------------------------------------------
-- SECTION 10: financial_deposits
-- -----------------------------------------------------------------------------
create table if not exists public.financial_deposits (
  id                uuid primary key default gen_random_uuid(),
  entity_id         uuid not null
                      references public.entities(id) on delete restrict,
  currency_code     char(3) not null
                      references public.financial_supported_currencies(currency_code),
  amount            numeric not null check (amount > 0),
  payer_name        text,
  name_match_status text not null default 'unverified'
                      check (name_match_status in ('pending', 'matched', 'mismatched', 'unverified')),
  name_match_score  numeric check (name_match_score between 0.0 and 1.0),
  external_reference text,
  status            text not null default 'pending'
                      check (status in ('pending', 'credited', 'flagged', 'reversed')),
  credited_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid()
);

comment on table public.financial_deposits is
  'Incoming payment records with payer-name capture for Rule 3 enforcement.';

create index if not exists financial_deposits_entity_status_idx
  on public.financial_deposits (entity_id, status);
create index if not exists financial_deposits_name_match_idx
  on public.financial_deposits (name_match_status);

-- -----------------------------------------------------------------------------
-- SECTION 11: financial_conversions
-- -----------------------------------------------------------------------------
create table if not exists public.financial_conversions (
  id                uuid primary key default gen_random_uuid(),
  entity_id         uuid not null
                      references public.entities(id) on delete restrict,
  from_currency     char(3) not null
                      references public.financial_supported_currencies(currency_code),
  to_currency       char(3) not null
                      references public.financial_supported_currencies(currency_code),
  from_amount       numeric not null check (from_amount > 0),
  to_amount         numeric not null check (to_amount > 0),
  exchange_rate     numeric not null check (exchange_rate > 0),
  fee               numeric not null default 0 check (fee >= 0),
  status            text not null default 'pending'
                      check (status in ('pending', 'completed', 'failed')),
  completed_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  check (from_currency <> to_currency)
);

comment on table public.financial_conversions is
  'Currency conversion records between supported balances.';

create index if not exists financial_conversions_entity_idx
  on public.financial_conversions (entity_id, created_at desc);

-- -----------------------------------------------------------------------------
-- SECTION 12: financial_audit_trail (append-only)
-- -----------------------------------------------------------------------------
create table if not exists public.financial_audit_trail (
  id                uuid primary key default gen_random_uuid(),
  entity_id         uuid references public.entities(id) on delete set null,
  event_type        text not null,
  subject_type      text
                      check (subject_type in
                        ('profile', 'currency_account', 'balance', 'escrow',
                         'milestone', 'payout_account', 'payout', 'deposit', 'conversion')),
  subject_id        uuid,
  from_state        text,
  to_state          text,
  amount            numeric,
  currency_code     char(3),
  actor_id          uuid,
  details           jsonb not null default '{}'::jsonb,
  created_at        timestamptz not null default now()
);

comment on table public.financial_audit_trail is
  'Authoritative immutable financial audit log (append-only, no UPDATE/DELETE).';

create index if not exists financial_audit_trail_entity_idx
  on public.financial_audit_trail (entity_id);
create index if not exists financial_audit_trail_created_at_idx
  on public.financial_audit_trail (created_at desc);
create index if not exists financial_audit_trail_subject_idx
  on public.financial_audit_trail (subject_type, subject_id);

-- -----------------------------------------------------------------------------
-- SECTION 13: updated_at triggers (10 mutable tables)
-- -----------------------------------------------------------------------------
create trigger financial_supported_currencies_set_updated_at before update on public.financial_supported_currencies
  for each row execute function public.platform_set_updated_at();
create trigger financial_profiles_set_updated_at before update on public.financial_profiles
  for each row execute function public.platform_set_updated_at();
create trigger financial_currency_accounts_set_updated_at before update on public.financial_currency_accounts
  for each row execute function public.platform_set_updated_at();
create trigger financial_balances_set_updated_at before update on public.financial_balances
  for each row execute function public.platform_set_updated_at();
create trigger financial_escrow_set_updated_at before update on public.financial_escrow
  for each row execute function public.platform_set_updated_at();
create trigger financial_escrow_milestones_set_updated_at before update on public.financial_escrow_milestones
  for each row execute function public.platform_set_updated_at();
create trigger financial_payout_accounts_set_updated_at before update on public.financial_payout_accounts
  for each row execute function public.platform_set_updated_at();
create trigger financial_payouts_set_updated_at before update on public.financial_payouts
  for each row execute function public.platform_set_updated_at();
create trigger financial_deposits_set_updated_at before update on public.financial_deposits
  for each row execute function public.platform_set_updated_at();
create trigger financial_conversions_set_updated_at before update on public.financial_conversions
  for each row execute function public.platform_set_updated_at();

-- -----------------------------------------------------------------------------
-- SECTION 14: Deposit payer-name match trigger (Rule 3 enforcement)
-- -----------------------------------------------------------------------------
create or replace function public.financial_deposit_name_match()
returns trigger
language plpgsql
as $$
declare
  v_legal text;
begin
  if new.payer_name is null or btrim(new.payer_name) = '' then
    new.name_match_status := 'unverified';
    new.name_match_score := null;
  else
    select btrim(legal_name) into v_legal
      from public.entity_profiles
     where entity_id = new.entity_id;
    if v_legal is null then
      new.name_match_status := 'unverified';
      new.name_match_score := null;
    elsif lower(btrim(new.payer_name)) = lower(v_legal) then
      new.name_match_status := 'matched';
      new.name_match_score := 1.0;
    else
      new.name_match_status := 'mismatched';
      new.name_match_score := 0.0;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists financial_deposits_name_match_tg on public.financial_deposits;
create trigger financial_deposits_name_match_tg
  before insert or update of payer_name on public.financial_deposits
  for each row execute function public.financial_deposit_name_match();

-- -----------------------------------------------------------------------------
-- SECTION 15: RLS enable + revoke + grants + self-scoped policies (default-deny)
-- -----------------------------------------------------------------------------
alter table public.financial_supported_currencies enable row level security;
alter table public.financial_profiles enable row level security;
alter table public.financial_currency_accounts enable row level security;
alter table public.financial_balances enable row level security;
alter table public.financial_transactions enable row level security;
alter table public.financial_escrow enable row level security;
alter table public.financial_escrow_milestones enable row level security;
alter table public.financial_payout_accounts enable row level security;
alter table public.financial_payouts enable row level security;
alter table public.financial_deposits enable row level security;
alter table public.financial_conversions enable row level security;
alter table public.financial_audit_trail enable row level security;

-- Revoke all blanket privileges (mirrors enforcement_foundation pattern)
revoke all on
  public.financial_supported_currencies,
  public.financial_profiles,
  public.financial_currency_accounts,
  public.financial_balances,
  public.financial_transactions,
  public.financial_escrow,
  public.financial_escrow_milestones,
  public.financial_payout_accounts,
  public.financial_payouts,
  public.financial_deposits,
  public.financial_conversions,
  public.financial_audit_trail
from anon, authenticated, service_role;

-- financial_supported_currencies: public read (authenticated + service_role); service_role write
grant select on public.financial_supported_currencies to authenticated, service_role;
grant insert, update on public.financial_supported_currencies to service_role;

-- financial_profiles: self read/insert (auth); full (service_role)
grant select, insert (entity_id, default_currency) on public.financial_profiles to authenticated;
grant select, insert, update on public.financial_profiles to service_role;

-- financial_currency_accounts: self read/insert (auth); full (service_role)
grant select, insert (entity_id, currency_code) on public.financial_currency_accounts to authenticated;
grant select, insert, update on public.financial_currency_accounts to service_role;

-- financial_balances: self read/insert(limited)/update(authenticated, self-scoped); full (service_role)
grant select,
      insert (financial_profile_id, entity_id, currency_code),
      update (available_balance, held_balance, pending_balance, total_deposited, total_withdrawn, last_transaction_at, updated_at)
  on public.financial_balances to authenticated;
grant select, insert, update, delete on public.financial_balances to service_role;

-- financial_transactions: self read/insert (auth); service_role read/insert (NO update/delete to anyone).
-- RESOLVED: authenticated is granted INSERT so the entity-facing write RPCs
-- (withdraw, convert_currency) can record double-entry ledger rows. Immutability
-- is preserved: no UPDATE/DELETE grant to any role (plan §8.3 / DoD #9).
grant select, insert on public.financial_transactions to authenticated, service_role;

-- financial_escrow: self read (payer/payee) (auth); full (service_role)
grant select on public.financial_escrow to authenticated;
grant select, insert, update on public.financial_escrow to service_role;

-- financial_escrow_milestones: self read via escrow (auth); full (service_role)
grant select on public.financial_escrow_milestones to authenticated;
grant select, insert, update on public.financial_escrow_milestones to service_role;

-- financial_payout_accounts: self read/insert(limited, excludes is_verified/verified_at) (auth); full (service_role)
grant select,
      insert (entity_id, currency_code, bank_name, account_number, account_name),
      update (bank_name, account_number, account_name, status, is_default)
  on public.financial_payout_accounts to authenticated;
grant select, insert, update on public.financial_payout_accounts to service_role;

-- financial_payouts: self read/insert(limited) (auth); full (service_role)
grant select,
      insert (entity_id, payout_account_id, currency_code, amount, fee, net_amount, status)
  on public.financial_payouts to authenticated;
grant select, insert, update on public.financial_payouts to service_role;

-- financial_deposits: self read (auth); full (service_role)
grant select on public.financial_deposits to authenticated;
grant select, insert, update on public.financial_deposits to service_role;

-- financial_conversions: self read/insert(limited) (auth); full (service_role)
grant select,
      insert (entity_id, from_currency, to_currency, from_amount, to_amount, exchange_rate, fee, status)
  on public.financial_conversions to authenticated;
grant select, insert, update on public.financial_conversions to service_role;

-- financial_audit_trail: self read/insert (auth); read/insert (service_role); NO update/delete to anyone
grant select, insert on public.financial_audit_trail to authenticated, service_role;

-- Self-scoped RLS policies (service_role bypasses RLS; these constrain anon/authenticated)
create policy financial_supported_currencies_read on public.financial_supported_currencies
  for select to anon, authenticated using (true);

create policy financial_profiles_select on public.financial_profiles
  for select to authenticated using (entity_id = auth.uid());
create policy financial_profiles_insert on public.financial_profiles
  for insert to authenticated with check (entity_id = auth.uid());

create policy financial_currency_accounts_select on public.financial_currency_accounts
  for select to authenticated using (entity_id = auth.uid());
create policy financial_currency_accounts_insert on public.financial_currency_accounts
  for insert to authenticated with check (entity_id = auth.uid());

create policy financial_balances_select on public.financial_balances
  for select to authenticated using (entity_id = auth.uid());
create policy financial_balances_insert on public.financial_balances
  for insert to authenticated with check (entity_id = auth.uid());
create policy financial_balances_update on public.financial_balances
  for update to authenticated using (entity_id = auth.uid());

create policy financial_transactions_select on public.financial_transactions
  for select to authenticated using (entity_id = auth.uid());
create policy financial_transactions_insert on public.financial_transactions
  for insert to authenticated with check (entity_id = auth.uid());

create policy financial_escrow_select on public.financial_escrow
  for select to authenticated
  using (payer_entity_id = auth.uid() or payee_entity_id = auth.uid());

create policy financial_escrow_milestones_select on public.financial_escrow_milestones
  for select to authenticated
  using (exists (
    select 1 from public.financial_escrow e
     where e.id = escrow_id
       and (e.payer_entity_id = auth.uid() or e.payee_entity_id = auth.uid())
  ));

create policy financial_payout_accounts_select on public.financial_payout_accounts
  for select to authenticated using (entity_id = auth.uid());
create policy financial_payout_accounts_insert on public.financial_payout_accounts
  for insert to authenticated with check (entity_id = auth.uid());
create policy financial_payout_accounts_update on public.financial_payout_accounts
  for update to authenticated using (entity_id = auth.uid());

create policy financial_payouts_select on public.financial_payouts
  for select to authenticated using (entity_id = auth.uid());
create policy financial_payouts_insert on public.financial_payouts
  for insert to authenticated with check (entity_id = auth.uid());

create policy financial_deposits_select on public.financial_deposits
  for select to authenticated using (entity_id = auth.uid());

create policy financial_conversions_select on public.financial_conversions
  for select to authenticated using (entity_id = auth.uid());
create policy financial_conversions_insert on public.financial_conversions
  for insert to authenticated with check (entity_id = auth.uid());

create policy financial_audit_trail_select on public.financial_audit_trail
  for select to authenticated using (entity_id = auth.uid() or entity_id is null);
create policy financial_audit_trail_insert on public.financial_audit_trail
  for insert to authenticated with check (entity_id = auth.uid() or entity_id is null);

-- =============================================================================
-- SECTION 16: RPCs
-- =============================================================================

-- 16.1 financial_profile_create ---------------------------------------------
create or replace function public.financial_profile_create(p_default_currency char(3) default 'NGN')
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_currency char(3) := coalesce(nullif(btrim(p_default_currency), ''), 'NGN');
  v_profile_id uuid;
  v_balance_id uuid;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if not exists (select 1 from public.financial_supported_currencies where currency_code = v_currency) then
    perform public.platform_raise_error('PLT003', 'Default currency is not supported.');
  end if;

  if exists (select 1 from public.financial_profiles where entity_id = v_actor) then
    perform public.platform_raise_error('PLT005', 'A financial profile already exists for this entity.');
  end if;

  begin
    insert into public.financial_profiles (entity_id, default_currency)
    values (v_actor, v_currency)
    returning id into v_profile_id;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'A financial profile already exists for this entity.');
  end;

  insert into public.financial_balances (financial_profile_id, entity_id, currency_code)
  values (v_profile_id, v_actor, v_currency)
  returning id into v_balance_id;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, to_state, currency_code, actor_id)
  values (v_actor, 'profile_created', 'profile', v_profile_id, 'active', v_currency, v_actor);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Financial profile created.',
    'data', jsonb_build_object('profile_id', v_profile_id, 'default_currency', v_currency, 'balance_id', v_balance_id)
  );
end;
$$;

-- 16.2 financial_profile_get -------------------------------------------------
create or replace function public.financial_profile_get()
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_profile record;
  v_accounts jsonb;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  select * into v_profile from public.financial_profiles where entity_id = v_actor;

  select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
    into v_accounts
    from (
      select id, currency_code, account_status, receiving_account_number, receiving_bank_name, activated_at
        from public.financial_currency_accounts
       where entity_id = v_actor
       order by currency_code
    ) t;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Financial profile retrieved.',
    'data', jsonb_build_object('profile', to_jsonb(v_profile), 'currency_accounts', v_accounts)
  );
end;
$$;

-- 16.3 financial_balance_get -------------------------------------------------
create or replace function public.financial_balance_get(p_currency_code char(3))
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_currency char(3) := nullif(btrim(p_currency_code), '');
  v_row public.financial_balances;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  if v_currency is null or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_currency
  ) then
    perform public.platform_raise_error('PLT004', 'Currency is not supported.');
  end if;

  select * into v_row
    from public.financial_balances
   where entity_id = v_actor and currency_code = v_currency;

  if not found then
    v_row := null;
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Balance retrieved.',
    'data', jsonb_build_object(
      'currency_code', v_currency,
      'available_balance', coalesce(v_row.available_balance, 0),
      'held_balance', coalesce(v_row.held_balance, 0),
      'pending_balance', coalesce(v_row.pending_balance, 0)
    )
  );
end;
$$;

-- 16.4 financial_escrow_create ----------------------------------------------
-- RESOLVED SIGNATURE: p_payer_entity_id added (the plan omitted the payer; the
-- payer must be explicit because this RPC is service_role-only and has no
-- auth.uid() context). All downstream escrow RPCs reference this payer.
create or replace function public.financial_escrow_create(
  p_payer_entity_id uuid,
  p_payee_entity_id uuid,
  p_currency_code char(3),
  p_total_amount numeric,
  p_milestones jsonb default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_currency char(3) := nullif(btrim(p_currency_code), '');
  v_profile_id uuid;
  v_escrow_id uuid;
  v_milestone jsonb;
  v_sum numeric := 0;
begin
  if p_payer_entity_id is null then
    perform public.platform_raise_error('PLT003', 'Payer entity is required.');
  end if;
  if p_payee_entity_id is null then
    perform public.platform_raise_error('PLT003', 'Payee entity is required.');
  end if;
  if v_currency is null or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_currency
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;
  if p_total_amount is null or p_total_amount <= 0 then
    perform public.platform_raise_error('PLT003', 'Escrow amount must be greater than zero.');
  end if;

  select id into v_profile_id from public.financial_profiles where entity_id = p_payer_entity_id;
  if v_profile_id is null then
    perform public.platform_raise_error('PLT004', 'Payer financial profile not found.');
  end if;

  if p_milestones is not null and jsonb_typeof(p_milestones) = 'array' then
    for v_milestone in select * from jsonb_array_elements(p_milestones)
    loop
      v_sum := v_sum + coalesce((v_milestone->>'amount')::numeric, 0);
    end loop;
    if v_sum <> p_total_amount then
      perform public.platform_raise_error('PLT003', 'Milestone amounts must sum to the escrow total.');
    end if;
  end if;

  insert into public.financial_escrow (financial_profile_id, payer_entity_id, payee_entity_id, currency_code, total_amount, status)
  values (v_profile_id, p_payer_entity_id, p_payee_entity_id, v_currency, p_total_amount, 'created')
  returning id into v_escrow_id;

  if p_milestones is not null and jsonb_typeof(p_milestones) = 'array' then
    for v_milestone in select * from jsonb_array_elements(p_milestones)
    loop
      insert into public.financial_escrow_milestones (escrow_id, milestone_number, title, description, amount, sort_order)
      values (
        v_escrow_id,
        coalesce((v_milestone->>'milestone_number')::integer, 1),
        v_milestone->>'title',
        v_milestone->>'description',
        (v_milestone->>'amount')::numeric,
        coalesce((v_milestone->>'sort_order')::integer, 0)
      );
    end loop;
  end if;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, to_state, amount, currency_code)
  values (p_payer_entity_id, 'escrow_created', 'escrow', v_escrow_id, 'created', p_total_amount, v_currency);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Escrow created.',
    'data', jsonb_build_object('escrow_id', v_escrow_id, 'total_amount', p_total_amount, 'currency_code', v_currency)
  );
end;
$$;

-- 16.5 financial_escrow_fund ------------------------------------------------
create or replace function public.financial_escrow_fund(p_escrow_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_escrow public.financial_escrow;
  v_balance public.financial_balances;
begin
  if p_escrow_id is null then
    perform public.platform_raise_error('PLT003', 'Escrow id is required.');
  end if;

  select * into v_escrow from public.financial_escrow where id = p_escrow_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;
  if v_escrow.status <> 'created' then
    perform public.platform_raise_error('PLT005', 'Escrow is not in a fundable state.');
  end if;

  select * into v_balance
    from public.financial_balances
   where entity_id = v_escrow.payer_entity_id and currency_code = v_escrow.currency_code
   for update;
  if not found then
    perform public.platform_raise_error('PLT006', 'Insufficient funds to fund escrow.');
  end if;
  if v_balance.available_balance < v_escrow.total_amount then
    perform public.platform_raise_error('PLT006', 'Insufficient funds to fund escrow.');
  end if;

  insert into public.financial_transactions
    (financial_profile_id, entity_id, transaction_type, currency_code, amount,
     source_entity_id, destination_entity_id, debit_balance_type, credit_balance_type,
     reference_type, reference_id, description)
  values
    (v_escrow.financial_profile_id, v_escrow.payer_entity_id, 'escrow_fund', v_escrow.currency_code, v_escrow.total_amount,
     v_escrow.payer_entity_id, v_escrow.payer_entity_id, 'available', 'held',
     'escrow', v_escrow.id, 'Escrow funded');

  update public.financial_balances
     set available_balance = available_balance - v_escrow.total_amount,
         held_balance = held_balance + v_escrow.total_amount,
         last_transaction_at = now(),
         updated_at = now()
   where id = v_balance.id;

  update public.financial_escrow
     set status = 'funded', funded_at = now(), updated_at = now()
   where id = v_escrow.id;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, from_state, to_state, amount, currency_code)
  values (v_escrow.payer_entity_id, 'escrow_funded', 'escrow', v_escrow.id, 'created', 'funded', v_escrow.total_amount, v_escrow.currency_code);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Escrow funded.',
    'data', jsonb_build_object('escrow_id', v_escrow.id, 'status', 'funded', 'amount', v_escrow.total_amount)
  );
end;
$$;

-- 16.6 financial_escrow_release ---------------------------------------------
create or replace function public.financial_escrow_release(p_escrow_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_escrow public.financial_escrow;
  v_release_amount numeric;
begin
  if p_escrow_id is null then
    perform public.platform_raise_error('PLT003', 'Escrow id is required.');
  end if;

  select * into v_escrow from public.financial_escrow where id = p_escrow_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;
  if v_escrow.status not in ('funded', 'partially_released') then
    perform public.platform_raise_error('PLT005', 'Escrow cannot be released in its current state.');
  end if;

  v_release_amount := v_escrow.total_amount - v_escrow.released_amount - v_escrow.refunded_amount;
  if v_release_amount <= 0 then
    perform public.platform_raise_error('PLT005', 'Escrow has no remaining held funds to release.');
  end if;

  insert into public.financial_transactions
    (financial_profile_id, entity_id, transaction_type, currency_code, amount,
     source_entity_id, destination_entity_id, debit_balance_type, credit_balance_type,
     reference_type, reference_id, description)
  values
    (v_escrow.financial_profile_id, v_escrow.payer_entity_id, 'escrow_release', v_escrow.currency_code, v_release_amount,
     v_escrow.payer_entity_id, v_escrow.payee_entity_id, 'held', 'available',
     'escrow', v_escrow.id, 'Escrow released');

  update public.financial_balances
     set held_balance = held_balance - v_release_amount,
         last_transaction_at = now(), updated_at = now()
   where entity_id = v_escrow.payer_entity_id and currency_code = v_escrow.currency_code;

  insert into public.financial_balances
    (financial_profile_id, entity_id, currency_code, available_balance, held_balance, last_transaction_at)
  values
    (v_escrow.payee_entity_id, v_escrow.payee_entity_id, v_escrow.currency_code, v_release_amount, 0, now())
  on conflict (entity_id, currency_code) do update set
    available_balance = financial_balances.available_balance + excluded.available_balance,
    last_transaction_at = now(), updated_at = now();

  update public.financial_escrow
     set released_amount = released_amount + v_release_amount,
         status = 'released', released_at = now(), updated_at = now()
   where id = v_escrow.id;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, from_state, to_state, amount, currency_code)
  values (v_escrow.payee_entity_id, 'escrow_released', 'escrow', v_escrow.id, 'funded', 'released', v_release_amount, v_escrow.currency_code);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Escrow released.',
    'data', jsonb_build_object('escrow_id', v_escrow.id, 'status', 'released', 'released_amount', v_release_amount)
  );
end;
$$;

-- 16.7 financial_escrow_refund ----------------------------------------------
create or replace function public.financial_escrow_refund(p_escrow_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_escrow public.financial_escrow;
  v_refund_amount numeric;
begin
  if p_escrow_id is null then
    perform public.platform_raise_error('PLT003', 'Escrow id is required.');
  end if;

  select * into v_escrow from public.financial_escrow where id = p_escrow_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;
  if v_escrow.status not in ('created', 'funded', 'partially_released', 'disputed') then
    perform public.platform_raise_error('PLT005', 'Escrow cannot be refunded in its current state.');
  end if;

  v_refund_amount := v_escrow.total_amount - v_escrow.released_amount - v_escrow.refunded_amount;
  if v_refund_amount <= 0 then
    perform public.platform_raise_error('PLT005', 'Escrow has no remaining held funds to refund.');
  end if;

  insert into public.financial_transactions
    (financial_profile_id, entity_id, transaction_type, currency_code, amount,
     source_entity_id, destination_entity_id, debit_balance_type, credit_balance_type,
     reference_type, reference_id, description)
  values
    (v_escrow.financial_profile_id, v_escrow.payer_entity_id, 'escrow_refund', v_escrow.currency_code, v_refund_amount,
     v_escrow.payer_entity_id, v_escrow.payer_entity_id, 'held', 'available',
     'escrow', v_escrow.id, 'Escrow refunded');

  update public.financial_balances
     set held_balance = held_balance - v_refund_amount,
         available_balance = available_balance + v_refund_amount,
         last_transaction_at = now(), updated_at = now()
   where entity_id = v_escrow.payer_entity_id and currency_code = v_escrow.currency_code;

  update public.financial_escrow
     set refunded_amount = refunded_amount + v_refund_amount,
         status = 'refunded', refunded_at = now(), updated_at = now()
   where id = v_escrow.id;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, from_state, to_state, amount, currency_code)
  values (v_escrow.payer_entity_id, 'escrow_refunded', 'escrow', v_escrow.id, v_escrow.status, 'refunded', v_refund_amount, v_escrow.currency_code);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Escrow refunded.',
    'data', jsonb_build_object('escrow_id', v_escrow.id, 'status', 'refunded', 'refunded_amount', v_refund_amount)
  );
end;
$$;

-- 16.8 financial_escrow_milestone_complete ---------------------------------
create or replace function public.financial_escrow_milestone_complete(p_milestone_id uuid)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_milestone public.financial_escrow_milestones;
  v_escrow public.financial_escrow;
  v_total integer;
  v_done integer;
begin
  if p_milestone_id is null then
    perform public.platform_raise_error('PLT003', 'Milestone id is required.');
  end if;

  select * into v_milestone from public.financial_escrow_milestones where id = p_milestone_id for update;
  if not found then
    perform public.platform_raise_error('PLT004', 'Milestone not found.');
  end if;
  if v_milestone.status in ('completed', 'released') then
    perform public.platform_raise_error('PLT005', 'Milestone has already been completed.');
  end if;

  select * into v_escrow from public.financial_escrow where id = v_milestone.escrow_id for update;

  update public.financial_escrow_milestones
     set status = 'completed', completed_at = now(), updated_at = now()
   where id = v_milestone.id;

  insert into public.financial_transactions
    (financial_profile_id, entity_id, transaction_type, currency_code, amount,
     source_entity_id, destination_entity_id, debit_balance_type, credit_balance_type,
     reference_type, reference_id, description)
  values
    (v_escrow.financial_profile_id, v_escrow.payer_entity_id, 'escrow_release', v_escrow.currency_code, v_milestone.amount,
     v_escrow.payer_entity_id, v_escrow.payee_entity_id, 'held', 'available',
     'escrow', v_escrow.id, 'Milestone released');

  update public.financial_balances
     set held_balance = held_balance - v_milestone.amount,
         last_transaction_at = now(), updated_at = now()
   where entity_id = v_escrow.payer_entity_id and currency_code = v_escrow.currency_code;

  insert into public.financial_balances
    (financial_profile_id, entity_id, currency_code, available_balance, held_balance, last_transaction_at)
  values
    (v_escrow.payee_entity_id, v_escrow.payee_entity_id, v_escrow.currency_code, v_milestone.amount, 0, now())
  on conflict (entity_id, currency_code) do update set
    available_balance = financial_balances.available_balance + excluded.available_balance,
    last_transaction_at = now(), updated_at = now();

  update public.financial_escrow
     set released_amount = released_amount + v_milestone.amount,
         updated_at = now()
   where id = v_escrow.id;

  select count(*), count(*) filter (where status in ('completed', 'released'))
    into v_total, v_done
    from public.financial_escrow_milestones
   where escrow_id = v_escrow.id;

  if v_done >= v_total then
    update public.financial_escrow set status = 'released', released_at = now(), updated_at = now() where id = v_escrow.id;
    insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, from_state, to_state, amount, currency_code)
    values (v_escrow.payee_entity_id, 'escrow_released', 'escrow', v_escrow.id, 'partially_released', 'released', v_milestone.amount, v_escrow.currency_code);
  else
    update public.financial_escrow set status = 'partially_released', updated_at = now() where id = v_escrow.id;
    insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, from_state, to_state, amount, currency_code)
    values (v_escrow.payee_entity_id, 'escrow_partially_released', 'escrow', v_escrow.id, v_escrow.status, 'partially_released', v_milestone.amount, v_escrow.currency_code);
  end if;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, to_state, amount, currency_code)
  values (v_escrow.payer_entity_id, 'milestone_completed', 'milestone', v_milestone.id, 'completed', v_milestone.amount, v_escrow.currency_code);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Milestone completed.',
    'data', jsonb_build_object('milestone_id', v_milestone.id, 'escrow_id', v_escrow.id, 'escrow_status', v_escrow.status)
  );
end;
$$;

-- 16.9 financial_escrow_get -------------------------------------------------
create or replace function public.financial_escrow_get(p_escrow_id uuid)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_escrow record;
  v_milestones jsonb;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_escrow_id is null then
    perform public.platform_raise_error('PLT003', 'Escrow id is required.');
  end if;

  select * into v_escrow
    from public.financial_escrow
   where id = p_escrow_id
     and (payer_entity_id = v_actor or payee_entity_id = v_actor);
  if not found then
    perform public.platform_raise_error('PLT004', 'Escrow not found.');
  end if;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.sort_order, t.milestone_number), '[]'::jsonb)
    into v_milestones
    from public.financial_escrow_milestones t
   where t.escrow_id = v_escrow.id;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Escrow retrieved.',
    'data', jsonb_build_object('escrow', to_jsonb(v_escrow), 'milestones', v_milestones)
  );
end;
$$;

-- 16.10 financial_payout_account_bind ---------------------------------------
create or replace function public.financial_payout_account_bind(
  p_currency_code char(3),
  p_bank_name text,
  p_account_number text,
  p_account_name text
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_currency char(3) := nullif(btrim(p_currency_code), '');
  v_id uuid;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if v_currency is null or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_currency
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;
  if nullif(btrim(p_bank_name), '') is null then
    perform public.platform_raise_error('PLT003', 'Bank name is required.');
  end if;
  if nullif(btrim(p_account_number), '') is null then
    perform public.platform_raise_error('PLT003', 'Account number is required.');
  end if;
  if nullif(btrim(p_account_name), '') is null then
    perform public.platform_raise_error('PLT003', 'Account name is required.');
  end if;

  begin
    insert into public.financial_payout_accounts (entity_id, currency_code, bank_name, account_number, account_name)
    values (v_actor, v_currency, btrim(p_bank_name), btrim(p_account_number), btrim(p_account_name))
    returning id into v_id;
  exception
    when unique_violation then
      perform public.platform_raise_error('PLT005', 'A payout account with this number already exists.');
  end;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, to_state, currency_code, actor_id)
  values (v_actor, 'payout_account_bound', 'payout_account', v_id, 'pending', v_currency, v_actor);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Payout account bound.',
    'data', jsonb_build_object('payout_account_id', v_id, 'currency_code', v_currency, 'status', 'pending')
  );
end;
$$;

-- 16.11 financial_payout_account_verify -------------------------------------
create or replace function public.financial_payout_account_verify(p_payout_account_id uuid, p_method text)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_account public.financial_payout_accounts;
begin
  if p_payout_account_id is null then
    perform public.platform_raise_error('PLT003', 'Payout account id is required.');
  end if;

  select * into v_account from public.financial_payout_accounts where id = p_payout_account_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Payout account not found.');
  end if;

  update public.financial_payout_accounts
     set is_verified = true,
         verified_at = now(),
         verification_method = nullif(btrim(p_method), ''),
         status = 'active',
         updated_at = now()
   where id = v_account.id;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, to_state, currency_code)
  values (v_account.entity_id, 'payout_account_verified', 'payout_account', v_account.id, 'active', v_account.currency_code);

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Payout account verified.',
    'data', jsonb_build_object('payout_account_id', v_account.id, 'is_verified', true)
  );
end;
$$;

-- 16.12 financial_withdraw --------------------------------------------------
create or replace function public.financial_withdraw(p_payout_account_id uuid, p_amount numeric)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_account public.financial_payout_accounts;
  v_balance public.financial_balances;
  v_profile_id uuid;
  v_cashout_limit numeric;
  v_fee numeric := 0;
  v_net numeric;
  v_payout_id uuid;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if p_amount is null or p_amount <= 0 then
    perform public.platform_raise_error('PLT003', 'Withdrawal amount must be greater than zero.');
  end if;

  select * into v_account
    from public.financial_payout_accounts
   where id = p_payout_account_id and entity_id = v_actor;
  if not found then
    perform public.platform_raise_error('PLT004', 'Payout account not found.');
  end if;
  if not v_account.is_verified then
    perform public.platform_raise_error('PLT003', 'Payout account is not verified.');
  end if;

  select id into v_profile_id from public.financial_profiles where entity_id = v_actor;
  if v_profile_id is null then
    perform public.platform_raise_error('PLT004', 'Financial profile not found.');
  end if;

  select * into v_balance
    from public.financial_balances
   where entity_id = v_actor and currency_code = v_account.currency_code
   for update;
  if not found or v_balance.available_balance < p_amount then
    perform public.platform_raise_error('PLT006', 'Insufficient available balance.');
  end if;

  select coalesce(kt.cashout_limit, 0)
    into v_cashout_limit
    from public.entity_kyc_levels ekl
    join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
   where ekl.entity_id = v_actor;
  v_cashout_limit := coalesce(v_cashout_limit, 0);
  if p_amount > v_cashout_limit then
    perform public.platform_raise_error('PLT006', 'Withdrawal exceeds your cashout limit.');
  end if;

  v_net := p_amount - v_fee;

  insert into public.financial_transactions
    (financial_profile_id, entity_id, transaction_type, currency_code, amount,
     source_entity_id, debit_balance_type, reference_type, description)
  values
    (v_profile_id, v_actor, 'withdrawal', v_account.currency_code, p_amount,
     v_actor, 'available', 'payout', 'Withdrawal initiated');

  update public.financial_balances
     set available_balance = available_balance - p_amount,
         total_withdrawn = total_withdrawn + p_amount,
         last_transaction_at = now(), updated_at = now()
   where id = v_balance.id;

  insert into public.financial_payouts (entity_id, payout_account_id, currency_code, amount, fee, net_amount, status)
  values (v_actor, v_account.id, v_account.currency_code, p_amount, v_fee, v_net, 'pending')
  returning id into v_payout_id;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, amount, currency_code, actor_id)
  values (v_actor, 'payout_initiated', 'payout', v_payout_id, p_amount, v_account.currency_code, v_actor);

  perform public.platform_audit_log_add('financial_withdraw', 'financial_payouts',
    jsonb_build_object('payout_id', v_payout_id, 'amount', p_amount, 'currency_code', v_account.currency_code));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Withdrawal initiated.',
    'data', jsonb_build_object(
      'payout_id', v_payout_id, 'amount', p_amount, 'fee', v_fee, 'net_amount', v_net,
      'cashout_remaining', (v_cashout_limit - p_amount)
    )
  );
end;
$$;

-- 16.13 financial_deposit_record --------------------------------------------
create or replace function public.financial_deposit_record(
  p_entity_id uuid,
  p_currency_code char(3),
  p_amount numeric,
  p_payer_name text default null,
  p_external_reference text default null
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_currency char(3) := nullif(btrim(p_currency_code), '');
  v_profile_id uuid;
  v_deposit public.financial_deposits;
  v_balance public.financial_balances;
begin
  if p_entity_id is null then
    perform public.platform_raise_error('PLT003', 'Entity id is required.');
  end if;
  if v_currency is null or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_currency
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;
  if p_amount is null or p_amount <= 0 then
    perform public.platform_raise_error('PLT003', 'Deposit amount must be greater than zero.');
  end if;

  select id into v_profile_id from public.financial_profiles where entity_id = p_entity_id;
  if v_profile_id is null then
    perform public.platform_raise_error('PLT004', 'Financial profile not found.');
  end if;

  insert into public.financial_deposits (entity_id, currency_code, amount, payer_name, external_reference, status)
  values (p_entity_id, v_currency, p_amount, nullif(btrim(p_payer_name), ''), nullif(btrim(p_external_reference), ''), 'pending')
  returning * into v_deposit;

  if v_deposit.name_match_status = 'matched' then
    insert into public.financial_balances (financial_profile_id, entity_id, currency_code)
    values (v_profile_id, p_entity_id, v_currency)
    on conflict (entity_id, currency_code) do nothing;

    select * into v_balance
      from public.financial_balances
     where entity_id = p_entity_id and currency_code = v_currency
     for update;

    insert into public.financial_transactions
      (financial_profile_id, entity_id, transaction_type, currency_code, amount,
       destination_entity_id, credit_balance_type, reference_type, reference_id, description)
    values
      (v_profile_id, p_entity_id, 'deposit', v_currency, p_amount,
       p_entity_id, 'available', 'deposit', v_deposit.id, 'Deposit credited');

    update public.financial_balances
       set available_balance = available_balance + p_amount,
           total_deposited = total_deposited + p_amount,
           last_transaction_at = now(), updated_at = now()
     where id = v_balance.id;

    update public.financial_deposits
       set status = 'credited', credited_at = now(), updated_at = now()
     where id = v_deposit.id;

    insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, to_state, amount, currency_code)
    values (p_entity_id, 'deposit_credited', 'deposit', v_deposit.id, 'credited', p_amount, v_currency);
  elsif v_deposit.name_match_status = 'mismatched' then
    update public.financial_deposits set status = 'flagged', updated_at = now() where id = v_deposit.id;
    insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, to_state, amount, currency_code)
    values (p_entity_id, 'deposit_flagged', 'deposit', v_deposit.id, 'flagged', p_amount, v_currency);
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Deposit recorded.',
    'data', jsonb_build_object(
      'deposit_id', v_deposit.id, 'status', v_deposit.status,
      'name_match_status', v_deposit.name_match_status, 'amount', p_amount
    )
  );
end;
$$;

-- 16.14 financial_deposit_verify_name ---------------------------------------
create or replace function public.financial_deposit_verify_name(p_deposit_id uuid)
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_deposit public.financial_deposits;
  v_legal text;
  v_status text;
  v_score numeric;
begin
  if p_deposit_id is null then
    perform public.platform_raise_error('PLT003', 'Deposit id is required.');
  end if;

  select * into v_deposit from public.financial_deposits where id = p_deposit_id;
  if not found then
    perform public.platform_raise_error('PLT004', 'Deposit not found.');
  end if;

  if v_deposit.payer_name is null or btrim(v_deposit.payer_name) = '' then
    v_status := 'unverified'; v_score := null;
  else
    select btrim(legal_name) into v_legal from public.entity_profiles where entity_id = v_deposit.entity_id;
    if v_legal is null then
      v_status := 'unverified'; v_score := null;
    elsif lower(btrim(v_deposit.payer_name)) = lower(v_legal) then
      v_status := 'matched'; v_score := 1.0;
    else
      v_status := 'mismatched'; v_score := 0.0;
    end if;
  end if;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Name verification complete.',
    'data', jsonb_build_object('deposit_id', v_deposit.id, 'name_match_status', v_status, 'name_match_score', v_score)
  );
end;
$$;

-- 16.15 financial_convert_currency -----------------------------------------
create or replace function public.financial_convert_currency(
  p_from_currency char(3),
  p_to_currency char(3),
  p_amount numeric,
  p_rate numeric
)
returns jsonb
language plpgsql
security invoker
volatile
as $$
declare
  v_actor uuid := auth.uid();
  v_from char(3) := nullif(btrim(p_from_currency), '');
  v_to char(3) := nullif(btrim(p_to_currency), '');
  v_profile_id uuid;
  v_balance public.financial_balances;
  v_dest_balance public.financial_balances;
  v_to_amount numeric;
  v_fee numeric := 0;
  v_conv_id uuid;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;
  if v_from is null or v_to is null or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_from
  ) or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_to
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;
  if v_from = v_to then
    perform public.platform_raise_error('PLT003', 'Source and destination currencies must differ.');
  end if;
  if p_amount is null or p_amount <= 0 then
    perform public.platform_raise_error('PLT003', 'Conversion amount must be greater than zero.');
  end if;
  if p_rate is null or p_rate <= 0 then
    perform public.platform_raise_error('PLT003', 'Exchange rate must be greater than zero.');
  end if;

  select id into v_profile_id from public.financial_profiles where entity_id = v_actor;
  if v_profile_id is null then
    perform public.platform_raise_error('PLT004', 'Financial profile not found.');
  end if;

  select * into v_balance
    from public.financial_balances
   where entity_id = v_actor and currency_code = v_from
   for update;
  if not found or v_balance.available_balance < p_amount then
    perform public.platform_raise_error('PLT006', 'Insufficient source balance.');
  end if;

  v_to_amount := p_amount * p_rate - v_fee;

  insert into public.financial_balances (financial_profile_id, entity_id, currency_code)
  values (v_profile_id, v_actor, v_to)
  on conflict (entity_id, currency_code) do nothing;

  select * into v_dest_balance
    from public.financial_balances
   where entity_id = v_actor and currency_code = v_to
   for update;

  insert into public.financial_transactions
    (financial_profile_id, entity_id, transaction_type, currency_code, amount,
     source_entity_id, debit_balance_type, reference_type, description)
  values
    (v_profile_id, v_actor, 'conversion_debit', v_from, p_amount,
     v_actor, 'available', 'conversion', 'Currency conversion debit');

  insert into public.financial_transactions
    (financial_profile_id, entity_id, transaction_type, currency_code, amount,
     destination_entity_id, credit_balance_type, reference_type, description)
  values
    (v_profile_id, v_actor, 'conversion_credit', v_to, v_to_amount,
     v_actor, 'available', 'conversion', 'Currency conversion credit');

  update public.financial_balances
     set available_balance = available_balance - p_amount,
         last_transaction_at = now(), updated_at = now()
   where id = v_balance.id;

  update public.financial_balances
     set available_balance = available_balance + v_to_amount,
         last_transaction_at = now(), updated_at = now()
   where id = v_dest_balance.id;

  insert into public.financial_conversions (entity_id, from_currency, to_currency, from_amount, to_amount, exchange_rate, fee, status)
  values (v_actor, v_from, v_to, p_amount, v_to_amount, p_rate, v_fee, 'completed')
  returning id into v_conv_id;

  insert into public.financial_audit_trail (entity_id, event_type, subject_type, subject_id, amount, currency_code, details)
  values (v_actor, 'conversion_executed', 'conversion', v_conv_id, p_amount, v_from,
    jsonb_build_object('from_currency', v_from, 'to_currency', v_to, 'to_amount', v_to_amount));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Currency converted.',
    'data', jsonb_build_object('conversion_id', v_conv_id, 'from_amount', p_amount, 'to_amount', v_to_amount, 'rate', p_rate)
  );
end;
$$;

-- 16.16 financial_status_get ------------------------------------------------
create or replace function public.financial_status_get()
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_actor uuid := auth.uid();
  v_profile public.financial_profiles;
  v_balances jsonb;
  v_active_escrows integer;
  v_cashout_limit numeric;
begin
  if v_actor is null then
    perform public.platform_raise_error('PLT001', 'Authentication required.');
  end if;

  select * into v_profile from public.financial_profiles where entity_id = v_actor;

  select coalesce(jsonb_agg(jsonb_build_object(
    'currency_code', currency_code,
    'available_balance', available_balance,
    'held_balance', held_balance,
    'pending_balance', pending_balance
  ) order by currency_code), '[]'::jsonb)
    into v_balances
    from public.financial_balances
   where entity_id = v_actor;

  select count(*)
    into v_active_escrows
    from public.financial_escrow
   where (payer_entity_id = v_actor or payee_entity_id = v_actor)
     and status in ('created', 'funded', 'partially_released');

  select coalesce(kt.cashout_limit, 0)
    into v_cashout_limit
    from public.entity_kyc_levels ekl
    join public.kyc_tiers kt on kt.tier_code = ekl.tier_code
   where ekl.entity_id = v_actor;

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Financial status retrieved.',
    'data', jsonb_build_object(
      'default_currency', v_profile.default_currency,
      'profile_status', v_profile.status,
      'balances', v_balances,
      'active_escrow_count', coalesce(v_active_escrows, 0),
      'cashout_limit', coalesce(v_cashout_limit, 0)
    )
  );
end;
$$;

-- 16.17 financial_reconcile -------------------------------------------------
create or replace function public.financial_reconcile(p_entity_id uuid, p_currency_code char(3))
returns jsonb
language plpgsql
security invoker
stable
as $$
declare
  v_currency char(3) := nullif(btrim(p_currency_code), '');
  v_balance public.financial_balances;
  v_avail numeric;
  v_held numeric;
  v_pend numeric;
  v_reconciled boolean;
begin
  if p_entity_id is null then
    perform public.platform_raise_error('PLT003', 'Entity id is required.');
  end if;
  if v_currency is null or not exists (
    select 1 from public.financial_supported_currencies where currency_code = v_currency
  ) then
    perform public.platform_raise_error('PLT003', 'Currency is not supported.');
  end if;

  select * into v_balance
    from public.financial_balances
   where entity_id = p_entity_id and currency_code = v_currency;

  select coalesce(sum(amount) filter (where destination_entity_id = p_entity_id and credit_balance_type = 'available' and currency_code = v_currency), 0)
       - coalesce(sum(amount) filter (where source_entity_id = p_entity_id and debit_balance_type = 'available' and currency_code = v_currency), 0),
       coalesce(sum(amount) filter (where destination_entity_id = p_entity_id and credit_balance_type = 'held' and currency_code = v_currency), 0)
       - coalesce(sum(amount) filter (where source_entity_id = p_entity_id and debit_balance_type = 'held' and currency_code = v_currency), 0),
       coalesce(sum(amount) filter (where destination_entity_id = p_entity_id and credit_balance_type = 'pending' and currency_code = v_currency), 0)
       - coalesce(sum(amount) filter (where source_entity_id = p_entity_id and debit_balance_type = 'pending' and currency_code = v_currency), 0)
    into v_avail, v_held, v_pend
    from public.financial_transactions
   where entity_id = p_entity_id and currency_code = v_currency;

  v_reconciled := (coalesce(v_balance.available_balance, 0) = coalesce(v_avail, 0))
              and (coalesce(v_balance.held_balance, 0) = coalesce(v_held, 0))
              and (coalesce(v_balance.pending_balance, 0) = coalesce(v_pend, 0));

  return jsonb_build_object(
    'success', true, 'code', 'PLT000', 'message', 'Reconciliation complete.',
    'data', jsonb_build_object(
      'reconciled', v_reconciled,
      'available', jsonb_build_object('ledger', coalesce(v_avail, 0), 'stored', coalesce(v_balance.available_balance, 0)),
      'held', jsonb_build_object('ledger', coalesce(v_held, 0), 'stored', coalesce(v_balance.held_balance, 0)),
      'pending', jsonb_build_object('ledger', coalesce(v_pend, 0), 'stored', coalesce(v_balance.pending_balance, 0))
    )
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- SECTION 17: EXECUTE grants (revoke from public pseudo-role, then grant)
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema public from public;

-- Entity-facing (authenticated + service_role)
grant execute on function public.financial_profile_create(char(3)) to authenticated, service_role;
grant execute on function public.financial_profile_get() to authenticated, service_role;
grant execute on function public.financial_balance_get(char(3)) to authenticated, service_role;
grant execute on function public.financial_escrow_get(uuid) to authenticated, service_role;
grant execute on function public.financial_payout_account_bind(char(3), text, text, text) to authenticated, service_role;
grant execute on function public.financial_withdraw(uuid, numeric) to authenticated, service_role;
grant execute on function public.financial_convert_currency(char(3), char(3), numeric, numeric) to authenticated, service_role;
grant execute on function public.financial_status_get() to authenticated, service_role;

-- System/internal (service_role only)
grant execute on function public.financial_escrow_create(uuid, uuid, char(3), numeric, jsonb) to service_role;
grant execute on function public.financial_escrow_fund(uuid) to service_role;
grant execute on function public.financial_escrow_release(uuid) to service_role;
grant execute on function public.financial_escrow_refund(uuid) to service_role;
grant execute on function public.financial_escrow_milestone_complete(uuid) to service_role;
grant execute on function public.financial_payout_account_verify(uuid, text) to service_role;
grant execute on function public.financial_deposit_record(uuid, char(3), numeric, text, text) to service_role;
grant execute on function public.financial_deposit_verify_name(uuid) to service_role;
grant execute on function public.financial_reconcile(uuid, char(3)) to service_role;

-- -----------------------------------------------------------------------------
-- SECTION 18: function comments (documentation)
-- -----------------------------------------------------------------------------
comment on function public.financial_profile_create(char(3)) is
  'Create the unified financial profile + default-currency balance for the authenticated entity. Self-scoped; SECURITY INVOKER; VOLATILE. EXECUTE granted to authenticated, service_role.';
comment on function public.financial_profile_get() is
  'Retrieve the authenticated entity financial profile with currency accounts. Self-scoped; SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';
comment on function public.financial_balance_get(char(3)) is
  'Currency-specific balance for the authenticated entity. Self-scoped; SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';
comment on function public.financial_escrow_create(uuid, uuid, char(3), numeric, jsonb) is
  'Create an escrow (with optional milestones) between explicit payer and payee. service_role only; SECURITY INVOKER; VOLATILE.';
comment on function public.financial_escrow_fund(uuid) is
  'Fund an escrow: payer available -> payer held (double-entry). service_role only; SECURITY INVOKER; VOLATILE.';
comment on function public.financial_escrow_release(uuid) is
  'Release held escrow funds to payee available (double-entry). service_role only; SECURITY INVOKER; VOLATILE.';
comment on function public.financial_escrow_refund(uuid) is
  'Refund held escrow funds to payer available (double-entry). service_role only; SECURITY INVOKER; VOLATILE.';
comment on function public.financial_escrow_milestone_complete(uuid) is
  'Mark a milestone completed and release its amount; auto-release when all milestones done. service_role only; SECURITY INVOKER; VOLATILE.';
comment on function public.financial_escrow_get(uuid) is
  'Retrieve escrow + milestones for payer/payee. Self-scoped; SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';
comment on function public.financial_payout_account_bind(char(3), text, text, text) is
  'Bind a bank account for the authenticated entity. Self-scoped; SECURITY INVOKER; VOLATILE. EXECUTE granted to authenticated, service_role.';
comment on function public.financial_payout_account_verify(uuid, text) is
  'Verify payout account ownership. service_role only; SECURITY INVOKER; VOLATILE.';
comment on function public.financial_withdraw(uuid, numeric) is
  'Withdraw to a verified payout account within KYC cashout limit (double-entry). Self-scoped; SECURITY INVOKER; VOLATILE. EXECUTE granted to authenticated, service_role.';
comment on function public.financial_deposit_record(uuid, char(3), numeric, text, text) is
  'Record an incoming deposit; credits balance if payer name matches legal name. service_role only; SECURITY INVOKER; VOLATILE.';
comment on function public.financial_deposit_verify_name(uuid) is
  'Compare deposit payer name against entity legal name. service_role only; SECURITY INVOKER; STABLE.';
comment on function public.financial_convert_currency(char(3), char(3), numeric, numeric) is
  'Convert between balances (double-entry). Self-scoped; SECURITY INVOKER; VOLATILE. EXECUTE granted to authenticated, service_role.';
comment on function public.financial_status_get() is
  'Aggregated financial status for the authenticated entity. Self-scoped; SECURITY INVOKER; STABLE. EXECUTE granted to authenticated, service_role.';
comment on function public.financial_reconcile(uuid, char(3)) is
  'Verify balance table matches transaction ledger sum (tamper detection). service_role only; SECURITY INVOKER; STABLE.';

-- -----------------------------------------------------------------------------
-- SECTION 19: Realtime exclusion (guarded, idempotent)
-- -----------------------------------------------------------------------------
do $$
begin
  -- Realtime exclusion (consistent with EP-01/EP-02-03 pattern): the 12 new
  -- tables must NOT be published. Drop them if a prior/default publication added
  -- them; never add them.
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename in (
         'financial_supported_currencies', 'financial_profiles', 'financial_currency_accounts',
         'financial_balances', 'financial_transactions', 'financial_escrow',
         'financial_escrow_milestones', 'financial_payout_accounts', 'financial_payouts',
         'financial_deposits', 'financial_conversions', 'financial_audit_trail'
       )
  ) then
    alter publication supabase_realtime drop table
      public.financial_supported_currencies, public.financial_profiles, public.financial_currency_accounts,
      public.financial_balances, public.financial_transactions, public.financial_escrow,
      public.financial_escrow_milestones, public.financial_payout_accounts, public.financial_payouts,
      public.financial_deposits, public.financial_conversions, public.financial_audit_trail;
  end if;
end;
$$;
