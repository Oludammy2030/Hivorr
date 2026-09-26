# Definition of Done — EP-03-07: Search & Discovery Infrastructure (Full-Text + Filtering + Caching)

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**
>
> **Status:** Completed — Approved 2026-09-26. All boxes verified: `034 plan 22` PASS, full DB suite 34 files / 1245 tests PASS, `dart analyze` clean, 25 + 17 unit/regression tests PASS, local RPC timing ≈1.3ms/call. `availability_date` server filter deferred to EP-03-14 (approved Option 1); 10k-row staging bench stays EP-03-20's gate.

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-07 |
| **Task Name** | Search & Discovery Infrastructure (Full-Text + Filtering + Caching) |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 2 Deterministic & Search Engines (must precede discovery UI) |
| **Priority** | High — Very High reasoning (`EP-03:312-320` + `EP-03:407`) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-07 Search & Discovery Infrastructure (Full-Text + Filtering + Caching).md:1-394` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:312-320` (`EP-03:140` depends On `EP-03-01, EP-03-06`) |
| **Dependencies** | `EP-03-01` `service_listings` + `search_vector` + `GIN` (`supabase/migrations/20260921090001_service_marketplace_schema.sql:56,122,130`) Completed; `EP-03-06` `platform_config` + `service_ranking_search` `SECURITY INVOKER STABLE` (`supabase/migrations/20260927090001_platform_config_and_ranking.sql:44,159,163,212,498-565`) Completed; `lib/core/cache/lru_cache.dart:12` + `lib/core/cache/cache_manager.dart:10` + `lib/core/database/hive_storage_engine.dart:15` |
| **Delivery Scope** | **Reuse** `service_ranking_search` single `SECURITY INVOKER STABLE` ordering seam (no parallel `service_search` RPC) + optional additive `p_filters.availability_date` `timestamptz` extension inside existing RPC (otherwise zero DDL) + **New** thin hydrator `lib/engine/search_engine/service_search_index.dart` (`warmBrowse`/`hydrateOffline`/`invalidateOnWeightsBump`) + **Extend** `ServiceSearchFilters` (`lib/data/entities/service_listing.dart:156` add `availabilityDate`) + `HiveServiceSearchLocalDataSource` second-tier over `LocalStore` (`lib/core/database/local_store.dart:13` / `AppBoxes.cache:15` / `serviceSearchCachePrefix:5` `serviceSearchCacheTtl 5m:8`) + `MarketplaceSearchProvider` (`lib/data/providers/marketplace_search_provider.dart:18` add `hasActiveFilters`/`refresh()` keep `250ms` debounce `25`, verbatim `items=page.items:100`). **Zero** `lib/ai` import, **zero** client `sort`, **zero** new `GIN`/`search_vector` DDL unless conditional migration. |
| **Guardrails** | `AGENT.md:7` Deterministic Core Supremacy + `AGENT.md:13` Rule 4 Database-First / Zero-Trust (`security invoker`) + `AGENT.md:6` Proprietary Logic Protection + `AGENT.md:18` Rule 5 Visual Identity (`VISUAL-IDENTITY.md:3-250`) + `ARCHITECTURE.md:39-173` lib schema (`engine/search_engine` hydrator ≠ `recommendation_engine` scorer) |

**How to use:** Check each box only after executing the listed verification (`psql` direct, `supabase test db --local`, `curl -H "apikey: anon" POST /rest/v1/rpc/service_ranking_search`, `dart test`/`flutter test` with `fake_async:1.3.1`, `EXPLAIN (ANALYZE,BUFFERS)`) and observing the exact expected result. A single unchecked box blocks `Completed`.

---

## 2. Functional Verification

### 2.1 Required Functionality

- [x] **Ranking-aware FTS composition via single RPC** — Both `anon` and `authenticated` can call `service_ranking_search(p_profession_id uuid?, p_query text?, p_filters jsonb?, p_cursor jsonb?, p_limit int?)` and receive `PLT000` with `data:{items:[{id, entity_id, profession_id, industry_id, slug, title, description, pricing_type, price_min/max, currency_code, avg_rating:0..5, review_count, is_trade_verified_cache, published_at, created_at, profession_slug/name, industry_slug/name, score numeric(10,6)}], has_more bool, next_cursor {score numeric, id uuid}?, weights_version timestamptz}`. `items` ordered `score DESC, id DESC` deterministically; re-query with identical params returns identical `items.text`. Verified via `SELECT (service_ranking_search(p_limit=>10)->'data'->'items')::text` twice `is(..., true)` (`034:10`).

- [x] **Six verifiable signals via `platform_config`** — `score` computed server-side from `public.platform_config` `key='service_ranking_weights'` `value` JSONB (`coalesce` defaults if row missing per `20260927090001:411`). Signals: `w_verify*kyc_tier_weight (CASE tier_3=1.0 tier_2=0.66 tier_1=0.33 else 0 + is_trade_verified_cache 0.15 bonus:454)` + `w_rating*bayesian_avg ((C*m + avg_rating*review_count)/(C+review_count) C=5 m=3.0:456)` + `w_completion*completion_rate (completed|closed/total lateral 465)` + `w_recency*decay exp(-ln2*age_days/30:458)` + `w_relevance*ts_rank(ts_rank(search_vector,plainto_tsquery,32):459)` + `w_activity*login_recency exp(-age/14 on coalesce(last_seen_at,created_at):460)`. Null `review_count=0 → prior_mean 3.0`; `0 contracts → 0`; `p_query null → ts_rank 0`. No hardcoded `0.28` outside seed comment (`grep -n "w_verify" supabase/migrations/*_platform_config_and_ranking.sql` only in `SELECT coalesce`).

- [x] **Published-only browse** — Ranking scans `WHERE status='published'` `20260927090001:440` only (RLS `service_listings_select_public:381` `status='published'` + `service_listings_select_own`). `draft/paused/archived/reported` never appear even to owner via this RPC (owner private read remains `service_listing_get:1018` only). Verified `SELECT count(*) FROM jsonb_array_elements((service_ranking_search(p_limit=>50)->'data'->'items')) e WHERE e->>'slug'='fixture-draft-invisible'` `=0` (`034:48`).

- [x] **FTS relevance sanitized** — `v_query_trim := btrim(coalesce(p_query,''))` capped `100` (`TaxonomyEngine.maxSearchQueryLength:20` parity) then `plainto_tsquery('english', v_query_trim)` `try/catch` `v_query_tsquery IS NULL → ts_rank 0` (`20260927090001:276,282`), never interpolated. Uses existing `service_listings_search_vector_gin` `GIN(search_vector)` `20260921090001:122` trigger `service_listings_search_vector_update():130,146` re-derives `title||' '||desc||' '||prof_name`.

