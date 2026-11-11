# Hivorr Control Portal — Architecture Assessment

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/CONTROL-PORTAL-ARCHITECTURE-ASSESSMENT.md` |
| **Version** | 1.0 (assessment only) |
| **Date** | 11 November 2026 |
| **Status** | **APPROVED — 11 November 2026.** Implementation has started under the `CP` workstream; see `EXECUTION-TRACKER.md`. |
| **Author role** | Principal architect / security architect / technical governance lead |
| **Scope** | The whole Hivorr ecosystem as it exists in the repository on 11 November 2026 |
| **Companion** | `CONTROL-PORTAL-IMPLEMENTATION-PLAN.md` (priorities, phases, work packages) |

> **Reading rule.** This document assesses what exists. It does not change a code file, a migration,
> a capability, a permission, the prototype, or an approved document. Every recommendation is
> `[PROPOSED]`. Every unresolved item is `[OPEN]` and remains blocked until the founder decides it.
> Where an approved document and this assessment disagree, the approved document wins and this
> assessment has a defect.

---

## 0. Executive summary

### 0.1 What exists

Hivorr already has a genuine governance *foundation*, but it does **not** yet have a Control Portal in
the sense this brief describes.

**Exists and works, or partly works:**

- A four-portal topology (`app`, `control`, `staff`, `partner`) with host-to-audience mapping,
  host-only sessions, environment binding and mandatory MFA for non-`app` audiences.
- Identity: accounts, users, credentials, memberships, sessions, devices, TOTP MFA, recovery codes,
  and scoped privileged grants.
- A pure, default-deny capability engine with stable deny reasons.
- An append-only `platform.audit_log`, written by the service layer in the same transaction.
- A ten-module backend skeleton with one PostgreSQL schema per module.
- Live staging for all four hosts, build-once release artifacts and a founder approval gate.
- A working grant administration surface: list, create and revoke `admin`, `staff`, `partner` and
  `platform_engineering` grants.
- A read-only control portal probe with four sections: Overview, Users, Grants, Audit.

**Does not exist:**

- The `admin` schema has **no tables**. The admin module is a nine-line empty boundary.
- No admin-role assignment model, staff model, department model, partner-organisation model, case
  model, evidence model, approval workflow, configuration registry, reporting model, support/dispute
  model, financial read model, verification model, or document metadata model.
- No verification, market, services, errands, logistics, finance or messaging tables. Those module
  boundaries are empty by design; they belong to later phases.
- No resource-level authorization, no assignment scope, no explicit-deny model, no temporary
  elevation, no separation-of-duties enforcement.
- No staff or partner product screens. Both apps are foundation placeholders.

### 0.2 The four conclusions that matter

1. **The Control Portal is not a greenfield build and must not become a parallel architecture.**
   The correct move is to complete and extend the existing identity, capability, audit, module and
   portal foundations. The `admin` module is the intended home for governance (`ARCHITECTURE.md`
   §9.2 #9, §9.13). Building a second authorization system, a second audit trail, a second ledger, a
   second file store or a second notification system would violate the approved architecture.

2. **The largest gap is authorization depth, not screens.** The capability engine currently accepts
   activities and grants. It does not accept admin roles, staff roles, KYC, verification evidence,
   department scope, partner organisation scope or case assignment. As a result, several capabilities
   that the engine declares (`admin.verification.review`, `admin.payment.review`,
   `admin.dispute.resolve`, `admin.account.suspend`, `admin.configuration.write`) are **permanently
   denied**: no mechanism can grant them. This is the critical foundation defect.

3. **The prompt's "one Control Portal" conflicts with an approved architecture decision.** The
   approved model separates `control` (founder and explicitly authorised administrators/developers)
   from `staff` (job-scoped operational staff) and `partner` (external organisations)
   (`ARCHITECTURE.md` §1.4, §4.0, §7.2–§7.4). The brief describes management, staff, investigators,
   departments and partners operating inside one Control Portal. Those two positions cannot both be
   true. **Founder decision required before implementation** (§5, decision D-01). The recommended
   resolution is *one governance architecture, two operational shells*: `control` for privileged
   governance and `staff` for job-scoped operations, both served by the same `admin` domain and the
   same authorization engine. That satisfies the brief's functional intent without weakening the
   approved trust separation.

4. **The portal is not implementation-ready for its full scope.** Two high EP-01 findings remain open
   (`F-49` stale staging API, `F-50` manual Pages rollout). Several EP-02 entry gates are undecided
   (funds custody, KYC ladder, dispute rules, verification vendor). The P0 authorization and audit
   defects below must be closed first. Work that *is* ready now is documentation, decision
   ratification, authorization design, audit-contract design, the control shell and the deny-path
   test matrix.

### 0.3 Recommended shape in one sentence

> Keep the four approved portals and the ten modules; complete the capability engine into a hybrid
> RBAC + ABAC authorization service; make the `admin` module the single governance domain (staff,
> departments, partners, roles, cases, evidence, approvals, configuration, reporting); expose it
> through a privileged `control` shell for governance and a job-scoped `staff` shell for operations;
> reuse the existing identity, audit, ledger, storage, notification and design-system foundations
> rather than duplicating any of them.

---

## 1. Method and evidence base

### 1.1 What was inspected

| Area | Evidence inspected |
|---|---|
| Governance documents | `documents/Context/AGENTS.md`, `ARCHITECTURE.md`, `VISION.md`, `Unified-Account-and-Activity-Permission-Matrix.md`, `Database-Migration-and-Supabase-Data-API-Rules.md`, `ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`, `VISUAL-IDENTITY.md` |
| Execution governance | `ENGINEERING_EXECUTION_STRUCTURE.md`, `EP-00`/`EP-01` phase plans, `EP-01` entry record, phase overview, tracker, execution records |
| Portals | `apps/README.md`, `apps/control/**`, `apps/staff/**`, `apps/partner/**` |
| Backend | `server/src/**`: modules, controllers, services, domain, database, worker, OpenAPI |
| Shared contracts | `packages/shared/src/**`, `packages/api-client/src/**`, `packages/app-shell/src/**`, `packages/design/src/**` |
| Database | All 17 migrations in `supabase/migrations/` |
| Tests | 47 test files under `tests/`, plus scripts and CI configuration |
| Prototype | `src/app/App.tsx` (visual authority; not modified) |

### 1.2 Verification posture

- The assessment is based on the **as-built repository**, not on plans or documents alone.
- No file was modified in producing this assessment.
- No database, hosted environment, secret or deployed service was touched.
- No claim below asserts that Hivorr is secure, compliant or production-ready. It records what was
  found, where, and what is missing.

---

## 2. Deliverable 1 — Existing system assessment

### 2.1 Platform topology

| Component | As built | Status |
|---|---|---|
| Four application bundles | `web` (root), `apps/control`, `apps/staff`, `apps/partner`; all build | **Adequate as foundation** |
| Portal audience isolation | `packages/shared` portal definitions; `server/src/common/audience.ts`; host-to-audience guard | **Adequate** |
| Session audiences | Four audiences; audience and environment checked on read/refresh; host-only cookies | **Adequate** |
| MFA | TOTP enrolment, single-use challenge, recovery codes, step-up; non-`app` audiences require MFA at sign-in | **Adequate as foundation** |
| API | NestJS 12 + Fastify 5, `/v1`, correlation IDs, validated config, error contract | **Adequate as foundation** |
| Worker/outbox | Lease-based outbox, retry/backoff, dead-letter, health | **Adequate as foundation; no handlers registered** |
| Database | PostgreSQL 16-compatible, schema per module, five roles, forward-only migrations | **Adequate as foundation** |
| Staging | Eight hosts, TLS, Access, same-origin `/api`, build-once manifest | **Partial — `F-49`, `F-50` open** |
| CI | Install, lint, typecheck, test, database, build, security; OpenAPI diff | **Partial — visual gate and migration diff incomplete** |

### 2.2 The Control Portal front end

**Location:** `apps/control/src/App.tsx` (857 lines), `apps/control/src/foundation.css`,
`apps/control/src/api.ts`.

**What it does:**

- Sign-in with MFA challenge.
- Four sections in a hand-rolled shell: Overview, Users, Grants, Audit.
- Users: search by email/name, filter by status, select a row, view a read-only detail card.
- Grants: create and revoke grants from a hard-coded scope map.
- Audit: recent entries, action/actor/target.

**Status: Incomplete / Inadequate for the brief.**

| Limitation | Effect |
|---|---|
| No router, no URL-addressable screens, no deep links | Every view is local state; back/forward and links do not work; screen-level authorization cannot be enforced by route |
| Uses `foundation.css` with its own raw hex values | Duplicates the design token layer; violates `ARCHITECTURE.md` §8.12 / §14.3 and `AGENTS.md` §2.12 |
| Navigation is static, not permission-aware | A user sees sections they may not use; backend still denies, but the UX and the security signal are wrong |
| No pagination, filtering, sorting or export controls | Lists are capped at 100; no cursor; no export audit |
| No account actions | Suspend, reinstate, restrict, close, revoke sessions are absent; the UI itself says they are "the next control slice" |
| No staff, partner, role, case, approval, finance, verification or reporting surface | The core governance functions in the brief are absent |
| No error/empty/loading permission states beyond a single banner | Poor operational usability |

### 2.3 The Staff and Partner portals

| App | State | Consequence |
|---|---|---|
| `apps/staff` | Sign-in/MFA plus a session overview; no operational queues | Staff cannot perform any job function |
| `apps/partner` | Static "Foundation build" page; no session | Partners cannot apply, track referrals or view commission |

Both are explicitly recorded as scaffolds in `apps/README.md` §Current state. That is honest, but it
means the brief's staff, department and partner governance requirements have **no product surface**.

### 2.4 The backend `admin` module

**Location:** `server/src/modules/admin/index.ts`.

```ts
/**
 * Administration and governance module boundary.
 * ...
 * EP-01 creates the boundary and the public interface; the schema
 * and endpoints arrive with EP-01-024/036.
 */
