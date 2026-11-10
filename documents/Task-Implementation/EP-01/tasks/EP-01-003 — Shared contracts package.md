# EP-01-003 — Shared contracts package

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-003` |
| **Task title** | Shared contracts package |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — cross-client contract |
| **Execution order** | 3 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage A |
| **Dependencies** | `002` (workspace), `zod` decision (`standards` §16 `#1`) |

## 2. Objective

Publish `@hivorr/shared` as the single framework-free vocabulary for the API and every client:
environment and portal contracts (already present), activity registry types, capability and grant
constants, API error codes and body shape, approved route IDs, and the zod schemas that validate
them. No client or server may keep a second copy of any of these lists.

## 3. Scope

### 3.1 Included

- Extend the existing `packages/shared/src/index.ts` contract; keep its environment, portal, host and
  release-manifest exports unchanged.
- Activity vocabulary: the six approved activity IDs, direction, dashboard label and route family.
- Capability and grant vocabulary moved out of `server/src/domain/capabilities.ts`.
- API error codes and the error body shape moved out of `server/src/common/errors.ts`.
- Approved UI route IDs from `ARCHITECTURE.md` §8.6 and §4.2.
- Zod schemas for every shared enum and the error body.
- Server imports the shared constants instead of declaring them.
- Contract tests.

### 3.2 Excluded

- Capability **computation** stays server-side. Moving `computeCapabilities` into a client-consumable
  package would breach `AGENTS.md` Rule 4 (no client authority).
- Activity activation transitions, tables and endpoints — `024`, `033`, `035`.
- Request-body schemas for register/sign-in/grants — they belong to `011`/`031` and would expand this
  task into the identity domain.
