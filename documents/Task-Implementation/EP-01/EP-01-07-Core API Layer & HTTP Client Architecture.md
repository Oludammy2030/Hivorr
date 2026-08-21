# TASK IMPLEMENTATION PLAN: EP-01-07

## Core API Layer & HTTP Client Architecture

---

## 1. Task Objective

Build the single client-to-backend communication channel in `lib/core/api/`, providing:

- A **Supabase client** initialized per environment (Dev/Staging/Prod) using the EP-01-03 `EnvironmentConfig` contract (URL + public anon key only).
- A **Dio HTTP client** with a composable interceptor chain for **auth token injection**, **401-triggered token refresh + single retry**, **normalized error handling**, **transient-failure retry**, and **structured request/response logging**.
- A **typed error-normalization layer** that maps the EP-01-05 server-side error contract (`PLT001`–`PLT999`) and transport failures into a single `ApiException` model.
- A **`BaseApiService`** abstract class that every future repository (EP-01-08+) extends, so no business system talks to Dio/Supabase directly and no business logic enters the transport layer.

**Dependency:** EP-01-02 (packages pinned) and EP-01-03 (config contract) — both completed. EP-01-05 (RPC error contract `PLT001`–`PLT999`) is consumed for error mapping.

---

## 2. Business Problem Being Solved

Without a centralized API layer:

- Repositories and business systems (EP-01-08+) would each instantiate their own Dio/Supabase clients, scattering auth, retry, and error-handling logic across the codebase.
- Auth tokens would be attached ad hoc; 401/expired-session handling would be inconsistent or absent, causing silent logout and failed requests in poor-connectivity (Nigeria) conditions.
- Server errors would surface as raw PostgREST/Dio errors (`SocketException`, `DioException`, PostgREST JSON) rather than typed, handleable exceptions — violating the clean error envelope established by EP-01-05.
- Environment endpoints would be hardcoded or read from env variables outside the loader, reopening the contamination/secret-leak risks EP-01-03 closed.
- The client would risk embedding logic it shouldn't (AGENT.md Rule 4) because there would be no enforced "transport-only" boundary.

This task is the **communication backbone** for the entire client; every data operation in EP-02+ flows through it.

---

## 3. Scope

### In Scope

- `lib/core/api/` module structure (see §5.2).
- Supabase client initialization bound to the EP-01-03 `EnvironmentConfig` (URL + anon key only; service-role keys already rejected upstream).
- Dio instance factory with a fixed interceptor chain.
- Interceptors:
  - **Auth interceptor** — attach current Supabase session access token to outbound Dio requests via an injectable `AccessTokenProvider` (default reads `Supabase.instance.client.auth.currentSession`).
  - **Error/normalization interceptor** — convert Dio/transport/PostgREST errors and `PLT*` codes into `ApiException`.
  - **Retry interceptor** — exponential-backoff retry on idempotent transient failures (timeout, connection reset, 500/502/503/504), with one 401-refresh-and-retry path.
  - **Logging interceptor** — structured request/response/error logging through a local `ApiLogSink` abstraction (default `developer.log`); EP-01-14 will later wire Sentry without changing this layer.
- Typed `ApiException` model + mapper covering: network, timeout, auth (`401`/`PLT001`), forbidden (`PLT002`), validation (`PLT003`), not-found (`PLT004`), conflict (`PLT005`), server (`PLT999`), unknown.
- `BaseApiService` abstract base providing safe access to the Dio client and Supabase client for repositories.
- Environment-aware endpoint configuration (base URL + timeouts + connect/read/write limits) sourced only from `EnvironmentConfig`.
- Unit tests for interceptors, token injection, error mapping, and retry behavior (no live backend; mock `AccessTokenProvider` / Dio `Interceptor` responses).
- Provider/initialization wiring hook so `lib/app/` bootstrap (EP-01-15) can initialize the API layer at startup.

### Out of Scope

