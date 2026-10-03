# Task Implementation Plan — EP-03-10: Contract Creation & Milestone Management System (Client)

> **Planning artifact only — no production code written. Awaiting approval before implementation.**
> Sources: `documents/Context/AGENT.md:1-18`, `documents/Context/ARCHITECTURE.md:39-173`, `documents/Context/VISUAL-IDENTITY.md`, `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:345-354` (§EP-03-10) + `§6 Stage 4`, `§7 deps`.

---

## 1. Task Objective

Build the **client-side, unprivileged presentation layer** that converts discovery (`EP-03-08/09`) into a financially-protected engagement over the already-landed `EP-03-02` server contract (`supabase/migrations/20260923090001_service_contract_schema.sql` — 3 tables + 8 `SECURITY INVOKER` RPCs):

- Data vertical slice: `ServiceContractRemoteDataSource` + `SupabaseServiceContractRemoteDataSource` + `ServiceContractEnvelopeParser` → `ServiceContractRepository(+Impl)` → `ServiceContractProvider` → `ContractService` facade (`lib/systems/documents/services/contract_service.dart`).
- Screens (3, per Phase Plan): `contract_offer_screen.dart` (consumer creates offer + milestone array), `contract_detail_screen.dart` (timeline + milestone states + role-gated actions), `milestone_editor_screen.dart` (add/edit/reorder milestones pre-offer; evidence attach post-accept).
- Widgets: **reuse** `lib/systems/finance/widgets/milestone_list_card.dart` verbatim; new `contract_timeline` + `contract_status_badge` (thin `HivorrBadge` wrappers) + `milestone_evidence_tile`; **reuse** `escrow_write_cta_panel.dart` pattern for disputed/write-unavailable guidance.
- Flows: `ServiceDetailScreen Book/Request Proposal` CTA → `contract_offer` (milestones array + total, `sum == total` invariant) → professional `service_contract_accept` → `escrow_id` linkage resolved by `EP-03-11` orchestrator (this task **creates the escrow linkage expectation, never funds/releases itself**). Milestone evidence uploads to the existing `service-listing-media` bucket under the professional-owner prefix.

Per `AGENT.md:6,13` (Separation of Concerns, Rule 4 Zero-Trust): **no pricing math, status machine, sum-invariant, currency, participant, or expiry logic decided in the client.** All authoritative checks stay server-side; client mirrors them only for fast UX feedback.

## 2. Business Problem Being Solved

`EP-03-01` (listings) + `EP-03-02` (contract RPCs) + `EP-03-08` (listing CRUD) + `EP-03-09` (discovery) exist, but there is **no client path to form an engagement**:

- Consumers cannot request a service with structured milestones/total from a `published` listing.
- Professionals cannot accept/cancel/verify milestones or submit evidence.
- `EP-03-11` (escrow release), `EP-03-12` (reviews), `EP-03-13` (messaging), `EP-03-14` (scheduling), `EP-03-17` (disputes) have no contract object to bind to.

Without EP-03-10, Stage 4 (Transaction Core) never starts and the marketplace never converts — the first-revenue capability stays unrealized.

## 3. Scope

**In scope (exactly EP-03-10):**

1. Contract data slice over the 8 EP-03-02 RPCs: `service_contract_offer`, `service_contract_accept`, `service_contract_cancel`, `service_contract_complete_milestone`, `service_contract_verify_milestone` (verify / `revision_requested`), `service_contract_close`, `service_contract_get`, `service_contract_list_mine`.
2. `ContractService` thin facade with static validators mirroring server CHECKs (`validateMilestoneTitle 1–255`, `validateMilestoneDescription ≤2000`, `validateTotal >0`, `validateMilestoneSums sum==total tolerance 0.01`, `validateCurrency ∈ {NGN,GHS,USD,GBP}`, `validateExpiry >now()`).
3. Evidence pipeline: pick → `StorageValidators.validateForBucket(service-listing-media)` → `StorageService.upload(path=StoragePaths.listingMedia)` → `service_contract_complete_milestone(p_evidence_path)`; orphan-bytes cleanup on RPC failure (copy `ServiceListingService.uploadMedia` storage-before-RPC pattern).
4. Three screens + timeline/evidence widgets + DI (`registerServiceContractLayer()` in `lib/data/data_layer.dart` mirroring `registerServiceListingLayer`/`registerHiresLayer`) + protected router routes `/contracts`, `/contracts/new?listingId=`, `/contracts/:id`, `/contracts/:id/milestones/edit`.
5. Unit + widget + RPC-seam integration tests (see §Testing Strategy). No pgTAP work (server already covered by `025/026` suites).

## 4. Out of Scope

Explicitly **not** in EP-03-10 (deferred, no silent expansion):

- Any new migration / RPC / RLS / trigger / bucket policy — EP-03-02 contract reused verbatim.
- Escrow fund/release/refund orchestration and `escrow_id` backfill — `EP-03-11` `contract_escrow_orchestrator.dart` (this task only surfaces `escrow_id` read-only via `service_contract_get` and guides to support when write seam is off).
- Review submit/reveal (`EP-03-12`), messaging thread (`EP-03-13`), scheduling booking (`EP-03-14`), portfolio link RPC (`EP-03-15`), earnings (`EP-03-16`), dispute filing (`EP-03-17` — only deep-link to existing `disputesFile(contractId)` entry point), notifications fan-out (`EP-03-18`), public SEO `/s/:slug/:id` changes (`EP-03-19`).
- Admin moderation / `active→cancelled` service_role path (client surfaces `PLT005` guidance only).
- `lib/ai/*` drafting assistance (excluded from EP-03 per Phase Plan §8.2).
- Offline mutation queue for contracts (messaging `EP-03-13` owns the `action_queue.dart` pattern; contract writes require connectivity — documented limitation).

