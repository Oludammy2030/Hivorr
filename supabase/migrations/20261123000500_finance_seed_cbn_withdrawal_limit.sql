-- CBN tier-based withdrawal limit (EP-02-014 / EP-02-053).
--
-- Founder direction, 23 November 2026: a withdrawal limit follows the CBN
-- tier model. The only approved Hivorr tier above `tier_0` is `tier_1`, and it
-- is mapped to CBN Level 2 (identity/basic verification). The seeded value is
-- the CBN 2013 three-tier KYC mobile-banking daily limit for Level 2:
-- NGN 100,000 per day.
--
-- This is configuration, not code: the row is effective-dated and a later
-- decision can add a new row without editing this migration. `tier_0` remains
-- denied before the limit check. Higher CBN levels and the exact framework
-- mapping remain open and must be confirmed before they are seeded.
--
-- Source: CBN "Three Tiered KYC Requirements" (18 January 2013), Level 2
-- mobile-banking products: maximum transaction NGN 10,000, daily limit
-- NGN 100,000.

set local lock_timeout = '5s';

insert into finance.limits
  (tier, account_id, limit_type, currency, amount, period, effective_from,
   created_by)
values
  ('tier_1', null, 'withdrawal', 'NGN', 100000.0000, 'daily', now(), null)
on conflict do nothing;

comment on table finance.limits is
  'Effective-dated financial limits per KYC tier or per account override. The numbers are configuration, never code. tier_0 has no positive limit (EP-02-035). tier_1 carries the CBN Level 2 daily withdrawal cap (EP-02-014).';
