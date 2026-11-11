# Control Portal — Execution Tracker

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/EXECUTION-TRACKER.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Updated** | 11 November 2026 |
| **Authority** | `DECISION-RECORD.md` (approved 11 November 2026) |
| **Status rule** | A package is `COMPLETED` only with a linked artifact. Code alone is `REQUIRES_REVIEW`. |

---

## 1. Status

| ID | Package | Owning phase | Status | Evidence |
|---|---|---|---|---|
| CP-001 | Decision closure and governance charter | Cross-phase (pre-EP-02) | **COMPLETED** | Decision record; governance architecture; architecture/matrix/execution-structure amendments |
| CP-002 | Administrative authorization model | EP-02 (foundation) | **REQUIRES_REVIEW** | `20261111000100_admin_create_authorization_tables.sql`; `server/src/modules/admin/authorization.ts`; pure tests; database migration run passed 2026-11-11 |
| CP-003 | Capability registry and context extension | EP-02 (foundation) | **REQUIRES_REVIEW** | Capability registry additions; permission/deny rules; registry tests; OpenAPI regenerated |
| CP-004 | Admin read path and user-directory remediation | EP-02 (foundation) | **REQUIRES_REVIEW** | `20261111000200_admin_create_user_read_functions.sql`; scoped user read; audit; cursor pagination; control UI update; database migration run passed 2026-11-11 |
| CP-005 | Audit contract extension | EP-02 | **REQUIRES_REVIEW** | `20261111000400_platform_alter_audit_contract.sql`; audit read filters/cursor; read-of-audit record; control UI; tests; database migration run passed 2026-11-11 |
| CP-006 | Admin module schema foundation | EP-02 | **REQUIRES_REVIEW** | `20261111000500_admin_create_organisation_tables.sql`; `20261111000600_admin_create_case_and_approval_tables.sql`; schema tests; database migration run passed 2026-11-11 |
| CP-007 | Control shell foundation | EP-02 | **REQUIRES_REVIEW** | `react-router` routes; permission-aware navigation; `GET /v1/control/authority`; 404 and unauthorised states; **design-token migration still partial** |
| CP-008 | Deny/allow/RLS evidence pack | EP-02 | **REQUIRES_REVIEW** | `P0-EVIDENCE-PACK.md`; `tests/control-p0-matrix.test.ts`; `tests/control-routes.test.ts`; local gates and database run green; **CI/review/staging outstanding** |
| CP-010…CP-024 | P1 core governance | EP-02 | `PENDING` / gated | — |
| CP-030…CP-038 | P2 advanced governance | EP-02–EP-05 | `PENDING` / gated | — |
| CP-040…CP-043 | P3 future | Later | `PENDING` / gated | — |

## 2. CP-001 evidence

- `documents/Engineering-Execution/Control-Portal/DECISION-RECORD.md` — D-01…D-08, D-13 approved; O-01…O-12 remain open.
- `documents/Context/Administrative-Governance-Architecture.md` — approved governance domain.
- `documents/Context/ARCHITECTURE.md` — §7.7, decision register row 20, changelog 11 November 2026.
- `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md` — §14.5 pointer.
- `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` — §8.1 `CP` exception and changelog.

## 3. CP-002/003/004 evidence

### Files

- `supabase/migrations/20261111000100_admin_create_authorization_tables.sql`
- `supabase/migrations/20261111000200_admin_create_user_read_functions.sql`
- `supabase/migrations/20261111000300_admin_seed_governance_roles.sql`
- `supabase/migrations/20261111000400_platform_alter_audit_contract.sql`
- `supabase/migrations/20261111000500_admin_create_organisation_tables.sql`
- `supabase/migrations/20261111000600_admin_create_case_and_approval_tables.sql`
- `server/src/modules/admin/authorization.ts`
- `server/src/modules/admin/index.ts`
- `server/src/domain/capabilities.ts`
- `packages/shared/src/capabilities.ts`
- `server/src/api/users.controller.ts`
- `server/src/api/audit.controller.ts`
- `server/src/api/control-authority.controller.ts`
- `server/src/contracts/schemas.ts`
- `server/src/openapi/operations.ts`
- `apps/control/src/App.tsx`, `apps/control/src/api.ts`, `apps/control/src/main.tsx`
- `scripts/bootstrap-staging-admin.ps1` — assigns the founder role out of band
- `tests/admin-authorization.test.ts`
- `tests/admin-authorization-schema.test.ts`
- `tests/admin-schema.test.ts`
- `tests/audit.test.ts`
- `tests/capabilities.test.ts`, `tests/capability-registry.test.ts`, `tests/workspace-contracts.test.ts`

### Commands run (11 November 2026, local Windows workstation)

