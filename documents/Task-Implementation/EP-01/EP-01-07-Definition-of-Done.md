# DEFINITION OF DONE — EP-01-07

## Core API Layer & HTTP Client Architecture

> **Document Type:** Standalone Task Definition of Done (Verification Checklist)
> **Reference Plan:** `documents/Task-Implementation/EP-01/EP-01-07-Core API Layer & HTTP Client Architecture.md`
> **Purpose:** Practical checklist for the project lead to confirm EP-01-07 is implemented per the approved plan before approval.

---

## Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-07 |
| **Task Name** | Core API Layer & HTTP Client Architecture |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-07-Core API Layer & HTTP Client Architecture.md` |
| **Phase Plan Status** | Not Started → In Progress (pending implementation approval) |
| **Dependencies** | EP-01-02 (packages pinned), EP-01-03 (config contract) — both Completed; EP-01-05 (RPC error contract `PLT001`–`PLT999`) consumed |

---

## Functional Verification

### Required Functionality
- [ ] The API layer builds exactly **one** Supabase client initialized from `EnvironmentConfig` (URL + public anon key only).
- [ ] The API layer builds exactly **one** Dio instance via `api_client_factory.dart` with the ordered interceptor chain: **auth → logging → retry → error**.
- [ ] `api_initializer.initializeApi(EnvironmentConfig)` wires Supabase + Dio and is exported for `lib/app/` (EP-01-15) to call at bootstrap.
- [ ] `BaseApiService` is available for repositories (EP-01-08) to extend, exposing only `dio` and `supabase` through safe accessors.
- [ ] `ApiException` typed model + mapper normalize Dio/transport/PostgREST/`PLT*` errors.

### Expected Workflows
- [ ] **Init flow:** `initializeApi(config)` → Supabase initialized → Dio singleton built with interceptors → layer ready for repositories (no bootstrap change required in this task).
- [ ] **Outbound request:** Public route → auth skipped; authenticated route → `Authorization: Bearer <token>` attached via `AccessTokenProvider`.
- [ ] **Transient failure:** Connection/timeout/`5xx` → retry with exponential backoff + jitter, bounded max attempts.
- [ ] **Auth expiry:** `401` → `AccessTokenProvider.refresh()` → exactly one retry; persistent `401` → `ApiException.auth`.
- [ ] **Server error:** `PLT*` envelope or HTTP status → normalized `ApiException` with typed `kind`/`code`/`message`.

### Success Conditions
- [ ] All environments (Dev/Staging/Prod) route to their own Supabase project via `EnvironmentConfig` (no cross-contamination).
- [ ] Every outbound authenticated request carries a valid session token.
- [ ] All error paths resolve to a typed `ApiException` (no raw `DioException`/`SocketException`/`PostgREST` JSON leaks to callers).
- [ ] Logging captures method, path, status, and duration without exposing secrets.

### Error Handling Scenarios
- [ ] **Missing/uninitialized Supabase:** `supabase_client_provider` throws a clear, safe error (no config value leaked).
- [ ] **No access token:** Request proceeds without `Authorization` only on explicitly public routes; authenticated routes produce `ApiException.auth` rather than an unattached call.
- [ ] **Refresh failure:** One retry attempted; then `ApiException.auth` surfaced.
- [ ] **Retry budget exhausted:** Final failure normalized to `ApiException.network`/`timeout`/`server` as appropriate.
- [ ] **Malformed PostgREST body:** Mapper degrades safely to `unknown`/`server` without throwing during normalization.

### Important User Interactions
- [ ] No UI/UX surface in this task (per scope). The only "interaction" is developer/operator bootstrap wiring via `initializeApi(config)` (verified by EP-01-15 later).
- [ ] End-user impact is indirect: graceful 401 refresh prevents unexpected logout on expired sessions (verifiable via EP-01-09 integration).

---

## Technical Verification

### Architecture Compliance
- [ ] All code resides under `lib/core/api/` exactly as the §5.2 structure defines (no top-level `lib/` directories created outside ARCHITECTURE.md).
- [ ] No business logic, entity models, DTOs, repositories, datasources, or mappers introduced (transport-only boundary enforced).
- [ ] `String.fromEnvironment` is **not** used anywhere in `lib/core/api/` (only EP-01-03 loader may read compile-time values).
- [ ] No modification to `lib/main.dart`, bootstrap, UI, DB, auth framework, security, or monitoring code.

### Required System Behavior
- [ ] Supabase init reads **only** `EnvironmentConfig.supabaseConfig.url` + `.anonKey`.
- [ ] `AccessTokenProvider` default reads `Supabase.instance.client.auth.currentSession?.accessToken`.
- [ ] `ApiLogSink` default uses `developer.log` (no Sentry init; EP-01-14 wires later).
- [ ] Retry uses exponential backoff + jitter with a configurable, bounded max; exactly one 401-refresh-retry.
- [ ] Error interceptor runs last (`onError`) after retry is exhausted.

### Module Integration
- [ ] Consumes EP-01-03 `EnvironmentConfig` contract (no direct env-variable reads).
- [ ] Consumes EP-01-05 error contract: maps `PLT001`/`PLT002`/`PLT003`/`PLT004`/`PLT005`/`PLT999` appropriately.
- [ ] Exposes stable seams: `AccessTokenProvider` (EP-01-09), `ApiLogSink` (EP-01-14), interceptor registry (EP-01-10 SSL pinning) — none implemented here, only extension points.
- [ ] Dio instance reusable by future integration adapters under `integrations/`.

### Technical Requirements from the Plan
- [ ] `api_config.dart` defines timeouts + retry policy.
- [ ] `api_exception.dart` + `api_exception_mapper.dart` implemented (consume `PLT*` contract).
- [ ] `api_log_sink.dart` (interface + `developer.log` default) implemented.
- [ ] `access_token_provider.dart` (interface + Supabase-backed default) implemented.
- [ ] Four interceptors (`auth`, `logging`, `retry`, `error`) implemented.
- [ ] `api_client_factory.dart` (ordered chain, singleton Dio) implemented.
- [ ] `supabase_initializer.dart` + `supabase_client_provider.dart` implemented.
- [ ] `base_api_service.dart` implemented.
- [ ] `api_initializer.dart` (top-level entrypoint) implemented.

---

## Data Verification

> This task introduces **no business, user, or domain data**. Verification is limited to transport metadata and in-memory client state.

- [ ] No tokens, config values, or response bodies are persisted to local storage, cache, or logs.
- [ ] Environment endpoint metadata is sourced solely from the immutable `EnvironmentConfig` (already validated by EP-01-03); the API layer does not create, mutate, or store it.
- [ ] The layer holds only in-memory client instances and transient per-request state; no durable data relationships or accuracy concerns exist at this layer.
- [ ] `ApiException.data` carries only non-sensitive, typed error context (no raw payloads, no SQL, no PII).
- [ ] Request/response bodies are not written to logs (logging records path/status/duration only; bodies capped/redacted).

---

## Security Verification

### Authentication
- [ ] Auth interceptor attaches the current Supabase session access token to authenticated routes via `AccessTokenProvider`.
- [ ] Public routes are explicitly marked and skip token injection (no token sent where not required).
- [ ] `401` triggers `AccessTokenProvider.refresh()` then a single retry; refresh uses Supabase's own auth refresh (no hardcoded credential).

### Authorization
- [ ] Supabase client initialized with **anon key only**; service-role keys already rejected by EP-01-03 loader and never accepted by this layer.
- [ ] Client cannot switch environments at runtime (EP-01-03 invariant preserved — no build-time/env override added).

### Access Control
- [ ] No direct table/RPC access logic in the client; all enforcement remains server-side (AGENT.md Rule 4).
- [ ] `supabase_client_provider` exposes client only after initialization; uninitialized access fails closed with a safe error.

### Sensitive Data Protection
- [ ] `logging_interceptor` + `ApiLogSink` redact `Authorization` header and never log tokens, config values, or secret-bearing bodies.
- [ ] `ApiException.message` never embeds raw values, SQL, or sensitive data.
- [ ] No `print()` calls in production code (enforced by strict `analysis_options.yaml`).
- [ ] No service-role key, secret, or hardcoded endpoint present in `lib/core/api/` source.

### Security Rules
- [ ] Transport over HTTPS enforced by EP-01-03 URL validation; plain-HTTP loopback permitted only in Development (consistent with EP-01-03).
- [ ] SSL pinning deferred to EP-01-10 via an interceptor hook (no implementation here, but the seam exists).
- [ ] Retry logic cannot be abused to cause refresh storms (single 401-refresh-retry; bounded backoff).

---

## Performance Verification

### Response Performance
- [ ] Connect/read/write timeouts are explicit and environment-tunable via `api_config.dart`; no infinite hangs on poor networks.
- [ ] Retry backoff + jitter prevents thundering-herd on `5xx`.

### Resource Usage
- [ ] Exactly one Dio instance (connection pooling, keep-alive) — no per-request client creation.
- [ ] Interceptor chain is lightweight; logging avoids stringifying large bodies (size cap + redaction).
- [ ] No synchronous blocking I/O in interceptors.
- [ ] Negligible impact on the 15–20 MB base installer (no new packages, no assets added).

### System Reliability
- [ ] Transient failures auto-recover via bounded retry.
- [ ] Expired sessions auto-recover via single 401-refresh-retry without user-visible logout.
- [ ] Error normalization guarantees callers always receive a typed `ApiException` (no unhandled exception escape from the transport layer).

### Performance Expectations
- [ ] Retry budget is configurable and bounded (verified by unit test asserting max attempts).
- [ ] Exactly one 401-refresh-retry occurs (verified by unit test with mocked `AccessTokenProvider`).

---

## Testing Verification

### Automated Testing Requirements
- [ ] `test/unit/core/api/` exists with unit tests covering:
  - [ ] Auth interceptor attaches `Bearer` token; skips public routes.
  - [ ] Logging interceptor redacts `Authorization` and never logs config values (assert via mock `ApiLogSink`).
  - [ ] Retry interceptor retries transient errors with backoff; performs exactly one 401-refresh-retry; gives up after budget.
  - [ ] Error mapper maps each `DioExceptionType`, each HTTP status, and representative PostgREST `{code,message}` bodies to correct `ApiException.kind`; asserts no raw value leaks into `message`.
  - [ ] `AccessTokenProvider` default reads Supabase session; `refresh()` invoked on 401 (mocked Supabase auth).
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`).
- [ ] `flutter test` passes (all new unit tests green).

