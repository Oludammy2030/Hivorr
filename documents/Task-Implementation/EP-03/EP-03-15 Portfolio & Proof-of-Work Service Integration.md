# Task Implementation Plan — EP-03-15: Portfolio & Proof-of-Work Service Integration

> **Task ID:** EP-03-15 | **Phase:** EP-03 Stage 3 (Service Listing & Discovery) | **Priority:** High
> **Status:** Completed — Approved 2026-10-09. Definition of Done at `documents/Task-Implementation/EP-03/EP-03-15-Definition-of-Done.md`.
> **Source of truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:400-409`

---

## 1. Task Objective

Extend the EP-02-19 portfolio system (`lib/systems/portfolio`, `portfolio_items` + `portfolio_public_profile_get`) so a verified professional can **link existing `portfolio_items` as proof-of-work on a `service_listing`**, and any viewer (including signed-out) sees that linked proof inside the service detail experience.

Concrete deliverable per Phase Plan §400-409:

- New link model + `service_listing_link_portfolio_items(p_listing_id, p_portfolio_ids uuid[])` RPC with ownership guard (caller must own both listing and items).
- Listing detail proof section replacing the `_ProofSlot` placeholder in `lib/systems/marketplace/screens/service_detail_screen.dart:498-538` with a real linked-proof carousel/grid reusing `PortfolioGrid` / `PortfolioItemCard` + `VerificationBadgesRow` (still authoritative per EP-02-11/12).
- Owner link/unlink/reorder flow; unlinked state keeps `HivorrEmptyState` + owner-only `Add portfolio` CTA.
- Expected behavior: create `portfolio_item` → link to `published` listing → unauth viewer sees carousel; non-owner link fails `PLT001`; unlinked shows empty state.

## 2. Business Problem Being Solved

Discovery without evidence does not convert (`Business-Roadmap:225`). EP-03-09 discovery and `service_detail_screen` currently render pricing, verification badges, and media, but the `_ProofSlot` is a hardcoded empty state with a snackbar (`service_detail_screen.dart:520-531`). Professionals with real work history cannot surface it in service context, and consumers cannot distinguish claimed skill from demonstrated work.

EP-02-19 built the trust-display output (public profile at `/p/:slug/:id` with `PortfolioGrid`) but left it **entity-scoped only** — no binding to a specific service offering. EP-03-15 closes that gap by binding entity-scoped proof to listing-scoped discovery, deepening Universal Entity entanglement without duplicating media storage, RLS, or badge logic.

## 3. Scope

**In scope:**

1. **Server (one new additive migration, no edits to existing migrations):**
   - Junction table `service_listing_portfolio_links` (name to finalize; alternatives `service_listing_proofs` / `listing_portfolio_links`) with FKs to `service_listings` + `portfolio_items`, denormalized `entity_id`, `sort_order`, audit columns.
   - RLS default-deny + `SECURITY INVOKER` RPCs: `service_listing_link_portfolio_items`, `service_listing_unlink_portfolio_item` (or single link RPC with full-replace semantics + separate unlink/reorder), `service_listing_portfolio_list` (public read, published-only), optionally `service_listing_portfolio_reorder`.
   - Envelope `{success,code,message,data}` with `PLT000/001/003/004/005/999` per `20260829100004` convention.
2. **Client data layer (extensions only):**
   - Extend `ServiceListingRepository` (or new narrow `ServiceProofRepository` behind same DI shape) + DTO/mapper/entity for linked proof; envelope parser reuse; `Supabase*` impls via `supabase.rpc`.
   - Extend `ServiceListingService` with `linkProofs/unlinkProof/reorderProofs/listProofs` + validators (ownership is server-authoritative; client validates count/shape only).
   - Proof load state (extend `ServiceListingProvider` selection or add `ServiceProofProvider` mirroring `service_listing_provider.dart` lifecycle).
3. **Client UI (replace placeholder, no new top-level route):**
   - Replace `_ProofSlot` with real `ServiceProofSection` (loading / empty / grid-or-carousel / error states) consuming `PortfolioItemCard` + `PortfolioGrid` patterns + `ServiceMediaCarousel` interaction precedent.
   - Owner-only link picker as `HivorrBottomSheet` / dialog reusing `ProfessionPicker(selectedId/onSelected)` interaction shape + `PortfolioItemCard` rows with multi-select; entry from detail `Add portfolio` CTA (and optionally `MyListingsScreen` overflow — sheet only, no new `/services/mine/:id/portfolio` route).
   - `ProfessionalProfileScreen` cross-link: listing detail links back to `/p/:slug/:id`; profile screen itself needs no schema change (it already lists all items) — add optional "Used in service" affordance only if trivial, else deep-link CTA.
4. **SEO/meta:** extend `PortfolioSeoMetaBuilder` usage for listing detail `og:image` fallback to first linked proof image (logic only, no new bucket).
5. **Tests:** pgTAP link matrix + unit/widget/integration per §Testing Strategy.

## 4. Out of Scope

- **No portfolio item CRUD UI.** EP-02-19 left owner portfolio create/edit UI unbuilt; `portfolio_items` writes remain direct RLS owner self-CRUD. EP-03-15 is **link-only** — it does not build portfolio creation, upload, or editing screens. If owner has zero items, picker shows empty state with guidance to create items via the (separate) portfolio path.
- **No new storage bucket, no MIME change.** Reuse `portfolio-items` (public) + `service-listing-media` (public) buckets as-is. `item_type video/link` in DB CHECK has no bucket video support — out of scope to transcode; video/link items render as placeholder cards with type chip.
- **No ranking/search change.** `service_ranking_search` / `service_search` ordering untouched; proof count does not influence rank in this task (future EP could weight it via `platform_config`).
- **No contract/milestone/escrow/review/messaging/scheduling change.**
- **No new verification gate.** Trade gate (`trade_verification_status == APPROVED` from `20260915090001` source) and KYC tier remain enforced by EP-03-01/EP-02-11; EP-03-15 reuses, does not re-implement.
- **No new top-level route** unless full-page picker proves necessary during implementation; default is bottom-sheet inside existing `service-detail` / `service-seo-detail` routes. No `/s/:slug/:id` route work (deferred to EP-03-19).
- **No AI ranking override** per `AGENT.md:7`; no financial math in client per `AGENT.md:13`.

## 5. Existing Asset and Dependency Analysis

Inspected via codebase exploration (read-only) + EP-02-19 plan/DoD + EP-03 Phase Plan. All paths absolute under `C:\Project\hivorr`.

### 5.1 Portfolio system — REUSE (EP-02-19, complete)

| Asset | Path | Reuse verdict |
|---|---|---|
| `ProfessionalProfileService` facade | `lib/systems/portfolio/services/professional_profile_service.dart` — `load`, `tradeVerified`, `verifiedIdentity`, `mediaPublicUrl(bucket:StorageBuckets.portfolioItems)`, `avatarPublicUrl`, `seoMeta` | **Reuse/extend.** Add no new storage logic; reuse `mediaPublicUrl` for proof thumbnails. If service needs linked-proof helpers, add thin delegates — do not fork. |
| `PortfolioGrid` (responsive 1/2/3-col `Wrap`, `sort_order` nulls-last stable) | `lib/systems/portfolio/widgets/portfolio_grid.dart:15-84` | **Reuse verbatim** for grid variant in listing detail. Cited as reference impl in `FLUTTER-UI-IMPLEMENTATION-RULES.md`. |
| `PortfolioItemCard` (16/9 thumb, type chip, title/desc, placeholder) | `lib/systems/portfolio/widgets/portfolio_item_card.dart` | **Reuse verbatim** for proof tiles + picker rows. |
| `VerificationBadgesRow` | `lib/systems/portfolio/widgets/verification_badges_row.dart` | **Reuse unmodified** — remains authoritative per EP-02-11/12. |
| `TradeVerifiedBadge` (large container) | `lib/systems/verification/widgets/trade_verified_badge.dart` | **Reuse** in detail only (already used at `service_detail_screen.dart:416`); discovery cards keep lightweight `HivorrBadge`. |
| `PortfolioProvider` (`load(entityId)`, `idle/loading/loaded/error`) | `lib/data/providers/portfolio_provider.dart` | **Reuse pattern; do not add writes here.** Proof-link state lives in marketplace provider layer (see §6). |
| `SupabasePortfolioRemoteDataSource` + `PortfolioEnvelopeParser` + `PortfolioMappers` + `PortfolioRepositoryImpl` (RPC-only, `PLT004→null`) | `lib/data/datasources/remote/supabase_portfolio_remote_data_source.dart`, `portfolio_envelope_parser.dart`, `lib/data/mappers/portfolio_mappers.dart`, `lib/data/repositories/portfolio_repository_impl.dart` | **Reuse pattern** for new proof RPCs (same `_guard` + envelope + mapper shape). |
| `portfolio_items` table + `portfolio_public_profile_get` DEFINER RPC | `supabase/migrations/20260913090001_portfolio_public_profile.sql` (entity-scoped, whitelisted projection, identical `PLT004`, anon EXECUTE) | **Reuse, do not modify.** Link table FKs into it; read path stays unchanged. |
| `portfolio-items` bucket (public, 10 MiB, jpeg/png/webp/pdf, owner-prefix RLS) | `supabase/migrations/20260830100001_storage_buckets.sql:73-82,176-204` + `lib/core/storage/storage_config.dart` | **Reuse.** No new bucket. |
| `ProfessionalProfileScreen` (`/p/:slug/:id`, header + badges + credentials + grid) | `lib/systems/portfolio/screens/professional_profile_screen.dart` | **Reuse; minimal touch** (cross-link CTA only). |
| `PortfolioSeoMetaBuilder` | `lib/systems/portfolio/seo/portfolio_seo_meta.dart` | **Extend usage** for listing `og:image` fallback, not a rewrite. |

### 5.2 Marketplace / service listing system — REUSE (EP-03-01/08/09, complete)

| Asset | Path | Reuse verdict |
|---|---|---|
| `service_listings` + `service_listing_media` + `service_favorites` schema, 7 INVOKER RPCs, D5 guard trigger, trade gate, FTS `search_vector` + GIN | `supabase/migrations/20260921090001_service_marketplace_schema.sql` (1310 lines) | **Reuse, do not modify.** Junction table FKs to `service_listings.id`; no column added to `service_listings`. |
| `ServiceDetailScreen` + reserved `_ProofSlot` hook | `lib/systems/marketplace/screens/service_detail_screen.dart:498-538` — explicit comment `linking ships in EP-03-15 — no link-write is attempted here` | **Extend.** Replace `_ProofSlot` body with real section. `initialListing` instant-paint + authoritative re-read pattern stays. |
| `ServiceMediaCarousel` (`PageView`, server order, Cover badge, Dots, `HivorrEmptyState`) | `lib/systems/marketplace/widgets/service_media_carousel.dart` | **Reuse pattern** for proof carousel variant (adapt `ListingMedia→PortfolioItem` + `imageUrlFor`). Do not fork carousel infra. |
| `ServiceListingService` (validators, `uploadMedia/deleteMedia` with orphan cleanup, PII-safe logging, `marketplace.listing.*` spans) | `lib/systems/marketplace/services/service_listing_service.dart` (404 lines) | **Extend** with `link/unlink/reorder/listProofs`. Copy upload-then-bind + orphan-cleanup discipline for link writes (no bytes moved, but same RPC-failure hygiene). |
| `ServiceListingRepository` + `SupabaseServiceListingRemoteDataSource` + envelope parser + `ServiceListingMapper` | `lib/data/repositories/service_listing_repository.dart`, `lib/data/datasources/remote/supabase_service_listing_remote_data_source.dart`, `service_listing_envelope_parser.dart`, `lib/data/mappers/service_listing_mapper.dart` | **Extend interfaces** with proof methods; same envelope + `BaseApiService._guard` seam. |
| `ServiceListingProvider` (cursor pagination, `loadMine/loadMore/select/refresh`, lifecycle pause gate) | `lib/data/providers/service_listing_provider.dart` (~300 lines) | **Reuse pattern.** Proof state either nests here (selected-listing proofs) or in a sibling `ServiceProofProvider` with identical lifecycle. |
| `MyListingsScreen`, `ServiceListingFormScreen`, `ServiceListingMediaScreen`, `ListingMediaTile` | `lib/systems/marketplace/screens/*`, `widgets/listing_media_tile.dart` | **Reuse.** Picker grid mirrors `ServiceListingMediaScreen` + `PortfolioGrid`. |
| Router (`/services`, `/services/:id`, `/s/:slug/:id` alias, `/services/mine*`, `/p/:slug/:id`, `...For(id)` builders, `?next=` resume) | `lib/app/router/app_router.dart` (717 lines), `route_paths.dart`, `route_names.dart`, `route_guard.dart` | **Reuse, no new route** (sheet default). |
| `TaxonomyEngine` + `ProfessionPicker` | `lib/workspace/profession_registry/taxonomy_engine.dart`, `widgets/profession_picker.dart` | **Reuse interaction shape** for portfolio picker (search + select list, token-only styling). |

### 5.3 Storage / verification / shared UI / test infra — REUSE

- `StorageService` (`upload/download/remove/getPublicUrl/createSignedUrl/list/validateForBucket`), `SupabaseStorageService` (validate-first, Dio progress fallback, `PLT001/002/003/004/999` map), `StorageValidators`, `StoragePaths.portfolioItem/listingMedia` (+ `sanitize`), `StorageBuckets/StorageLimits/StorageMimeTypes/StorageBucketVisibilities` — all in `lib/core/storage/` + `lib/core/platform/platform_file_picker.dart`. **No new storage API.** Gap noted: no `pickPortfolioItem()` — not needed for link-only scope; if picker needs file-pick, reuse `pickDocument/pickListingMedia` types, do not add a third picker without justification.
- `TradeVerificationGate.canBid`, `KycTier.fromCode().isAtLeastVerified`, `StorageBuckets` — reuse, no new gate.
- Shared UI: `HivorrCard/Chip/Badge/Avatar/Button/EmptyState/ErrorState/LoadingState/Skeleton/Dialog/BottomSheet/ContentPane/ResponsiveScaffold/SectionHeader/Spacing/Formatters` in `lib/shared/` + `AppTheme` (`ColorScheme` + `AppThemeExtension` + `TextTheme`, Plus Jakarta Sans, role accents Client `#2D3FE7` / Professional `#16A34A`) in `lib/app/theme/`. **All proof UI must consume tokens; `Colors.*`/hex/`fontFamily` per-widget fails DoD.**
- Test fakes/patterns: `FakeSupabaseStorageClient`, `fake_portfolio.dart`, `fake_service_listing.dart`, `portfolio_test_support.dart` (`buildPortfolioStack`, `pumpPortfolioScreen`), `service_listing_media_storage_test.dart` (bucket/MIME/path template), pgTAP `017_storage_posture.sql` / `018_portfolio_public_profile.sql` harness (`plan()`, `has_table`, `throws_ok`, `set_config(request.jwt.claim...)`). **Reuse all.**

### 5.4 Dependencies (from Phase Plan §7 + verified in tree)

- **Requires:** EP-02-19 (portfolio read path + `portfolio-items` bucket), EP-02-06 (bucket RLS), EP-03-01 (listing schema + trade gate + `service-listing-media`), EP-03-08 (listing CRUD + media screens whose patterns the picker copies).
- **Consumed by:** EP-03-09 discovery detail (renders proof inline; no EP-03-09 code change beyond the `_ProofSlot` replacement owned by this task), EP-03-19 SEO (extends meta with proof image), EP-03-20 validation (proof-linkage check #10).
- **External:** none new. Supabase RPC+RLS+Storage only; no new package, no new payment credential, no Edge Function (linking is synchronous; no cron needed unlike EP-03-11 auto-release).

## 6. Reuse / Extension / Refactoring Assessment

| Proposed need | Decision | Justification |
|---|---|---|
| Link model (listing ↔ portfolio items, ordered) | **Create new (genuine gap).** Junction table `service_listing_portfolio_links` | Inspected `portfolio_items` (no `service_listing_id`), `service_listings` (no portfolio FK/array), zero `service_listing_portfolio` hits outside docs. Array column on `service_listings` rejected: no ordering metadata, no per-link audit, FK integrity weaker, RLS harder. Junction is the reusable platform primitive (mirrors `service_listing_media` / `service_favorites` shape; future EP-04 `product_listings` can mirror it). Designed for reuse: generic `(listing_id, portfolio_item_id, entity_id, sort_order)` + unique + index. |
| Link/unlink/reorder/list RPCs | **Create new (genuine gap).** `service_listing_link_portfolio_items` + siblings | Zero existing link RPCs; `portfolio_public_profile_get` is entity-scoped read-only; `service_listing_*` RPCs cover CRUD/publish/favorite only. New RPCs follow existing INVOKER + envelope + D5-guard-trigger conventions so future modules reuse the pattern. |
| Proof read for detail | **Extend existing.** New `service_listing_portfolio_list` read RPC; do **not** alter `service_listing_get` / `service_ranking_search` / `portfolio_public_profile_get` payloads | Keeps Stage 1/2 contracts frozen; additive read avoids breaking EP-03-08/09 consumers and pgTAP suites. Detail composes two RPCs (listing + proofs) client-side. |
| Repository/datasource/service/provider | **Extend existing.** Add proof methods to `ServiceListingRepository` seam + `ServiceListingService`; proof state in `ServiceListingProvider` family | New parallel `ProofService` system rejected: would duplicate envelope, logging, tracer, and DI shape (`registerMarketplaceLayer` record). Extension keeps one marketplace seam. If interface grows too large, extract `ServiceProofRepository` interface but still wire through `registerMarketplaceLayer` record — no second DI root. |
| `PortfolioItem` entity/DTO/mapper | **Reuse; add-if-needed thin `LinkedProof` view-model only** | `PortfolioItem(id/itemType/title/description/mediaPath/sortOrder)` already models everything the proof tile needs. Only addition: link `sort_order` (link-table order, not item `sort_order`) + `listing_id` context for the detail sort. Prefer `(PortfolioItem, linkSortOrder)` tuple/view-model over a forked entity. |
| Proof UI section | **Extend existing.** Replace `_ProofSlot` with `ServiceProofSection` reusing `PortfolioGrid`/`PortfolioItemCard`/`ServiceMediaCarousel` pattern | New bespoke carousel/grid rejected: `PortfolioGrid` breakpoints + `ServiceMediaCarousel` PageView+Dots already solve responsive + cover + empty states. New widget is composition, not reinvention. |
| Owner picker | **Create new composable (genuine gap) reusing primitives.** `LinkPortfolioSheet` (bottom sheet + multi-select list) | No picker exists (`ProfessionPicker` is taxonomy-specific; `ServiceListingMediaScreen` is media-specific). New sheet reuses `HivorrBottomSheet/Dialog`, `PortfolioItemCard` rows, `ProfessionPicker` search/select interaction, `HivorrButton`/`HivorrEmptyState`/`HivorrErrorState`. Designed reusable: generic multi-select sheet future modules can adopt. |
| Router | **Reuse; no new route** | Sheet keeps `app_router.dart` / `route_paths.dart` / `route_guard.dart` untouched. New `/services/mine/:id/portfolio` route only if design review proves sheet insufficient (e.g., desktop bulk-manage) — default no. |
| Storage helpers | **Reuse.** `mediaPublicUrl` + `getPublicUrl(portfolio-items)` + `StoragePaths` | No new bucket/path/validator. Upload-then-bind precedent (`ServiceListingService.uploadMedia`) informs link-write hygiene, but no bytes move in this task. |
| Cache | **Reuse; no new cache.** No `portfolioCachePrefix` / local datasource | Proof sets are tiny (cap ~8, see §7) and listing detail already re-reads authoritatively; adding Hive + TTL + invalidation for this task is over-engineering. Revisit only if profiling shows repeated proof-fetch jank. |
| Verification badges | **Reuse unmodified** | `VerificationBadgesRow` stays authoritative; proof linkage never implies verification. No badge logic duplicated. |

**New assets (only where inspection proved a gap):** (1) junction table + RLS + RPCs, (2) proof repository/service/provider method extensions + optional `LinkedProof` view-model, (3) `ServiceProofSection` composition widget, (4) `LinkPortfolioSheet` picker composition. Each is designed as a reusable platform capability (junction pattern EP-04 can mirror; sheet pattern future multi-selects can adopt) and integrates via existing DI/envelope/theme/router seams.

## 7. Recommended Technical Approach

### 7.1 Server (Supabase migration — single additive file)

New migration `supabase/migrations/2026*_service_listing_portfolio_links.sql` (timestamp-ordered after `20260921090001`, never editing prior files):

```sql
-- Junction: one row per (listing, portfolio_item). Entity-scoped via entity_id.
create table public.service_listing_portfolio_links (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.service_listings(id) on delete cascade,
  portfolio_item_id uuid not null references public.portfolio_items(id) on delete cascade,
  entity_id uuid not null references public.entities(id) on delete cascade,
  sort_order integer null,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  constraint service_listing_portfolio_links_unique unique (listing_id, portfolio_item_id)
);
create index service_listing_portfolio_links_listing_sort_idx
  on public.service_listing_portfolio_links (listing_id, sort_order);
alter table public.service_listing_portfolio_links enable row level security;
-- RLS default-deny: REVOKE ALL FROM anon,authenticated; GRANT SELECT,INSERT,UPDATE,DELETE TO authenticated (write further gated by RPC ownership checks); SELECT TO service_role.
-- No anon policy; public visibility enforced inside read RPC (published-only).
```

**RPCs (`SECURITY INVOKER`, `SET search_path`, envelope return):**

1. `service_listing_link_portfolio_items(p_listing_id uuid, p_portfolio_ids uuid[])` — full-replace semantics (idempotent; simplest for reorder + client retry + offline replay dedup):
   - Validate `p_listing_id not null`, array non-null, length `1..8` (cap proof count for detail performance; `PLT003` otherwise), no dup IDs in input.
   - Lock + verify caller owns listing: `service_listings.entity_id == auth.uid()` else `PLT001`; listing must exist else `PLT004`.
   - Verify every `portfolio_items.id` exists **and** `entity_id == auth.uid()` **and** equals listing `entity_id` (ownership guard; any mismatch → `PLT001`, never reveal which ID failed beyond count to avoid enumeration).
   - Optional but recommended: require listing `status IN ('draft','published','paused')` (linking allowed pre-publish so owners can stage proof; visibility still published-only). `archived/reported` → `PLT005`.
   - Delete existing links for listing + insert new rows with `sort_order = array_position`. Single transaction. Return `{success:true, code:'PLT000', data:{listing_id, linked_ids[], count}}`.
   - Trade gate: **no new check** — EP-03-01 `service_listing_*` publish/offer RPCs already enforce `trade_verification_status == APPROVED`; linking is staging, publishing is gating. Document this layering explicitly.
2. `service_listing_unlink_portfolio_item(p_listing_id uuid, p_portfolio_item_id uuid)` — convenience single-remove (owner-checked, idempotent success on already-absent).
3. `service_listing_portfolio_list(p_listing_id uuid)` — public read:
   - If listing `status != 'published'` → `PLT004` for anon / non-owner (mirror draft-privacy of `service_listing_get`); owner may read own drafts (enables staging preview).
   - Else return whitelisted `portfolio_items(id,item_type,title,description,media_path,sort_order, link_sort_order)` ordered by `link sort_order ASC NULLS LAST, created_at ASC`. Never leak `legal_name/document_path/review metadata`. `GRANT EXECUTE TO anon,authenticated,service_role`.
4. (Optional, only if UX needs drag-reorder without full replace) `service_listing_portfolio_reorder(p_listing_id, p_ordered_ids uuid[])` — else reorder rides on full-replace link RPC. Default: **skip separate reorder RPC**; keep surface minimal.

Ordering authority: **link `sort_order`** (per-listing curation), not item `sort_order` (entity showcase order). Client renders server order verbatim, never re-sorts (determinism rule extends to proof order).

### 7.2 Client data layer

- `lib/data/models/service_listing_proof_dto.dart` (new, tiny): `fromJson` for `{portfolio_item columns + link_sort_order}`; `lib/data/mappers/service_listing_mapper.dart` extended (or new `service_proof_mapper.dart` if cleaner) mapping DTO → `(PortfolioItem, linkOrder)`; reuse `PortfolioItemDto.fromJson` for item columns — do not duplicate item parsing.
- Extend `ServiceListingRemoteDataSource` abstract + `SupabaseServiceListingRemoteDataSource` with `linkPortfolioItems/unlinkPortfolioItem/listPortfolioProofs` via `supabase.rpc(...)` through existing `_guard` + `ServiceListingEnvelopeParser` (reuse `PLT000-005` mapping; malformed → `DataException`).
- Extend `ServiceListingRepository` + impl with same three methods returning `List<PortfolioItem>` (ordered) / `int count`; `PLT004 → empty/null` for read (mirrors `PortfolioRepositoryImpl` `PLT004→null`), write errors rethrow as `ApiException` for UI mapping.
- Extend `ServiceListingService` with `linkProofs({listingId, portfolioItemIds, onProgress?})`, `unlinkProof`, `fetchProofs(listingId)` + pure validators: `validateProofSelection(ids)` (non-empty, ≤8, no dups) — ownership/published checks stay server-side. PII-safe logging (`listingIdSuffix` only) + `marketplace.listing.proof.*` Sentry spans mirroring existing `marketplace.listing.*` naming.
- State: add proof fields to `ServiceListingProvider` selection (`proofs`, `proofsState`, `isProofsEmpty`) **or** sibling `ServiceProofProvider` with identical `idle/loading/loaded/error` + `_disposed` guard + `load(listingId)/refresh/link/unlink` (which internally calls service then reloads). Prefer sibling provider if `ServiceListingProvider` diff grows noisy; wire both through `registerMarketplaceLayer` record (no new DI root). Detail screen `watch`es proof provider; instant-paint uses `initialListing`, proofs load async with skeleton.

### 7.3 Client UI

- **Replace `_ProofSlot`** (`service_detail_screen.dart:500-538`) with `ServiceProofSection` (new file `lib/systems/marketplace/widgets/service_proof_section.dart`):
  - States: loading → `HivorrLoadingState`/`HivorrSkeleton`; empty → existing `HivorrEmptyState('No proof linked yet', ...)` copy preserved verbatim + owner-only `HivorrButton('Add portfolio')` opening `LinkPortfolioSheet`; loaded → proof display: **carousel on mobile** (`ServiceMediaCarousel` pattern adapted to `PortfolioItem` via `imageUrlFor: ProfessionalProfileService.mediaPublicUrl`) **or grid** (`PortfolioGrid` with `mediaUrlBuilder`) — decision: carousel when `1..4` image-heavy items on narrow widths, grid otherwise; keep both code paths sharing `PortfolioItemCard`. Error → `HivorrErrorState` + Retry.
  - Header `Proof of work` (`titleMedium`) + `VerificationBadgesRow`-adjacent placement unchanged; proof never replaces badges. Each proof tile deep-links to owner's `/p/:slug/:id` (profile) for full context.
  - `isOwner` from existing detail model (`viewerId == listing.entityId`); non-owner never sees picker entry. `Book/Request Proposal` CTA untouched.
- **`LinkPortfolioSheet`** (new `lib/systems/marketplace/widgets/link_portfolio_sheet.dart`): `HivorrBottomSheet` containing search field (reuse `TaxonomySearchField` pattern) + multi-select list of owner's `portfolio_items` (fetched via existing `PortfolioProvider.load(viewerId)` — owner reading own items; note `portfolio_public_profile_get` requires ≥1 approved profession, which owner by definition staging a listing should have; if `PLT004`, sheet shows guidance state) with `PortfolioItemCard`-compact rows + check affordances + `Save (n)` `HivorrButton`; on save → `ServiceListingService.linkProofs` → provider reload → success `HivorrSnackbar`. Handles `PLT001/003/004/005` → `HivorrErrorState`/snackbar copy (non-owner impossible client-side, but server message surfaced if session changed).
- **Profile cross-link (minimal):** detail proof header gets `View full portfolio → /p/:slug/:id` link; `ProfessionalProfileScreen` unchanged except optionally showing `Used in N services` chip later — out of this task's default scope.
- **Theme/responsive:** all new widgets consume `context.colorScheme` / `extension<AppThemeExtension>()` / `textTheme`, `HivorrSpacing`/`HivorrElevation`/`HivorrMotion`; layouts via `HivorrContentPane` / `HivorrResponsiveScaffold` / `breakpoints.dart`; `const` constructors, `ListView`/lazy where long, `Image.network(cacheWidth:1200, gaplessPlayback, loading/error→placeholder)` copied from `PortfolioItemCard`.

### 7.4 Why this approach (and not alternatives)

- **Junction over array/FK-on-item:** preserves item reuse across multiple listings (one portfolio piece can prove several services), per-listing ordering, and clean RLS; array would couple listing row size to proof count and complicate per-link audit.
- **Full-replace link RPC over incremental add/remove-only:** idempotent (safe retry/offline replay with `client_message_id`-style dedup via unique constraint), single round-trip for reorder, trivial conflict semantics. Single-unlink convenience added for swipe-to-remove without refetching full selection.
- **Sheet over new route:** proof linking is a sub-task of detail/my-listings, not a destination; sheet preserves `:id`-authoritative routing, avoids guard/SEO surface growth, and matches `discovery_filter_sheet.dart` precedent. Full-page route reserved only if bulk-manage UX demands it.
- **Extend marketplace seam over new portfolio-write system:** portfolio remains the item source of truth; marketplace owns the *relationship*. One seam, one envelope, one DI record — no parallel proof stack.

## 8. Required Systems, Modules, and Components

| # | Component | Location | New / Extend / Reuse |
|---|---|---|---|
| 1 | Junction table + indexes + RLS + triggers | `supabase/migrations/2026*_service_listing_portfolio_links.sql` | **New** |
| 2 | Link/unlink/list (+optional reorder) RPCs | same migration | **New** |
| 3 | pgTAP link + RLS + leakage suite | `supabase/tests/database/0*_service_listing_portfolio_links.sql` | **New** (mirrors `018` harness) |
| 4 | Proof DTO + mapper extension + view-model | `lib/data/models/service_listing_proof_dto.dart` (new, tiny), `lib/data/mappers/service_listing_mapper.dart` or `service_proof_mapper.dart` | **New tiny + extend** |
| 5 | Remote datasource methods | `lib/data/datasources/remote/service_listing_remote_data_source.dart` + `supabase_service_listing_remote_data_source.dart` | **Extend** |
| 6 | Repository methods | `lib/data/repositories/service_listing_repository.dart` + `_impl.dart` | **Extend** |
| 7 | Service methods + validators | `lib/systems/marketplace/services/service_listing_service.dart` | **Extend** |
| 8 | Proof provider state | `lib/data/providers/service_listing_provider.dart` extension or new `service_proof_provider.dart` via `registerMarketplaceLayer` | **Extend** |
| 9 | `ServiceProofSection` (replaces `_ProofSlot`) | `lib/systems/marketplace/widgets/service_proof_section.dart` (new composition) | **New composition of reused widgets** |
| 10 | `LinkPortfolioSheet` picker | `lib/systems/marketplace/widgets/link_portfolio_sheet.dart` (new composition) | **New composition of reused widgets** |
| 11 | Detail screen wiring | `lib/systems/marketplace/screens/service_detail_screen.dart` | **Extend** (slot swap + provider watch) |
| 12 | Barrel + DI wiring | `lib/systems/marketplace/marketplace.dart`, `marketplace_dependency_injection.dart`, `lib/data/data_layer.dart` | **Extend exports only** |
| 13 | SEO `og:image` fallback | `service_detail_screen` meta path + `PortfolioSeoMetaBuilder` usage | **Extend usage** |
| 14 | Fakes + test support | `test/support/fakes/fake_service_listing.dart` (extend), `test/support/portfolio/portfolio_test_support.dart` (reuse) | **Extend** |

No changes to: `portfolio_public_profile_get`, `service_listing_get`, `service_ranking_search`, `service_search`, storage buckets/policies, router tables, `VerificationBadgesRow`, `PortfolioGrid`/`PortfolioItemCard` internals, AI layer.

## 9. Data Requirements

- **Input (link write):** `p_listing_id: uuid`, `p_portfolio_ids: uuid[1..8]`, caller JWT (`auth.uid()`). Client pre-validates: non-empty, deduped, ≤8, all UUID well-formed; server re-validates authoritatively.
- **Output (link write):** envelope `data: {listing_id, linked_ids: uuid[], count: int}`.
- **Output (list read):** envelope `data: [{id, item_type, title, description, media_path, sort_order, link_sort_order}]` ordered by `link_sort_order ASC NULLS LAST, created_at ASC`. Media bytes never travel over RPC — client resolves `media_path` → public CDN URL via `ProfessionalProfileService.mediaPublicUrl` (null → placeholder).
- **Entities:** reuse `PortfolioItem`; add `linkSortOrder` context at view-model layer only. No `entity_id/created_by/legal_name/document_path` in any client payload.
- **Validation rules (client mirrors, server enforces):** listing exists + caller-owned; every item exists + caller-owned + same `entity_id`; cap 8; no dups; `archived/reported` listings reject (`PLT005`); unpublished listings linkable but not publicly visible.
- **No PII in logs:** `listingIdSuffix`/`entityIdSuffix` only via `pii_redactor`; never log full IDs, titles, or media paths.

## 10. Database Considerations

- **Additive only.** One new migration; zero edits to `20260913090001_portfolio_public_profile.sql`, `20260921090001_service_marketplace_schema.sql`, or any EP-01/EP-02 migration (ENV + Rule 4 compliance).
- **Integrity:** FKs `listing_id→service_listings(id) ON DELETE CASCADE`, `portfolio_item_id→portfolio_items(id) ON DELETE CASCADE`, `entity_id→entities(id) ON DELETE CASCADE`; `UNIQUE(listing_id, portfolio_item_id)` doubles as idempotency guard for retry/replay; `CHECK` on array length enforced procedurally in RPC (Postgres array cardinality check).
- **RLS:** `ENABLE RLS`; `REVOKE ALL FROM anon,authenticated`; `GRANT SELECT,INSERT,UPDATE,DELETE TO authenticated`, `SELECT TO service_role`; policies: owner-only write (`entity_id == auth.uid()`), **no anon policy** — public visibility gated inside `service_listing_portfolio_list` (published-only), mirroring `portfolio_public_profile_get`'s RPC-as-public-read precedent and `service_listing_media_select_public`'s published-only posture.
- **Indexes:** `(listing_id, sort_order)` composite for detail fetch; unique constraint index covers dedup; consider `(portfolio_item_id)` lookup for "used in N services" later (defer unless needed).
- **Concurrency:** link RPC takes `FOR UPDATE` lock on parent `service_listings` row (or advisory lock on `listing_id`) so concurrent full-replace writes serialize; unique violation maps to `PLT005` retry-safe.
- **Realtime:** exclude junction table from `supabase_realtime` publication (proof updates ride on detail refetch, not live subscription — matches portfolio precedent).
- **pgTAP:** assert table/cols/unique/index/trigger/RLS-enabled/no-anon-grants/owner-write/public-read-via-RPC-only/published-vs-draft visibility/`PLT001` non-owner/`PLT003` null+oversize/`PLT004` unknown/`PLT005` archived + leakage matrix (entity-B reads 0 rows of entity-A drafts).

## 11. API Requirements

All RPCs `SECURITY INVOKER`, `STABLE` for read / `VOLATILE` for writes, `SET search_path = pg_catalog, public`, envelope return, `REVOKE EXECUTE FROM public`:

| RPC | Execute grant | Codes |
|---|---|---|
| `service_listing_link_portfolio_items(uuid, uuid[])` | `authenticated, service_role` (no `anon`) | `PLT000` ok; `PLT001` not-owner; `PLT003` null/empty/>8/dup/malformed; `PLT004` listing-or-item not found (identical message, no oracle); `PLT005` archived/reported/conflict; `PLT999` server |
| `service_listing_unlink_portfolio_item(uuid, uuid)` | `authenticated, service_role` | same code family; absent link → idempotent `PLT000` |
| `service_listing_portfolio_list(uuid)` | `anon, authenticated, service_role` | `PLT000` with ordered array; `PLT004` for unknown or unpublished-to-non-owner; `PLT003` null id |

Client seam: exactly one datasource per RPC family (`SupabaseServiceListingRemoteDataSource`), errors normalized via existing envelope parser → `ApiException(kind: auth/forbidden/validation/notFound/conflict/server)`. No direct `postgrest` table writes to the junction table from client (table `INSERT` for `authenticated` may remain granted for RLS completeness, but canonical path is RPC; document RPC-only like financial tables where applicable).

## 12. User Interface Requirements

- **`ServiceProofSection`** in listing detail below media/pricing/badges, above reviews/CTA (replacing `_ProofSlot` position):
  - Loading: `HivorrSkeleton`/loader pulse; Loaded with items: carousel (narrow) / `PortfolioGrid` (wide) with `mediaUrlBuilder: ProfessionalProfileService.mediaPublicUrl`; Empty: preserve current `HivorrEmptyState('No proof linked yet', ...)` copy + owner-only `HivorrButton.outline('Add portfolio')`; Error: `HivorrErrorState` + Retry.
  - Proof tiles reuse `PortfolioItemCard` (thumb + type chip + title/desc); tap → owner profile `/p/:slug/:id` or lightbox (lightbox only if existing infra, else profile link).
  - Owner row: `Edit proof` affordance opening the same sheet (unlink/reorder).
- **`LinkPortfolioSheet`**: bottom sheet (mobile) / dialog (desktop via responsive scaffold), search + checkbox list + `Save (n)`; empty (owner has no items) → `HivorrEmptyState` + `Create portfolio piece` guidance (navigates to portfolio creation path if exists, else static guidance — no new creation UI here); error → inline `HivorrErrorState`.
- **My listings (optional, low-cost):** overflow/menu `Manage proof` on `ServiceListingCard` opening the same sheet — only if it adds no new route/state; otherwise detail-only entry suffices for v1.
- **Visual identity (DoD-gating):** `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme` only; `HivorrCard/ContentPane/Chip/Badge/Button/Empty/Error/Loading` throughout; button touch targets ≥48dp; no `Colors.*`/hex/`fontFamily` literals.

## 13. User Experience Considerations

- **Owner staging:** linking allowed on `draft` so proof is ready before `Publish`; communicate via helper text `Only published listings show proof publicly`.
- **Idempotent saves:** full-replace + unique constraint means double-tap/retry never duplicates; show single success snackbar, no optimistic ghost tiles (await RPC, then reload).
- **Cap communication:** `Up to 8 pieces — pick your strongest work` counter in sheet (`3 of 8 selected`); attempt beyond cap blocked client-side with inline hint, server `PLT003` as backstop.
- **Empty states stay calm** per `VISUAL-IDENTITY.md §9`: viewer's empty copy remains `Proof of work will appear here once the professional links it` (no dead-ends); owner's copy is action-oriented.
- **Offline:** link writes are online-only (server-authoritative ownership); if offline, sheet save surfaces connectivity error with retry (reuse `connectivity_plus` gating pattern from EP-03-13, do not build an offline proof queue in this task).
- **Accessibility:** sheet list items expose semantics (`Selected — {title}`), carousel dots expose page semantics, `TradeVerifiedBadge` semantics preserved.
- **Localization:** all new strings via `lib/core/localization` (no hardcoded user-facing English outside l10n tables).

## 14. Security Considerations

- **Zero-trust client (`AGENT.md:13`, Rule 4):** ownership + published-visibility enforced in RPC, never client-evaluated. RLS default-deny; `anon` zero grants on junction table; `authenticated` direct writes non-canonical (RPC-only documented).
- **No enumeration oracle:** unknown listing vs unpublished-to-viewer vs missing item all return identical `PLT004`; non-owner link returns `PLT001` without disclosing which ID mismatched.
- **No PII/financial leakage:** proof payload whitelists showcase columns only; `legal_name`, `document_path`, reviewer metadata, KYC limits, balances never selected. Public CDN URLs only for `portfolio-items`/`service-listing-media` (both public buckets); never `getPublicUrl` on `credential-documents`.
- **Trade/KYC posture unchanged:** linking does not bypass publish/offer gates; `VerificationBadgesRow` remains the sole verification signal. Document that an unverified owner can stage links but cannot publish (server gate in EP-03-01).
- **Injection/validation:** array input cardinality + UUID shape validated server-side; `media_path` CHECK parity (`portfolio-items/{entity_id}/%`) already prevents path traversal; client `sanitize` reused if any filename handling arises (none expected — link-only).
- **Audit:** `created_by = auth.uid()` + `created_at`; link writes optionally emit `contract_events`-style audit only if listing audit infra exists — otherwise table audit columns suffice (do not invent a new audit table).

## 15. Performance Considerations

- **Small-N read:** proof sets capped at 8; single indexed `JOIN` (`listing_id` → links → items) per detail view; no pagination needed; no N+1 (one RPC returns all tiles).
- **No ranking/search impact:** proof fetch is out-of-band from `service_ranking_search`/`service_search`; discovery lists never join proofs (detail-only fetch). p95 search budget (<400ms per EP-03-20) untouched.
- **Images:** CDN public URLs + `cacheWidth:1200` + `gaplessPlayback` (copied from `PortfolioItemCard`); no bytes over RPC; placeholder on null/failure.
- **Rebuild discipline:** provider `watch` scoped to proof section; `const` constructors; no per-frame allocation (follow `PortfolioProvider`/`ServiceListingProvider` patterns); sheet list lazy (`ListView.builder`) for owners with large portfolios.
- **No new cache layer** (justified in §6); detail refetch on link-save only.

## 16. Testing Strategy

- **pgTAP** (`supabase/tests/database/0*_service_listing_portfolio_links.sql`, `plan(~30)` mirroring `018` harness):
  - DDL: table/cols/unique/index/trigger/RLS-enabled/no-anon-grants/owner-write/public-read-via-RPC-only/published-vs-draft visibility/`PLT001` non-owner/`PLT003` null/empty/>8/dups; `PLT004` unknown listing / unknown item (identical); `PLT005` archived/reported; `PLT000` happy path + order preserved + full-replace idempotency + unlink idempotency.
  - Visibility: anon reads published-links ok; anon reads draft-links → `PLT004`/0 rows; entity-B reads entity-A draft → 0; owner reads own draft ok.
  - Leakage: `legal_name/document_path` negative asserts on read payload.
- **Unit (Dart, `test/unit/`):** proof DTO/mapper (whitelist + order mapping), `ServiceListingService.validateProofSelection` (empty/dup/>8), envelope parser new codes, repository `PLT004→empty` mapping, provider state transitions — reuse `fake_service_listing.dart` + `fake_portfolio.dart` patterns.
- **Widget (`test/widget/marketplace/`):** `ServiceProofSection` states (loading/empty/loaded/error), owner vs viewer CTA visibility, sheet multi-select + cap counter + save wiring (mock service), theme-token assertion (no `Colors.*` — grep gate), golden mobile+web for detail proof block.
- **Integration (`test/integration/`):** owner creates item (via fake/seed) → links to published listing → signed-out detail shows carousel; non-owner link attempt surfaces `PLT001`; unlink → empty state + owner CTA; draft listing proof hidden from anon but visible to owner.
- **Static:** `dart analyze`, `flutter test`, `grep Colors\.|fontFamily` zero-tolerance, `dart format` (or project formatter).

## 17. Recommended Implementation Sequence

1. **DB migration + pgTAP** — junction table + RLS + 3 RPCs + grants; pgTAP green (unblocks all client work; parallelizable with step 2's pure-Dart DTO/validator work).
2. **Data layer extensions** — DTO → mapper → datasource → repository (+ fakes), unit-tested.
3. **Service + provider extensions** — `link/unlink/list` + validators + spans/logging; unit-tested.
4. **`ServiceProofSection`** — replace `_ProofSlot`, wire provider watch + `mediaPublicUrl`; widget-tested.
5. **`LinkPortfolioSheet`** — picker + save flow + error mapping; widget-tested.
6. **Detail wiring + profile cross-link + SEO `og:image` fallback** — no router change; integration-tested.
7. **Full matrix + DoD audit** — pgTAP + `flutter test` + analyzer + token grep + anon-vs-owner visibility + EP-03-20 input (#10 proof-linkage check data).

## 18. Expected Outcome

A listing detail page where linked portfolio evidence renders as a first-class trust signal: verified owners curate up to 8 proof pieces per service (staged on draft, visible on published), and any visitor — including signed-out web — sees the ordered carousel/grid with public CDN thumbnails, with verification badges remaining the authoritative trust signal. Non-owners cannot link; drafts leak nothing; empty states guide owners to act and reassure viewers. The junction pattern is documented for EP-04 (`product_listings` mirror) and the sheet composition is reusable for future multi-select linking. EP-03-09 discovery, ranking, contracts, escrow, reviews, messaging, and scheduling are untouched.

## 19. Definition of Done (DoD)

- [ ] Migration creates `service_listing_portfolio_links` (+ unique, index, RLS default-deny, no anon grant, realtime-excluded) without editing any existing migration.
- [ ] `service_listing_link_portfolio_items` enforces ownership (listing + every item, same `entity_id`), cap 8, dedup, `archived/reported → PLT005`, full-replace idempotent, envelope-coded; non-owner → `PLT001`.
- [ ] `service_listing_portfolio_list` returns whitelisted ordered items for `published` to `anon`; draft/unpublished hidden from non-owners (`PLT004`/0 rows); owner sees own drafts.
- [ ] pgTAP suite green (DDL + RPC matrix + visibility + leakage + identical-`PLT004`).
- [ ] Data layer extended (DTO/mapper/datasource/repository/service/provider) with unit tests; no forked `PortfolioItem`; no client-side ownership/published decisions.
- [ ] `_ProofSlot` replaced by `ServiceProofSection` (loading/empty/loaded/error) reusing `PortfolioGrid`/`PortfolioItemCard`/`ServiceMediaCarousel` pattern + `mediaPublicUrl`; server order rendered verbatim.
- [ ] Owner `Add portfolio`/`Edit proof` opens `LinkPortfolioSheet` (search + multi-select ≤8 + save); success snackbar + reload; `PLT001/003/004/005` surfaced as `HivorrErrorState`/snackbar.
- [ ] Unlinked listing shows preserved `HivorrEmptyState` copy (viewer vs owner variants); no snackbar placeholder remains.
- [ ] `VerificationBadgesRow`/`TradeVerifiedBadge` untouched and still authoritative; proof never implies verification.
- [ ] No new route, no new bucket, no new package, no ranking/search/contract/escrow change; `dart analyze` + `flutter test` green; zero `Colors.*`/hex/`fontFamily` literals in new widgets; localized strings only.
- [ ] Integration test green: item → link → published → anon sees proof; non-owner blocked; unlink → empty state.

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: High**
- **Reasoning Level Justification:** Moderate-high integration complexity (new junction + RLS + 3 RPCs bridging two mature systems — portfolio and marketplace — with ownership/published-visibility invariants), but **no** financial ledger, escrow state machine, deterministic ranking formula, or double-blind cryptographic invariant (the drivers of Very/Extremely High in EP-03-01/02/03/06/11). Business impact is trust-conversion (High) with privacy risk bounded by published-only reads and whitelisted projections; security risk is contained to well-understood RLS+INVOKER+envelope patterns already proven in `018`/`20260921090001`. High (matching the Phase Plan's own `Planning: High / Coding: High` for EP-03-15) provides sufficient rigor for the RLS matrix and cross-system UI without the exhaustive formal-verification overhead reserved for fund-moving tasks.

---

*Implemented and verified per the Definition of Done. Two build-time corrections apply (documented in DoD §10): the public-list read RPC is SECURITY DEFINER (INVOKER reads of `portfolio_items` are impossible by design), and junction write policies carry the owned-listing conjunct.*
