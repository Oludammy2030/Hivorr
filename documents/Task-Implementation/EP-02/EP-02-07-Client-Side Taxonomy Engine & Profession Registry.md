# Task Implementation Plan — EP-02-07: Client-Side Taxonomy Engine & Profession Registry

**Task ID:** EP-02-07 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Completed | **Priority:** High | **Dependencies:** EP-02-02 (Taxonomy Management RPCs) | **Stage:** 3 — Client-Side Infrastructure

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:313-323` | Architecture: `documents/Context/ARCHITECTURE.md:55-139` , `documents/Context/AGENT.md:4-18` | Dependencies: `EP-02:135`, `EP-02:106-112` | Seeded Data: `supabase/migrations/20260829090001_taxonomy_seed_data.sql:28-38` (8 industries, 46 professions) | RPC Contract: `supabase/migrations/20260829090002_taxonomy_management_rpcs.sql:35-92` | Visual Identity: `documents/Context/VISUAL-IDENTITY.md:1-248`

---

## 1. Task Objective

Build the client-side taxonomy engine in `lib/workspace/profession_registry/` — hierarchical `Industry → Profession` browsing, profession listing by industry, search/filter, caching, and the complete Unified Data Access Layer (`lib/data/`) for taxonomy data. Deliver entities, DTOs, mappers, remote/local datasources, repository, provider, engine service, and registry picker widgets. Data is sourced exclusively via server-side RPCs `taxonomy_industries_list` and `taxonomy_professions_list` with the standard `{success, code, message, data}` envelope `EP-02-02:76-89`. No DDL, no RPC creation, no financial logic.

## 2. Business Problem Being Solved

EP-02-01 seeded 8 industries + 46 professions and EP-02-02 exposed them via 2 public read RPCs (`anon, authenticated, service_role` `EP-02-02:165-166`) + 5 service-role write RPCs. No client abstraction exists:

* Onboarding (EP-02-18) cannot offer `Industry → Profession` selection — `AGENT.md:15` Rule 2 is un-implementable.
* Professional profile display (EP-02-19), verification flows (EP-02-10/11), and marketplace discovery have no browsable taxonomy — they would fallback to direct `supabase.from('industries')` reads, bypassing the envelope contract and EP-01-08 §5.6 abstraction.
* No caching: every screen would re-fetch 54 rows, wasting bandwidth on Nigerian networks and violating EP-01-11 transient cache mandate `lib/core/cache/cache_manager.dart:4-9`.
* No search/filter: `EP-02-02:52` explicitly deferred taxonomy search to client-side (EP-02-07).
* No hierarchical engine: future industries would require code changes instead of data inserts, violating `EP-02:204` universal taxonomy extensibility.

This task creates the cached, searchable, hierarchical client engine that all downstream trust UX depends on.

## 3. Scope

| In Scope | Detail |
|---|---|
| Domain entities | `Industry` + `Profession` in `lib/data/entities/` — pure Dart, no Flutter/Supabase imports, fields mirror `public.industries`/`public.professions` (`id, slug, name, description, isActive, sortOrder, createdAt`) `20260821090001_entity_taxonomy_tables.sql:16-77` |
| DTOs | `IndustryDto` + `ProfessionDto` in `lib/data/models/` — `fromJson` matching server column names, `toJson` for local cache, snake_case mapping |
| Mappers | `IndustryMapper`, `ProfessionMapper` in `lib/data/mappers/` — `Dto ↔ Entity` transformers, null-safe, no business logic `lib/data/mappers/entity_mapper.dart:9-23` pattern |
| Remote datasource | `TaxonomyRemoteDataSource` abstract + `SupabaseTaxonomyRemoteDataSource implements BaseApiService` `lib/core/api/services/base_api_service.dart:15-44` — calls `supabase.rpc('taxonomy_industries_list')` / `taxonomy_professions_list` via `BaseApiService.invoke` + `mapDataException` `lib/data/datasources/remote/data_exception_mapper.dart:12` |
| Envelope parsing | Unwrap `jsonb` envelope (`success, code, message, data`), validate `code == PLT000`, normalize `PLT003/004/005` via `ApiExceptionMapper`, return `List<Dto>`; `data` is `coalesce(jsonb_agg(...),'[]'::jsonb)` `20260829090002:46-55,76-87` |
| Local datasource | `TaxonomyLocalDataSource` — `CacheManager` transient cache `lib/core/cache/cache_manager.dart:10-96` with prefix `taxonomy:` + TTL (default from `CacheConfig.defaultTtl` `lib/core/cache/cache_config.dart:20`), optional Hive box `hive: ^2.2.3` for offline resilience (EP-01-11). Methods: `getIndustries, saveIndustries, getProfessions(industryId), saveProfessions` |
| Repository | `TaxonomyRepository` abstract + `TaxonomyRepositoryImpl` `lib/data/repositories/entity_repository_impl.dart:17-83` pattern — cache-first read (local hit → return, miss → remote fetch → save), cache invalidation via `CacheManager.invalidatePrefix('taxonomy:')` |
| Provider | `TaxonomyProvider extends ChangeNotifier` `lib/data/providers/entity_provider.dart:27-94` pattern — `TaxonomyProviderState {idle, loading, loaded, error}`, `List<Industry> industries`, `Map<String, List<Profession>> professionsByIndustry`, `Industry? selectedIndustry`, `Profession? selectedProfession`, `ApiException? error`, debounced search query |
| Taxonomy engine | `lib/workspace/profession_registry/taxonomy_engine.dart` (or `profession_registry_engine.dart`) — hierarchical lookup `getProfessionsForIndustry(id)`, `getIndustryForProfession(id)`, client-side search/filter (case-insensitive substring over `name/slug/description` across cached lists), sort by `sort_order ASC` `20260821090001:44-45,90-92`, `activeOnly` filtering, cache-aware refresh |
| Widgets | `lib/workspace/profession_registry/widgets/` — `IndustryPicker`, `ProfessionPicker`, `ProfessionRegistryBrowser` (hierarchical wizard: industry grid → profession list), `TaxonomySearchField` (debounce 200-300ms), using `shared/widgets/` primitives (`HivorrCard`, `HivorrChip` `lib/shared/widgets/hivorr_chip.dart:18-112`, `HivorrEmptyState/LoadingState/ErrorState`) + `AppTheme` tokens `lib/app/theme/app_colors.dart` / `app_text_theme.dart` |
| Caching policy | TTL 10 min (configurable via `EnvironmentConfig`/`CacheConfig`), LRU eviction `CacheConfig.maxEntries`, `CacheManager.put(key, value, ttl:)` `lib/core/cache/cache_manager.dart:69-71`, stale-while-revalidate on resume via `AppLifecycleObserver` `lib/app/lifecycle/app_lifecycle_observer.dart` |
| Integration wiring | Barrel export update `lib/data/data_layer.dart`, Provider registration in `lib/app/app_bootstrap.dart` `MultiProvider`, no `Dio`/`SupabaseClient` construction outside `BaseApiService` `EP-01-08 §5.4` |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| Taxonomy seed data or RPC creation/alteration | EP-02-01 / EP-02-02 finalized — `supabase/migrations/2026082909000*.sql` — no DDL in this task |
| Write RPCs (`taxonomy_industry_create/update`, `profession_create/update/move`) | `service_role` only `EP-02-02:462-474` — admin tooling, post EP-02 |
| Supabase Storage or `lib/core/storage/` | EP-02-06 / EP-02-08 (`supabase/migrations/20260830100001_storage_buckets.sql`) |
| Payment gateway abstraction `lib/integrations/payment_gateways/` | EP-02-09 |
| Verification / KYC / Financial / Dispute systems | EP-02-03 — EP-02-05, EP-02-10 — EP-02-17 |
| Onboarding flow & professional profile screens | EP-02-18 / EP-02-19 (consume this engine) |
| Industry-specific business logic | `AGENT.md:8` Separation of Concerns + `ARCHITECTURE.md:91-104` domain separation — universal infrastructure only |
| Direct table SELECT (`supabase.from('industries')`) | Must use RPC channel only; direct access bypasses envelope and is forbid-den by code review |
| New `public.*` tables, RLS policies, GRANTs | No DB changes |
| Hardcoded slugs / names / industry lists | Extensibility violation — new industries are `INSERT` data, not code `EP-02:204` |

## 5. Recommended Technical Approach

### 5.1 Layered Architecture — EP-01-08 Unified Data Access Layer Compliance

Follow the established 4-layer slice `lib/data/` — `Datasources → Repositories → Providers` — mirrored from `EntityRepositoryImpl`/`EntityProvider`:

```
Remote RPC (Supabase) ──┐
                         ├─► Repository (cache-first, envelope unwrap, DTO→Entity)
