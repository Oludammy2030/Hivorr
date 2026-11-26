-- Paystack collection accounts and clearing-account provisioning (EP-02-042).
--
-- One dedicated virtual account per account/provider. The row stores only the
-- bank-issued account details and the owner user; it holds no secret. The
-- webhook matches a deposit by this account number or the Paystack customer
-- code, then posts the ledger entry idempotently.

set local lock_timeout = '5s';

create table finance.collection_accounts (
  id uuid primary key default platform.uuidv7(),
  account_id uuid not null references identity.accounts (id) on delete restrict,
  owner_user_id uuid not null references identity.users (id) on delete restrict,
  provider text not null default 'paystack' check (provider in ('paystack')),
  reference text not null unique check (length(btrim(reference)) between 3 and 120),
  provider_customer_code text,
  account_number text not null unique check (account_number ~ '^[0-9]{10}$'),
  account_name text not null check (length(btrim(account_name)) between 1 and 160),
  bank_name text,
  currency text not null default 'NGN' check (currency ~ '^[A-Z]{3}$'),
  status text not null default 'active' check (status in ('active', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, provider)
);

comment on table finance.collection_accounts is
  'Dedicated virtual account for wallet funding. It stores no provider secret; the webhook matches a deposit by account number or customer code.';

create index collection_accounts_account_idx
  on finance.collection_accounts (account_id, status);

alter table finance.collection_accounts enable row level security;

create policy collection_accounts_select on finance.collection_accounts
  for select to hivorr_api
  using (account_id = platform.current_account_id());

create policy collection_accounts_insert on finance.collection_accounts
  for insert to hivorr_api
  with check (
    account_id = platform.current_account_id()
    and owner_user_id = platform.current_user_id()
  );

grant select, insert on finance.collection_accounts to hivorr_api;

-- The platform clearing account is the counterparty for a deposit. Extend the
-- narrow provisioning function; wallet and payout-payable behaviour is unchanged.
create or replace function finance.ensure_ledger_account(
  p_kind text,
  p_owner_type text,
  p_owner_id uuid,
  p_currency text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if platform.current_account_id() is null then
    raise exception 'ledger_context_missing' using errcode = '42501';
  end if;

  if p_currency is null or p_currency !~ '^[A-Z]{3}$' then
    raise exception 'ledger_currency_invalid' using errcode = '22023';
  end if;

  if p_kind = 'user_wallet' then
    if p_owner_type <> 'account'
       or p_owner_id is null
       or p_owner_id is distinct from platform.current_account_id() then
      raise exception 'ledger_wallet_owner_invalid' using errcode = '42501';
    end if;
  elsif p_kind = 'payout_payable' then
    if p_owner_type <> 'platform' or p_owner_id is not null then
      raise exception 'ledger_platform_owner_invalid' using errcode = '22023';
    end if;
  elsif p_kind = 'platform_clearing' then
    if p_owner_type <> 'platform' or p_owner_id is not null then
      raise exception 'ledger_platform_owner_invalid' using errcode = '22023';
    end if;
  else
    raise exception 'ledger_kind_unsupported' using errcode = '22023';
  end if;

  insert into finance.ledger_accounts (kind, owner_type, owner_id, currency)
  values (p_kind, p_owner_type, p_owner_id, p_currency)
  on conflict do nothing;

  select la.id into v_id
    from finance.ledger_accounts la
   where la.kind = p_kind
     and la.owner_type = p_owner_type
     and la.owner_id is not distinct from p_owner_id
     and la.currency = p_currency;

  if v_id is null then
    raise exception 'ledger_account_missing' using errcode = 'P0002';
  end if;

  return v_id;
end;
$$;

revoke all on function finance.ensure_ledger_account(text, text, uuid, text) from public;
grant execute on function finance.ensure_ledger_account(text, text, uuid, text) to hivorr_api;
