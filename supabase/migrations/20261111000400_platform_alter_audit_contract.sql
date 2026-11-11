-- Audit contract extension (CP-005).
--
-- Additive only. Existing audit rows remain valid: the new columns are
-- nullable. The append-only trigger is unchanged. No history is rewritten.

set local lock_timeout = '5s';

alter table platform.audit_log
  add column reason text,
  add column approval_reference text,
  add column session_id uuid;

comment on column platform.audit_log.reason is
  'Why the action was taken. Required by the service layer for sensitive actions.';

comment on column platform.audit_log.approval_reference is
  'The approval request that authorised a sensitive action, when one is required.';

comment on column platform.audit_log.session_id is
  'The actor session, when the action came from an authenticated session.';

create index audit_log_action_idx
  on platform.audit_log (action, occurred_at desc);