Local Cache (CacheManager/Hive) ──┘
                                 │
                            Provider (ChangeNotifier, UI state)
                                 │
                         Engine (hierarchical + search)
                                 │
                         Widgets (AppTheme, shared/)
```

All business systems and UI consume `TaxonomyRepository`/`TaxonomyProvider` abstractions — never `SupabaseClient` or `Dio` directly `lib/core/api/services/base_api_service.dart:8-14`.

### 5.2 Remote Datasource — RPC Envelope Contract

```dart
abstract class TaxonomyRemoteDataSource {
  Future<List<IndustryDto>> getIndustries({bool includeInactive = false});
  Future<List<ProfessionDto>> getProfessions({String? industryId, bool includeInactive = false});
}
class SupabaseTaxonomyRemoteDataSource extends BaseApiService implements TaxonomyRemoteDataSource {
  // supabase.rpc('taxonomy_industries_list', params: {'p_include_inactive': false})
  // response is jsonb envelope → extract data array → map to DTOs
  // errors normalized via mapDataException → ApiException(kind: validation/notFound/conflict/forbidden/server)
}
```

* Volatility: RPCs are `STABLE` `20260829090002:41,70` — cacheable.
* Grants: `anon`/`authenticated` can read; no auth guard needed in client. `PLT003/004/005` mapped to `ApiExceptionKind.validation/notFound/conflict` `lib/data/datasources/remote/data_exception_mapper.dart:19-39`.
* No `SELECT` on `industries`/`professions` tables — RLS `using (true)` exists but is not the access path; RPC is the contract.

### 5.3 Local Datasource — CacheManager + Hive Option

* Primary: `CacheManager.instance.get<List<IndustryDto>>('taxonomy:industries')` / `put('taxonomy:industries', list, ttl: Duration(minutes:10))` — transient, process-lifetime, LRU `lib/core/cache/cache_manager.dart:58-95`.
* Secondary (optional, align with EP-01-11): Hive box `taxonomy_box` with `industry_dto` / `profession_dto_<industryId>` keys for offline cold-start. On cache miss, fall back to Hive before network. Hive is synchronous but wrapped async for consistency with `EntityLocalDataSource`.
* Invalidation: `invalidatePrefix('taxonomy:')` on TTL expiry, manual pull-to-refresh, or `AppLifecycleObserver` resume after `defaultTtl`.

### 5.4 Repository — Cache-First Policy

Reuse `EntityRepositoryImpl:31-43` pattern:

```dart
Future<List<Industry>> getIndustries() async {
  final cached = await local.getIndustries(); // CacheManager + Hive
  if (cached != null && cached.isNotEmpty) return cached.map(IndustryMapper.toEntity).toList();
  final fetched = await remote.getIndustries(); // RPC
  await local.saveIndustries(fetched);
  return fetched.map(...).toList();
}
Future<List<Profession>> getProfessions(String industryId) async {
  final cached = await local.getProfessions(industryId);
  if (cached != null) return cached.map(...).toList();
  final fetched = await remote.getProfessions(industryId: industryId);
  await local.saveProfessions(industryId, fetched);
  return ...
}
```

Single network round-trip per type (8 + up to 46 rows — negligible). No pagination needed at current cardinality; design `getProfessions({String? industryId})` to support `null = all` for future `professions_list` without code change.

### 5.5 Provider — State Lifecycle

Mirror `EntityProvider:9-21,27-94`:

```dart
enum TaxonomyProviderState { idle, loading, loaded, error }
class TaxonomyProvider extends ChangeNotifier {
  TaxonomyProviderState _state; List<Industry> _industries; Map<String,List<Profession>> _byIndustry;
  Industry? _selectedIndustry; Profession? _selectedProfession;
  String _searchQuery = ''; // debounced setter triggers notifyListeners
  ApiException? _error;
  Future<void> loadIndustries() => _run(() async => _industries = await repo.getIndustries());
  Future<void> loadProfessions(String industryId) => _run(() async => _byIndustry[industryId] = await repo.getProfessions(industryId));
  Future<void> selectIndustry(String id) { _selectedIndustry = industries.firstWhere((i)=>i.id==id); _selectedProfession=null; notifyListeners(); }
  List<Profession> get filteredProfessions => search(_searchQuery, _byIndustry[_selectedIndustry?.id] ?? []);
}
```

Debounce search input 250ms via `Future.delayed` or `Timer` to avoid per-keystroke filtering.

### 5.6 Engine — Hierarchical + Search

`lib/workspace/profession_registry/taxonomy_engine.dart` is a thin pure-Dart service over `TaxonomyRepository` (or consumed by provider):

* `Future<List<Industry>> browseIndustries({bool activeOnly = true})` — returns sorted by `sort_order`, filters `isActive` when requested (mirrors RPC `p_include_inactive` but also client-side for cached data).
* `Future<List<Profession>> browseProfessions(String industryId, {bool activeOnly})` — hierarchical constraint.
* `List<Profession> search(String query, List<Profession> scope)` — case-insensitive `name.contains || slug.contains || description.contains`; empty query returns scope unfiltered; query sanitized (btrim, max 100 chars).
* `Industry? industryForProfession(String professionId)` — reverse lookup via cached map.
* No hardcoded slugs — engine is agnostic to `legal/technology/...` set `supabase/migrations/20260829090001:30-37`; extensibility is data-driven `EP-02:204`.

Location rationale: `ARCHITECTURE.md:89` mandates `lib/workspace/profession_registry/` for taxonomy lookup. `lib/engine/profession_engine/` `ARCHITECTURE.md:75` is reserved for capability calculators (trade-specific logic) — not used here. If a re-usable algorithm is needed, expose it via the workspace registry, not the deterministic engine.

### 5.7 Widgets — Design System Compliance

All widgets consume `AppTheme` tokens `VISUAL-IDENTITY.md:44-46,118-126`:

* Colors via `Theme.of(context).colorScheme.primary/secondary/surface/onSurface` and `context.appExtension` `lib/shared/widgets/hivorr_chip.dart:36-37` — never `Colors.*` or raw hex `AGENT.md:17` Rule 5.
* Typography via `context.textTheme` `VISUAL-IDENTITY.md:121-135` — never per-widget `fontFamily`.
* Spacing/radius/elevation/motion via `AppThemeExtension.spacing/radiusLg/radiusSm` `VISUAL-IDENTITY.md:217-239`.
* Composition: `IndustryPicker` = `ListView`/`GridView` of `HivorrChip`/`HivorrCard` `lib/shared/widgets/hivorr_card.dart`, `ProfessionPicker` = filterable list, `ProfessionRegistryBrowser` = 2-step wizard with progress indicator bridging to EP-02-18 pattern.
* States: `HivorrLoadingState` (uses `HivorrLoader` breathing pulse `VISUAL-IDENTITY.md:148-150`), `HivorrEmptyState`, `HivorrErrorState` `VISUAL-IDENTITY.md:238-245`, never bare `CircularProgressIndicator`.
* Responsive via `shared/layouts/` scaffolds `ARCHITECTURE.md:147-150` — 16dp mobile / 24dp web content pane, `LayoutBuilder` breakpoint.
* Semantics: `Semantics(label, selected)` `lib/shared/widgets/hivorr_chip.dart:105-110`, `InkWell` 48dp min touch target `VISUAL-IDENTITY.md:242-245`.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `Industry` entity | `lib/data/entities/industry.dart` | **Create** — pure Dart, `id, slug, name, description, isActive, sortOrder, createdAt` |
| `Profession` entity | `lib/data/entities/profession.dart` | **Create** — `id, industryId, slug, name, description, isActive, sortOrder, createdAt` |
| `IndustryDto` | `lib/data/models/industry_dto.dart` | **Create** — `fromJson(Map)` matching `industries` columns, `toJson` for cache |
| `ProfessionDto` | `lib/data/models/profession_dto.dart` | **Create** — `fromJson` matching `professions` columns incl. `industry_id` |
| `IndustryMapper` | `lib/data/mappers/industry_mapper.dart` | **Create** — `Dto→Entity`, `Entity→Dto` |
| `ProfessionMapper` | `lib/data/mappers/profession_mapper.dart` | **Create** — `Dto→Entity` |
| `TaxonomyRemoteDataSource` | `lib/data/datasources/remote/taxonomy_remote_data_source.dart` | **Create** — abstract `getIndustries/getProfessions` |
| `SupabaseTaxonomyRemoteDataSource` | `lib/data/datasources/remote/supabase_taxonomy_remote_data_source.dart` | **Create** — extends `BaseApiService`, RPC envelope parsing |
| `TaxonomyLocalDataSource` | `lib/data/datasources/local/taxonomy_local_data_source.dart` | **Create** — `CacheManager` + optional Hive, `get/save/invalidate` |
| `TaxonomyRepository` | `lib/data/repositories/taxonomy_repository.dart` | **Create** — abstract `getIndustries/getProfessions/search` |
| `TaxonomyRepositoryImpl` | `lib/data/repositories/taxonomy_repository_impl.dart` | **Create** — cache-first, remote fallback, `mapDataException` propagation |
| `TaxonomyProvider` | `lib/data/providers/taxonomy_provider.dart` | **Create** — `ChangeNotifier`, `TaxonomyProviderState`, selection + search |
| Taxonomy engine | `lib/workspace/profession_registry/taxonomy_engine.dart` | **Create** — hierarchical + search service (or `profession_registry_service.dart`) |
| `IndustryPicker` | `lib/workspace/profession_registry/widgets/industry_picker.dart` | **Create** — browsable industry grid/list |
| `ProfessionPicker` | `lib/workspace/profession_registry/widgets/profession_picker.dart` | **Create** — profession list by industry, filtered |
| `ProfessionRegistryBrowser` | `lib/workspace/profession_registry/widgets/profession_registry_browser.dart` | **Create** — 2-step hierarchical wizard + search field |
| `TaxonomySearchField` | `lib/workspace/profession_registry/widgets/taxonomy_search_field.dart` | **Create** — debounced text field, clear affordance |
| Barrel exports | `lib/data/data_layer.dart`, `lib/data/entities.dart` etc. | **Update** — export new entities/DTOs/mappers |
| Provider wiring | `lib/app/app_bootstrap.dart`, `lib/app/app.dart` | **Update** — `Provider<TaxonomyRepository>` + `ChangeNotifierProvider<TaxonomyProvider>` |
| Hive registration | `lib/core/database/hive_adapters.dart` (if Hive used) | **Update** — adapters for `IndustryDto`/`ProfessionDto` if persisting |
| No migration | `supabase/migrations/` | **No change** — reads via existing RPCs only |
| Tests | `test/unit/`, `test/widget/`, `test/integration/` | **Create** — see §13 |

No files under `lib/engine/`, `lib/systems/finance/`, `lib/integrations/` are created.

## 7. Data Requirements

### 7.1 Industry Entity

| Field | Type | Source Column | Notes |
|---|---|---|---|
| `id` | `String` (UUID) | `industries.id` | PK |
| `slug` | `String` | `industries.slug` | SEO-stable, globally unique, `^[a-z0-9]+(-[a-z0-9]+)*$` `20260821090001:27-29` |
| `name` | `String` | `industries.name` | Display, `1-255` chars `20260821090001:31-33` |
| `description` | `String?` | `industries.description` | Nullable |
| `isActive` | `bool` | `industries.is_active` | Soft gate, inactive filtered by default |
| `sortOrder` | `int` | `industries.sort_order` | Increments of 10 `supabase/migrations/20260829090001:30-37`, display order |
| `createdAt` | `DateTime?` | `industries.created_at` | Audit |

Seeded: 8 rows (`legal, technology, healthcare, construction, financial-services, creative, education, logistics`) `supabase/migrations/20260829090001:30-37`.

### 7.2 Profession Entity

| Field | Type | Source Column | Notes |
|---|---|---|---|
| `id` | `String` | `professions.id` | PK |
| `industryId` | `String` | `professions.industry_id` | FK → `industries.id` `ON DELETE RESTRICT` `20260821090001:60` |
| `slug` | `String` | `professions.slug` | Globally unique, same format constraint `20260821090001:69-72` |
| `name` | `String` | `professions.name` | — |
| `description` | `String?` | `professions.description` | — |
| `isActive` | `bool` | `professions.is_active` | — |
| `sortOrder` | `int` | `professions.sort_order` | Scoped to industry |
| `createdAt` | `DateTime?` | `professions.created_at` | — |

Seeded: 46 rows, 5-8 per industry `supabase/migrations/20260829090001:42-158`.

### 7.3 Search/Filter Vocabulary

* Search scope: cached `List<Industry>` + `List<Profession>` — no server query.
* Ranking: `sortOrder ASC` primary, then alphabetical `name`. No fuzzy matching; substring only — keeps complexity low at 54 rows, scales to hundreds without index.
* Filters: `activeOnly` (default `true`), `industryId` (required for profession browse).

## 8. Database Considerations

| Consideration | Approach |
|---|---|
| No DDL | This is a **read-only client** task. No `CREATE/ALTER TABLE`, no `INSERT/UPDATE/DELETE` on `industries`/`professions`. Writes remain `service_role` only via EP-02-02 RPCs. |
| Access path | **RPC only** — `taxonomy_industries_list(p_include_inactive)` + `taxonomy_professions_list(p_industry_id, p_include_inactive)` `20260829090002:35-92`. PostgREST `/rest/v1/rpc/taxonomy_*`. No `supabase.from('industries').select()` in production code (lint-guarded by review). |
| RLS posture unchanged | `industries_is_active_sort_idx` + `professions_is_active_industry_idx` `20260821090001:44-45,90-92` already optimize the read patterns used inside the RPCs. Client caching respects `is_active` filtering. |
| Envelope | RPC returns `jsonb {success, code, message, data}` — `success=true, code=PLT000` on success, `PLT003/004/005` on validation/not-found/conflict. Client must validate envelope before mapping `data` array. |
| Transaction safety | N/A — no writes. Reads are `STABLE` and idempotent. |
| Idempotency | Seeded data uses `ON CONFLICT (slug) DO NOTHING` — re-runs safe. Cache invalidation is local-only. |
| Extensibility | No schema change when adding industries — engine discovers via RPC; new industry is data insert + automatic browse. Validated by `EP-02:204` universal taxonomy principle. |

If applicable — none beyond read path; no migrations are produced.

## 9. API Requirements

| RPC | PostgREST | Client Params | Returns (after envelope) | Access |
|---|---|---|---|---|
| `taxonomy_industries_list` | `POST /rest/v1/rpc/taxonomy_industries_list` | `p_include_inactive: bool = false` | `List<IndustryDto>` ordered `sort_order ASC` | `anon, authenticated, service_role` |
| `taxonomy_professions_list` | `POST /rest/v1/rpc/taxonomy_professions_list` | `p_industry_id: uuid? = null, p_include_inactive: bool = false` | `List<ProfessionDto>` filtered by `industry_id` when provided, ordered `sort_order ASC` | `anon, authenticated, service_role` |

* No REST endpoints, Edge Functions, or direct table grants are created.
* All calls go through `BaseApiService.invoke` → `Dio` + `SupabaseClient` singletons from `lib/core/api/api_initializer.dart` `EP-01-07`.
* Error codes: `PLT003 validation (empty slug/name, invalid format)` → `ApiExceptionKind.validation`, `PLT004 not found` → `notFound`, `PLT005 conflict (duplicate slug)` → `conflict`, `42501 insufficient privilege` → `forbidden` `lib/data/datasources/remote/data_exception_mapper.dart:19-39`. Taxonomy reads never hit write codes, but mapper must still handle them for future admin reads with `p_include_inactive=true`.

## 10. User Interface Requirements

| Widget | Purpose | Tokens & Primitives |
|---|---|---|
| `ProfessionRegistryBrowser` | Hierarchical wizard: Step 1 industry grid/list → Step 2 profession list (filtered by selected industry) + search bar + selection confirm. Used by EP-02-18 onboarding Step 2/3 and EP-02-19 profile. | `AppTheme` `ColorScheme` + `AppThemeExtension` spacing/radius `VISUAL-IDENTITY.md:219-239`, `HivorrCard`, `HivorrChip` `lib/shared/widgets/hivorr_chip.dart:42-54`, `HivorrButton` primary Cerulean `#0B6E99` `VISUAL-IDENTITY.md:27-37` |
| `IndustryPicker` | Stateless browsable grid/list of industries, `sortOrder` ordered, active-only by default, `onSelected(Industry)` | `HivorrChip` variant `primary`, `surfaceContainerHighest` for unselected, outline `ColorScheme.outline` `VISUAL-IDENTITY.md:59-62` |
| `ProfessionPicker` | Profession list for a given `industryId`, respects search query, shows description subtitle | `HivorrCard` radius 16dp `VISUAL-IDENTITY.md:239`, `TextTheme.titleMedium` (500) for name, `bodySmall` (400) for description `VISUAL-IDENTITY.md:128-133` |
| `TaxonomySearchField` | `TextField` with debounce, clear button, hint “Search industries or professions”, empty state integration | `HivorrTextField` `lib/shared/widgets/hivorr_text_field.dart`, focus ring `primary`, error text `error` token |
| States | Loading → `HivorrLoadingState` with `HivorrLoader` breathing pulse `VISUAL-IDENTITY.md:148-150`; Empty → `HivorrEmptyState` with guidance “No professions in this industry”; Error → `HivorrErrorState` with retry; Success selection → `HivorrSnackbar` | Never bare spinner `VISUAL-IDENTITY.md:238-245` |
| Responsive | `shared/layouts/` scaffold: `Column` on mobile (full-width cards), `Row` (master-detail 320dp + flex) on web ≥768px `ARCHITECTURE.md:147-150` | 16dp mobile / 24dp web padding `VISUAL-IDENTITY.md:219` |

