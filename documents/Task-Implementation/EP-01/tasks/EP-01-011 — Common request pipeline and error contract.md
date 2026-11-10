# EP-01-011 — Common request pipeline and error contract

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-011` |
| **Task title** | Common request pipeline and error contract |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — request boundary and denial semantics |
| **Execution order** | 6 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage B |
| **Dependencies** | `EP-01-010` |

## 2. Objective

Give every endpoint one request pipeline: an explicit audience, allowlist validation that rejects
unknown fields, one exception mapping with stable codes that distinguish unauthenticated,
unauthorised, activity-inactive, validation and not-found, plus cursor-pagination and idempotency
primitives. No route may invent its own validation or error handling.

## 3. Scope

### 3.1 Included

- `@Audience(...)` metadata and a global `AudienceGuard` that rejects an undeclared route, the wrong
  portal audience and an unrecognised host, and resolves the trusted forwarded host exactly as the
  existing request context did.
- One validation helper (`parseBody`, `parseQuery`) that returns `VALIDATION_FAILED` with field names
  and no internal reason.
- Strict request schemas so unknown fields are rejected rather than stripped.
- `ACTIVITY_INACTIVE` as a stable shared error code and an `activityInactive()` factory.
- Cursor-pagination contract in `@hivorr/shared` and cursor/`toPage` helpers in the server.
- Idempotency primitives: `Idempotency-Key` parsing, a stable TTL, and a canonical request
  fingerprint.
- Deduplicate the portal host map by using `getPortalByHost` from `@hivorr/shared`.
- Unit and contract tests for every primitive, plus HTTP deny-path tests in the existing
  integration suite.

### 3.2 Excluded

- Applying pagination to the existing grant collections. The primitive exists; adopting it changes
  the response shape and belongs to the grant module and the `013` contract — recorded as `F-18`.
- Durable idempotency replay against `platform.idempotency_keys`. The table exists; the endpoint that
  owns a transaction must write and read the record under that transaction.
- A handler execution deadline. Recorded as `F-20`.
- Capability declaration alongside audience. Capabilities are enforced in services today and their
  full declaration is `035`.
- The ten-module skeleton — `012`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Every routed method declares `public` or one or more portal audiences. | API-04, Architecture §9.9 |
| R-02 | An undeclared route is a server defect, not an open endpoint. | API-04; default deny |
| R-03 | A request on the wrong portal host is rejected before the handler. | AUT-12, Architecture §5.4 |
| R-04 | The forwarded host is trusted only with the edge secret. | `010` request-context |
| R-05 | Unknown request fields are rejected, not ignored. | SEC-23, API-06 |
| R-06 | Validation names the field and never the internal zod reason. | SEC-27 |
| R-07 | The error contract distinguishes unauthenticated, forbidden, activity-inactive, validation and not-found. | Plan `011` outcome |
| R-08 | Collection pagination is cursor-based with a bounded page size. | API-09, Architecture §9.9 |
| R-09 | A retryable mutation can require an `Idempotency-Key`; the fingerprint binds the key to the payload. | API-08, Architecture §9.9 |
| R-10 | The validation and pagination contracts are shared, not duplicated per client. | Reuse rule; `003` |
| R-11 | No new runtime dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-010` bootstrap | **REQUIRES_REVIEW** — supplies `ApiConfig`, the request context and the exception filter |
| `EP-01-003` contracts | **COMPLETED** — owns error codes and now pagination |
| `EP-01-004` CI | **REQUIRES_REVIEW** — runs the new tests |
| `zod` 4.6.7 | Existing in `server` and `packages/shared`; reused |
| `rxjs` 7.8.2 | Existing Nest dependency; not used by this change |

## 6. Implementation plan

1. Read the controllers, request context, error filter, portal map and migrations.
2. Add the audience metadata, resolver and guard; register it globally.
3. Move the trusted-forward host resolution into the shared audience module so there is one copy.
4. Add the central validation helpers and make every request schema strict.
5. Add `ACTIVITY_INACTIVE` and its factory to the shared and server error contracts.
6. Add the shared pagination schema/envelope and the server cursor helpers.
7. Add the idempotency header and fingerprint primitives.
8. Add unit and contract tests; add HTTP deny-path tests to the integration suite.
9. Run typecheck, lint, boundaries, formatting, tests and builds; record what Windows cannot load.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `common/api-error.filter.ts` | **Reuse, no change** | Already maps `ApiError`, `HttpException` and unknown errors to one body |
| `common/errors.ts` | **Extend** | One new factory; the class and serialiser stay |
| `packages/shared/src/errors.ts` | **Extend** | The code list is the contract; add one code |
| `modules/identity/portal.ts` | **Replace with re-export** | Host resolution moved to `common/audience`; no second map |
| `packages/shared` `PORTALS` / `getPortalByHost` | **Reuse** | Removes the duplicate host table in the server |
| `modules/identity/request-context.ts` | **Refactor internals only** | Uses the guard-resolved audience; same errors |
| Controller-local validators | **Replace** | One `parseBody`; no per-controller error wording |
| `tests/identity-integration.test.ts` | **Extend** | Runs the real app over HTTP; denies are tested there |
| `tests/api-bootstrap.test.ts` | **Reuse** | Covers the 413 path; unaffected |
| `Pagination` / `idempotency` tables | **Not edited** | The migration already exists; no schema change |

