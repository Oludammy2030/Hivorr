# TASK IMPLEMENTATION PLAN: EP-01-20

## Phase Integration Validation & Foundation Verification

| Field | Value |
|---|---|
| Task ID | EP-01-20 |
| Task Name | Phase Integration Validation & Foundation Verification |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Not Started (plan for approval) |
| Dependencies | **All EP-01 items (EP-01-01 through EP-01-19).** This task validates the integrated operation of every preceding task. Specific validation targets: EP-01-05/06 (Supabase RPC+RLS + Universal Entity schema), EP-01-07 (Core API Layer), EP-01-08 (Unified Data Access Layer), EP-01-09 (Authentication Framework), EP-01-10 (Security Infrastructure), EP-01-11 (Local Storage & Cache), EP-01-12 (Offline Sync Engine), EP-01-13 (Network Management), EP-01-14 (Monitoring & Logging), EP-01-15 (App Bootstrap & Routing), EP-01-16 (Design System), EP-01-17 (Localization), EP-01-18 (Notifications), EP-01-19 (Test Infrastructure). Consumed downstream by EP-02 (phase gate — EP-01 must be complete before EP-02 begins). |
| Priority | Critical |
| Planning Reasoning | High (approved EP-01 matrix) |
| Coding Reasoning | High (approved EP-01 matrix) |

---

## 1. Task Objective

Perform comprehensive end-to-end integration validation of all EP-01 systems, proving that the 19 individually-implemented foundation components operate correctly as an integrated platform — not merely in isolation — before EP-01 is marked complete and EP-02 is unblocked:

- **10-Point Integration Validation Suite** — a structured set of integration tests, verification scripts, and validation checks covering each of the 10 phase completion criteria defined in the approved EP-01 phase plan (§10):
  1. **Auth Flow Validation** — register, login, token refresh, logout through full stack (client → API → Supabase Auth → session persistence → state propagation).
  2. **API + RLS Validation** — API request traverses Dio → interceptor → Supabase → RLS enforcement → response → cache → UI, with unauthenticated requests denied.
  3. **RPC Execution Validation** — at least one RPC function demonstrates server-side enforcement (client calls RPC, server executes logic, RLS filters result, client receives response).
  4. **Data Flow Pipeline Validation** — complete data access layer vertical slice: Entity → DTO → Datasource → Mapper → Repository → Provider → Widget, verifying cache-first reads, write-through, and error propagation.
  5. **Offline Sync Validation** — action queue captures actions while offline, replays on reconnection, retry with exponential backoff, basic conflict detection, sync status observable.
  6. **Sentry Capture Validation** — errors thrown in any layer are captured by Sentry, breadcrumbs are recorded, performance traces are initiated, PII is redacted from logs.
  7. **Localization Validation** — translations load from JSON, dynamic language switching works, typed key access functions, pluralization renders correctly, locale provider propagates.
  8. **Design System Validation** — design system widgets render on both mobile (390px) and web (1280px) viewports, theme tokens applied consistently, responsive scaffolds adapt.
  9. **CI/CD Validation** — GitHub Actions PR validation workflow runs lint + analyze + test + build successfully; branch protection enforced.
  10. **No Hardcoded Secrets Validation** — static analysis scan confirms zero hardcoded secrets, tokens, API keys, or credentials in the codebase.

- **Environment Isolation Verification** — Dev, Staging, and Prod environment configurations load correctly, are fully isolated (separate Supabase URLs/keys), and the environment switching mechanism functions.

- **Cross-Platform Compilation Verification** — Flutter app compiles (or build-attempts) for Android, iOS, and Web targets, documenting any platform-specific issues.

- **App Size Audit** — build the app (or estimate from dependency analysis) and verify the base installer is within the 15–20 MB target.

- **EP-02 Readiness Assessment** — a structured checklist confirming that all systems EP-02 depends on are operational, documented, and tested.

- **Foundation Verification Report** — a comprehensive verification document recording pass/fail status for each validation point, any issues discovered, and remediation actions taken.

**Dependency note:** EP-01-20 depends on ALL EP-01 items per the approved matrix. This task does not implement new production features — it validates the integrated operation of existing systems. Where integration gaps are discovered, this task creates targeted integration tests and verification scripts, and may apply minimal fixes to wiring/glue code (e.g., bootstrap initialization order, provider registration) that were not covered by individual task scopes. It does not modify core system logic, database schema, RPC functions, or RLS policies.

---

## 2. Business Problem Being Solved

Without a comprehensive phase integration validation:

- **Integration gaps go undetected.** Individual systems (auth, API, data access, sync, security, monitoring) may work correctly in isolation but fail when composed. EP-01-07's API layer may not correctly inject tokens from EP-01-09's auth framework. EP-01-12's sync engine may not correctly trigger from EP-01-13's connectivity changes. EP-01-15's bootstrap may not initialize all systems in the correct order.
- **Phase completion is unverifiable.** The EP-01 phase plan defines 19 specific phase completion criteria (§10). Without a structured validation exercise, there is no evidence that these criteria are met. Marking EP-01 "complete" without validation creates false confidence.
- **EP-02 starts on a broken foundation.** EP-02 (Entity Onboarding & Trust Formation) builds directly on auth, API, data access, security, design system, and routing. If any integration seam is broken, EP-02 tasks fail in confusing ways, wasting development time and creating technical debt.
- **No regression baseline.** Without integration tests that exercise cross-system flows, future changes to any EP-01 system risk breaking integration seams silently. EP-01-20 establishes the regression baseline.
- **Environment isolation unverified.** Three environments exist (Dev/Staging/Prod) but without explicit validation, config cross-contamination or misconfiguration could go undetected until production deployment.
- **Security posture unverified.** Zero-trust architecture requires that unauthenticated clients cannot access data. Without explicit RLS+API integration testing, a misconfigured policy or missing interceptor could expose data.
- **App size constraint unverified.** The 15–20 MB target is a business requirement. Without measurement, the app could exceed the constraint undetected until user complaints.

