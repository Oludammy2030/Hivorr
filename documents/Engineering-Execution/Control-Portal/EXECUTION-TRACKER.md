# Control Portal — Execution Tracker

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/EXECUTION-TRACKER.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Updated** | 14 November 2026 |
| **Authority** | `DECISION-RECORD.md` (approved 11 November 2026) |
| **Status rule** | `REQUIRES_REVIEW` — implemented, no recorded review. `REVIEWED` — independent review pass recorded, findings closed, CI green on the merge commit, staging evidence present. `COMPLETED` — signed off by the founder against the reviewed evidence. |

---

## 1. Status

| ID | Package | Owning phase | Status | Evidence |
|---|---|---|---|---|
| CP-001 | Decision closure and governance charter | Cross-phase (pre-EP-02) | **COMPLETED** | Decision record; governance architecture; architecture/matrix/execution-structure amendments |
| CP-002 | Administrative authorization model | EP-02 (foundation) | **REVIEWED** | `20261111000100_admin_create_authorization_tables.sql`; `server/src/modules/admin/authorization.ts`; pure tests; database migration run passed 2026-11-11 |
| CP-003 | Capability registry and context extension | EP-02 (foundation) | **REVIEWED** | Capability registry additions; permission/deny rules; registry tests; OpenAPI regenerated |
| CP-004 | Admin read path and user-directory remediation | EP-02 (foundation) | **REVIEWED** | `20261111000200_admin_create_user_read_functions.sql`; scoped user read; audit; cursor pagination; control UI update; database migration run passed 2026-11-11 |
| CP-005 | Audit contract extension | EP-02 | **REVIEWED** | `20261111000400_platform_alter_audit_contract.sql`; audit read filters/cursor; read-of-audit record; control UI; tests; database migration run passed 2026-11-11 |
| CP-006 | Admin module schema foundation | EP-02 | **REVIEWED** | `20261111000500_admin_create_organisation_tables.sql`; `20261111000600_admin_create_case_and_approval_tables.sql`; schema tests; database migration run passed 2026-11-11 |
| CP-007 | Control shell foundation | EP-02 | **REVIEWED** | `react-router` routes; permission-aware navigation; `GET /v1/control/authority`; 404 and unauthorised states; **design-token migration still partial** |
| CP-008 | Deny/allow/RLS evidence pack | EP-02 | **REVIEWED** | `P0-EVIDENCE-PACK.md`; `tests/control-p0-matrix.test.ts`; `tests/control-routes.test.ts`; local gates and database run green; **CI/review/staging outstanding** |
| CP-009 | Audit actor accountability and portal deploy parity | EP-02 | **REVIEWED** | `20261112000100_platform_alter_audit_actor_snapshot.sql`; `20261112000200_platform_alter_audit_actor_role_scope.sql`; actor name/email/role/scope/capability snapshots; Actor column shows role, scope and name; `deploy-pages` job publishes all four bundles from the verified artifact; local gates green |
| CP-011 | Grant organisation by department | EP-02 | **REVIEWED** | `20261112000300_identity_grants_department.sql`; department on each grant; department list and drill-in with search and status filter; grant holder's name in the read model; assignment audited with a reason |
| CP-010 | Staff records and lifecycle | EP-02 | **REVIEWED** | `20261113000100_admin_create_staff_lifecycle.sql`; `20261113000200_admin_add_staff_profile_attachment.sql`; `staff.controller.ts`; `staff-invite.controller.ts`; `staff.service.ts`; Staff screen; `/invite.html` page; existing-account onboarding; ZeptoMail invitation email; OpenAPI regenerated; staging deploy green |
| CP-012 | Role administration | EP-02 | **REVIEWED** | `20261114000200_admin_add_role_administration.sql`; seeded role catalogue with permissions; assign and revoke with scope, expiry and reason; self-change and last-manager guards; Roles screen; audit rows; OpenAPI regenerated |
| CP-013 | Account governance | EP-02 | **REVIEWED** | `20261114000400_admin_add_account_governance.sql`; suspend, reactivate, close and revoke-sessions functions; operator notes; account timeline; Users detail actions; audit rows; OpenAPI regenerated |
| CP-020 | Approval and maker-checker | EP-02 | **REVIEWED** | `20261114000500_admin_add_approvals.sql`; typed requests over the existing approval tables; requester cannot decide; approver needs both `admin.approval.decide` and the action permission; account closure wired as the first action; Approvals screen; audit rows |
| CP-014 | Partner organisations | EP-02 | **REVIEWED** | `20261114000600_admin_add_partner_governance.sql`; partner register, lifecycle and representatives; `admin.partner.read/manage` permissions; partners screen; audit rows; OpenAPI regenerated |
| CP-015 | Partner isolation | EP-02 | **REVIEWED** | `20261114000700_admin_add_partner_isolation.sql`; self-scoped partner read model; `GET /v1/partner/organisations`; partner audience refuses control/activity surfaces; isolation integration tests |
| CP-016 | Case spine and timeline | EP-02 | **REVIEWED** | `20261114000800_admin_add_case_spine.sql`; case register, creation, append-only timeline, assignment and status; Cases screen; audit rows; OpenAPI regenerated |
| CP-017 | Case evidence metadata | EP-02 | **REVIEWED** | `20261114000900_admin_add_case_evidence.sql`; evidence metadata with SHA-256, access audit on the timeline, supersede link; case evidence UI; OpenAPI regenerated |
| CP-018 | Support and dispute operations | EP-02 | **REVIEWED** | `20261114001000_admin_add_case_decisions.sql`; case decisions routed through CP-020; outcome and closure reason on the case; decision events on the timeline; "Request decision" in the case detail; OpenAPI regenerated |
| CP-019 | Verification review | EP-02 | **REVIEWED** | `20261114001100_admin_add_verification_reviews.sql`; verification queue over review cases; evidence-gated approval; approve/reject/request-information with reason; Verification screen; audit rows |
| CP-021…CP-024 | P1 core governance | EP-02 | `PENDING` / gated | — |
| CP-030…CP-038 | P2 advanced governance | EP-02–EP-05 | `PENDING` / gated | — |
| CP-040…CP-043 | P3 future | Later | `PENDING` / gated | — |