## 5. Existing Asset and Dependency Analysis

Inspected live codebase (read-only). `lib/systems/documents/` contains only `.gitkeep` — the contract UI home is a genuine gap.

| Asset (exact path) | Status | Relevance to EP-03-10 |
|---|---|---|
| `supabase/migrations/20260923090001_service_contract_schema.sql` (8 RPCs, 3 tables, envelope `PLT000/001/003/004/005/999`) | **Reuse verbatim** | Canonical contract. `offer(p_service_listing_id, p_total_amount, p_currency_code, p_milestones jsonb, p_offer_expires_at)` → `accept/cancel/complete_milestone/verify_milestone/close/get/list_mine`. Sum-invariant, currency-active, `published`-listing gate, `client!=professional`, evidence-prefix `service-listing-media/{auth.uid()}/%` all server-side. Zero new SQL. |
| `supabase/migrations/20260829100004_financial_integrity_schema.sql` (`financial_escrow`, `financial_escrow_milestones`) + `lib/data/repositories/escrow_repository.dart`, `lib/systems/finance/services/escrow_service.dart` (`validateMilestoneSums 0.01`, `releasedMilestoneTotal`, traced+logged facade) | **Reuse pattern / read-only link** | Milestone structure must mirror `financial_escrow_milestones` 1:1. Reuse `validateMilestoneSums` semantics (copy tolerance, do not import escrow math for settlement). `escrow_id`/`escrow_milestone_id` stay `NULL` until EP-03-11 — this task reads them only. |
| `lib/systems/finance/widgets/milestone_list_card.dart`, `escrow_status_badge.dart`, `escrow_dispute_banner.dart`, `escrow_write_cta_panel.dart` | **Reuse verbatim (first) / reuse pattern (rest)** | `MilestoneListCard(milestones, totalAmount, currencyCode)` renders `contract_milestones` via a light adapter (contract milestone → `EscrowMilestone` view shape) — no fork. `EscrowWriteCtaPanel(writeAvailable, isDisputed)` pattern reused for `ContractWriteCtaPanel` (support-guidance card when disputed/expired/unauthorized). `escrow_dispute_banner` reused verbatim on `status==disputed`. |
| `lib/data/repositories/service_listing_repository.dart` + impl, `lib/systems/marketplace/services/service_listing_service.dart` (RPC-only writes, re-read-after-write via `get`, `validateTitle/Description/Pricing/Currency`, storage-before-RPC `uploadMedia/deleteMedia`, orphan cleanup, PII-redacted logging) | **Reuse pattern** | Closest template for the new contract slice (offer→`get` re-read, evidence upload ordering, `validateForBucket` + `StoragePaths.listingMedia`). |
| `lib/data/repositories/hire_repository.dart` + `supabase_hires_remote_data_source.dart` (8-RPC `supabase.rpc` + `JobsEnvelopeParser.unwrap` + `_guard(mapDataException)`) + `lib/systems/jobs/services/hire_service.dart` (vocab + `validateAmount` + traced facade) | **Reuse pattern** | Closest 8-RPC contract analogue (`hire_accept` already creates a linked `service_contracts` row server-side). Remote/parser/service shape copied line-for-line. |
| `lib/data/datasources/remote/supabase_service_listing_remote_data_source.dart`, `service_listing_envelope_parser.dart`, `dispute_envelope_parser.dart`, `BaseApiService` | **Reuse pattern** | Template for new `SupabaseServiceContractRemoteDataSource` + `ServiceContractEnvelopeParser` (PLT→`ApiExceptionKind` mapping). |
| `lib/data/providers/dispute_provider.dart`, `service_listing_provider.dart`, `hire_provider.dart`, `submit_state.dart` | **Reuse pattern** | `ServiceContractProvider` mirrors list/select/refresh + keyset pagination + `WidgetsBindingObserver` pause gate + `lastError: ApiException?`. |
| `lib/data/data_layer.dart` (`registerServiceListingLayer`, `registerHiresLayer`, `registerDisputeLayer`) | **Extend (additive)** | Add `registerServiceContractLayer()` identical shape. No existing registration touched. |
| `lib/core/storage/storage_config.dart` (`serviceListingMedia` bucket/10MiB/jpeg-png-webp-pdf/public), `storage_paths.dart` (`listingMedia(entityId,listingId,fileName)`), `supabase_storage_service.dart`, `storage_validators.dart`, `platform_file_picker.dart` | **Reuse verbatim** | Evidence reuses the EP-03-01 bucket + owner-prefix RLS (`foldername[1]=auth.uid()`). No config/path change needed; evidence path = `listingMedia(entityId: professionalId, listingId: contractId, fileName)` (contract-scoped leaf under existing convention). |
| `lib/systems/support/services/dispute_service.dart` (vocab + `validateReason/Title/Description` + PII-safe logging) | **Reuse pattern** | Validator + logging style for `ContractService`. |
| `lib/systems/marketplace/screens/service_detail_screen.dart` (`Book/Request Proposal` CTA, self-listing disabled, `?next=` resume) | **Reuse as entry point (extend CTA wiring only)** | Offer entry: CTA navigates to `/contracts/new?listingId=`; self-contract attempt still server-rejected `PLT005` (CTA disable is UX only). |
| `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart`, `route_guard.dart` | **Extend (additive)** | Add 4 protected contract routes + path/name constants + typed builders. No guard logic change. |
| `lib/shared/*` (`hivorr_button/card/empty_state/error_state/loading_state/success_state/snackbar/badge/chip/text_field`, `components/hivorr_form_field/dialog/bottom_sheet/list_tile/section_header`, `layouts/hivorr_content_pane/screen_scaffold/responsive_scaffold/breakpoints`, `validators/hivorr_validators`, `mixins/form_validation_mixin/loading_state_mixin`, `helpers/hivorr_formatters/spacing`) + `lib/app/theme/*` | **Reuse verbatim** | Entire contract UI composed from tokens. No new primitives. Rule 5 binding. |
| `supabase/tests/database/025_service_contract_schema_posture.sql` + `026_service_contract_rpc_enforcement.sql` | **Reuse (no new DB tests)** | Server enforcement already proven (`offered→active→completed→verified→closed`, `PLT003/004/005` matrix). Client task adds no SQL. |
| `test/support/fakes/fake_service_listing.dart`, `fake_supabase_storage.dart` | **Reuse + extend** | Add `FakeServiceContractRepository/Remote` with counts + verbatim pages; storage fake reused for evidence tests. |

