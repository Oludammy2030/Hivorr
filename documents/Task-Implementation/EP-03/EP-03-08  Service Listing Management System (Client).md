# Task Implementation Plan — EP-03-08: Service Listing Management System (Client)

> **Planning artifact only — no production code written. Awaiting approval before implementation.**
> Sources: `documents/Context/AGENT.md`, `documents/Context/ARCHITECTURE.md`, `documents/Context/VISUAL-IDENTITY.md`, `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md §EP-03-08` (lines 323-332).

---

## 1. Task Objective

Build the **supply-side owner CRUD** for the professional services marketplace as a thin, unprivileged Flutter presentation layer over the already-landed EP-03-01 server contract:

- `draft / create / update / publish / unpublish (→paused) / get / list_mine` via the 7 `SECURITY INVOKER` RPCs in `supabase/migrations/20260921090001_service_marketplace_schema.sql`
- Media attach/detach/reorder via RLS-scoped `service_listing_media` rows + `service-listing-media` Storage bucket
- Profession binding via the existing two-tier `industries → professions` taxonomy

Per `AGENT.md:6,13` (Separation of Concerns, Rule 4 Database-First Zero-Trust): **no pricing, ranking, gate, or slug logic in the client.** All authoritative validation (title 10–120, description 50–5000, pricing vocab, currency active, profession bound+active, trade gate `approved` on publish, D5 publish-guard) stays server-side. Client mirrors it only for fast UX feedback.

---

## 2. Business Problem Being Solved

Verified professionals have no way to create supply. Without an owner listing flow:

- EP-03-09 discovery, EP-03-10 contracts, EP-03-15 portfolio linkage, EP-03-19 SEO routes have nothing to render/transact on.
- Unverified supply cannot be gated at creation time (Rule 2 trust risk).
- Media proof (cover images, work samples) cannot be attached, reducing conversion (`Business-Roadmap:225` proof-of-work → trust).

EP-03-08 unblocks Stage 3 (first user-visible marketplace) per Phase Plan §6.

---

## 3. Scope

**In scope (exactly EP-03-08):**

1. Data vertical slice (owner writes + reads):
   - `ServiceListingRemoteDataSource` + `SupabaseServiceListingRemoteDataSource` wrapping RPCs: `service_listing_create`, `service_listing_update`, `service_listing_publish`, `service_listing_unpublish`, `service_listing_get`, `service_listing_list_mine` (+ `service_favorite_toggle` read-through only where needed for detail preview — no favorites screen).
   - `ServiceListingRepository` (+ impl) entity-only, fail-fast `PLT003` pre-validation, re-read-after-write pattern.
   - `ServiceListingProvider` (`ChangeNotifier`, `idle/loading/loaded/error`, keyset pagination `(created_at DESC, id DESC)`, status filter, selected detail memo).
   - `ServiceListingService` thin facade (`lib/systems/marketplace/services/service_listing_service.dart`) with static `validateTitle/Description/Price*` mirroring SQL CHECKs + PII-redacted logging.
   - DTO/mapper extension for owner projection (`status`, `media[]`, `updated_at`) — see §6.
2. Media pipeline: pick → `StorageValidators.validateForBucket` → `StorageService.upload(service-listing-media, ...)` with `onSendProgress` → RLS `INSERT service_listing_media` → link; reorder via `UPDATE(sort_order)`; delete via RLS `DELETE` + `StorageService.remove`.
3. Screens (3, per Phase Plan):
   - `service_listing_form_screen.dart` (create/edit: profession step + details step + pricing step)
   - `service_listing_media_screen.dart` (picker grid, progress, retry, cover ordering)
   - `my_listings_screen.dart` (owner list with status `HivorrChip` filter + pagination + empty/error/loading states)
4. DI wiring: `registerServiceListingLayer()` in `lib/data/data_layer.dart` mirroring `registerMarketplaceSearchLayer` / `registerDisputeLayer`; `lib/systems/marketplace/marketplace_dependency_injection.dart` mirroring `lib/systems/portfolio/portfolio_dependency_injection.dart`.
5. Router additions: `/services/mine`, `/services/mine/new`, `/services/mine/:id/edit`, `/services/mine/:id/media` (protected; reads via `service_listing_get` stay RPC, not public SEO — SEO is EP-03-19).
6. Storage client extensions: `service-listing-media` bucket constants, path helper, picker entry (see §6).
7. Unit + widget tests for the new slice (see §15).

---

## 4. Out of Scope

Explicitly **not** in EP-03-08 (deferred to named tasks, no silent expansion):

