# EP-01-014 — Worker, PostgreSQL queue and outbox

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-014` |
| **Task title** | Worker, PostgreSQL queue and outbox |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | High |
| **Class** | `[REVIEW]` — background process and delivery semantics |
| **Execution order** | 9 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage B |
| **Dependencies** | `EP-01-012`; `EP-01-024` (see §5) |

## 2. Objective

Run a worker process that consumes the transactional outbox: claim a batch with a lease,
dispatch each event to one registered handler, complete it, retry a failure with exponential
backoff, dead-letter an exhausted or unhandled event, and expose queue health without exposing event
data. Side effects must not block the API request.

## 3. Scope

### 3.1 Included

- Verify the existing `worker.ts`, `OutboxRepository`, `OutboxWorker`, handler registry and health
  server against the expected outcome.
- Add local tests for the worker loop: claim, dispatch, replay idempotency, retry, dead-letter,
  unhandled event and lost lease.
- Add local HTTP tests for `/health/live`, `/health/ready`, `/health/queue`, 503 fail-closed, 404 and
  405.
- Add a process smoke test for the compiled worker: start, liveness, queue 503 without a database,
  SIGTERM, and missing configuration exiting 1.
- Wire the smoke test into CI and `verify`.

### 3.2 Excluded

- Registering provider handlers. No notification, payment or storage adapter exists yet; an event
  with no handler is dead-lettered deliberately.
- Durable idempotency storage for handlers. The contract is at-least-once and keyed by event id;
  each handler owns its dedupe.
- Structured logging, correlation and error tracking — `040`.
- Feature work that emits events — later phases.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The worker starts as its own process and serves liveness. | Plan `014` |
| R-02 | Claims are leases; an expired lease is reclaimable. | Plan `014` |
| R-03 | Delivery is at-least-once; a handler is keyed by event id. | `outbox.ts` contract |
| R-04 | A failure retries with exponential backoff. | Plan `014` |
| R-05 | An exhausted event is dead-lettered, never dropped. | Plan `014` |
| R-06 | An event with no handler is dead-lettered with a clear reason. | Plan `014` |
| R-07 | Queue health reports counts and the oldest pending timestamp only. | Plan `014` |
| R-08 | Queue health fails closed when the database is unreachable. | `AFS-CONF-08` |
| R-09 | Missing worker configuration stops startup with code 1. | `010` pattern |
| R-10 | SIGTERM stops polling, signals handlers and closes the pool. | Plan `014` |
| R-11 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-012` modules | **COMPLETED** |
| `EP-01-024` platform schema | **PENDING in the plan**, but the tables the worker needs already exist from migrations `002` (`platform.outbox`) and `011` (delivery fields and `outbox_health()`). The worker does not read any `profile` table. Recorded as `F-26`. |
| `EP-01-004` CI database job | **REQUIRES_REVIEW** — runs `pnpm test:worker` against Postgres |
| `EP-01-013` build | **REQUIRES_REVIEW** — supplies `build:server` for the smoke test |

## 6. Implementation plan

1. Read the worker entry point, repository, loop, health server, migration and integration suite.
2. Add `tests/worker-loop.test.ts` with a fake repository for the orchestration rules.
3. Add `tests/worker-health.test.ts` for the HTTP surface and fail-closed behaviour.
4. Add `scripts/smoke-worker.mjs` for the compiled process.
5. Add `test:worker-smoke`, CI, `verify` and the pipeline contract.
6. Run every local gate; record that the Postgres suite is CI-only.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `server/src/worker.ts` | **Reuse** | Entry point, configuration check, shutdown, health wiring |
| `OutboxRepository` | **Reuse** | Lease claim, complete, fail, dead-letter, health |
| `OutboxWorker` | **Reuse** | Batch loop, retry, dead-letter, stop |
| `OutboxHandlers` / `retryDelayMs` | **Reuse** | Registry and deterministic backoff |
| `startWorkerHealthServer` | **Reuse** | Liveness, readiness, queue counts |
| `migration 011` | **Reuse as-is** | Lease fields, claimable/dead-letter indexes, health function |
| `tests/worker-outbox.test.ts` | **Reuse** | Postgres integration, run in CI |
| `tests/worker-unit.test.ts` | **Reuse** | Backoff and registry |
| `scripts/smoke-api.mjs` | **Pattern** | Same process-smoke structure |
| `build:server` | **Reuse** | Compiles the worker entry |

**Must not be duplicated:** a second queue table, a second claim query, a second backoff function, a
second health endpoint, or a second worker entry point.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `tests/worker-loop.test.ts` | **New** — orchestration with a fake repository |
| `tests/worker-health.test.ts` | **New** — HTTP health surface |
| `scripts/smoke-worker.mjs` | **New** — compiled process start/stop/config |
| `package.json` | `test:worker-smoke`; `verify` |
| `.github/workflows/ci.yml` | Build job runs the worker smoke |
| `tests/ci-pipeline.test.ts` | Requires `pnpm test:worker-smoke` |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

The worker implementation and migration were **not** rewritten.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | The compiled worker starts and answers `/health/live`. |
| DoD-02 | Queue health returns counts and `oldestPendingAt`; it never returns event data. |
| DoD-03 | Queue health is 503 when the repository cannot be read. |
| DoD-04 | A claimed event is dispatched and completed exactly once. |
| DoD-05 | A redelivered event triggers the handler again; the keyed effect stays single. |
| DoD-06 | A throwing handler retries with backoff and dead-letters at the limit. |
| DoD-07 | An unhandled event is dead-lettered with a clear reason. |
| DoD-08 | A lost lease does not count as a completion. |
| DoD-09 | Missing worker configuration exits 1 and names the setting. |
| DoD-10 | `pnpm test:worker-smoke` passes and is wired into CI. |
| DoD-11 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates`, `build:all`, `build:server` pass. |
| DoD-12 | No new dependency, secret or CI permission. |
| DoD-13 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- With no database, the worker still starts, `/health/live` is 200 and `/health/queue` is 503 — it
  never claims readiness it does not have.
- With a database, the integration suite claims, completes, replays, retries, dead-letters and
  reports health.
- Killing the worker leaves a leased event reclaimable after the lease expires.
- An event whose type has no handler is retained as a dead letter, not deleted.
- The health payload contains counts and one timestamp, never a payload, aggregate id or credential.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/worker-loop.test.ts tests/worker-health.test.ts` |
| T-02 | `pnpm test:worker-smoke` after `pnpm build:server` |
| T-03 | `pnpm test:gates` |
| T-04 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-05 | `pnpm build:all`, `build:server` |
| T-06 | `pnpm test:worker` — Postgres integration, CI database job |
| T-07 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| At-least-once delivery can duplicate effects. | Documented contract; handlers key by event id. The loop test demonstrates the dedupe pattern. |
| The production registry has no handlers yet. | Unhandled events are dead-lettered with a reason; they are not silently dropped. |
| The worker health server binds `0.0.0.0`. | The Fly worker config has no `[services]`; the listener is private-network only. |
| `LOG_LEVEL` is not applied to the worker logger. | Structured logging is `040`; the current logger is JSON-shaped and never logs event payloads. |
| The Postgres integration suite is CI-only. | The local loop and HTTP tests cover the orchestration; the SQL is exercised in the database job. |
| The plan lists `024` as a dependency but `024` is pending. | The required tables already exist; recorded as `F-26`. |
| Windows cannot load argon2. | The worker does not import identity; the worker tests and smoke run locally. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | Linux CI runs `pnpm test:worker` against Postgres and the worker smoke |
| **Execution record** | `execution-records/EP-01-014.md` |
