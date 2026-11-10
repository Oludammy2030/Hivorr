# EP-01-040 — Structured logging, correlation and error-tracking seam

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-040` |
| **Task title** | Structured logging, correlation and error-tracking seam |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — observability seam |
| **Execution order** | 24 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage E |
| **Dependencies** | `EP-01-010`, `EP-01-011` |

## 2. Objective

Produce structured JSON logs with the correlation ID on every request, redact credentials and
personal data by key, expose an error-tracking seam with no vendor lock-in, and report unexpected
errors without leaking a stack, query string or token. The worker uses the same logger.

## 3. Scope

### 3.1 Included

- `createLogger` — levels, service/environment, JSON lines, injectable sink.
- Recursive key-based redaction for credentials and personal data.
- `ErrorTracker` seam and `CaptureErrorTracker` (in-memory, no network).
- `ApiErrorFilter` as an `APP_FILTER` with injected logger/tracker; 5xx and unknown errors are
  captured, 4xx are not.
- Fastify `onResponse` structured request log with method, path, status, duration and correlation;
  health probes skipped; query strings and headers never logged.
- Worker logger replaced by the structured logger through an `OutboxLogger` adapter.
- Unit tests for logging, redaction, level filtering, tracker capture and filter reporting.

### 3.2 Excluded

- A vendor error-tracking integration, log drain, alerting or dashboards.
- OpenTelemetry spans. This is a logging seam, not a tracing implementation.
- Log retention policy.
- Scrubbing free text inside provider error messages — recorded as `F-40`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Every log line is structured JSON with level, service, environment and event. | Plan `040` |
| R-02 | The request log carries the correlation ID. | Plan `040` |
| R-03 | Credentials and personal data are redacted by key at every depth. | `AFS-LOG` |
| R-04 | No request body, header, cookie or query string is logged. | `AFS-LOG-01` |
| R-05 | Unknown errors are captured and logged; 4xx are not. | Plan `040` |
| R-06 | The error tracker is an interface with a capture-only default. | Plan `040` |
| R-07 | A raw `Error` is never serialised into a log. | `AFS-LOG-01` |
| R-08 | The worker emits the same structured shape. | Plan `040` |
| R-09 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-010` bootstrap | **REQUIRES_REVIEW** — app hooks and filters |
| `EP-01-011` error contract | **REQUIRES_REVIEW** — filter mapping |
| `EP-01-014` worker | **REQUIRES_REVIEW** — worker logger |
| `EP-01-036` audit | **REQUIRES_REVIEW** — separate evidence trail |

## 6. Implementation plan

1. Read the filter, request hooks and worker logger.
2. Add the structured logger and redaction.
3. Add the error-tracker interface and capture adapter.
4. Convert the filter to an `APP_FILTER` with injected logger/tracker.
5. Add the request `onResponse` log.
6. Convert the worker logger.
7. Add unit tests; run local gates.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `resolveCorrelationId` | **Reuse** | Correlation generation and sanitisation already correct |
| `onRequest` hook | **Reuse** | It already sets the header and request field |
| `ApiErrorFilter` | **Convert to DI** | It needs logger/tracker |
| `ApiError`, `toErrorBody` | **Reuse** | Stable error body |
| Worker `OutboxLogger` | **Adapt** | The worker contract stays; the implementation becomes structured |
| No new dependency | **Required** | Node `process.stdout` is enough |

**Must not be duplicated:** a second correlation generator, a second error filter, or a second worker
logger.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `server/src/common/logger.ts` | **New** — structured logger and redaction |
| `server/src/common/error-tracker.ts` | **New** — seam and capture adapter |
| `server/src/common/api-error.filter.ts` | Injected logger/tracker; 5xx reporting |
| `server/src/app.ts` | Remove manual filter; add `onResponse` |
| `server/src/app.module.ts` | `APP_FILTER`, `LOGGER`, `ERROR_TRACKER` providers |
| `server/src/worker.ts` | Structured logger adapter |
| `tests/logger.test.ts` | **New** |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Logs are single-line JSON with level/service/environment/event. |
| DoD-02 | Correlation appears on the request log and the response header. |
| DoD-03 | Sensitive keys are redacted recursively. |
| DoD-04 | Level filtering works. |
| DoD-05 | Unknown and 5xx errors are captured; 4xx are not. |
| DoD-06 | The captured context has correlation, method, path and status, no query. |
| DoD-07 | A raw `Error` is not serialised into a log. |
| DoD-08 | The worker uses the structured logger. |
| DoD-09 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-10 | No new dependency, secret or permission. |
| DoD-11 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- An info log with `email`, `token` and nested `password` contains `[redacted]` for each and keeps a
  correlation ID.
- At `error` level, `info` is suppressed and `error` is written.
- The filter captures an unknown error with the correlation and path but not the query string.
- An `ApiError` 401 is neither captured nor logged as an unhandled error.
- The worker's log output has the same shape as the API's.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/logger.test.ts` |
| T-02 | `pnpm test:gates` |
| T-03 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-04 | `pnpm test:api` / worker smoke in CI — live wiring |
| T-05 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Free-text error messages can contain PII. | The filter logs only the error name; the worker logs provider messages. Recorded as `F-40`. |
| A redaction key list can miss a new secret name. | The list is central and tested; review when a new credential is added. |
| Request paths can contain identifiers. | Paths are needed for operations; query strings and bodies are never logged. |
| The logger sink is synchronous. | One line per event; a high-volume drain is a later adapter. |
| `APP_FILTER` changes filter instantiation. | The filter is DI-ready; the app no longer constructs it manually. |
| No local API start (argon2). | The live request/worker wiring is exercised by CI smoke. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI smoke exercises the API request log and worker structured output; `F-40` is accepted or fixed |
| **Execution record** | `execution-records/EP-01-040.md` |
