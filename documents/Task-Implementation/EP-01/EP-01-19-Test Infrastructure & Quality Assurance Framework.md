# TASK IMPLEMENTATION PLAN: EP-01-19

## Test Infrastructure & Quality Assurance Framework

| Field | Value |
|---|---|
| Task ID | EP-01-19 |
| Task Name | Test Infrastructure & Quality Assurance Framework |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Done (implemented & verified — 2026-08-28) |
| Dependencies | EP-01-04 (CI/CD Pipeline — completed; provides GitHub Actions workflows running `flutter test` as a blocking gate). EP-01-07 (Core API Layer — completed; provides `BaseApiService`, `Dio` interceptors, `SupabaseClient`, `ApiExceptionMapper`, `AccessTokenProvider` requiring mock factories). Consumed downstream by EP-01-20 (Phase Integration Validation). |
| Priority | High |
| Planning Reasoning | High (approved EP-01 matrix) |
| Coding Reasoning | High (approved EP-01 matrix) |

---

## 1. Task Objective

Establish the comprehensive test infrastructure, mock factories, test data builders, and reference test patterns that define the quality bar for the entire Hivorr project — consolidating existing ad-hoc test utilities into a coherent, reusable framework and filling critical gaps:

- **Centralized Test Utilities Module** — a `test/support/` directory consolidating shared test infrastructure (fakes, builders, harnesses) into well-organized, importable modules that eliminate duplication across the existing ~88 test files.
- **Mock Supabase Client Factory** — a `MockSupabaseClientFactory` providing one-call creation of fully configurable fake Supabase clients (fake `GoTrueClient`, fake `SupabaseClient`, scriptable auth state, scriptable RPC responses) for CI testing without live backends.
- **Mock API Service Factory** — a `MockApiServiceFactory` providing one-call creation of test-configured `Dio` instances with scriptable `HttpClientAdapter` responses, fake token providers, and fake exception mappers for testing any service that extends `BaseApiService`.
- **Test Data Builders** — fluent builder classes for constructing domain entities, DTOs, and configuration objects with sensible defaults and selective overrides (e.g., `EntityProfileBuilder().withEmail('test@test.com').build()`).
- **Repository Test Pattern** — a complete reference unit test for `EntityRepositoryImpl` demonstrating the canonical pattern: fake datasources injected, cache-first reads verified, write-through behavior asserted, error propagation tested.
- **Widget Test Pattern** — reference widget tests for the design system (`lib/shared/`) demonstrating the canonical pattern: themed `MaterialApp` wrapper, pump-and-settle, responsive breakpoint testing.
- **Integration Test Scaffolding** — a scaffolded integration test for the authentication flow demonstrating the canonical pattern: real app bootstrap, fake backend injection, multi-step user journey assertion.
- **CI Test Enhancement** — extend the existing `reusable-validation.yml` to add test coverage collection (`flutter test --coverage`) and test report output, establishing the coverage baseline for EP-02+.

**Dependency note:** EP-01-19 depends on EP-01-04 (CI/CD pipelines) and EP-01-07 (API layer) per the approved matrix. This task consolidates and extends test utilities already created by EP-01-07 through EP-01-18 into a coherent framework. It does not modify production code in `lib/` — it creates test infrastructure in `test/` and enhances CI configuration in `.github/workflows/`.

---

## 2. Business Problem Being Solved

Without a formalized test infrastructure and quality assurance framework:

- **Inconsistent test patterns.** The existing ~88 test files use ad-hoc fakes scattered across 13+ helper files with no centralized module. New developers (human or AI) must rediscover patterns for each test file, leading to inconsistent quality and duplicated effort.
- **No standardized mock factories.** Each subsystem creates its own fake Supabase clients, fake API services, and fake datasources independently. There is no one-call factory for creating test-ready Supabase or API infrastructure.
- **No test data builders.** Domain entities, DTOs, and configuration objects are constructed inline in test files with hardcoded values — making tests brittle and verbose.
- **No reference test patterns.** There is no canonical "how to test a repository" or "how to test a widget" reference that EP-02+ feature developers can follow.
- **No integration test scaffolding.** The `integration_test/` directory is empty. Existing integration tests use `flutter_test` rather than the standard `integration_test` package.
- **No test coverage visibility.** CI runs `flutter test` with no `--coverage` flag — zero visibility into which code paths are tested.
- **EP-01-20 phase validation requires test infrastructure.** Without standardized test infrastructure, EP-01-20 must build its own test harness from scratch.
- **EP-02+ quality at risk.** Every feature built in EP-02 through EP-08 needs tests. Without established patterns and factories, test quality degrades as the codebase grows.

