# Task Implementation Plan — EP-03-09: Service Discovery & Search Experience (Client)

## 1. Task Objective

Build the client-facing discovery surface for the professional services marketplace:

- `marketplace_discovery_screen.dart` — industry → profession browse with ranked defaults.
- `marketplace_search_screen.dart` — query + filter chips (`profession`, `industry`, `price_range`, `currency`, `rating_min`, `verified_only`, `availability_date`) over ranked search.
- `service_detail_screen.dart` — public listing detail (header, pricing, verification badges, media carousel, portfolio proof placeholder, `Book / Request Proposal` CTA).
- Result list, filter bottom-sheet, discovery card, favorites toggle UI, and ranking-explainability tooltip.

Strict consumer of the landed server contract (`service_ranking_search` from `20260927090001_platform_config_and_ranking.sql` via EP-03-06/07). **No client re-sort, no new ranking logic, no new tables/RPCs.**

## 2. Business Problem Being Solved

Supply exists (EP-03-08 owner CRUD) and ranking/search infrastructure exists (EP-03-06/07), but clients have no way to browse, search, filter, or evaluate services. Without this task:

- Verified professionals are undiscoverable — no frequency driver (`Business-Roadmap:219-226`).
- Deterministic ranking is unproven in UI — trust/fairness claim unvalidated.
- No path from discovery → contract (EP-03-10) → escrow (EP-03-11).

This task proves `AGENT.md:7` Deterministic Core Supremacy in a consumer product: results render in RPC order verbatim.

## 3. Scope

**In scope:**

1. Discovery browse: industry → profession hierarchy, default ranked feed (empty query = recently-published ranked defaults).
2. Search: debounced query (250ms), `ServiceSearchFilters` → `p_filters` composition, keyset pagination (`Load more` / infinite scroll), pull-to-refresh.
3. Filters UI: profession/industry picker, price min/max + currency (`NGN/GHS/USD/GBP`), rating_min slider/chips, verified-only toggle, availability date (conditional).
4. Discovery result card (public variant) + detail screen with media carousel, `TradeVerifiedBadge`, rating aggregate, portfolio-proof slot (read-only hook for EP-03-15), favorite toggle (existing `service_favorite_toggle` RPC), self-hire guard (viewer == professional → CTA disabled).
5. Cache/offline: `ServiceSearchIndex.warmBrowse/hydrateOffline` pre-warm on `initState`, `Hive` + `CacheManager` 5-min TTL, `weights_version` invalidation.
6. Router: public browse/search/detail routes + guard treatment (drafts → 404/`HivorrEmptyState`), deep-linkable URLs (pattern after `/p/:slug/:id`; canonical `/s/...` deferred to EP-03-19 but route names/paths added here without breaking SEO).
7. Visual identity compliance, loading/empty/error states, responsive layouts, logging with PII redaction.

## 4. Out of Scope

- No new Supabase migrations, tables, `search_vector`/GIN DDL, or RPCs. `service_ranking_search` is sole ordering authority.
- No ranking formula changes, weight edits (`platform_config` service_role only), or `RankingFormula` ordering use (display/explain only).
- No contract offer/accept, escrow, review submit, messaging, scheduling, dispute, earnings, notifications (EP-03-10–18).
- No owner CRUD changes (EP-03-08 screens untouched).
- No portfolio linking write path or SEO meta builder (EP-03-15 / EP-03-19 own those; this task only reserves carousel slot + route shape).
- No AI re-ranking or "Featured" override of RPC order (`AGENT.md:7` ban).
- No persistent taxonomy Hive box (transient `CacheManager` suffices unless restart-persistence proven needed — see §6).

## 5. Existing Asset and Dependency Analysis

Inspected via codebase search + EP-03-06/07/08 plan docs:

