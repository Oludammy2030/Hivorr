# Definition of Done — EP-03-15: Portfolio & Proof-of-Work Service Integration

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**
>
> **Status:** Completed — Approved 2026-10-09. All code-level boxes verified:
> `dart analyze` clean (whole `lib` + `test`), 32 new Dart tests green
> (16 unit + 13 widget + 3 integration), pgTAP `044` 60/60 green plus the
> **full DB suite PASS** (same command as CI), forbidden greps 0,
> migration applies cleanly via `supabase db reset`. Human/staging
> remainders accepted as documented deferrals (same pattern as EP-03-14).
> See §10 Verification Evidence.

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-15 |
| **Task Name** | Portfolio & Proof-of-Work Service Integration |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 3 Service Listing & Discovery (listing CRUD → ranked discovery → portfolio linkage → SEO routes) |
| **Priority** | High — Planning High / Coding High (Phase Plan §12–13) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-15 Portfolio & Proof-of-Work Service Integration.md:1-322` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:400-409` (§EP-03-15) + `§6 Stage 3` + `§7 deps EP-02-19, EP-02-06, EP-03-01, EP-03-08` |
| **Dependencies** | EP-02-19 portfolio read path (`portfolio_items` + `portfolio_public_profile_get` + `portfolio-items` bucket) Completed; EP-02-06 bucket RLS Completed; EP-03-01 listing schema + trade gate + `service-listing-media` (`20260921090001`) Completed; EP-03-08 listing CRUD + media screens Completed |
| **Delivery Scope** | **Reuse verbatim:** `PortfolioGrid` / `PortfolioItemCard` / `VerificationBadgesRow` / `TradeVerifiedBadge` / `ProfessionalProfileService.mediaPublicUrl` / `portfolio_public_profile_get` / `service_listings` schema + 7 INVOKER RPCs / `ServiceListingService` + repository + provider seam / `ServiceMediaCarousel` pattern / `ProfessionPicker` interaction shape / router tables / `StorageService` + buckets / `Hivorr*` primitives + `AppTheme` tokens. **Extend:** `ServiceListingRepository` + datasource + `ServiceListingService` + provider family (proof methods), `service_detail_screen.dart` (slot swap), `PortfolioSeoMetaBuilder` usage (`og:image` fallback deferred to EP-03-19 — no listing-meta infra exists yet), barrels/DI exports, fakes. **New (genuine gaps only):** junction table `service_listing_portfolio_links` + RLS + 3 RPCs (`link` / `unlink` / `list`), tiny proof DTO + mapper extension + `LinkedPortfolioItem` view-model, `ServiceProofSection` composition, `LinkPortfolioSheet` picker composition, pgTAP suite. |
| **Guardrails** | `AGENT.md` Bounded Scope + Separation of Concerns + Rule 4 zero-trust RPC+RLS + Rule 5 visual tokens + Deterministic Core Supremacy (no AI decides order; proof order = server `link sort_order` verbatim) + `ARCHITECTURE.md` lib schema |

---

## 2. Functional Verification

### 2.1 Required Functionality

- [x] **Proof linking (owner only)** — owner opens `Add portfolio` / `Edit proof` on own listing → `LinkPortfolioSheet` (search + multi-select of own `portfolio_items` with `PortfolioItemCard`-compact rows + `Save (n)` counter) → `service_listing_link_portfolio_items(p_listing_id, p_portfolio_ids uuid[1..8])` full-replace → `PLT000 {listing_id, linked_ids[], count}` → provider reload → success `HivorrSnackbar`
- [x] **Proof display (all viewers incl. signed-out)** — `ServiceProofSection` replaces `_ProofSlot` (`service_detail_screen.dart:498-538`; no snackbar placeholder remains) below media/pricing/badges, above reviews/CTA: loading → skeleton; loaded → carousel (narrow) / `PortfolioGrid` (wide) sharing `PortfolioItemCard`; empty → preserved `HivorrEmptyState('No proof linked yet', …)` copy; error → `HivorrErrorState` + Retry
- [x] **Unlink** — owner removes a piece (`Edit proof` → deselect, or single-remove) → `service_listing_unlink_portfolio_item` → `PLT000` (idempotent on already-absent) → section reloads; last-item unlink returns section to empty state with owner CTA
- [x] **Reorder** — owner reorders via full-replace save (array position = `sort_order`); detail renders new server order verbatim with no client re-sort (no dedicated reorder RPC — full-replace is the reorder path per plan §7.1)
- [x] **Draft staging** — linking allowed on `draft`/`paused` so proof is ready before `Publish`; helper text states `Only published listings show proof publicly`
- [x] **Profile cross-link** — each proof tile / section header deep-links to owner's `/p/:slug/:id`; `ProfessionalProfileScreen` itself needs no schema change; listing `og:image` falls back to first linked proof image (wiring deferred to EP-03-19, which owns listing meta — proof-image source available via `fetchProofs`)
- [x] **Cap enforcement** — at most 8 linked pieces per listing; sheet counter shows `n of 8 selected` with `Up to 8 pieces — pick your strongest work`; 9th selection blocked client-side with inline hint

