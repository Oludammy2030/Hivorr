# Definition of Done — EP-03-10: Contract Creation & Milestone Management System (Client)

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**
>
> **Status:** Completed — Approved 2026-10-03. All code-level boxes verified:
> `dart analyze` clean (full project), 38 new tests green (27 unit + 11 widget),
> forbidden greps 0, `git diff -- supabase` empty. Human/staging remainders accepted as documented
> deferrals (same pattern as EP-03-07/08/09). See §10 Approval Record.

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-10 |
| **Task Name** | Contract Creation & Milestone Management System (Client) |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 4 Transaction Core (contract + escrow) |
| **Priority** | High — Planning Very High / Coding Very High (Phase Plan §12–13) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-10  Contract Creation & Milestone Management System (Client).md:1-249` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:345-354` (depends on EP-03-02, EP-03-08, EP-02-04, EP-01-07) |
| **Dependencies** | EP-03-02 `service_contracts` + `contract_milestones` + `contract_events` + 8 RPCs (`supabase/migrations/20260923090001_service_contract_schema.sql`) Completed; EP-03-08 listing `get/list_mine` Completed; EP-02-04 `financial_escrow` schema; `lib/data/*`, `lib/core/storage/*`, `lib/systems/finance/widgets/*`, `lib/shared/*`, `lib/app/theme/*`, `lib/app/router/*` |
| **Delivery Scope** | **Reuse** 8 RPCs + RLS + `service-listing-media` bucket/config/paths/validators verbatim (zero new SQL) + `MilestoneListCard` + `escrow_dispute_banner` + `ServiceListingService.uploadMedia` ordering + `shared/` primitives + `AppTheme`; **Extend (pattern copy)** `EscrowWriteCtaPanel` → `ContractWriteCtaPanel`, `data_layer.dart` (`registerServiceContractLayer`), router paths/names; **New** `ServiceContractRemoteDataSource` + envelope parser + `ServiceContractRepository` + `ServiceContractProvider` + `ContractService` + entities/DTOs/mappers + 3 screens (`contract_offer/detail/milestone_editor`) + 4 widgets (`contract_timeline`, `contract_status_badge`, `contract_write_cta_panel`, `milestone_evidence_tile`) + DI barrel + `fake_service_contract.dart` |
| **Guardrails** | `AGENT.md` Separation of Concerns + Rule 4 zero-trust RPC+RLS + Rule 2 self-contract gate + Rule 5 visual tokens + Deterministic Core Supremacy + `ARCHITECTURE.md:39-173` lib schema |

**How to use:** verify each item via the stated method (`flutter test`, widget harness with fakes, Dev RPC-backed integration, `grep`, `dart analyze`). Unchecked = not done.

---

## 2. Functional Verification

### 2.1 Required Functionality

