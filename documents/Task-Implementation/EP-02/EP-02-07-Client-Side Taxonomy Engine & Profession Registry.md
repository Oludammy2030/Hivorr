# Task Implementation Plan — EP-02-07: Client-Side Taxonomy Engine & Profession Registry

| Field | Value |
|---|---|
| **Task ID** | EP-02-07 |
| **Task Name** | Client-Side Taxonomy Engine & Profession Registry |
| **Phase** | EP-02 Trust, Identity & Financial Integrity Engine |
| **Status** | Not Started — Planning Only |
| **Priority** | High |
| **Dependencies** | EP-02-02 `taxonomy_management_rpcs.sql` (7 RPCs, SECURITY INVOKER, envelope `PLT000`) — verified exists at `supabase/migrations/20260829090002_taxonomy_management_rpcs.sql:1`; EP-01-06 taxonomy tables `supabase/migrations/20260821090001_entity_taxonomy_tables.sql:16`; EP-01-07 `lib/core/api/services/base_api_service.dart:15` + `lib/core/api/exceptions/api_exception.dart:6`; EP-01-08 data layer pattern `lib/data/data_layer.dart:29`; EP-01-11 `lib/core/cache/cache_manager.dart:10` |
| **Blocks** | EP-02-10, EP-02-18, EP-02-19, EP-02-11 (indirect) |
| **Planning Reasoning** | High (per EP-02 Phase Plan §11) |
| **Source of Truth** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:313` — do not modify |

---
## 1. Task Objective

Build the client-side taxonomy engine in `lib/workspace/profession_registry/` that consumes the server-side two-tier registry (`industries` → `professions`) via EP-02-02 RPCs, and exposes industry browsing, profession listing by industry, hierarchical `Industry → Profession` navigation, client-side search/filter, and TTL-aware caching.

Deliver the full vertical data slice for taxonomy (entities, DTOs, mappers, remote + local datasources, repository, provider) mirroring the EP-01-08 reference slice `lib/data/entities/entity.dart:31` / `lib/data/repositories/entity_repository_impl.dart:17`, plus a reusable presentation widget for onboarding/profile consumers. No schema, RLS, or RPC changes.

## 2. Business Problem Being Solved

Tables and seed data exist (8 industries, 46 professions via `20260829090001_taxonomy_seed_data.sql`) and RPCs exist, but:

- No client abstraction exists — consumers would call `supabase.rpc()` ad-hoc, duplicating envelope parsing, ordering, caching, and error mapping, and bypassing the EP-01-07 interceptor chain.
- Onboarding `EP-02-18` (industry/profession selection wizard), professional profile `EP-02-19` (badges/SEO URL `/p/:profession_slug/:entity_id` per `ARCHITECTURE.md:150`), and trade verification `EP-02-11` have no stable taxonomy service to bind against.
- Future industries must be addable as data inserts (ARCHITECTURE.md §10, EP-02 §8.4) without app update or schema migration — hardcoded slugs would break this.
- Current direct PostgREST reads lack consistent `{success, code, message, data}` envelope, pagination affordance, and debounced search; no offline/cache-first path exists.

This engine is the universal classification backbone for every trust workflow.

## 3. Scope

| In Scope | Detail |
|---|---|
| Taxonomy domain entities | `Industry` + `Profession` pure-Dart entities (`lib/data/entities/` pattern — no Flutter/Supabase imports) |
| DTOs + mappers | `IndustryDto`, `ProfessionDto` mirroring `industries`/`professions` columns; `IndustryMapper`, `ProfessionMapper` null-safe, tests covering `fromJson ↔ toEntity` |
| Remote datasource | `TaxonomyRemoteDataSource` abstract + `SupabaseTaxonomyRemoteDataSource implements TaxonomyRemoteDataSource extends BaseApiService` — calls `taxonomy_industries_list(p_include_inactive)` and `taxonomy_professions_list(p_industry_id, p_include_inactive)` via `supabase.rpc`, parses envelope `data` array, normalizes `PostgrestException` → `ApiException` via `lib/data/datasources/remote/data_exception_mapper.dart:12` |
| Local datasource / cache seam | `TaxonomyLocalDataSource` abstract + `InMemoryTaxonomyLocalDataSource` default (map-backed, `CacheManager`-aware). EP-01-11 `CacheManager.instance` is used for transient TTL caching with prefix `taxonomy:` — satisfies `lib/core/cache/cache_config.dart:10` transient mandate |
| Repository | `TaxonomyRepository` abstract + `TaxonomyRepositoryImpl(remote, local, cacheManager)` : cache-first reads, remote fallback, `LruCache` promotion on `get` (`lib/core/cache/lru_cache.dart:38`), `invalidatePrefix('taxonomy:')` on demand |
| Provider | `TaxonomyProvider extends ChangeNotifier` (`lib/data/providers/entity_provider.dart:27` pattern) — `loadIndustries()`, `loadProfessions(industryId)`, `search(query)`, `state` (`idle/loading/loaded/error`), `error: ApiException?`, no Supabase/Dio imports |
| Taxonomy engine | `lib/workspace/profession_registry/profession_registry_service.dart` (or `taxonomy_engine.dart`) — orchestrates repository + `CacheManager`, provides: `browseIndustries()`, `professionsByIndustry(id)`, `hierarchicalTree`, `searchProfessions(query)` (in-memory filter, case-insensitive, debounced at widget layer), `getIndustryBySlug`, `getProfessionBySlug` |
| Presentation widget(s) | `ProfessionRegistryWidget` + `IndustryPicker` + `ProfessionList` in `lib/workspace/profession_registry/` — hierarchical navigation, search field (`shared/widgets/hivorr_text_field.dart`), token-driven UI (`app/theme/app_colors.dart`, `app_text_theme.dart`), responsive via `shared/layouts/hivorr_responsive_scaffold.dart`, states using `HivorrEmptyState`, `HivorrLoadingState`, `HivorrErrorState` |
| Barrel + registration | Export via `lib/workspace/profession_registry/profession_registry.dart`; optional `registerTaxonomyLayer()` hook analogue to `lib/data/data_layer.dart:29` for `app/app_bootstrap.dart:1` |
| Tests | Unit: mappers, repository (mocked datasources), provider state, engine search; Widget: picker navigation + theme compliance; Integration: RPC → cache → provider → widget (mocked Supabase) |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| Supabase migrations, RLS, grants, table DDL | EP-01-06 final; EP-02-02 owns RPCs |
| Write RPCs (`taxonomy_industry_create/update`, `taxonomy_profession_create/update/move`) client exposure | Service-role only (`20260829090002_taxonomy_management_rpcs.sql:164`) — no client write path |
| Taxonomy admin CRUD UI | Future admin tooling (post EP-02) |
| Onboarding wizard steps, trade proof submission, identity verification screens | EP-02-18 / EP-02-10 / EP-02-11 |
| Financial, escrow, KYC, payout, dispute, storage, payment gateway logic | EP-02-03+ |
| New Flutter packages | EP-01-02 pinned deps only (`pubspec.yaml:30`) |
| Hardcoded industry/profession catalogs or slug constants | Violates extensibility; data must come from RPCs |
| `main.dart` / native platform permission edits | EP-01-15 / ARCHITECTURE.md §142 |

## 5. Recommended Technical Approach

### 5.1 Architecture Alignment

- Respects `ARCHITECTURE.md:87` — all code under `lib/workspace/profession_registry/` (engine-adjacent lookup) and `lib/data/` (data layer). No top-level dirs created.
- Data flows through `BaseApiService` only (`lib/core/api/services/base_api_service.dart:33` `invoke()`); never constructs `Dio()` or `SupabaseClient` directly — preserves EP-01-07 auth injection / 401-refresh / logging.
- Pure entities, DTO ↔ entity mappers, abstract repositories — identical to EP-01-08 §5.2 structure, enabling EP-02+ clone-template.
- `engine/profession_engine/` reserved for capability calculators; this task does not place taxonomy logic there (avoids conflation).

### 5.2 Data Layer Vertical Slice

```
lib/data/
├── entities/
│   ├── industry.dart              # id, slug, name, description, isActive, sortOrder, createdAt
│   └── profession.dart            # id, industryId, slug, name, description, isActive, sortOrder, createdAt
├── models/
│   ├── industry_dto.dart          # fromJson matching column names; toJson minimal
│   └── profession_dto.dart
├── mappers/
│   ├── industry_mapper.dart       # IndustryDto ↔ Industry
│   └── profession_mapper.dart
├── datasources/
│   ├── remote/
│   │   ├── taxonomy_remote_data_source.dart          # abstract
│   │   └── supabase_taxonomy_remote_data_source.dart # impl via BaseApiService
│   └── local/
│       └── taxonomy_local_data_source.dart           # abstract + InMemory + CacheManager-backed
├── repositories/
│   ├── taxonomy_repository.dart         # abstract
│   └── taxonomy_repository_impl.dart    # remote+local+cacheManager composition
├── providers/
│   └── taxonomy_provider.dart           # ChangeNotifier
└── data_layer.dart                      # re-export taxonomy providers (or workspace barrel)
lib/workspace/profession_registry/
├── profession_registry.dart             # barrel
├── profession_registry_service.dart     # taxonomy engine (search, hierarchy, lookup)
└── widgets/
    ├── profession_registry_widget.dart  # browsable Industry→Profession selector
    ├── industry_picker.dart
    └── profession_list.dart
