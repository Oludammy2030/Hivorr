# EP-01-010 — API bootstrap and runtime configuration

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-010` |
| **Task title** | API bootstrap and runtime configuration |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — runtime boundary and process behaviour |
| **Execution order** | 5 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage B |
| **Dependencies** | `002` (workspace), `004` (CI pipeline) |

## 2. Objective

Stand up the NestJS + Fastify API as the single ingress for all five clients: `/v1` prefix, validated
configuration that fails fast, honest health and readiness, request receipt timeout, body limit,
correlation IDs and graceful shutdown. A missing or malformed setting must stop the process before it
listens, and no supplied secret may appear in a log.

## 3. Scope

### 3.1 Included

- Verify the existing `createApplication`, `main.ts`, `config.ts`, health controller, correlation hook
  and database pool against the objective.
- Make the compiled API runnable: `@hivorr/shared` must resolve at runtime, not only at compile time.
- Make the runtime image include the shared package that the compiled API requires.
- Declare the real Node floor for the ESM-to-CommonJS boundary.
- Prove HTTP-level behaviour: `/v1` only, body limit, request timeout, correlation sanitisation,
  shutdown.
- Prove process-level behaviour: start, serve, stop; invalid configuration exits non-zero without
  echoing a secret.
- Wire the process smoke test into CI and `verify`.

### 3.2 Excluded

- Request validation, audience declaration, error-code mapping, pagination and idempotency — `011`.
- The ten-module boundary skeleton — `012`.
- OpenAPI and generated client — `013`.
- Worker entry point — `014`.
- Database-backed readiness — `020`/`026`. `/v1/health/ready` continues to return 503 by design.
- Handler execution timeouts. See §12.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Every API route is served under `/v1`; an unprefixed path is not found. | Plan `010` |
| R-02 | Configuration is parsed and validated before the listener opens; errors name the field, never the value. | Plan `010` |
| R-03 | Staging and production require `BACKEND_ENVIRONMENT`, `SUPABASE_PROJECT_REF`, `DATABASE_URL`, `SESSION_ISSUER` and a 32-byte `MFA_ENCRYPTION_KEY`. | Architecture; `043` |
| R-04 | Database URLs must belong to the declared project reference. | Environment topology |
| R-05 | `/v1/health` and `/v1/health/live` return 200; `/v1/health/ready` returns 503 until a real check exists. | Plan `010`; `F-08` |
| R-06 | A request body above 1 MiB is rejected before a handler runs. | Plan `010` |
| R-07 | The request receipt timeout is 15 000 ms. | Plan `010` |
| R-08 | A safe caller correlation ID is echoed; an unsafe or missing value is replaced. | Plan `010`; `040` |
| R-09 | SIGTERM closes the listener and database pool instead of leaving the process running. | Plan `010` |
| R-10 | Missing configuration exits with code 1 and no supplied secret in output. | Plan `010` |
| R-11 | The compiled API starts from `server/dist/main.js` with only the declared runtime files. | Plan `010`; Dockerfile |
| R-12 | No new runtime dependency; no new secret; no write permission in CI. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-002` workspace | **COMPLETED** 2026-11-09 — eight workspaces resolve |
| `EP-01-003` shared contracts | **COMPLETED** 2026-11-09 — the package the API now loads at runtime |
| `EP-01-004` CI pipeline | **REQUIRES_REVIEW** — supplies the build job the smoke step joins |
| Node 22.12 or newer | Required for `require()` of an ESM package; CI and the Docker base image are current 22.x |
| Postgres | **Not required** — the health route does not open a connection |

## 6. Implementation plan

1. Read the existing bootstrap, config, health, pool, correlation and test files.
2. Reproduce a cold start of `server/dist/main.js`.
3. Fix the shared-package runtime contract: exports point at compiled output; internal ESM
   specifiers carry `.js`; the API declares the workspace dependency.
4. Add the shared package to the runtime image.
5. Add `tests/api-bootstrap.test.ts` for HTTP-level behaviour.
6. Add `scripts/smoke-api.mjs` for process-level behaviour.
7. Wire `test:api` into `verify` and the CI build job.
8. Run typecheck, lint, boundaries, formatting, tests and both builds; record what the Windows host
   cannot execute.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `server/src/app.ts` | **Reuse, no change** | Already sets `/v1`, body limit, timeout, correlation hook, shutdown hooks |
| `server/src/main.ts` | **Reuse, no change** | Already logs only the error message and exits 1 |
| `server/src/config.ts` | **Reuse, no change** | Zod schema, project-ref match, secret-safe error message, worker defaults |
| `server/src/modules/health/health.controller.ts` | **Reuse, no change** | Honest 503 readiness; live alias |
| `server/src/db/pool.ts`, `database.service.ts` | **Reuse, no change** | Lazy pool, shutdown hook |
| `tests/server-app.test.ts`, `server-config.test.ts`, `server-correlation.test.ts` | **Reuse** | Keep the existing coverage; add the missing HTTP and process evidence |
| `@hivorr/shared` | **Reuse; repair its runtime contract** | One vocabulary; no re-duplication of capability IDs |
| `vite.config.ts` | **Extend with one alias** | Tests and dev consume shared source; the API consumes compiled output |
| Dockerfile | **Extend the runtime stage** | The compiled API requires the shared package |
| `pnpm build:shared`, `build:server` | **Reuse** | The build order already exists |

