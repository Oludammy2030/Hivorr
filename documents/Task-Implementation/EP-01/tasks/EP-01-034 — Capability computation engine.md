# EP-01-034 — Capability computation engine

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-034` |
| **Task title** | Capability computation engine |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — authoritative authorisation model |
| **Execution order** | 21 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage D |
| **Dependencies** | `EP-01-033` |

## 2. Objective

Replace ad-hoc capability conditions with one pure, deterministic table over the full permission
matrix. Every capability has a rule and a stable deny reason. Unknown capabilities deny. Capabilities
that need an activity, a verification lane, KYC, an admin role or a payout account are registered
now and deny until the owning phase supplies the input. No request input can widen the set.

## 3. Scope

### 3.1 Included

- Expand `CAPABILITY_IDS` in `@hivorr/shared` to the full matrix (53 identifiers).
- `CAPABILITY_RULES` in `server/src/domain/capabilities.ts`: audience, activity, verification, KYC,
  grant, admin role, membership, business state and payout-account requirements.
- `evaluateCapability`, `computeCapabilities`, `can`; stable `CAPABILITY_DENY_REASONS`.
- Typed `AccessContext` inputs for activities, verification lanes, KYC tier, admin roles, membership,
  business approval and payout account.
- Table-driven tests covering every capability's allow branch and every requirement's deny branch.
- Session view passes active activities into the computation.

### 3.2 Excluded

- Enforcement in each endpoint — `035`. This task computes; it does not change the guarded routes.
- Verification and KYC storage — `024`/later phases. The engine accepts the inputs when supplied.
- The KYC ladder beyond `tier_1` — the matrix leaves it open; the engine models `tier_0` vs
  `tier_1` and above (`F-37`).
- Admin role management — `036`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The computation is pure and deterministic. | Plan `034` |
| R-02 | Every shared capability has exactly one rule. | Matrix §9.3 |
| R-03 | Every requirement has a stable deny reason. | Plan `034` outcome |
| R-04 | Unknown capabilities deny. | Plan `034` outcome |
| R-05 | Missing activity/verification/KYC/admin/member/payout input denies. | Matrix §9.3 |
| R-06 | Supplying the input allows the capability. | Plan `034` outcome |
| R-07 | No request-shaped field widens the set. | Rule 4; matrix §11 |
| R-08 | The session view includes activity-derived capabilities. | `032` |
| R-09 | Shared IDs remain the single vocabulary. | `003` |
| R-10 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-033` activities | **REQUIRES_REVIEW** — activation states feed the context |
| `EP-01-030` domain | **REQUIRES_REVIEW** — module layering |
| Shared contract | Existing; one list expanded |
| CI | No database needed for this task |

## 6. Implementation plan

1. Read the matrix §9.3 and the current computation.
2. Expand the shared capability list.
3. Define the rule table and typed context.
4. Implement evaluation and deny reasons.
5. Pass activities from the session view.
6. Add table-driven tests.
7. Run local gates and regenerate the contract enum.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `CAPABILITY_IDS` | **Expand** | One vocabulary for API and clients |
| `computeCapabilities` | **Replace internals** | Keep the call sites; one table drives it |
| `can` | **Keep** | Now delegates to the same evaluation |
| Session view | **Reuse** | Already reads grants and activities |
| Grants and activities | **Reuse** | Inputs to the context |
| OpenAPI enum | **Regenerate** | The shared list changed |

**Must not be duplicated:** a second capability list, a second deny-reason set, or a per-endpoint
capability condition.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `packages/shared/src/capabilities.ts` | Full 53-ID matrix |
| `server/src/domain/capabilities.ts` | Rule table, evaluation, deny reasons |
| `server/src/modules/identity/identity.service.ts` | Pass active activities |
| `tests/capability-registry.test.ts` | **New** — table-driven allow/deny |
| `tests/workspace-contracts.test.ts` | Full list, count and uniqueness |
| `tests/capabilities.test.ts` | Reused; existing outcomes hold |
| `openapi/openapi.json`, `packages/api-client/src/index.ts` | Regenerated capability enum |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No schema, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Every shared capability has a rule; no extras. |
| DoD-02 | Every capability evaluates allowed with all inputs supplied. |
| DoD-03 | Every requirement's removal denies the capability. |
| DoD-04 | Unknown capability returns `UNKNOWN_CAPABILITY`. |
| DoD-05 | Deny reasons are stable and unique. |
| DoD-06 | The session view passes active activities. |
| DoD-07 | Request-shaped fields cannot widen the set. |
| DoD-08 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-09 | No new dependency, secret or permission. |
| DoD-10 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- `CAPABILITY_IDS` contains 53 unique identifiers.
- The rule table keys equal the shared list.
- The table-driven test passes for all 53 allow branches and every deny variant.
- A main session with `market.buy` active gains `market.cart.manage` and still denies
  `market.product.publish` without a seller lane.
- A control session without `admin.audit.read` denies that capability; with the grant it allows.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/capability-registry.test.ts tests/capabilities.test.ts` |
| T-02 | `pnpm test -- tests/workspace-contracts.test.ts` |
| T-03 | `pnpm openapi:generate`; contract test |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` |
| T-05 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The matrix gives requirements, not a predicate order. | The order is explicit and tested; deny reasons are stable. |
| The KYC ladder is open. | `tier_0` vs `tier_1` only; recorded as `F-37`. |
| Expanding the shared list changes the contract. | The client enum regenerates; no endpoint response shape changes. |
| Verification/KYC inputs are not yet stored. | Context fields are optional; capabilities deny until a later phase supplies them. |
| Admin roles are not grant scopes. | A separate `adminRoles` input keeps the grant table unchanged. |
| A rule could disagree with the matrix. | The rule table mirrors §9.3; tests pin every branch. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `COMPLETED` |
| **Started** | 2026-11-09 |
| **Completed** | 2026-11-09 |
| **Execution record** | `execution-records/EP-01-034.md` |