All EP-02 UI consumes `AppTheme` tokens — any hardcoded `Colors.*`/hex or per-widget `fontFamily` fails DoD per `AGENT.md:17` Rule 5 and `VISUAL-IDENTITY.md:177-190`.

## 11. User Experience Considerations

* **Hierarchical mental model matches AGENT.md Rule 2** — user first picks `Industry` (broad: Technology), then `Profession` (specific: Software Engineer). No parallel single-list; breadcrumb `Industry > Profession` persists selection.
* **Calm & uncluttered** `VISUAL-IDENTITY.md:212` — one primary action per view (`Continue` after profession select), generous whitespace 8pt grid, soft elevation for picker cards vs. border for static dividers `VISUAL-IDENTITY.md:217-240`.
* **Discoverability at 54 rows** — 8 industry chips fit above the fold; professions per industry ≤8 so scrolling is minimal. Search narrows instantly (client-side) without network flicker.
* **Debounce + fail-fast** — search debounced 250ms prevents jank; invalid empty selection shows inline validation via `HivorrValidators` `lib/shared/validators/hivorr_validators.dart`; network failure shows retry with cached stale data if available.
* **Resumability** — `TaxonomyProvider` holds `selectedIndustry/selectedProfession` across navigation; onboarding can exit and return `EP-02:441` without losing picker state (provider survives route stack).
* **Accessibility premium** `VISUAL-IDENTITY.md:242-245` — 48dp min tap targets `lib/shared/widgets/hivorr_chip.dart:61`, WCAG AA contrast via `ColorScheme.onSurface/onSurfaceVariant`, `Semantics` labels `selected` state, visible focus ring on web.
* **Trust-forward microcopy** `VISUAL-IDENTITY.md:214-215` — empty state “No matches — try a broader term”, not “0 results”.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Zero-trust client `AGENT.md:16` Rule 4 | No financial/escrow/KYC logic in this task — taxonomy is public classification only. DTO/Entity separation ensures no pricing/matching formula exists to reverse-engineer. |
| Public data classification | `industries`/`professions` are public (`SELECT using (true)` `EP-01-06`). No PII, no secrets, no auth bypass. `anon` read is intentional for SEO-friendly `/p/:profession_slug/:entity_id` `ARCHITECTURE.md:150`. |
| No `SECURITY DEFINER` | No new DB functions in this task. Existing 7 taxonomy RPCs are `SECURITY INVOKER` `20260829090002:40,70` — posture audit `008_full_schema_posture_audit.sql` remains 0 new `prosecdef`. |
| No direct table access | Code review gate: forbid `supabase.from('industries'|'professions')` in `lib/` — all taxonomy reads via `TaxonomyRemoteDataSource` RPC channel. Prevents envelope bypass and keeps `EP-01-08 §5.6` abstraction. |
| Input sanitization | Search query: `btrim`, max 100 chars, no SQL interpolation — filtering is in-memory `String.contains`, not SQL. `industryId` validated as UUID before RPC call. |
| Cache PII-at-rest | No PII in taxonomy rows; `CacheManager` is transient `lib/core/cache/cache_manager.dart:4-9` (process-only). If Hive persists, taxonomy box is non-sensitive and excluded from `flutter_secure_storage` `pubspec.yaml:56`. |
| ENV isolation `ENV-001/002/008` | Taxonomy data seeded per environment via migration; RPC grants identical across dev/staging/prod. No env-specific branching in client. |
| No hardcoded secrets | No API keys, no `service_role` key exposure — client uses `anon`/`authenticated` Supabase key only. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Dataset size | 54 rows today (8 + 46) `supabase/migrations/20260829090001:30-158` — entire taxonomy fits in one `jsonb_agg` payload (<20KB). Future growth to hundreds still fits without pagination; design `ListView.builder` + `SliverGrid` for O(n) render. |
| Network minimization | Cache-first repo: cold start = 1-2 RPCs (industries, then professions for selected industry). Warm start = 0 network (CacheManager hit). `CacheManager` LRU `maxEntries` `lib/core/cache/cache_config.dart:19` + TTL 10 min prevents churn. |
| RPC optimization | Reads use `industries_is_active_sort_idx` + `professions_is_active_industry_idx` `20260821090001:44-45,90-92` inside RPC — index-ordered `sort_order ASC`. No N+1: `taxonomy_professions_list` returns all professions for industry in one call `EP-02-02:102-108`. |
| Client search cost | In-memory `O(n)` filter over ≤46 items — negligible (<1ms). Debounce 250ms avoids per-keystroke recompute. No RegExp; simple `toLowerCase().contains`. |
| Widget jank | `Provider` `notifyListeners` batched via `_run` guard `lib/data/providers/entity_provider.dart:81-93` — single rebuild per load. `ListView.builder` with `const` card constructors where possible. |
| Offline | Cached taxonomy renders instantly when offline; `connectivity_plus: ^6.1.0` `pubspec.yaml:68` can gate refresh attempt. No blank screen on flaky Nigerian networks. |
| Future scale | If taxonomy grows to 1000+ professions, repository can add paginated `getProfessionsPaginated(limit, offset)` without breaking existing `getProfessions(industryId)` — engine remains backward compatible. |

