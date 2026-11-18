-- Wallet derived views (EP-02-032).
--
-- A wallet figure is never stored. Both views read the append-only postings so
-- the displayed balance and the statement cannot disagree with the ledger.
--
-- Definitions, in the terms approved by PAYMENT-WALLET-ESCROW-ARCHITECTURE.md 2:
--   available    = the net of the account's user_wallet postings
--   pending      = the net of escrow postings against that account's held escrows
--   total        = available + pending
--   withdrawable = available, until payout reservations exist in EP-02-053
--
-- An internal escrow hold moves value from the wallet to the escrow account, so
-- it lowers `available` and raises `pending` by the same amount: `total` does
-- not change. Release and refund policy remains BD-D03 and is not encoded here.
--
-- Both views are `security_invoker`, so the caller's RLS on postings,
-- ledger_accounts and escrow_accounts applies. A view that runs as its owner
-- would hand out every account's wallet.
--
-- This migration also extends the posting select policy so a payer can read the
-- postings on their own escrow account. Without it, `pending` would always read
-- zero because escrow ledger accounts are owned by the activity, not the payer.

set local lock_timeout = '5s';

drop policy postings_select on finance.postings;

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
    or exists (
      select 1
        from finance.escrow_accounts ea
       where ea.ledger_account_id = finance.postings.ledger_account_id
         and ea.payer_account_id = platform.current_account_id()
    )
  );

create view finance.wallet_balances
with (security_invoker = true) as
with wallet as (
  select la.owner_id as account_id,
         p.currency,
         sum(case p.direction when 'debit' then p.amount else -p.amount end)
           as available
    from finance.postings p
    join finance.ledger_accounts la on la.id = p.ledger_account_id
   where la.kind = 'user_wallet'
     and la.owner_type = 'account'
   group by la.owner_id, p.currency
),
escrow as (
  select ea.payer_account_id as account_id,
         ea.currency,
         sum(case p.direction when 'debit' then p.amount else -p.amount end)
           as pending
    from finance.escrow_accounts ea
    join finance.postings p on p.ledger_account_id = ea.ledger_account_id
   where ea.state = 'held'
   group by ea.payer_account_id, ea.currency
)
select coalesce(w.account_id, e.account_id) as account_id,
       coalesce(w.currency, e.currency) as currency,
       coalesce(w.available, 0)::numeric(20, 4) as available,
       coalesce(e.pending, 0)::numeric(20, 4) as pending,
       (coalesce(w.available, 0) + coalesce(e.pending, 0))::numeric(20, 4)
         as total,
       coalesce(w.available, 0)::numeric(20, 4) as withdrawable
  from wallet w
  full join escrow e
    on e.account_id = w.account_id
   and e.currency = w.currency;

comment on view finance.wallet_balances is
  'Derived wallet figures per account and currency. available = wallet net; pending = held escrow; total = available + pending; withdrawable = available until payout reservations (EP-02-053).';

create view finance.wallet_statement
with (security_invoker = true) as
select p.id as posting_id,
       la.owner_id as account_id,
       p.currency,
       p.direction,
       p.amount::numeric(20, 4) as amount,
       (case p.direction when 'debit' then p.amount else -p.amount end)
         ::numeric(20, 4) as signed_amount,
       je.id as entry_id,
       je.kind as entry_kind,
       je.reference,
       p.activity_id,
       p.created_at as occurred_at
  from finance.postings p
  join finance.ledger_accounts la on la.id = p.ledger_account_id
  join finance.journal_entries je on je.id = p.entry_id
 where la.kind = 'user_wallet'
   and la.owner_type = 'account';

comment on view finance.wallet_statement is
  'One row per user_wallet posting, with the entry reference, kind and activity attribution. signed_amount is positive for a credit to the wallet.';

grant select on finance.wallet_balances to hivorr_api;
grant select on finance.wallet_statement to hivorr_api;
