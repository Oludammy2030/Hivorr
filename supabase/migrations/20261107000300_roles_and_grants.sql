-- Least-privilege database roles. Passwords and login credentials are never
-- stored here; the managed provider and deployment secret store supply them.
-- The API role cannot alter schema, truncate, or bypass RLS.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'hivorr_api') then
    create role hivorr_api nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'hivorr_worker') then
    create role hivorr_worker nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'hivorr_readonly') then
    create role hivorr_readonly nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'hivorr_migrator') then
    create role hivorr_migrator nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'hivorr_breakglass') then
    create role hivorr_breakglass nologin;
  end if;
end;
$$;

grant usage on schema platform to hivorr_api, hivorr_worker, hivorr_readonly;
grant usage on schema identity, profile, market, services, errands, logistics,
  finance, messaging, admin to hivorr_api, hivorr_worker;

-- The API may append audit records and read them for a scoped audit screen.
grant select, insert on platform.audit_log to hivorr_api;
grant select on platform.audit_log to hivorr_readonly;

-- The API writes outbox events; the worker consumes and updates them.
grant select, insert, update on platform.outbox to hivorr_api;
grant select, insert, update on platform.outbox to hivorr_worker;

grant select, insert, update on platform.idempotency_keys to hivorr_api;
grant select on platform.feature_flags to hivorr_api, hivorr_worker, hivorr_readonly;
grant select, insert, update on platform.reference_counters to hivorr_api;

-- No application role may change the audit trail or platform definitions.
revoke update, delete on platform.audit_log from public;
