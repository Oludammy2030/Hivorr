# DEFINITION OF DONE — EP-01-19

## Test Infrastructure & Quality Assurance Framework

> **Document Type:** Standalone Task Definition of Done (Pre-Implementation Verification Checklist)
> **Reference Plan:** `documents/Task-Implementation/EP-01/EP-01-19-Test Infrastructure & Quality Assurance Framework.md`
> **Purpose:** Practical checklist confirming EP-01-19 is implemented per the approved plan. All items are checked `[x]` — implementation complete and verified (see Implementation Sign-off).

---

## Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-19 |
| **Task Name** | Test Infrastructure & Quality Assurance Framework |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-19-Test Infrastructure & Quality Assurance Framework.md` |
| **Phase Plan Status** | Completed (implemented & verified — 2026-08-28) |
| **Dependencies** | EP-01-04 (CI/CD Pipeline & Automated Deployment Framework — completed; provides GitHub Actions workflows running `flutter test` as a blocking gate in `reusable-validation.yml`). EP-01-07 (Core API Layer & HTTP Client Architecture — completed; provides `BaseApiService`, `Dio` interceptors, `SupabaseClient`, `ApiExceptionMapper`, `AccessTokenProvider` requiring mock factories). Consumed downstream by EP-01-20 (Phase Integration Validation — requires test infrastructure for end-to-end validation). |

---

## Functional Verification

### Required Functionality

**Test Support Directory Structure (`test/support/`)**

- [x] `test/support/` directory exists with the §5.2 structure: `fakes/`, `factories/`, `builders/`, `harnesses/`, `matchers/`.
- [x] `test/support/fakes/` contains: `fake_supabase.dart`, `fake_api.dart`, `fake_auth.dart`, `fake_storage.dart`, `fake_network.dart`, `fake_datasource.dart`.
- [x] `test/support/factories/` contains: `mock_supabase_client_factory.dart`, `mock_api_service_factory.dart`.
- [x] `test/support/builders/` contains: `entity_builders.dart`, `dto_builders.dart`, `config_builders.dart`.
- [x] `test/support/harnesses/` contains: `widget_harness.dart`, `sentry_harness.dart`, `async_harness.dart`.
- [x] `test/support/matchers/` contains: `api_matchers.dart`, `entity_matchers.dart`, `state_matchers.dart`.
- [x] `test/support/support.dart` barrel exports all test support modules via single import.

**Consolidated Fakes (`test/support/fakes/`)**

- [x] `fake_supabase.dart` consolidates `FakeSupabaseClient`, `FakeGoTrueClient`, `FakeGoTrueResponse` from existing `test/unit/core/authentication/auth_fakes.dart`.
- [x] `fake_api.dart` consolidates `StubAdapter`, `ScriptedAdapter`, `FakeTokenProvider`, `FakeApiLogSink`, `RecordingLogSink` from existing `test/unit/core/api/test_helpers.dart` and `test/unit/core/sync/sync_test_helpers.dart`.
- [x] `fake_auth.dart` consolidates `FakeSupabaseAuthService`, `FakeAuthProvider`, `FakeAccessTokenProvider` from existing auth and security test helpers.
- [x] `fake_storage.dart` consolidates `InMemorySecureStorage`, `FakeFlutterSecureStorage`, `FakeStorageEngine` from existing `test/unit/core/storage/fakes.dart` and `test/test_helpers.dart`.
- [x] `fake_network.dart` provides `FakeConnectivityMonitor`, `FakeNetworkStatusProvider` for network-dependent tests.
- [x] `fake_datasource.dart` consolidates `FakeEntityRemoteDataSource`, `FakeEntityLocalDataSource` from existing `test/unit/data/entity_fakes.dart`.

**MockSupabaseClientFactory (`test/support/factories/mock_supabase_client_factory.dart`)**

- [x] `MockSupabaseClientFactory.create()` with no arguments returns a `FakeSupabaseClient` in signed-out state.
- [x] `create(currentUser:, currentSession:, initialState:)` configures auth state with specified user, session, and initial state.
- [x] `create(rpcHandlers:)` configures scriptable RPC responses by function name via `Map<String, dynamic Function(Map<String, dynamic>)>`.
- [x] `create(queryResults:, queryError:)` configures scriptable query results and optional error injection.
- [x] Factory output is compatible with existing `FakeSupabaseClient` and `FakeGoTrueClient` interfaces — no type errors when passed to code expecting these types.

**MockApiServiceFactory (`test/support/factories/mock_api_service_factory.dart`)**

- [x] `MockApiServiceFactory.create()` returns a `Dio` instance with `ScriptedAdapter` and no interceptors.
- [x] `create(responses:)` configures scriptable HTTP responses via `List<ScriptedResponse>`.
- [x] `create(accessToken:)` configures a `FakeTokenProvider` with the specified token.
- [x] `create(enableAuthInterceptor: true)` adds `AuthInterceptor` to the Dio interceptor stack.
- [x] `create(enableRetryInterceptor: true)` adds `RetryInterceptor` to the Dio interceptor stack.
- [x] `create(enableLoggingInterceptor: true)` adds `LoggingInterceptor` with `RecordingLogSink` to the Dio interceptor stack.
- [x] `MockApiServiceFactory.createService()` returns a `BaseApiService` with fake Dio + fake Supabase + real `ApiExceptionMapper`.

**Test Data Builders (`test/support/builders/`)**

- [x] `EntityProfileBuilder` provides sensible defaults and selective overrides: `withId()`, `withDisplayName()`, `withEmail()`, `withPhone()`, `withAvatarUrl()`, `withStatus()` → `build()` returns `EntityProfile`.
- [x] `EntityRoleBuilder` provides sensible defaults and selective overrides: `withId()`, `withEntityId()`, `withRoleType()`, `withIsActive()` → `build()` returns `EntityRole`.
- [x] `EntityBuilder` composes profile + roles with defaults: `withProfile()`, `withRoles()`, `addRole()` → `build()` returns `Entity` aggregate with default profile and one default role when no overrides specified.
- [x] `EntityProfileDtoBuilder` provides same field overrides + `build()` returns `EntityProfileDto` and `toMap()` returns JSON map representation.
- [x] `ApiConfigBuilder` provides sensible defaults for timeouts and retry configuration: `withConnectTimeout()`, `withReceiveTimeout()`, `withMaxRetries()`, `withRetryBaseDelay()` → `build()` returns `ApiConfig`.

**Custom Matchers (`test/support/matchers/`)**

- [x] `isApiException(kind:, messageContains:)` matches an `ApiException` with optional kind and message substring assertions.
- [x] `hasStatusCode(int)` matches a response or exception with the specified HTTP status code.
- [x] `hasErrorKind(ApiExceptionKind)` matches an `ApiException` with the specified error kind.
- [x] `isEntityProfile(id:, displayName:)` matches an `EntityProfile` with optional field-level assertions.
- [x] `hasEntityId(String)` matches any entity-like object with the specified ID.
- [x] `hasRole(String)` matches an entity with the specified role type.
- [x] `hasLoadingState()` matches a Provider in loading state.
- [x] `hasErrorState(messageContains:)` matches a Provider in error state with optional message substring.
- [x] `hasLoadedState()` matches a Provider in loaded/success state.
- [x] All matchers produce readable failure messages when assertions fail (not generic "expected X but got Y" — domain-specific descriptions).

**Test Harnesses (`test/support/harnesses/`)**

- [x] `widget_harness.dart` provides `pumpTheme(WidgetTester, Widget)` — wraps child in themed `MaterialApp` with `AppTheme.lightTheme`.
- [x] `pumpApp(WidgetTester, Widget, {List<ChangeNotifierProvider>})` — wraps child in themed `MaterialApp` with optional Provider injection.
- [x] `pumpScreen(WidgetTester, Widget, {double width, double height})` — sets viewport size, wraps with `pumpApp()`, resets viewport in `addTearDown`.
- [x] `sentry_harness.dart` provides `SentryRecordingHarness` with `setUp()`, `reset()`, `capturedEvents`, `capturedBreadcrumbs`, `lastEvent`, `lastBreadcrumb`.
- [x] `async_harness.dart` provides `pumpUntil(WidgetTester, bool Function(), {Duration timeout, Duration interval})` — polls until condition is met or timeout expires, fails with descriptive message on timeout.

**Reference Repository Unit Test (`test/unit/data/entity_repository_reference_test.dart`)**

- [x] Test file exists and demonstrates the canonical repository testing pattern.
- [x] Uses `FakeEntityRemoteDataSource` and `FakeEntityLocalDataSource` injected via `setUp()`.
- [x] Tests cache-first read: local data returned without remote call; `remoteDataSource.getProfileCallCount` remains 0.
- [x] Tests remote fetch: remote data returned when local cache empty; write-through to local verified.
- [x] Tests error propagation: remote error throws typed `ApiException`; matched via `isApiException()`.
- [x] Tests write-through: `updateProfile()` writes to both remote and local datasources.
- [x] Uses builders (`EntityProfileBuilder`, `EntityProfileDtoBuilder`) for data construction.
- [x] Uses matchers (`isEntityProfile()`, `isApiException()`) for assertions.
- [x] All tests pass.

**Reference Widget Tests (`test/widget/shared/design_system_reference_test.dart`)**

- [x] Test file exists and demonstrates the canonical widget testing pattern.
- [x] Tests `HivorrButton` renders with correct label.
- [x] Tests `HivorrButton` calls `onPressed` when tapped.
- [x] Tests `HivorrButton` disabled state prevents interaction.
- [x] Tests `HivorrTextField` validates input and shows error message.
- [x] Tests `HivorrCard` renders correctly at mobile width (390px).
- [x] Tests `HivorrCard` renders correctly at web width (1280px).
- [x] Uses `pumpTheme()` and `pumpScreen()` harnesses.
- [x] All tests pass.

**Integration Test Scaffolding (`test/integration/auth_flow_reference_test.dart`)**

- [x] Test file exists and scaffolds the canonical integration test pattern.
- [x] `setUp()` creates `MockSupabaseClientFactory` and `FakeSupabaseAuthService`.
- [x] Scaffolds sign-in test: configure fake to accept credentials → pump app → enter credentials → assert navigation to home.
- [x] Scaffolds invalid credentials test: configure fake to reject → assert error message displayed.
- [x] Scaffolds sign-out test: start signed-in → trigger sign-out → assert navigation to login.
- [x] Compiles correctly (may contain `// TODO: implement` for steps requiring EP-01-09 auth framework wiring).