export {}
```

The `admin` schema exists (`20261107000100_initial_schemas.sql`) and the API/worker roles have
`USAGE` on it (`20261107000300_roles_and_grants.sql`), but it contains **no tables, views, functions
or endpoints**. Every governance capability in the brief therefore has no implementation home yet.

### 2.5 Identity, grants and administrative authority

| Capability | Implementation | Status |
|---|---|---|
| Account, user, membership | `identity.accounts`, `identity.users`, `identity.memberships`; one owner user per account | **Adequate as foundation** |
| Credentials and sessions | Argon2id, refresh rotation, reuse detection, revocation, devices | **Adequate** |
| Privileged grants | `identity.grants`: `admin`, `staff`, `partner`, `platform_engineering`; environment-scoped; revocable; expiry | **Partial** |
| Grant administration | `identity.list_grants`, `create_grant`, `revoke_grant`; last grant-manager guard; audit | **Partial — see defects** |
| Admin role model | `AdminRole` type in `server/src/domain/capabilities.ts`; **no table, no assignment, no endpoint** | **Missing** |
| Staff role model | One `staff.support.handle` grant scope | **Missing** |
| Partner model | One `partner.referral.read` grant scope | **Missing** |
| Resource-level scope | None | **Missing** |
| Explicit deny / temporary elevation / access review | None | **Missing** |

### 2.6 Capability engine

**Location:** `packages/shared/src/capabilities.ts` (vocabulary) and
`server/src/domain/capabilities.ts` (computation).

**What is right:**

- Capabilities are computed server-side, never stored on the client.
- Evaluation is pure, default-deny, with a stable, ordered deny reason.
- The activity + verification + KYC + grant model is encoded in one table.
- The capability list is presentation-only; every mutating endpoint re-checks inside the transaction.

**What is missing or wrong:**

| Defect | Evidence | Effect |
|---|---|---|
| `adminRoles` is never populated | `server/src/modules/identity/access.ts` builds context from grants and activities only | All five capabilities that require an `adminRole` are permanently denied |
| Admin grant scopes are only three | `identity.grant_scope_is_valid` allows `admin.audit.read`, `admin.grant.read`, `admin.grant.manage` | `admin.verification.review`, `admin.payment.review`, `admin.dispute.resolve`, `admin.account.suspend`, `admin.configuration.write` cannot be granted by any path |
| No staff role beyond `staff.support.handle` | `CAPABILITY_IDS`, `GRANT_IDS` | Verification officer, operations, investigations and finance staff cannot be represented |
| No partner scope beyond `partner.referral.read` | `CAPABILITY_IDS`, `GRANT_IDS` | Partner organisations, representatives and commissions cannot be represented |
| No resource scope | `AccessContext` has no resource attributes | A permission is all-or-nothing across the module; assignment-based access is impossible |
| No explicit deny | No model | Conflict resolution is undefined |
| No temporary elevation | `expires_at` on grants only | Privilege elevation and access review are not supported |
| No separation of duties | No approval model | Maker-checker, self-approval prevention and dual control are not enforceable |

### 2.7 The user directory — a concrete P0 defect

`server/src/api/users.controller.ts`:

- Is gated by `admin.grant.read` — a grant-management capability used as a proxy for user reading.
- Reads `identity.users` directly inside a transaction whose identity context is the **caller's**
  account/user.
- `identity.users` has `FORCE ROW LEVEL SECURITY` with policy
  `account_id = platform.current_account_id()`
  (`20261107000600_identity_rls.sql` lines 102–113).

**Consequence:** the query can only see users in the caller's own account. A control administrator
will see one row (themselves) or none, not the platform directory. The endpoint is functionally
broken as a governance read and is gated by the wrong capability.

This is not a cosmetic bug. It demonstrates the core architectural issue: **cross-account
administrative reads need an explicit, scoped, audited admin read path.** They cannot be produced by
reading account-scoped tables under the actor's own RLS context. The fix is a new capability
(`admin.user.read`), a dedicated read model or security-definer function with its own justification,
and an audit record for the read and any export.

### 2.8 Audit

**Location:** `platform.audit_log` (`20261107000200_platform_tables.sql`),
`server/src/modules/platform/audit.ts`.

**Strong points:**

- Append-only trigger rejects update and delete.
- Written in the same transaction as the state change.
- Captures actor type, actor id, audience, environment, action, target, before/after summary, IP,
  user agent, correlation id and timestamp.
- Used by identity and grants; sign-in, MFA and privileged sign-in actions are audited.

**Gaps against the brief:**

| Gap | Status |
|---|---|
| No `reason` / justification column | Missing |
| No `approval_reference` column | Missing |
| No `session_id` or request id beyond correlation id | Partial |
| No audit-of-audit-read (every sensitive read/export must be logged) | Missing |
| No pagination, actor/target/date filters or export controls | Missing |
| No tamper-evidence beyond the trigger (no hash chain, no external anchor, no WORM) | Partial / `[OPEN]` |
| No retention or legal-hold policy | `[OPEN]` |
| No RLS on `platform.audit_log`; any API query path could read it | `F-32` remains open |
| Audit read returns at most 100 rows and no summaries | Incomplete |

### 2.9 Data model — actual tables that exist

| Schema | Tables that exist | Tables expected by the brief | Status |
|---|---|---|---|
| `identity` | accounts, users, credentials, memberships, grants, devices, sessions, mfa_factors, recovery_codes, tokens, mfa_challenges | + admin role assignments? (ownership to decide) | **Partial** |
| `profile` | profiles, activity_activations | verification lanes, cases, documents, KYC tier | **Missing** |
| `platform` | audit_log, outbox, idempotency_keys, feature_flags, reference_counters | config registry, reporting metadata, document metadata (or Files module) | **Partial** |
| `admin` | **none** | departments, staff, partners, roles, cases, evidence, approvals, queues, configuration, reporting read models | **Missing** |
| `market` | none | stores, products, orders, fulfilments | **Missing (later phase)** |
| `services` | none | jobs, applications, engagements, milestones | **Missing (later phase)** |
| `errands` | none | requests, offers, assignment, status | **Missing (later phase)** |
| `logistics` | none | dispatch, assignments, tracking, proof of delivery | **Missing (later phase)** |
| `finance` | none | ledger accounts, journal entries, postings, payouts, reconciliation | **Missing (later phase)** |
| `messaging` | none | threads, messages, notifications, delivery attempts | **Missing (later phase)** |

**Identity state-model gaps:** `identity.accounts.status` and `identity.users.status` allow only
`active`, `suspended`, `closed`. The permission matrix defines `RESTRICTED` as an account state
(§12.2). There is no `kyc_tier` on the account/profile. No account-level restriction model exists.

### 2.10 Financial governance

No ledger, no postings, no escrow, no payout, no reconciliation, no commission, no financial read
model, no maker-checker. This is expected: `ARCHITECTURE.md` §9.10 designs the ledger, but the
`finance` module is an empty boundary and EP-02 has not started. The Control Portal must **not**
invent a second financial model; it must consume the ledger and expose read models and approval
controls.

### 2.11 Verification, support, disputes, investigations

| Area | Exists |
|---|---|
| Verification lanes / cases / documents | No |
| Review queue | No |
| Support tickets / complaints | No |
| Disputes | No |
| Investigations | No |
| Evidence management | No |
| Notifications | Outbox exists; **no handlers**; no in-app notification table |
| Documents | Private-bucket design exists; no metadata table, no upload path |

### 2.12 Configuration and system health

- `platform.feature_flags` exists. It is explicitly non-financial and has no change history,
  approval or attribution beyond the row.
- No business configuration registry, no versioned settings, no effective dates, no rollback.
- Health endpoints exist. `/v1/health/ready` deliberately returns 503 because the database-backed
  check is not implemented.
- No job-queue dashboard, no integration status, no error-tracking vendor, no metrics/traces wiring.

### 2.13 Documentation and execution governance

The documentation set is unusually strong: approved product, architecture, permission, database,
security and visual documents; a phase/gate model; a work-package protocol; 47 tests; evidence packs.
The Control Portal assessment must **extend** this system, not sit beside it. The existing phase
model already assigns the `control` review platform to EP-02 and per-activity work to EP-03–EP-05.

---

## 3. Deliverable 2 — Functional coverage and gap analysis

Legend: **A** Adequate · **P** Partial · **I** Incomplete · **N** Inadequate · **M** Missing ·
**NR** Not Required (current scope).

### 3.1 Portal foundation and governance model

| # | Requirement | Status | Evidence / gap |
|---|---|---|---|
| 1 | Separate privileged portal application | **A** | `apps/control`, audience guard, MFA |
| 2 | One central governance architecture | **P** | Identity/audit/capability shared; `admin` domain empty; no shared admin services |
| 3 | Centralized authentication | **A** | One identity service per environment; four audiences |
| 4 | Centralized authorization | **P** | Pure engine exists; admin/staff/partner/resource inputs absent |
| 5 | Shared organizational/resource scope | **M** | No department, partner org or assignment model |
| 6 | Reusable administrative services | **M** | `admin` module empty |
| 7 | Standardized audit logging | **P** | Append-only exists; reason/approval/read-audit/export gaps |
| 8 | Controlled approval workflows | **M** | No approval model |
| 9 | Consistent investigation records | **M** | No case model |
| 10 | Shared notification infrastructure | **P** | Outbox exists; no handlers, no notification records |
| 11 | Standardized reporting | **M** | No read models or report service |
| 12 | Secure document/evidence management | **M** | Design only |
| 13 | Centralized administrative configuration | **P** | Feature flags only; no history/approval |

### 3.2 Business activity governance

| Activity | Governance surface | Status |
|---|---|---|
| Buy — Local Market | Listings, categories, sellers, moderation, orders, refunds, complaints, investigations | **M** — no `market` tables or endpoints |
| Hire a Professional | Jobs, applications, quotations, agreements, progress, earnings, disputes, verification | **M** — no `services` tables |
| Send an Errand | Requests, assignment, status, payments, incidents, disputes | **M** — no `errands` tables |
| Sell | Seller eligibility, products, orders, performance, payouts, restrictions | **M** — no `market` tables |
| Provide Services | Registration, verification, profiles, skills, listings, performance, payouts | **M** — no `services` tables |
| Provide Logistics | Provider verification, dispatch, tracking, earnings, incidents, compliance | **M** — no `logistics` tables |
| Future activities | Registry-driven extensibility | **P** — activity registry and capability namespace exist; admin surfaces are not registry-driven |

**Assessment:** the six activities are correctly modelled as distinct capabilities with a shared
identity, wallet, inbox and design system. That is the right foundation. The Control Portal should
provide a **generic governance frame** (queues, cases, approvals, audit, configuration, reports) plus
**per-activity read models**, not six separate admin systems.

### 3.3 Users and accounts

| Requirement | Status | Gap |
|---|---|---|
| User search/discovery | **N** | Endpoint exists but gated by wrong capability and blocked by RLS |
| User profile / unified identity | **P** | Account/user/profile exist; no administrative profile view |
| Account status and history | **P** | Status exists; no history, no `RESTRICTED` |
| Activity participation view | **P** | Activation table exists; no admin read model |
| Account restrictions/suspension/closure | **M** | No endpoints or service; only sign-in-time revocation |
| Session revocation | **P** | Self-service only; no admin action |
| Complaints/transaction/investigation history | **M** | No linked records |
| Administrative notes / timeline | **M** | No model |
| Activity-specific restrictions | **P** | Activation state exists; no admin command/audit |

### 3.4 Staff, departments and internal organisation

| Requirement | Status |
|---|---|
| Staff records, onboarding, profiles, employment status | **M** |
| Department creation, leadership, membership, scope | **M** |
| Staff lifecycle, offboarding, permission revocation, session invalidation | **M** |
| Staff workload, assignment, escalation, performance | **M** |
| Job-scoped staff capabilities | **P** — one `staff.support.handle` scope only |

### 3.5 Partners and external organisations

| Requirement | Status |
|---|---|
| Partner applications, invitations, onboarding | **M** |
| Organisation profiles, verification, due diligence | **M** |
| Authorized representatives | **M** |
| Contracts, categories, status, assigned services | **M** |
| Partner-specific access and reporting | **M** |
| Performance, compliance, renewal, suspension, termination | **M** |
| Organisation isolation, partner roles, resource scope | **M** |

### 3.6 Roles and permissions

| Requirement | Status |
|---|---|
| Roles distinct from permissions | **P** — vocabulary exists; no role entity |
| RBAC + ABAC hybrid | **P** — rule table is attribute-driven; no role/resource attributes |
| Granular module/page/resource permissions | **P** — capability strings exist; no admin resource actions |
| Custom roles, multiple roles, individual grants | **M** |
| Explicit deny | **M** |
| Department/activity/investigation roles | **M** |
| Temporary access / expiry | **P** — grant expiry only |
| Conflict resolution | **M** — undefined |
| Resource-level authorization | **M** |
| Privileged access protection, elevation, review, emergency access | **M** |
| Backend enforcement | **P** — strong pattern, incomplete coverage |

### 3.7 Investigation and case management

All items in brief §10 are **M** — no case workspace, lifecycle, evidence, authority separation,
cross-module access or retention.

### 3.8 Financial governance

All items in brief §11 are **M**, except that the ledger design is approved in
`ARCHITECTURE.md` §9.10 and must be followed, not replaced.

### 3.9 Verification and compliance

**M.** The permission matrix defines six lanes and their states; no table, queue, decision or
evidence model exists.

### 3.10 Support, complaints and disputes

**M.** No ticket, complaint, dispute or messaging model.

### 3.11 Configuration and platform policy

| Requirement | Status |
|---|---|
| Business configuration registry | **M** |
| Permission-controlled, validated, audited changes | **M** |
| History, rollback, approval | **M** |
| Separation from infrastructure/secrets | **P** — architecture states the boundary; no enforcement |

### 3.12 Approvals and workflows

**M.** No workflow definitions, stages, reviewers, approvers, limits, maker-checker, escalation or
history. The architecture explicitly excludes a generic workflow engine at MVP
(`ARCHITECTURE.md` §1.3). The answer is a **narrow, typed approval service**, not BPMN.

### 3.13 Notifications and communication

**P.** The outbox is real; the notification module is empty; no templates, delivery attempts,
preferences or in-app feed.

### 3.14 Reporting and analytics

**M.** No read models, report definitions, export controls or dashboard metrics. The brief's
financial metric distinctions cannot be implemented until the ledger exists.

### 3.15 Security, audit and accountability

| Requirement | Status |
|---|---|
| MFA / privileged protection | **A** |
| Session management / revocation | **P** — self-service; no admin or global revocation |
| Login history / failed-login monitoring | **P** — audited; no UI or alerting |
| Audit trail | **P** |
| Audit integrity / tamper evidence | **P** |
| Security incident management | **M** |
| Access reviews | **M** |

### 3.16 Data governance and privacy

| Requirement | Status |
|---|---|
| Data classification | **P** — documents define categories; no schema/field classification |
| Sensitive data restrictions | **P** — RLS and scopes; no admin read model |
| Minimisation | **P** — principles documented; no enforcement |
| Retention / deletion / legal hold | **M** and `[OPEN]` |
| Export controls and access auditing | **M** |
| Correction history | **M** |

### 3.17 Documents and knowledge

**M.** No document metadata, versioning, ownership, access log or retention. The storage design
(private R2, signed URLs, scanning) exists in `ARCHITECTURE.md` §9.12 and must be reused.

### 3.18 System health and integrations

| Requirement | Status |
|---|---|
| Application/service health | **P** — liveness; readiness 503 |
| Background jobs / queue health | **P** — worker health exists; no portal view |
| Failed jobs / errors | **P** — dead-letter exists; no UI; no error tracker |
| Integration status | **M** |
| Performance indicators | **M** |
| Secrets/infrastructure isolation | **P** — architecture; no portal exposure (correct) |

### 3.19 Navigation, overview, future extensibility

| Requirement | Status |
|---|---|
| Coherent IA | **P** — four hard-coded sections |
| Role-based nav | **M** |
| Executive overview | **N** — session and capability cards only |
| Future activity support | **P** — registry exists; admin is not registry-driven |

---

## 4. Deliverable 3 — Proposed information architecture

### 4.1 Principles

1. **One navigation model, two shells.** `control` and `staff` are different trust surfaces with
   different navigation emphases, but they expose the same governance concepts and the same backend
   services. `partner` remains a separate external shell.
2. **Twelve areas, not seventeen systems.** Each area maps to an `admin` service and one or more
   module read models. A navigation area is not a database or a deployable.
3. **Operational first.** The default landing view is the work that needs a decision today, not a
   wall of statistics.
4. **Contextual cross-links.** A user, case, transaction, order, job, errand, delivery, partner and
   staff member are linkable entities. Cross-module navigation is a link with a scoped read, never a
   second copy of the record.
5. **Capability-filtered navigation.** Navigation items are derived from the computed capability set.
   Hiding is a courtesy; the API remains authoritative.
6. **Activity views are registered, not hard-coded.** A new activity adds a registry entry and its
   read model; it does not add a new navigation framework.

### 4.2 Proposed control navigation

| # | Area | Sub-navigation | Primary backend |
|---|---|---|---|
| 1 | **Overview** | Action centre, platform pulse, exceptions | `admin` read models |
| 2 | **Accounts** | Search, account detail, activity participation, restrictions, sessions | `identity`, `profile` |
| 3 | **People & Organisations** | Staff, departments, partners, representatives | `admin` |
| 4 | **Access & Authority** | Roles, assignments, temporary access, access reviews, denials | `admin` + `identity` |
| 5 | **Trust & Compliance** | Verification queues, lanes, evidence, reverification, compliance cases | `profile` + `admin` |
| 6 | **Cases & Investigations** | Support, disputes, investigations, incidents, evidence, outcomes | `admin` |
| 7 | **Business Activities** | Buy, Hire, Errand, Sell, Services, Logistics (registry-driven) | activity modules |
| 8 | **Finance** | Ledger overview, transactions, wallets, payouts, refunds, reconciliation, exceptions | `finance` |
| 9 | **Configuration & Approvals** | Policies, taxonomy, fees/limits, approvals inbox, approval history | `admin` + `platform` |
| 10 | **Reports & Analytics** | Platform, financial, operational, compliance, exports | read models |
| 11 | **Security & Audit** | Audit search, privileged activity, sign-in anomalies, security incidents, access reviews | `platform` + `admin` |
| 12 | **System & Integrations** | API health, workers, queues, integrations, failed jobs | `platform` + worker |

**Cross-cutting, not a nav area:** **Documents & Evidence**. A document is reachable from the
account, case, partner, staff member or approval it belongs to. A standalone "Documents" area is an
optional later addition for policy/procedure libraries; it must not become a second storage system.

**Why this grouping:**

- It separates **people** (accounts), **internal organisation** (staff/departments), **external
  organisation** (partners) and **authority** (roles/access).
- It separates **trust decisions** (verification) from **disputes and investigations** (cases), while
  allowing a case to link to a verification record.
- It separates **business activity operations** from **financial oversight**, because an order and a
  ledger entry have different owners and different controls.
- It separates **configuration** (business rules) from **system health** (technical operations), as
  the brief and the architecture require.
- It puts **approvals** next to configuration, but the approval inbox is global and also appears as a
  badge in the top bar. Approvals are not a separate module from the actions they authorise.

### 4.3 Staff shell navigation

| Area | Content |
|---|---|
| My work | Assigned cases, verification tasks, support tickets, overdue items |
| Verification | Assigned lane cases, evidence view, decision within policy |
| Support | Assigned tickets, complaints, customer context, message threads |
| Operations | Assignment oversight, dispatch exceptions, SLA monitoring |
| Knowledge | Approved procedures and policy references (read-only) |
| My activity | Own actions, audit history |

Staff do **not** see: finance configuration, role administration, partner contracts, platform-wide
audit, engineering tools, or another department's queues. A staff member who also holds a control
grant uses `control` as a separate session/audience; the grant does not merge into the staff shell.

### 4.4 Partner shell navigation

| Area | Content |
|---|---|
| Overview | Partnership status, performance summary, outstanding actions |
| Applications | Application, documents, status, renewal |
| Referrals | Codes, attributed sign-ups, conversion status (aggregate) |
| Commission | Accrual, statements, payout status |
| Organisation | Profile, representatives, agreements, contacts |

Partners never see another organisation, referred-user personal data beyond aggregate status, any
activity capability, any wallet, or any internal operations screen.

### 4.5 Executive overview design rule

The overview has three bands, in this order:

1. **Decide now** — approvals awaiting me, overdue cases, verification SLA breaches, security alerts,
   reconciliation breaks, failed payouts, suspensions awaiting review.
2. **Operate today** — open cases by type, queue depth, verification backlog, support first-response,
   delivery exceptions, staff workload.
3. **Understand the platform** — accounts, activity participation, GTV, platform revenue, wallet
   liabilities, pending payouts, refunds, growth.

Every number has: a definition, an owner, a source model, a freshness timestamp and a link to the
filtered list that produced it. A metric without a definition is not shown.

---

## 5. Conflicts with approved decisions — founder decisions required

### D-01 — Control vs staff scope (critical)

**Approved position:** `control` is for the founder and explicitly authorised
administrators/developers; `staff` is for appointed staff with job-specific permissions; a staff
member does not automatically receive administrator privileges, and staff never reach `control`
unless they separately hold a control grant (`ARCHITECTURE.md` §1.4, §4.4, §4.5, §7.2–§7.3,
§10.6).

**Brief position:** management personnel, staff, investigators, departments and partners operate
within a central Control Portal, with management visibility and staff permissions separated.

**Assessment:** these are compatible in *function* but not in *surface*. The recommended resolution:

- **Option A (recommended): one governance architecture, two operational shells.** Keep `control` and
  `staff` as approved. Put all governance services in the `admin` module. `control` exposes
  governance, approvals, configuration, investigations and platform-wide oversight. `staff` exposes
  job-scoped operational queues. Both use the same authorization engine and service layer. This
  preserves the approved trust boundary and satisfies "centralized governance without unrestricted
  access".
- **Option B: widen `control` to all management and operational staff.** This requires revising
  `ARCHITECTURE.md` §1.4, §4.1, §7.2–§7.3 and the session-audience model. It increases the blast
  radius of the highest-value target, gives every staff member a session on the governance host, and
  weakens the "staff never default to admin" guarantee. Not recommended.
- **Option C: merge `staff` into `control` and retire the staff host.** Not recommended for the same
  reasons, plus it breaks the approved eight-deployment topology.

**Decision needed:** A, B or C. **Recommendation: A.**

### D-02 — Who may see platform-wide data

The brief asks for broad management visibility. The approved model requires scoped access, data
minimisation and audit of sensitive reads. These are not contradictory if "visibility" means
**aggregate and exception visibility by default**, with record-level PII requiring an explicit
capability, a reason and an audit record.

**Decision needed:** confirm that platform-wide *aggregates* are available to management roles, while
record-level identity, financial, verification and investigation data require a scoped capability and
are audited. **Recommendation: confirm.**

### D-03 — Administrative role model ownership

`ARCHITECTURE.md` assigns grants to the identity module and admin scopes to the admin module. The
existing `AdminRole` type lives in the capability engine but has no data home.

**Options:** (a) admin roles and assignments in `admin`, with identity grants remaining the
privileged-surface grant record; (b) all roles in `identity.grants`, overloading `scope`; (c) a new
`authorization` schema.

**Recommendation:** (a). `identity.grants` continues to answer "may this user enter this privileged
surface and hold this grant type"; `admin.role_assignments` answers "what governance role, in which
department/organisation, for how long". The capability engine composes both. This preserves the
module boundary and avoids overloading a security-critical table. **Decision needed.**

### D-04 — Case spine vs separate systems

The brief requires support, disputes, investigations, incidents and evidence. The architecture
forbids unnecessary duplication.

**Recommendation:** one `admin.cases` spine with typed cases and typed links, not five systems. A
support case that becomes an investigation gets a linked child investigation case, preserving the
support history and the escalation trail. **Decision needed.**

### D-05 — Partner organisation cardinality

The permission matrix leaves "business as account or profile" open (`§18 #5`). Partner organisations
with multiple representatives raise the same question.

