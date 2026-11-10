# EP-01-032 — Session lifecycle, audiences and session endpoint

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-032` |
| **Task title** | Session lifecycle, audiences and session endpoint |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — session transport and audience isolation |
| **Execution order** | 19 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage D |
| **Dependencies** | `EP-01-031` |

## 2. Objective

Issue host-only audience cookies, rotate access and refresh tokens, detect refresh reuse, support
device sessions and revocation, and return a current-session view with the account, active activities
and presentation-only capabilities. `GET /v1/session` is the read surface.

## 3. Scope

### 3.1 Included

- Extend `getSession` to return account, active activities and presentation-only capabilities.
- Move the session endpoint from `/v1/auth/session` to `/v1/session` via a dedicated controller.
- Detect a suspended/closed user or account on session read and refresh; revoke the user's sessions
  server-side and return 401.
- Add `currentSessionResponse` to the contract and regenerate the OpenAPI document and client.
- Expose `listActiveActivities` as the profile module's public interface, so identity does not read
  the profile schema directly.
- Integration tests for the session view and suspension revocation.

### 3.2 Excluded

- The full capability registry and deny reasons — `034`. The response is presentation-only and uses
  the existing pure computation.
- An admin suspension command that revokes immediately — `036`. Detection is currently on the next
  session read/refresh.
- Activity activation endpoints — `033`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Sign-in issues a `__Host-` session cookie for the correct audience. | Plan `032` |
| R-02 | A session for another audience or environment is rejected. | AUT-12 |
| R-03 | Refresh rotation and reuse detection revoke the family. | Plan `032` |
| R-04 | Sign-out revokes the session server-side. | Plan `032` |
| R-05 | A suspended/closed user or account is rejected and its sessions revoked. | Plan `032` |
| R-06 | `GET /v1/session` returns account, active activities and capabilities. | Plan `032` outcome |
| R-07 | Capabilities are presentation-only; authority stays server-side. | Architecture §9.8 |
| R-08 | Identity reads profile activities through the profile module interface. | `012` boundary rule |
| R-09 | The endpoint is documented and generated. | `013` |
| R-10 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-031` recovery | **REQUIRES_REVIEW** — session creation and reset revocation |
| `EP-01-024` profile schema | **REQUIRES_REVIEW** — activity rows |
| `EP-01-025` RLS | **REQUIRES_REVIEW** — own-row policies |
| `EP-01-013` contract | **REQUIRES_REVIEW** — client regeneration |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the session policy, lookup functions and `getSession`.
2. Add `CurrentSession` and the account/activities/capabilities queries.
3. Detect suspended/closed identity on read and refresh; revoke sessions.
4. Add `SessionController` at `/v1/session`; remove the old route.
5. Add the profile module interface for active activities.
6. Update the contract, regenerate, and update route coverage.
7. Add integration tests; run local gates.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `sessionPolicy`, cookie builders | **Reuse** | Host-only cookies and per-audience lifetimes already correct |
| `find_session_by_access`, `find_refresh_token` | **Reuse** | Pre-auth lookups already exist |
| `createSession`, refresh rotation | **Reuse** | Rotation and reuse detection already implemented |
| `computeCapabilities` | **Reuse** | Presentation-only computation |
| `identity.grants`, accounts, users | **Reuse** | Queried under the session's RLS context |
| `profile.activity_activations` | **Wrap in the profile module** | Identity must not read the profile schema directly |
| OpenAPI generator | **Reuse** | One changed response and one moved path |

**Must not be duplicated:** a second session table, a second cookie policy, a second lookup function,
or a second capability computation.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/modules/identity/identity.service.ts` | `CurrentSession`, suspension checks, activity/capability reads |
| `server/src/modules/identity/session.controller.ts` | **New** — `/v1/session` |
| `server/src/modules/identity/identity.controller.ts` | Remove the old session route |
| `server/src/modules/profile/activities.ts`, `index.ts` | **New public interface** |
| `server/src/app.module.ts` | Register `SessionController` |
| `server/src/contracts/schemas.ts` | `currentSessionResponse` |
| `server/src/openapi/operations.ts` | Session path and response |
| `openapi/openapi.json`, `packages/api-client/src/index.ts` | Regenerated |
| `tests/identity-integration.test.ts` | Path updates and session-view tests |
| `tests/{audience-declaration,openapi-route-coverage}.test.ts` | `SessionController` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | `/v1/session` returns account, active activities and capabilities. |
| DoD-02 | Inactive activities are omitted. |
| DoD-03 | Capabilities include only the current environment's active grants. |
| DoD-04 | A suspended user/account is rejected and all sessions are revoked. |
| DoD-05 | Refresh rejects a suspended identity and revokes sessions. |
| DoD-06 | The old `/v1/auth/session` route is removed. |
| DoD-07 | Identity reads activities through `profile/index.ts`. |
| DoD-08 | The OpenAPI document and client include the new response. |
| DoD-09 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-10 | `pnpm test:identity` passes the session tests in CI. |
| DoD-11 | No new dependency, secret or permission. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- A fresh app session returns `account`, `activities: []` and at least `session.read` and
  `activity.activate`.
- After an activation row is inserted, the session view includes it with its state.
- Setting the user to `suspended` makes the next read return 401 and leaves zero unrevoked sessions.
- Refresh for the suspended user returns 401 and revokes the family.
- The generated client's `session()` returns the extended type; the old path is absent.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/openapi-contract.test.ts tests/api-client.test.ts` |
| T-02 | `pnpm test:identity` — CI database job |
| T-03 | `pnpm test:gates` |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-05 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Suspension revocation is discovered on next use, not at the moment of suspension. | Recorded as `F-35`; `036` adds the admin action that revokes immediately. |
| Capabilities are presentation-only and do not yet encode denied reasons. | `034` owns the registry and deny reasons; authority stays in the service. |
| Changing the path breaks an existing client. | The UI is not wired yet; the generated client and tests are updated together. |
| The session view adds three queries to every read. | Indexed account/user/activity/grant lookups; `last_seen` already writes. |
| Identity could read the profile schema directly. | The boundary linter caught it; the public profile interface fixes it. |
| No Postgres locally. | Integration tests run in CI. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI passes the session-view and suspension tests; `036` revokes immediately on suspension |
| **Execution record** | `execution-records/EP-01-032.md` |
