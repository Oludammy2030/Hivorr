# Task Implementation Plan — EP-03-11: Contract Escrow-Backed Milestone Release & Verification Orchestration

> **Planning artifact only — no production code written. Awaiting approval before implementation.**
> Sources: `documents/Context/AGENT.md:1-19`, `documents/Context/ARCHITECTURE.md:39-178`, `documents/Context/VISUAL-IDENTITY.md:1-60`, `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:356-365` (§EP-03-11) + `§6 Stage 4`, `§7 deps`, `§8 risks`.

---

## 1. Task Objective

Build the **only path where held funds become available** in the Services Marketplace: a verification-gated orchestration bridging the `EP-03-02` contract milestone state machine to the `EP-02-04` provider-agnostic escrow ledger.

Deliverables:

- **Client orchestrator** `lib/systems/finance/services/contract_escrow_orchestrator.dart` sequencing `ContractService` verification states → `EscrowService` fund movement via the existing write-proxy seam (never direct `supabase.rpc` to `service_role`-only writes).
- **Server linkage completion**: backfill `service_contracts.escrow_id` + `contract_milestones.escrow_milestone_id` (both `NULL` until this task per `supabase/migrations/20260923090001_service_contract_schema.sql:19-23,49,76,105,131`) via a `service_role`-only path; add verification-gate + `review_period` expiry semantics without breaking frozen `EP-02-04` invariants.
- **Expiry automation**: Edge Function `escrow_milestone_auto_release` (cron) for `7d` review-period expiry — `supabase/functions/` does not exist today (verified absent), so this is a genuine new capability.
- **UI integration**: `escrow_id` chip → live escrow state on `contract_detail_screen.dart`; reuse `MilestoneListCard`, `EscrowStatusBadge`, `EscrowDisputeBanner`, `EscrowWriteCtaPanel` pattern; disputed/expired/write-unavailable guidance cards.
- **Event fan-out hooks** for `EP-03-18`: `milestone_completed / verified / rejected / released / expired-auto-released / disputed-blocked` via existing `lib/core/notifications` + `EscrowProvider._maybeNotifyRelease` pattern.

Per `AGENT.md:6,13` Rule 4 + `ARCHITECTURE.md:160-166`: **zero financial math, zero status decisions, zero release authorization in the client.** The orchestrator is a sequencer and UX coordinator only; authorization stays in RPC + RLS + proxy.

## 2. Business Problem Being Solved

`EP-03-02` (contract `offered→active→completed→verified→closed`, 8× `SECURITY INVOKER` RPCs, pgTAP `025/026` green) + `EP-03-10` (`ContractService`, 3 screens, evidence storage-before-RPC, `escrow_id` read-only) exist, but **no verified-release path exists**:

- `contract_milestones.status = verified` (client acceptance via `service_contract_verify_milestone`, authenticated-allowed) is disconnected from `financial_escrow_milestones.status = released` + `held→available` ledger movement (service_role-only writes at `20260829100004:1690-1694`).
- `SupabaseEscrowRemoteDataSource:73-80` write seam is `writeViaProxy == false` → `EscrowWriteUnavailableException`; proxy `financial-escrow-proxy (EP-02-18)` is pending. Any direct client `rpc('financial_escrow_release')` returns `403 PLT002`.
- `financial_escrow_milestone_complete:1028-1108` currently moves `held→available` immediately with **no escrow-state check and no contract-verification precondition**; `financial_escrow_release:923` rejects `disputed` but milestone-complete path needs explicit `disputed` + `verified` gating for the contract use-case.
- No `review_period` (7d) exists: `offer_expires_at` is the only expiry in contracts; double-blind reviews have a 14d `review_deadline` (`20260924090001:16-22`) but escrow has no expiry column, no `pg_cron`, no Edge cron.
- Without this task, `EP-03-10` milestones stall at `verified` with funds permanently held; `EP-03-16` earnings never materialize; `EP-03-17` dispute-freeze has nothing to freeze; first-revenue capability fails.

## 3. Scope

**In scope (exactly EP-03-11):**

