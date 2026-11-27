# EP-02-061 — Wallet and payout account UI

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-02-061` |
| **Task title** | Wallet and payout account UI |
| **Parent phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Priority** | High |
| **GOV-09 class** | [REVIEW] (provisional; confirm at G0) |
| **Execution order** | 34 of 40 |
| **Governing plan** | EP-02 phase plan §10, Stage G |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |

## 2. Objective

Build the wallet overview, statement, payout-account list and binding flow using derived figures and server-computed eligibility.

## 3. Scope

### 3.1 Included

- Build the wallet overview, statement, payout-account list and binding flow using derived figures and server-computed eligibility.
- Wallet overview and statement from derived server figures.
- Payout-account list and binding flow.
- `tier_0` explanation instead of a broken form.

### 3.2 Excluded

- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Escrow release timing, dispute outcomes, refunds or cancellation policy while BD-D03 is open.
- Fee computation, take-rate application, commission or promoted placement.
- Multi-currency conversion or FX.
- Production deployment or G4.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.
- Marketplace dashboards or transaction screens.
- New colour, font, size, radius or shadow.
- Client-side financial calculation or authority.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The task objective and scope in §2–§3 are implemented exactly. | Task document; EP-02 plan §10 |
| R-02 | Approved architecture, security and database rules are respected. | `AGENTS.md`; `ARCHITECTURE.md`; standards; database rules |
| R-03 | Existing modules, services and utilities are inspected and reused; no parallel implementation is introduced. | `AGENTS.md` §3; EES §8.4 |
| R-04 | The service layer remains authoritative and RLS remains defence in depth. | `ARCHITECTURE.md` §10.2; database rules §6.2 |
| R-05 | Relevant tests, including every deny path, are implemented and pass. | Standards §10; EP-02 plan §4 |
| R-06 | No marketplace transaction flow, production deployment or out-of-scope feature is added. | EP-02 plan §5.2 |
| R-07 | The expected outcome is: Total, available, pending and withdrawable are server-derived; an empty wallet is coherent; binding shows the resolved/verified state; a `tier_0` account sees the reason, not a broken form; no amount is calculated in the client. | EP-02-061 |

## 5. Dependencies

- **Task dependencies:** EP-02-032/035/050; design system.
- **Phase prerequisite:** `EP-02-001` must record EP-01 G5 and every entry decision before this task is eligible.
- **Global prerequisites:** EP-01 G5; funds-custody register; VFD written scope; KYC ladder; verification vendor; second reviewer.
- **Evidence rule:** a dependency is satisfied only by a linked artefact, not by a status sentence.

## 6. Implementation plan

1. Read this task document, the approved phase plan, the EP-02 entry record and the relevant approved documents.
2. Inspect the prototype screens, design tokens and existing slice primitives.
3. Inspect the generated client and session/capability context.
4. Extract only the primitives the EP-02 screens need.
5. Wire the verification and wallet surfaces to real contracts.
6. Add denial, pending and empty states.
7. Run visual regression at 375 / 768 / 1280.
8. Produce the evidence, update this document, update the tracker and write the execution record.

## 7. Existing components and reusability

Inspect before creating. Reuse or extend the following; do not create a parallel implementation:

- `packages/design` tokens and primitives.
- `packages/api-client` generated client.
- `apps/web` route manifest and session context.
- `src/app/App.tsx` as visual reference only; never edited.
- EP-01 visual baseline and harness.

The task DoD must record what was inspected and why nothing existing served the need.

## 8. Files and systems affected

Anticipated paths; update this section if implementation reveals more.

- `packages/design/src/**`
- `apps/web/src/**`
- `apps/control/src/**` where a control surface is in scope
- `visual/baseline/**`
- `tests/design-parity*`, `tests/slice-parity*`

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | The expected outcome is achieved: Total, available, pending and withdrawable are server-derived; an empty wallet is coherent; binding shows the resolved/verified state; a `tier_0` account sees the reason, not a broken form; no amount is calculated in the client. | Linked artefact in the execution record |
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

- Component tests for status, denial and empty states.
- Playwright visual regression at three widths.
- Keyboard focus and non-colour status checks.
- No-dead-control and route-reachability checks.

## 12. Risks and considerations

- Visual drift from the prototype.
- Client-side financial logic enters a component.
- A screen is added without its deny state.
- The phase entry gate may remain blocked; no implementation may start while `EP-02-001` is blocked.

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `IN PROGRESS` |
| **Execution date** | 2026-11-26 |
| **Execution record** | `execution-records/EP-02-061.md` |
| **Blocked by** | — (founder-authorised increment; open items are listed in the record) |
| **Notes** | A connected wallet screen in the integrated slice covers balances, deposit account, payout accounts, withdrawal and recent activity. A dedicated `tier_0` state, pagination and responsive evidence are deferred. |

