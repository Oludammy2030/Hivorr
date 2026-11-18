# EP-02 — Phase Overview
## Trust, Identity & Financial Integrity Engine

| Field | Value |
|---|---|
| **Phase ID** | `EP-02` |
| **Phase name** | Trust, Identity & Financial Integrity Engine |
| **Roadmap phase served** | Phase 0 → Phase 1 |
| **Governing plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 — Trust, Identity & Financial Integrity Engine.md` |
| **Phase record root** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/` |
| **Task documentation root** | `documents/Task-Implementation/EP-02/` |
| **Entry record** | `EP-02-ENTRY-RECORD.md` — `PARTIAL START`, 2026-11-15 |
| **Phase status at this overview** | **`In build`** — partial scope: non-provider finance foundation |
| **Total tasks** | **40** (`001`–`073`, per the approved plan §10) |
| **Completed** | 7 (`EP-02-001`, `EP-02-002`, `EP-02-020`, `EP-02-021`, `EP-02-022`, `EP-02-030`, `EP-02-031`) |
| **Blocked** | Verification, VFD adapter and dependent scopes |
| **Pending** | 33 |
| **Closure authority** | Founder, on the architect’s recommendation, through G5 (`EP-02-073`) |

> **Why this file exists.** The approved phase plan defines what EP-02 must achieve. This overview, the tracker and the task documents turn that plan into the execution record required by the development protocol. They do not open the phase.

---

## 1. Phase objectives

EP-02 builds the trust, identity and financial-integrity layer that makes a stranger-to-stranger transaction safe before any marketplace flow exists:

1. Six independent verification lanes, each with its own state machine and decision.
2. Immutable verification decisions and private, audited evidence.
3. KYC tiers that gate financial writes, never dashboard access.
4. A control review capability with scoped admin authority and dual control.
5. Two admin-configurable taxonomies: Profession and Product.
6. A provider-agnostic, append-only, double-entry ledger.
7. Escrow account structure without an invented release policy.
8. Bound payout accounts, payer-name-matched deposits and KYC-driven limits.
9. A VFD adapter behind a provider port, with sandbox certification.
10. Reconciliation and audit evidence for every verification and financial mutation.
11. Verification and wallet surfaces that preserve the prototype’s visual identity.
12. No marketplace transaction flow.

---

## 2. Scope

### 2.1 In scope

- Profiles and verification: six lanes, state machines, submissions, evidence references, KYC tiers and decisions.
- Private evidence storage: pre-signed upload, scanning, signed read and access audit.
- Control review: case/evidence/approval integration, verification queue, overrides and dual control.
- Taxonomy: Profession and Product registries, admin-configurable and versioned.
- Finance: ledger, escrow, payout accounts, limits, disputes, reconciliation and provider references.
- Provider integration: `PaymentProvider` port, VFD authentication, collections, payouts and webhooks.
- Deposits and payouts: payer match, deposit posting, payout eligibility and execution.
- Frontend: verification centre, wallet, payout accounts, financial dialogs and visual regression.
- Staging and evidence: E2E, invariant report, certification, reconciliation report, review and G5.

### 2.2 Out of scope

- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Escrow release timing, dispute outcomes, refunds or cancellation policy while BD-D03 is open.
- Fee computation, take-rate application, commission or promoted placement.
- Multi-currency conversion or FX.
- Production deployment or G4.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.

---

## 3. Functional and technical requirements

### 3.1 Functional

- A test account can submit evidence for each lane and be reviewed in `control.` to `APPROVED` or `REJECTED`.
- Lanes remain independent; one decision never changes another lane.
- KYC tiers gate financial writes and remain independent of activity lanes.
- Taxonomies are administered as data, not code.
- A sandbox deposit is matched by payer name and posted once; a mismatch is rejected.
- A payout to an unbound or unverified account is refused by the service and by RLS.
- Reconciliation produces a report with differences and owners.

### 3.2 Technical

- The service layer is the authoritative policy point; RLS is defence in depth.
- Every new table has RLS, grants, constraints, indexes and comments in one migration.
- Money is `numeric(20,4)` plus currency; no balance column; no update/delete path.
- Every money mutation is idempotent and traceable to a provider reference.
- The VFD adapter is replaceable without touching the domain or ledger.
- Every verification and financial mutation writes audit in the same transaction.
- The prototype remains the visual authority.

---

## 4. Dependencies and prerequisites

### 4.1 Entry gate — partial start, 2026-11-15

