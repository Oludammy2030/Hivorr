# Definition of Done — EP-01-08: Unified Data Access Layer

| Field | Value |
|---|---|
| Task ID | EP-01-08 |
| Task Name | Unified Data Access Layer |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Reference Implementation Plan | `documents/Task-Implementation/EP-01/EP-01-08-Unified Data Access Layer.md` |
| Priority | High |
| Status | Completed (implementation verified: `flutter analyze` clean, 11/11 unit tests passing, web + android smoke builds green) |

---

## 1. Task Identification

- **Task ID:** EP-01-08
- **Task Name:** Unified Data Access Layer
- **Related Phase:** EP-01 — Core Platform Foundation & Infrastructure
- **Reference Implementation Plan:** `documents/Task-Implementation/EP-01/EP-01-08-Unified Data Access Layer.md`
- **Dependencies (must be completed):** EP-01-06 (Universal Entity schema + RPC contract), EP-01-07 (Core API layer `BaseApiService` / `ApiException` / Supabase + Dio clients)
- **Scope Summary:** Establish the client-side `lib/data/` data-access layer with a complete vertical reference slice (Entity → DTO → RemoteDataSource → Mapper → Repository → Provider), abstract repository interfaces for vendor-lock-in mitigation, a local-datasource contract (filled by EP-01-11/12), and unit tests. No business logic, no UI, no migrations.

---

## 2. Functional Verification

### 2.1 Required Functionality
- [ ] The `lib/data/` module structure matches §5.2 of the plan (entities, models, mappers, datasources/remote, datasources/local, repositories, providers, data_layer.dart).
- [ ] Domain entities (`Entity`, `EntityProfile`, `EntityRole`) exist as pure Dart (no Flutter/Supabase/Dio imports) and represent the fluid Universal Entity from EP-01-06 (D1–D4).
- [ ] DTOs (`EntityDto`, `EntityProfileDto`, `EntityRoleDto`) mirror EP-01-06 column/RPC shapes with null-safe `fromJson`/`toJson`.
- [ ] Mappers transform DTO ↔ entity correctly.
- [ ] `EntityRemoteDataSource` (abstract + `SupabaseEntityRemoteDataSource`) reads self-scoped `entity_profiles` and calls EP-01-06 RPCs (`entity_profile_update`, `entity_roles_activate`, `entity_profession_bind`) via the injected `BaseApiService`.
- [ ] `EntityLocalDataSource` abstract + `InMemoryEntityLocalDataSource` default exist (no EP-01-11 storage code).
- [ ] `EntityRepository` (abstract) + `EntityRepositoryImpl` compose remote + local with a cache-first read seam.
- [ ] `EntityProvider` (`ChangeNotifier`) exposes load state, profile, roles, and error.
- [ ] `data_layer.dart` exports barrels + `registerDataLayer()` hook for EP-01-15; `main.dart`/bootstrap unchanged.

### 2.2 Expected Workflows
- [ ] **Load profile:** `EntityProvider.loadProfile()` → repository reads (local fallback → remote) → maps DTO → populates provider `loaded` state with `EntityProfile`.
- [ ] **Update profile:** `updateProfile(...)` → remote RPC `entity_profile_update` → on success refreshes local + returns mapped entity.
- [ ] **Activate role:** `activateRole(role)` → remote RPC `entity_roles_activate` → repository reflects new `EntityRole` state.
- [ ] **Get roles:** `getRoles()` returns `List<EntityRole>` from self-scoped remote read.

### 2.3 Success Conditions
- [ ] All reads/writes return correctly mapped domain entities (not raw JSON).
- [ ] Provider transitions `idle → loading → loaded` on success.
- [ ] Remote calls use only the EP-01-07 `BaseApiService` (auth token injected, errors normalized, logs redacted by the API layer).
- [ ] Cache-first seam delegates to local when a concrete local source is supplied (no behavior change with the in-memory default today).

### 2.4 Error Handling Scenarios
- [ ] Any transport/PostgREST/`PLT*` failure from the remote datasource is normalized to `ApiException` (via EP-01-07 mapper) before crossing the repository boundary.
- [ ] `EntityProvider` surfaces error state with the `ApiException` (no raw SQL/stack/secret leakage to callers).
- [ ] `activateRole()` with an unknown role propagates the server's `PLT003` as a typed `ApiException` (client does not validate business vocabulary beyond forwarding).
- [ ] No swallowed exceptions; failures are observable to the caller/provider.

### 2.5 Important User Interactions (developer/consumer)
- [ ] EP-02+ engineers can clone the `Entity` slice to build new repositories without altering core structure.
- [ ] `registerDataLayer()` is callable from EP-01-15 bootstrap without modifying this task's files.
- [ ] Consumers depend only on abstract `EntityRepository` / `EntityProvider`, never on `SupabaseEntityRemoteDataSource` concrete type.

