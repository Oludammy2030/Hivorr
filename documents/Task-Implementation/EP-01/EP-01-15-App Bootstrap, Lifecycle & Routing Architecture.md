# TASK IMPLEMENTATION PLAN: EP-01-15

## App Bootstrap, Lifecycle & Routing Architecture

---

## 1. Task Objective

Build the application shell in `lib/app/` and replace the default `main.dart` counter app with the production bootstrap sequence, providing:

- A **`main.dart` entrypoint** that orchestrates the full initialization sequence: environment loading, API layer wiring, authentication framework initialization, and app launch — all fail-closed with structured error handling.
- A **`lib/app/app.dart`** root widget composing `MaterialApp.router` with `MultiProvider` (auth + future core providers), `AppTheme` light/dark theming, and GoRouter integration.
- A **GoRouter-based routing architecture** in `lib/app/router/` with auth-guarded route protection, public/protected route classification, auth-state-driven redirects (unauthenticated → `/login`, authenticated on auth pages → `/`), and SEO-friendly deep-link URLs (`/p/:slug/:id`, `/store/:store_id`).
- A **splash/startup sequence** in `lib/app/startup/` that displays the Hivorr brand identity (logo + `HivorrLoader`) during initialization and transitions to the router on readiness.
- An **app lifecycle observer** in `lib/app/lifecycle/` that hooks into `WidgetsBindingObserver` to propagate lifecycle events (pause, resume, detach) to core services (auth session refresh, sync engine pause/resume).

**Dependencies:** EP-01-09 (Authentication & Authorization Framework — code implemented, status Not Started) and EP-01-03 (Multi-Environment Configuration — Completed).

---

## 2. Business Problem Being Solved

Without a centralized bootstrap and routing layer:

- The app has no initialization sequence — Supabase, Dio, and auth are never initialized, making every downstream system inoperable.
- There is no route protection — unauthenticated users could navigate to protected screens, or authenticated users would be stuck on login pages.
- Deep links and SEO-friendly URLs are absent — web crawlers cannot index public entity profiles, and shared links do not resolve correctly.
- The app has no splash or readiness indicator — users see a blank screen or the default Flutter counter app during cold start.
- Lifecycle events (backgrounding, foregrounding) go unobserved — auth sessions expire silently, sync engine does not pause/resume, and the app wastes resources when backgrounded.
- Core providers (auth, future data providers) are not wired into the widget tree — no system can react to auth state changes or propagate data.

This task is the **orchestration layer** that wires all EP-01 core systems into a functional application shell. Every screen in EP-02+ renders inside this shell.

---

## 3. Scope

### In Scope

- `lib/main.dart` — replacement of the default counter app with the production bootstrap sequence.
- `lib/app/app.dart` — root `MaterialApp.router` widget with `MultiProvider`, theming, and GoRouter binding.
- `lib/app/router/` — GoRouter configuration:
  - Route tree definition (public + protected routes).
  - Auth-state redirect logic using `AuthGuard` from EP-01-09.
  - SEO-friendly URL patterns for public entity profiles and stores.
  - Placeholder screens for route targets (stubs only — no business UI).
  - Deep-link handling for web and mobile.
- `lib/app/startup/` — splash screen widget + initialization orchestrator.
- `lib/app/lifecycle/` — `AppLifecycleObserver` with `WidgetsBindingObserver`.
- Provider wiring: `AuthProvider` (from EP-01-09) registered in `MultiProvider`; extensibility hooks for future providers (EP-01-08 data providers, EP-01-13 network provider).
- Unit tests for route protection, redirect logic, lifecycle observer, and initialization sequence.
- Widget tests for splash screen and app root.

### Out of Scope

- Business UI screens, feature pages, or dashboard content — EP-02+.
- Design system components (buttons, inputs, cards) — EP-01-16.
- Localization engine — EP-01-17.
- Notification engine — EP-01-18.
- Authentication framework internals (session management, token refresh) — EP-01-09 (already implemented).
- API layer, security infrastructure, storage, sync, network, monitoring — EP-01-07 through EP-01-14.
- Supabase migrations, RPC, RLS — EP-01-05/06.
- Native platform configuration changes (Android manifest, iOS Info.plist, web manifest).
- Theme or design token modifications — existing `lib/app/theme/` is consumed as-is.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, or AGENT.md.