```

- Entities: immutable, `const` constructor, no business logic (mirrors `lib/data/entities/entity_profile.dart:5`).
- DTOs: `factory fromJson` tolerates missing `description`/`created_by`; field names equal server columns to avoid drift (EP-01-08 §5.3 contract).
- Mappers: pure static `toEntity`, `fromEntity` when needed, null-safe optional handling.
- Remote: `_guard()` pattern like `lib/data/datasources/remote/supabase_entity_remote_data_source.dart:24` → `mapDataException`; RPC envelope unwrapping: `response['data'] as List` → `Dto.fromJson`; error envelope (`success:false`) → throw `ApiException(kind: server/validation, code: PLT003...)`.

### 5.3 Remote Datasource Contract

```dart
abstract class TaxonomyRemoteDataSource {
  Future<List<IndustryDto>> listIndustries({bool includeInactive = false});
  Future<List<ProfessionDto>> listProfessions({String? industryId, bool includeInactive = false});
}
```

Impl calls `supabase.rpc('taxonomy_industries_list', params: {'p_include_inactive': includeInactive})` and `taxonomy_professions_list` — both `STABLE`, `SECURITY INVOKER`, granted to `anon, authenticated, service_role` per migration `476:467`. No `platform_is_authenticated()` gate needed client-side; RLS `using (true)` already permits public read.

### 5.4 Taxonomy Engine Core

`ProfessionRegistryService` (or `TaxonomyEngine`) depends on `TaxonomyRepository`:

- `Future<List<Industry>> getIndustries()` — repository cache-first; fallback remote.
- `Future<List<Profession>> getProfessions(industryId)` — same.
- `Future<TaxonomyTree> getTree()` — parallel fetch, builds `Map<Industry, List<Profession>>` sorted by `sortOrder` (indexes `industries_is_active_sort_idx` `supabase/migrations/20260821090001_entity_taxonomy_tables.sql:44` and `professions_is_active_industry_idx:90` already optimize RPC SELECTs).
- `List<Profession> search(String query, List<Profession> corpus)` — client-side case-insensitive substring on `name/slug/description`; no RPC search param today (filtered to keep server simple per EP-02-02 §52 bulk/fuzzy deferred to EP-02-07). Future server search can be added without breaking clients.

No pricing, matching, verification, or financial math (AGENT.md Rule 4).

### 5.5 Caching Strategy

- Use `CacheManager.instance` (`lib/core/cache/cache_manager.dart:18`) — singleton LRU+TLL (`lib/core/cache/lru_cache.dart:12`). Keys: `taxonomy:industries`, `taxonomy:professions:$industryId`, `taxonomy:tree`. TTL sourced from `CacheConfig.defaultTtl` (`lib/core/cache/cache_config.dart:31`) — defaults safe if env var absent.
- Reads: `cache.get<T>()` hit → return; miss → remote → `cache.put(key, value)`. Promotes MRU on access (`lib/core/cache/lru_cache.dart:48`).
- Invalidation: `invalidatePrefix('taxonomy:')` after any admin taxonomy mutation (service-role path — client can expose method for future admin call, but EP-02-07 does not trigger writes).
- Transient-only, process-lifetime, no Hive persistence — avoids PII-at-rest (taxonomy data is public classification, no PII, but still transient per plan §5.4).
- LRU `maxEntries` honors `CacheConfig.maxEntries` (AppConstants-driven via `EnvironmentValueSource`).

### 5.6 Presentation Layer

- `ProfessionRegistryWidget`: Stateful, consumes `TaxonomyProvider` via `Provider`. States: `loading → HivorrLoader` (`lib/app/widgets/hivorr_loader.dart`) or `HivorrLoadingState`, `empty → HivorrEmptyState` (friendly microcopy per `VISUAL-IDENTITY.md:240`), `error → HivorrErrorState` with retry, `loaded → hierarchical list`.
- `IndustryPicker`: chips/cards using `shared/widgets/hivorr_chip.dart` / `hivorr_card.dart` with `Theme.of(context).colorScheme` + `AppThemeExtension.spacing/radius` — never `Colors.*` or raw hex (`VISUAL-IDENTITY.md:44`, AGENT.md Rule 5).
- `ProfessionList`: `ListView` with `sortOrder` ordering; tapping a profession calls `onSelected(Profession)` callback (owner integration in EP-02-18, not navigation here). Search field debounced 300ms (`hivorr_text_field.dart`) filtering in-memory corpus to avoid RPC spam.
- Responsive: wraps via `shared/layouts/hivorr_responsive_scaffold.dart` or `Breakpoints`; mobile 16dp padding, web 24dp (`VISUAL-IDENTITY.md:223`), grid vs list at breakpoint.
- Accessibility: ≥48dp tap targets (`VISUAL-IDENTITY.md:238`), visible focus, WCAG AA contrast asserted in widget tests.
- No GoRouter route registration in this task (EP-02-18 owns onboarding routes); widget is embeddable.

### 5.7 Dependency Wiring

- `registerTaxonomyLayer(ApiLayer)` analogue creates `SupabaseTaxonomyRemoteDataSource(dio, supabase, exceptionMapper)`, `InMemoryTaxonomyLocalDataSource()`, `TaxonomyRepositoryImpl`, `TaxonomyProvider`, and optionally `ProfessionRegistryService`. Consumed by `app/app_bootstrap.dart` provider tree (EP-01-15 pattern) — do not edit `main.dart` here, only expose constructor.
- Reuse `lib/shared/validators/hivorr_validators.dart`, `lib/shared/helpers/hivorr_formatters.dart`, `lib/shared/extensions/*` — check before creating helpers (AGENT.md Code Standards).

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Industry / Profession entities | `lib/data/entities/industry.dart`, `profession.dart` | Create |
| Industry / Profession DTOs | `lib/data/models/industry_dto.dart`, `profession_dto.dart` | Create |
| Industry / Profession mappers | `lib/data/mappers/industry_mapper.dart`, `profession_mapper.dart` | Create |
| Taxonomy remote datasource | `lib/data/datasources/remote/taxonomy_remote_data_source.dart`, `supabase_taxonomy_remote_data_source.dart` | Create |
| Taxonomy local datasource | `lib/data/datasources/local/taxonomy_local_data_source.dart` | Create |
| Taxonomy repository | `lib/data/repositories/taxonomy_repository.dart`, `taxonomy_repository_impl.dart` | Create |
| Taxonomy provider | `lib/data/providers/taxonomy_provider.dart` | Create |
| Taxonomy engine / registry service | `lib/workspace/profession_registry/profession_registry_service.dart` | Create |
| Registry widgets | `lib/workspace/profession_registry/widgets/*` | Create |
| Barrel | `lib/workspace/profession_registry/profession_registry.dart` | Create |
| Existing: `BaseApiService`, `ApiException`, `CacheManager`, `LruCache`, `data_exception_mapper`, `AppTheme` | `lib/core/*`, `lib/app/theme/*` | Reuse — no edits |
| Existing: `industries`, `professions` tables + `taxonomy_*_list` RPCs | `supabase/migrations/*` | Consume only |

No new packages; `dio`, `supabase_flutter`, `provider` already pinned (`pubspec.yaml:44`).

## 7. Data Requirements

### 7.1 Read Shapes (from RPC envelope `data`)

`Industry` (tier-1): `id: uuid`, `slug: string` (kebab-case `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤140, lower, `industries_slug_format`), `name: string` (1–255), `description: string?`, `isActive: bool`, `sortOrder: int`, `createdAt: DateTime?`

`Profession` (tier-2): `id: uuid`, `industryId: uuid` (FK → `industries.id ON DELETE RESTRICT`), `slug: string` (globally unique, same format), `name`, `description?`, `isActive`, `sortOrder`, `createdAt`

Seed reference: 8 industries, 46 professions (`supabase/migrations/20260829090001_taxonomy_seed_data.sql` + test `supabase/tests/database/009_taxonomy_seed_verification.sql:14`) — engine must handle growth to hundreds.

### 7.2 Access Patterns

| Operation | Source | Key Filter | Ordering |
|---|---|---|---|
| List industries | `taxonomy_industries_list` | `is_active` default true; `p_include_inactive` false for UX pickers | `sort_order ASC` |
| List professions | `taxonomy_professions_list` | `industry_id` optional; `is_active` default true | `sort_order ASC` |
| Search | In-memory over cached corpus | `name/slug/description contains query` | Retain `sortOrder`; optional relevance rank later |
| Resolve by slug | In-memory over cached arrays | `slug == target` | — |

No client writes. No pagination initially (46 rows negligible); design repository to accept `limit/offset` params later without breaking callers.

## 8. Database Considerations

- No DDL, no RLS, no GRANT/REVOKE — existing posture is final: `industries`/`professions` `using (true)` SELECT for `anon/authenticated`, INSERT/UPDATE/DELETE denied to `authenticated` (`supabase/tests/database/009_taxonomy_seed_verification.sql:99`), service-role-only writes via RPC grants (`20260829090002_taxonomy_management_rpcs.sql:464`).
- Indexes already cover read paths: `industries_is_active_sort_idx` (`20260821090001_entity_taxonomy_tables.sql:44`), `professions_is_active_industry_idx` (`20260821090001_entity_taxonomy_tables.sql:90`). Engine inherits this; no new indexes requested.
- Volatility: `STABLE` read RPCs allow planner optimization; results cacheable on server side. Client cache supplements (not replaces) this.
- Envelope invariant: all RPCs return `jsonb_build_object('success', true, 'code', 'PLT000', 'message', ..., 'data', coalesce(v_rows, '[]'))` (`20260829090002_taxonomy_management_rpcs.sql:51`). Client unwraps `data` and maps; `success:false` never expected on STABLE reads — treat as `ApiExceptionKind.server`.
- Idempotency / extensibility: new `industries`/`professions` are inserts with `ON CONFLICT (slug) DO NOTHING` (seed pattern) — engine discovers them on next fetch with no code change.

## 9. API Requirements

| RPC | HTTP (PostgREST) | Roles | Params | Returns (jsonb) |
|---|---|---|---|---|
| `taxonomy_industries_list` | `POST /rest/v1/rpc/taxonomy_industries_list` | `anon, authenticated, service_role` | `p_include_inactive bool default false` | `{success:true, code:'PLT000', message:'Industries retrieved.', data: Industry[]}` |
| `taxonomy_professions_list` | `POST /rest/v1/rpc/taxonomy_professions_list` | same | `p_industry_id uuid default null`, `p_include_inactive bool default false` | `{success:true, code:'PLT000', message:'Professions retrieved.', data: Profession[]}` |

- Error codes: `PLT003` validation not applicable to reads; server errors surface as `PLT999`/`4xx` — mapped via `lib/data/datasources/remote/data_exception_mapper.dart:17` to `ApiExceptionKind.server/forbidden`.
- No new RPCs, no Edge Functions, no REST endpoints created in this task. Envelope contract is reused verbatim.

## 10. User Interface Requirements

Per `VISUAL-IDENTITY.md` binding (AGENT.md Rule 5) and `ARCHITECTURE.md lib/shared/`:

- All colors via `Theme.of(context).colorScheme` + `AppThemeExtension`; `TextTheme` for type (`app/theme/app_text_theme.dart`) — never `Colors.*`, raw hex, or `fontFamily` per-widget. Assertion in widget tests: `ColorScheme.primary == #0B6E99` (`documents/Context/VISUAL-IDENTITY.md:49`).
- Spacing/radius/elevation/motion via `AppThemeExtension.spacing` 8pt grid, 16dp card radius / 24dp sheet (`VISUAL-IDENTITY.md:218`) — any non-token usage fails DoD per §9.8.
- Responsive `shared/layouts/hivorr_responsive_scaffold.dart` — mobile/web scaffolds, breakpoint-driven layout (`shared/layouts/breakpoints.dart`).
- States: branded `HivorrEmptyState` (warm guidance + CTA), `HivorrLoadingState` (uses `HivorrLoader` breathing pulse, not spin), `HivorrErrorState` (retry action), `HivorrSnackbar` for transient errors (`shared/widgets/hivorr_snackbar.dart`) — never bare `CircularProgressIndicator`.
- Widget API: `ProfessionRegistryWidget({required ValueChanged<Profession> onSelected, initialIndustryId, showSearch = true})` — embeddable, callback-driven, no router push inside.

| Widget | Responsibility |
|---|---|
| `ProfessionRegistryWidget` | Composes picker + list + search; drives `TaxonomyProvider`; handles loading/error/empty |
| `IndustryPicker` | Horizontal chips or vertical cards of industries, `sortOrder` sorted, selection emits `industryId` |
| `ProfessionList` | `ListView` of professions for selected industry, `sortOrder` sorted, searchable, `onTap → onSelected` |
| `TaxonomySearchField` | `HivorrTextField` with debounce, clear affordance, `onSurfaceVariant` hint |

## 11. User Experience Considerations

- **Calm & uncluttered** (`VISUAL-IDENTITY.md:212`): one primary action per view (select a profession); whitespace, 16/24dp screen padding.
- **Predictable browsing**: Industries ordered by curated `sortOrder`; professions grouped under industry — matches mental model `Industry → Profession` (AGENT.md Rule 2).
- **Search as accelerator**: Empty query shows full `sortOrder` list; non-empty filters in-memory instantly (300ms debounce) — no network flicker.
- **Resumable context**: Selected `industryId` retained in provider state so back-navigation restores list (supports EP-02-18 wizard resumability).
- **Guidance on empty**: No results → `HivorrEmptyState` with "Try a different keyword" + clear filter; inactive-only filtering never surfaces to end-users (default `isActive:true`).
- **Feedback on error**: Network failure → `HivorrErrorState` with retry; envelope failure → `HivorrSnackbar` with safe message (`ApiException.message` via `_safeMessage`), never raw SQL.
- **Performance perception**: Cached second visit (<50ms from `CacheManager`), skeleton shimmer on first cold fetch.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| No financial/proprietary logic | Taxonomy is public classification only; no pricing/matching/escrow logic in client (AGENT.md Rules 3,4). Verification that `grep -r supabase_calc\|escrow\|payout lib/workspace/profession_registry` yields zero hits. |
| No client write surface | Write RPCs remain `service_role` only (`42501` for anon/authenticated — `supabase/tests/database/010_taxonomy_rpc_enforcement.sql` pattern). This task never adds EXECUTE grants or imports write RPCs. |
| Zero trust client | All critical decisions server-side; client only browses public slugs/names/descriptions. No `SECURITY DEFINER` functions introduced. |
| RLS bypass avoidance | Datasources use `BaseApiService.supabase.rpc()` with invoker context; never use `service_role` key client-side. Env keys sourced via `EnvironmentConfig` (EP-01-03) only. |
| Secret hygiene | No `String.fromEnvironment`, no keys in taxonomy code; `supabase_flutter` key already managed by `ApiInitializer` (`lib/core/api/api_initializer.dart`). |
| PII | Taxonomy contains no PII. Cache is transient (`CacheManager`) — not persisted to Hive, avoiding at-rest concerns. |
| Input handling | Search query escaped before `contains`; DTO `fromJson` validates `slug` format defensively (regex) before mapping, even though server already enforces `industries_slug_format`. |
| Logging | No `legal_name`/`bio` logging in taxonomy path; if logging occurs, use redacting `LogRouter` (`lib/core/logging/log_router.dart`). |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Payload size | 8 + 46 rows today → ~15KB JSON. Even at 200 professions, <80KB. No pagination required now; repository signature reserved for `limit/offset` to support 500+ later without widget changes. |
| Cache hit path | `LruCache.get` is O(1) amortized (`lib/core/cache/lru_cache.dart:38`); hit avoids network round-trip. Target p95 browse <100ms cache-hit, <600ms cold. |
| Debounced search | 300ms debounce on text field; filter is O(n) in-memory (~46 items → negligible) — no RPC per keystroke, prevents PostgREST load. |
| No N+1 | One RPC per industry list, one per profession batch. `taxonomy_professions_list(p_industry_id=null)` for all-in-one tree build is single call. |
| Volatility & planner | `STABLE` read RPCs allow PG query plan reuse; composite indexes already optimal. No additional indexes. |
| LRU pressure | `CacheConfig.maxEntries` bounds total cache; taxonomy occupies ≤3 entries — eviction via `LruCache._evictIfNeeded` (`lib/core/cache/lru_cache.dart:86`) only under unrelated pressure. |
| Memory | DTOs are lightweight maps; provider holds one copy. Invalidation clears prefix, not whole cache. |
| Web/Mobile parity | Same cache manager both platforms; no platform-specific native code. |

## 14. Testing Strategy

### 14.1 Unit — Mappers (`test/unit/data/taxonomy_mapper_test.dart`)

Round-trip `Dto.fromJson → toEntity → fromEntity` ; null optional tolerance (`bio/description` absent); slug format preservation; `isActive/sortOrder` fidelity. Mirrors `test/unit/data/entity_mapper_test.dart:11`.

### 14.2 Unit — Repository (`test/unit/data/taxonomy_repository_test.dart`, `test/unit/workspace/taxonomy_engine_test.dart`)

Mocked `TaxonomyRemoteDataSource` + `TaxonomyLocalDataSource` + `CacheManager` (reset via `CacheManager.dispose()` between tests). Cases:

- `getIndustries()` cache-hit returns cached, no remote call; cache-miss → remote → cache.put → return; remote error → `ApiException` propagated.
- `getProfessions(industryId)` same per-key caching.
- `search("electric", corpus)` case-insensitive, substring, order-preserving, empty query returns full corpus.
- `hierarchicalTree` composes correctly, respects `sortOrder`.
- `invalidatePrefix('taxonomy:')` clears only taxonomy keys (leave `entity:` intact — `lib/core/cache/cache_manager.dart:88`).

### 14.3 Unit — Provider (`test/unit/data/taxonomy_provider_test.dart`)

Mirrors `test/unit/data/entity_provider_test.dart` pattern: `loadIndustries()` transitions `idle→loading→loaded`, notifies listeners; error sets `ApiException` and `error` state; `loadProfessions()` independent; `search()` pure in-memory does not affect `state`; no Supabase/Dio imports in test file.

### 14.4 Widget (`test/widget/workspace/profession_registry_widget_test.dart`)

Harness `test/support/harnesses/widget_harness.dart`:

- Renders `ProfessionRegistryWidget` against `FakeTaxonomyRepository` injected via `Provider`.
- Assertions: industries rendered in `sortOrder`; selecting industry updates profession list; search filters correctly; loading shows `HivorrLoadingState`, error shows `HivorrErrorState` + retry invokes provider again; empty corpus shows `HivorrEmptyState`.
- Theme compliance: `colorScheme.primary == 0xFF0B6E99`, `textTheme.bodyMedium.fontFamily == 'Inter'` (`test/widget/shared/design_system_reference_test.dart` pattern).
- Tap target ≥48dp, focus visible, WCAG contrast.

### 14.5 Integration (`test/integration/`) — Optional mock-network slice

Mock `SupabaseClient` via `test/support/fakes/fake_supabase.dart` returning envelope `{success:true, code:'PLT000', data:[...]}` → repository → provider → widget render. Verifies envelope unwrapping + `PostgrestException.code='PLT003'` → `ApiExceptionKind.validation` mapping.

### 14.6 Static & Regression

`flutter analyze` (strict lints, no `print`, no `implicit_dynamic`), `flutter test` (full suite, no regression on `008_full_schema_posture_audit.sql`-adjacent client posture), platform smoke build (no native edits).

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `20260821090001_entity_taxonomy_tables.sql`, `20260829090002_taxonomy_management_rpcs.sql`, `009_taxonomy_seed_verification.sql`, `lib/data/data_layer.dart`, `lib/core/cache/*`, `lib/data/*` patterns | Context confirmed; diff scope = `lib/workspace/profession_registry/` + `lib/data/taxonomy/*` |
| 2 | Implement `lib/data/entities/industry.dart`, `profession.dart` pure-Dart entities | Entities |
| 3 | Implement `lib/data/models/industry_dto.dart`, `profession_dto.dart` with `fromJson` matching server columns | DTOs |
| 4 | Implement `lib/data/mappers/industry_mapper.dart`, `profession_mapper.dart` | Mappers |
| 5 | Implement `lib/data/datasources/remote/taxonomy_remote_data_source.dart` abstract + `supabase_taxonomy_remote_data_source.dart` via `BaseApiService.rpc` + envelope unwrap | Remote datasource |
| 6 | Implement `lib/data/datasources/local/taxonomy_local_data_source.dart` abstract + `InMemoryTaxonomyLocalDataSource` + `CacheManager` integration | Local seam |
| 7 | Implement `lib/data/repositories/taxonomy_repository.dart` + `taxonomy_repository_impl.dart` (cache-first composition) | Repository |
| 8 | Implement `lib/data/providers/taxonomy_provider.dart` (`ChangeNotifier`) | Provider |
| 9 | Implement `lib/workspace/profession_registry/profession_registry_service.dart` (search, hierarchy, slug lookups) | Engine |
| 10 | Implement `lib/workspace/profession_registry/widgets/*` (registry, picker, list) with `AppTheme` tokens + responsive + state widgets | UI |
| 11 | Implement `lib/workspace/profession_registry/profession_registry.dart` barrel | Export |
| 12 | Add unit tests: mappers, repository, provider, engine | Tests |
| 13 | Add widget tests + integration envelope test | Tests |
| 14 | Run `flutter analyze`, `flutter test`, verify no hardcoded colors/fonts via grep | Gate |
| 15 | Diff review — only approved paths touched; no migration/phase-doc/native edits; stop at approval gate | Ready for EP-02-10/18 |

## 16. Expected Outcome

- A cached, provider-driven taxonomy engine serving browsable `Industry → Profession` hierarchy, searchable/filterable, backed by `STABLE` `taxonomy_*_list` RPCs with zero client write paths.
- Full data slice (`entities/dtos/mappers/datasources/repository/provider/engine`) mirroring EP-01-08, typed `ApiException`-only errors, transient LRU+TTL cache under `taxonomy:` prefix.
- Embeddable `ProfessionRegistryWidget` (theme-compliant, responsive, accessible, state-aware) ready for `EP-02-18` onboarding wizard and `EP-02-19` profile display without further taxonomy work.
- Data-driven extensibility: new industries/professions as DB inserts become visible to clients after cache TTL / invalidation, without migration or app update.
- 100% test coverage of mapper/repository/provider/engine; widget assertions covering theme, state, and interaction.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/data/entities/industry.dart`, `profession.dart` exist, pure Dart (no Flutter/Supabase imports), no business logic | `grep -L flutter.*import` + file inspection |
| 2 | `lib/data/models/industry_dto.dart`, `profession_dto.dart` `fromJson`/`toJson` match EP-01-06 columns, null-safe | Code review + `Dto.fromJson(seedRow)` round-trip test |
| 3 | `lib/data/mappers/industry_mapper.dart`, `profession_mapper.dart` map correctly, tolerate null `description` | Unit `mapper_test` pass |
| 4 | `TaxonomyRemoteDataSource` abstract + `SupabaseTaxonomyRemoteDataSource extends BaseApiService` call only `taxonomy_industries_list` / `taxonomy_professions_list` via `supabase.rpc`, never constructs clients | `grep BaseApiService lib/data/datasources/remote/supabase_taxonomy*` + code review |
| 5 | Envelope unwrapped (`['data'] → List`) and `ApiException` mapping via `mapDataException` (`data_exception_mapper.dart:12`) | Integration mock test with `PLT000` envelope |
| 6 | `TaxonomyLocalDataSource` abstract + `InMemoryTaxonomyLocalDataSource` + `CacheManager` prefix `taxonomy:` with `get/put/invalidatePrefix` | `cache_manager_test` pattern + provider flow |
| 7 | `TaxonomyRepository` abstract + `TaxonomyRepositoryImpl` cache-first (local hit → no remote) else remote→cache→return | Repository unit test with mocked sources, `verifyNever(remote.list…)` on hit |
| 8 | `TaxonomyProvider extends ChangeNotifier` exposes `state`, `industries`, `professions`, `searchResults`, `error: ApiException?`; `loadIndustries` / `loadProfessions(industryId)` / `search` implemented; no Supabase/Dio imports | `import` grep + `entity_provider_test` pattern |
| 9 | `profession_registry_service.dart` provides `browse`, `tree`, `search` (case-insensitive, order-preserving) + slug lookups | Engine unit test |
| 10 | `ProfessionRegistryWidget` (+ picker/list) renders hierarchy `sortOrder`-sorted, searchable (300ms debounce), `onSelected` callback, empty/loading/error states via `HivorrEmptyState/LoadingState/ErrorState` | Widget test harness (`widget_harness.dart`) |
| 11 | All UI uses `Theme.colorScheme`/`AppThemeExtension`/`TextTheme` + responsive scaffold (`breakpoints.dart`) — no `Colors.*`, no raw hex, no `fontFamily` per-widget; passes `design_system_reference_test.dart` assertions (`primary==#0B6E99`, `Inter`) | `grep -R "Colors\.\|#0B6E99\|fontFamily" lib/workspace/profession_registry` = 0; widget test |
| 12 | No write RPCs, no migrations, no RLS/GRANT changes — task consumes reads only | Diff inspection: `supabase/migrations/*` untouched |
| 13 | No financial/escrow/matching logic in `lib/workspace/profession_registry` or `lib/data/taxonomy` | `grep` for `escrow\|payout\|balance` = 0 |
| 14 | No new dependencies added to `pubspec.yaml` | Diff |
| 15 | Unit tests (mappers, repository, provider, engine) + widget tests + envelope integration test pass | `flutter test` zero failures |
| 16 | `flutter analyze` strict lints pass (no `print`, no `implicit_dynamic`) | CI log |
| 17 | Existing `009_taxonomy_seed_verification.sql` + `010_taxonomy_rpc_enforcement.sql` (if present) still pass; full suite non-regressive | `supabase db test` or `flutter test` counterpart |
| 18 | Docs: barrel exported, `registerTaxonomyLayer`-style hook documented, no phase-doc (`EP-02`) edits | Code comment + file presence check |
| 19 | EP-02-10 / EP-02-18 / EP-02-19 unblocked via importable taxonomy API | Dependency check — consumers can `import 'workspace/profession_registry/profession_registry.dart'` |

## 18. Implementation AI Execution Profile

| Attribute | Recommendation |
|---|---|
| **Recommended Coding Reasoning Level** | **High** |
| **Reasoning Level Justification** | **Technical complexity**: Moderate — requires correct layering across DTO/mapper/remote/local/repository/provider/engine/widget with cache composition and envelope handling; mistakes would propagate to every EP-02 trust workflow, but no novel algorithms (in-memory filter, LRU+TTL already provided by `CacheManager`/`LruCache`). **Business impact**: High — taxonomy is the universal classification backbone for onboarding, verification, and discovery; incorrect ordering/filtering or hardcoded catalogs would block EP-02-18/19/11, yet no direct financial loss risk. **Security risk**: Low — taxonomy data is public classification (`using (true)` reads, writes remain service-role `42501`); no financial logic, no PII, no secrets; enforcement is read-only envelope consumption. **Performance sensitivity**: Moderate — 46→500 row corpus, single RPC + debounced filter, transient cache; indexes already optimal, but cache-hit and responsiveness underlie first onboarding impression. **Data complexity**: Moderate — two-tier FK hierarchy with `is_active`/`sortOrder` and slug uniqueness/format constraints already server-enforced; client must mirror shapes faithfully without duplicating constraints. **Integration complexity**: High — must consume EP-02-02 `STABLE` RPCs via `BaseApiService` with `ApiException` normalization, compose `CacheManager` LRU+TTL, and expose `Provider` for widget tree, all while staying embeddable for future wizard/profile screens. Overall matches the EP-02 Phase Plan assignment of **High** for EP-02-07 (not Extremely High — no financial double-entry, no escrow state machine, no provider-agnostic gateway). |

---

> **Approval gate**: This plan is ready for review. Upon approval, implementation will produce the taxonomy engine under `lib/workspace/profession_registry/` + `lib/data/taxonomy/*` with the test suite described above. No production code is written in planning; no `supabase/migrations/` or `EP-02 Trust… Engine.md` file is modified. Awaiting explicit approval before proceeding to code.