| Category | Existing asset (reused verbatim) | Relevance to EP-03-09 |
|---|---|---|
| **Server contract** | `supabase/migrations/20260921090001_service_marketplace_schema.sql` (`service_listings`, `search_vector` trigger, `published`-only read); `20260927090001_platform_config_and_ranking.sql` (`service_ranking_search(p_profession_id, p_query, p_filters, p_cursor, p_limit)`, keyset `(score,id)`, `weights_version`) | Ordering, filtering, pagination, security invariants — zero new backend |
| **Data seam** | `lib/data/datasources/remote/service_search_remote_data_source.dart` + `service_search_envelope_parser.dart` (single RPC, envelope `{success PLT000/003/004/005, data:{items, has_more, next_cursor, weights_version}}`) | Only network entry point; forbids `from('service_listings').select()` |
| **Repository** | `lib/data/repositories/service_search_repository.dart` + `service_search_repository_impl.dart` (browse cache-first / FTS network-first, sha256 key 16-char, verbatim order) | Business-rule holder; screens never call datasource directly |
| **Provider** | `lib/data/providers/marketplace_search_provider.dart` (`idle/loading/loaded/error`, debounced `setQuery` 250ms, `search/loadMore/refresh/invalidate`, `hasActiveFilters/isEmpty`) | Screen state; already wired in `registerMarketplaceSearchLayer` + `app_bootstrap.dart` |
| **Offline engine** | `lib/engine/search_engine/service_search_index.dart` (`warmBrowse/hydrateOffline/invalidateOnWeightsBump`); `lib/data/datasources/local/hive_service_search_local_data_source.dart` + `service_search_local_data_source.dart` (prefix `service_search:`, 5m TTL); `lib/core/cache/lru_cache.dart`/`cache_manager.dart`; `lib/core/database/*` (`AppBoxes.cache`, `LocalStore`) | Offline browse + cold-start; no new box |
| **Ranking explain** | `lib/engine/recommendation_engine/ranking_weights.dart` + `ranking_formula.dart` (`compute/explain`, 1e-9 SQL parity) | Tooltip copy only (`Verification 0.28×…`), never ordering |
| **Taxonomy** | `lib/workspace/profession_registry/taxonomy_engine.dart`, `taxonomy_provider.dart`, `taxonomy_repository*.dart`, `supabase_taxonomy_remote_data_source.dart`, `taxonomy_local_data_source.dart`; widgets `taxonomy_search_field.dart` (debounced canonical search input), `industry_picker.dart`, `profession_picker.dart`, `profession_registry_browser.dart` | Browse hierarchy + filter pickers; no new taxonomy UI |
| **Entities/DTOs** | `lib/data/entities/service_listing.dart` (`ServiceListing`, `ServiceSearchFilters→p_filters`, `ServiceSearchPage`, `ServiceListingCursor`); `listing_media.dart`; `lib/data/models/service_listing_dto.dart`; `lib/data/mappers/service_listing_mapper.dart` (`toPageEntity` verbatim) | Type-safe filter composition + order preservation |
| **Owner supply** | `lib/systems/marketplace/services/service_listing_service.dart` (vocab/validators/price formatting), `screens/my_listings_screen.dart` (chip filter + `Load more` + empty/loading/error scaffold), `widgets/service_listing_card.dart`, `listing_status_badge.dart`, `listing_media_tile.dart`, `pricing_type_selector.dart` | Patterns to adapt; supply guarantee (`published` only searchable) |
| **Detail precedent** | `lib/systems/portfolio/screens/professional_profile_screen.dart` (public `/p/:slug/:id` loading/PLT004-404/retry), `widgets/portfolio_grid.dart` (1/2/3-col `LayoutBuilder`), `portfolio_item_card.dart`, `profile_header_card.dart`, `services/professional_profile_service.dart` | Detail state machine + responsive grid + header pattern |
| **Shared UI** | `HivorrCard`, `HivorrChip`, `HivorrButton` (48dp), `HivorrBadge`, `HivorrAvatar`, `HivorrTintBadge`, `HivorrTextField`, `HivorrSnackbar`, `HivorrSectionHeader`, `HivorrBottomSheet`, `HivorrEmptyState/LoadingState(HivorrLoader)/ErrorState/SuccessState`; `TradeVerifiedBadge` (`lib/systems/verification/widgets/`) | Mandated primitives per `VISUAL-IDENTITY.md` + `AGENT.md:18` |
| **Layouts/theme** | `hivorr_screen_scaffold.dart`, `hivorr_responsive_scaffold.dart`, `breakpoints.dart` (mobile<600/tablet/desktop≥1024), `mobile_compact.dart`; `lib/app/theme/*` (`AppThemeExtension`, `RoleThemeExtension`, `ColorScheme`, `TextTheme`); `hivorr_spacing.dart`, `hivorr_formatters.dart` | Responsive discovery grid (1120dp list cap per `MyListings` precedent — **not** 720dp `HivorrContentPane` which is for forms) |
| **Router/guard** | `lib/app/router/app_router.dart`, `route_paths.dart`, `route_names.dart`, `route_guard.dart` + `auth_guard.dart` (`_isPublicContentView` for `/p/*`, `/store/*`); `lib/systems/portfolio/seo/portfolio_seo_meta.dart`; `public_page_scaffold.dart` | Public-route pattern to extend |
| **Filter-sheet precedent** | `lib/systems/dashboard/screens/opportunities_screen.dart` (`_FindWorkSearchField` + filter button + `_FwFilterSheet` bottom-sheet + `Wrap(HivorrChip)` + `RefreshIndicator`); `hires_screen.dart`, `finance_hubs_screen.dart`, `manage_user_screen.dart` | Filter bottom-sheet + search-header structure to copy |
| **Infra** | `dio:5.11.0`, `go_router:17.5.0`, `provider:6.1.5`, `hive:2.2.3`, `supabase_flutter:2.17.2`; `lib/core/api/*` (`BaseApiService`, interceptors); `lib/core/logging/pii_redactor.dart` | Transport, routing, state, redacted logging |

