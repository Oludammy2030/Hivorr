# TASK IMPLEMENTATION PLAN: EP-01-09

## Authentication & Authorization Framework

| Field | Value |
|---|---|
| Task ID | EP-01-09 |
| Task Name | Authentication & Authorization Framework |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Not Started (plan for approval) |
| Dependencies | EP-01-05 (Supabase RPC + RLS — completed), EP-01-07 (Core API Layer — completed). Relies on EP-01-06 server schema/RPC contract (completed) and EP-01-03 config (completed) transitively. |
| Priority | Critical |
| Planning Reasoning | Extremely High (approved EP-01 matrix) |
| Coding Reasoning | Extremely High (approved EP-01 matrix) |

---

## 1. Task Objective

Implement the client-side **Authentication & Authorization Framework** in `lib/core/authentication/`, establishing the single gateway through which every platform operation is authorized:

- **Auth service** wrapping Supabase Auth (`supabase_flutter`) for **sign up, login, logout, session recovery, and auth-state observation**.
- **Session persistence** and **token auto-refresh** relying on Supabase Auth's built-in secure session handling (the API layer's `SupabaseAccessTokenProvider` already reads `Supabase.instance.client.auth.currentSession` and refreshes on 401 — EP-01-07 §5.3/§5.7). EP-01-09 does **not** reimplement token injection; it guarantees the shared session is the single source of truth.
- **App-wide auth state propagation** via a Provider (`ChangeNotifier`) exposing auth status, the current entity id (`auth.users.id`), and operation methods.
- **Route-guard enabling primitives** (auth-status enum, `isAuthenticated`, redirect resolver) consumed by EP-01-15's GoRouter — this task does **not** build the router itself.
- **Bootstrap hook** (`initializeAuth()` / `registerAuthLayer()`) for EP-01-15 to wire at startup; `main.dart`/bootstrap is **not** modified by this task.
- **Entity provisioning on signup** via a self-scoped, RLS-bounded insert (the `entities` row + default `consumer` role), keeping all creation server-enforced (zero-trust).

---

## 2. Business Problem Being Solved

Without a unified auth framework:

- Every future feature (EP-02+ registration, verification, trust, finance) would hand-roll Supabase Auth calls, scattering session, refresh, and state logic and eroding the zero-trust discipline.
- Token/refresh consistency would break: EP-01-07 already injects the session token and performs 401-refresh-retry, but only if a coherent, single auth session exists — without EP-01-09 there is no authoritative session owner, causing silent logout and failed requests on Nigeria's unreliable networks.
- UI would have no reliable signal of "who is logged in / are they confirmed," making route protection and dashboard gating impossible and risking unauthenticated access to protected surfaces.
- The `entities.id = auth.users.id` identity model (EP-01-06 D1) would have no client-side owner guarantee, undermining every downstream self-scoped RLS read/write.

This task is the **trust gate** for the entire client; EP-02 builds identity, verification, and trust directly on top of it.

---

## 3. Scope

