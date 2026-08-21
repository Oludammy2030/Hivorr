# TASK IMPLEMENTATION PLAN: EP-01-08

## Unified Data Access Layer

| Field | Value |
|---|---|
| Task ID | EP-01-08 |
| Task Name | Unified Data Access Layer |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Completed (implemented 2026-08-21; unit tests passing; DoD verified) |
| Dependencies | EP-01-06 (Universal Entity schema + RPC contract — completed), EP-01-07 (Core API layer `BaseApiService`/`ApiException`/Supabase+Dio clients — completed) |
| Priority | High |
| Planning Reasoning | Very High |
| Coding Reasoning | Very High (per approved EP-01 matrix) |

---

## 1. Task Objective

Establish the client-side **Unified Data Access Layer** in `lib/data/`, implementing the project-wide data-flow pattern that every feature in EP-02+ will reuse:

- Define **domain entities** (pure Dart, framework-agnostic) for the Universal Entity model.
- Define **DTOs** mirroring the EP-01-06 table/RPC shapes.
- Implement **remote datasources** that access Supabase **only** through the EP-01-07 `BaseApiService` (no direct Supabase/Dio primitives from business code).
- Define **local datasource interfaces** (contracts) so EP-01-11/EP-01-12 can plug in cache/offline persistence without reshaping the layer.
- Implement **mappers** (DTO ↔ entity) as the single transformation boundary.
- Implement **repositories** behind **abstract interfaces** that compose remote + local datasources — the abstraction that mitigates Supabase vendor lock-in (phase objective 4, ARCHITECTURE.md `data/`).
- Implement **Provider-based state management** exposing repository data to the UI (Provider is the confirmed stack).
- Deliver **one complete vertical reference slice** (Entity → DTO → RemoteDataSource → Mapper → Repository → Provider) proving the pattern end-to-end, plus reusable abstract repository/base classes so EP-02+ clones the slice instead of inventing new patterns.

The layer is **strictly a data-movement and abstraction boundary**: no business rules, pricing, matching, or financial logic are permitted (AGENT.md Rules 1, 4).

---

## 2. Business Problem Being Solved

Without a unified data access layer:

- Business systems (EP-01-09 auth onward, and all of EP-02+) would each hand-roll Supabase calls, duplicating mapping, error handling, caching, and state logic, and eroding the zero-trust "client is presentation only" discipline.
- Direct Supabase/Dio access from feature code would bypass the EP-01-07 interceptor chain (auth token injection, 401-refresh, error normalization, logging), reintroducing silent-auth-failure and raw-error-leak risks.
- Tight coupling to Supabase concrete types in every feature would make the documented vendor-lock-in mitigation (ARCHITECTURE.md, phase Risk register) impossible to honor later.
- State would be scattered (ad-hoc `FutureBuilder`s, duplicated fetches), producing inconsistent UI and no single source of truth per entity.
- There would be no reference contract for EP-02+ engineers, guaranteeing structural drift across eight phases.

This task makes the data path **uniform, abstracted, observable, and server-enforcing** — the connective tissue between the EP-01-07 transport layer and every future feature.

---

## 3. Scope

### In Scope

- `lib/data/` module structure (see §5.2), built on top of EP-01-07 deliverables.
- **Domain entities** (pure Dart): `Entity`, `EntityProfile`, `EntityRole` — representing the fluid Universal Entity (per EP-01-06 D1–D4). No Flutter/Supabase imports.
- **DTOs** for the reference slice tables/RPCs: `EntityDto`, `EntityProfileDto`, `EntityRoleDto`, with `fromJson`/`toJson` matching EP-01-06 column/RPC envelopes exactly.
- **Mappers**: `EntityMapper`, `EntityProfileMapper`, `EntityRoleMapper` (DTO ↔ entity, pure functions, null-safe).
- **Remote datasource** for the reference slice:
  - `EntityRemoteDataSource` (abstract interface).
  - `SupabaseEntityRemoteDataSource` (impl) using `BaseApiService` only (via `supabase` accessor for self-scoped `select`/RPC `rpc()`), never constructing clients.
- **Local datasource contract** for the reference slice:
  - `EntityLocalDataSource` (abstract interface only); concrete implementation deferred to EP-01-11 (storage) / EP-01-12 (sync). EP-01-08 wires the interface with a no-op/in-memory default so the repository compiles and the seam is explicit.
- **Repositories** for the reference slice:
  - `EntityRepository` (abstract interface).
  - `EntityRepositoryImpl` composing remote + local; cache-first read seam (delegates to local only when EP-01-11 provides it), remote-write-then-refresh pattern.