**Dependencies (per Phase Plan §7):** EP-03-07 (search seam — must be landed), EP-03-08 (supply — searchable `published` data), EP-03-15 (portfolio read hook — consume read-only, no write), EP-01-16 (design system), EP-02-07 (taxonomy engine).

## 6. Reuse / Extension / Refactoring Assessment

| Proposed need | Decision | Justification |
|---|---|---|
| Ranked fetch, cache, pagination, debounced query | **Reuse** `ServiceSearchRepository`, `MarketplaceSearchProvider`, `ServiceSearchIndex`, Hive+CacheManager locals | EP-03-07 built explicitly for this consumer; rebuilding duplicates ordering/caching invariants and risks re-sort violation |
| Taxonomy browse/filter pickers, debounced search field | **Reuse** `TaxonomyEngine/Provider`, `IndustryPicker`, `ProfessionPicker`, `ProfessionRegistryBrowser`, `TaxonomySearchField` | No new taxonomy UI; change only `hint`/filter wiring |
| Detail media grid, header, verification row | **Extend/adapt** `PortfolioGrid`, `ListingMediaTile`, `ProfileHeaderCard` pattern, `ProfessionalProfileScreen` state machine | Owner `ServiceListingCard` is action-oriented (Edit/Publish); public card needs cover+price+rating+trade badge — new variant widget, not a fork of business logic |
| Filter bottom-sheet, search header, `RefreshIndicator`+`Wrap(HivorrChip)`+`Load more` | **Reuse pattern** from `opportunities_screen` / `my_listings_screen` + `HivorrBottomSheet` | UI pattern copy; no new infra |
| Discovery routes + public guard | **Extend** `route_paths.dart`, `route_names.dart`, `app_router.dart`, `_isPublicContentView` | No discovery routes exist (`/services`, `/services/search`, `/services/:id`, `/s/:slug/:id` all missing) — genuine gap; follow `/p/:slug/:id` precedent so EP-03-19 SEO can build on it |
| Favorite toggle UI | **Reuse RPC, new tiny widget** — `service_favorite_toggle` exists, zero widgets consume it | Genuinely new presentation-only asset |
| Ranking explainability tooltip | **New tiny widget over reused logic** — `RankingFormula.explain` exists, no UI | Genuinely new; display-only |
| Discovery browse card, discovery/search/detail screens, filter-sheet widget, detail carousel | **New presentation assets** — zero `*discovery*\|*search*\|*browse*\|*detail*` under `lib/systems/marketplace/screens/` today | Genuine gap; must be thin presentation over reused provider/repo (per `AGENT.md:5,6`) |
| Persistent taxonomy Hive datasource | **Do NOT create** unless restart-persistence proven needed | `taxonomy_local*` is transient-only today; search Hive already covers offline browse. Only add `hive_taxonomy_*` if acceptance shows taxonomy cold-start regression — needs evidence, not speculation |
| Any new table, RPC, GIN index, weight store | **Refused** | Backend complete; new backend would create parallel ordering source and violate Deterministic Core Supremacy |

