-- Money idempotency and provider-reference scope (EP-02-034).
--
-- Two changes make a repeated money operation a no-op rather than a second
-- movement:
--
--   1. A journal entry's idempotency key is unique per creator, not globally.
--      A platform record holds the request hash and the stored response, so a
--      replay returns the original result and a different request under the same
--      key is refused.
--   2. A provider reference belongs to an account, is unique per provider and is
--      readable only by that account until it is linked to an entry it can see.
--
-- Provider references are written with insert/update grants only; the amount,
-- direction, provider and reference are immutable after recording.
--
-- Money idempotency keys do not expire. The platform expiry column is set to
-- `infinity` for a ledger entry; reusing a key after a timeout would be a second
-- movement.

set local lock_timeout = '5s';

drop index finance.journal_entries_idempotency_idx;

create unique index journal_entries_idempotency_idx
  on finance.journal_entries (
    coalesce(created_by, '00000000-0000-0000-0000-000000000000'::uuid),
    idempotency_key
  )
  where idempotency_key is not null;

comment on index finance.journal_entries_idempotency_idx is
  'An idempotency key is unique per creator; system entries (null creator) share one namespace.';

alter table finance.provider_references
  add column account_id uuid references identity.accounts (id) on delete restrict;

alter table finance.provider_references
  alter column account_id set not null;

create index provider_references_account_idx
  on finance.provider_references (account_id, status, created_at);

drop policy provider_references_select on finance.provider_references;

create policy provider_references_select on finance.provider_references
  for select to hivorr_api
  using (
    account_id = platform.current_account_id()
    or (
      journal_entry_id is not null
      and exists (
        select 1
          from finance.journal_entries je
         where je.id = finance.provider_references.journal_entry_id
      )
    )
  );

create policy provider_references_insert on finance.provider_references
  for insert to hivorr_api
  with check (account_id = platform.current_account_id());

create policy provider_references_update on finance.provider_references
  for update to hivorr_api
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

grant insert on finance.provider_references to hivorr_api;
grant update (status, journal_entry_id, updated_at) on finance.provider_references
  to hivorr_api;