- **Provider** for the reference slice: `EntityProvider` (`ChangeNotifier`) exposing load state, profile, roles, and operation status to the widget tree.
- **Barrel/initializer**: `lib/data/data_layer.dart` exporting providers/repositories and a `registerDataLayer()` helper for EP-01-15 bootstrap (interface only — no `main.dart`/bootstrap edits).
- Unit tests: mapper round-trips, repository (mocked datasources), provider state transitions. No live backend; datasources mocked.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope

- Authentication framework, session persistence, route guarding — EP-01-09.
- SSL pinning, AES encryption, secure storage wrappers, token rotation — EP-01-10.
- Concrete local-storage drivers / cache manager / LRU-TTL — EP-01-11 (this task defines only the local-datasource **interface** + in-memory default).
- Offline sync queue, replay, conflict resolution — EP-01-12 (this task leaves the repository seam; does not implement sync).
- Connectivity monitoring — EP-01-13.
- Logging/Sentry concrete wiring of data-layer events — EP-01-14 (layer may call the EP-01-07 `ApiLogSink` surface but does not initialize monitoring).
- App bootstrap, GoRouter, splash — EP-01-15.
- Supabase migrations, RPC, RLS — EP-01-05/06 (consumed only).
- UI widgets, design system, localization, notifications — later phases.
- Native platform configuration changes.
- Implementing all nine tables as full repositories — only the **reference slice** (Entity + Profile + Role) is built; other entities clone the pattern in later tasks.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, escrow, verification-decision, or any server-enforced logic is permitted in this layer. The data layer **transports and abstracts**; it does not decide. All invariant enforcement remains server-side via EP-01-06 RPC + RLS (AGENT.md Rule 4).

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer | AGENT.md Rule 4, ARCHITECTURE.md |
| All backend access through one channel | EP-01-07 (`BaseApiService`); no feature-constructed clients |
| Repository abstraction over concrete backend | ARCHITECTURE.md `data/`, phase Risk (vendor lock-in) |
| Provider for state | EP-01 tech stack (confirmed) |
| No business logic in client | AGENT.md Rules 1, 4 |
| Errors normalized via `ApiException` | EP-01-07 §5.5; EP-01-05 `PLT###` contract |
| Secrets/config via `EnvironmentConfig` | EP-01-03; never read `String.fromEnvironment` here |

### 5.2 Proposed Structure

```text
lib/data/
├── entities/
│   ├── entity.dart                # aggregate: id, status, profile, roles
│   ├── entity_profile.dart        # legal_name, display_name, bio, avatar_path, country_code
│   └── entity_role.dart           # role (consumer/professional/merchant/rider), is_active
├── models/
│   ├── entity_dto.dart            # {id, status}
│   ├── entity_profile_dto.dart    # mirrors entity_profiles columns
│   └── entity_role_dto.dart       # mirrors entity_roles columns
├── mappers/
│   ├── entity_mapper.dart
│   ├── entity_profile_mapper.dart
│   └── entity_role_mapper.dart
├── datasources/
│   ├── remote/
│   │   ├── entity_remote_data_source.dart        # abstract interface
│   │   └── supabase_entity_remote_data_source.dart # impl via BaseApiService
│   └── local/
│       └── entity_local_data_source.dart         # abstract interface + InMemory default
├── repositories/
│   ├── entity_repository.dart      # abstract
│   └── entity_repository_impl.dart # remote + local composition
├── providers/
│   └── entity_provider.dart        # ChangeNotifier state
└── data_layer.dart                 # barrels + registerDataLayer() for EP-01-15
```

### 5.3 Entity / DTO Contract (reference slice, mirrors EP-01-06)

- `EntityProfileDto`: `legal_name`, `display_name`, `bio`, `avatar_path`, `country_code` + audit fields. `fromJson` tolerant of missing audit columns.
- `EntityRoleDto`: `role` (validated against EP-01-06 vocabulary `consumer|professional|merchant|rider`), `is_active`, `activated_at`.
- `Entity`: aggregate holding `EntityId`, `EntityStatus`, optional `EntityProfile`, `List<EntityRole>`. Domain layer exposes only getters — no mutation logic, no rules.

### 5.4 Remote Datasource (Supabase-backed, via BaseApiService)

- `SupabaseEntityRemoteDataSource` receives a `BaseApiService` instance (injected; never constructed internally).
- Reads use `supabase.from('entity_profiles').select().eq('entity_id', uid)` — self-scoped by RLS (EP-01-06 default-deny). Writes/role-shifts use EP-01-06 RPCs via `supabase.rpc('entity_profile_update', {...})`, `entity_roles_activate`, `entity_profession_bind`.
- **Never** uses `service_role`; **never** constructs Dio/Supabase clients; **never** embeds request-body business rules beyond forwarding typed params.
- All throws are normalized: catch transport/PostgREST/`PLT*` via the EP-01-07 `ApiExceptionMapper` (re-thrown as `ApiException`) so repositories/providers handle one typed error type.

