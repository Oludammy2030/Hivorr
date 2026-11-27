# EP-02-015 — Control review integration and immutable decision record

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-02-015` |
| **Task title** | Control review integration and immutable decision record |
| **Parent phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Priority** | Critical |
| **GOV-09 class** | [REVIEW] (provisional; confirm at G0) |
| **Execution order** | 8 of 40 |
| **Governing plan** | EP-02 phase plan §10, Stage B |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |

## 2. Objective

Connect lane submissions to the existing `control.` case spine and verification queue, and make approval/rejection atomically update lane state and KYC tier with an immutable decision record.

## 3. Scope

### 3.1 Included

- Connect lane submissions to the existing `control.` case spine and verification queue, and make approval/rejection atomically update lane state and KYC tier with an immutable decision record.
- Lane submission to `control.` case and queue integration.
- Atomic decision effect on lane state and KYC tier.
- Immutable decision record with actor, reason and evidence references.

### 3.2 Excluded

- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Escrow release timing, dispute outcomes, refunds or cancellation policy while BD-D03 is open.
- Fee computation, take-rate application, commission or promoted placement.
- Multi-currency conversion or FX.
- Production deployment or G4.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.
- Any activity transaction or marketplace flow.
- Escrow release, refund or dispute outcomes.
- Fee computation or multi-currency conversion.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The task objective and scope in §2–§3 are implemented exactly. | Task document; EP-02 plan §10 |
| R-02 | Approved architecture, security and database rules are respected. | `AGENTS.md`; `ARCHITECTURE.md`; standards; database rules |
| R-03 | Existing modules, services and utilities are inspected and reused; no parallel implementation is introduced. | `AGENTS.md` §3; EES §8.4 |
| R-04 | The service layer remains authoritative and RLS remains defence in depth. | `ARCHITECTURE.md` §10.2; database rules §6.2 |
| R-05 | Relevant tests, including every deny path, are implemented and pass. | Standards §10; EP-02 plan §4 |
| R-06 | No marketplace transaction flow, production deployment or out-of-scope feature is added. | EP-02 plan §5.2 |
| R-07 | The expected outcome is: Submission creates a typed verification case; the queue reads lane, subject and evidence count; a decision records actor, timestamp, reason, evidence references and prior/next state; no user action or automated job approves; the decision and lane change commit together. | EP-02-015 |

## 5. Dependencies

- **Task dependencies:** EP-02-011/012/013/014; CP-016/017/019; `admin.verification` queue.
- **Phase prerequisite:** `EP-02-001` must record EP-01 G5 and every entry decision before this task is eligible.
- **Global prerequisites:** EP-01 G5; funds-custody register; VFD written scope; KYC ladder; verification vendor; second reviewer.
- **Evidence rule:** a dependency is satisfied only by a linked artefact, not by a status sentence.

## 6. Implementation plan

1. Read this task document, the approved phase plan, the EP-02 entry record and the relevant approved documents.
2. Inspect EP-01 identity, profile, capability, audit and RLS patterns.
3. Inspect the existing CP case, evidence, verification and approval services.
4. Create or extend the schema and constraints first; no behaviour before the invariant.
5. Implement the pure domain state machine and deny branches.
6. Wire the service, transaction and audit path; then the API contract.
7. Prove allow and deny branches with unit, integration and RLS tests.
8. Produce the evidence, update this document, update the tracker and write the execution record.

## 7. Existing components and reusability

Inspect before creating. Reuse or extend the following; do not create a parallel implementation:

- `server/src/modules/profile` for activity and profile ownership.
- `server/src/modules/admin/verification.service.ts` for the existing queue and decision seam.
- `server/src/modules/admin/evidence.service.ts` for private evidence patterns.
- `server/src/modules/admin/cases.service.ts` and `approvals.service.ts` for the case and approval spine.
- `server/src/modules/platform` for audit, outbox, reference numbers and idempotency.
- `supabase/migrations` for the RLS, grant and self-contained migration pattern.

The task DoD must record what was inspected and why nothing existing served the need.

## 8. Files and systems affected

Anticipated paths; update this section if implementation reveals more.

- `supabase/migrations/*_profile_verification_*.sql`
- `server/src/modules/profile/**`
- `server/src/modules/admin/verification.service.ts`
- `server/src/contracts/schemas.ts` and `server/src/openapi/operations.ts`
- `tests/verification*.test.ts`, `tests/identity-integration.test.ts`
- `tests/db-*` or the migration policy suite

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | The expected outcome is achieved: Submission creates a typed verification case; the queue reads lane, subject and evidence count; a decision records actor, timestamp, reason, evidence references and prior/next state; no user action or automated job approves; the decision and lane change commit together. | Linked artefact in the execution record |
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

- Unit tests for every lane transition and every invalid transition.
- Integration tests for submission, freeze, resubmission and decision.
- RLS allow and deny tests for lane, evidence and decision tables.
- E2E review flow through `control.` once the CP surface is available.
- Evidence access test: unsigned denial, signed read, audit record.

## 12. Risks and considerations

- Lane semantics may collapse into one account status.
- Evidence may leak through a public URL or a log.
- The control-portal dependency may become circular.
- The phase entry gate may remain blocked; no implementation may start while `EP-02-001` is blocked.

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `COMPLETED` |
| **Execution date** | 2026-11-27 |
| **Execution record** | `execution-records/EP-02-015.md` |
| **Blocked by** | — |
| **Notes** | A submitted lane opens the existing review case and queue; the reviewer decision moves the lane, the KYC tier and the immutable decision record in one transaction, and a subject cannot approve. Evidence previews wait for the signed read in `EP-02-012`. |