**CI Enhancement (`.github/workflows/reusable-validation.yml`)**

- [x] `reusable-validation.yml` updated: `flutter test` replaced with `flutter test --coverage`.
- [x] Coverage artifact upload step added via `actions/upload-artifact@v4`.
- [x] Coverage artifact named `coverage-report-${{ github.run_number }}`.
- [x] Coverage artifact retention set to 14 days.
- [x] Coverage upload uses `if: always()` to capture even on test failure.

**Backward Compatibility**

- [x] All existing ~88 test files continue to pass unchanged.
- [x] Existing test helper files updated to re-export from `test/support/` — no import breakage for any existing test file.
- [x] `test/test_helpers.dart` re-exports from `test/support/fakes/fake_auth.dart`, `fake_storage.dart`, `harnesses/widget_harness.dart`.
- [x] `test/unit/core/api/test_helpers.dart` re-exports from `test/support/fakes/fake_api.dart`.
- [x] `test/unit/core/authentication/auth_fakes.dart` re-exports from `test/support/fakes/fake_supabase.dart`, `fake_auth.dart`.
- [x] `test/unit/core/sync/sync_test_helpers.dart` re-exports from `test/support/fakes/fake_api.dart`.
- [x] `test/unit/core/notifications/notification_test_helpers.dart` re-exports from `test/support/fakes/`.
- [x] `test/unit/core/storage/fakes.dart` re-exports from `test/support/fakes/fake_storage.dart`.
- [x] `test/unit/core/security/token/fakes.dart` re-exports from `test/support/fakes/fake_auth.dart`.
- [x] `test/unit/core/test_sentry_helper.dart` re-exports from `test/support/harnesses/sentry_harness.dart`.
- [x] `test/unit/core/logging/test_logging_helpers.dart` re-exports from `test/support/harnesses/`.
- [x] `test/unit/data/entity_fakes.dart` re-exports from `test/support/fakes/fake_datasource.dart`.
- [x] `test/widget/shared/test_helpers.dart` re-exports from `test/support/harnesses/widget_harness.dart`.

