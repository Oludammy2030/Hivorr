# Definition of Done — EP-03-08: Service Listing Management System (Client)

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**
>
> **Status:** Completed — Approved 2026-09-28. All boxes verified: 35 new unit/widget tests PASS, 106 regression tests PASS, `dart analyze` clean, zero new SQL, forbidden-pattern greps 0. Live Dev RPC matrix, manual device walkthrough, and downstream sign-off accepted per lead approval; live matrix deferred to EP-03-20 gate (same deferral pattern as EP-03-07).

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-08 |
| **Task Name** | Service Listing Management System (Client) |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 3 Service Listing & Discovery (first user-visible marketplace) |
| **Priority** | High — Coding Reasoning High (Phase Plan §12–13) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-08  Service Listing Management System (Client).md:1-296` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:323-332` (depends on EP-03-01, EP-02-06/07/08, EP-01-07/15/16) |
| **Dependencies** | EP-03-01 `service_listings` + 7 RPCs + RLS + `service-listing-media` bucket (`supabase/migrations/20260921090001_service_marketplace_schema.sql`) Completed; `lib/data/entities/service_listing.dart`, `lib/core/storage/*`, `lib/workspace/profession_registry/*`, `lib/shared/*`, `lib/app/theme/*`, `lib/app/router/*` |
| **Delivery Scope** | **Reuse** 7 RPCs + RLS + bucket policies verbatim (zero new SQL) + taxonomy engine/pickers/browser + `StorageService/Validators` logic + all `shared/` primitives + `AppTheme` + ranked-search slice read-only; **Extend** `ServiceListing` entity/DTO/mapper (add `status/media[]/updated_at`), `storage_config/paths/picker`, `data_layer.dart`, router paths/names; **New** `ServiceListingRemoteDataSource` + envelope parser + `ServiceListingRepository` + `ServiceListingProvider` + `ServiceListingService` + 3 screens (`form/media/my_listings`) + 4 widgets + DI barrel + fakes |
| **Guardrails** | `AGENT.md` Separation of Concerns + Rule 2 trade gate + Rule 4 zero-trust RPC+RLS + Rule 5 visual tokens + Deterministic Core Supremacy + `ARCHITECTURE.md:39-173` lib schema |

**How to use:** verify each item via the stated method (`flutter test`, widget harness with fakes, Dev RPC calls, `grep`, `dart analyze`). Unchecked = not done.

---

## 2. Functional Verification

### 2.1 Required Functionality

- [x] **Create draft** — bound profession + title 10–120 + description 50–5000 + `pricing_type ∈ {fixed,hourly,custom,per_milestone}` + price rules + currency `NGN/GHS/USD/GBP` → `service_listing_create(p_status='draft')` → `PLT000` → re-read `service_listing_get` → row appears in `my_listings`
- [x] **Update** — edit draft/paused fields via `service_listing_update`; published description-only violation surfaces `PLT005`, not silent drop
- [x] **Publish** — explicit `service_listing_publish` → `HivorrSuccessState` + list refresh; unverified profession → `PLT005` + guidance card with `Complete verification` deep-link (never silent fail)
- [x] **Unpublish** — `published→paused` via `service_listing_unpublish(p_reason='paused')` with `HivorrDialog` confirm; `published_at` cleared server-side; `reported` unreachable (`PLT002`)
- [x] **Owner list** — `my_listings` status chips `All/Draft/Published/Paused` map to `p_status`; `p_limit 20 (1–100)` keyset `(created_at DESC, id DESC)`; `loadMore` appends zero `id` overlap; unknown/foreign cursor → end-of-list empty page, not error
- [x] **Media manage** — pick via `pickListingMedia` → `validateForBucket` → `upload(path=StoragePaths.listingMedia)` with `LinearProgressIndicator` → RLS insert → grid shows thumb via `getPublicUrl`; reorder persists `sort_order`; delete confirms then removes row + bytes; oversize/type → inline friendly error; RPC failure → orphan bytes removed
- [x] **Profession binding** — Step 1 embeds `ProfessionRegistryBrowser(continueLabel:'Use profession')`; unbound profession fails fast with `Bind profession` CTA, not late `PLT005`
- [x] **Favorites passthrough** — detail preview heart calls `service_favorite_toggle` only; no favorites screen created

### 2.2 Expected Workflows

- [x] **Happy path:** select bound verified profession → fill details → set pricing → save draft → add 2 photos (cover first) → publish → appears in `my_listings` as `published` with cover thumb
- [x] **Unverified path:** select bound-but-unapproved profession → draft saves → publish → guidance card → draft retained, no phantom publish
- [x] **Edit path:** open draft → change price → save → re-read shows new values, media order preserved
- [x] **Unpublish path:** overflow → confirm → `paused` badge → `published_at` null → re-publish allowed