## 14. Testing Strategy

### 14.1 Unit Tests `test/unit/`

| Suite | Assertions |
|---|---|
| `industry_dto_test.dart` | `fromJson` maps `id/slug/name/description/is_active/sort_order/created_at` exactly; `toJson` round-trip; handles null `description/created_at` |
| `profession_dto_test.dart` | Same + `industry_id → industryId` mapping, FK preserved |
| `industry_mapper_test.dart`, `profession_mapper_test.dart` | `Dto→Entity` snake→camel, `is_active→isActive`, `sort_order→sortOrder`; null-safe |
| `supabase_taxonomy_remote_data_source_test.dart` | Mock `SupabaseClient.rpc` — success envelope unwraps to DTO list; `PLT003→validation`, `PLT004→notFound`, `42501→forbidden` via `mapDataException`; empty `data: []` returns empty list; malformed envelope throws `ApiExceptionKind.server` |
| `taxonomy_repository_impl_test.dart` | Cache hit → no remote call; cache miss → remote fetch + `local.save`; remote error propagates as `ApiException`; `invalidatePrefix` clears |
| `taxonomy_provider_test.dart` | `loadIndustries` transitions `idle→loading→loaded`, `loadProfessions(industryId)` populates `byIndustry`; `search` filters case-insensitively; `selectIndustry` resets `selectedProfession`; error → `state=error` with `ApiException` |
| `taxonomy_engine_test.dart` | `browseIndustries` sorted `sortOrder`; `browseProfessions` hierarchical filter; `search('soft')` matches `Software Engineer`; empty query returns unfiltered; query >100 chars truncated |

