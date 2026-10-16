# EP-03-19 — Public Listing Routes & SEO Discoverability
## Task Implementation Plan (planning artifact only — no code written)

### 1. Task Objective

Implement the approved EP-03-19 objective (§11):

> Routes `/s/:profession_slug/:service_id` (public listing detail), `/s/:industry_slug` (profession-filtered browse), `/c/:profession_slug/:entity_id` alias compatibility for profile → listing cross-link. Extend `lib/app/router/*` with public (unauth) read guard, deep-link redirect, web `pathUrlStrategy` clean URLs, `lib/systems/portfolio/seo/portfolio_seo_meta.dart` extension for listing meta (title, description, `og:image` via `logo_icon.png` fallback). Responsive via `lib/shared/layouts/breakpoints.dart` + `HivorrContentPane`.

Engineering purpose: SEO discoverability without auth while drafts remain private. Marketplace must be indexable on web; canonical meta deferred from EP-03-09 ships here.

Approved dependencies: `EP-03-08`, `EP-01-15` (router), `EP-02-19` (SEO pattern). Approved reasoning: Planning **High** / Coding **High**.

### 2. Business Problem Being Solved

1. Published listings are currently reachable via app-internal shapes (`/services`, `/services/:id`) plus an SEO alias (`/s/:slug/:id`) whose **canonical meta was explicitly deferred** (`app_router.dart:768`, `route_paths.dart:207`).
2. No industry-browse SEO entry (`/s/:industry_slug` does not exist), no `/c/` compatibility alias, no dynamic `<title>`/description/canonical/`og:` per listing, and `web/index.html` + `manifest.json` contain only a static generic description, stale description, and no `og:`/`canonical`/`robots`/JSON-LD.
3. Without this, word-of-mouth / cross-role discovery (`Business-Roadmap:44-50`) cannot be crawled or shared as stable URLs, while the privacy invariant (draft = owner-only, published = public) must hold.

### 3. Scope

**In scope:**

- Add missing public routes, reusing existing screens (no duplicate screens):
  - `GET /s/:industrySlug` → filtered browse (industry-validated; profession-filtered browse per approved wording).
  - `GET /c/:slug/:id` → compatibility alias → canonical redirect to `/p/:slug/:id` (profile → listing cross-link; no new screen).
- Harden existing `/s/:slug/:id`, `/services`, `/services/search`, `/services/:id`, `/p/:slug/:id` for SEO: slug-cosmetic / id-authoritative preserved, mismatch renders without redirect chain (EP-02-19 pattern), `draft` unauth → SEO-404 (`HivorrEmptyState`), `published` unauth → renders detail.
- Listing SEO meta: new `ListingSeoMeta` + builder extending `PortfolioSeoMeta` pattern (title, description ≤160, canonicalUrl, `og:image` with `logo_icon.png` fallback — closing the EP-03-15 DoD deferral).
- Dynamic web head updates on web only (`document.title`, `meta[name=description]`, `link[rel=canonical]`, `og:*`) via `web: ^1.1.0` interop behind a small seam; static shell hardening in `web/index.html`, `web/manifest.json`, plus static `web/robots.txt` (+ `web/sitemap.xml` stub pointing at stable public doors).
- Guard/allowlist updates: `RouteGuard._isPublicContentView`, `NotificationTapDispatcher.isAllowedRoute`, `router_harness.dart` coverage for new shapes.
- Responsive compliance via existing breakpoints/scaffolds; `AppTheme` token compliance (no new theme).

**Route-shape reconciliation (no silent redesign):** the approved doc names `/s/:industry_slug` and `/c/:profession_slug/:entity_id`, while the codebase already ships `/services` (browse), `/services/search?q=&profession=`, `/services/:id`, `/s/:slug/:id`, `/p/:slug/:id`. The plan keeps all existing canonicals untouched and adds only the two genuinely missing shapes as thin wrappers/redirects over existing screens. Rationale documented in §6.

### 4. Out of Scope

- No new tables, columns, RPCs, RLS policies, storage buckets, ranking formula changes, FTS index changes, or financial logic.
- No SSR / prerender service / Edge Function renderer. Flutter web remains SPA; SEO is stable URLs + correct head/meta + crawlable static shell, not server rendering.
- No admin console expansion, no `/store/` changes, no AI ranking/display changes, no EP-04 product/store/logistics routes.
- No new state framework, no new design tokens, no hardcoded colors/fonts.
- No authenticated deep-link changes for `/contracts/*`, `/dashboard/*`, `/services/mine*`.