This is the **phase gate** — it transforms individual system completion into verified platform readiness.

---

## 3. Scope

### In Scope

- **Integration test suite** in `test/integration/`:
  - `auth_flow_integration_test.dart` — end-to-end auth flow through full stack (sign up, sign in, token refresh, session persistence, logout, auth state propagation).
  - `api_rls_integration_test.dart` — API request pipeline with RLS enforcement (authenticated access granted, unauthenticated access denied, token injection verified, error normalization verified).
  - `rpc_execution_integration_test.dart` — RPC function invocation through API layer (client calls → Dio → Supabase RPC → server-side execution → RLS filter → response → cache).
  - `data_flow_pipeline_integration_test.dart` — complete vertical data flow (repository → datasource → mapper → provider → widget) with cache-first, write-through, and error propagation.
  - `offline_sync_integration_test.dart` — offline action capture, connectivity change detection, queue replay on reconnection, retry with backoff, sync status observation.
  - `sentry_capture_integration_test.dart` — error capture across layers, breadcrumb recording, performance trace initiation, PII redaction verification.
  - `localization_integration_test.dart` — translation loading, language switching, typed key access, pluralization, locale provider propagation to widgets.
  - `design_system_integration_test.dart` — design system widgets rendering at mobile and web viewports, theme token consistency, responsive scaffold adaptation.
  - `environment_isolation_integration_test.dart` — environment config loading per environment, isolation verification (different Supabase URLs/keys), switching mechanism.
  - `bootstrap_integration_test.dart` — app bootstrap initializes all core systems in correct order, providers registered, router configured with auth guards.

- **Verification scripts** in `test/integration/verification/`:
  - `secret_scan_verification.dart` — static analysis scan for hardcoded secrets, tokens, API keys, credentials.
  - `app_size_verification.dart` — build size measurement or dependency-based estimation.
  - `cross_platform_build_verification.dart` — build attempt for Android, iOS, Web with result documentation.
  - `phase_completion_checklist.dart` — structured checklist verifying each of the 19 phase completion criteria.

- **Foundation Verification Report** — `documents/Task-Implementation/EP-01/EP-01-20-Foundation-Verification-Report.md` recording:
  - Pass/fail status for each of the 10 validation points.
  - Environment isolation verification results.
  - Cross-platform compilation results.
  - App size measurement.
  - Secret scan results.
  - EP-02 readiness assessment.
  - Issues discovered and remediation actions taken.

- **Minimal wiring/glue fixes** — where integration testing reveals missing bootstrap initialization, unregistered providers, or incorrect initialization order, this task applies minimal fixes to `lib/app/app.dart`, `lib/app/app_bootstrap.dart`, or `lib/main.dart` to correctly wire existing systems. These are integration-seam fixes, not new feature implementations.

- **CI/CD verification** — trigger the existing `pr-validation.yml` workflow and verify it runs lint + analyze + test + build successfully. Document results.

- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope

- Implementing new production features, systems, or modules.
- Modifying core system logic in any `lib/core/` module (auth, API, sync, security, etc.) — only wiring/glue code in `lib/app/` may be adjusted.
- Modifying database schema, RPC functions, or RLS policies (EP-01-05/06).
- Modifying CI/CD workflow logic (EP-01-04) — only triggering and verifying existing workflows.
- Modifying environment configuration values (EP-01-03) — only verifying they load correctly.
- Implementing new design system widgets (EP-01-16) — only verifying existing widgets render correctly.
- Implementing new localization features (EP-01-17) — only verifying existing engine works.
- Implementing new notification features (EP-01-18) — only verifying existing engine initializes.
- Implementing new test infrastructure (EP-01-19) — only using existing test factories, builders, and harnesses.
- End-to-end device testing on physical devices (CI covers emulator/simulator).
- Performance benchmarking or load testing — deferred to EP-02+.
- Security penetration testing — this task validates architectural controls, not attack resistance.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, escrow, or verification logic is implemented by this task. This layer **validates integration**; it does not authorize, compute, or decide business outcomes. Integration tests exercise existing system behavior through their public interfaces — they do not replicate server-side enforcement (RLS, RPC) in test code. All server-side enforcement remains authoritative and is tested via the existing `database-rls-tests.yml` workflow (AGENT.md Rule 4). The verification report documents factual results — it does not modify or override system behavior. No secrets, tokens, or credentials are hardcoded in test files or the verification report. Minimal wiring fixes in `lib/app/` are limited to initialization order and provider registration — no business logic is introduced.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Validate, don't implement | This task proves existing systems work together; it does not build new features |
| Use EP-01-19 test infrastructure | `MockSupabaseClientFactory`, `MockApiServiceFactory`, builders, harnesses, matchers |
| Integration tests use real composition | Where possible, compose real system objects (not mocks) to verify actual integration seams |
| Minimal wiring fixes only | If bootstrap is missing a provider registration, fix it; do not rewrite system logic |
| Evidence-based validation | Every validation point produces test output or documented evidence |
| No hardcoded secrets | Placeholder constants only; secret scan verification enforces this |
| CI-validated | All integration tests pass in CI via `flutter test` |
| Phase gate discipline | If a validation point fails, document the failure, fix the integration seam, re-validate |