**Must not be duplicated:** a second host map, a second error-code list, a second validation helper,
a second pagination envelope, or a second idempotency-key parser.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `packages/shared/src/errors.ts` | Add `ACTIVITY_INACTIVE` |
| `packages/shared/src/pagination.ts` | **New** — page schema, envelope, limits |
| `packages/shared/src/index.ts` | Export pagination |
| `server/src/common/audience.ts` | **New** — decorator, resolver, guard, metadata helpers |
| `server/src/common/validation.ts` | **New** — strict body/query parsing |
| `server/src/common/pagination.ts` | **New** — cursor encode/decode and `toPage` |
| `server/src/common/idempotency.ts` | **New** — header schema and fingerprint |
| `server/src/common/errors.ts` | Add `activityInactive()` |
| `server/src/app.module.ts` | Register `APP_GUARD` |
| `server/src/modules/identity/portal.ts` | Re-export the single resolver |
| `server/src/modules/identity/request-context.ts` | Use the guard-resolved audience |
| `server/src/modules/identity/identity.controller.ts` | Audience, strict schemas, shared parser |
| `server/src/modules/grants/grants.controller.ts` | Audience, strict schema, shared parser |
| `server/src/modules/health/health.controller.ts` | Declare `public` |
| `tests/request-pipeline.test.ts` | **New** — primitives and guard |
| `tests/audience-declaration.test.ts` | **New** — metadata coverage (Linux) |
| `tests/workspace-contracts.test.ts` | Nine codes; pagination contract |
| `tests/identity-integration.test.ts` | Unknown-field 400 and wrong-audience 403 |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Every routed method declares a valid audience; an undeclared route fails closed. |
| DoD-02 | The guard allows the declared portal and denies another portal and an unknown host. |
| DoD-03 | A forwarded host is honoured only with the correct edge secret. |
| DoD-04 | Unknown request fields return 400 `VALIDATION_FAILED` and name the field. |
| DoD-05 | Validation never echoes the internal reason or a supplied secret value. |
| DoD-06 | The error contract distinguishes unauthenticated, forbidden, activity-inactive, validation and not-found. |
| DoD-07 | Shared pagination enforces a default of 20 and a maximum of 100 and rejects unknown query fields. |
| DoD-08 | Cursor encode/decode round-trips; a malformed cursor is a 400 `VALIDATION_FAILED`. |
| DoD-09 | `toPage` returns at most `limit` rows and a cursor only when more exist. |
| DoD-10 | `Idempotency-Key` is required/validated by one helper; the fingerprint is order-independent. |
| DoD-11 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `build:all`, `build:server` pass. |
| DoD-12 | No new runtime dependency, secret or CI permission. |
| DoD-13 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- A route added without `@Audience` returns 500 `INTERNAL_ERROR` and fails the declaration test.
- A control-only route called on `staging.hivorr.com` returns 403 before authentication.
- A body with an undeclared field returns 400 `VALIDATION_FAILED` naming that field; it never reaches
  the database.
- A malformed cursor returns 400, not an empty page or a 500.
- The same idempotency key with a different payload produces a different fingerprint.
- The five denial/validation outcomes have five distinct codes and appropriate status codes.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/request-pipeline.test.ts` |
| T-02 | `pnpm test -- tests/workspace-contracts.test.ts` |
| T-03 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-04 | `pnpm build:all`, `pnpm build:server`, `pnpm test:gates` |
| T-05 | `tests/audience-declaration.test.ts` — Linux CI |
| T-06 | `tests/identity-integration.test.ts` — Linux CI with Postgres |
| T-07 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| A global guard could break existing routes if a declaration is missed. | Every controller is annotated; the metadata test fails on a missing declaration; integration tests exercise the real app over HTTP. |
| `getAllAndOverride` uses handler metadata before class metadata. | Method declarations are intentional (grants own vs control) and documented. |
| Strict schemas could reject a field a client already sends. | No generated client exists yet (`013`); the integration suite sends only declared fields. |
| `ACTIVITY_INACTIVE` is a contract addition. | It is required by the task's expected outcome; the shared contract test pins the nine codes. |
| A durable idempotency implementation without a transaction could record a response before commit. | Not implemented; the primitive stops at the header and fingerprint. The owning module must write within its transaction. |
| Handler execution has no deadline (API-07). | Recorded as `F-20`; a global interceptor would affect future SSE, so it needs an explicit decision. |
| Existing collection endpoints are unbounded arrays. | Recorded as `F-18`; the primitive is ready for the adoption change. |
| Windows cannot load argon2, so the controller and HTTP suites do not run locally. | `F-10`; Linux CI is the reference. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | Linux CI runs the declaration and HTTP deny-path suites green |
| **Execution record** | `execution-records/EP-01-011.md` |
