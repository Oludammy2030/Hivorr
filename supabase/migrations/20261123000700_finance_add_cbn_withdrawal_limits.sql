-- CBN tier-based withdrawal limits (EP-02-014).
--
-- Founder decision, 23 November 2026: use the full CBN three-tier model. Only
-- withdrawals follow CBN; deposits are not capped because Hivorr is not a bank.
--
-- Tiers and daily withdrawal limits (CBN 2013 three-tier KYC, mobile banking):
--   tier_1 (Level 1): NGN 30,000
--   tier_2 (Level 2): NGN 100,000
--   tier_3 (Level 3): NGN 1,000,000
--
-- The earlier `tier_1` NGN 100,000 row from the previous mapping is closed with
-- `effective_to`; the new rows are effective from now. Limits stay
-- effective-dated configuration, never code.

set local lock_timeout = '5s';

update finance.limits
   set effective_to = now()
 where tier = 'tier_1'
   and limit_type = 'withdrawal'
   and period = 'daily'
   and currency = 'NGN'
   and effective_to is null;

insert into finance.limits
  (tier, account_id, limit_type, currency, amount, period, effective_from,
   created_by)
values
  ('tier_1', null, 'withdrawal', 'NGN', 30000.0000, 'daily', now(), null),
  ('tier_2', null, 'withdrawal', 'NGN', 100000.0000, 'daily', now(), null),
  ('tier_3', null, 'withdrawal', 'NGN', 1000000.0000, 'daily', now(), null)
on conflict do nothing;

comment on table finance.limits is
  'Effective-dated financial limits per KYC tier or account override. The numbers are configuration, never code. tier_0 has no positive limit (EP-02-035). tier_1/tier_2/tier_3 carry the CBN 3-tier daily withdrawal caps (EP-02-014); deposits are not CBN-capped.';
