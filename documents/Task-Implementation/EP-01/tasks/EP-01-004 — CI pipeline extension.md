# EP-01-004 — CI pipeline extension

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-004` |
| **Task title** | CI pipeline extension |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — CI configuration |
| **Execution order** | 4 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage A |
| **Dependencies** | `002` (workspace), `003` (shared contracts), EP-00 CI |

## 2. Objective

Extend the EP-00 pipeline so every stage in `ARCHITECTURE.md` §12.2 has a real, failing gate:
multi-package install and build, lint/format, typecheck, contract and unit tests, migration lint and
a schema-diff review artefact, OpenAPI diff, visual regression, and dependency plus secret scanning.
Each gate must be proven able to fail by a seeded fixture, not merely present in YAML.

## 3. Scope

### 3.1 Included

- Add the missing gates to `.github/workflows/ci.yml` and a single `ci-complete` status job.
- Add `pnpm test:contracts`, `pnpm lint:migrations`, `pnpm db:snapshot`, `pnpm db:diff`,
  `pnpm openapi:diff`, `pnpm visual:check` and `pnpm test:gates`.
- Add `scripts/lint-migrations.mjs` — structural migration checks from
  `Database-Migration-and-Supabase-Data-API-Rules.md` §9.
- Add `scripts/db-schema-snapshot.mjs` and `scripts/db-schema-diff.mjs` — deterministic schema
  snapshot and reviewable diff, reusing `pg`.
- Add `scripts/openapi-diff.mjs` — breaking-change detection with a JSON document, dormant until
  `013` publishes the first spec.
- Add `scripts/visual-diff.mjs` and `scripts/lib/png.mjs` — dependency-free PNG comparison, dormant
  until `050` publishes a baseline.
- Add `scripts/test-ci-gates.mjs` — seeded-failure proofs for typecheck, contract, migration,
  OpenAPI, visual and secret gates.
- Add `tests/ci-pipeline.test.ts` — asserts the pipeline wiring cannot be silently removed.
- Run `pnpm test:push-protection` in CI; it is currently absent.
- Record the `F-03` ratification and the legacy-migration exception.

### 3.2 Excluded

- The OpenAPI document and generated client — `013`.
- The Playwright harness, screenshot capture and visual baseline — `050`.
- Migration edits or renames. Applied migrations are never renamed (§9.3).
- Branch protection, environment reviewers or deployment gating — `060`/`063`, `DEV-002`.
- Replacing the custom boundary linter, migration runner or outbox. `F-03` is ratified.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Every stage 1–9 in `ARCHITECTURE.md` §12.2 is represented in CI. | Architecture §12.2 |
| R-02 | Each blocking gate has a seeded fixture that proves it exits non-zero. | Plan `004` outcome |
| R-03 | No new runtime dependency; `pg`, `vitest`, `tsc` and `git` are reused. | Standards §3.4, TEC-11 |
| R-04 | Migration lint enforces §9.3 naming and §9.4 self-containment for **new** files only, because applied migrations cannot be renamed. | DB rules §9.3–§9.4 |
| R-05 | Destructive SQL requires an explicit `destructive-approved` comment. | DB rules §9.6 |
| R-06 | The schema snapshot is deterministic and contains no data, secrets or connection details. | DB rules §11.1 |
| R-07 | OpenAPI and visual gates are dormant, not green-by-accident, when their artefacts do not exist. | Plan `004`, `013`, `050` |
| R-08 | CI remains `contents: read`; no new action, secret or write permission is introduced. | Standards §4A |
| R-09 | One `ci-complete` job depends on every gate, so a single status represents the pipeline. | Architecture §12.3 (compensating control) |
| R-10 | A structural test fails if a required gate is removed from `ci.yml` or `package.json`. | Reuse rule |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-002` workspace | **COMPLETED** 2026-11-09 |
| `EP-01-003` shared contracts | **COMPLETED** 2026-11-09 |
| `F-03` ruling | **Ratified 2026-11-09** — as-built tools accepted |
| Postgres 17 in CI | Provided by the existing `database` job service |
| `pg` 8.16.3 | Already a root dependency; reused |
| Playwright | **Approved** (`EX-10`, ruling 3) but installed by `050`, not this task |

## 6. Implementation plan

1. Read `ci.yml`, the migration runner, the secret scan, the format gate and the phase plan.
2. Write `lint-migrations.mjs` with a legacy allowlist for the 11 applied files.
3. Write `db-schema-snapshot.mjs` and `db-schema-diff.mjs`.
4. Write `openapi-diff.mjs` with fixture-driven breaking-change detection.
5. Write `lib/png.mjs` and `visual-diff.mjs`.
6. Write `test-ci-gates.mjs` covering typecheck, contract, migration, OpenAPI, visual and secret.
7. Add the scripts to `package.json`; extend `verify`.
8. Extend `ci.yml` with the gates, the artefact summary and `ci-complete`.
9. Add `tests/ci-pipeline.test.ts`.
10. Run every gate, the seeded proofs, lint, boundaries, typecheck and both builds.
11. Update the tracker, overview and execution record.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `.github/workflows/ci.yml` | **Extend** | Already owns install, lint, typecheck, test, database, build and security jobs |
| `scripts/lint.mjs`, `lint-boundaries.mjs`, `format-check.mjs` | **Reuse as-is** | Working gates; `F-03` ratifies the boundary linter |
| `scripts/test-db-migrations.mjs` | **Reuse as-is** | Applies migrations and asserts the foundation; the snapshot runs after it |
| `scripts/secret-scan.mjs` | **Reuse as-is** | Already accepts explicit paths, so the seeded proof needs no change |
| `pg` 8.16.3 | **Reuse** | Snapshot uses the existing driver; no new dependency |
| `vitest` 4.1.12, `typescript` 5.9.3 | **Reuse** | Seeded proofs invoke the installed binaries |
| `git` | **Reuse** | Base-spec extraction and diff output |
| `GITHUB_STEP_SUMMARY` | **Reuse** | Review artefact without adding an upload action |
| `tests/workspace-contracts.test.ts` | **Reuse as-is** | The contract gate is the existing suite |
| `actions/checkout`, `pnpm/action-setup`, `actions/setup-node` | **Reuse at the existing pins** | No new action is added |
| `supabase/migrations/*.sql` | **Do not rename** | Applied migrations are immutable (§9.3) |