### 5.2 Proposed Structure

```text
test/integration/
├── auth_flow_integration_test.dart
├── api_rls_integration_test.dart
├── rpc_execution_integration_test.dart
├── data_flow_pipeline_integration_test.dart
├── offline_sync_integration_test.dart
├── sentry_capture_integration_test.dart
├── localization_integration_test.dart
├── design_system_integration_test.dart
├── environment_isolation_integration_test.dart
├── bootstrap_integration_test.dart
└── verification/
    ├── secret_scan_verification.dart
    ├── app_size_verification.dart
    ├── cross_platform_build_verification.dart
    └── phase_completion_checklist.dart

documents/Task-Implementation/EP-01/
└── EP-01-20-Foundation-Verification-Report.md
```

### 5.3 Validation Point 1: Auth Flow Integration Test

**Objective:** Prove the authentication flow works end-to-end through the full stack.

**Test scenarios:**
1. **Sign-up flow:** Create `MockSupabaseClientFactory` with sign-up acceptance → invoke `AuthService.signUp(email, password)` → verify session created → verify `AuthProvider` emits `authenticated` → verify token injected into API layer interceptors.
2. **Sign-in flow:** Configure fake with existing user → invoke `AuthService.signIn(email, password)` → verify session restored → verify `AuthProvider` state transition → verify `AccessTokenProvider` returns valid token.
3. **Token refresh:** Configure fake with expired token → trigger API call → verify `AuthInterceptor` detects 401 → invokes `AuthService.refreshSession()` → retries original request with new token.
4. **Session persistence:** Sign in → dispose auth service → recreate auth service → verify session restored from secure storage → `AuthProvider` emits `authenticated`.
5. **Logout:** Sign in → invoke `AuthService.signOut()` → verify session cleared → verify `AuthProvider` emits `unauthenticated` → verify secure storage tokens removed → verify API interceptor no longer injects tokens.
6. **Auth state propagation:** Sign in → verify `AuthProvider` notifies listeners → verify `RouteGuard` permits protected routes → sign out → verify `RouteGuard` redirects to login.

**Uses:** `MockSupabaseClientFactory`, `MockApiServiceFactory`, EP-01-19 builders, EP-01-09 `AuthService`/`AuthProvider`, EP-01-07 `AuthInterceptor`, EP-01-10 secure storage.

### 5.4 Validation Point 2: API + RLS Integration Test

**Objective:** Prove the API request pipeline correctly enforces zero-trust through RLS.

**Test scenarios:**
1. **Authenticated request:** Configure fake Supabase with valid session → make API call via `BaseApiService` → verify auth token injected by interceptor → verify Supabase request includes auth header → verify response returned and mapped.
2. **Unauthenticated request denied:** No session configured → make API call → verify request rejected (401 or RLS deny) → verify `ApiExceptionMapper` normalizes to typed `ApiException`.
3. **Error normalization:** Configure fake to return 400, 403, 404, 500 → verify each maps to correct `ApiException` kind (`badRequest`, `forbidden`, `notFound`, `serverError`).
4. **Retry on transient failure:** Configure fake to fail twice then succeed → verify `RetryInterceptor` retries with backoff → verify final success.
5. **Environment-aware endpoint:** Load `EnvironmentConfig` for Dev → verify API base URL matches Dev Supabase URL. Load Staging → verify different URL. Verify no cross-contamination.

**Uses:** `MockApiServiceFactory`, `MockSupabaseClientFactory`, EP-01-07 `BaseApiService`/interceptors, EP-01-03 `EnvironmentConfig`.

### 5.5 Validation Point 3: RPC Execution Integration Test

**Objective:** Prove at least one RPC function demonstrates server-side enforcement through the full stack.

**Test scenarios:**
1. **RPC invocation:** Configure `MockSupabaseClientFactory` with `rpcHandlers` for a foundational RPC function (e.g., `get_entity_profile`) → invoke via `BaseApiService.rpc()` → verify handler called with correct parameters → verify response mapped to domain entity.
2. **RPC with RLS enforcement:** Configure fake to simulate RLS-filtered result (empty result for unauthorized entity) → verify client receives empty/null response → verify no error thrown (authorized query, zero results).
3. **RPC error handling:** Configure fake to throw RPC error → verify `ApiExceptionMapper` normalizes → verify error logged via `HivorrLogger` → verify Sentry breadcrumb recorded.

**Uses:** `MockSupabaseClientFactory` (rpcHandlers), EP-01-07 `BaseApiService`, EP-01-08 `EntityRepository`.

### 5.6 Validation Point 4: Data Flow Pipeline Integration Test

**Objective:** Prove the complete data access layer vertical slice works end-to-end.

**Test scenarios:**
1. **Cache-first read:** Seed local datasource with entity data → invoke `EntityRepository.getProfile()` → verify local data returned without remote call → verify data mapped correctly through `EntityMapper`.
2. **Remote fetch with write-through:** Empty local datasource → invoke `EntityRepository.getProfile()` → verify remote datasource called → verify response written to local datasource → verify Provider emits loaded state with correct entity.
3. **Error propagation:** Configure remote datasource to throw → invoke repository → verify `ApiException` propagated → verify Provider emits error state → verify error logged.
4. **Provider state management:** Invoke repository → verify Provider transitions: `idle` → `loading` → `loaded` (or `error`) → verify `notifyListeners()` called at each transition.
5. **Update write-through:** Invoke `EntityRepository.updateProfile()` → verify remote datasource called → verify local datasource updated → verify Provider emits updated entity.

