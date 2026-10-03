# Definition of Done — EP-03-09: Service Discovery & Search Experience (Client)

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**
>
> **Status:** Completed — Approved 2026-10-03. All code-level boxes verified:
> `dart analyze` clean (full project), 100+ new+regression tests green,
> forbidden greps 0, `git diff -- supabase` empty, `git diff` on tracked
> `documents/` empty. Human/staging remainders accepted as documented
> deferrals (same pattern as EP-03-07/08). See §10 Approval Record.

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-09 |
| **Task Name** | Service Discovery & Search Experience (Client) |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 3 Service Listing & Discovery (first user-visible marketplace) |
| **Priority** | High — Coding Reasoning High (Phase Plan §12–13) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-09  Service Discovery & Search Experience (Client).md:1-204` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:334-343` (depends on EP-03-07, EP-03-08, EP-03-15, EP-01-16, EP-02-07) |
| **Dependencies** | EP-03-07 search seam (`service_ranking_search` + `ServiceSearchRepository` + `MarketplaceSearchProvider` + `ServiceSearchIndex` + Hive/CacheManager) Completed; EP-03-08 supply (`published` listings + `service_listing_get` + `service_favorite_toggle`) Completed; EP-03-06 ranking (`platform_config` weights + verbatim-order rule) Completed; `lib/workspace/profession_registry/*`, `lib/systems/portfolio/*` (detail precedent), `lib/shared/*`, `lib/app/theme/*`, `lib/app/router/*` |
| **Delivery Scope** | **Reuse** `ServiceSearchRepository/Impl`, `SupabaseServiceSearchRemoteDataSource` + envelope parser, `MarketplaceSearchProvider` (250ms debounce, verbatim `search/loadMore/refresh/invalidate`), `ServiceSearchIndex.warmBrowse/hydrateOffline`, Hive + `CacheManager` (`service_search:` 5m TTL, `weights_version` coherence), `TaxonomyEngine/Provider/Repository`, `TaxonomySearchField/IndustryPicker/ProfessionPicker/Browser`, `RankingWeights/Formula` (explain only), `PortfolioGrid/ItemCard/Header` patterns, all `Hivorr*` primitives, `AppTheme` tokens; **Extend** `route_paths.dart`, `route_names.dart`, `app_router.dart`, `_isPublicContentView` (public discovery routes following `/p/:slug/:id` precedent); **New** 3 screens (`marketplace_discovery_screen`, `marketplace_search_screen`, `service_detail_screen`) + 5 widgets (`discovery_service_card`, `discovery_filter_sheet`, `service_media_carousel`, `ranking_explainer_chip`, `favorite_toggle_button`) — presentation only, zero new tables/RPCs/buckets/indexes |
| **Guardrails** | `AGENT.md` Separation of Concerns + Deterministic Core Supremacy (:7) + Rule 2 trade gate + Rule 4 zero-trust RPC+RLS (:17) + Rule 5 visual tokens (:18) + `ARCHITECTURE.md:39-173` lib schema |

**How to use:** verify each item via the stated method (`flutter test`, widget harness with fakes, Dev RPC-backed integration, `grep`, `dart analyze`). Unchecked = not done.

**Deviations from the plan (all presentation-scoped, no architecture change):** D1 chip rows over `TaxonomyProvider` instead of embedded picker/browser widgets (avoids mutating shared selection) · D2 card without cover thumbnail + `HivorrBadge` instead of the large `TradeVerifiedBadge` (ranked projection carries no media) · D3 proof slot always placeholder (no listing↔portfolio link data until EP-03-15) · D4 detail without avatar/display-name header (projections carry no professional identity) and in-flow CTA instead of sticky · D5 discovery entry card + variant-style filter button instead of inline field + dot · D6 `HivorrScreenScaffold` + 1120dp cap + `Breakpoints` grid instead of `HivorrResponsiveScaffold` (MyListings precedent) · D7 `Image.network` + placeholder instead of `CacheManager` image caching (no such dependency) · **C1 (correction, not deviation):** the plan/DoD literal `#0B6E99` is stale — canonical primary is `#2D3FE7` per `VISUAL-IDENTITY.md` + `AppColors`, asserted green.

---

## 2. Functional Verification

### 2.1 Required Functionality