**Must not be duplicated:** a second migration runner, a second boundary linter, a second secret
scanner, a second test runner, a second contract suite, or a second schema source of truth. The
snapshot is derived output, never authoritative.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `.github/workflows/ci.yml` | Extend jobs and add `ci-complete` |
| `package.json` | Add gate scripts; extend `verify` |
| `scripts/lint-migrations.mjs` | **New** |
| `scripts/db-schema-snapshot.mjs` | **New** |
| `scripts/db-schema-diff.mjs` | **New** |
| `scripts/openapi-diff.mjs` | **New** |
| `scripts/visual-diff.mjs` | **New** |
| `scripts/lib/png.mjs` | **New** |
| `scripts/test-ci-gates.mjs` | **New** |
| `tests/ci-pipeline.test.ts` | **New** |
| `.gitignore` | Ignore generated `artifacts/` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | CI contains install, lint/format, typecheck, contract/unit tests, build, visual, OpenAPI, dependency/secret and migration/schema gates. |
| DoD-02 | `pnpm test:gates` proves typecheck, contract, migration, OpenAPI, visual and secret gates fail on seeded input. |
| DoD-03 | `pnpm lint:migrations` passes on the repository and fails on a bad name, a destructive statement without approval, and a new table without RLS. |
| DoD-04 | `pnpm db:snapshot` produces a deterministic, data-free snapshot; `pnpm db:diff` reports added and removed schema lines. |
| DoD-05 | `pnpm openapi:diff` fails on a removed operation and passes on an additive change. |
| DoD-06 | `pnpm visual:check` fails on a changed pixel and passes on identical images. |
| DoD-07 | `pnpm test:push-protection` runs in CI. |
| DoD-08 | `ci-complete` depends on every gate job. |
| DoD-09 | `pnpm typecheck`, `pnpm lint`, `pnpm lint:boundaries`, `pnpm build:all`, `pnpm build:server` pass. |
| DoD-10 | `tests/ci-pipeline.test.ts` fails if a required gate is removed. |
| DoD-11 | No new dependency, permission, secret or action. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- A pull request that removes the contract test, breaks a type, adds a malformed migration, removes
  an OpenAPI operation, changes a screenshot or commits a token is blocked by a named job.
- The OpenAPI and visual jobs report themselves dormant, with an explicit message, until `013` and
  `050` provide their artefacts; they never report a false pass after the artefact exists.
- The database job publishes a schema snapshot a reviewer can read without reading the migrations.
- The pipeline remains read-only and adds no new action or secret.
- Removing a gate from `ci.yml` fails `tests/ci-pipeline.test.ts`.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test:gates` — all six seeded proofs behave as intended |
| T-02 | `pnpm lint:migrations` on the repository; then on fixtures (bad name, destructive, missing RLS) |
| T-03 | `pnpm db:diff` on two fixture snapshots — added and removed lines are reported |
| T-04 | `pnpm openapi:diff` on fixtures — breaking fails, additive passes |
| T-05 | `pnpm visual:check` on generated PNG fixtures — changed fails, identical passes |
| T-06 | `pnpm test -- tests/ci-pipeline.test.ts` |
| T-07 | `pnpm typecheck`, `lint`, `lint:boundaries`, `build:all`, `build:server` |
| T-08 | Prototype and theme diff against `v0.0.1-bootstrap` |
| T-09 | Full `pnpm test` — Windows argon2 limitation recorded, not suppressed |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Existing migrations violate §9.3 naming and §9.4 self-containment | Legacy allowlist; applied files are never renamed; new files are strict. Recorded as `F-12`. |
| No local Postgres or Docker on the workstation | Snapshot is exercised in CI; the diff is unit-tested with snapshots. CI is the reference. |
| OpenAPI and visual gates have no artefacts yet | Dormant with an explicit message; seeded proofs live in `test:ci-gates`. |
| A dormant gate can be mistaken for a pass | The job summary states `dormant (artefact not yet published)` and the named owner task. |
| Byte-level screenshot comparison is strict | Default threshold is 0.1% of pixels; `050` may add tolerance when Playwright lands. |
| A temporary contract fixture could be left behind | Created under `tests/` with a unique name and removed in `finally`; `.gitignore` also covers it. |
| CI YAML is hard to test | `tests/ci-pipeline.test.ts` asserts the required commands and the `ci-complete` dependency set. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Gate code complete** | 2026-11-09 |
| **Closes when** | a green GitHub Actions run is observed, plus the `test:gates` job |
| **Execution record** | `execution-records/EP-01-004.md` |