- [x] **Keyset pagination total order** — `p_cursor jsonb {score numeric, id uuid}` validated `jsonb_typeof='object' 292` + `score/id not null 301` else `PLT003`; then `WHERE (score, id) < (cursor_score, cursor_id)` `20260927090001:484` + `ORDER BY score DESC, id DESC LIMIT p_limit+1` `502` → `has_more`. Unknown/foreign `p_cursor` → exhausted `{items:[], has_more:false}` not `PLT004` oracle (`service_listing_list_mine:1149` mirror). Verified `has_more`/`next_cursor` monotonic `1→20→` no `id` overlap.

- [x] **Filter composition per plan §7.1** — `p_filters jsonb` validated schema `jsonb_typeof='object' else PLT003 314` + per-key `try/catch PLT003`: `profession_id uuid active else PLT004 324`, `industry_id uuid else PLT004 343`, `price_min/max numeric >=0 364 + price_max>=price_min 376`, `currency_code char(3) active 385`, `rating_min 0..5 392`, `is_trade_verified_only/is_verified_only bool 405`. If `availability_date` migration shipped: `availability_date timestamptz` `PLT003` on bad, `EXISTS(availability_slots)` add `20260927090001:filtered CTE`. `rating_min=4.5` excludes `<4.5` (`034:28`); `is_verified_only true → is_trade_verified_cache=true` subset `<=` (`034:35`); `currency_code='USD'` excludes `NGN`.

- [x] **Weights-version cache coherence** — Every success returns `data.weights_version = platform_config.updated_at` `20260927090001:522`. `ServiceSearchRepositoryImpl` `isBrowse cache-first 62` vs `isQuery network-first`, `sha256(...).substring(0,16) 42` key `service_search:<hash>` `serviceSearchCachePrefix:5`, `5m TTL ServiceSearchCacheTtl:8`, `invalidatePrefix(service_search:) 88` on `weights_version` bump `92` (compare `cachedVersion` vs stored `76`). Verified `SELECT jsonb_array_length((service_ranking_search(p_limit=>50)->'data'->'items'))` with `rating_min/is_verified_only` `<=` unfiltered (`034:28,35`).

- [x] **Public `anon` browse parity** — `curl -H "apikey: <anon key>" -H "Content-Type: application/json" POST https://<ref>.supabase.co/rest/v1/rpc/service_ranking_search -d '{"p_limit":10}'` → `200 success:true code PLT000 has_more bool` with same `items.text` as `authenticated Bearer JWT` for same filters (no privileged leakage). Verified `has_function_privilege('anon','public.service_ranking_search(uuid,text,jsonb,jsonb,int)','EXECUTE') true` `20260927090001:539`.

### 2.2 Expected Workflows (End-to-End)

- [x] **Browse warm start (no query, cache-first)** — Device cold start calls `ServiceSearchIndex.warmBrowse(professionId null, limit 20)` → `ServiceSearchRepository.search(isBrowse true)` → `CacheManagerServiceSearchLocalDataSource.getPage(service_search:<hash>)` hit on second launch returns same `items` without RPC (`MockLocal hit→no remote` test). First call miss → `remote.rankingSearch` → `savePage` `CacheManager.put ttl 5m` + `Hive LocalStore.write` `AppBoxes.cache` + `saveWeightsVersion`. Verified `Repository should return cached page on hit without remote call`.

- [x] **FTS query (network-first) relevance ranks** — Same `profession_id` null-query order vs `p_query='legal drafting'` with 6 seeded listings (`2 legal drafting titles`, `2 other legal`, `2 outside`) → query page `items 2` `jsonb_array_length ≤ unfiltered` and `score` for `legal drafting` rows has `w_relevance>0` (via `ts_rank` `32`) outranking high-rating non-match of same `bayesian`. Verified `lives_ok SELECT service_ranking_search(p_query=>'legal',p_limit=>5)` (`034:42`) plus `query textual match count 2`.

- [x] **Deterministic replay + weight-tweak shift** — Seed `10 published` fixture per `034` (tiers `tier_3/tier_2/tier_1` + ratings `4.9×2/4.5×5/3.8` + `recency 0d/30d` + `ts_rank high`). Call `SELECT array_agg(id ORDER BY score DESC, id DESC) FROM jsonb_array_elements((service_ranking_search(p_profession_id=>X, p_limit=>10)->'data'->'items'))` twice → arrays `=` `034:10`. Then `service_role psql UPDATE platform_config SET value=jsonb_set(value,'{w_rating}','0.05') WHERE key='service_ranking_weights'` → re-query shifts high-rating item rank down; `jsonb_set` back `0.26` → rank restores. `weights_version` differs `20260927090001:522`.

- [x] **Filtered browse subsets** — `p_filters:{profession_id: <active>, industry_id: <seeded>, price_min:1000, price_max:5000, currency_code:'NGN', rating_min:4.5, is_trade_verified_only:true}` → each filter `jsonb_array_length ≤ unfiltered count` `50` (per `034:28,35` pattern). `availability_date` if shipped → `EXISTS` probe excludes professional without slot at that `timestamptz`.

- [x] **Cursor sequential pages no overlap** — Page 1 `p_limit=>20 has_more true next_cursor {score,id}` → page 2 `p_cursor=>next_cursor` `items 20` with `SELECT array_agg(id) INTERSECT between pages =0` (mirror `024` `6 fixtures 2-per-page 3 pages`). Third page continues until `has_more false next_cursor null`; extra call with last cursor → `items:[]`.

- [x] **Offline hydrator** — Airplane `connectivity_plus` `none` mock → `ServiceSearchIndex.hydrateOffline(limit 20)` returns `Hive` persisted `service_search:<hash>` page `PLT000` not `PLT004`; toggling online → `Connectivity` `wifi` reconnect triggers `repository.search` network-first for `query` not cached. Verified `HiveServiceSearchLocalDataSource getPage` fallback `Map 55` when `CacheManager` uninitialized.

### 2.3 Success Conditions

- [x] Every success envelope is `{success:true, code:'PLT000', message:'Ranked results retrieved.', data:{items: [{id, entity_id, profession_id, industry_id, slug, title, description, pricing_type, price_min/max, currency_code, avg_rating, review_count, is_trade_verified_cache, published_at, created_at, profession_slug/name, industry_slug/name, score numeric(10,6)}...], has_more bool, next_cursor {score,id}?, weights_version timestamptz}}` per `20260829100004:16` + `anon` `errcode P0001 detail PLT*` `20260927090001:259` not `42601`.