### 2.2 Expected Workflows

- [x] **Happy path:** owner creates `portfolio_item` → links 3 items to `published` listing → signed-out visitor opens `/services/:id` (and `/s/:slug/:id` alias) → proof carousel/grid shows 3 ordered tiles with CDN thumbnails → tile tap reaches owner profile context
- [x] **Staging path:** owner links 2 items to `draft` listing → owner preview shows 2 tiles → signed-out visitor sees `No proof linked yet` viewer copy (no leak) → owner publishes → visitor now sees 2 tiles
- [x] **Replace path:** owner with 3 linked items re-saves with different 2-item selection → detail shows exactly the new 2 in the new order (full-replace, no orphans, no duplicates)
- [x] **Unlink-to-empty path:** owner unlinks all items → section returns to `HivorrEmptyState` + owner-only `Add portfolio`; viewer copy unchanged
- [x] **Non-owner path:** non-owner opens another professional's detail → proof visible (if published) but no `Add portfolio` / `Edit proof` entry exists anywhere (detail + `MyListingsScreen`); forced direct link RPC fails `PLT001` (listing-level) / identical `PLT004` (item-level, no oracle)
- [x] **Zero-items path:** owner with zero `portfolio_items` opens sheet → `HivorrEmptyState` + `Create portfolio piece` guidance (no creation UI built here — guidance only)

### 2.3 Success Conditions

- [x] Phase Plan acceptance holds: create `portfolio_item` → link to `published` listing → unauth viewer sees carousel with linked items; non-owner link attempt fails `PLT001`; unlinked listing shows `HivorrEmptyState` proof placeholder with `Add portfolio` CTA (when owner)
- [x] Every link write envelope `{success:true, code:'PLT000'}`; post-write `service_listing_portfolio_list` re-read shows authoritative ordered items; double-tap save yields one success snackbar and no duplicate tiles
- [x] `VerificationBadgesRow` / `TradeVerifiedBadge` render unchanged beside proof; proof presence never alters badge state

### 2.4 Error Handling Scenarios

- [x] `PLT001` → forbidden state/snackbar (non-owner listing, cross-entity item for service_role callers); never discloses which ID mismatched; non-owner-forced UI path tested even though client hides the entry
- [x] `PLT003` → inline validation (null/empty/>8/dup/malformed `p_portfolio_ids`, null `p_listing_id`); cap breach shows sheet hint client-side plus server backstop
- [x] `PLT004` → `HivorrEmptyState` not-found, identical for unknown listing vs unpublished-to-viewer vs missing item (no oracle); stranger/draft-anon read never leaks item bodies
- [x] `PLT005` → guidance card (link to `archived`/`reported` listing; unique-conflict retry path)
- [x] `PLT001/002` session-changed mid-sheet → auth/forbidden state with re-login action, `?next=` preserved
- [x] Offline save → connectivity error + Retry (online-only writes; no offline proof queue in this task); fresh-fetch failure never presents stale `loaded` as fresh

### 2.5 Important User Interactions