1. Orchestrator sequencing: `contract_milestones.pending →completed (professional + evidence)` → `verified (client accept) / pending (revision_requested)` → **iff `verified` + escrow `funded/partially_released` + not `disputed`** → escrow milestone fund movement → re-read `financial_escrow_get` + `service_contract_get` → provider refresh + notifications.
2. Escrow linkage creation on first funding: `financial_escrow_create` (mirroring contract milestones 1:1) + `financial_escrow_fund` + backfill `service_contracts.escrow_id` / `contract_milestones.escrow_milestone_id` via `service_role` only.
3. `disputed` hard block: pre-flight `escrow.status == disputed` or `contract.status == disputed` → abort with `PLT005`-equivalent guidance; `financial_escrow_release` guard (`923`) + `dispute_place_escrow_hold:311-321` reused, never bypassed.
4. `7d review_period` expiry: `verified OR completed+7d-without-revision` → auto-release via Edge cron; client displays countdown + expired-auto-released state.
5. Contract-detail escrow surfacing: status badge, held/available delta caption, per-milestone release state, dispute banner, write-unavailable support card.
6. Server delta (minimal, additive): one migration (linkage RPC + `review_period_expires_at` + verify-before-release guard on the contract-linked path) + one Edge Function + pgTAP posture/enforcement suites. No modification of frozen `financial_*` table definitions.
7. Unit + widget + RPC-seam integration + E2E ledger tests (see §Testing).

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| New ledger tables, new currency, 3-party split | Deferred to EP-04; `NGN/GHS/USD/GBP` scope frozen (`Phase Plan §8 Assump.4`) |
| Contract offer/accept/evidence UI rebuild | `EP-03-10` landed (`ContractService`, 3 screens, `contract_milestone_adapter.dart`) — reuse verbatim |
| Double-blind review submit/reveal | `EP-03-12` (`service_review_*` RPCs) |
| Messaging / scheduling / portfolio / SEO | `EP-03-13/14/15/19` |
| Dispute filing/resolution UI | `EP-03-17` extends `dispute_cases` with `contract_id` FK; this task only honors the `disputed` freeze |
| Earnings dashboards | `EP-03-16` reads `financial_transactions` via `service_earnings_summary` |
| Full notification center + push infra | `EP-03-18` owns fan-out matrix; this task emits events only |
| `lib/ai/*` ranking/suggestion | Excluded from EP-03 (`Phase Plan §8.2`); ranking untouched |
| Admin moderation console | Reuses `EP-02-11` Admin shell queue; no new admin screens |
| Offline mutation queue for fund movement | Financial writes require connectivity by design; messaging `EP-03-13` owns `action_queue.dart` pattern |

## 5. Existing Asset and Dependency Analysis

Inspected live codebase read-only (subagent scans + direct reads of `escrow_service.dart`, `supabase_escrow_remote_data_source.dart`, `contract_service.dart:1-80`, `VISUAL-IDENTITY.md:1-60`).