**Must not be duplicated:** a second configuration schema, a second health controller, a second
correlation generator, a second body-limit setting, or a duplicated capability list in the server.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `packages/shared/package.json` | `exports` and `types` point at `dist`, not `src` |
| `packages/shared/src/index.ts` | ESM specifiers carry `.js` |
| `packages/shared/src/routes.ts` | Type import carries `.js` |
| `packages/shared/tsconfig.build.json` | Explicit ESM build for Node |
| `server/package.json` | Declares `@hivorr/shared` — the phantom dependency is removed |
| `package.json` | `build:all` and `build:portals` build shared first; `test:api`; Node floor; `verify` |
| `vite.config.ts` | `@hivorr/shared` alias to source for tests and dev |
| `Dockerfile` | Runtime stage copies the shared package and its compiled output |
| `scripts/smoke-api.mjs` | **New** — process-level start, serve, stop, invalid-config |
| `tests/api-bootstrap.test.ts` | **New** — `/v1`, limits, correlation, shutdown |
| `.github/workflows/ci.yml` | Build job runs `pnpm test:api` after `build:server` |
| `tests/ci-pipeline.test.ts` | Requires `pnpm test:api` in CI |
| `tests/readiness.test.ts` | Toolchain contract reflects the real Node floor |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Every route is under `/v1`; `/health` returns 404. |
| DoD-02 | Configuration validation fails fast and never echoes a supplied value. |
| DoD-03 | `/v1/health` and `/v1/health/live` return 200; `/v1/health/ready` returns 503. |
| DoD-04 | An over-limit body returns 413 before reaching a handler. |
| DoD-05 | The adapter applies a 1 MiB body limit and a 15 000 ms request receipt timeout. |
| DoD-06 | A safe correlation ID is echoed; an unsafe value is replaced. |
| DoD-07 | `app.close()` closes the listener and the database pool. |
| DoD-08 | The compiled process starts, serves `/v1/health/live` and stops on SIGTERM. |
| DoD-09 | Missing configuration exits 1, names the field and does not echo a secret. |
| DoD-10 | The compiled process resolves `@hivorr/shared` with only the runtime image's files. |
| DoD-11 | `pnpm typecheck`, `pnpm lint`, `pnpm lint:boundaries`, `pnpm format:check`, `pnpm build:all`, `pnpm build:server` pass. |
| DoD-12 | `tests/api-bootstrap.test.ts` and `scripts/smoke-api.mjs` exist and are wired into CI. |
| DoD-13 | No new runtime dependency, secret or CI permission. |
| DoD-14 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- A cold `node server/dist/main.js` reaches a listening socket on a supported host, answers the
  liveness route and exits on SIGTERM.
- A staging process without the required settings exits 1 before listening, states the missing
  fields and never prints `DATABASE_URL`, `MFA_ENCRYPTION_KEY` or any supplied value.
- An oversized body is a 413, not a handler error or a silent truncation.
- The runtime image contains every file the compiled API resolves.
- Removing the process smoke step from CI fails `tests/ci-pipeline.test.ts`.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/api-bootstrap.test.ts` — HTTP behaviour |
| T-02 | `pnpm test:api` — process start, serve, stop, invalid configuration |
| T-03 | `node -e "require('./server/dist/domain/capabilities.js')"` — compiled shared resolution |
| T-04 | `pnpm build:all`, `pnpm build:server` — both consumers of the shared package |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-06 | `pnpm test`, `pnpm test:contracts`, `pnpm test:gates` |
| T-07 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The Windows host cannot load `@node-rs/argon2`, so no process can start locally. | Recorded as `F-10`; the process smoke runs in the Linux CI build job. No architecture or `supportedArchitectures` change. |
| `@hivorr/shared` was exported from `src`, so the compiled API resolved untranspiled TypeScript. | Fixed: exports point at compiled ESM; internal specifiers carry `.js`; the server declares the dependency. Recorded as `F-14`. |
| The runtime image did not contain `packages/shared`. | Fixed in the Dockerfile. |
| ESM required from CommonJS needs Node 22.12+. | The engine floor is now `>=22.12.0 <23`; CI and the Docker base use current 22.x. |
| Fastify `requestTimeout` bounds receipt of the request, not handler execution. | Stated plainly; a handler deadline is not implemented. Follow-up below. |
| Portal builds resolved the package from `dist`; a missing build would surface late. | `build:all` and `build:portals` build shared first; tests and dev use the source alias. |
| `tests/api-bootstrap.test.ts` cannot load on Windows for the same argon2 reason as `server-app`. | CI is the reference; the limitation is recorded, not suppressed. |
| The smoke test's invalid-config case could pass for the wrong reason. | It requires both exit 1 and the `failed to start` message and `SESSION_ISSUER` before passing. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | a Linux CI run observes `pnpm test:api` and `tests/api-bootstrap.test.ts` passing |
| **Execution record** | `execution-records/EP-01-010.md` |
