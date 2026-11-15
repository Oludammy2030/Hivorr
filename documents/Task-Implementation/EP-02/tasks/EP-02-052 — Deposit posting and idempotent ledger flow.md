# EP-02-052 — Deposit posting and idempotent ledger flow

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-02-052` |
| **Task title** | Deposit posting and idempotent ledger flow |
| **Parent phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Priority** | Critical |
| **GOV-09 class** | [FOUNDER] (provisional; confirm at G0) |
| **Execution order** | 28 of 40 |
| **Governing plan** | EP-02 phase plan §10, Stage F |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |

## 2. Objective

Post a matched sandbox deposit to the ledger exactly once, with provider reference, idempotency key and audit.

## 3. Scope

### 3.1 Included

- Post a matched sandbox deposit to the ledger exactly once, with provider reference, idempotency key and audit.
- Matched deposit posting with provider clearing and wallet credit.
- Idempotent replay and mismatch no-op.
- Balanced journal entry and wallet-view reflection.

### 3.2 Excluded

- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Escrow release timing, dispute outcomes, refunds or cancellation policy while BD-D03 is open.
- Fee computation, take-rate application, commission or promoted placement.
- Multi-currency conversion or FX.
- Production deployment or G4.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.
- Escrow release and dispute outcomes.
- Fee computation or marketplace settlement.
- Manual adjustment of a production ledger outside an approved operation.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The task objective and scope in §2–§3 are implemented exactly. | Task document; EP-02 plan §10 |
| R-02 | Approved architecture, security and database rules are respected. | `AGENTS.md`; `ARCHITECTURE.md`; standards; database rules |
| R-03 | Existing modules, services and utilities are inspected and reused; no parallel implementation is introduced. | `AGENTS.md` §3; EES §8.4 |
| R-04 | The service layer remains authoritative and RLS remains defence in depth. | `ARCHITECTURE.md` §10.2; database rules §6.2 |
| R-05 | Relevant tests, including every deny path, are implemented and pass. | Standards §10; EP-02 plan §4 |
| R-06 | No marketplace transaction flow, production deployment or out-of-scope feature is added. | EP-02 plan §5.2 |
| R-07 | The expected outcome is: A matched deposit debits provider clearing and credits the user wallet; a replay posts nothing; a mismatch posts nothing; the journal entry balances; the wallet view reflects the posting; the traceability chain is complete. | EP-02-052 |

## 5. Dependencies

- **Task dependencies:** EP-02-031, EP-02-034, EP-02-051.
- **Phase prerequisite:** `EP-02-001` must record EP-01 G5 and every entry decision before this task is eligible.
- **Global prerequisites:** EP-01 G5; funds-custody register; VFD written scope; KYC ladder; verification vendor; second reviewer.
- **Evidence rule:** a dependency is satisfied only by a linked artefact, not by a status sentence.

## 6. Implementation plan

1. Read this task document, the approved phase plan, the EP-02 entry record and the relevant approved documents.
2. Inspect the ledger, provider port, payout-account and audit paths.
3. Confirm the payer-name ruling and the approved destination model.
4. Implement binding, encryption and account-name enquiry.
5. Implement payer match and deposit posting with idempotency.
6. Implement payout eligibility, approval and execution.
7. Schedule reconciliation and prove the audit traceability chain.
8. Produce the evidence, update this document, update the tracker and write the execution record.

## 7. Existing components and reusability

Inspect before creating. Reuse or extend the following; do not create a parallel implementation:

- `server/src/modules/finance` for ledger, payout and limits.
- `server/src/integrations/vfd` for account enquiry and transfers.
- `server/src/modules/admin/approvals.service.ts` for maker-checker.
- `server/src/modules/platform` for audit, outbox and idempotency.
- EP-01 worker and queue for reconciliation.

The task DoD must record what was inspected and why nothing existing served the need.

## 8. Files and systems affected

Anticipated paths; update this section if implementation reveals more.

- `server/src/modules/finance/**`
- `server/src/integrations/vfd/**`
- `server/src/contracts/schemas.ts` and `server/src/openapi/operations.ts`
- `server/src/worker/**` reconciliation handler
- `tests/finance*.test.ts`, `tests/reconciliation*.test.ts`

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | The expected outcome is achieved: A matched deposit debits provider clearing and credits the user wallet; a replay posts nothing; a mismatch posts nothing; the journal entry balances; the wallet view reflects the posting; the traceability chain is complete. | Linked artefact in the execution record |
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

- Payer match and mismatch tests, including normalisation variants.
- Deposit replay and duplicate-provider-event tests.
- Payout deny tests for unbound, unverified, mismatched and `tier_0`.
- RLS deny tests independent of the service layer.
- Reconciliation seeded-mismatch test.

## 12. Risks and considerations

- A false payer match credits the wrong person.
- A payout bypasses the service gate through a direct write.
- The provider has no reliable reconciliation source.
- The phase entry gate may remain blocked; no implementation may start while `EP-02-001` is blocked.

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `PENDING` |
| **Execution date** | — |
| **Execution record** | — |
| **Blocked by** | `EP-02-001` and the unresolved EP-02 entry gate |
| **Notes** | Task documentation issued; implementation has not started. |