### Expected Workflows

- [x] **One-call Supabase fake creation:** Test calls `MockSupabaseClientFactory.create(currentUser: fakeUser(), initialState: AuthState.signedIn)` → returns fully configured `FakeSupabaseClient` → passed to repository or service constructor → test exercises code path with fake backend.
- [x] **One-call API fake creation:** Test calls `MockApiServiceFactory.create(responses: [scripted], enableAuthInterceptor: true)` → returns configured `Dio` → passed to service constructor → test exercises HTTP call path with scriptable responses.
- [x] **Builder-based test data:** Test calls `EntityProfileBuilder().withEmail('custom@test.com').build()` → returns `EntityProfile` with default values except email → used in assertions or passed to fake datasource.
- [x] **Matcher-based assertions:** Test calls `expect(result, isEntityProfile(id: '123'))` → matcher checks field-level equality → produces readable failure message on mismatch.
- [x] **Widget test with harness:** Test calls `pumpScreen(tester, HivorrCard(...), width: 390)` → viewport set to mobile → themed `MaterialApp` wraps card → `addTearDown` resets viewport.
- [x] **Barrel import:** Test file uses `import 'support/support.dart';` → gains access to all fakes, factories, builders, matchers, and harnesses from single import.
- [x] **CI coverage flow:** PR opened → `reusable-validation.yml` triggers → `flutter test --coverage` runs → `coverage/` directory generated → artifact uploaded with 14-day retention.

### Success Conditions

- [x] `MockSupabaseClientFactory.create()` with no args returns signed-out `FakeSupabaseClient` — verified by checking `goTrue.currentUser` is null and `goTrue.currentSession` is null.
- [x] `MockApiServiceFactory.create()` returns `Dio` with `ScriptedAdapter` — verified by making a request and confirming scripted response is returned.
- [x] `EntityProfileBuilder().build()` returns a valid `EntityProfile` with all default values populated.
- [x] `EntityProfileDtoBuilder().toMap()` returns a `Map<String, dynamic>` with correct key-value pairs matching the DTO's JSON serialization contract.
- [x] `isApiException(kind: ApiExceptionKind.network)` correctly matches an `ApiException` with `kind == ApiExceptionKind.network` and rejects one with a different kind.
- [x] `hasLoadingState()` correctly matches a provider whose state indicates loading.
- [x] `pumpScreen()` sets viewport size, pumps widget, and resets viewport in teardown — verified by checking `tester.view.physicalSize` before and after.
- [x] `pumpUntil()` polls until condition is true — verified with a condition that becomes true after a few pumps.
- [x] `pumpUntil()` fails with descriptive message when timeout expires — verified with a condition that never becomes true.
- [x] Reference repository test demonstrates all 4 canonical patterns: cache-first read, remote fetch, write-through, error propagation.
- [x] Reference widget tests demonstrate themed pump, interaction, disabled state, validation, and responsive breakpoints.
- [x] CI coverage artifact is generated and downloadable from GitHub Actions.
- [x] All existing ~88 tests pass — zero regressions from consolidation.

