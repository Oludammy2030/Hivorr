# EP-01-022 — Database roles, grants and default privileges

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-022` |
| **Task title** | Database roles, grants and default privileges |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — database authorisation |
| **Execution order** | 12 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage C |
| **Dependencies** | `EP-01-021` |

## 2. Objective

Create the migrator, API, worker, readonly and break-glass roles; grant only what each needs; close
defaults so a new object starts closed. The API role cannot change schema, truncate or bypass RLS. No
application role is superuser, and the migrator credential is CI-only.

## 3. Scope

### 3.1 Included

- Verify the five roles in migration `003` and their explicit grants.
- Add a forward-only migration that closes default table, sequence and function privileges, revokes
  PUBLIC execution on all module-schema functions, and closes `public`/`private`.
- Add a local policy test for the roles and the new default-privilege statements.
- Extend the fresh-database test: role attributes, API DDL/ALTER/TRUNCATE denial, closed defaults for
  a new function, worker/readonly isolation.
- Record the migrator/runbook contradiction (`F-29`).

### 3.2 Excluded

- Editing migration `003` or any applied migration. Applied migrations are immutable (§9.3); the new
  rules are a new migration.
- Creating login credentials or distributing them. The provider and secret store own credentials.
- Row-level policies — `023`/`024`.
- Per-table grants for tables that do not exist yet. Each owning migration grants explicitly.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Five roles exist: migrator, API, worker, readonly, break-glass. | Plan `022` |
| R-02 | No application role can log in directly; no role is superuser or bypasses RLS. | Plan `022` |
| R-03 | The API cannot create, alter or truncate schema objects. | Plan `022` |
| R-04 | The API cannot bypass RLS. | Plan `022` |
| R-05 | The worker cannot read identity tables; readonly cannot append audit. | Least privilege |
| R-06 | Future tables, sequences and functions start closed. | Plan `022` |
| R-07 | PUBLIC cannot execute functions in any module schema. | PostgreSQL default hardening |
| R-08 | `public` is not a writable schema for application roles; `private` stays closed. | Least privilege |
| R-09 | The migrator is not an application login role. | Plan `022` |
| R-10 | Each environment has distinct credentials. | `020` |
| R-11 | No new dependency or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-021` runner and baseline | **REQUIRES_REVIEW** — applies the new migration and verifies history |
| `EP-01-020` environment | **REQUIRES_REVIEW** — project separation and credentials |
| Migration `003` | Applied; not edited |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read migration `003`, all function grants and the fresh-database test.
2. Add `20261109000100_platform_alter_default_privileges.sql`.
3. Add `tests/database-roles.test.ts`.
4. Extend `test-db-migrations.mjs` with role attributes, DDL/ALTER/TRUNCATE denial and default
   function closure.
5. Run the migration lint and local gates; record the DB evidence that needs CI.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| Migration `003` | **Reuse, do not edit** | Roles and base grants already exist; applied files are immutable |
| Function grants in `004`–`011` | **Reuse** | Each helper is already revoked from PUBLIC and granted explicitly |
| `test-db-migrations.mjs` | **Extend** | One fresh-database suite already owns role and RLS assertions |
| `lint:migrations` | **Reuse** | The new file is the first strict-named migration |
| `platform.set_identity_context`, `uuidv7`, `outbox_health` | **Reuse** | Explicit grants preserved |

**Must not be duplicated:** a second role-creation block, a second default-privilege migration, or a
second RLS test suite.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `supabase/migrations/20261109000100_platform_alter_default_privileges.sql` | **New** — forward-only hardening |
| `tests/database-roles.test.ts` | **New** — role and default policy |
| `scripts/test-db-migrations.mjs` | Extended DB assertions |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No existing role, applied migration, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Five application roles exist as `nologin`. |
| DoD-02 | Every role is non-superuser, non-`bypassrls`, non-`createdb`, non-`createrole`. |
| DoD-03 | The API cannot create, alter or truncate a table. |
| DoD-04 | The API cannot bypass RLS. |
| DoD-05 | The worker cannot read `identity.users`; readonly cannot insert audit. |
| DoD-06 | Default table, sequence and function privileges are revoked from PUBLIC. |
| DoD-07 | PUBLIC execute is revoked on every module schema; `public`/`private` are closed. |
| DoD-08 | A function created after the migration is not executable by the API. |
| DoD-09 | The migration is strict-named and passes `lint:migrations`. |
| DoD-10 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-11 | No new dependency, secret or permission. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- The fresh-database suite proves the API is refused `CREATE TABLE`, `ALTER TABLE` and `TRUNCATE`
  with `42501`.
- A newly created function has no API execute privilege.
- `pg_roles` shows five `hivorr_*` roles with every elevated attribute false.
- `lint:migrations` reports one strict migration and eleven legacy-applied files.
- No application role can log in without a provider-issued credential.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/database-roles.test.ts` |
| T-02 | `pnpm lint:migrations` |
| T-03 | `pnpm test:db` — CI database job |
| T-04 | `pnpm test:gates` |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-06 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Default privileges are scoped to the role that applies the migration. | Documented in the migration; the deployment must keep one migration role. |
| The runbook says "apply as `hivorr_migrator`", but the role is `nologin` and the runner connects with the provider admin. | Recorded as `F-29`; the roles still have no login. |
| Revoking PUBLIC execute could break a helper. | Every helper used by the API/worker has an explicit grant; the fresh-database suite exercises the paths. |
| A future migration could forget to grant a new table. | That is the intended default-closed behavior; the owning task adds the grant. |
| No Postgres locally. | The fresh-database and role tests run in CI. |
| `revoke all on all functions` requires ownership. | The migration role owns the functions it created; CI/production apply as that owner. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI applies the new migration and passes the extended role suite; `F-29` is ruled on |
| **Execution record** | `execution-records/EP-01-022.md` |
