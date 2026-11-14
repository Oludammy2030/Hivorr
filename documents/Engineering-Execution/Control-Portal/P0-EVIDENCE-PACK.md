# Control Portal — P0 Evidence Pack

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/P0-EVIDENCE-PACK.md` |
| **Pack date** | 11 November 2026 |
| **Workstream** | `CP` |
| **Scope** | CP-001 … CP-008 (P0 foundation) |
| **Status** | **SUPERSEDED — 14 November 2026.** Kept for history; the current evidence index is `REVIEW-REGISTER.md` and the review records are `REVIEW-BATCH-A.md`, `-B.md` and `-C.md`. |
| **Approver status** | Not signed. Superseded before sign-off; the packages it covers are now `REVIEWED` in `EXECUTION-TRACKER.md`, awaiting founder sign-off. |

> This pack states what was run and what it proves. It is not a claim that the Control Portal is
> complete, secure or production-ready. A criterion without an artifact is unmet.

> **Superseded.** This pack was written on 11 November 2026, before CI produced a run for `4e29364`
> and before any independent review existed. The packages it covers are now recorded in
> `REVIEW-REGISTER.md`, independently reviewed in `REVIEW-BATCH-A.md`, and carry `REVIEWED` status in
> the execution tracker. Do not cite this pack as current evidence; the register and the batch
> reviews replace it.

---

## 1. Package status

| ID | Package | Status | Evidence |
|---|---|---|---|
| CP-001 | Decision closure and governance charter | **COMPLETED** | Decision record; governance architecture; architecture/matrix/execution-structure amendments |
| CP-002 | Administrative authorization model | **REQUIRES_REVIEW** | Migration, pure composition, tests; database run passed |
| CP-003 | Capability registry and context extension | **REQUIRES_REVIEW** | Registry, permission/deny rules, tests, OpenAPI |
| CP-004 | Admin read path and user directory | **REQUIRES_REVIEW** | Security-definer read, permission check, audit, cursor, UI; database run passed |
| CP-005 | Audit contract extension | **REQUIRES_REVIEW** | Migration, filters/cursor, read-of-audit, UI, tests; database run passed |
| CP-006 | Admin schema foundation | **REQUIRES_REVIEW** | Organisation, partner, case, evidence, approval and configuration tables; database run passed |
| CP-007 | Control shell foundation | **REQUIRES_REVIEW** | Router, permission-aware nav, 404/unauthorised states, authority endpoint; route tests; design-token migration partial |
| CP-008 | P0 test matrix and evidence | **REQUIRES_REVIEW** | This pack; `tests/control-p0-matrix.test.ts`; `tests/control-routes.test.ts`; local gates and database run |

---

## 2. Commands and results

Environment: Windows workstation, Node 22, pnpm 10.34.9, 11 November 2026.

| Command | Result | What it proves |
|---|---|---|
| `pnpm typecheck` | PASS | Type contracts compile across the workspace |
| `pnpm test:db` | **PASS** — all 23 migrations applied to a disposable PostgreSQL 16.15 instance; admin tables, roles, RLS and append-only audit verified | Migrations are executable and self-contained |
| `pnpm test` | PASS — 50 files, 356 tests, 31 skipped | Unit, schema, contract and component checks |
| `pnpm lint` | PASS — 20 known baseline, 0 new | No new lint debt |
| `pnpm lint:boundaries` | PASS | App/server/package import boundaries hold |
| `pnpm lint:migrations` | PASS — 23 migrations (12 strict, 11 legacy) | New migrations follow naming/self-containment rules |
| `pnpm format:check` | PASS | Formatting consistent |
| `pnpm docs:check` | PASS | Work-package governance intact |
| `pnpm build:all` | PASS | Web, control, staff and partner bundles build |
| `pnpm build:server` | PASS | Server build succeeds |
| `pnpm openapi:generate` | PASS — 27 paths | Contract and generated client include the authority and audit endpoints |

**Not run:** CI on the exact commit, staging deployment and a live founder-role assignment. The
database gate did run against a disposable PostgreSQL 16.15 instance; the log is
`evidence/db-migration-test-2026-11-11.txt`.

---

## 3. Controls and their tests

| Control | Test / artifact |
|---|---|
| Every admin capability is control-only and default-deny | `tests/control-p0-matrix.test.ts` |
| Explicit deny is scope-aware and overrides allow | `tests/admin-authorization.test.ts`, `tests/capability-registry.test.ts`, `tests/capabilities.test.ts` |
| Role/permission composition and scope | `tests/admin-authorization.test.ts` |
| Admin tables enable and force RLS | `tests/control-p0-matrix.test.ts`, `tests/admin-schema.test.ts` |
| No API write grant on admin tables | `tests/control-p0-matrix.test.ts`, `tests/admin-schema.test.ts` |
| User directory checks the platform permission in-database | `tests/admin-authorization-schema.test.ts`, `tests/control-p0-matrix.test.ts` |
| Audit is append-only and extended | `tests/audit.test.ts`, `tests/control-p0-matrix.test.ts` |
| Audit read is filtered, bounded and itself audited | `tests/audit.test.ts`; `server/src/api/audit.controller.ts` |
| Case timeline and approval decisions are append-only | `tests/admin-schema.test.ts` |
| Case spine, evidence hash and supersession | `tests/admin-schema.test.ts` |
| Approval schema supports maker-checker | `tests/admin-schema.test.ts` |
| Control routes are URL-addressable and permission-aware | `apps/control/src/routes.ts`; `tests/control-routes.test.ts` |
| Control shell renders 404 and unauthorised states | `apps/control/src/App.tsx`; source review (no browser E2E yet) |
| Contract and controllers agree | `tests/openapi-route-coverage.test.ts`, `tests/openapi-contract.test.ts` |

---

## 4. Residual risk

| Risk | Severity | Mitigation / next step |
|---|---|---|
| No CI run on the exact commit | **High** | Open PR, run all gates |
| Independent review outstanding (`DEV-003`) | **High** | Second reviewer or recorded compensating controls |
| Design-token migration for the control shell is partial | Medium | CP-007 follow-up; do not duplicate the palette |
| Session capability list does not yet include role permissions | Medium | CP-007/CP-012 composition; the control shell now uses `/v1/control/authority` |
| No role/staff/partner/case feature endpoints yet | Medium | CP-010…CP-024; schema is intentionally deny-all until then |
| No staff/partner UI yet | Medium | Later tranches |
| Audit hash chain not implemented | Medium | CP-043; retain append-only trigger now |
| Retention/legal hold open | Medium | O-06; no purge is built |
| Founder role assignment is out-of-band | Low | `bootstrap-staging-admin.ps1`; assignment is audited later by CP-012 |

---

## 5. Conditions to move P0 from `REQUIRES_REVIEW` to `COMPLETED`

1. Run the database policy tests and the full suite in CI on Linux.
2. Obtain independent review of the authorization, audit and migration changes.
3. Record the staging deployment artifact and smoke result.
4. Assign the founder role on staging and verify the user directory and audit read with the composed
   authority endpoint.
5. Approve this evidence pack and update `EXECUTION-TRACKER.md`.

Until then, the P0 tranche is **implemented but not verified**.

---

**End of P0 evidence pack.**