**Uses:** EP-01-19 `FakeEntityRemoteDataSource`, `FakeEntityLocalDataSource`, EP-01-08 `EntityRepositoryImpl`, `EntityMapper`, `EntityProvider`.

### 5.7 Validation Point 5: Offline Sync Integration Test

**Objective:** Prove the offline sync engine captures, persists, and replays actions correctly.

**Test scenarios:**
1. **Offline capture:** Set connectivity to offline → enqueue sync action → verify action persisted in queue → verify status is `pending`.
2. **Replay on reconnection:** Enqueue actions while offline → set connectivity to online → verify `SyncConnectivityAdapter` detects change → verify sync engine replays queued actions in FIFO order → verify actions marked `completed`.
3. **Retry with backoff:** Configure API fake to fail with 500 → enqueue action → verify retry with exponential backoff + jitter → verify eventual success or `failed` status after max retries.
4. **Conflict detection:** Enqueue action with stale timestamp → configure API to return conflict → verify `ConflictDetector` flags conflict → verify action status reflects conflict.
5. **Sync status observation:** Enqueue multiple actions → verify `SyncStatusProvider` emits status transitions: `idle` → `syncing` → `synced` (or `error`).

**Uses:** EP-01-12 `SyncEngine`, `ActionQueue`, `ConflictDetector`, EP-01-13 `SyncConnectivityAdapter`, `FakeConnectivityMonitor`, EP-01-19 fakes.

### 5.8 Validation Point 6: Sentry Capture Integration Test

**Objective:** Prove errors are captured by Sentry, breadcrumbs recorded, PII redacted.

**Test scenarios:**
1. **Error capture:** Throw exception in API layer → verify `MonitoringService.captureException()` called → verify `SentryRecordingHarness` captured the event with correct type and message.
2. **Breadcrumb recording:** Perform a sequence of operations (auth, API call, data access) → verify breadcrumbs recorded for each operation → verify ordering.
3. **PII redaction:** Log a message containing an email address → verify `HivorrLogger` redacts the email before it reaches the log sink → verify Sentry breadcrumb does not contain raw PII.
4. **Performance trace:** Start a performance trace → perform operations → stop trace → verify `PerformanceTracer` recorded the span.
5. **Environment-aware Sentry:** Load Dev config → verify Sentry DSN matches Dev project. Verify `debug` mode enables verbose breadcrumbs. Load Prod config → verify different DSN, reduced verbosity.

**Uses:** EP-01-19 `SentryRecordingHarness`, EP-01-14 `MonitoringService`, `HivorrLogger`, `PerformanceTracer`, EP-01-03 `EnvironmentConfig`.

### 5.9 Validation Point 7: Localization Integration Test

**Objective:** Prove the localization engine loads translations, switches languages, and propagates to widgets.

**Test scenarios:**
1. **Translation loading:** Initialize `LocalizationService` with `en` locale → verify `en.json` loaded → verify `translate('common.welcome')` returns English string.
2. **Language switching:** Switch to a second locale (e.g., `fr` or `es` if available, otherwise test with a second `en` variant) → verify `LocaleProvider` emits new locale → verify translations update.
3. **Typed key access:** Access translations via typed keys → verify correct values returned.
4. **Pluralization:** Test pluralization rules with count = 0, 1, 2+ → verify correct plural forms selected.
5. **Missing key fallback:** Request a non-existent translation key → verify fallback behavior (return key itself or default value).
6. **Widget integration:** Pump a widget that uses `context.loc.translate()` → verify rendered text matches translation → switch locale → verify text updates.

**Uses:** EP-01-17 `LocalizationService`, `LocaleProvider`, `HivorrLocalizations`, EP-01-19 `pumpApp()` harness.

### 5.10 Validation Point 8: Design System Integration Test

**Objective:** Prove design system widgets render correctly on mobile and web viewports with consistent theme tokens.

**Test scenarios:**
1. **Mobile rendering (390px):** Pump `HivorrButton`, `HivorrTextField`, `HivorrCard` at 390px width → verify rendering without overflow → verify theme tokens applied (colors from `ColorScheme`, typography from `TextTheme`).
2. **Web rendering (1280px):** Same widgets at 1280px width → verify responsive adaptation → verify no hardcoded colors (AGENT.md Rule 5).
3. **Theme consistency:** Pump widgets in light mode → verify colors match `AppTheme` tokens. Switch to dark mode → verify colors update.
4. **Responsive scaffolds:** Pump `MobileScaffold` at 390px → verify mobile layout. Pump `WebScaffold` at 1280px → verify web layout with navigation rail/sidebar.
5. **Design token compliance:** Inspect rendered widget properties → verify no `Colors.*` or raw hex values → verify `fontFamily` not set per-widget (AGENT.md Rule 5).

**Uses:** EP-01-16 design system widgets, EP-01-19 `pumpScreen()` harness with viewport management.

### 5.11 Validation Point 9: CI/CD Verification

**Objective:** Prove the CI/CD pipeline runs lint + analyze + test + build successfully.

**Verification approach:**
1. **Trigger PR validation:** Push the EP-01-20 branch → verify `pr-validation.yml` triggers.
2. **Lint check:** Verify `flutter analyze` passes with zero errors.
3. **Test execution:** Verify `flutter test` (or `flutter test --coverage`) passes — all unit, widget, and integration tests green.
4. **Build verification:** Verify build step completes (or document build issues per platform).
5. **Branch protection:** Verify PR cannot merge without passing checks (document branch protection rules).