This is the **quality backbone** — it transforms ad-hoc testing into a disciplined, repeatable, scalable practice.

---

## 3. Scope

### In Scope

- `test/support/` directory: centralized test infrastructure modules.
  - `test/support/fakes/` — consolidated fake implementations (Supabase, API, auth, storage, network).
  - `test/support/factories/` — mock factory classes (Supabase client, API service).
  - `test/support/builders/` — fluent test data builders (entities, DTOs, configs).
  - `test/support/harnesses/` — test harnesses (Sentry recording, widget pump helpers, async helpers).
  - `test/support/matchers/` — custom test matchers for domain-specific assertions.
  - `test/support/support.dart` — barrel export for all test support infrastructure.
- **MockSupabaseClientFactory** — one-call fake Supabase client creation with configurable auth state, scriptable RPC handlers, and scriptable query results.
- **MockApiServiceFactory** — one-call test-configured `Dio` and `BaseApiService` creation with scriptable responses and optional interceptor stack.
- **Test Data Builders** — `EntityProfileBuilder`, `EntityRoleBuilder`, `EntityBuilder`, `EntityProfileDtoBuilder`, `ApiConfigBuilder`.
- **Custom Matchers** — `isApiException()`, `isEntityProfile()`, `hasLoadingState()`, `hasErrorState()`, `hasLoadedState()`.
- **Reference Repository Unit Test** — canonical pattern for `EntityRepositoryImpl`.
- **Reference Widget Tests** — canonical pattern for design system atomic widgets.
- **Integration Test Scaffolding** — scaffolded auth flow integration test.
- **CI Enhancement** — `flutter test --coverage` + coverage artifact upload in `reusable-validation.yml`.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope

- Modifying any production code in `lib/`.
- Writing tests for every existing module — this task establishes patterns; EP-02+ tasks write their own tests.
- Server-side test infrastructure (pgTAP, Supabase test DB) — already handled by `database-rls-tests.yml`.
- End-to-end device testing on physical devices.
- Golden image testing — `golden_toolkit` not in `pubspec.yaml`; deferred to EP-02+.
- Performance/benchmark testing — deferred to EP-02+.
- Mutation testing — not in scope for EP-01.
- Test coverage thresholds/enforcement — this task establishes collection; threshold enforcement deferred to EP-02+.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No production code in `lib/` is modified by this task. The test infrastructure layer **enables testing**; it does not implement, authorize, compute, or decide outcomes. It must never contain business logic, proprietary algorithms, or financial rules. All fakes and mocks simulate infrastructure behavior only — they do not replicate server-side enforcement (RLS, RPC). The test infrastructure operates purely as a development-time quality assurance layer — all server-side enforcement remains authoritative and is tested via the existing `database-rls-tests.yml` workflow (AGENT.md Rule 4). No secrets, tokens, or credentials are hardcoded in test files.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| No production code modification | Test infrastructure only; `lib/` unchanged |
| Hand-rolled fakes pattern | Established project convention — no `mockito`/`mocktail` |
| Consolidation over duplication | Centralize existing scattered fakes into `test/support/` |
| One-call factory pattern | Complex test setup reduced to single factory call |
| Fluent builder pattern | Test data construction with sensible defaults + selective overrides |
| CI-tested | All test infrastructure validated via `flutter test` in CI |
| No hardcoded secrets | Placeholder constants only; no real credentials |
| Reference patterns | Canonical examples for repository, widget, and integration testing |