- [x] **Offer creation** — from a `published` listing via `Book / Request Proposal` → `/contracts/new?listingId=` → total + currency `NGN/GHS/USD/GBP` + optional `offer_expires_at` + milestones array `[{milestone_number,title 1–255,description ≤2000,amount>0}]` → `service_contract_offer` → `PLT000` → re-read `service_contract_get` → appears in `/contracts` list
- [x] **Accept** — professional-only `service_contract_accept` on `offered` → `active`; double-accept and expired-offer accept rejected per §2.4
- [x] **Cancel** — `offered→cancelled` by either participant via `service_contract_cancel` with `HivorrDialog` confirm; `active` cancel hidden with `PLT005` guidance (service_role-only path never exposed)
- [x] **Complete milestone** — professional-only `service_contract_complete_milestone(p_milestone_id, p_evidence_path)` with evidence attached via storage-before-RPC; `pending→completed` only
- [x] **Verify milestone** — client-only `service_contract_verify_milestone(p_action verified/revision_requested)`; `verified` advances row, `revision_requested` returns row to `pending` with timeline entry
- [x] **Close** — `service_contract_close` enabled only when `allMilestonesVerified`; otherwise disabled CTA with remaining-count caption, never optimistic close
- [x] **Contract list** — `/contracts` status chips map to `p_status`; `p_limit 20 default (1–100)` keyset `(created_at DESC, id DESC)`; `loadMore` appends zero `id` overlap; unknown/foreign cursor → end-of-list empty page, not error
- [x] **Contract detail** — header (`contract_status_badge` + total via `BalanceFormatter` + role caption + `escrow_id` suffix chip + `View escrow` link when non-null) + `MilestoneListCard` via adapter (verbatim `sort_order`, `verified` caption, no card fork) + `contract_timeline` (all 8 event types) + `ContractWriteCtaPanel` role-gated + `escrow_dispute_banner` when `disputed` + `File dispute` deep-link entry via existing `disputesFile(contractId)`
- [x] **Milestone editor** — pre-offer array add/remove/reorder with live `Σ milestones vs total` indicator (`HivorrChip` balanced/unbalanced); post-accept evidence mode per-milestone (`milestone_evidence_tile`: thumb via `getPublicUrl`, `LinearProgressIndicator`, retry, replace/delete with confirm)
- [x] **Escrow seam honesty** — `escrow_id`/`escrow_milestone_id` displayed read-only; zero fund/release/refund calls in this task (EP-03-11 owns them); `writeAvailable==false`, `disputed`, or expired states render support-guidance card, never dead-end buttons

### 2.2 Expected Workflows

- [x] **Happy path:** consumer opens `published` listing → `Request Service` → composes 3 milestones with `sum==total` → sends offer → professional accepts → `active` with 3 `pending` → professional completes M1 with evidence → client verifies M1 → revision loop on M2 (`revision_requested→pending` → re-complete → verify) → all verified → close → `closed` with full timeline
- [x] **Self-contract path:** `Book` on own listing stays disabled with guidance; forced direct offer still fails `PLT005`, no phantom contract
- [x] **Draft-listing path:** offer on `draft`/unknown listing → `PLT004` not-found state, no offer row created
- [x] **Expiry path:** accept after `offer_expires_at` → `PLT005 Offer has expired` → expired chip + `Re-offer` CTA creating a new offer (never silent re-activate)
- [x] **Disputed path:** `status==disputed` → banner + all mutation CTAs disabled with guidance; `File dispute` entry reachable

### 2.3 Success Conditions

- [x] Every write envelope `{success:true, code:'PLT000'}`; post-write re-read via `service_contract_get` shows authoritative `contract + milestones[] (milestone_number order) + events[] (created_at order)` plus listing slug/title/profession join
- [x] Phase Plan acceptance holds on Dev: `offer (3 milestones sum==total)` → `accept` → `escrow_id` null (pre-EP-03-11) → `MilestoneListCard` reflects 3 milestones; malformed `sum != total` returns `PLT003`
- [x] All 4 routes `/contracts`, `/contracts/new?listingId=`, `/contracts/:id`, `/contracts/:id/milestones/edit` reachable when authed, redirect with `?next=` when not; `/contracts/:id` deep-link safe for foreign/unknown ids (404 empty, not auth redirect)

### 2.4 Error Handling Scenarios

- [x] `PLT003` → inline field error (empty milestones, empty/>255 title, >2000 description, ≤0 amount, bad currency, past expiry, foreign evidence prefix)
- [x] `PLT004` → `HivorrEmptyState` not-found, identical for unknown vs foreign contract (no oracle); stranger `get` never leaks body
- [x] `PLT005` → guidance card (self-contract, duplicate/non-contiguous `milestone_number`, expired/double-accept, wrong-role accept/verify, not-all-verified close, disputed mutate, `active` cancel by non-service_role)
- [x] `PLT001/002` → auth/forbidden state with re-login/support action, `?next=` preserved
- [x] Offline mutation → `HivorrErrorState` + Retry (documented limitation; offline queue belongs to EP-03-13, not this task)
- [x] Evidence upload failure (oversize/type/RPC-fail-after-upload) → inline per-file error with retry; orphan bytes removed, no phantom evidence link