New assets will live under existing platform paths (`lib/systems/marketplace/screens/`, `widgets/`, `services/` thin facade if needed) and be reusable: discovery card/grid and filter-sheet become the canonical browse pattern for future EP-04 commerce discovery.

## 7. Recommended Technical Approach

Thin-presentation over landed seams; verbatim-order discipline throughout:

1. **State flows one way:** Screens `Consumer<MarketplaceSearchProvider + TaxonomyProvider>` → `provider.search/loadMore/refresh` → `ServiceSearchRepository` → `SupabaseServiceSearchRemoteDataSource.rankingSearch` → `service_ranking_search`. Items assigned verbatim (`items = page.items`), `loadMore` appends, `ValueKey(id)` rows, no `.sort()` anywhere (CI-greppable).
2. **Browse vs search:** empty query + optional profession/industry = browse (cache-first via `ServiceSearchIndex.warmBrowse` on `initState`); non-empty query or active filters = FTS (network-first). `p_filters` built from `ServiceSearchFilters` value object (profession_id, industry_id, price_min/max ≥0 with max≥min, currency active `NGN/GHS/USD/GBP`, rating_min 0–5, `is_trade_verified_only` (+ alias), `availability_date` ISO8601 conditional on availability approval else deferred per EP-03-07).
3. **Detail:** `service_listing_get` re-read for single row (never for ordering); media in `sort_order ASC, created_at ASC` verbatim; portfolio slot reads via existing `PortfolioProvider/Service` read path only.
4. **Guards:** viewer==owner professional or `tradeVerificationStatus != APPROVED` → CTA disabled with guidance (client affordance only; enforcement stays server-side per `AGENT.md:13`, `Rule 2`).
5. **All UI from tokens:** `Theme.of(context).colorScheme` / `AppThemeExtension` / `TextTheme`, `Hivorr*` primitives, 1120dp list cap, `Breakpoints` 1/2/3-col grid.

## 8. Required Systems, Modules, and Components

**New (presentation only, under existing `lib/systems/marketplace/`):**

- `screens/marketplace_discovery_screen.dart` — industry→profession browser + ranked default feed.
- `screens/marketplace_search_screen.dart` — query + chips + ranked results + pagination.
- `screens/service_detail_screen.dart` — header/pricing/badges/carousel/portfolio-slot/CTA.
- `widgets/discovery_service_card.dart` — public card (cover, title, price line, rating, `TradeVerifiedBadge`, score-hidden).
- `widgets/discovery_filter_sheet.dart` — `HivorrBottomSheet` wrapping profession/price/currency/rating/verified/availability controls.
- `widgets/service_media_carousel.dart` — adapts `ListingMediaTile`/`PortfolioGrid` pattern (cover = `sort_order 0`).
- `widgets/ranking_explainer_chip.dart` — tooltip over `RankingFormula.explain` ("Ranked by verification, rating, completion").
- `widgets/favorite_toggle_button.dart` — thin wrapper over `service_favorite_toggle`.
- Router additions: `RoutePaths` builders + `RouteNames` + `AppRouter GoRoute`s + `_isPublicContentView` extension.

**Reused/extended (no logic forks):** `MarketplaceSearchProvider`, `TaxonomyProvider`, `ServiceSearchRepository`, `ServiceSearchIndex`, `RankingWeights/Formula`, `TaxonomyEngine`, `TaxonomySearchField/IndustryPicker/ProfessionPicker`, `PortfolioGrid/ItemCard/Header` patterns, all `Hivorr*` primitives, `CacheManager/LocalStore(AppBoxes.cache)`.

## 9. Data Requirements

- Read `ServiceListing` ranked projection (`id, entity_id, profession_id, industry_id, slug, title, description, pricing_type, price_min/max, currency_code, avg_rating, review_count, is_trade_verified_cache, published_at, profession/industry slug+name, score numeric(10,6)`). Never `search_vector`.
- `ServiceSearchFilters` → `p_filters` JSONB (shape per §7); `ServiceListingCursor{score,id}` → `p_cursor`; `p_limit` 1–50 default 20; `p_query` trimmed ≤100 chars.
- Cache key `sha256(prof|q|f|c|l)` 16-char, TTL 5m, `weights_version` coherence check → `invalidatePrefix(service_search:)`.
- Detail re-read via `service_listing_get` projection (media `sort_order` order preserved).
- No client-computed aggregates, averages, or scores for ordering.

