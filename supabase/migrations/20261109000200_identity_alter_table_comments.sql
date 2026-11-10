-- Complete the table comments required by EP-01-023.
--
-- Four identity tables were created without a comment. The schema contract
-- requires a comment on every table so an operator reading the database does not
-- have to infer purpose from the name. This is a new forward-only migration
-- because applied migrations are immutable.

comment on table identity.memberships is
  'Links a user to an account with an owner or member role. One owner per account.';

comment on table identity.devices is
  'A named device that holds sessions. Used for session listing and revocation.';

comment on table identity.recovery_codes is
  'Single-use MFA recovery codes, stored hashed and never returned after enrolment.';

comment on table identity.tokens is
  'Single-use verification, reset and invitation tokens, stored hashed with a purpose and expiry.';