- Business logic, domain models, DTOs, repositories, datasources, mappers — EP-01-08.
- Authentication framework, session persistence, route guarding — EP-01-09.
- SSL pinning, AES encryption, token rotation, secure storage wrappers — EP-01-10.
- Local storage, cache, offline sync queue — EP-01-11, EP-01-12.
- Connectivity monitoring — EP-01-13.
- Sentry initialization, PII-redacting logger concrete implementation — EP-01-14.
- App bootstrap, GoRouter, splash — EP-01-15.
- Supabase migrations, RPC, RLS, Edge Functions — EP-01-05/06.
- UI, design system, localization, notifications.
- Native platform configuration changes.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, or escrow logic is permitted in this layer. The API layer is **transport-only**.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles

- **Transport-only:** No entity models, no business decisions, no RPC-body construction beyond forwarding typed parameters from callers.
- **Single channel:** Exactly one Dio instance (configurable base URL) and one Supabase client; both constructed through factory functions, never ad hoc.
- **Interceptor composition over subclassing:** Behavior is added via ordered interceptors, keeping `BaseApiService` thin.
- **Fail-safe, never leak secrets:** Tokens are attached at request time from the provider; logs never print tokens, bodies containing secrets, or config values.
- **Zero-trust alignment:** Only the public anon key is ever held client-side; refresh uses Supabase's own auth refresh, never a hardcoded credential.

### 5.2 Proposed Structure

```text
lib/core/api/
├── api_config.dart                 # Timeouts, connect/read/write limits, retry policy
├── api_client/
│   ├── api_client_factory.dart     # Builds the singleton Dio with interceptor chain
│   ├── auth_interceptor.dart       # Attaches access token via AccessTokenProvider
│   ├── error_interceptor.dart      # Normalizes into ApiException
│   ├── retry_interceptor.dart      # Backoff retry + 401-refresh-retry
│   └── logging_interceptor.dart    # Structured logs via ApiLogSink
├── supabase/
│   ├── supabase_initializer.dart   # initialize(EnvironmentConfig) -> SupabaseClient
│   └── supabase_client_provider.dart # Safe accessor for the initialized client
├── auth/
│   └── access_token_provider.dart  # Interface + Supabase-backed default impl
├── exceptions/
│   ├── api_exception.dart          # Typed error model (code, kind, message, data)
│   └── api_exception_mapper.dart  # Dio/PostgREST/PLT* -> ApiException
├── logging/
│   └── api_log_sink.dart           # ApiLogSink interface + developer.log default
├── services/
│   └── base_api_service.dart       # Abstract base for repositories
└── api_initializer.dart            # Top-level initializeApi(EnvironmentConfig)
```

### 5.3 Supabase Client Initialization