| Condition | State | Evidence |
|---|---|---|
| EP-01 G5 signed | **Met** — 2026-11-15 | `EP-01-G5-CLOSURE.md` |
| Funds-custody model recorded | **Met** — pooled collection/settlement, internal wallets, internal escrow | `PAYMENT-WALLET-ESCROW-ARCHITECTURE.md`; `ARCHITECTURE.md` §16.4 #2 |
| VFD written licence-scope confirmation | **Open** — blocks provider tasks | BD-D11; VFD docs |
| KYC tier ladder and limits | **Open** — blocks verification tasks | `ARCHITECTURE.md` §16.4 #6 |
| Verification vendor | **Open** — blocks verification tasks | Architecture register |
| Reviewer capacity / second reviewer | **Open** — blocks G2 on sensitive changes | Standards §13.3 |

### 4.2 Internal dependencies

- EP-01 identity, capability engine, audit, RLS, transaction foundation, worker and staging.
- CP-002/003/005/006/012 and CP-016/017/019/020/022 governance foundations.
- EP-01 design system, visual baseline and generated API client.

### 4.3 External dependencies

- VFD/PSL sandbox access, certification and settlement evidence.
- VFD MFB written licence-scope confirmation.
- Verification vendor, if #15 selects one.
- NIBSS/bank-account name enquiry through VFD.
- Cloudflare R2 private bucket.
- Counsel on custody, KYC/AML applicability and retention.

---

## 5. Task execution sequence

| Order | Task | Title | Dependencies | Status |
|---:|---|---|---|---|
| 1 | `EP-02-001` | Entry gate closure and decision register | EP-01 G5; founder decisions | **COMPLETED** — partial start |
| 2 | `EP-02-002` | Shared contracts, capability inputs and error semantics | EP-02-001; EP-01-003; EP-01-034. | **COMPLETED** — lane/tier/ledger/payout contracts |
| 3 | `EP-02-010` | Verification schema, lane registry and constraints | EP-02-002; EP-01-021/022/025. | **PENDING** |
| 4 | `EP-02-011` | Lane state machines and submission domain | EP-02-010. | **PENDING** |
| 5 | `EP-02-012` | Evidence storage, scanning and signed access | EP-02-010; EP-01 object-storage interface; R2 provisioning. | **PENDING** |
| 6 | `EP-02-013` | Verification submission and status API | EP-02-011, EP-02-012; EP-01-011/013. | **PENDING** |
| 7 | `EP-02-014` | KYC tier model and financial gating inputs | EP-02-010, EP-02-013; entry decision #6. | **PENDING** |
| 8 | `EP-02-015` | Control review integration and immutable decision record | EP-02-011/012/013/014; CP-016/017/019; `admin.verification` queue. | **PENDING** |
| 9 | `EP-02-016` | Verification override and dual control | EP-02-015; CP-020 approvals; CP-012 role administration. | **PENDING** |
| 10 | `EP-02-020` | Taxonomy registry schema and hierarchy domain | EP-02-002; EP-01-021/022/025; G0 ruling on depth. | **COMPLETED** — schema, triggers, RLS, domain |
| 11 | `EP-02-021` | Taxonomy administration API, versioning and control UI | EP-02-020; CP-022 configuration; CP-012 roles. | **COMPLETED** — API, audit, control screen |
| 12 | `EP-02-022` | Taxonomy seed data and read contracts | EP-02-020, EP-02-021. | **COMPLETED** — read contract, active endpoint, no seed |
| 13 | `EP-02-030` | Finance schema, ledger accounts and RLS | EP-02-002; EP-01-021/022/025. | **COMPLETED** — append-only ledger, invariants, encrypted payout shape, RLS |
| 14 | `EP-02-031` | Posting engine, double-entry invariants and property tests | EP-02-030. | **COMPLETED** — pure engine, property tests, audit-backed write path |
| 15 | `EP-02-032` | Wallet derived views and statement read model | EP-02-031. | **PENDING** |
| 16 | `EP-02-033` | Escrow account model and state machine | EP-02-031; BD-D03 for transition enablement. | **PENDING** |
| 17 | `EP-02-034` | Money idempotency and provider reference model | EP-02-030, EP-02-031. | **PENDING** |
| 18 | `EP-02-035` | Financial limits, KYC gating and capability enforcement | EP-02-014, EP-02-032, EP-02-034. | **PENDING** |
| 19 | `EP-02-036` | Dispute case record and evidence linkage | EP-02-030; CP-016, CP-017. | **PENDING** |
| 20 | `EP-02-040` | PaymentProvider port and adapter contract | EP-02-031, EP-02-034. | **PENDING** |
| 21 | `EP-02-041` | VFD authentication and resilience client | EP-02-040; VFD sandbox credentials. | **PENDING** |
| 22 | `EP-02-042` | VFD collections adapter | EP-02-041, EP-02-050. | **PENDING** |
| 23 | `EP-02-043` | VFD payouts adapter | EP-02-041, EP-02-053. | **PENDING** |
| 24 | `EP-02-044` | VFD webhook intake, raw storage and dedupe | EP-02-042, EP-02-043, EP-02-034; founder approval for the new inbound webhook. | **PENDING** |
| 25 | `EP-02-045` | VFD sandbox certification and settlement evidence | EP-02-042/043/044. | **PENDING** |
| 26 | `EP-02-050` | Payout account binding, encryption and name enquiry | EP-02-035, EP-02-040, EP-02-043. | **PENDING** |
| 27 | `EP-02-051` | Payer-name match rule and manual review path | EP-02-042, EP-02-050; G0 payer-name ruling. | **PENDING** |
| 28 | `EP-02-052` | Deposit posting and idempotent ledger flow | EP-02-031, EP-02-034, EP-02-051. | **PENDING** |
| 29 | `EP-02-053` | Payout execution workflow and dual control | EP-02-043, EP-02-050, EP-02-035; CP-020. | **PENDING** |
| 30 | `EP-02-054` | Payout eligibility gate in service and RLS | EP-02-030, EP-02-050, EP-02-053. | **PENDING** |
| 31 | `EP-02-055` | Reconciliation job and exception reporting | EP-02-043/044/052/053; worker. | **PENDING** |
| 32 | `EP-02-056` | Financial audit coverage and traceability | EP-02-015/016/031/052/053/055; EP-01-036; CP-005. | **PENDING** |
| 33 | `EP-02-060` | Verification centre UI | EP-02-013/015; design system; EP-01-052. | **PENDING** |
| 34 | `EP-02-061` | Wallet and payout account UI | EP-02-032/035/050; design system. | **PENDING** |
| 35 | `EP-02-062` | Financial action dialogs and deny-state UX | EP-02-013/050/053; prototype `FinancialActionDialog`. | **PENDING** |
| 36 | `EP-02-063` | Visual regression and responsive verification | EP-02-060/061/062; EP-01-050. | **PENDING** |
| 37 | `EP-02-070` | EP-02 E2E suite and staging verification | EP-02-015/016/045/052/053/054/055/060/061; staging deployment. | **PENDING** |
| 38 | `EP-02-071` | Phase evidence pack and traceability index | Every EP-02 item. | **PENDING** |
| 39 | `EP-02-072` | Phase security and quality review | EP-02-071; second reviewer; OWASP and standards checklists. | **PENDING** |
| 40 | `EP-02-073` | G5 phase closure record | EP-02-071, EP-02-072. | **PENDING** |