**Evidence:** GitHub Actions run URL, pass/fail status, test count, coverage percentage (if available).

### 5.12 Validation Point 10: No Hardcoded Secrets Verification

**Objective:** Prove zero hardcoded secrets exist in the codebase.

**Verification approach:**
1. **Static scan:** Implement `secret_scan_verification.dart` that searches `lib/`, `test/`, and config files for patterns matching:
   - Supabase URLs (`*.supabase.co`)
   - API keys (long alphanumeric strings in assignment contexts)
   - Bearer tokens (`Bearer ` followed by JWT-like patterns)
   - Password literals (`password: '...'` with non-placeholder values)
   - Private keys (`-----BEGIN`)
2. **Environment variable verification:** Verify all `EnvironmentConfig` values are sourced from environment variables or compile-time defines — no literal fallbacks that contain real credentials.
3. **`.gitignore` verification:** Verify `.env`, `.env.*`, and credential files are in `.gitignore`.
4. **Report results:** Document scan results — zero findings expected.

### 5.13 Environment Isolation Verification

**Objective:** Prove Dev, Staging, and Prod environments are fully isolated.

**Test scenarios:**
1. **Config loading:** Load each environment → verify Supabase URL, anon key, and project reference are different per environment.
2. **No cross-contamination:** Load Dev config → verify no Staging/Prod values present. Repeat for each environment.
3. **Switching mechanism:** Switch from Dev to Staging → verify all config values update → verify no cached Dev values persist.

### 5.14 Cross-Platform Build Verification

**Objective:** Verify the app compiles for Android, iOS, and Web.

**Approach:**
1. **Android:** `flutter build apk --debug` (or `--profile`) → record success/failure + APK size.
2. **iOS:** `flutter build ios --debug --no-codesign` (CI environment) → record success/failure.
3. **Web:** `flutter build web` → record success/failure + output size.
4. **Document:** Record build results, any platform-specific errors, and remediation if needed.

### 5.15 App Size Audit

**Objective:** Verify the base installer is within the 15–20 MB target.

**Approach:**
1. **Android APK:** Measure `flutter build apk --release` output size.
2. **Web output:** Measure `flutter build web` output size.
3. **Dependency analysis:** If full release build is not possible in CI, analyze `pubspec.lock` dependency sizes and estimate.
4. **Report:** Document measured/estimated size against the 15–20 MB target.

### 5.16 Bootstrap Integration Test

**Objective:** Prove app bootstrap initializes all core systems in the correct order.

**Test scenarios:**
1. **Initialization order:** Verify `app_bootstrap.dart` initializes systems in dependency order: config → API → auth → security → storage → cache → sync → network → monitoring → notifications → localization → router.
2. **Provider registration:** Verify all core providers are registered in `MultiProvider` and accessible via `context.read<T>()`.
3. **Router configuration:** Verify `GoRouter` has public routes, protected routes, auth redirect logic, and SEO-friendly URL patterns.
4. **Splash sequence:** Verify splash screen displays during initialization → transitions to home (authenticated) or login (unauthenticated).

### 5.17 Minimal Wiring Fixes Strategy

When integration testing reveals gaps in bootstrap wiring:

| Gap Type | Fix Location | Example |
|---|---|---|
| Missing provider registration | `lib/app/app.dart` or `app_bootstrap.dart` | Add `ChangeNotifierProvider<NotificationProvider>` to `MultiProvider` |
| Incorrect initialization order | `lib/app/app_bootstrap.dart` | Reorder `initialize*()` calls to respect dependencies |
| Missing system initialization | `lib/app/app_bootstrap.dart` | Add `initializeNotifications()` call if missing |
| Router missing auth redirect | `lib/app/router/app_router.dart` | Add `redirect` callback if missing |
| Missing barrel export | Module barrel file | Add missing export to barrel `.dart` file |

**Constraint:** Fixes are limited to wiring/glue code. No system logic, no business rules, no schema changes.

### 5.18 Foundation Verification Report

The report documents:

| Section | Content |
|---|---|
| Executive Summary | Overall pass/fail, critical issues, EP-02 readiness verdict |
| Validation Point Results | Pass/fail + evidence for each of the 10 points |
| Environment Isolation | Config loading results, isolation verification |
| Cross-Platform Build | Build results per platform |
| App Size Audit | Measured/estimated size vs. target |
| Secret Scan | Scan results, zero findings confirmation |
| Issues Discovered | List of integration gaps found, severity |
| Remediation Actions | Fixes applied, re-validation results |
| EP-02 Readiness Checklist | Structured assessment of each system EP-02 depends on |
| Recommendations | Outstanding items for EP-02+ attention |

### 5.19 Extensibility Hooks