- Any new migration / RPC / RLS / bucket policy — EP-03-01 contract is reused verbatim.
- Discovery/search UI (`EP-03-09`), ranking formula changes (`EP-03-06`), FTS changes (`EP-03-07`) — read-only `service_ranking_search` is never called for ordering here.
- Contract offer/accept, milestone editor, escrow linkage (`EP-03-10/11`).
- Review submit/reveal (`EP-03-12`), messaging (`EP-03-13`), scheduling (`EP-03-14`), portfolio link RPC (`EP-03-15`), earnings (`EP-03-16`), disputes (`EP-03-17`), notifications (`EP-03-18`), public SEO routes `/s/:slug/:id` (`EP-03-19`).
- Admin moderation console / `reported` transitions (service_role-only; client surfaces `reported` as read-only badge).
- AI-assisted drafting (`lib/ai/*` excluded from EP-03 per Phase Plan §8.2).

---

## 5. Existing Asset and Dependency Analysis

Inspected live codebase (read-only). `lib/systems/marketplace/` contains only `.gitkeep` — all logic must arrive via reuse/extension below.

| Asset (exact path) | Status | Relevance to EP-03-08 |
|---|---|---|
| `supabase/migrations/20260921090001_service_marketplace_schema.sql` (1310 lines: tables + 7 RPCs + RLS + bucket) | **Reuse verbatim** | Canonical contract. `service_listing_create(p_profession_id, p_title, p_description, p_pricing_type, p_price_min/max, p_currency_code, p_status)`; `update(p_listing_id, ...nullable)`; `publish(uuid)`; `unpublish(uuid, p_reason)`; `get(uuid)` STABLE public+owner; `list_mine(p_status, p_limit 1–100, p_cursor uuid)` keyset `(created_at,id)`; `favorite_toggle`. CHECKs + trade-gate `PLT005` + D5 guard + envelope `PLT000–005`. No new DDL needed. |
| `lib/data/entities/service_listing.dart`, `lib/data/models/service_listing_dto.dart`, `lib/data/mappers/service_listing_mapper.dart` | **Extend** | Ranked-projection only (no `status`/`media`). Owner detail needs `status/media[]/updated_at`. Parser helpers (`parseDouble/Int/Date`) reused. |
| `lib/data/datasources/remote/service_search_remote_data_source.dart` + `service_search_envelope_parser.dart`; `supabase_dispute_remote_data_source.dart` + `dispute_envelope_parser.dart` + `dispute_remote_data_source.dart` | **Reuse pattern** | Template for new remote: extend `BaseApiService`, `_guard(mapDataException)`, `supabase.rpc(...)`, `EnvelopeParser.unwrap`. Dispute's 5-RPC file is the closest CRUD analogue. |
| `lib/data/repositories/dispute_repository*.dart`, `service_search_repository*.dart`, `verification_repository*.dart` | **Reuse pattern** | `fileDispute` re-read-after-write + `_requireInVocabulary/_requireLength→PLT003` mirrored for listings. `entityId=auth.uid()` never caller-trusted. |
| `lib/data/providers/dispute_provider.dart`, `marketplace_search_provider.dart`, `taxonomy_provider.dart`, `submit_state.dart` | **Reuse pattern / reuse directly** | `DisputeProvider` list/select/refresh + lifecycle pause gate = template for `ServiceListingProvider`. `TaxonomyProvider` + `MarketplaceSearchProvider` reused directly (no new taxonomy/search code). |
| `lib/data/data_layer.dart` (`registerMarketplaceSearchLayer`, `registerDisputeLayer`, `registerVerificationLayer`) | **Extend** | Add `registerServiceListingLayer()` following identical shape. |
| `lib/workspace/profession_registry/taxonomy_engine.dart`, `widgets/profession_picker.dart`, `industry_picker.dart`, `profession_registry_browser.dart`, `taxonomy_search_field.dart`, `profession_registry.dart` | **Reuse verbatim** | Editor profession step: embed `ProfessionRegistryBrowser(continueLabel:'Use profession')` over `TaxonomyProvider`. No new taxonomy UI. |
| `lib/core/storage/supabase_storage_service.dart`, `storage_service.dart`, `storage_validators.dart`, `storage_exceptions.dart` | **Reuse verbatim** | Upload/download/remove/getPublicUrl abstraction + fail-fast MIME/size + PLT-mapped errors. |
| `lib/core/storage/storage_config.dart`, `storage_paths.dart` | **Extend (additive)** | Missing `service-listing-media` entry (only 3 EP-02-06 buckets present). Add bucket + 10MiB + `jpg/png/webp/pdf` + `public:true` + `listingMedia({entityId,listingId,fileName})` helper. |
| `lib/core/platform/platform_file_picker.dart` (+ `file_picker_web_options*.dart`) | **Extend (additive)** | `pickDocument()` already matches listing allowlist; add `pickListingMedia()` alias or reuse `pickDocument()`. Never import `file_picker` directly in screens. |
| `lib/systems/portfolio/services/professional_profile_service.dart`, `screens/professional_profile_screen.dart`, `widgets/portfolio_item_card.dart`, `portfolio_grid.dart`, `portfolio_dependency_injection.dart` | **Reuse pattern** | Facade + loading/error/empty state machine + public-URL media card + DI factory shape. |
| `lib/systems/verification/screens/trade_proof_upload_screen.dart`, `identity_document_upload_screen.dart`; `lib/systems/support/screens/dispute_evidence_form_screen.dart`, `dispute_filing_screen.dart`; `lib/systems/support/services/dispute_service.dart` | **Reuse pattern** | Storage-before-RPC ordering, `_FileCard + LinearProgressIndicator + retry`, `PickXxxCallback` injectable seams for tests, static `validateReason/Title/Description` style, `DropdownButtonFormField` vocab pattern. |
| `lib/systems/onboarding/screens/industry_profession_selection_screen.dart`, `widgets/onboarding_document_upload_tile.dart`, `onboarding_avatar_picker.dart` | **Reuse pattern** | Profession dropdown gating + media tile chrome. |
| `lib/shared/*` (`hivorr_button/card/empty_state/error_state/loading_state/success_state/snackbar/badge/chip/text_field`, `components/hivorr_form_field/dialog/bottom_sheet/list_tile/section_header`, `layouts/hivorr_content_pane/screen_scaffold/responsive_scaffold/breakpoints`, `validators/hivorr_validators`, `mixins/form_validation_mixin/loading_state_mixin`, `helpers/hivorr_formatters/spacing`, `extensions/*`) | **Reuse verbatim** | Entire form/list/media UI composed from tokens. No new primitives. |
| `lib/app/theme/app_colors.dart` (`brandPrimary #0B6E99`), `app_text_theme.dart`, `app_theme.dart` | **Reuse verbatim** | `context.colorScheme / appExtension / textTheme` only; hardcoded `Colors.*`/hex/`fontFamily` fails DoD (Rule 5). |
| `lib/app/router/app_router.dart`, `route_paths.dart`, `route_names.dart`, `route_guard.dart` | **Extend (additive)** | Add 4 protected `GoRoute`s + path/name constants + typed builders. No guard logic change. |
| `lib/systems/finance/widgets/escrow_write_cta_panel.dart`, `milestone_list_card.dart` | **Reuse pattern** | Publish/unpublish CTA + trade-gate guidance card (`PLT005 unverified → guidance`, mirrors `writeAvailable` gate). |
| `test/support/fakes/fake_taxonomy.dart`, `fake_supabase_storage.dart`, `fake_service_search.dart`; `test/unit/core/storage/*_test.dart`; `test/unit/shared/validators_test.dart` | **Reuse + extend** | Taxonomy fakes reused directly; storage fakes + validator/path tests extended with listing-bucket cases. |
| `supabase/tests/database/024_service_marketplace_rpc_enforcement.sql` (116 asserts), `023_service_marketplace_schema_posture.sql` | **Reuse (no new DB tests)** | Server enforcement already proven; client task adds no SQL. If media-update ordering asserts are missing they belong to a future schema task, not EP-03-08. |

