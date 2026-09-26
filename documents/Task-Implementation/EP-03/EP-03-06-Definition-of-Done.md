# Definition of Done — EP-03-06: Deterministic Ranking & Matching Engine

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-06 |
| **Task Name** | Deterministic Ranking & Matching Engine |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 2 Deterministic & Search Engines (must precede discovery UI) |
| **Priority** | Critical |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-06 Deterministic Ranking & Matching Engine.md:1-509` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:301-309` |
| **Dependencies** | EP-03-01 `service_listings` (`supabase/migrations/20260921090001_service_marketplace_schema.sql:42`), EP-02-11 `entity_professions.trade_verification_status` + `kyc_tiers` (`20260829090003`), EP-03-03 `service_review_aggregates` (`20260924090001:108`), `platform_*` helpers (`20260819090001:37`) |
| **Delivery Scope** | 1 table `platform_config` + seed `service_ranking_weights` + 1 RPC `service_ranking_search` `SECURITY INVOKER STABLE` + 1 partial index `service_listings_published_ranking_idx` + 2 Dart engine files (`ranking_formula.dart`, `ranking_weights.dart`) + seam `matching_seam.dart` + 7 data-layer files (DTO/mapper/remote parser/local/repo/provider) + 2 pgTAP suites `033`/`034`. **Zero** `lib/ai` import, **zero** client-side sort. |
| **Guardrails** | `AGENT.md:7` Deterministic Core Supremacy + `AGENT.md:13` Rule 4 Database-First/Zero-Trust + `AGENT.md:6` Proprietary Logic Protection + `ARCHITECTURE.md:160` DB-First |

**How to use this document:** Check each box only after executing the listed verification (`psql` query, `supabase test db --local`, `curl /rpc/service_ranking_search`, `dart test`/`flutter test`, `EXPLAIN`) and observing the exact expected result. A single unchecked box blocks `Completed` status.

---

## 2. Functional Verification

### 2.1 Required Functionality

- [ ] **Deterministic ranked browse** — `anon` and `authenticated` can call `service_ranking_search(p_profession_id uuid?, p_query text?, p_filters jsonb?, p_cursor jsonb?, p_limit int?)` and receive `PLT000` with `data:{items:[{id, entity_id, profession_id, industry_id, slug, title, description, pricing_type, price_min/max, currency_code, avg_rating, review_count, is_trade_verified_cache, published_at, profession_slug/name, industry_slug/name, score}], has_more bool, next_cursor {score numeric, id uuid}?, weights_version timestamptz}`. `items` are ordered `score DESC, id DESC` deterministically for identical inputs; re-query with same params returns identical `array_agg(id ORDER BY score DESC, id DESC)`.
- [ ] **Weight-driven scoring** — `score = w_verify*kyc_tier_weight + w_rating*bayesian_avg + w_completion*completion_rate + w_recency*decay(now()-published_at) + w_relevance*ts_rank + w_activity*login_recency` computed server-side from `public.platform_config` `key='service_ranking_weights'` `value` JSONB. `w_*` read per call (`coalesce` defaults if row missing); no hardcoded constant in RPC body (verified by `grep -n "0.28\|0.26" supabase/migrations/*_platform_config_and_ranking.sql` → 0 outside seed comment).
- [ ] **Signal completeness — 6 verifiable signals:** `kyc_tier_weight` via `CASE tier_code WHEN 'tier_3' THEN 1.0 ...` + `is_trade_verified_cache` bonus; `bayesian_avg = (C*m + avg_rating*review_count)/(C+review_count)` using `service_review_aggregates` (`C=5,m=3.0` from weights); `completion_rate = completed|closed / total` per `(professional_entity_id, profession_id)` via `service_contracts` lateral (or escrow variant, documented); `decay = exp(-ln2*age_days/half_life)` on `published_at`; `ts_rank = ts_rank(search_vector, plainto_tsquery('english', p_query), 32)` normalized `0..1`; `login_recency = exp(-age_days/14)` on `coalesce(last_seen_at, created_at)`. Null `review_count=0` → `prior_mean`; `0 contracts → 0`; `p_query null → ts_rank 0`.
- [ ] **Published-only browse** — Ranking scans `WHERE status='published'` only (RLS `service_listings_select_public:381`). `draft/paused/archived/reported` rows never appear even to owner via this RPC (owner private read remains via `service_listing_get:1018` only).
- [ ] **FTS relevance** — `p_query` sanitized via `plainto_tsquery('english', btrim(p_query))` server-side only; `search_vector @@ plainto_tsquery` filtered + `ts_rank` contribution; uses existing `service_listings_search_vector_gin` `GIN(search_vector)` (`20260921090001:122`) trigger `service_listings_search_vector_update():130` re-derives `search_vector`.
- [ ] **Keyset pagination** — `p_cursor {score, id}` lexicographic `WHERE (score, id) < (cursor_score, cursor_id)` + `ORDER BY score DESC, id DESC LIMIT p_limit+1` → `has_more`. Unknown/foreign `p_cursor` → exhausted `{items:[], has_more:false}` (no `PLT004` oracle), mirroring `service_listing_list_mine:1149`. No `OFFSET`.
- [ ] **Filtering** — `p_filters jsonb` validated schema `{profession_id?, industry_id?, price_min?, price_max?, currency_code? (active), rating_min? 0-5, is_trade_verified_only? bool}`; `price_max >= price_min`; inactive `profession_id` → `PLT004`; `rating_min 4.5` excludes `<4.5`; `is_verified_only true` excludes `is_trade_verified_cache=false`.
- [ ] **Public `anon` browse** — `curl -H "apikey: anon" POST /rest/v1/rpc/service_ranking_search` returns `PLT000` ranked published items without JWT (RLS-scoped). Same rowset as `authenticated` for same filters (no privileged leakage).