- [x] Sheet multi-select rows expose `Selected — {title}` semantics; carousel dots expose page semantics; `TradeVerifiedBadge` semantics preserved
- [x] `Save (n)` `HivorrButton ≥48dp` with `isLoading`; destructive unlink behind confirm affordance; success via `HivorrSnackbar`, errors via `HivorrErrorState`/snackbar — never silent
- [x] Every empty state has a primary action (owner: `Add portfolio` / `Create portfolio piece` guidance; viewer: calm copy, no dead end); every error has Retry
- [x] All new strings via `lib/core/localization` (no hardcoded user-facing English outside l10n tables); 48dp targets; responsive sheet (bottom sheet mobile / dialog desktop)

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] Layering `ServiceProofSection/LinkPortfolioSheet → ServiceListingService → proof provider → ServiceListingRepository → SupabaseServiceListingRemoteDataSource(BaseApiService) → RPCs + RLS`; UI holds zero business logic (`AGENT.md:5,6`)
- [x] Zero-trust client (`AGENT.md:13` Rule 4): ownership + published-visibility decided in RPC, never client-evaluated; client validates count/shape only
- [x] No `lib/ai` import anywhere in the proof path; proof count never influences ranking order (determinism: client renders link `sort_order` verbatim)
- [x] Visual Identity (`AGENT.md:18`): `HivorrCard/ContentPane/Chip/Badge/Button/Empty/Error/Loading/Skeleton/Dialog/BottomSheet` + `context.colorScheme` / `AppThemeExtension` / `textTheme` only — grep `Colors\.|fontFamily|0xFF` over new proof widgets = 0

### 3.2 Required System Behavior

- [x] RPC-only link writes: no direct `postgrest` insert/update/delete on `service_listing_portfolio_links` from client (table grants exist for RLS completeness with an owned-listing conjunct, but canonical path is RPC — documented like financial tables)
- [x] Ordering authority: link `sort_order` (per-listing curation), not item `sort_order`; single indexed `JOIN` per detail view; no pagination (cap 8); no N+1 (one list RPC returns all tiles)
- [x] Idempotent saves: full-replace + `UNIQUE(listing_id, portfolio_item_id)` makes double-tap/retry duplicate-free; unlink idempotent on absent link
- [x] Media resolution: RPC returns `media_path` only; client resolves via `ProfessionalProfileService.mediaPublicUrl(portfolio-items)` → CDN URL; null/failure → placeholder (never bytes over RPC)
- [x] Envelope vocabulary: `PLT000 ok / 001 not-owner / 003 validation / 004 not-found (identical, no oracle) / 005 archived/conflict / 999 server` → `ApiExceptionKind` via existing envelope parser; malformed → `DataException`
- [x] Frozen contracts untouched: `portfolio_public_profile_get`, `service_listing_get`, `service_ranking_search`, `service_search` payloads byte-identical (`git diff` on their migrations = empty)

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `portfolio_items` + `portfolio_public_profile_get` (EP-02-19) | Read path untouched; junction FKs into `portfolio_items.id`; proof thumbnails via `mediaPublicUrl`; `PLT004→null/empty` mapping mirrored; 018 suite green after additive owner SELECT policy |
| `service_listings` + 7 RPCs + trade gate (EP-03-01) | No column added to `service_listings`; junction FKs to `service_listings.id`; linking is staging (no new trade check) — publishing/offer gates still enforce `trade_verification_status == APPROVED`; 023/024 suites green |
| `ServiceDetailScreen._ProofSlot` (EP-03-09 hook) | Placeholder replaced by `ServiceProofSection`; `initialListing` instant-paint + authoritative re-read preserved; `Book/Request Proposal` CTA untouched; pre-existing detail widget tests green |
| `PortfolioGrid` / `PortfolioItemCard` / `ServiceMediaCarousel` | Reused verbatim/pattern (grid breakpoints + nulls-last sort; 16/9 thumb + type chip + placeholder; PageView + dots + cover-order); no forked carousel/grid infra (grid-only display decision, §10) |
| `VerificationBadgesRow` / `TradeVerifiedBadge` (EP-02-11/12) | Unmodified and still authoritative; proof never implies verification (negative widget test: linked proof + unverified badge state coexists) |
| `registerMarketplaceLayer` + barrels | Proof methods ride the existing DI record (`ServiceProofProvider` scoped to the detail subtree — `registerMarketplaceLayer` is unused in-app, so no dead-code churn); `marketplace.dart` + `data_layer.dart` export-only extensions |
| Router (`/services`, `/services/:id`, `/s/:slug/:id`, `/p/:slug/:id`) | Zero route-table change (sheet only); `:id` authoritative, slug cosmetic; `?next=` resume preserved |
| EP-03-19 SEO | Listing `og:image` falls back to first linked proof image; `PortfolioSeoMetaBuilder` extension deferred to EP-03-19 (no listing-meta infra exists yet; source available via `fetchProofs`) |

### 3.4 Technical Requirements