---

## 4. Out of Scope (Explicit Boundary Reaffirmation)

No proprietary/business rule, pricing, matching, or escrow logic is permitted in this layer. The bootstrap and routing layer is **orchestration-only** — it wires systems together but contains no business decisions. Route stubs are empty shells; no feature content is built.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles

- **Orchestration-only:** This layer initializes, wires, and delegates. No business logic, no data transformation, no domain decisions.
- **Fail-closed initialization:** If environment loading, Supabase init, or auth init fails, the app shows a structured error state — never silently degrades or falls back to a wrong environment.
- **Single initialization path:** `main()` → `AppBootstrap.run()` → `MaterialApp.router`. No secondary entry points or ad hoc initialization.
- **Route protection by default:** All routes require authentication unless explicitly listed as public. The `AuthGuard` from EP-01-09 is the single authorization gate.
- **SEO-first URL design:** Public entity routes use slug-based, human-readable URLs that web crawlers can index.
- **Provider composition:** `MultiProvider` registers all core providers at the root. New providers (EP-01-08, EP-01-13, etc.) are added by appending to the provider list — no restructuring.

### 5.2 Proposed Structure

```text
lib/
├── main.dart                          # Entrypoint: calls AppBootstrap.run()
├── app/
│   ├── app.dart                       # Root MaterialApp.router + MultiProvider
│   ├── app_bootstrap.dart             # Initialization orchestrator
│   ├── router/
│   │   ├── app_router.dart            # GoRouter factory + route tree
│   │   ├── route_names.dart           # Named route constants
│   │   ├── route_paths.dart           # URL path constants + builders
│   │   └── route_guard.dart           # GoRouter redirect delegate to AuthGuard
│   ├── startup/
│   │   ├── splash_screen.dart         # Brand splash (logo + HivorrLoader)
│   │   └── initialization_state.dart  # Init status enum (loading, ready, error)
│   ├── lifecycle/
│   │   └── app_lifecycle_observer.dart # WidgetsBindingObserver delegate
│   ├── theme/                         # (existing — consumed, not modified)
│   └── widgets/                       # (existing — consumed, not modified)
```

### 5.3 Bootstrap Sequence (`AppBootstrap.run()`)

The initialization orchestrator executes a strict, ordered sequence:

1. **`WidgetsFlutterBinding.ensureInitialized()`** — Flutter engine readiness.
2. **`AppConfig.load()`** — Environment configuration via EP-01-03 `EnvironmentLoader` (fail-closed; throws `EnvironmentConfigException` on missing/invalid values).
3. **`ApiInitializer.initializeApi(appConfig.environmentConfig)`** — Supabase + Dio wiring via EP-01-07 (returns `ApiLayer`).
4. **`initializeAuth(authClient, supabaseClient, authConfig)`** — Auth framework wiring via EP-01-09 (returns `AuthLayer`).
5. **`authLayer.provider.initialize()`** — Restore persisted session, start observing auth-state changes.
6. **`runApp(HivorrApp(...))`** — Launch the root widget with all initialized artifacts injected.

If any step throws, the orchestrator catches the exception and renders a fatal-error screen (not a crash) with a user-safe message and a structured log entry. The error screen is non-interactive except for a "Retry" button that re-runs the bootstrap.

### 5.4 Root Widget (`HivorrApp`)

```
MultiProvider
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(authLayer.provider),
    // Future: data providers (EP-01-08), network provider (EP-01-13), etc.
  ]
  child: MaterialApp.router(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    routerConfig: appRouter,  // GoRouter from §5.5
    debugShowCheckedModeBanner: false,
  )
```

- Theme sourced from existing `AppTheme.lightTheme` / `AppTheme.darkTheme` — never hardcoded (AGENT.md Rule 5).
- `MaterialApp.router` (not `MaterialApp`) — GoRouter owns navigation; no `Navigator` direct usage.
- `debugShowCheckedModeBanner: false` across all environments.

