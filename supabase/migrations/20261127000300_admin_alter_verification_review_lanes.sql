-- Reconcile the control-portal review lane with the six approved lanes (CP-019).
--
-- `admin.verification_reviews.lane` was created with a review-local vocabulary —
-- identity, business, address, phone, document — that never matched the six
-- approved lanes in `@hivorr/shared` and `profile.verification_lanes`. Two
-- vocabularies meant a review could name a lane the rest of the system does not
-- have.
--
-- This migration maps the three review-local values onto the lane that owns that
-- evidence and then replaces the check with a foreign key, so the registry is the
-- only vocabulary and a future lane cannot drift again.
--
-- Mapping assumed here, recorded for confirmation:
--   address  -> kyc        (a residential address is KYC evidence)
--   phone    -> kyc        (contact verification is part of KYC)
--   document -> identity   (the review lane named after identity documents)
-- The table is empty on a fresh database, so the update is a no-op there; it
-- exists so an existing environment cannot be left with an invalid value.
--
-- The business rule that a decision must carry evidence is unchanged and lives in
-- `admin.record_verification_decision`.

set local lock_timeout = '5s';

alter table admin.verification_reviews
  drop constraint if exists verification_reviews_lane_check;

update admin.verification_reviews
   set lane = case lane
                when 'address' then 'kyc'
                when 'phone' then 'kyc'
                when 'document' then 'identity'
                else lane
              end,
       updated_at = now()
 where lane in ('address', 'phone', 'document');

alter table admin.verification_reviews
  add constraint verification_reviews_lane_fkey
  foreign key (lane) references profile.verification_lanes (key) on update cascade;

comment on column admin.verification_reviews.lane is
  'The verification lane under review. A foreign key to profile.verification_lanes, so the control portal and the account-side lane model share one vocabulary.';

comment on table admin.verification_reviews is
  'Verification decision per review case. Evidence remains on the case. The lane is the approved six-lane vocabulary.';
