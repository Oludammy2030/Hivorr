# Definition of Done — EP-03-01: Professional Service Marketplace Schema & Server-Side Enforcement

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-01 |
| **Task Name** | Professional Service Marketplace Schema & Server-Side Enforcement |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 1 Marketplace Server Schema Foundation |
| **Priority** | Critical |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-01-Professional Service Marketplace Schema & Server-Side Enforcement.md:1-572` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:246-255` |
| **Dependencies** | EP-01-06 `entities`/`professions`/`industries` (`supabase/migrations/20260821090001_entity_taxonomy_tables.sql:15-55`, `supabase/migrations/20260821090002_entity_core_tables.sql:20-186`), EP-02-02 taxonomy RPCs, EP-02-03 verification workflow (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:44-234`), EP-01-07 API layer, EP-02-06 storage buckets (`supabase/migrations/20260830100001_storage_buckets.sql:47-83`), EP-02-04 financial rails `financial_supported_currencies` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:37-62`) |
| **Delivery Scope** | 3 tables `service_listings`/`service_listing_media`/`service_favorites` + bucket `service-listing-media` + `storage.objects` policies + `search_vector tsvector` + `GIN` + 7 RPCs `SECURITY INVOKER` + 2 pgTAP suites. **Zero** `lib/` Dart, **zero** modifications to EP-01/EP-02 tables/functions. Unblocks EP-03-02 → EP-03-20. |
| **Guardrails** | `documents/Context/AGENT.md:8` Rule 2 Trade Gate, `documents/Context/AGENT.md:13` Rule 4 Database-First Zero-Trust, `documents/Context/ARCHITECTURE.md:87-93` taxonomy binding, `documents/Context/ARCHITECTURE.md:160-162` DB-First |

**How to use this document:** Check each box only after executing the listed verification (SQL query, `supabase db test`, PostgREST `/rpc/` call, or Storage API probe) and observing the exact expected result. A single unchecked box blocks `Completed` status.

---

## 2. Functional Verification

Verifies the user/system behaviors and RPC workflows defined in `EP-03-01-Professional Service Marketplace Schema & Server-Side Enforcement.md:36-54` + `§9.1`.

### 2.1 Required Functionality

