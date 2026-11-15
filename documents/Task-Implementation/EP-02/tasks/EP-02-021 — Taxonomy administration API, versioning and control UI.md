# EP-02-021 — Taxonomy administration API, versioning and control UI

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-02-021` |
| **Task title** | Taxonomy administration API, versioning and control UI |
| **Parent phase** | `EP-02` — Trust, Identity & Financial Integrity Engine |
| **Priority** | High |
| **GOV-09 class** | [REVIEW] (provisional; confirm at G0) |
| **Execution order** | 11 of 40 |
| **Governing plan** | EP-02 phase plan §10, Stage C |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-02/EP-02-ENTRY-RECORD.md` |

## 2. Objective

Provide admin-configurable taxonomy CRUD with version, effective date, approval and audit, plus the `control.` management surface.

## 3. Scope

### 3.1 Included

- Provide admin-configurable taxonomy CRUD with version, effective date, approval and audit, plus the `control.` management surface.
- Admin taxonomy CRUD with version, effective date and approval.
- `control.` management surface with permission-aware actions.
- Audit and configuration-history integration.

### 3.2 Excluded

- Any Buy, Hire, Errand, Sell, Offer-services or Logistics transaction flow.
- Escrow release timing, dispute outcomes, refunds or cancellation policy while BD-D03 is open.
- Fee computation, take-rate application, commission or promoted placement.
- Multi-currency conversion or FX.
- Production deployment or G4.
- Any edit to `src/app/App.tsx`, `VISUAL-IDENTITY.md`, the permission matrix, the database rules or `ARCHITECTURE.md`.
- Product listings, stores, categories in use, or any market flow.
- A generic EAV store for every entity.
- Production reference data that has not been approved.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The task objective and scope in §2–§3 are implemented exactly. | Task document; EP-02 plan §10 |
| R-02 | Approved architecture, security and database rules are respected. | `AGENTS.md`; `ARCHITECTURE.md`; standards; database rules |
| R-03 | Existing modules, services and utilities are inspected and reused; no parallel implementation is introduced. | `AGENTS.md` §3; EES §8.4 |
| R-04 | The service layer remains authoritative and RLS remains defence in depth. | `ARCHITECTURE.md` §10.2; database rules §6.2 |
| R-05 | Relevant tests, including every deny path, are implemented and pass. | Standards §10; EP-02 plan §4 |
| R-06 | No marketplace transaction flow, production deployment or out-of-scope feature is added. | EP-02 plan §5.2 |
| R-07 | The expected outcome is: An authorised admin adds or edits a node; the change carries a version, effective date and audit record; approval follows the configuration policy; a new vertical requires no code change; the control screen is permission-aware and responsive. | EP-02-021 |

## 5. Dependencies

- **Task dependencies:** EP-02-020; CP-022 configuration; CP-012 roles.
- **Phase prerequisite:** `EP-02-001` must record EP-01 G5 and every entry decision before this task is eligible.
- **Global prerequisites:** EP-01 G5; funds-custody register; VFD written scope; KYC ladder; verification vendor; second reviewer.
- **Evidence rule:** a dependency is satisfied only by a linked artefact, not by a status sentence.

## 6. Implementation plan

1. Read this task document, the approved phase plan, the EP-02 entry record and the relevant approved documents.
2. Inspect `platform` schema ownership and the existing configuration patterns.
3. Confirm the taxonomy depth ruling and the approved node levels.
4. Create the node and attribute-definition schema with constraints and RLS.
5. Implement the domain validation for cycles, orphans and duplicate siblings.
6. Add the admin API, versioning and control surface through the CP configuration path.
7. Publish read contracts and seed only approved structural data.
8. Produce the evidence, update this document, update the tracker and write the execution record.

## 7. Existing components and reusability

Inspect before creating. Reuse or extend the following; do not create a parallel implementation:

- `server/src/modules/platform` for registry and reference-data ownership.
- `server/src/modules/admin` configuration and audit patterns.
- CP-022 configuration versioning and approval.
- `supabase/migrations` for reference-data seeding rules.

The task DoD must record what was inspected and why nothing existing served the need.

## 8. Files and systems affected

Anticipated paths; update this section if implementation reveals more.

- `supabase/migrations/*_platform_taxonomy_*.sql`
- `server/src/modules/platform/taxonomy*`
- `server/src/contracts/schemas.ts` and `server/src/openapi/operations.ts`
- `apps/control/src/**` taxonomy management surface
- `tests/taxonomy*.test.ts`

## 9. Definition of Done

| # | Condition | Evidence required |
|---|---|---|
| DoD-01 | The expected outcome is achieved: An authorised admin adds or edits a node; the change carries a version, effective date and audit record; approval follows the configuration policy; a new vertical requires no code change; the control screen is permission-aware and responsive. | Linked artefact in the execution record |
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

- Hierarchy integrity tests: cycle, orphan, duplicate sibling.
- RLS and grant tests for admin write and public/read-only access.
- Version and effective-date tests.
- Read-contract tests for both taxonomies.

## 12. Risks and considerations

- Taxonomy depth is open in `VISION.md`.
- The registry becomes an EAV platform.
- Unapproved reference data is seeded as if decided.
- The phase entry gate may remain blocked; no implementation may start while `EP-02-001` is blocked.

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `PENDING` |
| **Execution date** | — |
| **Execution record** | — |
| **Blocked by** | `EP-02-001` and the unresolved EP-02 entry gate |
| **Notes** | Task documentation issued; implementation has not started. |