## 1.1 Independent review evidence

Three review passes under `DEV-002` cover every implemented package. Each read the diff at the
merge commit, not the pull-request description (`QUA-30`), and recorded findings with the rule they
breach.

| Batch | Packages | Record | Findings | Closed | Open |
|---|---|---|---|---|---|
| A | CP-002 → CP-008 | `REVIEW-BATCH-A.md` | 7 | F-A-01, F-A-02, F-A-07 | F-A-03, F-A-04, F-A-05, F-A-06 |
| B | CP-010 → CP-015 | `REVIEW-BATCH-B.md` | 6 | F-B-01, F-B-02, F-B-04 | F-B-03, F-B-05, F-B-06 |
| C | CP-016 → CP-020 | `REVIEW-BATCH-C.md` | 5 | F-C-01, F-C-02, F-C-03 | F-C-04, F-C-05 |

The evidence index itself is `REVIEW-REGISTER.md` (Phase 1), which maps every package to its pull
requests, merge commit, CI run, Fly release, staging gate, migration and test files, and records
the eleven gaps it found (`G-01` → `G-11`).

Findings closed by pull request: #100 (F-A-01), #101 and #102 (F-A-02, F-A-07), #105 (F-B-01,
F-B-02, F-B-04), #107 (F-C-02, F-C-03), #108 (F-C-01). #103 wired the governance database suites
into CI, which is what turned their evidence from assertion into execution.

`REVIEWED` is not `COMPLETED`. Every package below still needs the founder's signature, and the
open findings above are recorded rather than waived.

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

### CP-005 — Audit contract extension

- **Class:** `[REVIEW]` — audit schema and API contract.
- **Scope in:** `reason`, `approval_reference` and `session_id` columns (additive); filtered, cursor-paged audit reads; `admin.audit_read` written on every read; Audit screen; `audit_log_action_idx`.
- **Scope out:** hash chain and signed export (approved in principle, later); historical backfill.
- **Reuse:** `platform.audit_log`, the append-only trigger, `appendAudit`, existing capability checks.
- **Test plan:** unit tests for actor classification, capability and scope parsing; `tests/audit.test.ts` covers filters and pagination; the CI database job applies the migration and verifies history.
- **Gap recorded at review:** "reason is required" exists only as a column comment (F-A-04). The columns are intentionally nullable so historical rows remain valid.
- **Approver:** Architect; founder for the audit-read presentation.

### CP-006 — Admin module schema foundation

- **Class:** `[REVIEW]` — new schema and RLS surface.
- **Scope in:** permissions, roles, role permissions, role assignments, permission grants, access denials, departments, staff profiles, department members, partner entities, cases, case events, evidence, findings, recommendations, decisions, actions, approvals, work items and configuration tables; forced RLS with self-scoped select policies only.
- **Scope out:** any feature endpoint; any write grant to `hivorr_api`.
- **Reuse:** `platform.uuidv7()`, `identity.users`, `platform.touch_updated_at()`.
- **Test plan:** schema assertions; `control-p0-matrix` proves enable/force RLS on every table and that no write grant exists; sensitive tables (cases, evidence, approvals) have no direct `SELECT` grant at all.
- **Review note:** the strongest part of the batch — access is function-only by construction.
- **Approver:** Architect.