### 2.2 Expected Workflows (End-to-End)

- [ ] **Cold browse (no query)** — `anon` calls `service_ranking_search(p_limit=>10)` with `p_query null` → ranked page `items 10, has_more bool, next_cursor?` ordered by bayesian+decay+verification mix; `ts_rank` component `0` for all. Second call with `next_cursor` returns next page with `0` overlap (`SELECT array_agg(id) INTERSECT` → 0).
- [ ] **Query relevance** — Same `profession_id` + `p_query='legal drafting'` ranks `title~'legal drafting'` rows above same `profession_id` null-query order; `service_role` `debug_scores` (when `p_debug`) shows `w_relevance>0` only with query.
- [ ] **Deterministic replay** — Seed `10 published` fixture (`034`): `tier_3 verified 4.9×2`, `tier_0 5.0 low completion`, `old published_at 3.5`, `high ts_rank` etc. Call twice `SELECT array_agg(id ORDER BY score DESC, id DESC) FROM service_ranking_search(p_profession_id=>X)` → both arrays `= '{expected uuid[]}'` (pgTAP asserts).
- [ ] **Weight-tweak shift proof** — `service_role` `UPDATE platform_config SET value=jsonb_set(value,'{w_rating}','0.05') WHERE key='service_ranking_weights'` → re-query order shifts (high-rating item drops ranks); `jsonb_set` back → order restores. Proves weights live via `platform_config`.
- [ ] **Filtered browse** — `p_filters:{rating_min:4.5, price_min:1000, price_max:5000, is_verified_only:true}` excludes non-matching rows; `currency_code='USD'` mismatched excludes `NGN` rows (checked via `034` subset asserts).
- [ ] **Cursor exhaustion** — Last page `has_more=false, next_cursor null`; calling with `next_cursor null` + `p_cursor` last id returns `[]`.

### 2.3 Success Conditions

- [ ] Every `service_ranking_search` success returns envelope `{success:true, code:'PLT000', message:'Ranked results retrieved.', data:{items, has_more, next_cursor, weights_version}}` per `20260829100004:16`.
- [ ] `score` is `numeric(10,6)` total order `score DESC, id DESC`; tie-break `id DESC` guarantees total determinism (no float flip).
- [ ] `search_vector` never appears in `data.items` projection (whitelisted columns only).
- [ ] `weights_version = platform_config.updated_at` returned per call enables client `invalidatePrefix` without `ETag`.
- [ ] Dart `RankingFormula.compute/explain` mirrors SQL within `1e-9` for fixture and `explain()` sum equals `total` within `1e-9`.

### 2.4 Error Handling Scenarios

