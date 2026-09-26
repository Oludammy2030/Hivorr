# Task Implementation Plan — EP-03-07 Search & Discovery Infrastructure (Full-Text + Filtering + Caching)

> **Status:** Planning Artifact Only — No Production Code | **Plan Mode:** Read-Only
> **Phase:** EP-03 Stage 2 — Deterministic & Search Engines (must precede discovery UI)
> **Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:312-320` + `documents/Context/AGENT.md:1-18` + `documents/Context/ARCHITECTURE.md:39-173`
> **Dependencies:** `EP-03-01` Completed + `EP-03-06` Completed (verified on `main` 2026-09-26)
> **Inspection Method:** `Read` + `Glob` + `Grep` (read-only) via explore subagent + direct `Read` on 12 files

---

## 1. Task Objective

Deliver the **ranking-aware, filterable, paginated, offline-resilient search infrastructure** that composes the existing deterministic core — without duplicating it. Specifically:

- **Compose** `service_ranking_search` (`supabase/migrations/20260927090001_platform_config_and_ranking.sql:212`) — the sole `SECURITY INVOKER STABLE` ranking primitive — for FTS + filtered discovery; **do not** create a parallel `service_search` RPC.
- **Extend** `p_filters jsonb` validation to cover the full `EP-03:316` filter surface (`profession_id`, `industry_id`, `price_range`, `rating_min`, `is_verified_only`, `currency_code`, `availability_date` future) via additive validation inside the existing RPC.
- **Implement** the client offline hydrator `lib/engine/search_engine/service_search_index.dart` that hydrates a **two-tier cache** (`LruCache` transient 5m + `Hive` persistent) for taxonomy + recent ranked browse results, enabling offline browse without client-side ordering.
- **Wire** the single search seam `lib/data/datasources/remote/service_search_remote_data_source.dart:30` + cache-first repository `lib/data/repositories/service_search_repository_impl.dart:19` + `MarketplaceSearchProvider` `lib/data/providers/marketplace_search_provider.dart:18` with `250ms` debounce and `weights_version` invalidation — preserving `AGENT.md:7` verbatim RPC order.

No new FTS DDL, no new `GIN`, no new `search_vector` — `20260921090001_service_marketplace_schema.sql:122,130` already live.

---

## 2. Business Problem Being Solved

Discovery is the frequency driver (`Business-Roadmap:219-226` per `EP-03:317`). Without ranking-aware FTS, paginated filtering, and offline browse, `EP-03-08` supply creation has no demand and `EP-03-09` consumer discovery cannot prove `AGENT.md:7` determinism. Risks if solved incorrectly:

- **Parallel ranking** (duplicate `service_search` RPC or client `sort`) violates `Deterministic Core Supremacy` (`AGENT.md:7`), creates audit failure and regulatory exposure (`EP-03:175`).
- **Injection / enumeration oracle** via raw `to_tsquery` or drafted `PRIVATE` listings leaking to `anon`.
- **Cache divergence** after `platform_config` weight bump — stale pages served without invalidation.
- **Unbounded fetch / N+1** — `p95 <400ms` (`EP-03:56`) violated, offline users see blank state on Nigeria unreliable connectivity (`EP-03:383`).

`EP-03-07` closes Stage 2 before any discovery UI consumes ranking.

---

## 3. Scope

**In Scope:**

- Additive migration `supabase/migrations/<ts>_search_filter_extension.sql` only if `availability_date` availability-join filter is approved for this sprint; otherwise **zero DDL** (preferred) and client-only hydrator. If created: `ALTER FUNCTION service_ranking_search` to accept `p_filters.availability_date timestamptz` via `EXISTS (SELECT 1 FROM availability_slots WHERE ...)` validation, plus partial index on `availability_slots(profession_id, weekday)` — idempotent.
- Client `lib/engine/search_engine/service_search_index.dart` — class `ServiceSearchIndex` with `Future<ServiceSearchPage> warmBrowse({professionId, filters})` and `Future<void> hydrateOffline({limit=20})` that calls `ServiceSearchRepository.search(browse)` and persists via `LocalStore`/`AppBoxes.cache` prefix, using `CacheManager` `5m TTL` for result window.
- Extension `ServiceSearchFilters` `lib/data/entities/service_listing.dart:156` to include `availabilityDate DateTime?` with `toJson()` `availability_date` ISO8601.
- Extension `ServiceSearchLocalDataSource` `lib/data/datasources/local/service_search_local_data_source.dart:14` — optional `HiveServiceSearchLocalDataSource` implementing same contract via `LocalStore` (`lib/core/database/local_store.dart:13`) over `AppBoxes.cache` (`lib/core/database/boxes/app_boxes.dart:15`), or retain `CacheManagerServiceSearchLocalDataSource` with Hive fallback already present (decision at impl: prefer reusing `CacheManagerServiceSearchLocalDataSource` and adding Hive second-tier per `TaxonomyLocalDataSource` pattern).
- Extension `MarketplaceSearchProvider` — expose `hasActiveFilters`, `refresh()` that checks `weightsVersion` bump, keep `setQuery` debounce `250ms` (`lib/data/providers/marketplace_search_provider.dart:25`), `search`/`loadMore` verbatim order.
- Minor `ServiceSearchRemoteDataSource` filter passthrough (no new method — reuse `rankingSearch` `filters` map).
- Tests: extend `034_service_ranking_rpc_enforcement.sql` coverage for `query='legal drafting'` ranked hits, `rating_min=4.5` exclusion, cursor `has_more/no overlap`, injection sanitized, `unknown profession PLT004`; unit `service_search_index_test`, `repository cache-first/browse vs network-first/query`, provider debounce `fake_async`.

**Dependencies Blocking Start:** `service_listings` + `search_vector` + `GIN` (`20260921090001:56,122`) present; `platform_config` + `service_ranking_search` + `service_listings_published_ranking_idx` (`20260927090001:163`) present; `LruCache`/`CacheManager` (`lib/core/cache/lru_cache.dart:12`, `lib/core/cache/cache_manager.dart:10`) present; `BaseApiService` seam present. All at `main` `HEAD`.

---

## 4. Out of Scope

- New `service_listings.search_vector` DDL, new `GIN`, new `search_vector` trigger — already `20260921090001:130-162` recomputing `title||description||profession name`.
- New parallel RPC `service_search` composing `to_tsquery+ts_rank` — duplicates `service_ranking_search` `p_query ts_rank` (`20260927090001:458`); if proposed elsewhere, rejected via reuse-first.
- `EP-03-08/09` screens (`marketplace_discovery_screen`, `marketplace_search_screen`, `service_detail_screen`), `HivorrChip` filters, `portfolio` carousel, SEO routes (`EP-03:103`) — Stage 3.
- `lib/ai/*` intelligence, `lib/engine/matching_engine` spatial routing (`EP-04`), new currency scope (`NGN/GHS/USD/GBP` unchanged per `financial_supported_currencies:55`), admin weight console (service_role `UPDATE platform_config` sufficient).
- `view_count` increment on read (deferred per `20260921090001:27`).
- Real-time subscription for search (pull-only; messaging Realtime `20260925090001` not involved).

---

## 5. Existing Asset and Dependency Analysis

Inspection: `Glob lib/engine/**/*` (7 `.gitkeep`), `Glob supabase/migrations/*` (35 files), `Glob supabase/tests/database/*` (34 files), `Grep search lib/` (97 hits), `Read pubspec.yaml:189` + 8 direct file reads.

| Asset | Path:Line | State | Relevance to Search & Discovery | Reuse Verdict |
|---|---|---|---|---|
| **FTS vector + GIN + trigger** | `supabase/migrations/20260921090001_service_marketplace_schema.sql:56`, `122`, `130` | Live, idempotent | `search_vector tsvector` trigger-generated `to_tsvector('english', title||' '||desc||' '||prof_name)` never client-supplied; `GIN(search_vector)` feeds `ts_rank` | **Reuse verbatim — no new DDL** |
| **Ranking RPC** | `supabase/migrations/20260927090001_platform_config_and_ranking.sql:212`, `498-565` comment | `SECURITY INVOKER STABLE` live, `anon/authenticated/service_role` grant, keyset `(score DESC, id DESC)` | 6-signal formula `w_verify*kyc + w_rating*bayesian + w_completion*rate + w_recency*decay + w_relevance*ts_rank + w_activity*login` + `plainto_tsquery` sanitized `v_query_trim 100 char cap` `20260927090001:276` | **Reuse — single ordering seam** |
| **Weight store + indexes** | `supabase/migrations/20260927090001_platform_config_and_ranking.sql:44,159,163` | `platform_config` + seed `service_ranking_weights` + `service_listings_published_ranking_idx WHERE published` | Versioned weights `coalesce` per call, `updated_at` as `weights_version` (`20260927090001:522`) | **Reuse** |
| **Search remote seam** | `lib/data/datasources/remote/service_search_remote_data_source.dart:30` + `service_search_envelope_parser.dart` | Live: `supabase.rpc('service_ranking_search')` via `BaseApiService`, `_guard(mapDataException)`, envelope `{items,has_more,next_cursor,weights_version}` | Single search accessor — never `from('service_listings').select()` | **Reuse — no new datasource file** |
| **Repository (cache-first)** | `lib/data/repositories/service_search_repository_impl.dart:19` | Live: `sha256(...).substring(0,16)` key `lib/data/repositories/service_search_repository_impl.dart:42`, browse `cache-first` vs query `network-first` `lib/data/repositories/service_search_repository_impl.dart:62`, `weights_version` invalidation `lib/data/repositories/service_search_repository_impl.dart:92` | Result window policy already matches `EP-03:56` p95 | **Reuse verbatim** |
| **Provider** | `lib/data/providers/marketplace_search_provider.dart:18` | Live: `ChangeNotifier`, `searchDebounce 250ms:25`, verbatim `items = page.items:100` no resort, `loadMore` append `121`, `invalidate` `129` | Discovery state `idle/loading/loaded/error` + empty `51` | **Extend (add getters, not replace)** |
| **Local cache** | `lib/data/datasources/local/service_search_local_data_source.dart:5,31` | `serviceSearchCachePrefix='service_search:'`, `serviceSearchCacheTtl 5m`, `CacheManagerServiceSearchLocalDataSource:31` with `Map` fallback | Transient window already `EP-03:316` compliant | **Reuse + add Hive tier** |
| **LRU + CacheManager** | `lib/core/cache/lru_cache.dart:12`, `lib/core/cache/cache_manager.dart:10` | Bounded (`maxEntries` env), `lazy expiry 39`, `put O(1) 58`, `invalidatePrefix 88` | Window for ranked pages | **Reuse — no new cache engine** |
| **Hive store** | `lib/core/database/adapters/hive_storage_engine.dart:15`, `lib/core/database/local_store.dart:13`, `lib/core/database/boxes/app_boxes.dart:11`, `lib/core/database/database.dart:27` | `Hive.init` via `path_provider`, `writeBatch snapshot rollback`, `6` boxes (`cache`, `syncQueue`, `entityCache`, etc.) | Persistent offline tier | **Extend — reuse engine, add `cache` prefix usage** |
| **Taxonomy engine** | `lib/workspace/profession_registry/taxonomy_engine.dart:12,20,52` | `browseIndustries/professions` `sortOrder`, `search` cap `100` `String.contains` | Filter chip validation (`profession_id`, `industry_id` active `PLT004`) | **Reuse for filter UI** |
| **Engine seam** | `lib/engine/search_engine/.gitkeep`, `lib/engine/recommendation_engine/ranking_formula.dart:17`, `lib/engine/matching_engine/matching_seam.dart:15` | `search_engine` empty; `RankingFormula` pure Dart mirror `6` signals, `1e-9` parity; `MatchingSeam` boundary note | `search_engine` must stay ranking-free (`AGENT.md:7`) — offline hydrator only | **Create `service_search_index.dart` thin hydrator (not ranking)** |
| **pgTAP posture** | `supabase/tests/database/023_service_marketplace_schema_posture.sql:1`, `033_platform_config_posture.sql:1`, `034_service_ranking_rpc_enforcement.sql:1` (plan 15) | Deterministic `plan 15`, `11` policies, `anon zero INSERT` checks | Template for `035/036` extensions | **Reuse pattern** |

Zero suitable existing `availability_date` filter exists — requires extension (see §7).

---

## 6. Reuse / Extension / Refactoring Assessment

| Major Proposed Asset | Assess | Decision | Why Not Alternate | Integration & Future Reuse |
|---|---|---|---|---|
| `service_listings.search_vector` + `GIN` + trigger | **Reuse** | Reuse verbatim | `20260921090001:122,130` already recomputes `industry_id` + `search_vector`; new DDL would diverge and break `034` `EXPLAIN Bitmap Scan` | Search composes `search_vector @@ v_query_tsquery` `20260927090001:449`; profession name already in vector, no `industries` join needed |
| `service_ranking_search` RPC | **Reuse** | Extend `p_filters` inside existing RPC (additive `IF p_filters ? 'availability_date'` block) | Creating `service_search` alias RPC duplicates 566-line scoring per `20260927090001:212`; violates `AGENT.md:7` single source | Weights read per call `coalesce(value->>'w_verify')`; extension keeps `has_table relrowsecurity` audits green (no new `SECURITY DEFINER` — `prosecdef` count stays 1 `service_review_reveal_if_ready`) |
| `ServiceSearchRemoteDataSource` | **Reuse** | Reuse `rankingSearch:17` | `SupabaseServiceSearchRemoteDataSource:30` already is single seam via `BaseApiService`; second class would split `dio`/`supabase` wiring | Filters forwarded as `filters?.toJson()`; no new method — `ServiceSearchFilters.toJson` extended |
| `ServiceSearchRepositoryImpl` cache policy | **Reuse** | Reuse `isBrowse cache-first 62, isQuery network-first` | Policy already prevents stale `ts_rank`; refactoring to `Hive` driver would replace `hive ^2.2.3` with `drift/isar` against `ARCHITECTURE.md:68` `hive` pin | `crypto sha256 3.0.3` already used for key `42`; future industries reuse same key derivation |
| `ServiceSearchLocalDataSource` Hive tier | **Extend** | Add `HiveServiceSearchLocalDataSource implements ServiceSearchLocalDataSource` mirroring `HiveOnboardingProgressStore` or wrap `CacheManagerServiceSearchLocalDataSource` with `LocalStore` second tier | Existing `CacheManager` is transient (`CacheManager:10` comment `process-wide`); offline browse requires `IndexedDB` persistence via `HiveStorageEngine` — no new driver, no new `AppBoxes` box required (reuse `cache` box with `service_search:` prefix `service_search_local_data_source.dart:5`) | Designed as reusable platform capability — `taxonomy_local_data_source:9` already `CacheManager` + fallback `Map`; extension extracts `FallbackResolver` helper for future engines |
| `MarketplaceSearchProvider` | **Extend** | Extend with `hasActiveFilters`, `refresh()` | Creating parallel `SearchProvider` splits `provider:6.1.5` state and breaks widget `no-resort` test `marketplace_search_screen_no_resort_test.dart` | Provider stays `ChangeNotifier` mirroring `TaxonomyProvider:31` `idle/loading/loaded/error` |
| `ServiceSearchFilters` | **Extend** | Add `availabilityDate DateTime?` field `lib/data/entities/service_listing.dart:156` | No existing `AvailabilityFilter` VO — `ServiceSearchFilters` is canonical `p_filters` VO (`toJson` maps snake) | Extension is additive; `isEmpty` + `toJson` updated; future `scheduling` module can reuse `availability_date` without schema change |
| `lib/engine/search_engine/service_search_index.dart` | **New** | Create new thin hydrator (not ranking) | All 7 `lib/engine/*.gitkeep` empty; `RankingFormula:17` explicitly `Never decides ordering` and must not be duplicated; `MatchingSeam:15` reserves routing for `EP-04` | `ServiceSearchIndex` depends on `ServiceSearchRepository` + `TaxonomyEngine.taxa 20` + `LocalStore` only; injects `ConnectivityPlus` for offline gate; exposes `warmBrowse` for `EP-03-09` `marketplace_discovery_screen` to call on `initState` without ordering logic; future `growth_engine` can reuse warm cache |
| `supabase/migrations` availability filter DDL | **Extend** (conditional) | Create additive migration only if product confirms `availability_date` in-sprint; else defer | `availability_slots` table `20260926090001_service_scheduling_schema.sql` exists but no `service_listings` join yet; pre-mature `EXISTS` subquery without product filter would be dead code | Migration `IF EXISTS` check on `availability_slots`, adds `availability_slots_profession_weekday_idx` if absent, patches `service_ranking_search` with `AND (v_filter_availability_date IS NULL OR EXISTS(...))` — idempotent, `PLT003` on bad date |

**Duplicate-prevention statement:** Every new asset above was inspected and found to have no suitable predecessor — `Grep platform_config`=found 1 table, `Grep service_ranking_search`=found 1 RPC, `Glob lib/engine/search_engine/*`=`.gitkeep` only. Proposing a new `service_search` RPC or second `LruCache` would create a parallel system performing the same business responsibility (ranking + FTS) with no architectural reason; therefore rejected.

---

## 7. Recommended Technical Approach

### 7.1 Server-Side: Single RPC Composition (Zero-Trust)

- **No new vector/index/tables** unless `availability_date` gated. All reads `WHERE status='published'` (`20260927090001:440`) so `anon` sees only `published`; `draft/paused/archived/reported` invisible (`PLT004` oracle-uniform `service_listing_get:1018` precedent).
- **Query sanitization:** `v_query_trim := btrim(coalesce(p_query,''))` capped `100` (`TaxonomyEngine.maxSearchQueryLength:20` parity), `plainto_tsquery('english', v_query_trim)` try/catch `v_query_tsquery IS NULL -> ts_rank 0` (`20260927090001:282`), never interpolated. Injection probe `'; DROP TABLE service_listings; --'` must `lives_ok` and table retained (`034:74`).
- **Filters JSON schema** (`20260927090001:314` pattern) — extend with:
  ```sql
  -- inside service_ranking_search after rating_min block
  IF p_filters ? 'availability_date' AND (p_filters->>'availability_date') IS NOT NULL THEN
    BEGIN v_filter_available_at := (p_filters->>'availability_date')::timestamptz;
    EXCEPTION WHEN others THEN 
      RAISE EXCEPTION USING errcode='P0001', message='PLT003: Invalid availability_date.', detail='PLT003';
    END;
  END IF;
  -- filtered CTE add:
  AND (v_filter_available_at IS NULL OR EXISTS (
    SELECT 1 FROM availability_slots s 
    JOIN appointments a ON a.slot_id=s.id 
    WHERE s.entity_id=sl.entity_id AND s.profession_id=sl.profession_id AND tstzrange(a.starts_at,a.ends_at) @> v_filter_available_at
  ))
  ```
  Validation returns `PLT003` for bad type, `PLT004` for unknown `profession_id`/`industry_id` (`20260927090001:325`).

### 7.2 Client: Two-Tier Cache + Offline Hydrator

```
supabase.rpc('service_ranking_search')  <-- only ordering authority
        |
ServiceSearchRemoteDataSource (BaseApiService:30, _guard:38)
        |
ServiceSearchRepositoryImpl  -- isBrowse cache-first / isQuery network-first (62)
        |-- getPage(service_search:<hash>)  -- LruCache transient 5m (serviceSearchCacheTtl 5m)
        |         `-- weights_version check -> invalidatePrefix(service_search:) if stale (92)
        `-- savePage + saveWeightsVersion -> CacheManager.put + Hive via LocalStore (fallback Map:55)
        |
MarketplaceSearchProvider (debounce 250ms:25, items verbatim 100, loadMore append 121)
        |
ServiceSearchIndex (lib/engine/search_engine/service_search_index.dart) -- new hydrator
        |-- warmBrowse(professionId?) calls repository.search(browse, limit 20) -> saves to Hive cache
        |-- hydrateOffline() prefetches industries -> professions -> top pages for offline ListView
        `-- invalidateOnWeightsBump() subscribes to weightsVersion delta
```

- **Cache key** `sha256('prof:…|q:…|f:…|c:…|l:…').substring(0,16)` (`40`) deterministic, `weights_version` in same namespace `service_search:weights_version` (`76`).
- **TTL** `serviceSearchCacheTtl 5m` (`service_search_local_data_source.dart:8`) preserves `STABLE` PostgREST `max-age 60` for `anon` without stale rank after weight bump (invalidation via `invalidatePrefix:88`).
- **Hive tier:** Reuse `Database.localStore(engine)` `lib/core/database/database.dart:82` over `AppBoxes.cache:15` — no new box constant unless capacity dictates; `AppBoxes.all:34` additive if needed.

### 7.3 Integration with Existing Platform

- **Domain models:** `service_listings.industry_id` re-derived `20260921090001:145` from `professions.industry_id` — future industry seed `20260829090001_taxonomy_seed_data.sql` auto-participates, no migration.
- **User/account:** `auth.uid()` drives RLS inside RPC; `platform_is_authenticated` `20260819090001` gate unchanged.
- **Professional/Client:** `is_trade_verified_cache` fast path (`service_listing_publish:554` trade gate) remains ranking input (`kyc_weight + verify_bonus 0.15` `20260927090001:454`).
- **Transaction/Finance:** `completion_rate` lateral `(count completed|closed / total) 20260927090001:465` over `service_contracts` unchanged — no ledger DDL.
- **Realtime/Sync:** `lib/core/sync/action_queue.dart:12` `sync_queue` box not used for search (read-only); `connectivity_plus:6.1.0` gates offline `warmBrowse` retry.

---

## 8. Required Systems, Modules, and Components

| Location | Component | Type | Purpose |
|---|---|---|---|
| `supabase/migrations/<ts>_search_filter_extension.sql` | Optional additive patch to `service_ranking_search` for `availability_date` + index `availability_slots(entity_id, profession_id)` | Migration (conditional, idempotent) | Filter composition extension without duplicating scoring |
| `lib/engine/search_engine/service_search_index.dart` | `class ServiceSearchIndex { Future<ServiceSearchPage> warmBrowse(...); Future<void> hydrateOffline(...); }` | Engine hydrator | Offline browse cache warmer — thin, ranking-free, reuses `ServiceSearchRepository` + `TaxonomyEngine` |
| `lib/data/entities/service_listing.dart:156` | Extend `ServiceSearchFilters` with `availabilityDate` | Entity VO | `p_filters.availability_date` typed contract |
| `lib/data/datasources/local/service_search_local_data_source.dart:14` | `HiveServiceSearchLocalDataSource implements ServiceSearchLocalDataSource` (or second-tier wrapper over `CacheManagerServiceSearchLocalDataSource:31`) | Local DS | Persistent `service_search:` prefix via `LocalStore`/`HiveStorageEngine` |
| `lib/data/datasources/remote/service_search_remote_data_source.dart:30` | No new file — extend `filters` passthrough | Remote DS | Single seam preserved |
| `lib/data/repositories/service_search_repository_impl.dart:19` | No new file — keep `sha256` key + `isBrowse` policy | Repository | Cache-first browse / network-first query |
| `lib/data/providers/marketplace_search_provider.dart:18` | Add `hasActiveFilters`, `refresh()` | Provider | State for `EP-03-09` filter chips + debounce |
| `supabase/tests/database/034_service_ranking_rpc_enforcement.sql:1` | Extend plan 15 → plan 22 (add `query='legal drafting'` `ts_rank`, `currency`/`price_range`/`availability_date`, cursor no-overlap, injection) | pgTAP | Enforcement matrix extension |
| `supabase/tests/database/035_search_cache_posture.sql` | New only if Hive tier adds table/box policy; else omit | pgTAP (conditional) | `relrowsecurity` + `anon EXECUTE` stay green |
| `test/unit/engine/search_engine/service_search_index_test.dart` | Unit + `fake_async` | Test | `warmBrowse` caches browse, `hydrateOffline` on offline returns `Hive` page |
| `test/unit/data/service_search_repository_impl_test.dart` | Existing → extend | Test | Hit/miss/invalidation on `weights_version` bump |

No new `lib/systems/marketplace` widgets in this task — provider DTO proves contract.

---

## 9. Data Requirements

- **Inputs per call:** `p_profession_id uuid?` (active only `PLT004`), `p_query text?` `btrim` `0..100` `plainto_tsquery` sanitized, `p_filters jsonb` (`profession_id uuid?`, `industry_id uuid?`, `price_min/max numeric >=0` `price_max>=price_min` `20260927090001:364`, `currency_code char(3)` active `20260927090001:385`, `rating_min 0..5` `20260927090001:392`, `is_trade_verified_only bool` `405` + alias `is_verified_only` `405`, `availability_date timestamptz?` — new, `PLT003` on bad, `PLT004` on unknown profession/industry), `p_cursor jsonb {score numeric, id uuid}?` `20260927090001:291`, `p_limit 1..50` default `20` `20260927090001:258`.
- **Output `data`:** `items[{id, entity_id, profession_id, industry_id, slug, title, description, pricing_type, price_min/max, currency_code, avg_rating: 0..5, review_count, is_trade_verified_cache, published_at, profession_slug/name, industry_slug/name, score numeric(10,6)}...]`, `has_more bool`, `next_cursor {score,id}?`, `weights_version timestamptz` (`20260927090001:522`). `search_vector` never returned (whitelist projection `20260921090001:542` owner grants zero).
- **Cursor determinism:** `(score DESC, id DESC)` total order; `score round(::numeric,6)` eliminates float tie-flip (`20260927090001:472`).
- **Weights:** `platform_config.key='service_ranking_weights'` `value jsonb` `CHECK sum 0.999..1.001` `20260927090001:68` — `anon/authenticated` `SELECT` only, `service_role` `UPDATE` (`20260927090001:111`).

---

## 10. Database Considerations

- **No prior DDL rewritten.** All patches `IF NOT EXISTS / CREATE OR REPLACE / DROP IF EXISTS` per `20260921090001:38` discipline.
- **If `availability_date` gated:** Add
  ```sql
  create index if not exists availability_slots_entity_profession_idx 
    on public.availability_slots (entity_id, profession_id);
  -- patch service_ranking_search signature unchanged; body adds v_filter_available_at timestamptz + EXISTS clause filtered:7
  comment on function public.service_ranking_search(uuid,text,jsonb,jsonb,int) is '... + availability_date via availability_slots EXISTS.';
  revoke execute on all functions in schema public from public; -- re-apply anon grants per 20260927090001:537
  grant execute on function public.service_ranking_search(uuid,text,jsonb,jsonb,int) to anon, authenticated, service_role;
  ```
  Exclude `platform_config`/`service_listings` from `supabase_realtime` already (`20260927090001:555`).
- **Performance indexes verified:** `service_listings_search_vector_gin 122`, `service_listings_published_ranking_idx (profession_id, avg_rating DESC, published_at DESC) WHERE published 163`, `entities_last_seen_at_idx 169` retained. `EXPLAIN` must show `Bitmap Index Scan on service_listings_search_vector_gin` when `p_query` present (pgTAP assert).

---

## 11. API Requirements

| Endpoint | Method | Auth | Purpose | Notes |
|---|---|---|---|---|
| `POST /rest/v1/rpc/service_ranking_search` | `supabase.rpc` via `BaseApiService.supabase` (`lib/core/api/services/base_api_service.dart:1`) | `anon` (public browse) + `authenticated` + `service_role` | Ranked filtered discovery page | `STABLE` cacheable `GET /rpc/...` with `apikey anon`; `Cache-Control: public, max-age=60`; `weights_version` in payload invalidates without `ETag` |
| (direct table `GET /rest/v1/service_listings`) | — | — | **Not used for discovery ordering** | Owner CRUD via `service_listing_get:list_mine` only; discovery is RPC-only to enforce `AGENT.md:13` |
| `platform_config SELECT` | — | `anon`/`authenticated` `SELECT` only | Weight read per RPC call | `service_role` `INSERT(key,value,description)/UPDATE(value,description)` only `20260927090001:110` |

- **Request (`jsonb` envelope):** `p_profession_id uuid?`, `p_query text?` (empty → `ts_rank 0`), `p_filters jsonb` strict schema, `p_cursor jsonb {score,id}?`, `p_limit int`.
- **Response envelope:** `{success bool, code PLT000|PLT003|PLT004|PLT999, message, data:{items, has_more, next_cursor?, weights_version}}` per `20260829100004:16` + `anon` `errcode P0001`/`detail PLT*` contract `20260927090001:259`.
- **Errors:** `p_profession_id` unknown/inactive → `PLT004` identical to no visible rows (no oracle `service_listing_get:1054`); `p_limit` out of `1..50` → `PLT003`; `p_cursor` invalid → `PLT003`; `p_filters.rating_min 6` → `PLT003` (`034:94`); `price_max<price_min` → `PLT003`; `injection` `'test; DROP TABLE...'` → `lives_ok` table retained (`034:74`).
- **Pagination:** Keyset `WHERE (score,id) < (cursor_score,cursor_id)` `20260927090001:484` + `ORDER BY score DESC, id DESC LIMIT p_limit+1` → `has_more` (`20260927090001:502`).

---

## 12. User Interface Requirements

Per `EP-03:316` this task ships **no new screen** but ships the provider/DTO contract `EP-03-08/09` consumes. UI constraints for subsequent work (gated in DoD):

- **Token compliance (`AGENT.md:18`, `VISUAL-IDENTITY.md:3-250`):** No `Colors.*`/`raw hex`/`fontFamily` per-widget; future `marketplace_discovery_screen` must use `Theme.of(context).colorScheme` / `AppThemeExtension` + `TextTheme` + `HivorrCard` `lib/shared/widgets/hivorr_card.dart`, `HivorrContentPane` `lib/shared/layouts/hivorr_content_pane.dart` (`~720dp max, 16/24dp gutters`), `HivorrChip` filters, `HivorrLoadingState(HivorrLoader)` pulse, `HivorrEmptyState` for `items=[]` (`MarketplaceSearchProvider.isEmpty:51`).
- **Route hygiene:** No new `lib/app/router/app_router.dart:1` route in this task (`/s/:profession_slug/:service_id` deferred to `EP-03-19`).
- **Widgets not required for DoD:** `marketplace_discovery_screen.dart`, `marketplace_search_screen.dart`, `service_detail_screen.dart`, `portfolio_grid` (`EP-03:99`).

---

## 13. User Experience Considerations

- **Fairness UX:** Same query → same order until `weights_version` bump or new `published` insertion — no shimmer reorder; `ListView key: ValueKey(id)` preserves position. Lint bans `sort.*score` (`EP-03:308`).
- **Cold-start:** `bayesian_avg` prior `5×3.0` (`20260927090001:144`) keeps 0-review verified listings mid-list, not sunk.
- **Empty & error:** `items=[]` + `HivorrEmptyState` `No services yet` (owner) vs `Try another filter` (consumer) driven `isEmpty`; `PLT003/004` → `HivorrErrorState` + `Retry` via `RetryInterceptor`.
- **Offline:** Warm browse from `CacheManager 5m` returns instantly; FTS `query` is network-first for fresh `ts_rank`; `ServiceSearchIndex.hydrateOffline()` prewarms `Hive` with taxonomy + top 20 per popular `profession_id` so airplane browse shows last ranked page without blank.
- **No AI surprise:** Per `AGENT.md:7` AI groups (`Featured`) never override RPC order; copy states `Ranked by verification, rating, completion`.

---

## 14. Security Considerations

- **Zero-Trust (`AGENT.md:6,13` Rule 4):** All scoring in `SECURITY INVOKER STABLE` `20260927090001:230`; client never receives `search_vector` (whitelist `service_listing_get:1042` excludes it), `kyc` internals, or `UPDATE platform_config` grant. `RankingFormula:17` display-only; CI flags `amount reduce` or `score sort` in `lib/systems` as failure (`EP-03:182`).
- **RLS:** `platform_config anon/authenticated SELECT only` `20260927090001:109`; `service_listings` `REVOKE ALL` + `service_listings_select_public (status='published')` `20260921090001:381` + `select_own/insert_own/update_own` `386`; `service_review_aggregates` `SELECT anon,authenticated` `20260924090001:158`. `anon` `GET /rpc/service_ranking_search` sees only `published`.
- **No `SECURITY DEFINER` expansion:** Only `service_review_reveal_if_ready:541` stays definer; new RPC is invoker (`023:216` pins 1).
- **Injection:** `p_query` via `plainto_tsquery('english', v_query_trim)` `282`; `search_vector` trigger `20260921090001:146` prevents injection; `p_filters` via `::numeric/::uuid` casts with `PLT003` on bad.
- **Weights tampering:** `authenticated` lacks `UPDATE` on `platform_config`; RLS `current_user IN ('service_role','postgres')` blocks `PATCH /rest/v1/platform_config` (`42501`). Only console `service_role` mutates; `updated_at` audited.
- **PII:** Projection excludes `legal_name`/`document_path`; `lib/core/logging/pii_redactor.dart:1` redacts logs.
- **Realtime:** `platform_config` + `service_listings` excluded from `supabase_realtime` `20260927090001:555`.

---

## 15. Performance Considerations

| Query path | Index | Verification (`EXPLAIN`) |
|---|---|---|
| `p_query present` | `service_listings_search_vector_gin` `GIN(search_vector)` `20260921090001:122` | `Bitmap Index Scan` on `service_listings_search_vector_gin` when `search_vector @@ plainto_tsquery` (`20260927090001:449`) |
| `profession_id filter` | `service_listings_published_ranking_idx (profession_id, avg_rating DESC, published_at DESC) WHERE published` `20260927090001:163` | `Index Scan` on `profession_id` |
| `rating + recency` | `service_listings_published_at_idx WHERE published:120` + `service_review_aggregates_profession_idx:129` | `Index Only Scan` on aggregates PK `(professional_entity_id, profession_id)` |
| `completion_rate` lateral | `service_contracts (professional_entity_id)` | `Index Scan` (no per-row N+1 — single `SELECT` with `LATERAL`) |
| `availability_date` (if added) | `availability_slots(entity_id, profession_id)` new | `Index Scan` on `EXISTS` |

- **Pagination:** Keyset `(score DESC, id DESC)` `LIMIT p_limit+1 (50+1)` avoids `OFFSET` O(N); cursor `jsonb {score,id}` `20260927090001:510`.
- **Budget:** `p95 <400ms` `EP-03:56`; benchmark seeded 10k `published` via `EXPLAIN (ANALYZE,BUFFERS)` — `shared hit` dominated, no `Seq Scan`; client cap `50` prevents unbounded fetch.
- **Client cache:** `LruCache(maxEntries:50, defaultTtl:5m)` `lib/core/cache/cache_config.dart:1` + `invalidatePrefix('service_search:')` `lib/core/cache/cache_manager.dart:88` bounded; `Hive` warm persists browse without `Isar/SQLite` change (`lib/core/database/database_config.dart driverType hive`).

---

## 16. Testing Strategy

### 16.1 pgTAP — Posture & Enforcement (`supabase test db`)

**Extend `034_service_ranking_rpc_enforcement.sql` plan 15 → plan 22:**

- Deterministic `service_ranking_search(p_limit=>10)` twice same `items.text` (`034:10`)
- `weights_version present` (`034:22`)
- `query='legal drafting'` ranked hits with `ts_rank` tie-break — `jsonb_array_length` with query ≤ without + `ts_rank query executes` (`034:42`) plus new assertion `score` monotonic `DESC, id DESC` over 10 fixtures
- `rating_min=4.5` excludes `<4.5` (`034:28`) + `currency_code='NGN'` + `price_min/max` bracket + `industry_id` subset `<=` count
- Cursor `has_more`/`next_cursor` no overlap — page 1 `20` → page 2 `no id overlap` via `sha256` key pagination already in `024` `list_mine 6 fixtures` pattern
- `p_limit 0/51 PLT003` (`034:53`), `p_cursor bad PLT003` (`034:66`), `unknown profession PLT004` (`034:83`), `non-object p_filters PLT003` (`034:91`), `rating_min 6 PLT003` (`034:94`)
- Injection sanitized `lives_ok` + table retained (`034:74`)
- `draft invisible slug 0` (`034:48`), `anon lives_ok` for `service_ranking_search` (`033: anon EXECUTE 4` + `20260927090001:539`)
- `EXPLAIN Bitmap Index Scan on service_listings_search_vector_gin` when `p_query='legal'` (new `lives_ok` with `EXPLAIN`) — p95 `<400ms` logged in `EP-03-20` report

If availability migration added: new `035_search_filter_extension_posture.sql` (`has_index availability_slots_entity_profession_idx`, `has_function_privilege anon EXECUTE service_ranking_search`, `regression 023/033 counts` `prosecdef still 1`).

### 16.2 Unit / Widget / Repository / Provider (`flutter test`)

| Suite | File (new or extend) | Cases |
|---|---|---|
| `RankingFormula` | `test/unit/engine/recommendation_engine/ranking_formula_test.dart:1` already | 10-listing fixture deterministic `1e-9` vs SQL `score`, `kycTierWeight tier_3=1.0/2=0.66/1=0.33:179`, `bayesianAvg 132`, `recencyDecay 142` |
| `ServiceSearchRemote` | `test/unit/data/service_search_remote_data_source_test.dart` | `rankingSearch` with `p_query` sanitizes, `filters.currency_code invalid → PLT003` map via `ServiceSearchEnvelopeParser`, anon `P0001 detail PLT003` path `20260921090001:1036` |
| `Repository` | Extend `test/unit/data/service_search_repository_impl_test.dart` | Browse `cache hit → zero RPC`, miss → remote → save, query `network-first` never cache, `weights_version bump → invalidatePrefix(service_search:)` `88` |
| `LocalDataSource` | `test/unit/data/service_search_local_data_source_test.dart` | `CacheManager` `5m TTL` expiry `LruCache:39`, `Fallback Map 68`, `weights_version persisted` `73` |
| `ServiceSearchIndex` | New `test/unit/engine/search_engine/service_search_index_test.dart` | `warmBrowse` populates `service_search:<hash>`, `hydrateOffline` on offline (`connectivity_plus` mock `none`) returns `Hive` page, not `PLT004` |
| `Provider` | `test/unit/providers/marketplace_search_provider_test.dart` | `setQuery debounce 250ms` `fake_async:1.3.1` same as `TaxonomyProvider`, `search` assigns `items` verbatim no resort, `loadMore` appends, `invalidate` resets `idle` `129` |
| `Widget` | `test/widget/systems/marketplace_search_screen_no_resort_test.dart` | Assert `renderOrder == rpcOrder` fails if `sort.*score` regex found; `HivorrEmptyState` on `isEmpty 51`, `HivorrLoadingState` on `isLoading 54` |

### 16.3 Integration / E2E (Staging)

- Seed 6 listings across 2 professions (`fixture-draft-invisible` stays excluded) → `query='fixtures drafting'` paginate `limit 2` three pages `has_more/next_cursor` no overlap (`024` pattern 6 fixtures).
- `anon` browse `GET /rpc/service_ranking_search` `PLT000` vs authenticated same `items.text` identical.
- Token assertion `ColorScheme.primary == #0B6E99` `VISUAL-IDENTITY:84` passes.

---

## 17. Recommended Implementation Sequence

1. **Reconcile filter surface** — confirm with product whether `availability_date` enters `EP-03-07` or defers to `EP-03-14`; if defer, step 2 is **zero DDL**.
2. **Server (conditional)** — if `availability_date` approved: author `supabase/migrations/<ts>_search_filter_extension.sql` patching `service_ranking_search` `p_filters` validation + `EXISTS(availability_slots)` + index; `REVOKE/GRANT` re-apply `anon/authenticated/service_role` `20260927090001:539`; `COMMENT` version `v1.1`; lint `supabase db diff` shows additive only.
3. **Client VO** — extend `ServiceSearchFilters` `lib/data/entities/service_listing.dart:156` with `availabilityDate`.
4. **Client Hive tier** — implement `HiveServiceSearchLocalDataSource implements ServiceSearchLocalDataSource` over `LocalStore` `lib/core/database/local_store.dart:13` reusing `serviceSearchCachePrefix:5` + `serviceSearchCacheTtl 5m:8`; or wrap `CacheManagerServiceSearchLocalDataSource:31` with `Hive` second tier; `writeBatch` `storage_engine.dart:60` for atomic warm.
5. **Engine hydrator** — create `lib/engine/search_engine/service_search_index.dart` (`ServiceSearchIndex` + `SearchCacheWarmer` if split), injecting `ServiceSearchRepository` + `TaxonomyEngine.browseIndustries 23` + `CacheManager.isInitialized 27`.
6. **Provider extension** — add `hasActiveFilters`, `refresh()` to `MarketplaceSearchProvider:18` keeping debounce `25`; emit `notifyListeners` `76`.
7. **Tests** — extend `034` to 22, add unit suites above, run `dart analyze` + `flutter test` + `supabase test db` + `EXPLAIN` bench; `grep -r "sort.*score" lib/` must be `0`.
8. **Verification gate** — demo on Staging: `curl anon apikey POST /rpc/service_ranking_search p_query='legal drafting'` ranked + `rating_min=4.5` filter + cursor paging no overlap + offline airplane `hydrateOffline` returns warm page.

---

## 18. Expected Outcome

- **FTS correctness:** `search_vector` trigger + `GIN` retained (`023` `GIN 1` check green); `query='legal drafting'` returns ranked hits with `ts_rank` tie-break; `rating_min`/`price`/`industry`/`verified_only`/`currency` filters subset counts correctly.
- **Pagination:** Cursor `(score DESC, id DESC)` `has_more`/`next_cursor` 20-per-page deterministic; sequential pages have zero `id` overlap.
- **Caching:** Browse (warm `industries→professions` Top 20) issues zero RPCs (`cache-first 62`); `5m` `CacheManager` window `invalidatePrefix 88` on `weights_version` bump (`20260927090001:522`) prevents stale rank; offline `Hive` hydrate serves last ranked page via `ServiceSearchIndex`.
- **No ordering oracle:** Client never resorts — `MarketplaceSearchProvider` `items=page.items 100` verbatim; `LruCache` + `Hive` store opaque pages, not re-score.
- **Anon/public SEO:** `anon` `POST /rpc/service_ranking_search` `PLT000` for `published` only; `draft` rows remain `PLT004` oracle-uniform; `service_search_envelope_parser` maps `42501/P0001 PLT002`.

---

## 19. Definition of Done (DoD)

**Functional**
- [ ] `GIN(service_listings.search_vector)` retained `1` (`20260921090001:122`) — `034` `has_index` passes.
- [ ] `service_ranking_search(p_limit 1..50, p_profession_id active, p_query btrim<=100, p_filters jsonb, p_cursor {score,id})` deterministic `score DESC, id DESC` — seeded 10 fixtures yield identical `items.text` twice (`034:10`).
- [ ] Filters `profession_id`/`industry_id`/`price_min`/`price_max`/`currency_code`/`rating_min 0..5`/`is_trade_verified_only` (alias `is_verified_only`) validated `PLT003` on bad, `PLT004` on unknown (`20260927090001:314`).
- [ ] `query='legal drafting'` FTS path executes via `plainto_tsquery` + `ts_rank` `0..1`; stopwords-only `query` treated as `NULL` (`ts_rank 0`), not error.
- [ ] Keyset cursor pagination `has_more`/`next_cursor` no overlap across 3 pages of 20.
- [ ] `weights_version` (`platform_config.updated_at`) returned in `data` and drives `CacheManager invalidatePrefix(service_search:)` on bump (`service_search_repository_impl:92`).
- [ ] `ServiceSearchIndex.warmBrowse` / `hydrateOffline` caches `industries→professions` Top 20 per warm profession into `Hive`/`CacheManager` `service_search:<hash>` `5m`.
- [ ] `anon` browse `PLT000`, `draft` never in ranked results (`034:48`).

**Technical**
- [ ] No new `search_vector`/`GIN`/trigger DDL unless `availability_date` conditional migration — `supabase db diff` shows only additive filter patch if present.
- [ ] All RPCs `SECURITY INVOKER STABLE` (`082` `prosecdef` still `1` — `service_review_reveal_if_ready` only); `REVOKE execute on all functions from public` + `GRANT anon,authenticated,service_role` on `service_ranking_search` `539`.
- [ ] Client never `sort`s RPC `items` — `grep -r "sort.*score" lib/` `0`; provider `items = data.items` verbatim.
- [ ] Single RPC seam `SupabaseServiceSearchRemoteDataSource:30` via `BaseApiService`; no `supabase.from('service_listings').select` for discovery ordering.

**Data**
- [ ] `platform_config` RLS `enable row level security 105` + `relrowsecurity true 1` + `CHECK key_format + value is_object + weights_required_keys + weights_range + weights_sum + weights_priors` `033`.
- [ ] Projection whitelist excludes `search_vector`/`view_count` zero grants (`20260921090001:350`).

**Security**
- [ ] `anon`/`authenticated` `SELECT` only on `platform_config`; `authenticated` zero `INSERT/UPDATE/DELETE` (`033` `has_column_privilege`); `service_role` `UPDATE(value,description)` only `111`.
- [ ] Injection probe `'; DROP TABLE service_listings; --'` `lives_ok` and `pg_class relname='service_listings'` `=1` (`034:74`).
- [ ] `p_query` capped `100`, `p_limit` `1..50` `PLT003`, `p_filters non-object` `PLT003`, `rating_min 6` `PLT003`.

**Performance**
- [ ] `EXPLAIN (ANALYZE,BUFFERS)` when `p_query` present → `Bitmap Index Scan on service_listings_search_vector_gin`; else `Index Scan` on `service_listings_published_ranking_idx`.
- [ ] p95 filtered search `<400ms` on staging seeded 10k `published` (logged in `EP-03-20` style report).
- [ ] `LruCache(maxEntries:50, defaultTtl:5m)` bounded; `invalidatePrefix` without full clear.

**Testing**
- [ ] `supabase/tests/database/034_service_ranking_rpc_enforcement.sql` extended plan 22 all green; `023`/`008` full-schema posture audits still green.
- [ ] Unit `service_search_index_test 4`, repository `hit/miss/invalidate`, provider `fake_async 250ms`, widget `no-resort` all green; `dart analyze` 0 issues.

**UI / Visual Identity**
- [ ] Zero `Colors.*`/`hex`/`fontFamily` in `lib/engine`/`lib/data` per `AGENT.md:18`; `VISUAL-IDENTITY` token assertion `ColorScheme.primary == #0B6E99` passes.
- [ ] Provider drives `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState` throughout future screens (`MarketplaceSearchProvider:isEmpty 51`).

**Final Approval**
- [ ] Migration `/** RANKING FORMULA v1 — 2026-09-26 — weights via platform_config service_ranking_weights */` header (`20260927090001:30`) retained; patch if any adds `v1.1 availability_date` note without losing determinism.
- [ ] `documents/Task-Implementation/EP-03/EP-03-07-Definition-of-Done.md` produced mirroring `EP-03-06` 12-gate checklist.

---

## 20. Implementation AI Execution Profile

**Recommended Coding Reasoning Level:** **Very High**

**Justification:**

- **Technical complexity — High:** Composes 6-signal deterministic scoring (`kyc_tier_weight`, `bayesian_avg`, `completion_rate`, `recency_decay`, `ts_rank`, `activity_decay`) across 5 lateral CTEs (`20260927090001:426`) with keyset cursor `(score,id)` lexicographic `20260927090001:484` and `GIN`/`partial` index selection. Additive `availability_date` requires `availability_slots` temporal `EXISTS` without regressing `p95 <400ms` or `Bitmap Scan`. Two-tier cache `key=sha256 16` `42` + `weights_version` coherence adds concurrency edge.
- **Business impact — High:** Frequency driver + ranking is catastrophic trust risk (`EP-03:175` perceived bias); Stage 2 gate — ranking error blocks `EP-03-08/09/20` marketplace Go/No-Go.
- **Security risk — High:** `anon` FTS (`plainto_tsquery` sanitization `282`), RLS `status='published'` only, `plain P0001 detail PLT003/004` oracle-uniform `259`, no `SECURITY DEFINER` expansion (posture `prosecdef` `1`). Any misstep leaks `draft` or enables weight tampering `authenticated UPDATE`.
- **Performance sensitivity — High:** GIN `ts_rank` + `profession_id` partial + keyset pagination must avoid `Seq Scan`/`OFFSET`; p95 budget `400ms` enforceable only with correct `LIMIT p_limit+1` `502` and bounded `LruCache 50/5m`.
- **Data complexity — Very High:** Cross-domain joins (`service_listings` + `service_review_aggregates` + `entity_kyc_levels` + `service_contracts` lateral `465` + `entities.last_seen_at` `167` + optional `availability_slots`) with Bayesian cold-start `prior 5×3.0` `144` and tie-break total order `id DESC`.
- **Integration complexity — High:** Must reuse `BaseApiService` single seam, `CacheManager` + `HiveStorageEngine` without new driver, `TaxonomyEngine` filter validation, and preserve `ARCHITECTURE.md:71-76` directory boundaries (`search_engine` hydrator ≠ `recommendation_engine` scorer).

> `High` insufficient — misses injection/oracle/bayesian edge; `Extremely High` reserved for `EP-03-01/02/03/06/11` financial/double-blind state machines where ledger atomicity is at stake. `Very High` aligns with `EP-03` roadmap summary `EP-03-07: Very High` (`EP-03:407`).

**Wait for approval before proceeding to implementation.**