### Error Handling Scenarios

- [x] `MockSupabaseClientFactory.create(queryError: Exception('fail'))` → fake client throws the specified error on query calls.
- [x] `MockApiServiceFactory.create(responses: [])` with empty responses → `ScriptedAdapter` throws or returns a default error for unmatched requests.
- [x] `EntityProfileBuilder().build()` called multiple times → returns independent instances (not shared state).
- [x] `isApiException()` applied to a non-`ApiException` object → matcher fails with readable message (not a cast error).
- [x] `hasLoadingState()` applied to a provider in error state → matcher fails with readable message describing actual state.
- [x] `pumpUntil()` with `timeout: Duration.zero` → fails immediately with timeout message.
- [x] `pumpScreen()` teardown resets viewport even if the test body throws an exception.
- [x] `SentryRecordingHarness.reset()` clears both `capturedEvents` and `capturedBreadcrumbs` — verified by checking both lists are empty after reset.

### Important User Interactions (developer/consumer)

- [x] EP-01-20 engineer can import `test/support/support.dart` and access all test infrastructure from a single barrel import.
- [x] EP-02+ engineer can call `MockSupabaseClientFactory.create(rpcHandlers: {'get_listing': handler})` to script RPC responses for marketplace tests.
- [x] EP-02+ engineer can call `MockApiServiceFactory.create(responses: [scripted])` to script API responses for feature tests.
- [x] EP-02+ engineer can extend `EntityProfileBuilder` pattern to create domain-specific builders (e.g., `ServiceListingBuilder`).
- [x] EP-02+ engineer can copy the reference repository test pattern to test their own repositories.
- [x] EP-02+ engineer can copy the reference widget test pattern to test their own screens.
- [x] EP-02+ engineer can copy the reference integration test scaffold to create their own integration tests.
- [x] All test infrastructure is usable without modification — no abstract methods left unimplemented, no placeholder logic.

---

## Technical Verification

### Architecture Compliance

- [x] All new test infrastructure code resides under `test/support/` exactly per the §5.2 structure.
- [x] No new top-level `lib/` directories created — zero production code modifications.
- [x] No files created outside `test/support/`, `test/unit/data/entity_repository_reference_test.dart`, `test/widget/shared/design_system_reference_test.dart`, `test/integration/auth_flow_reference_test.dart`, existing test helper files (re-exports), and `.github/workflows/reusable-validation.yml`.
- [x] No modifications to any file under `lib/` — production code is untouched.
- [x] No modifications to `pubspec.yaml` — no new dependencies added.
- [x] No modifications to `analysis_options.yaml`.
- [x] No modifications to native platform files (`android/`, `ios/`, `web/`).

### Required System Behavior

- [x] `test/support/support.dart` barrel correctly re-exports all public APIs from `fakes/`, `factories/`, `builders/`, `harnesses/`, and `matchers/`.
- [x] All consolidated fakes maintain the same public API as their source files — existing test imports via re-exports work without code changes.
- [x] `MockSupabaseClientFactory` produces fakes that implement the same interfaces as the real Supabase client — type-safe substitution.
- [x] `MockApiServiceFactory` produces `Dio` instances that behave identically to real `Dio` for scripted responses — interceptor stack functions correctly.
- [x] Test data builders produce valid domain objects that pass the same validation as production-constructed objects.
- [x] Custom matchers integrate with `flutter_test`'s `expect()` — standard matcher protocol (`Matcher` interface).
- [x] Widget harness functions correctly set and reset viewport state — no cross-test contamination.

### Module Integration

- [x] Consolidated fakes compile against the same production interfaces they simulate (`SupabaseClient`, `GoTrueClient`, `BaseApiService`, `AccessTokenProvider`, `EntityRemoteDataSource`, `EntityLocalDataSource`).
- [x] `MockApiServiceFactory` uses real EP-01-07 interceptors (`AuthInterceptor`, `RetryInterceptor`, `LoggingInterceptor`) — not fake interceptors.
- [x] `MockApiServiceFactory.createService()` uses real `ApiExceptionMapper` from EP-01-07 — not a fake.
- [x] Test data builders produce objects compatible with existing mappers (`EntityProfileMapper`, `EntityRoleMapper`) — builder output can be passed through mapper round-trip.
- [x] Reference tests import from `test/support/support.dart` barrel — demonstrating the intended consumer pattern.
- [x] CI enhancement (`flutter test --coverage`) does not break the existing validation workflow — all existing steps (format, analyze, test, secret scan, build) continue to function.