Target: ≥85% line coverage for `lib/data/` taxonomy slice; financial-grade edge-case discipline applied to error-path coverage.

### 14.2 Widget Tests `test/widget/`

| Suite | Assertions |
|---|---|
| `industry_picker_test.dart` | Renders 8 industry chips in `sortOrder`; tap calls `onSelected`; selected chip fill = `colorScheme.primary`, unselected = transparent with `outline` border `lib/shared/widgets/hivorr_chip.dart:64-65` |
| `profession_picker_test.dart` | Given `industryId=technology`, renders 8 professions ordered `sortOrder`; filtering via search hides non-matches; empty list shows `HivorrEmptyState` |
| `profession_registry_browser_test.dart` | 2-step flow: select industry → profession list updates; search narrows; `Continue` disabled until profession selected; uses `Provider` mock |
| `taxonomy_search_field_test.dart` | Debounce not firing before 250ms; clear button resets query; integration with provider `searchQuery` |
| Theme compliance | No widget uses hardcoded `Colors.*`/hex or `fontFamily` — assertions on `Theme.of(context).colorScheme` and `TextTheme` `VISUAL-IDENTITY.md:177-190` |

Use `ProviderScope` with fake `TaxonomyRepository` (in-memory DTO lists from seed data) — no network.

### 14.3 Integration Test `test/integration/`

