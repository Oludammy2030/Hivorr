# EP-01 — Phase Evidence Pack and Traceability Index

**Task:** `EP-01-070`
**Date:** 2026-11-10
**Phase status:** `In build` — **not complete**
**Worktree:** `staging` at `8d461d2`; EP-01 work is **uncommitted**
**Authority:** `EP-01 — Core Platform Foundation & Infrastructure.md` §13

> A criterion without an observed artifact is unmet. This index records what was executed, where the
> result lives, and what was not executed. It does not convert a task status into phase completion.

---

## 1. Phase completion criteria

Legend: **Met** = artifact observed; **Partial** = code/artifact exists but the required run or proof is
missing; **Unmet** = no artifact or a known failure; **Open** = depends on a later task.

| # | Criterion | Status | Evidence | Gap |
|---|---|---|---|---|
| C1 | Entry gate satisfied | **Met** | `Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md`; `evidence/decision-pack.md`; `evidence/protection-403.log` | — |
| C2 | Build graph works in CI | **Partial** | Local: `typecheck`, `lint` (20 baseline), `lint:boundaries` (87 files / 10 modules), `format:check` (186 files), `build:all` (four bundles), `build:server`, `test:api`, `test:worker-smoke` | **No CI run observed**; work is uncommitted and `gh` is unavailable |
| C3 | Contract generated; breaking diff fails | **Partial** | `openapi/openapi.json` (25 paths); `packages/api-client/src/index.ts`; `openapi-contract.test.ts`; `openapi-diff.mjs`; seeded proof in `test:gates` | `openapi:check` fails locally only because generated files are uncommitted; CI run unobserved |
| C4 | Schema reproducible; `db diff` clean | **Unmet** | `scripts/test-db-migrations.mjs`; `migrations:plan/apply/verify`; 17 migrations | No local PostgreSQL; CI database job unobserved; **`F-28` no committed schema baseline**, so `db diff` cannot be clean |
| C5 | Least privilege proven; migrator CI-only | **Partial** | `test-db-migrations.mjs` asserts five roles cannot log in, API cannot DDL/alter/truncate; `database-roles.test.ts`; migration job now uses a distinct `MIGRATOR_DATABASE_URL` never set on Fly | Database assertions run only in CI (unobserved); `F-29` is an accepted residual — `hivorr_migrator` stays `nologin`, login role is a pre-production follow-up |
| C6 | RLS fails closed | **Partial** | `test-db-migrations.mjs` (14 tables, FORCE RLS, one policy per operation, allow and deny probes); `rls-policy.test.ts`; `identity-schema.test.ts` | DB-backed proof only in the unobserved CI database job |
| C7 | Session isolation proven | **Partial** | `identity-session.test.ts`; `identity-integration.test.ts`; audience guard; refresh rotation/reuse code | Seven suites cannot load argon2 on Windows (`F-10`); CI unobserved |
| C8 | Capability authority proven | **Partial** | `capability-registry.test.ts`; `capabilities.test.ts`; `enforcement.test.ts`; table-driven registry in `server/src/domain` | Integration/DB-backed checks in the unobserved CI job |
| C9 | Enforcement in transaction | **Partial** | `enforcement.test.ts`; `transaction.test.ts`; `withTransaction`; service-layer guards | Live DB path in CI unobserved |
| C10 | Audit immutable | **Partial** | `test-db-migrations.mjs` rejects update/delete; `audit.test.ts`; append-only triggers in migrations | DB proof in the unobserved CI job |
| C11 | Visual identity preserved | **Partial** | Founder approval 2026-11-10 (`EP-01-050`); 9-image baseline at 375/768/1280; zero-tolerance diff unchanged; sign-in exact parity at three widths; no new font; `F-47` tokens additive | Registration uses the approved divergence (`F-48`); activity/recovery screens are not pixel-compared |
| C12 | Staging provable | **Unmet** | Topology probe: four hosts, valid TLS, Access challenges, edge health (`evidence/staging-topology/2026-11-10.md`) | **`F-49` staging API predates `/v1/session` and `/v1/activities` (404)**; **`F-50` slice bundle not deployed**; smoke and E2E correctly fail |
| C13 | Operability baseline | **Partial** | Structured logger/redaction (`logger.test.ts`); correlation (`server-correlation.test.ts`); health/readiness; worker queue health; error-tracker seam | Live log/worker wiring only in unobserved CI smoke; `F-40` free-text redaction |
| C14 | Budgets captured | **Partial** | `bundles:check`: main 121.4 KB gzip, each portal 71.0 KB, inside 200 KB | **API read/write latency not measured**; route-JS budget measured on the built artifact |
| C15 | Quality gates honest | **Partial** | `test:gates` 23/23; typecheck/lint/boundaries/format/config; secret scan; OpenAPI/visual/migration/db jobs in CI | CI run unobserved |
| C16 | Review complete | **Open** | — | `EP-01-071` not started |
| C17 | Closure signed | **Open** | — | `EP-01-072` not started |