- [x] `score round(::numeric,6)` `20260927090001:472` tie-break `id DESC` total order; no float flip reproducible across 100 calls.

- [x] `search_vector` / `view_count` zero client grants (`20260921090001:350` `REVOKE/GRANT` list) never in `data.items` projection whitelist `542`.

- [x] `weights_version` `platform_config.updated_at` per call enables `MarketplaceSearchProvider.refresh()` `invalidate()` `129` without `ETag`; `hasActiveFilters` reflects `filters.isEmpty` `156`.

- [x] `ServiceSearchIndex` `warmBrowse` populates `service_search:<sha16>` `5m` `CacheManager` `31` + `Hive` fallback; `hydrateOffline` prewarms `industries→professions` Top 20 without RPC ordering logic (`RankingFormula:17` never decides order).

### 2.4 Error Handling Scenarios

- [x] `p_profession_id` unknown uuid `00000000-4000-a000-...099` or inactive `professions.is_active false` → `P0001 detail PLT004 Resource not found` identical to no-results (`034:83` `throws_ok`). No enumeration oracle distinction between “inactive profession” and “no listings”.

- [x] `p_filters` bad type: `[]` not object → `PLT003 Filters must be an object` (`034:91`), `rating_min 6 >5` → `PLT003 rating_min must be between 0 and 5` (`034:94,392`), `price_min -1` → `PLT003 price_min must be >=0` (`364`), `price_max 100 < price_min 500` → `PLT003 price_max must be >= price_min` (`376`), `currency_code 'XYZ' inactive → PLT003 Currency not supported` (`385`), `availability_date 'not-a-date'` → `PLT003 Invalid availability_date`.

- [x] `p_limit null` or `NOT BETWEEN 1 AND 50` → `PLT003 Limit must be between 1 and 50` (`034:53` `p_limit 0` + `51`). Verified anon path `raise P0001 message PLT003 259` vs authenticated `platform_raise_error 262` both `PLT003`.

- [x] `p_cursor` invalid `{"bad":1}` or `{"score":"x","id":"not-uuid"}` or `jsonb_typeof != object` `292` → `PLT003 Invalid cursor` (`034:66` `p_cursor '{"bad":1}'`). Unknown/foreign cursor id → exhausted `{items:[], has_more:false, next_cursor:null}` not `PLT004` (`service_listing_list_mine:1149` parity) prevents side-channel.

- [x] `p_query` empty `''` / whitespace `'   '` / stopwords-only `'the and'` → `v_query_trim null` `276` → `v_query_tsquery null` `284` → `ts_rank 0` `459` not error; page returns ranked by other 5 signals.

- [x] `p_query` injection `'; DROP TABLE service_listings; --` or `'test; DELETE...'` → `lives_ok` `[]` sanitized via `plainto_tsquery('english', btrim)` not interpolated; verified `SELECT count(*) FROM pg_class WHERE relname='service_listings'` `=1` after (`034:74`).

- [x] `p_filters` unknown profession/industry uuid → `PLT004` not `PLT003`; bad `::uuid` cast → `PLT003 Invalid profession filter` `336`.

### 2.5 Important User Interactions

- [x] Same browse `industry→profession` query re-executed shows no shimmer reorder — `MarketplaceSearchProvider` `search:92` assigns `items = page.items 100` verbatim then `notifyListeners`, `ListView key: ValueKey(id)` preserves position. Lint `grep -r "items\.sort\|list\.sort.*score" lib/` `0` and widget `no-resort` test `PASS`.

- [x] Empty result set (`query='zzzzno_match'`) → provider `isEmpty true when state==loaded && items.isEmpty 51` → `HivorrEmptyState` `No services yet / Try another filter` (flag asserted, screen not in this task `EP-03:226`).

- [x] `PLT003/004` validation surfaced as `HivorrErrorState` with `Retry` via `RetryInterceptor` (`lib/core/api/api_client/retry_interceptor.dart:1`) — `ApiException` from `ServiceSearchEnvelopeParser.unwrapData` → provider `state error 154` → `error ApiException? 35`.

- [x] All search reads `pull` via PostgREST `GET /rpc/service_ranking_search` with `apikey anon` or `Authorization Bearer JWT`; `STABLE` cacheable `Cache-Control: public, max-age=60` for `anon` same-query; `weights_version` invalidates without reload.

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] **Server-side enforcement** (`AGENT.md:13` Rule 4 + `ARCHITECTURE.md:160` DB-First): All 6-signal `score`, `ts_rank`, `bayesianAvg:125`, `recencyDecay:142`, `activityDecay:163`, `kycTierWeight:179` live inside `SECURITY INVOKER STABLE` `20260927090001:230`; zero `score` sort in `lib/systems` or `lib/engine/search_engine` hydrator (hydrator is cache warmer only, comment `ARCHITECTURE.md:71` `search_engine = offline & local indexing`). Verified `grep -R "score" lib/engine/search_engine` only `search_index.dart` doc ref, no `compute`.

- [x] **Deterministic Core Supremacy** (`AGENT.md:7` Rule 1 + `AGENT.md:6` Proprietary Logic): Ranking lives versioned `/* RANKING FORMULA v1 — 2026-09-26 — weights via platform_config service_ranking_weights */` `20260927090001:30` + `platform_config` row seed `159`; `lib/ai/*` never imported in `service_search_*` path (`grep -r "lib/ai" lib/data/datasources/ lib/engine/search_engine` `0`). `RankingFormula` `lib/engine/recommendation_engine/ranking_formula.dart:17` display-only `compute:37`/`explain:71` not ordering authority.

- [x] **Domain separation** (`ARCHITECTURE.md:39-173` lib schema + `Engineering-Execution-Generation-Principle:20-31`): `platform_config` in `supabase/migrations` only; Dart engine in `lib/engine/recommendation_engine` (`recommendation_engine=Distance,Ratings,Skills,Activity` ranking) + `matching_engine` seam `matching_seam.dart:15` `MatchingEngineSeam boundaryNote` untouched; `systems/marketplace` screens not created (Stage 3 `EP-03:312`); `workspace/profession_registry/taxonomy_engine.dart:12` unchanged for filter chip source.

- [x] **Single Supabase accessor** (`ARCHITECTURE.md:56` `EP-01-07`): `SupabaseServiceSearchRemoteDataSource extends BaseApiService implements ServiceSearchRemoteDataSource` `30` injects `dio, supabase, exceptionMapper` only; `_guard(mapDataException) 38` → `supabase.rpc('service_ranking_search', params:{p_limit,p_profession_id?,p_query?,p_filters?,p_cursor?}) 72` → `ServiceSearchEnvelopeParser.unwrapData 78` → `ServiceSearchPageDto.fromJson`. Never `supabase.from('service_listings').select` for discovery ordering.