- [ ] `p_profession_id` unknown or inactive `professions.is_active=false` → `PLT004` identical to no-results (no oracle distinction).
- [ ] `p_query` stopwords-only (`'the and'`) → treated as `null` (`ts_rank 0`), not error.
- [ ] `p_limit null` or `NOT BETWEEN 1 AND 50` → `PLT003` `Limit must be between 1 and 50.`
- [ ] `p_cursor` invalid JSON (`{score:"bad", id:"not-uuid"}`) or `score` non-numeric → `PLT003`.
- [ ] `p_filters` invalid schema: `rating_min 6` or `price_max < price_min` or `currency_code 'XYZ' inactive` → `PLT003`.
- [ ] `p_query` SQL injection `'''; DROP TABLE service_listings; --` sanitized via `plainto_tsquery` → `[]` not DDL; verified `SELECT count(*) FROM service_listings` unchanged.
- [ ] Unknown `service_listings` cursor `id` → exhausted `{items:[], has_more:false}` not `PLT004`.

### 2.5 Important User Interactions

- [ ] Same query re-executed shows no shimmer reorder — `items` replace once, `ListView key: ValueKey(id)` preserves position (future screen `EP-03-09` contract; this task proves via widget no-resort test).
- [ ] Empty result set renders provider `isEmpty=true` → `HivorrEmptyState` `No services yet` / `Try another filter` (provider flag; no screen in this task, test asserts flag).
- [ ] `PLT003/004` errors surfaced as `HivorrErrorState` with `Retry` via existing `RetryInterceptor` (`lib/core/api/api_client/retry_interceptor.dart:1`).
- [ ] All RPC is CORS-accessible via PostgREST `/rpc/service_ranking_search` with `apikey` `anon` or `Authorization: Bearer <JWT>`; `STABLE` cacheable `Cache-Control: public, max-age=60` for `anon` same-query.

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **Server-side enforcement** (`AGENT.md:13` Rule 4, `ARCHITECTURE.md:160`): All `score` computation, weight read, `ts_rank`, bayesian, decay inside `SECURITY INVOKER STABLE` RPC. Zero `score` sort or `amount` reduce in `lib/systems` (CI `grep -r "sort.*score\|reversed.*ranking" lib/` → 0).
- [ ] **Deterministic Core Supremacy** (`AGENT.md:7` Rule 1, `AGENT.md:6`): Ranking resides in versioned SQL `/* RANKING FORMULA v1 */` + `platform_config` row; `lib/ai/*` never imported in ranking path (`grep -r "lib/ai" lib/engine/recommendation_engine lib/data/datasources` → 0). `RankingFormula` is display-only mirror.
- [ ] **Domain separation** (`ARCHITECTURE.md:39-173` lib schema): `platform_config` lives in `supabase/migrations` only; Dart files in `lib/engine/recommendation_engine:71` (`recommendation_engine` = ranking), `matching_engine` left as documented seam (no logic), `search_engine` not mutated this task, `systems/marketplace` screens not created (Stage 3 per plan `§12`).
- [ ] **Single Supabase accessor** (`ARCHITECTURE.md:56`): Remote DS injects `BaseApiService` (`dio, supabase, exceptionMapper`) only via `lib/core/api/services/base_api_service.dart:1`; never constructs `SupabaseClient`.
- [ ] **No third design hue / Visual Identity** (`AGENT.md:18` Rule 5): No `Colors.*` / raw hex / `fontFamily` in `ranking_formula.dart` or data layer; `dart analyze` + `ThemeData` token assert `ColorScheme.primary == #0B6E99` remains green (`VISUAL-IDENTITY.md:3-250`).

### 3.2 Required System Behavior