### 5.2 Proposed Structure

```text
test/
├── support/
│   ├── fakes/
│   │   ├── fake_supabase.dart          # FakeSupabaseClient, FakeGoTrueClient
│   │   ├── fake_api.dart               # StubAdapter, ScriptedAdapter, FakeTokenProvider
│   │   ├── fake_auth.dart              # FakeSupabaseAuthService, FakeAuthProvider
│   │   ├── fake_storage.dart           # InMemorySecureStorage, FakeFlutterSecureStorage
│   │   ├── fake_network.dart           # FakeConnectivityMonitor, FakeNetworkStatusProvider
│   │   └── fake_datasource.dart        # FakeEntityRemoteDataSource, FakeEntityLocalDataSource
│   ├── factories/
│   │   ├── mock_supabase_client_factory.dart
│   │   └── mock_api_service_factory.dart
│   ├── builders/
│   │   ├── entity_builders.dart         # EntityBuilder, EntityProfileBuilder, EntityRoleBuilder
│   │   ├── dto_builders.dart           # EntityProfileDtoBuilder, EntityRoleDtoBuilder
│   │   └── config_builders.dart        # ApiConfigBuilder, AppConfigBuilder
│   ├── harnesses/
│   │   ├── widget_harness.dart         # pumpTheme(), pumpApp(), pumpScreen()
│   │   ├── sentry_harness.dart         # SentryRecordingHarness
│   │   └── async_harness.dart          # pumpUntil()
│   ├── matchers/
│   │   ├── api_matchers.dart           # isApiException(), hasStatusCode(), hasErrorKind()
│   │   ├── entity_matchers.dart        # isEntityProfile(), hasEntityId(), hasRole()
│   │   └── state_matchers.dart         # hasLoadingState(), hasErrorState(), hasLoadedState()
│   └── support.dart                    # Barrel export
├── unit/data/
│   └── entity_repository_reference_test.dart
├── widget/shared/
│   └── design_system_reference_test.dart
└── integration/
    └── auth_flow_reference_test.dart
```

### 5.3 MockSupabaseClientFactory

One-call creation of a fully configurable fake Supabase client:

```dart
class MockSupabaseClientFactory {
  static FakeSupabaseClient create({
    FakeUser? currentUser,
    FakeSession? currentSession,
    AuthState initialState = AuthState.signedOut,
    Map<String, dynamic Function(Map<String, dynamic>)>? rpcHandlers,
    List<Map<String, dynamic>>? queryResults,
    Object? queryError,
  });
}
```

**Capabilities:** Configurable auth state, scriptable RPC responses by function name, scriptable query results with optional error injection, auth state change simulation. Compatible with existing `FakeSupabaseClient`/`FakeGoTrueClient` from `auth_fakes.dart`.

### 5.4 MockApiServiceFactory

One-call creation of test-configured `Dio` and `BaseApiService`:

```dart
class MockApiServiceFactory {
  static Dio create({
    List<ScriptedResponse> responses = const [],
    String? accessToken,
    bool enableAuthInterceptor = false,
    bool enableRetryInterceptor = false,
    bool enableLoggingInterceptor = false,
  });

  static BaseApiService createService({
    List<ScriptedResponse> responses = const [],
    String? accessToken,
    FakeSupabaseClient? supabaseClient,
  });
}
```

**Capabilities:** Scriptable HTTP responses via `ScriptedAdapter`, optional interceptor stack, one-call `BaseApiService` creation. Compatible with existing `StubAdapter`, `ScriptedAdapter`, `FakeTokenProvider`, `RecordingLogSink`.

### 5.5 Test Data Builders

Fluent builder pattern with sensible defaults:

