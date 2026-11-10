# EP-01-042 — Authentication abuse controls

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-042` |
| **Task title** | Authentication abuse controls |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | High |
| **Class** | `[REVIEW]` — abuse resistance |
| **Execution order** | 25 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage E |
| **Dependencies** | `EP-01-032` |

## 2. Objective

Rate-limit sign-in, password reset and OTP attempts per identifier and per IP; return `429` with
`Retry-After`; lock an account after the configured threshold; write an audit record for every
privileged sign-in. Limits are configurable per environment.

## 3. Scope

### 3.1 Included

- `FixedWindowRateLimiter` with identifier and IP buckets.
- Config: window, identifier max, IP max, lockout attempts and lockout duration.
- Sign-in, password-reset and OTP limits.
- Lockout thresholds read from config; `Retry-After` on lockout and limiter denials.
- `ApiError` headers; the filter sets `Retry-After`.
- `identity.privileged_sign_in` audit for control/staff/partner sessions, with the audit row's IP.
- Unit tests and HTTP integration tests.

### 3.2 Excluded

- A distributed rate-limit store (Redis/Postgres). The limiter is per process; recorded as `F-41`.
- CAPTCHA, IP reputation, device fingerprinting and geo-velocity checks.
- A new-location flag based on history; every privileged sign-in is audited with its IP (`F-42`).
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Sign-in is limited per identifier and per IP. | Plan `042` |
| R-02 | Password-reset requests are limited per identifier and IP. | Plan `042` |
| R-03 | OTP verification is limited per challenge/token and IP. | Plan `042` |
| R-04 | A denial returns `429` with `Retry-After`. | Plan `042` outcome |
| R-05 | Account lockout uses configurable attempts and duration. | Plan `042` outcome |
| R-06 | A privileged sign-in writes an audit record. | Plan `042` outcome |
| R-07 | Limits are configurable per environment. | Plan `042` outcome |
| R-08 | The limiter fails closed on denial and is bounded in memory. | Abuse control |
| R-09 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-032` session | **REQUIRES_REVIEW** — sign-in and privileged sessions |
| `EP-01-031` recovery | **REQUIRES_REVIEW** — reset request |
| `EP-01-036` audit | **REQUIRES_REVIEW** — privileged event |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the sign-in, reset and MFA paths and the config schema.
2. Add the fixed-window limiter.
3. Add config keys with environment defaults.
4. Apply limits and `Retry-After` in the service.
5. Make the lockout thresholds configurable.
6. Add the privileged sign-in audit.
7. Add unit and integration tests; run local gates.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `failed_attempts` / `locked_until` | **Reuse** | The credential lockout already exists |
| `identity.sign_in` audit | **Reuse** | Add a privileged sibling event |
| `ApiError` filter | **Extend** | Set `Retry-After` headers |
| Config schema | **Extend** | Per-environment limits |
| `MFA_MAX_ATTEMPTS` | **Reuse** | Per-challenge ceiling remains |
| Correlation/logger | **Reuse** | No new logging path |

**Must not be duplicated:** a second lockout counter, a second rate-limit store, or a second sign-in
audit path.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/common/rate-limiter.ts` | **New** |
| `server/src/common/errors.ts` | `rateLimited` + headers |
| `server/src/common/api-error.filter.ts` | Set error headers |
| `server/src/config.ts` | Auth abuse settings |
| `server/src/modules/identity/identity.service.ts` | Limits, lockout config, privileged audit |
| `.env.example` | Auth abuse keys |
| `tests/rate-limiter.test.ts` | **New** |
| `tests/logger.test.ts` | `Retry-After` filter test |
| `tests/server-config.test.ts` | Auth defaults |
| `tests/identity-integration.test.ts` | Lockout/Retry-After, privileged audit |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No migration, dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Sign-in is limited per identifier and IP. |
| DoD-02 | Reset and OTP are limited. |
| DoD-03 | A denial returns `429` with `Retry-After`. |
| DoD-04 | Lockout triggers at the configured threshold and duration. |
| DoD-05 | A privileged sign-in writes `identity.privileged_sign_in`. |
| DoD-06 | Limits are parsed from the environment with safe defaults. |
| DoD-07 | The limiter separates identifier and IP buckets. |
| DoD-08 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-09 | `pnpm test:identity` proves lockout and the privileged audit in CI. |
| DoD-10 | No new dependency, secret or permission. |
| DoD-11 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- The limiter allows N attempts and denies N+1 with the remaining window in `Retry-After`.
- A fresh window allows again; different keys do not interfere.
- Five bad sign-ins lock the credential; the next request is 429 with `Retry-After`.
- A control sign-in writes `identity.privileged_sign_in` with the audience and environment.
- Config values change the window, limits and lockout duration.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/rate-limiter.test.ts tests/server-config.test.ts` |
| T-02 | `pnpm test -- tests/logger.test.ts` — headers |
| T-03 | `pnpm test:identity` — CI database job |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` |
| T-05 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| In-memory limits are per process. | Recorded as `F-41`; the limiter interface is the seam for a shared store. |
| Counting successful sign-ins can hit a legitimate user. | The default is 10/min per identifier; configurable. |
| IP can be spoofed if the proxy is untrusted. | `TRUST_PROXY` is explicit; the edge sets the origin. |
| A privileged sign-in is not necessarily a new location. | Every privileged sign-in is audited with the row IP; history/geo is `F-42`. |
| Lockout can be used to deny a known account. | Lockout is temporary and the response is generic. |
| No Postgres locally. | Lockout and privileged audit run in CI. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI proves lockout and the privileged audit; a shared limiter is decided |
| **Execution record** | `execution-records/EP-01-042.md` |