### 5.5 GoRouter Configuration

**Route tree:**

| Path | Name | Auth Required | Description |
|---|---|---|---|
| `/` | `home` | Yes | Dashboard/home stub |
| `/login` | `login` | No | Login screen stub |
| `/signup` | `signup` | No | Registration screen stub |
| `/forgot-password` | `forgotPassword` | No | Password recovery stub |
| `/reset-password` | `resetPassword` | No | Password reset stub |
| `/profile` | `profile` | Yes | Entity profile stub |
| `/settings` | `settings` | Yes | Settings stub |
| `/p/:slug/:id` | `publicProfile` | No | SEO-friendly public entity profile |
| `/store/:storeId` | `publicStore` | No | SEO-friendly public store |

**Redirect logic** (consumes `AuthGuard` from EP-01-09):

- `AuthGuard.redirectResolver(location)` is called on every navigation.
- Unauthenticated + protected route → redirect to `/login`.
- Authenticated + auth-page route (`/login`, `/signup`) → redirect to `/`.
- All other cases → allow navigation.

**`refreshListens`** — GoRouter listens to `AuthProvider` (via `Listenable`) so route re-evaluation triggers on auth-state changes (sign-in, sign-out).

**SEO-friendly URLs:**

- `/p/:slug/:id` — public entity profile (e.g., `/p/electrician/abc-123`).
- `/store/:storeId` — public store front (e.g., `/store/xyz-456`).
- These routes are public (no auth required) and render stub shells; EP-02+ fills content.
- `route_paths.dart` exposes typed path builders: `RoutePaths.publicProfile(slug: 'electrician', id: 'abc-123')` → `/p/electrician/abc-123`.

### 5.6 Splash Screen

- Renders `LogoHorizontal` (from `lib/app/widgets/logo_variants.dart`) centered with `HivorrLoader` below.
- Background uses `Theme.of(context).scaffoldBackgroundColor` — respects light/dark.
- Displayed during the initialization sequence (§5.3); transitions to the router on `InitializationState.ready`.
- On initialization failure, displays a user-safe error message with a retry button.

### 5.7 App Lifecycle Observer

`AppLifecycleObserver` extends `WidgetsBindingObserver`:

- **`didChangeAppLifecycleState`** — propagates `resumed`, `paused`, `inactive`, `detached` to registered callbacks.
- On `resumed`: trigger auth session refresh check (EP-01-09 `AuthService` already handles auto-refresh via Supabase).
- On `paused`/`detached`: notify sync engine to flush pending queue (EP-01-12 hook — callback registration, not implementation).
- Registered in `main.dart` before `runApp`.

### 5.8 Extensibility Hooks

- **Provider list** in `MultiProvider` is a `List<SingleChildWidget>` built by a factory function — EP-01-08/13/14 append providers without modifying `app.dart`.
- **Route tree** is built by a factory function — EP-02+ appends feature routes without modifying the GoRouter constructor.
- **Lifecycle callbacks** are a registration list — core services subscribe without the observer knowing about them.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `main.dart` | `lib/` | Entrypoint: `AppBootstrap.run()` |
| `app.dart` | `lib/app/` | Root `MaterialApp.router` + `MultiProvider` |
| `app_bootstrap.dart` | `lib/app/` | Initialization orchestrator (ordered sequence) |
| `app_router.dart` | `lib/app/router/` | GoRouter factory, route tree, redirect delegate |
| `route_names.dart` | `lib/app/router/` | Named route constants |
| `route_paths.dart` | `lib/app/router/` | URL path constants + typed path builders |
| `route_guard.dart` | `lib/app/router/` | GoRouter redirect → `AuthGuard` bridge |
| `splash_screen.dart` | `lib/app/startup/` | Brand splash widget |
| `initialization_state.dart` | `lib/app/startup/` | Init status enum |
| `app_lifecycle_observer.dart` | `lib/app/lifecycle/` | `WidgetsBindingObserver` delegate |
| Placeholder screens | `lib/app/router/` or inline | Stub `Scaffold` per route target |
| Test suite | `test/unit/app/`, `test/widget/app/` | Router, guard, lifecycle, splash tests |

