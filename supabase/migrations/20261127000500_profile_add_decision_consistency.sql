-- A decided submission carries a decision timestamp, and only a decided one
-- (EP-02-011).
--
-- The transition trigger stops a subject from entering APPROVED or REJECTED, but
-- it does not say that the entry must be a *decision*. Without this constraint a
-- direct update could mark a submission rejected with no record of when the
-- decision was taken, which is exactly the shortcut the database gate used before
-- the transition table existed.
--
-- `EXPIRED` is not a decision and carries no timestamp: expiry is a system
-- transition, not an outcome.

set local lock_timeout = '5s';

alter table profile.verification_submissions
  add constraint verification_submissions_decision_consistent
  check (
    case
      when state in ('APPROVED', 'REJECTED') then decided_at is not null
      else decided_at is null
    end
  );

comment on constraint verification_submissions_decision_consistent
  on profile.verification_submissions is
  'A decided attempt must record when it was decided; no other state may carry a decision timestamp.';