### CP-007 — Control shell foundation

- **Class:** `[REVIEW]` — new control surface and a new authority endpoint.
- **Scope in:** `react-router` routes, permission-aware navigation, `GET /v1/control/authority`, 404 and unauthorised states, design tokens.
- **Scope out:** staff and partner shells; the design-token migration remains partial.
- **Reuse:** `computeCapabilities`, `loadAccessContext`, `AudienceGuard`.
- **Test plan:** `control-routes` covers path and title mapping; `control-p0-matrix` covers the audience of every admin capability; `slice-screens` covers rendering.
- **Finding at review:** the authority endpoint folded unscoped permissions into capabilities (F-A-01), fixed in #100.
- **Approver:** Architect.

### CP-008 — Deny/allow/RLS evidence pack

- **Class:** `[REVIEW]` — evidence, not code.
- **Scope in:** `P0-EVIDENCE-PACK.md`, `tests/control-p0-matrix.test.ts`, `tests/control-routes.test.ts`, local gate output, the first database run.
- **Scope out:** runtime proof of every deny path, which is the CI database job's role.
- **Evidence:** CI `43047734311`, Fly `43047734163` and staging gate `43047734228` on `4e29364`; the pack itself is now superseded by `REVIEW-REGISTER.md` and the batch reviews.
- **Finding at review:** the matrix tests assert on migration SQL text rather than behaviour (F-A-05); the pack's description overstated the runtime half (F-A-06).
- **Approver:** Architect.

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
- **Scope in:** `admin.staff_invites`; staff directory; invite, attach-existing, suspend, reactivate, offboard and department functions; `GET /v1/control/staff`; `POST /v1/control/staff/invites`; `POST /v1/control/staff/attach`; `POST /v1/control/staff/:userId/{suspend,reactivate,offboard}`; `PATCH /v1/control/staff/:userId/department`; `POST /v1/auth/staff-invite/accept`; `GET /v1/auth/staff-invite`; Staff screen; `/invite.html` acceptance page; ZeptoMail invitation email with copy-link fallback; two-address invitations (official `@hivorr.com` account, personal delivery address).
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
| PR #74 (branded invitation email) | Merged into `staging`; CI green; Fly release `9218786` |
| PR #75 (one email layout, inline brand mark, recovery pages) | Merged into `staging`; CI run `43381859309` green; Fly release `v57` on `e82f673`; `https://staging.hivorr.com/reset` and `/verify` serve `200` |
| PR #76 (official staff address, personal delivery address) | Merged into `staging`; CI run `43392130105` green including the database migration; Fly release `v58` on `d4c36f9`; `GET /v1/auth/staff-invite` returns `404` for an unknown token and `/invite` serves `200` |
| Staging deployment gate | Runs `43301894294` and later green; Pages job deployed all four bundles |
| `pnpm typecheck`, `lint`, `format:check`, `lint:boundaries`, `docs:check`, `lint:migrations`, `config:check` | PASS |
| `pnpm test` | PASS — 55 files, 388 passed, 32 skipped |
| `pnpm openapi:check`, `build:all` | PASS — 36 paths |
| Live staging | `https://staging.hivorr.com/invite.html` serves the invitation page; the staff API route is registered |
| `pnpm test:db` | Not run locally (Docker unavailable); the CI database job passed |

#### Control portal navigation and scrolling (13 November 2026)

UI-only change: no migration, no API contract change and no permission change.