No new dependency added — GoRouter (`17.5.0`), Provider (`6.1.5`), and `supabase_flutter` (`2.17.2`) are already pinned in EP-01-02.

---

## 7. Data Requirements

No business, user, or domain data is introduced. The layer carries only:

- Configuration metadata (from `AppConfig` → `EnvironmentConfig`).
- Initialized client instances (`ApiLayer`, `AuthLayer`) injected into the widget tree.
- Route parameters (slugs, IDs) passed as path parameters — no data fetching.

The bootstrap must never persist tokens, config, or session data — that responsibility belongs to EP-01-09 (auth) and EP-01-11 (storage).

---

## 8. Database Considerations

**Not applicable.** This task does not interact with the database directly. Supabase is consumed only through the EP-01-07 `ApiLayer` and EP-01-09 `AuthLayer` that are initialized during bootstrap. All enforcement remains server-side (AGENT.md Rule 4).

---

## 9. API Requirements

- **No new endpoints** are defined. The bootstrap initializes the EP-01-07 API layer and passes it downstream.
- The GoRouter route tree defines **client-side navigation paths** that future features (EP-02+) will populate with data-fetching screens.
- SEO-friendly routes (`/p/:slug/:id`, `/store/:storeId`) define the URL contract that server-side rendering and web crawlers will consume.

---

## 10. User Interface Requirements

- **Splash screen:** `LogoHorizontal` + `HivorrLoader` centered on themed background. No hardcoded colors (AGENT.md Rule 5).
- **Error screen:** User-safe error message + retry button on initialization failure.
- **Placeholder screens:** Minimal `Scaffold` with route-name label per route target — no business UI content. These are stubs that EP-02+ replaces.
- **Theme:** `AppTheme.lightTheme` / `AppTheme.darkTheme` applied globally via `MaterialApp.router`.

---

## 11. User Experience Considerations

- **Fast perceived startup:** Splash displays brand identity immediately while initialization runs asynchronously.
- **Graceful failure:** Initialization errors show a user-safe message (no stack traces, no config values) with a retry option.
- **Seamless auth transitions:** Route re-evaluation on auth-state change prevents users from seeing protected content or being stuck on login after signing in.
- **Deep-link resolution:** Shared links (`/p/electrician/abc-123`) resolve directly to the correct screen on cold start.
- **No jarring transitions:** Splash → router transition is a single `MaterialApp.router` swap, not a navigation push.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Initialization bypass | Fail-closed: any init step failure prevents app launch; no fallback to wrong environment |
| Route protection bypass | `AuthGuard` fail-closed: unknown routes require auth; no default-allow |
| Secret leakage in error screens | Error messages are user-safe; no config values, stack traces, or Supabase URLs shown |
| Hardcoded routes/credentials | All configuration from `AppConfig`; no literals for URLs, keys, or endpoints |
| Session persistence across lifecycle | Lifecycle observer triggers auth refresh on resume; no silent session expiry |
| Deep-link injection | GoRouter validates route paths; unknown paths redirect to home or login |
| Business logic in bootstrap | Layer is strictly orchestration-only; no entity/RPC/domain decisions |
| Unauthorized environment switching | `AppConfig` is immutable and loaded once at startup (EP-01-03 invariant preserved) |

---

## 13. Performance Considerations

- **Async initialization:** All init steps are `Future`-based; the splash screen renders immediately while initialization runs.
- **Single Supabase + Dio instance:** Constructed once during bootstrap; never re-created (EP-01-07 invariant).
- **GoRouter route building:** Routes are defined declaratively; no runtime reflection or dynamic route generation.
- **Provider tree:** `MultiProvider` at root; no nested `Provider` re-construction on navigation.
- **Lifecycle observer:** Lightweight callback dispatch; no heavy work on state transitions (delegates to registered services).
- **No synchronous blocking I/O** in the bootstrap sequence.
- **Negligible impact on the 15–20 MB installer** — no new packages, no new assets (existing logo SVGs + `HivorrLoader` reused).