- `supabase_initializer.initialize(EnvironmentConfig config)` calls `await Supabase.initialize(url: config.supabaseConfig.url, anonKey: config.supabaseConfig.anonKey)`.
- Reads **only** from the EP-01-03 contract; never reads `String.fromEnvironment` directly (preserving EP-01-03's single-loader rule).
- `supabase_client_provider` exposes `SupabaseClient` (or throws if not initialized) and surfaces `auth.currentSession?.accessToken` for the token provider.

### 5.4 Dio Interceptor Chain (order matters)

1. **Auth** — injects `Authorization: Bearer <token>` from `AccessTokenProvider`; skips routes explicitly marked public.
2. **Logging** — records method, URL (path only, no query secrets), status, duration; redacts `Authorization`.
3. **Retry** — on connection/timeout/`5xx`, retries with exponential backoff + jitter (max N attempts, configurable). On `401`, triggers `AccessTokenProvider.refresh()` then retries **once**; subsequent `401` becomes `ApiException.auth`.
4. **Error** — final `onError` normalization into `ApiException` (runs after retry exhausts).

### 5.5 Error Normalization (consuming EP-01-05)

The `api_exception_mapper` maps:
- `DioExceptionType.connectionTimeout / sendTimeout / receiveTimeout` → `ApiException.timeout`.
- `DioExceptionType.connectionError / unknown (SocketException)` → `ApiException.network`.
- HTTP `401` → `ApiException.auth` (`PLT001`).
- `403` → `ApiException.forbidden` (`PLT002`).
- `404` → `ApiException.notFound` (`PLT004`); `409` → `ApiException.conflict` (`PLT005`).
- `422`/`400` with `PLT003` in PostgREST `code` → `ApiException.validation`.
- `5xx` → `ApiException.server` (`PLT999`).
- PostgREST error body `{code, message, details}` parsed; `code` honored if present.
- **No raw values or SQL surfaced** — messages are safe, typed, and loggable (per the AGENT.md/EP-01-05 contract).

### 5.6 `BaseApiService`

Abstract class holding:
- `Dio get dio` (the configured instance)
- `SupabaseClient get supabase`
- Helper `safeInvoke`/`handle` wrapper that wraps calls in `try/catch` and re-throws `ApiException`.

Repositories (EP-01-08) extend this; they never construct Dio or call Supabase primitives except through it.

### 5.7 Extensibility Hooks (for later tasks)

- `AccessTokenProvider` interface lets EP-01-09 replace/augment token sourcing and refresh without touching interceptors.
- `ApiLogSink` lets EP-01-14 route logs to Sentry.
- Dio interceptor list is built from a registry so EP-01-10 can insert an SSL-pinning/security interceptor without modifying core logic.

### 5.8 Initialization Wiring

`api_initializer.initializeApi(EnvironmentConfig)` initializes Supabase, builds the Dio singleton, and registers interceptors. `lib/app/` (EP-01-15) will call this during bootstrap — **this task does not modify `main.dart` or bootstrap**; it only exports the initializer.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `EnvironmentConfig` | `lib/config/environments/` (EP-01-03) | Source of URL + anon key |
| `api_config.dart` | `lib/core/api/` | Timeouts, retry policy |
| `api_client_factory.dart` | `lib/core/api/api_client/` | Singleton Dio + interceptor chain |
| Auth/Error/Retry/Logging interceptors | `lib/core/api/api_client/` | Cross-cutting HTTP behavior |
| `supabase_initializer.dart` | `lib/core/api/supabase/` | Per-env Supabase init |
| `access_token_provider.dart` | `lib/core/api/auth/` | Token source + refresh hook |
| `api_exception*.dart` | `lib/core/api/exceptions/` | Typed errors + mapper |
| `api_log_sink.dart` | `lib/core/api/logging/` | Pluggable log sink |
| `base_api_service.dart` | `lib/core/api/services/` | Repository base |
| `api_initializer.dart` | `lib/core/api/` | Top-level init entrypoint |
| Test suite | `test/unit/core/api/` | Interceptor, mapping, retry tests |

No new dependency added (Dio + Supabase already pinned in EP-01-02).

---

## 7. Data Requirements

No business, user, or domain data is introduced. The layer carries only:
- Environment endpoint metadata (from `EnvironmentConfig`, already validated).
- In-memory client instances and transient request/response state.

It must never persist tokens, config, or responses to storage or logs.

---

## 8. Database Considerations

**Not applicable** to this client task. Supabase is consumed only as a client. No migrations, RPC, or RLS here (EP-01-05/06). The layer merely forwards calls; all enforcement remains server-side (AGENT.md Rule 4).

---

## 9. API Requirements

- **No new endpoints** are defined. The layer is the HTTP/RPC transport consumer.
- Defines the **client-side consumption contract** for EP-01-05 RPCs: attach auth header, normalize `PLT*` envelopes, retry transient failures.
- Exposes environment-aware base URL for the Dio instance (from `EnvironmentConfig`); external integration adapters (EP integrations/, later) will reuse this Dio.

---

## 10. User Interface Requirements

**Not applicable.** No widgets, screens, or routing. The initializer is exported for EP-01-15 but `main.dart` is unchanged.

---

## 11. User Experience Considerations

Developer/operator experience only:
- One-call `initializeApi(config)` produces a fully wired client.
- Consistent typed errors make every future feature's failure handling uniform.
- Structured, secret-free logs ease debugging without PII/secret exposure.
- Graceful 401 refresh prevents unexpected user logout on expired sessions.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Secret leakage in logs | `logging_interceptor` and `ApiLogSink` redact `Authorization`, tokens, and config values; `ApiException` never embeds secrets |
| Hardcoded endpoints/credentials | All endpoint + key values come exclusively from `EnvironmentConfig` (EP-01-03), never literals |
| Service-role key in client | Supabase init uses anon key only; service-role rejection already enforced by EP-01-03 loader |
| Token interception / MITM | Transport over HTTPS (enforced by EP-01-03 URL validation); SSL pinning deferred to EP-01-10 via interceptor hook |
| Expired-session lockout | 401 → `AccessTokenProvider.refresh()` → one retry; avoids silent logout |
| Raw error/SQL leakage to UI | `api_exception_mapper` sanitizes; only typed `code`/`kind`/`message` exposed |
| Business logic in client | Layer is strictly transport-only; no entity/RPC-body decisions |
| Unauthorized env access | Client cannot switch environments at runtime (EP-01-03 invariant preserved) |

---

## 13. Performance Considerations

- Single Dio instance (connection pooling, keep-alive) — no per-request clients.
- Interceptor chain is lightweight; logging avoids stringifying large bodies (size cap + redaction).
- Retry uses exponential backoff + jitter with a bounded max to avoid thundering-herd on `5xx`.
- Only one 401-refresh-retry to prevent refresh storms.
- Timeouts (connect/read/write) explicit and environment-tunable via `api_config.dart`; no infinite hangs on poor networks.
- No synchronous blocking I/O in interceptors.
- Negligible impact on the 15–20 MB installer (no new packages, no assets).

---

## 14. Testing Strategy

### 14.1 Unit — Interceptors
- Auth interceptor attaches `Bearer` token from `AccessTokenProvider`; skips public routes.
- Logging interceptor redacts `Authorization` and never logs config values (assert via mock `ApiLogSink`).
- Retry interceptor retries transient errors with backoff; performs exactly one 401-refresh-retry; gives up after budget.

### 14.2 Unit — Error Mapping
- Map each `DioExceptionType`, each HTTP status, and representative PostgREST `{code,message}` bodies to the correct `ApiException.kind`; assert no raw value leaks into `message`.

### 14.3 Unit — Token Provider
- `AccessTokenProvider` default reads Supabase session; `refresh()` path invoked on 401 (mocked Supabase auth).

### 14.4 Project Validation
- `flutter analyze` (strict lints; no `print` in production).
- `flutter test` — all new unit tests pass.
- Where toolchains exist: platform smoke build without native changes.

### 14.5 Scope Validation
- Diff review: only `lib/core/api/` + `test/unit/core/api/` + minimal `pubspec`/`analysis_options` unchanged. No bootstrap, UI, DB, auth-framework, security, or monitoring implementation leaked in. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-02/03 deliverables and confirm `lib/core/api/` is empty (`.gitkeep` only).
2. Create `api_config.dart` (timeouts, retry policy constants).
3. Implement `api_exception.dart` + `api_exception_mapper.dart` (consume `PLT*` contract from EP-01-05).
4. Implement `api_log_sink.dart` (interface + `developer.log` default).
5. Implement `access_token_provider.dart` (interface + Supabase-backed default).
6. Implement the four interceptors (`auth`, `logging`, `retry`, `error`).
7. Implement `api_client_factory.dart` (ordered chain, singleton Dio).
8. Implement `supabase_initializer.dart` + `supabase_client_provider.dart`.
9. Implement `base_api_service.dart`.
10. Implement `api_initializer.dart` (top-level init entrypoint).
11. Add `test/unit/core/api/` unit tests for mapping, interceptors, retry, token provider.
12. Run `flutter analyze` and `flutter test`.
13. Perform available platform smoke builds (no native changes).
14. Review final diff for strict EP-01-07 scope containment and phase-document integrity.
15. **Stop at the approval gate** — do not wire `main.dart`, build repositories, or implement downstream tasks.

---

## 16. Expected Outcome

- A single, environment-aware Supabase client and Dio instance, both sourcing config solely from EP-01-03.
- A composable interceptor chain delivering auth injection, 401-refresh-retry, transient retry, error normalization, and secret-free logging.
- A typed `ApiException` model that consumes the EP-01-05 `PLT001`–`PLT999` contract consistently across all future features.
- A `BaseApiService` boundary guaranteeing repositories never touch Dio/Supabase primitives directly and never embed business logic.
- Unit tests proving interceptor, mapping, and retry behavior without a live backend.
- Clean extensibility hooks for EP-01-09 (token provider), EP-01-10 (SSL pinning), and EP-01-14 (Sentry logging).

---

## 17. Definition of Done (DoD)

- [ ] `lib/core/api/` contains the module structure in §5.2, all files implemented.
- [ ] Supabase initialized only via `EnvironmentConfig` (URL + anon key); no `String.fromEnvironment` usage outside EP-01-03 loader.
- [ ] Exactly one Dio instance with the ordered interceptor chain (auth → logging → retry → error).
- [ ] Auth interceptor injects the current session access token via `AccessTokenProvider`.
- [ ] 401 triggers token refresh + single retry; persistent 401 → typed `ApiException.auth`.
- [ ] Retry interceptor applies bounded exponential backoff + jitter on transient/`5xx` failures.
- [ ] `ApiException` + mapper normalize Dio/transport/PostgREST/`PLT*` errors with no secret/raw-value leakage.
- [ ] Logging interceptor + `ApiLogSink` redact `Authorization`, tokens, and config values.
- [ ] `BaseApiService` exposes only Dio + Supabase through safe accessors; no business logic present.
- [ ] `api_initializer.initializeApi(EnvironmentConfig)` wires Supabase + Dio; `main.dart`/bootstrap unchanged (exported for EP-01-15).
- [ ] SSL-pinning and Sentry hooks are extension points only (no implementation).
- [ ] Unit tests cover mapping, interceptors, retry budget, and token provider; all pass.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`).
- [ ] `flutter test` passes.
- [ ] Available platform smoke builds pass (no native config changed).
- [ ] No service-role key, secret, or hardcoded endpoint in source.
- [ ] No business logic, domain model, repository, auth framework, security, monitoring, UI, or DB code included.
- [ ] The approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-07 changes.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Very High**

### Reasoning Level Justification

- **Technical complexity:** High — designing a correct interceptor ordering, safe 401-refresh-and-retry-without-storm logic, accurate `PLT*` error mapping, and a clean extensibility boundary across Dio + Supabase requires precise reasoning where mistakes cause silent auth failures, infinite retry loops, or leaked secrets.
- **Business impact:** Critical — every EP-02+ data operation depends on this channel; flaws propagate platform-wide.
- **Security risk:** High — token handling, log redaction, anon-key-only enforcement, and prevention of secret leakage are security-sensitive even though zero-trust enforcement itself stays server-side.
- **Performance sensitivity:** Medium-high — retry/backoff policy, connection reuse, and timeout tuning directly affect behavior on unreliable Nigerian networks and must avoid thundering herds.
- **Data complexity:** Low — no business/domain data; only transport metadata and typed errors.
- **Integration complexity:** Very high — must cleanly consume EP-01-03's config contract and EP-01-05's error contract, while exposing stable seams for EP-01-08/09/10/14/15 without coupling them to implementation details.

Very High reasoning matches the approved EP-01 matrix (EP-01-07 = Very High) and the foundational, cross-cutting nature of the task.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-07-Core API Layer & HTTP Client Architecture.md` and implementation will begin only after a separate implementation approval. No production code is written during planning.

---