---

## 3. Technical Verification

### 3.1 Architecture Compliance
- [ ] All code resides under `lib/data/` (no new top-level `lib/` directory).
- [ ] Concrete Supabase/Dio usage is confined to `datasources/remote/`; repositories, providers, and entities depend only on abstractions/interfaces.
- [ ] Data flow respects ARCHITECTURE.md `data/` mapping (models, entities, repositories, providers, datasources, mappers).
- [ ] Provider (not a different state library) is used for state management per the confirmed stack.

### 3.2 Required System Behavior
- [ ] Remote datasource accesses Supabase **only** through the injected `BaseApiService.supabase` accessor; it never constructs `SupabaseClient`, `Dio`, or calls `Supabase.initialize`.
- [ ] Reads are self-scoped (RLS `auth.uid()` enforced server-side per EP-01-06); the client never requests cross-entity data.
- [ ] Only EP-01-06 RPCs and self-scoped PostgREST reads are invoked — no verification-state or client-forbidden paths exist.

### 3.3 Module Integration
- [ ] Compiles against EP-01-07 `BaseApiService`, `ApiException`, `ApiExceptionMapper`, `ApiLogSink`.
- [ ] `data_layer.dart` integrates cleanly as a bootstrap hook target for EP-01-15.
- [ ] Local-datasource interface aligns with the future EP-01-11 storage contract and EP-01-12 sync seam (no later refactor required to fulfill it).

### 3.4 Technical Requirements from the Plan
- [ ] No new package added to `pubspec.yaml` (all from EP-01-02/07).
- [ ] DTOs exactly match EP-01-06 column/RPC param names (no silent deserialization drift).
- [ ] `flutter analyze` passes with strict lints; no `print`; no `implicit_dynamic`.
- [ ] No `String.fromEnvironment` usage; config sourced transitively via EP-01-03 → EP-01-07.

---

## 4. Data Verification

### 4.1 Data Creation
- [ ] No operational/business data is created or seeded by this task.
- [ ] The in-memory local default holds nothing across sessions (no persistence side effect).
- [ ] RPC invocations forward only typed parameters; no fabricated rows client-side.

### 4.2 Data Updates
- [ ] `updateProfile()` maps client input → `entity_profile_update` RPC params per EP-01-06 shape; server performs validation/audit.
- [ ] `activateRole()` maps role string → `entity_roles_activate` param exactly.

### 4.3 Data Relationships
- [ ] DTO ↔ entity mapping preserves the aggregate relationship (Entity holds profile + roles).
- [ ] `EntityRole` vocabulary matches EP-01-06 (`consumer|professional|merchant|rider`).

### 4.4 Data Accuracy
- [ ] Mapper round-trip (`Dto.fromJson → Entity → Dto.toJson`) preserves all modeled fields.
- [ ] Optional fields (`bio`, `avatar_path`) tolerate null without throwing.

### 4.5 Data Integrity
- [ ] DTO field names/types match EP-01-06 exactly (verified by reading the schema/RPC contract, not assumptions).
- [ ] Any future EP-01-06 column/RPC change is flagged as requiring a lead-approved amendment before this layer adapts (contract-stability note honored).

---

## 5. Security Verification

### 5.1 Authentication
- [ ] Remote calls inherit EP-01-07 auth-token injection (no manual token handling in this layer).
- [ ] No session/token logic implemented here (owned by EP-01-09).

### 5.2 Authorization
- [ ] Client calls only self-scoped reads + EP-01-06 RPCs; no privileged/server-only transitions are reachable.
- [ ] No client path to verification-state columns or other EP-01-06 forbidden fields.

### 5.3 Access Control
- [ ] All backend access flows through the single EP-01-07 channel (no feature-constructed clients, no `Dio()` literals).
- [ ] Concrete Supabase types confined to `datasources/remote/` behind interfaces (vendor lock-in + blast-radius control).

### 5.4 Sensitive Data Protection
- [ ] Mappers/providers do not log `legal_name`, `display_name`, or `bio` (relies on EP-01-07 redacting `ApiLogSink`).
- [ ] No `ApiException` message/raw value containing SQL or secrets crosses the repository boundary.

### 5.5 Security Rules
- [ ] AGENT.md Rule 4 upheld: no business/pricing/matching/verification logic in the layer.
- [ ] No `String.fromEnvironment`, hardcoded endpoint, or secret in source.
- [ ] EP-01-03/07 secret-handling invariants preserved transitively.

---

## 6. Performance Verification