`taxonomy_engine_integration_test.dart` — verifies `RPC → Cache → Provider → UI` data flow against `supabase start` local stack (or `supabase_flutter` mock with real envelope):

1. `supabase.db reset` applies `20260829090001` + `20260829090002` — `SELECT count(*) FROM industries` = 8, `professions` = 46.
2. `TaxonomyRepository.getIndustries()` → returns 8, `code=PLT000`, first row `slug=legal` `sort_order=10`.
3. `getProfessions(industryId=technology)` → 8 rows, ordered.
4. Second call hits `CacheManager` (no second RPC — verified via mock call count).
5. `TaxonomyProvider.loadIndustries()` → `state=loaded`, `industries.length=8`.
6. `ProfessionRegistryBrowser` renders industries → tap `Technology` → professions appear → search “web” → `Web Developer` remains.
7. Cache expiry after TTL → next call re-fetches.

### 14.4 Regression

* Existing pgTAP suites `001–010` remain green — especially `006_taxonomy_integrity.sql`, `009_taxonomy_seed_verification.sql`, `010_taxonomy_rpc_enforcement.sql` (`anon` can read RPCs, `authenticated` cannot write `42501`).
* `008_full_schema_posture_audit.sql` still 0 new `SECURITY DEFINER` for `taxonomy_%`.
* `flutter analyze` / `dart analyze` zero issues; `flutter test` full suite green.