---

## 14. Testing Strategy

### 14.1 Unit — Route Guard
- `RouteGuard` redirects unauthenticated users on protected routes to `/login`.
- `RouteGuard` redirects authenticated users on auth pages (`/login`, `/signup`) to `/`.
- `RouteGuard` allows unauthenticated access to public routes (`/p/:slug/:id`, `/store/:storeId`).
- `RouteGuard` allows authenticated access to protected routes.

### 14.2 Unit — Route Paths
- `RoutePaths.publicProfile(slug, id)` produces `/p/{slug}/{id}`.
- `RoutePaths.publicStore(storeId)` produces `/store/{storeId}`.
- Named route constants match GoRouter route names.

### 14.3 Unit — Lifecycle Observer
- `AppLifecycleObserver` dispatches `resumed`, `paused`, `detached` to registered callbacks.
- Registered callbacks are invoked in order; unregistered callbacks are not invoked.

### 14.4 Unit — Bootstrap
- `AppBootstrap` initialization sequence calls steps in order.
- Initialization failure produces `InitializationState.error` with a safe message.
- Successful initialization produces `InitializationState.ready` with all artifacts.

### 14.5 Widget — Splash Screen
- `SplashScreen` renders `LogoHorizontal` and `HivorrLoader`.
- Error state renders user-safe message and retry button.

### 14.6 Widget — App Root
- `HivorrApp` renders `MaterialApp.router` with correct theme.
- `AuthProvider` is accessible from the widget tree via `context.watch<AuthProvider>()`.

### 14.7 Project Validation
- `flutter analyze` — strict lints; no `print` in production code.
- `flutter test` — all new tests pass.
- Available platform smoke builds (Android, iOS, Web) — app launches to splash and routes correctly.

### 14.8 Scope Validation
- Diff review: only `lib/main.dart`, `lib/app/` (excluding `theme/` and `widgets/` which are consumed, not modified), and `test/` changes. No API, auth, security, storage, sync, network, monitoring, or design system implementation leaked in. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-09 and EP-01-03 deliverables; confirm `lib/app/router/`, `lib/app/startup/`, `lib/app/lifecycle/` are empty (`.gitkeep` only).
2. Create `initialization_state.dart` (loading, ready, error enum).
3. Create `route_names.dart` (named route constants).
4. Create `route_paths.dart` (URL path constants + typed path builders).
5. Create `route_guard.dart` (GoRouter redirect → `AuthGuard` bridge).
6. Create `app_router.dart` (GoRouter factory with route tree, redirect, and `refreshListenable`).
7. Create placeholder/stub screens for each route target (inline or separate files).
8. Create `splash_screen.dart` (brand splash with logo + loader + error state).
9. Create `app_lifecycle_observer.dart` (`WidgetsBindingObserver` with callback dispatch).
10. Create `app_bootstrap.dart` (initialization orchestrator with ordered sequence).
11. Create `app.dart` (root `MaterialApp.router` + `MultiProvider`).
12. Replace `main.dart` with production entrypoint calling `AppBootstrap.run()`.
13. Add `test/unit/app/` tests for route guard, route paths, lifecycle observer, and bootstrap.
14. Add `test/widget/app/` tests for splash screen and app root.
15. Run `flutter analyze` and `flutter test`.
16. Perform available platform smoke builds (Android, iOS, Web).
17. Review final diff for strict EP-01-15 scope containment and phase-document integrity.
18. **Stop at the approval gate** — do not build feature screens, design system components, localization, or notifications.

---

## 16. Expected Outcome