| Asset (exact path) | Status | Relevance to EP-03-11 |
|---|---|---|
| `supabase/migrations/20260829100004_financial_integrity_schema.sql` — `financial_escrow:191-217` (7 states), `financial_escrow_milestones:232-257` (3 states), `financial_transactions:151-186`, `financial_balances:120-146`, `financial_audit_trail:387-413`; RPCs `financial_escrow_create:762-838`, `fund:841-903`, `release:905-967` (guard `923` rejects `disputed`), `refund:970-1025`, `milestone_complete:1028-1108` (immediate `held→available`), `get:1111-1147` (self-scoped `PLT004`); writes `GRANT service_role` only `:1690-1694` | **Reuse verbatim** | Canonical ledger. No table redefinition. Orchestrator consumes `get` (authenticated) + writes exclusively via proxy seam |
| `supabase/migrations/20260923090001_service_contract_schema.sql` — `service_contracts.escrow_id NULL:49`, `contract_milestones.escrow_milestone_id NULL:105`, statuses `draft/offered/active/completed/closed/cancelled/disputed`, milestone `pending/completed/verified/released`, evidence `service-listing-media/{professional_id}/% :607-612`; 8× `SECURITY INVOKER` RPCs | **Reuse verbatim + backfill** | Verification precondition source. `escrow_id` linkage is this task's server work |
| `supabase/migrations/20260829120005_dispute_resolution_schema.sql` + `20260829120006_dispute_withdraw_definer.sql` — `dispute_place_escrow_hold:283-328` (`funded/partially_released→disputed`), `dispute_release_escrow_hold:331-375` | **Reuse verbatim** | Freeze enforcement; orchestrator pre-flights it |
| `lib/systems/finance/services/escrow_service.dart:22-224` — `validateMilestoneSums 0.01:56-66`, `releasedMilestoneTotal`, `milestoneProgress`, `completeMilestone/releaseMilestone/releaseFinal/refundEscrow`, `_tracedAndLogged` + `PiiRedactor` | **Reuse verbatim** | Fund-movement facade; orchestrator delegates to it, never duplicates math |
| `lib/data/repositories/escrow_repository.dart:16-82` + `escrow_repository_impl.dart:45-133` — `writeAvailable:18`, sum/currency validators, re-read-after-write `getById` | **Reuse verbatim** | Write-seam contract; orchestrator reads `writeAvailable` for CTA gating |
| `lib/data/datasources/remote/supabase_escrow_remote_data_source.dart:47-137` + `escrow_remote_data_source.dart` + `escrow_write_unavailable_exception.dart` + `financial_envelope_parser.dart` | **Reuse verbatim** | Proxy seam: `false→EscrowWriteUnavailableException`, `true→UnimplementedError(EP-02-18)`. Orchestrator must honor, never circumvent with direct `rpc` |
| `lib/systems/documents/services/contract_service.dart:35-384` — vocabs, `validateMilestoneSums`, `completeMilestoneWithEvidence:285-345` (storage-before-RPC + orphan cleanup), explicit `34: never funds/releases — EP-03-11` | **Reuse verbatim** | Verification half of the sequence; orchestrator composes it |
| `lib/data/*contract*` — entities (`service_contract.dart` `escrowId nullable`, `contract_milestone.dart` `escrowMilestoneId nullable`), DTOs, `contract_mapper.dart`, `service_contract_provider.dart`, `supabase_service_contract_remote_data_source.dart`, `service_contract_envelope_parser.dart` | **Reuse verbatim** | Read/projection layer for orchestrator state checks |
| `lib/systems/finance/widgets/milestone_list_card.dart`, `escrow_status_badge.dart`, `escrow_dispute_banner.dart:5-10`, `escrow_write_cta_panel.dart:12-77`, `escrow_card.dart` + `lib/systems/documents/widgets/contract_milestone_adapter.dart:14-40`, `contract_status_badge.dart`, `contract_write_cta_panel.dart`, `contract_detail_screen.dart:27-28,379` | **Reuse verbatim (finance) / extend (contract panel)** | Display layer; adapter maps `verified→completed+(Verified)` without forking card |
| `lib/core/storage/storage_config.dart` (`serviceListingMedia` 10 MiB `jpeg/png/webp/pdf` public), `storage_paths.dart:170-188` (`listingMedia(entityId,listingId,fileName)`), `storage_validators.dart`, `supabase_storage_service.dart` | **Reuse verbatim** | Evidence bytes already handled by `EP-03-10`; orchestrator never re-uploads |
| `lib/data/providers/escrow_provider.dart:20-26,282-309` (`_maybeNotifyRelease`, `actionRoute:/finance/escrow/:id`) + `dispute_provider.dart:251-272` + `lib/core/notifications/*` (`notification_service.dart`, `hivorr_notification.dart`, `supabase_push_receiver.dart`) | **Reuse + extend event types** | Notification seam; add `milestone_verified/released/expired/disputed-blocked` types |
| `lib/systems/support/services/dispute_service.dart:113-172`, `screens/dispute_filing_screen.dart:57,113-118`, `widgets/escrow_frozen_banner.dart` | **Reuse verbatim** | Freeze UX vocabulary |
| `lib/app/router/route_paths.dart`, `app_router.dart`, `route_names.dart` — `/finance/escrow/:id`, `/contracts/:id`, `/support/disputes/*` | **Extend additively** | Deep-link targets for release notifications; no guard change |
| `supabase/tests/database/013_financial_schema_posture.sql (plan 25)`, `014_financial_rpc_enforcement.sql (plan 96)`, `025_service_contract_schema_posture.sql (plan 29)`, `026_service_contract_rpc_enforcement.sql (plan 68)` | **Reuse + add 2 suites** | Proven invariants; new suites assert linkage + gate + expiry |
| `test/support/fakes/fake_service_contract.dart`, `fake_supabase_storage.dart` | **Reuse + extend** | Add `FakeEscrowRepository` release-matrix + orchestrator fake |

**Dependencies (must be available):** `EP-03-02` (contract RPCs — landed), `EP-02-04` (escrow ledger — landed), `EP-03-10` (contract client slice — landed), `EP-02-05` (dispute freeze), `EP-02-18` proxy contract (interface; deployment pending — orchestrator must degrade gracefully), `EP-01-07` (`BaseApiService`/Dio), `EP-01-18` (notifications), `EP-01-16` (design system).

## 6. Reuse / Extension / Refactoring Assessment

| Proposed asset | Verdict | Why not the alternatives |
|---|---|---|
| Ledger tables / `financial_escrow_*` core RPCs / RLS / dispute hold triggers | **Reuse** — zero redefinition | Frozen + pgTAP-covered (`013/014`). Parallel ledger or client-side `held-available` math would violate `AGENT.md:13` Rule 4 and `Phase Plan §8.1` |
| `EscrowService`, `EscrowRepository`, `FinancialEnvelopeParser`, `ContractService`, contract data slice, storage bucket/validators/paths, `MilestoneListCard`, `EscrowStatusBadge`, `EscrowDisputeBanner`, `ContractMilestoneAdapter` | **Reuse verbatim** | Fit for purpose. Forking `MilestoneListCard` or duplicating `validateMilestoneSums` would create two milestone truths |
| `ContractWriteCtaPanel` / `EscrowWriteCtaPanel` release actions | **Extend (additive buttons + states)** | Escrow panel's `Release/Refund` labels are fund-centric; contract panel needs `Verify & Release / Request revision / View escrow / File dispute` with `writeAvailable/isDisputed/expiry` gating. Generalizing either panel in place would break `EP-02-14 FV-40/47/48` semantics |
| `contract_escrow_orchestrator.dart` + `contract_escrow_state.dart` (sequence result type) | **New (genuine gap)** — `glob **/*orchestrator*.dart → 0 hits` | No file sequences contract-verification → escrow-release with disputed/expiry guards. Extending `EscrowService` would conflate fund movement with contract lifecycle (domain separation: `ARCHITECTURE.md lib/systems/finance` vs `lib/systems/documents`); extending `ContractService` would violate its documented `never funds/releases` boundary (`contract_service.dart:34`) |
| Server migration `service_contract_escrow_linkage` (linkage RPC + `review_period_expires_at` + verify-gate on contract-linked release path) | **New (genuine gap)** | `escrow_id` nullable-placeholder was explicitly deferred (`schema.sql:76`). No existing RPC backfills it; `authenticated UPDATE` on `escrow_id` must remain forbidden — needs `service_role` RPC. Designed for reuse: `EP-03-16/17/18` consume linkage + expiry without rework |
| Edge Function `escrow_milestone_auto_release` (cron, `service_role`) | **New (genuine gap)** — `supabase/functions/` absent, no `pg_cron` in repo | Expiry automation exists nowhere (only `offer_expires_at` + review 14d lazy-reveal). Client timers cannot authorize fund movement. Function reuses `financial_escrow_*` RPCs + `contract_events` append, not new ledger logic |
| `service_escrow_linkage_provider` additions / `escrow_provider` release-event extension | **Extend** | Follows `registerHiresLayer` / `EscrowNotificationChannel` pattern; no provider rewrite |
| Notification event types + deep links | **Extend** | Generic `HivorrNotification(actionRoute,payload)` already supports; only new types/payloads |