### 5.5 Local Datasource (contract only)

- `EntityLocalDataSource` abstract: `Future<EntityProfileDto?> getProfile()`, `Future<void> saveProfile(...)`, `Future<void> clear()`.
- `InMemoryEntityLocalDataSource` default impl satisfies the interface with a simple map so the repository compiles and runs in tests/CI now.
- EP-01-11 replaces the default with SQLite/Hive/Isar-backed impl; EP-01-12 adds queue/replay. **No behavioral change to repositories/providers** because they depend on the interface only.

### 5.6 Repository

- `EntityRepository` abstract: `Future<EntityProfile> getProfile()`, `Future<void> updateProfile(...)`, `Future<void> activateRole(role)`, `Future<List<EntityRole>> getRoles()`.
- `EntityRepositoryImpl`:
  - Reads: attempt local (cache-first seam) → fallback remote → map to entity → populate provider.
  - Writes: remote (RPC) → on success refresh local + return mapped entity.
  - Converts `ApiException` into domain-friendly failures; **no business decisions**.

### 5.7 Provider

- `EntityProvider extends ChangeNotifier`: holds `AsyncValue`-style state (`idle|loading|loaded|error`), current `EntityProfile`, `List<EntityRole>`, last error (`ApiException`). Exposes `loadProfile()`, `updateProfile()`, `activateRole()` delegating to the repository. No Supabase/Dio imports.

### 5.8 Extensibility Hooks (for later tasks)

- Repository interfaces are the clone template for EP-02+ entities.
- Local datasource interface is the EP-01-11/12 integration seam.
- `data_layer.dart` `registerDataLayer()` is the EP-01-15 bootstrap hook (this task exports it; does not modify `main.dart`).

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `BaseApiService` | `lib/core/api/services/` (EP-01-07) | Supabase/Dio access for datasources |
| `ApiException` / mapper | `lib/core/api/exceptions/` (EP-01-07) | Typed error normalization |
| `EnvironmentConfig` | `lib/config/environments/` (EP-01-03) | Endpoint/key source (consumed transitively) |
| `entities/*` | `lib/data/entities/` | Pure-Dart domain models |
| `models/*` | `lib/data/models/` | DTOs mirroring EP-01-06 |
| `mappers/*` | `lib/data/mappers/` | DTO ↔ entity |
| `datasources/remote/*` | `lib/data/datasources/remote/` | Supabase-backed access via BaseApiService |
| `datasources/local/*` | `lib/data/datasources/local/` | Interface + in-memory default (EP-01-11 fills) |
| `repositories/*` | `lib/data/repositories/` | Abstraction + composition |
| `providers/entity_provider.dart` | `lib/data/providers/` | State to UI |
| `data_layer.dart` | `lib/data/` | Barrels + bootstrap hook |
| Test suite | `test/unit/data/` | Mapper, repository, provider tests |

No new dependency added (all packages pinned in EP-01-02; Supabase/Dio from EP-01-07).

---

## 7. Data Requirements

- Only the reference-slice data shapes are modeled: `entities` (minimal: id, status), `entity_profiles`, `entity_roles`. All shapes derived strictly from EP-01-06 column/RPC definitions.
- No operational data is created, seeded, or persisted by this task. The in-memory local default holds nothing across sessions.
- DTOs must round-trip the EP-01-06 envelope `{success, code, message, data}` where RPCs return it, mapping `data` into the DTO without surfacing raw `code`/`message` strings to the UI.
- Mappers must be null-safe and tolerant of absent optional columns (e.g., `bio`, `avatar_path`).

---

## 8. Database Considerations

Not applicable to this **client** task. The layer consumes the EP-01-06 schema/RPC contract only; it neither defines nor alters migrations, RLS, or grants. All enforcement (self-scoping, verification gating, RPC validation) remains server-side. The DTO column names must exactly match EP-01-06 to avoid silent deserialization drift; a contract-stability note is recorded (any EP-01-06 column/RPC change requires lead-approved amendment before this layer adapts).

---

## 9. API Requirements

- **No new endpoints/RPCs** are defined. The layer is the **client-side consumer** of the EP-01-06 RPC contract (`entity_profile_update`, `entity_roles_activate`, `entity_profession_bind`) and self-scoped PostgREST reads, both reached through EP-01-07 `BaseApiService`.
- Defines the **client data contract**: DTO field names/types mirror EP-01-06 exactly; `ApiException` is the only error type crossing the repository boundary.
- The local-datasource interface is the downstream contract for EP-01-11 (storage) and EP-01-12 (sync).

