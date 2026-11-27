-- KYC tier source (EP-02-014, minimal increment).
--
-- The approved shared contract currently defines only `tier_0` and `tier_1`.
-- This migration stores the account's effective tier and adds one narrow way to
-- assign it: an audited verifier action. It does not invent a ladder above
-- `tier_1`, thresholds or a verification vendor.
--
-- `tier_0` is the default and cannot withdraw. `tier_1` is the financially
-- eligible tier already used by `finance.limits` and the capability engine.

set local lock_timeout = '5s';

alter table identity.accounts
  add column kyc_tier text not null default 'tier_0'
    check (kyc_tier in ('tier_0', 'tier_1')),
  add column kyc_tier_updated_at timestamptz not null default now();

comment on column identity.accounts.kyc_tier is
  'Effective KYC tier. Only tier_0 and tier_1 are approved today; the ladder above tier_1 remains open.';

comment on column identity.accounts.kyc_tier_updated_at is
  'When the effective tier was last changed. The audit log carries the actor and reason.';

create function identity.set_kyc_tier(
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

  if p_tier is null or p_tier not in ('tier_0', 'tier_1') then
    raise exception 'kyc_tier_invalid' using errcode = '22023';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'kyc_tier_reason_required' using errcode = '22023';
  end if;

  update identity.accounts a
     set kyc_tier = p_tier,
         kyc_tier_updated_at = v_updated_at,
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