**Recommendation:** partner organisations are `admin` entities, not second accounts. Representatives
are users linked through `identity.memberships` and `admin.partner_representatives`. No second
credential store, no second wallet, no activity capability. **Decision needed.**

### D-06 — Approval engine shape

The architecture excludes a generic workflow engine (`§1.3`). The brief asks for configurable
workflows.

**Recommendation:** a narrow, typed `admin.approval_requests` service with fixed stages and
configurable thresholds per action type. No BPMN, no expression language, no plugin runtime.
**Decision needed.**

### D-07 — Audit tamper evidence and retention

The append-only trigger is a good control but not tamper-evident against a database owner. The brief
asks for tamper evidence.

**Recommendation:** add a per-record hash chain over the audit fields, plus a periodic signed digest
exported to immutable storage. Retention and legal hold remain `[OPEN]` and must be decided with
counsel. **Decision needed** on retention and on whether the hash-chain work is MVP or later.

### D-08 — Financial and verification scope

The Control Portal cannot implement financial oversight before the ledger exists, and cannot manage
verification before the lanes exist. Both depend on open founder decisions: funds custody (BD-D01),
take rate (BD-D02), escrow/dispute rules (BD-D03), KYC ladder (BD-D05), verification vendor (#15).
**No financial or verification implementation may begin until those are decided.** This is a
sequencing fact, not a technical preference.

### D-09 — Activity governance scope

The brief lists governance for all six activities. EP-01 explicitly excludes all six transaction
flows, and EP-03–EP-05 own them. The Control Portal's activity surfaces must be built **with** each
activity module, not ahead of it. Building admin screens for tables that do not exist would create
dead, misleading UI.

---

## 6. Deliverable 4 — Centralized authorization architecture

### 6.1 The model in one paragraph

Authorization is a **server-side decision** over four inputs: who is acting (identity, account,
audience, environment), what authority they hold (privileged grants, role assignments, individual
permissions, explicit denies, temporary elevation), what the resource is (type, owner, organisation,
department, sensitivity, assignment, state), and what the action is (a capability string). The
decision is computed per request inside the transaction, never trusted from the client, never encoded
in a token claim the client can forge, and recorded in the audit trail when it is sensitive.

### 6.2 Identity relationships

```
user ──membership──► account ──activation──► activity ──► activity capability
  │                     │
  │                     ├── profile / KYC tier / verification lanes
  │                     └── wallet / records
  │
  ├── privileged grants (identity.grants)      → portal entry + grant type
  ├── admin role assignments (admin.*)          → governance authority + scope
  ├── staff profile / department (admin.*)      → internal organisational scope
  └── partner representative (admin.*)          → organisation scope
```

The account remains the legal/billing party and the owner of records. A staff member, administrator
or partner representative is a **user** with additional assignments; none of these is an account
type, and none activates an activity.

### 6.3 Roles versus permissions

| Concept | Definition | Stored as |
|---|---|---|
| Permission | A specific capability string, e.g. `admin.case.assign` | `admin.permissions` / code registry |
| Role | A named collection of permissions, e.g. `investigator` | `admin.roles` + `admin.role_permissions` |
| Assignment | A role or permission granted to a user, with scope and validity | `admin.role_assignments`, `admin.permission_grants` |
| Resource scope | The records the assignment may reach | Assignment attributes + resource policy |
| Deny | An explicit prohibition that overrides an allow | `admin.access_denials` |

A role never grants every record in its module. `Investigator` grants investigation capabilities;
the assignment's scope (department, case, activity, organisation) determines which investigations.

### 6.4 Decision algorithm (normative order)

```
1. Reject if unauthenticated, wrong audience, or wrong environment.
2. Reject if the capability is unknown or not registered.
3. Collect effective authority:
     a. active privileged grants (environment-scoped, unexpired, unrevoked)
     b. active role assignments (unexpired, unrevoked, approved)
     c. active individual permission grants
     d. active temporary elevations
4. If any matching explicit deny is active → DENY (deny wins).
5. If no matching allow → DENY (default deny).
6. If the capability requires an approval → require an approved request whose requester is not the actor.
7. If the capability is resource-scoped → evaluate the resource policy:
     a. resource exists and is visible to the actor's scope
     b. actor is not the subject of a prohibited self-action
     c. resource sensitivity is within the actor's clearance
8. Allow, and write the audit record when the action is sensitive.
```

**Conflict resolution:** union of allows, then explicit deny wins, then scope intersection. Multiple
roles never widen scope beyond the assignment's own scope. An expired assignment contributes nothing.
No wildcard permission and no `*` role exist.

### 6.5 Proposed governance roles (collections, not universes)

| Role | Typical permissions | Typical scope | Explicitly not included |
|---|---|---|---|
| Founder | All governance capabilities | Platform-wide | Cannot bypass dual control or self-approval rules |
| Governance Administrator | Role assignment, staff/partner administration, configuration read, approvals | Platform, or delegated departments | No money movement, no investigation decision, no audit deletion |
| Verification Officer | Verification queue read, evidence read, recommend decision | Assigned lanes/cases | Payments, configuration, account closure |
| Support Officer | Support case read/update, customer context, messages | Assigned queues/cases | Verification decisions, refunds above threshold, PII export |
| Operations Officer | Assignment oversight, dispatch exceptions, SLA | Assigned activity/department | Financial configuration, role administration |
| Finance Officer | Ledger read, reconciliation, payout review | Finance scope | Role administration, verification, account suspension |
| Investigator | Case read, evidence, notes, findings, recommendation | Assigned cases/teams | Final sanction approval, money movement |
| Compliance Reviewer | Case review, decision, policy reference | Assigned case categories | Case investigation authorship on the same case |
| Partner Manager | Partner application, organisation, agreement, performance | Partner portfolio | Internal staff data, platform audit, any activity capability |
| Auditor | Audit read, report read, export | Read-only, platform or scope | Any write |
| Platform Engineer | Health, queues, logs, deployment metadata | Technical scope | User PII, money, verification, business rules |
| Department Manager | Staff workload, department reports, case assignment | Own department | Cross-department records, financial configuration |

These are **starting definitions**, not final. The founder must approve the role catalogue and the
permission-to-role mapping. The table is deliberately narrow; the brief's breadth is achieved through
scope and assignment, not by granting every role every module.

### 6.6 Proposed capability namespaces

Extend the existing registry; do not create a second list.

| Namespace | Examples |
|---|---|
| `admin.user.*` | `read`, `update`, `restrict`, `suspend`, `reactivate`, `close`, `session.revoke`, `export` |
| `admin.staff.*` | `read`, `invite`, `update`, `suspend`, `offboard`, `department.assign` |
| `admin.department.*` | `read`, `create`, `update`, `member.manage` |
| `admin.partner.*` | `read`, `application.review`, `organisation.verify`, `representative.manage`, `agreement.manage`, `suspend`, `terminate` |
| `admin.role.*` | `read`, `create`, `update`, `assign`, `revoke`, `review` |
| `admin.verification.*` | `queue.read`, `case.read`, `evidence.read`, `decide`, `request_info`, `override` |
| `admin.case.*` | `read`, `create`, `assign`, `update`, `escalate`, `recommend`, `approve`, `close`, `reopen` |
| `admin.evidence.*` | `read`, `upload`, `verify`, `supersede`, `export` |
| `admin.finance.*` | `read`, `transaction.read`, `refund.review`, `payout.review`, `adjustment.request`, `reconciliation.review`, `export` |
| `admin.config.*` | `read`, `write`, `publish`, `rollback` |
| `admin.approval.*` | `read`, `decide`, `delegate` |
| `admin.report.*` | `read`, `export` |
| `admin.audit.*` | `read`, `export` |
| `admin.security.*` | `incident.read`, `incident.manage`, `access_review.run` |
| `staff.*` | `support.handle`, `verification.review`, `operations.manage`, `marketing.manage` |
| `partner.*` | `application.read`, `referral.read`, `commission.read`, `representative.manage` |

A capability is a string in `@hivorr/shared`; computation remains server-side. Adding a capability
requires a row in the requirement table and a deny-path test.

### 6.7 Resource scope model

Resource scope is **not** a SQL string supplied by the client. It is derived from the assignment and
evaluated by the service.

| Scope kind | Attribute source | Example |
|---|---|---|
| Platform | Assignment `scope_type = platform` | Founder, Auditor |
| Department | `admin.department_members` | Support queue for Department A |
| Organisation | `admin.partner_representatives` | Partner organisation X |
| Activity | Assignment `activity_id` | Logistics operations |
| Case | `admin.case_assignments` | Investigator assigned to case C |
| Team | `admin.case_team_members` | Investigation team |
| Subject | Resource owner/party | A user's own account |
| Sensitivity | Resource classification vs actor clearance | Identity documents, financial records |

Every admin list query takes a **scope predicate** from the service. The repository applies it as a
parameterised `where` clause; RLS is the second line. A missing scope predicate fails closed.

### 6.8 Worked examples

**Example 1 — Verification officer opens a case**

- User `U` holds `staff` grant `staff.verification.review` and admin assignment
  `verification_officer`, department `Trust`, expiry in 30 days.
- Request: `GET /v1/staff/verification/cases/{id}`.
- The service checks audience `staff`, resolves the assignment, checks
  `admin.verification.case.read`, then loads the case's `department_id` and `assignee_id`.
- Allow only if the case is in `Trust` **and** (`assignee = U` or the officer has
  `queue.read` for that queue). Otherwise return `NOT_FOUND` (preferred over `FORBIDDEN`, to avoid
  confirming existence).
- Every evidence document open issues a short-lived signed URL and writes an audit record.

**Example 2 — Support officer tries to refund**

- User `S` holds `staff.support.handle`, no finance capability.
- Request: `POST /v1/control/finance/refunds`.
- Capability `admin.finance.refund.review` is not held → `403 FORBIDDEN` with a stable code.
- Even if `S` held it, the refund requires an approved `approval_request` whose requester is not `S`.
  The service checks the approval state, amount threshold, and that the ledger entry is a reversal,
  not an edit.

**Example 3 — Investigator recommends suspension**

- Investigator `I` holds `admin.case.investigate` and is assigned to case `C`.
- `POST /v1/control/cases/C/recommendations` with outcome `SUSPEND_ACCOUNT`.
- Allowed: `I` may write a recommendation, not execute it.
- The recommendation creates an approval request. `I` cannot approve it (requester ≠ approver).
- A `Compliance Reviewer` with `admin.case.approve` and the right scope approves or rejects.
- Execution is performed by a separate service call holding `admin.user.suspend`, with the approval
  reference, reason and audit record. If the approver also holds the execution capability, the
  approval and execution are still two recorded steps.

**Example 4 — Department manager views workload**

- Manager `M` holds `admin.case.assign` scoped to department `Operations`.
- The workload query's scope predicate is `department_id = Operations`.
- A case in `Trust` is invisible: the list does not include it and a direct fetch returns `NOT_FOUND`.
- The audit record for the read is written only if the report is sensitive or exported; ordinary
  list reads are sampled/aggregated per the audit policy.

### 6.9 Temporary access, review and emergency access

- **Temporary elevation:** `admin.role_assignments.expires_at`; a separate
  `admin.access_requests` record captures reason, approver and window. Elevation never changes the
  user's base roles; it is an additional, expiring assignment.
- **Access reviews:** `admin.access_reviews` with a scope, a reviewer, a due date and per-assignment
  decisions (`keep`, `revoke`, `reduce`). Overdue reviews appear on the overview.
- **Emergency access:** break-glass uses the existing `hivorr_breakglass` database role for database
  emergencies and a time-boxed, dual-controlled control grant for application emergencies. Every use
  is audited and reviewed within one business day. The application does not invent a permanent
  superuser.
- **Self-action:** no user may suspend, restrict or close their own account; no user may approve their
  own request; no user may approve a case they investigated; no user may revoke the last
  grant-manager (existing guard, extended).

### 6.10 Backend enforcement

| Layer | Control |
|---|---|
| Edge | Cloudflare Access on control/staff; TLS; HSTS; noindex; rate limits |
| Route | Audience declaration; session audience/environment validation |
| Service | `authorize(actor, capability, resource)` inside the transaction; approval and SoD checks |
| Repository | Mandatory scope predicate; parameterised SQL; no cross-schema reads |
| Database | RLS and grants, as defence in depth; `security definer` only where justified and pinned |
| Audit | Sensitive read/write/export records written in the same transaction |

**Existing gaps to close:** the engine is not wired to admin roles; the control user read is not a
scoped admin read; `identity.grants` cannot express the needed scopes; no resource policy exists; no
deny/elevation/approval model exists.

---

## 7. Deliverable 5 — Staff and partner governance architecture

### 7.1 Internal staff

**Entities (proposed, `admin` schema):**

- `admin.staff_profiles` — user id, employee reference, job title, department, supervisor,
  engagement status, start/end dates, contact metadata.
- `admin.departments` — name, description, parent department, leadership user id, status.
- `admin.department_members` — department, user, role in department, effective dates.
- `admin.role_assignments` — user, role, scope type/id, department, effective dates, approver.
- `admin.work_items` — assigned cases/tasks, priority, due date, status, escalation. This is the
  single task/assignment spine; it is not a second project-management system.

**Lifecycle:** invite → accept → profile → department → role assignment → work → transfer →
suspension/leave → offboarding. Offboarding revokes grants, role assignments and sessions
immediately, retains the staff record and the audit history, and reassigns open work. It never
deletes the person's past actions.

**Workload:** derived from `admin.work_items` and case assignments, not a separate performance
system. Performance reporting uses decision counts, SLA attainment, case ageing and quality review
outcomes; it must not become covert surveillance. Any individual-level performance metric requires a
founder decision and a stated purpose.

### 7.2 External partners

**Entities (proposed, `admin` schema):**

- `admin.partner_organisations` — legal name, trading name, registration, category, status.
- `admin.partner_representatives` — user, organisation, representative role, authority evidence,
  effective dates.
- `admin.partner_applications` — application, documents, review, decision.
- `admin.partner_agreements` — contract reference, terms metadata, start/end, renewal.
- `admin.partner_scopes` — which programme/services the organisation may access.
- `admin.partner_performance` — read model over referrals/commission/service delivery.

**Access isolation:** partner sessions carry audience `partner`; they never carry an activity
capability or a wallet. Every query is scoped by `organisation_id` derived from the representative
record, not from a request parameter. RLS adds the same predicate. A representative of organisation A
cannot read organisation B, even with a guessed id.

**Separation from staff:** a partner representative never holds a staff or admin assignment. A person
may be both a partner representative and an ordinary Hivorr user, or separately a staff member, but
the assignments are distinct and the sessions are separate audiences. No inheritance.

---

## 8. Deliverable 6 — Investigation and case management architecture

### 8.1 One case spine

```
admin.cases
  id, reference, case_type, category, title, description,
  source, priority, severity, sensitivity, status,
  subject_type, subject_id, activity_id,
  department_id, queue_id, assignee_id, team_id,
  parent_case_id, created_by, created_at, updated_at, closed_at,
  outcome, closure_reason
```

`case_type` is one of: `support`, `complaint`, `dispute`, `investigation`, `incident`,
`verification_review`, `financial_exception`, `security_incident`, `staff_conduct`,
`partner_conduct`. `parent_case_id` preserves escalation and keeps support history intact.

**Why one spine:** the brief requires cross-module investigations and warns against duplicating the
same issue in disconnected systems. A support ticket, a dispute and an investigation share assignment,
priority, notes, evidence, escalation, approval and audit. Separate tables would duplicate all of
those and make cross-case reporting unreliable.

### 8.2 Supporting tables

| Table | Purpose |
|---|---|
| `admin.case_events` | Append-only timeline: status, assignment, note, escalation, decision |
| `admin.case_links` | Typed links to user, account, order, job, errand, delivery, transaction, verification, partner, staff, incident |
| `admin.case_evidence` | Document metadata, source, submitter, hash, classification, supersede chain |
| `admin.case_findings` | Findings, factual basis, policy reference, author |
| `admin.case_recommendations` | Recommended action, rationale, author, approval reference |
| `admin.case_decisions` | Authorised decision, approver, reason, outcome, execution reference |
| `admin.case_actions` | Executed outcomes (suspend, restrict, refund, payout hold, etc.) with result |
| `admin.case_assignments` | Assignment history, not just current assignee |
| `admin.case_team_members` | Multi-investigator cases |

### 8.3 Lifecycle

```
RECEIVED → TRIAGED → OPEN → INVESTIGATING
                         ├→ PENDING_INFORMATION → INVESTIGATING
                         ├→ ESCALATED → REVIEW
                         └→ REVIEW → DECIDED → ACTION_PENDING → CLOSED
CLOSED → REOPENED → INVESTIGATING
Any state → MERGED (into a parent case) or ARCHIVED (retention only)
```

Rules:

- A decision cannot be recorded without a finding (except administrative closure with a reason).
- A sanction cannot be executed from a recommendation alone; it requires an approved decision.
- Reopening preserves the prior closure and appends a new cycle.
- Merging preserves both references and the audit trail.
- Closure requires a disposition code and a reason.

### 8.4 Evidence management

- Upload to the private R2 bucket through a pre-signed PUT; the API validates type, size and
  ownership; the object key is not a public URL.
- Store metadata, SHA-256 hash, MIME type, size, uploader, source, classification and retention class.
- Serve through short-lived signed GET; every issuance is audited.
- Originals are immutable. A correction creates a new version linked by `supersedes_id`; the original
  remains readable to authorised auditors.
- Antivirus/malware scan before the evidence becomes usable (`ARCHITECTURE.md` §9.12).
- Evidence deletion is prohibited while a case or legal hold is open; retention disposition is
  `[OPEN]`.
- A case can link to evidence held by another module (for example a KYC document) without copying it;
  the link carries the source module and the access is checked at read time.

### 8.5 Authority and separation of duties

| Step | Who | Capability |
|---|---|---|
| Triage | Support/operations | `admin.case.assign` |
| Investigate | Assigned investigator | `admin.case.investigate` |
| Find | Investigator | `admin.case.finding.write` |
| Recommend | Investigator | `admin.case.recommend` |
| Review/decide | Compliance reviewer/approver | `admin.case.approve` |
| Execute | Authorised operator | the specific action capability, plus approval reference |
| Audit | Auditor | `admin.audit.read` |

Rules: investigator ≠ approver; requester ≠ approver; executor may equal approver only for low-risk
actions and only when the policy allows it and records both steps. High-risk actions always require
two people.

### 8.6 Cross-module access without duplication

- The case stores **references**, not copies.
- The workspace calls each module's public read interface (`market.readOrder`, `finance.readEntry`,
  `profile.readVerification`, etc.) inside its own transaction.
