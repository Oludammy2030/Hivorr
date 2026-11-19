# EP-02 — Phase Execution Tracker
## Trust, Identity & Financial Integrity Engine

| Field | Value |
|---|---|
| **Phase** | `EP-02` |
| **Governing plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 — Trust, Identity & Financial Integrity Engine.md` |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |
| **Tracker updated** | 2026-11-18 |
| **Phase status** | `In build` — partial scope: non-provider finance foundation only |
| **Tasks total** | 40 |
| **Completed** | 11 |
| **In progress** | 0 |
| **Requires review** | 0 |
| **Blocked** | 0 |
| **Pending** | 29 |

> **Partial start.** `EP-02-002` and the finance foundation (`030`–`036`) are eligible. Verification (`010`–`016`) is blocked on the KYC ladder and vendor. VFD adapter and dependent deposit/payout tasks are blocked on written VFD confirmation. Frontend and exit tasks are pending their dependencies.

> **Status rule.** A task moves to `COMPLETED` only when its task-specific DoD is satisfied and validated, and an execution record exists. Existing code is never sufficient on its own. A criterion without an artefact is unmet.

---

## 1. Tracker

| # | Task | Title | Dependencies | Status | Completed | Record |
|---:|---|---|---|---|---|---|
| 1 | `EP-02-001` | Entry gate closure and decision register | EP-01 G5; founder decisions | **COMPLETED** — partial start: EP-01 closed; pooled wallet/escrow model recorded; verification and provider scopes blocked | 2026-11-15 | `execution-records/EP-02-001.md` |
| 2 | `EP-02-002` | Shared contracts, capability inputs and error semantics | EP-02-001; EP-01-003; EP-01-034. | **COMPLETED** — lane/tier/ledger/payout contracts; capability states | 2026-11-15 | `execution-records/EP-02-002.md` |
| 3 | `EP-02-010` | Verification schema, lane registry and constraints | EP-02-002; EP-01-021/022/025. | **PENDING** | — | — |
| 4 | `EP-02-011` | Lane state machines and submission domain | EP-02-010. | **PENDING** | — | — |
| 5 | `EP-02-012` | Evidence storage, scanning and signed access | EP-02-010; EP-01 object-storage interface; R2 provisioning. | **PENDING** | — | — |
| 6 | `EP-02-013` | Verification submission and status API | EP-02-011, EP-02-012; EP-01-011/013. | **PENDING** | — | — |
| 7 | `EP-02-014` | KYC tier model and financial gating inputs | EP-02-010, EP-02-013; entry decision #6. | **PENDING** | — | — |
| 8 | `EP-02-015` | Control review integration and immutable decision record | EP-02-011/012/013/014; CP-016/017/019; `admin.verification` queue. | **PENDING** | — | — |
| 9 | `EP-02-016` | Verification override and dual control | EP-02-015; CP-020 approvals; CP-012 role administration. | **PENDING** | — | — |
| 10 | `EP-02-020` | Taxonomy registry schema and hierarchy domain | EP-02-002; EP-01-021/022/025; G0 ruling on depth. | **COMPLETED** — node/attribute schema, hierarchy triggers, RLS, domain | 2026-11-15 | `execution-records/EP-02-020.md` |
| 11 | `EP-02-021` | Taxonomy administration API, versioning and control UI | EP-02-020; CP-022 configuration; CP-012 roles. | **COMPLETED** — permission-gated API, audit, control screen | 2026-11-15 | `execution-records/EP-02-021.md` |
| 12 | `EP-02-022` | Taxonomy seed data and read contracts | EP-02-020, EP-02-021. | **COMPLETED** — shared read contract, active endpoint, no production seed | 2026-11-15 | `execution-records/EP-02-022.md` |
| 13 | `EP-02-030` | Finance schema, ledger accounts and RLS | EP-02-002; EP-01-021/022/025. | **COMPLETED** — append-only ledger, deferred balance invariant, encryption shape, owner-scoped RLS | 2026-11-18 | `execution-records/EP-02-030.md` |
| 14 | `EP-02-031` | Posting engine, double-entry invariants and property tests | EP-02-030. | **COMPLETED** — pure engine, property tests, transactional write path, in-transaction audit | 2026-11-18 | `execution-records/EP-02-031.md` |
| 15 | `EP-02-032` | Wallet derived views and statement read model | EP-02-031. | **COMPLETED** — security_invoker views, owner-scoped reads, keyset statement | 2026-11-18 | `execution-records/EP-02-032.md` |
| 16 | `EP-02-033` | Escrow account model and state machine | EP-02-031; BD-D03 for transition enablement. | **COMPLETED** — ledger-backed reservations; dispute enabled; release/refund disabled in domain and database | 2026-11-18 | `execution-records/EP-02-033.md` |
| 17 | `EP-02-034` | Money idempotency and provider reference model | EP-02-030, EP-02-031. | **COMPLETED** — claim/replay, account-scoped keys, provider reference replay and linking | 2026-11-18 | `execution-records/EP-02-034.md` |
| 18 | `EP-02-035` | Financial limits, KYC gating and capability enforcement | EP-02-014, EP-02-032, EP-02-034. | **PENDING** | — | — |
| 19 | `EP-02-036` | Dispute case record and evidence linkage | EP-02-030; CP-016, CP-017. | **COMPLETED** — admin-owned typed dispute, procedural statuses, audited evidence access; signed URL pending EP-02-012 | 2026-11-19 | `execution-records/EP-02-036.md` |
| 20 | `EP-02-040` | PaymentProvider port and adapter contract | EP-02-031, EP-02-034. | **PENDING** | — | — |
| 21 | `EP-02-041` | VFD authentication and resilience client | EP-02-040; VFD sandbox credentials. | **PENDING** | — | — |
| 22 | `EP-02-042` | VFD collections adapter | EP-02-041, EP-02-050. | **PENDING** | — | — |
| 23 | `EP-02-043` | VFD payouts adapter | EP-02-041, EP-02-053. | **PENDING** | — | — |
| 24 | `EP-02-044` | VFD webhook intake, raw storage and dedupe | EP-02-042, EP-02-043, EP-02-034; founder approval for the new inbound webhook. | **PENDING** | — | — |
| 25 | `EP-02-045` | VFD sandbox certification and settlement evidence | EP-02-042/043/044. | **PENDING** | — | — |
| 26 | `EP-02-050` | Payout account binding, encryption and name enquiry | EP-02-035, EP-02-040, EP-02-043. | **PENDING** | — | — |
| 27 | `EP-02-051` | Payer-name match rule and manual review path | EP-02-042, EP-02-050; G0 payer-name ruling. | **PENDING** | — | — |
| 28 | `EP-02-052` | Deposit posting and idempotent ledger flow | EP-02-031, EP-02-034, EP-02-051. | **PENDING** | — | — |
| 29 | `EP-02-053` | Payout execution workflow and dual control | EP-02-043, EP-02-050, EP-02-035; CP-020. | **PENDING** | — | — |
| 30 | `EP-02-054` | Payout eligibility gate in service and RLS | EP-02-030, EP-02-050, EP-02-053. | **PENDING** | — | — |
| 31 | `EP-02-055` | Reconciliation job and exception reporting | EP-02-043/044/052/053; worker. | **PENDING** | — | — |
| 32 | `EP-02-056` | Financial audit coverage and traceability | EP-02-015/016/031/052/053/055; EP-01-036; CP-005. | **PENDING** | — | — |
| 33 | `EP-02-060` | Verification centre UI | EP-02-013/015; design system; EP-01-052. | **PENDING** | — | — |
| 34 | `EP-02-061` | Wallet and payout account UI | EP-02-032/035/050; design system. | **PENDING** | — | — |
| 35 | `EP-02-062` | Financial action dialogs and deny-state UX | EP-02-013/050/053; prototype `FinancialActionDialog`. | **PENDING** | — | — |
| 36 | `EP-02-063` | Visual regression and responsive verification | EP-02-060/061/062; EP-01-050. | **PENDING** | — | — |
| 37 | `EP-02-070` | EP-02 E2E suite and staging verification | EP-02-015/016/045/052/053/054/055/060/061; staging deployment. | **PENDING** | — | — |
| 38 | `EP-02-071` | Phase evidence pack and traceability index | Every EP-02 item. | **PENDING** | — | — |
| 39 | `EP-02-072` | Phase security and quality review | EP-02-071; second reviewer; OWASP and standards checklists. | **PENDING** | — | — |
| 40 | `EP-02-073` | G5 phase closure record | EP-02-071, EP-02-072. | **PENDING** | — | — |

---

## 2. Next eligible task

**`EP-02-040` — PaymentProvider port and adapter contract.**

The dispute record is in place; `EP-02-035` remains blocked on the KYC ladder (#6). The provider
port is the next unblocked scope: it is provider-agnostic and testable against a fake provider, and
`EP-02-040` does not need VFD credentials. VFD authentication and every adapter call remain blocked on
written confirmation.

Still open and blocking specific scopes:

1. VFD written API/account confirmation — blocks `040`–`045` and dependent deposit/payout tasks.
2. KYC tier ladder (#6) and verification vendor (#15) — blocks `010`–`016`.
3. Second reviewer / renewed `DEV-003` — required for G2 on verification and finance changes.
4. CP-022 approval workflow — taxonomy writes are permission-gated and audited, not approval-routed.

## 3. Status history

| Date | Task | From | To | Record |
|---|---|---|---|---|
| 2026-11-15 | `EP-02-001` | `PENDING` | `BLOCKED` | `execution-records/EP-02-001.md` |
| 2026-11-15 | `EP-02-001` | `BLOCKED` | `COMPLETED` — partial start | `execution-records/EP-02-001.md` |
| 2026-11-15 | `EP-02-002` | `PENDING` | `COMPLETED` | `execution-records/EP-02-002.md` |
| 2026-11-15 | `EP-02-020` | `PENDING` | `COMPLETED` | `execution-records/EP-02-020.md` |
| 2026-11-15 | `EP-02-021` | `PENDING` | `COMPLETED` | `execution-records/EP-02-021.md` |
| 2026-11-15 | `EP-02-022` | `PENDING` | `COMPLETED` | `execution-records/EP-02-022.md` |
| 2026-11-18 | `EP-02-030` | `PENDING` | `COMPLETED` | `execution-records/EP-02-030.md` |
| 2026-11-18 | `EP-02-031` | `PENDING` | `COMPLETED` | `execution-records/EP-02-031.md` |
| 2026-11-18 | `EP-02-032` | `PENDING` | `COMPLETED` | `execution-records/EP-02-032.md` |
| 2026-11-18 | `EP-02-033` | `PENDING` | `COMPLETED` | `execution-records/EP-02-033.md` |
| 2026-11-18 | `EP-02-034` | `PENDING` | `COMPLETED` | `execution-records/EP-02-034.md` |
| 2026-11-19 | `EP-02-036` | `PENDING` | `COMPLETED` — evidence signing partial | `execution-records/EP-02-036.md` |

---

**Tracker status:** current to 2026-11-18. Every later status change requires a task document, an execution record and this table.