- [ ] **Execution model:** `service_ranking_search(uuid,text,jsonb,jsonb,int)` is `SECURITY INVOKER STABLE` (`pg_proc.prosecdef=false`, `provolatile='s'`), `search_path=public` pinned, `COMMENT ON FUNCTION` not null stating `SECURITY INVOKER STABLE — deterministic ranking v1`.
- [ ] **Volatility:** `STABLE` (PostgREST cacheable, retry-safe via `retry_interceptor`); never `VOLATILE` (no writes).
- [ ] **Envelope:** Returns `jsonb_build_object('success',bool,'code',text,'message',text,'data',jsonb)` with `PLT000/003/004/999` vocabulary per `20260829100004:16`.
- [ ] **Weights:** `SELECT value FROM platform_config WHERE key='service_ranking_weights'` at RPC top (or `CROSS JOIN LATERAL`) with `coalesce` fallback defaults; `updated_at` returned as `weights_version`.
- [ ] **No AI override:** Provider `MarketplaceSearchProvider` assigns `items = data.items` verbatim; widget test asserts `renderOrder == rpcOrder` (EP-03-06:308).

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `service_listings` fact table (`20260921090001:42`) | `SELECT count(*) FROM service_listings WHERE status='published'` ≥ fixture 10; `search_vector` `NOT NULL` for `published`; ranking `EXPLAIN` uses `Bitmap Index Scan` on `service_listings_search_vector_gin`; `search_vector` never returned in `data.items` |
| `service_review_aggregates` (`20260924090001:108`) | `JOIN service_review_aggregates USING (professional_entity_id, profession_id)` feeds `bayesian_avg`; `review_count=0` → `prior_mean` path exercised |
| `industries/professions` (`20260821090001:15`) | `p_profession_id` FK `RESTRICT` → inactive `profession_id` yields `PLT004`; `TaxonomyEngine.browseIndustries/browseProfessions` still deterministic `sortOrder` for filter validation |
| `kyc_tiers / entity_professions` (`20260829090003`) | `w_verify` maps `tier_code` via `CASE` or `sort_order`; `is_trade_verified_cache true` for `published` (`20260921090001:65`) bonus exercised |
| `service_contracts + financial_escrow` (`20260923090001:43`, `20260829100004:191`) | `completion_rate` lateral `COUNT(completed\|closed)/COUNT(total)` per `(professional_entity_id, profession_id)` with no `Seq Scan` on `service_contracts_professional_idx`; `0 contracts → 0` not division error |
| `entities` / `entity_devices.last_seen_at` | `login_recency` uses `coalesce(last_seen_at, created_at)`; additive `entities.last_seen_at` column present if chosen (`\d public.entities` → `last_seen_at timestamptz` or `GREATEST(max(device.last_seen_at))` join documented) |
| `platform_config` | `SELECT value->>'w_verify' FROM platform_config WHERE key='service_ranking_weights'` → `0.28`; sum `w_*` `~1.0` |
| `Core` `LruCache/CacheManager` (`lib/core/cache/lru_cache.dart:12`) | `CacheManager.put('service_search:${sha}', page, ttl:5m)` + `get` + `invalidatePrefix('service_search:')` on `weights_version` bump; `maxEntries 50` eviction `0/1` |
| `BaseApiService + envelope` (`lib/core/api/services/base_api_service.dart:1`) | `SupabaseServiceSearchRemoteDataSource._guard(mapDataException)` maps `PLT*`; `ServiceSearchEnvelopeParser.unwrapData` validates `{success,code,message,data}` |

### 3.4 Technical Requirements

- [ ] Migration header `/* RANKING FORMULA v1 — 2026-09-26 — weights via platform_config service_ranking_weights */` + `SECURITY INVOKER` + envelope + `weights not hardcoded` documented.
- [ ] Idempotent migration: `IF NOT EXISTS / DROP IF EXISTS / CREATE OR REPLACE / ON CONFLICT(key) DO NOTHING` throughout (`20260921090001:38` pattern); `ls supabase/migrations | tail -n 5` shows new `*_platform_config_and_ranking.sql` after `20260926090001` tip.
- [ ] Exactly 1 new table `platform_config` + 1 new RPC `service_ranking_search` + 1 new index `service_listings_published_ranking_idx WHERE status='published'`; no prior table/function/policy mutated (`git diff -- supabase/migrations/202608* supabase/migrations/2026092*` → only new file ± `entities.last_seen_at` additive column).
- [ ] `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` baseline + explicit `GRANT EXECUTE service_ranking_search TO anon, authenticated, service_role` (so `anon` executable count `2→3` in `023:290`, documented deviation).
- [ ] Pure Dart engine: `lib/engine/recommendation_engine/ranking_formula.dart:1` + `ranking_weights.dart:1` + `matching_seam.dart:1` only; no `lib/systems/marketplace` screen created.

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] No rows inserted into `service_listings` / `service_review_aggregates` / `financial_*` by ranking RPC (read-only). Verified `SELECT count(*) FROM service_listings` before/after 10 `service_ranking_search` calls unchanged.
- [ ] `platform_config` `INSERT ... ON CONFLICT(key) DO NOTHING` seed creates single row `('service_ranking_weights', '{w_verify:0.28,...}', 'Deterministic ranking v1')` with `created_at/updated_at` not null.

### 4.2 Data Updates