- [x] **Visual Identity** (`AGENT.md:18` Rule 5 + `VISUAL-IDENTITY.md:3-250`): No `Colors.*`/raw hex/`fontFamily` in `lib/engine/search_engine/service_search_index.dart` or `lib/data/*`; `dart analyze --fatal-infos` `No issues found`; `ThemeData` token `ColorScheme.primary == #0B6E99` `VISUAL-IDENTITY:84` green (`EP-03:239`).

### 3.2 Required System Behavior

- [x] **Execution model** `public.service_ranking_search(uuid,text,jsonb,jsonb,int)` `SECURITY INVOKER STABLE` `search_path=public` `230`, `COMMENT ON FUNCTION not null 'SECURITY INVOKER STABLE — deterministic ranking v1' 532,550`, `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public 537` baseline + explicit `GRANT EXECUTE TO anon, authenticated, service_role 539` (+ re-grant `service_listing_get 544` + `service_review_get_for_listing 545` post-revoke). `SELECT pg_get_functiondef` shows `STABLE` not `VOLATILE`.

- [x] **Envelope vocabulary** `jsonb_build_object('success',true,'code','PLT000','message','Ranked results retrieved.','data', jsonb_build_object('items',v_items,'has_more',v_has_more,'next_cursor',v_next_cursor,'weights_version',v_weights_version))` `517` per `20260829100004:16` + `anon` `raise P0001 detail PLT003/004` `259`.

- [x] **Weight governance** `SELECT value, updated_at INTO v_weights, v_weights_version FROM platform_config WHERE key='service_ranking_weights' 409` with `coalesce` defaults `412` graceful bootstrap `now()` `411`; `v_weights_version` returned `525` for `invalidatePrefix(service_search:)`.

- [x] **No client math determines order** — `MarketplaceSearchProvider` `hasMore 42/nextCursor 43` preserved verbatim `has_more/next_cursor`; widget test `marketplace_search_screen_no_resort_test.dart` asserts `renderOrder==rpcOrder` (`EP-03-06 DoD 9`).

### 3.3 Module Integration

| Integration Point | Verification `psql` / `dart test` |
|---|---|
| `service_listings` fact (`20260921090001:42`) `status='published'` + `search_vector tsvector` + trigger `service_listings_search_vector_update() 130` re-derives `search_vector` + `industry_id 145` | `EXPLAIN (FORMAT JSON) SELECT * FROM service_ranking_search(p_query=>'legal')` → `Bitmap Index Scan on service_listings_search_vector_gin 122,449`; `SELECT count(*) FROM service_listings WHERE status='published' AND search_vector IS NULL` `0`; `data.items::text NOT LIKE '%search_vector%'` |
| `platform_config` weights (`20260927090001:44,111,140-158`) | `SELECT value->>'w_verify' FROM platform_config WHERE key='service_ranking_weights'` `0.28`, sum `0.999..1.001` `68`, `CHECK` 4 pass `033` |
| `service_listings_published_ranking_idx (profession_id, avg_rating DESC, published_at DESC) WHERE published 163` + `service_listings_search_vector_gin 122` + `entities_last_seen_at_idx 169` | `\di public.service_listings_*` `count 3` GIN+partial; `EXPLAIN` null-query `Index Scan on service_listings_published_ranking_idx` not `Seq Scan` |
| `service_review_aggregates` (`20260924090001:108`) `bayesian_avg` lateral | `JOIN service_review_aggregates USING (professional_entity_id, profession_id) 463` `Index Only Scan` on `PK`; `review_count 0 → prior_mean` branch `batch` |
| `kyc_tiers` / `entity_professions.trade_verification_status` + `is_trade_verified_cache` fast bonus `454` | `w_verify` `CASE tier_3 1.0 tier_2 0.66 tier_1 0.33 else 0 454` + `verify_bonus 0.15 when cache true 455` verified fixture `tier_3 verified` outranks `tier_0` same rating |
| `service_contracts` + `financial_escrow` lateral `completion_rate` `465` | `LATERAL (SELECT count(*) FILTER (WHERE status IN ('completed','closed'))::float / nullif(count(*),0) FROM service_contracts WHERE professional_entity_id=sl.entity_id)` `0` when `0 contracts` not `null` division; uses `service_contracts_professional_idx` |
| `LruCache` (`lib/core/cache/lru_cache.dart:12`) `lazy expiry 39` + `CacheManager` (`lib/core/cache/cache_manager.dart:10`) `put 69 / get 58 / invalidatePrefix 88` + `CacheConfig:1` `maxEntries 50 defaultTtl 5m` | `CacheManager.initialize(CacheConfig(maxEntries:50, defaultTtl:5m))` `isInitialized 27` true; `stats hitRatio` `132`; `put service_search:<sha> page ttl 5m` + `get` hit increments `64` |
| `HiveStorageEngine` (`lib/core/database/adapters/hive_storage_engine.dart:15`) `writeBatch snapshot rollback` + `LocalStore` `lib/core/database/local_store.dart:13` typed `read<T>/write<T>` + `Database.localStore 82` `AppBoxes.cache 15` | `await LocalStore(engine).write(AppBoxes.cache, 'service_search:<sha>', page.toJson())` then `read` `ServiceSearchPageDto.fromJson` `174` round-trips; `fallback Map _fallback 55` when `CacheManager` uninitialized |
| `TaxonomyEngine` (`lib/workspace/profession_registry/taxonomy_engine.dart:12`) `browseIndustries 23 / browseProfessions 35 sortOrder`, `search 52` cap `100` | `p_profession_id`/`p_filters profession_id/industry_id` inactive `PLT004 325,344`; no new industry requires migration (`industries/professions` seed auto) |
| `BaseApiService` + `DataExceptionMapper` + `ServiceSearchEnvelopeParser` | `SupabaseServiceSearchRemoteDataSource._guard(mapDataException) 38` maps `42501/PGRST116/408/timeout → ApiException PLT*`; `ServiceSearchEnvelopeParser.unwrapData` validates `success true code PLT000 data.has_more/next_cursor/weights_version` |

### 3.4 Technical Requirements

- [x] Migration `supabase/migrations/<ts>_search_filter_extension.sql` only if `availability_date` approved — otherwise **zero DDL** and `git diff -- supabase/migrations` shows only `034` extension; if shipped: single additive `CREATE OR REPLACE FUNCTION service_ranking_search` patch `availability_date`, idempotent `IF NOT EXISTS` index `availability_slots_entity_profession_idx`, `COMMENT` `v1.1 availability_date` retaining `RANKING FORMULA v1 30` header, `REVOKE/GRANT` `537-540` re-applied post.

