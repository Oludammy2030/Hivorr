# Administrative Governance Architecture

| Field | Value |
|---|---|
| **Document** | `documents/Context/Administrative-Governance-Architecture.md` |
| **Version** | 1.0 |
| **Date** | 11 November 2026 |
| **Status** | **APPROVED — 11 November 2026.** Binding for the governance domain. |
| **Owner** | Founder (AfriNova) for business authority; architect for technical content |
| **Supersedes** | Nothing. It extends the approved architecture and permission model for the governance domain. |
| **Companions** | `VISION.md`, `ARCHITECTURE.md`, `Unified-Account-and-Activity-Permission-Matrix.md`, `Database-Migration-and-Supabase-Data-API-Rules.md`, `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`, `AGENTS.md` |
| **Basis** | `documents/Engineering-Execution/Control-Portal/DECISION-RECORD.md` D-01…D-08, D-13 |

> **Authority rule.** This document does not restate the six activity capabilities, the account
> model, the database mechanics or the visual identity. Those remain governed by their approved
> documents. Where this document conflicts with a higher document, the higher document wins and this
> document has a defect. Items marked `[OPEN]` are not requirements.

---

## 1. Purpose and scope

This document defines the **administrative governance domain** of Hivorr: the identities, roles,
scopes, organisations, cases, evidence and approvals through which authorised people govern the
platform.

It answers:

1. Who may govern, and under what authority?
2. How are internal staff, departments, external partners and investigators represented?
3. How does a permission become a decision on a specific record?
4. How are sensitive decisions separated, approved and audited?
5. How does the domain extend to new activities without redesign?

It does **not** define the six activity workflows, the financial ledger, the verification vendor,
retention periods or the visual identity. Those are separate authorities.

---

## 2. Domain boundaries

```
identity          accounts, users, credentials, sessions, memberships, grants, MFA
profile           shared profile, activity activation, verification lanes, KYC
admin             governance: roles, staff, departments, partners, cases, evidence,
                  approvals, configuration, reporting read models
finance           ledger, escrow, payouts, reconciliation (read by admin)
market/services/  activity records (read by admin through public read models)
errands/logistics
platform          audit, outbox, flags, reference counters
messaging         threads, notifications, delivery attempts
```

**Rules:**

1. `admin` owns governance records. It does not own activity, finance or identity records.
2. `admin` reads another module only through that module's public interface or read model.
3. No cross-schema table access. A `select` that joins `admin` to `finance` is a defect.
4. The identity service remains the only credential store and the only session issuer.
5. The audit trail remains `platform.audit_log`; governance actions write to it through the platform
   service.

---

## 3. Actors and authority

| Actor | Authority source | Session audience | Default visibility |
|---|---|---|---|
| Founder | Founder authority | `control` | Platform-wide, within dual-control rules |
| Governance administrator | Admin role assignment | `control` | Platform or delegated scope |
| Verification officer | Staff grant + role assignment | `staff` | Assigned verification queue |
| Support officer | Staff grant + role assignment | `staff` | Assigned support queue |
| Operations officer | Staff grant + role assignment | `staff` | Assigned activity/department |
| Finance officer | Admin role assignment | `control` | Finance scope |
| Investigator | Admin role assignment | `control` | Assigned cases/teams |
| Compliance reviewer | Admin role assignment | `control` | Assigned review scope |
| Partner manager | Admin role assignment | `control` | Partner portfolio |
| Auditor | Admin role assignment | `control` | Read-only scope |
| Platform engineer | `platform.engineering` grant | `control` | Technical scope; no PII, no money |
| Partner representative | Partner membership | `partner` | Own organisation only |
| Ordinary user | Account | `app` | Own records only |

**No actor inherits another actor's authority.** A staff grant never creates a control session. A
partner representative never receives an activity capability or a wallet. An administrator who also
holds activities gains nothing extra inside those activities.

---

## 4. Authorization model

### 4.1 Layers

```
Permission   a capability string, e.g. admin.case.assign
Role         a named collection of permissions, e.g. investigator
Assignment   a role or permission granted to a user, with scope and validity
Scope        the records the assignment may reach
Deny         an explicit prohibition that overrides an allow
Decision     permission + scope + resource attributes + approval state
```

### 4.2 Decision order