### 5. Existing Asset and Dependency Analysis

Inspected (read-only) before proposing anything new:

| Asset | Path | Finding — reuse as-is |
|---|---|---|
| Router config | `lib/app/router/app_router.dart` (812 lines) | `GoRouter`, `refreshListenable`, `redirect: routeGuard`, `initialLocation` web `/welcome`. Discovery/detail/profile/store routes already exist with comments "canonical meta ships in EP-03-19". `usePathUrlStrategy()` already in `lib/main.dart`. **Reuse; add 2 routes only.** |
| Path constants | `lib/app/router/route_paths.dart`, `route_names.dart` | `serviceDiscovery=/services`, `serviceSearch=/services/search`, `serviceDetailRoute=/services/:id`, `serviceSeoDetailRoute=/s/:slug/:id`, `publicProfileRoute=/p/:slug/:id`, `publicStoreRoute=/store/:storeId`. Builders URL-encode. **Extend with 2 constants + builders.** |
| Public guard | `lib/app/router/route_guard.dart` + `lib/core/authentication/guards/auth_guard.dart` | `_isPublicContentView` already allows `/p/`, `/store/`, `/services`, `/services/search`, `/services/<single-id>`, `/s/`. `_defaultPublicPrefixes` is auth/welcome/info only. Fail-closed `?next=` resume. **Extend prefix check for `/s/<single>` and `/c/`.** |
| Listing read path | `service_listing_get` (`20260921090001:1106,1287`), `service_ranking_search` (`20260927090001:540`), `service_listing_portfolio_list` (`20261007090001:348`) | All `SECURITY INVOKER`, `grant execute … to anon` for public reads; RLS `status='published'` public `SELECT` to `anon,authenticated`; `PLT004` identical for unknown vs non-visible. Slug is client-cosmetic, `:id` authoritative. **No DB change; reuse RPCs.** |
| Detail/discovery screens | `lib/systems/marketplace/screens/service_detail_screen.dart` (565 lines), `marketplace_discovery_screen.dart`, `marketplace_search_screen.dart` + `services/service_listing_service.dart`, `providers/service_listing_provider.dart` | Instant-paint `initialListing` → authoritative `getListing` re-read; `?next=` login resume; self-hire disable; 250 ms debounce; `DiscoveryResultsView` verbatim order. **Reuse screens; no new screens.** |
| Portfolio SEO pattern | `lib/systems/portfolio/seo/portfolio_seo_meta.dart` (103 lines) + `services/professional_profile_service.dart:140-148 seoMeta()` + `screens/professional_profile_screen.dart` SEO-404 semantics | `title=displayName · professionName`, `description=bio.truncate(160)`, `canonical={origin}/p/{slug}/{entityId}`; RPC slug wins, route slug fallback; never `legal_name`. `seoBaseUrl=''` injectable via `registerPortfolioLayer`. **Canonical pattern to extend.** |
| Taxonomy slugs | `data/entities/profession.dart`, `industry.dart`, `service_listing.dart:47-48,83` (`slug`, `professionSlug`, `industrySlug`), `workspace/profession_registry/taxonomy_engine.dart` + pickers | SEO-stable `^[a-z0-9-]+$` slugs; `TaxonomyEngine` pure-Dart, no hardcoded slugs. **Reuse for `/s/:industrySlug` validation + canonical slug resolution.** |
| Layouts/theme | `shared/layouts/breakpoints.dart` (600/1024), `hivorr_responsive_scaffold.dart`, `hivorr_content_pane.dart` (720), `hivorr_screen_scaffold.dart`, `mobile_compact.dart`; `app/theme/*` (`#2D3FE7`, `Plus Jakarta Sans`) | Detail uses 1120 cap + `HivorrDetailScaffold`; profile uses `ContentPane`. **Reuse; no new layout.** |
| Growth engine seam | `lib/engine/growth_engine/` — only `.gitkeep`; ARCHITECTURE.md reserves it for "SEO metadata & referral loop engine" | Empty by design. **Correct home for thin SEO seam; do not create parallel `marketplace/seo/` silo.** |
| Notification deep-links | `core/notifications/navigation/notification_tap_dispatcher.dart` (allowlist includes `/services`, `/s/`, `/p/`), `templates/lifecycle_notification_templates.dart`, `push/supabase_push_receiver.dart` | Payloads carry IDs + event only; malformed → drop. **Add `/c/` + single-segment `/s/` to allowlist if dispatcher resolves them.** |
| Web shell | `web/index.html` (46 lines), `web/manifest.json`, `pubspec.yaml` (`go_router:17.5.0`, `flutter_web_plugins`, `web:^1.1.0`, no SEO package) | Static description only; manifest description `"A new Flutter project."`, `theme_color #0175C2` ≠ brand. No `og:`, `canonical`, `robots`. **Harden static shell; no new pub dependency.** |
| Tests | `test/unit/app/route_guard_test.dart` (722 lines), `route_paths_test.dart`, `support/harnesses/router_harness.dart` (no `/services*`/`/s/*`), portfolio `seoMeta` + `public_profile_integration_test`, marketplace widget tests | Guard matrix + SEO-meta pattern proven. Harness lacks new shapes; zero listing-SEO tests. **Extend, don't replace.** |

