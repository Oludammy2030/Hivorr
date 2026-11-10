# EP-01-033 — Activity registry and activation state machine

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-033` |
| **Task title** | Activity registry and activation state machine |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | High |
| **Class** | `[REVIEW]` — activity lifecycle |
| **Execution order** | 20 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage D |
| **Dependencies** | `EP-01-024`, `EP-01-030` |

## 2. Objective

Implement the six-activity registry and activation lifecycle. Any of the six activates in any order;
activation is idempotent; deactivation sets `INACTIVE` and retains the row and its history. Invalid
transitions are rejected in the pure domain and by a database trigger. Activation is not gated by
verification.

## 3. Scope

### 3.1 Included

- `profile/domain/activation.ts` — persisted states and the transition table.
- `20261110000100_profile_alter_activation_transitions.sql` — database trigger backstop.
- `ProfileService` — list, activate, deactivate, audit.
- Composition controller `server/src/api/activity.controller.ts`:
  - `GET /v1/activities`
  - `POST /v1/activities/{id}/activate`
  - `POST /v1/activities/{id}/deactivate`
- Contract schemas and generated client for the three operations.
- Domain tests and integration tests for all six, idempotency, retained history and trigger refusal.

### 3.2 Excluded

- Capability registry and deny reasons — `034`.
- Verification lanes and gating — activation is deliberately not gated.
- Admin restriction/suspension commands — `036`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Exactly the six shared activity IDs are accepted. | Matrix §5 |
| R-02 | Any order, any combination, no exclusivity. | Matrix §5.4 |
| R-03 | Activating twice is a no-op, not an error or a duplicate. | Matrix §5.2 |
| R-04 | Deactivation sets `INACTIVE` and retains the row. | Matrix §7 |
| R-05 | The transition table is enforced in the domain and by a trigger. | Plan `033` outcome |
| R-06 | Activation is not gated by verification. | Matrix §5.3 |
| R-07 | Only the app audience activates activities. | Matrix capabilities |
| R-08 | Activation and deactivation are audited. | `036` precondition |
| R-09 | The six states survive in the session view. | `032` |
| R-10 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-024` profile table | **REQUIRES_REVIEW** — activation rows and RLS |
| `EP-01-030` domain | **REQUIRES_REVIEW** — module layering |
| `EP-01-032` session view | **REQUIRES_REVIEW** — activities in `/v1/session` |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the activation table, RLS policies and matrix states.
2. Add the pure transition table.
3. Add the database trigger.
4. Add `ProfileService` with audit and idempotent writes.
5. Add the composition controller and contract operations.
6. Regenerate OpenAPI and the client.
7. Add domain and integration tests; run local gates.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `profile.activity_activations` | **Reuse** | Unique `(account, activity)`, state check, RLS |
| Shared `ACTIVITY_IDS` | **Reuse** | One vocabulary |
| `withTransaction` | **Reuse** | Activation is a unit of work with context |
| `appendAudit` | **Reuse** | One audit path |
| `ProfileService` module | **Extend** | The activity endpoints already use the profile module |
| Session view | **Reuse** | Reads non-INACTIVE rows through the profile interface |
| OpenAPI generator | **Reuse** | Three additional operations |

**Must not be duplicated:** a second activity list, a second activation table, a second state set, or
a second session-activity query.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/modules/profile/domain/activation.ts` | **New** — transition table |
| `server/src/modules/profile/profile.service.ts` | **New** — list/activate/deactivate |
| `server/src/modules/profile/index.ts` | Public service export |
| `server/src/api/activity.controller.ts` | **New** — composition endpoints |
| `server/src/app.module.ts` | Controller/service registration |
| `supabase/migrations/20261110000100_profile_alter_activation_transitions.sql` | **New** — trigger |
| `server/src/contracts/schemas.ts`, `server/src/openapi/operations.ts` | Activity view and three operations |
| `openapi/openapi.json`, `packages/api-client/src/index.ts` | Regenerated |
| `tests/activation-domain.test.ts` | **New** |
| `tests/identity-integration.test.ts` | Activation lifecycle and trigger tests |
| `tests/{audience-declaration,openapi-route-coverage}.test.ts` | Controller registration |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | All six activities activate in any order. |
| DoD-02 | A duplicate activation is idempotent. |
| DoD-03 | Deactivation sets `INACTIVE` and keeps the row. |
| DoD-04 | The session view includes active states and omits `INACTIVE`. |
| DoD-05 | Invalid transitions are rejected by the domain and the trigger. |
| DoD-06 | A new row cannot start `RESTRICTED` or `SUSPENDED`. |
| DoD-07 | Activation succeeds without any verification record. |
| DoD-08 | Only the app audience can call the endpoints. |
| DoD-09 | Activation and deactivation are audited. |
| DoD-10 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-11 | `pnpm test:identity` passes the activation lifecycle in CI. |
| DoD-12 | No new dependency, secret or permission. |
| DoD-13 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- Activating each of the six returns `ACTIVE`; a duplicate returns `ACTIVE` without a second row.
- `GET /v1/activities` returns six entries; a missing row is `INACTIVE`.
- Deactivating one returns `INACTIVE`, keeps the row, and removes it from `/v1/session`.
- `market.discover` returns 400.
- `UPDATE ... INACTIVE -> SUSPENDED` and an initial `RESTRICTED` insert fail with `23514`.
- The generated client exposes list/activate/deactivate.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/activation-domain.test.ts` |
| T-02 | `pnpm test:identity` — CI database job |
| T-03 | `pnpm lint:migrations`, `pnpm test:gates` |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-05 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The matrix names the four states but not a transition table. | The adopted table is minimal and recorded as `F-36` for ratification. |
| Domain and trigger could disagree. | The domain test pins the table; the DB integration test proves the trigger matches. |
| Deactivation while obligations are open. | The matrix revision permits it and keeps obligations actionable; no open-obligation check exists yet. |
| A composition controller outside `modules/` is unusual. | It breaks the identity ↔ profile cycle; both modules remain independent. |
| Activation without verification is intentional. | The expected outcome says activation is not gated; writes remain gated by later capability checks. |
| No Postgres locally. | Trigger and lifecycle tests run in CI. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI passes the activation lifecycle and trigger tests; `F-36` is ratified |
| **Execution record** | `execution-records/EP-01-033.md` |