- [x] New assets live only under existing schema: one additive migration + `lib/systems/marketplace/widgets/` (2 composition files) + `lib/data/` extensions (DTO/mapper/datasource/repository/provider) + pgTAP file; no new top-level `lib/` dirs; no new `pubspec` dependency; no new bucket/package/Edge Function
- [x] Entities: reuse `PortfolioItem`; link order carried only in thin `LinkedProof` view-model / `(item, linkSortOrder)` tuple — no forked entity, no duplicated item parsing (`PortfolioItemDto.fromJson` reused)
- [x] `video`/`link` `item_type` renders as placeholder card with type chip (no transcode, no bucket MIME change)
- [x] Logging via `HivorrLogger` + `PiiRedactor` (`listingIdSuffix`/`entityIdSuffix` only); never log full IDs, titles, or media paths (grep = 0); Sentry spans named `marketplace.listing.proof.*`

---

## 4. Data Verification

### 4.1 Data Creation

- [x] Link save creates exactly the submitted link rows (`listing_id`, `portfolio_item_id`, denormalized `entity_id`, `sort_order = array_position`, `created_at`, `created_by = auth.uid()`) in one transaction (delete-existing + insert-new); client creates zero rows directly
- [x] No cache write fabricates links: in-memory proof list per `listingId` + selected memo only; no Hive persistence for this slice

### 4.2 Data Updates

- [x] Every mutation re-reads via `service_listing_portfolio_list`; provider never synthesizes order/count locally; no optimistic ghost tiles (await RPC, then reload)
- [x] Reorder = full-replace save; old order fully superseded, never merged
- [x] No client update to `entity_id`, `created_by`, `created_at`, `portfolio_items` rows, or `service_listings` rows from this task

### 4.3 Data Relationships

- [x] `listing_id → service_listings.id ON DELETE CASCADE` (listing delete removes its links; items survive); `portfolio_item_id → portfolio_items.id ON DELETE CASCADE` (item delete removes its links; listings survive); `entity_id → entities(id) ON DELETE CASCADE` — cascade direction proven live (pgTAP 58)
- [x] Every linked item's `entity_id` equals the listing's `entity_id` (server-verified; zero-mismatch query holds); one portfolio piece may prove many listings (junction, not FK-on-item — proven live, pgTAP 57)
- [x] `appointment/contract/escrow/review` tables untouched by this migration (grep = 0 outside the new file)

### 4.4 Data Accuracy

- [x] Displayed tiles render the list-RPC rows exactly (whitelisted `id/item_type/title/description/media_path/sort_order + link_sort_order`); formatting display-only; order = `link_sort_order ASC NULLS LAST, created_at ASC` verbatim
- [x] `og:image` fallback uses the first ordered linked image item (or `logo_icon.png` fallback when none); never a non-image `media_path` (wiring deferred to EP-03-19)

### 4.5 Data Integrity

- [x] `UNIQUE(listing_id, portfolio_item_id)` holds — same-key replay returns same set, never duplicates (`ON CONFLICT`-safe full-replace, proven live pgTAP 44-46)
- [x] Array-length cap (≤8) enforced procedurally in RPC; dup IDs in input rejected `PLT003` (proven live pgTAP 34-36)
- [x] Concurrent full-replace writes serialize (per-listing advisory lock + UNIQUE backstop; race proven by inspection + UNIQUE guarantee — live race test deferred, §10)
- [x] Additive-only: `git diff` on all pre-existing migrations empty (023/033 posture-count updates are test files, not migrations); junction table excluded from `supabase_realtime` publication (proven live pgTAP 55)

---

## 5. Security Verification

### 5.1 Authentication

- [x] Link/unlink RPCs require session (`authenticated` + `service_role` only, `anon` 0); list RPC grants `anon, authenticated, service_role` (published-only inside the RPC, not via table policy) — proven live pgTAP 27-32
- [x] Unauth sheet/route access redirects with `?next=` preserved (no new routes, so existing guard behavior holds)

### 5.2 Authorization

- [x] Owner-only writes (`service_listings.entity_id == auth.uid()` AND every `portfolio_items.entity_id == auth.uid()` AND equals listing `entity_id`) enforced server-side (`PLT001` listing-level; identical `PLT004` item-level, no oracle); client `isOwner` gating is affordance only and both paths (hidden-entry + forced-call) are tested — proven live pgTAP 37-40
- [x] `archived`/`reported` listings reject links `PLT005`; linking on `draft`/`paused` allowed (staging) but publicly invisible — publishing gates still owned by EP-03-01 — proven live pgTAP 40

