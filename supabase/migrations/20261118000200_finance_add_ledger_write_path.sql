-- Ledger write path (EP-02-031).
--
-- The posting engine is the only writer. This migration grants exactly the two
-- inserts it needs, behind an insert policy that requires a transaction
-- identity, and prevents the same entry being reversed twice.
--
-- There is still no update or delete grant. A correction is a new reversal
-- entry; the append-only triggers from EP-02-030 refuse mutation even if a
-- future grant is added by mistake.
--
-- The insert policy requires only that the transaction carries an account
-- context. It deliberately does not require the caller to own every posting:
-- a deposit credits a wallet from clearing, and an escrow release debits the
-- buyer's escrow and credits the professional. Scoping writes to one account
-- would make legitimate transfers impossible; authorisation remains the
-- service layer's job (database rules 6.2).

set local lock_timeout = '5s';

create unique index journal_entries_reversal_unique_idx
  on finance.journal_entries (reverses_entry_id)
  where reverses_entry_id is not null;

comment on index finance.journal_entries_reversal_unique_idx is
  'An entry is corrected by at most one reversal. A reversal of a reversal names that reversal, not the original.';

create policy journal_entries_insert on finance.journal_entries
  for insert to hivorr_api
  with check (platform.current_account_id() is not null);

create policy postings_insert on finance.postings
  for insert to hivorr_api
  with check (platform.current_account_id() is not null);

grant insert on finance.journal_entries to hivorr_api;
grant insert on finance.postings to hivorr_api;
