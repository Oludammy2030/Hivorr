-- Payout-account write path (EP-02-050, partial increment).
--
-- The ledger migration created finance.payout_accounts and its owner-scoped
-- read. This migration adds the binding write:
--
--   * an owner may insert a destination, and only as `verified`, because the
--     service writes the row only after the provider name matches the verified
--     legal name;
--   * an owner may disable a destination and change nothing else, so the
--     encrypted bank details are immutable once bound;
--   * delete is refused, so a bound destination is disabled rather than erased.
--
-- Payout execution and payer-name matching are not part of this increment.

set local lock_timeout = '5s';

create function private.validate_payout_account_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'verified' or new.verified_at is null then
      raise exception 'payout_account_must_be_verified' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.status <> 'disabled' then
    raise exception 'payout_account_update_forbidden' using errcode = '42501';
  end if;

  if old.status = 'disabled' then
    raise exception 'payout_account_already_disabled' using errcode = '23514';
  end if;

  if new.account_id is distinct from old.account_id
     or new.bank_code is distinct from old.bank_code
     or new.bank_name is distinct from old.bank_name
     or new.account_name is distinct from old.account_name
     or new.account_name_normalized is distinct from old.account_name_normalized
     or new.account_number_ciphertext is distinct from old.account_number_ciphertext
     or new.encryption_key_id is distinct from old.encryption_key_id
     or new.account_number_last4 is distinct from old.account_number_last4
     or new.account_number_fingerprint is distinct from old.account_number_fingerprint
     or new.provider_reference is distinct from old.provider_reference
     or new.verified_at is distinct from old.verified_at
     or new.created_at is distinct from old.created_at then
    raise exception 'payout_account_immutable' using errcode = '42501';
  end if;

  return new;
end;
$$;

create function private.reject_payout_account_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'payout_account_delete_forbidden' using errcode = '42501';
end;
$$;

create trigger payout_accounts_validate_write
before insert or update
on finance.payout_accounts
for each row execute function private.validate_payout_account_write();

create trigger payout_accounts_no_delete
before delete
on finance.payout_accounts
for each row execute function private.reject_payout_account_delete();

create policy payout_accounts_insert on finance.payout_accounts
  for insert to hivorr_api
  with check (account_id = platform.current_account_id());

create policy payout_accounts_update on finance.payout_accounts
  for update to hivorr_api
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

grant insert, update on finance.payout_accounts to hivorr_api;