### In Scope
- `lib/core/authentication/` module structure (§5.2), built on EP-01-05/06/06 contracts.
- **Auth models** (pure Dart): `AuthCredentials` (email/password value object — raw password held only for the duration of the call), `AuthSession` (typed, token-free wrapper: entity id, expires-at, refreshed-at, provider).
- **Auth state**: `AuthStatus` enum (`initial`, `unauthenticated`, `authenticated`, `awaitingEmailConfirmation`).
- **Auth service** (abstract `AuthService` + `SupabaseAuthService` impl): `signUp`, `signIn`, `signOut`, `currentEntityId`, `currentSession`, `isSignedIn`, `onAuthStateChange` stream, `ensureEntityExists()` (self-scoped provisioning). Constructor-injected `GoTrueClient` for testability.
- **Auth provider** (`AuthProvider extends ChangeNotifier`): holds `AuthStatus`, `currentEntityId`, last error; exposes `signUp/signIn/signOut/initialize()` delegating to the service; subscribes to `onAuthStateChange`.
- **Guard primitives**: `AuthGuard` for EP-01-15 — `isAuthenticated`, `redirectResolver()` (fail-closed: unauthenticated → login route), `requiresAuth(location)`.
- **Bootstrap hook**: `authentication.dart` barrel + `initializeAuth()` returning an `AuthLayer` (service + provider) for EP-01-15. `main.dart` unchanged.
- Unit tests (mocked `GoTrueClient`): signUp/Login/Logout transitions, session recovery on cold start, `onAuthStateChange` propagation, guard resolution, `ensureEntityExists` idempotency. No live backend.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope
- Building the GoRouter or route table — EP-01-15 (this task supplies guard primitives only).
- SSL pinning, AES encryption, token-rotation hardening, secure-storage wrappers — EP-01-10 (relies on supabase_flutter's built-in persistence now; EP-01-10 hardens storage later).
- Local storage drivers / cache / offline sync — EP-01-11, EP-01-12.
- Connectivity monitoring — EP-01-13.
- Sentry/logger concrete wiring — EP-01-14.
- Data-access repositories, DTOs, mappers, `EntityProvider` — EP-01-08 (auth service may call self-scoped inserts directly but does not build the data layer).
- Supabase migrations, RPC, RLS, Edge Functions — EP-01-05/06 (consumed only). **No new SQL/migration in this task.**
- UI widgets, design system, localization, notifications — later phases.
- Native platform configuration changes.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, escrow, or verification-decision logic is permitted. The auth framework **authenticates and identifies**; it does not authorize business capabilities (those are server-enforced via RLS + RPC, AGENT.md Rule 4). Role/verification gating belongs to EP-02+ and the server.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer | AGENT.md Rule 4, ARCHITECTURE.md |
| All Supabase access through shared client | EP-01-07 `SupabaseInitializer` / `Supabase.instance.client` |
| Token injection + 401-refresh already owned by API layer | EP-01-07 `SupabaseAccessTokenProvider` (reads `currentSession.accessToken`; `refresh()` → `refreshSession()`) |
| Config via `EnvironmentConfig` only | EP-01-03; never `String.fromEnvironment` |
| Errors normalized via `ApiException` | EP-01-07/`ApiException` |
| Entity identity = `auth.users.id`; self-scoped writes | EP-01-06 D1 + RLS owner-defaults migration |
| No business logic in client | AGENT.md Rules 1, 4 |

### 5.2 Proposed Structure

```text
lib/core/authentication/
├── auth_config.dart                 # tunables (e.g., session-expiry buffer, confirmation-required flag from env)
├── models/
│   ├── auth_credentials.dart        # email/password value object (no persistence of raw secret)
│   └── auth_session.dart            # typed, token-free session wrapper
├── state/
│   └── auth_status.dart             # enum: initial|unauthenticated|authenticated|awaitingEmailConfirmation
├── services/
│   ├── auth_service.dart            # abstract AuthService interface
│   └── supabase_auth_service.dart   # impl over injected GoTrueClient
├── providers/
│   └── auth_provider.dart           # ChangeNotifier: status + entity id + ops
├── guards/
│   └── auth_guard.dart              # isAuthenticated + redirectResolver for EP-01-15
└── authentication.dart              # barrel + initializeAuth() hook for EP-01-15
```

### 5.3 Auth Service (over shared Supabase client)

- `SupabaseAuthService` is constructed with a `GoTrueClient` (production: `Supabase.instance.client.auth`; tests: `FakeGoTrueClient`). It never re-initializes Supabase and never constructs its own client — guaranteeing the session is shared with the EP-01-07 API layer (so token injection + 401-refresh work unchanged).
- `signUp(AuthCredentials)`: calls `auth.signUp(email, password)`. Returns `AuthResult` with status: `authenticated` (if a session is returned — email confirmation disabled in env) or `awaitingEmailConfirmation` (session null). On `authenticated`, triggers `ensureEntityExists()`.
- `signIn(AuthCredentials)`: `auth.signInWithPassword(email, password)` → `ensureEntityExists()` → status `authenticated`.
- `signOut()`: `auth.signOut()` → status `unauthenticated`.
- `ensureEntityExists()`: idempotent self-scoped provisioning — `INSERT INTO entities (id) VALUES (auth.uid()) ON CONFLICT (id) DO NOTHING`, then ensure a `consumer` role row (`entity_roles_activate('consumer')` RPC or self-scoped insert). Scoped entirely by RLS to the caller; no `entity_id` parameter is ever supplied by the client (owner-defaults migration makes it `auth.uid()`). This keeps entity creation server-enforced and zero-trust.
- `currentEntityId` = `auth.currentUser?.id`; `isSignedIn` = session != null; `onAuthStateChange` exposes the stream so the provider stays live across refresh/expiry.

### 5.4 Token Refresh & Session Persistence (integration contract)

- **Persistence**: `supabase_flutter` automatically persists the session (its `localStorage`) and restores `Supabase.auth.currentSession` on cold start. On bootstrap, `AuthProvider.initialize()` reads the restored session to set initial `AuthStatus`, then subscribes to `onAuthStateChange` for live changes.
- **Refresh**: handled by `supabase_flutter` (proactive token refresh) **and** by the EP-01-07 retry interceptor's `AccessTokenProvider.refresh()` on 401. EP-01-09 **relies on this existing mechanism** and must only guarantee correct startup ordering: EP-01-15 calls `ApiInitializer.initializeApi(config)` (which initializes Supabase + builds the token provider) **before** `initializeAuth()`. No new refresh code is added.
- **Extension hook**: EP-01-10 may later replace supabase_flutter's `localStorage` backing with the hardened `flutter_secure_storage` wrapper; EP-01-09 code must not assume a specific storage backend.

### 5.5 Auth Provider (app-wide state)

- `AuthProvider extends ChangeNotifier`: holds `AuthStatus status`, `String? currentEntityId`, `ApiException? lastError`. `initialize()` restores state from the service and wires `onAuthStateChange`. Exposes `signUp/signIn/signOut` that delegate to the service, map failures to `ApiException`, and `notifyListeners()` on real transitions only. No Supabase/Dio imports beyond the injected service.

### 5.6 Guard Primitives (for EP-01-15)

- `AuthGuard`: `bool get isAuthenticated`, `String? redirectResolver(String location)` returning the login path when unauthenticated and accessing a protected route (fail-closed), and `bool requiresAuth(String location)` (registry of public vs protected prefixes). Pure, testable, no router dependency.

### 5.7 Bootstrap Hook

- `initializeAuth({required GoTrueClient authClient})` builds `SupabaseAuthService` + `AuthProvider`, registers the auth-state subscription, and returns an `AuthLayer` for EP-01-15 to provide app-wide. `main.dart`/`app.dart` unchanged in this task.

### 5.8 Extensibility Hooks (for later tasks)

- Injected `GoTrueClient` lets EP-01-19 build mock factories and CI test without a backend.
- Guard primitives are the EP-01-15 route-protection seam.
- `AuthProvider` is the EP-01-18 (notifications) and EP-02 (verification) identity source.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `SupabaseInitializer` / `Supabase.instance.client` | `lib/core/api/supabase/` (EP-01-07) | Shared auth client + session source |
| `SupabaseAccessTokenProvider` | `lib/core/api/auth/` (EP-01-07) | Token injection + 401 refresh (reused, not duplicated) |
| `ApiException` | `lib/core/api/exceptions/` (EP-01-07) | Typed error normalization |
| `EnvironmentConfig` | `lib/config/environments/` (EP-01-03) | Endpoint/key source (transitive) |
| `entities`/`entity_roles` RLS + owner-defaults + `entity_roles_activate` RPC | Supabase (EP-01-06) | Server-enforced self-scoped entity provisioning |
| `models/*`, `state/*`, `services/*`, `providers/*`, `guards/*` | `lib/core/authentication/` | This task |
| `authentication.dart` | `lib/core/authentication/` | Barrel + `initializeAuth()` hook |
| Test suite | `test/unit/core/authentication/` | Service/provider/guard tests |

No new dependency added (supabase_flutter already pinned in EP-01-02; API layer in EP-01-07).

---

## 7. Data Requirements

- Only identity-related shapes are touched: `auth.users` (created by Supabase Auth), and the `entities`/`entity_roles` rows provisioned via **self-scoped, RLS-bounded** inserts/UPSERTs (no client-supplied `entity_id`).
- `AuthCredentials` holds email/password transiently (never persisted, never logged).
- `AuthSession` carries only non-sensitive identity metadata (entity id, expiry timestamps) — **never** the access/refresh token.
- No operational business data is created, seeded, or persisted by this task beyond the mandatory identity row(s).

---

## 8. Database Considerations

This client task defines **no migrations, RPCs, or RLS**. It consumes the EP-01-06 contract:
- `entities.id uuid PK → auth.users(id)` with `DEFAULT auth.uid()` (migration `20260821090002`, `20260821090005`).
- RLS `INSERT` on `entities`/`entity_roles` granted to `authenticated`, owner-scoped by `auth.uid()` (migration `20260821090003`); `entity_roles_activate(p_role)` RPC enforces vocabulary server-side (`PLT003` on unknown role).
- **Open integration decision (flagged for approval gate — §12 Risk R1):** the current migration set contains **no `auth.users` trigger** to auto-create the `entities` row on signup. This plan recommends the client perform the self-scoped provisioning in `ensureEntityExists()` (RLS-bounded, zero-trust-safe, in-scope). The alternative — a server `auth.users` trigger — would require a new migration (out of this client task's scope) and is noted for lead decision.

---

## 9. API Requirements

- **No new endpoints/RPCs** defined. The framework consumes Supabase Auth (`signUp`, `signInWithPassword`, `signOut`, `refreshSession`, `onAuthStateChange`) and the EP-01-06 `entity_roles_activate` RPC (via the EP-01-07 `BaseApiService`/Supabase client) for entity provisioning.
- The framework is the **client-side identity contract**: it exposes `currentEntityId` and `AuthStatus` to every future feature and the EP-01-15 router.

---

## 10. User Interface Requirements

**Not applicable.** No widgets, screens, or routing in this task. Guard primitives and `AuthProvider` are exported for EP-01-15/EP-02 UI consumption; `main.dart`/bootstrap unchanged.

---

## 11. User Experience Considerations

Developer/operator experience only:
- One-call `initializeAuth()` yields a fully wired, app-wide auth state.
- A single, authoritative session source prevents duplicate-login/logout bugs and silent 401 loops.
- Clear `awaitingEmailConfirmation` state lets EP-02 build the confirmation UX deterministically.
- Guard primitives give EP-01-15 a fail-closed, copy-able route-protection pattern.
- Idempotent entity provisioning means login after reinstall/confirmation never duplicates the identity row.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Duplicated/competing sessions | Auth service uses the **single** shared `Supabase.instance.client.auth`; never constructs its own client |
| Token/secret leakage in logs | `AuthCredentials`/`AuthSession` never log the password or tokens; rely on EP-01-07 redaction |
| Raw error/SQL leakage | All failures normalized to `ApiException` before crossing the provider boundary |
| Business logic in client | Framework authenticates/identifies only; no role/verification authorization decisions (AGENT.md Rule 4) |
| Unauthorized entity creation | `ensureEntityExists()` supplies **no** `entity_id`; RLS scopes every insert to `auth.uid()`; vocabulary validated server-side by `entity_roles_activate` (`PLT003`) |
| Unauthenticated route access | Guard `redirectResolver` fails **closed** → login; protected prefixes explicit |
| Stale/invalid session | `AuthProvider.initialize()` restores from persisted session; `onAuthStateChange` + EP-01-07 401-refresh keep it live |
| Service-role / secret usage | Uses anon-key Supabase client only (enforced by EP-01-03/07); no `String.fromEnvironment` |
| Session storage weakness | Relies on supabase_flutter persistence now; EP-01-10 hardens with `flutter_secure_storage` wrapper (extension point, not this task) |
| Cross-entity identity confusion | `currentEntityId` sourced solely from `auth.currentUser.id` (== `entities.id`, D1) |

**R1 (approval-gate decision):** entity-row provisioning mechanism (client self scoped insert — recommended — vs. server `auth.users` trigger). See §8.

---

## 13. Performance Considerations

- Auth operations are low-frequency (login/logout/signup); no hot path concerns.
- Session restore is a synchronous read of the persisted session at bootstrap; subscription is event-driven (no polling).
- `notifyListeners()` only on real status transitions; provider is lightweight.
- No new packages, assets, or storage engines — negligible impact on the 15–20 MB installer.
- `ensureEntityExists()` is idempotent (single `ON CONFLICT DO NOTHING` / RPC call) — no redundant round-trips on every login.

---

## 14. Testing Strategy

### 14.1 Unit — Auth Service (mocked `GoTrueClient`)
- `signUp` returns `authenticated` when a session is returned, `awaitingEmailConfirmation` when null.
- `signIn` → `authenticated`; `signOut` → `unauthenticated`.
- `ensureEntityExists()` performs exactly one self-scoped provisioning call and is idempotent across repeated calls.
- Failures from the auth client map to typed `ApiException` (auth/validation/network/server).

### 14.2 Unit — Auth Provider
- `initialize()` transitions `initial → authenticated` when a persisted session exists; `initial → unauthenticated` otherwise.
- `onAuthStateChange` (simulated) drives `authenticated ↔ unauthenticated` and updates `currentEntityId`.
- Operations set `lastError` as `ApiException` and notify on real transitions; no Supabase/Dio imports in the test beyond the injected fake.

### 14.3 Unit — Guard
- `redirectResolver` returns login path for protected routes when unauthenticated; returns null (allow) when authenticated; public prefixes always allowed (fail-closed default).

### 14.4 Project Validation
- `flutter analyze` (strict lints; no `print`; no `implicit_dynamic`).
- `flutter test` — all new unit tests pass.
- Available platform smoke build (no native changes).

### 14.5 Scope Validation
- Diff review: only `lib/core/authentication/` + `test/unit/core/authentication/`. No bootstrap/UI/DB/migration/security/monitoring implementation leaked. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-05/06/07 deliverables; confirm `lib/core/authentication/` is empty (`.gitkeep` only).
2. Implement `state/auth_status.dart` (enum).
3. Implement `models/auth_credentials.dart` + `models/auth_session.dart` (pure Dart, token-free).
4. Implement `auth_config.dart` (env-derived tunables; no `String.fromEnvironment`).
5. Implement `services/auth_service.dart` (abstract) + `services/supabase_auth_service.dart` (injected `GoTrueClient`; `signUp/signIn/signOut/ensureEntityExists/onAuthStateChange`).
6. Implement `providers/auth_provider.dart` (`ChangeNotifier`).
7. Implement `guards/auth_guard.dart` (guard primitives).
8. Implement `authentication.dart` (barrel + `initializeAuth()` hook for EP-01-15).
9. Add `test/unit/core/authentication/` tests (service with `FakeGoTrueClient`, provider, guard).
10. Run `flutter analyze` and `flutter test`.
11. Available platform smoke builds (no native changes).
12. Review final diff for strict EP-01-09 scope containment and phase-document integrity.
13. **Stop at the approval gate** — do not wire `main.dart`, build routes, or implement downstream tasks (EP-01-10+).

---

## Approval-Required Decisions (flagged for the lead)

- **R1 — Entity provisioning on signup:** This plan recommends **client self-scoped, RLS-bounded provisioning** in `ensureEntityExists()` (in-scope, zero-trust-safe). The alternative is a server `auth.users` trigger (new migration, out of this client task). Please confirm the recommended approach or approve the migration deviation.
- **Email confirmation behavior:** Default `awaitingEmailConfirmation` state is modeled; confirm whether Dev/Staging environments run with email confirmation disabled (session returned at signup) vs. Prod (confirmation required). Behavior is env-driven via `auth_config.dart` and does not change code paths.

---

## 16. Expected Outcome

- A unified, app-wide auth framework in `lib/core/authentication/` providing sign up, login, logout, session recovery, live auth-state propagation, and fail-closed guard primitives.
- A single, shared Supabase Auth session that the EP-01-07 API layer already uses for token injection and 401-refresh — no duplicated session or refresh logic.
- Idempotent, server-enforced entity provisioning on signup/login (self-scoped `entities` + default `consumer` role), consistent with EP-01-06 D1 and RLS.
- Unit tests proving service/provider/guard behavior without a live backend (injectable `GoTrueClient`).
- An `initializeAuth()` hook ready for EP-01-15 bootstrap, with `main.dart` unchanged.

---

## 17. Definition of Done (DoD)

**Structure & Code**
- [ ] `lib/core/authentication/` contains the §5.2 structure; all files implemented and importing correctly.
- [ ] `AuthService` (abstract + `SupabaseAuthService`) built over an **injected** `GoTrueClient`; never re-initializes or constructs its own Supabase client.
- [ ] `signUp/signIn/signOut/currentEntityId/isSignedIn/onAuthStateChange/ensureEntityExists` implemented; `ensureEntityExists` is self-scoped (no client-supplied `entity_id`) and idempotent.
- [ ] `AuthProvider` (`ChangeNotifier`) exposes `AuthStatus`, `currentEntityId`, `lastError`; restores state at `initialize()`; no Supabase/Dio imports beyond the injected service.
- [ ] `AuthGuard` provides `isAuthenticated` + fail-closed `redirectResolver` (pure, testable).
- [ ] `authentication.dart` exports barrel + `initializeAuth()` hook; `main.dart`/bootstrap unchanged.
- [ ] All auth failures normalized to `ApiException` before crossing the provider boundary.
- [ ] No business/pricing/matching/verification authorization logic in the framework (AGENT.md Rule 4).
- [ ] No `String.fromEnvironment`, hardcoded endpoint, or secret in source.
- [ ] `ensureEntityExists` supplies no `entity_id`; all writes are RLS-scoped to `auth.uid()`.
- [ ] Guard `redirectResolver` fails closed (unauthenticated → login) — verified by unit test.
- [ ] Unit tests cover service (mocked client), provider state transitions, and guard resolution; all pass.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes.
- [ ] Available platform smoke builds pass (no native config changed).
- [ ] No router/UI/migration/security/monitoring/storage/sync code included.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-09 changes.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Extremely High**

### Reasoning Level Justification

- **Technical complexity:** High–Extremely high — designing correct session ownership, idempotent self-scoped entity provisioning, live auth-state propagation, and a fail-closed guard without duplicating the EP-01-07 token/refresh mechanism requires precise reasoning; mistakes cause silent logout, duplicate identities, or unauthenticated route access.
- **Business impact:** Critical — every EP-02+ capability (registration, verification, trust, finance) is built on this gateway; flaws propagate platform-wide.
- **Security risk:** Extremely high — the framework is the trust gate; incorrect session sharing, entity-provisioning scoping, or guard fail-open directly enable unauthorized access or identity confusion (AGENT.md Rule 4).
- **Performance sensitivity:** Medium — auth is low-frequency, but session-restore correctness and 401-refresh interaction with EP-01-07 affect reliability on unreliable Nigerian networks.
- **Data complexity:** Medium-high — must faithfully bind client identity to `entities.id = auth.users.id` and provision roles without leaking server invariants.
- **Integration complexity:** Extremely high — must consume EP-01-05/06/07 contracts exactly (shared Supabase client, `SupabaseAccessTokenProvider`, RLS owner-defaults, `entity_roles_activate` RPC) while exposing stable seams for EP-01-10 (storage hardening), EP-01-15 (routing guards), EP-01-18 (notifications), and EP-02 (verification) without coupling them to implementation.

Extremely High reasoning matches the approved EP-01 matrix (EP-01-09 = Extremely High) and the security-critical, foundational nature of the auth gateway.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Specifically, the lead's confirmation is requested on the **Approval-Required Decisions** (§15 follow-up): **R1** (entity-row provisioning mechanism — client self-scoped insert recommended vs. server `auth.users` trigger) and the **email confirmation behavior** across environments.

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-09-Authentication & Authorization Framework.md` (matching the established task-plan format; a separate `EP-01-09-Definition-of-Done.md` will be produced at completion per established practice). Implementation will begin only after a separate implementation approval. No production code is written during planning.
