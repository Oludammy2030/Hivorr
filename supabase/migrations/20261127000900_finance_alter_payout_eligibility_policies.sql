-- Payout eligibility enforced in the database as well as the service (EP-02-054).
--
-- The service already refuses an unbound destination, an unverified one, a
-- mismatched owner, `tier_0` and an active financial hold. RLS is the second
-- line: a caller that reaches the table directly still cannot write an ineligible
-- payout.
--
-- The policies use the transaction identity context only; no Supabase auth helper and no
-- client-supplied account id.

set local lock_timeout = '5s';

drop policy payout_accounts_insert on finance.payout_accounts;
create policy payout_accounts_insert on finance.payout_accounts
  for insert to hivorr_api
  with check (
    account_id = platform.current_account_id()
    and exists (
      select 1
        from identity.accounts a
       where a.id = platform.current_account_id()
         and a.kyc_tier in ('tier_1', 'tier_2', 'tier_3')
         and a.financial_hold_reason is null
    )
  );

drop policy payout_requests_insert on finance.payout_requests;
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
    -- The destination must be verified and belong to the same account.
    and exists (
      select 1
        from finance.payout_accounts pa
       where pa.id = payout_account_id
         and pa.account_id = platform.current_account_id()
         and pa.status = 'verified'
    )
    -- The payer must be financially eligible and not on a KYC-upgrade hold.
    and exists (
      select 1
        from identity.accounts a
       where a.id = platform.current_account_id()
         and a.kyc_tier in ('tier_1', 'tier_2', 'tier_3')
         and a.financial_hold_reason is null
    )
  );

comment on policy payout_requests_insert on finance.payout_requests is
  'A payout request can only name a verified destination of the same account, from a tier_1+ account with no financial hold.';

comment on policy payout_accounts_insert on finance.payout_accounts is
  'A payout destination can only be bound by a tier_1+ account with no financial hold.';