- Each module returns only the fields the case capability is allowed to see, with the resource scope
  applied by that module.
- A cross-module read that reveals sensitive data writes an audit record.
- The case does not join across schemas and does not create a second copy of business records.

---

## 9. Deliverable 7 — Financial governance architecture

### 9.1 Reuse, do not rebuild

The ledger is `ARCHITECTURE.md` §9.10: double-entry, append-only, `numeric(20,4)`, currency,
journal entries and postings, escrow, payout payable, commission payable, adjustment. The Control
Portal adds **read models, exception queues and approval controls**, never a second balance or a
second ledger.

### 9.2 Definitions that must be fixed before any dashboard

| Metric | Definition | Source |
|---|---|---|
| Gross transaction value (GTV) | Sum of settled customer payments in the period, before refunds | Ledger clearing postings / order read model |
| Platform revenue | Recognised fee revenue postings in the period | `fee_revenue` ledger account |
| Wallet balance | Sum of posted user-wallet entries per currency | Ledger |
| Available balance | Wallet balance minus held/pending amounts | Ledger + holds |
| Pending payout | Payout payable not yet settled | `payout_payable` |
| Outstanding liability | Wallet + escrow + payout payable + commission payable | Ledger |
| Refund obligation | Approved but unexecuted refunds | Approval + ledger |
| Commission | Accrued partner commission payable | `commission_payable` |
| Realised revenue | Fee revenue minus refunds/chargebacks attributable to the period | Ledger |