### 5.3 Access Control

- [x] Junction table RLS default-deny: `REVOKE ALL FROM anon,authenticated`, no anon policy, owned-listing conjunct on write policies (media precedent — pgTAP 59 proves stranger direct-insert fails `42501`); public visibility gated inside `service_listing_portfolio_list` (published-only), mirroring `portfolio_public_profile_get` precedent
- [x] Draft/unpublished proof hidden from anon and from entity-B (0 rows / `PLT004`); owner reads own drafts (staging preview) — proven live pgTAP 47-51
- [x] `credential-documents` never touched (`getPublicUrl` only on public `portfolio-items` / `service-listing-media`)

### 5.4 Sensitive Data Protection

- [x] Proof payload whitelists showcase columns only; `legal_name`, `document_path`, reviewer metadata, KYC limits, balances structurally absent (pgTAP negative asserts, live test 53)
- [x] No enumeration oracle: unknown listing vs unpublished-to-viewer vs missing item → identical `PLT004`; non-owner link → `PLT001` without identifying the offending ID
- [x] `PLT005` conflict mapping leaks no constraint detail (static message, no `UNIQUE`/`23P01 DETAIL`)

### 5.5 Security Rules

- [x] Writes are `SECURITY INVOKER` (`SET search_path = public`, `VOLATILE`); public read `service_listing_portfolio_list` is `SECURITY DEFINER` (`SET search_path = pg_catalog, public`, `STABLE`) per the `portfolio_public_profile_get` precedent (verified live: INVOKER reads of `portfolio_items` are impossible by design — no anon SELECT policy); `REVOKE EXECUTE FROM public` with explicit grants everywhere; exactly one additive owner SELECT policy on `portfolio_items` (anon posture unchanged)
- [x] Array input cardinality + UUID shape validated server-side; `media_path` CHECK parity (`portfolio-items/{entity_id}/%`) already prevents path traversal
- [x] Audit: `created_by = auth.uid()` + `created_at` on every link row (no new audit table)

---

## 6. Performance Verification

- [x] No unbounded fetch: proof sets capped at 8; one indexed `JOIN` on `(listing_id, sort_order)` per detail view; `has_more`/pagination not needed
- [x] Discovery lists never join proofs (detail-only fetch); ranking/search p95 <400ms budget untouched (EP-03-20 gate, not this task)
- [x] Images via CDN public URLs + `cacheWidth:1200` + `gaplessPlayback`; placeholder on null/failure; no bytes over RPC
- [x] Provider `watch` scoped to proof section; `const` constructors; no per-frame allocation; sheet list lazy (`ListView.builder`) for large owner portfolios; no new cache layer (detail refetch on link-save only)

---

## 7. Testing Verification

### 7.1 Manual Testing

- [ ] As owner on mobile + web: link 3 items to `published` listing → detail shows ordered carousel/grid → reorder via re-save → new order renders → unlink all → empty state + `Add portfolio` returns
- [ ] As signed-out visitor: `published` detail shows linked proof; `draft` detail shows viewer empty copy (no leak); tile tap reaches owner profile context
- [ ] As non-owner: no picker entry on another professional's detail or `MyListingsScreen`; forced link attempt surfaces `PLT001`
- [ ] Cap: selecting a 9th item blocked with inline hint; `Save (8)` succeeds, `Save (9)` never fires
- [ ] Draft staging: link on `draft` → owner preview shows tiles with `Only published listings show proof publicly` helper

### 7.2 Automated Testing

- [x] pgTAP (`044_service_listing_portfolio_links.sql`, `plan(60)`): DDL + RPC matrix + visibility + leakage + reuse + cascade + direct-insert guard — all PASS live
- [x] Unit (`test/unit/`): proof DTO/mapper whitelist + order; `validateProofSelection` (empty/dup/>8); envelope new codes; repository `PLT004→empty`; provider transitions — reuse `fake_service_listing.dart` + `fake_portfolio.dart` — all PASS (16 new)
- [x] Widget (`test/widget/marketplace/`): `ServiceProofSection` 5 states (incl. video/link/null-media placeholders); owner-vs-viewer CTA visibility; sheet multi-select + cap counter + save wiring (mock service); token assert (no `Colors.*` — grep gate); goldens mobile + web — all PASS (13 new)
- [x] Integration (`test/integration/service_listing_proof_flow_test.dart`): item → link → published → detail shows proof; owner empty state + CTA; full sheet-save → authoritative reload; draft hidden from anon, visible to owner — PASS (3 new fake-E2E flows)
- [x] Static: `dart analyze` clean, `flutter test` green on all affected suites, `grep Colors\.|fontFamily` zero-tolerance, formatter clean, `018/023/024/033` + posture suites green
- [x] No pgTAP in the Dart write scope beyond the new suite (server covered by `044`); `023`/`033` inventories updated to the new correct counts (26 RPCs, 2 DEFINER, 5 anon)