No refactoring of existing assets recommended — all reused assets are fit for purpose as-is.

## 7. Recommended Technical Approach

**Layering (`ARCHITECTURE.md lib/` schema + `AGENT.md` separation):**

```
contract_detail_screen / milestone rows
  → ContractEscrowOrchestrator (NEW: pre-flight → verify → proxy-release → re-read → notify)
      → ContractService (verify/revision, authenticated RPC)   [reuse]
      → EscrowService / EscrowRepository (release, proxy seam) [reuse]
      → Supabase RPCs (authoritative) + Edge proxy (service_role) + cron fn
  → EscrowProvider / ServiceContractProvider (refresh, notify) [extend]
```

Key rules:

1. **Verify-before-release ordering (non-negotiable).** Orchestrator pseudosequence per milestone: `re-read contract_get + escrow_get` → assert `contract_milestone.status == verified` (via `service_contract_verify_milestone`, client `accept`) AND `escrow.status IN (funded, partially_released)` AND `contract/escrow.status != disputed` → invoke escrow movement via `EscrowService` (proxy) → re-read both → append `contract_events(milestone_released)` server-side → notify. Any precondition failure aborts before fund movement with field-level guidance. Client never decides `verified`; server RPC does.
2. **Proxy-seam honesty.** Orchestrator checks `EscrowService.escrowWriteAvailable` first. `false` → support-guidance card (`EscrowWriteUnavailableException` copy) + `View escrow` read-only + `File dispute` link; never falls back to direct `supabase.rpc('financial_escrow_*_write')` (would `403`). `true` → proxy payload `{contract_id, milestone_id, escrow_id, escrow_milestone_id, idempotency_key: uuid v4}` per `lib/core/sync/sync_action.dart` convention; duplicate replay is no-op server-side.
3. **Linkage creation mirrors milestones 1:1.** On first fund: contract milestones (`milestone_number,title,amount,sort_order`) map to `financial_escrow_create.p_milestones jsonb` preserving order; `sum == total` re-validated server-side (`0.01` tolerance client mirror only). Response `{escrow_id}` backfilled with milestone `escrow_milestone_id`s in one `service_role` transaction; `contract_events(disputed-blocked paths)` appended.
4. **Expiry is server-clock.** New `contract_milestones.review_period_expires_at = verified_at/completed_at + 7d` (timestamptz). Cron fn queries `completed AND expires_at < now() AND NOT disputed AND NOT released` with `FOR UPDATE SKIP LOCKED`, releases via same guarded path, marks `released_at`, appends events. Client shows countdown from server timestamps only; never computes release locally.
5. **`disputed` short-circuits everything.** Both pre-flight and cron check `financial_escrow.status` + `service_contracts.status`; `disputed` → `PLT005`-equivalent abort + `EscrowDisputeBanner` + `ContractWriteCtaPanel(isDisputed)` with all mutation CTAs `onPressed: null`.
6. **Idempotency + audit.** Every orchestrator call carries `Idempotency-Key: uuid v4`; server dedupes on `(contract_id, milestone_id, action)`; every mutation produces paired `financial_transactions` rows + `financial_audit_trail` entry + `contract_events` row in one transaction (mirrors `EP-02-04` double-entry rule).
7. **Display mapping.** `ContractMilestoneAdapter` extended with `releaseState: awaiting-verification / awaiting-release / releasing / released / disputed-blocked / expired-auto-released`; `MilestoneListCard` order preserved verbatim (`sort_order`,`milestone_number`); `verified` keeps `completed+(Verified)` treatment + new `Released` caption when `released_at` non-null.
8. **Logging:** `HivorrLogger` + `PiiRedactor` suffix-only IDs (copy `escrow_service._tracedAndLogged` / `contract_service._tracedAndLogged`); never log titles, amounts-full, evidence bytes; `PerformanceTracer` spans `finance.contract-escrow.{link,verify-release,auto-release}`.