Dependency status: EP-03-08 and EP-03-09 are `Completed` (DoDs 2026-09-28 / 2026-10-03); EP-02-19 SEO pattern is Approved/built; EP-01-15 router (`go_router` + path URLs) is live. EP-03-19 is Stage 3 sequencing-correct (after listing CRUD + ranked discovery, before transaction core).

### 6. Reuse / Extension / Refactoring Assessment

| Proposed need | Verdict | Rationale |
|---|---|---|
| Listing detail rendering for `/s/:slug/:id` | **Reuse** `ServiceDetailScreen` + `ServiceListingService.getListing` + `service_listing_get` RPC | Already serves both `/services/:id` and `/s/:slug/:id`; authoritative re-read + SEO-404 already implemented. New screen would duplicate business logic and violate bounded scope. |
| Browse rendering for `/s/:industrySlug` | **Reuse** `MarketplaceDiscoveryScreen` / `MarketplaceSearchScreen` stack with `initialIndustrySlug` filter | Same ranked `service_ranking_search` + taxonomy cache + `DiscoveryResultsView`. New browse screen would fork filter/pagination logic. |
| Profile alias `/c/:slug/:id` | **Reuse** via redirect to canonical `/p/:slug/:id` (`ProfessionalProfileScreen`) | `/c/` is compatibility only. Rendering a second profile screen creates canonical-duplication SEO harm; redirect preserves link equity and single source of truth. |
| SEO meta model | **Extend** `PortfolioSeoMeta` pattern → new `ListingSeoMeta` in growth-engine seam | Portfolio builder is profile-specific (`PublicProfile`, `/p/` canonical). Generalizing it to handle listings would pollute its contract; a sibling builder reusing its truncation/canonical/origin conventions is correct extension. Refactoring `PortfolioSeoMeta` into a generic base is rejected — unnecessary churn on a verified EP-02-19 asset. |
| SEO head application | **New (genuine gap)** — thin `SeoHead`/`SeoService` in `lib/engine/growth_engine/` + `shared/` widget | Nothing in repo writes `document.title`/`meta`/`canonical`/`og:` dynamically (`grep og:/canonical` only in comments). Must be designed reusable (profile + listing + future store/product) and web-guarded (`kIsWeb`) so mobile is no-op. |
| Router constants/guards | **Extend** `route_paths.dart`, `route_names.dart`, `route_guard.dart`, `auth_guard` consumers, `notification_tap_dispatcher.dart` | Add `serviceSeoBrowseRoute=/s/:industrySlug` + builders and `profileAliasRoute=/c/:slug/:id`; extend `_isPublicContentView` and dispatcher allowlist. No guard-logic rewrite. |
| Static web shell | **Extend** `web/index.html`, `web/manifest.json`; **new** `web/robots.txt` (+ minimal `web/sitemap.xml`) | Correct stale manifest description + theme color, add `og:`/`twitter:`/`theme-color`/`robots` static fallbacks. No new packages. |
| Tests/harness | **Extend** `router_harness.dart`, `route_guard_test.dart`, `route_paths_test.dart`; **new** `listing_seo_meta_test` + router integration tests mirroring portfolio SEO tests | Follows proven `seoMeta` group + `public_profile_integration_test` pattern. |