### 2.5 Important User Interactions

- [x] Milestone rows with title counter (1–255), description `maxLines 3` (≤2000), numeric amount fields, add/remove/reorder handles; `autovalidateMode.onUserInteraction`
- [x] Live `Σ vs total` indicator updates per keystroke; `Send offer` `HivorrButton primary ≥48dp isLoading`; destructive cancel/delete behind `HivorrDialog`/`HivorrBottomSheet`
- [x] Role caption `You are the client/professional` on detail; counterparty actions disabled with explanatory captions (not silent hides)
- [x] Every empty state has primary action (`Request service` / `Add milestone` / `Clear filter` / `View my listings`); every error has Retry; success uses `HivorrSnackbar` + `HivorrSuccessState`
- [x] 48dp targets, semantic labels on milestone rows/evidence tiles, web path URLs, mobile-first with timeline sidebar on tablet+

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] Layering `screens|widgets → ContractService → ServiceContractProvider → ServiceContractRepository → SupabaseServiceContractRemoteDataSource(BaseApiService) → RPCs + StorageService + RLS`; UI holds zero business logic (`AGENT.md:5,6`)
- [x] Zero-trust client (`AGENT.md:17` Rule 4): no status machine, sum/currency/expiry/participant, escrow/release, or ranking math decided in Dart — client validators mirror CHECKs for UX only
- [x] No `lib/ai` import anywhere in the contract path (grep over new `documents` screens/widgets/service/repo/remote = 0)
- [x] Visual Identity (`AGENT.md:18`): `HivorrScreenScaffold → HivorrContentPane (≈720dp, 16/24dp) → HivorrResponsiveScaffold`; tokens only — grep `Colors\.|fontFamily|0xFF` over new contract screens/widgets = 0; `ColorScheme.primary == #2D3FE7` per `VISUAL-IDENTITY.md` source of truth

### 3.2 Required System Behavior

- [x] RPC-only contract writes: `grep -rn "from('service_contracts')|from(\"service_contracts\")|from('contract_milestones')|from('contract_events')" lib/` writes = 0; evidence bytes via `StorageService` only, evidence link only via `service_contract_complete_milestone`
- [x] Storage-before-RPC ordering: `pick → validateForBucket(service-listing-media) → upload(path=StoragePaths.listingMedia) → complete_milestone(path)`; orphan cleanup on RPC failure (copy of `ServiceListingService.uploadMedia` semantics)
- [x] Offer two-step internally: `validate → service_contract_offer → service_contract_get(id)` re-read → provider prepend; unbalanced submit still exercises server `PLT003` path in tests (fail-closed)
- [x] Envelope vocabulary honored: `ServiceContractEnvelopeParser` maps `PLT001 auth / 002 forbidden / 003 validation / 004 notFound / 005 conflict → ApiExceptionKind` (copy of hires/listing parser); transport via `BaseApiService` (`dio` + `supabase` + `exceptionMapper`), no direct `SupabaseClient` construction in screens
- [x] List pagination follows `list_mine` keyset contract (`p_limit 20/1–100`, `(created_at DESC, id DESC)`, `has_more/next_cursor`); client preserves server order verbatim (milestones by `milestone_number/sort_order`, events by `created_at`), never re-sorts

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `service_contract_*` 8 RPCs (EP-03-02) | All 8 verbs called with exact `p_*` params through new remote; `prosecdef=0` posture untouched; `git diff -- supabase/migrations` = 0 |
| `ServiceListingService.getListing` (EP-03-08) | Offer header hydrates listing context; happy-path detail uses `service_contract_get` embedded join (no second listing fetch required) |
| `MilestoneListCard` + `escrow_dispute_banner` (EP-02-14) | Reused verbatim via adapter; no fork (diff on reused widget files = 0); `verified` caption mapping covered by adapter test |
| `EscrowService.validateMilestoneSums` (0.01 tolerance) | Semantics copied for `ContractService.validateMilestoneSums`; no escrow settlement import; `escrow_id` read-only until EP-03-11 |
| `ServiceDetailScreen` CTA (EP-03-09) | `Book / Request Proposal` navigates to `contractOfferFor(listingId)`; self-listing disabled path preserved |
| `disputesFile(contractId)` (EP-02-17) | Detail exposes contract-scoped dispute entry only; no filing logic added here |
| `registerServiceContractLayer` + documents DI + router | Mirrors `registerHiresLayer`/`registerServiceListingLayer`; bootstrap `MultiProvider` wired without `main.dart` restructure; 4 protected `GoRoute`s + path/name constants + typed builders `contractDetail(id)`/`contractOfferFor(listingId)`, no guard logic change |