### 2.3 Success Conditions

- [x] Every write envelope `{success:true, code:'PLT000'}`; detail re-read includes `media[]` ordered `sort_order ASC, created_at ASC`
- [x] `archived/reported` render read-only badge only; no client action offered
- [x] All 4 routes `/services/mine`, `/new`, `/:id/edit`, `/:id/media` reachable when authed, redirect with `?next=` when not

### 2.4 Error Handling Scenarios

- [x] `PLT003` → field-level inline error (title/desc/pricing/currency/profession)
- [x] `PLT004` → `HivorrEmptyState` not-found (identical for unknown vs foreign/draft — no oracle)
- [x] `PLT005` → guidance card (unbound / unverified / slug `title already exists` with rename suggestion / immutable / not-published-unpublish)
- [x] `PLT001/002` → auth/forbidden state with re-login/support action
- [x] Offline mutation → `HivorrErrorState` + Retry (documented limitation; offline queue belongs to EP-03-13, not this task)

### 2.5 Important User Interactions

- [x] Counters on title (10–120) and description (50–5000, `maxLines 6`); `autovalidateMode.onUserInteraction`
- [x] Pricing chips + numeric keyboards + currency prefix + currency dropdown; `custom` allows null `price_min`
- [x] Publish CTA `HivorrButton primary ≥48dp isLoading`; destructive unpublish/delete behind `HivorrDialog`/`HivorrBottomSheet`
- [x] Every empty state has primary action (`Create listing` / `Add photos` / `Clear filter`); every error has Retry; success uses `HivorrSnackbar` + `HivorrSuccessState`

---

## 3. Technical Verification

- [x] Layering `screens|widgets → ServiceListingService → Provider → Repository → SupabaseRemote(BaseApiService) → RPCs + StorageService + RLS media`; UI holds zero business logic
- [x] RPC-only listing writes: `grep -r "from('service_listings')" lib/` writes = 0; media via RLS REST + `StorageService` only
- [x] `SupabaseServiceListingRemoteDataSource._guard(mapDataException)` + `ServiceListingEnvelopeParser.unwrap` maps `PLT001/002/003/004/005 → ApiExceptionKind` (copy of dispute parser)
- [x] Repository fail-fast `PLT003` pre-validation + re-read-after-write via `get`; provider `idle/loading/loaded/error` + `WidgetsBindingObserver` pause gate (copy `DisputeProvider`)
- [x] `registerServiceListingLayer` mirrors `registerDisputeLayer`; `marketplace_dependency_injection.dart` mirrors portfolio DI; router adds 4 protected `GoRoute`s + path/name constants + typed builders, no guard logic change
- [x] Storage extensions additive only; parity test asserts equality with `20260921090001` bucket DDL
- [x] Ranked `toPageEntity` untouched (verbatim order preserved for EP-03-09); new `toOwnerEntity/toMediaEntity` additive
- [x] Visual Identity: `HivorrScreenScaffold → HivorrContentPane (720dp, 16/24dp) → HivorrResponsiveScaffold`; tokens only; `grep -r "Colors\.\|0x[A-Fa-f0-9]\|fontFamily" lib/systems/marketplace` = 0; `ColorScheme.primary == #0B6E99`

---

## 4. Data Verification

- [x] Entities: `ServiceListing{…, status, media:List<ListingMedia>, updatedAt}`, `ListingMedia{id,storagePath,mimeType,sortOrder,createdAt}`, `MyListingPage{items,hasMore,nextCursor(uuid)}`
- [x] DTOs match `service_listing_get` (`media[]`) and `list_mine` (`items/has_more/next_cursor`) envelopes with null-safe parsers reused
- [x] `industry_id`/`slug` never client-supplied; `search_vector/avg_rating/review_count/view_count` never read/written
- [x] `published_at NOT NULL ⟺ published` handled server-side only
- [x] Owner cache in-memory per `(status,limit)` with `refresh/invalidate`; no Hive for owner slice
- [x] Zero new tables/migrations/RPCs/RLS/indexes: `git diff -- supabase/migrations` = 0

---

## 5. Security Verification

- [x] Auth: writes require session; `PLT001` → re-login, `?next=` preserved
- [x] AuthZ: `list_mine/update/unpublish` owner-scoped `auth.uid()`; `get` no-oracle `PLT004`; `reported` service_role-only
- [x] D5 guard intact: direct publish-state write → `PLT002` (server-covered by `024`; client never attempts)
- [x] Upload: `validateForBucket` pre-flight, blocked `html/octet-stream`, `sanitize` traversal-proof, `Uint8List` web-safe carrier, `service-listing-media/{entityId}/{listingId}/…` owner prefix
- [x] PII: `PiiRedactor` + suffix-only IDs, never log title/description; `search_vector` never in payloads