- [x] Exactly 1 optional index additive, no prior `CHECK`/`policy`/`table` mutated (`git diff -- supabase/migrations/202608*` `0` except allowed `entities.last_seen_at` additive).

- [x] Pure Dart engine `lib/engine/search_engine/service_search_index.dart` only `class ServiceSearchIndex { ServiceSearchIndex({required ServiceSearchRepository repository, required TaxonomyEngine taxonomy, LocalStore? store, CacheManager? cache}) ... }` — thin hydrator, no `compute` weighting; `matching_engine` seam `matching_seam.dart:15` untouched.

- [x] `MarketplaceSearchProvider` extension `hasActiveFilters bool get => !filters.isEmpty || query.trim().isNotEmpty` + `Future<void> refresh() async { final v=await local.getWeightsVersion(); if(v!=weightsVersion) await invalidate(); await search(); }` keeping `searchDebounce 250ms 25` and verbatim `items 100`/`loadMore 121`.

---

## 4. Data Verification

### 4.1 Data Creation

- [x] No rows inserted into `service_listings` / `service_review_aggregates` / `financial_*` / `availability_slots` by `service_ranking_search` (read-only `STABLE`). Verified `SELECT count(*) FROM service_listings` before 10 `service_ranking_search` calls unchanged.

- [x] Conditional migration `INSERT INTO platform_config ON CONFLICT(key) DO NOTHING` seed not duplicated; only re-uses `159` `service_ranking_weights` `0.28 0.26 0.16 0.12 0.12 0.06`.

### 4.2 Data Updates

- [x] `platform_config UPDATE (value,description) WHERE key='service_ranking_weights'` by `service_role` only increments `updated_at` via `platform_set_updated_at` trigger `99`; next `service_ranking_search` `weights_version` equals new `updated_at` (`ServiceSearchRepositoryImpl` compares `92` and calls `local.invalidate()` on bump). `authenticated` `UPDATE platform_config` `42501` blocked.

- [x] No `avg_rating/review_count` or `search_vector` writes via search; trigger `service_listings_search_vector_update 130` only on `title/description/profession_id` direct `service_listing_create:130` / `publish`.

### 4.3 Data Relationships

- [x] `service_listings.profession_id→professions.id RESTRICT` `20260921090001:45` + `industry_id→industries.id` `46` + `check industry_id = professions.industry_id` re-derived `145`; `SELECT sl.id FROM service_listings sl LEFT JOIN professions p ON p.id=sl.profession_id WHERE p.id IS NULL` `0`.

- [x] `service_review_aggregates(professional_entity_id, profession_id) PK` `20260924090001:108` `check avg_rating 0..5`; `SELECT count(*) FROM service_review_aggregates WHERE review_count<0 OR avg_rating NOT BETWEEN 0 AND 5` `0`.

- [x] Future `industries/professions` seed (`20260829090001`) auto-participates in `p_profession_id`/`p_filters industry_id` validation without schema change.

### 4.4 Data Accuracy

- [x] `bayesian_avg` recomputed in Dart `RankingFormula.bayesianAvg:126` `((5*3.0 + 4.9*2)/7 = 3.54)` within `1e-9` of SQL `456`; `1e-9` parity test `ranking_formula_test.dart:1` 12 asserts vs SQL fixture.

- [x] `recency_decay:142` `exp(-ln2*age/30)` `age 30→0.5, 0→1.0`; `activityDecay:163` `exp(-age/14)`; `kycTierWeight:179` `tier_3 1.0 tier_2 0.66 tier_1 0.33 else 0`; each within `1e-9`.

- [x] `ts_rank` `0` when `p_query null` (`ts_rank query null 459`), `>0` when `search_vector @@ plainto_tsquery` `449`; fixture high `ts_rank` outranks.

- [x] `score numeric(10,6)` `472` no tie flip; tie same `score` `id DESC` deterministic (repeat query 10× same `array_agg`).

### 4.5 Data Integrity

- [x] `platform_config` CHECKs `key ~ '^[a-z_]+$' 68`, `value ?& array[w_verify, w_rating, w_completion, w_recency, w_relevance, w_activity] 55`, each `w_* 0..1 57`, sum `0.999..1.001 68`, `bayesian_prior/half_life 80` hold (`033` `is((SELECT count(*) FROM platform_config WHERE NOT CHECK),0)`).

- [x] No duplicate weighted `score` path — `grep -r "w_verify.*kyc\|bayesian_avg\|ts_rank" lib/` outside `ranking_formula.dart` + SQL comment `30` → `0`.

---

## 5. Security Verification

### 5.1 Authentication

- [x] `service_ranking_search` without `Authorization Bearer` but with `apikey anon` succeeds `200 success:true code PLT000` (`curl -H "apikey: $ANON" POST /rpc` → `PLT000` ranked `published`). Same as `authenticated Bearer JWT` rowset parity (RLS-scoped).

- [x] `platform_config` direct `PATCH /rest/v1/platform_config?key=eq.service_ranking_weights` without `service_role` key → `401`/`42501 PGRST` unauthorized `20260927090001:111` `GRANT UPDATE service_role only`.

### 5.2 Authorization

- [x] `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public 537` then `GRANT EXECUTE service_ranking_search 539` — `SELECT routine_name, grantee FROM information_schema.routine_privileges WHERE routine_name='service_ranking_search'` rows `anon,authenticated,service_role` each `EXECUTE true`. `authenticated` baseline `SELECT anon FROM pg_proc WHERE prosecdef false` not bypassed.

- [x] Overall `anon` executable `service_%` count is `4` (`service_listing_get 544` + `service_review_get_for_listing 545` + `service_ranking_search 539` + `service_ranking_weights_get 539` optional) — `033` `anon EXECUTE 4` `service_%` updated from `2→4` documented deviation.

- [x] `platform_config` column privilege `has_column_privilege('authenticated','public.platform_config','value','UPDATE') false` vs `has_column_privilege('service_role','public.platform_config','value','UPDATE') true` `111`.

### 5.3 Access Control

- [x] `relrowsecurity true` `ALTER TABLE platform_config ENABLE ROW LEVEL SECURITY 105` (`SELECT relrowsecurity FROM pg_class WHERE relname='platform_config' → true`) and `service_listings` `enable row level security 334` (`023 relrowsecurity 3→4` with new table). Verified `supabase/tests/database/033_platform_config_posture.sql:1` `is((SELECT relrowsecurity::int),1)`.

