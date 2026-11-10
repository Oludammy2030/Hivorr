# EP-01-020 — Managed PostgreSQL and environment configuration

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-020` |
| **Task title** | Managed PostgreSQL and environment configuration |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — infrastructure and credentials |
| **Execution order** | 10 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage C |
| **Dependencies** | `EP-01-001` |

## 2. Objective

Provision the chosen managed PostgreSQL provider for local and staging and define the per-environment
connection and secret contract: separate projects, databases, roles and credentials; connection
validation; no shared credentials; local container parity. This execution verifies the contract and
adds the missing connection check and pool evidence; it does not create a new provider resource.

## 3. Scope

### 3.1 Included

- Verify the committed environment topology, project manifest, local container settings and role
  migration.
- Add `scripts/check-database.mjs` (`pnpm db:check`): connect, report database/role/version/TLS,
  optionally enforce the role and PostgreSQL major version, and never print the URL.
- Add pool tests: remote TLS, CA verification, loopback exemption, development/test behaviour,
  timeouts and application name.
- Add environment contract tests: distinct active projects, topology/manifest agreement, per-environment
  secrets, `supabase/config.toml` parity (project id, port 54322, major 17), `.env.example` worker
  variables, nologin roles and least-privilege grants.
- Document the worker variables in `.env.example`.
- Wire `db:check` into the CI database job.

### 3.2 Excluded

- Creating, resizing, backing up or rotating a managed provider resource. That is an operator action;
  no provider credential or production access exists in this environment.
- Setting `DATABASE_SSL_CA` on staging. That remains `F-08`; the pool verifies the certificate when it
  is supplied and reports unverified TLS otherwise.
- A database-backed `/health/ready`. That remains `F-08`/`026`.
- Migration content — `021`/`022`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Staging and production use different managed projects and credentials. | Plan `020` |
| R-02 | The topology manifest and backend-project manifest agree. | `config/*.json` |
| R-03 | Each environment declares `DATABASE_URL`, `WORKER_DATABASE_URL` and `MFA_ENCRYPTION_KEY`. | Plan `020` |
| R-04 | A remote staging/production connection is encrypted. | `db/pool.ts` |
| R-05 | A supplied `DATABASE_SSL_CA` verifies the server. | `F-08` |
| R-06 | A loopback/local container connection does not force TLS. | Local parity |
| R-07 | Database and worker URLs must belong to the declared project. | `010` config |
| R-08 | `db:check` connects, reports role/database/version/TLS and enforces optional expectations. | Plan `020` |
| R-09 | `db:check` never prints the URL or a credential, and exits 2 without `DATABASE_URL`. | `AFS-LOG-01` |
| R-10 | Roles are `nologin` and grants are least privilege. | Migration `003`, `022` |
| R-11 | Local container parity: project id, port 54322, PostgreSQL 17. | Plan `020` |
| R-12 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-001` provider decision | **COMPLETED** — Supabase managed PostgreSQL, project per environment |
| `EP-01-010` configuration | **REQUIRES_REVIEW** — supplies validation and the pool factory |
| `EP-01-021`/`022` migrations | **REQUIRES_REVIEW** — supply roles, grants and the baseline |
| CI Postgres 17 service | Existing in the database job |
| `.env.example` | Extended with worker variables |

## 6. Implementation plan

1. Read the topology, project manifest, pool factory, local Supabase config, roles migration and
   staging runbook.
2. Add `scripts/check-database.mjs` with role, major-version and TLS checks.
3. Add `tests/db-pool.test.ts` for TLS and timeouts.
4. Add `tests/database-environment.test.ts` for project separation, parity, secrets and roles.
5. Document worker variables in `.env.example`.
6. Add `db:check` to `package.json`, CI and the pipeline contract.
7. Run local gates; record what needs a live database.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `server/src/config.ts` | **Reuse** | Project-ref matching, required secrets |
| `server/src/db/pool.ts` | **Reuse, test it** | TLS logic and timeouts already exist |
| `config/environments.json`, `config/backend-projects.json` | **Reuse** | One topology and one project manifest |
| `scripts/lib/environment-topology-policy.mjs` | **Reuse** | Project separation and host rules |
| `supabase/config.toml` | **Reuse** | Local container definition |
| `.env.example` | **Extend** | Worker variables were undocumented |
| Migration `003` | **Reuse** | Roles and grants |
| CI Postgres service | **Reuse** | No new service |

**Must not be duplicated:** a second topology file, a second pool factory, a second TLS rule, or a
second project manifest.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `scripts/check-database.mjs` | **New** — connection and role validation |
| `tests/db-pool.test.ts` | **New** — TLS, timeout and app-name evidence |
| `tests/database-environment.test.ts` | **New** — project, parity, secret and role contract |
| `.env.example` | Worker variables documented |
| `package.json` | `db:check` |
| `.github/workflows/ci.yml` | `db:check --expect-major 17` in the database job |
| `tests/ci-pipeline.test.ts` | Requires `pnpm db:check` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No schema, migration, dependency, provider resource or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Staging and production active project refs differ and no active ref is retired. |
| DoD-02 | Topology project refs match the backend-project manifest. |
| DoD-03 | Both environments require the database and worker secrets. |
| DoD-04 | Remote staging/production connections are encrypted; a CA verifies when supplied. |
| DoD-05 | A loopback connection does not force TLS; development/test stay unencrypted. |
| DoD-06 | Pool timeouts, pool size and application name are asserted. |
| DoD-07 | Local container parity is asserted: project id, 54322, PostgreSQL 17, shadow 54320. |
| DoD-08 | `.env.example` documents the worker variables and contains no real credential. |
| DoD-09 | Five roles are `nologin`; least-privilege grants and the audit revoke are present. |
| DoD-10 | `db:check` exits 2 without a URL, 1 on a refused connection, and never prints the URL. |
| DoD-11 | `db:check` is wired into CI with the major-version expectation. |
| DoD-12 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-13 | No new dependency, secret or permission. |
| DoD-14 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- Two environments cannot resolve to the same Supabase project; the topology policy and the
  environment test both refuse it.
- A staging connection without a CA is still encrypted; with a CA the certificate is verified.
- `db:check` against a live database prints database, role, TLS and server version, and fails when
  the role or major version does not match.
- The CI database job runs the check against PostgreSQL 17.
- No output contains a connection string or password.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/db-pool.test.ts tests/database-environment.test.ts` |
| T-02 | `pnpm db:check` with no URL (exit 2) and a refused URL (exit 1) |
| T-03 | `pnpm db:check -- --expect-major 17` in CI against Postgres |
| T-04 | `pnpm test:topology`, `pnpm topology:verify` |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-06 | `pnpm test:gates` |
| T-07 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The environment records disagree about staging status. | `config/environments.json` says `planned`, `backend-projects.json` says `active`, and the provisioning runbook says live. Recorded as `F-27`; not resolved silently. |
| No live staging/production connection was tested here. | `db:check` is wired into CI and the staging runbook; the live run is operator evidence. |
| `DATABASE_SSL_CA` is unset on staging. | The connection is encrypted but the server is unverified; `F-08` remains. |
| A local loopback URL in staging is refused by config validation. | The pool keeps a defensive loopback branch for a tunnel/sandbox; the contract still requires staging to use the managed project. |
| `db:check` uses `pg_stat_ssl`, which a role may not read. | It degrades to `tls=false`; a remote connection then fails closed. |
| The CI Postgres is not the managed provider. | CI proves the check logic and version; staging proves the provider path. |
| Secrets could leak in error output. | The script prints only database, role, TLS and version, never the URL; the connection error is the driver's message. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI runs `db:check` against Postgres; staging runs `db:check --expect-role hivorr_api`; `F-27` is ruled on |
| **Execution record** | `execution-records/EP-01-020.md` |