## 8. Required Systems, Modules, and Components

| # | Component | Location (new unless noted) | Notes |
|---|---|---|---|
| S1 | Linkage migration | `supabase/migrations/<ts>_service_contract_escrow_linkage.sql` | `review_period_expires_at timestamptz` on `contract_milestones`; `service_contract_link_escrow(p_contract_id, p_escrow_id, p_links jsonb)` `service_role`-only `SECURITY INVOKER`; verify-gate trigger/function on contract-linked release path (`verified` required, `disputed` rejected); `COMMENT ON`, grants, Realtime exclusion |
| S2 | Auto-release Edge Function + cron | `supabase/functions/escrow_milestone_auto_release/index.ts` + schedule config | `service_role`, `FOR UPDATE SKIP LOCKED`, idempotent, appends `contract_events` + audit; skips `disputed` |
| S3 | Orchestrator + state | `lib/systems/finance/services/contract_escrow_orchestrator.dart`, `contract_escrow_state.dart` | `ensureEscrowLinked / verifyAndReleaseMilestone / releaseVerifiedMilestones / refreshReleaseStates`; result type `{ok, code PLT000/001/002/003/004/005, milestoneId, escrowId, releasedAmount?}`; traced+logged |
| S4 | Provider/DI extension | Extend `lib/data/providers/escrow_provider.dart`, `service_contract_provider.dart`; extend `lib/data/data_layer.dart` + `finance_dependency_injection.dart` | `releaseViaOrchestrator`, `_maybeNotifyRelease` new event types; `registerContractEscrowLayer()` additive |
| S5 | Contract-detail escrow section | Extend `contract_detail_screen.dart` + `contract_write_cta_panel.dart` + `contract_milestone_adapter.dart` | Escrow chip (`suffix` id + `View escrow`), per-row release CTA/copy, countdown, dispute banner (reuse verbatim), write-unavailable card (copy `EscrowWriteCtaPanel._SupportGuidanceCard`) |
| S6 | Notification types | Extend `escrow_provider._maybeNotifyRelease` + `notification` payloads | `Milestone verified / released / auto-released / disputed-blocked`; `actionRoute: /contracts/:id` + `/finance/escrow/:id` |
| S7 | Fakes | Extend `test/support/fakes/` (`fake_escrow_repository.dart`, `fake_contract_escrow_orchestrator.dart`) | Counts + verbatim pages + release-matrix |
| S8 | pgTAP suites | `supabase/tests/database/027_contract_escrow_linkage_posture.sql`, `028_contract_escrow_release_enforcement.sql` | Posture (column, RPC perms, Realtime 0) + enforcement matrix (see §Testing) |

## 9. Data Requirements

- **No new core entities.** Reuse `ServiceContract{escrowId}`, `ContractMilestone{escrowMilestoneId, evidencePath, releasedAt (now populated)}`, `ContractEvent`, `EscrowDetail{escrow, milestones, transactions}`.
- **New client type:** `ContractEscrowReleaseState{contractId, milestoneId, escrowId, escrowMilestoneId, phase: idle/checking/verifying/releasing/released/blocked/failed, blockReason?: disputed/not-verified/not-funded/write-unavailable/expired, releasedAmount?, serverTimestamps}` + `ContractEscrowPage` reuse of `ServiceContractPage`.
- **New column (server):** `contract_milestones.review_period_expires_at timestamptz NULL` (`completed_at + interval '7 days'` set on `complete_milestone`; refreshed on `revision_requested→pending→completed` cycle); index `WHERE status IN ('completed','verified') AND released_at IS NULL`.
- **Vocabs (server authoritative, client mirrors):** escrow `created/funded/partially_released/released/refunded/cancelled/disputed`; contract-milestone `pending/completed/verified/released`; event `+ milestone_released/milestone_auto_released/release_blocked_disputed`.
- **Validation matrix (client pre-check → server):** unverified milestone release → abort `not-verified` (server `PLT005`); `disputed` either side → abort `PLT005`; escrow `created/refunded/released/cancelled` → abort `PLT005` (only `funded/partially_released` releasable); sum/currency mismatch on link → `PLT003`; stranger → `PLT004`; proxy-off → `EscrowWriteUnavailableException` guidance (not silent).
- **Caching:** no Hive persistence of balances; in-memory selected-detail memo + explicit `refresh` after every orchestrator call; countdown derived from server `expires_at` on each `get`.

## 10. Database Considerations

**No new tables, no ledger redefinition, no RLS weakening.** `EP-03-02` + `EP-02-04` are complete backends:

- Tables reused: `service_contracts` (partial `escrow_idx`), `contract_milestones` (`UNIQUE(contract_id,milestone_number)`), `contract_events` (append-only), `financial_escrow/_milestones/_transactions/_balances/_audit_trail`.
- Migration is additive: `ADD COLUMN review_period_expires_at` (nullable, no backfill of historical rows beyond `NULL = no-expiry`), one `service_role`-only linkage RPC, one guard function; `REVOKE EXECUTE FROM public` + `GRANT` to `service_role` (+ `authenticated` read where applicable); `ENABLE RLS` untouched; Realtime `DROP TABLE` guard replicated.
- Client access map: reads via `service_contract_get/list_mine` + `financial_escrow_get` (authenticated); **all fund movement via proxy → `service_role` RPCs**; evidence bytes via `service-listing-media` owner-prefix (unchanged); no direct table REST writes from orchestrator.
- Concurrency: linkage + release RPCs `SELECT ... FOR UPDATE` on contract + milestone + escrow rows; cron uses `SKIP LOCKED`; `UNIQUE(contract_id,milestone_number)` + idempotency-key dedupe prevent double-release; second concurrent release sees `released` → `PLT005` no-op.
- Future-proofing: `EP-03-16` aggregates released rows; `EP-03-17` freeze flips status to `disputed` which both pre-flight and cron already honor; `EP-04` 3-party split consumes same `escrow_id` FK without schema change.

## 11. API Requirements

| RPC / Function | Params | Used by | Handling |
|---|---|---|---|
| `service_contract_verify_milestone` (existing, authenticated) | `p_milestone_id, p_action verified/revision_requested` | Orchestrator step 1 (client accept) | `verified→` eligible; `revision→pending` resets `expires_at` |
| `financial_escrow_create/fund` (existing, via proxy `service_role`) | `p_payer,p_payee,currency,total,milestones jsonb` / `p_escrow_id` | `ensureEscrowLinked` (first fund) | Milestones mirror 1:1; `PLT003` sum mismatch |
| `service_contract_link_escrow` (new, `service_role` via proxy) | `p_contract_id, p_escrow_id, p_links [{contract_milestone_id, escrow_milestone_id}]` | Linkage backfill | Participant + sum + currency checks; `PLT004/003/005` |
| `financial_escrow_milestone_complete` + `financial_escrow_release` (existing, via proxy) + new verify-gate wrapper on contract-linked path | `p_milestone_id` / `p_escrow_id` + `p_contract_id` context | `verifyAndReleaseMilestone` + cron | Gate: `contract_milestone.status == verified` (or `completed + expires_at < now()`) AND escrow `funded/partially_released` AND not `disputed`; else `PLT005` |
| `service_contract_get` + `financial_escrow_get` (existing, authenticated) | `p_contract_id` / `p_escrow_id` | Pre-flight + post-release re-read | `PLT004` stranger oracle → 404 empty state |
| `escrow_milestone_auto_release` Edge cron (new, `service_role`) | scheduled, no params | Expiry sweep | Idempotent; emits `milestone_auto_released` events + notifications |

Envelope `{success,code,message,data}` unwrapped by existing `ServiceContractEnvelopeParser` / `FinancialEnvelopeParser` (`PLT001 auth / 002 forbidden / 003 validation / 004 notFound / 005 conflict / 006 funds`). Transport: `BaseApiService` (Dio + Supabase + `exceptionMapper`); no direct `SupabaseClient` writes in orchestrator; idempotency header per `sync_action.dart`.

## 12. User Interface Requirements

All UI: `HivorrScreenScaffold → HivorrContentPane` (≈720dp, 16/24dp) → `HivorrResponsiveScaffold`; `Theme.of(context).colorScheme` + `AppThemeExtension` + `TextTheme` exclusively (Rule 5; no `Colors.*`/hex/`fontFamily`).

- **Contract-detail escrow section (extend, not new screen):** `escrow_id` suffix chip + `View escrow` link (when linked) / `Funding pending` caption (when `NULL`); `EscrowStatusBadge` + held→available delta caption via `BalanceFormatter`; per-milestone row actions from orchestrator state (`Verify & Release` client / `Mark complete` professional via existing flows / `Release` auto-enabled only when `verified` + `writeAvailable` + not disputed).
- **States:** `HivorrLoadingState` (releasing shimmer on acted row only), `HivorrErrorState` (kind→message + Retry), `HivorrEmptyState` 404 on `PLT004`, `HivorrSuccessState` on released; `EscrowDisputeBanner` verbatim on `disputed`; support-guidance card (copy `EscrowWriteCtaPanel` structure) on `writeAvailable == false` / expired / stranger.
- **Countdown:** `review_period_expires_at` rendered via `hivorr_formatters` (`Expires in 3d 4h` / `Auto-released`); no client-computed release.
- **No new primitives.** 100% composed from `shared/` + reused finance/document widgets.

## 13. User Experience Considerations

