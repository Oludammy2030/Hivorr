# EP-02-002 — Shared contracts, capability inputs and error semantics

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-02-002` |
| **Task title** | Shared contracts, capability inputs and error semantics |
| **Parent phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Priority** | Critical |
| **GOV-09 class** | [REVIEW] (provisional; confirm at G0) |
| **Execution order** | 2 of 40 |
| **Governing plan** | EP-02 phase plan §10, Stage A |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |

## 2. Objective

Define shared types and schemas for lanes, submission states, KYC tiers, evidence references, ledger operations, payout accounts and provider references; extend the capability context with verification and tier inputs.

## 3. Scope

### 3.1 Included

- Define shared types and schemas for lanes, submission states, KYC tiers, evidence references, ledger operations, payout accounts and provider references; extend the capability context with verification and tier inputs.
- Shared types and schemas for lanes, submission states, KYC tiers, evidence references, ledger operations, payout accounts and provider references.
- Capability-context inputs for lane state and KYC tier, without client-supplied authority.
- Stable error codes and validation semantics consumed by the API and clients.

### 3.2 Excluded

- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Escrow release timing, dispute outcomes, refunds or cancellation policy while BD-D03 is open.
- Fee computation, take-rate application, commission or promoted placement.
- Multi-currency conversion or FX.
- Production deployment or G4.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.
- Any verification, financial, provider or frontend implementation.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The task objective and scope in §2–§3 are implemented exactly. | Task document; EP-02 plan §10 |
| R-02 | Approved architecture, security and database rules are respected. | `AGENTS.md`; `ARCHITECTURE.md`; standards; database rules |
| R-03 | Existing modules, services and utilities are inspected and reused; no parallel implementation is introduced. | `AGENTS.md` §3; EES §8.4 |
| R-04 | The service layer remains authoritative and RLS remains defence in depth. | `ARCHITECTURE.md` §10.2; database rules §6.2 |
| R-05 | Relevant tests, including every deny path, are implemented and pass. | Standards §10; EP-02 plan §4 |
| R-06 | No marketplace transaction flow, production deployment or out-of-scope feature is added. | EP-02 plan §5.2 |
| R-07 | The expected outcome is: `@hivorr/shared` exposes lane, tier, ledger and payout contracts; the capability context consumes lane states and tier without trusting the client; allow/deny tests pass for the extended inputs; no marketplace capability is enabled. | EP-02-002 |

## 5. Dependencies

- **Task dependencies:** EP-02-001; EP-01-003; EP-01-034.
- **Phase prerequisite:** `EP-02-001` must record EP-01 G5 and every entry decision before this task is eligible.
- **Global prerequisites:** EP-01 G5; funds-custody register; VFD written scope; KYC ladder; verification vendor; second reviewer.
- **Evidence rule:** a dependency is satisfied only by a linked artefact, not by a status sentence.

## 6. Implementation plan

1. Read this task document, the approved phase plan, the EP-02 entry record and the relevant approved documents.
2. Inspect the EP-01 evidence pack, tracker and G5 record; do not infer closure from commits.
3. Inspect the architecture register, BD-D01/BD-D11 and the permission matrix.
4. Record every open decision with its owner and blocking effect.
5. Define or extend shared contracts without introducing a second vocabulary.
6. Run the governance and traceability gates.
7. Produce the evidence, update this document, update the tracker and write the execution record.

## 7. Existing components and reusability

Inspect before creating. Reuse or extend the following; do not create a parallel implementation:

- `EP-01-ENTRY-RECORD.md` as the entry-record structure.
- `EP-01-PHASE_EXECUTION_TRACKER.md` as the tracker structure.
- `packages/shared/src` for types, schemas and error codes.
- `server/src/domain/capabilities.ts` for capability computation.
- `documents/Context/AGENTS.md` and EES §6.5 for authority.

The task DoD must record what was inspected and why nothing existing served the need.

## 8. Files and systems affected

Anticipated paths; update this section if implementation reveals more.

- `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md`
- `documents/Task-Implementation/EP-02/PHASE_OVERVIEW.md`
- `documents/Task-Implementation/EP-02/PHASE_EXECUTION_TRACKER.md`
- `packages/shared/src/*` when extending contracts
- `server/src/domain/capabilities.ts` when extending inputs

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | The expected outcome is achieved: `@hivorr/shared` exposes lane, tier, ledger and payout contracts; the capability context consumes lane states and tier without trusting the client; allow/deny tests pass for the extended inputs; no marketplace capability is enabled. | Linked artefact in the execution record |
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

- `pnpm docs:check` passes and every task ID traces to the phase plan.
- Contract tests prove shared schemas reject unknown fields.
- Capability allow/deny tests cover every new input.

## 12. Risks and considerations

- EP-01 is not closed, so the phase cannot open.
- An open decision may be silently defaulted.
- A second vocabulary may diverge from the existing shared package.
- The phase entry gate may remain blocked; no implementation may start while `EP-02-001` is blocked.

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `PENDING` |
| **Execution date** | — |
| **Execution record** | — |
| **Blocked by** | `EP-02-001` and the unresolved EP-02 entry gate |
| **Notes** | Task documentation issued; implementation has not started. |