**Dependencies (must land/be available before or alongside):** EP-03-01 (server contract — landed), EP-02-06 (storage infra pattern), EP-02-07 (taxonomy engine/provider), EP-01-16 (design system), EP-01-07 (ApiLayer/BaseApiService), EP-01-15 (router), `file_picker:12.3.0` + `file_picker_web:3.1.0` (already wired).

---

## 6. Reuse / Extension / Refactoring Assessment

| Proposed asset | Verdict | Why not the alternatives |
|---|---|---|
| Server tables/RPCs/RLS/bucket policies | **Reuse** — zero new SQL | Contract landed and pgTAP-covered (024: 116 asserts). Creating parallel tables or client-side gates would violate Rule 4 + D5 guard. |
| `ServiceListing` entity / `ServiceListingDto` / `ServiceListingMapper` | **Extend** — add `status`, `media: List<ListingMedia>`, `updated_at` (owner view); add `MyListingPageDto {items, has_more, next_cursor(uuid)}`, `ListingMediaDto {id, storage_path, mime_type, sort_order, created_at}`; add `toOwnerEntity/fromOwner` mappers preserving existing ranked mappers untouched | Refactoring the ranked entity in place would risk `AGENT.md:7` verbatim-order invariant consumed by EP-03-09. Additive extension isolates owner concerns. |
| `StorageBuckets/StorageLimits/StorageMimeTypes/StorageBucketVisibilities` | **Extend** — add `serviceListingMedia='service-listing-media', 10MiB, {jpeg,png,webp,pdf}, public:true` mirroring migration §bucket + parity test | Reuse impossible (bucket absent); new parallel config file would duplicate source of truth — extension is the sanctioned pattern (`storage_config.dart` header). |
| `StoragePaths` | **Extend** — add `listingMedia({entityId, listingId, fileName}) => {entityId}/{listingId}/{uuid}_{safe}` mirroring `portfolioItem`/`disputeEvidence` owner-prefix convention | Same rationale; keeps RLS `WITH CHECK (foldername[1]=auth.uid())` passing. |
| `PlatformFilePicker` | **Extend** — add `pickListingMedia()` (same extensions as `pickDocument`) or document reuse of `pickDocument()` | Avoids screens importing `file_picker` directly (separation of concerns). |
| `ServiceListingRemoteDataSource` + Supabase impl + `ServiceListingEnvelopeParser` | **New (genuine gap)** — modeled line-for-line on `SupabaseDisputeRemoteDataSource` + `DisputeEnvelopeParser` | No existing remote wraps the 7 listing RPCs; extending `ServiceSearchRemoteDataSource` would conflate ranked-read with owner-write responsibilities (domain separation). Designed for reuse: EP-03-10/15/19 consume `get/list_mine` through it. |
| `ServiceListingRepository` + impl | **New (genuine gap)** | Same — no owner-CRUD repo exists; `ServiceSearchRepository` is read-only by design. |
| `ServiceListingProvider` + `ServiceListingService` | **New (genuine gap)** | `MarketplaceSearchProvider` owns ranked discovery; `DisputeProvider` owns disputes. Owner-listing lifecycle (draft→published→paused, media queue, form state) is a distinct state machine. Mirrors `DisputeProvider`/`PortfolioProvider` shape for future reuse by EP-03-10. |
| Screens `service_listing_form/media/my_listings` + widgets (`listing_card`, `media_tile`, `status_badge` via `HivorrBadge`, `pricing_type_selector` via `HivorrChip`) | **New (genuine gap)** — composed 100% from `shared/` + `profession_registry/` primitives | `lib/systems/marketplace/` is empty; no existing listing screen to extend. Portfolio screens are read-only and cannot be generalized without breaking their contract. |
| `registerServiceListingLayer` + `marketplace_dependency_injection.dart` + router paths/names | **Extend (additive)** | Follows `registerDisputeLayer` / `portfolio_dependency_injection.dart` / `route_paths.dart` builder pattern. |