- [ ] `platform_config` `UPDATE (value, description) ... WHERE key='service_ranking_weights'` by `service_role` increments `updated_at` via `platform_set_updated_at` trigger; `weights_version` in next `service_ranking_search` response equals new `updated_at`; client `MarketplaceSearchProvider` invalidates `service_search:*` prefix on mismatch.
- [ ] No writes to `service_listings` / `aggregates` / `escrow` via ranking path.

### 4.3 Data Relationships

- [ ] `service_listings.profession_id → professions.id RESTRICT` — `SELECT sl.id FROM service_listings sl LEFT JOIN professions p ON p.id=sl.profession_id WHERE p.id IS NULL` → 0.
- [ ] `service_listings` rows for ranking always have `industry_id = professions.industry_id` (trigger `service_listings_search_vector_update():138` re-derives) — future industry seed (`20260829090001` insert) auto-participates, no schema change.
- [ ] `service_review_aggregates(professional_entity_id, profession_id) PK` — `SELECT count(*) FROM service_review_aggregates WHERE avg_rating NOT BETWEEN 0 AND 5` → 0.

### 4.4 Data Accuracy

- [ ] `bayesian_avg = (5*3.0 + avg_rating*review_count)/(5+review_count)` recomputed in Dart within `1e-9` of SQL `score` component (`ranking_formula_test.dart` `plan 12`).
- [ ] `decay = exp(-ln2*age_days/30)` with `age_days = extract(epoch FROM now()-published_at)/86400`; `age 30 → 0.5, age 0 → 1.0` verified unit test.
- [ ] `ts_rank` `0` when `p_query IS NULL`; non-zero when query matches `search_vector` (fixture high `ts_rank` row outranks null-query order).
- [ ] `score numeric(10,6)` no float tie-flip; `ORDER BY score DESC, id DESC` total order stable.

### 4.5 Data Integrity

- [ ] `platform_config` CHECKs hold: `key ~ '^[a-z_]+$'`, `value ?& array['w_verify','w_rating','w_completion','w_recency','w_relevance','w_activity']`, each `w_* 0..1`, sum `0.999..1.001`, `bayesian_prior_*` in range, `half_life >0` — `SELECT count(*) FROM platform_config WHERE NOT (value ? 'w_verify')` → 0.
- [ ] No duplicate `service_ranking_search` scoring path — `Grep -r "w_verify.*kyc\|bayesian_avg" lib/` outside `ranking_formula.dart` → 0 (CI).

---

## 5. Security Verification

### 5.1 Authentication

- [ ] `service_ranking_search` without JWT **succeeds** `PLT000` with published rows (public browse) — `curl -H "apikey: <anon>" POST /rpc/service_ranking_search '{}' ` → `200` `success:true`.
- [ ] `platform_config` direct `PATCH /rest/v1/platform_config` without `service_role` key → `42501` / `PGRST` unauthorized (no client weight tamper).

### 5.2 Authorization

- [ ] `REVOKE EXECUTE` baseline + `GRANT EXECUTE service_ranking_search TO anon, authenticated, service_role` — `SELECT count(*) FROM information_schema.routine_privileges WHERE grantee='anon' AND routine_name='service_ranking_search'` → 1; `authenticated` → 1; `service_role` → 1.
- [ ] Overall `anon` executable `service_%` count now `3` (`service_listing_get`, `service_review_get_for_listing`, `service_ranking_search`) — `023:290` expectation updated from 2→3 and documented.
- [ ] `platform_config` `GRANT UPDATE(service_role)` only — `has_column_privilege('authenticated','public.platform_config','value','UPDATE')` → false; `has_column_privilege('service_role','public.platform_config','value','UPDATE')` → true.

### 5.3 Access Control

- [ ] **Tables:** `relrowsecurity true` on `platform_config` (`SELECT relrowsecurity FROM pg_class WHERE relname='platform_config'` → true) and `service_listings` (`023:40` `count 3` now `4` with new table, posture `033` asserts `4`).
- [ ] **Policies:** `platform_config_select USING (true)` for `SELECT anon,authenticated`; `platform_config_update USING (current_user IN ('service_role','postgres'))` for update (mirrors `service_listing_unpublish:951`); `service_listings_select_public (status='published')` + `service_listings_select_own (entity_id=auth.uid())` (`20260921090001:381`) still enforce published-only ranking.
- [ ] **`service_role` bypass** — no RLS block for `service_role` on `platform_config` update (verified service_role `UPDATE` succeeds).

### 5.4 Sensitive Data Protection

