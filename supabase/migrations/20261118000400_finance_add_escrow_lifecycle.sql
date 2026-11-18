-- Escrow lifecycle (EP-02-033).
--
-- The escrow ledger account already exists from EP-02-030. This migration adds
-- the narrow metadata write path and the state machine:
--
--   held -> disputed            enabled: it moves no money and asks for review
--   held -> released/refunded   defined by BD-D03, disabled
--   held -> cancelled           defined by BD-D03, disabled
--   disputed -> released/refunded defined by BD-D03, disabled
--
-- A disabled transition is refused in the service and again by a trigger, so a
-- caller that bypasses the service still cannot release or refund. The same list
-- is published as `ESCROW_TRANSITIONS` in `@hivorr/shared`.
--
-- No fee, split, release timing or refund rule is encoded. Enabling a transition
-- requires a new migration after BD-D03 is decided.

set local lock_timeout = '5s';

-- Only escrow ledger accounts may be created by the API; wallet and platform
-- accounts remain migration/service-owned.
create policy ledger_accounts_insert on finance.ledger_accounts
  for insert to hivorr_api
  with check (
    kind = 'escrow'
    and owner_type = 'activity'
    and owner_id is not null
    and platform.current_account_id() is not null
  );

grant insert on finance.ledger_accounts to hivorr_api;

create policy escrow_accounts_insert on finance.escrow_accounts
  for insert to hivorr_api
  with check (payer_account_id = platform.current_account_id());

create policy escrow_accounts_update on finance.escrow_accounts
  for update to hivorr_api
  using (payer_account_id = platform.current_account_id())
  with check (payer_account_id = platform.current_account_id());

-- Only the lifecycle columns are mutable. The payer, ledger account, activity,
-- reference and currency are fixed when the reservation is opened.
grant update (state, updated_at, resolved_at) on finance.escrow_accounts
  to hivorr_api;
grant insert on finance.escrow_accounts to hivorr_api;

create function private.validate_escrow_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.state is not distinct from old.state then
    return new;
  end if;

  new.updated_at := now();

  if old.state = 'held' and new.state = 'disputed' then
    if new.resolved_at is not null then
      raise exception 'escrow_resolved_at_invalid' using errcode = '23514';
    end if;
    return new;
  end if;

  if (old.state = 'held' and new.state in ('released', 'refunded', 'cancelled'))
     or (old.state = 'disputed' and new.state in ('released', 'refunded')) then
    raise exception 'escrow_transition_disabled' using errcode = '42501';
  end if;

  raise exception 'escrow_transition_invalid' using errcode = '23514';
end;
$$;

create trigger escrow_accounts_transition
before update of state
on finance.escrow_accounts
for each row execute function private.validate_escrow_transition();