- Integration test patterns established → EP-02+ phases add their own integration tests following the same structure.
- Verification scripts → EP-02+ phases re-run secret scan, app size, and build verification.
- Foundation Verification Report template → reused for EP-02+ phase gates.
- Bootstrap wiring patterns → EP-02+ systems register their providers and initialization in the established pattern.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| Auth flow integration test | `test/integration/` | Validate end-to-end auth through full stack |
| API+RLS integration test | `test/integration/` | Validate API pipeline with zero-trust enforcement |
| RPC execution integration test | `test/integration/` | Validate server-side enforcement through API layer |
| Data flow pipeline integration test | `test/integration/` | Validate complete data access layer vertical slice |
| Offline sync integration test | `test/integration/` | Validate sync engine capture, replay, retry |
| Sentry capture integration test | `test/integration/` | Validate error capture, breadcrumbs, PII redaction |
| Localization integration test | `test/integration/` | Validate translation loading, switching, widget propagation |
| Design system integration test | `test/integration/` | Validate responsive rendering and theme token compliance |
| Environment isolation integration test | `test/integration/` | Validate environment config loading and isolation |
| Bootstrap integration test | `test/integration/` | Validate initialization order and provider registration |
| Secret scan verification | `test/integration/verification/` | Static analysis for hardcoded secrets |
| App size verification | `test/integration/verification/` | Build size measurement |
| Cross-platform build verification | `test/integration/verification/` | Build attempt per platform |
| Phase completion checklist | `test/integration/verification/` | Structured criteria verification |
| Foundation Verification Report | `documents/Task-Implementation/EP-01/` | Comprehensive validation results document |
| Minimal wiring fixes | `lib/app/` | Bootstrap initialization and provider registration fixes only |
| EP-01-19 test infrastructure | `test/support/` | MockSupabaseClientFactory, MockApiServiceFactory, builders, harnesses, matchers |

**No new dependencies required.** All integration tests use `flutter_test` SDK and EP-01-19 test infrastructure.

---

## 7. Data Requirements

- Integration tests use EP-01-19 test data builders (`EntityProfileBuilder`, `EntityRoleBuilder`, etc.) with placeholder values only.
- No real user data, real credentials, or real Supabase connections.
- Environment isolation tests use the existing `EnvironmentConfig` loading mechanism with compile-time defines — no real environment credentials in test code.
- Secret scan verification searches for patterns, not actual secrets — it reports pattern matches for review.
- The Foundation Verification Report contains factual test results — no sensitive data.
- No business, financial, or domain data is created or persisted.

---

## 8. Database Considerations

**No direct schema changes by this task.** Integration tests that exercise the data flow pipeline use EP-01-19 `FakeEntityRemoteDataSource` and `FakeEntityLocalDataSource` — no live database connections. The RPC execution integration test uses `MockSupabaseClientFactory` with scriptable RPC handlers — no live Supabase RPC calls. Server-side database validation (RLS, RPC, schema) remains the responsibility of `database-rls-tests.yml`.

**Integration contract verified:** This task validates that the client-side code correctly invokes RPCs and processes responses. The server-side enforcement (RLS policies, RPC logic) is validated independently. The integration test proves the client→server→client round-trip works with simulated server responses.

---

## 9. API Requirements

**No new API endpoints or RPCs.** Integration tests exercise existing API infrastructure:
- `BaseApiService` (EP-01-07) with `MockApiServiceFactory` (EP-01-19) for HTTP simulation.
- `MockSupabaseClientFactory` (EP-01-19) for Supabase client simulation.
- No live network traffic. All API interactions are intercepted in-memory.

---

## 10. User Interface Requirements

**No new UI widgets or screens.** Design system integration tests exercise existing EP-01-16 widgets using the EP-01-19 `pumpScreen()` harness. Bootstrap integration tests verify existing router configuration and splash sequence. No new routes, screens, or widgets are created.

---

## 11. User Experience Considerations

**Developer/operator experience:**
- Integration tests provide fast feedback on cross-system integration seams.
- Verification scripts can be re-run by EP-02+ phases as regression checks.
- Foundation Verification Report gives EP-02 developers confidence in the platform foundation.
- Minimal wiring fixes improve app bootstrap reliability.

**End-user experience:**
- Verified auth flow ensures users can register, login, and maintain sessions reliably.
- Verified offline sync ensures no data loss during connectivity interruptions.
- Verified design system ensures consistent, responsive UI across devices.
- Verified localization ensures multi-language support works from day one.
- Verified app size ensures fast download and install.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Integration tests exposing secrets | All tests use placeholder values. Secret scan verification confirms zero hardcoded secrets. |
| Integration tests bypassing security controls | Tests exercise security infrastructure (SSL pinning, token rotation, secure storage) through their public interfaces — no bypass. |
| Fake auth in tests resembling real auth | `MockSupabaseClientFactory` simulates auth behavior for testing only. Tests verify the real `AuthService` integrates correctly with the real `AuthInterceptor`. |
| Verification report containing sensitive data | Report contains pass/fail status and test output summaries. No credentials, tokens, or PII. |
| Wiring fixes introducing security gaps | Minimal fixes limited to initialization order and provider registration. No security logic modified. |
| Cross-environment contamination in tests | Environment isolation tests verify separation. Tests do not connect to live environments. |
| Business logic in integration tests | Tests verify system integration behavior — no business rules, pricing, matching, or escrow logic. |

---

## 13. Performance Considerations

- Integration tests are more expensive than unit tests. Estimated suite runtime: 5–10 minutes (within CI 20-minute timeout).
- `MockSupabaseClientFactory` and `MockApiServiceFactory` provide fast in-memory simulation — no network latency.
- Cross-platform build verification is a separate CI step (not part of `flutter test`).
- Secret scan verification is a fast file-system search (< 30 seconds).
- App size measurement is a one-time build operation.
- No new dependencies. Zero impact on the 15–20 MB installer target.
- Integration tests run in CI only — developers run unit tests locally for fast feedback.

---

## 14. Testing Strategy

### 14.1 Integration — Auth Flow (Validation Point 1)
- Sign-up, sign-in, token refresh, session persistence, logout, auth state propagation. All pass.