- **No optimistic fund movement:** every release waits for server envelope; rows show row-local `isLoading`; double-tap disabled during `releasing`.
- **Role clarity:** `You are client/professional` caption persists; counterparty actions disabled with explanatory captions (not silent hides) so `PLT004` paths stay unreachable by accident yet tested.
- **Sum/expiry honesty:** linkage preview shows `Σ milestones vs total` + currency before fund; unbalanced never reaches RPC in happy path but `PLT003` path tested fail-closed.
- **Disputed freeze legibility:** banner + frozen chip + `Filing freezes escrow` / `Withdrawing unfreezes` copy reused from dispute screens; all mutation CTAs null-disabled.
- **Error translatability:** `PLT003→inline`, `PLT004→404`, `PLT005→guidance card` (unverified/disputed/double-release/expired), `PLT001/002→re-login/support`, `EscrowWriteUnavailable→support card with `Contact support``. Preserve `?next=` on auth redirects.
- **Accessibility/responsive:** 48dp targets, semantic labels on release rows, web path URLs via existing `pathUrlStrategy`; timeline sidebar on tablet+.

## 14. Security Considerations

| Consideration | Approach | Verification |
|---|---|---|
| Zero client authorization | Release authorized only in RPC/proxy (`SECURITY INVOKER` verify + `service_role` fund movement); orchestrator holds no amounts/status math for settlement | Static grep: no `held-available` arithmetic in orchestrator; `dart analyze` + forbidden-pattern scan |
| Verify-before-release | Contract-linked release path requires `verified` (or expired `completed+7d`) else `PLT005` | pgTAP `028`: `pending/completed-unexpired → PLT005`; `verified → PLT000` |
| Disputed freeze | Pre-flight + cron + `financial_escrow_release:923` all reject `disputed`; `dispute_place_escrow_hold` is sole freezer | E2E: file dispute → release returns `PLT005` blocked |
| Stranger oracle | Participant-only `get`; foreign/unknown identical `PLT004` | `028` stranger matrix |
| Evidence traversal | Unchanged (`service-listing-media/{auth.uid()}/%` + storage RLS) — orchestrator never handles bytes | `026` foreign-prefix `PLT003` regression |
| Idempotency / double-release | `uuid v4` key + `(contract,milestone,action)` dedupe + `FOR UPDATE`; second release `PLT005` no-op | Concurrent-release pgTAP + integration double-tap test |
| PII / audit | `PiiRedactor` suffix-only; every mutation → `financial_transactions` pair + `financial_audit_trail` + `contract_events` atomically | Ledger-row assertions in E2E |
| No `SECURITY DEFINER` sprawl | New RPC `SECURITY INVOKER` + proxy `service_role`; posture `prosecdef == 0` for `service_contract_*` | `027` posture suite |

## 15. Performance Considerations

- Keyset pagination unchanged (`list_mine` 20/100); orchestrator operates per-milestone, never bulk-fetches; `get` single-query projection (contract + milestones + events) + `escrow_get` — no N+1 (2 RPCs per release cycle + 2 re-reads).
- Cron uses partial index `WHERE released_at IS NULL AND expires_at < now()` + `SKIP LOCKED`; sweep bounded (`LIMIT 100` per tick).
- Volatility: `STABLE` reads cacheable; `VOLATILE` writes only.
- Realtime excluded for new tables/columns (guard replicated); polling only via explicit refresh + notification tap.
- Target: release cycle p95 <800ms on staging (2× `get` + proxy + 2× re-read); search/discovery p95 unaffected; measured in `EP-03-20`, not this task.

## 16. Testing Strategy

| Layer | Tests (mirror existing patterns) |
|---|---|
| pgTAP `027` posture (`plan ~25`) | Tables/column `review_period_expires_at`, `service_contract_link_escrow` exists + `service_role`-only, `authenticated 0` on write path, Realtime 0, grants/comments |
| pgTAP `028` enforcement (`plan ~60`) | Linkage: stranger `PLT004`, sum-mismatch `PLT003`, duplicate link `PLT005`; Release: `pending→PLT005`, `completed-unexpired→PLT005`, `verified→PLT000` ledger+balances+audit deltas, `disputed→PLT005`, double-release `PLT005` no-op, expiry cron path (`completed+7d→released`), `sum == total` invariant |
| Unit (orchestrator/service) | `contract_escrow_orchestrator_test`: pre-flight matrix (unverified/disputed/unfunded/write-off/stranger), sequencing (verify→release→re-read), idempotency-key uniqueness, `expired` derivation from server timestamps, PII-log redaction; `escrow_service_test` + `contract_service_test` regression |
| Widget | Detail escrow section: linked vs `NULL` vs `disputed` vs write-unavailable vs countdown vs released captions; role-gating (client sees `Verify & Release`, professional sees `Mark complete`, stranger sees empty); theme-token assertion (no `Colors.*`/hex/`fontFamily`) |
| Integration (RPC seam, Dev/Staging) | `escrow_funded 30000 → milestone_completed 10000 + client verify → release → payee available +10000, payer held −10000, financial_transactions escrow_release row, no conversion row`; `disputed` verify blocked; expiry auto-release via cron trigger; malformed link `PLT003`; stranger `PLT004`; pagination no-overlap |
| Static | `dart analyze`, `flutter test`, `flutter_lints:6.0.0`; forbidden greps: no `from('service_contracts'/'financial_escrow').insert/update`, no direct `rpc('financial_escrow_release'/'refund'/'milestone_complete')` in `lib/` outside proxy seam, no `Colors.`/hex, no client ledger reduce for settlement |