## 15. Recommended Implementation Sequence

| Step | Action | Output | Verified By |
|---|---|---|---|
| 1 | Read `AGENT.md`, `ARCHITECTURE.md`, `VISUAL-IDENTITY.md`, `EP-02:313-323`, `20260829090002` RPC contract, `lib/data/` patterns | Baseline — no assumptions | Code review |
| 2 | Create `Industry` + `Profession` entities `lib/data/entities/industry.dart`, `profession.dart` | Domain models | `dart analyze` |
| 3 | Create `IndustryDto` + `ProfessionDto` `lib/data/models/` with `fromJson` snake mapping | DTOs | Unit test |
| 4 | Create `IndustryMapper` + `ProfessionMapper` `lib/data/mappers/` | Mappers | Unit test |
| 5 | Create `TaxonomyRemoteDataSource` abstract `lib/data/datasources/remote/` | Contract | File inspection |
| 6 | Implement `SupabaseTaxonomyRemoteDataSource extends BaseApiService` — envelope unwrap, `mapDataException` | Remote datasource | Unit test (mock Supabase) |
| 7 | Create `TaxonomyLocalDataSource` — `CacheManager` prefix `taxonomy:` + TTL, optional Hive box | Local cache | Unit test |
| 8 | Create `TaxonomyRepository` abstract + `TaxonomyRepositoryImpl` cache-first | Repository | Unit test (mock datasources) |
| 9 | Create `TaxonomyProvider` `lib/data/providers/taxonomy_provider.dart` — state, selection, debounced search | Provider | Unit test |
| 10 | Create `TaxonomyEngine` `lib/workspace/profession_registry/taxonomy_engine.dart` — hierarchical + search | Engine | Unit test |
| 11 | Build `IndustryPicker` + `ProfessionPicker` widgets `lib/workspace/profession_registry/widgets/` — `AppTheme` tokens, `HivorrChip/Card` | Widgets | Widget test + theme assertion |
| 12 | Build `ProfessionRegistryBrowser` + `TaxonomySearchField` hierarchical wizard + debounce | Browser widget | Widget test |
| 13 | Update barrel `lib/data/data_layer.dart` + wire providers in `lib/app/app_bootstrap.dart` | Integration | `flutter analyze` |
| 14 | Write integration test `test/integration/taxonomy_engine_integration_test.dart` (RPC→cache→UI) | Integration test | `flutter test` |
| 15 | Run `flutter analyze`, `flutter test` full suite, `supabase db test` pgTAP regression 001–010 | Green suite | CI |
| 16 | Verify no hardcoded colors/fonts (`grep -r "Colors\.\|Color(0x" lib/workspace/profession_registry`) + no direct `from('industries')` | Guardrails | Static check |

## 16. Expected Outcome

* Client-side taxonomy engine browses `Industry → Profession` hierarchically, search/filters client-side, caches with TTL via `CacheManager` — 0 network on warm start, 1-2 RPCs on cold start.
* Complete data layer per EP-01-08: 2 entities, 2 DTOs, 2 mappers, 2 datasources (remote+local), 1 repository, 1 provider — all consuming `BaseApiService` + `ApiException` contracts.
* `ProfessionRegistryBrowser` widget usable by EP-02-18 (onboarding steps 2/3) and EP-02-19 (profile), responsive mobile/web, `AppTheme` compliant, accessible (48dp, semantics).
* Integration test proves `taxonomy_industries_list`/`taxonomy_professions_list` → cache → provider → UI flow with real seeded data (8 industries, 46 professions).
* Zero DDL, zero RPC mutation, zero financial logic, zero hardcoded taxonomy — new industries appear automatically via data insert.
* EP-02-18, EP-02-19, EP-02-10/11 unblocked `EP-02:134,138,440,451`.

## 17. Definition of Done (DoD)