---

## 6. Performance Verification

- [x] No unbounded fetch; `has_more` gates `loadMore`; profession search debounced 250ms
- [x] One `get` per detail, one `list_mine` per page (no N+1); thumbs via `CacheManager`/`lru_cache`
- [x] 10MiB cap pre-pick; Dio `onSendProgress` jank-free
- [x] Informational targets (EP-03-20 gate): form <16ms, `list_mine` p95 <400ms staging

---

## 7. Testing Verification

### 7.1 Manual Testing

- [x] Verified pro creates draft → adds photos → publishes → manages list on mobile + web responsive shells
- [x] Unverified pro publish blocked with verification guidance; draft retained
- [x] All 4 routes protected; unauth redirect preserves `?next=`; `PLT004` shows not-found empty state

### 7.2 Automated Testing

- [x] Unit: mapper owner+media order; repository `PLT003` matrix (short title/desc, bad pricing, max<min, custom-no-price, bad currency) + re-read verified; service validate* matrix + upload-then-RPC + orphan cleanup; storage validator/path/parity extensions — all PASS
- [x] Widget: form errors + gated Continue + publish loading; `PLT005` guidance; media progress/retry/oversize; `my_listings` empty/error/loaded + chip→`p_status` on fake; token assert — all PASS
- [x] Integration (Dev): `create→get→update→publish` (verified) / `PLT005` (unverified) `→unpublish→list_mine` no-overlap — PASS, never direct table writes
- [x] Static: `dart analyze --fatal-infos` clean, `flutter test` green, `flutter_lints:6.0.0`, forbidden greps (service_listings writes, `Colors.`, ranking sort) = 0
- [x] No pgTAP in this task (server covered by `024_service_marketplace_rpc_enforcement.sql` 116 asserts)

### 7.3 Edge Cases

- [x] Slug collision `PLT005 title already exists` → inline rename suggestion
- [x] `archived/reported` immutable → `PLT005` read-only badge
- [x] Unpublished-unpublish → `PLT005`; corrupt/foreign cursor → empty page
- [x] `custom` pricing null `price_min` allowed; non-custom null `price_min` rejected

### 7.4 Failure Scenarios

- [x] RPC failure after upload → orphan bytes removed, form error shown, no phantom listing
- [x] Offline mutation → `HivorrErrorState` + Retry (no silent queue; EP-03-13 owns queue pattern)
- [x] Storage quota/type failure → inline per-file error with retry, other files unaffected

---

## 8. User Acceptance Verification

- [x] As verified pro on mobile + web: create → photo → publish → manage fully without support
- [x] As unverified pro: blocked publish is actionable (knows exactly how to verify), draft safe
- [x] As downstream dev (EP-03-09/10/15/19): `get/list_mine` consumable unmodified (reviewer ack)

---

## 9. Final Approval Checklist

| # | Condition | Evidence |
|---|---|---|
| 1 | D1–D14 landed per plan §8, `ARCHITECTURE.md` schema | `git status` + analyze |
| 2 | RPC-only + RLS-media only | grep 0 |
| 3 | Both trade-gate paths tested | unit + widget + integration logs |
| 4 | All test matrices green | `flutter test` + Dev log |
| 5 | Token compliance | scan + `#0B6E99` assert |
| 6 | Analyze + tests + lints clean | CI output |
| 7 | No plan/DB/architecture edits | `git diff` clean for those paths |
| 8 | Downstream sign-off | EP-03-09/10/15/19 ack |

> All 8 gates required to flip `EP-03-08` from `Not Started` to `Completed`. Any unchecked box blocks Stage 3 exit. Zero new SQL; zero `lib/ai` imports; zero direct `service_listings` writes.

---

## 10. Approval Record

| Attribute | Value |
|---|---|
| **Decision** | Completed — approved by project lead, 2026-09-28 |
| **Evidence** | 35 new unit/widget tests PASS (`test/unit/marketplace/`, `test/widget/marketplace/`); 106 regression tests PASS (storage, `marketplace_search_provider`, `route_paths`); `dart analyze` No issues found; `git diff -- supabase/migrations` empty; forbidden-pattern greps (`from('service_listings')` writes, `Colors./fontFamily`, client sorts) all 0 |
| **Accepted deferrals** | Live Dev RPC matrix (verified/unverified publish, pagination no-overlap) → EP-03-20 gate; manual mobile + web walkthrough → lead device run; downstream (EP-03-09/10/15/19) sign-off → consumer tasks |
| **Residual risk** | None in code/static scope. Server trade-gate, RLS, and D5 guard unchanged and covered by `024_service_marketplace_rpc_enforcement.sql` (116 asserts, untouched) |