No `025/026/013/014` modification — regression run only.

## 17. Recommended Implementation Sequence

1. **Migration `service_contract_escrow_linkage.sql`** (column + linkage RPC + gate + grants/comments) — establishes server truth.
2. **`027` posture pgTAP** → `supabase db reset --local` → green.
3. **`028` enforcement pgTAP** (linkage + verify-gate + disputed + expiry precondition; cron path simulated via `service_role` call) → green.
4. **Edge Function `escrow_milestone_auto_release`** + local `supabase functions serve` + cron schedule on staging → expiry E2E on seeded `completed+8d` fixture.
5. **Orchestrator + state (S3)** + unit tests with extended fakes.
6. **Provider/DI extension (S4)** + router deep-link test (`?next=` preserved).
7. **Contract-detail escrow UI (S5)** + adapter release-state + widget + token tests + goldens (mobile + web).
8. **Notification types (S6)** + foreground/background tap test.
9. **Full integration pass** (ledger E2E matrix on Dev) + `dart analyze` + `flutter test` + static-grep gates.
10. Handoff to `EP-03-16/17/18` (earnings/dispute/notifications consume linkage + events without rework).

## 18. Expected Outcome

A funded contract's verified milestones convert to payee `available_balance` atomically — `professional marks completed + evidence → client verifies (or 7d expires) → held→available + ledger + audit + contract_events` — while `disputed` contracts cannot release, strangers cannot observe, and the write-proxy seam stays honest. Phase Plan acceptance holds: `escrow_funded 30000 → milestone 10000 verified → available +10000 / held −10000 + escrow_release row`; `disputed → PLT005`; expiry auto-releases via cron.

## 19. Definition of Done (DoD)

- [ ] Linkage migration + auto-release function deployed on isolated Dev (`ENV-002/008`); `027/028` pgTAP green; `013/014/025/026` regression green.
- [ ] `contract_escrow_orchestrator.dart` + state landed under `ARCHITECTURE.md lib/` schema (no top-level dirs, no `lib/ai/*`, no hardcoded colors/fonts); all fund movement via `EscrowService`/proxy — grep-clean of direct write-RPC calls.
- [ ] `escrow_id`/`escrow_milestone_id` backfilled on fund; `review_period_expires_at` set on complete; `verified`-or-expired gate enforced server-side (`pending/unexpired → PLT005` tested).
- [ ] `disputed` blocks verify-release on both pre-flight and cron (`PLT005` tested); `EscrowDisputeBanner` + null-disabled CTAs verified in widget tests.
- [ ] Contract-detail escrow section green (linked/pending/disputed/write-off/countdown/released) with `MilestoneListCard` reused verbatim via adapter (no fork).
- [ ] E2E ledger test green (balances + `financial_transactions` + `financial_audit_trail` + `contract_events` deltas asserted; no conversion row).
- [ ] Notification types fire with correct deep links (`/contracts/:id`, `/finance/escrow/:id`); disabled-permission path shows guidance.
- [ ] `dart analyze` + `flutter test` clean; `flutter_lints` clean; `VISUAL-IDENTITY` token asserts pass.
- [ ] `EP-03-16/17/18` can consume linkage + events without modification (interface review sign-off).
- [ ] Docs: plan handoff note only (no final feature docs — forbidden in plan mode).

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: Extremely High**
- **Reasoning Level Justification:** Matches the approved Phase Plan matrix (`EP-03-11: Planning Extremely High / Coding Extremely High`, §12–13 — one of 5 `Extremely High` items). Rationale: **technical complexity Extremely High** (cross-system sequencing across 2 state machines + nullable linkage backfill + `service_role` proxy seam + cron idempotency + `FOR UPDATE SKIP LOCKED`); **business impact Critical** (sole held→available path — first-revenue gate); **security risk Extremely High** (fund misrelease on unverified/disputed milestone = irreversible financial loss; stranger oracle + evidence-prefix + proxy-only writes must all hold); **performance sensitivity High** (release cycle + cron sweep bounded, no N+1); **data complexity Extremely High** (exact `numeric` sums, multi-currency, double-entry + audit + events atomicity); **integration complexity Extremely High** (touches contracts, escrow, disputes, storage, notifications, router, earnings — 6 downstream consumers). `Very High` would underweight the irreversible-ledger + verify-gate + expiry-cron surface; `High`/`Medium`/`Low` would be unsafe for fund-movement code.

---

**Awaiting your approval to proceed to implementation on exit from plan mode.**