---

## 6. Architectural considerations

1. The service layer is authoritative; RLS is a second line, not the model.
2. Default deny applies to every endpoint, lane, table, bucket and provider event.
3. Modules do not read each other’s tables; cross-module reads use a public interface or read model.
4. Migrations are self-contained, forward-only and expand/contract.
5. Audit is written inside the transaction; a post-commit record is not evidence.
6. No balance column and no update/delete path for ledger records.
7. Provider payloads are untrusted and are translated at the adapter boundary.
8. Evidence is referenced, never stored in the database; private reads are signed and audited.
9. Admin authority is orthogonal to activity capability; no self-approval.
10. The prototype is the only visual authority; no new hex, font, size or radius.
11. No marketplace transaction is built in EP-02.
12. A status above `Not started` requires a linked artefact.

---

## 7. Documentation method

- `PHASE_OVERVIEW.md` and `PHASE_EXECUTION_TRACKER.md` cover all 40 tasks.
- Every task has a document in `tasks/` using the standard 13-section format.
- `EP-02-001` is the only executed task; it is `BLOCKED` and records the gate blockers.
- Tasks 002–073 are `PENDING`; no implementation has started.
- Each executed task gets an execution record in `execution-records/`.

### 7.1 Governance finding

- `scripts/check-work-packages.mjs` treated every phase after EP-01 as contiguous, so the approved EP-02 stage-block plan failed `pnpm docs:check`.
- **Resolved 2026-11-15:** EP-02 added to the stage-block scheme; identifiers were not renumbered. `pnpm docs:check` passes with 3 phase plans and 93 allocated identifiers.

---

## 8. Related documentation

- `documents/Context/AGENTS.md`
- `documents/Context/VISION.md`
- `documents/Context/ARCHITECTURE.md`
- `documents/Context/Unified-Account-and-Activity-Permission-Matrix.md`
- `documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md`
- `documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`
- `documents/Context/OWASP_APPLICATION_SECURITY_STANDARD.md`
- `documents/Context/VISUAL-IDENTITY.md`
- `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md`
- `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 — Trust, Identity & Financial Integrity Engine.md`
- `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md`
- `documents/Engineering-Execution/Control-Portal/CONTROL-PORTAL-IMPLEMENTATION-PLAN.md`
- `documents/integrations/vfd/`

---

**Overview status:** current to 2026-11-15. Task statuses change only through the tracker and an execution record.