No duplicate data models, validation, authorization, status systems, or APIs are proposed. New assets (`ListingSeoMeta`, `SeoHead` seam, two routes, static web files) integrate with the existing platform and are reusable by EP-04 product/store routes.

### 7. Recommended Technical Approach

1. **Routing (thin delta, order-sensitive).** In `route_paths.dart` / `route_names.dart` add `serviceSeoBrowseRoute = '/s/:industrySlug'` + `serviceSeoBrowse(industrySlug)` and `profileAliasRoute = '/c/:slug/:id'` + `profileAlias(slug,id)`. In `app_router.dart`, register in this order: `/s/:slug/:id` (2-segment, existing) **before** `/s/:industrySlug` (1-segment, new) to avoid shadowing; `/c/:slug/:id` as `redirect: (ctx,state) => RoutePaths.publicProfile(slug route, id)` preserving query params, never rendering directly. `Browse` builder reuses `MarketplaceDiscoveryScreen(initialIndustrySlug: pathParam)`; detail builder stays `ServiceDetailScreen`. No `onExit`/canonical-redirect loops; slug mismatch still renders (cosmetic), never 301-chains (EP-02-19 semantics).
2. **Public-read enforcement (no DB change).** Keep `service_listing_get` / `service_ranking_search` as the only anon seams. `RouteGuard` extended to treat `/s/<single>` and `/c/` as public-content views; `AuthGuard` untouched. Owner routes (`/services/mine*`), contracts, messages remain fail-closed with `?next=` resume. Verify via existing pgTAP posture audit — no migration in this task; if audit finds a gap, file it for EP-03-01 follow-up rather than expanding scope.
3. **SEO meta (extend pattern).** New `ListingSeoMeta{title,description,canonicalUrl,ogImage}` + `ListingSeoMetaBuilder.build({required ServiceListing listing, required String baseUrl, String? routeSlug})` in the growth-engine seam (e.g. `lib/engine/growth_engine/listing_seo_meta.dart`, exported via barrel), mirroring `PortfolioSeoMetaBuilder`: `title = '{title} · {professionName}'` (fallback listing title), `description = description.truncate(160)` (fallback `'Verified service — {professionName} on Hivorr.'`), `canonical = '{origin}/s/{professionSlug ?? routeSlug ?? listing.slug}/{listing.id}'` (RPC `professionSlug` wins), `ogImage = listing.coverImageUrl ?? 'assets/images/logo_icon.png'`-derived absolute URL. Never include `legal_name`, `entity_id` of viewer, escrow, or contact PII. Inject `seoBaseUrl` the same way `registerPortfolioLayer({seoBaseUrl})` does (config/env origin, trailing-slash tolerant).
4. **Head application (web-only, reusable).** Small `SeoHead` widget (or `SeoService.update(meta)`) using `package:web` JS interop guarded by `kIsWeb`: sets `document.title`, `meta[name=description]`, `link[rel=canonical]`, `og:title/description/image/url/type`. Mounted in `ServiceDetailScreen` (listing meta), `MarketplaceDiscoveryScreen` (browse meta: `title='{Industry} services on Hivorr'`, canonical `/s/{industrySlug}`), and retrofitted minimally into `ProfessionalProfileScreen` so `seoMeta` actually reaches the document head (currently computed but not rendered — `_ScaffoldChild` title stays `'Profile'`). Mobile/desktop: no-op. No new dependency; unreadable if JS unavailable → static shell still valid.
5. **Static shell.** `web/index.html`: keep Flutter bootstrap; add static `og:site_name/type`, `twitter:card`, `theme-color #2D3FE7`, `robots` max-image-preview, canonical placeholder note (dynamic canonical wins at runtime). `web/manifest.json`: fix `description` + `theme_color/background_color` to brand tokens. Add `web/robots.txt` (allow `/services`, `/s/`, `/p/`, disallow `/services/mine`, `/contracts`, `/dashboard`, `/admin`, `/finance`, `/support`) and minimal `web/sitemap.xml` referencing stable public doors (regen owned by release pipeline, not per-listing).
6. **Responsive/a11y/visual identity.** No layout changes: detail keeps 1120 cap + carousel + `TradeVerifiedBadge` + proof section; browse keeps chip filters + `DiscoveryResultsView`; profile alias lands on existing `HivorrContentPane` profile. All text via `TextTheme`, colors via `ColorScheme`/`AppThemeExtension`, CTAs ≥48 dp, `HivorrEmptyState` for unknown-industry / draft-anon / not-found (same-URL SEO-404, no id echo). Browse route validates `industrySlug` against `TaxonomyEngine`/cached industries; unknown slug → `HivorrEmptyState`, not redirect loop.
7. **Notifications.** Add new public shapes to `NotificationTapDispatcher.isAllowedRoute` only if dispatcher is used to resolve them; payload schema unchanged (IDs + event, `***last4` only).

