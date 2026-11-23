-- Payout execution reserve, reversal and status transitions (EP-02-053).
--
-- The request row already exists. This migration adds:
--
--   * a transaction-safe way to obtain the user's wallet ledger account and the
--     platform payout-payable account;
--   * an owner-scoped update path, guarded by a trigger that refuses any
--     transition outside REQUESTED -> RESERVED/PROCESSING -> PAID/FAILED and
--     refuses a change to the request's immutable financial fields;
--   * no delete path and no provider call. The service posts the reserve and the
--     reversal in the same transaction as the request status change.

set local lock_timeout = '5s';

-- The API may not insert wallet or platform ledger accounts directly. This
-- function creates one on demand and returns it; the wallet owner must be the
-- current account, and the payout-payable account is platform-owned.
create function finance.ensure_ledger_account(
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
  if p_currency is null or p_currency !~ '^[A-Z]{3}$' then
    raise exception 'ledger_currency_invalid' using errcode = '22023';
  end if;

  if platform.current_account_id() is null then
    raise exception 'ledger_context_missing' using errcode = '42501';
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

create policy payout_requests_update on finance.payout_requests
  for update to hivorr_api
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

grant update on finance.payout_requests to hivorr_api;

create function private.validate_payout_request_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'REQUESTED' then
      raise exception 'payout_request_insert_status' using errcode = '23514';
    end if;
    if new.approved_by is not null
       or new.provider is not null
       or new.provider_reference is not null
       or new.journal_entry_id is not null
       or new.reversal_entry_id is not null
       or new.completed_at is not null then
      raise exception 'payout_request_insert_fields' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.account_id is distinct from old.account_id
     or new.payout_account_id is distinct from old.payout_account_id
     or new.amount is distinct from old.amount
     or new.currency is distinct from old.currency
     or new.reference is distinct from old.reference
     or new.idempotency_key is distinct from old.idempotency_key
     or new.requested_by is distinct from old.requested_by
     or new.created_at is distinct from old.created_at then
    raise exception 'payout_request_immutable' using errcode = '42501';
  end if;

  if old.status in ('PAID', 'FAILED', 'CANCELLED') then
    raise exception 'payout_request_terminal' using errcode = '23514';
  end if;

  if new.status <> old.status then
    if not (
      (old.status = 'REQUESTED' and new.status in ('RESERVED', 'CANCELLED'))
      or (old.status = 'RESERVED' and new.status = 'PROCESSING')
      or (old.status = 'PROCESSING' and new.status in ('PAID', 'FAILED'))
    ) then
      raise exception 'payout_request_invalid_transition' using errcode = '23514';
    end if;
  end if;

  if new.status in ('RESERVED', 'PROCESSING', 'PAID')
     and new.journal_entry_id is null then
    raise exception 'payout_request_reserve_missing' using errcode = '23514';
  end if;

  if new.status = 'PAID'
     and (new.provider_reference is null or new.completed_at is null) then
    raise exception 'payout_request_paid_incomplete' using errcode = '23514';
  end if;

  if new.status = 'FAILED'
     and (new.failure_code is null or new.completed_at is null) then
    raise exception 'payout_request_failed_incomplete' using errcode = '23514';
  end if;

  if new.status = 'FAILED'
     and old.journal_entry_id is not null
     and new.reversal_entry_id is null then
    raise exception 'payout_request_reversal_missing' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger payout_requests_validate_transition
before insert or update
on finance.payout_requests
for each row execute function private.validate_payout_request_transition();