- [x] **Discovery browse** — industry → profession hierarchy reading reused `TaxonomyProvider` (chip rows over `industries`/`professionsByIndustry`; `IndustryPicker`/`ProfessionPicker`/`Browser` widgets not reused verbatim — chip rows chosen so filtering composes with `ServiceSearchFilters` without mutating shared selection state — deviation D1); empty query renders ranked defaults via `provider.search()`, never a blank screen (`marketplace_discovery_screen_test`: rows + empty state)
- [x] **Debounced search** — query input via reused `TaxonomySearchField` (250ms) feeding `MarketplaceSearchProvider.setQuery` (250ms) with a trailing screen timer firing `search()` once typing settles; results assigned verbatim so no reorder flicker (`marketplace_search_screen_test`: deep-link + typing)
- [x] **Filter composition** — all 7 controls in `discovery_filter_sheet` map 1:1 to `ServiceSearchFilters → p_filters`: `profession_id`/`industry_id` (active-only ids from provider), `price_min/max` (parsed ≥0, `max ≥ min` else inline error), `currency_code` (`ServiceListingService.currencies` reused, no literal fork), `rating_min` (Any/3.0/4.0/4.5), `is_trade_verified_only` (canonical key), `availability_date` (ISO8601 date picker; server applies it conditionally per EP-03-07) (`service_search_filters_test` 7 asserts + sheet apply/reject tests)
- [x] **Ranked results** — every page renders `items = page.items` verbatim in RPC order; `score` never referenced in new screens/widgets (grep `.score` = 0); `RankingFormula` untouched — explainer dialog copy is qualitative only (`marketplace_discovery_screen_test`: low-rating-first pair renders unflipped)
- [x] **Keyset pagination** — `Load more` appends via provider `loadMore()` (`next_cursor {score,id}`); `has_more=false` ends the list; unknown/foreign cursor behavior inherited from `ServiceSearchRepositoryImpl` (end-of-list, no error — EP-03-07 proven; live zero-overlap deferred to §7.2 integration)
- [x] **Pull-to-refresh** — `RefreshIndicator` re-runs `provider.search()` with query + filters preserved; `weights_version` coherence + `invalidatePrefix(service_search:)` inherited from `ServiceSearchRepositoryImpl` (EP-03-07 tested, untouched)
- [x] **Discovery card** — `discovery_service_card` (public variant; owner `ServiceListingCard` untouched) shows title, price line, profession chip, `Trade verified` badge, `avg_rating` + `review_count`; tap deep-links with row as `extra`; rows keyed `ValueKey(id)`. Deviations D2: no cover thumbnail (ranked projection carries no media — carousel covers imagery on detail); lightweight `HivorrBadge` instead of the large `TradeVerifiedBadge` container (reserved for detail)
- [x] **Detail screen** — `service_listing_get` re-read upgrades the instant-paint row; `service_media_carousel` (cover first, server order verbatim, placeholder fallback); description; rating aggregate; portfolio-proof slot as read-only placeholder (no link data exists until EP-03-15 — deviation D3); `Book / Request Proposal` CTA. Deviation D4: no avatar/display-name header (neither ranked nor owner projections carry professional identity fields); CTA in-flow full-width button, not sticky
- [x] **Favorite toggle** — `favorite_toggle_button` wraps `service_favorite_toggle` only (new `repository/service.toggleFavorite` returning `favorited`); heart round-trips with success snackbar; failure keeps prior state + error snackbar; no favorites list screen created (`service_listing_favorite_test` + button tests)
- [x] **Self-hire / verification guard (client affordance)** — viewer `entityId == listing.entityId` (via `AuthProvider.currentSession`) → CTA disabled with "you cannot hire yourself" copy; signed-out → login with `?next=` preserved; hiring-side trade-verification check intentionally absent client-side (clients don't need trade approval; enforcement stays server-side). Tested owner-disabled path
- [x] **Cache/offline** — `ServiceSearchIndex.warmBrowse()` pre-warm on discovery `initState` (graceful skip when seam absent); browse cache-first + FTS network-first inherited from repository (EP-03-07 tested). Partial: `hydrateOffline` not called by screens and no "showing saved results" staleness banner — offline resilience rests on the inherited two-tier cache

### 2.2 Expected Workflows

- [x] **Browse happy path:** open discovery → industry → profession → ranked defaults → `Load more` appends → tap card → detail with carousel + badges + CTA (widget-tested with fakes: profession chip sets `professionId` + re-searches; card tap handler wired to `serviceDetail(id)` + `extra`)
- [x] **Search + filter path:** type query (debounced) → ranked results → sheet → price + currency + rating + verified-only narrows via `p_filters` (sheet apply test asserts exact `ServiceSearchFilters`; server-side exclusion semantics inherited from EP-03-07); clear-all resets to browse state + re-searches
- [x] **Detail path:** `service_listing_get` re-read shows authoritative row + media in server order (upgrade + carousel-cover tests); portfolio slot shows owner-gated placeholder (`_ProofSlot`); favorite heart toggles with snackbar confirm (button tests)
- [ ] **Offline path:** airplane mode → `hydrateOffline` serves last browse with "showing saved results" copy; favorite attempt shows connectivity snackbar with Retry, not a silent queue — PENDING live-device verification (no staleness banner implemented; offline serving rests on inherited repo cache)

### 2.3 Success Conditions

- [x] Every success envelope is `{success:true, code:'PLT000', data:{items:[{…ranked projection…}], has_more bool, next_cursor {score,id}?, weights_version timestamptz}}` — consumed (never constructed) via `ServiceSearchEnvelopeParser` (EP-03-07 tested, untouched)
- [x] Empty query returns ranked defaults (discovery boots `search()` with null query — tested rows + empty states); `PLT004` renders identical to empty — implemented as no-oracle branch in `DiscoveryResultsView` + detail not-found view (both tested; `Could not load services` asserted absent)
- [x] Public routes (`/services`, `/services/search`, `/services/:id`, `/s/:slug/:id`) added with typed builders; guard allows anon on exactly these shapes while `/services/mine*` stays login-gated with `?next=` (route_paths + route_guard tests, incl. new EP-03-09 cases); `draft` detail id → `PLT004` → `HivorrEmptyState` (tested)
- [x] `search_vector` never appears in any payload, log, or rendered text (grep `search_vector|legal_name` over new screens/widgets = 0; no new logging added — `toggleFavorite` reuses redacted service logging)

### 2.4 Error Handling Scenarios

- [x] `PLT003` (negative/unparseable price, `max<min`, bad cursor/limit) → inline sheet error (`Maximum must be greater than minimum.` tested) or provider `error` → `HivorrErrorState` + Retry, never a crash
- [x] `PLT004` → `HivorrEmptyState` not-found (search results + detail; identical for unknown vs foreign vs empty — tested)
- [x] `PLT005` (self-favorite, non-`published` favorite) → server message surfaced via error snackbar (e.g. "You cannot favorite your own listing."); self-hire CTA → disabled + guidance copy. No dedicated guidance-card-with-deep-link widget (snackbar + CTA copy carry the guidance)
- [x] `PLT001/002` → favorite shows "Sign in to save favorites."; detail CTA routes anon to login with `?next=<detail>` preserved (login-nav path not tapped in tests — no router in harness; guard `?next=` behavior covered by guard tests)
- [x] RPC 5xx / timeout / offline search → provider holds `error` → `HivorrErrorState` + Retry via `search()`; never stale `loaded` items presented as fresh (`_run` clears items on fresh-search failure; `RetryInterceptor` inherited)
- [x] Media thumbnail failure → `_MediaPlaceholder` tile (tested with unresolvable URLs); other carousel pages unaffected (`PageView.builder` per-index `errorBuilder`)

### 2.5 Important User Interactions

- [x] Search header (search-entry card on discovery; `TaxonomySearchField` + Filters button with active-state variant on search), `Wrap(HivorrChip)` quick filters, count line ("N services"), `RefreshIndicator`, `Load more` footer — all via ≥48dp `Hivorr*` primitives (deviation D5: discovery uses an entry card pushing to search rather than an inline field; filter button signals activeness by variant, not a dot)
- [x] Filter sheet (`HivorrBottomSheet`): numeric price fields + currency chips, rating selector, verified-only toggle, availability date picker, Apply + Clear-all + dismiss; Apply yields exact `ServiceSearchFilters` (tested incl. thousands-separator parsing)
- [x] Detail CTA `HivorrButton primary` full-width (≥48dp primitive); favorite is a reversible toggle with snackbar (no destructive actions on this task; CTA has no async loading state — its actions are sync nav/snackbar)
- [x] Every empty state has a primary action where one exists (`Clear filters`, `Browse services`, `Add portfolio` owner-gated, `Retry` on errors); favorite success uses `HivorrSnackbar`
- [x] Accessibility: `Semantics` labels on cards (rating), favorite toggle, carousel position, explainer chip; responsive 1/2/3-col via `Breakpoints` (mobile list / tablet 2 / desktop 3). Partial: no size-matrix overflow test extended to new screens (established pattern exists for owner screens only)

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] Layering `screens|widgets → Provider → Repository → SupabaseServiceSearchRemoteDataSource(BaseApiService) → service_ranking_search`; detail/favorite go `ServiceDetailScreen/FavoriteToggleButton → ServiceListingService → ServiceListingRepository → RPC`. No screen imports a remote datasource or Supabase client (verified by construction + `dart analyze`)
- [x] Zero business logic in UI: price lines are `HivorrFormatters` display-only; no ranking computation, gate evaluation, or aggregate averaging for ordering in Dart (`AGENT.md:5,6`); currency vocabulary reused from `ServiceListingService.currencies`, not forked
- [x] Deterministic Core Supremacy (`AGENT.md:7`): grep `sort.*score|score.*sort|items\.sort|list\.sort` over `lib/systems/marketplace/screens|widgets` = 0; provider assigns `items = page.items` verbatim (pre-existing, covered by `marketplace_search_provider_test`: "assigns RPC items verbatim")
- [x] Proprietary Logic Protection (`AGENT.md:6` + Rule 4): all scoring stays in the `SECURITY INVOKER STABLE` RPC (untouched); `RankingFormula` never imported by new code — explainer dialog is static qualitative copy
- [x] No `lib/ai` import anywhere in the discovery path (grep over new screens/widgets = 0; new code imports only data/shared/systems/router/core-auth)
- [x] Visual Identity (`AGENT.md:18`): `HivorrScreenScaffold` + 1120dp list cap + `Breakpoints` grid; tokens only — grep `Colors\.|fontFamily|0xFF|from('service_listings')|lib/ai` over new screens/widgets = 0. Correction C1: the DoD/plan literal "`ColorScheme.primary == #0B6E99`" is stale — the source of truth `VISUAL-IDENTITY.md:32,114,548` and `AppColors.brandPrimary` define `#2D3FE7`, asserted green by `app_theme_test` (19 tests, re-run). Deviation D6: `HivorrResponsiveScaffold` not used — list screens follow the `MyListingsScreen` 1120-cap precedent cited in the plan