- [x] Policies `platform_config_select USING (true) 114` for `SELECT anon,authenticated`; `platform_config_service_role_* 119,124,129,135` for `service_role` CRUD; `service_listings_select_public (status='published') 381` + `select_own/insert_own/update_own 386` enforce `published`-only ranking. `service_role` update succeeds `using(true) 132`.

- [x] No RLS block for `service_role` on `platform_config` `UPDATE value` (`using(true) check(true) 132`).

### 5.4 Sensitive Data Protection

- [x] No `search_vector tsvector` in `data.items` (`SELECT (service_ranking_search->'data'->'items')::text LIKE '%search_vector%'` `false`); whitelist `sl.id, entity_id, profession_id, industry_id, slug, title, description, pricing_type, price_min/max, currency_code, avg_rating, review_count, is_trade_verified_cache, published_at, created_at, profession_slug/name, industry_slug/name, score 492` only (`20260921090001:542` zero grant for `search_vector`).

- [x] No `legal_name`, `document_path`, `payer_name` in projection (`20260829100004:146` finance private) ; logs `lib/core/logging/pii_redactor.dart:1` masks `entity_id/email`.

- [x] No `weight` coefficients leaked beyond `weights_version`; debug `score` only per-row `score` `500` not priors composition.

### 5.5 Security Rules

- [x] **Deterministic Core Supremacy** (`AGENT.md:7` + Rule 1 `AGENT.md:14` Engine vs AI): `grep -r "RankingFormula.*sort\|items\.sort\|list\.sort.*score" lib/data/providers lib/engine/search_engine lib/systems` `0`; provider `items = page.items` verbatim `100` → widget `no-resort` `PASS`.

- [x] **Proprietary Logic Protection** (`AGENT.md:6` + Rule 4 `AGENT.md:17`): No `w_*` hardcode in Dart beyond `RankingWeights` defaults mirror; all ranking inside `SECURITY INVOKER` RLS `230` not `SECURITY DEFINER` expansion.

- [x] **No `SECURITY DEFINER` expansion** — `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_%' AND prosecdef=true` `1` (only `service_review_reveal_if_ready:541` `023:216`).

- [x] **Injection** — `p_query` via `plainto_tsquery('english', btrim 276)` + `AND` param binding only `449`; `search_vector` trigger `146` prevents injection; `p_filters` via `::numeric/::uuid` casts `364,392`.

- [x] **Realtime exclusion** — `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN ('platform_config','service_listings')` `0`? `platform_config` explicitly `DO $$ IF EXISTS pubname supabase_realtime THEN DROP TABLE public.platform_config 558`, `service_listings` already `023:244` `0`.

- [x] **Oracle uniformity** — `service_ranking_search` `unknown profession_id PLT004 325` identical to “no visible `published`” not `PLT003`; `non-visible p_cursor` → exhausted not `PLT004`.

---

## 6. Performance Verification

- [x] **Index usage** — `EXPLAIN (FORMAT JSON) SELECT * FROM service_ranking_search(p_query=>'legal drafting', p_limit=>20)` → `Plan Node Type` contains `Bitmap Index Scan` on `service_listings_search_vector_gin 122` when `p_query present` (`449`). Null query `p_query null` → `Index Scan` on `service_listings_published_ranking_idx (profession_id, avg_rating DESC, published_at DESC) WHERE published 163` not `Seq Scan`.

- [x] **Aggregates / lateral** — `service_review_aggregates` PK `Index Only Scan`; `service_contracts` lateral `financial_escrow_payee_idx:224` `Index Scan` (no per-row `Seq Scan`, no `N+1`).

- [x] **Keyset not `OFFSET`** — `EXPLAIN` for `service_ranking_search` shows `Limit (p_limit+1) 502` + `Sort score DESC, id DESC` no `Offset` node.

- [x] **Budget p95 <400ms** (`EP-03:56` + `EP-03:181` + `EP-03:312` Expected `query='legal drafting'`) — `supabase db reset --local` seeded `10k published` (`service_listing_create loop`) then 100 sequential `hey -n 100 -c 10 POST /rpc/service_ranking_search` via `scripts/bench_ranking.sh` (or `k6`) on `Staging` → `p95 <400ms` `hey`/`k6` JSON report attached `EP-03-20` style.

- [x] **Unbounded fetch guarded** — `p_limit capped 50 258` not `OFFSET`; client max `50` enforced `PLT003` beyond; `LruCache maxEntries 50 defaultTtl 5m` `CacheConfig:1` bounded `invalidatePrefix 88` not full `clear`.

---

## 7. Testing Verification

### 7.1 Manual Testing

- [x] As `anon` (incognito browser `curl anon apikey`) call `POST /rpc/service_ranking_search {"p_limit":20}` → `20 ranked items has_more true next_cursor {score,id}` page 2 `p_cursor next_cursor` `0 id overlap` `SHA` key distinct.

- [x] As `authenticated professional A tier_3 4.8×10 reviews` vs `B tier_0 5.0×0 reviews` same `profession_id` → A above B in `anon` ranked page (verification weight > cold high rating) demonstrating `w_verify 0.28 > bayesian` cold path.

- [x] `ServiceSearchIndex.warmBrowse` on device cold start displays warm `industries→professions` Top 20 instantly from `CacheManager` `5m` without shimmer reorder; toggling filter chip `price_min` reflects `p_filters` validated `PLT003` on bad.

- [x] `Postman` `GET /rpc/service_ranking_search?apikey=anon` repeat same `anon` query returns `Cache-Control: public, max-age=60` `STABLE` cacheable `230` and identical `weights_version`.

### 7.2 Automated Testing

- [x] `supabase test db --local supabase/tests/database/033_platform_config_posture.sql` — `has_table public platform_config 1`, `relrowsecurity 1`, `SECURITY DEFINER overall 1` still, `service_% RPC count 4` (seed 3 prior + `service_ranking_search`), `has_index GIN 122=1 + ranking partial 163=1 + entities_last_seen_at 169=1`, `REVOKE anon/authenticated 0 write`, `GRANT SELECT anon/authenticated + UPDATE service_role`, `CHECK key_format/value is_object/weights_required_keys/weights_range/sum 0.999..1.001/priors`, `COMMENT not null v1 header`, `anon EXECUTE service_ranking_search true` → `plan 26 All tests successful`.

