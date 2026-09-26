# Task Implementation Plan — EP-03-06 Deterministic Ranking & Matching Engine

> **Status:** Planning Artifact Only — No Production Code | **Plan Mode:** Read-Only  
> **Phase:** EP-03 Stage 2 — Deterministic & Search Engines (must precede discovery UI)  
> **Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:301-309` + `documents/Context/AGENT.md:1-18` + `documents/Context/ARCHITECTURE.md:39-173`

---

## 1. Task Objective

Implement the server-authoritative, auditable deterministic ranking that orders all marketplace discovery results. Deliver:

* Versioned SQL formula in a single `SECURITY INVOKER` RPC `service_ranking_search(p_profession_id, p_query, p_filters jsonb, p_cursor jsonb)` — deterministic, explainable, covers 100% of discovery ordering per `ARCHITECTURE.md:158` / `AGENT.md:7`.
* `public.platform_config` table (service-role-writable weights, not hardcoded coefficients) — `key='service_ranking_weights'` → `{w_verify, w_rating, w_completion, w_recency, w_relevance, w_activity}` + Bayesian priors and decay constants.
* Pure-Dart mirror `lib/engine/recommendation_engine/ranking_formula.dart` for offline explainability only — **never decides order client-side**; `lib/engine/matching_engine` left as seam for EP-04 spatial routing.
* Data-layer vertical slice (`RemoteDataSource → Repository → Provider`) + `LruCache` window + pgTAP + unit/widget test coverage. Zero AI override path.

Formula (approved, `EP-03:305`):

```
score = w_verify * kyc_tier_weight
      + w_rating * bayesian_avg
      + w_completion * completion_rate
      + w_recency * decay(now() - published_at)
      + w_relevance * ts_rank
      + w_activity * login_recency