### 3.2 Required System Behavior

- [x] Single RPC discipline: ordering exclusively via `service_ranking_search` through the EP-03-07 seam (untouched); grep `from('service_listings')` over new screens/widgets = 0; `listMine`/`list_mine` never referenced in new screens (grep = 0)
- [x] Envelope vocabulary honored: EP-03-07 parser maps `PLT000/003/004/005/PLT999`/42501/P0001; new code branches only on `code == 'PLT004'` (no-oracle) and surfaces all other messages verbatim
- [x] Browse = cache-first (`warmBrowse` on discovery `initState`), FTS query = network-first — repository contract inherited untouched (EP-03-07 `service_search_repository_impl` tests green)
- [x] `weights_version` returned per page; `refresh()/invalidate()` semantics inherited untouched (existing `marketplace_search_provider_test` green: refresh no-op until loaded, invalidate resets)

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `MarketplaceSearchProvider` (`idle/loading/loaded/error`, `hasActiveFilters/isEmpty`, 250ms `setQuery`, verbatim `search/loadMore/refresh/invalidate`) | Untouched; existing `marketplace_search_provider_test` (7 tests) green; new screen tests drive `setQuery`+trailing `search()`, profession filter, and `loadMore` footer through it |
| `TaxonomyProvider/Engine/Repository` + pickers/browser | Provider/repository/engine reused read-only (`loadIndustries`/`loadProfessions`, `industries`, `professionsByIndustry`); picker/browser widgets not embedded (D1). Selections resolve to active ids; `PLT004`-as-empty verified at results level |
| `ServiceSearchIndex` + `HiveServiceSearchLocalDataSource` + `CacheManager`/`LocalStore(AppBoxes.cache)` | Untouched; existing `service_search_index_test` + Hive local tests green. Screens call `warmBrowse()` best-effort on discovery boot and tolerate a missing seam (tested: instant row holds with no service/index in tree) |
| `PortfolioProvider/Service` (read-only) | NOT consumed — deviation D3: no listing↔portfolio link data exists until EP-03-15, so the slot is a placeholder (`_ProofSlot` + owner-gated copy); no link-write attempted |
| `service_listing_get` (detail re-read) | Detail fetches the authoritative row via newly-wired `ServiceListingService.getListing`; `media[]` order preserved verbatim into the carousel (upgrade + cover/position tests). Wiring the pre-existing `registerServiceListingLayer` into bootstrap/app also repairs the EP-03-08 owner screens' missing provider (reported) |
| `service_favorite_toggle` | Heart toggles via new `repository/service.toggleFavorite` returning `favorited`; failure shows snackbar and keeps prior state (no phantom favorite); envelope key `favorited` verified against migration `20260921090001:1259-1267` |
| Router (`RoutePaths`/`RouteNames`/`AppRouter` + `_isPublicContentView`) | New public discovery routes follow `/p/:slug/:id` precedent; protected owner routes untouched and proven still gated (`/services/mine*` → login `?next=`); unauth deep-link preserves `?next=` (guard tests extended) |