## 10. Database Considerations

None — **no migrations**. Rely on EP-03-01 (`service_listings` + `search_vector` trigger + GIN + `published`-only RLS) and EP-03-06 (`platform_config` weights + `service_ranking_search STABLE`, granted to `anon/authenticated/service_role`). Plan must assert `EXPLAIN` shows GIN `Bitmap Scan` on query / `service_listings_published_ranking_idx` otherwise (already proven in EP-03-07; re-verify in validation, not rebuilt).

## 11. API Requirements

Single RPC, existing seam only:

- `POST /rest/v1/rpc/service_ranking_search` via `SupabaseServiceSearchRemoteDataSource.rankingSearch` + envelope parser (`PLT000` success; `PLT003` field error; `PLT004` not-found/empty uniform with empty; `PLT005` guard; `PLT999`/42501/P0001 mapped).
- Keyset pagination: `WHERE (score,id) < cursor ORDER BY score DESC, id DESC LIMIT p_limit+1 → has_more + next_cursor`. No `OFFSET`.
- Owner `service_listing_get` for detail re-read; `service_favorite_toggle` for heart UI. No direct `from('service_listings')` reads/writes for discovery.

## 12. User Interface Requirements

- Discovery: `HivorrScreenScaffold` + `HivorrResponsiveScaffold`, search header (`TaxonomySearchField` + filter button), `Wrap(HivorrChip)` profession/quick filters, count line, responsive 1/2/3-col card grid, `HivorrLoadingState(HivorrLoader)` initial, `HivorrEmptyState` (no results / no listings), `HivorrErrorState` + Retry, `RefreshIndicator`, `Load more` footer (keyset).
- Search: same + `discovery_filter_sheet` (`HivorrBottomSheet` with price fields, currency chips, rating selector, verified toggle, availability date picker), active-filter indicator + clear-all.
- Detail: header card (avatar/title/profession chips/`TradeVerifiedBadge`), pricing line, media carousel, description, rating aggregate (post-reveal data only — no blind leakage), portfolio-proof slot (`HivorrEmptyState` + owner-only `Add portfolio` CTA when unlinked), sticky `Book / Request Proposal` CTA with self-hire/verification disabled state.
- All text via `TextTheme`, colors via `ColorScheme`/`AppThemeExtension`, spacing via `hivorr_spacing`, time via `hivorr_formatters`. Zero `Colors.*`/hex/`fontFamily`.

## 13. User Experience Considerations

- Empty query shows useful ranked defaults (not blank); debounced typing (250ms) with no scroll jump or reorder flicker.
- Filter state reflected 1:1 in `p_filters`; clearing filters returns to browse cache instantly.
- Offline: `hydrateOffline` serves last browse; banner/empty copy explains staleness; mutations (favorite) require connectivity with snackbar guidance.
- Self-hire prevented with explanatory copy, not silent disable.
- `PLT004`/empty indistinguishable (no oracle); `PLT005` shows guidance card; auth errors route to login.
- Accessibility: 48dp chip/button targets, semantic labels, keyboard/direction-safe scroll.

## 14. Security Considerations

- Zero-trust client: no pricing/ranking/gate logic in Dart; `anon` sees `published` only (RLS); drafts/paused/archived/reported invisible + direct-URL 404.
- No `search_vector`, `legal_name`, unrevealed review bodies, or non-participant data rendered; PII redaction in logs (`PiiRedactor`, suffix-only IDs).
- `plainto_tsquery` sanitization server-side; injection probe must `lives_ok` (inherited, re-asserted).
- No new storage buckets; media via `getPublicUrl` for `published` only.
- `ENV-001–010` respected: dev→staging→prod, isolated DBs, no prod experimentation.

## 15. Performance Considerations

- Keyset pagination only (limit 20 default, ≤50); no unbounded fetches; `ListView` keyed rows; image thumbnails with placeholders.
- Pre-warm Top-20×professions via `ServiceSearchIndex.warmBrowse`; 5-min TTL + `weights_version` invalidation balances freshness/cost.
- Target p95 filtered search <400ms on staging (EP-03-20 gate); `EXPLAIN` index usage re-verified.
- No N+1: page fetch is single RPC; detail carousel/portfolio reads batched via existing providers.