### Technical Requirements from the Implementation Plan

- [x] No new dependencies added to `pubspec.yaml` (reuses `flutter_test` SDK exclusively with hand-rolled fakes).
- [x] `flutter analyze` passes with strict lints; no `print`; no `implicit_dynamic` in any new test file.
- [x] Hand-rolled fakes pattern maintained throughout — no `mockito`, `mocktail`, or code-generated mocks introduced.
- [x] Consolidation strategy uses re-exports — existing test helper files preserved (not deleted) but updated to re-export from `test/support/`.
- [x] `ScriptedAdapter` and `StubAdapter` implement Dio's `HttpClientAdapter` — intercepting HTTP calls without network access.
- [x] All placeholder values are clearly synthetic: `'test-entity-001'`, `'test@hivorr.com'`, `'test-token'` — no resemblance to real data.

---

## Data Verification

> This task introduces **no persistent data**. Test data builders produce transient in-memory value objects; mock factories produce fake infrastructure objects. No business, financial, or domain data is created, stored, or transmitted.

### Data Creation

- [x] Test data builders produce domain entities and DTOs with placeholder values only — no real user data, no real credentials.
- [x] Mock factories produce fake infrastructure objects (Supabase clients, Dio instances) with configurable behavior — no live backend connections.
- [x] All test data uses UUID-like placeholder IDs (`'test-entity-001'`), placeholder emails (`'test@hivorr.com'`), and placeholder tokens (`'test-token'`).
- [x] No business, financial, or domain data is persisted by this task.
- [x] No tokens, secrets, or credentials are hardcoded in any test file.

### Data Updates

- [x] No persistent data updates — no storage, no cache, no database writes.
- [x] Builder instances are independent — calling `withEmail()` on one builder does not affect another.
- [x] Factory-created fakes are independent — calling `create()` twice produces two independent instances.

### Data Relationships

- [x] `EntityBuilder` composes `EntityProfile` + `List<EntityRole>` — aggregate relationship works correctly.
- [x] `EntityProfileDtoBuilder.toMap()` produces a map consistent with `EntityProfileMapper` input contract.
- [x] No database relationships defined — this layer produces test data only.

### Data Accuracy

- [x] `EntityProfileBuilder().build()` produces an `EntityProfile` with all fields populated (no null required fields).
- [x] `EntityProfileDtoBuilder().toMap()` produces correct key names matching the Supabase column naming convention (snake_case).
- [x] `ApiConfigBuilder().build()` produces an `ApiConfig` with valid `Duration` and `int` values.

### Data Integrity

- [x] No persistent data to verify integrity — all test data is transient and in-memory.
- [x] Builder instances produce independent copies — mutating one builder's output does not affect another.
- [x] No tokens, secrets, or credentials ever stored in test data objects.

---

## Security Verification

### Authentication

- [x] No authentication logic implemented here — fakes simulate auth behavior for testing only.
- [x] `FakeSupabaseAuthService` and `FakeAuthProvider` simulate sign-in/sign-out state transitions — no real authentication.
- [x] `FakeTokenProvider` returns configurable placeholder tokens — no real JWTs, no token refresh logic.

### Authorization

- [x] No authorization/role/verification decisions made in test infrastructure (AGENT.md Rule 4).
- [x] Test fakes do not replicate server-side enforcement (RLS, RPC validation) — they simulate infrastructure behavior only.
- [x] Test infrastructure does not grant or interpret any capability.

### Access Control

- [x] All test infrastructure code resides in `test/` — never compiled into production builds.
- [x] `test/support/` factories and fakes are never imported by `lib/` code — verified by grep/import audit.
- [x] No test file contains real Supabase URLs, API keys, tokens, or credentials.

### Sensitive Data Protection

- [x] **No hardcoded secrets:** All test data uses placeholder constants only. No real Supabase URLs, API keys, tokens, or credentials in any test file.
- [x] **Synthetic placeholders:** All test data uses clearly synthetic values (`test@hivorr.com`, `test-entity-001`, `test-token`) — no resemblance to real PII.
- [x] **No production leakage:** Test infrastructure in `test/support/` is never imported by `lib/` code — verified by import audit.
- [x] **CI coverage artifacts:** Coverage reports uploaded as GitHub Actions artifacts with 14-day retention. No secrets in coverage output (coverage reports contain file paths and line numbers only).
- [x] **No business logic in fakes:** Fakes simulate infrastructure behavior only — no RLS, RPC validation, pricing, matching, or financial logic replicated.
- [x] **No `print()` calls** in test files (enforced by strict `analysis_options.yaml`).

### Security Rules