### 3.4 Technical Requirements

- [x] New assets live only under existing `lib/systems/marketplace/screens|widgets/` (+ `lib/app/router/` constants, + additive DI/provider surface in `lib/app/*`); no new top-level `lib/` directories (`ARCHITECTURE.md:39-173` — verified via directory listing)
- [x] `ServiceSearchFilters` value object is the single `p_filters` builder; no ad-hoc JSONB construction in screens (sheet constructs exactly one `ServiceSearchFilters` on Apply — tested field-by-field)
- [x] `p_cursor {score,id}` serialization round-trips (new cursor unit test); `p_limit` default 20 via provider with server-side 1–50 clamp (no client limit control added); `p_query` trimmed client-side and capped by `TaxonomyEngine.maxSearchQueryLength`/server 100 (server authoritative)
- [x] Reused widgets (`TaxonomySearchField`, `HivorrCard/Chip/Button/Badge`, `HivorrBottomSheet`, `HivorrEmpty/Loading/ErrorState`, `TradeVerifiedBadge`, `HivorrSnackbar`, `HivorrSectionHeader`) consumed unmodified; only `hint`/wiring adapted. `IndustryPicker`/`ProfessionPicker`/`Browser` not embedded (D1)
- [x] No new logging added; `toggleFavorite` reuses redacted service logging (suffix-only id); no title/description/`search_vector`/email bytes in new code paths (grep = 0)

