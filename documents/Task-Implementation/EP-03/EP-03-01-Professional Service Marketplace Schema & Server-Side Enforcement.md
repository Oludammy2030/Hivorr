# Task Implementation Plan — EP-03-01: Professional Service Marketplace Schema & Server-Side Enforcement

**Task ID:** EP-03-01 | **Priority:** Critical | **Status:** Not Started | **Phase:** EP-03 Stage 1 — Marketplace Server Schema Foundation

> **Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:246-255` + `documents/Context/AGENT.md:1-18` + `documents/Context/ARCHITECTURE.md:39-173` + `documents/Engineering-Execution/Engineering-Execution-Principle/Engineering-Execution-Generation-Principle.md:20-31`

---

## 1. Task Objective

Create the atomic marketplace database foundation that every EP-03 capability depends on. Deliverables:

- **3 new tables:** `service_listings`, `service_listing_media`, `service_favorites` (plus `service-listing-media` Storage bucket)
- **7 RPCs:** `service_listing_create` (draft), `service_listing_update`, `service_listing_publish`, `service_listing_unpublish`, `service_listing_get`, `service_listing_list_mine`, `service_favorite_toggle` — all `SECURITY INVOKER`, envelope `{success,code,message,data}` (`PLT000`/`PLT001`/`PLT003`/`PLT004`/`PLT005`/`PLT999` per `supabase/migrations/20260829100004_financial_integrity_schema.sql:17-19`)
- **Full RLS (default-deny)** on all 3 tables; Storage `storage.objects` policies for `service-listing-media` bucket
- **Trade-verification gate** enforced server-side: `entity_professions.trade_verification_status == 'approved'` required for `publish` (and `create` if `status='published'`) — source `supabase/migrations/20260821090002_entity_core_tables.sql:171-186` + `20260829090003_verification_admin_review_schema.sql:472-489` + `20260915090001_onboarding_authoritative_state.sql:1-27`
- **Full-text search vector** (`tsvector` + `GIN`) generated from `title || description || profession name` for `EP-03-07` / `EP-03-06`
- **2 pgTAP test files:** `*_service_marketplace_schema_posture.sql`, `*_service_marketplace_rpc_enforcement.sql`
- **Zero modifications** to any EP-01 (`20260821090001_entity_taxonomy_tables.sql:15-55`, `20260821090002_entity_core_tables.sql:20-256`) or EP-02 table/function; **zero client-side Dart** — server-side only task that unblocks `EP-03-02` → `EP-03-20`.

## 2. Business Problem Being Solved

EP-02 completed trust infrastructure (taxonomy `industries→professions` at `20260829090001_taxonomy_seed_data.sql:28-158`, verification workflow at `20260829090003_verification_admin_review_schema.sql:44-234`, financial rails at `20260829100004_financial_integrity_schema.sql:37-414`, portfolio at `20260913090001_portfolio_public_profile.sql:23-55`) but **no marketplace primitive exists to hold supply**:

- No `service_listings` — verified professionals (`AGENT.md:8` Rule 2) cannot advertise a service bound to `profession_id→professions.id→industries.id` (`ARCHITECTURE.md:87-93`). Discovery (`EP-03-06` ranking, `EP-03-07` FTS), contract linkage (`EP-03-02` `service_contracts.service_listing_id`), review aggregation (`EP-03-03`), portfolio linkage (`EP-03-15`), and SEO routes (`EP-03-19` `/s/:profession_slug/:service_id`) have no FK target.
- No trade-gate enforcement — without a server-side check on `publish`, unverified supply could enter search, violating `AGENT.md:7` Rule 2 and destroying marketplace trust before the first transaction.
- No `service_listing_media` — listing cover images / proof evidence cannot be uploaded via the `20260830100001_storage_buckets.sql:47-83` bucket pattern; `lib/core/storage/supabase_storage_service.dart` has no bucket to target.
- No `service_favorites` — consumer-side shortlisting/bookmarking primitive missing for discovery frequency (`Business-Roadmap:219-226`).
- No `search_vector` / `GIN` — `EP-03-07` cannot implement `ts_rank` + taxonomy filters without the indexed vector; unbounded `LIKE` scans would not meet the `EP-03:55` `p95 < 400ms` target.
- No auditable pricing/currency anchor — `currency_code` must FK to `financial_supported_currencies` (`20260829100004:37-62` `NGN/GHS/USD/GBP`) to reuse EP-02 multi-currency integrity; otherwise price becomes untrusted client math (`AGENT.md:13` Rule 4 violation risk).

This task is the **load-bearing schema** for EP-03. Incorrect taxonomy binding, gate enforcement, or RLS here propagates as unverified supply, search bypass, or financial mis-anchoring in every downstream phase (EP-03 through EP-08).

## 3. Scope

| In Scope | Detail |
|---|---|
| `service_listings` table | Core listing: `entity_id→entities.id` (owner), `profession_id→professions.id` (taxonomy binding), `status` enum `draft/published/paused/archived/reported`, `pricing_type` enum, `price_min/max`, `currency_code→financial_supported_currencies`, `title/description/slug`, `search_vector tsvector`, `avg_rating` cache, `review_count` cache, `is_trade_verified_cache boolean`, `view_count`, `published_at`, audit cols `created_at/updated_at/created_by` + `platform_set_updated_at()` trigger |
| `service_listing_media` table | Media rows: `listing_id→service_listings.id ON DELETE CASCADE`, `storage_path text` (enforces `service-listing-media/{entity_id}/{listing_id}/{file}` parity), `mime_type`, `sort_order`, `created_at/updated_at` |
| `service_favorites` table | Favorites: `entity_id→entities.id` (fan), `listing_id→service_listings.id ON DELETE CASCADE`, `created_at`, `unique(entity_id, listing_id)` |
| `service-listing-media` Storage bucket | Provision in `storage.buckets` (`public=true`, `10MiB`, `image/jpeg/png/webp,application/pdf` per `20260830100001:51-55` pattern) + `storage.objects` RLS policies (owner-write, public-read for `published` media; see §8.3) |
| `search_vector` trigger + `GIN` index | `BEFORE INSERT OR UPDATE` trigger `service_listings_search_vector_update()` (`to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,'') || ' ' || profession_name)` via lookup) + `GIN(search_vector)` |
| RPC: `service_listing_create` | Create draft (or directly `published` if trade gate passes) — validates profession exists+active, price range, currency active, title length; sets `is_trade_verified_cache` by checking `entity_professions` |
| RPC: `service_listing_update` | Owner-only mutable field update (`draft`/`paused` only for pricing/taxonomy changes; `published` limited to `description`/`media` unless republish flow) |
| RPC: `service_listing_publish` | State `draft/paused → published`: re-validates trade gate (`approved` per profession), sets `published_at=now()`, flips `is_trade_verified_cache` |
| RPC: `service_listing_unpublish` | `published → paused` (owner) or `reported` (service_role / future moderation); clears `published_at` semantics |
| RPC: `service_listing_get` | Public read for `published` (any `anon`/`authenticated`), owner read for own `draft/paused/archived`, service_role full |
| RPC: `service_listing_list_mine` | Owner-scoped paginated list (`p_status filter`, `p_cursor`, `p_limit`) |
| RPC: `service_favorite_toggle` | Idempotent toggle (insert if absent, delete if present) for `authenticated` fan |
| RLS + grants | Default-deny on 3 tables; column-level grants; `anon` zero grants except `service_listing_get` via RPC path for `published` |
| pgTAP posture test | `supabase/tests/database/*_service_marketplace_schema_posture.sql` |
| pgTAP enforcement test | `supabase/tests/database/*_service_marketplace_rpc_enforcement.sql` |
| Currency seed reuse | FK to existing `financial_supported_currencies` (`NGN/GHS/USD/GBP` seeded at `20260829100004:57-62`) — no new seed |
| Realtime exclusion | Guarded `DO $$` block to `DROP` 3 tables from `supabase_realtime` if present (mirrors `20260829090003:799-816`, `20260830100001:218-233`) |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| `service_contracts` / `contract_milestones` / `contract_events` | `EP-03-02` — depends on `service_listings.id` FK |
| `service_reviews` / `service_review_aggregates` | `EP-03-03` — depends on contracts |
| `conversations` / `messages` / Realtime messaging | `EP-03-04` / `EP-03-13` |
| `availability_slots` / `appointments` | `EP-03-05` / `EP-03-14` |
| Deterministic ranking RPC `service_ranking_search` | `EP-03-06` — consumes `service_listings.avg_rating`/`is_trade_verified_cache`/`search_vector` produced here |
| Client search FTS composition `service_search` | `EP-03-07` |
| Any `lib/systems/marketplace/*`, `lib/data/*`, `lib/engine/*` Dart code | Client tasks `EP-03-08`/`09`/`15`/`19` |
| Admin moderation console for `reported` listings | `EP-02-11` tooling reuse; full console not EP-03 deliverable |
| Modification of `industries`, `professions`, `entities`, `entity_professions`, `financial_supported_currencies`, `financial_balances` | Finalized in EP-01/EP-02; this task references, not alters |
| New `kyc_tiers` or currency additions | Currency scope remains `NGN/GHS/USD/GBP` per `EP-03:191` assumption |
| `lib/ai/*` intelligence | Explicitly excluded from EP-03 (`EP-03:106`, `AGENT.md:14`) — AI may never override ranking |

## 5. Recommended Technical Approach

### 5.1 Single SQL Migration — `supabase/migrations/<YYYYMMDDHHMMSS>_service_marketplace_schema.sql`

Ordered **immediately after** `20260917090002_manage_user.sql` (the current tip). Content in strict order:

1. Header comment block (EP-03-01, execution model, envelope, trade-gate source, FTS strategy, grant strategy — mirrors `20260829100004:1-31` header)
2. DDL: `service_listings` (constraints, indexes, `search_vector` column, trigger, comments)
3. DDL: `service_listing_media` (FK, path CHECK, indexes, trigger, comments)
4. DDL: `service_favorites` (FKs, unique, index, comments — no `updated_at`, immutable favorite)
5. Bucket DDL: `INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('service-listing-media', ...)` `ON CONFLICT (id) DO UPDATE` (mirrors `20260830100001:51-83`)
6. `storage.objects` policy reset (`DROP POLICY IF EXISTS` + `CREATE POLICY` for `service-listing-media` — four policies: `select_public/read_authenticated`, `insert_owner`, `update_owner`, `delete_owner`)
7. RLS enable + `REVOKE ALL` + per-table column grants + self-scoped/public policies
8. 7 RPC function definitions (`SECURITY INVOKER`, `VOLATILE` for writes, `STABLE` for reads)
9. `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` + explicit `GRANT EXECUTE` per RPC + `COMMENT ON FUNCTION`
10. Realtime exclusion `DO $$` block + posture assertions comment

**No changes to any prior table, function, or policy.**

### 5.2 Execution Model: `SECURITY INVOKER` (No New `SECURITY DEFINER`)

All 7 RPCs are `SECURITY INVOKER` — RLS applies inside the function body. Required for:

- Compliance with `supabase/tests/database/008_full_schema_posture_audit.sql` posture (asserts no entity/marketplace `SECURITY DEFINER` outside the whitelisted `portfolio_public_profile_get`) — `20260913090001_portfolio_public_profile.sql:120-126` is the sole allowed `SECURITY DEFINER` precedent
- Consistency with EP-02-04 (`20260829100004:12-13`), EP-02-05 helper exception is `dispute_%` only, EP-02-03 review RPCs are `service_role`-gated `INVOKER` (`20260829090003:18-22`)
- `AGENT.md:13` Rule 4 — client is unprivileged; writes via RPC + RLS

**Authorization model:**

| RPC | `anon` | `authenticated` | `service_role` | Gate |
|---|---|---|---|---|
| `service_listing_create` | — | `EXECUTE` (self, trade-gate validated) | `EXECUTE` | `platform_is_authenticated()` + `entity_professions.trade_verification_status='approved'` if `p_status='published'` |
| `service_listing_update` | — | `EXECUTE` (owner only) | `EXECUTE` | `owner = auth.uid()` |
| `service_listing_publish` | — | `EXECUTE` (owner, trade-gate re-check) | `EXECUTE` | `approved` gate; `draft/paused → published` only |
| `service_listing_unpublish` | — | `EXECUTE` (owner) | `EXECUTE` | `published → paused`; `reported` is `service_role` only |
| `service_listing_get` | `EXECUTE` (published only) | `EXECUTE` (published + own) | `EXECUTE` | `status='published'` public; else `entity_id=auth.uid()` |
| `service_listing_list_mine` | — | `EXECUTE` (self) | `EXECUTE` | `entity_id=auth.uid()` |
| `service_favorite_toggle` | — | `EXECUTE` (self fan) | `EXECUTE` | `listing.status='published'` + `fan != owner` |

`anon` EXECUTE on `service_listing_get` only, mirroring `portfolio_public_profile_get` (`20260913090001:283-285`).

### 5.3 Trade-Verification Gate — Server-Side Enforcement

```sql
-- Inside publish/create(published) — the only authorized gate transition
-- Mirrors 20260915090001:197-209 verification breadth check
IF NOT EXISTS (
  SELECT 1 FROM public.entity_professions ep
   WHERE ep.entity_id = auth.uid()
     AND ep.profession_id = p_profession_id
     AND ep.trade_verification_status = 'approved'
) THEN
  PERFORM public.platform_raise_error('PLT005',
    'Trade verification required. Complete verification before publishing.');
END IF;
```

- **Column grants block client bypass:** `service_listings.is_trade_verified_cache`, `status` transitions via direct `UPDATE` are **not** granted to `authenticated` (`UPDATE` limited to `title/description/price_*` on `draft` only) — only the RPC may set `status='published'` after the `EXISTS` check. This mirrors the `entity_professions` `trade_verification_status` client-exclusion at `20260829090003:257-262`.
- **Direct `INSERT` blocked:** `authenticated` has **no** `INSERT` column grant on `service_listings` except via the RPC path (`REVOKE` + narrow `GRANT` + RLS `WITH CHECK (entity_id=auth.uid())` + trigger guard alternative: the RPC is the canonical write path; REST `INSERT` with `status='published'` would still hit the RLS `is_trade_verified_cache` check but the RPC gate is the enforced path for `PLT005` fidelity).
- **Cache column:** `is_trade_verified_cache` is denormalized at publish time (`approved` → `true`) to make `EP-03-06` ranking `WHERE` efficient without joining `entity_professions` per row; refreshed on `publish` / `entity_professions` status change via a deferred trigger or RPC re-check (not a live FK).

### 5.4 Full-Text Search Vector — `tsvector` + `GIN`

```sql
ALTER TABLE public.service_listings ADD COLUMN search_vector tsvector;

CREATE OR REPLACE FUNCTION public.service_listings_search_vector_update() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_prof_name text;
BEGIN
  SELECT p.name INTO v_prof_name FROM public.professions p WHERE p.id = NEW.profession_id;
  NEW.search_vector := to_tsvector('english',
    coalesce(NEW.title,'') || ' ' || coalesce(NEW.description,'') || ' ' || coalesce(v_prof_name,'')
  );
  RETURN NEW;
END; $$;

CREATE TRIGGER service_listings_search_vector_tg
  BEFORE INSERT OR UPDATE OF title, description, profession_id
  ON public.service_listings FOR EACH ROW EXECUTE FUNCTION public.service_listings_search_vector_update();

CREATE INDEX service_listings_search_vector_gin ON public.service_listings USING gin(search_vector);
```

- Vector **never** client-supplied — always recomputed by trigger (prevents `search_vector` injection).
- `EP-03-06` ranking will compose `ts_rank(search_vector, to_tsquery(...))` + `avg_rating` + `is_trade_verified_cache` without re-deriving the vector.

### 5.5 Storage Bucket — `service-listing-media`

Provision identical to `20260830100001:51-83`:

```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('service-listing-media','service-listing-media', true, 10485760,
  '{image/jpeg,image/png,image/webp,application/pdf}')
ON CONFLICT (id) DO UPDATE SET public=excluded.public,
  file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types, updated_at=now();
```

Policies (four, bucket-scoped):

- `service_listing_media_select_public` — `FOR SELECT TO anon, authenticated USING (bucket_id='service-listing-media')` — public read (but `service_listing_get` enforces `draft` media is only returned to owner; direct Storage URL for `draft` media is still public-by-bucket — acceptable per `EP-03:90` "*public read for `published` listing media*" — the mitigation is that `draft` media paths are unguessable `/{entity_id}/{listing_id}/{uuid}.{ext}` and not enumerated)
- `service_listing_media_insert_owner` — `FOR INSERT TO authenticated WITH CHECK (bucket_id='service-listing-media' AND (storage.foldername(name))[1]=auth.uid()::text)`
- `service_listing_media_update_owner` / `delete_owner` — same `foldername` conjunct.

Path convention: `service-listing-media/{entity_id}/{listing_id}/{uuid}.{ext}` — `entity_id == auth.uid()::text` (mirrors `20260830100001:30-33` + `20260913090001:46-47`).

### 5.6 Response Envelope & Error Codes

All RPCs `RETURNS jsonb` envelope `jsonb_build_object('success', true/false, 'code', 'PLT...', 'message', '...', 'data', to_jsonb(...))`:

| Code | Meaning | When |
|---|---|---|
| `PLT000` | Success | Happy path |
| `PLT001` | Authentication required | `auth.uid() IS NULL` (except `service_listing_get` public `published` branch) |
| `PLT003` | Validation failed | Bad `profession_id`, inactive profession, bad `pricing_type`, `price_min > price_max`, `currency_code` not in `financial_supported_currencies` active set, title length, empty slug |
| `PLT004` | Not found | `profession_id` unknown, `listing_id` unknown, or `draft` requested by non-owner (identical message to `published` not-found to avoid enumeration oracle per `20260913090001:14-16`) |
| `PLT005` | Conflict / gate | Trade gate not `approved`, `draft` already `published`, duplicate `service_favorites` toggle race, `published` listing update of restricted fields |
| `PLT999` | Internal | Unexpected exception |

No new codes beyond the `20260829100004:19` vocabulary (`PLT006` is financial-only).

### 5.7 Reuse of Platform Helpers

| Helper | Source | Usage |
|---|---|---|
| `platform_is_authenticated()` | `20260819090001_enforcement_foundation.sql:37-43` | Auth gate on 6 of 7 RPCs |
| `platform_current_user_id()` | `20260819090001:45-51` | Self-scope alias |
| `platform_raise_error(code, message)` | `20260819090001:68-82` | Typed `P0001` envelope errors |
| `platform_set_updated_at()` | `20260819090001:54-62` | `updated_at` trigger on `service_listings`, `service_listing_media` |
| `platform_audit_log_add(...)` | `20260819090003:388-398` precedent | Optional audit for publish events (authenticated context has `auth.uid()`) |
| `financial_supported_currencies` | `20260829100004:37-62` | FK target + `is_active` check in RPCs |
| `entity_professions` gate | `20260821090002:171-186` | `trade_verification_status` gate |
| `storage.foldername(name)` | `20260830100001:112-204` pattern | Owner-path check in Storage policies |

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Service marketplace schema + RPCs migration | `supabase/migrations/<timestamp>_service_marketplace_schema.sql` | **Create** — new SQL migration |
| Bucket `service-listing-media` + `storage.objects` policies | Inside same migration (`storage.buckets` + `storage.objects` policies) | **Create** |
| pgTAP schema posture test | `supabase/tests/database/*_service_marketplace_schema_posture.sql` | **Create** |
| pgTAP RPC enforcement test | `supabase/tests/database/*_service_marketplace_rpc_enforcement.sql` | **Create** |

**No `lib/` files created** — this is a server-side-only task. Client vertical slice (`lib/data/entities/service_listing.dart`, `lib/data/models/service_listing_dto.dart`, `lib/data/datasources/remote/supabase_service_*`, `lib/data/repositories/*`, `lib/data/providers/marketplace_*`, `lib/systems/marketplace/services/service_listing_service.dart`, `lib/workspace/profession_registry/*` picker reuse) is `EP-03-08` scope.

## 7. Data Requirements

### 7.1 `service_listings`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK `gen_random_uuid()` | |
| `entity_id` | `uuid` FK `entities(id) ON DELETE CASCADE` | Owner; denormalized for RLS `entity_id=auth.uid()` (mirrors `financial_balances:125` pattern) |
| `profession_id` | `uuid` FK `professions(id) ON DELETE RESTRICT` | `RESTRICT` prevents taxonomy orphaning per `20260821090001:59` |
| `industry_id` | `uuid` FK `industries(id) ON DELETE RESTRICT` | Denormalized from `professions.industry_id` at write time for filter efficiency; `CHECK (industry_id = (SELECT industry_id FROM professions WHERE id=profession_id))` via trigger or RPC validation (not a DB CHECK subquery) |
| `slug` | `text` | URL-safe, lowercase kebab, `CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug) <= 140)` per `20260821090001:29` |
| `title` | `text` NOT NULL | `CHECK (char_length(btrim(title)) BETWEEN 10 AND 120)` |
| `description` | `text` NOT NULL | `CHECK (char_length(btrim(description)) BETWEEN 50 AND 5000)` |
| `status` | `text` NOT NULL `DEFAULT 'draft'` | `CHECK (status IN ('draft','published','paused','archived','reported'))` — vocabulary `text+CHECK` not `ENUM` per `20260821090002:15-17` D2 forward-extensibility |
| `pricing_type` | `text` NOT NULL | `CHECK (pricing_type IN ('fixed','hourly','custom','per_milestone'))` |
| `price_min` | `numeric` | `CHECK (price_min IS NULL OR price_min >= 0)`; required when `pricing_type != 'custom'` |
| `price_max` | `numeric` | `CHECK (price_max IS NULL OR price_max >= price_min)` |
| `currency_code` | `char(3)` FK `financial_supported_currencies(currency_code)` | `DEFAULT 'NGN'`; `CHECK (currency_code ~ '^[A-Z]{3}$')` per `20260829100004:38` |
| `search_vector` | `tsvector` | Generated by trigger; **not** client-writable (excluded from `authenticated` column grants) |
| `avg_rating` | `numeric` `DEFAULT 0` | `CHECK (avg_rating BETWEEN 0 AND 5)` — cache recomputed by `EP-03-03` `service_review_aggregates` reveal transaction |
| `review_count` | `integer` `DEFAULT 0` | `CHECK (review_count >= 0)` |
| `is_trade_verified_cache` | `boolean` `DEFAULT false` | Set by publish RPC from `entity_professions` gate |
| `view_count` | `integer` `DEFAULT 0` | Incremented by `service_listing_get` when `status='published'` (optional) |
| `published_at` | `timestamptz` | `NULL` when `draft/paused/archived`, `NOT NULL` when `published` — enforced by `CHECK ((status='published' AND published_at IS NOT NULL) OR (status!='published' AND published_at IS NULL))` or RPC |
| `created_at` | `timestamptz` NOT NULL `DEFAULT now()` | |
| `updated_at` | `timestamptz` NOT NULL `DEFAULT now()` | `platform_set_updated_at()` |
| `created_by` | `uuid` `DEFAULT auth.uid()` | |

Constraints: `UNIQUE (entity_id, slug)` scoped uniqueness for SEO route `/s/:profession_slug/:slug` collision avoidance; `CHECK (price_min IS NOT NULL OR pricing_type='custom')`.

Indexes: `service_listings_entity_idx (entity_id, status)`, `service_listings_profession_idx (profession_id, status)`, `service_listings_industry_idx (industry_id, status)`, `service_listings_status_published_idx (status) WHERE status='published'`, `service_listings_search_vector_gin USING gin(search_vector)`, `service_listings_currency_idx (currency_code)`, `service_listings_published_at_idx (published_at DESC) WHERE status='published'`.

### 7.2 `service_listing_media`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `listing_id` | `uuid` FK `service_listings(id) ON DELETE CASCADE` | |
| `entity_id` | `uuid` FK `entities(id) ON DELETE CASCADE` | Denormalized owner for RLS self-scope without join |
| `storage_path` | `text` NOT NULL | `CHECK (storage_path LIKE 'service-listing-media/' || entity_id::text || '/%')` — path-RLS parity per `20260913090001:44-47` |
| `mime_type` | `text` | `CHECK (mime_type IN ('image/jpeg','image/png','image/webp','application/pdf'))` |
| `sort_order` | `integer` NOT NULL `DEFAULT 0` | |
| `created_at` | `timestamptz` NOT NULL `DEFAULT now()` | |
| `updated_at` | `timestamptz` NOT NULL `DEFAULT now()` | `platform_set_updated_at()` |
| `created_by` | `uuid` `DEFAULT auth.uid()` | |

Indexes: `service_listing_media_listing_idx (listing_id, sort_order)`, `service_listing_media_entity_idx (entity_id)`.

### 7.3 `service_favorites`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `entity_id` | `uuid` FK `entities(id) ON DELETE CASCADE` | Fan |
| `listing_id` | `uuid` FK `service_listings(id) ON DELETE CASCADE` | |
| `created_at` | `timestamptz` NOT NULL `DEFAULT now()` | |

No `updated_at` — favorite is immutable toggle (insert/delete only). `UNIQUE (entity_id, listing_id)` + `CHECK (entity_id != (SELECT entity_id FROM service_listings WHERE id=listing_id))` via RPC (cannot self-favorite) — enforced by RPC `PLT005`, not a subquery CHECK constraint.

Indexes: `service_favorites_entity_idx (entity_id, created_at DESC)`, `service_favorites_listing_idx (listing_id)`.

## 8. Database Considerations

### 8.1 Existing Schema (References Only — No Modification)

- `entities(id, status, capability, onboarding_completed_at)` — `20260821090002:20-29` + `20260915090001:31-39`
- `entity_professions(entity_id, profession_id, trade_verification_status, is_primary)` — `20260821090002:171-186` — **gate source**
- `professions(id, industry_id, slug, name, is_active)` — `20260821090001:58-77`
- `industries(id, slug, name, is_active)` — `20260821090001:16-34`
- `financial_supported_currencies(currency_code, is_active)` — `20260829100004:37-62`
- `financial_audit_trail` / `verification_audit_trail` — audit precedents, not mutated here
- `storage.buckets` / `storage.objects` — `20260830100001:47-204`

### 8.2 Constraint Compliance

| Constraint | Enforced By |
|---|---|
| Slug format | `CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$')` per `20260821090001:27-29` |
| Title/description length | `CHECK char_length(btrim(...)) BETWEEN` |
| Status vocabulary | `CHECK (status IN (...))` — `text`, not `ENUM` |
| Pricing integrity | `CHECK (price_min >=0 AND price_max >= price_min)` + RPC `currency_code` active check |
| FK integrity | `FOREIGN KEY ... ON DELETE CASCADE/RESTRICT` |
| Unique slug per entity | `UNIQUE (entity_id, slug)` |
| One favorite per listing per fan | `UNIQUE (entity_id, listing_id)` |
| No self-favorite | RPC `PLT005` |
| `search_vector` not client-supplied | Column excluded from `authenticated` grants + trigger overwrite |
| `is_trade_verified_cache` not client-supplied | Column excluded from `authenticated` grants |

### 8.3 RLS & Grants (Default-Deny — `20260819090001:18-26` posture)

**Revoke first:**
```sql
REVOKE ALL ON TABLE public.service_listings, public.service_listing_media, public.service_favorites FROM anon, authenticated;
```

**Per-table grants (narrow, column-level):**

| Table | `anon` | `authenticated` | `service_role` |
|---|---|---|---|
| `service_listings` | `SELECT` (via `service_listing_get` public branch only — no direct table SELECT; but grant minimal `SELECT` with RLS `status='published'` to support `anon` RPC `SECURITY INVOKER` read path) — alternatively `REVOKE` + RPC-only public read (preferred: `anon` zero table grant, RPC `SECURITY DEFINER` exception) — **decision: keep `SECURITY INVOKER` + `anon` EXECUTE on `service_listing_get` only; direct table SELECT for `anon` is blocked by RLS `USING (status='published')` but grant is `SELECT` to `anon, authenticated` on `service_listings` for `published` rows | `SELECT` (public `published` + own), `INSERT(entity_id, profession_id, slug, title, description, pricing_type, price_min, price_max, currency_code)` (no `status/search_vector/is_trade_verified_cache/avg_rating/published_at`), `UPDATE(title, description, pricing_type, price_min, price_max, currency_code)` (restricted — `status` not writable) | `SELECT, INSERT, UPDATE, DELETE` |
| `service_listing_media` | — (`anon` reads media via public bucket URL only if listing `published`) | `SELECT` (own + public `published` listing media via join), `INSERT(entity_id, listing_id, storage_path, mime_type, sort_order)`, `UPDATE(sort_order)`, `DELETE` (own) | `SELECT, INSERT, UPDATE, DELETE` |
| `service_favorites` | — | `SELECT` (own), `INSERT(entity_id, listing_id)`, `DELETE` (own) | `SELECT, INSERT, DELETE` |

**Critical column exclusions** (mirrors `20260829100004:534-546` + `20260821090002:188-200`):
- `service_listings.status`, `search_vector`, `is_trade_verified_cache`, `avg_rating`, `review_count`, `published_at`, `view_count` — **not** writable by `authenticated`
- `service_listing_media.storage_path` — `WITH CHECK` `foldername` parity required

**RLS policies (self-scoped + public `published`):**

```sql
-- service_listings
CREATE POLICY service_listings_select_public ON public.service_listings FOR SELECT TO anon, authenticated
  USING (status='published');
CREATE POLICY service_listings_select_own ON public.service_listings FOR SELECT TO authenticated
  USING (entity_id=auth.uid());
CREATE POLICY service_listings_insert_own ON public.service_listings FOR INSERT TO authenticated
  WITH CHECK (entity_id=auth.uid());
CREATE POLICY service_listings_update_own ON public.service_listings FOR UPDATE TO authenticated
  USING (entity_id=auth.uid()) WITH CHECK (entity_id=auth.uid());

-- service_listing_media (via listing ownership OR published listing)
CREATE POLICY service_listing_media_select ON public.service_listing_media FOR SELECT TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.service_listings sl WHERE sl.id=listing_id AND sl.status='published')
      OR entity_id=auth.uid());
CREATE POLICY service_listing_media_insert_own ON public.service_listing_media FOR INSERT TO authenticated
  WITH CHECK (entity_id=auth.uid());
CREATE POLICY service_listing_media_update_own ON public.service_listing_media FOR UPDATE TO authenticated
  USING (entity_id=auth.uid());
CREATE POLICY service_listing_media_delete_own ON public.service_listing_media FOR DELETE TO authenticated
  USING (entity_id=auth.uid());

-- service_favorites (anon zero)
CREATE POLICY service_favorites_select_own ON public.service_favorites FOR SELECT TO authenticated
  USING (entity_id=auth.uid());
CREATE POLICY service_favorites_insert_own ON public.service_favorites FOR INSERT TO authenticated
  WITH CHECK (entity_id=auth.uid());
CREATE POLICY service_favorites_delete_own ON public.service_favorites FOR DELETE TO authenticated
  USING (entity_id=auth.uid());
```

`service_role` **bypasses RLS** — no policy needed (consistent with `20260829100004:568` comment).

### 8.4 Trigger Compatibility

`platform_set_updated_at()` attached to **2 mutable tables**: `service_listings`, `service_listing_media`. `service_favorites` has no `updated_at` and no trigger (immutable favorite — mirrors `financial_transactions` `20260829100004:417-437`). `search_vector` trigger is `BEFORE INSERT OR UPDATE`.

### 8.5 Concurrency & Locking

- **Slug uniqueness race:** `UNIQUE (entity_id, slug)` + `EXCEPTION WHEN unique_violation THEN PLT005` (mirrors `20260829090003:364-382` `verification_submit` dedup).
- **Publish race:** `SELECT ... FOR UPDATE` on `service_listings` row + `SELECT ... FOR UPDATE` on `entity_professions` gate row before `status` transition; second concurrent `publish` sees `status='published'` → `PLT005`.
- **Favorite toggle race:** `INSERT ... ON CONFLICT (entity_id, listing_id) DO NOTHING` + `DELETE` idempotency; `unique_violation` mapped to `PLT005` then retried as delete.

### 8.6 Realtime Exclusion

Guarded `DO $$` block (mirrors `20260829090003:799-816`):
```sql
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime'
               AND schemaname='public' AND tablename IN ('service_listings','service_listing_media','service_favorites')) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.service_listings, public.service_listing_media, public.service_favorites;
  END IF;
END $$;
```

### 8.7 Idempotency

- Bucket: `ON CONFLICT (id) DO UPDATE` (`20260830100001:56-60`).
- Policies: `DROP POLICY IF EXISTS` before `CREATE POLICY` (`20260830100001:96-109`).
- `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` re-baseline per `20260829090003:789`.

### 8.8 Posture Audit Compatibility

New tables/functions **do not** affect existing `supabase/tests/database/008_full_schema_posture_audit.sql` (9-table) or `013_financial_schema_posture.sql` (12-table) or `015_dispute_schema_posture.sql` (4-table) assertions — they assert only their own table cohorts. New `service_marketplace_schema_posture.sql` adds parallel assertions for `service_%` / `service_favorites` / `service-listing-media`.

## 9. API Requirements

### 9.1 RPC API Surface (PostgREST `/rpc/`)

| RPC | Signature | Access | Volatility | Purpose |
|---|---|---|---|---|
| `service_listing_create` | `(p_profession_id uuid, p_title text, p_description text, p_pricing_type text, p_price_min numeric DEFAULT NULL, p_price_max numeric DEFAULT NULL, p_currency_code char(3) DEFAULT 'NGN', p_status text DEFAULT 'draft')` | `authenticated, service_role` | `VOLATILE` | Create draft (or `published` if gate passes); returns created listing jsonb |
| `service_listing_update` | `(p_listing_id uuid, p_title text DEFAULT NULL, p_description text DEFAULT NULL, p_profession_id uuid DEFAULT NULL, p_pricing_type text DEFAULT NULL, p_price_min numeric DEFAULT NULL, p_price_max numeric DEFAULT NULL, p_currency_code char(3) DEFAULT NULL)` | `authenticated, service_role` | `VOLATILE` | Owner field update; validates trade gate if profession changes |
| `service_listing_publish` | `(p_listing_id uuid)` | `authenticated, service_role` | `VOLATILE` | `draft/paused → published`; gate check; sets `published_at`, `is_trade_verified_cache=true` |
| `service_listing_unpublish` | `(p_listing_id uuid, p_reason text DEFAULT NULL)` | `authenticated (→paused), service_role (→paused/reported)` | `VOLATILE` | `published → paused/reported` |
| `service_listing_get` | `(p_listing_id uuid)` | `anon, authenticated, service_role` | `STABLE` | Public `published` read; owner `draft` read; includes `profession.slug/name`, `industry.slug/name`, media array, `avg_rating` |
| `service_listing_list_mine` | `(p_status text DEFAULT NULL, p_limit int DEFAULT 20, p_cursor uuid DEFAULT NULL)` | `authenticated, service_role` | `STABLE` | Owner paginated list with `has_more` cursor |
| `service_favorite_toggle` | `(p_listing_id uuid)` | `authenticated, service_role` | `VOLATILE` | Toggle favorite; returns `{favorited: bool}` |

### 9.2 No REST Endpoints / No Edge Functions

No `supabase/functions/*` created. All writes via RPC; media upload via `storage.objects` + `supabase_storage` client. Edge Functions for escrow auto-behavior are `EP-03-11` scope.

## 10. User Interface Requirements

**None.** This task produces no UI. Server-side only. UI tasks that consume this schema:

- `EP-03-08` — `lib/systems/marketplace/services/service_listing_service.dart` + `screens/service_listing_form_screen.dart`, `service_listing_media_screen.dart`, `my_listings_screen.dart` (profession picker reuse `lib/workspace/profession_registry/widgets/profession_picker.dart` at `ARCHITECTURE.md:89`)
- `EP-03-09` — `marketplace_discovery_screen.dart`, `marketplace_search_screen.dart`, `service_detail_screen.dart` (consumes `service_listing_get` + ranking `EP-03-06`)
- `EP-03-15` — portfolio carousel linkage (`20260913090001:241-251`)
- All EP-03 UI must comply with `AGENT.md:18` Rule 5 + `documents/Context/VISUAL-IDENTITY.md:44-80` tokens — verified in client tasks, not here.

## 11. User Experience Considerations

While server-side only, this schema directly shapes downstream UX:

- **Trade-gate error clarity:** `PLT005` message `"Trade verification required. Complete verification before publishing."` enables `HivorrErrorState` (`lib/shared/widgets/*` via `ARCHITECTURE.md:122-129`) with `Complete Verification` CTA in `EP-03-08`.
- **Price range integrity:** `price_min/max` + `currency_code` anchored to `financial_supported_currencies` lets `EP-03-08` form show `NGN/GHS/USD/GBP` picker without client currency math (`AGENT.md:13`).
- **Search vector invisibility:** `search_vector` never returned to client; `EP-03-07` search composes `to_tsquery` server-side, so client never bypasses server filter (`EP-03:51`).
- **Favorite idempotency:** `service_favorite_toggle` returning `{favorited}` lets `EP-03-09` chip show optimistic toggle + rollback on `PLT004`/`PLT005`.
- **Published-only public read:** `anon` `service_listing_get` on `draft` returns `PLT004` identical to "not found" (no enumeration oracle per `20260913090001:16`) — `EP-03-19` SEO route `/s/:profession_slug/:service_id` can safely be `public` without leaking drafts.
- **Consistent envelope:** all RPCs `{success,code,message,data}` matches `20260829100004:17` + `20260829090003:32` — client `lib/core/api/*` `dio:5.11.0` error interceptor can handle uniformly.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Zero client-side marketplace logic | All taxonomy binding, trade-gate check, `search_vector` generation, status transition, favorite toggle executes inside `SECURITY INVOKER` RPCs — client is unprivileged presentation (`AGENT.md:13`, `ARCHITECTURE.md:160-162`) |
| Trade-gate bypass prevention | `entity_professions.trade_verification_status='approved'` checked inside `publish`/`create(published)` RPC + `is_trade_verified_cache/status` columns not writable by `authenticated` + direct `INSERT ... status='published'` blocked by RLS `WITH CHECK` + `service_listings` `authenticated` `INSERT` column list excludes `status` |
| `search_vector` injection prevention | Trigger recomputes vector from `title/description/profession_name`; column excluded from `authenticated` grants; no client parameterization of `to_tsvector` |
| Default-deny | `REVOKE ALL` on 3 tables from `anon, authenticated` (`20260819090001:18-26` posture) then narrow grants per table |
| Self-scoping | Entity-facing RPCs enforce `entity_id=auth.uid()` via RLS + explicit `platform_is_authenticated()` check; `service_listing_get` public branch is `status='published'` only |
| Enumeration oracle prevention | `service_listing_get` on non-existent **or** `draft` not owned returns identical `PLT004` (`20260913090001:14-16` precedent) |
| No new `SECURITY DEFINER` | All 7 RPCs `SECURITY INVOKER` (posture audit `prosecdef=0`); bucket policies use `storage.foldername` check, not definer helpers — avoids expanding the `015` `dispute_%` definer allowance (`documents/Task-Implementation/EP-02/EP-02-05-...md:8.6`) |
| Storage path traversal prevention | `service_listing_media.storage_path CHECK (LIKE 'service-listing-media/' || entity_id || '/%')` + `storage.objects` `foldername(name)[1]=auth.uid()::text` (`20260830100001:118-126`) |
| No self-favorite / no unverified publish | RPC validates `fan != owner` (`PLT005`) and `listing.status='published'` for favorite; publish validates `profession.is_active=true` |
| SQL injection | All DML parameterized via PL/pgSQL variable references; no string-built SQL; `platform_validate_payload` available if jsonb payload variant adopted |
| Secrets / PII | No credentials, API keys, or `legal_name` exposure in function bodies/comments; `avg_rating` is cached aggregate, not KYC limits (`20260913090001:17`) |
| Realtime leakage | 3 tables excluded from `supabase_realtime` (`20260829090003:799-816` guard) |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| `search_vector` ranking | `GIN(search_vector)` (`20260829100004:446` trigram/btree precedent) supports `@@ to_tsquery` + `ts_rank` without sequential scan; `EP-03-20` `p95 <400ms` search target relies on this index (`EP-03:55`) |
| Published listing scan | Partial index `WHERE status='published'` (`service_listings_status_published_idx`) keeps public discovery scans narrow; `anon` cannot trigger full-table scan via `list_mine` (owner-scoped) |
| Owner listing list | `service_listing_list_mine` uses keyset pagination `(created_at DESC, id DESC)` with `p_cursor uuid` + `LIMIT` (cursor/keyset per `EP-03:55` `Discovery lists paginated (cursor/keyset)`) — no `OFFSET`; `entity_id + status` composite index |
| Profession-filtered discovery | `service_listings_profession_idx (profession_id, status)` + `industry_idx` support `EP-03-09` `industry→profession` browser without join to `professions` |
| Media fetch | `service_listing_media_listing_idx (listing_id, sort_order)` — single indexed join in `service_listing_get` assembles media array in one query (no N+1) |
| Favorite toggle | `UNIQUE (entity_id, listing_id)` `ON CONFLICT` — single-row upsert, no table lock |
| Volatility | Read RPCs `STABLE` (cacheable by `PostgREST`), write RPCs `VOLATILE` |
| No N+1 | `service_listing_get` and `service_listing_list_mine` assemble `profession`/`industry` slug/name + media in one function with indexed lookups |
| Bucket performance | `storage.objects` policies use `bucket_id='service-listing-media'` conjunct (`20260830100001:12-13`) to keep policy evaluation bucket-scoped; no cross-bucket leakage scan |

## 14. Testing Strategy

### 14.1 `*_service_marketplace_schema_posture.sql` (pgTAP — mirrors `supabase/tests/database/013_financial_schema_posture.sql` + `015_dispute_schema_posture.sql`)

| Test | Assertion |
|---|---|
| All 3 tables exist | `has_table('public','service_listings')` ×3 |
| RLS enabled on all 3 | `SELECT relrowsecurity FROM pg_class WHERE relname IN (...)` count `=3` |
| `anon` zero grants on 3 tables (except `service_listings SELECT` for public `published` via RLS — assert `anon` has no `INSERT/UPDATE/DELETE` and `SELECT` is RLS-`published`-scoped) | `role_table_grants` `grantee='anon'` `privilege_type IN ('INSERT','UPDATE','DELETE')` count `=0` |
| `service_listings.status/search_vector/is_trade_verified_cache/avg_rating/published_at/view_count` not writable by `authenticated` | `column_grants` `grantee='authenticated' AND column_name IN (...)` count `=0` |
| `service_listings.search_vector` not client-suppliable (no `INSERT`/`UPDATE` column grant) | `column_grants` count `=0` |
| `service_listing_media.storage_path` path-RLS CHECK exists | `has_check` / `pg_constraint` `contype='c'` on `storage_path` |
| `service_favorites` `UNIQUE (entity_id, listing_id)` exists | `has_index` `service_favorites_entity_listing_key` |
| `service_listings` slug format CHECK exists | `has_check` on `slug` |
| Triggers present on 2 mutable tables (`service_listings`, `service_listing_media`) `platform_set_updated_at` + `search_vector` | `has_trigger` count `=3` (2 `updated_at` + 1 `search_vector`) |
| `GIN(search_vector)` index exists | `has_index` `service_listings_search_vector_gin` |
| No `service_%` `SECURITY DEFINER` function (except whitelisted `portfolio_public_profile_get`) | `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_%' AND prosecdef=true` `=0` |
| Realtime excludes all 3 tables | `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN (...)` `=0` |
| Comments present on 3 tables | `obj_description` `IS NOT NULL` ×3 |
| `storage.buckets` `service-listing-media` provisioned (`public=true`, `file_size_limit=10485760`, `allowed_mime_types` contains `image/jpeg`) | `SELECT count(*) FROM storage.buckets WHERE id='service-listing-media'` `=1` |
| `storage.objects` 4 policies for `service-listing-media` exist | `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND policyname LIKE 'service_listing_media_%'` `=4` |
| Posture regression — `008`/`013`/`015` assertions unaffected | Run full suite `001`–`015` + new `017`/`018` |

### 14.2 `*_service_marketplace_rpc_enforcement.sql` (pgTAP — mirrors `supabase/tests/database/014_financial_rpc_enforcement.sql` + `016_dispute_rpc_enforcement.sql`)

**Authorization (per `20260819090001:18-26` + `20260829090003:789-797` `REVOKE EXECUTE FROM public`):**

| Test | Assertion |
|---|---|
| `anon` cannot call 6 `authenticated`-gated RPCs (`create/update/publish/unpublish/list_mine/favorite_toggle`) | `throws_ok('SELECT service_listing_create(...)', '42501', ...)` ×6 |
| `anon` **can** call `service_listing_get` on `published` | `lives_ok` |
| `anon` `service_listing_get` on `draft` returns `PLT004` (not `42501`) — RLS-filtered not auth-gated | `results_eq('SELECT (service_listing_get(draft_id)->>code)', 'PLT004')` |
| `authenticated` cannot self-favorite (`PLT005`) | `throws_ok` / `code=PLT005` |
| `service_role` can call all 7 RPCs | `lives_ok` ×7 |

**Validation (authenticated / service_role):**

| Test | Assertion |
|---|---|
| `service_listing_create` with `NULL` profession_id | `PLT003` |
| `service_listing_create` with non-existent `profession_id` | `PLT004` |
| `service_listing_create` with inactive profession (`is_active=false`) | `PLT004` |
| `service_listing_create` with empty `title` / short `title` (<10) | `PLT003` |
| `service_listing_create` with short `description` (<50) | `PLT003` |
| `service_listing_create` with `price_min > price_max` | `PLT003` |
| `service_listing_create` with unsupported `currency_code` (`XYZ`) | `PLT003` |
| `service_listing_create` with `currency_code` inactive in `financial_supported_currencies` | `PLT003` |
| `service_listing_create(p_status='published')` by unverified entity (no `entity_professions` `approved`) | `PLT005` trade gate |
| `service_listing_publish` by unverified entity | `PLT005` |
| `service_listing_publish` on already `published` | `PLT005` |
| `service_listing_publish` by non-owner | `PLT004` (identical to not-found — no oracle) |
| `service_listing_update` by non-owner | `PLT004` |
| `service_listing_update` with `price_min > price_max` | `PLT003` |
| `service_listing_unpublish` on `draft` (invalid transition) | `PLT005` |
| `service_favorite_toggle` on `draft` listing (not `published`) | `PLT005` / `PLT004` |
| `service_favorite_toggle` on non-existent listing | `PLT004` |
| `service_favorite_toggle` by listing owner (self-favorite) | `PLT005` |

**Functional / Gate / FTS:**

| Test | Assertion |
|---|---|
| Verified entity `service_listing_create(draft)` → row `status='draft'` `is_trade_verified_cache=false`, `search_vector` non-null, `slug` stored, FKs valid | Envelope `success=true code=PLT000`; `SELECT * FROM service_listings WHERE id=...` verifies |
| Unverified entity `service_listing_create(draft)` → succeeds (draft allowed), but `service_listing_publish` → `PLT005` gate | Two-step pgTAP |
| Verified entity `service_listing_create(p_status='published')` in one RPC → `status='published'`, `published_at IS NOT NULL`, `is_trade_verified_cache=true` | Gate-pass verified |
| Verified entity `draft → publish` → `search_vector` matches `to_tsvector(title||description||profession_name)` | `search_vector @@ to_tsquery('english', ...)` `= true` |
| `service_listing_update` (owner, `draft`) title change → `search_vector` recomputed (trigger) | `search_vector` new value `@@` new `to_tsquery` `= true` |
| `service_listing_publish` → `is_trade_verified_cache` flipped `true` atomically | Row check |
| `service_listing_unpublish` → `status='paused'`, `published_at` semantics preserved per CHECK | Row check |
| `service_listing_get(published_id)` as `anon` → returns `{listing, profession_slug/industry_slug, media[]}` with `view_count` incremented (if implemented) | Envelope + data shape |
| `service_listing_get(draft_id)` as `anon` → `PLT004` identical to unknown id | No oracle |
| `service_listing_get(draft_id)` as owner → returns draft row | Owner read path |
| `service_listing_list_mine` as owner → returns only own rows, paginated `limit` respected, cursor progression returns `has_more` | `jsonb_array_length(data->'items') = limit` |
| `service_favorite_toggle` insert → `service_favorites` row exists; second toggle → row deleted (idempotent) | Toggle count `1 → 0` |
| Duplicate slug per entity → `PLT005` (unique violation mapped) | `unique_violation` → `PLT005` |
| `search_vector` GIN supports `@@` query — `INSERT` listing with `title='Corporate Legal Drafting'` → `SELECT * FROM service_listings WHERE search_vector @@ to_tsquery('english','legal & drafting')` returns row | FTS correctness |
| Storage path CHECK — `service_listing_media` `storage_path='service-listing-media/wrong-entity/...'` → `CHECK violation` | `throws_ok` |

**Envelope contract:** all RPCs return `{success, code, message, data}`; success `PLT000`; messages static (no data values) per `20260819090001:65-68`.

### 14.3 Regression

Run full suite `supabase/tests/database/001_*` → `014_*` + `015_*`/`016_*` + `017_*`/`018_*` (new). Assert `008_full_schema_posture_audit.sql`, `013_financial_schema_posture.sql`, `015_dispute_schema_posture.sql`, `017_storage_posture.sql`, `009_taxonomy_seed_verification.sql`, `006_taxonomy_integrity.sql` still pass — no prior table/policy altered.

Manual verification post-migration:
```sql
-- Taxonomy binding valid
SELECT l.id, l.slug, l.profession_id, p.slug as prof_slug, i.slug as ind_slug
FROM service_listings l JOIN professions p ON p.id=l.profession_id JOIN industries i ON i.id=p.industry_id
LIMIT 5;

-- FTS works
SELECT id, title FROM service_listings WHERE search_vector @@ to_tsquery('english','legal & consultant');

-- Gate cached
SELECT entity_id, profession_id, is_trade_verified_cache, status FROM service_listings WHERE status='published';
```

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Create migration file `supabase/migrations/<timestamp>_service_marketplace_schema.sql` (after `20260917090002`) | Scaffold |
| 2 | Header comment block (EP-03-01, execution model `SECURITY INVOKER`, envelope, trade gate source, FTS strategy, grant strategy) | Docs |
| 3 | DDL: `service_listings` (FKs, `CHECK` vocabularies, `UNIQUE(entity_id, slug)`, `search_vector tsvector`, indexes incl. `GIN`, `platform_set_updated_at` trigger, `search_vector` trigger, `COMMENT ON TABLE/COLUMN`) | Table |
| 4 | DDL: `service_listing_media` (FKs, `storage_path` CHECK, indexes, trigger, comments) | Table |
| 5 | DDL: `service_favorites` (FKs, `UNIQUE(entity_id, listing_id)`, indexes, comments — no `updated_at`) | Table |
| 6 | Bucket DDL: `INSERT INTO storage.buckets … 'service-listing-media'` `ON CONFLICT DO UPDATE` | Bucket |
| 7 | Storage policies: `DROP POLICY IF EXISTS` + `CREATE POLICY` ×4 for `service-listing-media` (`storage.objects`) | Security |
| 8 | RLS enable + `REVOKE ALL` + per-table column-level `GRANT` + self-scoped/public `CREATE POLICY` × (`service_listings` 4 + `media` 4 + `favorites` 3) | Security |
| 9 | Implement `service_listing_create` (auth, profession active check, price validation, currency active check via `financial_supported_currencies`, trade gate if `published`, slug generation/normalization, `search_vector` trigger will fill) | RPC |
| 10 | Implement `service_listing_update` (owner check, `FOR UPDATE` lock, state-aware field whitelist, `search_vector` auto-recompute) | RPC |
| 11 | Implement `service_listing_publish` (owner `FOR UPDATE`, trade gate `EXISTS` on `entity_professions`, `status` transition `draft/paused → published`, set `published_at`/`is_trade_verified_cache`) | RPC |
| 12 | Implement `service_listing_unpublish` (owner `FOR UPDATE`, `published → paused`; `service_role` branch `→ reported`) | RPC |
| 13 | Implement `service_listing_get` (`STABLE`, `status='published'` public branch for `anon`, owner branch else, join `professions`+`industries` for slugs + `service_listing_media` array) | RPC |
| 14 | Implement `service_listing_list_mine` (`STABLE`, owner keyset pagination) | RPC |
| 15 | Implement `service_favorite_toggle` (`VOLATILE`, `published` + `fan!=owner` check, `INSERT ON CONFLICT` / `DELETE`, `FOR UPDATE` on `service_favorites` unique) | RPC |
| 16 | `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public` + `GRANT EXECUTE` per RPC (6 `authenticated+service_role`, 1 `anon+authenticated+service_role`) + `COMMENT ON FUNCTION` ×7 | Authz |
| 17 | Realtime exclusion `DO $$` block for 3 tables | Security |
| 18 | Create `supabase/tests/database/*_service_marketplace_schema_posture.sql` | Test |
| 19 | Create `supabase/tests/database/*_service_marketplace_rpc_enforcement.sql` | Test |
| 20 | `supabase db reset` (or `supabase db push`) on Dev — verify migration applies cleanly on isolated DB (`ARCHITECTURE.md:164-171` ENV-002/ENV-008 isolation) | Migrate |
| 21 | `supabase test db` / `supabase db test` — new + existing suites green; `dart analyze` unaffected (no Dart changes) | Verify |

## 16. Expected Outcome

- 3 marketplace tables deployed with full RLS (default-deny), `CHECK` vocabularies, `FK` integrity to `entities`/`professions`/`industries`/`financial_supported_currencies`, `GIN(search_vector)`, triggers, comments, Realtime exclusion
- `storage.buckets` row `service-listing-media` provisioned (`public=true`, `10MiB`, `image/jpeg/png/webp,application/pdf`) with 4 `storage.objects` policies (owner-write, public-read) per `20260830100001:112-204` pattern
- 7 RPCs deployed, all `SECURITY INVOKER`, no `SECURITY DEFINER` added — `posture` audit `prosecdef=0` for `service_%`
- Trade verification gate enforced server-side: `draft` is owner-creatable by anyone with `entity_professions` binding, but `publish` (and `create` with `published`) succeeds **only** when `trade_verification_status='approved'` for that `profession_id` — unverified publish returns `PLT005`; direct REST `INSERT … status='published'` cannot bypass due to column grants + RLS
- `search_vector` trigger guarantees FTS vector is never client-injected and is immediately rankable by `EP-03-06`/`EP-03-07` without additional migration
- `service_favorite_toggle` is idempotent and self-favorite-proof
- `service_listing_get` serves `published` listings publicly (`anon` capable) and `draft` only to owner — enumeration oracle-free (`PLT004` uniformity)
- pgTAP `*_schema_posture` + `*_rpc_enforcement` pass; full suite `001`–`016` + new `017`/`018` green
- `EP-03-02` (contract schema `service_listing_id` FK), `EP-03-06` (ranking inputs), `EP-03-07` (FTS), `EP-03-08`/`09`/`15`/`19` (client vertical slices) unblocked with a real marketplace foundation — no prior table altered (`ENV-005` single source, `ENV-007` Dev→Staging→Prod flow ready)
- Zero marketplace logic leaked to the client (`AGENT.md:13` Rule 4); zero visual-identity violation (no Dart shipped)

## 17. Definition of Done (DoD)

| # | Criterion | Verification Method |
|---|---|---|
| 1 | Migration file exists, named `<timestamp>_service_marketplace_schema.sql`, ordered after `20260917090002_manage_user.sql` | File inspection |
| 2 | 3 tables created: `service_listings`, `service_listing_media`, `service_favorites` | `has_table` ×3 |
| 3 | All 3 tables have `RLS` enabled (`relrowsecurity=true`) | `relrowsecurity` check |
| 4 | `anon` has zero `INSERT/UPDATE/DELETE` grants on 3 tables; `anon` `SELECT` on `service_listings` is RLS-`published`-scoped (or zero — RPC-only public path documented) | `role_table_grants` query |
| 5 | `service_listings.status/search_vector/is_trade_verified_cache/avg_rating/published_at/view_count` not writable by `authenticated` (column grants count `=0`) | Column-grant assertion |
| 6 | `service_listing_media.storage_path` has owner-path `CHECK` parity | `pg_constraint` check |
| 7 | `service_favorites` has `UNIQUE (entity_id, listing_id)` + no self-favorite via RPC `PLT005` | Index + pgTAP |
| 8 | `service_listings` slug format `CHECK` exists + `UNIQUE (entity_id, slug)` | `pg_constraint` + `has_index` |
| 9 | `GIN(search_vector)` index exists + `search_vector` trigger present + `search_vector` not client-writable | `has_index` + `has_trigger` + column-grant `=0` |
| 10 | `storage.buckets` row `service-listing-media` exists with correct `public/file_size_limit/allowed_mime_types` | `SELECT count(*) FROM storage.buckets WHERE id='service-listing-media'` `=1` |
| 11 | 4 `storage.objects` policies for `service-listing-media` exist (select/insert/update/delete) with `bucket_id` + `foldername` conjuncts | `pg_policies` count `=4` |
| 12 | 7 RPCs exist, all `SECURITY INVOKER` (`prosecdef=false`) | `pg_proc` `prosecdef=0` count `=7` |
| 13 | No `service_%` `SECURITY DEFINER` introduced (regression vs `015` `dispute_%` allowance) | `pg_proc` `proname LIKE 'service_%' AND prosecdef=true` `=0` |
| 14 | EXECUTE grants: `service_listing_get` → `anon, authenticated, service_role`; other 6 → `authenticated, service_role` only | `information_schema.routine_privileges` / `has_function_privilege` |
| 15 | `anon` cannot call 6 gated RPCs (`42501`), `anon` can call `service_listing_get(published)` | pgTAP `throws_ok` / `lives_ok` |
| 16 | `service_listing_create(published)` / `service_listing_publish` by unverified entity → `PLT005` trade gate | pgTAP |
| 17 | `service_listing_create(published)` by verified entity → `published` + `published_at NOT NULL` + `is_trade_verified_cache=true` + `search_vector @@ to_tsquery` true | pgTAP |
| 18 | `service_listing_update` by non-owner → `PLT004` (no oracle); duplicate slug per entity → `PLT005` | pgTAP |
| 19 | `service_favorite_toggle` → insert then delete idempotent; self-favorite → `PLT005`; draft favorite → `PLT005` | pgTAP |
| 20 | `service_listing_get(draft)` as `anon` → `PLT004` identical to unknown id; as owner → success | pgTAP (no enumeration oracle) |
| 21 | `service_listing_list_mine` returns owner-scoped paginated rows with `has_more` cursor | pgTAP |
| 22 | Realtime excludes all 3 tables | `pg_publication_tables` count `=0` |
| 23 | `*_service_marketplace_schema_posture.sql` passes | `supabase db test` |
| 24 | `*_service_marketplace_rpc_enforcement.sql` passes | `supabase db test` |
| 25 | Full suite `001`–`016` + new `017`/`018` passes (no EP-01/EP-02 regression) | `supabase db test` |
| 26 | No DDL alters any prior table/function/policy; no `financial_%` `SECURITY DEFINER` introduced; no client Dart files created | Migration review + file inspection |
| 27 | Envelope contract `{success,code,message,data}` on all RPCs; `PLT000` on success; messages static | pgTAP `jsonb` assertions |
| 28 | `EP-03-02` FK dependency satisfied: `service_contracts.service_listing_id → service_listings.id` can be added without migration conflict | Dependency check |

---

## 18. Implementation AI Execution Profile

### Recommended Coding Reasoning Level: **Extremely High**

### Reasoning Level Justification

| Factor | Assessment |
|---|---|
| **Technical complexity** | **Extremely High** — 3 tables with cross-schema FKs (`entities`, `professions`, `industries`, `financial_supported_currencies`), denormalized `industry_id` parity, `tsvector` trigger + `GIN`, `CHECK` vocabularies (price range, slug, pricing_type), `UNIQUE(entity_id, slug)` SEO constraint, `storage.buckets` + 4 `storage.objects` policies with `foldername` parity, 7 RPCs with state machines and cursor pagination |
| **Business impact** | **Extremely High** — the listing is the atomic marketplace unit (`EP-03:251` "without … discovery, ranking, and contract linkage have no trustworthy foundation"). Gate failure lets unverified supply into search, destroying marketplace trust before the first revenue event (`EP-03:15` first revenue-generating capability) |
| **Security risk** | **Extremely High** — trade-gate bypass via direct `INSERT status='published'` is the highest-privilege-escalation risk in EP-03 (`EP-03:178` High → Catastrophic if combined with `EP-03-06` ranking boost). Requires column-level grants + RLS + `EXISTS` gate in one atomic RPC + enumeration-oracle-free `PLT004` uniformity; any `SECURITY DEFINER` mis-introduction would fail the `008`/`013` posture audits |
| **Performance sensitivity** | **Very High** — `GIN(search_vector)` is the sole index supporting `EP-03-07` FTS + `EP-03-06` `ts_rank` at scale; missing/delayed index regresses `p95 <400ms` discovery gate (`EP-03:55`). Keyset pagination in `list_mine` must be correct to avoid `OFFSET` degradation at supply scale |
| **Data complexity** | **Extremely High** — taxonomy binding (`profession_id → industries.id`) must stay consistent with `EP-01-06` two-tier model (`ARCHITECTURE.md:87-93`) + currency FK to `financial_supported_currencies` + denormalized `is_trade_verified_cache` that `EP-03-06` ranking treats as a weighted signal — stale cache would silently misrank |
| **Integration complexity** | **Extremely High** — blocks 6 downstream schemas (`EP-03-02` FK, `EP-03-06` ranking inputs `avg_rating/is_trade_verified_cache/search_vector`, `EP-03-07` `GIN`, `EP-03-08`/`09` client vertical slices, `EP-03-15` portfolio linkage, `EP-03-19` SEO route) — all depend on exact column names/types/RLS semantics defined here; deviation forces migration rewrites |

**Selection rationale:** `EP-03:255` phase plan explicitly assigns `EP-03-01` **Planning Reasoning = Extremely High / Coding Reasoning = Extremely High** (one of only 5 `Extremely High` items in EP-03 per `EP-03:499`). Any lower level would under-allocate verification rigor to the gate + FTS + RLS + storage-path invariants that are irreversible once published listings exist. `Very High` is insufficient for the combined financial-taxonomy-trust surface.

---

**Next step:** Awaiting your approval to proceed to implementation (migration + `storage.buckets`/`storage.objects` policies + 7 RPCs + 2 pgTAP suites). No production code will be written and no files will be created until approval is received (`plan` mode read-only).