**Dependencies (must be available):** EP-03-02 (server contract — landed), EP-03-08 (listing `get/list_mine` for offer context — landed), EP-02-04 (escrow schema for milestone-shape parity), EP-01-07 (`ApiLayer`/`BaseApiService`), EP-01-15 (router), EP-01-16 (design system), `file_picker` via `PlatformFilePicker` (already wired).

## 6. Reuse / Extension / Refactoring Assessment

| Proposed asset | Verdict | Why not the alternatives |
|---|---|---|
| Server tables/RPCs/RLS/bucket | **Reuse** — zero new SQL | Landed + pgTAP-covered. Parallel tables or client-side status math would violate Rule 4. |
| `MilestoneListCard`, `escrow_dispute_banner`, storage bucket/validators/paths, `shared/` primitives, `ServiceListingService.uploadMedia` ordering | **Reuse verbatim** | Fit for purpose as-is. Forking `MilestoneListCard` would duplicate the single milestone-render source of truth — adapter pattern instead (contract milestone mapped to card's view props, `sort_order` order preserved verbatim). |
| `EscrowWriteCtaPanel` → `ContractWriteCtaPanel` | **Extend (pattern copy, new file)** | Escrow panel labels (`Release milestone/Refund`) are escrow-specific and must not be generalized in place (would break EP-02-14 `FV-40/47/48` semantics). New panel copies the guidance-card-when-unavailable structure with contract actions (`Accept / Cancel / Mark complete / Verify / Close / Contact support`). |
| `ServiceContractRemoteDataSource` + Supabase impl + `ServiceContractEnvelopeParser` | **New (genuine gap)** — modeled on `SupabaseHiresRemoteDataSource` + `JobsEnvelopeParser` | No remote wraps the 8 contract RPCs; extending `ServiceListingRemoteDataSource` would conflate listing-owner CRUD with engagement lifecycle (domain separation, `ARCHITECTURE.md lib/systems/documents` vs `lib/systems/marketplace`). Designed for reuse: EP-03-11/12/13/14/17 consume `get/list_mine` through it. |
| `ServiceContractRepository(+Impl)` + `ServiceContractProvider` + `ContractService` | **New (genuine gap)** | `HireRepository` covers hiring funnel, not `service_contracts` verbs; `EscrowRepository` covers fund movement behind a write-proxy seam, not offer/accept/verify. New slice owns the contract state machine client mirror. |
| Entities `ServiceContract`, `ContractMilestone`, `ContractEvent`, `ServiceContractPage` + DTOs + mappers | **New (genuine gap)** | No `lib/data/entities/*contract*` exists (glob confirms). `EscrowMilestone` is fund-centric (`pending/completed/released`, `escrowId`) and cannot represent contract milestones (`pending/completed/verified/released`, `contractId`, `evidence_path`, `milestone_number`) without breaking EP-02-14. New entities + `contract_mapper.dart` + `contract_envelopes_dto.dart`. |
| Screens `contract_offer/detail/milestone_editor` + `contract_timeline` + `contract_status_badge` + `milestone_evidence_tile` | **New (genuine gap)** — 100% composed from `shared/` + reused finance widgets | `lib/systems/documents/` is empty; `escrow_detail_screen` is fund-centric and cannot be generalized without breaking its contract. |
| `registerServiceContractLayer` + `documents` barrel/DI + router paths/names/routes | **Extend (additive)** | Follows `registerHiresLayer` / `portfolio_dependency_injection` / `route_paths` builder pattern. |

No refactoring of existing assets recommended — all reused assets are fit for purpose as-is.

## 7. Recommended Technical Approach

**Layering (`ARCHITECTURE.md lib/` schema + `AGENT.md` separation):**

```
UI (lib/systems/documents/screens|widgets)
  → ContractService (validation mirror + evidence orchestration: upload-then-RPC)
  → ServiceContractProvider (ChangeNotifier, keyset pagination, selection)
  → ServiceContractRepository (entity-only, PLT003 fail-fast, re-read-after-write via get)
  → SupabaseServiceContractRemoteDataSource (BaseApiService, supabase.rpc, envelope unwrap)
  → Supabase RPCs (authoritative) + StorageService (evidence bytes) + RLS
```

Key rules:

1. **RPC-only writes.** Never `from('service_contracts'/'contract_milestones'/'contract_events').insert/update`. Evidence bytes go through `StorageService`; the evidence *link* goes only through `service_contract_complete_milestone(p_evidence_path)`.
2. **Storage-before-RPC for evidence** (copy `ServiceListingService.uploadMedia`): `pick → validateForBucket → upload → complete_milestone(path)`; orphan bytes removed on RPC failure. Milestone *creation* (offer array) carries no files — titles/descriptions/amounts only.
3. **Client validation mirrors, never replaces, server CHECKs:** milestone title `1–255` trimmed, description `≤2000`, each amount `>0`, `sum(milestones)==total` within `0.01`, `milestone_number ≥1` unique + contiguous from 1, currency ∈ active subset, `offer_expires_at > now()` when supplied. Server re-checks everything (`PLT003/004/005`).
4. **Offer is explicit two-step internally:** `validate → service_contract_offer → service_contract_get(id)` re-read → provider prepend. Malformed `sum != total` never reaches RPC in happy path, but the `PLT003` server path stays tested (fail-closed).
5. **Role-gated actions from the authoritative row only:** `accept` visible to `professional_entity_id`, `verify/revision` to `client_entity_id`, `complete` to professional, `cancel` to either (offered) / hidden for active (service_role-only → guidance card), `close` when `all milestones verified`. Client role derived from `auth.uid()` vs row participants — enforcement stays server-side (`PLT004` stranger oracle).
6. **`MilestoneListCard` adapter:** map `ContractMilestone{number,title,amount,status→pending/completed/verified/released}` to card props preserving `sort_order` verbatim; `verified` renders with the card's completed-adjacent treatment + explicit `Verified` caption (no card fork). Contract timeline (`offered/accepted/milestone_completed/milestone_verified/revision_requested/closed/disputed` from `contract_events[]`) is the new widget.
7. **Escrow seam honesty:** `escrow_id` displayed read-only (`View escrow` deep-link when non-null); milestone *release* actions are **not** in this task (EP-03-11). When `writeAvailable==false` or `status==disputed/expired`, action panel renders the support-guidance card (copy `EscrowWriteCtaPanel` `_SupportGuidanceCard` structure).
8. **List pagination** follows `list_mine` keyset `(created_at DESC, id DESC)`, `p_limit 20 default (max 100)`; unknown cursor → empty page (no oracle — end-of-list, not error).
9. **Logging:** `HivorrLogger` + `PiiRedactor` suffix-only IDs (copy `dispute_service.dart`/`hire_service.dart`); never log milestone titles/descriptions/evidence bytes.

## 8. Required Systems, Modules, and Components

| # | Component | Location (new unless noted) | Notes |
|---|---|---|---|
| D1 | `ServiceContractRemoteDataSource` (abstract) + `SupabaseServiceContractRemoteDataSource` + `ServiceContractEnvelopeParser` | `lib/data/datasources/remote/service_contract_remote_data_source.dart`, `supabase_service_contract_remote_data_source.dart`, `service_contract_envelope_parser.dart` | 8 RPCs with exact `p_*` params; `_guard(mapDataException)`; copy of hires/listing remote shape |
| D2 | `ServiceContractDto`, `ContractMilestoneDto`, `ContractEventDto`, `ServiceContractPageDto` | `lib/data/models/service_contract_dto.dart`, `contract_milestone_dto.dart`, `contract_event_dto.dart`, `service_contract_page_dto.dart` (or single `contract_envelopes_dto.dart` mirroring `hire_envelopes_dto.dart`) | Match `service_contract_get` single-query projection (`contract + milestones[] + events[]` + listing slug/title/profession join) and `list_mine` keyset envelope; null-safe parsers reused |
| D3 | `ServiceContract`, `ContractMilestone`, `ContractEvent`, `ServiceContractPage` entities + `contract_mapper.dart` | `lib/data/entities/service_contract.dart`, `contract_milestone.dart`, `contract_event.dart` + `lib/data/mappers/contract_mapper.dart` | Pure domain; `isOffered/isActive/isCompleted/isDisputed`, `allMilestonesVerified`, `canAccept/CanVerify/...` view-intent helpers (display only, never enforcement) |
| D4 | `ServiceContractRepository` + `ServiceContractRepositoryImpl` | `lib/data/repositories/service_contract_repository.dart`, `service_contract_repository_impl.dart` | Entity-only; `_requireMilestones/_requireSum/_requireCurrency/_requireExpiry` → `PLT003`; re-read via `get` after every write |
| D5 | `ServiceContractProvider` | `lib/data/providers/service_contract_provider.dart` | `idle/loading/loaded/error`; `loadMine({status,refresh})/loadMore()/select()/offer/accept/cancel/completeMilestone/verifyMilestone/close/refresh`; `lastError: ApiException?`; pause gate copy |
| D6 | `ContractService` | `lib/systems/documents/services/contract_service.dart` | `contractStatusList/milestoneStatusList/eventTypeList` vocabs + static validators + `offerWithMilestones/completeMilestoneWithEvidence` orchestration + `evidencePublicUrl via StorageService.getPublicUrl` |
| D7 | Offer screen | `lib/systems/documents/screens/contract_offer_screen.dart` | Listing context header (via `ServiceListingService.getListing`) + total/currency/expiry form + dynamic milestone list (add/remove/reorder, live `sum vs total` indicator) + `HivorrButton(isLoading)`; entry route `/contracts/new?listingId=` |
| D8 | Detail screen | `lib/systems/documents/screens/contract_detail_screen.dart` | Header (`contract_status_badge` + total + participants + `escrow_id` chip) + `MilestoneListCard` (adapter) + `contract_timeline` + `ContractWriteCtaPanel` (role-gated) + `escrow_dispute_banner` when disputed |
| D9 | Milestone editor screen | `lib/systems/documents/screens/milestone_editor_screen.dart` | Pre-offer milestone array editor + post-accept evidence attach (`pickListingMedia` FAB, progress, retry — copy `service_listing_media_screen.dart` tile pattern) |
| D10 | Widgets | `lib/systems/documents/widgets/contract_timeline.dart`, `contract_status_badge.dart` (thin `HivorrBadge`), `contract_write_cta_panel.dart`, `milestone_evidence_tile.dart` | Pure display; tokens only; `MilestoneListCard` reused not duplicated |
| D11 | DI + barrel | Extend `lib/data/data_layer.dart` (`registerServiceContractLayer`); new `lib/systems/documents/documents.dart`, `documents_dependency_injection.dart` | Mirror hires/dispute DI |
| D12 | Router | Extend `route_paths.dart`, `route_names.dart`, `app_router.dart` | `/contracts`, `/contracts/new`, `/contracts/:id`, `/contracts/:id/milestones/edit` (protected; `?next=` preserved by existing `RouteGuard`); typed builders `contractDetail(id)`, `contractOfferFor(listingId)` |
| D13 | Service-detail CTA wiring | Extend `service_detail_screen.dart` CTA only | `Book/Request Proposal` → `contractOfferFor(listingId)`; self-listing stays disabled with guidance |
| D14 | Test fakes | New `test/support/fakes/fake_service_contract.dart` | `FakeServiceContractRepository/Remote` with counts + verbatim pages |

## 9. Data Requirements

- **Entities:** `ServiceContract{id, serviceListingId, clientEntityId, professionalEntityId, status: draft/offered/active/completed/disputed/closed/cancelled, escrowId?, totalAmount, currencyCode, offerExpiresAt?, offeredAt?, acceptedAt?, completedAt?, closedAt?, cancelledAt?, milestones: List<ContractMilestone>, events: List<ContractEvent>, listingSlug?, listingTitle?, professionName?}`, `ContractMilestone{id, contractId, milestoneNumber, title, description?, amount, status: pending/completed/verified/released, evidencePath?, sortOrder, completedAt?, verifiedAt?}`, `ContractEvent{id, eventType, fromStatus?, toStatus?, actorId?, details, createdAt}`, `ServiceContractPage{items, hasMore, nextCursor}`.
- **DTOs:** match `service_contract_get` single-query projection (`milestones[]` ordered by `milestone_number`, `events[]` ordered by `created_at`) and `list_mine` keyset envelope; `offer` returns `{contract, milestones[]}`.
- **Enums/vocabs (client mirrors, server authoritative):** contract `draft/offered/active/completed/disputed/closed/cancelled`; milestone `pending/completed/verified/released`; event `offered/accepted/cancelled/milestone_completed/milestone_verified/revision_requested/closed/disputed`; currencies `{NGN,GHS,USD,GBP}`.
- **Validation matrix (client pre-check → server RPC):** empty milestones → `PLT003`; title empty/>255 → `PLT003`; description >2000 → `PLT003`; amount ≤0 → `PLT003`; duplicate/non-contiguous `milestone_number` → `PLT005`; `sum != total` → `PLT003`; bad/expired currency → `PLT003`; draft/non-`published` listing → `PLT004`; self-contract → `PLT005`; expired offer accept → `PLT005`; non-professional accept / non-client verify → `PLT004/005`; close with unverified → `PLT005`; disputed mutate → `PLT005`.
- **Caching:** in-memory per `(status, limit)` page + selected-detail memo with explicit `refresh/invalidate`; no Hive persistence (contract truth is participant-scoped and short-lived; offline queue out of scope).

## 10. Database Considerations

**No new tables, migrations, RPCs, RLS, indexes, triggers, or bucket policies.** EP-03-02 is the complete backend:

- Tables reused: `service_contracts` (6 indexes incl. keyset + partial `escrow_idx`), `contract_milestones` (`UNIQUE(contract_id, milestone_number)`, 3 indexes), `contract_events` (append-only, 3 indexes).
- RLS posture reused: participant `SELECT` (`client OR professional = auth.uid()`), RPC-scoped `INSERT/UPDATE`, `contract_events` append-only; `service_role` bypass for future EP-03-11 `escrow_id` backfill.
- Client access map: **all 8 verbs via RPC exclusively**; evidence bytes via `service-listing-media` owner-prefix (professional) + `storage.objects` RLS double-gate; no direct table REST from this slice.
- Integrity notes: `escrow_id`/`escrow_milestone_id` remain `NULL` until EP-03-11 (display-only here); `sum(milestones)=total` exact `numeric` server-side; `contract_events` never `UPDATE/DELETE` from client.
- Future-proofing: EP-03-11 orchestrator, EP-03-12 review gate (`completed/closed` contract filter), EP-03-13 `conversation_ensure_for_contract`, EP-03-14 `appointments.contract_id`, EP-03-17 `dispute_cases.contract_id` all attach without schema change.

## 11. API Requirements

| RPC | Params | Used by | Client handling |
|---|---|---|---|
| `service_contract_offer` | `p_service_listing_id, p_total_amount, p_currency_code='NGN', p_milestones jsonb [{milestone_number,title,description?,amount}], p_offer_expires_at?` | Offer screen → Create | Pre-validate → RPC → `get(id)` re-read → provider prepend; `PLT003` sum/title/amount → inline milestone errors; `PLT004` draft listing → not-found state; `PLT005` self → guidance card |
| `service_contract_accept` | `p_contract_id` | Detail CTA (professional) | `PLT004` non-owner → forbidden; `PLT005` expired/double-accept → expired chip + `Re-offer` CTA |
| `service_contract_cancel` | `p_contract_id, p_reason?` | Detail overflow + confirm dialog | `offered→cancelled` either participant; `active` → `PLT005` guidance (service-role-only path not exposed) |
| `service_contract_complete_milestone` | `p_milestone_id, p_evidence_path` | Milestone row action (professional) + evidence tile | Evidence-prefix `PLT003` → inline upload error; already-`completed` → `PLT005` |
| `service_contract_verify_milestone` | `p_milestone_id, p_action verified/revision_requested` | Detail actions (client) | `verified` → row badge + timeline append; `revision_requested` → row back to `pending` + professional notified (EP-03-18 consumes) |
| `service_contract_close` | `p_contract_id` | Detail CTA when `allVerified` | Not-all-verified `PLT005` → disabled CTA with remaining-count caption (never optimistic close) |
| `service_contract_get` | `p_contract_id` | Detail/editor screens | `PLT004` identical foreign/unknown → `HivorrEmptyState` 404 (deep-link safe `/contracts/:id`) |
| `service_contract_list_mine` | `p_status?, p_limit 1–100, p_cursor?` | `/contracts` list + `loadMore` | Keyset append; `has_more/next_cursor` |

Envelope `{success, code, message, data}` unwrapped by new `ServiceContractEnvelopeParser` (copy of `JobsEnvelopeParser`/`ServiceListingEnvelopeParser`: `PLT001 auth / 002 forbidden / 003 validation / 004 notFound / 005 conflict` → `ApiExceptionKind`). Transport: `BaseApiService` (`dio` + `supabase` + `exceptionMapper` injected); no direct `SupabaseClient` construction in screens; Dio upload path with `onSendProgress` reused from `SupabaseStorageService`.

## 12. User Interface Requirements

All screens: `HivorrScreenScaffold` → `HivorrContentPane` (≈720dp max, 16/24dp gutters) → `HivorrResponsiveScaffold` for tablet/desktop; `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme` exclusively (Rule 5; no `Colors.*`/hex/`fontFamily` per-widget).

- **`contract_offer_screen.dart`:** listing context `HivorrCard` (title, profession, price hint via `HivorrFormatters`) + total `HivorrFormField` (numeric, currency prefix + currency dropdown) + expiry picker + dynamic milestone editor (title 1–255 counter, description ≤2000 `maxLines 3`, amount field, add/remove/reorder handles) + live `Σ milestones vs total` indicator (`HivorrChip` balanced/unbalanced) + draft-validated `HivorrButton primary ≥48dp Send offer (isLoading)`. `autovalidateMode.onUserInteraction`.
- **`contract_detail_screen.dart`:** header `HivorrCard` (`contract_status_badge`, total via `BalanceFormatter`, role caption `You are client/professional`, `escrow_id` suffix chip + `View escrow` link when non-null) + `MilestoneListCard` (adapter, verbatim order) with per-row role actions (`Mark complete` professional / `Verify`+`Request revision` client via `ContractWriteCtaPanel`) + `contract_timeline` (event dots + `hivorr_formatters` timestamps) + `escrow_dispute_banner` when `disputed` + `File dispute` deep-link entry. States: `HivorrLoadingState` / `HivorrErrorState(kind→message + Retry)` / `HivorrEmptyState` 404.
- **`milestone_editor_screen.dart`:** pre-offer array editor (same row component as offer screen, standalone route for editing before send) + post-accept evidence mode (per-milestone `milestone_evidence_tile`: thumbnail via `getPublicUrl`, `LinearProgressIndicator`, retry, replace/delete with `HivorrDialog` confirm).
- **Shared:** `HivorrSnackbar.success/error` for `PLT000/PLT00x`; `HivorrSuccessState` on offered/accepted/closed; `TradeVerifiedBadge`-adjacent verification caption on listing header (display only).

## 13. User Experience Considerations

- **Progressive disclosure:** listing context first → milestones → totals → expiry; fail fast on empty/single-milestone drafts with inline guidance rather than late `PLT003`.
- **Sum honesty:** the `Σ vs total` indicator updates per keystroke; `Send offer` stays enabled but server remains authoritative (unbalanced submit surfaces `PLT003` inline in tests — never hidden).
- **Optimistic restraint:** no optimistic accept/verify/close — every transition waits for RPC (financial sensitivity); rows show `isLoading` on the acted milestone only.
- **Role clarity:** each screen states `You are the client/professional` and disables counterparty actions with explanatory captions (not silent hides), so `PLT004` stranger paths are unreachable by accident yet still tested.
- **Evidence honesty:** per-file progress + cancel/retry; upload-then-link means a failed `complete_milestone` never leaves a phantom evidence link (orphan bytes removed).
- **Error translatability:** `PLT003→field error`, `PLT004→not-found empty state`, `PLT005→guidance card` (self/draft/expired/sum/disputed/unverified-close), `PLT001/002→auth/forbidden` (re-login / support). Preserve `?next=` on auth redirects.
- **Accessibility/responsive:** 48dp targets, semantic labels on milestone rows/evidence tiles, web path URLs via existing `pathUrlStrategy`; mobile-first, timeline sidebar on tablet+.
- **Empty→action:** every empty state carries a primary action (`Request service`, `Add milestone`, `Clear filter`, `View my listings`).

## 14. Security Considerations

- **Zero-trust client (Rule 4):** all 8 verbs via `SECURITY INVOKER` RPCs; client holds no status machine, sum, currency, escrow, or ranking math for settlement.
- **Self-contract + stranger oracles:** `client!=professional` and participant-only `get/list_mine` enforced server-side (`PLT005`/`PLT004`); client CTA gating is UX only and must never mask the server error path in tests (assert both).
- **Evidence traversal safety:** `StorageValidators.validateForBucket` before bytes leave device; `StoragePaths.listingMedia` traversal-proof; `Uint8List` carrier (web-safe); professional-prefix enforced server-side (`PLT003` foreign prefix) + storage object RLS double-gate.
- **Disputed/expired freeze:** `status==disputed` disables all mutation CTAs (copy `EscrowWriteCtaPanel isDisputed` semantics); expired offers show `Offer expired` chip + `Re-offer` (new offer, never silent re-activate).
- **PII/logging:** `PiiRedactor` on all logs; never log titles/descriptions/evidence bytes; IDs suffix-only.
- **Audit:** every write RPC server-audit-logs (`platform_audit_log_add`) + appends `contract_events` — client asserts envelope `PLT000` only.

## 15. Performance Considerations

- Keyset pagination (`limit 20`, max 100) on `/contracts`; no unbounded fetch; `has_more` gate on `loadMore`.
- `get` single-query projection (contract + `milestones[]` + `events[]`); no N+1 — one `get` per detail, one `list_mine` per page; listing header hydrated from `get`'s embedded join (no second `service_listing_get` in happy path).
- Evidence: 10MiB/bucket cap pre-pick; Dio `onSendProgress` avoids jank; thumbnails via public URL with existing image caching (`lib/core/cache/lru_cache.dart`).
- Client preserves server order verbatim (milestones by `milestone_number/sort_order`, events by `created_at`, list by `(created_at,id)`); never re-sorts.
- Target: form interaction jank-free, `list_mine`/`get` p95 <400ms on staging (measured in EP-03-20, not this task).

## 16. Testing Strategy

| Layer | New tests (mirror existing patterns) |
|---|---|
| Unit (repository/mapper/service) | `contract_mapper_test` (participant/status/milestone order verbatim, `allVerified` derivation); `service_contract_repository_test` (fail-fast `PLT003` matrix: empty milestones, short/empty title, long description, zero amount, sum≠total, bad currency, past expiry; re-read-after-write verified via fake remote — copy `service_listing_repository_test` + `hire` harness); `contract_service_test` (validate* matrix + `validateMilestoneSums 0.01` parity with `escrow_service_test` + orchestration: upload-then-`complete_milestone`, orphan cleanup on RPC fail) |
| Unit (adapter) | `milestone_list_card_adapter_test` (contract milestones → card props, `verified` caption mapping, order preserved, `releasedTotal/progressValue` unaffected) |
| Widget | Offer form validation (milestone inline errors, sum indicator states, expiry gating, send-offer loading); `PLT005` self/draft guidance cards; detail role-gating (client sees Verify, professional sees Complete, stranger sees empty — all via fakes); evidence tile progress/retry/oversize (copy `service_listing_media_screen_test` with mock `SupabaseStorageService`); `/contracts` list empty/error/loaded + status-chip filter → `p_status` asserted on fake; theme-token assertion (no `Colors.*`/hex/`fontFamily` — grep + `ColorScheme.primary == #2D3FE7` assert per `VISUAL-IDENTITY.md`) |
| Integration (RPC seam) | Live-RPC matrix on Dev/Staging, never direct table writes: `offer (3 milestones sum==total)` → `accept` → `get` shows `active` + 3 `pending` + `escrow_id` null (pre-EP-03-11) → `complete M1 + evidence` → `verify M1` → `revision_requested M2 → pending` → re-complete/verify → `close` after all verified; malformed `sum != total` → `PLT003`; self-offer → `PLT005`; stranger `get` → `PLT004`; `list_mine` pagination no-overlap. Uses `FakeServiceContractRepository` + live-RPC switch |
| Static | `dart analyze`, `flutter test`, `flutter_lints:6.0.0`; forbidden-pattern grep: no `from('service_contracts'/'contract_milestones'/'contract_events')` writes, no `Colors.`/hex in new widgets, no client-side escrow/release math, no ranking sort |

No pgTAP work in EP-03-10 (server already covered by `025/026` suites).

## 17. Recommended Implementation Sequence

1. **DTOs/entities/mapper + envelope parser** (D2–D3) + mapper/parser tests — establishes the contract language.
2. **Remote + repository + provider + service** (D1, D4–D6) + unit tests with new fakes (`fake_service_contract.dart`).
3. **`registerServiceContractLayer` + `documents` barrel/DI** (D11) — wire into bootstrap `MultiProvider` (no `main.dart` restructure).
4. **Router paths/names/routes** (D12) + redirect test (protected; `?next=` preserved).
5. **Widgets** (`contract_status_badge`, `contract_timeline`, `contract_write_cta_panel`, `milestone_evidence_tile` + `MilestoneListCard` adapter) (D10) + widget tests + token assertions.
6. **Screens** (offer → detail → milestone editor) (D7–D9) + `service_detail_screen` CTA wiring (D13) + widget tests + goldens (mobile + web).
7. **Integration pass** (live RPC matrix on Dev) + `dart analyze` + full `flutter test` + static-grep gates.
8. Handoff to EP-03-11 (escrow orchestration consumes `get/list_mine` + milestone states), EP-03-12/13/14/17 (review/messaging/scheduling/dispute bind to `contractId`) — all consume this slice without rework.

## 18. Expected Outcome

A consumer can: open a `published` listing → `Request Service` → compose milestones with live sum validation → send an offer → track `offered→active→completed→closed` in a role-aware timeline with evidence states — while a professional can accept, submit evidence, and progress milestones, all through server-authoritative RPCs, token-compliant UI, and fully tested seams that EP-03-11/12/13/14/17 build on without rework. Phase Plan acceptance holds: `offer (3 milestones sum==total)` → `accept` → `milestone_list_card` reflects 3 milestones; malformed sums return `PLT003`.

## 19. Definition of Done (DoD)

- [ ] `registerServiceContractLayer` + 3 screens + provider/service/repo/remote/parser + entities/DTOs/mappers + 4 widgets landed under `ARCHITECTURE.md lib/` schema (no top-level dirs, business logic out of widgets, no `lib/ai/*`, no hardcoded colors/fonts).
- [ ] All 8 verbs via RPCs; no `service_contracts`/`contract_milestones`/`contract_events` direct writes in client (grep-clean); evidence via RLS bucket + `StorageService` only.
- [ ] `MilestoneListCard` reused verbatim via adapter (no fork); `escrow_dispute_banner` reused on `disputed`; `ContractWriteCtaPanel` guidance-card paths tested (disputed/expired/stranger/write-unavailable).
- [ ] Role-gating matrix green (client/professional/stranger) with server-error paths asserted (never masked by client hides); self-offer `PLT005`, sum-mismatch `PLT003`, stranger `PLT004` all covered.
- [ ] Validation mirror matrix green (unit); offer/detail/editor widget tests green; RPC-seam integration matrix green on Dev (3-milestone offer→accept→complete→verify→close + revision loop).
- [ ] `Hivorr*` primitives + `AppTheme` tokens exclusively (static scan clean; `VISUAL-IDENTITY` assert passes).
- [ ] `dart analyze` + `flutter test` clean; `flutter_lints` clean.
- [ ] Docs: plan handoff note only (no final feature docs — forbidden in plan mode).
- [ ] EP-03-11/12/13/14/17 can consume `get/list_mine` + milestone/event projections without modification (interface review sign-off).

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: Very High**
- **Reasoning Level Justification:** Matches the approved Phase Plan matrix (`EP-03-10: Planning Very High / Coding Very High`, §12–13). Rationale: technically a bounded client slice over a proven server contract (no new financial settlement, ranking, or crypto — unlike `Extremely High` items EP-03-01/02/03/06/11), but carries **high business impact** (the discovery→revenue conversion point), **high integration complexity** (8 RPCs + evidence storage + role-gated state machine + timeline + router + DI across ~14 components + 4 downstream consumers), and **high security sensitivity** (participant oracles, self-contract, evidence-prefix, disputed-freeze UX must never mask server enforcement; any client-side status/sum confusion would corrupt the EP-03-11 fund-release precondition). `Very High` provides rigorous cross-layer consistency and edge-case coverage (revision loops, expiry, disputed, stranger, orphan cleanup) without the formal-verification overhead reserved for escrow-release atomicity and double-blind invariants. `High` would underweight the state-machine/role-matrix surface; `Extremely High` would be disproportionate (no ledger writes here); `Medium`/`Low` would underweight the marketplace trust surface.

---

**Awaiting your approval to proceed to implementation on exit from plan mode.**