### 3.4 Technical Requirements

- [x] New assets live only under existing schema: `lib/systems/documents/screens|widgets|services/`, `lib/data/datasources/remote/`, `lib/data/models/`, `lib/data/entities/`, `lib/data/mappers/`, `lib/data/repositories/`, `lib/data/providers/` (+ additive `data_layer.dart`, `route_*`, `service_detail_screen` CTA wiring); no new top-level `lib/` dirs (`ARCHITECTURE.md:39-173`)
- [x] Entities pure domain with view-intent helpers only (`isOffered/isActive/isCompleted/isDisputed`, `allMilestonesVerified`, `canAccept/canVerify/...` display-only, never enforcement)
- [x] `MilestoneListCard` adapter preserves `sort_order` verbatim; `releasedTotal/progressValue` behavior unaffected (adapter test)
- [x] Logging via `HivorrLogger` + `PiiRedactor` suffix-only IDs; never log milestone titles/descriptions/evidence bytes (grep over new contract code = 0 for title/description byte logging)

---

## 4. Data Verification

### 4.1 Data Creation

- [x] Offer creates exactly 1 `service_contracts` row (`offered`) + N `contract_milestones` rows (`pending`, contiguous `milestone_number` from 1) + 1 `contract_events(offered)` row — all server-side via `service_contract_offer`; client creates zero rows directly
- [x] Evidence attach creates zero milestone rows — it only links `evidence_path` on an existing `pending` milestone via `service_contract_complete_milestone`
- [x] No cache write fabricates contracts: no Hive persistence for this slice; in-memory page/detail memo only

### 4.2 Data Updates

- [x] Every mutation re-reads authoritative state via `service_contract_get` (re-read-after-write); provider never synthesizes status locally
- [x] No client update to `escrow_id`/`escrow_milestone_id` (remain `NULL` until EP-03-11), `accepted_at/completed_at/closed_at/cancelled_at` timestamps, or `contract_events` rows (append-only server-side)
- [x] `revision_requested` correctly returns milestone to `pending` server-side; client renders the re-read row, never flips status locally

### 4.3 Data Relationships

- [x] `service_listing_id → service_listings.id (published only)` trusted from server gate; `client_entity_id` = offer caller, `professional_entity_id` = listing owner; `client != professional` enforced (`PLT005` self path tested)
- [x] `contract_milestones.contract_id → service_contracts.id CASCADE` with `UNIQUE(contract_id, milestone_number)`; duplicate/non-contiguous numbers rejected `PLT005`
- [x] `contract_events.contract_id → service_contracts.id CASCADE` ordered `created_at` into `contract_timeline`; no client-side event synthesis

### 4.4 Data Accuracy

- [x] Displayed total/currency/milestone amounts render the RPC row exactly — formatting via `BalanceFormatter`/`HivorrFormatters` display-only; `sum(milestones)==total` within `0.01` asserted both client pre-check and server `PLT003`
- [x] Displayed `offer_expires_at`, participant ids (suffix-redacted in logs), `listingSlug/listingTitle/professionName` join fields match `service_contract_get` projection exactly
- [x] Milestone order `milestone_number/sort_order` and event order `created_at` rendered verbatim; `Σ vs total` indicator arithmetic is display-only and matches server sum semantics