1. Authenticated, correct audience, correct environment.
2. Capability registered.
3. Collect active authority: grants, role permissions, individual grants, temporary elevations.
4. Any matching explicit deny → **deny**.
5. No matching allow → **deny**.
6. Approval required and not approved, or requester is the actor → **deny**.
7. Resource outside the assignment scope → **deny** (return `NOT_FOUND` where existence is sensitive).
8. Otherwise allow, and audit when sensitive.

### 4.3 Conflict resolution

- Allows are unioned.
- An explicit deny always wins.
- Scope is intersected, never unioned across assignments.
- An expired or revoked assignment contributes nothing.
- There is no wildcard permission and no role that means "all".
- A role assignment does not widen another assignment's scope.

### 4.4 Resource scope kinds

| Scope | Source | Example |
|---|---|---|
| `platform` | Assignment | Founder, auditor |
| `department` | `admin.department_members` | Support queue for Trust |
| `organisation` | `admin.partner_representatives` | Partner organisation X |
| `activity` | Assignment `activity_id` | Logistics operations |
| `case` | `admin.case_assignments` | Investigator on case C |
| `team` | `admin.case_team_members` | Investigation team |
| `sensitivity` | Resource classification vs clearance | Identity documents |

### 4.5 Separation of duties

- Requester ≠ approver, always.
- Investigator ≠ approver of the same case, always.
- A user may not suspend, restrict or close their own account.
- A user may not approve their own access elevation.
- The last active grant manager cannot be revoked (existing rule).
- High-risk execution records the approval reference; approval and execution are separate audit
  events even when one person holds both capabilities.

---

## 5. Role catalogue (initial)

Roles are collections; scope is separate. The detailed permission mapping is finalised in `CP-012`.

| Role key | Purpose | Typical scope | Exclusions |
|---|---|---|---|
| `founder` | Ultimate business authority | Platform | Cannot bypass dual control or self-approval |
| `governance_admin` | Roles, staff, partners, configuration read | Platform or delegated department | No money movement, no case decision |
| `verification_officer` | Verification queue and evidence | Assigned lanes | Payments, configuration, account closure |
| `support_officer` | Support cases and customer context | Assigned queues | Verification decisions, high-value refunds |
| `operations_officer` | Activity operations, dispatch exceptions, SLA | Assigned activity/department | Financial configuration, role administration |
| `finance_officer` | Ledger, reconciliation, payout review | Finance scope | Role administration, verification, suspension |
| `investigator` | Case investigation, findings, recommendations | Assigned cases/teams | Final sanction approval |
| `compliance_reviewer` | Case review and decision | Assigned categories | Investigating the same case |
| `partner_manager` | Partner onboarding, agreements, performance | Partner portfolio | Internal staff data, platform audit |
| `auditor` | Audit and report read | Read-only scope | Any write |
| `platform_engineer` | Health, queues, logs, deployment metadata | Technical scope | PII, money, business rules |
| `department_manager` | Department workload and assignment | Own department | Cross-department records |

`[OPEN]` The final role-to-permission mapping and any additional roles are approved in CP-012.

---

## 6. Staff and departments

### 6.1 Entities

- `admin.staff_profiles` — user, employee reference, job title, department, supervisor, engagement
  status, dates.
- `admin.departments` — name, description, parent, leadership, status.
- `admin.department_members` — department, user, membership role, effective dates.
- `admin.role_assignments` — role, scope, effective dates, approver, reason.
- `admin.work_items` — assigned cases/tasks, priority, due date, status, escalation.

### 6.2 Lifecycle

Invite → accept → profile → department → role assignment → work → transfer → suspension/leave →
offboarding.

Offboarding:

1. revoke grants and role assignments;
2. revoke all sessions immediately;
3. reassign open work;
4. retain the staff record, decisions and audit history;
5. record the reason and the approver.

### 6.3 Workload

Workload is derived from assignments and case load. It is not a second project-management system.
Individual performance reporting requires an approved purpose and safeguards (`[OPEN]`, CP-041).

---

## 7. Partner organisations

### 7.1 Entities

- `admin.partner_organisations` — legal/trading name, registration, category, status.
- `admin.partner_representatives` — user, organisation, representative role, authority evidence,
  effective dates.
- `admin.partner_applications`, `admin.partner_agreements`, `admin.partner_scopes`.
- `admin.partner_performance` — read model over referrals and commission.

### 7.2 Isolation