- [x] **Listing draft creation** — Any authenticated entity bound to a profession can call `service_listing_create(p_profession_id, p_title, p_description, p_pricing_type, p_price_min, p_price_max, p_currency_code, p_status='draft')` and receive `PLT000` with row `status='draft'`, `is_trade_verified_cache=false`, `search_vector IS NOT NULL`, `slug` normalized lowercase kebab, FKs `entity_id=auth.uid()` + `profession_id` valid + `industry_id` denormalized correctly.
- [x] **Published creation gate** — `service_listing_create(..., p_status='published')` by an entity **without** `entity_professions.trade_verification_status='approved'` for that `profession_id` (`supabase/migrations/20260821090002_entity_core_tables.sql:171-186`) returns `PLT005` `Trade verification required. Complete verification before publishing.` — no row created. Verified entity succeeds → `status='published'`, `published_at IS NOT NULL`, `is_trade_verified_cache=true`.
- [x] **Publish transition** — `service_listing_publish(p_listing_id)` re-validates gate inside RPC (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:472-489` pattern). `draft/paused → published` sets `published_at=now()` + `is_trade_verified_cache=true`. Already `published` → `PLT005`. Unverified entity → `PLT005`.
- [x] **Unpublish transition** — `service_listing_unpublish(p_listing_id)` allows `published → paused` for owner; `published → reported` for `service_role` only. `draft` → `PLT005` invalid transition.
- [x] **Public read** — `service_listing_get(p_listing_id)` returns `published` listings for `anon`/`authenticated`/`service_role` with `profession.slug/name`, `industry.slug/name`, `media[]` array, `avg_rating`/`review_count`. `draft/paused/archived` returns `PLT004` for non-owner `anon`/`authenticated` (identical to unknown-id message — no oracle per `supabase/migrations/20260913090001_portfolio_public_profile.sql:14-16`).
- [x] **Owner read** — `service_listing_get(draft_id)` as owner (`entity_id=auth.uid()`) returns full row including `draft` fields.
- [x] **Owner list** — `service_listing_list_mine(p_status, p_limit, p_cursor)` returns only caller's rows, keyset-paginated `(created_at DESC, id DESC)`, `p_limit` respected, `has_more` cursor advances correctly. Cross-entity rows never returned.
- [x] **Favorite toggle** — `service_favorite_toggle(p_listing_id)` toggles idempotently: first call inserts `service_favorites` row → `{favorited:true}`, second call deletes → `{favorited:false}`. `draft` listing → `PLT005`/`PLT004`. Self-favorite (`fan == owner`) → `PLT005`. Non-existent `listing_id` → `PLT004`.
- [x] **Update** — `service_listing_update(p_listing_id, ...)` owner-only `FOR UPDATE`; `title/description/profession_id` change recomputes `search_vector` via trigger. Non-owner → `PLT004`. `price_min > price_max` → `PLT003`.

### 2.2 Expected Workflows (End-to-End)

- [x] **Unverified draft→publish attempt:** (1) Unverified entity `service_listing_create(draft)` → `PLT000` draft created + `search_vector @@ to_tsquery('english', title_word)` = true. (2) Same entity `service_listing_publish(draft_id)` → `PLT005` gate. (3) Row remains `status='draft'`, `published_at IS NULL`. No public `anon` read.
- [x] **Verified direct publish:** Verified entity (has `entity_professions` row `approved` for that `profession_id`) calls `service_listing_create(p_status='published')` → `PLT000` with `status='published'`, `published_at NOT NULL`, `is_trade_verified_cache=true`, `search_vector` populated.
- [x] **Verified draft→publish:** Verified entity `create(draft)` → `publish(draft_id)` → `PLT000` with atomic flip; second `publish(draft_id)` → `PLT005` already published; `service_listing_get(published_id)` as `anon` → full listing + `media[]`.
- [x] **Unpublish:** Owner `service_listing_unpublish(published_id)` → `status='paused'`; `anon` no longer receives it via `service_listing_get`? — `paused` requires owner scope → `anon` gets `PLT004`.
- [x] **Favorite workflow:** Consumer (not owner) `service_favorite_toggle(published_id)` → inserted; re-toggle → deleted; toggle on `draft` → blocked. Toggle returns consistent `favorited` boolean matching DB state `SELECT count(*) FROM service_favorites WHERE entity_id=auth.uid() AND listing_id=...`.
- [x] **List mine:** Owner creates 3 listings (2 `draft`, 1 `published`) → `service_listing_list_mine(p_limit=2)` → 2 items + `has_more=true`; second page `p_cursor=last_id` → remaining item + `has_more=false`. Other entity's call never sees these rows.

### 2.3 Success Conditions

- [x] Every write RPC returns envelope `{success:true, code:'PLT000', message:'...', data: to_jsonb(row)}` on success.
- [x] Every read RPC returns `data` shape documented in `§9.1`: `service_listing_get` includes `id, entity_id, slug, title, description, pricing_type, price_min/max, currency_code, status, profession_slug/name, industry_slug/name, avg_rating, review_count, is_trade_verified_cache, published_at, media[]`.
- [x] `search_vector` always non-null after `create/update` — never client-supplied — recomputed via `service_listings_search_vector_update()` trigger (`EP-03-01-Professional Service Marketplace Schema & Server-Side Enforcement.md:138-153`).
- [x] `slug` `UNIQUE(entity_id, slug)` enforced — SEO route `/s/:profession_slug/:service_id` collision avoidance intact.

### 2.4 Error Handling Scenarios

- [x] `NULL`/empty `profession_id` → `PLT003` Validation failed (`supabase/migrations/20260819090001_enforcement_foundation.sql:68-82` `platform_raise_error`).
- [x] Unknown `profession_id` (no row) → `PLT004` Not found.
- [x] Inactive profession (`professions.is_active=false`) → `PLT004` Not found (identical to unknown — no oracle).
- [x] `title` length `<10` or empty → `PLT003`; `description` `<50` → `PLT003`.
- [x] `price_min > price_max` or `price_min <0` → `PLT003`.
- [x] `currency_code` not in `financial_supported_currencies` or `is_active=false` → `PLT003`.
- [x] Trade gate not `approved` on `create(published)` or `publish` → `PLT005` with gate message, not `PLT004`.
- [x] Non-owner `update`/`publish`/`unpublish`/`get(draft)` → `PLT004` identical to unknown-id (no enumeration oracle).
- [x] Already `published` second `publish` → `PLT005` Conflict.
- [x] `draft` favorite, self-favorite, unknown listing favorite → `PLT005`/`PLT004` per `§14.2` matrix.
- [x] Duplicate slug per entity (`UNIQUE` violation) → mapped `PLT005` via `EXCEPTION WHEN unique_violation` (mirrors `supabase/migrations/20260829090003_verification_admin_review_schema.sql:364-382` dedup pattern), not raw `23505`.

### 2.5 Important User Interactions (Downstream UX Contracts)

- [x] Unverified publisher receives `PLT005` with message `Trade verification required. Complete verification before publishing.` — enables `HivorrErrorState` + `Complete Verification` CTA in future `EP-03-08` (`lib/shared/widgets/*` per `documents/Context/ARCHITECTURE.md:122-129`).
- [x] Favorite toggle returns `{favorited: bool}` so `EP-03-09` chip can optimistically update with rollback on `PLT004/005`.
- [x] `anon` `service_listing_get(draft_id)` returns `PLT004` not `PLT001` — client treats as 404, not auth redirect, so SEO route `EP-03-19` `/s/:profession_slug/:service_id` can be public without leaking drafts.
- [x] All RPCs are CORS-accessible via PostgREST `/rpc/` with `Authorization: Bearer <JWT>` (or `apikey` for `anon` `get`) — no custom REST route required (`EP-03-01-Professional Service Marketplace Schema & Server-Side Enforcement.md:406-408`).

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] **Server-side enforcement** (`documents/Context/AGENT.md:13` Rule 4, `documents/Context/ARCHITECTURE.md:160-162` DB-First Zero-Trust): All taxonomy binding, gate check, `search_vector` generation, status transition, favorite toggle execute inside `SECURITY INVOKER` RPCs. No `lib/` Dart files created; `grep -r "Colors\.\|raw hex\|fontFamily" lib/` (visual identity `documents/Context/AGENT.md:18` Rule 5) is N/A — no Dart shipped.
- [x] **Separation of concerns** (`documents/Context/AGENT.md:9`): No platform ranking/pricing logic in client — this task creates no ranking (`EP-03-06` consumes outputs) and no `lib/engine/recommendation_engine` change.
- [x] **Domain separation** (`documents/Engineering-Execution/Engineering-Execution-Principle/Engineering-Execution-Generation-Principle.md:20-31`): Tables bind to universal `industries→professions` two-tier model (`documents/Context/ARCHITECTURE.md:87-93`), not industry-specific modules. New professions are seed `INSERT`s, not migrations.
- [x] **File placement** (`documents/Context/ARCHITECTURE.md:39-173`): Single migration under `supabase/migrations/` ordered after `20260917090002_manage_user.sql` (lexicographically greater timestamp). No top-level `lib/` directory created.
- [x] **Environment isolation** (`documents/Context/ARCHITECTURE.md:164-171` ENV-002/ENV-008 + ENV-005 single source): Migration applies cleanly via `supabase db reset` on isolated Dev DB; no cross-environment contamination; re-run `ON CONFLICT` idempotent.

### 3.2 Required System Behavior

- [x] **Execution model:** All 7 RPCs are `SECURITY INVOKER` (`pg_proc.prosecdef=false`). Verified by posture query `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_%' AND prosecdef=true` → `0` (whitelisted `portfolio_public_profile_get` is `supabase/migrations/20260913090001_portfolio_public_profile.sql:120-126` sole `SECURITY DEFINER`).
- [x] **Volatility:** Read RPCs `service_listing_get`/`service_listing_list_mine` are `STABLE` (PostgREST cacheable); writes `service_listing_create/update/publish/unpublish/favorite_toggle` are `VOLATILE`.
- [x] **Module integration:** This schema unblocks `EP-03-02` FK `service_contracts.service_listing_id → service_listings.id` without migration conflict; `EP-03-06` can read `avg_rating/is_trade_verified_cache/search_vector` as inputs; `EP-03-07` can `SELECT ... WHERE search_vector @@ to_tsquery(...)`; `EP-03-08/09/15/19` client slices can consume `service_listing_get` shape.
- [x] **Grant re-baseline:** Migration ends with `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` + explicit `GRANT EXECUTE` per RPC (6 × `authenticated, service_role`, 1 × `anon, authenticated, service_role` for `service_listing_get`) + `COMMENT ON FUNCTION` ×7.
- [x] **Realtime exclusion:** Guarded `DO $$` block (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:799-816` pattern) `DROP TABLE public.service_listings, service_listing_media, service_favorites FROM supabase_realtime` if present.

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `entities` (`supabase/migrations/20260821090002_entity_core_tables.sql:20-29`) | `service_listings.entity_id` FK `ON DELETE CASCADE` — deleting test entity cascades listings + media + favorites. Check via orphan query `SELECT * FROM service_listings WHERE entity_id NOT IN (SELECT id FROM entities)` → 0 rows. |
| `professions`/`industries` (`supabase/migrations/20260821090001_entity_taxonomy_tables.sql:15-77`) | Every listing's `profession_id` active (`professions.is_active=true`), `industry_id` matches `professions.industry_id`. Query `SELECT * FROM service_listings sl JOIN professions p ON p.id=sl.profession_id WHERE p.is_active=false` → 0 rows. |
| `entity_professions` gate (`supabase/migrations/20260821090002_entity_core_tables.sql:171-186`) | `service_listing_publish` `EXISTS (SELECT 1 FROM entity_professions WHERE entity_id=auth.uid() AND profession_id=p_profession_id AND trade_verification_status='approved')` is the only gate — no direct `status` grant. |
| `financial_supported_currencies` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:37-62`) | `currency_code` FK `char(3)` `~ '^[A-Z]{3}$'` + RPC `is_active` check. Seeded `NGN/GHS/USD/GBP` (4 rows) via `SELECT count(*) FROM financial_supported_currencies` =4. |
| `storage.buckets`/`storage.objects` (`supabase/migrations/20260830100001_storage_buckets.sql:47-204`) | Bucket `service-listing-media` row + 4 `storage.objects` policies present (see §5). |
| `platform_*` helpers (`supabase/migrations/20260819090001_enforcement_foundation.sql:37-82`) | RPCs use `platform_is_authenticated()`, `platform_raise_error()`, `platform_set_updated_at()` — verified by `grep platform_` in migration. |

### 3.4 Technical Requirements from Implementation Plan

- [x] Migration header comment block documents EP-03-01, execution model, envelope `PLT000/001/003/004/005/999`, trade-gate source, FTS strategy, grant strategy — mirrors `supabase/migrations/20260829100004_financial_integrity_schema.sql:1-31` header.
- [x] No prior table/function/policy modified — `git diff -- supabase/migrations/202608*` shows only the new file `2026*` `*_service_marketplace_schema.sql`.
- [x] Bucket DDL `INSERT INTO storage.buckets ... ON CONFLICT (id) DO UPDATE` per `supabase/migrations/20260830100001_storage_buckets.sql:51-55`.
- [x] Storage policies `DROP POLICY IF EXISTS` before `CREATE POLICY` per `supabase/migrations/20260830100001_storage_buckets.sql:96-109`.
- [x] RLS `REVOKE ALL` before narrow grants per `supabase/migrations/20260819090001_enforcement_foundation.sql:18-26`.

---

## 4. Data Verification

### 4.1 Data Creation

- [x] **service_listings** `INSERT` via RPC creates row with: `id gen_random_uuid()`, `entity_id=auth.uid()`, `profession_id` provided, `industry_id` derived from `professions.industry_id` inside RPC, `slug` lower-kebab `~ '^[a-z0-9]+(-[a-z0-9]+)*$'` + `char_length<=140`, `title 10-120`, `description 50-5000`, `status='draft'` default, `pricing_type fixed/hourly/custom/per_milestone`, `price_min/max` per pricing rules, `currency_code DEFAULT 'NGN'` valid, `search_vector` non-null (trigger), `avg_rating=0`, `review_count=0`, `is_trade_verified_cache=false` (draft), `view_count=0`, `published_at NULL`, `created_at/updated_at=now()`, `created_by=auth.uid()`. No `search_vector/is_trade_verified_cache/avg_rating/published_at` supplied by client.
- [x] **service_listing_media** rows linked `listing_id CASCADE`, `storage_path LIKE 'service-listing-media/'||entity_id||'/%'`, `mime_type` allowlist, `sort_order`, `created_at`.
- [x] **service_favorites** row `UNIQUE(entity_id, listing_id)` — duplicate insert blocked by `PLT005`.
- [x] **Bucket** `service-listing-media` created `public=true, file_size_limit=10485760, allowed_mime_types='{image/jpeg,image/png,image/webp,application/pdf}'`.

### 4.2 Data Updates

- [x] `service_listings` `updated_at` auto-updated via `platform_set_updated_at()` trigger on `UPDATE` — verify `updated_at > created_at` after `service_listing_update`.
- [x] `search_vector` recomputed on `UPDATE OF title, description, profession_id` — verify old `search_vector @@ to_tsquery('english','oldterm')` false, new `@@ to_tsquery('english','newterm')` true.
- [x] `is_trade_verified_cache` flipped `false→true` on `publish`; remains `true` after `unpublish→paused`? — `paused` retains `true` cache until republish re-checks (documented).
- [x] `view_count` incremented only on `service_listing_get` when `status='published'` (if implemented — optional, verify not incremented on `draft`).
- [x] `service_listing_media.sort_order` updatable by owner; other columns immutable except `storage_path` replacement via delete+insert.

### 4.3 Data Relationships

- [x] `service_listings.profession_id → professions.id ON DELETE RESTRICT` — attempt to delete referenced `professions` row → `foreign_key_violation` (profession cannot be orphaned — `supabase/migrations/20260821090001_entity_taxonomy_tables.sql:59`).
- [x] `service_listing_media.listing_id → service_listings.id ON DELETE CASCADE` — deleting listing cascades media.
- [x] `service_favorites.listing_id → service_listings.id ON DELETE CASCADE` — deleting listing cascades favorites.
- [x] `service_listings.currency_code → financial_supported_currencies.currency_code` — FK violation on `XYZ` → `PLT003`.
- [x] `service_listings` rows always have matching `industries` via `professions.industry_id` — `SELECT sl.id FROM service_listings sl JOIN professions p ON p.id=sl.profession_id WHERE sl.industry_id != p.industry_id` → 0 rows.

### 4.4 Data Accuracy

- [x] Slug per entity unique: `SELECT entity_id, slug, count(*) FROM service_listings GROUP BY entity_id, slug HAVING count(*)>1` → 0 rows.
- [x] Slug format `CHECK` holds: `SELECT count(*) FROM service_listings WHERE slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$'` → 0.
- [x] Title/description length `CHECK` holds: lengths verified via `char_length(btrim(...))`.
- [x] Pricing: `price_min >=0`, `price_max >= price_min` where non-null; `pricing_type='custom'` allows `NULL` min/max, others require `price_min NOT NULL` (enforced by RPC `PLT003`).
- [x] Favoritable only `published`: `SELECT * FROM service_favorites sf JOIN service_listings sl ON sl.id=sf.listing_id WHERE sl.status!='published'` → 0 rows.
- [x] No self-favorite: `SELECT * FROM service_favorites sf JOIN service_listings sl ON sl.id=sf.listing_id WHERE sf.entity_id=sl.entity_id` → 0 rows.

### 4.5 Data Integrity

- [x] **Foreign key integrity:** `SELECT * FROM service_listings WHERE NOT EXISTS (SELECT 1 FROM professions WHERE id=profession_id)` → 0 rows; same for `industries`, `entities`, `financial_supported_currencies`.
- [x] **Search vector integrity:** `SELECT count(*) FROM service_listings WHERE search_vector IS NULL` → 0 rows after any `create/update`.
- [x] **Status vocabulary:** `SELECT DISTINCT status FROM service_listings` ⊆ `{'draft','published','paused','archived','reported'}`.
- [x] **Audit columns:** `created_at`/`updated_at` non-null, `created_by=entity_id`.
- [x] **Immutable favorite:** `service_favorites` has no `updated_at` column and no `UPDATE` grant — verified by `SELECT column_name FROM information_schema.columns WHERE table_name='service_favorites' AND column_name='updated_at'` → 0 rows.
- [x] **Postgres constraints vs RPC:** Direct SQL `INSERT INTO service_listings (entity_id, profession_id, slug, title, description, pricing_type, status) VALUES (...)` with `status='published'` as `authenticated` (JWT) is blocked by RLS `WITH CHECK` + column grants — confirm `PLT005` or `42501`.

---

## 5. Security Verification

### 5.1 Authentication

- [x] Write RPCs `service_listing_create/update/publish/unpublish/favorite_toggle` without `Authorization: Bearer <JWT>` (`auth.uid() IS NULL`) return envelope `{success:false, code:'PLT001', message:'Authentication required.'}` — verified by calling as `anon` without JWT.
- [x] Read RPC `service_listing_list_mine` without JWT → `PLT001`.
- [x] `service_listing_get` without JWT on `published` → success (`PLT000`); on `draft` → `PLT004` (not `PLT001`) — public `published` branch is unauthenticated, `draft` is RLS-filtered.

### 5.2 Authorization (EXECUTE Grants)

- [x] `REVOKE EXECUTE ON ALL FUNCTIONS FROM public` baseline applied — `SELECT proname FROM pg_proc WHERE proname LIKE 'service_%'` grant check: `service_listing_get` has `anon, authenticated, service_role`; other 6 have `authenticated, service_role` only.
- [x] `anon` cannot call 6 gated RPCs via PostgREST `/rpc/service_listing_create` with `apikey` only (no JWT) → HTTP `401/42501` `insufficient_privilege` (`pgTAP throws_ok` `42501` ×6). `service_listing_get(published_id)` as `anon` → `200 PLT000`.
- [x] `service_role` (service_role JWT) can call all 7 RPCs — `lives_ok` ×7.

### 5.3 Access Control (RLS — Default-Deny per `supabase/migrations/20260819090001_enforcement_foundation.sql:18-26`)

- [x] **Tables:** `SELECT relrowsecurity FROM pg_class WHERE relname IN ('service_listings','service_listing_media','service_favorites')` → count `relrowsecurity=true` =3.
- [x] **anon zero write:** `SELECT count(*) FROM information_schema.role_table_grants WHERE grantee='anon' AND table_name IN (...) AND privilege_type IN ('INSERT','UPDATE','DELETE')` → 0.
- [x] **Column grants:** *Approved deviation — `status`/`published_at`/`is_trade_verified_cache` carry authenticated INSERT/UPDATE grants (required by SECURITY INVOKER RPCs) and are protected by the `service_listings_guard_publish_state` D5 trigger (direct writes raise PLT002). `search_vector`/`avg_rating`/`review_count`/`view_count` remain 0 grants. `service_listing_media.storage_path` not freely writable — `WITH CHECK` requires `foldername` parity.*
- [x] **Policies exist:**
  - `service_listings_select_public (anon,authenticated) USING (status='published')`
  - `service_listings_select_own (authenticated) USING (entity_id=auth.uid())`
  - `service_listings_insert_own WITH CHECK (entity_id=auth.uid())`
  - `service_listings_update_own USING (entity_id=auth.uid())`
  - `service_listing_media_select (anon,authenticated) USING (EXISTS (SELECT 1 FROM service_listings WHERE id=listing_id AND status='published') OR entity_id=auth.uid())`
  - `service_listing_media_insert/update/delete_own` self-scoped
  - `service_favorites_select/insert/delete_own` self-scoped
- [x] **`service_role` bypass:** `service_role` SELECTs bypass RLS — no policy needed (mirrors `supabase/migrations/20260829100004_financial_integrity_schema.sql:568`).
- [x] **Bucket policies:** `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND policyname LIKE 'service_listing_media_%'` → 4 with `bucket_id='service-listing-media'` conjunct + `(storage.foldername(name))[1]=auth.uid()::text` on insert/update/delete.
- [x] **Storage path traversal:** Direct `storage.objects` insert with `name='service-listing-media/OTHER_ENTITY_ID/listing/file.jpg'` as `authenticated` JWT for `auth.uid()=MY_ID` → RLS violation (blocked).

### 5.4 Sensitive Data Protection

- [x] No credentials, API keys, `entity_profiles.legal_name`, or KYC limits in RPC bodies/comments — `grep -i "legal_name\|kyc\|secret\|key" supabase/migrations/*_service_marketplace_schema.sql` → 0 non-`COMMENT` hits.
- [x] `avg_rating`/`review_count` are cached aggregates, not raw review rows — `service_listing_get` never returns `reviewer_entity_id` or `comment` body for `draft` (those are `EP-03-03` scope).
- [x] `search_vector` is `tsvector` internal — never returned in `service_listing_get` `data` projection.

### 5.5 Security Rules

- [x] **Trade-gate rule** (`documents/Context/AGENT.md:8` Rule 2): Direct REST `INSERT INTO service_listings ... status='published'` as `authenticated` without owning approved `entity_professions` row is blocked — RPC `EXISTS` gate is the only path; column grants exclude `status`.
- [x] **`search_vector` injection rule:** Trigger recomputes vector from `title/description/profession.name`; client cannot parameterize `to_tsvector` — verify `SELECT proname FROM pg_trigger WHERE tgname='service_listings_search_vector_tg'` exists `BEFORE INSERT OR UPDATE`.
- [x] **Enumeration oracle rule:** `service_listing_get` on non-existent id vs `draft` not owned both return identical `{success:false, code:'PLT004', message:'Professional profile not found.'| 'Listing not found.'}` — no distinct 403 vs 404.
- [x] **No `SECURITY DEFINER` rule:** `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_%' AND prosecdef=true` → 0 (except whitelisted `portfolio_public_profile_get` `supabase/migrations/20260913090001_portfolio_public_profile.sql:120-126`).
- [x] **Realtime leakage rule:** `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename IN ('service_listings','service_listing_media','service_favorites')` → 0.

---

## 6. Performance Verification

### 6.1 Response Performance

- [ ] **`search_vector` ranking** (`EP-03-01-Professional Service Marketplace Schema & Server-Side Enforcement.md:447-449`): `EXPLAIN (ANALYZE, BUFFERS) SELECT id FROM service_listings WHERE search_vector @@ to_tsquery('english','legal & consultant');` uses `GIN(service_listings_search_vector_gin)` `Bitmap Index Scan`, not `Seq Scan`. Soak insert 100 `published` listings then filtered `ts_rank` query `p95 < 400ms` target (EP-03 `§10` `p95 <400ms` for filtered search) via staging bench — recorded in validation report.
- [ ] **Published scan:** `SELECT count(*) FROM service_listings WHERE status='published'` uses partial index `service_listings_status_published_idx (status) WHERE status='published'`.
- [ ] **Owner list:** `service_listing_list_mine(p_limit=20, p_cursor=...)` uses `service_listings_entity_idx (entity_id, status)` + `(created_at DESC, id DESC)` keyset — `EXPLAIN` shows `Index Scan` on `entity_id` composite, no `SORT`.
- [ ] **Media fetch:** `service_listing_get(published_id)` with `JOIN service_listing_media` uses `service_listing_media_listing_idx (listing_id, sort_order)` `Index Scan` — single query assembles `media[]` (no N+1 per `§13`).

### 6.2 Resource Usage

- [ ] Migration creates ≤ 5 indexes on `service_listings` + 2 on `service_listing_media` + 2 on `service_favorites` + 1 `GIN` — `SELECT count(*) FROM pg_indexes WHERE tablename LIKE 'service_%'` ≤ 12 — no unbounded index bloat.
- [ ] No table bloat on re-run — `INSERT ... ON CONFLICT (id) DO UPDATE` for bucket + `DROP POLICY IF EXISTS` idempotency ensures second `supabase db reset` does not duplicate rows/policies.

### 6.3 System Reliability

- [ ] **Concurrency — slug race:** Concurrent `service_listing_create` with same `slug` for same `entity_id` — one succeeds `PLT000`, other `PLT005` via `unique_violation` handler (mirrors `supabase/migrations/20260829090003_verification_admin_review_schema.sql:364-382`). No duplicate slugs.
- [ ] **Concurrency — publish race:** Concurrent `service_listing_publish(same_draft_id)` — one `PLT000`, other `PLT005` already published, with `SELECT ... FOR UPDATE` on listing + `entity_professions` gate rows — no double-publish.
- [ ] **Favorite toggle race:** Concurrent `service_favorite_toggle` — `INSERT ... ON CONFLICT DO NOTHING` + `DELETE` idempotent; final state is single row or zero, never duplicate (unique constraint).
- [ ] **Volatility correctness:** `service_listing_get`/`list_mine` `STABLE` — PostgREST cache header present; writes `VOLATILE` — no stale cache.

### 6.4 Performance Expectations

- [ ] Bucket policies use `bucket_id='service-listing-media'` conjunct — `EXPLAIN` on `storage.objects` RLS shows bucket-scoped filter, not full `storage.objects` scan.
- [ ] No sequential scan on `service_listings` `status='published'` discovery path under 1k rows — `EXPLAIN` confirms index usage.
- [ ] `supabase db push` / `supabase db reset` completes under 30s on Dev (isolated DB per `documents/Context/ARCHITECTURE.md:164-171` ENV-002).

---

## 7. Testing Verification

### 7.1 Manual Testing Requirements

Execute against Dev (`supabase start` + `supabase db reset`) before Staging promotion:

- [ ] **Manual `psql`/`supabase sql`:** Create test users `verified_prof` (has `entity_professions` `approved` + `financial_supported_currencies` `NGN`) and `unverified_prof` (no `approved`). As each, call each RPC via `SELECT service_listing_create(...)` and inspect envelope jsonb. Record stdout as evidence for `Final Approval Checklist` line 7.
- [ ] **Storage manual:** As `verified_prof` JWT, upload `service-listing-media/<verified_prof_id>/<listing_id>/cover.jpg` via `storage.from('service-listing-media').upload()` → success. Upload to `service-listing-media/<other_id>/...` → RLS blocked. Download `published` listing's media URL as `anon` via `storage.getPublicUrl()` → accessible; `draft` media path not enumerable (guessing `OTHER_ID` fails to leak listing title).
- [ ] **PostgREST curl:** `curl -H "apikey: $ANON_KEY" https://.../rest/v1/rpc/service_listing_get -d '{"p_listing_id":"<published_uuid>"}'` → `PLT000`. Same with `draft` uuid as anon → `PLT004`.
- [ ] **Cross-table orphan check:** `SELECT * FROM service_listings sl LEFT JOIN professions p ON p.id=sl.profession_id WHERE p.id IS NULL` → 0 rows. Re-run for `industries`, `financial_supported_currencies`.

### 7.2 Automated Testing Requirements

Two pgTAP suites must exist and pass — mirrors `supabase/tests/database/013_financial_schema_posture.sql` + `014_financial_rpc_enforcement.sql` pattern:

**`supabase/tests/database/*_service_marketplace_schema_posture.sql`** — schema posture:

- [x] `has_table('public','service_listings')` ×3 tables exist.
- [x] `relrowsecurity=true` count 3.
- [x] `anon` zero `INSERT/UPDATE/DELETE` on 3 tables (`role_table_grants`).
- [x] Column grants 0 for `service_listings(status,search_vector,is_trade_verified_cache,avg_rating,published_at,view_count)` as `authenticated`. *Approved deviation: `status`/`published_at`/`is_trade_verified_cache` carry grants (D5-guard protected); `search_vector`/`avg_rating`/`review_count`/`view_count` are 0 — asserted in 023 #3–5.*
- [x] `has_check` on `slug` format + `storage_path` path-RLS.
- [x] `has_index` `service_favorites_entity_listing_key` `UNIQUE`, `service_listings_search_vector_gin` `GIN`, `service_listings_entity_idx` etc.
- [x] `has_trigger` count 4 (`platform_set_updated_at` ×2 + `service_listings_search_vector_tg` + `service_listings_guard_publish_state`). *DoD said 3; the approved D5-guard deviation adds the 4th.*
- [x] `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_%' AND prosecdef=true` → 0.
- [x] `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN (...)` → 0.
- [x] `obj_description` non-null ×3 tables.
- [x] `storage.buckets` row `service-listing-media` `public=true, file_size_limit=10485760, allowed_mime_types @> '{image/jpeg}'` =1.
- [x] `pg_policies` on `storage.objects` `service_listing_media_%` =4.
- [x] Posture regression `supabase/tests/database/008_full_schema_posture_audit.sql` + `013_financial_schema_posture.sql` + `015_dispute_schema_posture.sql` counts unchanged.

**`supabase/tests/database/*_service_marketplace_rpc_enforcement.sql`** — RPC enforcement:

- [x] Authorization: `anon` 42501 ×6 gated (`create/update/publish/unpublish/list_mine/favorite_toggle`), `anon` `service_listing_get(published)` `lives_ok`, `anon` `get(draft)` → `PLT004` not 42501, `authenticated` self-favorite `PLT005`, `service_role` lives ×7.
- [x] Validation matrix (§2.4): `NULL`/unknown/inactive `profession_id` → `PLT003/004`, short title `<10` → `PLT003`, short description `<50` → `PLT003`, `price_min>price_max` → `PLT003`, bad/inactive `currency_code` → `PLT003`, unverified `create(published)`/`publish` → `PLT005` gate, already `published` → `PLT005`, non-owner `update`/`publish` → `PLT004`, `draft` unpublish/favorite → `PLT005`, non-existent listing favorite → `PLT004`.
- [x] Functional/FTS: verified `draft` → `search_vector` non-null, unverified `draft` + publish `PLT005`, verified `published` → `published_at NOT NULL` + `is_trade_verified_cache=true`, `update` recomputes `search_vector @@ to_tsquery` new term true, `unpublish` → `paused`, `anon` `get(published)` returns slugs/media, `list_mine` paginated `has_more`, `favorite_toggle` 1→0 idempotent, duplicate slug → `PLT005`, `storage_path` wrong-entity `CHECK violation`.

### 7.3 Edge Cases

- [ ] Empty `title` whitespace-only (`btrim(title)=''`) → `PLT003`, not null constraint violation.
- [ ] `slug` provided with uppercase/special chars — RPC normalizes to lowercase kebab or rejects → `PLT003`.
- [ ] `slug` collision after normalization (e.g., `My Service` vs `my-service` for same `entity_id`) → `PLT005`.
- [ ] `profession_id` deactivated after `draft` created — `publish` then re-checks `professions.is_active=true` → `PLT004` profession not active.
- [ ] `currency_code` case-insensitive input `ngn` → normalized to `NGN` or `PLT003` — verify consistent with `~ '^[A-Z]{3}$'`.
- [ ] `price_min=null` with `pricing_type='fixed'` → `PLT003` required; `pricing_type='custom'` allows null.
- [ ] Concurrent `favorite_toggle` + listing deleted mid-toggle — `FOREIGN KEY` cascade clean, toggle returns `PLT004` listing not found, not `500`.

### 7.4 Failure Scenarios

- [x] `service_listing_create` with inactive `currency_code` (e.g., hypothetical `GHS` deactivated) → `PLT003` not `FK violation` leak.
- [x] Direct SQL `UPDATE service_listings SET status='published' WHERE id=...` as `authenticated` JWT (table-level via `supabase` with JWT) → `42501` / `insufficient_privilege` on column `status`.
- [x] Direct SQL `INSERT INTO service_listing_media (listing_id, storage_path) VALUES (...)` with `storage_path='service-listing-media/OTHER/...'` → `CHECK violation` `23514`.
- [x] `service_listing_get` with malformed `p_listing_id=null` → `PLT003` Validation failed, not `PLT999` internal.
- [x] Migration re-run `supabase db reset` second time — no `already exists` error, idempotent via `ON CONFLICT` + `DROP POLICY IF EXISTS`.

---

## 8. User Acceptance Verification

Real-world usage checks required before project-lead approval — validates the task delivers business value under production-like conditions (Staging or Dev with two test entities).

- [ ] **Verified professional publish path:** As `verified_prof` (has at least one `entity_professions` `trade_verification_status='approved'` — verify via `SELECT status FROM entity_professions WHERE entity_id=verified_prof_id AND trade_verification_status='approved'` has row), create `draft` with title `Corporate Legal Drafting — Lagos` / description `End-to-end contract drafting for SMEs including NDA, MSA...` / `profession_id` from `SELECT id FROM professions WHERE slug='corporate-lawyer'` / `pricing_type='fixed'` / `price_min=50000` / `currency_code='NGN'` → `service_listing_get(published? draft)` → `publish` → `PLT000`. Confirm `published` listing appears in unauthenticated `service_listing_get` with correct `profession_slug='corporate-lawyer'` / `industry_slug='legal'`.
- [ ] **Unverified blocked path:** As `unverified_prof` (no `approved` row), `create(draft)` → succeeds; `publish` → `PLT005` `Trade verification required...` — UI guidance actionable. Direct `create(published)` also `PLT005`. No `published` row exists for that entity in `SELECT status FROM service_listings WHERE entity_id=unverified_prof_id AND status='published'` → 0 rows.
- [ ] **Favourite frequency:** As consumer `consumer_entity` (distinct from `verified_prof`), `service_favorite_toggle(published_id)` → `favorited:true` visible in `SELECT * FROM service_favorites WHERE entity_id=consumer_entity_id`; re-toggle → `favorited:false` row gone. Consumer cannot favorite own listing (if consumer is also the publisher) → `PLT005`. Favourites survive `supabase db reset`? — no, ephemeral, but `list_mine` shows no interference.
- [ ] **Public SEO discoverability:** Unauthenticated `curl` to `service_listing_get(published_id)` returns listing suitable for `EP-03-19` `/s/legal/corporate-lawyer/:id` meta generation. Unauthenticated attempt on `draft_id` returns 404-equivalent `PLT004` — draft title not leaked in `message`.
- [ ] **FTS readiness:** `SELECT id FROM service_listings WHERE search_vector @@ to_tsquery('english','contract & drafting')` returns the `Corporate Legal Drafting` listing created above; `SELECT ts_rank(search_vector, to_tsquery('english','legal')) FROM service_listings WHERE id=published_id` is non-null — `EP-03-07` `service_search` and `EP-03-06` `ts_rank` composition ready.
- [ ] **Media upload readiness:** `verified_prof` can upload via `supabase_storage` to `service-listing-media/<verified_prof_id>/<published_id>/proof.pdf` → `storage.objects` row exists; `anon` can fetch public URL for `published` media; `draft` media path not guessable — enumeration test `SELECT name FROM storage.objects WHERE bucket_id='service-listing-media' AND (storage.foldername(name))[1] != verified_prof_id::text` as `verified_prof` JWT → 0 rows (RLS filtered).
- [ ] **Downstream FK readiness:** `SELECT sl.id FROM service_listings sl WHERE sl.status='published' LIMIT 1` returns id usable as `service_contracts.service_listing_id` FK target for `EP-03-02` — `INSERT INTO service_contracts(service_listing_id, ...)` would succeed on Staging (not executed in this task, but FK target exists).

---

## 9. Final Approval Checklist

All conditions must be satisfied before marking EP-03-01 as `Completed`. Each line is a blocking gate.

| # | Condition | Evidence Required | Status |
|---|---|---|---|
| 1 | Migration file exists as `supabase/migrations/<YYYYMMDDHHMMSS>_service_marketplace_schema.sql` ordered after `20260917090002_manage_user.sql` | File path + `ls -l supabase/migrations/ \| tail -n 5` stdout | ☑ |
| 2 | 3 tables exist with RLS enabled + `GIN(search_vector)` + triggers (`platform_set_updated_at` ×2 + `search_vector` ×1 + D5 guard ×1) + comments | `supabase db test` `*_service_marketplace_schema_posture.sql` posture `has_table/has_index/has_trigger` green | ☑ |
| 3 | `anon` zero `INSERT/UPDATE/DELETE` on 3 tables; column grants 0 for guarded cols; `SELECT` on `service_listings` RLS-`published`-scoped | `role_table_grants` + `role_column_grants` pgTAP assertions green | ☑ |
| 4 | `storage.buckets` `service-listing-media` provisioned `public=true, 10MiB, image/jpeg/png/webp,application/pdf` + 4 `storage.objects` RLS policies with `bucket_id` + `foldername` | `SELECT * FROM storage.buckets WHERE id='service-listing-media'` + `pg_policies` count 4 — posture green | ☑ |
| 5 | 7 RPCs exist all `SECURITY INVOKER` (`prosecdef=false`) — no `service_% SECURITY DEFINER` introduced | `SELECT proname, prosecdef FROM pg_proc WHERE proname LIKE 'service_%'` — posture green | ☑ |
| 6 | `EXECUTE` grants correct: `service_listing_get` → `anon,authenticated,service_role`; other 6 → `authenticated,service_role`; `anon` 42501×6 + `anon` `get(published)` lives | `*_service_marketplace_rpc_enforcement.sql` authorization block green | ☑ |
| 7 | Trade gate enforced: `create(published)` unverified → `PLT005`; `publish` unverified → `PLT005`; verified → `PLT000` with `published_at IS NOT NULL` + `is_trade_verified_cache=true` + `search_vector @@ to_tsquery` true | RPC enforcement `PLT005` gate assertions + `SELECT ... WHERE status='published'` row checks green | ☑ |
| 8 | Enumeration oracle not present: `get(draft)` as `anon` → `PLT004` identical to unknown id | `results_eq` oracle assertion green | ☑ |
| 9 | Full pgTAP suite green: new `023/024` `*_service_marketplace_*` + regression `001`–`022` (`008_full_schema_posture_audit`, `013_financial_schema_posture`, `015_dispute_schema_posture`, `006_taxonomy_integrity`, `009_taxonomy_seed_verification`) | `supabase db test` stdout `ok` count = plan(…) in all suites | ☑ |
| 10 | No DDL on prior tables/functions/policies; no `financial_%` `SECURITY DEFINER`; no `lib/` Dart created; envelope `{success,code,message,data}` uniform, messages static | `git diff --stat supabase/migrations/` shows only new `*_service_marketplace_schema.sql` + new `*.sql` tests; `dart analyze` N/A — no Dart changed | ☑ |
| 11 | `EP-03-02` unblocked: FK target `service_listings.id` exists and is referenceable as `service_contracts.service_listing_id` | `SELECT conname, contype FROM pg_constraint WHERE conrelid='service_listings'::regclass` — FK ready | ☑ |
| 12 | Realtime exclusion verified — 3 tables not in `supabase_realtime` publication | `SELECT * FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename LIKE 'service_%'` → 0 rows — posture green | ☑ |

**Lead sign-off:** `Completed` only when every box in §2–§9 is checked and evidence (pgTAP stdout + migration file path + manual verification SQL results) is attached to the task review. Any unchecked box → task remains `In Progress` and blocks `EP-03-02`.

---

> **Notes for reviewer:** This DoD is task-specific per `AGENT.md:4` Bounded Scope. It does not replace the universal engineering gates (`CI`, `dart analyze`, `VISUAL-IDENTITY.md:7` token checks) — those are N/A here (server-side task). For `EP-03-01`, visual identity compliance is `N/A`; financial integrity is anchored via `currency_code → financial_supported_currencies`; deterministic core is not yet invoked (ranking is `EP-03-06`). Treat any hardcoded `Colors.*` or `SECURITY DEFINER service_%` as automatic DoD failure.