- A production `main.dart` that orchestrates environment loading, API initialization, auth initialization, and app launch in a strict, fail-closed sequence.
- A root `HivorrApp` widget composing `MaterialApp.router` with `MultiProvider` (auth provider registered), `AppTheme` light/dark theming, and GoRouter integration.
- A GoRouter route tree with public and protected routes, auth-state-driven redirects, and SEO-friendly deep-link URLs.
- A splash screen displaying the Hivorr brand identity during initialization, with graceful error handling and retry.
- An app lifecycle observer propagating pause/resume/detach events to registered core services.
- Placeholder screens for all route targets, ready for EP-02+ to fill with business UI.
- Unit and widget tests proving route protection, redirect logic, lifecycle dispatch, and initialization behavior.
- Clean extensibility hooks for future providers (EP-01-08), feature routes (EP-02+), and lifecycle subscribers (EP-01-12/13).

---

## 17. Definition of Done (DoD)

- [ ] `lib/main.dart` replaced with production entrypoint calling `AppBootstrap.run()`.
- [ ] `lib/app/app.dart` renders `MaterialApp.router` with `MultiProvider` and `AppTheme` light/dark.
- [ ] `lib/app/app_bootstrap.dart` executes the ordered initialization sequence (env → API → auth → runApp).
- [ ] Initialization failure shows a user-safe error screen with retry; no config values or stack traces exposed.
- [ ] `lib/app/router/app_router.dart` configures GoRouter with the complete route tree.
- [ ] `lib/app/router/route_guard.dart` bridges GoRouter redirect to EP-01-09 `AuthGuard`.
- [ ] Unauthenticated users on protected routes redirect to `/login`.
- [ ] Authenticated users on auth pages redirect to `/`.
- [ ] Public routes (`/p/:slug/:id`, `/store/:storeId`) accessible without authentication.
- [ ] `lib/app/router/route_paths.dart` exposes typed path builders for SEO-friendly URLs.
- [ ] `lib/app/router/route_names.dart` defines named route constants.
- [ ] GoRouter `refreshListenable` bound to `AuthProvider` for auth-state-driven route re-evaluation.
- [ ] `lib/app/startup/splash_screen.dart` renders `LogoHorizontal` + `HivorrLoader` on themed background.
- [ ] `lib/app/lifecycle/app_lifecycle_observer.dart` dispatches lifecycle events to registered callbacks.
- [ ] Placeholder screens exist for all route targets (no business UI content).
- [ ] No hardcoded colors, fonts, or brand values — all from `AppTheme` tokens (AGENT.md Rule 5).
- [ ] No hardcoded secrets, endpoints, or credentials.
- [ ] Unit tests cover route guard, route paths, lifecycle observer, and bootstrap sequence.
- [ ] Widget tests cover splash screen and app root.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`).
- [ ] `flutter test` passes.
- [ ] Available platform smoke builds pass (Android, iOS, Web).
- [ ] No business logic, domain model, repository, security, monitoring, design system, localization, or notification code included.
- [ ] The approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-15 changes.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Very High**

### Reasoning Level Justification

- **Technical complexity:** High — orchestrating a multi-step async initialization sequence with fail-closed error handling, wiring GoRouter with auth-state-driven redirects, and composing a provider tree that scales for future tasks requires precise reasoning where mistakes cause silent auth bypass, initialization deadlocks, or broken deep links.
- **Business impact:** Critical — this is the application shell that every EP-02+ screen renders inside; flaws propagate to every feature.
- **Security risk:** High — route protection must be fail-closed (default-deny); any misconfiguration in the redirect logic exposes protected screens to unauthenticated users.
- **Performance sensitivity:** Medium — initialization must be async and non-blocking; lifecycle observer must be lightweight; route building must not cause unnecessary rebuilds.
- **Data complexity:** Low — no business/domain data; only configuration, client instances, and route parameters.
- **Integration complexity:** Very high — must correctly consume EP-01-03 (`AppConfig`), EP-01-07 (`ApiInitializer`), and EP-01-09 (`initializeAuth`, `AuthGuard`, `AuthProvider`) interfaces, while exposing stable extensibility seams for EP-01-08/12/13/14/16/17/18 and EP-02+.

Very High reasoning matches the approved EP-01 matrix (EP-01-15 = Very High) and the cross-cutting orchestration nature of the task.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-15-App Bootstrap, Lifecycle & Routing Architecture.md` and implementation will begin only after a separate implementation approval. No production code is written during planning.