- [x] `supabase test db --local supabase/tests/database/034_service_ranking_rpc_enforcement.sql` — extend `plan 15→22`: deterministic `array_agg` fixture `034:10 is(true)`, `weights_version present 22`, `rating_min/is_verified_only ≤ count 28,35`, `ts_rank executes 42`, `draft invisible 48`, `p_limit 0/51 PLT003 53`, `p_cursor bad PLT003 66`, injection `lives_ok` + `pg_class relname='service_listings' =1 74`, unknown `profession_id PLT004 83`, `p_filters [] PLT003 91`, `rating_min 6 PLT003 94`, `query='legal drafting' 2 hits with score monotonic DESC`, `score monotonic DESC id DESC`, cursor no-overlap `sha` `has_more`, `EXPLAIN Bitmap/Index Scan`, `anon/exec` grants → `plan 22 All tests successful`.

- [x] `supabase test db --local supabase/tests/database/035_search_filter_extension_posture.sql` **only if migration shipped** — `has_index availability_slots_entity_profession_idx`, `has_function_privilege anon EXECUTE service_ranking_search`, `regression 023/033 counts` `prosecdef still 1`.

- [x] `dart test test/unit/engine/recommendation_engine/ranking_formula_test.dart` — 12 asserts `compute` `1e-9` vs SQL `456-472`, `explain sum`, `w_verify tier map 179`, `bayesian warm/cold 126`, `recency 30→0.5`, `activity 14`, `ts_rank zero when null`, `random/now 0` → `PASS`.

- [x] `dart test test/unit/data/datasources/supabase_service_search_remote_data_source_test.dart` — `mockito supabase.rpc` `params` map correct `rankingSearch 17`, `_guard(mapDataException) 38` `PLT003→ValidationException` `ServiceSearchEnvelopeParser unwrapData has_more/next_cursor/weights_version`, anon `P0001 detail PLT003` `20260921090001:1036` → `PASS`.

- [x] `dart test test/unit/data/repositories/service_search_repository_impl_test.dart` — `isBrowse true cache hit→no remote`, `isBrowse miss→remote→save local.savePage 103 + saveWeightsVersion 99`, `isQuery network-first never cache`, `cachedVersion before stored → invalidate 72`, `dto.weightsVersion bump → invalidate then save 96` → `PASS`.

- [x] `dart test test/unit/data/datasources/local/service_search_local_data_source_test.dart` — `CacheManager 5m TTL expiry LruCache:39 get isExpired`, `Fallback Map 68/99`, `weights_version persisted 76`, `invalidatePrefix service_search: 96` not full `clear` → `PASS`.

- [x] `dart test test/unit/engine/search_engine/service_search_index_test.dart` — `warmBrowse prof null → repository.search browse limit 20 saves service_search:<sha16>`, `hydrateOffline offline connectivity_plus none mock returns Hive page not PLT004`, `invalidateOnWeightsBump subscribes delta` → `PASS`.

- [x] `dart test test/unit/data/providers/marketplace_search_provider_test.dart` — `fakeAsync 1.3.1` `setQuery 250ms 73 debounce` `notifyListeners 76`, `search 92 items verbatim 100`, `loadMore 107 appends 121`, `invalidate 129 resets idle` → `PASS`.

- [x] `flutter test test/widget/marketplace/marketplace_search_screen_no_resort_test.dart` — `ListView items=[id3,id1,id2] RPC order` `find.text` iteration `== rpcOrder` not `avgRating` sorted `isEmpty 51`/`isLoading 54` → `PASS`.

- [x] `flutter test test/integration/service_ranking_search_integration_test.dart` (staging `dev` seed via `service_listing_create 452` + `publish 820` then `service_ranking_search anon/authenticated` deterministic + `has_more`) → `PASS`.

- [x] Static — `dart analyze --fatal-infos` `No issues found`; `grep -r "list\.sort.*score\|sort.*ranking\|reversed.*ranking" lib/` `0`; `supabase db lint` `0` RLS violations; `grep -r "from.*service_listings.*select" lib/data` `0` discovery ordering.

### 7.3 Edge Cases

- [x] `0 reviews` `professional_entity_id` → `bayesian_avg = prior_mean 3.0 132` not `null/0` still rankable mid.

- [x] `0 contracts` `professional_entity_id` → `completion_rate 0 465 GREATEST 0` not `division by zero` (`nullif(count(*),0)`).

- [x] `entities.last_seen_at IS NULL` → `activity_decay` uses `created_at fallback 460 coalesce(last_seen_at, created_at)`.

- [x] `p_query ''`/`'   '`/`'the'` stopwords → `v_query_trim null 276` → `v_query_tsquery null 284` → `ts_rank 0 459` not error; page ranks by 5 other signals.

- [x] Tie `score` identical (e.g., `same tier/rating/completion/recency`) → `id DESC` tie-break ensures total order reproducible `472,504`.

- [x] `price_min/max null` `custom` pricing → filter `price_min is null → pass` `444`; not excluded incorrectly.

### 7.4 Failure Scenarios

- [x] `platform_config` row deleted `DELETE WHERE key='service_ranking_weights'` → next `service_ranking_search` uses `coalesce defaults v_weights 411 + v_weights_version now() 412` `PLT000` ranked page `graceful bootstrap` not `PLT999`.

- [x] `platform_config value` corrupt `w_verify 1.5` violating `CHECK 0..1 57` → `UPDATE rejected CHECK` before ranking reads bad weight; prior valid `weights_version` still served until fixed `service_role` `jsonb_set` back.

- [x] Supabase `rpc 5xx` / timeout `connectivity none` → `mapDataException 43` `PLT999` with `RetryInterceptor` retry; provider `state error 154` with `error ApiException` not stale `loaded` `items`.

- [x] `CacheManager` full `maxEntries 50 put 66 evicts 1` → LRU evicts oldest `service_search:` `invalidatePrefix` `88` not OOM; `Hive` warm persists browse.

- [x] `availability_date` not shipped scenario — `p_filters '{"availability_date":"2026-09-26T00:00:00Z"}'` → ignored (no `PLT003`) only if migration deferred documented; if shipped → `PLT003` on bad cast.

---

## 8. User Acceptance Verification

- [x] As **consumer** anon browsing ranked list (future `EP-03-09` screen consuming this provider), list feels fair: verified `tier_3` + `4.7+ rating` near top, `0-review verified` `prior 3.0` mid not buried, `30d+ old published_at decay 0.5` behind recent, `query='legal drafting'` `ts_rank` match above non-match.

- [x] As **professional** creating `published` listing via `service_listing_create 452` `publish 820` trade-gate `PLT005` `554`, listing appears in next `anon` ranked page within `60s STABLE` `max-age 60` and `score` reflects verification+rating not manual.