- **EntityProfileBuilder** — `withId()`, `withDisplayName()`, `withEmail()`, `withPhone()`, `withAvatarUrl()`, `withStatus()` → `build()` returns `EntityProfile`.
- **EntityRoleBuilder** — `withId()`, `withEntityId()`, `withRoleType()`, `withIsActive()` → `build()` returns `EntityRole`.
- **EntityBuilder** — `withProfile()`, `withRoles()`, `addRole()` → `build()` returns `Entity` aggregate.
- **EntityProfileDtoBuilder** — same field overrides + `build()` returns DTO, `toMap()` returns JSON map.
- **ApiConfigBuilder** — `withConnectTimeout()`, `withReceiveTimeout()`, `withMaxRetries()`, `withRetryBaseDelay()` → `build()` returns `ApiConfig`.

### 5.6 Custom Matchers

- **API Matchers:** `isApiException(kind:, messageContains:)`, `hasStatusCode()`, `hasErrorKind()`.
- **Entity Matchers:** `isEntityProfile(id:, displayName:)`, `hasEntityId()`, `hasRole()`.
- **State Matchers:** `hasLoadingState()`, `hasErrorState(messageContains:)`, `hasLoadedState()`.

### 5.7 Test Harnesses

- **Widget Harness:** `pumpTheme()` (themed MaterialApp), `pumpApp()` (with providers), `pumpScreen()` (with viewport size management + teardown).
- **Sentry Harness:** `SentryRecordingHarness` — `setUp()`, `reset()`, `capturedEvents`, `capturedBreadcrumbs`, `lastEvent`, `lastBreadcrumb`.
- **Async Harness:** `pumpUntil(tester, condition, timeout:)` — polls until condition is met or timeout expires.

### 5.8 Reference Repository Unit Test

Canonical pattern for `EntityRepositoryImpl`:
- Fake datasource injection via `setUp()`.
- Cache-first read: local data returned without remote call.
- Remote fetch: remote data returned when local cache empty, write-through to local verified.
- Error propagation: remote error throws typed `ApiException`.
- Write-through: `updateProfile()` writes to both remote and local.
- Uses builders for data construction and matchers for assertions.

### 5.9 Reference Widget Tests

Canonical pattern for design system widgets:
- `HivorrButton` renders with label, calls `onPressed` on tap, disabled state prevents interaction.
- `HivorrTextField` validates input and shows error message.
- `HivorrCard` renders correctly at mobile (390px) and web (1280px) widths.
- Uses `pumpTheme()` and `pumpScreen()` harnesses.

### 5.10 Integration Test Scaffolding

Canonical pattern for auth flow:
- `setUp()` creates `MockSupabaseClientFactory` and `FakeSupabaseAuthService`.
- Sign-in test: configure fake to accept credentials → pump app → enter credentials → assert navigation to home.
- Invalid credentials test: configure fake to reject → assert error message displayed.
- Sign-out test: start signed-in → trigger sign-out → assert navigation to login.

### 5.11 CI Enhancement

Extend `reusable-validation.yml`:
- Replace `flutter test` with `flutter test --coverage`.
- Add `actions/upload-artifact@v4` step uploading `coverage/` directory with 14-day retention.

### 5.12 Consolidation Strategy

Existing 13+ test helper files preserved (not deleted) but updated to re-export from `test/support/` — ensuring zero breakage of existing test imports:

| Existing File | Consolidated Into |
|---|---|
| `test/test_helpers.dart` | `test/support/fakes/fake_auth.dart`, `fake_storage.dart`, `harnesses/widget_harness.dart` |
| `test/unit/core/api/test_helpers.dart` | `test/support/fakes/fake_api.dart` |
| `test/unit/core/authentication/auth_fakes.dart` | `test/support/fakes/fake_supabase.dart`, `fake_auth.dart` |
| `test/unit/core/sync/sync_test_helpers.dart` | `test/support/fakes/fake_api.dart` |
| `test/unit/core/notifications/notification_test_helpers.dart` | `test/support/fakes/` (notification fakes) |
| `test/unit/core/storage/fakes.dart` | `test/support/fakes/fake_storage.dart` |
| `test/unit/core/security/token/fakes.dart` | `test/support/fakes/fake_auth.dart` |
| `test/unit/core/test_sentry_helper.dart` | `test/support/harnesses/sentry_harness.dart` |
| `test/unit/core/logging/test_logging_helpers.dart` | `test/support/harnesses/` |
| `test/unit/data/entity_fakes.dart` | `test/support/fakes/fake_datasource.dart` |
| `test/widget/shared/test_helpers.dart` | `test/support/harnesses/widget_harness.dart` |