No refactoring of existing assets is recommended — all reused assets are fit for purpose as-is.

---

## 7. Recommended Technical Approach

**Layering (ARCHITECTURE.md `lib/` schema + AGENT.md separation):**

```
UI (lib/systems/marketplace/screens|widgets)
  → ServiceListingService (validation mirror + orchestration: upload-then-RPC)
  → ServiceListingProvider (ChangeNotifier, pagination, selection)
  → ServiceListingRepository (entity-only, PLT003 fail-fast, re-read-after-write)
  → SupabaseServiceListingRemoteDataSource (BaseApiService, supabase.rpc, envelope unwrap)
  → Supabase RPCs (authoritative) + StorageService (bucket) + RLS media table
```

Key rules:

1. **RPC-only writes for listings.** Never `from('service_listings').insert/update`. Media rows use RLS-scoped REST (`service_listing_media` grants: `select` anon+auth, `insert/update(sort_order)/delete` own) — the migration's sanctioned split.
2. **Storage-before-RPC** (copied from `verification_repository` / `dispute_evidence_form_screen`): `pick → validateForBucket → upload(path=StoragePaths.listingMedia) → insert media row → call create/update`. Failure at any step aborts with field-level error; orphan uploads cleaned via `StorageService.remove` on RPC failure.
3. **Client validation mirrors, never replaces, server CHECKs:** title `10..120` trimmed, description `50..5000` trimmed, `pricing_type ∈ {fixed,hourly,custom,per_milestone}`, `price_min ≥0`, `price_max ≥ price_min`, `price_min required unless custom`, currency ∈ active `NGN/GHS/USD/GBP`, profession non-null + bound (checked via `TaxonomyEngine`/provider selection; server re-checks binding + `approved` gate with `PLT005`).
4. **Publish is a separate explicit action** (`service_listing_publish`) with trade-gate guidance card on `PLT005` (reuse `escrow_write_cta_panel.dart` pattern). `create(p_status)` defaults to `draft`; direct-publish from form calls `create(draft)` then `publish` so errors surface distinctly.
5. **List pagination** follows `list_mine` keyset: `p_limit 20 default (max 100)`, `p_cursor uuid`, `(created_at DESC, id DESC)`; unknown/foreign cursor → empty page (no oracle — surface as end-of-list, not error).
6. **Media ordering** is `sort_order ASC, created_at ASC` (server `service_listing_get` projection); client never re-sorts ranked data (not applicable here) and preserves media order verbatim.
7. **Idempotency/offline:** create/update carry `uuid v4` slug-collision handling (`PLT005 'title already exists'` → inline suggestion); offline queue (`lib/core/sync/action_queue.dart`) is **out of scope** for EP-03-08 (messaging EP-03-13 owns the pattern) — Mutations require connectivity; show `HivorrErrorState` with retry. Document as known limitation for EP-03-18 notification follow-up.
8. **Logging:** `HivorrLogger` + `PiiRedactor` suffix-only IDs (copy `dispute_service.dart`); never log title/description bytes.