---

## 10. User Interface Requirements

Not applicable. No widgets, screens, or routing in this task. `EntityProvider` is exported for future UI consumption; `main.dart`/bootstrap unchanged (hook only).

---

## 11. User Experience Considerations

Developer/operator experience only:

- A single, copy-able vertical slice gives every EP-02+ engineer a proven template (entity → dto → mapper → datasource → repository → provider).
- Uniform typed errors (`ApiException`) make feature failure handling predictable.
- Cache-first read seam positions the layer for offline support once EP-01-11/12 land, with no later refactor.
- `registerDataLayer()` provides a one-call bootstrap hook for EP-01-15.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Bypassing the API/interceptor chain | Datasources access Supabase **only** through injected `BaseApiService`; no feature-constructed clients, no `Dio()` literals |
| Raw error / SQL leakage to UI | All throws normalized to `ApiException` via EP-01-07 mapper before crossing repository boundary |
| Business logic in client | Layer transports/maps only; no pricing/matching/verification decisions (AGENT.md Rule 4) |
| PII in logs | Mappers/providers never log `legal_name`/`display_name`/`bio`; rely on EP-01-07 redacting `ApiLogSink` |
| Vendor lock-in | Concrete Supabase types confined to `datasources/remote/`; repositories/providers/entities depend on abstractions only |
| Secret/key exposure | No `String.fromEnvironment`; config sourced transitively via EP-01-03 through EP-01-07 |
| Unauthorized writes | Client calls only self-scoped reads + EP-01-06 RPCs (no verification-state/client-forbidden paths exist) |

---

## 13. Performance Considerations

- Repositories depend on interfaces; no heavy per-call object graphs. DTOs are lightweight `fromJson` maps.
- Cache-first read seam avoids redundant network calls once EP-01-11 provides persistence (no behavior change now).
- Mappers are pure, allocation-light, no I/O.
- Provider `notifyListeners()` called only on real state transitions (no polling in this task; EP-01-13/15 drive refresh).
- No impact on the 15–20 MB installer (no new packages/assets).

---

## 14. Testing Strategy

### 14.1 Unit — Mappers
- `EntityProfileDto.fromJson` → `EntityProfile` → `toJson` round-trip; optional-field tolerance (null `bio`/`avatar_path`); vocabulary validation of `role`.

### 14.2 Unit — Repository (mocked datasources)
- `getProfile()` returns mapped entity from mocked remote; cache-first path delegates to local when provided.
- `updateProfile()` calls RPC via remote, refreshes local, returns mapped entity.
- `activateRole()` invokes `entity_roles_activate` RPC; `ApiException` propagates as domain failure (no swallowed errors).

### 14.3 Unit — Provider
- `loadProfile()` transitions `idle→loading→loaded`; error sets `error` state with `ApiException`; no Supabase/Dio imports in test.

### 14.4 Project Validation
- `flutter analyze` (strict lints; no `print`; no `implicit_dynamic`).
- `flutter test` — all new unit tests pass.
- Available platform smoke build (no native changes).

### 14.5 Scope Validation
- Diff review: only `lib/data/` + `test/unit/data/`. No bootstrap/UI/DB/auth/security/monitoring implementation leaked. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-06 (schema/RPC shapes) and EP-01-07 (`BaseApiService`, `ApiException`) deliverables; confirm `lib/data/` subfolders empty (`.gitkeep` only).
2. Implement `entities/` (pure Dart): `entity.dart`, `entity_profile.dart`, `entity_role.dart`.
3. Implement `models/` DTOs mirroring EP-01-06 columns/RPC params.
4. Implement `mappers/` (DTO ↔ entity), null-safe.
5. Implement `datasources/remote/entity_remote_data_source.dart` (abstract) + `supabase_entity_remote_data_source.dart` (via `BaseApiService`).
6. Implement `datasources/local/entity_local_data_source.dart` (abstract + `InMemoryEntityLocalDataSource` default).
7. Implement `repositories/entity_repository.dart` (abstract) + `entity_repository_impl.dart` (composition, cache-first seam).
8. Implement `providers/entity_provider.dart` (`ChangeNotifier`).
9. Implement `data_layer.dart` (barrels + `registerDataLayer()` hook for EP-01-15).
10. Add `test/unit/data/` tests (mappers, repository with mocked datasources, provider).
11. Run `flutter analyze` and `flutter test`.
12. Available platform smoke builds (no native changes).
13. Review final diff for strict EP-01-08 scope containment and phase-document integrity.
14. **Stop at the approval gate** — do not wire `main.dart`, build other repositories, or implement downstream tasks (EP-01-09+).