- A partner session has audience `partner`.
- Organisation scope is derived from the representative record, never from a request parameter.
- A representative of organisation A cannot read organisation B.
- Partner data is aggregate for referred users unless a specific agreement and consent allow more.
- Partner access ends with the agreement; historical commission records are retained.
- A partner representative never receives a staff or admin assignment.

---

## 8. Cases and evidence

### 8.1 Case spine

`admin.cases` holds the reference, type, category, priority, severity, status, subject, activity,
department, queue, assignee, team, parent case, outcome and closure. Typed links point to the
relevant module records; they do not copy them.

### 8.2 Supporting records

`case_events` (append-only timeline), `case_links`, `case_evidence`, `case_findings`,
`case_recommendations`, `case_decisions`, `case_actions`, `case_assignments`,
`case_team_members`.

### 8.3 Lifecycle

```
RECEIVED → TRIAGED → OPEN → INVESTIGATING
                         ├→ PENDING_INFORMATION → INVESTIGATING
                         ├→ ESCALATED → REVIEW
                         └→ REVIEW → DECIDED → ACTION_PENDING → CLOSED
CLOSED → REOPENED → INVESTIGATING
Any → MERGED | ARCHIVED
```

A decision requires a finding or a reasoned administrative closure. A sanction requires an approved
decision and a separate execution. Reopening preserves the prior cycle.

### 8.4 Evidence

- Private R2 bucket, pre-signed upload, short-lived signed download.
- SHA-256 hash, MIME type, size, uploader, source, classification, retention class.
- Immutable original; correction by a superseding version, never overwrite.
- Every access is audited.
- No deletion while a case or legal hold is open.
- Malware scan before use.

---

## 9. Approvals and configuration

### 9.1 Approval service

`admin.approval_requests` (action type, target, amount/risk, requester, reason),
`admin.approval_steps` (stage, required permission, assignee, threshold),
`admin.approval_decisions` (approve/reject/request information, reason).

Rules: typed action catalogue; fixed stages; configurable thresholds; no self-approval; rejection
reason required; every decision audited; execution references the approval.

### 9.2 Configuration

`admin.configuration_entries`, `admin.configuration_versions`, effective dates, approver, reason and
rollback. Configuration changes are validated, attributable, auditable and reversible. Infrastructure,
secrets, deployment and environment settings are outside this domain.

---

## 10. Audit requirements

Every governance action records:

- actor id, actor type, audience, environment;
- action, target type, target id;
- before/after summary where applicable;
- reason where the action is sensitive;
- approval reference where required;
- correlation id and session id;
- timestamp.

Sensitive reads and every export are audited. The audit trail is append-only. Hash-chain and signed
export are approved in principle; retention remains `[OPEN]`.

---

## 11. Data protection

- Platform-wide aggregates are available to management roles.
- Record-level identity, financial, verification and investigation data require a capability and a
  scope.
- PII is minimised in lists; full details require a record view and an audit record.
- Exports require a capability, a bounded row count, a watermark and an audit record.
- Retention, legal hold and deletion remain `[OPEN]`; no automatic purge is built.
- Documents and evidence are private by default.

---

## 12. Extensibility

A new activity is added by:

1. registering the activity (existing registry);
2. adding its capability namespace;
3. adding its module read model;
4. adding governance navigation from the registry, not from hard-coded switches.

A new governance case type or approval type is added by a typed catalogue entry and a permission,
not by a new workflow engine. A new organisation type reuses the partner pattern only if it passes
the same isolation tests.

---

## 13. Invariants

1. One identity, one account, one credential store.
2. One audit trail, one ledger, one file store, one notification path, one design system.
3. No client-side authorization.
4. No wildcard permission or permanent superuser.
5. No self-approval, no self-suspension, no investigator-approver overlap.
6. No cross-schema table access.
7. No account-scoped RLS relaxation to satisfy an administrative read.
8. No sensitive action without an audit record.
9. No `[OPEN]` decision implemented by default.
10. No production deployment by an agent.

---

## 14. Related decisions and open items

- Approved: D-01…D-08, D-13 (`DECISION-RECORD.md`).
- Open: O-01…O-12 (`DECISION-RECORD.md` §3).
- Phase mapping: `CONTROL-PORTAL-IMPLEMENTATION-PLAN.md`.
- Evidence of the current state: `CONTROL-PORTAL-ARCHITECTURE-ASSESSMENT.md`.

---

**End of document.**