---

## 8. Required Systems, Modules, and Components

| # | Component | Location (new unless noted) | Notes |
|---|---|---|---|
| D1 | `ServiceListingRemoteDataSource` (abstract) + `SupabaseServiceListingRemoteDataSource` + `ServiceListingEnvelopeParser` | `lib/data/datasources/remote/service_listing_remote_data_source.dart`, `supabase_service_listing_remote_data_source.dart`, `service_listing_envelope_parser.dart` | 6 RPCs (create/update/publish/unpublish/get/list_mine) + `favorite_toggle` passthrough; `p_*` params exactly as migration signatures |
| D2 | `ListingMediaDto`, `MyListingPageDto`, extended `ServiceListingDto` fields | Extend `lib/data/models/service_listing_dto.dart` (+ new `listing_media_dto.dart`) | `media[]` + `status` + `updated_at`; null-safe parsers reused |
| D3 | Mapper extensions | Extend `lib/data/mappers/service_listing_mapper.dart` | `toOwnerEntity/toMediaEntity`; ranked `toPageEntity` untouched |
| D4 | `ServiceListingRepository` + `ServiceListingRepositoryImpl` | `lib/data/repositories/service_listing_repository.dart`, `service_listing_repository_impl.dart` | Entity-only; `_requireTitle/_requireDescription/_requirePricing/_requireCurrency` → `PLT003`; re-read via `get` after create/update/publish/unpublish |
| D5 | `ServiceListingProvider` | `lib/data/providers/service_listing_provider.dart` | `ServiceListingLoadState idle/loading/loaded/error`; `loadMine({status,refresh})/loadMore()/select()/create/update/publish/unpublish/refresh`; `lastError: ApiException?`; `WidgetsBindingObserver` pause gate (copy `DisputeProvider`) |
| D6 | `ServiceListingService` | `lib/systems/marketplace/services/service_listing_service.dart` | `validateTitle/Description/Pricing/Currency` statics + `createWithMedia/updateWithMedia` orchestration (storage→RPC→cleanup) + `coverUrl via StorageService.getPublicUrl` |
| D7 | Form screen | `lib/systems/marketplace/screens/service_listing_form_screen.dart` | `Form` + `FormValidationMixin` + `HivorrFormField` (title/desc/price) + `DropdownButtonFormField` pricing/currency + `ProfessionRegistryBrowser` step + `HivorrButton(isLoading)`; edit mode pre-fills from `provider.selected` |
| D8 | Media screen | `lib/systems/marketplace/screens/service_listing_media_screen.dart` | Grid of `listing_media_tile` (thumbnail via `getPublicUrl`, `LinearProgressIndicator`, retry), `pickListingMedia` FAB, cover star (sort_order 0), delete confirm via `HivorrDialog` |
| D9 | Owner list screen | `lib/systems/marketplace/screens/my_listings_screen.dart` | `HivorrSectionHeader('My listings' + New action)` + status `HivorrChip` filter + `HivorrCard` rows + `HivorrBadge(status)` + `HivorrEmptyState('No listings yet')` + pagination footer |
| D10 | Widgets | `lib/systems/marketplace/widgets/service_listing_card.dart`, `listing_media_tile.dart`, `pricing_type_selector.dart`, `listing_status_badge.dart` (thin `HivorrBadge` wrapper) | Pure display; tokens only |
| D11 | DI + barrel | Extend `lib/data/data_layer.dart` (`registerServiceListingLayer`); new `lib/systems/marketplace/marketplace.dart`, `marketplace_dependency_injection.dart` | Mirror portfolio/dispute DI |
| D12 | Storage + picker extensions | Extend `storage_config.dart`, `storage_paths.dart`, `platform_file_picker.dart` | Additive only (§6) |
| D13 | Router | Extend `route_paths.dart`, `route_names.dart`, `app_router.dart` | 4 protected routes; `?next=` preserved by existing `RouteGuard` |
| D14 | Test fakes | Extend `test/support/fakes/fake_supabase_storage.dart` (add bucket), new `test/support/fakes/fake_service_listing.dart` | `FakeServiceListingRepository/Remote` with counts + verbatim page |

---

## 9. Data Requirements