### 5.13 Extensibility Hooks

- `MockSupabaseClientFactory` → EP-02+ features add RPC handlers for marketplace, commerce, logistics.
- `MockApiServiceFactory` → EP-02+ features script API responses for their endpoints.
- Test data builders → EP-02+ features add builders for `ServiceListing`, `Order`, `Payment`, etc.
- Custom matchers → EP-02+ features add domain-specific matchers.
- Widget harness → EP-02+ screens use `pumpScreen()` for consistent responsive testing.
- Integration scaffolding → EP-02+ features scaffold their own integration tests.
- CI coverage → EP-02+ can add threshold enforcement.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| Existing test fakes | `test/unit/core/*/` (EP-01-07 through EP-01-18) | Source fakes to consolidate |
| `MockSupabaseClientFactory` | `test/support/factories/` | One-call fake Supabase client creation |
| `MockApiServiceFactory` | `test/support/factories/` | One-call fake API service creation |
| Entity/DTO/Config builders | `test/support/builders/` | Fluent test data construction |
| API/Entity/State matchers | `test/support/matchers/` | Domain-specific test assertions |
| Widget/Sentry/Async harnesses | `test/support/harnesses/` | Standardized test setup helpers |
| `support.dart` barrel | `test/support/` | Single import for all test infrastructure |
| Reference repository test | `test/unit/data/` | Canonical repository test pattern |
| Reference widget tests | `test/widget/shared/` | Canonical widget test pattern |
| Reference integration test | `test/integration/` | Canonical integration test scaffold |
| CI coverage enhancement | `.github/workflows/reusable-validation.yml` | `flutter test --coverage` + artifact upload |

**No new production or test dependencies required.** Reuses `flutter_test` (SDK) exclusively with hand-rolled fakes.

---

## 7. Data Requirements

- Test data builders produce domain entities and DTOs with placeholder values only — no real user data, no real credentials.
- Mock factories produce fake infrastructure objects with configurable behavior — no live backend connections.
- All test data uses UUID-like placeholder IDs (`'test-entity-001'`), placeholder emails (`'test@hivorr.com'`), and placeholder tokens (`'test-token'`).
- No business, financial, or domain data is persisted. No tokens, secrets, or credentials are hardcoded.

---

## 8. Database Considerations

**Not applicable.** Test infrastructure only. All server-side schema, RPC, and RLS remain owned by EP-01-05/06. `MockSupabaseClientFactory` simulates Supabase client behavior in-memory — no database connection. Server-side database testing handled by `database-rls-tests.yml`.

---

## 9. API Requirements

No new network endpoints/RPCs. `MockApiServiceFactory` creates `Dio` instances with `ScriptedAdapter` that intercept HTTP calls in-memory — no network traffic. `MockSupabaseClientFactory` returns scripted responses — no Supabase connection. No interceptor modifications to EP-01-07 production code.

---

## 10. User Interface Requirements

**Not applicable.** No production widgets, screens, or routing. Widget harness provides test-time UI wrapping only. Reference widget tests exercise existing design system widgets — no new UI created.

---

## 11. User Experience Considerations

Developer experience only:
- One-call factories eliminate 20+ lines of boilerplate per test file.
- Fluent builders replace verbose entity construction.
- Custom matchers provide readable assertions.
- Barrel import (`import 'support/support.dart';`) gives any test file access to all infrastructure.
- Reference patterns — EP-02+ developers copy-paste and customize.
- Backward compatibility — existing tests continue to work via re-exports.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Hardcoded secrets in test files | Placeholder constants only. No real Supabase URLs, API keys, tokens, or credentials. |
| Test data resembling real PII | Clearly synthetic placeholders (`test@hivorr.com`, `test-entity-001`, `test-token`). |
| Fake auth bypassing security | Fakes simulate auth behavior for testing only — no real authentication logic. |
| CI coverage artifact exposure | Coverage reports as GitHub Actions artifacts with 14-day retention. No secrets in output. |
| Test infrastructure in production | Test code in `test/` only — never compiled into production builds. |
| Mock factories leaking to production | Factories in `test/support/` — never imported by `lib/` code. |
| Business logic in test fakes | Fakes simulate infrastructure only — no RLS, RPC validation replication. |

