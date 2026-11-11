# Hivorr Control Portal — Implementation Plan

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/CONTROL-PORTAL-IMPLEMENTATION-PLAN.md` |
| **Version** | 1.0 (proposal only) |
| **Date** | 11 November 2026 |
| **Status** | **APPROVED — 11 November 2026.** P0 implementation has started; status is tracked in `EXECUTION-TRACKER.md`. |
| **Companion** | `CONTROL-PORTAL-ARCHITECTURE-ASSESSMENT.md` |
| **Workstream** | `CP` — Control Portal governance programme (cross-phase; see §2) |

> **Execution rule.** No package in this plan starts until the founder approves the assessment, the
> decisions in §1, and the package itself. A package may only run inside its owning engineering
> phase, under that phase's entry gate. This plan allocates work; it does not open a phase.

---

## 1. Decisions that must be recorded first

| ID | Decision | Recommended | Blocks |
|---|---|---|---|
| D-01 | Control/staff/partner scope | One governance architecture, two operational shells; keep the approved portals | Every screen and every session model |
| D-02 | Management visibility vs record-level PII | Aggregate visibility by default; record PII requires capability + reason + audit | Role catalogue, read models, exports |
| D-03 | Role ownership | `admin` owns roles/assignments; `identity.grants` remains portal grants | Schema, capability composition |
| D-04 | Case model | One case spine with typed cases and parent links | Case/evidence/approval schema |
| D-05 | Partner organisation | Admin entity + identity representatives; not a second account | Partner schema and RLS |
| D-06 | Approval engine | Narrow typed approval service; no BPMN | Approval schema and controls |
| D-07 | Audit integrity | Hash chain + signed export; retention `[OPEN]` | Audit design |
| D-08 | Role catalogue | Approve the initial roles and permission mapping | All admin capabilities |
| D-09 | Financial definitions | Approve metric definitions and fee/escrow/dispute rules | Finance screens |
| D-10 | Verification standard | Approve KYC ladder and verification vendor | Verification screens |
| D-11 | Investigation authority | Approve who may recommend, approve and execute sanctions | Case workflow |
| D-12 | Retention/export | Approve retention, legal hold and export policy | Documents, audit, cases |

**Rule:** a package that depends on an undecided item is `BLOCKED`, not "started with a placeholder".
No agent may choose a default.

---

## 2. Workstream model and numbering

### 2.1 Why a cross-phase workstream

The Control Portal is **not a phase**. It is a governance product surface that spans:

- **EP-01** — the existing control foundation, capability engine, audit and portals.
- **EP-02** — trust, verification, financial integrity, and the first `control` review platform.
- **EP-03–EP-05** — the activity modules whose records the portal governs.
- **EP-06–EP-08** — reserved/conditional; no CP work is scheduled there.

The existing execution structure recognises phases and work packages (`EP-xx-nnn`). It has no
identifier for a cross-phase programme. Creating a fake phase (for example "EP-02A") would corrupt
the dependency graph and the one-phase-in-build rule.

**Proposal:** add a `CP` workstream with identifiers `CP-001` … `CP-043`, each mapped to exactly one
owning phase and gate. The execution structure is amended once to recognise the workstream. If the
founder prefers, the same packages can be renumbered into `EP-02-1xx` when the EP-02 plan is written;
the content and dependencies do not change.

### 2.2 Status vocabulary

`PENDING` · `IN_PROGRESS` · `COMPLETED` · `BLOCKED` · `REQUIRES_REVIEW`.

A package is `COMPLETED` only with an execution record and evidence. A criterion without an artifact
is unmet.

### 2.3 Numbering rules

- Sequential, no gaps, no reused identifiers.
- P0: `001–008`. P1: `010–024`. P2: `030–038`. P3: `040–043`.
- A package never changes its identifier after approval; a superseded package is marked
  `SUPERSEDED` and a new one is appended.

---

## 3. Deliverable 11 — Priority matrix

### 3.1 Priority 0 — Critical foundations

Required for a secure and truthful Control Portal. These are corrections to the existing
foundation, not new product scope.

| ID | Package | Why P0 |
|---|---|---|
| CP-001 | Decision closure and governance charter | Nothing may be built on undecided scope |
| CP-002 | Administrative authorization model | Roles, scope, deny, elevation, SoD |
| CP-003 | Capability registry and context extension | Admin capabilities are currently un-grantable |
| CP-004 | Admin read path and user-directory remediation | The current user list is broken and wrongly gated |
| CP-005 | Audit contract extension and audit access | Reason, approval, read/export audit, pagination |
| CP-006 | Admin module public interface and schema foundation | The governance domain has no home |
| CP-007 | Control shell foundation | Router, design system, permission-aware nav |
| CP-008 | Deny/allow/RLS test matrix and P0 evidence | Proves the controls, including the deny path |

### 3.2 Priority 1 — Core governance

Essential administrative and operational capability, built in EP-02 as its entry gates allow.

| ID | Package | Dependency |
|---|---|---|
| CP-010 | Staff records and lifecycle | CP-002, 006 |
| CP-011 | Departments and membership | CP-010 |
| CP-012 | Role and permission administration | CP-002, 006 |
| CP-013 | Account governance actions | CP-002, 003, 005, 020 |
| CP-014 | Partner organisations and representatives | D-05, CP-002, 006 |
| CP-015 | Partner access isolation and scopes | CP-014 |
| CP-016 | Case spine and timeline | D-04, CP-006 |
| CP-017 | Evidence management | D-04, CP-016, storage |
| CP-018 | Support and dispute operations | CP-016, CP-017, CP-020 |
| CP-019 | Verification review operations | D-10, CP-016, CP-017, CP-020 |
| CP-020 | Approval and maker-checker | D-06, CP-006 |
| CP-021 | Investigation workspace and lifecycle | D-11, CP-016, CP-017, CP-020 |
| CP-022 | Configuration registry and change governance | D-12, CP-020 |
| CP-023 | Notification integration | CP-005, CP-016, CP-020 |
| CP-024 | Executive overview and operational reports | CP-016, CP-018, CP-019, CP-022 |

### 3.3 Priority 2 — Advanced governance

| ID | Package | Dependency |
|---|---|---|
| CP-030 | Financial read models and metrics | D-09, finance ledger, CP-024 |
| CP-031 | Financial exception and action controls | CP-030, CP-020 |
| CP-032 | Activity governance — Buy/Sell | EP-04 market module, CP-016, CP-024 |
| CP-033 | Activity governance — Hire/Offer | EP-03 services module, CP-016, CP-024 |
| CP-034 | Activity governance — Errand/Logistics | EP-04/05 modules, CP-016, CP-024 |
| CP-035 | Reporting, exports and data governance | CP-024, CP-030, D-02, D-12 |
| CP-036 | Security incidents and access reviews | CP-002, CP-005, CP-016 |
| CP-037 | System health and integrations | EP-01 worker/health, platform |
| CP-038 | Document and knowledge management | CP-017, retention decision |

### 3.4 Priority 3 — Future enhancements

| ID | Package | Precondition |
|---|---|---|
| CP-040 | Partner performance and compliance | CP-015, CP-035, agreed partner KPIs |
| CP-041 | Staff workload and performance | CP-010, CP-011, approved purpose and safeguards |
| CP-042 | Future activity registration governance | A new activity passes the four-part test (`ARCHITECTURE.md` §13.4) |
| CP-043 | Continuous assurance and external audit readiness | CP-005, CP-036, retention/legal hold, auditor scope |

### 3.5 Dependency graph (critical path)

```
D-01…D-12 + EP-02 entry gates
        │