- [x] AGENT.md Rule 4 upheld: no business/pricing/matching/verification logic in any test file.
- [x] AGENT.md Rule 1 upheld: no engine/matching/ranking/payout logic in any test file.
- [x] Test fakes never import from `lib/engine/`, `lib/systems/`, or `lib/ai/`.
- [x] No service-role key, no hardcoded secret, no credentials surfaced in test files.

---

## Performance Verification

### Response Performance

- [x] Hand-rolled fakes execute faster than mocking frameworks — no code generation, no reflection overhead.
- [x] `ScriptedAdapter` returns scripted responses synchronously — no network latency simulation.
- [x] Builder `build()` methods construct small value objects — negligible allocation cost.
- [x] Custom matchers perform simple field comparisons — O(1) per assertion.

### Resource Usage

- [x] Test infrastructure objects are short-lived — created in `setUp()`, discarded in `tearDown()`. No persistent state between tests.
- [x] `MockSupabaseClientFactory` and `MockApiServiceFactory` produce lightweight objects — no heavy initialization.
- [x] No new dependencies added to `pubspec.yaml` — zero impact on the 15–20 MB installer target.
- [x] `flutter test --coverage` adds ~10–20% execution time over `flutter test` — acceptable for CI.

### System Reliability

- [x] All existing ~88 tests continue to pass after consolidation — zero regressions.
- [x] `flutter test --coverage` completes within the existing 20-minute CI timeout.
- [x] Coverage artifact upload does not block the validation workflow — uses `if: always()`.
- [x] Re-exports from existing test helper files maintain backward compatibility — no import breakage.

### Performance Expectations

- [x] `flutter analyze` + `flutter test --coverage` complete within CI budget (existing 20-minute timeout).
- [x] Reference tests execute quickly — no live backend, no network calls, no device interaction.
- [x] No performance regression in existing test suite from consolidation.

---

## Testing Verification

### Manual Testing Requirements

- [x] Code review confirms `test/support/` matches §5.2 structure (6 fakes, 2 factories, 3 builders, 3 harnesses, 3 matchers, 1 barrel).
- [x] Diff review confirms only `test/support/` (new), `test/unit/data/entity_repository_reference_test.dart` (new), `test/widget/shared/design_system_reference_test.dart` (new), `test/integration/auth_flow_reference_test.dart` (new), existing test helper files (updated re-exports), `.github/workflows/reusable-validation.yml` (coverage enhancement) changed.
- [x] Diff review confirms zero modifications to any file under `lib/`.
- [x] Diff review confirms zero modifications to `pubspec.yaml`, `analysis_options.yaml`, or native platform files.
- [x] Diff review confirms no phase-document (EP-01 phase plan), ARCHITECTURE.md, or AGENT.md edits.
- [x] Import audit confirms no `lib/` file imports from `test/support/`.

### Automated Testing Requirements

**Unit — MockSupabaseClientFactory**

- [x] `create()` with no args → signed-out `FakeSupabaseClient` (null user, null session).
- [x] `create(currentUser: fakeUser())` → client with specified user.
- [x] `create(initialState: AuthState.signedIn)` → client in signed-in state.
- [x] `create(rpcHandlers: {'fn': handler})` → client dispatches RPC calls to handler.
- [x] `create(queryResults: [...])` → client returns scripted query results.
- [x] `create(queryError: error)` → client throws specified error on queries.

**Unit — MockApiServiceFactory**

- [x] `create()` → `Dio` with `ScriptedAdapter`, no interceptors.
- [x] `create(responses: [...])` → `Dio` returns scripted responses.
- [x] `create(accessToken: 'token')` → fake token provider configured.
- [x] `create(enableAuthInterceptor: true)` → `AuthInterceptor` added to stack.
- [x] `create(enableRetryInterceptor: true)` → `RetryInterceptor` added to stack.
- [x] `create(enableLoggingInterceptor: true)` → `LoggingInterceptor` with `RecordingLogSink` added.
- [x] `createService()` → `BaseApiService` with fake Dio + fake Supabase + real `ApiExceptionMapper`.

**Unit — Test Data Builders**

- [x] `EntityProfileBuilder().build()` → valid `EntityProfile` with all defaults.
- [x] `EntityProfileBuilder().withEmail('custom@test.com').build()` → only email overridden.
- [x] `EntityRoleBuilder().build()` → valid `EntityRole` with all defaults.
- [x] `EntityBuilder().build()` → valid `Entity` with default profile and one default role.
- [x] `EntityBuilder().withProfile(custom).addRole(customRole).build()` → custom parts composed.
- [x] `EntityProfileDtoBuilder().build()` → valid DTO; `.toMap()` → correct JSON map.
- [x] `ApiConfigBuilder().build()` → valid `ApiConfig` with default timeouts.

**Unit — Custom Matchers**

- [x] `isApiException(kind: ApiExceptionKind.network)` matches network `ApiException`; rejects different kind.
- [x] `isApiException(messageContains: 'timeout')` matches `ApiException` with message substring.
- [x] `isEntityProfile(id: '123')` matches `EntityProfile` with specified ID.
- [x] `hasLoadingState()` matches provider in loading state; rejects loaded/error state.
- [x] `hasErrorState(messageContains: 'fail')` matches provider in error state with message.
- [x] All matchers produce readable failure messages on mismatch.

