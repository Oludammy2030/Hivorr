# EP-01 — Review Queue Verification Record

| Field | Value |
|---|---|
| **Record** | `EP-01-REVIEW-QUEUE-VERIFICATION` |
| **Phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Date** | 2026-11-15 |
| **Purpose** | Verify the 31 `REQUIRES_REVIEW` tasks against the current CI, staging and local evidence before G5 |
| **Authority** | EES §9.3 evidence rule; EP-01-071 review addendum |

> This record does not sign G5. It closes task DoDs where the stated closure condition is evidenced and
> lists the tasks that still need a founder/architect decision.

---

## 1. Evidence base

| Evidence | Result |
|---|---|
| CI run `43677010391` (PR #127) | **Green** — install, lint/format, typecheck, unit/contract/policy, seeded gates, OpenAPI, visual, database, build, security and `ci-complete` |
| CI run `43675612150` (schema baseline) | **Green** — database job with `db diff --fail-on-change` |
| Staging Fly deploy `43675801983` | **Green** — `82e5599` reported by `/v1/health/live` |
| Staging Pages deploy `43675802021` | **Green** — slice bundle published |
| `pnpm smoke:staging` | **9/9 pass** |
| `pnpm e2e:slice` | **5/5 pass**; authenticated checks skipped (`M-08`) |
| `pnpm typecheck` | **Pass** |
| `pnpm lint` | **Pass** — 20 known baseline, 0 new |
| `pnpm lint:boundaries` | **Pass** — 126 files, 10 modules |
| `pnpm test:gates` | **23/23 pass** |
| `pnpm openapi:check` | **Pass** — 67 paths regenerated with no diff |
| `pnpm test:design-parity` | **Pass** — 9 exact comparisons |
| `pnpm test:slice-parity` | **Pass** — sign-in exact at three widths |
| `pnpm visual:check` after local capture | **1 difference** — `login-375.png`, 0.193%; CI visual job is green. Local environment difference is recorded under `F-44`, not a product change. |

---

## 2. Tasks verified and closed

These tasks meet their stated closure condition on the evidence above.

| Task | Title | Closure evidence |
|---|---|---|
| `EP-01-004` | CI pipeline extension | CI `43677010391`; `test:gates` 23/23 |
| `EP-01-010` | API bootstrap and runtime configuration | CI build job runs `test:api`; API bootstrap suite green |
| `EP-01-011` | Common request pipeline and error contract | CI unit/contract/policy suite and `test:api` green |
| `EP-01-013` | OpenAPI 3.1 contract and generated client | CI OpenAPI job; `openapi:check` 67 paths; client consumed by `src/features` |
| `EP-01-014` | Worker, PostgreSQL queue and outbox | CI database job `test:worker`; build job `test:worker-smoke` |
| `EP-01-021` | Migration runner and baseline schemas | CI `test:db`, double apply, `migrations:verify`; baseline committed |
| `EP-01-022` | Database roles, grants and default privileges | CI database role suite; `F-29` accepted residual |
| `EP-01-023` | Identity schema | CI catalog/identity suites |
| `EP-01-024` | Profile, activity and platform schema | CI constraint/RLS assertions |
| `EP-01-032` | Session lifecycle, audiences and session endpoint | `admin.govern_user` revokes sessions on suspension; `tests/account-governance.test.ts`; CI `43677010391` |
| `EP-01-035` | Service-layer enforcement and vertical-slice endpoints | CI enforcement/audit deny and allow suites |
| `EP-01-043` | Secret management and configuration contract | CI `config:check`; `F-04` closed by no-Doppler ruling |
| `EP-01-050` | Visual regression baseline and harness | CI visual job green against the approved baseline |
| `EP-01-051` | Design tokens and primitive extraction | CI visual/design parity; 9 exact comparisons |
| `EP-01-052` | Route manifest, router and providers | CI suite; slice shell mounted; E2E 5/5 |
| `EP-01-053` | Vertical-slice screens | CI green; E2E against staging `82e5599` |
| `EP-01-054` | Four-bundle build and deployment targets | CI build job `bundles:check`; Pages deploy |
| `EP-01-062` | Migration application pipeline | CI plan/apply/verify; baseline; `F-29` accepted |

**Closed: 18.** These move from `REQUIRES_REVIEW` to `COMPLETED`.

---

## 3. Tasks requiring an explicit decision

These tasks have a stated closure condition that is not met, or a condition that only the founder/architect can accept. They remain `REQUIRES_REVIEW`.

| Task | Why it remains open | Decision needed |
|---|---|---|
| `EP-01-020` | Staging `db:check --expect-role hivorr_api` was not run; `F-08` (`DATABASE_SSL_CA` unset) remains | Accept staging TLS gap or set/verify the CA |
| `EP-01-025` | `F-32` ruling: do service-internal `platform` tables without an account column need RLS? | Architect ruling |
| `EP-01-026` | `F-33`: session/MFA/grant flows still use manual transaction blocks; identity adoption is incomplete | Accept technical debt or complete adoption |
| `EP-01-030` | Identity repositories do not yet cover every flow (`031`/`032` remaining) | Accept or complete |
| `EP-01-031` | Recovery delivery is capture-only (`F-34`); no email/SMS provider | Accept for EP-01 |
| `EP-01-033` | `F-36`: activation transition table needs ratification | Architect ratification |
| `EP-01-036` | Retention is open (`F-39`); no purge is built | Accept retain-and-hold |
| `EP-01-040` | `F-40`: key-based redaction can miss free-text PII | Accept or add a scrubber |
| `EP-01-041` | CSP is absent; edge header tests are incomplete | Accept or implement CSP |
| `EP-01-042` | `F-41`: rate limits are per process | Accept for single-instance staging |
| `EP-01-060` | `F-08` database certificate and readiness 503 remain | Accept for staging or remediate |
| `EP-01-071` | Independent reviewer gap (`DEV-003`); addendum sign-off pending | Architect/founder acceptance |
| `EP-01-072` | G5 signature pending | Founder signature |

**Open: 13.**

---

## 4. Honest position

The phase is materially stronger than the 2026-11-10 pack: 18 review tasks are now backed by a green
CI run, a current staging deployment, a clean schema diff and a passing slice E2E. The remaining 13
are not all defects; most are documented residuals. But G5 should not be signed until each is either
accepted explicitly or remediated.

The highest-value remediation remains `EP-01-041` (CSP) and `EP-01-040` (free-text redaction). The
highest-value acceptance is `EP-01-060` (`F-08` staging TLS) and `EP-01-071`/`072` (review/signature).

---

**Record status:** complete for this verification pass. Task statuses are updated in
`PHASE_EXECUTION_TRACKER.md`.