### Manual Testing Requirements
- [ ] Where toolchains exist: platform smoke build (Android/iOS/Web) passes with no native config changes.
- [ ] Optional manual inspection: initialize layer against a Development Supabase project (via EP-01-03 local loopback config) and confirm `platform_health` reachability through the Dio/Supabase clients (no production data touched).

### Edge Cases
- [ ] Uninitialized Supabase → safe failure, no config leak.
- [ ] Null/absent access token on authenticated route → `ApiException.auth`, not an unattached request.
- [ ] Malformed PostgREST error body → safe fallback to `unknown`/`server`.
- [ ] Repeated `5xx` → retry budget exhausted, then normalized failure (no infinite loop).
- [ ] `401` on a non-idempotent request → refresh + single retry only (no unsafe duplicate mutation assumption documented).

### Failure Scenarios
- [ ] Network down → `ApiException.network` after retry budget.
- [ ] Timeout → `ApiException.timeout` after retry budget.
- [ ] Refresh fails → `ApiException.auth` after single retry.
- [ ] Server `5xx` → `ApiException.server` (`PLT999`) after retry budget.
- [ ] Forbidden/`403` → `ApiException.forbidden` (`PLT002`) without retry.

---

## User Acceptance Verification

> No end-user UI in this task. Acceptance is verified at the developer/operator and integration level.