| Command | Result |
|---|---|
| `pnpm typecheck` | PASS |
| `pnpm test` | PASS — 50 files, 356 tests, 31 skipped |
| `pnpm test:db` | PASS — 23 migrations on PostgreSQL 16.15; admin tables, RLS and append-only audit verified |
| `pnpm lint` | PASS — 20 known baseline, 0 new |
| `pnpm lint:boundaries` | PASS — 94 source files, 10 modules |
| `pnpm lint:migrations` | PASS — 23 migrations (12 strict, 11 legacy) |
| `pnpm format:check` | PASS — 198 files |
| `pnpm docs:check` | PASS — 2 phase plans, 53 identifiers |
| `pnpm build:all` | PASS — web, control, staff, partner |
| `pnpm build:server` | PASS |
| `pnpm openapi:generate` | PASS — 27 paths, client regenerated |

### Not yet evidenced

- CI run on the exact commit.
- Independent review (DEV-003 single-reviewer residual).
- Staging deployment and smoke.
- A live founder role assignment on staging (requires the updated bootstrap script to be run).

### Database evidence

- `pnpm test:db` against a disposable PostgreSQL 16.15 instance: **PASS**.
- All 23 migrations applied from empty.
- Schemas, platform tables, identity spine, roles, admin tables, RLS and the append-only audit
  trigger were verified by the database test.
- Log: `documents/Engineering-Execution/Control-Portal/evidence/db-migration-test-2026-11-11.txt`.

## 4. G0 records for the implemented packages

### CP-002 — Administrative authorization model

- **Class:** `[REVIEW]` — capability and migration change; second reviewer required (DEV-003 residual).
- **Scope in:** `admin` authorization tables; pure composition/evaluation; RLS; tests.
- **Scope out:** role administration screens; staff/partner/case tables; session composition.
- **Reuse:** `identity.grants`, `platform.current_user_id()`, `platform.uuidv7()`, existing capability deny-reason pattern.
- **Dependencies:** D-03, D-08.
- **Test plan:** pure composition; explicit deny overrides allow; expired assignment excluded; registry allow/deny for every capability; migration schema assertions.
- **Audit impact:** R2 identity/authority data; authority changes are audited by the later role administration package; no secret or production data.
- **Rollback:** forward-only; drop the new `admin` tables only with an approved destructive migration. Application code tolerates the absence of authority (default deny).
- **Approver:** Architect; founder for the widening of governance authority.

### CP-003 — Capability registry and context extension

- **Class:** `[REVIEW]` — authorization change.
- **Scope in:** new governance capability IDs; permission/deny requirements; context fields; tests; OpenAPI regeneration.
- **Scope out:** staff/partner capability expansion; session presentation.
- **Reuse:** existing `CapabilityId`, `CapabilityRule`, `evaluateCapability`, stable deny reasons.
- **Dependencies:** CP-002.
- **Test plan:** registry has one rule per ID; allow when permission supplied; deny when missing; explicit deny; wrong audience.
- **Audit impact:** none directly; enables audited actions.
- **Rollback:** remove the new IDs and rules in a forward commit; persisted permission rows remain harmless.
- **Approver:** Architect.

### CP-004 — Admin read path and user-directory remediation

- **Class:** `[REVIEW]` — authorization, personal data, API and UI change.
- **Scope in:** `admin.actor_has_platform_permission`, `admin.list_users`, `GET /v1/control/users`, audit of the read, cursor pagination, control UI consumption.
- **Scope out:** account actions; exports; user detail; staff context.
- **Reuse:** `identity.users`, `platform.audit_log`, `IdentityService`, audience guard, existing controller pattern.
- **Dependencies:** CP-002, CP-003.
- **Test plan:** schema assertions; capability deny path; permission check inside the function; bounded page; audit record; full suite.
- **Audit impact:** R2 identity data; every directory read writes `admin.users_listed`; no evidence or financial data.
- **Rollback:** revert the endpoint to a deny-only state by removing the capability assignment; the function can remain but is unreachable without the permission.
- **Approver:** Architect; founder for the read scope.

## 5. Known follow-ups

1. The session capability list (`GET /v1/session`) still composes grants and activities only. Role permissions are loaded by the control user endpoint, not yet by the session view. CP-007/CP-012 will compose the full authority for presentation.
2. `admin.audit.read` and `admin.grant.*` remain grant-gated, so a founder role does not replace the existing grants. The bootstrap script creates both.
3. Cursor pagination is implemented on the user directory; the control UI exposes "Load more" but does not yet show a page-size selector.
4. The `admin` schema is complete for P0, but no staff, partner, case or approval **feature endpoints**
   exist yet; those start in CP-010 and CP-016.
5. Explicit denials are scope-aware. Future resource policies must call `permissionScopes` rather than
   treating `deniedPermissions` as the whole answer.
6. Retention, legal hold, financial definitions and verification decisions remain open (O-01…O-12).
7. CI on the exact commit and independent review are the remaining gates before CP-002/003/004 move
   from `REQUIRES_REVIEW` to `COMPLETED`.

---

**End of tracker.**