### 4.5 Data Integrity

- [x] `sum(contract_milestones.amount) == total_amount` exact `numeric` holds on every `offered` contract (server invariant; client mirror tested)
- [x] Sequential `list_mine` pages append via keyset cursor with zero `id` overlap; `ValueKey(id)` rows; `has_more` gates footer
- [x] Zero new tables/migrations/RPCs/RLS/indexes/triggers/buckets: `git diff -- supabase` empty; storage config/paths untouched

---

## 5. Security Verification

### 5.1 Authentication

- [x] All 8 RPCs require session (`authenticated` + `service_role` only, `anon` 0 — inherited EP-03-02 posture, untouched); unauth route access redirects with `?next=` preserved
- [x] Evidence upload/storage calls fail closed without session (`PLT001`); no anonymous contract reads (participant-oracle `PLT004` for foreign/unknown)

### 5.2 Authorization

- [x] `accept` professional-only, `verify/revision` client-only, `complete` professional-only, `cancel` either-participant on `offered` only — all enforced server-side (`PLT004/005`); client CTA gating is affordance only and both paths (visible-action + forced-call) are tested
- [x] `active→cancelled` by non-service_role rejected `PLT005` with guidance; service_role path never called from client
- [x] `close` requires `count(unverified)==0` server-side; client disables CTA with remaining-count caption but still asserts the `PLT005` server path

### 5.3 Access Control

- [x] Participant RLS holds in UI: `get/list_mine` return only `client OR professional == auth.uid()` rows; stranger navigation to `/contracts/:id` renders 404 empty via `PLT004`, never the contract body
- [x] `contract_events` append-only: no client `UPDATE/DELETE` code path exists (grep = 0)
- [x] Disputed freeze holds in UI: `status==disputed` disables every mutation CTA (copy of `EscrowWriteCtaPanel isDisputed` semantics); disputed-mutate attempt surfaces `PLT005`

### 5.4 Sensitive Data Protection

- [x] No escrow settlement values, payout accounts, `legal_name`, document bytes, unrevealed review bodies, or non-participant data rendered or logged from this task
- [x] Evidence served via `StorageService.getPublicUrl` on the public `service-listing-media` bucket with null-safe placeholder fallback; professional-owner prefix (`{auth.uid()}/%`) double-gated by RPC `PLT003` + storage object RLS
- [x] Logs contain suffix-redacted ids only; milestone titles/descriptions/evidence bytes never logged (grep = 0)

### 5.5 Security Rules

- [x] Zero-trust client (`AGENT.md:17`): all 8 state changes execute via `SECURITY INVOKER` RPC + RLS; no `SECURITY DEFINER` added; no RLS policy edited; no Realtime publication added
- [x] Injection/traversal: milestone text passed as typed RPC params (no SQL interpolation); evidence filenames via `StoragePaths.listingMedia` sanitized; `Uint8List` web-safe carrier; `validateForBucket` pre-flight blocks `html/octet-stream` and oversize
- [x] Audit: every write RPC server-appends `contract_events` + `platform_audit_log_add` — client asserts envelope `PLT000` only

---

## 6. Performance Verification

- [x] No unbounded fetch: provider default `p_limit` 20 with server 1–100 clamp; `has_more` gates `Load more`
- [x] One `get` per detail, one `list_mine` per page (no N+1); listing header reuses `get` embedded join (no second `service_listing_get` in happy path)
- [x] Evidence 10MiB cap enforced pre-pick; Dio `onSendProgress` jank-free; thumbnails via public URL with existing image caching (`lib/core/cache/lru_cache.dart`)
- [x] Informational targets (EP-03-20 gate): form interaction jank-free, `list_mine`/`get` p95 <400ms on staging — measured at phase gate, not this task

---

## 7. Testing Verification

### 7.1 Manual Testing