### 14.2 Integration — API + RLS (Validation Point 2)
- Authenticated request succeeds, unauthenticated denied, error normalization, retry, environment-aware endpoints. All pass.

### 14.3 Integration — RPC Execution (Validation Point 3)
- RPC invocation through API layer, RLS-filtered results, RPC error handling. All pass.

### 14.4 Integration — Data Flow Pipeline (Validation Point 4)
- Cache-first read, remote fetch with write-through, error propagation, Provider state transitions, update write-through. All pass.

### 14.5 Integration — Offline Sync (Validation Point 5)
- Offline capture, replay on reconnection, retry with backoff, conflict detection, sync status observation. All pass.

### 14.6 Integration — Sentry Capture (Validation Point 6)
- Error capture, breadcrumb recording, PII redaction, performance trace, environment-aware Sentry. All pass.

### 14.7 Integration — Localization (Validation Point 7)
- Translation loading, language switching, typed key access, pluralization, missing key fallback, widget integration. All pass.

### 14.8 Integration — Design System (Validation Point 8)
- Mobile rendering, web rendering, theme consistency, responsive scaffolds, design token compliance. All pass.

### 14.9 CI/CD Verification (Validation Point 9)
- PR validation workflow runs lint + analyze + test + build. All pass.

### 14.10 Secret Scan (Validation Point 10)
- Static scan finds zero hardcoded secrets. `.gitignore` covers `.env` files.

### 14.11 Environment Isolation
- Each environment loads distinct config. No cross-contamination. Switching works.

### 14.12 Cross-Platform Build
- Android, iOS, Web build attempts documented. Issues remediated or documented.

### 14.13 App Size Audit
- Build size measured or estimated. Within 15–20 MB target or documented deviation.

### 14.14 Bootstrap Integration
- All systems initialized in correct order. Providers registered. Router configured. Splash sequence works.

### 14.15 Scope Validation
- Diff review: only `test/integration/` (new integration tests + verification scripts), `documents/Task-Implementation/EP-01/EP-01-20-Foundation-Verification-Report.md` (new report), and minimal `lib/app/` wiring fixes. No core system logic modified. No database schema changes. No new dependencies. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. **Audit all EP-01 deliverables** — confirm EP-01-01 through EP-01-19 are at "Completed" status. Catalog the public interfaces of each system for integration test composition.
2. **Inspect `lib/app/app_bootstrap.dart` and `lib/app/app.dart`** — verify all core systems are initialized and all providers registered. Document any gaps.
3. **Apply minimal wiring fixes** — if bootstrap is missing provider registrations or initialization calls, apply fixes to `lib/app/` files only.
4. **Implement `test/integration/bootstrap_integration_test.dart`** — verify initialization order, provider registration, router configuration, splash sequence.
5. **Implement `test/integration/auth_flow_integration_test.dart`** — end-to-end auth flow validation.
6. **Implement `test/integration/api_rls_integration_test.dart`** — API pipeline with zero-trust enforcement.
7. **Implement `test/integration/rpc_execution_integration_test.dart`** — RPC invocation through full stack.
8. **Implement `test/integration/data_flow_pipeline_integration_test.dart`** — complete data access layer vertical slice.
9. **Implement `test/integration/offline_sync_integration_test.dart`** — sync engine capture, replay, retry.
10. **Implement `test/integration/sentry_capture_integration_test.dart`** — error capture, breadcrumbs, PII redaction.
11. **Implement `test/integration/localization_integration_test.dart`** — translation loading, switching, widget propagation.
12. **Implement `test/integration/design_system_integration_test.dart`** — responsive rendering, theme compliance.
13. **Implement `test/integration/environment_isolation_integration_test.dart`** — environment config loading and isolation.
14. **Implement `test/integration/verification/secret_scan_verification.dart`** — static secret scan.
15. **Implement `test/integration/verification/app_size_verification.dart`** — build size measurement.
16. **Implement `test/integration/verification/cross_platform_build_verification.dart`** — build attempt documentation.
17. **Implement `test/integration/verification/phase_completion_checklist.dart`** — structured criteria verification.
18. **Run `flutter analyze`** — verify strict lints pass.
19. **Run `flutter test`** — verify all unit, widget, and integration tests pass.
20. **Trigger CI/CD pipeline** — verify `pr-validation.yml` runs successfully. Document results.
21. **Run secret scan verification** — confirm zero hardcoded secrets.
22. **Run cross-platform build verification** — attempt builds, document results.
23. **Run app size verification** — measure or estimate, document against target.
24. **Remediate any failures** — if integration tests reveal wiring gaps, apply minimal fixes and re-validate.
25. **Generate Foundation Verification Report** — document all results in `EP-01-20-Foundation-Verification-Report.md`.
26. **Final scope review** — diff contains only approved EP-01-20 changes.
27. **Stop at the approval gate** — do not begin EP-02.

---

## 16. Expected Outcome

- **10 integration tests** validating each phase completion criterion through composed, cross-system test scenarios.
- **4 verification scripts** for secret scanning, app size measurement, cross-platform build, and phase completion checklist.
- **Minimal wiring fixes** in `lib/app/` to resolve any integration-seam gaps discovered during testing.
- **Foundation Verification Report** documenting pass/fail for all 10 validation points, environment isolation, cross-platform builds, app size, secret scan, and EP-02 readiness.
- **CI/CD pipeline verified** — `pr-validation.yml` runs lint + analyze + test + build successfully with EP-01-20 tests included.
- **EP-01 phase marked complete** — all 20 items at "Completed" status.
- **EP-02 unblocked** — verified foundation ready for business feature development.
- `flutter analyze` + `flutter test` pass.

