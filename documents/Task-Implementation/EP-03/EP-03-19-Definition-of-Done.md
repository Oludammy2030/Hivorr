# EP-03-19 — Public Listing Routes & SEO Discoverability — Definition of Done

## 1. Task Identification

- **Task ID:** EP-03-19
- **Task Name:** Public Listing Routes & SEO Discoverability
- **Related Phase:** EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 3 (Service Listing & Discovery: after EP-03-08 listing CRUD + EP-03-09 ranked discovery, before transaction core)
- **Reference Implementation Plan:** `documents/Task-Implementation/EP-03/EP-03-19 Public Listing Routes & SEO Discoverability.md` (single source of truth; this DoD does not modify it)
- **Approved Dependencies:** EP-03-08 (listing management), EP-01-15 (router / `go_router` + `pathUrlStrategy`), EP-02-19 (portfolio SEO pattern `/p/:slug/:id` + `PortfolioSeoMeta`)
- **DoD Type:** Standalone task verification checklist for project-lead review and approval

## 2. Functional Verification

Verify each behavior on a web build with clean path URLs (no `#/`). All checks use existing screens — no duplicate screens are acceptable.

### 2.1 Required functionality

- [ ] FV-01 — Anon `GET /s/:profession_slug/:service_id` with `published` listing renders `ServiceDetailScreen` (header, pricing, `TradeVerifiedBadge`, rating aggregate, media carousel in server order, portfolio proof section, `Book/Request Proposal` CTA).
- [ ] FV-02 — Anon `GET /services` renders ranked browse; anon `GET /services/search?q=&profession=` renders filtered search; anon `GET /services/:id` (`published`) renders detail. No login wall for `published`.
- [ ] FV-03 — Anon `GET /s/:industrySlug` renders industry-filtered browse reusing `MarketplaceDiscoveryScreen` stack (chips reflect the industry filter, ranked `service_ranking_search` order verbatim, keyset pagination works).
- [ ] FV-04 — `GET /c/:slug/:id` performs a single-hop redirect to canonical `/p/:slug/:id` preserving URL-encoding and query params, then renders `ProfessionalProfileScreen`. No second profile screen exists.
- [ ] FV-05 — Listing head on web sets `document.title`, `meta[name=description]`, `link[rel=canonical]`, `og:title/description/image/url/type` from `ListingSeoMeta` (`title = '{title} · {professionName}'`, `description ≤160`, canonical `{origin}/s/{professionSlug}/{id}`, `og:image` = cover public URL else brand `logo_icon.png` fallback).
- [ ] FV-06 — Browse head on web sets `title = '{Industry} services on Hivorr'`, matching `description ≤160` and canonical `/s/{industrySlug}`.
- [ ] FV-07 — Profile head on web sets title/description/canonical from existing `seoMeta` (retrofit verified — display name visible in head, not generic `'Profile'` only).
- [ ] FV-08 — Static shell hardened: `web/index.html` contains description + `og:site_name/type` + `twitter:card` + `theme-color #2D3FE7`; `web/manifest.json` description fixed (no `"A new Flutter project."`) and `theme_color/background_color` match brand tokens; `web/robots.txt` and `web/sitemap.xml` present and well-formed.

### 2.2 Expected workflows

- [ ] WF-01 — Share flow: copy `/s/plumber/<published-id>` → paste into fresh anon web session → detail renders without login → `Book/Request Proposal` tap → `?next=` login resume → post-auth returns to same listing.
- [ ] WF-02 — Share flow: copy `/s/technology` → anon session renders technology-filtered browse → selecting a card lands on `/s/:slug/:id` with correct canonical.
- [ ] WF-03 — Alias flow: open `/c/electrician/<entity-id>` → lands on `/p/electrician/<entity-id>` in one hop → back-button and deep-link cold-start both resolve to the canonical profile.
- [ ] WF-04 — Slug-typo flow: open `/s/wrong-slug/<published-id>` → detail still renders (slug cosmetic) with canonical pointing at RPC-derived `professionSlug`, no redirect chain.

### 2.3 Success conditions