**Result: 1 met, 11 partial, 2 unmet, 2 open.** The phase is **not** complete and must not be reported
as closed.

---

## 2. Task traceability

Statuses are authoritative in `Task-Implementation/EP-01/PHASE_EXECUTION_TRACKER.md`. Each row links to
its execution record; no task is marked `COMPLETED` without a met DoD.

| Group | Count | Record location |
|---|---|---|
| **COMPLETED** — `001`, `002`, `003`, `012`, `034` | 5 | `execution-records/EP-01-<id>.md` |
| **REQUIRES_REVIEW** — every other build task through `063` | 30 | `execution-records/EP-01-<id>.md` |
| **PENDING** — `070`, `071`, `072` | 4 at pack start, then 2 | This pack, then `071`/`072` |

The tracker is authoritative for the exact per-task row. No task is `COMPLETED` without a met DoD and an
execution record.

The tracker currently records **5 completed, 30 review, 4 pending, 0 blocked**.

---

## 3. Gate and run evidence (local, 2026-11-10)

| Gate | Result | Artifact |
|---|---|---|
| `pnpm typecheck` | Pass | command output |
| `pnpm lint` | 20 known baseline, 0 new | `scripts/lint.mjs` output |
| `pnpm lint:boundaries` | 87 files, 10 modules | output |
| `pnpm format:check` | 186 files | output |
| `pnpm test` | 38 files / 278 tests pass, 7 skipped; 7 suites fail to load argon2 (`F-10`) | output |
| `pnpm test:gates` | 23/23 seeded proofs | output |
| `pnpm config:check` | 33 keys, 5 secrets | output |
| `pnpm bundles:check` | main 121.4 KB, portals 71.0 KB gzip | output |
| `pnpm test:design-parity` | 9 exact comparisons at 3 widths | output |
| `pnpm test:slice-parity` | Sign-in exact at 3 widths | output |
| Visual baseline | 9 images, zero-tolerance change | `visual/baseline/` |
| Release manifest | Four bundles recorded and verified | output |

**Not run:** CI, coverage, API latency measurement, security-header tests, live E2E.

---

## 4. Staging evidence

| Check | Result | Artifact |
|---|---|---|
| Four staging hosts resolve with valid TLS | Pass | `evidence/staging-topology/2026-11-10.md` |
| Access challenges control/staff/partner | Pass | same |
| Edge `/api/v1/health/live` 200, staging | Pass | same |
| `pnpm smoke:staging` | **Fail** — session 404, activities 404 (`F-49`) | `execution-records/EP-01-063.md` |
| `pnpm e2e:slice` | **Fail** — `/slice.html` serves a fallback (`F-50`) | same |
| Staging runs the candidate digest | **Not true** — `releaseSha` unrecorded / stale image | `F-49` |

---

## 5. Open findings that block closure

