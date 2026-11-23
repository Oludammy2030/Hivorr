-- CBN 3-tier KYC model (EP-02-014).
--
-- Founder decision, 23 November 2026: use the full CBN three-tier model.
-- `tier_0` is unverified and cannot move money; `tier_1` is Level 1, `tier_2`
-- is Level 2 and `tier_3` is Level 3. Deposits are not CBN-capped because
-- Hivorr is not a bank; the limits are withdrawal limits.

set local lock_timeout = '5s';

alter table identity.accounts
  drop constraint if exists accounts_kyc_tier_check;

alter table identity.accounts
  add constraint accounts_kyc_tier_check
  check (kyc_tier in ('tier_0', 'tier_1', 'tier_2', 'tier_3'));

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