---

## 13. Performance Considerations

- Hand-rolled fakes are faster than mocking frameworks (no code generation, no reflection).
- Existing ~88 tests run within the 20-minute CI timeout. Reference tests + coverage add ~2–3 minutes.
- `flutter test --coverage` adds ~10–20% execution time. Developers run `flutter test` locally without coverage.
- Builder performance: negligible allocation cost for small value objects.
- No new dependencies. Zero impact on the 15–20 MB installer target.
- Test infrastructure objects are short-lived — created in `setUp()`, discarded in `tearDown()`.

---

## 14. Testing Strategy

### 14.1 Unit — MockSupabaseClientFactory
- `create()` with no args → signed-out state. Configurable auth, RPC handlers, query results, error injection.

### 14.2 Unit — MockApiServiceFactory
- `create()` → `Dio` with `ScriptedAdapter`, no interceptors. Configurable responses, token, interceptor stack. `createService()` → `BaseApiService` with fake Dio + fake Supabase.

### 14.3 Unit — Test Data Builders
- Default values, selective overrides, `toMap()` for DTO builders.

### 14.4 Unit — Custom Matchers
- `isApiException`, `isEntityProfile`, state matchers — readable failure messages.

### 14.5 Unit — Widget Harness
- `pumpTheme`, `pumpApp`, `pumpScreen` with viewport management and teardown.

### 14.6 Unit — Reference Repository Test
- Fake injection, cache-first read, remote fetch, write-through, error propagation. All pass.

### 14.7 Widget — Reference Widget Tests
- Themed pump, button interaction, disabled state, input validation, responsive breakpoints. All pass.

### 14.8 Integration — Reference Integration Test
- Fake backend injection, sign-in, invalid credentials, sign-out. Compiles and scaffolds correctly.

### 14.9 CI Validation
- `flutter analyze` passes. `flutter test --coverage` passes and generates coverage. Artifact uploaded. All existing ~88 tests pass.

### 14.10 Scope Validation
- Diff review: only `test/support/` (new), reference tests (new), existing helpers (re-exports), CI workflow (coverage). No `lib/` modifications. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-04 and EP-01-07 deliverables; confirm CI workflow structure and API layer classes.
2. Audit existing test helper files in `test/` to catalog all fakes, stubs, and harnesses for consolidation.
3. Create `test/support/` directory structure: `fakes/`, `factories/`, `builders/`, `harnesses/`, `matchers/`.
4. Implement `test/support/fakes/fake_supabase.dart` — consolidate from `auth_fakes.dart`.
5. Implement `test/support/fakes/fake_api.dart` — consolidate from API and sync test helpers.
6. Implement `test/support/fakes/fake_auth.dart` — consolidate from auth and security test helpers.
7. Implement `test/support/fakes/fake_storage.dart` — consolidate from storage test helpers.
8. Implement `test/support/fakes/fake_network.dart` — `FakeConnectivityMonitor`, `FakeNetworkStatusProvider`.
9. Implement `test/support/fakes/fake_datasource.dart` — consolidate from data test helpers.
10. Implement `test/support/factories/mock_supabase_client_factory.dart`.
11. Implement `test/support/factories/mock_api_service_factory.dart`.
12. Implement `test/support/builders/entity_builders.dart`.
13. Implement `test/support/builders/dto_builders.dart`.
14. Implement `test/support/builders/config_builders.dart`.
15. Implement `test/support/matchers/api_matchers.dart`.
16. Implement `test/support/matchers/entity_matchers.dart`.
17. Implement `test/support/matchers/state_matchers.dart`.
18. Implement `test/support/harnesses/widget_harness.dart`.
19. Implement `test/support/harnesses/sentry_harness.dart`.
20. Implement `test/support/harnesses/async_harness.dart`.
21. Implement `test/support/support.dart` barrel export.
22. Update existing test helper files to re-export from `test/support/` (backward compatibility).
23. Implement `test/unit/data/entity_repository_reference_test.dart`.
24. Implement `test/widget/shared/design_system_reference_test.dart`.
25. Implement `test/integration/auth_flow_reference_test.dart`.
26. Enhance `.github/workflows/reusable-validation.yml` — add `flutter test --coverage` + artifact upload.
27. Run `flutter analyze` and `flutter test --coverage`.
28. Review final diff for strict EP-01-19 scope containment.
29. **Stop at the approval gate** — do not implement EP-01-20 or downstream tasks.