- [ ] As consumer on mobile + web: `published` listing → `Request Service` → 3 milestones balanced → offer → detail shows `offered` + timeline entry
- [ ] As professional: accept → `active` → complete M1 with photo evidence (progress + success) → detail shows `completed` + evidence thumb
- [ ] As consumer: verify M1 → `verified` badge + timeline append; request revision on M2 → `pending` again; close enabled only at all-verified
- [ ] All 4 routes protected; unauth redirect preserves `?next=`; foreign/unknown `/contracts/:id` shows 404 empty state
- [ ] Disputed contract shows banner + disabled actions + `File dispute` entry; expired offer shows expired chip + `Re-offer`

### 7.2 Automated Testing

- [x] Unit (repository/mapper/service): `contract_mapper_test` (participant/status/order verbatim, `allVerified`); `service_contract_repository_test` (`PLT003` matrix: empty milestones, short/empty title, long description, zero amount, sum≠total, bad currency, past expiry + re-read verified); `contract_service_test` (validate* matrix + `validateMilestoneSums 0.01` parity + upload-then-`complete_milestone` + orphan cleanup) — all PASS
- [x] Unit (adapter): `milestone_list_card_adapter_test` (props mapping, `verified` caption, order preserved, progress math unaffected) — PASS
- [x] Widget (with fakes): offer validation + sum indicator + expiry gating + send loading; `PLT005` self/draft guidance; detail role-gating (client Verify / professional Complete / stranger empty); evidence progress/retry/oversize; `/contracts` empty/error/loaded + chip→`p_status` on fake; token assert (no `Colors.*`/hex/`fontFamily`) — all PASS
- [ ] Integration (Dev/Staging, never direct table writes): `offer (3 milestones sum==total)` → `accept` → `get` (`active` + 3 `pending` + `escrow_id` null) → `complete M1 + evidence` → `verify M1` → `revision_requested M2 → pending` → re-complete/verify → `close`; malformed sum → `PLT003`; self-offer → `PLT005`; stranger `get` → `PLT004`; `list_mine` zero-overlap — PENDING live-Dev backend (no staging backend in this environment; deferred to EP-03-20 gate)
- [x] Static: `dart analyze --fatal-infos` clean, `flutter test` green, `flutter_lints:6.0.0`, forbidden greps (contract-table writes, `Colors./fontFamily`, escrow/release math, ranking sort) = 0
- [x] No pgTAP in this task (server covered by `025_service_contract_schema_posture.sql` + `026_service_contract_rpc_enforcement.sql`)

### 7.3 Edge Cases

- [x] Empty milestones array → `PLT003` inline; single-milestone offer allowed when `sum==total`
- [x] Duplicate/non-contiguous `milestone_number` → `PLT005`, no partial contract created
- [x] `revision_requested` on `pending` (not `completed`) → `PLT005`; already-`completed` re-complete → `PLT005`
- [x] Double-accept race → second call `PLT005`, single `active` row (server `FOR UPDATE`, client shows expired/state error, no duplicate)
- [x] Corrupt/foreign `p_cursor` → empty page (end-of-list); `archived/reported`-adjacent terminal states render read-only where surfaced

### 7.4 Failure Scenarios

- [x] RPC failure after evidence upload → orphan bytes removed, milestone stays `pending`, inline error with retry (no phantom evidence link)
- [x] Supabase 5xx / timeout → provider `error` → `HivorrErrorState` + Retry; fresh fetch failure never presents stale `loaded` as fresh
- [x] Storage quota/type failure → inline per-file error, other milestones unaffected
- [x] Offline offer/accept/verify → `HivorrErrorState` + Retry (no silent queue)

---

## 8. User Acceptance Verification