| # | Criterion | Verification Method |
|---|---|---|
| 1 | `Industry` + `Profession` entities exist `lib/data/entities/industry.dart`, `profession.dart` — pure Dart, `isActive/sortOrder` camelCase, no Flutter/Supabase imports | File inspection + `dart analyze` |
| 2 | `IndustryDto` + `ProfessionDto` exist `lib/data/models/` with `fromJson` mapping `is_active→isActive`, `sort_order→sortOrder`, `industry_id→industryId`, `toJson` round-trip | Unit test |
| 3 | `IndustryMapper` + `ProfessionMapper` exist `lib/data/mappers/` — null-safe `Dto↔Entity` | Unit test |
| 4 | `TaxonomyRemoteDataSource` abstract + `SupabaseTaxonomyRemoteDataSource extends BaseApiService` exist — use `supabase.rpc` only, envelope unwrap, `mapDataException` | `grep -r "supabase.rpc('taxonomy_"` = 2 hits, no `from('industries'|'professions')` |
| 5 | `TaxonomyLocalDataSource` exists — `CacheManager` keys `taxonomy:industries`, `taxonomy:professions:<industryId>`, TTL `defaultTtl`, `invalidatePrefix('taxonomy:')` | Unit test |
| 6 | `TaxonomyRepository` abstract + `TaxonomyRepositoryImpl` cache-first exist — remote fallback + `local.save` | Unit test (mock call counts) |
| 7 | `TaxonomyProvider` `ChangeNotifier` exists — `TaxonomyProviderState {idle,loading,loaded,error}`, `industries`, `professionsByIndustry`, selection, debounced `searchQuery`, `ApiException? error` | Unit test |
| 8 | `TaxonomyEngine` `lib/workspace/profession_registry/taxonomy_engine.dart` exists — `browseIndustries`, `browseProfessions(industryId)`, `search(query, scope)`, `industryForProfession` | Unit test |
| 9 | `IndustryPicker`, `ProfessionPicker`, `ProfessionRegistryBrowser`, `TaxonomySearchField` exist `lib/workspace/profession_registry/widgets/` | File inspection |
| 10 | All widgets consume `AppTheme` tokens — `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme`, no `Colors.*`/hex/`fontFamily` | Widget test assertions + `grep -r "Colors\.\|fontFamily" lib/workspace/profession_registry` = 0 |
| 11 | Widgets use `shared` primitives (`HivorrCard/Chip/TextField/Empty/Loading/ErrorState`) and `shared/layouts` responsive scaffolds | Visual review |
| 12 | Hardcoded taxonomy absent — no slug literals `legal/technology/...` outside tests; engine discovers via RPC | `grep -r "\"legal\"\|\"technology\"" lib/workspace` = 0 |
| 13 | No DDL, no RLS/GRANT changes, no new DB functions — `git diff --stat` shows only `lib/data/*`, `lib/workspace/profession_registry/*`, `lib/app/app_bootstrap.dart`, `test/*` | `git diff` |
| 14 | No financial logic in client — taxonomy-only | Code review |
| 15 | Envelope contract honored — `success==true && code==PLT000` validated before mapping; `PLT003/004/005` normalized to `ApiExceptionKind` | Unit test (error envelope) |
| 16 | `taxonomy_industries_list` returns 8 seeded industries ordered `sortOrder` via repository | Integration test + unit mock |
| 17 | `taxonomy_professions_list` with `industryId` returns correct count (e.g., `technology` = 8) ordered; `null` returns 46 | Integration test |
| 18 | Cache hit avoids second RPC; `invalidatePrefix` forces refetch; TTL expiry re-fetches | Unit test (call count) |
| 19 | Client-side search is case-insensitive substring over `name/slug/description`, debounced 200-300ms, empty query returns unfiltered, respects `activeOnly` | Unit + widget test |
| 20 | Hierarchical constraint: profession list scoped to selected industry; reverse lookup `industryForProfession` correct | Unit test |
| 21 | Provider wired in `lib/app/app_bootstrap.dart` `MultiProvider` — `Provider<TaxonomyRepository>` + `ChangeNotifierProvider<TaxonomyProvider>` | File inspection |
| 22 | `flutter analyze` zero issues | `flutter analyze` |
| 23 | Unit tests pass — DTO/mapper/repository/provider/engine ≥85% line coverage on taxonomy slice | `flutter test --coverage` |
| 24 | Widget tests pass — picker/browser/search + theme compliance | `flutter test test/widget/` |
| 25 | Integration test passes — `RPC → cache → provider → UI` with real seed data | `flutter test test/integration/taxonomy_engine_integration_test.dart` |
| 26 | Existing pgTAP `001`–`010` green, no `SECURITY DEFINER` drift for `taxonomy_%` | `supabase db test` |
| 27 | Full `flutter test` suite green — no regression in `entity_*` slice | `flutter test` |
| 28 | Accessibility: 48dp min tap targets, `Semantics`, WCAG AA contrast in light/dark `VISUAL-IDENTITY.md:242-245` | Widget test + manual |
| 29 | Documentation: engine + provider dartdoc, `comment` on public APIs | Code review |
| 30 | EP-02-18/19 unblocked — browser widget importable by onboarding/profile flows | Dependency check |

## 18. Implementation AI Execution Profile

| Attribute | Recommendation |
|---|---|
| **Recommended Coding Reasoning Level** | **High** |
| **Reasoning Level Justification** | **Technical complexity High** — not `Extremely High`: no double-entry ledger, no atomic financial RPC, no `SECURITY DEFINER`/`RLS` design. Complexity is the layered data-access slice (6 new `lib/data/` files + provider + engine) with envelope parsing, cache-first TTL/LRU, and debounced search — all must align with EP-01-08 `BaseApiService`/`ApiException`/`EntityRepositoryImpl` patterns. **Business impact High** — taxonomy is the universal classification backbone `EP-02:55,106`; incorrect sort/search or cache staleness breaks onboarding (EP-02-18) and profile (EP-02-19) for every future industry. **Security risk Medium** — data is public, but direct-table access bypass must be prevented and search input sanitized. **Performance sensitivity Medium** — 54-row in-memory filter is trivial, but network minimization via caching is critical for Nigerian low-bandwidth; TTL/debounce tuning matters. **Data complexity Medium** — 2 entities/DTOs with FK `industry_id`, hierarchical constraint, `is_active` filtering, `sort_order` ordering. **Integration complexity High** — touches `workspace/profession_registry`, `data/` barrel, `app_bootstrap` provider wiring, `core/cache`, `core/api`, `shared/widgets + theme`, and downstream EP-02-10/11/18/19 consumers. Phase Plan assigns EP-02-07 **Planning High / Coding High** `EP-02:479,496,506` — concentration of `Extremely High` items is the financial schema (EP-02-03/04/05/09/14/16) not this read-only engine. **High** is calibrated: rigorous but not the catastrophic financial reasoning of escrow/payouts. |

---

> **Awaiting your approval to proceed to implementation.** No files will be created, no `supabase db push`, and no Dart code will be written until confirmed. Open questions before green-light:
> 1. Confirm Hive persistence for taxonomy cache vs. `CacheManager` transient only — at current 54 rows, transient may suffice, but offline cold-start would benefit from Hive.
> 2. Confirm desired TTL (default 10 min from `CacheConfig` vs. explicit taxonomy TTL e.g., 30 min for near-static data).
> 3. Confirm widget placement: `lib/workspace/profession_registry/widgets/` only, or also expose a thin `lib/engine/profession_engine/` re-export for deterministic callers.
