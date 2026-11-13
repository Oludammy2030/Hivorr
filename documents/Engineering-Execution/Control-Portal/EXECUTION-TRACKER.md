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
| CP-009 | Audit actor accountability and portal deploy parity | EP-02 | **REQUIRES_REVIEW** | `20261112000100_platform_alter_audit_actor_snapshot.sql`; `20261112000200_platform_alter_audit_actor_role_scope.sql`; actor name/email/role/scope/capability snapshots; Actor column shows role, scope and name; `deploy-pages` job publishes all four bundles from the verified artifact; local gates green |
| CP-011 | Grant organisation by department | EP-02 | **REQUIRES_REVIEW** | `20261112000300_identity_grants_department.sql`; department on each grant; department list and drill-in with search and status filter; grant holder's name in the read model; assignment audited with a reason |
| CP-010 | Staff records and lifecycle | EP-02 | **REQUIRES_REVIEW** | `20261113000100_admin_create_staff_lifecycle.sql`; `20261113000200_admin_add_staff_profile_attachment.sql`; `staff.controller.ts`; `staff-invite.controller.ts`; `staff.service.ts`; Staff screen; `/invite.html` page; existing-account onboarding; ZeptoMail invitation email; OpenAPI regenerated; staging deploy green |
| CP-012…CP-024 | P1 core governance | EP-02 | `PENDING` / gated | — |
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

### CP-009 — Audit actor accountability and portal deploy parity

- **Class:** `[REVIEW]` — audit schema, personal-data snapshot, API contract and deployment change.
- **Scope in:** `platform.audit_log` actor snapshot columns; `platform.resolve_audit_actor`; control sign-in classified as `admin`; grant audit carries the authorising capability; Audit screen shows role, assignment scope, name and capability; Pages deployment job for all four bundles.
- **Scope out:** role administration UI; historical actor backfill (the information was never captured and is not invented); staff/partner portal content.
- **Reuse:** `platform.audit_log`, `admin.role_assignments`, `admin.roles`, `appendAudit`, release manifest verification, `wrangler pages deploy`.
- **Dependencies:** CP-004, CP-005.
- **Test plan:** audit writer unit tests for actor classification, capability, scope parsing and legacy rows; scope assertions in the migration run; grant snapshot assertions in the grants integration test; `pnpm test`; `bundles:check`; release-manifest verification.
- **Audit impact:** R2 identity data (name, email) and the role scope are snapshotted per governed action; no evidence or financial data. Rows written before the migrations keep empty snapshots and display the actor type.
- **Rollback:** the snapshot columns are additive; reverting the application restores the previous insert shape. Pages rollback is a redeploy of the previous commit's artifact.
- **Approver:** Architect; founder for the personal-data snapshot and the audit-read presentation.

### CP-011 — Grant organisation by department

- **Class:** `[REVIEW]` — schema, authorization surface, API contract and UI change.
- **Scope in:** `identity.grants.department_id`; four seeded departments; `identity.list_grants` read model with the holder's name and department; `identity.set_grant_department`; `admin.list_departments`; `GET /v1/control/departments`; `PATCH /v1/control/grants/:id/department`; department list, drill-in, search and status filter in the Grants screen.
- **Scope out:** department administration UI; bulk re-homing; moving a grant between environments; staff and partner portal grant views.
- **Reuse:** `admin.departments`, `identity.grants`, `admin.actor_has_platform_permission`, `identity.actor_has_grant`, `appendAudit`, existing grant capabilities.
- **Dependencies:** CP-003, CP-004.
- **Test plan:** migration run asserts the column, the seeded departments and that both new functions refuse without the capability; grants integration test proves department-required creation, unknown-department rejection, the catalogue, denial without `admin.grant.manage`, assignment with a reason and the stored audit row; `pnpm test`; `bundles:check`; OpenAPI diff additive only.
- **Audit impact:** R3 governance metadata. Creating a grant records the department; re-homing a grant writes `identity.grant_department_set` with the operator, the department and the reason. No evidence or financial data.
- **Rollback:** drop the column and the two functions in a forward migration; the read model falls back to the previous shape. Grants keep working because the department never authorises anything.
- **Approver:** Architect; founder for the department catalogue and the grant grouping.

### CP-010 — Staff records and lifecycle