### 8. Required Systems, Modules, and Components

| Component | Location | Reuse / New |
|---|---|---|
| Route constants + builders (2 new) | `lib/app/router/route_paths.dart`, `route_names.dart` | Extend |
| Router registration + redirect | `lib/app/router/app_router.dart` | Extend (order: 2-seg before 1-seg) |
| Public guard | `lib/app/router/route_guard.dart` (+ `auth_guard.dart` consumers) | Extend `_isPublicContentView` |
| Listing SEO model | `lib/engine/growth_engine/listing_seo_meta.dart` (+ barrel/export) | **New** (genuine gap; reusable) |
| Head-update seam | `lib/engine/growth_engine/seo_head.dart` or `lib/shared/components/seo_head.dart` (decision at implementation; prefer growth_engine per ARCHITECTURE.md) | **New** (web-guarded, reusable) |
| Screen wiring | `service_detail_screen.dart`, `marketplace_discovery_screen.dart`, `professional_profile_screen.dart` (head mount only) | Extend (no new screens) |
| Service/data/taxonomy | `service_listing_service.dart`, `service_listing_repository*`, `taxonomy_engine.dart`, `profession/industry` entities | Reuse |
| Notification allowlist | `core/notifications/navigation/notification_tap_dispatcher.dart` | Extend |
| Web shell | `web/index.html`, `web/manifest.json`, `web/robots.txt` (new), `web/sitemap.xml` (new stub) | Extend + 2 static news |
| Tests | `test/unit/app/*`, `test/unit/systems/.../listing_seo_meta_test.dart`, `test/widget/marketplace/*seo*`, `test/integration/*public_listing_routes*` | Extend + new |

### 9. Data Requirements

- No new entities. Consumed DTOs: `ServiceListing` (`id` authoritative, `slug`, `title` 10–120, `description` 50–5000, `professionSlug/Name`, `industrySlug/Name`, `avgRating`, `isTradeVerifiedCache`, `publishedAt`), `PublicProfile` (existing), taxonomy `Industry`/`Profession` slugs.
- `og:image`: listing cover/media public URL when `service_listing_media` row is `published`-visible; else `logo_icon.png` absolute fallback. No signed/private URLs in meta.
- Origin for canonicals: injected `seoBaseUrl` (env per ENV-006; default `''` → relative canonical, same as portfolio). No hardcoding of prod origin in widgets.

### 10. Database Considerations

- **No migration.** RLS already satisfies the SEO privacy invariant: `service_listings_select_public (status='published')` to `anon,authenticated`; owner-only for drafts; media `SELECT` requires `published` parent or ownership; `service_listing_get` returns identical `PLT004` for unknown vs non-visible (no oracle).
- Implementation must add a posture check (not a migration): extend the `00*_security_posture_audit`-style pgTAP/CI check to assert anon `service_listing_get(draft-id)` → `PLT004`, anon `service_ranking_search` returns `published`-only, and no `authenticated` direct-`INSERT` bypass where RPC is canonical. Any failure is routed back to EP-03-01, not fixed by scope-creeping this task.

### 11. API Requirements

- **No new endpoints/RPCs.** Reused: `service_listing_get(uuid)` (detail + alias head), `service_ranking_search` (browse + filtered `/s/:industrySlug` as `p_filters={industrySlug|profession}`), `portfolio_public_profile_get` (alias target), `service_listing_portfolio_list` (proof carousel already on detail).
- Client seams reused: `SupabaseServiceListingRemoteDataSource`, `ServiceListingRepository`, `ServiceListingProvider`, `TaxonomyProvider`/`TaxonomyLocalDataSource` cache for industry validation.