- [ ] No `search_vector` returned in `data.items` (whitelisted projection — verified `SELECT jsonb_agg(item) FROM service_ranking_search → items::text LIKE '%search_vector%'` → false).
- [ ] No `legal_name`, `document_path`, `payer_name` (`20260829100004:146` private) in ranking projection; logs redacted via `lib/core/logging/pii_redactor.dart:1` (`entity_id/email` masked).
- [ ] No `weight` update payload leaked to `anon` beyond `weights_version` (debug `debug_scores` only when service_role).

### 5.5 Security Rules

- [ ] **Deterministic Core Supremacy** (`AGENT.md:7`, Rule 1): `grep -r "RankingFormula.*sort\|items.sort" lib/data/providers lib/systems` → 0; provider assigns verbatim (`034` widget no-resort test `PASS`).
- [ ] **Database-First / Proprietary Logic Protection** (`AGENT.md:13` Rule 4, `AGENT.md:6`): No proprietary weight formula in Dart beyond mirror arithmetic; all ranking math gated by `SECURITY INVOKER` RLS. `RankingFormula` imports neither `supabase` nor `BaseApiService`.
- [ ] **No `SECURITY DEFINER` expansion:** `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_%' AND prosecdef=true` → 1 (only `service_review_reveal_if_ready:541`, posture `023:216`).
- [ ] **Injection:** `p_query` never interpolated; `plainto_tsquery('english', btrim(p_query))` + `AND` param binding only (verified by injection test in `034`).
- [ ] **Realtime exclusion:** `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='platform_config'` → 0; existing `service_listings`/`service_review_aggregates` still `0` (`023:244`).

---

## 6. Performance Verification

- [ ] `service_listings_search_vector_gin` `Bitmap Index Scan` for `p_query present` — `EXPLAIN (FORMAT JSON) SELECT * FROM service_ranking_search(p_query=>'legal')` JSON `Plan->Node Type` contains `Bitmap Index Scan`.
- [ ] `service_listings_published_ranking_idx` `Index Scan` for `p_query null` ordered filter — `EXPLAIN` for null query contains `Index Scan` on `service_listings_published_ranking_idx` (not `Seq Scan`).
- [ ] `service_review_aggregates` PK `Index Only Scan` for bayesian path.
- [ ] `service_contracts` + `financial_escrow` lateral uses existing `financial_escrow_payee_idx:224` `Index Scan` (no per-row Seq Scan; no N+1).
- [ ] **Pagination is keyset, not OFFSET:** `service_ranking_search` fetches `p_limit+1` and trims; `EXPLAIN` shows no `Offset` node.
- [ ] **Budget:** `scripts/bench_ranking.sh` 100 sequential `service_ranking_search(p_query=>'legal')` against `5k published` seed on Staging → `p95 <400ms` (`hey`/`k6` report attached, EP-03:56 gate).
- [ ] **Client boundedness:** `LruCache maxEntries 50, defaultTtl 5m`; `CacheManager.invalidatePrefix('service_search:')` on `weights_version` change; `Hive` warm cache for browse not duplicated (`lib/core/database/database_config.dart:1` `driverType hive`).

---

## 7. Testing Verification

### 7.1 Manual Testing

- [ ] As `anon` (incognito) call `service_ranking_search(limit 5)` → 5 ranked items, `has_more` consistent, `next_cursor` navigates to page 2 with 0 overlap.
- [ ] As `professional A (tier_3, 4.8, 10 reviews)` vs `professional B (tier_0, 5.0, 0 reviews)` with same `profession_id` → A outranks B (verification + bayesian > cold high rating).
- [ ] `service_role` updates `platform_config` weight via `psql UPDATE ... jsonb_set` → next browse order shifts as documented; revert → order restores.
- [ ] `Postman` `STABLE` cache: repeat same `anon` query returns `Cache-Control: public, max-age=60` and identical `weights_version`.

### 7.2 Automated Testing