- **Entities:** `ServiceListing` (extended with `status: draft|published|paused|archived|reported`, `media: List<ListingMedia>`, `updatedAt`), `ListingMedia {id, storagePath, mimeType, sortOrder, createdAt}`, `MyListingPage {items, hasMore, nextCursor(uuid)}`.
- **DTOs:** owner projection matches `service_listing_get` envelope (`media[]` ordered) and `list_mine` envelope (`items/has_more/next_cursor`); `service_listing_create/update/publish/unpublish` return single-row `data` (no `media` — re-read via `get` for media).
- **Enums/vocabs (client mirrors, server authoritative):** `pricing_type {fixed,hourly,custom,per_milestone}`; `status {draft,published,paused,archived,reported}` (client writes only `draft→published→paused`; `archived/reported` read-only); currencies active subset `{NGN,GHS,USD,GBP}` via `financial_supported_currencies`.
- **Validation matrix (client pre-check → server CHECK/RPC):** title 10–120 → `service_listings_title_length`; desc 50–5000 → `description_length`; pricing/price rules → `pricing_type_allowed/price_*`; currency active → `PLT003`; profession active+bound → `PLT004/PLT005`; publish gate `approved` → `PLT005`; slug collision → `PLT005`; `archived/reported` immutable → `PLT005`; unpublished-unpublish → `PLT005`.
- **Caching:** owner list cached in-memory per `(status, limit)` with explicit `refresh/invalidate`; no Hive persistence in EP-03-08 (ranked browse cache `HiveServiceSearchLocalDataSource` is discovery-only and untouched).

---

## 10. Database Considerations

**No new tables, migrations, RPCs, RLS, indexes, or bucket policies.** EP-03-01 is the complete backend:

- Tables reused: `service_listings` (indexes `entity_idx`, `profession_idx`, `status_published`, `published_at`), `service_listing_media` (owner-prefix CHECK, MIME allowlist, `sort_order ≥0`), `service_favorites`.
- RLS posture reused: listings owner-write-via-RPC + D5 `service_listings_guard_publish_state` trigger (direct patch → `PLT002`); media owner RLS (`insert_own/update_own/delete_own`); storage objects `service-listing-media` owner-prefix policies.
- Client access map: listings — RPC exclusively; media — RLS REST (`insert {listing_id, storage_path, mime_type, sort_order}`, `update(sort_order)`, `delete`); storage — `StorageService` against `service-listing-media/{entityId}/{listingId}/...`.
- Integrity notes: `industry_id` trigger-derived (never client-supplied); `slug` server-derived from title; `search_vector/avg_rating/review_count/view_count` zero client grants (never read/written by EP-03-08); `published_at` semantics (`NOT NULL ⟺ published`) handled server-side.
- Future-proofing: EP-03-06/09 analytics (`view_count` increment) and EP-03-15 portfolio-link RPC attach without schema change.

---

## 11. API Requirements

| RPC | Params | Used by | Client handling |
|---|---|---|---|
| `service_listing_create` | `p_profession_id, p_title, p_description, p_pricing_type, p_price_min?, p_price_max?, p_currency_code='NGN', p_status='draft'ʼ` | Form → Create | Pre-validate → RPC → `get(id)` re-read → provider prepend |
| `service_listing_update` | `p_listing_id + nullable(title, description, profession_id, pricing_type, price_min/max, currency_code)` | Form → Save (draft/paused only; published desc-only per trigger — surface `PLT005` otherwise) | Same re-read |
| `service_listing_publish` | `p_listing_id` | Form CTA / list row action | `PLT005` → trade-gate guidance card (`Complete verification` deep-link to verification flow); success → `HivorrSuccessState` + list refresh |
| `service_listing_unpublish` | `p_listing_id, p_reason? (paused only for client; reported → PLT002)` | List row / detail action with `HivorrDialog` confirm | `paused` clears `published_at` server-side |
| `service_listing_get` | `p_listing_id` | Detail/edit/media screens | `PLT004` identical for unknown vs non-visible (no oracle — show `HivorrEmptyState` not-found) |
| `service_listing_list_mine` | `p_status?, p_limit (1–100, default 20), p_cursor?` | `my_listings` + `loadMore` | Keyset append; `has_more/next_cursor(uuid)` |
| `service_favorite_toggle` | `p_listing_id` | Detail preview heart (optional) | Not a management action; no favorites screen |

Envelope: `{success, code: PLT000, message, data}` unwrapped by new `ServiceListingEnvelopeParser` (copy of `DisputeEnvelopeParser`: `PLT001 auth / 002 forbidden / 003 validation / 004 notFound / 005 conflict` → `ApiExceptionKind`). Transport: `BaseApiService` (`dio` + `supabase` + `exceptionMapper` injected); no direct `SupabaseClient` construction; `Dio` upload path with `onSendProgress` reused from `SupabaseStorageService`.

---

## 12. User Interface Requirements

All screens: `HivorrScreenScaffold` → `HivorrContentPane` (≈720dp max, 16/24dp gutters) → `HivorrResponsiveScaffold` for tablet/desktop; `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme` exclusively (VISUAL-IDENTITY compliance, `AGENT.md:18`).