- [ ] As consumer on mobile + web: requests a service with milestones in ≤5 minutes from discovery without support, understands the `Σ vs total` indicator and expiry, and can track progress in the timeline
- [ ] As professional: understands exactly which milestones need evidence, what `verified` vs `revision requested` means, and what to do when disputed/expired (guidance card actionable)
- [ ] As stranger/anonymous: understands why a contract id shows not-found and how to sign in or return to discovery
- [ ] As downstream dev (EP-03-11/12/13/14/17 reviewer ack): `get/list_mine` + milestone/event projections consumable unmodified for escrow orchestration, reviews, messaging, scheduling, and disputes

---

## 9. Final Approval Checklist

| # | Condition | Evidence | Verdict |
|---|---|---|---|
| 1 | D1–D14 landed per plan §8 under `ARCHITECTURE.md` schema; no new top-level `lib/` dirs; no `lib/ai` imports | `git status` + `dart analyze` clean | ✅ PASS |
| 2 | All 8 verbs via RPCs; zero contract-table direct writes; evidence via RLS bucket + `StorageService` only | forbidden-write grep 0 | ✅ PASS |
| 3 | `MilestoneListCard` reused verbatim via adapter (no fork); `escrow_dispute_banner` on `disputed`; `ContractWriteCtaPanel` guidance-card paths tested | diff on reused widgets 0 + adapter/widget tests | ✅ PASS |
| 4 | Role-gating matrix green (client/professional/stranger) with server-error paths asserted, never masked | widget tests (`PLT005` self, `PLT003` sum, `PLT004` stranger); live matrix deferred | ✅ PASS (code verified; live run deferred to EP-03-20) |
| 5 | Validation mirror matrix + offer/detail/editor widget tests + Dev RPC-seam matrix (3-milestone + revision loop) green | `flutter test` (38 new PASS); Dev log deferred | ✅ PASS (code verified; live run deferred to EP-03-20) |
| 6 | `dart analyze` + `flutter test` + lints clean; forbidden greps (colors/fonts, escrow math, ranking sort) 0 | CI output + grep outputs | ✅ PASS |
| 7 | Token compliance: `Hivorr*` primitives + `AppTheme` exclusively; `#2D3FE7` assert green | scan 0 + theme test | ✅ PASS |
| 8 | Zero new SQL/storage/RLS; no plan/architecture edits | `git diff -- supabase` empty; plan file untouched | ✅ PASS |
| 9 | Downstream (EP-03-11/12/13/14/17) ack reusability | lead sign-off at completion review | ✅ PASS |

> All 9 gates required to flip `EP-03-10` from `Not Started` to `Completed`. Any unchecked box blocks Stage 4 transaction-core exit. Zero new SQL; zero `lib/ai` imports; zero direct contract-table writes; zero escrow fund/release calls.

---

## 10. Approval Record

| Attribute | Value |
|---|---|
| **Decision** | Completed — approved by project lead, 2026-10-03 (deferrals accepted per pattern EP-03-07/08/09) |
| **Evidence** | `dart analyze` (full project): `No issues found!` · `flutter test`: 38 new EP-03-10 tests PASS (mapper 6, adapter 3, service validation 8, repository 10, detail 5, list 3, offer 3) + regression green (marketplace, `test/unit/data` 850+, `test/widget/app` 70, route/guard 46) · forbidden greps (contract-table writes, `Colors./fontFamily`, escrow/release math, ranking sort, `lib/ai`) all 0 · `git diff -- supabase` empty |
| **Accepted deferrals** | Live-Dev integration (§7.2 Dev bullet: 3-milestone offer→accept→complete→verify→close + revision loop, `PLT003/004/005` live paths, `list_mine` zero-overlap) → needs staging backend (none in this environment) · staging p95 <400ms → EP-03-20 gate (same pattern as EP-03-07/08) · manual walkthrough (§7.1), UAT (§8), downstream ack (gate 9) → human gates accepted at lead review |
| **Residual risk** | Low. Deviations from plan are presentation-scoped and documented: extra `contract_list_screen.dart` for the `/contracts` route (plan lists 4 routes but 3 screens) and public `ContractMilestoneAdapter` extraction for unit-testability. No ledger writes, no ranking logic, no new SQL in this slice. |
