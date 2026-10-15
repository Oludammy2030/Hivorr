# Task Implementation Plan — EP-03-16 (as-requested) / Structured Dispute Resolution for Service Engagements

> **ID anomaly — approval required:** You requested `EP-03-16 = Structured Dispute Resolution`. The approved single source of truth `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:411-431` defines `EP-03-16 = Financial Reporting & Earnings Visibility` and `EP-03-17 = Structured Dispute Resolution for Service Engagements` (§11, roadmap `§12:487-488`). This plan implements the **dispute content (§11 EP-03-17 objective)** under your requested `EP-03-16` label. Confirm whether to renumber to `EP-03-17` on approval. No phase document modified. No production code written.

## 1. Task Objective

Extend the frozen `EP-02-05/EP-02-17` dispute framework to service engagements: bind `dispute_cases` to `service_contracts` (in addition to the existing `escrow_id` link) via a new nullable `contract_id` FK and a contract-scoped filing RPC `service_dispute_file(p_contract_id, ...)`, reusing the same escrow-freeze enforcement (`financial_escrow.status='disputed'` via existing `SECURITY DEFINER` helpers). Deliver contract-first filing, evidence, tracking, frozen-contract UX, and resolve/withdraw unfreeze, without duplicating dispute vocabulary, storage, notification, or escrow logic.

Phase-plan source: `EP-03 Two-Party Transaction Engine & Professional Services Platform.md:422-431`.

## 2. Business Problem Being Solved

Current dispute system is escrow-only and cannot serve service engagements:

- `dispute_cases.escrow_id NOT NULL` (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:56-57`): unfunded contracts (`service_contracts.escrow_id NULL` until `EP-03-11` links, `supabase/migrations/20260923090001_service_contract_schema.sql:49`) cannot be disputed.
- Contract screens already link to disputes but pass the wrong key: `lib/systems/documents/screens/contract_detail_screen.dart:309,372` calls `RoutePaths.disputesFile(contract.id)` where `RoutePaths.disputesFile(escrowId)` expects an escrow id (`lib/app/router/route_paths.dart:131-133`); also `lib/systems/dashboard/screens/my_jobs_screen.dart:945`, `lib/systems/scheduling/screens/appointment_detail_screen.dart:265`, `lib/systems/finance/screens/contract_earnings_detail_screen.dart:145`. Result is `PLT004` / wrong-freeze confusion.
- No `contract_id → dispute` linkage: dispute detail shows escrow context only (`lib/systems/support/screens/dispute_detail_screen.dart:194-284`), no contract header, milestone context, or `View contract` path.
- No contract-status freeze for unfunded disputes: `service_contracts.status` already reserves `'disputed'` (`20260923090001_service_contract_schema.sql:62`) and verify/close guards block on it (`:599-600,:674-675,:761`), but nothing ever sets it — comment explicitly defers to this task (`:16`).
- Evidence path mismatch: phase plan requires `service-listing-media/dispute/<id>/` with participant-read, but current `StoragePaths.disputeEvidence()` routes to private `credential-documents` owner-only (`lib/core/storage/storage_paths.dart:107-117`, `supabase/migrations/20260830100001_storage_buckets.sql:112-144`), which blocks counterparty preview.

Without this task, service disputes either cannot be filed or freeze the wrong object, and milestone release (`lib/systems/finance/services/contract_escrow_orchestrator.dart:306-319` disputed guard) and contract UX disagree.

## 3. Scope

| In scope | Detail |
|---|---|
| Server linkage | Nullable `dispute_cases.contract_id → service_contracts.id`, partial indexes, trigger to set `service_contracts.status='disputed'` on file and release on `dispute_resolve`/`dispute_withdraw` |
| Filing RPC | `service_dispute_file(p_contract_id, p_dispute_type, p_reason, p_desired_outcome, p_priority)` — resolves `escrow_id` from contract when funded, validates participant, inserts case, calls existing hold helper, emits `contract_events('disputed')` |
| Read extension | `dispute_get`/`dispute_list` return `contract_id` + joined contract summary (status, escrow_id, total, currency); no new read RPC if view-join suffices, else `service_dispute_get` wrapper |
| Client data layer | Extend `DisputeCase` with `contractId`, DTOs/mappers, `DisputeRemoteDataSource.fileServiceDispute`, repository pre-validation, provider `fileForContract` |
| Contract-scoped UI | `DisputeFilingScreen` accepts `contractId` (resolves escrow via `ServiceContractProvider`/`ContractService`), contract context header, `DisputeDetailScreen` contract card + `View contract`/`View escrow`, `ContractDetailScreen` corrected to file by contract |
| Evidence | Participant-readable path under `service-listing-media/dispute/<caseId>/` with storage policies; reuse `StorageService.upload` + signed-URL preview |
| Freeze UX | Reuse `EscrowFrozenBanner` / `EscrowDisputeBanner`; hide milestone verify/release/close/book actions when `contract.isDisputed` (already partially done in `contract_detail_screen.dart:449-451,507-510,568`) |
| Notifications | `dispute_filed/resolved` events via existing `lib/core/notifications/*` with deep links `/support/disputes/:id`, `/contracts/:id` |
| Admin visibility | Filtered queue inside existing Admin shell reusing `EP-02-11` review-gate pattern; no new admin console |
| Tests | pgTAP posture + enforcement, unit/widget/integration per § Testing |

## 4. Out of Scope

- Modifying frozen financial ledger (`financial_transactions`, `financial_balances`, `financial_audit_trail`), escrow math, or `dispute_resolve` amounts — `service_role`-only remains.
- Wrapping/calling `dispute_resolve` from client; admin resolution decision UI (display only).
- New storage bucket; modifications to `StorageService`/`StorageConfig` limits; new payment rails/currencies.
- Appeal/escalation workflow, SLA timers, auto-escalation.
- AI ranking/ordering, local-commerce (`product_listings`), logistics 3-party split, B2B modules.
- Public SEO routes for disputes (private support flow).

## 5. Existing Asset and Dependency Analysis

Inspected:

| Asset | Location | Relevance |
|---|---|---|
| Dispute schema + RPCs | `supabase/migrations/20260829120005_dispute_resolution_schema.sql:54-184`, `20260829120006_dispute_withdraw_definer.sql:19-110` | 4 tables, 5 client RPCs, hold helpers, one-open-per-escrow index `:99-101`, envelope `{success,code,message,data}` |
| Dispute client | `lib/data/datasources/remote/dispute_remote_data_source.dart:13-46`, `lib/data/entities/dispute_case.dart:12-82`, `lib/data/repositories/dispute_repository.dart:5`, `lib/systems/support/services/dispute_service.dart:24-196`, `lib/systems/support/support.dart:1-19`, screens `lib/systems/support/screens/dispute_filing_screen.dart:26-108`, `dispute_detail_screen.dart:24-191`, widgets `dispute_status_badge`, `evidence_attachment_card`, `escrow_frozen_banner` | Full escrow-dispute vertical slice to extend, not duplicate |
| Contract engine | `supabase/migrations/20260923090001_service_contract_schema.sql:43-161`, `lib/data/entities/service_contract.dart:17-146` (`isDisputed:105`, `isTerminal:108`) | Lifecycle, `disputed` guard rails already present, `escrow_id` nullable `:49` |
| Escrow linkage + gate | `supabase/migrations/20261006090001_contract_escrow_linkage.sql:76-350` (`service_contract_link_escrow`, `service_contract_release_gate`) | Funded-state truth, `disputed` blocks linkage `:123-125` and release `:266-308` |
| Release orchestrator | `lib/systems/finance/services/contract_escrow_orchestrator.dart:280-387` | Fail-closed `disputed → blocked` projection already mirrors server gate; reuse |
| Contract UI | `lib/systems/documents/screens/contract_detail_screen.dart:448-569` | Already hides writes when `disputed`, shows `EscrowDisputeBanner`; needs correct filing key |
| Storage | `lib/core/storage/storage_config.dart:16,26`, `storage_paths.dart:65-169`, `supabase_storage_service.dart:40-41`, buckets `20260830100001_storage_buckets.sql:46-144` | `credential-documents` private owner-only vs `service-listing-media` public-read pattern; only path helper + policies needed |
| Notifications | `lib/core/notifications/channels/notification_channel_manager.dart`, `services/notification_service.dart`, `providers/notification_provider.dart` | Existing channels; consume `dispute_filed/resolved`, no new channel |
| Router | `lib/app/router/route_paths.dart:127-136` | `disputes`, `disputesNew=/support/disputes/file/:escrowId`, `disputeDetail`, `disputesEvidenceNew`; needs contract-scoped variant |
| Review/scheduling seams | `lib/systems/reviews/widgets/contract_review_section.dart`, scheduling entry in contract detail | Must respect `disputed` (no review/reveal or booking on frozen contracts — server `PLT005`) |

Dependencies: `EP-02-05` (frozen dispute schema), `EP-03-02` (contract schema), `EP-03-11` (escrow linkage/gate), `EP-02-06/EP-02-08` (storage), `EP-01-18` (notifications), `EP-01-16` (design tokens), `EP-01-07` (API/`BaseApiService`).

## 6. Reuse / Extension / Refactoring Assessment

| Proposed asset | Verdict | Why |
|---|---|---|
| `dispute_cases`, `dispute_evidence`, `dispute_resolutions`, `dispute_audit_trail` tables, vocab CHECKs, `dispute_place/release_escrow_hold` helpers, `dispute_submit_evidence/get/list/withdraw/resolve` | **Reuse** | Frozen and proven; new task adds only a nullable FK + trigger, zero CHECK changes. Duplicating tables would create parallel dispute systems. |
| `service_dispute_file` RPC | **New (thin wrapper)** | No suitable existing RPC accepts `contract_id`; `dispute_file` requires `p_escrow_id` non-null. Extension of `dispute_file` signature would break frozen contract; a thin wrapper that resolves `escrow_id` from `service_contracts.escrow_id` and delegates to the same hold helper preserves single enforcement point. Designed reusable: future `job/hire` engagements can add their own thin filer over the same core. |
| `contract_id` column + `disputed` trigger on `service_contracts` | **Extend** | `status='disputed'` enum + guards already exist; only the setter is missing (explicitly deferred). `ALTER ... ADD COLUMN IF NOT EXISTS` + trigger is additive, no prior DDL touched. |
| `DisputeCase`, DTOs, `DisputeMapper`, `DisputeRemoteDataSource`, `DisputeRepository`, `DisputeProvider`, `DisputeService` vocab/validators | **Extend** | Add optional `contractId` field + `fileServiceDispute({contractId,...})`; keep all vocab/validators byte-identical to frozen CHECKs. Refactor to a parallel service would duplicate validation and envelope parsing. |
| `DisputeFilingScreen`, `DisputeDetailScreen`, `DisputeStatusBadge`, `EvidenceAttachmentCard`, `EscrowFrozenBanner`, `EscrowDisputeBanner`, `BalanceFormatter`, `ContractStatusBadge`, `MilestoneListCard` | **Extend/Reuse** | Filing screen gains contract-mode (contract header + escrow resolution); detail gains contract card; badges/banners/formatters reused as-is. No new design language. |
| `RoutePaths.disputesFile` | **Extend** | Add `disputesFileForContract(contractId)` → `/support/disputes/file-by-contract/:contractId` alongside existing escrow route; fix the 4 mis-wired call sites to use it. No parallel route tree. |
| Evidence storage path | **Extend** | Add `StoragePaths.serviceDisputeEvidence(caseId,fileName)` under existing `service-listing-media` + participant-read storage policies (mirror `portfolio-items` public-read/owner-write pattern, scoped to `dispute/<caseId>/`). Reuses `StorageService.upload/createSignedUrl`, `StorageConfig` MIME/size. New bucket would fragment media governance. |
| Notifications, `PerformanceTracer`, `PiiRedactor`, `HivorrLogger` | **Reuse** | Existing channels/spans/redaction cover dispute events; only new event names + deep-link payloads. |

No new system, module, top-level `lib/` directory, ledger, or ranking logic proposed.

## 7. Recommended Technical Approach

1. **Server (additive migration `YYYY_service_dispute_contract_link.sql`):** `ALTER dispute_cases ADD contract_id NULL FK service_contracts(id) ON DELETE RESTRICT`; `CREATE INDEX dispute_cases_contract_idx(contract_id)` + partial open-per-contract index; trigger `service_contract_set_disputed_on_file()` (`AFTER INSERT ON dispute_cases FOR EACH ROW WHEN NEW.contract_id NOT NULL → UPDATE service_contracts SET status='disputed'` + `contract_events('disputed')`); trigger on `dispute_resolve`/`withdraw` to clear `disputed → active` (or `completed` per milestone state — read-only restore to pre-dispute status stored in `metadata`). All `SECURITY INVOKER` except reuse of existing `DEFINER` hold helpers; `REVOKE ... FROM anon`, `GRANT EXECUTE service_dispute_file TO authenticated`.
2. **`service_dispute_file(p_contract_id, p_dispute_type, p_reason, p_desired_outcome, p_priority)`:** authenticate → load contract `FOR UPDATE` (participant check `client/professional` else `PLT004` to avoid oracle) → reject `disputed/closed/cancelled` with `PLT005` → derive `escrow_id` (null if unfunded) → if funded, require escrow `funded/partially_released` else `PLT005`, compute counterparty from contract participants → `INSERT dispute_cases(escrow_id NULL-ok, contract_id, ...)` with `unique_violation → PLT005` → if `escrow_id NOT NULL`, `perform dispute_place_escrow_hold(escrow_id)` → audit + `platform_audit_log_add` → return envelope. Unfunded filing freezes contract only; funded filing freezes both (single transaction).
3. **Reads:** extend `dispute_get` response shape (or thin `service_dispute_get` if frozen function cannot change) to include `contract:{id,status,escrow_id,total_amount,currency_code,listing_title}` via join; `dispute_list` adds optional `p_contract_id` filter with participant check.
4. **Client data:** `DisputeCase.contractId (String?)`; DTO `contract_id` nullable passthrough; mapper null-safe; `DisputeRemoteDataSource.fileServiceDispute({required contractId,...})` via `supabase.rpc('service_dispute_file')`; repository pre-validates reason/type/outcome/priority identically + `contractId` non-empty; provider `fileForContract` → re-`select` for authoritative state; `ServiceContractProvider` refresh on file/resolve.
5. **UI:** filing screen contract mode — load contract, show listing title/total/`ContractStatusBadge`/escrow chip, same validators/counters, submit → `fileForContract` → push `disputeDetail`; detail screen — contract card (`View contract → /contracts/:id`, `View escrow → /finance/escrow/:id` when funded), frozen banner when `contract.isDisputed || escrow.status=='disputed'`; contract detail — switch `onFileDispute` to `disputesFileForContract(contract.id)`, keep write-hiding logic.
6. **Storage:** `service-listing-media/dispute/<caseId>/<sanitized>` via new `StoragePaths` helper; storage RLS: participant-read (contract parties + service_role) + owner-write; upload-before-`dispute_submit_evidence` flow unchanged; signed-URL preview.
7. **Notifications:** emit `dispute_filed` (both parties + deep link) and `dispute_resolved/withdrawn` (one-shot local + push) through `NotificationService`; no new channel; PII-redacted payloads.

## 8. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Migration + `service_dispute_file` + triggers + indexes + grants | `supabase/migrations/*_service_dispute_contract_link.sql` + pgTAP `supabase/tests/database/*_service_dispute_*.sql` | Create (additive only) |
| `DisputeCase.contractId`, `DisputeCaseDto.contract_id`, mapper | `lib/data/entities/dispute_case.dart`, `lib/data/models/dispute_case_dto.dart`, `lib/data/mappers/dispute_mapper.dart` | Extend |
| `DisputeRemoteDataSource.fileServiceDispute` + impl + envelope reuse | `lib/data/datasources/remote/dispute_remote_data_source.dart`, `supabase_dispute_remote_data_source.dart`, existing `dispute_envelope_parser.dart` | Extend (no new envelope shape) |
| `DisputeRepository.fileServiceDispute` + impl | `lib/data/repositories/dispute_repository*.dart` | Extend |
| `DisputeProvider.fileForContract` + contract refresh hook | `lib/data/providers/dispute_provider.dart` | Extend |
| Filing/detail screens + contract card | `lib/systems/support/screens/dispute_filing_screen.dart`, `dispute_detail_screen.dart` | Extend |
| Routes | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart` | Extend (`file-by-contract/:contractId`) + fix 4 call sites |
| Storage path + policies | `lib/core/storage/storage_paths.dart` + storage migration policies | Extend |
| Banners/badges/formatters | existing `escrow_frozen_banner.dart`, `escrow_dispute_banner.dart`, `dispute_status_badge.dart`, `balance_formatter.dart` | Reuse |
| Notifications wiring | `lib/core/notifications/*` + `supabase/templates/*` if used | Reuse/extend payloads |

## 9. Data Requirements

- `dispute_cases.contract_id NULL FK`; either `escrow_id` or `contract_id` non-null (CHECK); one-open-per-contract partial unique index mirroring `dispute_cases_one_open_per_escrow_idx`.
- `DisputeCase.contractId` nullable; unfunded cases carry `escrowId=null` until `service_contract_link_escrow` backfills escrow, then `dispute_cases.escrow_id` backfilled by resolve/withdraw trigger or left null with contract as anchor (decide in implementation: backfill on fund if open dispute exists — must not violate one-open-per-escrow).
- Evidence/resolution/audit shapes unchanged; `file_url` now points at `service-listing-media` dispute prefix for service cases (old `credential-documents` rows remain valid).
- `contract_events` gains `disputed` rows for the freeze/unfreeze transitions (already in allowed `event_type` list).

## 10. Database Considerations

- Additive-only: no `ALTER` on frozen tables beyond new nullable column + indexes + triggers; no CHECK vocabulary change; no new `SECURITY DEFINER` (reuse existing hold helpers); `REVOKE ... FROM anon`, narrow `GRANT` to `authenticated`.
- RLS: `dispute_cases` participant policy extended to `filer/counterparty OR contract participant`; `service_contracts` RLS unchanged (participant-scoped); storage policies participant-scoped for `dispute/*` prefix; Realtime excludes dispute tables (unchanged).
- Concurrency: `FOR UPDATE` on contract + escrow rows inside `service_dispute_file`; `unique_violation → PLT005` for double-file race; `service_contract_release_gate` already returns `eligible:false reason:disputed` so release is fail-closed.
- Idempotency: filing carries client `Idempotency-Key`/dedup via existing one-open indexes; evidence dedup unchanged.

## 11. API Requirements

| RPC | Params | Auth | Envelope |
|---|---|---|---|
| `service_dispute_file` (new) | `p_contract_id, p_dispute_type, p_reason, p_desired_outcome?, p_priority='medium'` | `authenticated` participant | `PLT000 + case` / `PLT001/003/004/005/999` matching `dispute_file` vocabulary |
| `dispute_submit_evidence/get/list/withdraw` | unchanged (+ `contract_id` in data) | unchanged party-scoped | unchanged |
| `dispute_resolve` | unchanged | `service_role` only — never called from client (grep lens) | unchanged |
| Storage | `upload` + `createSignedUrl` on `service-listing-media/dispute/...` | participant RLS | existing `StorageService` errors |

Error mapping via `ApiExceptionMapper` preserves `PLT003→validation` (inline), `PLT004→notFound` (identical empty state for foreign/unknown ids — no oracle), `PLT005→conflict` ("An active dispute already exists for this contract/escrow."), `PLT001→auth` (login redirect).

## 12. User Interface Requirements

- Filing (`/support/disputes/file-by-contract/:contractId`): contract header (title, total via `BalanceFormatter`, `ContractStatusBadge`, escrow chip or `Funding pending`), type selector (5), reason `TextField(maxLines:6, maxLength:2000)` + live counter + `DisputeService.validateReason`, outcome optional, priority default `medium`, submit `HivorrButton ≥48dp`; pre-disabled with conflict banner when contract already `disputed`.
- Detail (`/support/disputes/:id`): existing header/reason/evidence/resolution/withdraw + new contract context card; `View contract` / `View escrow` (conditional on funded); `Add evidence` only when `acceptsEvidence`; withdraw only `open + filer` with confirm dialog.
- Contract detail: `EscrowDisputeBanner` when `disputed` (already present) with `onViewDispute` routing to the open case; `ContractWriteCtaPanel` hides accept/complete/verify/revision/close (`writeAvailable` already `!disputed && !isTerminal`) and `onFileDispute` hidden when `disputed`.
- All screens: `HivorrContentPane` (16dp mobile/24dp web), `HivorrCard`, `HivorrEmptyState/LoadingState/ErrorState/SuccessState` + `HivorrLoader` pulse, `Theme.of(context).colorScheme/textTheme/AppThemeExtension` only — zero `Colors.*`/hex/`fontFamily` per-widget per `AGENT.md:18`.

## 13. User Experience Considerations

- **Contract-first, never type an id:** entry from contract detail / hires / appointments / earnings drill-down; escrow resolved server-side so unfunded contracts work.
- **Immediate freeze confirmation:** "This contract is now frozen — milestones, releases, bookings and reviews are paused until resolved."
- **Hidden, not dead, actions:** frozen controls removed with banner explanation; no disabled-without-reason buttons.
- **Fail-fast:** reason/title/description/MIME/size validated client-side before RPC; upload-before-evidence-RPC staging with retry preserving typed fields.
- **Transparency:** immutability note, `***last4` refs (never full legal names), amounts via `BalanceFormatter` with currency code, full reasoning shown read-only on resolution.

## 14. Security Considerations

- Server-authoritative per `AGENT.md:16` Rule 4: no REST DML on dispute/contract tables; status columns server-controlled; client mirrors freeze only.
- `service_role` boundary absolute: `grep -r "service_role" lib/ = 0` for new code; `grep -rn "dispute_resolve" lib/ = 0`; `dispute_resolve` stays `service_role`-only.
- Party-scoping + `PLT004` parity (no participant/oracle leak); RLS default-deny; evidence/resolutions immutable (no edit/delete affordances).
- PII: `HivorrLogger + PiiRedactor` (ids `***last4`, never full reason/description/title/counterparty name); amounts never logged raw; signed-URL TTLs validated; MIME/size enforced pre-upload.
- `ENV-001..010` isolation: per-env Supabase URL/keys; no cross-env reads.

## 15. Performance Considerations

- `dispute_get` single PK + indexed evidence join + contract join (add covering index `dispute_cases(contract_id, status)`); `dispute_list` uses existing filer/counterparty/status indexes + new contract index; `STABLE` reads; keyset pagination unchanged.
- Provider memoizes case + evidence + resolution + contract summary; 1 RPC per detail visit; `refresh()` re-reads selection only; `pausePolling/resumePolling` via `WidgetsBindingObserver`; no `Timer.periodic`.
- Evidence upload single transfer with progress callback; signed URLs lazy, never eager for list rows; const vocab lists, no per-build allocation; `PerformanceTracer` spans `support.dispute.file-service/get/list` sampled, no PII.

## 16. Testing Strategy

- **pgTAP:** posture (column/FK/indexes exist, `authenticated` EXECUTE on `service_dispute_file`, `anon` denied, no new DEFINER, RLS enabled) + enforcement (unauth `PLT001`; non-participant `PLT004`; bad type/reason `PLT003`; unfunded file → contract `disputed`, escrow null, verify blocked `PLT005`; funded file → both `disputed`, release gate `disputed`; double-file `PLT005`; withdraw → unfreeze both; resolve (service_role) → ledger + audit rows).
- **Unit (`test/unit/...`, no live Supabase):** remote data source (new method + envelope + error-code parity + no-resolve assertion), repository pre-validation, provider `fileForContract`/refresh/lifecycle, mapper null-`contract_id`/`escrow_id` safety, `DisputeService` vocab/validators (100% on mappers/service/parser).
- **Widget:** filing contract-mode (header, counter, pre-disabled on `disputed`, success → detail), detail contract card + banner visibility matrix, badge/banner token assertions (`grep Colors. = 0`), 320–600+ overflow checks.
- **Integration (fake-E2E):** offer → accept → fund → `fileServiceDispute` → assert both frozen → milestone verify blocked → evidence submit → withdraw/resolve → assert unfrozen + ledger correct. Live `supabase db test` is RLS source of truth; `flutter analyze` + `flutter test` green; RLS leak matrix 0 leaks.

## 17. Recommended Implementation Sequence

1. Migration + `service_dispute_file` + triggers + grants (unblocks all).
2. pgTAP posture + enforcement (prove freeze before any client consumes it).
3. Storage path helper + participant policies.
4. Data layer extension (entity → DTO → mapper → remote → repository → provider) + unit tests.
5. Routes + filing/detail contract UI + call-site fixes + widget tests.
6. Contract-detail freeze wiring verification + orchestrator guard confirmation (no orchestrator change expected).
7. Notifications payloads + integration test + `dart analyze`/`flutter test`/grep lenses.

## 18. Expected Outcome

A contract-anchored dispute path where any participant files from a contract (funded or not), the contract (and escrow when present) atomically freezes, milestone verify/release/close/booking/review pause with clear banner guidance, evidence accumulates participant-readably, and withdraw/admin-resolve atomically unfreezes with ledger/audit integrity — reusing the EP-02 dispute trust core without a parallel system, and unblocking `EP-03-20` validation point 12.

## 19. Definition of Done (DoD)

- [ ] Migration additive, `supabase db reset` green, Staging promoted per `ENV-007`; no frozen-table DDL beyond approved additive objects.
- [ ] Funded file → `service_contracts.status='disputed'` + `financial_escrow.status='disputed'`; unfunded file → contract `disputed`, escrow null; verify/release/close/link all return `PLT005` while disputed (SQL evidence attached).
- [ ] `service_dispute_file` envelope + error-code parity proven by pgTAP; `anon` zero `EXECUTE`; `dispute_resolve` absent from client (grep lenses `= 0`).
- [ ] Client reads/writes flow only through approved RPCs; no REST DML on dispute/contract tables; no client settlement math.
- [ ] Filing/detail contract context renders; 4 mis-wired `disputesFile` call sites fixed; frozen UX hides (not dead-ends) actions; deep links land (`/support/disputes/:id`, `/contracts/:id`, `/finance/escrow/:id`).
- [ ] Evidence round-trips via `service-listing-media/dispute/...` with participant preview; MIME/size enforced; private-bucket public-URL path never used.
- [ ] `flutter analyze` clean, `flutter test` green, RLS leak matrix 0 leaks, token assertions pass, `EXPLAIN` shows index usage, p95 detail/file <400ms on Staging.
- [ ] Project-lead marks `Completed` only when all boxes evidenced; otherwise `In Progress` with follow-ups.

## 20. Implementation AI Execution Profile

- **Recommended Coding Reasoning Level: Very High**
- **Justification:** Matches approved phase-plan rating for service-engagement disputes (`EP-03 §13: Very High`). High integration complexity (contract ↔ escrow ↔ dispute triple-state with nullable-escrow branch), high security risk (freeze bypass or wrongful unfreeze = direct fund loss / settlement divergence), and data complexity (dual-anchor invariant, backfill on fund, participant RLS across three tables + storage). Falls short of `Extremely High` because no new financial ledger, ranking formula, or double-blind invariant is invented — the money-movement and trust invariants are reused, and the new RPC is a thin contract-scoped filer over proven hold helpers.

*Planning artifact only. Awaiting your approval (including the EP-03-16 vs EP-03-17 numbering decision) before any implementation.*