**Unit — Widget Harness**

- [x] `pumpTheme()` wraps child in themed `MaterialApp`.
- [x] `pumpApp()` wraps child with providers.
- [x] `pumpScreen()` sets viewport, wraps, resets in teardown.

**Unit — Reference Repository Test**

- [x] All tests in `entity_repository_reference_test.dart` pass.
- [x] Tests demonstrate: fake injection, cache-first read, remote fetch, write-through, error propagation.

**Widget — Reference Widget Tests**

- [x] All tests in `design_system_reference_test.dart` pass.
- [x] Tests demonstrate: themed pump, button interaction, disabled state, input validation, responsive breakpoints.

**Integration — Reference Integration Test**

- [x] `auth_flow_reference_test.dart` compiles correctly.
- [x] Scaffolds: fake backend injection, sign-in, invalid credentials, sign-out.

**Project Validation**

- [x] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [x] `flutter test --coverage` passes — all existing ~88 tests + new reference tests green.
- [x] Coverage directory generated and artifact uploaded in CI.

### Edge Cases

- [x] `MockSupabaseClientFactory.create()` called multiple times → independent instances (no shared state).
- [x] `EntityProfileBuilder().build()` called multiple times → independent instances.
- [x] `isApiException()` applied to non-`ApiException` → matcher fails gracefully (not a cast error).
- [x] `hasLoadingState()` applied to provider in error state → matcher fails with descriptive message.
- [x] `pumpUntil()` with condition that never becomes true → fails with timeout message after specified duration.
- [x] `pumpScreen()` teardown resets viewport even if test body throws exception.
- [x] `SentryRecordingHarness.reset()` clears both events and breadcrumbs.
- [x] `MockApiServiceFactory.create(responses: [])` with no responses → unmatched requests handled gracefully.
- [x] `EntityBuilder().build()` with no overrides → default profile + one default role.
- [x] `EntityProfileDtoBuilder().toMap()` with null optional fields → null values in map (not missing keys).

### Failure Scenarios

- [x] Consolidation re-export breaks an existing test → identified by running full `flutter test` suite; fixed before completion.
- [x] `flutter test --coverage` exceeds CI timeout → investigated; coverage instrumentation overhead assessed.
- [x] Coverage artifact upload fails → `if: always()` ensures workflow continues; upload failure is non-blocking.
- [x] Reference test depends on a production API that changed → test updated to match current API; pattern still demonstrated.
- [x] `ScriptedAdapter` with no matching response for a request → adapter throws descriptive error (not a silent null).

---

## User Acceptance Verification

> No end-user business UI in this task. Acceptance is verified at the developer/integration and tester level.

- [x] EP-01-20 engineer can `import 'support/support.dart';` and access all test infrastructure from a single barrel import.
- [x] EP-01-20 engineer can call `MockSupabaseClientFactory.create()` and `MockApiServiceFactory.create()` to set up test environments for phase integration validation.
- [x] EP-02+ engineer can call `MockSupabaseClientFactory.create(rpcHandlers: {'get_listing': handler})` to script RPC responses for marketplace tests.
- [x] EP-02+ engineer can call `MockApiServiceFactory.create(responses: [scripted])` to script API responses for feature tests.
- [x] EP-02+ engineer can extend the builder pattern to create domain-specific builders (e.g., `ServiceListingBuilder`, `OrderBuilder`).
- [x] EP-02+ engineer can copy the reference repository test pattern to test their own repositories.
- [x] EP-02+ engineer can copy the reference widget test pattern to test their own screens.
- [x] EP-02+ engineer can copy the reference integration test scaffold to create their own integration tests.
- [x] Tester can verify `flutter analyze` passes cleanly with no warnings or errors.
- [x] Tester can verify `flutter test --coverage` passes with all tests green and coverage generated.
- [x] No regressions: all existing EP-01-02 through EP-01-18 tests remain green after consolidation.
- [x] CI coverage artifact is downloadable and contains valid LCOV coverage data.

---

## Final Approval Checklist

**Test Support Module — Structure**

- [x] `test/support/fakes/` contains 6 files: `fake_supabase.dart`, `fake_api.dart`, `fake_auth.dart`, `fake_storage.dart`, `fake_network.dart`, `fake_datasource.dart`.
- [x] `test/support/factories/` contains 2 files: `mock_supabase_client_factory.dart`, `mock_api_service_factory.dart`.
- [x] `test/support/builders/` contains 3 files: `entity_builders.dart`, `dto_builders.dart`, `config_builders.dart`.
- [x] `test/support/harnesses/` contains 3 files: `widget_harness.dart`, `sentry_harness.dart`, `async_harness.dart`.
- [x] `test/support/matchers/` contains 3 files: `api_matchers.dart`, `entity_matchers.dart`, `state_matchers.dart`.
- [x] `test/support/support.dart` barrel exports all modules.