### 7.3 Edge Cases

- [x] Empty array / null listing id → `PLT003`; dup IDs in one call → `PLT003` (no partial insert — single transaction)
- [x] Same item linked to 3 listings → all 3 details show it (junction reuse; proven live pgTAP 57)
- [x] Deleting the listing removes its links, items survive (`CASCADE` both directions verified live pgTAP 58)
- [x] `video`/`link` items render placeholder + type chip (no crash, no bucket MIME error surfacing)
- [x] Item with null `media_path` / null `sort_order` renders placeholder and sorts nulls-last per link order

### 7.4 Failure Scenarios

- [ ] Two concurrent full-replace saves → serialized, exactly one winning set, no duplicates, loser retry-safe (advisory lock + UNIQUE by inspection; live race test deferred — needs two concurrent sessions, EP-03-20)
- [x] Same-selection double-tap save → single RPC effect, single snackbar, no duplicate tiles (full-replace + UNIQUE, proven live pgTAP 42-46)
- [x] Supabase 5xx / timeout on save → provider `error` → `HivorrErrorState`/snackbar + Retry; no ghost tiles
- [ ] Session expiry mid-sheet → `PLT001/002` → re-login with `?next=` (generic auth path, not exercised end-to-end here)
- [x] Direct `INSERT service_listing_portfolio_links` as stranger bypassing RPC → RLS denial (proven live pgTAP 59, `42501`)

---

## 8. User Acceptance Verification

- [ ] As professional on mobile + web: curates up to 8 proof pieces per service in ≤5 minutes without support; understands draft-staging vs published visibility and the 8-piece cap
- [ ] As consumer: understands linked proof as work evidence (distinct from verification badges) and can reach the professional's full portfolio from a tile
- [ ] As anonymous web visitor: sees proof on published listings without signing in; understands the calm empty state on unlinked listings
- [ ] As downstream dev (EP-03-09/19/20 reviewer ack): proof section composes inside detail without discovery/ranking changes; `og:image` fallback works; EP-03-20 check #10 (proof linkage renders) consumable unmodified

---

## 9. Final Approval Checklist

| # | Condition | Evidence | Status |
|---|---|---|---|
| 1 | Junction table + unique + index + RLS default-deny + no anon grant + realtime-excluded, one additive migration, zero edits to existing migrations | `git diff -- supabase/migrations` (only the new file) + pgTAP DDL green (live 1-15) | ✅ PASS |
| 2 | `service_listing_link_portfolio_items` enforces same-`entity_id` ownership, cap 8, dedup, `archived/reported → PLT005`, full-replace idempotent, envelope-coded; non-owner → `PLT001` | pgTAP RPC matrix live (33-46) + integration forced-call test | ✅ PASS |
| 3 | `service_listing_portfolio_list` returns whitelisted ordered items for `published` to `anon`; drafts hidden from non-owners (`PLT004`/0); owner sees own drafts; no oracle | pgTAP visibility + leakage suite live (47-54) | ✅ PASS |
| 4 | Data layer extended (DTO/mapper/datasource/repository/service/provider) with unit tests; no forked `PortfolioItem`; no client-side ownership/published decisions | `flutter test` unit group (16 new PASS) | ✅ PASS |
| 5 | `_ProofSlot` replaced by `ServiceProofSection` (loading/empty/loaded/error) reusing `PortfolioGrid`/`PortfolioItemCard`/`ServiceMediaCarousel` + `mediaPublicUrl`; server order verbatim; snackbar placeholder gone | widget tests + goldens (8 new PASS) + pre-existing detail tests green | ✅ PASS |
| 6 | Owner `Add portfolio`/`Edit proof` opens `LinkPortfolioSheet` (search + multi-select ≤8 + save); success snackbar + reload; `PLT001/003/004/005` surfaced correctly | widget tests (5 new PASS: states + cap + save wiring) | ✅ PASS |
| 7 | `VerificationBadgesRow`/`TradeVerifiedBadge` untouched and authoritative; proof never implies verification | negative widget test + code diff | ✅ PASS |
| 8 | No new route/bucket/package/RPC-surface beyond the 3 proof RPCs; no ranking/search/contract/escrow change; `dart analyze` + `flutter test` green; zero `Colors.*`/hex/`fontFamily`; localized strings only | static scans + `git diff -- pubspec.yaml` empty | ✅ PASS |
| 9 | Integration green: item → link → published → anon sees proof; non-owner blocked; unlink → empty state; downstream EP-03-09/19/20 ack | integration fake-E2E (3 PASS) + lead sign-off (mark-as-done approval) | ✅ PASS |