---

## 16. Expected Outcome

- A **centralized test support module** in `test/support/` consolidating all existing scattered test utilities into well-organized, importable modules with a single barrel import.
- A **MockSupabaseClientFactory** providing one-call creation of fully configurable fake Supabase clients.
- A **MockApiServiceFactory** providing one-call creation of test-configured `Dio` instances and `BaseApiService`.
- **Fluent test data builders** replacing verbose inline entity construction with readable, composable builder chains.
- **Custom test matchers** providing readable, domain-specific assertions.
- **Test harnesses** standardizing widget and async test patterns.
- A **reference repository unit test** demonstrating the canonical pattern for testing any repository.
- **Reference widget tests** demonstrating the canonical pattern for testing design system widgets across responsive breakpoints.
- A **reference integration test scaffold** demonstrating the canonical pattern for multi-step user journey testing.
- **CI coverage collection** via `flutter test --coverage` with artifact upload.
- **Backward compatibility** — all existing ~88 tests continue to pass unchanged via re-exports.
- `flutter analyze` + `flutter test --coverage` pass.

---

## 17. Definition of Done (DoD)

**Structure & Code — Test Support Module**
- [ ] `test/support/` contains the §5.2 structure; all files implemented and importing correctly.
- [ ] `test/support/fakes/` contains: `fake_supabase.dart`, `fake_api.dart`, `fake_auth.dart`, `fake_storage.dart`, `fake_network.dart`, `fake_datasource.dart`.
- [ ] `test/support/factories/` contains `mock_supabase_client_factory.dart` and `mock_api_service_factory.dart`.
- [ ] `test/support/builders/` contains `entity_builders.dart`, `dto_builders.dart`, `config_builders.dart`.
- [ ] `test/support/harnesses/` contains `widget_harness.dart`, `sentry_harness.dart`, `async_harness.dart`.
- [ ] `test/support/matchers/` contains `api_matchers.dart`, `entity_matchers.dart`, `state_matchers.dart`.
- [ ] `test/support/support.dart` barrel exports all test support modules.

**MockSupabaseClientFactory**
- [ ] `create()` with no args returns signed-out `FakeSupabaseClient`.
- [ ] `create(currentUser:, currentSession:, initialState:)` configures auth state.
- [ ] `create(rpcHandlers:)` configures scriptable RPC responses.
- [ ] `create(queryResults:, queryError:)` configures query results and error injection.
- [ ] Compatible with existing `FakeSupabaseClient`/`FakeGoTrueClient` interfaces.

**MockApiServiceFactory**
- [ ] `create()` returns `Dio` with `ScriptedAdapter`, no interceptors.
- [ ] `create(responses:)` configures scriptable HTTP responses.
- [ ] `create(accessToken:)` configures fake token provider.
- [ ] `create(enableAuthInterceptor:, enableRetryInterceptor:, enableLoggingInterceptor:)` adds interceptors.
- [ ] `createService()` returns `BaseApiService` with fake Dio + fake Supabase + real `ApiExceptionMapper`.