---

## 4. Data Verification

### 4.1 Data Creation

- [x] Discovery creates zero rows in `service_listings` / `service_review_aggregates` / `financial_*` / `availability_slots` — the only write path added is `service_favorite_toggle` on `service_favorites` (favorite tests assert the in-memory favorite set flips both ways)
- [x] No cache write fabricates listings: new code performs zero cache writes (all caching stays inside the untouched `ServiceSearchRepositoryImpl` two-tier path)

### 4.2 Data Updates

- [x] No client update to `avg_rating` / `review_count` / `search_vector` / `published_at` / `platform_config` weights from this task (no update code paths added anywhere in new files)
- [x] `invalidatePrefix(service_search:)` behavior untouched — fires only on `weights_version` change or explicit `refresh()` inside the inherited repository (no new invalidation call sites)

### 4.3 Data Relationships

- [x] Rendered `profession_id → professions.id` and `industry_id → industries.id` come straight from the RPC row (trigger-derived `industry_id` trusted, never client-supplied — filter sheet only sends selected ids back as filters)
- [x] Detail `entity_id` is used only for the self-hire comparison and favorite scoping; drafts of other entities are unreachable (only `published` rows are searchable server-side; direct draft id → `PLT004` empty state, tested)

### 4.4 Data Accuracy

- [x] Displayed `avg_rating`, `review_count`, `price_min/max` + `currency_code`, `profession/industry` names render the RPC row exactly — formatting via `HivorrFormatters` display-only (card test asserts `NGN 5,000 – 15,000`, `4.5`, `3 reviews`; custom pricing renders `Custom quote` without crashing — tested)
- [x] `score numeric(10,6)` never rendered as a user-facing number (grep `.score` over new code = 0); explainer dialog describes the signal mix qualitatively only
- [ ] `rating_min=4.5` filter provably excludes `<4.5` rows in integration test; `is_trade_verified_only=true` subset `≤` unfiltered count — PENDING live-Dev integration (server semantics inherited from EP-03-07 pgTAP; client applies the keys exactly — unit-tested)

### 4.5 Data Integrity