- [ ] `supabase test db --local supabase/tests/database/033_platform_config_posture.sql` — `has_table` 1, `relrowsecurity` 1, `SECURITY DEFINER` overall count still 1, `service_%` RPC count 20 (19 prior `023:237` + `service_ranking_search 1`), `has_index` `GIN` 1 + `service_listings_published_ranking_idx` 1, `REVOKE` 0 write for `anon/authenticated`, `GRANT SELECT anon/authenticated + UPDATE service_role`, 4 CHECKs, `COMMENT` not null, `anon EXECUTE` 3 — `plan 18 All tests successful.`
- [ ] `supabase test db --local supabase/tests/database/034_service_ranking_rpc_enforcement.sql` — deterministic `array_agg` fixture, weight-tweak shift, filter subset asserts, `ts_rank` high vs null, cursor `has_more` + no overlap, RLS `draft` excluded for `anon`, injection sanitized `[]`, `p_limit 0 → PLT003`, `p_cursor bad → PLT003`, `EXPLAIN Bitmap/Index Scan`, `0 contracts → 0`, `last_seen_at null → fallback` — `plan 32 All tests successful.`
- [ ] `dart test test/unit/engine/recommendation_engine/ranking_formula_test.dart` — 12 asserts: `compute` within `1e-9` of SQL, `explain` sum, `w_verify` tier map, `bayesian` cold/warm, `decay 30d→0.5`, `ts_rank zero when null`, determinism (no `Random`/`now()`) — `PASS`.
- [ ] `dart test test/unit/data/datasources/supabase_service_search_remote_data_source_test.dart` — `mockito` `supabase.rpc` → `_guard(mapDataException)` `PLT003→ValidationException`, envelope `success:false → throw`, `unwrapData` shape — `PASS`.
- [ ] `dart test test/unit/data/repositories/service_search_repository_impl_test.dart` — `MockLocal hit→no remote`, `miss→remote→save`, `invalidatePrefix` on `weights_version` bump — `PASS`.
- [ ] `dart test test/unit/data/providers/marketplace_search_provider_test.dart` — `fakeAsync 250ms` debounce, `notifyListeners` on `loaded`, `order == rpcOrder` no `sort` spy, `error→HivorrErrorState` — `PASS`.
- [ ] `flutter test test/widget/marketplace/marketplace_search_screen_no_resort_test.dart` — `ListView` `items=[id3,id1,id2]` RPC order → `find.text` iteration equals RPC order, not `avgRating` sorted — `PASS`.
- [ ] `flutter test test/integration/service_ranking_search_integration_test.dart` (Staging `dev` seed via `service_listing_create/publish:452` + `service_review_submit:220` then `service_ranking_search` as `anon/authenticated`) — deterministic + `has_more` — `PASS`.
- [ ] Static: `dart analyze` `No issues found!`; `grep -r "list.sort.*score\|reversed.*ranking\|lib/ai" lib/` → 0; `supabase db lint` → 0 RLS violations.

### 7.3 Edge Cases

- [ ] `profile` `0 reviews` → `bayesian_avg = prior_mean 3.0` not `null` or `0`; still rankable mid-list.
- [ ] `professional 0 contracts` → `completion_rate 0` not division-by-zero; `GREATEST` fallback.
- [ ] `entities.last_seen_at IS NULL` → `login_recency` uses `created_at` fallback.
- [ ] `p_query` empty string / whitespace → treated as `null` (`ts_rank 0`) not error.
- [ ] Tie `score` identical (e.g., same signals) → `id DESC` tie-break ensures total order reproducible.

### 7.4 Failure Scenarios

- [ ] `platform_config` row deleted → RPC uses `coalesce` defaults (`w_verify 0.28` etc.) and still returns `PLT000` ranked page (graceful bootstrap) not `PLT999`.
- [ ] `platform_config` `value` corrupt (`w_verify 1.5` violating CHECK) → `UPDATE` rejected by CHECK `0..1` before ranking ever reads bad weight; prior valid `weights_version` still served.
- [ ] Supabase `rpc` 5xx / network timeout → `DataExceptionMapper` `PLT999` with `Retry` via `RetryInterceptor`; provider `error` state not stale `loaded`.
- [ ] `CacheManager` full (`maxEntries 50`) → LRU evicts oldest `service_search:` entry (`put` returns `1`), no OOM.

---

## 8. User Acceptance Verification

- [ ] As a **consumer** browsing `anon` `/s/:profession_slug` (future `EP-03-09` screen consuming this provider), ranked list feels fair: verified `tier_3` pros with `4.7+` near top, new `0-review` verified mid-list not buried, old `30d+` posts decay behind recent.
- [ ] As a **professional** creating `published` listing via `EP-03-08` flow, listing appears in next `anon` ranked page within `60s` `STABLE` cache window and its `score` reflects verification + rating, not manual sorting.
- [ ] As **auditor**, `psql SELECT pg_get_functiondef('public.service_ranking_search'::regproc)` shows versioned `RANKING FORMULA v1` comment + weight read + `ts_rank` + `exp` expressions; `SELECT * FROM platform_config WHERE key='service_ranking_weights'` shows documented defaults and `CHECK` prevents `w_verify 2.0`.
- [ ] Zero AI reordering surprise — reviewing provider code confirms `items` verbatim assignment; any `lib/ai` suggestion groups but never `sort` (accepted per `AGENT.md:7`).