No dashboard may mix GTV with revenue, or wallet balance with platform cash. Each metric has one
definition and one source model. The founder must approve the definitions; the financial rules
(fee, escrow, dispute) remain `[OPEN]` (`ARCHITECTURE.md` §16.4 #11).

### 9.3 Financial action controls

| Action | Control |
|---|---|
| Refund | `admin.finance.refund.review`; amount threshold; maker-checker; reversal posting only |
| Manual payout | `admin.finance.payout.review`; bound verified account; threshold; dual control |
| Adjustment | `admin.finance.adjustment.request`; reason; approver; reversing entry; no balance edit |
| Reconciliation sign-off | `admin.finance.reconciliation.review`; evidence; period lock |
| Commission approval | partner manager + finance reviewer; agreement reference |
| Limit/fee change | founder-only or delegated; configuration approval; effective date; audit |

**No one may move money because they hold general administrative access.** The capability, the
approval, the threshold and the ledger invariant are separate checks.

### 9.4 Exception and reconciliation

A daily reconciliation job compares provider settlements to the ledger and creates
`admin.finance_exceptions` for mismatches. The control surface shows unmatched items, ageing, owner
and resolution. Resolution is an approval-backed action with a reason, not a silent edit. Provider
callbacks are stored raw, verified and processed idempotently (existing architecture rule).

---

## 10. Deliverable 8 — Technical architecture recommendations

### 10.1 Frontend

| Concern | Recommendation |
|---|---|
| Design system | Reuse `packages/design` tokens and primitives. Add generic governance primitives there (`DataTable`, `FilterBar`, `StatusPill`, `Timeline`, `ApprovalPanel`, `EvidenceCard`, `ScopeBadge`) only when a second consumer exists. Do not create a second palette. |
| Shell | Replace the hand-rolled control shell with the shared app shell and `react-router`. Add a route manifest for control/staff/partner. |
| State | TanStack Query for server state (already a dependency); local state for dialogs; no global store. |
| Permission-aware UI | Session response returns presentation-only capabilities; a `Can` component hides/disables and explains. The API remains authoritative. |
| Navigation | Capability-filtered, role-aware; no dead links; no route that the API would deny outright. |
| Tables | Cursor pagination, server-side sort/filter, saved views, export with capability + audit. |
| Evidence | Signed-URL viewer, no public bucket, no inline rendering of untrusted SVG/HTML. |
| Accessibility / visual | Prototype tokens, 375/768/1280, visible focus, status not by colour alone. |
| Bundle safety | Control code never ships to partner; staff code never ships to app; keep four bundles. |

**Package question:** the architecture allows four apps to share `design`, `shared` and
`api-client`. A shared governance page package would reduce duplication between control and staff,
but adds a package. Recommendation: start with **design-level primitives** only; keep page
composition per app. If duplication becomes material, propose a `packages/governance-ui` as a
recorded architecture change — not silently.

### 10.2 Backend

| Concern | Recommendation |
|---|---|
| Module | `admin` owns governance tables and the public governance service. It reads other modules through their public interfaces. |
| Controllers | `/v1/control/*` (audience `control`), `/v1/staff/*` (audience `staff`), `/v1/partner/*` (audience `partner`). Every endpoint declares an audience. |
| Service | `authorize()` inside the transaction, before the read/write. Resource policy functions per resource type. |
| Domain | Pure state machines for cases, approvals and assignments. No HTTP or SQL in domain. |
| Repository | Parameterised SQL only; scope predicate mandatory; no cross-schema joins. |
| Read models | Module-owned views/functions for reporting; admin composes. No shared tables. |
| Approval | Narrow typed service; no generic workflow engine. |
| Audit | Platform `appendAudit`; extend the contract with reason, approval reference, session id and sensitivity. |
| Notifications | Reuse the outbox and messaging module; register handlers; no second queue. |
| Files | Reuse R2 and the private-document design; add metadata, not a second store. |
| Search | Start with indexed SQL; do not add a search engine until volume requires it. |

### 10.3 Data

- New `admin` schema tables; extend `identity` only where identity truly owns the concept; extend
  `profile` for verification; extend `platform` for configuration/audit metadata.
- Forward-only migrations, self-contained, reviewed. No destructive migration without founder
  sign-off and an expand/contract plan.
- UUIDv7, `timestamptz`, `numeric` for money, explicit status enums with check constraints.
- RLS on admin tables with a scope predicate; `FORCE ROW LEVEL SECURITY`; indexes on scope columns.
- `security definer` only for narrowly justified read paths; pin `search_path` per the database rules
  (see finding CPF-20); revoke public execute.

### 10.4 API

- Cursor pagination; bounded page size; no unbounded arrays (`F-18`).
- `ETag`/`If-Match` on mutable administrative records.
- `Idempotency-Key` on sensitive commands (refund, payout, adjustment, suspension).
- Stable error codes: `AUTHZ_*`, `CASE_STATE_*`, `APPROVAL_*`, `SCOPE_*`.
- Resource-level deny returns `NOT_FOUND` where confirming existence is a risk.
- Every response that includes sensitive data is audited or explicitly classified as non-sensitive.

### 10.5 Security and integration

- MFA on control and staff; Cloudflare Access; no public API.
- Rate limits per account/audience; tighter on exports and sensitive reads.
- No secrets in any portal, log, error or client bundle.
- Integration health is read-only; no infrastructure control through the portal.
- Error tracking and structured logs with PII redaction; no free-text provider payloads in logs.

### 10.6 Scalability and maintainability

The design scales by adding rows and read models, not infrastructure:

- More staff → more assignments, same tables.
- More departments → hierarchy rows.
- More partners → organisation rows and scopes.
- More cases → partitioned/indexed case tables; archive closed cases by policy.
- More activities → registry entries + module read models; no new admin framework.
- More transactions → ledger and read models, not admin tables.
- More granular permissions → permission rows, not code branches.

Revisit only on the recorded triggers (`ARCHITECTURE.md` §13.6): sustained DB CPU, queue latency,
module cadence divergence, second currency, mobile, licence, second product line.

---

## 11. Deliverable 9 — Data model and relationship assessment

### 11.1 Reuse as-is

`identity.accounts`, `identity.users`, `identity.credentials`, `identity.memberships`,
`identity.sessions`, `identity.devices`, `identity.mfa_factors`, `identity.recovery_codes`,
`identity.tokens`, `identity.grants`, `profile.profiles`, `profile.activity_activations`,
`platform.audit_log`, `platform.outbox`, `platform.idempotency_keys`, `platform.feature_flags`,
`platform.reference_counters`.

### 11.2 Extend

| Entity | Extension | Reason |
|---|---|---|
| `identity.accounts` | add `restricted` status; add `kyc_tier` (or a profile KYC record) | Matrix §12.2 and §7.4 |
| `identity.users` | add `restricted` status where appropriate; add `last_seen` metadata | Account lifecycle |
| `identity.grants` | add `reason`, `approval_reference`, `granted_by` already exists; consider `source` | Audit and governance |
| `platform.audit_log` | add `reason`, `approval_reference`, `session_id`, maybe `request_id`; add hash-chain columns | Brief §18.2–18.3 |
| `platform.feature_flags` | add `updated_by`, `change_reason`, history table | Configuration governance |
| `profile.profiles` | add business/profile fields if the business remains a profile (`OPEN #5`) | Business representation |
| `profile.activity_activations` | add `state_reason`, `state_changed_by` | Activity restriction audit |

### 11.3 New entities (all `[PROPOSED]`)

**Governance / access:** `admin.roles`, `admin.permissions`, `admin.role_permissions`,
`admin.role_assignments`, `admin.permission_grants`, `admin.access_denials`,
`admin.access_requests`, `admin.access_reviews`.

**Staff:** `admin.staff_profiles`, `admin.departments`, `admin.department_members`,
`admin.work_items`.

**Partners:** `admin.partner_organisations`, `admin.partner_representatives`,
`admin.partner_applications`, `admin.partner_agreements`, `admin.partner_scopes`.

**Cases:** `admin.cases`, `admin.case_events`, `admin.case_links`, `admin.case_evidence`,
`admin.case_findings`, `admin.case_recommendations`, `admin.case_decisions`, `admin.case_actions`,
`admin.case_assignments`, `admin.case_team_members`.

**Approvals:** `admin.approval_requests`, `admin.approval_steps`, `admin.approval_decisions`.

**Configuration:** `admin.configuration_entries`, `admin.configuration_versions`,
`admin.configuration_approvals` (or reuse approvals).

**Finance governance:** `admin.finance_exceptions`, `admin.reconciliation_periods` (read models;
ledger stays in `finance`).

**Documents:** `admin.document_metadata` (or a platform Files module) with owner, classification,
version, retention class, hash and access log. Do not create a second file store.

**Security:** `admin.security_incidents`, `admin.security_incident_events`.

### 11.4 Relationships and duplication risks

| Risk | Assessment | Recommendation |
|---|---|---|
| A second user/identity table for staff or partners | Would fragment the unified account | Reference `identity.users`; never duplicate |
| A second role table beside `identity.grants` | Two authorities would drift | Keep grants for portal entry/grant type; roles for governance scope; one composition |
| A separate support case and investigation table | Duplicates assignment, timeline, evidence, audit | One case spine with `parent_case_id` |
| A separate document table per module | Duplicates storage, permissions, retention | One metadata model + R2, linked by owner |
| A second audit table | Breaks the single trail | Extend `platform.audit_log` |
| A second ledger | Breaks financial invariants | Reuse `finance` ledger; admin only reads |
| Per-activity admin tables | Explosion and inconsistency | Generic governance + module read models |

### 11.5 Migration requirements

1. Extend audit and identity status columns (additive).
2. Create `admin` tables in dependency order: roles → assignments → staff/departments → partners →
   cases → evidence → approvals → configuration → read models.
3. Add RLS, grants, indexes and comments in the same migration (self-containment).
4. Backfill nothing from production; there is no production data. Seed only synthetic roles and
   permissions in development/staging, never a founder identity.
5. Keep `identity.grants` and current endpoints working during the transition; add the new fields
   before requiring them.
6. Do not rename applied migrations (`F-12`).

---

## 12. Deliverable 10 — Security and risk assessment

### 12.1 Risk register

| ID | Risk | Likelihood | Impact | Severity | Mitigation |
|---|---|---|---|---|---|
| R-01 | Admin capabilities cannot be granted, so governance is either blocked or, if patched hastily, over-granted | High | High | **Critical** | Complete the role/assignment model before adding admin screens; deny-path tests |
| R-02 | Cross-account user read is attempted through account-scoped RLS | High | High | **Critical** | Dedicated `admin.user.read`, scoped admin read model, audit; never loosen account RLS |
| R-03 | A broad "management" role becomes a de facto superuser | Medium | Critical | **High** | Least-privilege role catalogue; scope; dual control; access reviews |
| R-04 | Staff and partner surfaces are merged into control, widening blast radius | Medium | High | **High** | Keep audience separation (D-01); separate bundles and cookies |
| R-05 | Resource scope is enforced only in the UI | Medium | High | **High** | Service-layer resource policy + repository predicate + RLS; tests |
| R-06 | Evidence/documents are exposed through public or long-lived URLs | Medium | Critical | **High** | Private bucket, short-lived signed GET, access audit, no public URL |
| R-07 | Audit is not tamper-evident against a privileged operator | Medium | High | **High** | Hash chain + signed digest export; break-glass controls; retention policy |
| R-08 | Financial metrics are wrong because definitions are mixed | High | High | **High** | One definition per metric; ledger-derived; founder sign-off |
| R-09 | Admin export becomes data exfiltration | Medium | High | **High** | Export capability, row limits, watermark, audit, approval for sensitive exports |
| R-10 | Self-approval or investigator-approver conflict | Medium | High | **High** | Requester ≠ approver; investigator ≠ approver; DB/service checks |
| R-11 | Partner sees another organisation's data | Low | Critical | **High** | Organisation scope from membership; RLS; deny tests |
| R-12 | Security-definer functions bypass RLS too broadly | Medium | High | **Medium** | Narrow functions, pinned `search_path`, explicit actor check, review |
| R-13 | Stale staging API / manual rollout (`F-49`, `F-50`) means controls are not proven on the real artifact | High | Medium | **High** | Close before claiming readiness; evidence |
| R-14 | Audit/retention/legal hold undefined | High | Medium | **Medium** | Founder + counsel decision; no auto-purge |
| R-15 | Admin read endpoints are unbounded and slow | Medium | Medium | **Medium** | Cursor pagination, indexes, query budgets |
| R-16 | Notification handlers absent, so governance events are silent | High | Medium | **Medium** | Register handlers; delivery attempts; in-app feed |
| R-17 | Department/partner hierarchy creates recursive policy loops | Low | Medium | **Medium** | Materialised scope rows; no recursive policy; test |
| R-18 | Configuration change bypasses approval | Medium | High | **High** | Versioned config + approval + effective date + audit |
| R-19 | Portal ships raw hex / second design system | High | Low | **Low** | Consume `packages/design`; visual regression |
| R-20 | A future activity is hard-coded into admin navigation | Medium | Medium | **Medium** | Registry-driven activity governance |

### 12.2 Security assessment summary

- **Strong:** authentication, session audience isolation, MFA, append-only audit, default-deny
  capability pattern, module boundaries, secret-scanning, build-once release.
- **Weak:** authorization depth (roles, scope, deny, approval), administrative read paths, audit
  completeness, document/evidence controls, configuration governance, financial/verification
  absence, staff/partner isolation not yet implemented.
- **Unknown / open:** retention, legal hold, data residency, audit tamper evidence, export policy,
  partner due diligence standard, investigation authority limits, performance thresholds.

No statement in this section should be read as a certification or a compliance claim.

---

## 13. Deliverable 13 — Documentation and architecture decisions

### 13.1 Documents to update (not duplicate)

| Document | Change | Reason |
|---|---|---|
| `documents/Context/ARCHITECTURE.md` | Add a Control Portal governance subsection under §7/§9.13; extend §10.5 with the role/scope/approval model; add decisions to §16.4 | The architecture owns modules, security boundaries and open decisions |
| `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md` | Add administrative/staff/partner capabilities and resource-scope rules, or add a pointer to the new companion | The matrix is the authority on permissions; it currently covers only six admin scopes |
| `documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md` | Add `admin` schema conventions, scope-based RLS, evidence metadata, audit hash chain, `security definer` decision | The database rules own migrations, grants and RLS |
| `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` | Add dual-control, scope, evidence and admin-read test requirements | The standards own gates and test obligations |
| `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md` | Recognise a cross-phase Control Portal programme and its mapping | The structure owns phase/work-package IDs |
| `documents/Task-Implementation/EP-01/PHASE_OVERVIEW.md` + tracker | Record the P0 defects as findings and link remediation | EP-01 owns the existing control foundation |
| `documents/Engineering-Execution/Engineering-Phase-Plan/` | Create the EP-02 plan when approved, with the CP work packages mapped | EP-02 owns the first governance phase |
| `documents/Context/VISUAL-IDENTITY.md` | Add the admin/control composition rules if new primitives are approved | Visual authority remains the prototype; this document is the written reference |

### 13.2 New document — justified

**`documents/Context/Administrative-Governance-Architecture.md`** (proposed)

- **Why:** the approved architecture defines the four portals and six admin scopes, but not the
  administrative role catalogue, staff/department model, partner organisation model, case spine,
  evidence model, approval model, resource scope, or investigation authority. These are substantial
  enough to need one authoritative document, and too cross-cutting to bury in a phase plan.
- **Responsibility:** define the governance domain, its entities, roles, scopes, lifecycle and
  controls. It references, and does not restate, the activity capabilities, the database mechanics,
  the security standards or the visual identity.
- **Relationship:** subordinate to `VISION.md`, `ARCHITECTURE.md` and the permission matrix for the
  concerns those documents own; authoritative for the governance domain they do not yet cover.
- **Location:** `documents/Context/`.
- **Status:** `[PROPOSED]`, requires founder approval and a recorded revision of the matrix §14
  pointer.

**Do not create** a second architecture document, a second permission matrix, a second database
rules document or a second phase plan.

### 13.3 Architecture decision records to add

| ADR | Decision | Context | Alternatives | Implication |
|---|---|---|---|---|
| ADR-CP-01 | Keep control/staff/partner separation; one governance domain, two operational shells | Approved trust model vs brief's single portal | Merge; widen control; new portal | Preserves blast-radius separation; requires shared services |
| ADR-CP-02 | Hybrid RBAC + ABAC; deny wins; scope intersection | Engine already attribute-based | Pure RBAC; pure ABAC | Adds role/assignment tables and resource policies |
| ADR-CP-03 | `admin` owns roles/assignments; `identity.grants` remains portal grants | Module ownership | Overload grants; new schema | Composition in the capability engine |
| ADR-CP-04 | One case spine with typed cases and parent links | Duplication risk | Separate systems | Shared timeline/evidence/approval |
| ADR-CP-05 | Narrow typed approval service, not a workflow engine | Architecture excludes BPMN | Generic workflow engine | Configurable thresholds, fixed stages |
| ADR-CP-06 | Partner organisation as an admin entity, not a second account | Unified identity | Second account | Organisation scope + representatives |
| ADR-CP-07 | Reuse ledger/R2/outbox/audit; admin adds read models and controls | Financial/file/notification invariants | New subsystems | No duplication |
| ADR-CP-08 | Registry-driven activity governance | Future activities | Hard-coded nav | New activity = registry + read model |
| ADR-CP-09 | Audit hash chain + signed export (timing TBD) | Tamper evidence | Trigger only | Strengthens integrity; retention open |
| ADR-CP-10 | Control shell consumes the shared design system and router | Visual consistency | Bespoke CSS | Removes token duplication |

Each ADR records decision, context, rationale, alternatives, implementation implications, future
considerations and changelog, per the brief.

---

## 14. Deliverable 14 — Implementation readiness report

### 14.1 Ready now

- Identity, sessions, MFA, audience isolation.
- Pure capability engine and the vocabulary pattern.
- Append-only audit and service-layer write pattern.
- Ten-module scaffold and database roles.
- Grant administration (three admin scopes).
- Four bundles, staging topology and release governance.
- Design tokens, app shell and route manifest (slice).

### 14.2 Requires founder decisions

| # | Decision | Blocks |
|---|---|---|
| 1 | D-01 control vs staff vs merged scope | Navigation, trust boundary, session model |
| 2 | D-02 management visibility vs record-level PII | Role catalogue, read models, exports |
| 3 | D-03 role ownership | Schema and capability composition |
| 4 | D-04 one case spine | Case/investigation/evidence schema |
| 5 | D-05 partner organisation model | Partner schema and access |
| 6 | D-06 approval engine shape | Approval schema |
| 7 | D-07 audit retention and tamper evidence | Audit design |
| 8 | Role catalogue and permission mapping | Every admin screen |
| 9 | Staff performance measurement purpose | Workload/reporting |
| 10 | Financial metric definitions, fee/escrow/dispute rules | Finance screens |
| 11 | KYC ladder and verification vendor | Verification screens |
| 12 | Investigation authority limits and sanction approvals | Case workflow |
| 13 | Data retention, legal hold, export policy | Documents, audit, cases |
| 14 | Future activity governance scope | Extensibility |

### 14.3 Requires architectural decisions

- Role/assignment data ownership and composition.
- Resource-scope representation (assignment attributes vs materialised scope rows).
- Admin read-model strategy and `security definer` policy.
- RLS policy style for admin tables (scope columns, indexes, recursion avoidance).
- Audit contract extension and hash-chain design.
- Configuration versioning and rollback.
- Notification handler registration and delivery model.
- Export watermarking and row limits.
- Partner organisation RLS predicate.
- Staff/department hierarchy depth and scope inheritance.

### 14.4 Must be completed before implementation

1. **EP-01 closure or an explicit exception.** `F-49` and `F-50` remain high findings. `EP-01-072`
   is not signed.
2. **P0 remediation** (see the implementation plan): admin role model, correct user read path, audit
   contract, deny-path tests.
3. **Founder decisions** D-01 to D-07 and the role catalogue.
4. **EP-02 entry gates:** funds custody (BD-D01), escrow/dispute (BD-D03), launch configuration
   (BD-D04), KYC ladder (BD-D05), verification vendor. No ledger or verification build before these.
5. **A ratified documentation update** to `ARCHITECTURE.md`, the permission matrix and the standards.
6. **A written phase plan for EP-02** that maps the CP work packages and their evidence.

### 14.5 Not ready / do not build yet

- Full investigation workspace before the case schema and evidence controls are approved.
- Financial dashboards before the ledger and metric definitions exist.
- Verification queue before the lanes and vendor decision.
- Staff performance scoring before its purpose is approved.
- System-health controls that expose infrastructure or secrets.
- Any admin screen for an activity whose module does not exist.

### 14.6 Readiness verdict

**Not ready for full implementation. Ready for a bounded P0 foundation tranche after founder
approval.** The P0 tranche is security and correctness work on the existing foundation; it does not
expand product scope and does not depend on open financial or verification decisions. The broader
portal is correctly sequenced after EP-02's entry gates and the activity phases.

---

## 15. Approval request

This assessment is presented for founder review. Approval is requested for:

1. **D-01:** the recommended "one governance architecture, two operational shells" model.
2. **D-02–D-07:** the recommended positions, or a recorded alternative.
3. **The P0 remediation tranche** in the companion implementation plan.
4. **The new `Administrative-Governance-Architecture.md` document** and the listed amendments.
5. **The CP workstream identifiers** and their mapping to EP-02–EP-05.

No implementation begins until that approval is recorded. No `[OPEN]` item is resolved by this
document. No code, migration, permission, prototype or hosted environment was changed in producing
it.

---

**End of assessment.**