- [ ] SC-01 — `:id` is authoritative everywhere; `:slug`/`:industrySlug` are cosmetic/validating only and never gate data access.
- [ ] SC-02 — Route registration order verified: `/s/:slug/:id` (2-segment) matched before `/s/:industrySlug` (1-segment); no shadowing (2-seg URL never renders browse).
- [ ] SC-03 — No new screens introduced for `/s/:industrySlug` or `/c/:slug/:id`; wrappers/redirects over `MarketplaceDiscoveryScreen` and `ProfessionalProfileScreen` only.
- [ ] SC-04 — Ranking order on `/s/:industrySlug` and search matches `service_ranking_search` payload verbatim (no client re-sort).

### 2.4 Error handling scenarios

- [ ] EH-01 — Anon `GET /s/:slug/:draft-id` renders same-URL SEO-404 (`HivorrEmptyState`), not a login redirect leak and not a crash. Same for unknown id.
- [ ] EH-02 — `GET /s/<unknown-industry>` renders same-URL `HivorrEmptyState` + `Browse all services` action; no redirect loop, no 500.
- [ ] EH-03 — Unknown `/c/:slug/:unknown-id` redirects to canonical shape then profile shows its existing SEO-404 (`_ProfileNotFoundView`-equivalent), same URL, no id/`legal_name` echo.
- [ ] EH-04 — Offline/broken-network on public routes shows `HivorrErrorState` with retry; cached taxonomy browse degrades gracefully where applicable.
- [ ] EH-05 — Head-update JS unavailable (non-web or blocked interop) leaves the valid static shell; no exception surfaces to the user.

### 2.5 Important user interactions

- [ ] UI-01 — Self-listing CTA remains disabled with guidance; anon CTA preserves `?next=` intent.
- [ ] UI-02 — Filter chips on `/s/:industrySlug` reflect the URL filter; clearing the filter returns to unfiltered browse without breaking the back stack.
- [ ] UI-03 — Favorite toggle, media carousel swipe, proof-section expand, and auth-bounce flows behave identically on `/services/:id` and `/s/:slug/:id`.
- [ ] UI-04 — Copy uses verification-safe language (`Trade Verified`, `Identity Verified`); no RLS/RPC codes (`PLT004`, etc.) are user-visible; `PLT004` surfaces as friendly not-found.

## 3. Technical Verification

- [ ] TV-01 — Architecture compliance: changes confined to `lib/app/router/*`, `lib/engine/growth_engine/` SEO seam (`listing_seo_meta.dart`, head seam), head mounts in the three existing screens, `notification_tap_dispatcher.dart` allowlist, and `web/*` static files. No top-level `lib/` directory added outside `ARCHITECTURE.md` schema; no `marketplace/seo/` parallel silo.
- [ ] TV-02 — Router delta is thin: exactly `serviceSeoBrowseRoute = '/s/:industrySlug'` + `serviceSeoBrowse()` and `profileAliasRoute = '/c/:slug/:id'` + `profileAlias()` added to `route_paths.dart` / `route_names.dart`; `app_router.dart` order is 2-seg before 1-seg; `/c/` uses `redirect`, never a builder.
- [ ] TV-03 — Guard delta is thin: `RouteGuard._isPublicContentView` covers `/s/<single>` and `/c/`; `AuthGuard` logic untouched; owner (`/services/mine*`), `/contracts/*`, `/dashboard/*`, `/admin/*`, `/finance/*`, `/support/*` remain fail-closed with `?next=` resume.
- [ ] TV-04 — SEO seam is reusable and web-guarded: `ListingSeoMeta`/`ListingSeoMetaBuilder` mirrors `PortfolioSeoMetaBuilder` conventions (RPC slug wins, route slug fallback, trailing-slash-tolerant `seoBaseUrl` injection, `truncate(160)`); `SeoHead`/`SeoService` uses `package:web` interop behind `kIsWeb` and is a no-op on mobile/desktop. No new pub dependency added.
- [ ] TV-05 — Module integration: `TaxonomyEngine` + cached industries validate `industrySlug`; `ServiceListingService.getListing` / `service_listing_get` serve detail + head; `service_ranking_search` serves browse; `portfolio_public_profile_get` serves alias target; `service_listing_portfolio_list` feeds proof carousel. No forked data path.
- [ ] TV-06 — Visual identity (AGENT.md Rule 5): all touched widgets consume `ColorScheme` / `AppThemeExtension` + `TextTheme`; brand mark from `assets/images/logo*.svg`; `grep` for `Colors.*`, raw hex, and per-widget `fontFamily` in touched files returns zero hits; CTAs ≥48dp; `HivorrContentPane` / responsive scaffold / `MobileSafeBody` conventions preserved.
- [ ] TV-07 — Separation of concerns + server enforcement (AGENT.md Rules 1/4/6): zero pricing, ranking, escrow, or verification-decision logic added client-side; AI layer does not reorder results; no `Both` account concept introduced; deterministic-core ordering untouched.
- [ ] TV-08 — `usePathUrlStrategy` path URLs confirmed on `flutter build web` (no hash fragments on public routes); cold-start deep-links resolve to the correct route.