---

## 16. Expected Outcome

- A uniform, abstracted data-access layer in `lib/data/` with a proven vertical reference slice (Entity + Profile + Role) demonstrating entity → DTO → mapper → remote datasource → repository → provider.
- Concrete Supabase access confined to `datasources/remote/` behind `BaseApiService`; repositories/providers/entities depend on abstractions only (vendor-lock-in mitigation satisfied).
- A local-datasource interface + in-memory default that EP-01-11/12 will fulfill without reshaping the layer.
- Typed `ApiException`-only error flow across the repository boundary; no raw/SQL leakage.
- Unit tests proving mappers, repository composition, and provider state without a live backend.
- A `registerDataLayer()` hook ready for EP-01-15 bootstrap, with `main.dart` unchanged.
- Clean clone template for every EP-02+ data domain.

---

## 17. Definition of Done (DoD)

**Structure & Code**
- [ ] `lib/data/` contains the §5.2 structure, all files implemented and importing correctly.
- [ ] `entities/` are pure Dart (no Flutter/Supabase/Dio imports); no business logic present.
- [ ] DTOs in `models/` exactly mirror EP-01-06 columns/RPC params; null-safe `fromJson`/`toJson`.
- [ ] `mappers/` correctly transform DTO ↔ entity; optional-field tolerant.
- [ ] `datasources/remote/` accesses Supabase **only** via injected `BaseApiService`; no constructed clients; RLS self-scoped reads + EP-01-06 RPC calls only.
- [ ] `datasources/local/` defines the abstract interface + in-memory default; no EP-01-11 storage code.
- [ ] `repositories/` expose abstract `EntityRepository` + `EntityRepositoryImpl` composing remote + local with cache-first seam.
- [ ] `providers/entity_provider.dart` (`ChangeNotifier`) exposes load state/profile/roles/error with no Supabase/Dio imports.
- [ ] `data_layer.dart` exports barrels + `registerDataLayer()` hook; `main.dart`/bootstrap unchanged.

**Errors & Security**
- [ ] All datasource throws normalized to `ApiException` (via EP-01-07 mapper) before crossing the repository boundary.
- [ ] No business/pricing/matching/verification logic in the layer (AGENT.md Rule 4).
- [ ] No `String.fromEnvironment`, hardcoded endpoint, or secret in source.
- [ ] No client path to verification-state or other EP-01-06 forbidden columns/RPCs.

**Testing & Validation**
- [ ] Unit tests cover mapper round-trips, repository (mocked datasources, cache-first + error paths), and provider state transitions; all pass.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes.
- [ ] Available platform smoke builds pass (no native config changed).
- [ ] Final diff contains only approved EP-01-08 changes.

**Containment**
- [ ] No auth framework, security, storage drivers, sync engine, monitoring, UI, bootstrap, or DB/migration code included.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Very High**

### Reasoning Level Justification

- **Technical complexity:** High — designing a correct repository/datasource/mapper/provider layering with clean abstraction seams, cache-first composition, and a clone-able reference pattern requires precise structural reasoning; mistakes produce pervasive drift across EP-02+.
- **Business impact:** High — every future feature's data path is built on this layer; a weak abstraction forces rework platform-wide.
- **Security risk:** Medium-high — must guarantee all access flows through the EP-01-07 interceptor chain (auth/error/secret-redaction) and never embeds client-side business logic or forbidden RPC paths (AGENT.md Rule 4).
- **Performance sensitivity:** Medium — cache-first seam and provider notification discipline affect later offline/low-bandwidth behavior but are not on the hot transaction path now.
- **Data complexity:** Medium-high — must faithfully mirror the EP-01-06 Universal Entity shapes (fluid roles, profile anchor, RPC envelopes) without leaking server invariants into the client.
- **Integration complexity:** Very high — must consume EP-01-06's schema/RPC contract and EP-01-07's `BaseApiService`/`ApiException` exactly, while exposing stable seams for EP-01-09 (auth), EP-01-11 (storage), EP-01-12 (sync), and EP-01-15 (bootstrap) without coupling them to implementation.

Very High matches the approved EP-01 matrix (EP-01-08 = Very High) and the foundational, cross-cutting nature of the data layer.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-08-Unified-Data-Access-Layer.md` (matching the established task-plan format; a separate `EP-01-08-Definition-of-Done.md` will be produced at completion per established practice). Implementation will begin only after a separate implementation approval. No production code is written during planning.
