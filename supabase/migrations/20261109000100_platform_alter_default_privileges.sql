-- Close privileges on objects that do not exist yet.
--
-- Application roles receive object privileges explicitly, one grant at a time.
-- PostgreSQL still gives PUBLIC EXECUTE on every new function by default, so a
-- future helper would be callable by any role unless this default is revoked.
-- Default privileges are scoped to the role that applies the migration; the
-- deployment runner must keep using one migration role for this to hold.
--
-- Applied migrations are immutable, so this is a new forward-only migration
-- rather than an edit to 20261107000300_roles_and_grants.sql.

alter default privileges revoke all on tables from public;
alter default privileges revoke all on sequences from public;
alter default privileges revoke execute on functions from public;

-- Existing helpers are already revoked individually; this closes anything the
-- individual migrations missed, including trigger functions.
revoke all on all functions in schema platform from public;
revoke all on all functions in schema identity from public;
revoke all on all functions in schema profile from public;
revoke all on all functions in schema market from public;
revoke all on all functions in schema services from public;
revoke all on all functions in schema errands from public;
revoke all on all functions in schema logistics from public;
revoke all on all functions in schema finance from public;
revoke all on all functions in schema messaging from public;
revoke all on all functions in schema admin from public;

-- No application role may create objects in the shared `public` schema, and
-- `private` stays closed to every application role.
revoke create on schema public from public;
revoke all on schema private from public;