CP-001 ─┼─ CP-002 ─ CP-003 ─ CP-006 ─┬─ CP-010 ─ CP-011
        │                            ├─ CP-012
        │                            ├─ CP-014 ─ CP-015
        │                            ├─ CP-016 ─ CP-017 ─┬─ CP-018
        │                            │                   ├─ CP-019
        │                            │                   └─ CP-021
        │                            └─ CP-020
        │
CP-004 ─ CP-005 ─ CP-007 ─ CP-008 ─ CP-024
        │
        ├─ CP-022
        ├─ CP-023
        └─ CP-030 ─ CP-031
CP-032/033/034 after their activity modules
CP-035 ─ CP-036 ─ CP-037 ─ CP-038 ─ CP-040/041/042/043
```

**Sequencing rules:**

1. `CP-001` is first and is documentation only.
2. `CP-002` and `CP-004`/`CP-005` may run in parallel; `CP-003` depends on `CP-002`.
3. `CP-006` depends on `CP-002`; it creates the schema and public interface, not features.
4. `CP-007` and `CP-008` run beside the backend path and must land before any P1 screen is accepted.
5. `CP-020` approval must land before any action that requires maker-checker.
6. Activity packages cannot start before their activity module exists.
7. No P1 package starts before `CP-008` is green.

---

## 4. Deliverable 12 — Phased implementation roadmap

### Tranche A — Governance foundation completion (P0)

| Field | Detail |
|---|---|
| **Objective** | Make authorization, audit, module and shell foundations correct and provable. |
| **Scope** | CP-001 … CP-008. Documentation first, then authorization/audit/schema/shell/test work. |
| **Features** | Admin role/assignment model; scope context; correct admin user read; audit reason/approval/read-audit; admin module public interface; control router and permission-aware shell; deny/allow matrix. |
| **Reuses** | `identity` grants/sessions, capability engine, `platform.audit_log`, `packages/design`, `app-shell`, `api-client`, route manifest. |
| **Changes** | Additive migrations; new capabilities; new admin schema tables; control shell refactor; audit columns. |
| **Dependencies** | Founder approval of D-01…D-08; EP-01 P0 defect acceptance; no EP-01 feature freeze violation. |
| **Outputs** | Approved governance charter; authorization spec; capability registry v2; working scoped user read; extended audit; admin skeleton; control shell; test matrix; evidence pack. |
| **Acceptance** | See each package. At tranche level: every admin capability has a grant path and a deny path; a control administrator can read a user only with the right capability and the read is audited; no account-scoped table is read under the wrong RLS context; all P0 tests green in CI on Linux. |
| **Risks** | Scope creep into staff/partner features; schema changes that pre-empt D-03/D-04; weakening RLS to make the user list work. Mitigation: strict package scope; explicit deny tests; no RLS relaxation. |
| **Docs** | Governance charter; ADR-CP-01…04; architecture amendment; matrix amendment; EP-01 findings; evidence pack. |

### Tranche B — Identity, organisation and access administration (P1, EP-02)

| Field | Detail |
|---|---|
| **Objective** | Let authorised management administer accounts, staff, departments, partners and roles safely. |
| **Scope** | CP-010 … CP-015, CP-020, CP-024 (initial). |
| **Features** | Staff lifecycle; departments; role administration; account restrict/suspend/reactivate/close; partner onboarding and representatives; partner isolation; approvals; overview. |
| **Reuses** | Identity, grants, audit, R2, outbox, design system, route manifest. |
| **Changes** | Admin tables, endpoints, control/staff/partner screens; notifications for assignments and approvals. |
| **Dependencies** | Tranche A green; D-01…D-08, D-12; EP-02 entry gate. |
| **Outputs** | Staff/department/partner administration; account actions; approval inbox; overview; audit coverage. |
| **Acceptance** | A staff member can be onboarded, scoped, assigned, suspended and offboarded with immediate session revocation; a partner organisation can be onboarded and isolated; an account action cannot be self-approved; every sensitive action is audited. |
| **Risks** | Over-broad roles; partner data leakage; staff offboarding leaving sessions. Mitigation: least privilege, RLS, immediate revocation, deny tests. |
| **Docs** | Administrative governance architecture; role catalogue; staff/partner runbooks; matrix update. |

### Tranche C — Trust, cases and operational governance (P1, EP-02/EP-03)

| Field | Detail |
|---|---|
| **Objective** | Give staff and investigators a unified case, evidence, verification and support workspace with separation of duties. |
| **Scope** | CP-016 … CP-019, CP-021, CP-022, CP-023. |
| **Features** | Case spine, timeline, evidence, support/disputes, verification review, investigation lifecycle, configuration governance, notifications. |
| **Reuses** | Private R2, signed URLs, outbox, audit, messaging, verification lanes. |
| **Changes** | Admin case/evidence/approval/config tables; control and staff screens; notification handlers. |
| **Dependencies** | Tranche B; D-04, D-06, D-10, D-11; verification lanes exist; storage signing exists. |
| **Outputs** | Working case workspace; evidence controls; verification queue; support/dispute queue; config changes with approval and history. |
| **Acceptance** | A support case can escalate to an investigation without duplication; evidence is immutable and every access is audited; an investigator cannot approve their own case; a config change has a version, approver and effective date. |
| **Risks** | Duplicate case systems; evidence leakage; investigator overreach; config drift. Mitigation: one spine, private storage, SoD, versioning. |
| **Docs** | Case lifecycle; evidence policy; investigation authority; configuration policy. |

### Tranche D — Financial and activity governance (P2, EP-03–EP-05)

| Field | Detail |
|---|---|
| **Objective** | Give management trustworthy financial oversight and per-activity operational governance. |
| **Scope** | CP-030 … CP-038. |
| **Features** | Financial read models, exception queues, refund/payout/adjustment approvals, reconciliation; Buy/Sell, Hire/Offer, Errand/Logistics governance; reports/exports; security incidents; system health; document library. |
| **Reuses** | Finance ledger, activity modules, read models, audit, R2, worker health. |
| **Changes** | Read models, exception tables, activity governance screens, export controls, health views. |
| **Dependencies** | Tranche C; ledger exists; activity modules exist; D-09; D-12. |
| **Outputs** | Finance oversight; activity queues/moderation; reports; exports; incident and health views. |
| **Acceptance** | Every financial metric has one definition and reconciles to the ledger; no adjustment edits a balance; every activity has a governance view sourced from its module; exports are capability-gated, bounded and audited. |
| **Risks** | Metric confusion; duplicated financial logic; activity-specific admin drift. Mitigation: ledger-derived definitions, read models, registry-driven activity governance. |
| **Docs** | Financial metric dictionary; activity governance guide; export policy. |

### Tranche E — Assurance and future readiness (P3)

| Field | Detail |
|---|---|
| **Objective** | Strengthen assurance, partner/staff performance, extensibility and audit readiness. |
| **Scope** | CP-040 … CP-043. |
| **Features** | Partner performance, staff workload (purpose-approved), future activity registration, continuous assurance. |
| **Dependencies** | Tranches A–D; retention/legal hold; auditor scope. |
| **Acceptance** | A new activity can be registered with a governance view without redesign; access reviews run on schedule; audit evidence is exportable to an auditor. |
| **Risks** | Performance metrics becoming surveillance; future activity bypassing the four-part test. Mitigation: purpose limitation, founder approval, registry gate. |

---

## 5. Work-package register

Each package follows the standard 13-section format when it becomes eligible. The table below is the
planning register: objective, scope, reuse, dependencies, outputs, acceptance, documentation.

### 5.1 P0 packages

#### CP-001 — Decision closure and governance charter

- **Objective:** Record D-01…D-12 and the workstream model so implementation has an unambiguous basis.
- **Scope:** Decision record; charter; document amendments list; approval signatures. No code.
- **Reuse:** `ENGINEERING_EXECUTION_STRUCTURE.md` decision protocol; existing ADR format.
- **Dependencies:** Founder review of the assessment.
- **Outputs:** Signed decision record; approved charter; amended architecture/matrix/standards scope.
- **Acceptance:** Every decision has an owner, date, chosen option, rejected alternatives and implications; no `[OPEN]` item is silently resolved.
- **Docs:** New `Administrative-Governance-Architecture.md`; `ARCHITECTURE.md` §7/§9.13/§16.4; matrix §14; standards §19.

#### CP-002 — Administrative authorization model

- **Objective:** Define and implement the hybrid RBAC + ABAC model: roles, permissions, assignments, scope, deny, elevation, SoD.
- **Scope:** Data model, pure evaluation extension, resource policy interface, conflict rules, tests. No screens.
- **Reuse:** `server/src/domain/capabilities.ts`; `packages/shared/src/capabilities.ts`; `identity.grants`; `loadAccessContext`; existing deny reasons.
- **Dependencies:** D-03, D-08; CP-001.
- **Outputs:** Migrations for roles/permissions/assignments/denials; extended `AccessContext`; `authorize()` service; table-driven tests.
- **Acceptance:** Every role/permission/scope combination has allow and deny cases; deny wins; expired assignments contribute nothing; no wildcard; a self-action is denied; no second capability list.
- **Risks:** Overloading grants; recursive policy; ambiguous conflict resolution.
- **Docs:** Authorization model section; matrix amendment; ADR-CP-02/03.

#### CP-003 — Capability registry and context extension

- **Objective:** Register the governance, staff and partner capabilities and populate the context inputs the engine already expects.
- **Scope:** `CAPABILITY_IDS`, requirement table, `adminRoles`, `staffRoles`, `verification`, `kycTier`, `member`, `businessApproved`, `payoutAccountBound`; no endpoints.
- **Reuse:** Existing capability registry and tests; `AdminRole` type; `loadAccessContext`.
- **Dependencies:** CP-002.
- **Outputs:** Registry v2; context loader; test matrix.
- **Acceptance:** Every registered capability has a rule and a deny reason; no capability can be granted by a request body; unknown capability denies.
- **Risks:** Registry drift between shared and server; incomplete context load.
- **Docs:** Capability catalogue; matrix update.

#### CP-004 — Admin read path and user-directory remediation

- **Objective:** Replace the broken, wrongly gated user directory with a scoped, audited admin read.
- **Scope:** `admin.user.read`; a narrow security-definer read function or admin read model; search, filter, cursor pagination; account/user summary; audit of sensitive reads and exports.
- **Reuse:** `identity.users`, `identity.accounts`, `platform.audit_log`, controller/service pattern.
- **Dependencies:** CP-002, CP-003.
- **Outputs:** Working user directory; API contract; tests; OpenAPI update.
- **Acceptance:** A control admin with `admin.user.read` sees the platform directory; a caller without it gets `403`; a caller with a narrower scope sees only the scope; every sensitive read is audited; no account RLS policy is weakened.
- **Risks:** Accidental RLS bypass; PII over-exposure.
- **Docs:** Admin read policy; security note.

#### CP-005 — Audit contract extension and audit access

- **Objective:** Make the audit trail fit for governance: reason, approval reference, session, filters, pagination, read/export auditing.
- **Scope:** Additive audit columns; audit read model; filters; cursor; export capability and audit; integrity design (hash chain optional at this stage).
- **Reuse:** `platform.audit_log`, `appendAudit`, `listAuditEntries`.
- **Dependencies:** CP-002, CP-004.
- **Outputs:** Migration; audit service; control audit screen; tests.
- **Acceptance:** Every sensitive action records actor, action, target, before/after, reason (where required), approval ref (where required), correlation, timestamp; audit read/export is itself audited; no update/delete path; pagination bounded.
- **Risks:** Hash chain scope creep; retention undefined.
- **Docs:** Audit contract; retention `[OPEN]`; ADR-CP-09.

#### CP-006 — Admin module public interface and schema foundation

- **Objective:** Establish the `admin` module as the governance domain with an explicit public interface.
- **Scope:** Tables for roles/assignments/departments/staff/partners/cases/approvals (structure only, no features); RLS and grants; module `index.ts`; module boundary rules.
- **Reuse:** Ten-module skeleton; migration conventions; RLS pattern; boundary linter.
- **Dependencies:** CP-002; D-03, D-04, D-05, D-06.
- **Outputs:** Forward-only migrations; public interface; schema docs; RLS tests.
- **Acceptance:** No cross-schema table access; every table has comments, constraints, indexes and RLS; the API role has only the needed grants; the boundary linter is green.
- **Risks:** Schema pre-empts decisions; migration sprawl.
- **Docs:** Admin schema; database rules update.

#### CP-007 — Control shell foundation

- **Objective:** Replace the bespoke control shell with the shared design system, router and permission-aware navigation.
- **Scope:** Router, route manifest for control, app shell, token consumption, permission-aware nav, 404, loading/error states, responsive layout.
- **Reuse:** `packages/design`, `packages/app-shell`, `@hivorr/api-client`, route manifest pattern.
- **Dependencies:** CP-001, CP-003; visual baseline.
- **Outputs:** Control shell; route table; visual regression; accessibility check.
- **Acceptance:** No raw hex outside the token layer; navigation derives from capabilities; every route is addressable; 375/768/1280 pass; no code from other apps; visual baseline approved.
- **Risks:** Visual drift; broad refactor.
- **Docs:** Control IA; visual note; route manifest.

#### CP-008 — Deny/allow/RLS test matrix and P0 evidence

- **Objective:** Prove the P0 controls, including every deny path, and produce the evidence pack.
- **Scope:** Table-driven capability tests; RLS allow/deny tests; admin read tests; audit tests; CI wiring; evidence pack.
- **Reuse:** Existing Vitest/Testcontainers/Playwright; `tests/capabilities.test.ts`, `rls-policy.test.ts`, `enforcement.test.ts`.
- **Dependencies:** CP-002…CP-007.
- **Outputs:** Test matrix; CI run; evidence pack; P0 completion record.
- **Acceptance:** CI green on Linux; each control has a test that fails if the control is removed; every deny reason is covered; the evidence pack links to artifacts.
- **Risks:** Local-only tests; Windows-native argon2 limitation.
- **Docs:** Evidence pack; EP-01 findings closure.

### 5.2 P1 packages (summary register)

| ID | Objective | Key scope | Reuse | Depends | Acceptance |
|---|---|---|---|---|---|
| CP-010 | Staff lifecycle | Profile, invite, department, supervisor, status, offboarding, session revocation | Identity, grants, audit | CP-002, 006, 012 | Onboard → scope → offboard with immediate revocation and retained history |
| CP-011 | Departments | Create, hierarchy, leadership, membership, department scope | Admin RBAC | CP-010 | Department change does not require permission redesign; scope tested |
| CP-012 | Role administration | Role catalogue, permission mapping, assignment, revocation, expiry, history | CP-002 | CP-002, 006 | Custom role + assignment; deny path; audit |
| CP-013 | Account governance | Restrict, suspend, reactivate, close, revoke sessions, notes, timeline | Identity, audit, approvals | CP-002, 003, 005, 020 | No self-action; reason required; sessions revoked; audit |
| CP-014 | Partner organisations | Application, onboarding, organisation, representatives, agreements | Identity, R2, audit | D-05, CP-002, 006 | Onboard org with representatives; isolation; agreement metadata |
| CP-015 | Partner isolation | Partner audience, org scope, partner roles, RLS | Identity, admin | CP-014 | Partner A cannot read B; no activity capability; audit |
| CP-016 | Case spine | Cases, types, timeline, links, assignment, queues | Admin, audit | D-04, CP-006 | Support → investigation link; timeline append-only; scope |
| CP-017 | Evidence | Upload, hash, metadata, signed view, access audit, supersede | R2, audit | CP-016 | Immutable original; every access audited; no public URL |
| CP-018 | Support/disputes | Queue, assignment, messages, notes, resolution, escalation | Messaging, cases | CP-016, 017, 020 | SLA fields; escalation; resolution audit; no duplicate case |
| CP-019 | Verification review | Lane queues, evidence, decision, request info, history | Profile lanes, cases | D-10, CP-016, 017, 020 | Decision recorded; lane state changes; audit; evidence protected |
| CP-020 | Approvals | Typed requests, stages, thresholds, decisions, SoD, history | Admin, audit | D-06, CP-006 | Requester ≠ approver; threshold routing; rejection reason; audit |
| CP-021 | Investigation workspace | Lifecycle, findings, recommendations, decisions, actions | Cases, approvals | D-11, CP-016, 017, 020 | Investigator ≠ approver; execution separate; reopen; audit |
| CP-022 | Configuration | Registry, versions, effective dates, approval, rollback, history | Platform flags | D-12, CP-020 | Every change attributable, approved, reversible, audited |
| CP-023 | Notifications | Assignment, approval, escalation, SLA, security alerts | Outbox, messaging | CP-005, 016, 020 | Handler registered; delivery attempt; in-app feed; no PII in payload |
| CP-024 | Executive overview | Action centre, operational pulse, platform metrics, links | Read models | CP-016, 018, 019, 022 | Every metric defined; actionable items first; permission-aware |

### 5.3 P2 packages (summary register)

| ID | Objective | Key scope | Depends | Acceptance |
|---|---|---|---|---|
| CP-030 | Financial read models | Ledger overview, GTV, revenue, liabilities, pending payouts, refunds | Ledger, D-09 | Reconciles to ledger; definitions approved |
| CP-031 | Financial controls | Refund/payout/adjustment approvals, thresholds, reconciliation exceptions | CP-030, 020 | Maker-checker; no balance edit; reversal only; audit |
| CP-032 | Buy/Sell governance | Listings, categories, sellers, orders, moderation, complaints | Market module | Queue and moderation; seller restriction; audit |
| CP-033 | Hire/Offer governance | Jobs, applications, engagements, disputes, verification | Services module | Job/engagement oversight; dispute link; audit |
| CP-034 | Errand/Logistics governance | Requests, dispatch, delivery, incidents, compliance | Errand/logistics modules | Operational queues; incident link; audit |
| CP-035 | Reporting and exports | Platform, financial, operational, compliance reports; export controls | CP-024, 030 | One definition per metric; export gated and audited |
| CP-036 | Security incidents and access reviews | Incident lifecycle, containment, review, access review runs | CP-002, 005, 016 | Incident audit; overdue reviews surfaced |
| CP-037 | System health | API/worker/queue/integration health, failed jobs | EP-01 worker | Read-only; no secrets; role-controlled |
| CP-038 | Documents and knowledge | Policy/procedure library, versioning, access | CP-017, retention | Versioned; permissioned; audited |

### 5.4 P3 packages

| ID | Objective | Precondition |
|---|---|---|
| CP-040 | Partner performance and compliance | CP-015, 035, agreed KPIs |
| CP-041 | Staff workload and performance | CP-010/011, purpose and safeguards approved |
| CP-042 | Future activity governance | Four-part test passed; registry + read model |
| CP-043 | Continuous assurance | Audit chain, retention, auditor scope |

---

## 6. Task-level acceptance criteria (standard)

Every package's DoD includes, at minimum:

1. **Scope:** only the package's stated files and behaviours changed.
2. **Reuse:** the existing capability registry, audit, design tokens, route manifest, storage,
   ledger and notification path were used; no parallel implementation was introduced.
3. **Authorization:** every new endpoint declares an audience; every command checks a capability
   inside the transaction; resource scope is enforced in the service and the repository.
4. **Deny path:** a test proves the action is refused without the capability, with the wrong scope,
   with an expired assignment, with an explicit deny, and with a self-action.
5. **Audit:** every sensitive read/write/export writes the required fields; no update/delete path.
6. **Data:** migration is forward-only, self-contained, has constraints, indexes, RLS, grants and
   comments; no cross-schema access.
7. **API:** request validation rejects unknown fields; errors use stable codes; lists are paginated.
8. **UI:** approved tokens only; 375/768/1280; visible focus; status not by colour alone; permission-
   aware states; no dead controls.
9. **Tests:** unit, integration and (where applicable) E2E; CI green on the reference Linux runner.
10. **Evidence:** execution record, test output, migration hash, screenshots and audit sample.
11. **Docs:** the owning document updated; no duplicate document created.
12. **Security report:** for security-relevant work, the `AGENTS.md` §4A report fields are complete.

---

## 7. What must not be built

To protect scope and the approved architecture:

- A second identity, account, role, capability, audit, ledger, file store, notification system or
  design system.
- A generic workflow/BPMN engine, a policy DSL, a plugin runtime or a rules engine.
- A per-activity admin application or a per-activity database.
- A second task-management system beside the case/work-item spine.
- A superuser role, wildcard permission, permanent break-glass account or client-side authorization.
- An admin screen for a module or table that does not exist.
- A staff member in control by default, or a partner with any activity capability or wallet.
- A financial dashboard before the ledger and metric definitions exist.
- A verification queue before the lanes and vendor decision exist.
- A performance score for staff before its purpose and safeguards are approved.
- Production deployment, DNS, secret or hosted changes by any agent.

---

## 8. Documentation requirements per phase

| Phase | Required documents |
|---|---|
| Tranche A | Decision record; governance charter; authorization model; capability catalogue; audit contract; admin schema; control IA; P0 evidence pack; EP-01 findings closure; ADRs CP-01…04 |
| Tranche B | Role catalogue; staff lifecycle runbook; partner onboarding/termination runbook; account action policy; matrix update; ADR-CP-05/06 |
| Tranche C | Case lifecycle; evidence policy; investigation authority; configuration policy; notification catalogue; ADR-CP-04/07 |
| Tranche D | Financial metric dictionary; activity governance guide; export policy; incident runbook; ADR-CP-08 |
| Tranche E | Performance measurement policy; future activity checklist; assurance pack; retention/legal hold record |

---

## 9. Deliverable 14 (plan view) — readiness and next eligible work

### 9.1 Next eligible package

**CP-001 is complete.** CP-002 … CP-008 are implemented and locally verified, including a
PostgreSQL 16.15 migration run. They remain `REQUIRES_REVIEW` until CI, independent review and staging
verification exist. No P1 package starts until CP-008 is accepted and the EP-02 entry gate is met.

### 9.2 Conditions to open Tranche A

1. Founder approves D-01…D-08 and the P0 tranche.
2. EP-01 `F-49`/`F-50` are closed or a recorded exception is accepted.
3. The workstream identifier is ratified in the execution structure.
4. A reviewer is available for the authorization and audit changes (`DEV-003`).
5. The evidence pack format is agreed.

### 9.3 Conditions to open Tranche B

Tranche A green, EP-02 entry gate met (including BD-D01, BD-D03, BD-D04, BD-D05, verification
vendor), role catalogue approved, and the staff/partner scope decision recorded.

### 9.4 Conditions to open Tranche C

Tranche B green, D-04/D-06/D-10/D-11 recorded, verification lanes and private storage operational.

### 9.5 Conditions to open Tranche D

Tranche C green, ledger exists, activity modules exist, D-09 recorded, metric dictionary approved.

### 9.6 Conditions to open Tranche E

Tranches A–D green, retention/legal hold decided, auditor scope agreed.

---

## 10. Summary

The Control Portal should be built as **one governance domain, two operational shells, four approved
portals, ten modules, one identity, one audit trail, one ledger, one file store and one design
system**. The first work is not a dashboard; it is the authorization, audit and read-path foundation
that makes every later screen safe. The portal's breadth comes from scope, assignment and read
models — not from granting every management user every capability.

**Founder approval was recorded on 11 November 2026. Implementation is tracked in
`EXECUTION-TRACKER.md`; only the P0 tranche is in progress.**

---

**End of implementation plan.**