| ID | Finding | Owner | Closure condition |
|---|---|---|---|
| `F-04` | Secret provider: Doppler recorded vs GitHub/Fly as-built | Founder / architect | **Closed 2026-11-10** — no Doppler; GitHub + Fly ratified with compensating controls; standards §16 #8 needs a revision; manual-rotation residual |
| `F-08` | `DATABASE_SSL_CA` unset; pooler certificate not verified | Architect | Set and verified |
| `F-28` | No committed schema baseline; `db diff` not clean | Architect | Baseline committed |
| `F-29` | Migrator role `nologin`; runner uses deployment credential | Architect | **Accepted 2026-11-10** — distinct CI-only `MIGRATOR_DATABASE_URL`, never set on Fly; login migrator role before production |
| `F-40` | Key-based redaction misses free-text provider PII | Architect | Scrubber or accepted |
| `F-41` | Rate limits are per process | Architect | Shared store before scaling |
| `F-43` | Baseline covers entry screens only | Architect | `053`/future extraction |
| `F-44` | Visual determinism pinned to Windows/Chromium/Google Fonts | Architect | First CI visual run |
| `F-45` | `C.gray` has no `--hivorr-gray` token | Architect | Theme touch |
| `F-49` | Staging API stale; session/activities 404 | Founder | Deploy current digest |
| `F-50` | Pages rollout manual; slice not deployed | Architect / founder | Publish bundles |
| `F-51` | Registry image digest not captured | Architect | flyctl digest capture |
| — | No CI run observed | Founder | Push and green CI |
| — | Coverage not measured | Architect | Coverage report in CI |
| — | API latency budget not measured | Architect | Staging measurement |

Closed this phase: `F-27` (topology record), `F-46` (recovery URLs), `F-47` (auth tokens), `F-48`
(registration divergence), `F-30`/`F-31` (schema), `F-03` (ratified selections).

---

## 6. What EP-01 does not prove

- Verification, KYC or document handling.
- Money movement, escrow, splits or reconciliation.
- That any of the six activity experiences is usable; only activation state exists.
- That the control, staff or partner portals perform their functions; only bundles and hosts exist.
- That the system is production-ready. EP-01 exits on staging; G4 is later.

---

## 7. Third-party reproduction

```sh
pnpm install --frozen-lockfile
pnpm check:toolchain
pnpm lint && pnpm lint:boundaries && pnpm lint:migrations
pnpm topology:verify && pnpm config:check
pnpm typecheck
pnpm test && pnpm test:contracts && pnpm test:release && pnpm test:topology
pnpm test:gates
pnpm build:all && pnpm bundles:check && pnpm build:server
pnpm test:api && pnpm test:worker-smoke
pnpm verify:staging-hosts
pnpm smoke:staging
pnpm e2e:slice --base https://staging.hivorr.com
```

The last two are expected to fail until `F-49` and `F-50` are deployed. That failure is the evidence
that the promotion gate is real.

---

## 8. Index of primary artifacts

| Area | Path |
|---|---|
| Tracker | `Task-Implementation/EP-01/PHASE_EXECUTION_TRACKER.md` |
| Overview / findings | `Task-Implementation/EP-01/PHASE_OVERVIEW.md` |
| Task records | `Task-Implementation/EP-01/tasks/` |
| Execution records | `Task-Implementation/EP-01/execution-records/` |
| Entry and decisions | `Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md`, `evidence/decision-pack.md` |
| CI gates and seeded failures | `scripts/test-ci-gates.mjs`, `evidence/seeded-failures.log` |
| Contract | `openapi/openapi.json`, `packages/api-client/src/index.ts` |
| Database | `supabase/migrations/`, `scripts/test-db-migrations.mjs`, `scripts/apply-migrations.mjs` |
| Visual | `visual/baseline/`, `scripts/visual-*.mjs`, `scripts/slice-screen-parity.mjs` |
| Design | `packages/design/`, `tests/design-primitives.test.tsx` |
| Staging | `Engineering-Execution/STAGING_PROVISIONING.md`, `evidence/staging-topology/2026-11-10.md` |
| Smoke / E2E | `scripts/smoke-staging.mjs`, `scripts/e2e-slice.mjs` |