---

## 17. Definition of Done (DoD)

**Integration Tests — 10 Validation Points**
- [ ] `auth_flow_integration_test.dart`: sign-up, sign-in, token refresh, session persistence, logout, auth state propagation. All pass.
- [ ] `api_rls_integration_test.dart`: authenticated request, unauthenticated denied, error normalization, retry, environment-aware endpoints. All pass.
- [ ] `rpc_execution_integration_test.dart`: RPC invocation, RLS-filtered results, RPC error handling. All pass.
- [ ] `data_flow_pipeline_integration_test.dart`: cache-first read, remote fetch with write-through, error propagation, Provider state transitions, update write-through. All pass.
- [ ] `offline_sync_integration_test.dart`: offline capture, replay on reconnection, retry with backoff, conflict detection, sync status observation. All pass.
- [ ] `sentry_capture_integration_test.dart`: error capture, breadcrumb recording, PII redaction, performance trace, environment-aware Sentry. All pass.
- [ ] `localization_integration_test.dart`: translation loading, language switching, typed key access, pluralization, missing key fallback, widget integration. All pass.
- [ ] `design_system_integration_test.dart`: mobile rendering (390px), web rendering (1280px), theme consistency, responsive scaffolds, design token compliance (AGENT.md Rule 5). All pass.
- [ ] `environment_isolation_integration_test.dart`: config loading per environment, isolation verification, switching mechanism. All pass.
- [ ] `bootstrap_integration_test.dart`: initialization order, provider registration, router configuration, splash sequence. All pass.

**Verification Scripts**
- [ ] `secret_scan_verification.dart`: scans `lib/`, `test/`, config files for secret patterns. Zero findings.
- [ ] `app_size_verification.dart`: measures or estimates build size. Documented against 15–20 MB target.
- [ ] `cross_platform_build_verification.dart`: Android, iOS, Web build attempts documented.
- [ ] `phase_completion_checklist.dart`: structured verification of all 19 phase completion criteria from EP-01 §10.

**Foundation Verification Report**
- [ ] `EP-01-20-Foundation-Verification-Report.md` created with all sections (§5.18).
- [ ] Each of the 10 validation points has documented pass/fail status with evidence.
- [ ] Environment isolation results documented.
- [ ] Cross-platform build results documented.
- [ ] App size measurement documented.
- [ ] Secret scan results documented.
- [ ] EP-02 readiness assessment completed with verdict.
- [ ] Issues discovered and remediation actions documented.

**Minimal Wiring Fixes**
- [ ] Any bootstrap wiring gaps identified and fixed in `lib/app/` only.
- [ ] No core system logic modified in any `lib/core/` module.
- [ ] No database schema, RPC, or RLS changes.

**Cross-Cutting**
- [ ] All EP-01-19 test infrastructure used correctly (factories, builders, harnesses, matchers).
- [ ] No new dependencies added to `pubspec.yaml`.
- [ ] No hardcoded secrets, tokens, or credentials.
- [ ] No business logic in integration tests (AGENT.md Rule 4).
- [ ] `flutter analyze` passes cleanly.
- [ ] `flutter test` passes — all unit, widget, and integration tests green.
- [ ] CI/CD pipeline (`pr-validation.yml`) runs successfully.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-20 changes.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** High — composing integration tests that correctly exercise cross-system seams requires careful reasoning about initialization order, dependency injection, fake object composition, and async state propagation across 10+ interacting systems. Each integration test must correctly wire real system objects with EP-01-19 fakes at the right boundaries. Bootstrap wiring fixes require understanding the full initialization dependency graph. However, the patterns are established by EP-01-19 and the individual system implementations — this task composes rather than invents.
- **Business impact:** Critical — this is the phase gate. EP-01 cannot be marked complete and EP-02 cannot begin until this validation passes. A false-positive (marking EP-01 complete with undetected integration gaps) propagates defects into every subsequent phase. A false-negative (failing on non-issues) blocks EP-02 unnecessarily.
- **Security risk:** High — the zero-trust architecture validation (API+RLS, unauthenticated denial, secret scan) is a security-critical verification. Missing a security integration gap could expose data in production. The secret scan must correctly identify credential patterns without false positives that mask real secrets.
- **Performance sensitivity:** Medium — integration test suite must complete within CI timeout. Test composition must be efficient. App size verification must produce accurate measurements.
- **Data complexity:** Low — integration tests use EP-01-19 builders and fakes with placeholder data. No real data, no complex data relationships.
- **Integration complexity:** Very High — this task's entire purpose is integration validation. It must correctly compose 19 independently-implemented systems, understand their public interfaces, identify the correct integration seams, and verify cross-system behavior. The breadth of systems (auth, API, data access, sync, network, monitoring, localization, design system, notifications, security, routing, config) creates significant composition complexity.

High reasoning matches the approved EP-01 matrix (EP-01-20 = High) and the integration-composition-heavy, security-verification-critical nature of the task. While the integration complexity is very high, the task composes existing patterns rather than inventing new ones, keeping the overall reasoning at High rather than Very High.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

No approval-required decisions are flagged — this task introduces no new dependencies, no architectural tradeoffs, and no scope ambiguities. The plan validates existing systems through composition and documents results. Minimal wiring fixes are constrained to `lib/app/` bootstrap code only.

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-20-Phase-Integration-Validation-Foundation-Verification.md`. Implementation will begin only after a separate implementation approval. No production code is written during planning.