```

Weights read from `platform_config` per call; no constant in SQL/Dart except defaults for bootstrap.

## 2. Business Problem Being Solved

Marketplace fairness is a trust primitive (`VISION.md`, `EP-03:175 Risk — ranking perceived as opaque → catastrophic trust erosion`). EP-03 is first revenue-generating phase; unverifiable or AI-overridden ordering exposes regulatory and word-of-mouth risk. The engine must prove:

* Determinism — same inputs → same order, reproducible via seeded fixture.
* Auditability — versioned SQL + `platform_config` history, `EXPLAIN` shows index usage.
* Verifiable signals only — verification tier, aggregated ratings, completion rate, recency, FTS relevance, activity — never hidden coefficients or client manipulation (AGENT.md Rule 1, Rule 4).

Without EP-03-06, EP-03-07 search, EP-03-09 discovery, and EP-03-20 Go/No-Go (`p95 <400ms`) have no correct ordering primitive.

## 3. Scope

**In Scope:**

* Migration `supabase/migrations/*_platform_config_and_ranking.sql`:
  * Table `public.platform_config(key text PK, value jsonb not null, description text, created_at timestamptz, updated_at timestamptz)` + RLS + REVOKE + narrow GRANTS + trigger `platform_set_updated_at`.
  * Seed row `service_ranking_weights` with documented defaults + comment on formula version.
  * Helper `service_ranking_weights_get() STABLE` (optional, for Dart mirror bootstrap — read-only, `anon, authenticated, service_role`).
  * RPC `service_ranking_search(...) SECURITY INVOKER STABLE` — validates `p_profession_id` active, `p_query` sanitized to `to_tsquery`, `p_filters` JSON schema `{profession_id, industry_id, price_range, rating_min, is_trade_verified_only, currency_code}`, cursor `{score, id}` keyset, returns `{success, code, message, data:{items[], has_more, next_cursor, weights_version}}`. Filtering `status='published'` only (RLS-scoped), `is_trade_verified_cache` fast-path for `w_verify`, `avg_rating/review_count` via `service_review_aggregates` join, `bayesian_avg`, `decay`, `ts_rank`, `completion_rate`, `login_recency` computed server-side.
  * Indexes: `service_listings_published_ranking_idx (profession_id, avg_rating DESC, published_at DESC) WHERE status='published'` + reuse existing `service_listings_search_vector_gin` (`20260921090001:122`) + `service_review_aggregates_profession_idx` (`20260924090001:129`). `EXPLAIN` validation.
* Dart:
  * `lib/engine/recommendation_engine/ranking_formula.dart:1` — pure function `double score({required ServiceListing listing, required RankingWeights w, required double tsRank, ...})` mirroring SQL arithmetic, plus `explain()` returning per-signal breakdown for `HivorrCard` tooltip. No I/O, no ordering.
  * `lib/engine/recommendation_engine/ranking_weights.dart` — immutable value object + `fromJson` for `platform_config.value`.
  * `lib/engine/matching_engine/matching_seam.dart` — documented stub reserving spatial routing for EP-04 (no logic).
  * Data layer: `lib/data/models/service_listing_dto.dart` (reuse extension), `lib/data/mappers/service_listing_mapper.dart` (static `toEntity`), `lib/data/datasources/remote/supabase_service_search_remote_data_source.dart` (single seam via `BaseApiService:lib/core/api/services/base_api_service.dart:1`), `lib/data/datasources/remote/service_search_envelope_parser.dart`, `lib/data/datasources/local/service_search_local_data_source.dart` (Hive-backed via `lib/core/cache/lru_cache.dart:1` + `lib/core/database/local_store.dart:1`), `lib/data/repositories/service_search_repository.dart` + `service_search_repository_impl.dart` (cache-first, invalidate on `platform_config` version bump), `lib/data/providers/marketplace_search_provider.dart:1` (`ChangeNotifier`, debounced query, asserts `items` rendered in RPC order — no resort).
  * Tests: pgTAP `033_platform_config_posture.sql`, `034_service_ranking_rpc_enforcement.sql`; unit `test/unit/engine/recommendation_engine/ranking_formula_test.dart`, repository/provider tests, widget test `results render in RPC order`.
* Documentation comment on formula weights + version tag in migration.

**Dependencies Blocking Start:** `EP-03-01` (`service_listings` fact table + `search_vector` trigger + `avg_rating` cache) at `supabase/migrations/20260921090001_service_marketplace_schema.sql:42` + `EP-02-11` (`entity_professions.trade_verification_status`, `kyc_tiers`) + `EP-03-03` (`service_review_aggregates` at `20260924090001:108`) — all inspected as present. Stage 1 is `Completed` on staging per assumption `EP-03:186`.

## 4. Out of Scope

* `EP-03-07` full search infrastructure extensions beyond ranking RPC (additional `service_search` RPC composition, `Hive` offline index hydrator `service_search_index.dart`, `taxonomy` cache warmer) — only minimal local cache window for ranked pages is in scope; faceted `full-text` filter composition beyond `p_filters` note is deferred to 03-07.
* `EP-03-08/09` supply/consumer screens (`marketplace_discovery_screen.dart`, `service_detail_screen.dart`, media upload, profession picker UI) — this task provides the engine they consume; screens are Stage 3.
* `EP-03-10/11` contract & escrow orchestration — `completion_rate` reads existing `financial_escrow`/`service_contracts` but does not mutate them.
* `lib/engine/matching_engine` spatial routing (EP-04 3-party `logistics_dispatch`); AI layer `lib/ai/*` per `AGENT.md:7,14` — explicitly excluded, code-review gate bans `lib/ai` import in ranking path.
* Client-side resort, client-computed settlement, hardcoded ranking constants, or new currency scope (`NGN/GHS/USD/GBP` from `financial_supported_currencies:55` unchanged).
* Admin console for weight editing — `service_role` update via SQL/postgREST is sufficient; moderation queue is EP-03-17.
* `view_count` increment on read (deferred per `20260921090001:25`).

## 5. Existing Asset and Dependency Analysis

Inspection performed via `Glob`/`Read`/`Grep` (read-only, no writes). `lib/engine/**/*` = 7 `.gitkeep` seams; migrations 34 files; tests 32 pgTAP suites; `lib/data`, `lib/core`, `lib/workspace` fully read.

| Asset | Path | State | Relevance to Ranking |
|---|---|---|---|
| **Fact table + FTS** | `supabase/migrations/20260921090001_service_marketplace_schema.sql:42-124` | Live: `service_listings` (9 CHECKs, 7 indexes incl. `GIN(search_vector)`), trigger `service_listings_search_vector_update():130` recomputes `title+description+profession.name`, D5 guard `service_listings_guard_publish_state():168` | Primary scan `WHERE status='published'`. `search_vector @@ to_tsquery` + `ts_rank` + `is_trade_verified_cache` fast-path for `w_verify`. `avg_rating/review_count` zero client grants except `avg_rating` UPDATE for EP-03-03 reveal (`023_service_marketplace_schema_posture.sql:69`). |
| **Review aggregates** | `supabase/migrations/20260924090001_service_review_schema.sql:52,108` | Live: `service_reviews(is_revealed, revealed_at)` + `service_review_aggregates(avg_rating, review_count, distribution, last_revealed_at)` keyed `(professional_entity_id, profession_id)`, index `service_reviews_listing_revealed_idx:94` | `w_rating * bayesian_avg` — `avg_rating/review_count` already materialized; `bayesian_avg = (C*m + sum)/(C+n)` uses `C/m` from `platform_config`. No scan of `service_reviews` per ranking call. |
| **Taxonomy** | `supabase/migrations/20260821090001_entity_taxonomy_tables.sql:1` + `20260829090001_taxonomy_seed_data.sql:1` + `20260829090002_taxonomy_management_rpcs.sql:1` + `lib/workspace/profession_registry/taxonomy_engine.dart:1` | Live: `industries/professions` seeded, RPCs `taxonomy_industries_list/professions_list` `SECURITY INVOKER STABLE` `anon, authenticated` | `p_profession_id`/`p_industry_id` validation + `profession relevance` signal. `TaxonomyEngine.browseIndustries/browseProfessions/search` deterministic sort by `sortOrder` reusable for filter validation. |
| **KYC / Trade gate** | `supabase/migrations/20260829090003_verification_admin_review_schema.sql:1` + `lib/data/entities/verification_status.dart:1` | Live: `kyc_tiers(tier_code tier_0..3)`, `entity_kyc_levels`, `entity_professions(trade_verification_status)`, RPC `verification_status_get` | `w_verify * kyc_tier_weight` — map `kyc_tier_code` → weight via `CASE tier_code WHEN 'tier_3' THEN 1.0 ...` or `kyc_tiers.sort_order` lookup; `is_trade_verified_cache` boolean fast-path for published listings. No new verification table. |
| **Financial escrow** | `supabase/migrations/20260829100004_financial_integrity_schema.sql:191,232` | Live: `financial_escrow(status funded/partially_released/released)` + `financial_escrow_milestones` + `financial_balances` + `financial_transactions:149` double-entry | `w_completion * completion_rate` — derived from `service_contracts` ↔ `financial_escrow` join (see `20260923090001_service_contract_schema.sql:43` `service_contracts.escrow_id nullable`). `released_amount/total_amount` or `completed_contracts/total` per professional. |
| **Recency + Activity signals** | `service_listings.published_at:61` + `entities:20260821090002_entity_core_tables.sql:20` | Live: `published_at NOT NULL iff published CHECK:90`, `entities.created_at`, `entity_devices.last_seen_at` (if present) | `w_recency * decay(now()-published_at)` (`exp(-λ·age)` λ from `platform_config`), `w_activity * login_recency` — source is `entities.last_sign_in_at` or `max(entity_devices.last_seen_at)` (requires additive column if absent — see §10). |
| **Cache + LocalStore** | `lib/core/cache/lru_cache.dart:12` + `lib/core/cache/cache_manager.dart:1` + `lib/core/cache/cache_config.dart:1` + `lib/core/database/local_store.dart:1` + `lib/core/database/boxes/app_boxes.dart:1` | Live: `LruCache<T>` O(1) `get/put` + lazy expiry (`isExpired`), `CacheManager` singleton `invalidatePrefix`, `AppBoxes.cache`, `HiveStorageEngine` | Result window `CacheManager.put('service_search:{hash}', List<Dto>, ttl:5m)` + `invalidatePrefix('service_search:')` precedent `taxonomy:` in `taxonomy_local_data_source.dart:1`. |
| **API seam + Envelope** | `lib/core/api/services/base_api_service.dart:1` + `lib/data/datasources/remote/taxonomy_envelope_parser.dart:1` + `lib/data/datasources/remote/data_exception_mapper.dart:1` + `supabase/migrations/20260819090001_enforcement_foundation.sql:37` (`platform_is_authenticated`, `platform_raise_error` `PLT000..999`) | Live: Single Supabase access via `BaseApiService.supabase.rpc`, `DataExceptionMapper` maps `PLT*`, envelope `{success,code,message,data}` validated | Template for `SupabaseServiceSearchRemoteDataSource.rpc('service_ranking_search')` + new `ServiceSearchEnvelopeParser` (copy `TaxonomyEnvelopeParser`). |
| **RLS + pgTAP posture pattern** | `supabase/tests/database/023_service_marketplace_schema_posture.sql:1` (plan 30, `has_table`, `GIN` assert, `prosecdef` count=1, `EXECUTE` counts 2/19/19, 11 policies) + `024_service_marketplace_rpc_enforcement.sql`, `supabase/tests/database/027_service_review_schema_posture.sql` | Live: `341-line` posture template, `plan(N)`, `finish()` | Direct reuse for `033_platform_config_posture` + `034_service_ranking_rpc_enforcement` — same `has_table`, `has_index`, `role_column_grants`, `policies`, `anon EXECUTE` assertions. |
| **Shared UI tokens** | `lib/shared/widgets/hivorr_card.dart:1` + `lib/shared/layouts/hivorr_content_pane.dart:1` + `lib/systems/verification/widgets/trade_verified_badge.dart:1` | Live: `HivorrCard/Chip/LoadingState(HivorrLoader)` per `VISUAL-IDENTITY.md`, `TradeVerifiedBadge`, `VerificationBadgesRow` | Future discovery screens consume ranking order without resort; this task adds no new widget but must not introduce `Colors.*`/`fontFamily` (DoD gate). |
| **Engine directory seam** | `lib/engine/recommendation_engine/.gitkeep:1` + `lib/engine/matching_engine/.gitkeep:1` + `lib/engine/search_engine/.gitkeep:1` | Exists, empty (`ARCHITECTURE.md:71-76` naming correct: `recommendation_engine` = ranking, `matching_engine` = EP-04 routing, `search_engine` = offline index) | Naming preserved; no rename. |
| **Repository/Provider pattern** | `lib/data/repositories/taxonomy_repository_impl.dart:1` (cache-first `local hit→return, miss→remote→save`) + `lib/data/providers/taxonomy_provider.dart:1` (`ChangeNotifier`, `250ms` debounce, `filteredProfessions`) | Live | 1:1 template for `ServiceSearchRepositoryImpl` + `MarketplaceSearchProvider` (minus in-memory `search` filter — RPC order is canonical). |
| **Storage / Portfolio** | `supabase/migrations/20260830100001_storage_buckets.sql:1` + `lib/core/storage/supabase_storage_service.dart:1` + `20260913090001_portfolio_public_profile.sql:1` | Live: buckets `service-listing-media`, `portfolio-items`, `PortfolioEnvelopeParser` `SECURITY DEFINER` pattern (only precedent) | Not directly ranking, but confirms `anon zero table grant + SECURITY DEFINER RPC` posture audit expects `prosecdef count=1` already ( `service_review_reveal_if_ready` ) — new ranking RPC must stay `SECURITY INVOKER` to keep count=1 green. |

**Gaps (no suitable asset):**

* `public.platform_config` — `Grep platform_config` = 0 in migrations, 0 in `lib/`. Required for versioned, service-role-writable weights (plan `EP-03:305-308`).
* `service_ranking_search` RPC — `Grep service_ranking_search|service_search` = 0 in migrations/tests/lib.
* `RankingFormula` Dart + `RankingWeights` value object — `lib/engine` empty.
* Remote/local datasource + repository + provider for ranked search — `.gitkeep` in `lib/systems/marketplace` proves no existing slice.
* Composite ranking index `service_listings_published_ranking_idx` — not in `20260921090001` (only 6 btree + 1 GIN).

## 6. Reuse / Extension / Refactoring Assessment

| Major Proposed Asset | Assess | Decision | Rationale & Integration |
|---|---|---|---|
| `public.platform_config` table + seed `service_ranking_weights` | **New** | Create new | Inspected all 34 migrations + `lib/core/config` (`environments/`, `feature_flags/`, `constants/`) — no generic weight/config table exists; `financial_supported_currencies` is reference but not key-value. Extending `financial_*` or `taxonomy_*` tables would violate domain separation (`Engineering-Execution-Generation-Principle.md:20-31`). Create small `platform_config(key PK, value jsonb)` with RLS default-deny, `REVOKE ALL`, `GRANT SELECT anon,authenticated` + `GRANT UPDATE service_role` only, `platform_set_updated_at` trigger, comment `approved weights v1`. Designed for reuse — future engines (logistics dispatch ranking, growth SEO) insert `logistics_weights`, `search_weights` without migration. Explain why not refactor: no existing asset can reasonably hold arbitrary engine weights. |
| `service_ranking_search` RPC | **New** | Create new | Inspected `service_listing_*` (7 RPCs), `service_contract_*` (8), `service_review_*` (4) — all `SECURITY INVOKER`, envelope, `PLT*` — no ranking/search RPC. Cannot extend `service_listing_get/list_mine` — they are owner-scoped keyset `(created_at,id)` and `SECURITY INVOKER` STABLE but lack weighted scoring, `ts_rank`, cursor `(score,id)`, weight composition. New RPC follows identical execution model (`SECURITY INVOKER STABLE`, `REVOKE EXECUTE baseline + GRANT anon,authenticated,service_role`), envelope, `GUC platform.rpc_invocation` not needed (read-only). Integrates via `BaseApiService.supabase.rpc` single seam, consumed by new `SupabaseServiceSearchRemoteDataSource`. |
| `service_listings` + `search_vector` + `service_review_aggregates` | **Reuse** | Reuse verbatim | Direct `FROM service_listings WHERE status='published'` + `JOIN service_review_aggregates USING (professional_entity_id, profession_id)` + `service_listings_search_vector_gin` + trigger `service_listings_search_vector_update()`. No schema change beyond narrow `SELECT` usage. Cache columns `avg_rating/review_count` already narrow-granted for reveal (`20260924090001:163`). |
| `kyc_tiers` / `entity_professions.trade_verification_status` / `verification_status_get` | **Reuse** | Reuse | `w_verify` maps `kyc_tier_code` → weight via `CASE tier_code WHEN 'tier_3' THEN 1.0 ...` or `kyc_tiers.sort_order` lookup; `is_trade_verified_cache` boolean fast-path for published listings. No new verification table. |
| `financial_escrow` + `service_contracts` for `completion_rate` | **Reuse** | Reuse | `completion_rate` = `COUNT(completed|closed)/COUNT(total)` or `SUM(released_amount)/SUM(total_amount)` per professional+profession via join `service_contracts.escrow_id→financial_escrow.id` + `service_contracts.status`. Existing `financial_escrow_milestones` not scanned per ranking call — aggregate precomputed or computed via `LATERAL` subquery with index `financial_escrow_payee_idx`. |
| `LruCache<T>` + `CacheManager` + `LocalStore` + `AppBoxes` | **Extend** | Extend (additive) | `LruCache:12` + `cache_manager.dart:1` already supports `put/get/invalidatePrefix` + `maxEntries/defaultTtl` via `EnvironmentValueSource`. Extend by adding `CacheManagerTaxonomyLocalDataSource`-style `service_search:{hash}` window (5m TTL, 50 entries) + optional `AppBoxes.serviceSearchCache` box constant (additive, no migration). Refactoring `CacheManager` not needed — O(1) `get/put` proven; only `invalidatePrefix('service_search:')` on weight version bump. |
| `BaseApiService` + `TaxonomyEnvelopeParser` + `DataExceptionMapper` | **Reuse/Extend** | Reuse pattern, new parser | `SupabaseTaxonomyRemoteDataSource:16` `_guard(mapDataException)` + `TaxonomyEnvelopeParser.unwrapData` is 1:1 template. Reuse `BaseApiService` injection (`dio, supabase, exceptionMapper`); create `ServiceSearchEnvelopeParser` copying validation `{success,code,message,data}` → `{items, has_more, next_cursor, weights_version}` with same `PLT003/004/005/999` vocabulary. No refactor. |
| `TaxonomyEngine` + `ProfessionMapper`/`IndustryMapper` | **Reuse** | Reuse | `taxonomy_engine.dart:12` `browseIndustries/browseProfessions/search/industryForProfession` validates `p_profession_id`/`p_industry_id` in RPC + in provider filter chips. `ProfessionMapper.toEntity` pattern for `ServiceListingMapper.toEntity` (pure Dart, `fromJson/toJson` snake→camel). |
| `lib/engine/recommendation_engine/ranking_formula.dart` | **New** | Create new | Inspected `lib/engine` — all 7 `.gitkeep`. No formula exists; cannot extend `TaxonomyEngine` (taxonomy only) or `LruCache` (infra). New pure-Dart `double score(...)` mirroring SQL arithmetic + `RankingWeights` constants struct + `explain()` per-signal map. Future reuse — `growth_engine`, `dashboard_engine` can import `RankingWeights` schema. |
| `lib/engine/matching_engine` seam | **Reuse** | Reuse as stub | Per `ARCHITECTURE.md:71` `matching_engine` = spatial/3-party dispatch. Leave stub `matching_seam.dart` documenting EP-04 boundary — no parallel ranking system. |
| `lib/data/repositories/*_impl` + `lib/data/providers/*` | **Reuse pattern** | New impls mirroring pattern | `taxonomy_repository_impl.dart` cache-first + `taxonomy_provider.dart` `ChangeNotifier` + `SubmitState` patterns reused. No generic `SearchRepository` exists to extend — creating parallel would be correct (new domain slice). |
| Ranking composite index | **New** | Create new | `20260921090001:110` has 6 btree + 1 GIN but not `(profession_id, avg_rating DESC, published_at DESC) WHERE published`. New partial index speeds `profession_id` filter + `ORDER BY score DESC, id DESC` fallback when `p_query IS NULL`. Additive, idempotent. |

**Duplicate-prevention statement:** No existing table/RPC/component computes a weighted `score`. Creating `platform_config` + `service_ranking_search` is not a parallel system — it is the first deterministic core per `AGENT.md:7`. Alternative of extending `service_listing_list_mine` would leak ordering logic to client or hardcode weights, violating Rule 4 + determinism.

## 7. Recommended Technical Approach

### 7.1 Server-Side Deterministic Core (Non-Negotiable)

* **Versioned SQL is source of truth.** Migration `*_<timestamp>_platform_config_and_ranking.sql` contains commented `/* RANKING FORMULA v1 — 2026-09-26 — weights via platform_config service_ranking_weights */` header with full `score` expression. Weights never hardcoded — `SELECT value FROM platform_config WHERE key='service_ranking_weights'` at top of RPC (or `CROSS JOIN LATERAL`) and bound to locals `w_verify` etc. Defaults fallback if row missing (`coalesce`).
* **SECURITY INVOKER STABLE.** `service_ranking_search` is `SECURITY INVOKER` (not definer) so RLS `service_listings_select_public (status='published')` + `service_listing_media_select` applies inside body. Keep posture audit `prosecdef` count at 1 (only `service_review_reveal_if_ready:548` definer) — `023_service_marketplace_schema_posture.sql:216` pins 1, new RPC must not be definer.
* **Envelope + PLT vocabulary.** Returns `jsonb_build_object('success',bool,'code',text,'message',text,'data',jsonb)` per `20260829100004:16-20`. `PLT003` validation (`profession not found`, `limit 1-50`), `PLT004` unknown `profession_id` (no oracle — identical code for non-visible `published` check), `PLT005` conflict (none for read, but `rating_min` out of range), `PLT999` internal. `anon` capable (public discovery) — `GRANT EXECUTE anon, authenticated, service_role` + `REVOKE EXECUTE baseline` per `20260924090001:722`.
* **No client math determines order.** Dart `RankingFormula.score` is explanatory mirror; provider/widget test asserts `renderOrder == rpcOrder` (EP-03:308 Expected Outcome). CI lint forbids `list.sort((a,b)=>b.score.compareTo(a.score))` on `service_listings` payload (grep `sort.*score` fails build).

### 7.2 Signal Definitions (Auditable)

Default weights (seed `platform_config.value`, sum `1.0`, service-role tunable):

```json
{
  "w_verify": 0.28,
  "w_rating": 0.26,
  "w_completion": 0.16,
  "w_recency": 0.12,
  "w_relevance": 0.12,
  "w_activity": 0.06,
  "bayesian_prior_count": 5,
  "bayesian_prior_mean": 3.0,
  "recency_half_life_days": 30,
  "activity_half_life_days": 14,
  "ts_rank_normalization": 32
}
```

Per-signal computation (SQL, mirrored in Dart):

* `kyc_tier_weight` — `CASE kyc_tier WHEN 'tier_3' THEN 1.0 WHEN 'tier_2' THEN 0.66 WHEN 'tier_1' THEN 0.33 ELSE 0.0 END` via `JOIN entity_kyc_levels` or direct `entities.kyc_tier_code` if column exists; `is_trade_verified_cache` multiplies `w_verify` extra `0.15` bonus (published listings already approved per `20260921090001:65`).
* `bayesian_avg` — `(prior_count*prior_mean + avg_rating*review_count) / (prior_count+review_count)` using `service_review_aggregates.avg_rating/review_count`; fallback `prior_mean` when `review_count=0` (cold-start fairness). Null → `0`.
* `completion_rate` — `completed_or_closed_contracts / total_contracts` per `(professional_entity_id, profession_id)` via `LATERAL (SELECT count(*) FILTER (WHERE status IN ('completed','closed'))::float / nullif(count(*),0) FROM service_contracts WHERE professional_entity_id=sl.entity_id AND profession_id=sl.profession_id)` or escrow-based `SUM(released_amount)/SUM(total_amount)`. Choose contract-count variant (cheaper, index `service_contracts_professional_idx`); document in migration comment.
* `decay` — `exp(-ln(2) * age_days / half_life)` where `age_days = extract(epoch FROM now()-published_at)/86400`, `half_life=30`. `published_at` is `timestamptz` (`20260921090001:61`).
* `ts_rank` — `ts_rank(search_vector, plainto_tsquery('english', p_query), 32)` normalized `0..1` (`/ (1+ts_rank)` or direct). When `p_query IS NULL/''` → `0`. Uses `GIN(search_vector)` (`20260921090001:122`) — `EXPLAIN (ANALYZE,BUFFERS)` must show `Bitmap Index Scan`.
* `login_recency` — `exp(-age_days /14)` on `coalesce(entities.last_seen_at, entities.created_at)` or `GREATEST(max(entity_devices.last_seen_at), entities.created_at)`. **Additive column choice:** If `entities.last_seen_at timestamptz` absent, add `ALTER TABLE public.entities ADD COLUMN IF NOT EXISTS last_seen_at timestamptz` default `created_at` (idempotent, no backfill needed — future `auth.users.last_sign_in_at` sync via Edge Function later, not in this task).

Final `score` = sum; tie-break `id DESC` for determinism. Keyset cursor `WHERE (score, id) < (p_cursor_score, p_cursor_id)` (lexicographic) + `ORDER BY score DESC, id DESC LIMIT p_limit+1` to compute `has_more`.

### 7.3 Weight Storage & Governance

* `platform_config` row `key='service_ranking_weights'` `value` JSONB validated `CHECK (value ? 'w_verify' AND (value->>'w_verify')::numeric BETWEEN 0 AND 1)` per key + `CHECK ( (value->>'w_verify')::numeric + ... BETWEEN 0.999 AND 1.001)` sum check + `CHECK` for Bayesian priors range. `service_role` only `UPDATE` per RLS (`current_user IN ('service_role','postgres')` or `auth.jwt()->>role = 'service_role'` pattern mirroring `service_listing_unpublish:951`).
* `value` update increments `updated_at` via `platform_set_updated_at()`; RPC returns `weights_version = updated_at` in `data` for client cache invalidation (provider compares cached version).
* No Edge Function needed — weights are synchronous read.

### 7.4 Client Vertical Slice (No Order Override)

* **Remote:** `SupabaseServiceSearchRemoteDataSource extends BaseApiService implements ServiceSearchRemoteDataSource` — `Future<ServiceSearchPage> rankingSearch({String? professionId, String? query, RankingFilters filters, RankingCursor? cursor})` → `supabase.rpc('service_ranking_search', params:{p_profession_id, p_query, p_filters, p_cursor})` → `ServiceSearchEnvelopeParser.unwrapData` → `List<ServiceListingDto>.fromJson` → `Dart`. `_guard(mapDataException)` per `supabase_taxonomy_remote_data_source.dart:25`.
* **Local:** `ServiceSearchLocalDataSource` — `CacheManager.put('service_search:${sha256(query|filters|cursor)}', page, ttl:5m)` + `get` + `invalidatePrefix('service_search:')` on `weights_version` change. Backed `AppBoxes.cache` Hive box.
* **Repository:** `ServiceSearchRepositoryImpl` — cache-first for `p_query IS NULL` warm `browse` path, network-first for `p_query` FTS (to respect `ts_rank` freshness). Single seam — no two sources of truth.
* **Provider:** `MarketplaceSearchProvider extends ChangeNotifier` — states `idle/loading/loaded/error`, `TextEditingController` with `250ms` debounce mirroring `TaxonomyProvider`, `RankingFilters` value object (profession, price_range, rating_min, verified_only). **Invariant:** `items` list is assigned verbatim from `data.items`; widget test asserts no sort.
* **Engine mirror:** `RankingFormula` — static `double compute({...})` + `Map<String,double> explain({...})` returning per-signal breakdown for tooltip (`Verification 0.28×0.66=0.18`). Unit test with 10-listing fixture yields deterministic `double[]` within `1e-9` of SQL `(SELECT score FROM service_ranking_search)`.

### 7.5 Integration with Existing Platform

* **Domain models:** `Professions/Industries` FK chain `service_listings.profession_id→professions.id→industries.id` (`20260921090001:45`, trigger `service_listings_search_vector_update():138` re-derives `industry_id`) — any new industry seeded via `20260829090001` auto-participates, no schema change.
* **User/account:** `entities`/`entity_profiles.legal_name` anchor unchanged (`20260821090006_entity_profile_legal_name_guard.sql:1`). `auth.uid()` drives RLS inside RPC; `anon` discovery is `status='published'` only (`service_listings_select_public:381`).
* **Professional/Client:** Trade gate `entity_professions.trade_verification_status='approved'` enforced at `service_listing_publish:554` and cached `is_trade_verified_cache` — ranking reads cache (fast) but also joins `kyc_tiers` for granular `w_verify`.
* **Transaction system:** Reuses `financial_escrow` lifecycle (`created/funded/partially_released/released/disputed` at `20260829100004:205`) + `service_contracts` state machine (`draft/offered/active/completed/closed` at `20260923090001:43`) for `completion_rate`; no new ledger, no double-entry change.
* **AuthN/AuthZ:** `platform_is_authenticated:20260819090001` + `REVOKE ALL / GRANT column-level` pattern per `20260921090001:338` — ranking RPC respects it; no new auth service.
* **DB architecture:** Single source of truth is `service_listings` + `service_review_aggregates`; ranking never writes. Follows `ARCHITECTURE.md:160` Database-First Zero-Trust; `lib/core/api/api_config.dart:1` single Supabase accessor discipline.
* **Shared services:** `LruCache` + `BaseApiService` + `TaxonomyEngine` reused; no duplicate HTTP client or cache.

## 8. Required Systems, Modules, and Components

| Location | Component | Type | Purpose |
|---|---|---|---|
| `supabase/migrations/<ts>_platform_config_and_ranking.sql` | `platform_config` table + seed + RLS + trigger + 1 RPC `service_ranking_search` + 2 indexes | Migration | Weight store + deterministic ranking primitive |
| `public.platform_config` | Table `key PK, value jsonb, description, created_at/updated_at` + CHECKs | Table | Service-role-writable engine config (future-proof key prefix `service_`, `logistics_`) |
| `public.service_ranking_search` | `FUNCTION ... RETURNS jsonb SECURITY INVOKER STABLE` + `COMMENT` | RPC | Only ordering primitive for discovery |
| `service_listings_published_ranking_idx` | `CREATE INDEX ... WHERE status='published'` | Index | Filter + ordering fast-path |
| `lib/engine/recommendation_engine/ranking_formula.dart` | Pure Dart `RankingFormula` + `explain()` | Engine | SQL mirror, no ordering decision |
| `lib/engine/recommendation_engine/ranking_weights.dart` | `RankingWeights` value object + `fromJson/toJson` + `defaults` | Engine | Typed weights contract |
| `lib/engine/matching_engine/matching_seam.dart` | Stub + doc comment | Seam | Reserves EP-04 routing, documents non-use |
| `lib/data/models/service_listing_dto.dart` | DTO `fromJson/toJson` (snake→camel) | DTO | `service_listings` projection for ranking page (whitelist: no `search_vector`) |
| `lib/data/mappers/service_listing_mapper.dart` | `static ServiceListing toEntity(ServiceListingDto)` | Mapper | Pure transform, mirrors `profession_mapper.dart:1` |
| `lib/data/entities/service_listing.dart` | Entity `ServiceListing` (id, professionId, industryId, title, currency, avgRating, reviewCount, publishedAt, isTradeVerified, score?) | Entity | Domain entity (score transient, not persisted) |
| `lib/data/datasources/remote/supabase_service_search_remote_data_source.dart` | `SupabaseServiceSearchRemoteDataSource extends BaseApiService` | Remote DS | Single RPC seam |
| `lib/data/datasources/remote/service_search_envelope_parser.dart` | `ServiceSearchEnvelopeParser.unwrapData` | Parser | Validates `{success,code,message,data:{items,has_more,next_cursor}}`, maps `PLT*` → typed |
| `lib/data/datasources/local/service_search_local_data_source.dart` | `ServiceSearchLocalDataSource` (`CacheManager` + optional `HiveServiceSearchLocalDataSource`) | Local DS | Result window + `weights_version` invalidation |
| `lib/data/repositories/service_search_repository.dart` | Abstract `Future<ServiceSearchPage> search(...)` | Repository | Contract |
| `lib/data/repositories/service_search_repository_impl.dart` | Cache-first impl | Repository | `local hit → return, miss → remote → save` |
| `lib/data/providers/marketplace_search_provider.dart` | `ChangeNotifier` + `RankingFilters` + debounce | Provider | Discovery state (future `marketplace_discovery_screen.dart` consumer; this task ships provider only to prove no-resort) |
| `lib/core/cache/cache_manager.dart` | Extend prefix `service_search:` | Core | Reuse, not new |
| `supabase/tests/database/033_platform_config_posture.sql` | pgTAP `plan(18)` | Test | `platform_config` RLS/GRANTs/CHECKS/bucket isolation |
| `supabase/tests/database/034_service_ranking_rpc_enforcement.sql` | pgTAP `plan(32)` | Test | Deterministic fixture, weight-tweak shift, GIN `EXPLAIN`, anon `PLT004` uniformity, cursor pagination |

No new `lib/systems/marketplace` screens in this task (Stage 3) — provider + DTO are enough to prove contract.

## 9. Data Requirements

* **Inputs per call:** `p_profession_id uuid nullable` (when null → cross-profession ranked), `p_query text nullable` (empty → `ts_rank 0`), `p_filters jsonb` (`{profession_id?, industry_id?, price_min?, price_max?, currency_code?, rating_min? 0-5, is_verified_only? bool, is_trade_verified_only? bool}`), `p_cursor jsonb {score numeric, id uuid}?`, `p_limit int 1-50 default 20`.
* **Reference data:** `industries/professions` (active only), `financial_supported_currencies` active list, `kyc_tiers` (`tier_0..3`), `service_review_aggregates` aggregates, `service_contracts` completion counts, `entities`/`entity_devices` activity.
* **Derived signals:** `bayesian_avg` (`prior_count=5, prior_mean=3.0`), `completion_rate` (`0` when no contracts), `decay` half-lives, `ts_rank` normalization, `login_recency`.
* **Weights:** `platform_config.value` JSONB validated (see §10). Default seed as §7.2.
* **Output:** `data:{items:[{id, entity_id, profession_id, industry_id, slug, title, description, pricing_type, price_min/max, currency_code, avg_rating, review_count, is_trade_verified_cache, published_at, profession_slug/name, industry_slug/name, score, rank_explain?}], has_more bool, next_cursor {score,id}?, weights_version timestamptz}`. `search_vector` never returned.
* **Cursor determinism:** `(score DESC, id DESC)` total order; `score` computed to `numeric(10,6)` to avoid float tie-flip; `id` is tie-break.

## 10. Database Considerations

* **Table `platform_config`:**

```sql
create table if not exists public.platform_config (
  key text primary key check (key ~ '^[a-z_]+$'),
  value jsonb not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.platform_config is 'Engine weight store — versioned JSONB per key (service_ranking_weights, future logistics_weights). Service-role-writable only.';
```

  * RLS `enable row level security`; `REVOKE ALL ON public.platform_config FROM anon, authenticated, service_role`; `GRANT SELECT ON public.platform_config TO anon, authenticated, service_role`; `GRANT UPDATE (value, description) ON public.platform_config TO service_role`; `GRANT INSERT/DELETE TO service_role` (for future keys). Policy `platform_config_select USING (true)` for `SELECT` to anon/authenticated; `platform_config_update USING (current_user IN ('service_role','postgres'))` for service_role only (or `auth.jwt()->>role = 'service_role'` pattern mirroring `service_listing_unpublish:951`).
  * CHECKs: `value ? 'w_verify' AND ...` per key via `CHECK (key <> 'service_ranking_weights' OR (value ?& array['w_verify','w_rating','w_completion','w_recency','w_relevance','w_activity']))` + numeric range `0..1` + sum `0.999..1.001` + `bayesian_prior_*` range. `INSERT ... ON CONFLICT(key) DO NOTHING` seed with defaults + `description='Deterministic ranking v1 — see migration comment'`.
  * Idempotent + `IF NOT EXISTS` throughout, per `20260921090001:38`.

* **Optional additive activity column:**

```sql
alter table public.entities add column if not exists last_seen_at timestamptz default now();
create index if not exists entities_last_seen_at_idx on public.entities (last_seen_at desc);
```

  * Idempotent, no backfill migration needed; future sync from `auth.users.last_sign_in_at` via `supabase_auth_service.dart:1` or Edge Function (out of scope). If `entity_devices` already has `last_seen_at`, use `GREATEST` join instead — choose at implementation time after `SELECT column_name FROM information_schema.columns WHERE table_name='entities'` check.

* **Indexes:**

```sql
create index if not exists service_listings_published_ranking_idx
  on public.service_listings (profession_id, avg_rating desc, published_at desc)
  where status = 'published';
-- Existing GIN(search_vector) retained — verified by 023:190
-- Optional: btree_gin not needed; ts_rank uses GIN directly.
```

  * `EXPLAIN (ANALYZE, BUFFERS)` in pgTAP must show `Bitmap Index Scan on service_listings_search_vector_gin` when `p_query` present, else `Index Scan` on `service_listings_published_ranking_idx`.

* **RPC DDL:**

```sql
create or replace function public.service_ranking_search(
  p_profession_id uuid default null,
  p_query text default null,
  p_filters jsonb default '{}'::jsonb,
  p_cursor jsonb default null,
  p_limit int default 20
) returns jsonb language plpgsql security invoker stable set search_path = public as $$
-- validates auth not required (anon capable), validates profession active,
-- sanitizes p_query via plainto_tsquery('english', btrim(p_query)) (no injection — to_tsquery server-only),
-- validates p_filters schema, validates p_cursor {score,id} numeric+uuid,
-- reads weights from platform_config, computes lateral signals, orders by score desc, id desc, keyset paginates.
$$;
comment on function public.service_ranking_search(uuid,text,jsonb,jsonb,int) is 'SECURITY INVOKER STABLE — deterministic ranking v1: weighted sum over kyc_tier_weight, bayesian_avg, completion_rate, recency decay, ts_rank, login_recency. anon+authenticated. No client ordering.';
revoke execute on function public.service_ranking_search(uuid,text,jsonb,jsonb,int) from public;
grant execute on function public.service_ranking_search(uuid,text,jsonb,jsonb,int) to anon, authenticated, service_role;
```

  * Inside body: `(status='published' AND (p_profession_id IS NULL OR profession_id=p_profession_id))` + `search_vector @@ plainto_tsquery` when `p_query` not null + `price_range`/`rating_min` filters + `is_verified_only` → `is_trade_verified_cache=true`. RLS still applies, so `anon` cannot see `draft/paused`.

* **Storage/Realtime:** No bucket change. `ALTER PUBLICATION supabase_realtime DROP TABLE` not needed (ranking tables are read-only; `platform_config` excluded from realtime).

* **Migration discipline:** No DDL on any prior table/function/policy (Rule 3 write discipline per `20260924090001:43`). Idempotent `IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE`.

## 11. API Requirements

* **Single RPC, not table SELECT:**

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `POST /rest/v1/rpc/service_ranking_search` | `supabase.rpc` via `BaseApiService.supabase` | `anon` (public browse) + `authenticated` + `service_role` | Ranked discovery page |

  * **Request params (`jsonb`):** `p_profession_id uuid?`, `p_query text?` (trimmed, `char_length 0-100`, capped — matches `TaxonomyEngine.maxSearchQueryLength:20`), `p_filters jsonb` (strict schema validation before query), `p_cursor jsonb {score numeric, id uuid}?`, `p_limit int 1-50` (default 20, caps at 50 to protect `GIN`).
  * **Response envelope (`jsonb`):** `{success bool, code text PLT000|PLT003|PLT004|PLT999, message text, data jsonb}` per `20260829100004:16`. On success `data={items: jsonb[], has_more: bool, next_cursor: {score,id}?, weights_version: timestamptz, debug_scores?: [{id, score, signals}]?}` (debug_scores only when `p_debug=true` service_role — never anon).
  * **Errors:** `p_profession_id` unknown or inactive profession → `PLT004` (identical to no visible rows — no oracle). `p_query` with only stopwords → treated as `null` (empty `ts_rank 0`), not error. `p_limit` out of range → `PLT003`. `p_cursor` invalid uuid/score → `PLT003`. Unknown `service_listings` id never leaks (RLS).
  * **Pagination:** Keyset `(score DESC, id DESC)` — `WHERE (score, id) < (cursor_score, cursor_id)` inclusive lexicographic; caller passes `next_cursor` from prior `data`. No `OFFSET` (avoids `N+1` scan). `has_more = count > p_limit` (fetch `p_limit+1`).
  * **Caching headers:** `STABLE` allows PostgREST `Cache-Control: public, max-age=60` for `anon` same-query pages; `weights_version` in payload enables client `invalidatePrefix` without `ETag`.
  * **Rate limiting:** Existing `RetryInterceptor` + `ApiConfig` rate limiter applies; ranking is `STABLE` so retry safe.

* **No direct table endpoints:** `service_listings` `SELECT` via `supabase.from` is not used for discovery ordering — repository exclusively calls `rpc`. `service_listing_get/list_mine` remain for owner CRUD but never for ranked browse.

* **Internal weight mgmt (service_role only):** `UPDATE platform_config SET value=jsonb_set(...) WHERE key='service_ranking_weights'` via `supabase` with `service_role` key (server console). No new RPC for weight update — direct `UPDATE` is `service_role`-granted; audit via `financial_audit_trail` not needed (weights not financial, but `platform_config` comment logs version).

## 12. User Interface Requirements

Per approved spec `EP-03:305` this task ships **no new screen** but ships the data-layer contract future screens `EP-03-08/09` consume. UI requirements for this task are therefore constrained to engine helper contracts + token compliance gates:

* **No hardcoded colors/fonts:** Any illustrative explainability chip added later must consume `Theme.of(context).colorScheme` / `AppThemeExtension` + `TextTheme` per `AGENT.md:18` + `VISUAL-IDENTITY.md:3-250`. `dart analyze` + token assertion `ColorScheme.primary == #0B6E99` (`EP-03:239`) must pass. This task's Dart is pure engine, not widget, so fails only if future discovery screen violates.
* **Mirror explainability contract:** `RankingFormula.explain(listing, weights, query)` returns `Map<String,double>` (`kyc, bayesian, completion, recency, relevance, activity, total`) for future `HivorrChip` tooltip / `HivorrCard` footer — not a widget in this task, but DTO `score_signals` debug payload supports it.
* **Layout responsiveness (future):** When `marketplace_discovery_screen.dart` arrives (EP-03-09), it must use `HivorrResponsiveScaffold` + `HivorrContentPane` (`~720dp max, 16/24dp gutters`) + `HivorrChip` filters + `HivorrLoadingState(HivorrLoader)` pulse + `HivorrEmptyState` for `items=[]` — this task's provider already emits `empty` state flag.
* **Route hygiene:** No new route in `lib/app/router/app_router.dart:1` for this task. Future `/s/:profession_slug/:service_id` (`EP-03:103`) is EP-03-19.
* **Accessibility:** Engine mirroring is `isTestable` — `RankingFormula` has no UI a11y, but provider exposes `isLoading/isEmpty/errorMessage` for `Semantics` in later screens.

**Widgets not required for DoD:** `marketplace_discovery_screen.dart`, `marketplace_search_screen.dart`, `service_detail_screen.dart`, `portfolio_grid` reuse (`EP-03:99`). Those are Stage 3 (`EP-03-08/09`).

## 13. User Experience Considerations

* **Perceived fairness:** Determinism is UX — same query → same order until `weights_version` bumps or new `published` listings arrive. No shimmer reorder after fetch; `items` replace once, `ListView` `key: ValueKey(id)` preserves position. No client sort flicker (lint enforces).
* **Cold-start friendliness:** `bayesian_avg` prevents 0-review listings from sinking below `3.0` prior — new verified pros appear mid-list, not bottom, encouraging supply.
* **Explainability toggle (future, not in this task):** Debug `?explain=1` (service_role) surface per-signal breakdown as `BottomSheet` — this task ships the `explain()` map to enable it without extra migration.
* **Empty & error states:** `items=[]` with `HivorrEmptyState` branded slot `No services yet` (owner) vs `Try another filter` (consumer) — provider `isEmpty` flag. `PLT003/004` maps to `HivorrErrorState` with `Retry` via `RetryInterceptor`.
* **Offline resilience:** Cache-first for warm `browse` (taxonomy + top published) returns instantly from `LruCache` while network resolves; `ts_rank` query is network-first (fresh relevance). Offline `Hive` hydrator for taxonomy/search cache is EP-03-07, but `CacheManager` 5m window already prevents blank screen on reconnect (`connectivity_plus:6.1.0`).
* **No AI override surprise:** Per `AGENT.md:7`, AI draft helper may group results (`Featured`) but never reorders; UX copy states `Ranked by verification, rating, completion`.

## 14. Security Considerations

* **Zero-Trust Client (`AGENT.md:6,13` Rule 4):** All scoring executes in `SECURITY INVOKER` RPC. Client never receives `search_vector`, `kyc` internals, or weight update capability. `RankingFormula` is display-only; CI scan flags any `amount` reduce or `score` sort in `lib/systems` as failure (mirrors `EP-03:182` financial earnings lint).
* **RLS default-deny:** `platform_config` — `anon`/`authenticated` `SELECT` only; `UPDATE/INSERT/DELETE` `service_role` only. `service_listings` retains `REVOKE ALL` + `service_listings_select_public (status='published')` + `service_listings_select_own` (`entity_id=auth.uid()`) per `20260921090001:381-396`. `service_review_aggregates` `SELECT anon,authenticated` (`20260924090001:158`) remains. Ranking RPC respects these — `anon` sees only `published`, `draft` rows are `PLT004` (no enumeration oracle — `service_listing_get:1018` pattern reused).
* **No `SECURITY DEFINER` expansion:** Only `service_review_reveal_if_ready:541` remains definer (posture `023:216` `count=1`). New RPC is invoker; `has_function_privilege('anon', 'service_ranking_search', 'EXECUTE')` expected `true`, `prosecdef=false`.
* **Injection resistance:** `p_query` never interpolated — `plainto_tsquery('english', btrim(p_query))` server-side; `to_tsvector` trigger re-derives `search_vector` (`20260921090001:146`). `p_filters` JSON schema validated (`rating_min 0-5`, `price_min/max >=0`, `price_max>=price_min`) before concatenating into SQL via `AND` clauses with `USING` params only.
* **Weight tampering:** Client cannot `UPDATE platform_config` — `authenticated` lacks `UPDATE` grant; RLS `WITH CHECK (current_user IN ('service_role','postgres'))` blocks; direct `PATCH /rest/v1/platform_config` returns `42501` or `PLT002` D5-equivalent. Only staging/prod `service_role` console may change weights; change is audited via `updated_at` + optional `INSERT INTO financial_audit_trail` not required for ranking.
* **PII redaction:** `service_listings` projection excludes `legal_name`, `document_path`; `portfolio_public_profile_get:20260913090001` whitelisting pattern is precedent. Logs via `lib/core/logging/pii_redactor.dart:1` redact `entity_id`/`email`.
* **Realtime exclusion:** `platform_config` + `service_listings` already excluded from `supabase_realtime` (`023:244` `count=0`) — no ranking leakage via Realtime.
* **Deterministic oracle resistance:** `p_cursor` for non-visible rows treated as exhausted (`has_more=false`, `items=[]`) not `PLT004` — mirrors `service_listing_list_mine:1149` `Unknown cursor → exhausted` (no side-channel).

## 15. Performance Considerations

* **Indexes (proof via `EXPLAIN`):**

| Query path | Index | Verification |
|---|---|---|
| `p_query present` | `service_listings_search_vector_gin` `GIN(search_vector)` (`20260921090001:122`) | `EXPLAIN (ANALYZE,BUFFERS) SELECT ... WHERE search_vector @@ plainto_tsquery` → `Bitmap Index Scan` |
| `profession_id filter` | `service_listings_published_ranking_idx (profession_id, avg_rating DESC, published_at DESC) WHERE published` (new) + existing `service_listings_profession_idx:112` | `Index Scan` on `profession_id` |
| `rating + recency sort tie-break` | `service_listings_published_at_idx WHERE published:120` + `service_review_aggregates_profession_idx:129` | `Index Scan` / `Index Only Scan` |
| `review_count=0` bayesian path | `service_review_aggregates` PK `(professional_entity_id, profession_id)` | `Index Only Scan` |
| `completion_rate` lateral | `service_contracts` `(professional_entity_id, profession_id)` + `financial_escrow_payee_idx:224` | `Index Scan` |

  * pgTAP `034` asserts `is((SELECT count(*) FROM pg_indexes WHERE indexname='service_listings_search_vector_gin'),1)` + new ranking index `=1`.

* **Pagination:** Keyset `(score DESC, id DESC)` — `LIMIT p_limit+1` (50+1) avoids `OFFSET` O(N) skip. No N+1 over contracts/milestones — ranking is single `SELECT` with `LATERAL` subqueries, not per-row.

* **Budget:** `p95 <400ms` for filtered search per `EP-03:56` + `EP-03-20`. Benchmark in `034` via `EXPLAIN (ANALYZE)` on 10k seeded `published` listings (fixture factory) — `Buffers: shared hit` dominates, no `Seq Scan`. Client never fetches unbounded sets — `p_limit` capped `50`.

* **Client cache:** `LruCache(maxEntries:50, defaultTtl:5m)` + `invalidatePrefix` keeps memory bounded; `Hive` optional warm cache for `browse` path avoids cold-start flash. No `Isar/SQLite` change (`lib/core/database/database_config.dart:1` `driverType hive`).

* **PostgREST cacheability:** `STABLE` RPC is cacheable (`GET /rpc/service_ranking_search` with `apikey anon`); `Cache-Control` relies on `weights_version` payload, not `ETag`.

* **No Realtime/backpressure:** Ranking is pull-only; messaging Realtime (`20260925090001`) not involved.

## 16. Testing Strategy

### 16.1 pgTAP — Database Posture & Enforcement (Supabase `supabase test db`)

**`033_platform_config_posture.sql` — plan(18):**

* `has_table('public','platform_config')` + `relrowsecurity=true`
* `REVOKE` checks: `authenticated` has `0 INSERT/UPDATE/DELETE` on `platform_config` (only `SELECT`), `anon` `0` write, `service_role` `1` `UPDATE`
* `has_column_privilege` for `SELECT` on `value` to `anon,authenticated`
* `4` CHECKs on `key` format + JSONB weight keys + sum range + prior ranges
* `has_index` `GIN(search_vector)` retained + new `service_listings_published_ranking_idx=1`
* `0` `SECURITY DEFINER` beyond the approved `1` (`SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_%' AND prosecdef` = `1`)
* `COUNT(service_% RPCs)=20` (19 prior `023:237` + `service_ranking_search` 1)
* `Realtime` still `0` for marketplace tables + `platform_config` excluded
* `COMMENT ON TABLE/FUNCTION` not null
* `anon EXECUTE` count now `3` (`service_listing_get`, `service_review_get_for_listing`, `service_ranking_search`) — update `023:290` expectation from 2→3, document deviation

**`034_service_ranking_rpc_enforcement.sql` — plan(32):**

* **Deterministic fixture:** Seed `10 published service_listings` with varied signals (2 `tier_3` verified `rating 4.9/5`, 1 `tier_0` `rating 5.0` low completion, 1 `old published_at` `3.5 rating`, 1 `high ts_rank` query `legal drafting`, etc.) + matching `service_review_aggregates` + `service_contracts` completion. Assert `SELECT array_agg(id ORDER BY score DESC, id DESC) FROM service_ranking_search(p_profession_id=>...) = '{expected uuid[]}'` — ordering is fixed. Re-run same query → same array (idempotence).
* **Weight-tweak shift proof:** `UPDATE platform_config SET value=jsonb_set(value,'{w_rating}','0.05') WHERE key='service_ranking_weights'` service_role → re-query shifts order (high-rating item drops), then `jsonb_set` back → order restores. Proves weights are live, not hardcoded.
* **Filter contracts:** `p_filters {rating_min:4.5}` excludes `<4.5`; `is_verified_only:true` excludes `is_trade_verified_cache=false`; `price_range` bounds exclude; `currency_code` mismatched excludes — each asserts `items` subset.
* **`ts_rank` relevance:** `p_query='legal drafting'` returns `legal` title listings top-ranked vs `p_query IS NULL` returns pure Bayesian+recency order — `score` differs, `ts_rank` component verified via `debug_scores` service_role path.
* **Cursor pagination:** `SELECT ... LIMIT 5` → `has_more=true, next_cursor={score,id}`; second call with `p_cursor=next_cursor` returns no overlap `SELECT array_agg(id) INTERSECT` = `0`; final page `has_more=false`.
* **RLS leakage (anon oracle uniformity):** `anon` `service_ranking_search` returns only `status='published'` items — seed `1 draft` with high signals → `anon` result excludes it; `authenticated` owner reading own `draft` via `service_listing_get` succeeds but not via ranking. `anon` `GET` of unknown `profession_id` → `PLT004` identical to no-results `[]` not error oracle — verified via `code` in `data`.
* **Injection & validation:** `p_query='''; DROP TABLE service_listings; --'` sanitized via `plainto_tsquery` → returns `[]` not DDL. `p_limit 0` → `PLT003`; `p_cursor` with invalid uuid → `PLT003`.
* **Performance `EXPLAIN`:** `EXPLAIN (FORMAT JSON) SELECT * FROM service_ranking_search(...)` → JSON `Plan->Node Type` contains `Bitmap Index Scan` on `service_listings_search_vector_gin` when query present, else `Index Scan` on `service_listings_published_ranking_idx`; assert via `ok((plan->0->'Plan'->>'Node Type') LIKE '%Scan%')`.
* **Completion & activity edge:** Professional with `0 contracts` → `completion_rate=0` not null division error. `last_seen_at IS NULL` → fallback `created_at`.

### 16.2 Dart Unit Tests (`test/unit/engine/recommendation_engine/*`)

* `ranking_formula_test.dart` — `plan(12)`:
  * Fixed 10-listing fixture (mirror pgTAP) → `RankingFormula.compute` scores within `1e-9` of SQL `(SELECT score FROM service_ranking_search WHERE id=?)` (run via `supabase.rpc` in integration, or local `RankingWeights` fixed).
  * `explain()` breakdown sums to `total` within `1e-9`.
  * `w_verify` tier mapping `tier_0→0, tier_3→w_verify`.
  * `bayesian_avg` with `review_count=0` → `prior_mean`; with `n→∞` → `avg_rating`.
  * `decay` half-life 30d: `age=30 → 0.5`, `age=0→1.0`.
  * `ts_rank` zero when `query null`.
  * No `Random`/`DateTime.now()` in score — deterministic.

### 16.3 Repository / Provider Tests (`test/unit/data/*`, `test/widget/*`)

* `supabase_service_search_remote_data_source_test.dart` — mocks `BaseApiService.supabase.rpc` → validates `_guard(mapDataException)` mapping `PLT003→ValidationException`, `PLT004→NotFound`, `PLT999→Internal`, envelope unwrap `success:false → throw`.
* `service_search_repository_impl_test.dart` — `MockLocal hit→return without remote`, `miss→remote→save`, `invalidatePrefix` on `weights_version` bump.
* `marketplace_search_provider_test.dart` — `fake_async` `250ms` debounce, `notifyListeners` on `loaded`, asserts `provider.items.map((e)=>e.id) == remotePage.items.map((e)=>e.id)` **order preserved**, no `sort` call (spied via `isSorted` helper). `error` maps `PLT003` to `HivorrErrorState` message.

### 16.4 Widget No-Resort Guard (`test/widget/marketplace/*`)

* `marketplace_search_screen_no_resort_test.dart` — pumps `ListView` with `MarketplaceSearchProvider` `items=[id3,id1,id2]` in RPC order, asserts `find.text` order equals RPC order (via `tester.widgetList` iteration), not sorted by `avgRating`.

### 16.5 Integration (`test/integration/`) — Staging Only

* `service_ranking_search_integration_test.dart` — real Supabase (`dev` via `supabase_flutter:2.17.2`) seeds via `service_listing_create/publish:452`, `service_review_submit:220` + `service_review_reveal_if_ready:548`, then calls `service_ranking_search` as `anon` and `authenticated` and asserts `items` deterministic + `has_more`. Requires `EP-01-11` `Hive` init + `lib/core/api/api_initializer.dart:1`.

### 16.6 Load / Benchmark (EP-03-20 gate)

* `scripts/bench_ranking.sh` — `supabase.rpc` 100 sequential `service_ranking_search` with `p_query='legal'` against 5k `published` seed, asserts `p95 <400ms` via `hey` or `k6`. Run on Staging (`ENV-003`) before `Production` (`ENV-001..010`).

### 16.7 Static Checks

* `dart analyze` `No issues found!` (no `Colors.*`/raw hex/`fontFamily` per `VISUAL-IDENTITY.md` — auto-fails if `RankingFormula` imports `flutter/material.dart`).
* `grep -r "list.sort.*score\|.reversed.*ranking" lib/` → `0`.
* `supabase db lint` + `pgrst` RLS checks.

## 17. Recommended Implementation Sequence

| Step | Work | Owner | Gate |
|---|---|---|---|
| **0 — Pre-flight** | Verify `EP-03-01` `service_listings` + `023` posture `PASS` + `EP-03-03` aggregates `027 PASS` on `Staging`; `ls supabase/migrations \| tail -5` confirms `20260924090001` tip. `git diff -- supabase/migrations` clean. | Lead | `supabase test db --local 023 024 027 028` `PASS` |
| **1 — Migration (atomic)** | Write `supabase/migrations/<ts>_platform_config_and_ranking.sql` (idempotent `IF NOT EXISTS`, `REVOKE`+`GRANT`, `platform_config` seed, ranking index, `service_ranking_search` `SECURITY INVOKER STABLE` + comments). Local `supabase db reset` + `supabase migration up`. | DB | `psql \d public.platform_config` + `\df service_ranking_search` `security_invoker` |
| **2 — pgTAP posture** | Author `033_platform_config_posture.sql` (`plan 18`) mirroring `023:22`, run `supabase test db --local 033` until `All tests successful.` Include `anon EXECUTE 3` expectation update. | DB | `033` `PASS` |
| **3 — RPC enforcement + fixture** | Author `034_service_ranking_rpc_enforcement.sql` (deterministic 10-listing fixture, weight-tweak, `EXPLAIN`, RLS leakage, cursor, injection). Seed helper `supabase/tests/database/seed/034_ranking_fixture.sql` (pure inserts, no `SECURITY DEFINER`). Run until `plan 32 PASS`. | DB+App | `034` `PASS`, `EXPLAIN` shows `Bitmap Index Scan` |
| **4 — Engine Dart (pure)** | Implement `lib/engine/recommendation_engine/ranking_weights.dart:1` + `ranking_formula.dart:1` + `lib/engine/matching_engine/matching_seam.dart:1` (stub). Unit test `ranking_formula_test.dart` deterministic vs SQL spot-check (import `025` fixture). `dart test test/unit/engine/recommendation_engine/`. | App | `flutter test --coverage` `ranking_formula` `100%` |
| **5 — Data slice** | Implement `lib/data/models/service_listing_dto.dart:1` (+ `fromJson` envelope-parse), `lib/data/mappers/service_listing_mapper.dart:1`, `lib/data/datasources/remote/service_search_envelope_parser.dart:1`, `lib/data/datasources/remote/supabase_service_search_remote_data_source.dart:1` (`_guard` pattern), `lib/data/datasources/local/service_search_local_data_source.dart:1`, `lib/data/repositories/service_search_repository.dart:1` + `service_search_repository_impl.dart:1` (cache-first), `lib/data/providers/marketplace_search_provider.dart:1` (ChangeNotifier, debounce, no resort). Unit tests for each. | App | `flutter test test/unit/data/datasources` `PASS` + `dart analyze` `0 issues` |
| **6 — No-resort widget guard** | Add `test/widget/marketplace/marketplace_search_screen_no_resort_test.dart` asserting RPC order preservation (even without full `discovery_screen`). This is the audit trail `EP-03:308` `widget test asserts results render in RPC order`. | App | `flutter test test/widget/marketplace` `PASS` |
| **7 — Integration & bench** | Deploy to `Staging` (`ENV-003` isolated DB per `ARCHITECTURE.md:164`), run `test/integration/service_ranking_search_integration_test.dart` against `dev` seed, `scripts/bench_ranking.sh` `p95 <400ms`, `supabase test db --local` full `34` suites `PASS`. Demo walkthrough `anon` vs `authenticated` ranking pages. | DevOps+App | `supabase test db` `Result: PASS` + bench `PASS` → ready for `EP-03-07` and `EP-03-20` phase gate |

**Parallelizable after Step 3:** Steps 4 and 5 can start in parallel (engine pure vs data slice both depend only on `platform_config` contract), but Step 6 depends on Step 5.

## 18. Expected Outcome

* A live `public.platform_config` row (`service_ranking_weights`) editable by `service_role` only, versioned via `updated_at` — no hardcoded coefficients in client.
* A single `service_ranking_search` `SECURITY INVOKER STABLE` RPC that, for any `profession_id/query/filters/cursor` combination, returns a **deterministic, paginated, RLS-scoped, `GIN`-backed** ranked page with `score` tie-break `id DESC`. Ordering is provable via pgTAP fixture and `weights_version`.
* A pure Dart `RankingFormula` that mirrors SQL within `1e-9` and enables `explain()` for future UI, with no code path that reorders `items`.
* A repository `cache-first` with `LruCache` window and provider that preserves RPC order — ready for `EP-03-07` FTS composition, `EP-03-08/09` discovery screens, and `EP-03-19` SEO routes without re-implementing ranking.
* Posture: `supabase/tests/database` `34` suites `PASS`, `EXPLAIN` proves index usage, `p95 <400ms` on staging, `dart analyze` `0`, no `Colors.*` regression, and EP-04 `matching_engine` seam preserved. Marketplace trust risk `EP-03:175` retired for Stage 2.

## 19. Definition of Done (DoD)

> Check each box only after executing the verification and observing exact result. Single unchecked box blocks `Completed`.

**Migration & Schema:**

* [ ] File `supabase/migrations/<ts>_platform_config_and_ranking.sql` exists after `20260926090001` tip, idempotent (`IF NOT EXISTS`, `OR REPLACE`, `ON CONFLICT DO NOTHING`), header documents `RANKING FORMULA v1` + `SECURITY INVOKER` + envelope `PLT*` + weights not hardcoded.
* [ ] `public.platform_config` exists: `has_table true`, `relrowsecurity true`, `REVOKE ALL anon,authenticated,service_role` then `GRANT SELECT anon,authenticated` + `GRANT UPDATE service_role` narrow, `INSERT` seeded `service_ranking_weights` defaults sum `~1.0`, `CHECK` JSONB keys + range, `trigger platform_set_updated_at` fires on `UPDATE`, `COMMENT` not null — verified by `033` `is(...) 1` assertions.
* [ ] `service_listings_published_ranking_idx` exists `WHERE status='published'` (new) + `service_listings_search_vector_gin` retained `GIN=1` (`023:189`).
* [ ] No prior table/function/policy mutated — `git diff -- supabase/migrations/202608* supabase/migrations/2026092*` shows only new migration (± `platform_config` additive column `entities.last_seen_at` if added).
* [ ] `service_ranking_search(uuid,text,jsonb,jsonb,int)` exists `SECURITY INVOKER STABLE` `prosecdef false`, `COMMENT` not null, `REVOKE EXECUTE public` + `GRANT EXECUTE anon,authenticated,service_role` (so `anon EXECUTE` count = 3), `search_path=public` pinned — verified by `033` `has_function` + `prosecdef` count still `1` overall.

**Functional:**

* [ ] Seed 10 `published` fixture via `034` — `SELECT service_ranking_search(p_profession_id=>X, p_limit=>10)` returns deterministic `array_agg(id ORDER BY score DESC, id DESC) = '{expected}'` and re-query returns same array.
* [ ] Filter contracts: `rating_min=4.5` excludes `<4.5`; `is_verified_only=true` excludes `is_trade_verified_cache=false`; `price_range` respects `price_min/max` CHECK; `currency_code` filters — each asserts `items` subset via `034`.
* [ ] `ts_rank` path: `p_query='legal drafting'` ranks `legal` title rows higher than `p_query IS NULL` order — `debug_scores` service_role shows `w_relevance>0` only when query present.
* [ ] Cursor: `LIMIT 5` → `has_more=true, next_cursor={score,id}`; second call `p_cursor=next_cursor` → no overlap and `has_more` consistent until final page `false`.
* [ ] `anon` ranking excludes `draft/paused` seed row despite high signals; `authenticated` ranking same exclusion (public read `published` only).
* [ ] Injection: `p_query='''; DROP TABLE ...` → `[]` not DDL; `p_limit 0` → `PLT003`; `p_cursor` bad uuid → `PLT003`.

**Non-Functional:**

* [ ] `EXPLAIN (FORMAT JSON)` for `p_query` present contains `Bitmap Index Scan` on `service_listings_search_vector_gin`; for `p_query IS NULL` contains `Index Scan` on `service_listings_published_ranking_idx` — asserted via `ok(plan->>'Node Type' LIKE '%Scan%')` in `034`.
* [ ] Weights live: `UPDATE platform_config SET value=jsonb_set(value,'{w_rating}','0.05')` service_role → re-query order shifts; revert → order restores (no hardcoded constant).
* [ ] Performance bench on Staging `5k published` seed `p95 <400ms` — `scripts/bench_ranking.sh` `PASS` evidence in `EP-03-20` report draft.

**Dart & Platform:**

* [ ] `lib/engine/recommendation_engine/ranking_formula.dart` pure Dart `compute()` within `1e-9` of SQL scores for fixture; `explain()` sums to total; no `dart:io`, no `flutter/material.dart`, no `Random`, no `DateTime.now()` in scoring — `dart analyze` `0`.
* [ ] `lib/data/datasources/remote/supabase_service_search_remote_data_source.dart` uses `BaseApiService.supabase.rpc` + `_guard(mapDataException)` + `ServiceSearchEnvelopeParser` validates `{success,code,message,data}` and maps `PLT*` — `mockito` test `PASS`.
* [ ] `lib/data/repositories/service_search_repository_impl.dart` cache-first `hit→no remote`, `miss→remote→save`, `invalidatePrefix` on `weights_version` bump — `mockCacheManager` test `PASS`.
* [ ] `lib/data/providers/marketplace_search_provider.dart` `ChangeNotifier` debounce `250ms`, `idle/loading/loaded/error`, `items` assigned verbatim — `fake_async` test asserts `renderOrder == rpcOrder` (no resort) `PASS`.
* [ ] No new `lib/systems/marketplace` screen in this task; any future screen consuming provider must not `sort` — `grep -r "sort.*score" lib/` returns `0` (CI).
* [ ] `dart analyze` + `flutter test` (unit+widget+integration) `All tests passed.`; `lib/core/cache/lru_cache.dart` `maxEntries` enforced (eviction `put` returns `0/1`); `VISUAL-IDENTITY` token assert `ColorScheme.primary == #0B6E99` unaffected (no widget added).

**Tests & Evidence:**

* [ ] `supabase test db --local 033_platform_config_posture.sql` `plan 18` `All tests successful.`
* [ ] `supabase test db --local 034_service_ranking_rpc_enforcement.sql` `plan 32` `All tests successful.` including deterministic array + weight-tweak + leakage matrix.
* [ ] `test/unit/engine/recommendation_engine/ranking_formula_test.dart` `12` asserts `PASS`.
* [ ] `test/widget/marketplace/marketplace_search_screen_no_resort_test.dart` `PASS` (RPC order preserved).
* [ ] Full regression `supabase test db --local` `Files=34, Tests=... PASS` (32 prior + 2 new) — no prior suite regressed.

## 20. Implementation AI Execution Profile

| Attribute | Recommendation |
|---|---|
| **Recommended Coding Reasoning Level** | **Extremely High** |
| **Recommended Planning Reasoning Level** | **Extremely High** (this plan) |

**Justification (per `EP-03:499` distribution — `Extremely High` 5/20):**

* **Technical complexity — Extremely High.** Weighted deterministic SQL with `GIN` + `btree` composite, `bayesian_avg` (`C,m`), `exp` decay, `ts_rank`, keyset `(score,id)`, JSONB weight governance, and `SECURITY INVOKER STABLE` envelope must be versioned and `EXPLAIN`-proven. Mistuning `C` or `half_life` silently biases supply; `OFFSET` vs keyset determines scalability.
* **Business impact — Catastrophic if opaque.** Ranking is marketplace’s fairness primitive per `AGENT.md:7` Deterministic Core Supremacy; biased ordering = trust erosion, regulatory scrutiny, supply churn (`EP-03:175`). `EP-03-20` Go/No-Go depends on `p95 <400ms` + deterministic fixture.
* **Security risk — High.** `anon` `published`-only RLS, `platform_config` `service_role`-only `UPDATE`, `SECURITY INVOKER` posture (definer count must stay `1`), injection via `to_tsquery` must be server-only. Any `SECURITY DEFINER` or client resort reintroduces oracle.
* **Performance sensitivity — High.** Discovery is frequency driver (`Business-Roadmap:219-226`); ranking is hottest read path — `GIN` bitmap, partial index, `LIMIT 50` cap, no N+1, `STABLE` cacheability directly determine `p95`.
* **Data complexity — High.** Six heterogeneous signals across `service_listings`, `service_review_aggregates`, `entity_kyc_levels`, `service_contracts`/`financial_escrow`, `entities`/`entity_devices`, `search_vector` must compose in one `STABLE` transaction without write, with correct null-fallbacks and cold-start fairness.
* **Integration complexity — High.** Must unify `TaxonomyEngine`, `LruCache`, `BaseApiService`, `CacheManager`, provider `ChangeNotifier`, and future `EP-03-07/09/19` consumers without duplicating ordering logic or creating a parallel `lib/ai` ranking path.

No item falls below `High`; `Extremely High` for both planning and coding is required per approved `EP-03:500` (`EP-03-06` listed under `Extremely High` 5).

---

> **Next step:** Approval of this plan → exit read-only mode → write migration `*_<ts>_platform_config_and_ranking.sql` + `033/034` pgTAP + engine Dart slice as Steps 1-5 above. Do not proceed to `EP-03-07` search composition or `EP-03-08/09` discovery screens until `034` deterministic + weight-tweak proofs are `GO`. Wait for my approval before proceeding to implementation.
