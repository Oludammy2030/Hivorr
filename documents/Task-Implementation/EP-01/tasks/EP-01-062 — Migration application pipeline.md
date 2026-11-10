# EP-01-062 — Migration application pipeline

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-062` |
| **Task title** | Migration application pipeline |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — database delivery |
| **Execution order** | 34 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage G |
| **Dependencies** | `EP-01-021`, `EP-01-022`, `EP-01-060`, `EP-01-061` |

## 2. Objective

Apply forward-only migrations to staging as a discrete, reviewable pipeline step with a
pre-application check. A staging reset must apply every migration in order; a failed migration must
abort the deploy; the applied history must be verifiable; and the migrator credential must exist only
in that step.

## 3. Scope

### 3.1 Included

- `planMigrations` — pure pre-application plan: pending set, checksum drift, applied-but-unknown,
  and a pending file that sorts before the last applied file.
- `apply-migrations.mjs` now runs the plan **before** applying anything, applies only the pending set,
  then re-verifies the complete history.
- `--plan` / `pnpm migrations:plan` — connect, plan, print the pending set, change nothing.
- `deploy-fly-staging.yml`: a preflight plan step, the apply step, and a post-apply history check. A
  refusal or SQL failure fails the step, so the deploy does not continue.
- `tests/migration-plan.test.ts` — eight checks over fresh, partial and refused plans.
- Runbook note: the pipeline and its refusal rules.

### 3.2 Excluded / blocked

- **`F-29` — the migrator credential.** The runbook says migrations run as `hivorr_migrator`, but the
  role is `nologin` and the runner authenticates with the deployment credential. Making the role a
  login role is a credential and schema decision that needs an architect ruling; this task does not
  silently change it. The workflow still uses the deployment URL.
- **`F-28` — no committed schema baseline.** `db diff` cannot be clean without one; the pipeline
  records the applied set but cannot yet assert a clean diff.
- Running the workflow or touching staging. No database was available locally.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | A staging reset applies all migrations in order. | Plan `062` |
| R-02 | A pre-application check runs before any change. | Plan `062` |
| R-03 | A changed applied checksum is refused. | Runner property |
| R-04 | An applied file absent from the repository is refused. | History integrity |
| R-05 | An out-of-order pending file is refused. | Forward-only rule |
| R-06 | Each file is transactional and recorded only on success. | Runner property |
| R-07 | A failed migration aborts the deploy. | Plan `062` outcome |
| R-08 | The applied history is verified after application. | Runner property |
| R-09 | The plan is reviewable without applying. | Plan `062` |
| R-10 | The migrator credential is CI-only. | Plan `062` outcome — **blocked `F-29`** |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-021` migration runner | **REQUIRES_REVIEW** |
| `EP-01-022` roles/grants | **REQUIRES_REVIEW** — `hivorr_migrator` is `nologin` |
| `EP-01-060` staging topology | **REQUIRES_REVIEW** — verified live |
| `EP-01-061` release identity | **REQUIRES_REVIEW** — digest chain in place |
| `F-28` schema baseline | Open |

## 6. Implementation plan

1. Read the runner, history verifier, roles and deploy step.
2. Add the pure migration plan.
3. Run the plan before apply and apply only pending files.
4. Add `--plan` and the post-apply verification.
5. Add the workflow preflight and verification steps.
6. Add the unit tests and run the gates.
7. Record `F-29` and `F-28` as the remaining blockers.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `apply-migrations.mjs` | **Extend** | Already transactional, locked and checksum-aware |
| `verifyMigrationHistory` | **Reuse** | Post-apply completeness |
| `migrationChecksum` | **Reuse** | One checksum definition |
| `platform.schema_migrations` | **Reuse** | The history table |
| `migrations:verify` | **Reuse** | Deployment history check |
| Deploy migration step | **Extend** | Add plan and verify |

**Must not be duplicated:** a second checksum, history table, or migration runner.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `scripts/lib/migration-history.mjs` | `planMigrations` |
| `scripts/apply-migrations.mjs` | Preflight, pending-only apply, post-verify, `--plan` |
| `tests/migration-plan.test.ts` | **New** |
| `package.json` | `migrations:plan` |
| `.github/workflows/deploy-fly-staging.yml` | Plan and verify steps |
| `STAGING_PROVISIONING.md` | Pipeline note and `F-29` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No migration, credential or role changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | A fresh database plans every file in order. |
| DoD-02 | A partial database plans only the pending files. |
| DoD-03 | Checksum drift is refused. |
| DoD-04 | An unknown applied file is refused. |
| DoD-05 | An out-of-order pending file is refused. |
| DoD-06 | The plan runs before any apply. |
| DoD-07 | The post-apply history is verified. |
| DoD-08 | A failure exits non-zero and stops the deploy step. |
| DoD-09 | The plan is reviewable with `--plan`. |
| DoD-10 | Local gates pass. |
| DoD-11 | The migrator credential is CI-only. **Accepted residual 2026-11-10** — distinct `MIGRATOR_DATABASE_URL`; role stays `nologin`. |

## 10. Acceptance criteria

- `pnpm migrations:plan` prints the pending set and changes nothing.
- A changed checksum refuses before the first pending migration is applied.
- An applied file missing from the repo refuses.
- A pending file older than the last applied file refuses.
- A failing SQL file rolls back its transaction and exits non-zero.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/migration-plan.test.ts` |
| T-02 | `pnpm test:db` — applies every migration to a fresh database (CI service) |
| T-03 | `pnpm migrations:plan` / `migrations:apply` / `migrations:verify` against a database |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` |
| T-05 | Deploy workflow on staging |
| T-06 | A seeded failing migration in the CI database job |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| A partial run leaves history inconsistent. | The plan refuses before applying; each file is transactional; post-apply verification. |
| An out-of-order file appears. | The plan refuses a pending file older than the last applied. |
| Drift is discovered mid-run. | The plan checks all applied entries first. |
| The credential is too broad. | `F-29`; the role question needs a ruling. |
| No baseline for `db diff`. | `F-28`; recorded. |
| No local Postgres. | The unit tests cover the plan; the database job covers SQL. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | The CI database job runs the plan/apply/verify sequence, `F-29` is ruled, and `F-28` provides a baseline |
| **Execution record** | `execution-records/EP-01-062.md` |
