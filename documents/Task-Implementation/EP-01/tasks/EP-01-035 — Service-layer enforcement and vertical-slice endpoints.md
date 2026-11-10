# EP-01-035 — Service-layer enforcement and vertical-slice endpoints

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-035` |
| **Task title** | Service-layer enforcement and vertical-slice endpoints |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — enforcement path |
| **Execution order** | 22 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage D |
| **Dependencies** | `EP-01-032`, `EP-01-034`, `EP-01-036` |

## 2. Objective

Prove authorised enforcement, not just computation. The activity activation write checks
`activity.activate` inside its transaction; the control audit read checks `admin.audit.read` inside
the read transaction; denials use a stable code. Session read is guarded by a valid session and the
`session.read` capability it computes.

## 3. Scope

### 3.1 Included

- `requireCapability` helper with the stable `FORBIDDEN` code.
- `ProfileService.activate/deactivate` require `activity.activate`/`activity.deactivate` inside the
  unit of work before the write.
- `buildAccessContext` / `loadAccessContext` — the authoritative context from grants and activities.
- `GET /v1/control/audit` — a guarded audit-read probe; capability checked in the same transaction as
  the read.
- `platform.listAuditEntries` — a review-only audit read model.
- Contract, generated client and route coverage.
- Local enforcement tests and HTTP deny/allow integration tests.

### 3.2 Excluded

- The full audit service, retention and read model — `036` (see `F-38`).
- Per-endpoint enforcement for capabilities whose modules do not exist yet.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Enforcement uses the pure capability decision. | `034` |
| R-02 | The check runs inside the same transaction as the write/read. | Plan `035` outcome |
| R-03 | `activity.activate` allows an app session. | Plan `035` |
| R-04 | `admin.audit.read` denies without the grant. | Plan `035` |
| R-05 | Denials use the stable `FORBIDDEN` code. | `011` |
| R-06 | The audit probe returns review fields only. | AFS-API-07 |
| R-07 | No request input widens the capability set. | Rule 4 |
| R-08 | Session read requires a valid session and `session.read`. | Plan `035` |
| R-09 | The endpoint is documented and generated. | `013` |
| R-10 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-032` session | **REQUIRES_REVIEW** |
| `EP-01-034` capability engine | **COMPLETED** |
| `EP-01-036` audit service | **PENDING** — the probe uses the existing append-only table (`F-38`) |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the session, capability and audit paths.
2. Add `requireCapability`.
3. Enforce activity activation/deactivation inside the unit of work.
4. Add the context loader and the guarded audit probe.
5. Add the audit read model and contract.
6. Regenerate and add tests.
7. Run local gates; record the CI-only integration.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| Capability engine | **Reuse** | One decision function |
| `withTransaction` | **Reuse** | Check and write/read share the transaction |
| `ProfileService` | **Extend** | Add the capability check |
| `platform.audit_log` | **Reuse** | Append-only table already exists |
| `platform.appendAudit` | **Reuse** | Audit writes |
| Identity grants/activities | **Reuse** | Context inputs |
| OpenAPI generator | **Reuse** | One operation |

**Must not be duplicated:** a second capability check, a second audit table, or a second audit read
model.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/common/errors.ts` | `requireCapability` |
| `server/src/modules/profile/profile.service.ts` | Checks inside the write transaction |
| `server/src/modules/identity/access.ts` | `buildAccessContext`, `loadAccessContext` |
| `server/src/modules/identity/index.ts` | Public access-context exports |
| `server/src/modules/identity/identity.service.ts` | Uses the shared context builder |
| `server/src/modules/platform/audit.ts`, `index.ts` | Audit read model |
| `server/src/api/activity.controller.ts` | Passes capabilities |
| `server/src/api/audit.controller.ts` | **New** — guarded probe |
| `server/src/app.module.ts` | Controller registration |
| `server/src/contracts/schemas.ts`, `server/src/openapi/operations.ts` | Audit entry and operation |
| `openapi/openapi.json`, `packages/api-client/src/index.ts` | Regenerated |
| `tests/enforcement.test.ts` | **New** |
| `tests/identity-integration.test.ts` | Audit deny/allow |
| `tests/{audience-declaration,openapi-route-coverage}.test.ts` | `AuditController` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Activity activation checks `activity.activate` inside the write transaction. |
| DoD-02 | Deactivation checks `activity.deactivate` similarly. |
| DoD-03 | The audit probe checks `admin.audit.read` inside the read transaction. |
| DoD-04 | Denial is `403 FORBIDDEN`. |
| DoD-05 | The audit probe returns recent review fields only. |
| DoD-06 | No request-shaped field widens the set. |
| DoD-07 | Session read requires a valid session and returns `session.read`. |
| DoD-08 | Contract and client include the audit operation. |
| DoD-09 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-10 | `pnpm test:identity` proves the audit deny and allow branches in CI. |
| DoD-11 | No new dependency, secret or permission. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- An app session activates an activity; the capability check is inside the transaction.
- A control session without `admin.audit.read` receives `403 FORBIDDEN`; after the grant, the same
  request returns recent audit entries.
- The audit response contains id/timestamp/actor/action/target/correlation, not before/after payloads.
- The generated client exposes `listAudit`.
- The session endpoint returns 401 without a valid session and `session.read` in a valid response.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/enforcement.test.ts` |
| T-02 | `pnpm test:identity` — CI database job |
| T-03 | `pnpm openapi:generate`; contract test |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` |
| T-05 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| `036` is pending while `035` depends on it. | The probe uses the existing append-only table; the full audit service remains `036` (`F-38`). |
| The session capability set is computed before the write transaction. | Activity activation re-checks the passed capabilities inside the transaction; it does not query new grants. A revocation race is narrow and the endpoint is not money-moving. |
| The audit probe reads the platform table directly. | It goes through `platform.listAuditEntries`, the module's public interface. |
| Admin roles are not grant scopes. | The probe uses `admin.audit.read`, which is an existing grant. |
| No Postgres locally. | The deny/allow integration runs in CI. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI passes the audit deny/allow branches; `036` completes the audit service |
| **Execution record** | `execution-records/EP-01-035.md` |