| Gate | Result |
|---|---|
| Independent scrolling | `.app-shell` owns the viewport, `.app-main` scrolls with `min-height: 0` and `scrollbar-gutter: stable`, `.app-sidebar` scrolls its own nav, and `.app-topbar` sticks to the top of the content column. Panels may shrink below a wide table so it scrolls inside `.table-wrap` rather than the page. Below 720px the shell returns to normal document scroll. |
| Navigation | Grants leaves `NAV_GROUPS`. `/grants` remains in `SECTION_PATHS`, so the URL, permission gate and page still work. `SECTION_TITLES` now supplies the `<h1>`, independent of the nav. |
| Contextual entry | Users detail panel links to `/grants?user=<email>`; the Overview governance card links to `/grants` for callers with `admin.grant.read` but no `admin.user.read`. Department drill-in and back reflect `?department=` in the URL and apply client-side. |
| Scroll reset | Navigating between sections resets the content scroller to the top. |
| `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `docs:check` | PASS — no new lint violations |
| `pnpm test` | PASS — 55 files, 389 passed, 32 skipped |
| `pnpm build:all` | PASS — control, staff and partner bundles built |
| Browser pass | Built control bundle with a mocked API at 1440×900: section change pins the sidebar and topbar, only the content column scrolls, and navigation resets its scroll. At 375×667: static topbar, document scroll, no horizontal page overflow, and wide tables scroll inside their panel. No visual baseline covers the control portal, so this is manual evidence. |
| CI and staging deployment | PR #78; CI run `43399331197` green; Fly release `v60` on `bb87685`; staging deployment gate `43399686663` green. No migration was needed. |

### CP-012 — Role administration

- **Class:** `[REVIEW]` — authorization, governance data and API/UI change.
- **Scope in:** `admin.list_roles`, `admin.list_role_assignments`, `admin.list_role_scope_targets`, `admin.assign_role`, `admin.revoke_role`, `admin.actor_holds_platform_permission`; `GET /v1/control/roles`; `GET /v1/control/role-assignments`; `GET /v1/control/roles/scope-targets`; `POST /v1/control/role-assignments`; `POST /v1/control/role-assignments/{id}/revoke`; Roles screen with the catalogue, assignment form, search and status filters.
- **Scope out:** custom role creation (the seeded catalogue is the reviewed surface); permission editing; approval routing for sensitive assignments (CP-020); bulk assignment.
- **Reuse:** `admin.roles`, `admin.role_permissions`, `admin.role_assignments`, `admin.permission_grants`, `admin.access_denials`, `admin.departments`, `admin.partner_organisations`, `appendAudit`.
- **Dependencies:** CP-002, CP-006.
- **Test plan:** migration assertions for the catalogue, seed count and capability refusal; roles integration test covers a 403 without a governance role, catalogue permissions, assignment, duplicate, self-change, unknown role/user, missing reason, department scope, scope targets, revocation, self-revocation and the audit rows; `pnpm test`; `bundles:check`; OpenAPI route coverage.
- **Audit impact:** R3 governance data. Every assignment writes `identity.role_assigned` and every revocation `identity.role_revoked` with the operator, role, scope, reason and `admin.role.manage` capability.
- **Rollback:** drop the five functions and the five routes in a forward commit; the tables are untouched, so existing assignments remain valid.
- **Approver:** Architect; founder for the role catalogue and the self-change rule.

#### CP-012 evidence (13 November 2026)

| Gate | Result |
|---|---|
| PR #80 (schema, API, control screen) | Merged into `staging`; CI run `43408314881` green |
| Migration preflight | PR #80's first deploy was refused: a pending migration sorted before the applied `20261114000100`. PR #81 re-dated the file to `20261114000200`; no SQL changed. |
| PR #81 (migration order) | Merged; CI run `43409001140` green; Fly release `c5f40c9`; `apply-migrations: applied 20261114000200`; history verified 30 of 30 |
| Pages | Control bundle deployed from the verified artifact; contains "Assign a role", "Role catalogue" and the self-change note |
| API | `/v1/control/roles` and `/v1/control/role-assignments` return `403` unauthenticated, so the routes are registered |
| Local gates | `pnpm typecheck`, `lint`, `lint:boundaries`, `lint:migrations`, `format:check`, `docs:check`, `test` (389 passed), `build:portals`, `bundles:check`, OpenAPI generation and breaking-change gate all pass |
| Database | Migration run applies `20261114000200`; the catalogue, the eleven seeded roles and both capability refusals are asserted |
| Integration | `tests/roles-integration.test.ts` 6 of 6 pass against PostgreSQL 16.15 |

#### Role picker and compact catalogue (13 November 2026)

- `admin.list_assignable_staff(actor)` serves the picker, gated by `admin.role.manage` rather than
  `admin.user.read`, and lists only staff profiles with `engagement_status = 'active'` and an active
  account: name, official email and department.
- The Roles form replaces the manual email field with a filter and a staff selector; the assignment
  action moved into the panel heading and the catalogue is collapsed by default, so the button no
  longer requires scrolling.
- Integration test covers the 403 without `admin.role.manage`, the active-staff list, and that a user
  without a staff profile is not offered.
- Migration `20261114000300_admin_add_assignable_staff.sql`.

#### Access page (13 November 2026)

- Roles and Grants now share `/access/roles` and `/access/grants` under one **Access** navigation
  item, shown when the caller holds any role or grant capability.
- Each tab keeps its own capability gate; a caller with only grant rights is redirected to the Grants
  tab and never sees a role screen they cannot use.
- Legacy `/roles` and `/grants` redirect, preserving `?user=` and `?department=`, so the Overview card
  and user-detail links keep working.
- Route-manifest tests assert one section per path, the Access item's sibling highlight, and that
  Grants remains reachable without its own navigation item.
- A single person search sits above both tabs: it filters role assignments by name or email and
  switches the Grants tab to that person's grants across departments.

### CP-013 — Account governance

- **Class:** `[REVIEW]` — authorization, personal data, irreversible action and UI change.
- **Scope in:** `admin.govern_user`, `admin.add_user_note`, `admin.list_user_notes`, `admin.list_account_timeline`, `admin.user_notes`; suspend and reactivate; close with authority removal; per-account session revocation; operator notes; timeline; Users detail actions; audit rows.
- **Scope out:** maker-checker approval routing (CP-020), account merge, data deletion, restoring a closed account, bulk actions.
- **Reuse:** `identity.users`, `identity.sessions`, `identity.grants`, `admin.role_assignments`, `admin.permission_grants`, `platform.audit_log`, `admin.actor_holds_platform_permission`, `appendAudit`.
- **Dependencies:** CP-002, CP-003, CP-005; CP-020 is deferred, so sensitive actions are direct and audited rather than queued for a second approver.
- **Test plan:** migration run asserts the functions and the notes table and that governance refuses without `admin.user.manage`; the account integration test covers the 403, missing reason, self-action refusal, suspension with session revocation, reactivation, session revocation, closure that removes grants and roles, blocked sign-in, notes and the timeline; full suite and OpenAPI route coverage.
- **Audit impact:** R2 identity data. Every action writes `account.*` with the operator, reason, status and the counts of sessions, grants and roles revoked; notes are themselves audited.
- **Rollback:** drop the four functions and the notes table in a forward migration; statuses already changed remain, so a rollback must include an explicit data decision.
- **Approver:** Architect; founder for the irreversible closure path and the personal-data note store.

#### Session composition (13 November 2026)

- `GET /v1/session` now composes platform role permissions with grants and activities, so a
  governance role is authority in every portal rather than only in the control authority view.
- `platformPermissions` filters to platform-scoped assignments and removes platform/global denials;
  a department- or organisation-scoped role does not become a global capability.
- The session controller moved to the API layer so the identity module does not import the admin
  module; the module boundary lint stays green.
- The staff portal reads its capability summary from the session instead of `/v1/grants`.
- Tests: pure cases for `platformPermissions`; integration proves a platform role appears in the
  session and a department-scoped assignment does not.

### CP-014 — Partner organisations

- **Class:** `[REVIEW]` — authorisation, external organisation data and UI change.
- **Scope in:** partner register; create; activate, suspend and terminate; representatives linked to existing accounts; `admin.partner.read`/`admin.partner.manage`; Partners screen; audit rows.
- **Scope out:** partner applications workflow, agreement metadata, scope grants, partner portal screens and isolation (CP-015).
- **Reuse:** `admin.partner_organisations`, `admin.partner_representatives`, `admin.partner_agreements`, `admin.actor_holds_platform_permission`, `appendAudit`.
- **Dependencies:** CP-002, CP-006.
- **Test plan:** migration asserts the permissions and that the register refuses without them; partner integration test covers 403, registration, the lifecycle with a terminated-state refusal, representatives including duplicate and unknown account, and the audit rows; full suite and OpenAPI route coverage.
- **Audit impact:** R3 partner data. Registration, every status change and every representative link write an audit row with the operator and reason.
- **Rollback:** drop the five functions in a forward migration; organisations and representatives remain stored and can be re-exposed by a later function.
- **Approver:** Architect; founder for onboarding and termination.

### CP-015 — Partner isolation

- **Class:** `[REVIEW]` — authorization and audience isolation change.
- **Scope in:** `admin.list_own_partner_organisations`; `GET /v1/partner/organisations`; partner audience boundary proof; terminated organisations hidden; tests for A/B isolation and capability denial.
- **Scope out:** partner portal screens, partner activity capabilities, row-level policies for direct table access (the read model is function-only), partner agreement/application workflows.
- **Reuse:** `admin.partner_representatives`, `admin.partner_organisations`, `identity.getSession`, audience guard, capability composition.
- **Dependencies:** CP-014, CP-007.
- **Test plan:** isolation integration proves each partner sees only their organisation, a partner cookie is refused on control and wrong-audience routes, no governance or write capability appears in a partner session, and a terminated organisation disappears from the partner view.
- **Audit impact:** none directly; reads are not audited, consistent with the existing read policy.
- **Rollback:** drop the function and route in a forward commit; the partner audience returns to its foundation state.
- **Approver:** Architect; founder for the partner boundary.

#### CP-015 evidence (13 November 2026)

| Gate | Result |
|---|---|
| Migration | `20261114000700_admin_add_partner_isolation.sql` applied; history verified **35 of 35** |
| API | Release `5946647`; `/v1/partner/organisations` returns `403` unauthenticated |
| Isolation tests | 4 of 4: each partner sees only their organisation; a partner cookie is refused on control and wrong-audience routes; no governance or write capability appears in a partner session; a terminated organisation disappears |
| Full suite | 391 passed; typecheck, lint, boundaries, format, bundles and OpenAPI **55 paths** pass |

### CP-016 — Case spine and timeline

- **Class:** `[REVIEW]` — authorisation, case data and UI change.
- **Scope in:** case register; create; list with status/type/search filters; append-only timeline; assignment to an account or queue; status changes with a reason; `admin.case.read`/`admin.case.assign`; Cases screen; audit rows.
- **Scope out:** evidence upload (CP-017), messages and resolution (CP-018), verification lanes (CP-019), approvals on decisions, investigation workspace (CP-021).
- **Reuse:** `admin.cases`, `admin.case_events`, `admin.actor_holds_platform_permission`, `appendAudit`; approval tables remain ready for the decision step.
- **Dependencies:** CP-002, CP-006.
- **Test plan:** migration asserts the case register refuses without permission; the case integration test covers 403, creation with a first timeline event, filtered listing, note/assign/status events and the audit rows; full suite and OpenAPI route coverage.
- **Audit impact:** R3 case data. Creation, assignment, notes and status changes are audited with the operator and reason where required.
- **Rollback:** drop the six functions in a forward migration; case rows and events remain stored.
- **Approver:** Architect; founder for the case scope and retention.

### CP-017 — Case evidence metadata

- **Class:** `[REVIEW]` — evidence integrity, access auditing and UI change.
- **Scope in:** evidence metadata register with optional SHA-256; access recorded on the case timeline; supersede link between originals; `admin.case.read`/`admin.case.assign`; evidence section in the case detail; audit rows.
- **Scope out:** binary upload and signed download URLs (requires R2 credentials and object-storage wiring), retention jobs, quarantine workflow, evidence decisions.
- **Reuse:** `admin.case_evidence`, `admin.case_events`, `admin.actor_holds_platform_permission`, `appendAudit`.
- **Dependencies:** CP-016.
- **Test plan:** migration asserts the evidence register refuses without permission; the case suite proves metadata registration, hash validation, access events, supersede and the 403 for a reader without the case permission.
- **Audit impact:** R3 evidence metadata. Upload registration and supersede are audited; every access appends a timeline event.
- **Rollback:** drop the four functions in a forward migration; evidence rows remain stored.
- **Approver:** Architect; founder for evidence retention and the private storage policy.

### CP-018 — Support and dispute operations

- **Class:** `[REVIEW]` — authorization, case outcome and approval wiring.
- **Scope in:** decision requests for a case, routed through CP-020; outcome and closure reason stored on the case; `decision_requested`, `decision_recorded` and `decision_rejected` timeline events; "Request decision" in the case detail; approver must hold both `admin.approval.decide` and `admin.case.approve`.
- **Scope out:** threaded customer messages, SLA timers, automated escalation rules, evidence decisions, bulk resolution.
- **Reuse:** CP-016 case spine, CP-020 approval primitive, `admin.case_events`, `appendAudit`.
- **Dependencies:** CP-016, CP-020.
- **Test plan:** the approval suite proves a decision request, self-decision refusal, approval that sets `DECIDED` with the recorded outcome, and the timeline events; the case suite covers the working spine.
- **Audit impact:** R3 case data. The request, decision and outcome are audited with the operator and reason.
- **Rollback:** drop `request_case_decision` and restore the previous `decide_approval`; decided cases keep their outcome.
- **Approver:** Architect; founder for the separation-of-duties rule on decisions.

### CP-019 — Verification review

- **Class:** `[REVIEW]` — authorisation, personal-data review and decision.
- **Scope in:** verification queue over `verification_review` cases; lane, review state and evidence count; approve, reject and request-information with a reason; evidence-gated approval; case outcome and timeline events; `admin.verification.review`; Verification screen; audit rows.
- **Scope out:** automated lane routing, SLA timers, document OCR, identity-provider integration, approvals on verification decisions (the decision is direct and audited).
- **Reuse:** CP-016 cases, CP-017 evidence, `admin.case_events`, `appendAudit`.
- **Dependencies:** CP-016, CP-017.
- **Test plan:** verification suite covers 403, the queue with evidence count, an approval that sets `DECIDED` with `verification_approved`, refusal to approve without evidence, and information requests that move the case to `PENDING_INFORMATION`; migration asserts the queue gate.
- **Audit impact:** R2 identity data. Each decision writes `verification.<state>` with the officer, reason and evidence count.
- **Rollback:** drop the table and two functions in a forward migration; cases keep their last state.
- **Approver:** Architect; founder for the verification decision policy.

### CP-020 — Approval and maker-checker

- **Class:** `[REVIEW]` — authorization, irreversible action and new control surface.
- **Scope in:** `admin.request_approval`, `admin.list_approval_requests`, `admin.decide_approval`; typed requests over the existing `admin.approval_requests`, `approval_steps`, `approval_decisions` tables; account closure as the first wired action; Approvals screen; audit rows.
- **Scope out:** additional action types, multi-stage or threshold routing, delegation, expiry jobs, notification delivery (CP-023).
- **Reuse:** approval tables from CP-006, `admin.actor_holds_platform_permission`, `admin.govern_user`, `platform.audit_log`, `capabilities.ts`.
- **Dependencies:** CP-006, CP-013.
- **Test plan:** migration asserts the permission and that the register refuses without it; the approval integration test covers a request, a self-decision refusal, duplicate refusal, approval that closes the account and revokes grants and roles, and rejection that leaves the target active; full suite and OpenAPI route coverage.
- **Audit impact:** R2 governance data. Requests, approvals, rejections and the executed closure each write an audit row with the operator, reference and reason.
- **Rollback:** drop the three functions in a forward migration; existing requests and decisions remain readable. Account closure already executed is not undone.
- **Approver:** Architect; founder for the separation-of-duties rule.

#### CP-020 evidence (13 November 2026)

| Gate | Result |
|---|---|
| Migration | `20261114000500_admin_add_approvals.sql` applied; history verified **33 of 33** |
| API | Release `9f215e3`; `/v1/control/approvals` returns `403` unauthenticated for GET and POST |
| Pages | Control bundle `index-DcP2dcBx.js` contains **Approvals**, **Request closure** and the second-approver note |
| Approval integration | 4 of 4: request, self-decision refusal, duplicate refusal, approval that closes and revokes, rejection that leaves the target active |
| Account integration | 5 of 5 after the direct close path was retired |
| Full suite | 391 passed; typecheck, lint, boundaries, format, bundles and OpenAPI (51 paths, 0 breaking) pass |

## 5. Known follow-ups

1. Role permissions now compose into `GET /v1/session` for every portal. Only platform-scoped
   assignments are folded into the session capabilities, so a department-scoped role cannot become a
   global capability; scoped authority is enforced at the resource layer when those features arrive.
   The staff portal reads its capability summary from the session for the same reason.
2. `admin.audit.read` and `admin.grant.*` remain grant-gated, so a founder role does not replace the existing grants. The bootstrap script creates both.
3. Cursor pagination is implemented on the user directory; the control UI exposes "Load more" but does not yet show a page-size selector.
4. The `admin` schema is complete for P0, but no staff, partner, case or approval **feature endpoints**
   exist yet; those start in CP-010 and CP-016.
5. Explicit denials are scope-aware. Future resource policies must call `permissionScopes` rather than
   treating `deniedPermissions` as the whole answer.
6. Retention, legal hold, financial definitions and verification decisions remain open (O-01…O-12).
7. The independent review gate is closed for every implemented package: three batch passes are
   recorded in `REVIEW-BATCH-A.md`, `-B.md` and `-C.md`, their High and Medium findings are fixed on
   `staging`, and the governance database suites now run in CI. The remaining gate is founder
   sign-off: no package is `COMPLETED` until it is signed against that evidence.
8. Departments are seeded by migration and there is no department administration screen yet. A grant
   is placed in a department when it is created; grants issued before CP-011 appear under
   "Unassigned" until an administrator records the department. (CP-011)
9. Capability and grant labels live in `packages/shared/src/labels.ts` so every portal explains
   authority the same way. Control and staff consume it today; the partner portal is still a
   foundation shell with no authorisation screen to label.
10. Staff invitation email uses ZeptoMail under the Zoho CPaaS name. It is live on staging against
    the verified `mail.hivorr.com` sending domain. The copy-link fallback remains for a provider
    failure. The invitee's **official** `@hivorr.com` address must also be added to Cloudflare
    Access separately; the personal address is delivery-only. (CP-010)
11. New migrations must be dated after the newest applied migration. The staging preflight refuses a
    pending file that sorts earlier, which is what happened to the first CP-012 deploy; a future-dated
    migration already in the applied set is the usual cause. (CP-012)
12. Role assignments carry no environment column. Each environment has its own database, so a staging
    assignment cannot reach production in practice; the reasoning is recorded rather than adding a
    column that would change every role query. Revisit if one database ever hosts two environments.
    (CP-012)
13. Roles and grants share one Access section with two tabs and a single person search. The search
    filters role assignments by name or email and shows that person's grants across departments; each
    tab keeps its own permission gate and URL, and `/roles` and `/grants` redirect to the new URLs so
    contextual links keep working. (CP-012)
14. Account closure now goes through CP-020: the control UI raises a request and a second administrator
    must approve. The old `POST /users/{id}/close` path is kept for contract compatibility but answers
    `409` and points at `/v1/control/approvals`; the direct close is gone. The approver needs both
    `admin.approval.decide` and `admin.user.manage`, so the decision carries the authority to perform
    the action. Reopening a closed account still has no supported path.
15. The partner boundary is enforced at the API, but the partner portal is still a foundation shell.
    Its screens will consume `GET /v1/partner/organisations`; no organisation id is accepted, so the
    portal inherits the isolation instead of re-implementing it. (CP-015)
16. Every transactional message renders through one shared layout, so the brand cannot drift between
    messages. Password reset and email verification now carry a link to `/reset.html` and
    `/verify.html`; before this they sent a bare token with no page to use it on. Both pages need a
    real-browser pass on staging. (EP-01-031)
17. A staff invitation carries two addresses: the official `@hivorr.com` address becomes the
    account, and the personal address only receives the invitation. Acceptance never asks for an
    email, so the personal address cannot be used to register or sign in. The official mailbox is
    still created in the mail system by hand; the portal does not provision or suspend it. (CP-010)
18. A new grant still defaults to the first department alphabetically because the session response
    does not expose the operator's own department. Stage 2 will add that field so the form can
    pre-select it while keeping a free choice. (CP-011)
19. `admin.list_departments` is gated by `admin.grant.read` or `admin.grant.manage`, but the Staff
    screen also calls it to populate the invite form. A staff manager without a grant capability
    currently sees an error there. Stage 2 will also accept `admin.user.read`. (CP-010/CP-011)
20. Open review finding F-A-03: `admin.list_users` passes `%` and `_` through to `ilike` unescaped.
    No injection, but wildcard enumeration and a forced scan. (CP-004)
21. Open review finding F-A-04: the audit "reason is required" rule is a column comment. Neither the
    schema nor `appendAudit` enforces it for sensitive actions. (CP-005)
22. Open review finding F-B-03: the staff status audit before-state reads `admin.staff_profiles`
    under self-only RLS, so it is empty for every target other than the actor. (CP-010)
23. Open review finding F-B-05: the invite rate limiter is per API process, so the budget multiplies
    across Fly machines and resets on restart. Move it to shared state before production scale.
    (CP-010)
24. Open review finding F-C-04: eight governance permissions are seeded and shown as capabilities
    but checked by nothing. `admin.case.investigate`, `admin.payment.review`,
    `admin.dispute.resolve`, `admin.account.suspend`, `admin.configuration.write` and
    `admin.report.export` belong to unbuilt packages; `admin.case.recommend` and
    `admin.evidence.read` are now enforced. (CP-003)
25. Case **write** paths (`add_case_event`, `assign_case`, `set_case_status`, `add_case_evidence`,
    `supersede_case_evidence`) still act on any case id, including one the actor cannot see. A case
    read is now scoped (F-C-01); the write paths are the remaining half and need the same predicate.
    (CP-016)
26. `create_case` does not set `department_id`, so a new case enters the unfiled pool until someone
    files or assigns it. A department picker on creation is the natural follow-up to the visibility
    rule. (CP-016)
27. No browser pass has been recorded for the Denials tab (`/access/denials`), and the control portal
    still has no visual baseline. The staff invite flow, `/reset` and `/verify` are also unverified
    in a real browser on staging. (CP-002/CP-010)

---

**End of tracker.**