- [ ] Developer can call `initializeApi(config)` once at bootstrap and obtain a fully wired client (verified by EP-01-15 wiring).
- [ ] Every future feature's failure handling is uniform because all errors are typed `ApiException` (confirmed by mapper tests + later EP-01-08 usage).
- [ ] Debugging is possible without PII/secret exposure due to redacted, structured logs (confirmed by logging-interceptor test).
- [ ] Graceful 401 refresh prevents unexpected user logout on expired sessions (confirmed via `AccessTokenProvider` retry test + later EP-01-09 integration).
- [ ] No regressions: existing EP-01-02/03 tests and `flutter analyze`/`flutter test` remain green.

---

## Final Approval Checklist

- [ ] `lib/core/api/` contains the §5.2 module structure, all files implemented.
- [ ] Supabase initialized only via `EnvironmentConfig` (URL + anon key); no `String.fromEnvironment` outside EP-01-03 loader.
- [ ] Exactly one Dio instance with ordered interceptor chain (auth → logging → retry → error).
- [ ] Auth interceptor injects current session access token via `AccessTokenProvider`.
- [ ] `401` triggers token refresh + single retry; persistent `401` → `ApiException.auth`.
- [ ] Retry interceptor applies bounded exponential backoff + jitter on transient/`5xx`.
- [ ] `ApiException` + mapper normalize Dio/transport/PostgREST/`PLT*` errors with no secret/raw-value leakage.
- [ ] Logging interceptor + `ApiLogSink` redact `Authorization`, tokens, config values.
- [ ] `BaseApiService` exposes only Dio + Supabase through safe accessors; no business logic present.
- [ ] `api_initializer.initializeApi(EnvironmentConfig)` wires Supabase + Dio; `main.dart`/bootstrap unchanged (exported for EP-01-15).
- [ ] SSL-pinning and Sentry hooks are extension points only (no implementation).
- [ ] Unit tests cover mapping, interceptors, retry budget, token provider; all pass.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`).
- [ ] `flutter test` passes.
- [ ] Available platform smoke builds pass (no native config changed).
- [ ] No service-role key, secret, or hardcoded endpoint in source.
- [ ] No business logic, domain model, repository, auth framework, security, monitoring, UI, or DB code included.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-07 changes (`lib/core/api/` + `test/unit/core/api/`).
- [ ] Project lead has reviewed and signed off on this DoD checklist.

---