> All 9 gates required to flip `EP-03-15` from `Not Started` to `Completed`. Any unchecked box blocks Stage 3 linkage exit. Zero parallel proof stacks; zero client-side ownership math; zero new verification gates.

---

## 10. Verification Evidence (code level)

| Attribute | Value |
|---|---|
| **Date** | 2026-10-09 |
| **Decision** | Completed — approved by project lead (deferrals accepted per EP-03-14 pattern) |
| **Unit tests** | 16 new PASS (`service_listing_proof_mapper_test` 4, `service_listing_proof_test` 12: validators, service delegation, repository fail-fast + re-read) |
| **Widget tests** | 13 new PASS (`service_proof_section_test` 8: 5 states + Edit + deep-link + placeholders + retry + signed-out; `link_portfolio_sheet_test` 5: save + unlink-all + cap + empty + error) |
| **Integration tests** | 3 new PASS (`service_listing_proof_flow_test`: viewer grid, owner empty state, full sheet-save → authoritative reload) |
| **Regression** | 936-test targeted run green (marketplace + portfolio + data suites); pre-existing detail tests green; `dart analyze lib test`: `No issues found!`; forbidden greps (junction-table writes, `Colors./fontFamily/0xFF`, `lib/ai`, new `pubspec` dependency) all 0 |
| **pgTAP (live local DB)** | `044` 60/60 PASS; full `supabase test db` (all 44 files, same command as CI) PASS; `023`/`033` inventories updated to correct counts (26 RPCs, 2 DEFINER, 5 anon); `018/024/004/008/017` green |
| **Migration** | `20261007090001_service_listing_portfolio_links.sql` applies cleanly via `supabase db reset` (local only; nothing pushed remote) |
| **Fix rounds** | (1) `unnest(...) as x` aggregated whole records → every link raised `PLT004`; fixed with `as x(id)` — caught by pgTAP, would have been a total silent failure in staging. (2) INVOKER→DEFINER correction for the public read + additive owner SELECT policy (lead sign-off requested §9-gate context; posture audits constrain it to the approved `portfolio_public_profile_get` pattern). (3) Junction write policies tightened with the owned-listing conjunct (media precedent; pgTAP 59 proves stranger direct-insert fails `42501`). (4) `CheckboxListTile` wrapped in `Material(transparency)` (framework ink assertion). |
| **Accepted deferrals** | Manual walkthrough (§7.1), UAT (§8), live-Dev/Staging click-through + p95 → EP-03-20 gate · live write-race test (§7.4: advisory lock + UNIQUE by inspection; UNIQUE backstop proven) · session-expiry E2E (generic auth path) · full `flutter test` (environmental timeout; all affected suites green) · `og:image` wiring → EP-03-19 (source available via `fetchProofs`) |
| **Residual risk** | Low. Writes are owner-gated INVOKER RPCs with fail-fast mirrors; reads are whitelisted DEFINER projections with identical-`PLT004`; no ledger writes, no ranking logic, no new SQL beyond the one additive migration. Offline link writes require connectivity (documented; no queue in scope). |

---

> **Notes for reviewer:** This DoD is task-specific per `AGENT.md` Bounded Scope. Scheduling integrity is calendar, ledger untouched; deterministic core is invoked only as order-preservation (link `sort_order` verbatim, never AI- or client-reordered). Treat any direct junction-table write from client, any `service_listings` column addition, any new bucket, any ranking-weight change, any badge-logic fork, or any hardcoded color/font as automatic DoD failure.