- **`my_listings_screen.dart`:** `HivorrSectionHeader` + status filter `HivorrChip`s (`All/Draft/Published/Paused`) → `ListView` of `service_listing_card` (`HivorrCard`: title, `listing_status_badge`, price via `HivorrFormatters`/`NumericExtensions`, profession name, cover thumb via `getPublicUrl`) → states: `HivorrLoadingState` / `HivorrErrorState(kind→message + Retry)` / `HivorrEmptyState('No listings yet' + Create action)` / pagination loader. Publish/Unpublish overflow via `HivorrBottomSheet` + `HivorrDialog` confirm for destructive.
- **`service_listing_form_screen.dart`:** 3-step (`Profession → Details → Pricing & Publish`): Step 1 embeds `ProfessionRegistryBrowser`; Step 2 `HivorrFormField` title (counter 10–120) + description (counter 50–5000, `maxLines 6`); Step 3 `pricing_type_selector` chips + price-min/max `HivorrFormField`s (numeric keyboard, currency prefix) + currency dropdown + draft-save vs publish CTA (`HivorrButton primary ≥48dp, isLoading`). `autovalidateMode.onUserInteraction`.
- **`service_listing_media_screen.dart`:** `portfolio_grid`-style grid of `listing_media_tile` (thumb, progress bar, error retry, cover indicator, delete), Add FAB (`pickListingMedia`), Save-order action. Oversize/type errors inline via `StorageException → friendlyError` (copy `identity_document_upload_screen.dart`).
- **Shared:** `HivorrSnackbar.success/error` for `PLT000/PLT00x`; `HivorrSuccessState` on published; `TradeVerifiedBadge`-style `HivorrBadge` for `is_trade_verified_cache` on rows (display only).

---

## 13. User Experience Considerations

- **Progressive disclosure:** profession gating first (fail fast on unbound profession with `Bind profession` CTA rather than a late `PLT005`).
- **Optimistic restraint:** no optimistic publish — publish waits for RPC (trade gate is server-side); drafts save optimistically in-form only.
- **Media honesty:** per-file progress + cancel/retry; upload-then-link means a failed RPC never leaves a phantom listing with broken images (orphan bytes removed).
- **Error translatability:** map `PLT003→field error`, `PLT004→not-found empty state`, `PLT005→guidance card` (unbound profession / unverified / slug collision / immutable status), `PLT001/002→auth/forbidden` (re-login / contact support). Preserve `?next=` on auth redirects.
- **Accessibility/responsive:** 48dp touch targets, semantic labels on media tiles, web path URLs (no hash) via existing `pathUrlStrategy`; mobile-first, sidebar detail on tablet+.
- **Empty→action:** every empty state carries a primary action (`Create listing`, `Add photos`, `Clear filter`).

---

## 14. Security Considerations

- **Zero-trust client (Rule 4):** listings mutate only via `SECURITY INVOKER` RPCs; D5 trigger blocks direct publish-state writes (`PLT002`); client holds no pricing/ranking/escrow math.
- **Trade gate (Rule 2):** `publish` requires `entity_professions.trade_verification_status='approved'` for the bound profession — enforced + re-checked server-side; client pre-check is UX only and must never gate-hide the server error path in tests.
- **RLS scoping:** `list_mine`/`update`/`unpublish` owner-scoped (`auth.uid()`); `get` leaks nothing (`PLT004` identical for foreign/draft vs unknown); media RLS owner-prefix + storage object owner-prefix double-gated; `reported` unreachable from client (`PLT002`).
- **PII/logging:** `PiiRedactor` on all logs; never log title/description; IDs suffix-only (`***last4` pattern from `DisputeProvider`).
- **Upload safety:** `StorageValidators.validateForBucket` before bytes leave device; blocked `html/octet-stream`; `StoragePaths.sanitize` traversal-proof; `Uint8List` carrier (web-safe); signed vs public URL discipline follows bucket visibility (`service-listing-media` public per migration — cover thumbs via `getPublicUrl`, no signed-URL confusion).
- **Audit:** every write RPC server-audit-logs (`platform_audit_log_add`) — client asserts envelope `PLT000` only.

---

## 15. Performance Considerations

- Keyset pagination (`limit 20`, max 100) on `my_listings`; no unbounded fetch; `has_more` gate on `loadMore`; debounced profession search (250ms, reused `TaxonomyProvider`).
- Media: 10MiB/bucket cap enforced pre-pick; Dio `onSendProgress` avoids jank; thumbnails via public URL with `CacheManager` image caching (existing `lib/core/cache/lru_cache.dart`); no N+1 — one `get` (with embedded `media[]`) per detail, one `list_mine` per page.
- Indexes already live (`entity/status`, `profession/status`, partial `published`); client preserves server order (media `sort_order,created_at`; list `(created_at,id)`).
- Target: form interaction <16ms jank-free, `list_mine` p95 <400ms on staging (measured in EP-03-20, not this task).

---

## 16. Testing Strategy