### 12. User Interface Requirements

- `/s/:slug/:id`: existing `ServiceDetailScreen` + `SeoHead` mount; carousel order verbatim; `TradeVerifiedBadge`, rating aggregate, proof section, `Book/Request Proposal` CTA (self-listing disabled, anon `?next=` resume) unchanged.
- `/s/:industrySlug`: existing discovery stack pre-filtered to industry (chips reflect `industrySlug`; invalid slug → `HivorrEmptyState` + "Browse all services" action). Uses `HivorrResponsiveScaffold`, `HivorrChip`, `HivorrLoadingState(HivorrLoader)`, `HivorrErrorState` with retry.
- `/c/:slug/:id`: no UI; immediate redirect to `/p/:slug/:id`. Direct navigation shows profile, never a duplicate profile page.
- SEO-404: unknown id, draft-anon, or unknown industry renders same-URL not-found (`HivorrEmptyState`), no id/legal-name echo, no login-wall for `published`.
- All widgets consume `Theme.of(context).colorScheme` / `AppThemeExtension` + `TextTheme`; `logo*.svg` brand mark only; zero `Colors.*`/raw-hex/`fontFamily` per-widget (DoD gate per AGENT.md Rule 5).

### 13. User Experience Considerations

- Shareability: pasting `/s/plumber/abc-123` or `/s/technology` renders content without login; anon CTA tap preserves intent via `?next=` then resumes post-auth (existing pattern).
- No redirect chains on slug typo (cosmetic slug) — renders detail with canonical pointing at RPC slug; only `/c/` aliases redirect (single hop).
- Web back/forward + deep-link cold-start land on correct route with `pathUrlStrategy` (no `#/`); mobile deep-links unchanged.
- Copy must not leak verification internals: badges say `Trade Verified` / `Identity Verified`, never RLS/RPC codes; `PLT004` surfaces as friendly not-found.
- Localization via `lib/core/localization`; time display via `hivorr_formatters` if browse shows `publishedAt`.

### 14. Security Considerations

- Zero-trust client (AGENT.md Rule 4): no pricing/ranking/escrow logic added; SEO layer reads public RPC payloads only.
- Anon surface strictly `published`-only; drafts, contracts, messages, appointments, earnings, disputes never reachable via new routes. `PLT004` indistinguishability preserved; add negative tests for anon draft fetch + non-participant read (already covered for messaging — extend matrix to listings).
- `og:image`/canonical use public URLs only; no `legal_name`, `document_path`, contact, or escrow fields in meta (mirror EP-02-19 SV-08).
- Dispatcher allowlist prevents open-redirect via notification payloads; `/c/` redirect target is allowlisted canonical only, query-param passthrough encoded.
- `robots.txt` disallows private families; no `noindex` on `published`, `noindex`-equivalent (not-found, no canonical self-promotion) on drafts/unknown.

### 15. Performance Considerations

- Keyset `(score,id)` pagination reused; no unbounded fetches; `ServiceSearchIndex.warmBrowse()` + `LruCache` + Hive taxonomy cache reused for `/s/:industrySlug` instant paint.
- `initialListing` (`state.extra`) instant-paint retained; head update is O(1) DOM write, debounced with screen build, web-only.
- No N+1: detail performs single `getListing` + single portfolio-proof list; browse pages through ranking RPC.
- Target gates (for EP-03-20 to verify, not to re-benchmark here): filtered search p95 <400 ms on staging; Realtime unaffected; `EXPLAIN` shows existing GIN usage (no new indexes in this task).

### 16. Testing Strategy