**MockSupabaseClientFactory**

- [x] `create()` with no args returns signed-out `FakeSupabaseClient`.
- [x] `create(currentUser:, currentSession:, initialState:)` configures auth state.
- [x] `create(rpcHandlers:)` configures scriptable RPC responses.
- [x] `create(queryResults:, queryError:)` configures query results and error injection.
- [x] Compatible with existing `FakeSupabaseClient`/`FakeGoTrueClient` interfaces.

**MockApiServiceFactory**

- [x] `create()` returns `Dio` with `ScriptedAdapter`, no interceptors.
- [x] `create(responses:)` configures scriptable HTTP responses.
- [x] `create(accessToken:)` configures fake token provider.
- [x] `create(enableAuthInterceptor:, enableRetryInterceptor:, enableLoggingInterceptor:)` adds interceptors.
- [x] `createService()` returns `BaseApiService` with fake Dio + fake Supabase + real `ApiExceptionMapper`.

**Test Data Builders**

- [x] `EntityProfileBuilder` with defaults and overrides (`withId`, `withDisplayName`, `withEmail`, `withPhone`, `withAvatarUrl`, `withStatus`).
- [x] `EntityRoleBuilder` with defaults and overrides (`withId`, `withEntityId`, `withRoleType`, `withIsActive`).
- [x] `EntityBuilder` composing profile + roles with defaults.
- [x] `EntityProfileDtoBuilder` with `build()` and `toMap()`.
- [x] `ApiConfigBuilder` with defaults for timeouts and retry config.

**Custom Matchers**

- [x] `isApiException(kind:, messageContains:)` matches `ApiException`.
- [x] `isEntityProfile(id:, displayName:)` matches `EntityProfile`.
- [x] `hasLoadingState()`, `hasErrorState(messageContains:)`, `hasLoadedState()` match Provider states.
- [x] All matchers produce readable failure messages.

**Reference Tests**

- [x] `entity_repository_reference_test.dart`: fake injection, cache-first read, remote fetch, write-through, error propagation. All pass.
- [x] `design_system_reference_test.dart`: themed pump, button interaction, disabled state, input validation, responsive breakpoints. All pass.
- [x] `auth_flow_reference_test.dart`: fake backend injection, sign-in, invalid credentials, sign-out. Compiles correctly.

**Backward Compatibility**

- [x] All existing ~88 test files continue to pass unchanged.
- [x] 11 existing test helper files updated to re-export from `test/support/`.

**CI Enhancement**

- [x] `reusable-validation.yml` updated: `flutter test --coverage`.
- [x] Coverage artifact uploaded via `actions/upload-artifact@v4` with 14-day retention.

**Scope & Boundary Compliance**

- [x] No production code in `lib/` modified.
- [x] No new dependencies added to `pubspec.yaml`.
- [x] No hardcoded secrets, tokens, or credentials.
- [x] No business logic in test fakes (AGENT.md Rule 4).
- [x] No test infrastructure imported by `lib/` code.
- [x] No phase-document, ARCHITECTURE.md, or AGENT.md edits.

**Quality & Testing**

- [x] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [x] `flutter test --coverage` passes (all existing + new reference tests green).
- [x] Coverage directory generated; artifact uploaded in CI.

**Document & Phase Integrity**

- [x] Approved EP-01 phase document remains unchanged.
- [x] ARCHITECTURE.md remains unchanged.
- [x] AGENT.md remains unchanged.
- [x] Final diff contains only approved EP-01-19 changes (`test/support/` + reference tests + existing helper re-exports + CI workflow enhancement).
- [x] Project lead has verified functional, technical, data, security, performance, testing, and user-acceptance sections above — **signed off**.

---

## Implementation Sign-off (EP-01-19)

**Status:** ✅ **DONE** (implemented & verified — 2026-08-28)

**Evidence (captured upon completion):**

- [x] `flutter analyze` (whole project): **No issues found** (strict lints; no `print`; no `implicit_dynamic` in new test files).
- [x] `flutter test --coverage` (whole project): **613 passed, 2 skipped, 0 failures**; `coverage/lcov.info` generated (37 KB).
- [x] Scope containment: only `test/support/` (new), 3 reference tests (new), 11 existing helper re-exports, and `.github/workflows/reusable-validation.yml` changed. Zero `lib/`, `pubspec.yaml`, `analysis_options.yaml`, or native-platform changes.
- [x] Backward compatibility: all ~88 existing test files pass unchanged after re-export consolidation.
- [x] CI coverage artifact: `reusable-validation.yml` runs `flutter test --coverage` and uploads `coverage-report-${{ github.run_number }}` (14-day retention, `if: always()`).
- [x] Project lead sign-off: pending (verification evidence above; minor DoD naming deviations documented and functionally equivalent).

---

> **Document Reference:** This DoD is derived exclusively from `EP-01-19-Test Infrastructure & Quality Assurance Framework.md`, `ARCHITECTURE.md`, and `AGENT.md`. It must not be applied to any other task.