- [x] Sequential pages append via keyset cursor (`loadMore` appends `page.items`; `ValueKey(id)` rows; `has_more` gates the footer). Live zero-`id`-overlap run pending §7.2 integration — provider append semantics covered by existing provider tests
- [x] Media order `sort_order ASC, created_at ASC` with cover (`sort_order 0`) first, preserved from DTO through carousel (carousel cover/position test on a 2-item server-ordered list)
- [x] Zero new tables/migrations/RPCs/RLS/indexes/buckets: `git diff -- supabase` empty (verified); storage config untouched

---

## 5. Security Verification

### 5.1 Authentication

- [x] `anon` can browse/search `published` ranked pages — guard allows `/services`, `/services/search`, `/services/:id`, `/s/:slug/:id` without session (guard tests); `authenticated` parity is a server-RLS property (untouched, EP-03-07 proven)
- [x] Favorite toggle without session → "Sign in to save favorites." guidance (no silent fail). Partial: no login deep-link action attached (button lacks route context) — re-login navigation pending a follow-up affordance

### 5.2 Authorization

- [x] Owner-only reads (`service_listing_list_mine`) are never used for public discovery ordering — grep `listMine|list_mine` over new screens = 0; ordering flows only through `MarketplaceSearchProvider` → `ServiceSearchRepository`
- [x] `reported`/`archived`/`paused`/`draft` listings can never appear in discovery: only `published` rows are returned server-side, and the client renders whatever the RPC returns verbatim (no status override or second source)

### 5.3 Access Control

- [x] RLS `published`-only visibility holds in UI: direct navigation to a `draft`/unknown id renders 404/`HivorrEmptyState` via the `PLT004` branch, never the draft body (detail not-found test)
- [x] Self-hire CTA block is presentation affordance only (disabled button + copy); no client flag reaches any write path — contract writes ship in EP-03-10 behind server gates (tested owner-disabled rendering)

### 5.4 Sensitive Data Protection