- OpenAPI generation and the generated client — `013`.
- The router and route manifest implementation — `052`. This task defines IDs and paths only.
- Any edit to `src/app/App.tsx`, `src/styles/theme.css` or the prototype's `Screen` union.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | `@hivorr/shared` imports no React, Node, server, database or provider module. | Plan §11 `003`; `AGENTS.md` §3 |
| R-02 | One capability list, one grant list, one error-code list, one activity list, one route list. | Reuse rule (`AGENTS.md` §3) |
| R-03 | Activity IDs match the permission matrix exactly: `market.buy`, `services.hire`, `errands.request`, `market.sell`, `services.offer`, `logistics.provide`. | Matrix §A1 |
| R-04 | Route paths match `ARCHITECTURE.md` §8.6 and §4.2. | Architecture |
| R-05 | Zod is the only validation library; exact pin, seven-day policy respected. | `standards` §16 `#1` |
| R-06 | The API compiles against the shared vocabulary with no duplicate declaration. | This task |
| R-07 | Contract tests fail if a list, ID or path drifts. | Plan `003` expected outcome |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-002` workspace | **COMPLETED** 2026-11-09 |
| `zod` 4.6.7 | Installed in `server`; reused, not replaced |
| Permission matrix | Approved; activity IDs and directions read from it |
| `ARCHITECTURE.md` §8.6 / §4.2 | Decided route families |

## 6. Implementation plan

1. Read the current shared package, capability module, error module and the approved route/activity
   sources.
2. Add `packages/shared/src/activities.ts` with the six IDs, direction, dashboard label and route
   family, plus `activityIdSchema`.
3. Add `packages/shared/src/capabilities.ts` with `CAPABILITY_IDS`, `GRANT_IDS`, their types and
   schemas. Computation stays out.
4. Add `packages/shared/src/errors.ts` with `API_ERROR_CODES`, `ApiErrorCode`, `ApiErrorBody` and the
   zod schemas.
5. Add `packages/shared/src/routes.ts` with the approved route IDs, portal ownership, path and
   indexability.
6. Re-export the modules from `index.ts`; leave the existing contracts untouched.
7. Add `zod` to `packages/shared/package.json`, exact `4.6.7`; refresh the lockfile with
   `pnpm install`.
8. Replace the duplicated declarations in `server/src/domain/capabilities.ts` and
   `server/src/common/errors.ts` with imports and re-exports so existing imports keep working.
9. Extend `tests/workspace-contracts.test.ts` with activity, capability, error, route and schema
   assertions, including a seeded drift check.
10. Run the gates and record evidence.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `packages/shared/src/index.ts` | **Extend** | Already owns environment, portal, host and release-manifest contracts |
| `server/src/domain/capabilities.ts` — `CAPABILITY_IDS`, `CapabilityId`, `GrantId` | **Move** to shared; keep computation server-side | Single vocabulary; no client authority |
| `server/src/common/errors.ts` — `ApiErrorCode`, `ApiErrorBody` | **Move** types to shared; keep `ApiError` class server-side | The class carries HTTP status and stack behaviour |
| `server/src/modules/grants/grants.service.ts` — `GRANT_SCOPES` | **Reuse as-is** | Domain configuration; its values are now typed by `GrantId` |
| `zod` 4.6.7 | **Reuse** | Already installed and used by config and controllers |
| `tests/workspace-contracts.test.ts` | **Extend** | One contract suite for the shared package |
| `packages/shared/tsconfig.json` / `tsconfig.build.json` | **Reuse** | Framework-free lib and declaration build already configured |
| `scripts/lint-boundaries.mjs` | **Reuse** | Enforces shared→framework/server bans |
| `react-router` 7 | **Not used here** | Route IDs only; the router is `052` |

**Must not be duplicated:** the six activity IDs, the eight capability IDs, the six grant IDs, the
eight error codes, the eight portal host pairs, and the approved route paths.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `packages/shared/package.json` | Add `zod` `4.6.7` |
| `packages/shared/src/activities.ts` | **New** |
| `packages/shared/src/capabilities.ts` | **New** |
| `packages/shared/src/errors.ts` | **New** |
| `packages/shared/src/routes.ts` | **New** |
| `packages/shared/src/index.ts` | Re-export new modules |
| `server/src/domain/capabilities.ts` | Import shared constants; remove duplicates |
| `server/src/common/errors.ts` | Import shared types; remove duplicates |
| `tests/workspace-contracts.test.ts` | Extend |
| `pnpm-lock.yaml` | Updated by `pnpm install` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, execution record |

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | The six activity IDs and definitions are exported once and match the matrix exactly. |
| DoD-02 | `CAPABILITY_IDS` and `GRANT_IDS` are exported from shared; the server declares no second copy. |
| DoD-03 | `API_ERROR_CODES`, `ApiErrorCode` and `ApiErrorBody` are exported from shared; the server declares no second copy. |
| DoD-04 | Route IDs cover every approved URL family, are unique, and match the architecture paths. |
| DoD-05 | Zod schemas accept every valid ID and reject an unknown one. |
| DoD-06 | `@hivorr/shared` compiles with no React, Node, server or database import. |
| DoD-07 | The API typechecks against the shared vocabulary. |
| DoD-08 | The root web app still declares `@hivorr/shared` as a workspace dependency. |
| DoD-09 | Contract tests pass, including a drift assertion that fails if an ID or path is changed. |
| DoD-10 | `pnpm typecheck`, `pnpm lint`, `pnpm lint:boundaries` and both builds pass. |
| DoD-11 | `src/app/App.tsx`, `src/styles/theme.css` and the Figma config are unchanged. |

## 10. Acceptance criteria

- A server module can import any shared ID/type and no local duplicate remains.
- Adding a seventh activity, a ninth capability or a new error code in one place updates every
  consumer's types, and the contract test fails if a list changes without the test being updated.
- An unknown activity, capability, grant or error code is rejected by its schema.
- `@hivorr/shared` remains safe to ship to a browser: no server code, secret, database driver or React.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | Activity list: exactly six, exact IDs, unique, every one has a direction and route family |
| T-02 | Capability list: unique, contains `session.read`, `activity.activate`, `admin.audit.read` |
| T-03 | Grant list: unique, contains the six recorded grant IDs |
| T-04 | Error list: unique, contains all eight codes; `ApiErrorBody` schema accepts and rejects correctly |
| T-05 | Route list: unique IDs, unique `portal+path`, every activity route family resolves, admin belongs to `control` |
| T-06 | Zod enums reject an unknown value |
| T-07 | Seeded drift: change one expected ID in the test, confirm it fails, restore |
| T-08 | `pnpm typecheck`, `lint`, `lint:boundaries`, `build:all`, `build:server` |
| T-09 | Prototype and theme unchanged |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Moving constants breaks existing server imports | Re-export from the server modules so `api-error.filter.ts`, `grants.service.ts` and tests keep their current import paths |
| Zod in a browser package increases bundle size | Accepted: `zod` is the approved client validation library; the shared schemas are small |
| Route IDs could pre-empt `052` | Only IDs, paths and portal ownership are defined; no router, loader or component |
| Activity activation states could pre-empt `033` | Only the state vocabulary is exported; transition rules and tables are left to `033` |
| Route paths in the architecture use `/admin/*` | Modelled as a prefix route, not a wildcard matcher |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `COMPLETED` |
| **Started** | 2026-11-09 |
| **Completed** | 2026-11-09 |
| **Execution record** | `execution-records/EP-01-003.md` |