## 16. Testing Strategy

- **Widget:** ranked order matches RPC payload verbatim (no resort); filter-chip state → correct `p_filters`; empty query → ranked defaults; detail CTA disabled for self/unverified; media order preserved; theme-token assertion (no hardcoded colors — fails DoD per `AGENT.md:18`).
- **Unit:** `ServiceSearchFilters→p_filters` mapping (price/rating/currency/alias `is_verified_only`); cursor serialization; `RankingFormula.explain` display-only (never asserts order).
- **Integration:** seed listings → query `legal drafting` returns ranked hits; `rating_min=4.5` excludes `<4.5`; sequential pages zero ID overlap; offline `hydrateOffline` serves cache; favorite toggle round-trips; `draft` URL unauth → 404 empty state.
- **Static gates:** `dart analyze`, `flutter test`, `grep -r "sort.*score" lib/systems/marketplace/screens` == 0; `grep -r "Colors\.\|fontFamily\|0xFF" new screens` == 0.
- **Golden:** mobile + web responsive snapshots for discovery/search/detail.

## 17. Recommended Implementation Sequence

1. Router + guard skeleton (paths/names/`GoRoute`s, `_isPublicContentView`) behind existing providers — enables deep-link testing early.
2. `discovery_service_card` + discovery grid + browse screen over `MarketplaceSearchProvider` + `warmBrowse` (cache-first path).
3. Search screen + `discovery_filter_sheet` + `p_filters` wiring (network-first path) + `Load more`/refresh.
4. Detail screen + `service_media_carousel` + badges + favorite toggle + self-hire guard + portfolio slot.
5. `ranking_explainer_chip`, empty/error/loading polish, logging + PII redaction, visual-identity audit.
6. Widget/integration/static-gate suite + staging p95 check → handoff to EP-03-10 (contract CTA) and EP-03-15/19 (portfolio/SEO build on these routes).

## 18. Expected Outcome

Frictionless, auditable discovery: clients browse by industry→profession, search with filters, page through deterministically ranked `published` results in RPC order, open a trustworthy detail (pricing, trade badge, proof slot), and proceed to `Book / Request Proposal` — with offline resilience and full theme compliance. Unblocks EP-03-10 without exposing ranking, financial, or gate logic to the client.

## 19. Definition of Done (DoD)

- [ ] Three screens + four widgets + router entries exist under existing `lib/systems/marketplace/` + `lib/app/router/` paths; no new top-level `lib/` dirs, no new tables/RPCs/buckets.
- [ ] All discovery ordering from `service_ranking_search` verbatim; `grep sort.*score` on new screens == 0; `RankingFormula` used for tooltip only.
- [ ] `p_filters`/cursor/limit contract respected; pagination zero-overlap proven by test.
- [ ] Empty query → ranked defaults; `PLT004` == empty; `PLT005`/auth handled with guidance/login.
- [ ] Self-hire CTA disabled with copy; `draft` unauth → 404/`HivorrEmptyState`.
- [ ] Offline browse serves Hive/CacheManager cache; `weights_version` bump invalidates.
- [ ] `dart analyze` + `flutter test` + golden (mobile+web) green; p95 search <400ms evidence (or delegated to EP-03-20 with staging numbers).
- [ ] Zero `Colors.*`/hex/`fontFamily` in new widgets; `ColorScheme.primary == #0B6E99`-family token assertion passes; 48dp targets verified.
- [ ] Logging redacted; no `search_vector`/`legal_name`/blind-review leakage.

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: High**
- **Justification:** Client-only thin presentation over landed RPC/repo/provider seams — no financial math, no new RLS/RPC, low security risk. Complexity is integration-heavy (dual providers, two-tier cache, keyset pagination, taxonomy filters, responsive + router + offline states) with high business impact (first revenue-surface frequency driver), requiring careful verbatim-order discipline and visual-identity compliance, but not the irreversible fund/trust-invariant design that warrants Very/Extremely High.

---

*Planning artifact only. No production code written. Awaiting approval before implementation.*