| Layer | New tests (mirror existing patterns) |
|---|---|
| Unit (repository/mapper/service) | `service_listing_mapper_test` (owner fields + media order verbatim); `service_listing_repository_test` (fail-fast `PLT003` matrix: short title/desc, bad pricing, max<min, custom-no-price, bad currency; re-read-after-write verified via fake remote); `service_listing_service_test` (validate* matrix + orchestration: upload-then-RPC, orphan cleanup on RPC fail — copy `professional_profile_service_test` + `onboarding_service_test` harness) |
| Unit (storage/validators) | Extend `storage_validators_test`, `storage_paths_test` with `service-listing-media` cases; extend parity test asserting `StorageBuckets/Limits/MimeTypes` equality with `20260921090001` bucket DDL |
| Widget | Form validation (title/desc/price inline errors, profession-gated Continue, publish CTA loading); `PLT005` trade-gate guidance card; media tile progress/retry/oversize (`trade_proof_upload_screen_test` pattern with mock `SupabaseStorageService`); `my_listings` empty/error/loaded + status-chip filter → `p_status` asserted on fake; theme-token assertion (no `Colors.*`/hex/`fontFamily` — grep + `ColorScheme.primary == #0B6E99` assert) |
| Integration | RPC seam test (seed via `service_listing_create` → `get` → `update` → `publish` (verified fixture) / `PLT005` (unverified fixture) → `unpublish` → `list_mine` pagination no-overlap) against Dev/Staging; uses `FakeServiceListingRepository` + live-RPC switch, never direct table writes |
| Static | `dart analyze`, `flutter test`, `flutter_lints:6.0.0`; forbidden-pattern grep: no `from('service_listings')` writes, no `Colors.`/hex in new widgets, no client-side ranking sort |

No pgTAP work in EP-03-08 (server already covered by `024_service_marketplace_rpc_enforcement.sql`).

---

## 17. Recommended Implementation Sequence

1. **Storage + picker extensions** (`storage_config`, `storage_paths`, `platform_file_picker`) + parity/validator/path tests — unblocks media.
2. **DTO/mapper extensions** (`ListingMediaDto`, owner fields, page DTO) + mapper tests.
3. **Remote + envelope parser + repository + provider + service** (D1–D6) + unit tests with new fakes.
4. **`registerServiceListingLayer` + `marketplace_dependency_injection.dart` + barrel** — wire into bootstrap `MultiProvider` (no `main.dart` restructure).
5. **Router paths/names/routes** (protected) + redirect test.
6. **Screens + widgets** (form → media → my_listings) + widget tests + golden (mobile + web) + token assertions.
7. **Integration pass** (live RPC matrix on Dev) + `dart analyze` + full `flutter test` + static-grep gates.
8. Handoff to EP-03-09 (discovery), EP-03-10 (contracts), EP-03-15 (portfolio link), EP-03-19 (SEO) — all consume this slice's `get/list_mine`.

---

## 18. Expected Outcome

A verified professional can: select a bound profession → create a draft with validated pricing → attach ordered media with progress → publish (or receive actionable trade-gate guidance) → manage (filter/paginate/edit/unpublish) listings — all through server-authoritative RPCs, token-compliant UI, and fully tested seams that EP-03-09/10/15/19 build on without rework.

---

## 19. Definition of Done

- [ ] `registerServiceListingLayer` + 3 screens + provider/service/repo/remote/parser + storage extensions landed under `ARCHITECTURE.md lib/` schema (no top-level dirs, no `lib/ai/*`, no hardcoded logic in UI).
- [ ] All writes via RPCs; no `service_listings` direct writes in client (grep-clean); media via RLS + `StorageService` only.
- [ ] Trade-gate `PLT005` path tested (unverified publish shows guidance; verified publishes).
- [ ] Validation mirror matrix green (unit); form/media/list widget tests green; integration RPC matrix green on Dev.
- [ ] `Hivorr*` primitives + `AppTheme` tokens exclusively (static scan clean; `VISUAL-IDENTITY` assert passes).
- [ ] `dart analyze` + `flutter test` clean; `flutter_lints` clean.
- [ ] Docs: plan handoff note only (no final feature docs — forbidden in plan mode).
- [ ] EP-03-09/10/15/19 can consume `get/list_mine` without modification (interface review sign-off).

---

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: High**
- **Reasoning Level Justification:** Matches the approved Phase Plan matrix (`EP-03-08: Planning High / Coding High`, §12–13). Rationale: technically a bounded client CRUD over a proven server contract (no new financial math, ranking, or crypto — unlike `Extremely High` items EP-03-01/02/03/06/11), but carries **high business impact** (first supply-side revenue primitive), **medium-high integration complexity** (6 RPCs + RLS media + storage + taxonomy + router + DI across 14 components), and **moderate security sensitivity** (trade-gate UX must never mask server enforcement; RLS owner-prefix discipline). `High` provides rigorous multi-file consistency and edge-case coverage without the exhaustive formal-verification overhead reserved for escrow/ranking/double-blind invariants. `Very High`/`Extremely High` would be disproportionate; `Medium`/`Low` would underweight the cross-layer wiring and marketplace trust surface.

---

**Awaiting your approval to proceed to implementation on exit from plan mode.**
