-- CBN deposit caps and the KYC-upgrade hold (EP-02-014 / EP-02-053).
--
-- CBN sets a maximum single deposit per tier:
--   tier_1 (Level 1): NGN 20,000
--   tier_2 (Level 2): NGN 50,000
--   tier_3 (Level 3): no cap
--
-- A deposit above the account's cap is not credited and puts the account on a
-- `kyc_upgrade_required` hold. Every fund transaction checks the hold; a
-- verifier tier change clears it. Deposits are the only CBN-capped inflow;
-- withdrawals keep their separate daily caps.
--
-- `is_unlimited` makes an explicit "no cap" representable without inventing a
-- large number. It is configuration, not a threshold in code.

set local lock_timeout = '5s';

alter table finance.limits
  add column is_unlimited boolean not null default false;

alter table identity.accounts
  add column financial_hold_reason text
    check (financial_hold_reason in ('kyc_upgrade_required')),
  add column financial_hold_at timestamptz;

comment on column identity.accounts.financial_hold_reason is
  'Active fund-transaction hold. kyc_upgrade_required is set by an over-limit deposit and cleared by a tier change.';

comment on column identity.accounts.financial_hold_at is
  'When the current fund-transaction hold was set.';

create or replace function identity.set_kyc_tier(
  p_actor_user_id uuid,
  p_account_id uuid,
  p_tier text,
  p_reason text
)
returns table (
  account_id uuid,
  kyc_tier text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_updated_at timestamptz := now();
begin
  if not admin.actor_holds_platform_permission(
    p_actor_user_id,
    'admin.verification.review'
  ) then
    raise exception 'kyc_tier_forbidden' using errcode = '42501';
  end if;

  if p_tier is null
     or p_tier not in ('tier_0', 'tier_1', 'tier_2', 'tier_3') then
    raise exception 'kyc_tier_invalid' using errcode = '22023';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'kyc_tier_reason_required' using errcode = '22023';
  end if;

  update identity.accounts a
     set kyc_tier = p_tier,
         kyc_tier_updated_at = v_updated_at,
         financial_hold_reason = case
           when p_tier is distinct from a.kyc_tier then null
           else a.financial_hold_reason
         end,
         financial_hold_at = case
           when p_tier is distinct from a.kyc_tier then null
           else a.financial_hold_at
         end,
         updated_at = v_updated_at
   where a.id = p_account_id;

  if not found then
    raise exception 'kyc_account_not_found' using errcode = 'P0002';
  end if;

  return query
    select a.id, a.kyc_tier, a.kyc_tier_updated_at::timestamptz
      from identity.accounts a
     where a.id = p_account_id;
end;
$$;

revoke all on function identity.set_kyc_tier(uuid, uuid, text, text) from public;
grant execute on function identity.set_kyc_tier(uuid, uuid, text, text) to hivorr_api;

insert into finance.limits
  (tier, account_id, limit_type, currency, amount, period, is_unlimited,
   effective_from, created_by)
values
  ('tier_1', null, 'deposit', 'NGN', 20000.0000, 'per_transaction', false,
   now(), null),
  ('tier_2', null, 'deposit', 'NGN', 50000.0000, 'per_transaction', false,
   now(), null),
  ('tier_3', null, 'deposit', 'NGN', 0.0000, 'per_transaction', true,
   now(), null)
on conflict do nothing;

comment on table finance.limits is
  'Effective-dated financial limits per KYC tier or account override. The numbers are configuration, never code. tier_0 has no positive limit. Withdrawals use the CBN daily caps; deposits use the CBN single-deposit caps, with tier_3 unlimited (EP-02-014).';