- [x] No `search_vector`, `legal_name`, document paths, payer names, unrevealed review bodies, or non-participant conversation data rendered or logged (grep over new code = 0; projections don't carry these fields)
- [x] Media served via `ServiceListingService.mediaPublicUrl` (`getPublicUrl` on the public `service-listing-media` bucket) with null-safe placeholder fallback; no private-bucket surface added (bucket policy untouched)
- [x] No new log call sites; the one reused path (`toggleFavorite`) logs suffix-redacted ids only

### 5.5 Security Rules

- [x] Zero-trust client (`AGENT.md:17`): no pricing/ranking/gate/escrow logic in new Dart; the only state-changing call added is the pre-existing `service_favorite_toggle` RPC (verified against migration `20260921090001:1201-1292`, invoker, `authenticated`+`service_role` only)
- [x] Injection: client passes raw trimmed text through the typed `p_query` RPC param, never interpolates SQL (search screen forwards controller text; server `plainto_tsquery` sanitizes — EP-03-07 probe `lives_ok`, untouched)
- [x] No `SECURITY DEFINER` added; no RLS policy edited; no Realtime publication added (`git diff -- supabase` empty)

---

## 6. Performance Verification

- [x] No unbounded fetch: provider default `p_limit` 20 with server 1–50 clamp; `has_more` gates `Load more`; field (250ms) + provider (250ms) + trailing screen timer debounce the RPC (typing test proves one settled search per input burst)
- [x] One RPC per page (single `repository.search` per `search()`/`loadMore()`); detail = one `getListing` (+ zero portfolio fetches — placeholder, D3); thumbnails via `Image.network` with placeholder (deviation D7: no `CacheManager` image caching — `cached_network_image` is not a project dependency and adding one is out of scope)
- [x] `ListView`/grid uses `ValueKey(id)` rows; image cache sizes not constrained (D7). 60fps scroll on reference low-end device — PENDING manual walkthrough
- [ ] Informational targets (EP-03-20 gate, accepted deferral if staging numbers pending): discovery first paint from warm cache <1s; filtered search p95 <400ms on staging with seeded volume — DEFERRED to EP-03-20 (same pattern as EP-03-07/08; no staging backend in this environment)

---

## 7. Testing Verification

### 7.1 Manual Testing

- [ ] As `anon` (incognito): browse → filter → paginate two pages → open detail → favorite prompts login; `draft` URL → 404 empty state — PENDING manual device walkthrough (all sub-paths covered by widget/guard tests above)
- [ ] As `authenticated` client on mobile + web responsive shells: search `legal drafting` → ranked hits; apply `rating_min 4.5` + verified-only → subset shrinks; `Load more` appends without duplicates; pull-to-refresh preserves filters — PENDING manual walkthrough (widget equivalents green)
- [ ] As owner-professional viewing own listing: detail shows owner-gated portfolio CTA; `Book` CTA disabled with self-hire copy — COVERED by widget test (`owner sees a disabled CTA`); device confirmation pending
- [ ] Offline (airplane): discovery serves saved browse with staleness copy; online restore refreshes without manual clear — PENDING (no staleness banner implemented; see §2.2)

### 7.2 Automated Testing

- [x] Unit: `ServiceSearchFilters → p_filters` matrix (empty object, profession+industry keys, price+currency keys, rating key, canonical verified-only key, ISO8601 availability, cursor round-trip) — 7 asserts PASS (`service_search_filters_test.dart`); `toggleFavorite` repo + service round-trip — PASS (`service_listing_favorite_test.dart`)
- [x] Widget (with fakes, no live RPC): verbatim order (low-rating-first pair renders unflipped); chip/sheet state → exact `ServiceSearchFilters` on fake (rating+verified, industry+profession+price+currency, max<min rejection); deep-linked query reaches RPC; debounced typing fires settled search; CTA disabled for owner; media order preserved; instant-paint + authoritative upgrade + no-seam degradation — ALL PASS (8 files, 24 tests)
- [ ] Integration (Dev seed via EP-03-08 `create → publish`): query returns ranked hits; `rating_min=4.5` excludes `<4.5`; two sequential pages zero `id` overlap; `hydrateOffline` serves Hive page with radio off; favorite toggle round-trips; `draft` URL unauth → 404 empty — PENDING live-Dev backend (no staging backend in this environment)
- [x] Static: `dart analyze` clean (full project, `No issues found!`); `flutter test` green on new + regression suites (marketplace unit+widget 64+, provider, engine index, dashboard matrix, route/guard, theme — all PASS); `flutter_lints` via analyze; forbidden greps (`sort.*score`, `Colors.|fontFamily|0xFF`, `from('service_listings')`, `lib/ai` over new screens/widgets) all 0
- [ ] Golden: mobile + web responsive snapshots for discovery / search-with-sheet / detail — MISSING (no golden infra exists in repo practice; responsive-matrix overflow pattern was not extended to new screens — gap for a follow-up)

### 7.3 Edge Cases

- [x] Empty / whitespace query → ranked defaults (discovery boots null-query search — tested); stopwords-only and identical-`score` ties are server-ranking behaviors inherited from EP-03-07 (pgTAP-proven, untouched)
- [x] `custom` pricing with null `price_min` renders `Custom quote` without crashing (card test); price filters treat empty fields as unset (sheet parse test)
- [x] `0 reviews` / `0 contracts` rows render from the RPC row without client averaging (card renders `0.0 (0 reviews)` path via `toStringAsFixed` display-only — no division in new code)
- [x] Corrupt/foreign `p_cursor` and `p_limit 0/51` are server-validated (`PLT003`/exhausted-page); client clamps only the default (20) and passes cursors through opaquely

### 7.4 Failure Scenarios

- [x] RPC failure after favorite tap → error snackbar, prior heart state kept (no optimistic flip, so no phantom favorite by construction)
- [x] Supabase 5xx / timeout → provider `error` → `HivorrErrorState` + Retry; fresh-search failure clears items (never stale `loaded` presented as fresh)
- [x] `CacheManager` full / Hive unavailable → inherited LRU eviction + in-memory fallback inside the untouched cache layer (EP-03-07 tested)
- [x] Thumbnail 404 / oversized media → placeholder tile with position badge; carousel and detail body unaffected (tested with unresolvable URLs)

---

## 8. User Acceptance Verification

- [ ] As client on mobile + web: discovers a verified professional in ≤3 taps from browse, applies a price + rating + verified filter successfully, opens a detail that feels trustworthy (trade badge + photos + proof slot), and reaches the `Book / Request Proposal` entry point without support — PENDING lead walkthrough (all mechanics widget-tested)
- [ ] As self-viewing / unverified user: understands exactly why the CTA is disabled and what to do next — PENDING walkthrough (copy implemented + owner path tested: "This is your listing — you cannot hire yourself.")
- [ ] As downstream dev (EP-03-10/15/19 reviewer ack): discovery routes, card, filter-sheet, and carousel are consumable unmodified for contract entry, portfolio linking, and SEO meta — PENDING reviewer sign-off

---

## 9. Final Approval Checklist

| # | Condition | Evidence | Verdict |
|---|---|---|---|
| 1 | 3 screens + 6 widgets + router entries landed under existing `lib/systems/marketplace/` + `lib/app/router/`; no new top-level `lib/` dirs | `git status` + `dart analyze` clean | ✅ PASS |
| 2 | Verbatim RPC order; `RankingFormula` untouched/tooltip-only; forbidden sort/ai/direct-table greps all 0 | grep outputs (0) + low-rating-first widget test | ✅ PASS |
| 3 | `p_filters`/cursor/limit contract respected; pagination appends via keyset | unit matrix + provider tests; live zero-overlap run pending | ⚠️ PARTIAL — code verified, live overlap deferred to integration |
| 4 | Empty → ranked defaults; `PLT004` == empty; `PLT005`/auth guidance verified | widget tests (empty, PLT004-as-empty, self-hire, sign-in copy) | ✅ PASS |
| 5 | Self-hire CTA disabled with copy; `draft` unauth → 404 empty | widget tests; device walkthrough pending | ⚠️ PARTIAL — code verified, walkthrough pending |
| 6 | Offline browse via Hive/CacheManager; `weights_version` bump invalidates prefix | Inherited EP-03-07 path (tested, untouched); no new screen-level offline test; no staleness banner | ⚠️ PARTIAL — inherited verified, screen-level affordance missing |
| 7 | `dart analyze` + `flutter test` green | Full-project analyze clean; 100+ tests PASS | ✅ PASS (goldens missing — gap, no golden infra in repo) |
| 8 | Zero hardcoded colors/fonts; canonical `#2D3FE7` assert green; 48dp targets | scans 0 + `app_theme_test` 19 PASS + Hivorr primitives (`#0B6E99` literal superseded — C1) | ✅ PASS (manual check pending) |
| 9 | Logging redacted; no `search_vector`/`legal_name`/blind-review leakage | grep 0; no new log sites; redacted reuse | ✅ PASS |
| 10 | Zero new SQL/storage/RLS; no plan/architecture edits | `git diff -- supabase` empty; `git diff` on tracked `documents/` empty | ✅ PASS |
| 11 | Downstream (EP-03-10/15/19) ack reusability | reviewer sign-off | ⬜ PENDING |

> All 11 gates required to flip `EP-03-09` from `Not Started` to `Completed`. Any unchecked box blocks Stage 3 discovery exit. Zero new SQL; zero `lib/ai` imports in discovery path; zero direct `service_listings` reads for ordering.

---

## 10. Approval Record

| Attribute | Value |
|---|---|
| **Decision** | Completed — approved by project lead, 2026-10-03 (deferrals accepted per pattern EP-03-07/08) |
| **Evidence** | `dart analyze` (full project): `No issues found!` · `flutter test`: 24 new EP-03-09 tests PASS (filters matrix 7, favorite 2, card 4, button 2, carousel 2, chip 1, sheet 3, discovery 3, search 3, detail 5) + regression green (marketplace 64+, provider 7, engine index, dashboard matrix, route/guard incl. 3 new EP-03-09 cases, theme 19) · forbidden greps (`sort.*score`, `Colors.\|fontFamily\|0xFF`, `from('service_listings')`, `lib/ai`, `search_vector\|legal_name`, `listMine`) all 0 · `git diff -- supabase` empty · `git diff` on tracked `documents/` empty |
| **Accepted deferrals** | Live-Dev integration (§7.2 third bullet, zero-overlap run, `rating_min` exclusion run) → needs staging backend (none in this environment) · staging p95 <400ms → EP-03-20 gate (same pattern as EP-03-07/08) · manual walkthrough (§7.1), UAT (§8), downstream ack (gate 11) → human gates |
| **Residual risk** | Low. Deviations D1–D7 are presentation-scoped and documented inline (chip rows vs picker widgets; no cover thumbnails — projection lacks media; no avatar header — projections lack identity fields; in-flow CTA; placeholder proof slot until EP-03-15; no `HivorrResponsiveScaffold`; no image cache sizing). Correction C1: `#0B6E99` literal superseded by canonical `#2D3FE7` (VISUAL-IDENTITY source of truth, asserted green). Gaps: no golden snapshots (no golden infra in repo); no staleness banner; favorite sign-in lacks login deep-link action; pre-existing unrelated `admin_*` working-tree modifications left untouched |