### 6.1 Response Performance
- [ ] No synchronous blocking I/O in mappers/providers.
- [ ] Provider `notifyListeners()` invoked only on real state transitions (no polling in this task).

### 6.2 Resource Usage
- [ ] Repositories depend on interfaces; no heavy per-call object graphs.
- [ ] DTOs are lightweight `fromJson` maps; mappers allocation-light, no I/O.
- [ ] No impact on the 15–20 MB installer target (no new packages/assets).

### 6.3 System Reliability
- [ ] Cache-first read seam avoids redundant network calls once EP-01-11 provides persistence (no behavior change now).
- [ ] Error states are recoverable; a failed load does not leave the provider in a corrupted state.

### 6.4 Performance Expectations
- [ ] Unit tests execute quickly with no live backend (datasources mocked).
- [ ] No performance-regression in `flutter analyze` / `flutter test` within CI budget.

---

## 7. Testing Verification

### 7.1 Manual Testing Requirements
- [ ] Code review confirms `lib/data/` matches §5.2 structure and scope containment.
- [ ] Diff review confirms only `lib/data/` + `test/unit/data/` changed; no bootstrap/UI/DB/auth/security/monitoring leaked; no phase-document edits.

### 7.2 Automated Testing Requirements
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes, including all new `test/unit/data/` tests.
- [ ] Available platform smoke build passes (no native config changed).

### 7.3 Edge Cases
- [ ] Mapper handles null optional fields (`bio`, `avatar_path`).
- [ ] `getProfile()` cache-first path delegates to local when a local source is provided; falls back to remote otherwise.
- [ ] Repository handles `ApiException` from remote without swallowing; propagates as domain failure.
- [ ] `activateRole()` with unknown role propagates server `PLT003` as typed error.

### 7.4 Failure Scenarios
- [ ] Network/timeout failure → normalized `ApiException` → provider `error` state (no raw leakage).
- [ ] `401`/expired session → handled by EP-01-07 interceptor (refresh + single retry) before reaching this layer; this layer only sees the eventual typed result/error.
- [ ] Local in-memory default returns null/empty gracefully when empty (no crash).

---

## 8. User Acceptance Verification

- [ ] A downstream engineer (or lead) can clone the `Entity` slice to scaffold a new repository following the documented pattern without structural changes.
- [ ] `registerDataLayer()` is usable by EP-01-15 bootstrap without modifying EP-01-08 files.
- [ ] The reference slice demonstrably proves the full data path: entity → DTO → mapper → remote datasource → repository → provider.
- [ ] The local-datasource interface is clearly the integration point for EP-01-11 (storage) and EP-01-12 (sync), with no later refactor required.
- [ ] No business logic, pricing, matching, or financial rules are present in the layer (AGENT.md Rules 1, 4 honored).

---

## 9. Final Approval Checklist

- [ ] `lib/data/` contains the §5.2 structure; all files implemented and import correctly.
- [ ] `entities/` are pure Dart (no Flutter/Supabase/Dio imports); no business logic present.
- [ ] DTOs in `models/` exactly mirror EP-01-06 columns/RPC params; null-safe `fromJson`/`toJson`.
- [ ] `mappers/` correctly transform DTO ↔ entity; optional-field tolerant.
- [ ] `datasources/remote/` accesses Supabase **only** via injected `BaseApiService`; no constructed clients; RLS self-scoped reads + EP-01-06 RPC calls only.
- [ ] `datasources/local/` defines the abstract interface + in-memory default; no EP-01-11 storage code.
- [ ] `repositories/` expose abstract `EntityRepository` + `EntityRepositoryImpl` composing remote + local with cache-first seam.
- [ ] `providers/entity_provider.dart` (`ChangeNotifier`) exposes load state/profile/roles/error with no Supabase/Dio imports.
- [ ] `data_layer.dart` exports barrels + `registerDataLayer()` hook; `main.dart`/bootstrap unchanged.
- [ ] All datasource throws normalized to `ApiException` (via EP-01-07 mapper) before crossing the repository boundary.
- [ ] No business/pricing/matching/verification logic in the layer (AGENT.md Rule 4).
- [ ] No `String.fromEnvironment`, hardcoded endpoint, or secret in source.
- [ ] No client path to verification-state or other EP-01-06 forbidden columns/RPCs.
- [ ] Unit tests cover mapper round-trips, repository (mocked datasources, cache-first + error paths), and provider state transitions; all pass.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes.
- [ ] Available platform smoke builds pass (no native config changed).
- [ ] Final diff contains only approved EP-01-08 changes.
- [ ] No auth framework, security, storage drivers, sync engine, monitoring, UI, bootstrap, or DB/migration code included.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Project lead has verified functional, technical, data, security, performance, testing, and user-acceptance sections above.