## 4. Data Verification

No migration is expected (amended by §10 for `service_ranking_search`). Verify reuse and integrity of existing data contracts.

- [ ] DV-01 — No new tables, columns, buckets, or RPCs were created for this task (schema diff vs EP-03-01 baseline is empty for this task's scope).
- [ ] DV-02 — `ServiceListing` fields used for SEO (`id`, `slug`, `title` 10–120, `description` 50–5000, `professionSlug/Name`, `industrySlug/Name`) match RPC payloads; canonical prefers RPC `professionSlug`, then route slug, then listing slug — verified across at least one listing per case.
- [ ] DV-03 — `og:image` resolves to a `published`-visible `service_listing_media` public URL when present, else absolute brand-logo fallback; no signed/private URLs appear in meta (inspect head on a listing with and without media).
- [ ] DV-04 — Canonical origin uses injected `seoBaseUrl` (env per ENV-006); no hardcoded prod origin in widgets; empty origin yields correct relative canonical (portfolio parity).
- [ ] DV-05 — Data accuracy: head title/description for at least 3 sampled listings match their `published` RPC rows character-for-character (modulo 160-char truncation); browse head matches the taxonomy industry name.
- [ ] DV-06 — Data integrity: draft edits do not leak into public meta; unpublishing a listing flips its anon route back to SEO-404 without stale head persisting after navigation.

## 5. Security Verification

- [ ] SV-01 — Authentication: anon can read `published` via `service_listing_get` / `service_ranking_search` / `service_listing_portfolio_list` only; all write and owner/private reads still require auth (spot-check `/services/mine`, `/contracts/:id`, `/finance/earnings` redirect to login with `?next=`).
- [ ] SV-02 — Authorization / RLS: anon `service_listing_get(draft-id)` returns identical `PLT004` as unknown id (no oracle); anon search returns `published`-only; media for unpublished parents is not reachable; posture-audit-style check extended and green (amended by §10: the anon browse defect found here was fixed in-PR by product-lead decision rather than routed to EP-03-01).
- [ ] SV-03 — Access control: `robots.txt` allows `/services`, `/s/`, `/p/` (+ existing public info doors) and disallows `/services/mine`, `/contracts`, `/dashboard`, `/admin`, `/finance`, `/support`; drafts/unknown render not-found with no self-promoting canonical.
- [ ] SV-04 — Sensitive data protection: meta, canonicals, `og:` payloads, and share URLs contain no `legal_name`, `document_path`, contact details, escrow amounts, or viewer `entity_id`; page source / head inspection on detail, browse, and alias confirms this.
- [ ] SV-05 — Open-redirect safety: `/c/` redirect target is the allowlisted canonical `/p/:slug/:id` only; query passthrough is URL-encoded; `NotificationTapDispatcher.isAllowedRoute` covers the new public shapes and still drops non-allowlisted routes (malformed payload → log + drop, verified by unit test).

## 6. Performance Verification

- [ ] PV-01 — Browse `/s/:industrySlug` paginates via existing keyset `(score,id)`; no unbounded fetch (network inspector shows paged `service_ranking_search` calls).
- [ ] PV-02 — Detail performs at most one `getListing` + one portfolio-proof list per open (no N+1); `initialListing` extra still instant-paints; head update is a single O(1) DOM write per navigation.
- [ ] PV-03 — Cached taxonomy + `ServiceSearchIndex.warmBrowse()` + `LruCache` path reused for industry browse; repeat visit does not refetch taxonomy unnecessarily.
- [ ] PV-04 — No performance regression vs EP-03-09 baseline: filtered search remains within the EP-03-20 staging gate trajectory (p95 <400ms is measured at EP-03-20; this task records timings but does not re-benchmark production); Realtime paths unaffected; no new index required (`EXPLAIN` still shows existing GIN usage — informational only).

## 7. Testing Verification

### 7.1 Automated testing requirements

- [ ] AT-01 — Unit: `ListingSeoMetaBuilder` group green — title composition + fallback, 160-char truncation + fallback copy, canonical precedence (RPC slug > route slug > id), `logo_icon.png` fallback, trailing-slash origin handling, `legal_name`-absence assertion; `route_paths` builder encoding tests; `SeoService` non-web no-op test.
- [ ] AT-02 — Widget: `SeoHead` fake-head-adapter test green (title/meta/canonical/`og:` written); detail mounts listing meta; browse mounts industry meta; alias test asserts redirect and that no duplicate screen builds; `HivorrEmptyState` shown for draft-anon / unknown-id / unknown-industry; theme-token assertion passes.
- [ ] AT-03 — Router/guard: extended `route_guard_test.dart` + `route_paths_test.dart` green — anon `/s/<industry>` → public (null redirect), anon `/s/<slug>/<published-uuid>` → public, anon `/s/<slug>/<draft-uuid>` → not-found (not login leak), anon `/c/<slug>/<id>` → `/p/<slug>/<id>`, owner `/services/mine*` → `/login?next=`, 2-seg-before-1-seg order test, `doorRouter` harness covers `/services*` + `/s/*` + `/c/*`.
- [ ] AT-04 — Integration: web cold-start deep-link test green — path URLs (not hash), anon `service_listing_get` published-ok / draft-`PLT004`, `/s/:industrySlug` order matches RPC verbatim; `flutter build web` smoke passes.
- [ ] AT-05 — Static: `dart analyze` clean; `flutter test` (touched suites + full affected modules) green; static-file checks green (`index.html` description/`og:`/`twitter:`/`theme-color`, `manifest.json` description + brand colors, `robots.txt` allow/disallow lines, `sitemap.xml` well-formed).
- [ ] AT-06 — Negative/leakage matrix extended from messaging to listings: non-owner anon draft fetch, non-`published` media fetch, and dispatcher non-allowlist drop cases all covered and passing.

### 7.2 Manual testing requirements

- [ ] MT-01 — Fresh anon Chrome (web build): open `/s/:slug/:id` (published), `/s/:industrySlug`, `/c/:slug/:id`, `/services`, `/services/search?q=test`, `/services/:id`; confirm rendering, head values (DevTools Elements), and canonicals match §2.
- [ ] MT-02 — Draft/unknown drill: open draft `/s/:slug/:id`, unknown id, unknown industry, unknown `/c/` id; confirm same-URL `HivorrEmptyState`, no id echo, no redirect loop.
- [ ] MT-03 — Mobile (Android/iOS) + desktop widths: responsive breakpoints (600/1024), 1120 detail cap, `ContentPane` profile, no overflow; back/forward preserves route and head.
- [ ] MT-04 — View-source check: no `legal_name`, document paths, escrow values, or contact PII in served HTML/head for any public route.

### 7.3 Edge cases and failure scenarios

- [ ] EC-01 — Slug with uppercase/spaces/unicode → builders encode, route still resolves by id, canonical uses RPC slug.
- [ ] EC-02 — Listing without media/profession name → fallbacks used (logo image, title-only, generic description) with no crash.
- [ ] EC-03 — `seoBaseUrl` empty vs trailing-slash vs prod origin → canonicals correct in all three configs.
- [ ] EC-04 — Rapid navigation browse → detail → browse updates head exactly once per route (no stale meta).
- [ ] EC-05 — `robots.txt`/`sitemap.xml` served with correct content-type on the hosting target; private families remain disallowed after deploy.

## 8. User Acceptance Verification

Real-world checks with a project-lead walkthrough on staging web (anon window + one authenticated window):

- [ ] UA-01 — A non-technical reviewer can open a shared `/s/` link with no account and understand the service, professional, price, rating, and proof without encountering a login wall or technical error string.
- [ ] UA-02 — Sharing `/s/technology` (or another seeded industry) shows a recognizably filtered, ranked list; opening any card preserves the industry context in the canonical and chips.
- [ ] UA-03 — Opening an old `/c/` link from existing collateral lands on the correct live profile in one hop; no dead-end or duplicate profile is observed.
- [ ] UA-04 — Social-share preview (link unfurl) for a `published` listing shows the listing title, ≤160-char description, and brand/listing image — never a generic app title alone and never private data.
- [ ] UA-05 — Draft listings shared accidentally show a clean not-found state to outsiders and remain fully visible to the owner after login.

## 9. Final Approval Checklist

The task may be marked Completed only when all of the following hold:

- [ ] FA-01 — All Functional (§2), Technical (§3), Data (§4), Security (§5), Performance (§6), Testing (§7), and User Acceptance (§8) boxes above are checked with evidence (test run IDs / staging URLs / screenshots / head dumps linked in the review).
- [ ] FA-02 — No out-of-scope delivery exists: zero new tables/columns/RPCs/RLS/buckets/ranking changes/SSR/admin expansion; diff review confirms thin router + SEO-seam + screen mounts + `web/*` only (amended by §10: one product-lead-approved `service_ranking_search` security-mode change, no new object).
- [ ] FA-03 — Reuse-first honored: no duplicate detail/browse/profile screens, no `marketplace/seo/` silo, `PortfolioSeoMeta` untouched, growth-engine seam reused by design and documented for EP-04 product/store reuse.
- [ ] FA-04 — `web/index.html`, `web/manifest.json`, `web/robots.txt`, `web/sitemap.xml` reviewed and correct; `flutter build web` + `dart analyze` + `flutter test` (affected + full) green on the approval commit.
- [ ] FA-05 — EP-03-09 canonical-meta debt explicitly closed; any EP-03-20-deferred items (live crawl, p95 benchmark, goldens) are listed by name with owners — no silent carryover.
- [ ] FA-06 — Project lead has signed each section in the review record; the approved implementation plan remains unmodified and this DoD is stored alongside it as its verification companion.

## 10. Post-Verification Scope Amendment — Anon Browse Corrective (2026-10-17)

Recorded, product-lead-approved deviation from this plan's "no migration / no
ranking changes" posture (§4 note, SV-02, FA-02).

**Finding.** During the SV-02 anon posture work
(`supabase/tests/database/056_service_listing_seo_posture.sql`),
`service_ranking_search` failed for the anonymous role:
`ERROR: permission denied for table entity_kyc_levels`. The RPC is granted to
`anon` (`20260927090001:540`) and its body even carries `current_user = 'anon'`
error branches, but it was declared `SECURITY INVOKER` while reading `entities`,
`entity_kyc_levels` and `service_contracts` — tables anon has no SELECT grant on
(`revoke all … from anon` at `20260819090001:18`). The same self-scoped RLS
policies also silently zeroed `w_verify`/`w_completion` for every authenticated
caller; the pgTAP suites ran as `postgres` (table owner → RLS bypassed), which is
why the defect was previously invisible.

**Impact.** Anonymous marketplace browse/search — behind `/services`,
`/services/search` and the EP-03-19 route `/s/:industrySlug` (FV-02, FV-03,
WF-02, SV-01) — failed at the database for logged-out visitors, defeating the
task's anonymous discoverability goal.

**Approved resolution.** Fix in this PR (product-lead decision): promote the RPC
to `SECURITY DEFINER` with a pinned `search_path = pg_catalog, public`, mirroring
`portfolio_public_profile_get`. No new table/column/RPC/policy/grant is added —
only the RPC's security mode changes. Safety: the body hard-filters
`status = 'published'` and projects only whitelisted public fields; kyc tier,
`last_seen_at` and contract completion are read solely to compute scores and are
never returned. The error contract is unchanged (`platform_raise_error` formats
identically to the inline anon raises).

**Artifacts.**
- `supabase/migrations/20261017090001_service_ranking_search_anon_definer.sql`
- Posture counts updated 5→6 in `023_service_marketplace_schema_posture.sql` and
  `033_platform_config_posture.sql`; mode note refreshed in
  `034_service_ranking_rpc_enforcement.sql`; `056` strengthened with a positive
  anon ranking assertion.

**Effect on this DoD.**
- §4 "No migration is expected" and DV-01/DV-02: superseded by this amendment for
  `service_ranking_search` only; no other schema object changes.
- SV-02: the "routed to EP-03-01, not patched here" clause is amended to "fixed
  here by product-lead decision"; the posture extension is green in CI.
- FA-02: "zero … ranking changes" is amended for this single RPC mode change.
- The EP-03-01 follow-up for the anon browse defect is no longer required.

*Verification companion to the approved EP-03-19 implementation plan. It creates no new requirements and redesigns nothing — unchecked boxes block approval.*
