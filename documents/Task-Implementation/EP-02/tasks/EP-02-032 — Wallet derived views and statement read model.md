# EP-02-032 — Wallet derived views and statement read model

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-02-032` |
| **Task title** | Wallet derived views and statement read model |
| **Parent phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Priority** | High |
| **GOV-09 class** | [FOUNDER] (provisional; confirm at G0) |
| **Execution order** | 15 of 40 |
| **Governing plan** | EP-02 phase plan §10, Stage D |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |

## 2. Objective

Provide derived wallet figures — total, available, pending, withdrawable — and a ledger-backed statement read model per account.

## 3. Scope

### 3.1 Included

- Provide derived wallet figures — total, available, pending, withdrawable — and a ledger-backed statement read model per account.
- Derived wallet figures: total, available, pending and withdrawable.
- Ledger-backed statement read model with activity attribution where present.
- Owner-scoped read access and RLS coverage.

### 3.2 Excluded

- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Escrow release timing, dispute outcomes, refunds or cancellation policy while BD-D03 is open.
- Fee computation, take-rate application, commission or promoted placement.
- Multi-currency conversion or FX.
- Production deployment or G4.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.
- Fee computation, splits, refunds or release policy.
- Marketplace transaction postings.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The task objective and scope in §2–§3 are implemented exactly. | Task document; EP-02 plan §10 |
| R-02 | Approved architecture, security and database rules are respected. | `AGENTS.md`; `ARCHITECTURE.md`; standards; database rules |
| R-03 | Existing modules, services and utilities are inspected and reused; no parallel implementation is introduced. | `AGENTS.md` §3; EES §8.4 |
| R-04 | The service layer remains authoritative and RLS remains defence in depth. | `ARCHITECTURE.md` §10.2; database rules §6.2 |
| R-05 | Relevant tests, including every deny path, are implemented and pass. | Standards §10; EP-02 plan §4 |
| R-06 | No marketplace transaction flow, production deployment or out-of-scope feature is added. | EP-02 plan §5.2 |
| R-07 | The expected outcome is: Views reconcile to the underlying postings; an empty wallet reads zero; statement rows include activity attribution where present; no client can mutate a balance; read access is owner-scoped and RLS-tested. | EP-02-032 |

## 5. Dependencies

- **Task dependencies:** EP-02-031.
- **Phase prerequisite:** `EP-02-001` must record EP-01 G5 and every entry decision before this task is eligible.
- **Global prerequisites:** EP-01 G5; funds-custody register; VFD written scope; KYC ladder; verification vendor; second reviewer.
- **Evidence rule:** a dependency is satisfied only by a linked artefact, not by a status sentence.

## 6. Implementation plan

1. Read this task document, the approved phase plan, the EP-02 entry record and the relevant approved documents.
2. Inspect EP-01 database roles, RLS and transaction foundation.
3. Inspect the approved ledger model in `ARCHITECTURE.md` §9.10 and database rules §12.9.
4. Create the schema and constraints; no service before the invariant.
5. Implement the pure posting engine and property-based tests.
6. Add wallet views, escrow, idempotency, limits and dispute records.
7. Wire the service and API contract; prove allow and deny paths.
8. Produce the evidence, update this document, update the tracker and write the execution record.

## 7. Existing components and reusability

Inspect before creating. Reuse or extend the following; do not create a parallel implementation:

- `server/src/db/database.service.ts` for transactions and context.
- EP-01 RLS, role and migration patterns.
- `server/src/modules/platform` for idempotency and reference numbers.
- `server/src/modules/finance` as the module boundary.
- `ARCHITECTURE.md` §9.10 for the ledger shape.

The task DoD must record what was inspected and why nothing existing served the need.

## 8. Files and systems affected

Anticipated paths; update this section if implementation reveals more.

- `supabase/migrations/*_finance_*.sql`
- `server/src/modules/finance/**`
- `server/src/contracts/schemas.ts` and `server/src/openapi/operations.ts`
- `tests/ledger*.test.ts`, `tests/finance*.test.ts`
- `tests/db-*` policy suite

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | The expected outcome is achieved: Views reconcile to the underlying postings; an empty wallet reads zero; statement rows include activity attribution where present; no client can mutate a balance; read access is owner-scoped and RLS-tested. | Linked artefact in the execution record |
| DoD-02 | Every dependency is satisfied or explicitly recorded as a blocker | Dependency table |
| DoD-03 | `pnpm typecheck`, `pnpm lint`, `pnpm test` and the relevant database/contract gates pass | Command output |
| DoD-04 | Every new allow path has a deny test where the task touches verification, finance, evidence or admin authority | Test names and results |
| DoD-05 | The audit-readiness impact note is recorded where the task touches identity, money, personal data or a trust boundary | Impact note |
| DoD-06 | No parallel implementation, duplicate vocabulary or unapproved dependency is introduced | Reuse check |
| DoD-07 | Task document, tracker and execution record are current | Links |
| DoD-08 | No production code or feature outside EP-02 scope is added | Diff review |

## 10. Acceptance criteria

- The behaviour described in the objective is observable on staging or in an automated test.
- A reviewer who did not write the change can inspect the evidence and reach the same conclusion.
- The deny path is proven, not asserted.
- No marketplace transaction flow is added.
- The change remains inside the approved phase scope.

## 11. Testing and validation

Planned tests; no run is claimed until the execution record records the result.

- Property-based balance tests for every entry shape.
- Append-only and reversal tests.
- Idempotency replay tests.
- RLS allow and deny tests for ledger, payout and dispute tables.
- Derived-balance reconciliation tests.

## 12. Risks and considerations

- A ledger defect is inherited by every later phase.
- An invented fee or release rule enters the code.
- A balance column or update path is introduced.
- The phase entry gate may remain blocked; no implementation may start while `EP-02-001` is blocked.

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `PENDING` |
| **Execution date** | — |
| **Execution record** | — |
| **Blocked by** | `EP-02-001` and the unresolved EP-02 entry gate |
| **Notes** | Task documentation issued; implementation has not started. |