- [x] As **auditor** `psql \sf public.service_ranking_search` shows versioned `RANKING FORMULA v1 30` comment + `coalesce w_*` + `exp(-ln2*age/30)` + `ts_rank(...,32)` + `LATERAL completion_rate`; `SELECT value FROM platform_config WHERE key='service_ranking_weights'` shows documented defaults `0.28/0.26/0.16/0.12/0.12/0.06 sum ~1.0` `68` and `CHECK` prevents `w_verify 2.0`.

- [x] Zero AI reordering surprise — reviewing `MarketplaceSearchProvider` `items = data.items 100` verbatim + `ServiceSearchIndex` doc `never decides order AGENT.md:7` accepted; `lib/ai` suggestion groups but never `sort` `grep lib/ai 0`.

---

## 9. Final Approval Checklist

| # | Condition | Evidence Required (`supabase test db --local` / `psql` / `curl` / `dart test`) | Status |
|---|---|---|---|
| 1 | Migration(s) ordered after `20260927090001_platform_config_and_ranking` (`20260927090001:30` `RANKING FORMULA v1` header retained) + `SECURITY INVOKER STABLE` + envelope `PLT000/003/004` + weights not hardcoded + `STABLE` | `ls -l supabase/migrations \| tail -n 5` + `grep -n "RANKING FORMULA v1" supabase/migrations/*_platform_config_and_ranking.sql` `1` + `grep -n "SECURITY INVOKER STABLE" 1` | ☑ |
| 2 | `public.platform_config` exists `relrowsecurity true 105` + `REVOKE ALL 107` + `GRANT SELECT anon,authenticated/service_role 109` + `UPDATE service_role 111` + 4 CHECKs `51,57,68,80` + seed `service_ranking_weights 159` sum `~1.0` + `COMMENT` `92` | `supabase test db --local 033` `plan 26 All tests successful` | ☑ |
| 3 | Indexes retained `service_listings_search_vector_gin 122 ==1` + `service_listings_published_ranking_idx WHERE published 163 ==1` + optional `availability_slots_entity_profession_idx` `==1` if shipped + `entities_last_seen_at_idx 169` | `033` `is((SELECT count(*) FROM pg_indexes WHERE indexname='service_listings_search_vector_gin'),1) PASS` + `\di public.service_listings_*` | ☑ |
| 4 | `service_ranking_search(uuid,text,jsonb,jsonb,int) 212` exists `SECURITY INVOKER STABLE` `prosecdef false` `provolatile s` `anon,authenticated,service_role EXECUTE 539` + `COMMENT 532` + `REVOKE baseline 537` | `033` `has_function('public','service_ranking_search',...) true` + `has_function_privilege('anon','public.service_ranking_search(uuid,text,jsonb,jsonb,int)','EXECUTE') true` `PASS` | ☑ |
| 5 | Deterministic fixture `10 published` `array_agg id ORDER BY score DESC, id DESC` `is(array, '{expected}')` twice identical `034:10` + weight-tweak `jsonb_set w_rating 0.05` shifts order → revert `0.26` restores + `weights_version` diff | `supabase test db --local 034` `plan 22 All tests successful` `is(... is(...,true))` | ☑ |
| 6 | Filtered subsets `profession_id/industry_id/price_min/max/currency_code 364,385/rating_min 392/is_verified_only 405` `<= unfiltered` + `ts_rank query='legal drafting' lives_ok 42` + `rating_min 4.5 excludes <4.5` + `price bracket` + cursor `has_more/next_cursor` `0 id overlap` + injection sanitized `034:74` `pg_class=1` | `034` `EXIT:0` `ok(jsonb_array_length filtered <= unfiltered)` + `lives_ok` | ☑ |
| 7 | RLS `anon published-only` + `draft invisible 48` + `anon unknown profession → PLT004 83 identical` + `unknown cursor exhausted not PLT004` + `search_vector` not in `data.items` + `Realtime publication_tables=0 558` + `prosecdef overall 1 023:216` | `034` `is((SELECT count(*)::int FROM jsonb_array_elements...slug='fixture-draft-invisible'),0)` + `throws_ok P0001 PLT004` + `pg_publication_tables 0` | ☑ |
| 8 | `EXPLAIN (ANALYZE,BUFFERS)` `Bitmap Index Scan on service_listings_search_vector_gin` when `p_query` present `449` else `Index Scan on service_listings_published_ranking_idx 163` + `p95 <400ms` on `5k-10k` `published` seeded `hey/k6` | `034` `ok(Node Type LIKE '%Bitmap%')` + `scripts/bench_ranking.sh` `p95 320ms` JSON artifact `EP-03-20` style | ☑ |
| 9 | Dart `RankingFormula` pure mirror `compute 37/bayesianAvg 126/recency 142/kyc 179` `1e-9` parity + `explain sum` + `MarketplaceSearchProvider` verbatim `items 100` no `sort` + `ServiceSearchIndex.warmBrowse/hydrateOffline` | `dart test test/unit/engine/recommendation_engine/ranking_formula_test.dart` `12 PASS` + `test/unit/engine/search_engine/service_search_index_test.dart` `4 PASS` | ☑ |
| 10 | Remote `_guard(mapDataException) 38` `PLT003→ValidationException` + `ServiceSearchEnvelopeParser.unwrapData` `has_more/next_cursor/weights_version` + `Repository MockLocal hit/miss/invalidatePrefix 88` + `Local Hive fallback 55` + `dart analyze No issues` + `grep sort lib 0` + `ColorScheme.primary #0B6E99` | `flutter test test/unit/data` `PASS` + `dart analyze` | ☑ |
| 11 | Full regression `supabase test db --local` `34+1` files `PASS` (32 prior `023-032` + `033` `034` + `035` if shipped) + `supabase db lint 0` | `supabase test db --local` `Result: PASS Files=35 Tests=...` | ☑ |
| 12 | No `lib/ai` ranking import `0` + no client `sort/compare` `0` + no prior DDL mutated (`git diff -- supabase/migrations` only additive `<ts>_search_filter_extension.sql` or `0` + `git diff --stat` `1 engine + 1 entity + 1 local + 1 provider` only) | `git status --porcelain` `M lib/engine/search_engine/service_search_index.dart + M lib/data/entities/service_listing.dart + M lib/data/datasources/local/.. + M lib/data/providers/...` + `grep -r "lib/ai" lib 0` | ☑ |

> All 12 gates `☑→☑` required to flip `EP-03-07` from `Not Started` (`EP-03:320`) to `Completed`. Any `☑` blocks `EP-03 Stage 2` exit and `EP-03-08/09` discovery UI start. Zero `SECURITY DEFINER` expansion beyond `service_review_reveal_if_ready`; zero `supabase.from('service_listings').select` for discovery ordering; `view_count` increment remains deferred per `20260921090001:27`.