**Test Data Builders**
- [ ] `EntityProfileBuilder` with defaults and overrides (`withId`, `withDisplayName`, `withEmail`, `withPhone`, `withAvatarUrl`, `withStatus`).
- [ ] `EntityRoleBuilder` with defaults and overrides (`withId`, `withEntityId`, `withRoleType`, `withIsActive`).
- [ ] `EntityBuilder` composing profile + roles with defaults.
- [ ] `EntityProfileDtoBuilder` with `build()` and `toMap()`.
- [ ] `ApiConfigBuilder` with defaults for timeouts and retry config.

**Custom Matchers**
- [ ] `isApiException(kind:, messageContains:)` matches `ApiException`.
- [ ] `isEntityProfile(id:, displayName:)` matches `EntityProfile`.
- [ ] `hasLoadingState()`, `hasErrorState(messageContains:)`, `hasLoadedState()` match Provider states.
- [ ] All matchers produce readable failure messages.

**Reference Tests**
- [ ] `entity_repository_reference_test.dart`: fake injection, cache-first read, remote fetch, write-through, error propagation. All pass.
- [ ] `design_system_reference_test.dart`: themed pump, button interaction, disabled state, input validation, responsive breakpoints. All pass.
- [ ] `auth_flow_reference_test.dart`: fake backend injection, sign-in, invalid credentials, sign-out. Compiles correctly.

**Backward Compatibility**
- [ ] All existing ~88 test files continue to pass unchanged.
- [ ] Existing test helper files updated to re-export from `test/support/`.

**CI Enhancement**
- [ ] `reusable-validation.yml` updated: `flutter test --coverage`.
- [ ] Coverage artifact uploaded via `actions/upload-artifact@v4` with 14-day retention.

**Cross-Cutting**
- [ ] No production code in `lib/` modified.
- [ ] No new dependencies added to `pubspec.yaml`.
- [ ] No hardcoded secrets, tokens, or credentials.
- [ ] No business logic in test fakes (AGENT.md Rule 4).
- [ ] `flutter analyze` passes cleanly.
- [ ] `flutter test --coverage` passes.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-19 changes.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** Medium-high — designing a coherent test infrastructure framework requires careful reasoning about fake object composition, factory configurability, builder defaults, matcher semantics, and backward compatibility with 13+ existing test helper files. The consolidation strategy (re-exports from `test/support/`) must preserve zero breakage across ~88 existing test files. However, the patterns are well-established (hand-rolled fakes, fluent builders, custom matchers) and the implementation is largely consolidation and extension rather than novel algorithmic work.
- **Business impact:** High — this is the quality backbone for the entire project. Every feature in EP-02 through EP-08 depends on these test patterns and factories. Incorrect factories lead to false-positive tests; missing builders lead to verbose, brittle tests; broken backward compatibility breaks CI for all existing tests.
- **Security risk:** Medium — test infrastructure must never contain hardcoded secrets or real credentials. Placeholder constants must be clearly synthetic. Fakes must not replicate server-side enforcement logic. The risk is containment — ensuring test code never leaks into production builds.
- **Performance sensitivity:** Low-medium — test execution speed matters for CI feedback loops, but hand-rolled fakes are inherently fast. Coverage collection adds ~10–20% overhead, which is acceptable.
- **Data complexity:** Low — test data builders produce simple value objects with flat field structures. No relational data, no persistence, no schema design.
- **Integration complexity:** High — must integrate correctly with the existing test ecosystem: 13+ helper files, ~88 test files, the `flutter_test` SDK, the CI pipeline, and the established hand-rolled fakes pattern. The consolidation must maintain backward compatibility. The CI enhancement must not break the existing validation workflow.

High reasoning matches the approved EP-01 matrix (EP-01-19 = High) and the consolidation-heavy, backward-critical nature of the task.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

No approval-required decisions are flagged — this task introduces no new dependencies (reuses `flutter_test` SDK), no architectural tradeoffs, and no scope ambiguities. The plan follows the established hand-rolled fakes pattern and consolidates existing test utilities into a coherent framework.

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-19-Test-Infrastructure-Quality-Assurance-Framework.md`. Implementation will begin only after a separate implementation approval. No production code is written during planning.