---

## 9. Final Approval Checklist

| # | Condition | Evidence Required | Status |
|---|---|---|---|
| 1 | Migration `*_platform_config_and_ranking.sql` after `20260926090001` with `RANKING FORMULA v1` header + `SECURITY INVOKER STABLE` + envelope `PLT*` + weights not hardcoded | `ls -l supabase/migrations \| tail -n 5` + `grep "RANKING FORMULA v1" supabase/migrations/*_platform_config_and_ranking.sql` | ☐ |
| 2 | `public.platform_config` exists `relrowsecurity true` + `REVOKE ALL` + `GRANT SELECT anon,authenticated` / `UPDATE service_role` + 4 CHECKs + seed `service_ranking_weights` sum `~1.0` + `COMMENT` | `supabase test db --local 033` `plan 18 All tests successful.` | ☐ |
| 3 | `service_listings_published_ranking_idx WHERE published` exists + `service_listings_search_vector_gin` retained `GIN=1` + optional `entities_last_seen_at_idx` if added | `033` `is((SELECT count(*) FROM pg_indexes WHERE indexname='service_listings_published_ranking_idx'),1)` `PASS` + `\di` | ☐ |
| 4 | `service_ranking_search(uuid,text,jsonb,jsonb,int)` exists `SECURITY INVOKER STABLE` `prosecdef false` `anon,authenticated,service_role` (`anon` count `3`) + `COMMENT` + `REVOKE baseline` | `033` `has_function` + `has_function_privilege('anon','public.service_ranking_search...','EXECUTE') true` `PASS` | ☐ |
| 5 | Deterministic fixture `10 published` array `= '{expected}'` + weight-tweak shifts order → revert restores | `034` `plan 32 All tests successful.` `is(array_agg, '{expected}')` + `is(same query twice, identical)` | ☐ |
| 6 | Filtered `ts_rank` / `rating_min` / `is_verified_only` / `currency` subset asserts + cursor pagination no overlap + injected `DROP` sanitized + `p_limit`/`p_cursor` `PLT003` | `034` `EXIT:0` (subset + injection checks) | ☐ |
| 7 | RLS `anon published-only` + `draft` excluded + `anon unknown profession → PLT004` oracle uniformity + `unknown cursor exhausted` + `search_vector` not returned + `Realtime` `0` + `prosecdef overall 1` | `034` `PLT004` identical + `pg_publication_tables` `0` + `search_vector` not in `data.items` | ☐ |
| 8 | `EXPLAIN Bitmap Index Scan` on `GIN` when query present, `Index Scan` on ranking partial when null + `p95 <400ms` on `5k` seed Staging | `034` `ok(Node Type LIKE '%Scan%')` + `scripts/bench_ranking.sh` `p95 <400ms` artifact | ☐ |
| 9 | Dart pure engine `ranking_formula.dart` `1e-9` mirror + `explain` sum + 6 signals + no `Random/now` + provider `renderOrder==rpcOrder` + repository cache-first | `dart test test/unit/engine/recommendation_engine/ranking_formula_test.dart` `12 PASS` + provider/widget `PASS` | ☐ |
| 10 | Remote `_guard(mapDataException)` `PLT*` mapping + repository `MockLocal` hit/miss/invalidate + `dart analyze No issues` + `grep sort lib` `0` + `Theme` token `ColorScheme.primary == #0B6E99` | `flutter test test/unit/data` `PASS` + `dart analyze` + `git diff --stat` `no Colors.*` | ☐ |
| 11 | Full regression `supabase test db --local` `Files=34, Tests=...` `PASS` (32 prior + 2 new) + `supabase db lint` `0` violations | `supabase test db --local` `Result: PASS` | ☐ |
| 12 | No `lib/ai` ranking import, no client resort, no new screen, no prior DDL mutated (`git diff --stat` only new migration + additive column) | `git status --porcelain` `1 migration + 7 Dart + 2 tests` + `grep lib/ai` `0` | ☐ |