- **Class:** `[REVIEW]` — authorization, personal data, schema, API contract and UI change.
- **Scope in:** `admin.staff_invites`; staff directory; invite, attach-existing, suspend, reactivate, offboard and department functions; `GET /v1/control/staff`; `POST /v1/control/staff/invites`; `POST /v1/control/staff/attach`; `POST /v1/control/staff/:userId/{suspend,reactivate,offboard}`; `PATCH /v1/control/staff/:userId/department`; `POST /v1/auth/staff-invite/accept`; Staff screen; `/invite.html` acceptance page; ZeptoMail invitation email with copy-link fallback.
- **Scope out:** role and permission assignment (CP-012); maker-checker approvals (CP-020); bulk import; marketing or bulk email.
- **Reuse:** `admin.staff_profiles`, `admin.department_members`, `identity.users`, `identity.credentials`, `admin.actor_has_platform_permission`, `appendAudit`, existing controller and audience patterns.
- **Dependencies:** CP-002, CP-006.
- **Test plan:** migration run asserts the table, indexes, functions and grants; functions refuse without the capability; invite rejects an invalid email, a short reason, an unknown department and an existing account; acceptance consumes the token once; attaching an existing account creates one profile and refuses a duplicate or unknown email; suspension revokes sessions and offboarding also revokes grants, role assignments and membership; control link derivation, acceptance rate-limit and ZeptoMail adapter unit tests; full suite, OpenAPI and build gates.
- **Audit impact:** R2 personal and governance data. Invite creation, status changes, department moves and acceptance write audit rows with the operator, the reason and the capability. No evidence or financial data.
- **Rollback:** forward-only; drop the table and functions in an approved destructive migration after redeploying the previous release. Identity accounts and staff profiles remain valid.
- **Approver:** Architect; founder for staff personal data and immediate revocation.

#### CP-010 evidence (12 November 2026)

| Gate | Result |
|---|---|
| PR #62 (API, control screen, invite page) | Merged into `staging`; CI run `43299358738` green |
| PR #63 (invite link targets the main portal) | Merged into `staging`; CI run `43301288438` green |
| PR #64 (evidence record) | Merged into `staging`; CI run `43304311084` green |
| PR #65 (acceptance rate limit and audit correction) | Merged into `staging`; CI run `43306927743` green; Fly deployment green |
| PR #67 (attach an existing account as staff) | Merged into `staging`; CI run `43316369230` green; Fly deployment green; `admin.attach_staff_profile` present on staging |
| PR #69 (ZeptoMail invitation email) | Merged into `staging`; CI run `43366122425` green; Fly deployment green; `PUBLIC_APP_ORIGIN` and `MAIL_FROM_ADDRESS` present on staging |
| PR #71 (CPaaS API endpoint) | Merged into `staging`; CI run `43371795264` green; Fly deployment green; `ZEPTOMAIL_API_URL=https://cpaas.zoho.com/v1.1/email` present on staging |
| PR #72 (token that already carries the auth scheme) | Merged into `staging`; CI run `43373923656` green; Fly deployment `1eabb61` green; the send-only token authenticates against the live endpoint |
| Transactional email end-to-end | `mail.hivorr.com` verified in Zoho CPaaS with DKIM `1221557._domainkey` and bounce CNAME `bounce-zem.mail.hivorr.com → cluster89.zeptomail.com`; a real staff invitation from the control screen was delivered |
| Staging deployment gate | Runs `43301894294` and later green; Pages job deployed all four bundles |
| `pnpm typecheck`, `lint`, `format:check`, `lint:boundaries`, `docs:check`, `lint:migrations`, `config:check` | PASS |
| `pnpm test` | PASS — 54 files, 372 passed, 32 skipped |
| `pnpm openapi:check`, `build:all` | PASS — 36 paths |
| Live staging | `https://staging.hivorr.com/invite.html` serves the invitation page; the staff API route is registered |
| `pnpm test:db` | Not run locally (Docker unavailable); the CI database job passed |

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
8. Departments are seeded by migration and there is no department administration screen yet. A grant
   is placed in a department when it is created; grants issued before CP-011 appear under
   "Unassigned" until an administrator records the department. (CP-011)
9. Capability and grant labels live in `packages/shared/src/labels.ts` so every portal explains
   authority the same way. Control and staff consume it today; the partner portal is still a
   foundation shell with no authorisation screen to label.
10. Staff invitation email uses ZeptoMail under the Zoho CPaaS name. It is live on staging against
    the verified `mail.hivorr.com` sending domain. The copy-link fallback remains for a provider
    failure. The invitee's email must also be added to Cloudflare Access separately. (CP-010)

---

**End of tracker.**