| Layer | Cases (extend existing suites, don't fork) |
|---|---|
| Unit | `ListingSeoMetaBuilder`: title/description-160/canonical precedence (RPC slug > route slug > id), fallback copy, `logo_icon.png` fallback, trailing-slash origin, no `legal_name` in output; `route_paths` builders encode; `SeoService` web-stub no-op on non-web. |
| Widget | `SeoHead` sets title/meta/canonical via fake head adapter; detail mounts listing meta; browse mounts industry meta; alias never builds a screen (redirect); `HivorrEmptyState` for draft-anon/unknown-id/unknown-industry; theme-token assertion (no `Colors.*`/hex/`fontFamily`). |
| Router/guard | Extend `route_guard_test.dart` + `route_paths_test.dart`: anon `/s/<industry>` → null (public), anon `/s/<slug>/<uuid-published>` → null, anon `/s/<slug>/<draft-uuid>` → not-found (not login leak), anon `/c/<slug>/<id>` → redirect `/p/<slug>/<id>`, owner `/services/mine*` still `→ /login?next=`; route order test (2-seg beats 1-seg); harness `doorRouter` gains `/services*` + `/s/*` + `/c/*`. |
| Integration | Cold-start deep-link on web build: path URLs (not hash), `service_listing_get` anon published-ok / draft-`PLT004`; ranking order verbatim on `/s/:industrySlug`; `flutter build web` smoke + `dart analyze` + `flutter test`. |
| Static/SEO | `web/index.html` has description/`og:`/`twitter:`/`theme-color`; `manifest.json` description + brand colors fixed; `robots.txt` allows public / disallows private; `sitemap.xml` well-formed. Live crawl/p95/goldens deferred to EP-03-20 per EP-03-09 precedent. |

### 17. Recommended Implementation Sequence

1. Constants + router registration + guard/allowlist + harness (unblocks all manual testing).
2. `ListingSeoMeta` + builder unit tests (mirrors `seoMeta` group).
3. `SeoHead` web seam + screen mounts (detail → browse → profile-head retrofit).
4. Static shell (`index.html`, `manifest.json`, `robots.txt`, `sitemap.xml` stub).
5. Router/guard/widget/integration tests + `dart analyze` + token lint.
6. Staging web-build verification (path URLs, anon published vs draft, alias redirect, head inspection) → handoff to EP-03-20.

### 18. Expected Outcome

Published listings and industry browses are stable, shareable, indexable web URLs reusing the proven discovery/detail/profile stack; each serves correct title/description/canonical/`og:image` on web with zero new backend surface, zero private-data leakage, and full responsive/theme compliance — closing the EP-03-09 "canonical meta ships in EP-03-19" debt and unblocking EP-03-20 validation.

### 19. Definition of Done

- [ ] `/s/:slug/:id` unauth renders `published`, same-URL `HivorrEmptyState` for draft/unknown (`PLT004`, no id echo); slug cosmetic, id authoritative.
- [ ] `/s/:industrySlug` renders filtered browse; unknown slug → `HivorrEmptyState` + browse-all action.
- [ ] `/c/:slug/:id` single-hop redirects to `/p/:slug/:id` preserving encoding; no duplicate screen.
- [ ] Listing/browse/profile heads set `title`, `description≤160`, `canonical`, `og:*` on web; `og:image` falls back to brand logo; no `legal_name`/PII in meta.
- [ ] Static shell: `index.html` meta/`og:`/`twitter:`/`theme-color`, `manifest.json` description + brand colors, `robots.txt` + `sitemap.xml` present and correct.
- [ ] Guards: anon public shapes pass, owner/contract/dashboard/admin shapes still fail-closed with `?next=`; dispatcher allowlist updated.
- [ ] No new tables/RPCs/buckets; posture audit confirms anon `published`-only; `dart analyze` + `flutter test` green; zero `Colors.*`/hex/`fontFamily` in touched widgets; `usePathUrlStrategy` path URLs confirmed on web build.
- [ ] Tests added/extended per §16; EP-03-20E2E deferred items explicitly listed.

### 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: High** (matches approved EP-03-19 `High/High`).
- **Justification:** No financial state machine, ranking math, or crypto is introduced (rules out Very/Extremely High), but the task is integration-sensitive: GoRouter order/shadowing (`/s/:slug/:id` vs `/s/:industrySlug`), public-vs-private RLS boundary with `PLT004` indistinguishability, SPA-SEO head management via JS interop, canonical/alias redirect correctness, and cross-cutting guard/dispatcher/test updates. `High` provides the rigor for routing + privacy + SEO correctness without the exhaustive ledger-grade matrices reserved for EP-03-01/02/06/11.

---
*Planning artifact only. No production code written, no Phase doc modified. Awaiting your approval before proceeding to implementation (requires switching out of Plan mode to a build agent).*
