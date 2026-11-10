# EP-01-021 — Migration runner and baseline schemas

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-021` |
| **Task title** | Migration runner and baseline schemas |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — schema and migration infrastructure |
| **Execution order** | 11 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage C |
| **Dependencies** | `EP-01-020` |

## 2. Objective

Apply forward-only SQL migrations from an empty database, record exactly what was applied and with
which checksum, make a second run a no-op, refuse an edited applied file, and enforce the naming,
self-containment, destructive-change and RLS rules. A clean database built from migrations must
equal the deployed schema.

## 3. Scope

### 3.1 Included

- Verify `scripts/apply-migrations.mjs`: advisory lock, one transaction per file, history row only
  on success, checksum drift refusal, no connection string in output.
- Verify `scripts/test-db-migrations.mjs`: fresh database, all migrations, ten module schemas plus
  `private`, platform tables, identity spine, roles, RLS and append-only audit.
- Verify `scripts/lint-migrations.mjs` and its seeded proofs.
- Add a pure migration-history comparison and a database verifier (`pnpm migrations:verify`).
- Wire the verifier into CI after the two apply passes and into the pipeline contract.
- Record the baseline-snapshot gap (`F-28`).

### 3.2 Excluded

- Renaming or editing the eleven applied migrations (`F-12`, `F-03` ratified).
- Rebuilding the custom runner or adopting the Supabase CLI (`F-03` ratified).
- A committed `supabase/schema-baseline.txt`. It must be generated from a live migrated database;
  no Postgres exists on this workstation (`F-28`).
- Role/grant changes — `022`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Migrations apply in filename order, each in its own transaction. | DB rules §9.2 |
| R-02 | An advisory lock prevents concurrent runners. | Runner contract |
| R-03 | A history row is written only after the file commits. | DB rules §9.2, §11.1 |
| R-04 | Editing an applied file is refused, not silently re-run. | Runner contract |
| R-05 | A second run applies nothing and succeeds. | DB rules §11.1 |
| R-06 | An empty database yields the ten module schemas, `private` and platform tables. | Plan `021` |
| R-07 | Naming, self-containment, destructive approval, RLS and lock-timeout rules are enforced. | DB rules §9.3–§9.6 |
| R-08 | The history matches every file and checksum. | Plan `021` |
| R-09 | No credential appears in runner output. | `AFS-LOG-01` |
| R-10 | A schema baseline enables a clean `db diff`. | Plan `021` |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-020` environment | **REQUIRES_REVIEW** — supplies `DATABASE_URL`, roles and the CI database |
| Migration `001`–`011` | Applied set; names predate §9.3 and cannot be renamed (`F-12`) |
| Custom runner | **Ratified 2026-11-09** (`F-03`) |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the runner, the fresh-database test, the migration lint and the CI database job.
2. Add `scripts/lib/migration-history.mjs` with a pure comparison.
3. Add `scripts/verify-migration-history.mjs` and `pnpm migrations:verify`.
4. Add `tests/migration-history.test.ts`.
5. Wire the verifier into CI and the pipeline contract.
6. Run local gates; record the database and baseline evidence that needs CI.
7. Record `F-28` for the missing committed baseline.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `scripts/apply-migrations.mjs` | **Reuse unchanged** | It already has the lock, transaction, history and checksum rules |
| `scripts/test-db-migrations.mjs` | **Reuse unchanged** | Fresh-database proof of schemas, tables, roles and RLS |
| `scripts/lint-migrations.mjs` | **Reuse unchanged** | §9 rules and the legacy allowlist |
| `scripts/test-ci-gates.mjs` | **Reuse** | Seeded proofs for bad names, destructive SQL, missing RLS |
| `scripts/db-schema-snapshot.mjs` / `db-schema-diff.mjs` | **Reuse** | Baseline snapshot and review artefact |
| `platform.schema_migrations` | **Reuse** | The runner's history table |
| `supabase/migrations/*.sql` | **Do not rename or edit** | Applied migrations are immutable |

**Must not be duplicated:** a second runner, a second history table, a second checksum function, or
a second migration set.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `scripts/lib/migration-history.mjs` | **New** — pure history comparison |
| `scripts/verify-migration-history.mjs` | **New** — database verifier |
| `tests/migration-history.test.ts` | **New** — four failure modes and checksum stability |
| `package.json` | `migrations:verify` |
| `.github/workflows/ci.yml` | Verify history after the two apply passes |
| `tests/ci-pipeline.test.ts` | Requires `pnpm migrations:verify` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

The runner, migrations, lint and fresh-database test were not modified.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | The runner uses an advisory lock and one transaction per file. |
| DoD-02 | History is recorded only for a committed file, with its checksum. |
| DoD-03 | An edited applied file is refused. |
| DoD-04 | A second apply is a no-op and exits 0. |
| DoD-05 | A fresh database yields the ten schemas plus `private` and the platform tables. |
| DoD-06 | Lint fails on a bad name, destructive SQL without approval and a new table without RLS. |
| DoD-07 | The history verifier accepts a complete history and refuses missing, changed and unknown rows. |
| DoD-08 | `migrations:verify` is wired into CI after two applies. |
| DoD-09 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-10 | A committed schema baseline makes `db diff` clean. |
| DoD-11 | No new dependency, secret or permission. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

DoD-10 is **unmet**: no baseline exists (`F-28`). The task remains `REQUIRES_REVIEW`.

## 10. Acceptance criteria

- `pnpm test:db` on an empty database applies every migration and passes every assertion.
- `pnpm migrations:apply` twice reports the second run as fully present.
- `pnpm migrations:verify` reports the applied count and refuses a missing or edited file.
- `pnpm lint:migrations` passes the repository and fails each seeded defect.
- CI publishes a schema snapshot; with a committed baseline, `db:diff` reports no change.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/migration-history.test.ts` |
| T-02 | `pnpm migrations:verify` with no URL (exit 2) |
| T-03 | `pnpm test:db` — CI database job |
| T-04 | `pnpm migrations:apply` twice and `pnpm migrations:verify` — CI |
| T-05 | `pnpm lint:migrations` and `pnpm test:gates` |
| T-06 | `pnpm db:snapshot` / `db:diff` — CI |
| T-07 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-08 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| No committed schema baseline. | `F-28`; the snapshot/diff step is wired and publishes the head snapshot, but a base is required for a clean diff. |
| Eleven migration names predate §9.3. | `F-12`; grandfathered, never renamed. |
| A migration could be edited after apply. | The runner refuses a changed checksum; `migrations:verify` re-checks the history. |
| No Postgres on this workstation. | `test:db`, the double apply, history verification and snapshot run in CI. |
| The history verifier duplicates the runner's checksum logic. | Both use SHA-256 over the file; the pure test pins the behavior. |
| `db reset` is not a Supabase CLI command here. | The custom runner plus a fresh temporary database is the ratified reset path (`F-03`). |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI runs the double apply, `migrations:verify` and `test:db`; a committed baseline closes `F-28` |
| **Execution record** | `execution-records/EP-01-021.md` |
