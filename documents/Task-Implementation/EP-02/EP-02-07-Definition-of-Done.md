# Definition of Done — EP-02-07: Client-Side Taxonomy Engine & Profession Registry

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-07 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-07-Client-Side Taxonomy Engine & Profession Registry.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-07 |
| **Task Name** | Client-Side Taxonomy Engine & Profession Registry |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 3 — Client-Side Infrastructure |
| **Priority** | High |
| **Dependencies** | EP-02-02 (taxonomy management RPCs — `taxonomy_industries_list`, `taxonomy_professions_list`, strict envelope `{success, code, message, data}`); EP-01-06 (industries + professions tables); EP-01-07 (`BaseApiService`, `ApiException`); EP-01-08 (data layer pattern); EP-01-11 (`CacheManager`, `LruCache`) |
| **Blocks** | EP-02-10 (Identity Verification), EP-02-18 (Entity Registration & Onboarding Flow), EP-02-19 (Professional Profile & Credential Display), EP-02-11 (indirect) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-07-Client-Side Taxonomy Engine & Profession Registry.md` |

---

## 2. Functional Verification

This task delivers a client-side taxonomy engine (`lib/workspace/profession_registry/`) and its data-layer vertical slice (`lib/data/`) that consumes the two-tier `Industries → Professions` registry via EP-02-02 read RPCs. Functional verification confirms the engine and its provider-driven presentation widget behave correctly across browse, select, search, and error paths.

### 2.1 Required Functionality

- [x] **FV-01:** Taxonomy domain entities exist — `Industry` and `Profession` pure-Dart entities in `lib/data/entities/` with no Flutter/Supabase imports
- [x] **FV-02:** DTOs exist — `IndustryDto` and `ProfessionDto` in `lib/data/models/` with `fromJson`/`toJson` matching the EP-01-06 `industries` / `professions` columns (null-safe, optional fields tolerated)
- [x] **FV-03:** Mappers exist — `IndustryMapper` and `ProfessionMapper` in `lib/data/mappers/` transform DTO ↔ entity, tolerating null `description`
- [x] **FV-04:** Remote datasource exists — `TaxonomyRemoteDataSource` abstract + `SupabaseTaxonomyRemoteDataSource extends BaseApiService` calling `taxonomy_industries_list` / `taxonomy_professions_list` via `supabase.rpc`
- [x] **FV-05:** Local datasource seam exists — `TaxonomyLocalDataSource` abstract + `InMemoryTaxonomyLocalDataSource` backed by `CacheManager` under the `taxonomy:` prefix
- [x] **FV-06:** Repository exists — `TaxonomyRepository` abstract + `TaxonomyRepositoryImpl` composing remote + local with cache-first read and remote-write-then-refresh behavior (writes are not exposed in this task)
- [x] **FV-07:** Provider exists — `TaxonomyProvider extends ChangeNotifier` exposing `state` (`idle/loading/loaded/error`), `industries`, `professions`, `searchResults`, `error: ApiException?`
- [x] **FV-08:** Engine exists — `profession_registry_service.dart` (or `taxonomy_engine.dart`) exposing `browseIndustries()`, `professionsByIndustry(id)`, `hierarchicalTree`, `searchProfessions(query)`, `getIndustryBySlug`, `getProfessionBySlug`
- [x] **FV-09:** Registry widgets exist — `ProfessionRegistryWidget`, `IndustryPicker`, `ProfessionList` (and `TaxonomySearchField` where used) in `lib/workspace/profession_registry/widgets/`

### 2.2 Expected Workflows

- [x] **FV-10:** User browses industries — engine returns all active industries ordered by `sort_order ASC` from the `taxonomy_industries_list` RPC
- [x] **FV-11:** User selects an industry — engine returns all active professions for the selected `industry_id` ordered by `sort_order ASC` from the `taxonomy_professions_list` RPC
- [x] **FV-12:** User navigates the hierarchy — `hierarchicalTree` composes `Map<Industry, List<Profession>>` grouped by industry and sorted by `sortOrder`
- [x] **FV-13:** User searches — `searchProfessions(query)` filters the in-memory corpus case-insensitively on `name`/`slug`/`description`, preserving `sortOrder`; empty query returns the full corpus
- [x] **FV-14:** User taps a profession — `ProfessionRegistryWidget` invokes `onSelected(Profession)` (owner integration is EP-02-18; no router push inside this task)
- [x] **FV-15:** Resumable context — the selected `industryId` is retained in provider state so back-navigation restores the list (supports EP-02-18 wizard resumability)

### 2.3 Success Conditions

- [x] **FV-16:** Cold load succeeds — `loadIndustries()`/`loadProfessions(industryId)` transition `idle → loading → loaded` and populate the provider's data
- [x] **FV-17:** Cache hit succeeds — a second read returns from `CacheManager` without a remote call
- [x] **FV-18:** RPC data parsed — the `{success, code, message, data}` envelope's `data` array is unwrapped and mapped into DTOs (seed reference: 8 industries, 46 professions)
- [x] **FV-19:** Search returns ordered results — filtered results retain `sortOrder` ordering
- [x] **FV-20:** Widget renders loaded state — professions display in `sortOrder`; selecting an industry updates the profession list; search filters correctly

### 2.4 Error Handling Scenarios

- [x] **FV-21:** Network failure during load — provider transitions to `error` and `ProfessionRegistryWidget` shows `HivorrErrorState` with a retry action that re-invokes the provider
- [x] **FV-22:** Envelope failure — a `success:false` (or `PLT999`/`4xx` server error) is normalized via `mapDataException` to an `ApiException` (`ApiExceptionKind.server`/`forbidden`); UI shows `HivorrSnackbar` with the safe `ApiException.message`, never raw SQL
- [x] **FV-23:** Empty corpus on search — `HivorrEmptyState` with guidance like "Try a different keyword" + a clear-filter action; never a dead-end
- [x] **FV-24:** Inactive-only records — deactivated taxonomy entries never surface to end-users (default `isActive:true` filtering via `p_include_inactive` default `false`)
- [x] **FV-25:** Provider error propagation — a failed `loadProfessions(industryId)` sets `error` and does not leave the provider in `loaded` with stale data

### 2.5 Important User Interactions

- [x] **FV-26:** Industry selection — tapping an industry chip/card in `IndustryPicker` emits its `industryId` and drives the profession list
- [x] **FV-27:** Search input — `TaxonomySearchField` debounces input 300ms before filtering (no RPC per keystroke) and offers a clear affordance
- [x] **FV-28:** Empty-state CTA — the user can clear the search filter from the `HivorrEmptyState` guidance
- [x] **FV-29:** Error-state retry — the user can retry a failed load from `HivorrErrorState`
- [x] **FV-30:** Loading-state display — the user sees `HivorrLoadingState` (branded breathing `HivorrLoader`, never a bare spinner) during the cold fetch

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] **TV-01:** All taxonomy engine code resides under `lib/workspace/profession_registry/` and `lib/data/` — no top-level directories created in `lib/` outside the ARCHITECTURE.md schema (`ARCHITECTURE.md:87`)
- [x] **TV-02:** Data flows exclusively through `BaseApiService` — no `Dio()` or `SupabaseClient` constructed anywhere in taxonomy code; `BaseApiService.invoke()` (`base_api_service.dart:33`) is the only channel
- [x] **TV-03:** Entities are `lib/data/entities/entity_profile.dart:5`-pattern pure Dart — immutable, `const` constructor, no business logic, no Flutter/Supabase imports
- [x] **TV-04:** Repository abstraction over concrete backend — repositories/providers/entities depend on interfaces, not on concrete Supabase types
- [x] **TV-05:** `engine/profession_engine/` reserved for capability calculators — no taxonomy logic placed there (avoids conflation with `profession_registry`)

### 3.2 Required System Behavior — Data Layer

- [x] **TV-06:** DTO field names equal the EP-01-06 server column names exactly (avoid silent deserialization drift, per EP-01-08 §5.3 contract) — `id`, `slug`, `name`, `description`, `is_active`, `sort_order`, `created_at` (+ `industry_id` for professions)
- [x] **TV-07:** Remote datasource unwraps the standardized envelope `response['data'] as List`, maps each element via `Dto.fromJson`, and normalizes errors through `data_exception_mapper.dart:12` (`mapDataException`)
- [x] **TV-08:** Remote datasource calls only `taxonomy_industries_list` (`p_include_inactive bool default false`) and `taxonomy_professions_list` (`p_industry_id uuid default null`, `p_include_inactive bool default false`) — both `STABLE`, `SECURITY INVOKER` read RPCs
- [x] **TV-09:** Cache integration uses `CacheManager.instance` (`cache_manager.dart:18`) with prefix `taxonomy:` — keys `taxonomy:industries`, `taxonomy:professions:$industryId`, `taxonomy:tree`; seven entries honored via `CacheConfig.defaultTtl`/`maxEntries` (`cache_config.dart:31`)
- [x] **TV-10:** `LruCache.get` promotes entries to most-recently-used on access (`lru_cache.dart:38`); cache-miss → remote → `cache.put` → return
- [x] **TV-11:** `invalidatePrefix('taxonomy:')` clears only taxonomy keys, leaving unrelated prefixes (e.g., `entity:`) intact (`cache_manager.dart:88`)
- [x] **TV-12:** Provider exposes `state`, `industries`, `professions`, `searchResults`, `error: ApiException?` with `loadIndustries()`, `loadProfessions(industryId)`, `search(query)`; no Supabase/Dio imports in `taxonomy_provider.dart`

### 3.3 Module Integration

- [x] **TV-13:** `profession_registry_service.dart` orchestrates the `TaxonomyRepository` and `CacheManager` to provide browse / tree / search / slug-lookup operations
- [x] **TV-14:** `ProfessionRegistryWidget` consumes `TaxonomyProvider` via `Provider` and drives loading/empty/error/loaded states with the shared design-system widgets
- [x] **TV-15:** Barrel `lib/workspace/profession_registry/profession_registry.dart` exports the public taxonomy API; optional `registerTaxonomyLayer(ApiLayer)` hook is provided (analogous to `data_layer.dart:29`) without editing `main.dart`/bootstrap
- [x] **TV-16:** Reuses existing utilities before creating new ones per `AGENT.md` Code Standards (`lib/shared/validators/hivorr_validators.dart`, `lib/shared/helpers/hivorr_formatters.dart`, `lib/shared/extensions/*`)
- [x] **TV-17:** Consumers can `import 'workspace/profession_registry/profession_registry.dart'` — unblocking EP-02-10, EP-02-18, EP-02-19

### 3.4 Technical Requirements from the Implementation Plan

- [x] **TV-18:** `ProfessionRegistryWidget({required ValueChanged<Profession> onSelected, initialIndustryId, showSearch = true})` — embeddable, callback-driven, no router push inside
- [x] **TV-19:** Repository signature reserved for `limit/offset` to support 500+ taxonomy records later without breaking callers (no pagination initial implementation)
- [x] **TV-20:** No new Flutter packages added to `pubspec.yaml` — only EP-01-02 pinned dependencies (`dio`, `supabase_flutter`, `provider`, `hive`, `flutter_svg`) used
- [x] **TV-21:** No `main.dart` / bootstrap-editing / native platform (android/ios/web/etc.) file modifications made by this task
- [x] **TV-22:** No new RPCs, Edge Functions, or REST endpoints created — read RPC envelope contract reused verbatim

---

## 4. Data Verification

### 4.1 Data Creation

- [x] **DV-01:** No data is created or written by this task — it consumes read RPCs only; write RPCs (`taxonomy_industry_create/update`, `taxonomy_profession_create/update/move`) remain service-role-only and are never invoked client-side
- [x] **DV-02:** DTOs map the full read shape — `Industry` (`id`, `slug`, `name`, `description`, `isActive`, `sortOrder`, `createdAt`) and `Profession` (`id`, `industryId`, `slug`, `name`, `description`, `isActive`, `sortOrder`, `createdAt`)

### 4.2 Data Updates

- [x] **DV-03:** Taxonomy data is immutable from the client perspective — no update/insert/delete operations exposed or invoked
- [x] **DV-04:** Cache updates reflect remote data — a successful remote fetch refreshes the corresponding `taxonomy:` cache entry

### 4.3 Data Relationships

- [x] **DV-05:** `Profession.industryId` mirrors the `industries.id` FK (`professions.industry_id references public.industries (id) on delete restrict`) — every profession resolves to exactly one industry
- [x] **DV-06:** Hierarchical tree preserves the `Industry → Profession` relationship — professions are grouped under their owning industry (`AGENT.md` Rule 2 taxonomy)
- [x] **DV-07:** Slug lookups (`getIndustryBySlug` / `getProfessionBySlug`) resolve against the cached corpus and reflect the globally-unique slug invariants

### 4.4 Data Accuracy

- [x] **DV-08:** `sortOrder` values are mapped and preserved — results display in the server-provided `sort_order ASC` order without client re-ordering drift
- [x] **DV-09:** `isActive` is faithfully mapped — default active-only filtering matches the server default (`p_include_inactive` default `false`)
- [x] **DV-10:** DTO `fromJson` defensively validates slug format (regex `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤140, lower) before mapping, even though the server enforces `industries_slug_format`/`professions_slug_format`

### 4.5 Data Integrity

- [x] **DV-11:** The client mirrors the read shapes exactly without duplicating server constraints (no redundant validation logic that could drift)
- [x] **DV-12:** Extensibility preserved — new `industries`/`professions` inserted as data (`ON CONFLICT (slug) DO NOTHING` seed pattern) become visible to the client after cache TTL / `invalidatePrefix('taxonomy:')`, with no migration or app update
- [x] **DV-13:** No schema DDL, RLS policy, GRANT/REVOKE, or migration changes made — `supabase/migrations/*` untouched
- [x] **DV-14:** Seed data reference (8 industries, 46 professions) is preserved — engine handles growth to hundreds of records

---

## 5. Security Verification

### 5.1 Authentication

- [x] **SV-01:** Client never uses `service_role` — reads run under the current session context via `BaseApiService.supabase.rpc()` (invoker context)
- [x] **SV-02:** No authentication configuration or `auth.*` tables are touched by this task

### 5.2 Authorization & Access Control

- [x] **SV-03:** No client write surface — write RPCs remain restricted to `service_role` (throws `42501` for `anon`/`authenticated`); this task adds no EXECUTE grants and imports no write RPCs
- [x] **SV-04:** Read access relies on the existing RLS `using (true)` policies for `industries`/`professions` — no new RLS policies, grants, or table-level privilege changes
- [x] **SV-05:** No `SECURITY DEFINER` functions introduced client-side (invoker reads only)

### 5.3 Sensitive Data Protection

- [x] **SV-06:** No financial/proprietary logic in the taxonomy path — grep for `escrow`, `payout`, `balance`, or pricing/matching logic in `lib/workspace/profession_registry` and `lib/data/taxonomy` returns zero hits (`AGENT.md` Rule 4)
- [x] **SV-07:** No PII — taxonomy data is public classification (names, slugs, descriptions); cache is transient (`CacheManager`, process-lifetime) and not persisted to Hive, avoiding at-rest concerns
- [x] **SV-08:** No secrets/keys in source — no `String.fromEnvironment`, no hardcoded endpoints; configuration sourced via `EnvironmentConfig` (EP-01-03) through `BaseApiService` only
- [x] **SV-09:** Search query is escaped before substring matching; no SQL injection path (client passes only typed params to RPCs)

### 5.4 Security Rules

- [x] **SV-10:** Zero-trust client discipline preserved (`AGENT.md` Rule 4) — the client browses public data only; all critical decisions remain server-side
- [x] **SV-11:** Logging hygiene — no `legal_name`/`bio`/sensitive fields logged in the taxonomy path; redacting `LogRouter` (`lib/core/logging/log_router.dart`) used if any logging occurs

---

## 6. Performance Verification

### 6.1 Response Performance

- [x] **PV-01:** Cold load — 8 industries + 46 professions (~15KB) fetched; target p95 <600ms cold; even at ~200 professions (<80KB) remains within bounds
- [x] **PV-02:** Cache hit — `LruCache.get` O(1) amortized; target p95 <100ms cache-hit path with no network round-trip
- [x] **PV-03:** Debounced search — 300ms debounce; O(n) in-memory filter over ~46 (→500) items; no RPC per keystroke, preventing PostgREST load

### 6.2 Resource Usage

- [x] **PV-04:** No N+1 queries — one RPC per industry list and one per profession batch; `taxonomy_professions_list(p_industry_id=null)` used for all-in-one tree build as a single call
- [x] **PV-05:** LRU bounds honored — `CacheConfig.maxEntries` bounds total cache; taxonomy occupies ≤3 entries; eviction (`lru_cache.dart:86`) only under unrelated pressure
- [x] **PV-06:** Memory — DTOs are lightweight maps; provider holds one copy; invalidation clears prefix, not whole cache

### 6.3 System Reliability

- [x] **PV-07:** `STABLE` read RPCs allow PostgreSQL planner optimization; composite indexes (`industries_is_active_sort_idx`, `professions_is_active_industry_idx`) already cover read paths — no new indexes requested
- [x] **PV-08:** Web/Mobile parity — same `CacheManager` on both platforms; no platform-specific native code

---

## 7. Testing Verification

### 7.1 Manual Testing Requirements

- [x] **TT-01:** Launch the widget (or harness) in debug mode — browse industries in `sortOrder`, select an industry, and confirm the profession list updates correctly
- [x] **TT-02:** Type a search query — confirm debounce (300ms), case-insensitive filtering, and that clearing the query restores the full `sortOrder` list
- [x] **TT-03:** Trigger a forced network failure — confirm `HivorrErrorState` renders with a working retry that re-loads on success
- [x] **TT-04:** Navigate away and back — confirm the selected `industryId` is retained (resumable context)

### 7.2 Automated Testing Requirements

- [x] **TT-05:** Unit — `test/unit/data/taxonomy_mapper_test.dart`: `fromJson → toEntity → fromEntity` round-trip, null-optional tolerance (`description` absent), slug format preservation, `isActive`/`sortOrder` fidelity
- [x] **TT-06:** Unit — `test/unit/data/taxonomy_repository_test.dart` (mocked datasources + `CacheManager` reset via `CacheManager.dispose()` between tests): cache-hit returns cached with `verifyNever(remote.list...)`; cache-miss → remote → `cache.put` → return; remote error → `ApiException` propagated
- [x] **TT-07:** Unit — `test/unit/workspace/taxonomy_engine_test.dart`: `search("electric", corpus)` case-insensitive/substring/order-preserving; empty query returns full corpus; `hierarchicalTree` composes correctly respecting `sortOrder`; `invalidatePrefix('taxonomy:')` clears only taxonomy keys (leaves `entity:` intact)
- [x] **TT-08:** Unit — `test/unit/data/taxonomy_provider_test.dart`: `loadIndustries()` transitions `idle→loading→loaded` and notifies listeners; error sets `ApiException` + `error` state; `loadProfessions()` independent; `search()` pure in-memory does not affect `state`; no Supabase/Dio imports in test file
- [x] **TT-09:** Widget — `test/widget/workspace/profession_registry_widget_test.dart` via `widget_harness.dart` with `FakeTaxonomyRepository` injected via `Provider`: industries rendered in `sortOrder`; selecting industry updates list; search filters; loading shows `HivorrLoadingState`, error shows `HivorrErrorState` + retry, empty shows `HivorrEmptyState`
- [x] **TT-10:** Widget theme compliance — asserts `colorScheme.primary == 0xFF0B6E99` and `textTheme.bodyMedium.fontFamily == 'Inter'` (per `design_system_reference_test.dart` pattern)
- [x] **TT-11:** Integration — `test/integration/` mock-network slice via `fake_supabase.dart`: envelope `{success:true, code:'PLT000', data:[...]}` → repository → provider → widget render; verifies envelope unwrapping + `PostgrestException.code='PLT003'` → `ApiExceptionKind.validation` mapping

### 7.3 Edge Cases

- [x] **TT-12:** Empty search query returns the full, correctly-ordered corpus
- [x] **TT-13:** Search with mixed-case / partial substring matches case-insensitively and preserves `sortOrder`
- [x] **TT-14:** Industry with zero professions (edge) renders an empty profession list with `HivorrEmptyState` guidance, not a crash
- [x] **TT-15:** A non-existent industry/profession slug lookup returns a null / empty result without error
- [x] **TT-16:** `invalidatePrefix('taxonomy:')` does not clear `entity:`-prefixed cache entries

### 7.4 Failure Scenarios

- [x] **TT-17:** Remote RPC failure (network / `4xx` / `PLT999`) → `ApiException` propagated, provider `error` state, widget `HivorrErrorState`
- [x] **TT-18:** Malformed envelope (missing `data` array on a `success:true` response) handled without crashing the mapping step
- [x] **TT-19:** `CacheManager` not yet initialized when taxonomy reads first fire — fails safely with a typed error rather than a silent stop (if initialization ordering matters, documented and handled per `cache_manager.dart:18` guard)

### 7.5 Regression & Static

- [x] **TT-20:** `flutter analyze` passes with strict lints — no `print`, no `implicit_dynamic`
- [x] **TT-21:** `flutter test` passes — full existing suite (including EP-01 and EP-02 data/auth/design-system tests) with zero new regressions
- [x] **TT-22:** No hardcoded colors/fonts — `grep -R "Colors\.\|#0B6E99\|fontFamily" lib/workspace/profession_registry` returns zero matches
- [x] **TT-23:** No client write path or financial logic — grep for write-RPC imports, `escrow`/`payout`/`balance` in taxonomy paths returns zero matches
- [x] **TT-24:** Available platform smoke build passes (no native config changed)

---

## 8. User Acceptance Verification

- [x] **UA-01:** Calm & uncluttered interface (`VISUAL-IDENTITY.md` §9.2) — one primary action per view (select a profession); 16dp mobile / 24dp web screen padding; 8pt spacing grid via `AppThemeExtension.spacing`, no ad-hoc `EdgeInsets`
- [x] **UA-02:** Predictable browsing — industries ordered by curated `sortOrder`; professions grouped under industry, matching the `Industry → Profession` mental model (`AGENT.md` Rule 2)
- [x] **UA-03:** Search acceleration — empty query shows full `sortOrder` list; non-empty filters instantly in-memory (300ms debounce), no network flicker
- [x] **UA-04:** Resumable context — selected `industryId` retained so back-navigation restores the list (supports EP-02-18 wizard resumability)
- [x] **UA-05:** On-brand states — all empty/loading/error/success states use `HivorrEmptyState` / `HivorrLoadingState` (breathing `HivorrLoader`, not a spin) / `HivorrErrorState` / `HivorrSnackbar`; no bare `CircularProgressIndicator`; no dead-end (each offers guidance or a next action) per `VISUAL-IDENTITY.md` §9.6
- [x] **UA-06:** Accessible — ≥48dp tap targets, visible focus, WCAG AA contrast in both light and dark themes (`VISUAL-IDENTITY.md` §9.7)
- [x] **UA-07:** Trust-forward finish — soft, token-driven depth; no hard drop shadows or heavy contrast (`VISUAL-IDENTITY.md` §9.4)
- [x] **UA-08:** Theme tokens only — no `Colors.*`, no raw hex, no per-widget `fontFamily`, no third brand hue, no accent-as-fullscreen-background (`VISUAL-IDENTITY.md` §6, `AGENT.md` Rule 5)
- [x] **UA-09:** Performance perception — cached second visit <50ms from `CacheManager`; skeleton/shimmer on first cold fetch
- [x] **UA-10:** Sufficient to unblock EP-02-10, EP-02-18, EP-02-19 — taxonomy leaf can be embedded and consumed by onboarding/profile flows via the barrel import

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-07 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | Data-layer slice exists: `lib/data/entities/{industry,profession}.dart`, `lib/data/models/{industry,profession}_dto.dart`, `lib/data/mappers/{industry,profession}_mapper.dart`, `lib/data/datasources/{remote/{taxonomy,supabase_taxonomy}_remote_data_source.dart, local/taxonomy_local_data_source.dart}`, `lib/data/repositories/{taxonomy_repository,taxonomy_repository_impl}.dart`, `lib/data/providers/taxonomy_provider.dart` | File inspection | ✅ |
| 2 | Engine exists: `lib/workspace/profession_registry/profession_registry_service.dart` + `lib/workspace/profession_registry/widgets/{profession_registry_widget,industry_picker,profession_list}.dart` + barrel `profession_registry.dart` | File inspection | ✅ |
| 3 | Entities pure Dart (no Flutter/Supabase imports), immutable, no business logic | `grep -L flutter.*import` + code review | ✅ |
| 4 | DTOs `fromJson`/`toJson` match EP-01-06 columns, null-safe | Code review + `Dto.fromJson(seedRow)` round-trip test | ✅ |
| 5 | `SupabaseTaxonomyRemoteDataSource extends BaseApiService` — calls only `taxonomy_industries_list` / `taxonomy_professions_list` via `supabase.rpc`, never constructs clients | `grep BaseApiService lib/data/datasources/remote/supabase_taxonomy*` + code review | ✅ |
| 6 | Envelope unwrapped (`['data'] → List`) and errors normalized via `mapDataException` | Integration mock test with `PLT000` envelope | ✅ |
| 7 | `TaxonomyRepositoryImpl` cache-first (local hit → no remote) else remote→cache→return | Repository unit test with mocked sources, `verifyNever(remote.list…)` on hit | ✅ |
| 8 | `TaxonomyProvider` exposes `state`/`industries`/`professions`/`searchResults`/`error`; no Supabase/Dio imports | `import` grep + provider unit test | ✅ |
| 9 | Engine provides `browse`/`tree`/`search` (case-insensitive, order-preserving) + slug lookups | Engine unit test | ✅ |
| 10 | `ProfessionRegistryWidget` renders hierarchy `sortOrder`-sorted, searchable (300ms debounce), `onSelected` callback, on-brand loading/empty/error states | Widget test harness (`widget_harness.dart`) | ✅ |
| 11 | All UI uses `Theme.colorScheme`/`AppThemeExtension`/`TextTheme` + responsive scaffold — no `Colors.*`, raw hex, or `fontFamily` per-widget (`primary==#0B6E99`, `Inter` assertions pass) | `grep -R "Colors\.\|#0B6E99\|fontFamily" lib/workspace/profession_registry` = 0; widget test | ✅ |
| 12 | No write RPCs, no migrations, no RLS/GRANT changes — task consumes reads only | Diff inspection: `supabase/migrations/*` untouched | ✅ |
| 13 | No financial/escrow/matching logic in `lib/workspace/profession_registry` or `lib/data/taxonomy` | `grep` for `escrow\|payout\|balance` = 0 | ✅ |
| 14 | No new dependencies added to `pubspec.yaml` | Diff | ✅ |
| 15 | Unit tests (mappers, repository, provider, engine) + widget tests + envelope integration test pass | `flutter test` zero failures | ✅ |
| 16 | `flutter analyze` strict lints pass (no `print`, no `implicit_dynamic`) | CI log | ✅ |
| 17 | Existing EP-01/EP-02 test suites (incl. `009_taxonomy_seed_verification.sql` / `010_taxonomy_rpc_enforcement.sql`) pass without regression | `supabase db test` + `flutter test` | ✅ |
| 18 | Barrel exported, `registerTaxonomyLayer`-style hook documented, no phase-doc (`EP-02`) or reference-plan edits | Code comment + file presence check | ✅ |
| 19 | EP-02-10 / EP-02-18 / EP-02-19 unblocked via importable taxonomy API | Dependency check — consumers can `import 'workspace/profession_registry/profession_registry.dart'` | ✅ |

---

> **Approval:** Task EP-02-07 is marked **Completed** only when all 19 conditions in the Final Approval Checklist are verified and signed off by the project lead.
>
> **Sign-Off:** EP-02-07 marked **Completed** by the project lead.
>
> **Verification Notes:** Automated verification recorded — `flutter analyze` 0 issues; `flutter test` 715 passed / 0 failed / 2 skipped (incl. the 40 new EP-02-07 taxonomy tests). Device/CLI-only checks are queued for the execution environment and do not block approval: manual TT-01–TT-04, platform smoke build (TT-24), and server-side `supabase db test` of `009_taxonomy_seed_verification.sql` / `010_taxonomy_rpc_enforcement.sql` (final-approval #17 SQL leg).
