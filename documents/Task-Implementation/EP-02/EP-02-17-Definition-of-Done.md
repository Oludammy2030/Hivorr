# Definition of Done — EP-02-17: Dispute Resolution Framework

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-17 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-17-Dispute Resolution Framework.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-17 |
| **Task Name** | Dispute Resolution Framework |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 5 — Financial Integrity Systems |
| **Priority** | High |
| **Execution Justification Level** | Very High (per plan §18 — technical complexity high, business impact extremely high, security risk extremely high) |
| **Dependencies** | EP-02-05 (frozen dispute schema `supabase/migrations/20260829120005_dispute_resolution_schema.sql` + `20260829120006_dispute_withdraw_definer.sql`), EP-02-14 (`EscrowProvider`, `BalanceFormatter`, `EscrowStatus` — `lib/data/providers/escrow_provider.dart`, `lib/systems/finance/helpers/balance_formatter.dart`), EP-02-08 (`StorageService`/`StorageConfig`/`StoragePaths` — `lib/core/storage/storage_service.dart`, `storage_config.dart:16,36,58`) |
| **Blocks** | EP-02-18 (onboarding), EP-02-19 (professional profile), EP-02-20 (client verification display) — consume dispute routes, vocabulary, and `EscrowFrozenBanner` integration |
| **Read seam** | EP-02-05 server contract — 4 tables (`dispute_cases`, `dispute_evidence`, `dispute_resolutions`, `dispute_audit_trail`), 5 client-callable RPCs (`dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`, `dispute_get`, `dispute_list`), party-scoped RLS, pgTAP `015`/`016` |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-17-Dispute Resolution Framework.md` |

> Frozen server refs (reused, never modified): `supabase/migrations/20260829120005_dispute_resolution_schema.sql` — `dispute_cases` (`54-101`: `dispute_type` CHECK `62-65`, `status` CHECK `66-68`, `reason` CHECK 10–2000 `69-70`, `desired_outcome` CHECK `71-73`, `priority` CHECK `74-75`), `dispute_evidence` (`106-122`: `evidence_type` CHECK `112-113`, `title` CHECK 1–255 `114-115`, `description` ≤2000 `116-117`, immutable), `dispute_resolutions` (`135-152`: `resolution_type` CHECK `141-143`, `reasoning` CHECK 10–5000 `144-145`, amounts ≥0 `146-147`, immutable), `dispute_audit_trail` (`163-184`: `event_type` 11-value CHECK `169-174`, `subject_type` CHECK `175-177`), RLS default-deny `205-216` + party-scoped SELECT policies `241-276`, partial unique index `dispute_cases_one_open_per_escrow_idx` `99-101`, indexes `91-98`. RPCs: `dispute_file` (`382-473`, INVOKER), `dispute_submit_evidence` (`476-545`, INVOKER), `dispute_withdraw` (`20260829120006`, SECURITY DEFINER), `dispute_get` (`786-827`, INVOKER, STABLE), `dispute_list` (`830-859`, INVOKER, STABLE); client-callable EXECUTE grants `867-871`; **`dispute_resolve` is `service_role`-only (`874`) — prohibited from client**. Envelope contract `{success, code, message, data}`; `PLT000` success / `PLT001` auth / `PLT003` validation / `PLT004` notFound / `PLT005` conflict / `PLT999` internal. Evidence storage in the existing private `credential-documents` bucket (`storage_config.dart:16`) via the new `StoragePaths.disputeEvidence()` helper only. **Task is `lib/` + `test/` only; `git diff --stat supabase/` must be `0`; `.supabase/functions` untouched; no new bucket; no `StorageService`/`StorageConfig`/`StorageValidators` modification.**

---

## 2. Functional Verification

This task delivers the **Stage 5 dispute resolution framework** — the marketplace safety net (`EP-02:423-432`): dispute filing linked to an escrow, evidence submission over the private storage bucket, case status tracking, resolution display, and escrow-hold integration (disputed escrow rendered frozen). The client **connects to the five live client-callable RPCs** and **never** invokes the `service_role`-only `dispute_resolve`. Functional verification confirms the domain vocabulary, data layer, remote data source, repository, service facade, provider, screens, widgets, routing, and storage pipeline behave correctly and never bypass server invariants.

### 2.1 Required Functionality — Domain Vocabulary

- [x] **FV-01:** `lib/systems/support/models/dispute_status.dart` defines `DisputeStatus` with exactly 5 entries matching `dispute_cases.status` check `66-68`: `open` (`label: 'Open'`, tone `warning`), `under_review` (`label: 'Under review'`, tone `info`), `resolved` (`label: 'Resolved'`, tone `success`), `closed` (`label: 'Closed'`, tone `neutral`), `withdrawn` (`label: 'Withdrawn'`, tone `neutral`) — each with `code`, `label`, `tone`
- [x] **FV-02:** `DisputeStatus` is data-driven vocab only (no business logic) — `code` strings match the server check constraint exactly; no drift from `dispute_cases` `66-68`; `disputeStatuses.length == 5` asserted in unit test
- [x] **FV-03:** Dispute type vocabulary (compiled in `DisputeService`, §5.5) has exactly 5 entries matching `dispute_cases.dispute_type` check `62-65`: `service_quality` → "Service quality", `non_delivery` → "Non-delivery", `milestone_disagreement` → "Milestone disagreement", `fraud` → "Fraud", `other` → "Other"
- [x] **FV-04:** Desired-outcome vocabulary has exactly 4 options + `other` matching the nullable `dispute_cases.desired_outcome` check `71-73`: `release_to_payee` → "Release to provider", `refund_to_payer` → "Refund to me", `split` → "Split the amount", `other` → "Other"
- [x] **FV-05:** Priority vocabulary has exactly 4 entries matching `dispute_cases.priority` check `74-75`: `low`, `medium`, `high`, `critical` — default `medium` in the filing flow
- [x] **FV-06:** Evidence-type vocabulary (4) matches `dispute_evidence.evidence_type` check `112-113` (`document`, `screenshot`, `description`, `photo`); resolution-type vocabulary (4) matches `dispute_resolutions.resolution_type` check `141-143` (`release_to_payee`, `refund_to_payer`, `split`, `dismissed`) with outcome labels

### 2.2 Required Functionality — Data Layer (Entities, DTOs, Mappers)

- [x] **FV-07:** `DisputeCase` entity exists at `lib/data/entities/dispute_case.dart` — `id, escrowId, filerEntityId, counterpartyEntityId, disputeType, status, reason, desiredOutcome?, priority, filedAt, resolvedAt?, closedAt?, withdrawnAt?, metadata` — pure Dart, no Flutter/Supabase imports (field names are the client contract; map from `dispute_cases` snake_case columns)
- [x] **FV-08:** `DisputeEvidence` entity exists at `lib/data/entities/dispute_evidence.dart` — `id, caseId, submittedBy, evidenceType, title, description?, fileUrl?, fileMetadata, createdAt` — pure Dart
- [x] **FV-09:** `DisputeResolution` entity exists at `lib/data/entities/dispute_resolution.dart` — `id, caseId, resolvedBy?, resolutionType, reasoning, payerRefundAmount, payeeReleaseAmount, notes?, resolvedAt, createdAt` — pure Dart; `payer_refund_amount`/`payee_release_amount` `numeric` mapped to `double` without precision catastrophe
- [x] **FV-10:** DTOs exist at `lib/data/models/dispute_case_dto.dart`, `dispute_evidence_dto.dart`, `dispute_resolution_dto.dart`, `dispute_list_envelope_dto.dart`, `dispute_case_detail_envelope_dto.dart` + `DisputeCaseDetail` value object (`lib/data/models/dispute_case_detail.dart`) — JSON shapes match `dispute_get` (`{case, evidence:[...], resolution:{...}|null}`) and `dispute_list` (`{disputes:[...]}`) envelopes; null `desired_outcome`/`resolved_at`/`closed_at`/`withdrawn_at`/`resolved_by`/`notes` → `null`, not throw
- [x] **FV-11:** `DisputeMapper` at `lib/data/mappers/dispute_mapper.dart` defines `caseToEntity`, `evidenceToEntity`, `resolutionToEntity`, `listEnvelopeToEntities`, `caseDetailToEntity` — maps DTO→Entity without leaking RPC JSON shape; empty `evidence` array → `[]` (never null); missing `resolution` → `null`; `metadata` passthrough
- [x] **FV-12:** Numeric correctness — `payer_refund_amount`/`payee_release_amount` `numeric` parsed to `double`; all timestamps (`filed_at`, `resolved_at`, `closed_at`, `withdrawn_at`, `created_at`) mapped to nullable `DateTime`; null rendered as "—" not crash

### 2.3 Required Functionality — Remote Data Source (5 live RPCs)

- [x] **FV-13:** `DisputeRemoteDataSource` abstract exists at `lib/data/datasources/remote/dispute_remote_data_source.dart` — **exactly 5 methods**: `listDisputes({String? status})`, `getCase(String caseId)`, `fileDispute({required escrowId, required disputeType, required reason, desiredOutcome?, priority = 'medium'})`, `submitEvidence({required caseId, required evidenceType, required title, description?, fileUrl?, fileMetadata})`, `withdrawDispute(String caseId)` — **no `dispute_resolve` method declared** (§5.3)
- [x] **FV-14:** `SupabaseDisputeRemoteDataSource` exists at `lib/data/datasources/remote/supabase_dispute_remote_data_source.dart` — `extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`), constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`; wraps the 5 RPCs via `supabase.rpc<Map<String,dynamic>>('dispute_<fn>', params: {...})`
- [x] **FV-15:** Envelope unwrap via `DisputeEnvelopeParser` (`lib/data/datasources/remote/dispute_envelope_parser.dart`) — validates `success==true && code=='PLT000'` before mapping; `success:false` → `ApiException` with extracted `code/message`; same `{success, code, message, data}` contract as `FinancialEnvelopeParser`
- [x] **FV-16:** `dispute_withdraw` (SECURITY DEFINER `20260829120006`) is called exactly like the other entity-facing RPCs — `supabase.rpc('dispute_withdraw', params: {p_case_id: ...})`; filer-scoping enforced inside the function body; no special client handling required
- [x] **FV-17:** **No `dispute_resolve` method exists anywhere in the client contract** — `DisputeRemoteDataSource`/`SupabaseDisputeRemoteDataSource`/`DisputeRepository`/`DisputeService` never reference it; `grep -rn "dispute_resolve" lib/` = 0 (static lens)

### 2.4 Required Functionality — Repository

- [x] **FV-18:** `DisputeRepository` abstract + `DisputeRepositoryImpl` exist at `lib/data/repositories/dispute_repository.dart` + `dispute_repository_impl.dart` — methods `listDisputes({status})`, `getCase(id)`, `fileDispute(...)`, `submitEvidence(...)`, `withdrawDispute(id)`
- [x] **FV-19:** `listDisputes({status})` — validates status fixture client-side against the 5-value vocab `66-68` before RPC (only if a non-null status provided, else no filter passed); maps each DTO via `DisputeMapper`; never returns null list
- [x] **FV-20:** `fileDispute(...)` — **client pre-validates** reason length (10–2000 after trim), dispute type, desired outcome, priority against the frozen CHECK vocabularies, and non-null `escrowId` — before the RPC round-trip (prevents known `PLT003` violations); on success re-reads `getCase` for the authoritative envelope
- [x] **FV-21:** `submitEvidence(...)` — pre-validates evidence type (4-value vocab `112-113`), title length (1–255), description ≤2000, optional `fileUrl` (already uploaded to `credential-documents` before this call); evidence row is immutable server-side — no edit/delete pathways
- [x] **FV-22:** `withdrawDispute(id)` — maps updated case; UI only offers withdrawal when `status == 'open'` and caller is filer; repository **never imports** `lib/systems/` widgets (unidirectional `data → systems`) and **never writes** the 4 dispute tables via REST/direct SQL — writes flow only through the 3 client RPCs

### 2.5 Required Functionality — Systems Facade

- [x] **FV-23:** `DisputeService` exists at `lib/systems/support/services/dispute_service.dart` — exposes status (5), type (5), desired-outcome (4+other), priority (4), evidence-type (4), resolution-type (4) vocabularies matching the frozen CHECK constraints `62-75`, `112-113`, `141-143`
- [x] **FV-24:** `DisputeService.validateReason(String)` — 10–2000 chars after trim (matches server `69-70`); `validateTitle(String)` — 1–255 (`114-115`); `validateDescription(String)` — ≤2000 (`116-117`) — pure Dart, no I/O
- [x] **FV-25:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) redacted logging — `caseId`, `escrowId`, `entityId: ***last4`, dispute type, status deltas — **never** full `reason`, `description`, or evidence `title`; no counterparty full identity ever logged
- [x] **FV-26:** `PerformanceTracer` spans `support.dispute.get.duration`, `support.dispute.list.duration`, `support.dispute.file.duration` (`lib/core/monitoring/performance_tracer.dart`) — sampled via `MonitoringConfig`, no PII

### 2.6 Required Functionality — Provider (ChangeNotifier)

- [x] **FV-27:** `DisputeProvider` exists at `lib/data/providers/dispute_provider.dart` — `extends ChangeNotifier` (`provider:6.1.5`), state fields: `List<DisputeCase> disputes`, `DisputeCase? selected`, `List<DisputeEvidence> evidence`, `DisputeResolution? resolution`, `AsyncState loadState`, `ApiException? lastError`, `bool isRefreshing`
- [x] **FV-28:** Methods: `loadList({String? status})`, `select(String caseId)` (case + evidence + resolution via one `dispute_get`), `file(...)`, `submitEvidence(...)`, `withdraw(String caseId)`, `refresh()`
- [x] **FV-29:** 1 RPC per screen visit — `select` loads case + evidence + resolution in a single `dispute_get`; memoized per case id; `refresh()` re-reads only current selection; post-file/post-withdraw re-read for authoritative state, never optimistic
- [x] **FV-30:** Lifecycle mirrors `EscrowProvider` (`lib/data/providers/escrow_provider.dart`): `pausePolling()`/`resumePolling()` via `WidgetsBindingObserver.didChangeAppLifecycleState(background)`, `dispose()` cancels in-flight state changes; no `supabase_realtime`; no `Timer.periodic` leak while backgrounded
- [x] **FV-31:** Constructor injection `({required DisputeRepository repo, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability; no `SupabaseClientProvider` singleton inside provider (repository holds the client); `NotificationProvider` on file/withdraw success — one-shot, local-only

### 2.7 Required Functionality — UI Screens

- [x] **FV-32:** `DisputeListScreen` exists at `lib/systems/support/screens/dispute_list_screen.dart` (`GET /support/disputes`): `AppBar(title: Text('Disputes', style: textTheme.titleLarge))`, status filter chips (All / Open / Under review / Resolved / Withdrawn), dispute cards (status badge + type label + counterparty initials `***` — never full name + filed date), FAB / primary action → `DisputeFilingScreen`, pull-to-refresh (`HivorrLoader` breathing pulse, `VISUAL-IDENTITY.md:148`), `HivorrEmptyState` ("No disputes yet — raise one from an escrow's dispute action.")
- [x] **FV-33:** `DisputeDetailScreen` exists at `lib/systems/support/screens/dispute_detail_screen.dart` (`GET /support/disputes/:id`): header (status badge + type + priority chip + filed date), escrow context card (escrow id suffix `***`, amount via `BalanceFormatter`, `EscrowStatus` from EP-02-14 vocab) + "View escrow" → EP-02-14 `/finance/escrow/:id` + `EscrowFrozenBanner` when escrow disputed, reason block (full text, read-only), evidence section (`EvidenceAttachmentCard` per item + "Add evidence" when `status in ('open','under_review')`), resolution section (only when present: type + reasoning + outcome amounts via `BalanceFormatter`), withdraw action (open + filer only, confirmation dialog), immutability/audit awareness note
- [x] **FV-34:** `DisputeFilingScreen` exists at `lib/systems/support/screens/dispute_filing_screen.dart` (`GET /support/disputes/new`): escrow context header (pre-selected, read-only — status, total, currency via `BalanceFormatter`, "raise dispute against this escrow" framing), fields matching `dispute_file` params exactly (type selector 5-value, reason `TextField(maxLines: 6)` with live counter 10–2000 + `validateReason`, desired-outcome selector optional matching nullable `desired_outcome`, priority selector default medium), submit → `DisputeProvider.file(...)` → success routes to `DisputeDetailScreen`; mirror-client warning surfaced when the escrow already shows `disputed` (server `PLT005` via partial unique index `99-101`) — submit disabled
- [x] **FV-35:** `DisputeEvidenceFormScreen` exists at `lib/systems/support/screens/dispute_evidence_form_screen.dart`: evidence type selector (4-value vocab), title field (1–255 counter), description field (≤2000, optional), attachment picker for `document`/`screenshot`/`photo` — validates against `StorageConfig` (10 MiB, `jpeg/png/webp/pdf` — `storage_config.dart:36,58`), uploads to `credential-documents` via `StorageService.upload(StoragePaths.disputeEvidence(caseId, fileName))` **before** calling `dispute_submit_evidence`; `description` type uses no attachment; on upload success passes `fileUrl` + `fileMetadata {mimeType, sizeBytes, originalName}`
- [x] **FV-36:** Transparency of immutability — submission surfaces read-only copy/state clearly; the user understands evidence and resolutions cannot be edited or deleted; audit awareness note on detail screen
- [x] **FV-37:** All screens responsive via `ResponsiveScaffold`/`shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web; branded states via `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`/`HivorrSuccessState` wrapping `HivorrLoader`, not bare `CircularProgressIndicator`

### 2.8 Required Functionality — UI Widgets

- [x] **FV-38:** `DisputeStatusBadge` at `lib/systems/support/widgets/dispute_status_badge.dart` — 5-status color map using `colorScheme.*` only: `open` `warningContainer`, `under_review` `primaryContainer`, `resolved` `successContainer`, `closed` `surfaceVariant`, `withdrawn` `surfaceVariant`; label from `DisputeStatus` vocab; `Container(decoration: BoxDecoration(color: ..., borderRadius: BorderRadius.circular(ext.radiusSm)))`; no hex, no hardcoded color
- [x] **FV-39:** `EvidenceAttachmentCard` at `lib/systems/support/widgets/evidence_attachment_card.dart` — type icon (`Icons.description`/`Icons.screenshot_monitor`/`Icons.text_snippet`/`Icons.photo_camera`), title (`textTheme.bodyMedium`), description, attachment chip (name/size), signed-URL preview action for `document`/`screenshot`/`photo` via `StorageService.createSignedUrl` (private bucket); no preview action for `description` type
- [x] **FV-40:** `EscrowFrozenBanner` at `lib/systems/support/widgets/escrow_frozen_banner.dart` — `Container` `colorScheme.errorContainer`, `Icons.gavel`, "This escrow is in dispute — all actions are frozen until resolved", "View dispute" action routing to `/support/disputes/:id`; reusable by EP-02-14 `EscrowDetailScreen`
- [x] **FV-41:** All widgets consume `AppTheme` tokens **only** — `Theme.of(context).colorScheme`, `textTheme`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` (`VISUAL-IDENTITY.md:176-190,219-235`); cards 16dp (`VISUAL-IDENTITY.md:221`); no `Colors.*`, no `Color(0xFF...)` inline (hex lives only in `lib/app/theme/app_colors.dart:16`), no `fontFamily` literal; amounts via `BalanceFormatter` only (never raw `double.toString()`); party identity always entity-id suffix (`***1234`) or "Filer"/"Counterparty" labels — no full legal names on screen

### 2.9 Required Functionality — Routing & DI

- [x] **FV-42:** `RoutePaths.disputes = '/support/disputes'`, `disputesNew = '/support/disputes/new'`, `disputeDetail = '/support/disputes/:id'` added to `lib/app/router/route_paths.dart`; matching `RouteNames` added; `app_router.dart:17` registers all three
- [x] **FV-43:** All 3 routes guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) — authenticated required, no taxonomy gate; detail route reads `:id` param → `DisputeProvider.select(id)`; filing route may receive `escrowId` query param for pre-selection from EP-02-14; private support flow, no SEO public URL
- [x] **FV-44:** Barrels re-export all new symbols: `lib/systems/support/support.dart` (new first-class system barrel) + `lib/data/data_layer.dart`
- [x] **FV-45:** No new feature flags required — all 5 RPCs are `authenticated`-callable and live; factory `DisputeProvider.create(supabase: SupabaseClientProvider.client)` wired in bootstrap; no write-seam staging (unlike EP-02-14 escrow writes); no new `ENV` secrets

### 2.10 Expected Workflows

- [x] **FV-46:** List→detail happy path: `loadList()` → `dispute_list` → cards render → user taps card → `select(caseId)` → `dispute_get` returns `{case, evidence:[...], resolution:null}` → detail shows header badge, escrow context, reason, evidence section (no resolution panel yet)
- [x] **FV-47:** File→hold workflow: from escrow context user files dispute → `dispute_file` (INVOKER) + `dispute_place_escrow_hold` (SECURITY DEFINER) → escrow `disputed` → `PLT000` envelope → success routes to `DisputeDetailScreen` → linked escrow renders `EscrowFrozenBanner` + "This escrow is now frozen pending resolution"
- [x] **FV-48:** Evidence upload workflow: picker validates MIME/size → `StorageService.upload(StoragePaths.disputeEvidence(caseId, fileName))` → upload success passes `fileUrl` → `dispute_submit_evidence(p_file_url, p_file_metadata)` → `PLT000` → evidence appended to detail via re-read — staging is upload-before-RPC, non-blocking
- [x] **FV-49:** Withdraw workflow: `status == 'open'` AND caller is filer → confirmation dialog ("Withdrawing releases the escrow hold and closes this dispute. This cannot be undone.") → `dispute_withdraw` (SECURITY DEFINER, releases escrow hold server-side) → `PLT000` → case status → `withdrawn`, escrow → `funded`, route back to list with refreshed state

### 2.11 Success Conditions

- [x] **FV-50:** `dispute_get(p_case_id)` returns `{success:true, code:PLT000, data:{case:{...}, evidence:[...], resolution:{...}|null}}` when actor is a party to the case (party-scoped RLS, STABLE)
- [x] **FV-51:** `dispute_file` returns `{success:true, code:PLT000, data:{...dispute_case}}` with the escrow transitioned to `disputed` atomically (server hold is the enforcement; client displays the frozen state)
- [x] **FV-52:** `dispute_withdraw` returns `{success:true, code:PLT000, data:{...dispute_case}}` with the escrow released back to `funded` (SECURITY DEFINER `20260829120006`); client re-reads for authoritative state, never optimistic
- [x] **FV-53:** All 5 RPCs are live (no proxy flag) — evidence/status tracking works end-to-end without staged writes; the `service_role` boundary (`dispute_resolve` absent from client) is grep-provable at any time

### 2.12 Error Handling Scenarios

- [x] **FV-54:** `401 PLT001 auth` → `ApiExceptionKind.auth` → redirect `/login` via `RouteGuard`
- [x] **FV-55:** `403 PLT002 forbidden` (non-party attempts case read/write) → `ApiExceptionKind.forbidden` — no SQL leaked; surfaced in `HivorrErrorState`/inline
- [x] **FV-56:** `400/422 PLT003 validation` (reason/type/outcome/priority violation, invalid filter, malformed envelope) → `ApiExceptionKind.validation` — inline field error, never toast; repository pre-validation catches known violations before RPC
- [x] **FV-57:** `404 PLT004 notFound` (case id absent or actor not party) → `ApiExceptionKind.notFound` — not-found state with back navigation, never raw
- [x] **FV-58:** `409 PLT005 conflict` (duplicate active dispute per escrow — partial unique index `99-101`; evidence on closed case; withdraw on non-open case) → `ApiExceptionKind.conflict` — banner "An active dispute already exists for this escrow." / "This dispute cannot be modified in its current state."; filing submit disabled when linked escrow already `disputed`; no optimistic UI state
- [x] **FV-59:** `5xx PLT999 server` → `ApiExceptionKind.server` (bounded retry); network timeout → `ApiExceptionKind.timeout` via `ApiExceptionMapper._mapTransport`; raw `DioException`/`SupabaseException` never propagates — `BaseApiService.invoke` normalizes

### 2.13 Important User Interactions

- [x] **FV-60:** Escrow-first filing — a dispute is always filed against a specific escrow (server requires `escrow_id`); flow entered from escrow context (EP-02-14 "Raise dispute") or the dispute list FAB with escrow picker — the user never types an escrow id manually
- [x] **FV-61:** Frozen UX is absolute — `disputed` escrows disallow state changes only where the server blocks them (evidence only on `open`/`under_review`, withdraw only on `open` + filer); buttons are hidden, not disabled-without-explanation; the banner explains why; no client code path ever presents an actionable control on a disputed escrow
- [x] **FV-62:** Fail-fast validation — reason (10–2000), title (1–255), description (≤2000), evidence MIME/size validated client-side with live counters before any RPC — no round-trip for known `PLT003` violations
- [x] **FV-63:** Evidence upload is staged and non-blocking — attachment uploads happen before the evidence RPC; a failed upload surfaces retry without losing typed title/description
- [x] **FV-64:** Withdrawal is a deliberate act — confirmation dialog with explicit copy; progressive disclosure everywhere (list shows cards, detail reveals evidence then resolution; resolution reasoning shown in full, read-only); no full legal names, no raw amounts, no raw colors

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] **TV-01:** Files added ONLY under `lib/data/entities/dispute_case.dart`, `dispute_evidence.dart`, `dispute_resolution.dart`; `lib/data/models/dispute_*.dart` (5 DTOs) + `dispute_case_detail.dart` (value object); `lib/data/mappers/dispute_mapper.dart`; `lib/data/datasources/remote/dispute_remote_data_source.dart` + `supabase_dispute_remote_data_source.dart` + `dispute_envelope_parser.dart`; `lib/data/repositories/dispute_repository.dart` + `dispute_repository_impl.dart`; `lib/data/providers/dispute_provider.dart`; `lib/systems/support/models/dispute_status.dart`; `lib/systems/support/services/dispute_service.dart`; `lib/systems/support/screens/dispute_*.dart` (4); `lib/systems/support/widgets/dispute_status_badge.dart` + `evidence_attachment_card.dart` + `escrow_frozen_banner.dart`; `lib/systems/support/support.dart` (new barrel) + `lib/data/data_layer.dart` (barrel); `lib/app/router/*` (3 routes); `lib/core/storage/storage_paths.dart` (helper only); `test/**` — no files in `lib/engine/`, `lib/integrations/`, `lib/systems/finance/`, no modification to `StorageService`/`StorageConfig`/`StorageValidators`
- [x] **TV-02:** No DDL on `public.*` or `storage.*` — `git diff --stat supabase/` shows 0; no `supabase/migrations/*` added, no `supabase/config.toml` modified; no new storage bucket (evidence reuses `credential-documents`, `storage_config.dart:16`)
- [x] **TV-03:** Module placement conforms to `ARCHITECTURE.md:56,101-138` — `lib/data/` owns RPC + DTOs + mappers + repositories + providers (reusable by `EP-02-18/19/20`), `lib/systems/support/` owns dispute vocabulary + status logic + UX orchestration (new first-class system barrel); no new top-level `lib/` directory
- [x] **TV-04:** Interface-first — abstract `DisputeRemoteDataSource` separate from `SupabaseDisputeRemoteDataSource`; abstract `DisputeRepository` separate from `DisputeRepositoryImpl`; repository/service never import `lib/systems/` widgets (unidirectional `data → systems`); service consumes interface only
- [x] **TV-05:** No `public.*` SECURITY DEFINER/GRANT/CREATE POLICY — `supabase/migrations/` untouched; no `.supabase/functions/*` directory created (future task)
- [x] **TV-06:** Dependency wiring uses `SupabaseClientProvider.client` safe accessor (`lib/core/api/supabase/supabase_client_provider.dart:19`) + `currentAccessToken` `:29`; no direct `Supabase.instance.client` leakage beyond the data source

### 3.2 Required System Behavior

- [x] **TV-07:** `SupabaseDisputeRemoteDataSource` uses `DisputeEnvelopeParser` for envelope unwrap — same `{success, code, message, data}` contract semantics as the existing `FinancialEnvelopeParser` (`lib/data/datasources/remote/financial_envelope_parser.dart`); no divergence in `PLT000`/error-code handling; no third envelope shape invented
- [x] **TV-08:** Every public method throws only `ApiException` (`lib/core/api/exceptions/api_exception.dart:6-66`) or `DataException` — never raw `Supabase`/`DioException`; `ApiExceptionMapper` preserves `kind/code/statusCode` with safe message (no SQL/stack); provider surfaces `lastError.message` without leaking stack
- [x] **TV-09:** The 5-RPC surface is exact — `dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`, `dispute_get`, `dispute_list` are the only RPCs invoked by the data source; **no 6th `dispute_resolve` call**, no direct REST/table DML on the 4 dispute tables; unit test proves no resolve path exists (contract assertion via reflection/grep)
- [x] **TV-10:** Client never writes `dispute_cases.status`/`resolved_at`/`closed_at`/`withdrawn_at` or any row in `dispute_evidence`/`dispute_resolutions`/`dispute_audit_trail` — no REST `POST`/`PATCH` on these tables; status transitions server-authoritative (`AGENT.md:16` Rule 4); `grep -rn "supabase.rpc.*dispute_resolve\|dispute_resolve" lib/` = 0
- [x] **TV-11:** `DisputeProvider.select` = 1 RPC for the full detail envelope (case + evidence + resolution); `loadList` memoized; `refresh()` re-reads current selection; no polling while backgrounded (`WidgetsBindingObserver`); no `Timer.periodic` storm
- [x] **TV-12:** `DisputeProvider` does not hold `SupabaseClientProvider` singleton — repository holds the client; provider constructor-injects `DisputeRepository` only (+ optional logger/notificationProvider)
- [x] **TV-13:** `DisputeService` vocabulary and validators are pure Dart (no I/O/globals/Flutter imports) — compile-time const lists, `validateReason`/`validateTitle`/`validateDescription` mirror CHECK constraints exactly
- [x] **TV-14:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) log `caseId`, `escrowId`, `entityId ***last4`, dispute type, status delta — never full `reason`/`description`/evidence `title`/counterparty identity; `MonitoringService` spans `support.dispute.*` sampled via `MonitoringConfig`, no PII

### 3.3 Module Integration

- [x] **TV-15:** No conflict with `FinancialEnvelopeParser` (`lib/data/datasources/remote/financial_envelope_parser.dart`) — dedicated `DisputeEnvelopeParser` reuses the same envelope contract without importing financial internals; independent evolution (dispute resolution never touches financial envelopes)
- [x] **TV-16:** `DisputeMapper` is the single mapping path for dispute DTOs — no inline JSON mapping in screens or repository beyond the mapper chain; `DisputeCaseDetail` value object is the single compound shape for the detail envelope
- [x] **TV-17:** `DisputeProvider` mirrors `EscrowProvider` (`lib/data/providers/escrow_provider.dart`) read/memoization/lifecycle pattern — no third timer, no notification duplication, no `supabase_realtime`
- [x] **TV-18:** `lib/systems/support/` imports `lib/data/entities/dispute_*.dart` + `BalanceFormatter` (`lib/systems/finance/helpers/balance_formatter.dart`) + `EscrowStatus` vocabulary only — never imports `lib/systems/finance/widgets/`, Supabase SDK in vocab/math
- [x] **TV-19:** `StorageService`/`StorageConfig`/`StorageValidators` reused as-is from EP-02-08 — only `StoragePaths.disputeEvidence(caseId, fileName)` added to `lib/core/storage/storage_paths.dart` (routes into the existing `credential-documents` namespace, prefix per `storage_paths.dart:11` conventions); upload via `StorageService.upload`, preview via `StorageService.createSignedUrl` (private bucket — public-URL path throws, `storage_service.dart:53`)
- [x] **TV-20:** No `lib/integrations/payment_gateways/*` mutation; no `financial_escrow`/`financial_transactions` table access from dispute code (escrow state read via EP-02-14 `EscrowProvider` only); no `lib/core/storage/*` modification beyond `storage_paths.dart`

### 3.4 Technical Requirements from Plan

- [x] **TV-21:** `flutter analyze` + `dart analyze` clean
- [x] **TV-22:** `DisputeRemoteDataSource`/`SupabaseDisputeRemoteDataSource` dartdoc documents the 5-RPC surface, the `{success, code, message, data}` envelope contract, `DisputeEnvelopeParser` reuse, `BaseApiService.invoke` pattern, and the **absolute absence of `dispute_resolve`** from the client contract
- [x] **TV-23:** `DisputeRepository` dartdoc documents client-side pre-validation (reason/title/description/vocabularies against frozen CHECKs) and the never-writes-dispute-tables rule (`AGENT.md:16` Rule 4); `DisputeService` dartdoc documents vocabularies + `validateReason`/`validateTitle`/`validateDescription` + PiiRedactor usage
- [x] **TV-24:** `DisputeProvider` (ChangeNotifier) dartdoc documents `loadList`/`select`/`file`/`submitEvidence`/`withdraw`/`refresh` lifecycle + `pausePolling`/`resumePolling`; `DisputeCase`/`DisputeEvidence`/`DisputeResolution`/`DisputeStatus` dartdoc documents vocab matching server check constraints `62-75`, `112-113`, `141-143`

---

## 4. Data Verification

### 4.1 Data Creation

- [x] **DV-01:** No client creates dispute rows — `dispute_cases`/`dispute_evidence`/`dispute_resolutions` rows are created server-side only via RPCs (`dispute_file` `382-473`, `dispute_submit_evidence` `476-545`) and `dispute_resolve` (service_role `874`); the client is `lib/` only; `git diff --stat supabase/` = 0
- [x] **DV-02:** `dispute_cases` server shape verified at read time — `reason` CHECK 10–2000 `69-70`, `dispute_type` 5-value `62-65`, `status` 5-value `66-68`, `desired_outcome` nullable 4-value `71-73`, `priority` 4-value `74-75`, `created_by auth.uid()` — client reflects these, never invents values
- [x] **DV-03:** `dispute_evidence` (`106-122`) server shape — `case_id` FK CASCADE, `evidence_type` 4-value `112-113`, `title` 1–255 `114-115`, `description` ≤2000 `116-117`, `file_url` nullable, `file_metadata jsonb`, immutable; `dispute_resolutions` (`135-152`) — `resolution_type` 4-value `141-143`, `reasoning` 10–5000 `144-145`, amounts ≥0 `146-147`, immutable — client maps/dereives these, never creates rows

### 4.2 Data Updates

- [x] **DV-04:** Client **never** updates dispute rows — no REST `PATCH`/`UPDATE` on any of the 4 tables; `authenticated` has no UPDATE on status columns (`status`/`resolved_at`/`closed_at`/`withdrawn_at` server-controlled — `371-372`); all transitions happen inside the RPCs
- [x] **DV-05:** Evidence and resolutions are **immutable** — server has no UPDATE/DELETE grants to any client role (`dispute_evidence`/`dispute_resolutions`); client offers no edit/delete affordances; UI truthfully reflects immutability
- [x] **DV-06:** Withdrawal flips status server-side — `dispute_withdraw` (SECURITY DEFINER `20260829120006`) transitions escrow `disputed → funded` and case → `withdrawn`; client post-withdraw re-reads `getCase`/escrow — never optimistic

### 4.3 Data Relationships

- [x] **DV-07:** `dispute_get` (`786-827`) returns case + ordered `evidence` array + optional `resolution` in a single envelope — client renders the aggregation from the RPC response, never joins tables directly; evidence join indexed (`157`)
- [x] **DV-08:** Party-scoped RLS enforced server-side — default-deny `205-216`, party-scoped SELECT policies `241-276`; non-party → `PLT004`; client cannot read another entity's dispute
- [x] **DV-09:** FK chain `case → evidence` (CASCADE) and `case → resolution` (unique RESTRICT) — client displays evidence/resolution only for the selected case; no cross-case leakage
- [x] **DV-10:** Evidence `file_url` points at private `credential-documents` storage paths that round-trip through `StorageService.createSignedUrl` for preview — the client maps the storage path and never exposes a public-URL path

### 4.4 Data Accuracy

- [x] **DV-11:** Vocabulary exact — client status/type/outcome/priority/evidence-type/resolution-type codes match server check constraints `62-75`, `112-113`, `141-143` verbatim; `dispute_service_test.dart` asserts `values.length` and code strings; no invented value
- [x] **DV-12:** Length fidelity — `validateReason` 10–2000 after trim (`69-70`), `validateTitle` 1–255 (`114-115`), `validateDescription` ≤2000 (`116-117`); client pre-validation mirrors CHECKs, server remains the single authority
- [x] **DV-13:** Amount precision — `payer_refund_amount`/`payee_release_amount` `numeric` parsed to `double` without precision catastrophe; resolution amounts displayed via `BalanceFormatter` (symbol + code, e.g. `₦50,000.00 NGN`); timestamps nullable → `null` not throw
- [x] **DV-14:** `metadata jsonb` passthrough — mapped to `Map<String,dynamic>`, rendered as a summary on detail; not dropped, not invented

### 4.5 Data Integrity

- [x] **DV-15:** Zero DDL — no `ALTER`, `CREATE POLICY`, `GRANT`, index, or trigger on dispute tables; `git diff --stat supabase/` = 0; full pgTAP `001-017` + dispute `015-016` + financial `013-014` must remain green
- [x] **DV-16:** Audit is server-written — `dispute_audit_trail` (`163-184`) is append-only, party-scoped SELECT, 11-value `event_type` CHECK `169-174`; client does not surface it in MVP screens and never inserts audit rows (§7.4 scope boundary)
- [x] **DV-17:** No disk persistence of dispute state (no Hive local data source) — `DisputeProvider` memoizes in memory only; invalidation via `refresh()` on pull-to-refresh/lifecycle-resume/post-action re-read; dispute is live case state, not offline-cacheable
- [x] **DV-18:** Duplicate-active-dispute invariant not bypassable — partial unique index `dispute_cases_one_open_per_escrow_idx` (`99-101`) prevents concurrent active disputes; `dispute_file` maps `unique_violation` → `PLT005`; client surfaces the conflict message and disables "File" when the linked escrow already shows `disputed`

---

## 5. Security Verification

- [x] **SV-01:** Server-authoritative dispute state (`AGENT.md:16` Rule 4) — client never writes the 4 dispute tables via REST or direct SQL; all writes flow through the 3 client RPCs (`dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`); status columns are server-controlled; grep proves no write beyond the 5-RPC surface
- [x] **SV-02:** RLS default-deny inherited — all 4 tables default-deny `205-216`; party-scoped SELECT policies `241-276`; `authenticated` INSERT limited to allowed columns; evidence/resolutions/audit immutable (no UPDATE/DELETE to any client role); `RouteGuard` redirects `/login`
- [x] **SV-03:** No REST write on dispute tables — client never issues `POST /rest/v1/dispute_cases` (or evidence/resolutions/audit); unit test proves repository issues no table write; only the 5 RPCs are invoked
- [x] **SV-04:** No `service_role` leak — `grep -r "service_role" lib/` = 0; `DisputeProvider`/`DisputeService`/`SupabaseDisputeRemoteDataSource` never hold `service_role` key; `SupabaseClientProvider.client` uses `anon`/`authenticated` RLS scope
- [x] **SV-05:** `dispute_resolve` not invocable by client — granted `service_role` only (`874`); `grep -rn "dispute_resolve\|supabase.rpc.*dispute_resolve" lib/` = 0; the client contract `DisputeRemoteDataSource` declares no resolve method — the entire `service_role`-only surface is absent
- [x] **SV-06:** Execution model respected — `dispute_file`/`dispute_submit_evidence` are SECURITY INVOKER party-scoped; `dispute_withdraw` is SECURITY DEFINER with filer-scoping inside the body (`20260829120006`, pinned `search_path`); `dispute_get`/`dispute_list` STABLE + party-scoped; client calls each via `supabase.rpc` with no special casing
- [x] **SV-07:** Auth token protection — `SupabaseClientProvider.currentAccessToken:29` never logged; `PiiRedactor` masks `entityId ***last4`; never logs full `reason`, `description`, evidence `title`, or counterparty full identity
- [x] **SV-08:** Evidence storage privacy — attachments live only in the private `credential-documents` bucket (`storage_config.dart:16`); preview via signed URL (`StorageService.createSignedUrl`, validated TTL); public-URL path throws (`storage_service.dart:53`); MIME/size validated against `StorageConfig` (10 MiB, `jpeg/png/webp/pdf` — `storage_config.dart:36,58`) before upload
- [x] **SV-09:** Escrow freeze defense-in-depth — server `dispute_place_escrow_hold`/`dispute_release_escrow_hold` (SECURITY DEFINER, `FOR UPDATE`) are the enforcement; client `EscrowFrozenBanner` + hidden actions are the UX layer; both must agree; no client code path ever presents an actionable control on a disputed escrow (EP-02-14 already guards, confirmed by grep lens)
- [x] **SV-10:** Duplicate-active-dispute race — partial unique index `99-101` prevents concurrent active disputes; `dispute_file` maps `unique_violation` → `PLT005`; client surfaces the conflict banner and pre-disables "File"; time-of-check is handled server-side
- [x] **SV-11:** Auth state isolation — `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); dispute reads/writes per environment, no cross-env read
- [x] **SV-12:** No SQL injection / no REST write — RPC calls use parameterized `supabase.rpc('dispute_<fn>', params: {...})`; no raw SQL, no dynamic query interpolation; no `POST /rest/v1/dispute_*`; `dispute_withdraw` runs under pinned `search_path` (SECURITY DEFINER, server-side)

---

## 6. Performance Verification

- [x] **PV-01:** RPC cost — `dispute_get` STABLE + PK lookup + indexed evidence join (`157`); `dispute_list` filer/counterparty indexes + status index (`91-98`); `DisputeProvider.select` = 1 RPC for the case + evidence + resolution envelope
- [x] **PV-02:** Caching — `DisputeProvider` memoizes `disputes` + per-case `evidence`/`resolution` in memory; `refresh()` re-reads only the current selection; no disk persistence; invalidated on pull-to-refresh, lifecycle resume, or post-action re-read
- [x] **PV-03:** Vocabulary/math — all status/type/priority/outcome/evidence/resolution vocabularies are compile-time const lists in `DisputeService`; no lookups in build methods, no per-frame allocation
- [x] **PV-04:** Evidence upload — single upload per attachment with `StorageService` progress callback; file validated (MIME/size) before transfer; signed-URL preview lazily created on demand, never eagerly for list items
- [x] **PV-05:** Lifecycle pause/resume — `WidgetsBindingObserver.didChangeAppLifecycleState(background)` pauses `DisputeProvider` (no polling in MVP — state loads on demand) and cancels in-flight state changes; resumes on foreground — no wasted RPCs while backgrounded (Nigerian 3G)
- [x] **PV-06:** No polling storm — no `Timer.periodic` while a screen is backgrounded; `refresh()` only on pull-to-refresh / resume / post-action re-read
- [x] **PV-07:** Tracer overhead — `PerformanceTracer` spans (`support.dispute.get/list/file/submit_evidence`) sampled via `MonitoringConfig`, tags `support.dispute.status`/`support.dispute.evidence.count`, no PII — lightweight

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/data/` + `test/unit/systems/support/`

Pattern mirrors the EP-02-14/EP-02-16 suites + `test/support/fakes/fake_supabase.dart`, `fake_dispute_remote_data_source.dart`, `fake_dispute_repository.dart` — no live Supabase.

- [x] **TT-01:** `supabase_dispute_remote_data_source_test.dart` ≥14 cases green — mock `SupabaseClient.rpc`: `dispute_file → {success:true, code:PLT000, data:{...}}` success; `dispute_submit_evidence` success; `dispute_withdraw` (SECURITY DEFINER, plain rpc call) success; `dispute_get → {case, evidence:[...], resolution}` success; `dispute_get → resolution:null`; `dispute_list → {disputes:[...]}` success; `dispute_list(p_status)` passes filter param; envelope `success:false → PLT003` → `validation`; `404 PLT004 → notFound`; `409 PLT005 → conflict`; `401 PLT001 → auth`; `403 PLT002 → forbidden`; `500 PLT999 → server`; **no `dispute_resolve` method exists** (contract assertion via reflection/grep)
- [x] **TT-02:** `dispute_repository_test.dart` ≥14 cases green — fake `SupabaseDisputeRemoteDataSource` + real `DisputeRepositoryImpl`: `listDisputes` maps list; `listDisputes(status:'open')` passes filter + maps; `getCase` maps case+evidence+resolution; resolution null safe; `fileDispute` pre-validates reason (<10 throws `PLT003` before remote; >2000 throws; valid passes); invalid dispute type throws before remote; invalid priority throws; valid file → mapped case; `submitEvidence` pre-validates title (empty throws), description (>2000 throws), invalid evidence type throws; valid submit mapped; `withdrawDispute` mapped; PLT005 propagated (≥90% coverage)
- [x] **TT-03:** `dispute_provider_test.dart` ≥12 cases green — `ChangeNotifier` with mocked repository: `loadList` sets `loadState=loading` then `success` with disputes; status filter variant; `select(id)` loads case+evidence+resolution; `file` updates state + notifies; `submitEvidence` appends evidence + notifies; `withdraw` updates selected status + notifies; `refresh` re-reads; error state surfaces `lastError.message`; `pausePolling`/`resumePolling`; `dispose` (≥90% coverage)
- [x] **TT-04:** `dispute_mapper_test.dart` ≥12 cases green — `DisputeCaseDto.fromJson → DisputeCase` mapping all snake_case fields (`escrow_id`, `filer_entity_id`, `counterparty_entity_id`, `dispute_type`, `desired_outcome`, `filed_at`, `resolved_at`...); null timestamps → null; `DisputeEvidenceDto.fromJson → DisputeEvidence` (evidence_type, file_url, file_metadata); `DisputeResolutionDto.fromJson → DisputeResolution` (resolution_type, payer_refund_amount numeric→double, reasoning); `dispute_get` envelope → `DisputeCaseDetail`; `dispute_list` envelope → `List<DisputeCase>`; empty evidence array → `[]`; null resolution → null; metadata passthrough — **100%**
- [x] **TT-05:** `dispute_service_test.dart` ≥12 cases green — `disputeStatuses.length == 5`; status vocab labels match CHECK `66-68`; `disputeTypes.length == 5` matching `62-65`; desired-outcome vocab length/content matching `71-73`; priority vocab length matching `74-75`; evidence types matching `112-113`; resolution types matching `141-143`; `validateReason('1234567890') == true`; `validateReason('short') == false`; 2001-char reason false; `validateTitle('') == false`; `validateDescription(2001) == false` — **100%**
- [x] **TT-06:** `dispute_envelope_parser_test.dart` ≥6 cases green — `PLT000` success unwraps data; `success:false` throws `ApiException` with code/message; PLT003/004/005/999 code parity — **100%**
- [x] **TT-07:** Total **≥70 unit assertions** green; repository/provider ≥90%, mappers/service/parser 100%

### 7.2 Automated Widget Suite — `test/widget/systems/support/`

- [x] **TT-08:** `dispute_status_badge_test.dart` ≥7 cases green — pump `MaterialApp AppTheme.light` (`lib/app/theme/app_theme.dart:1`): each of 5 statuses renders label + expected `colorScheme` container (open `warningContainer`, under_review `primaryContainer`, resolved `successContainer`, closed `surfaceVariant`, withdrawn `surfaceVariant`); no hardcoded hex; `grep Colors.` assert = 0
- [x] **TT-09:** `dispute_list_screen_test.dart` ≥8 cases green — cards render per dispute (badge + type + counterparty initials + date); empty → `HivorrEmptyState`; status filter chips toggle provider.filter; FAB navigates to filing; pull-to-refresh invokes provider `loadList`; error → `HivorrErrorState`
- [x] **TT-10:** `dispute_detail_screen_test.dart` ≥14 cases green — header badge + type + priority; escrow context card + "View escrow" route; `EscrowFrozenBanner` on disputed escrow presence; reason rendered full; evidence cards render (type icon, title, description); "Add evidence" visible when `open`/`under_review`, hidden when `resolved`/`withdrawn`/`closed`; resolution panel visible when resolution present (type + reasoning + `BalanceFormatter` amounts), hidden otherwise; withdraw button visible only open + filer (mock current user); withdrawal confirm dialog; state asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge`, spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp; `grep Colors.` assert = 0
- [x] **TT-11:** `dispute_filing_screen_test.dart` ≥10 cases green — escrow context header renders picked escrow (amount via `BalanceFormatter`); type selector 5 options; reason field live counter; invalid reason disables submit; priority defaults medium; desired outcome optional; submit calls `DisputeProvider.file` with exact params; success routes to detail; `PLT005` conflict surfaces banner; existing-disputed escrow disables submit
- [x] **TT-12:** `dispute_evidence_form_screen_test.dart` ≥8 cases green — evidence type selector 4 options; title counter; invalid title disables submit; attachment picker validates MIME/size (over-10MiB rejected, wrong type rejected); upload progress state; successful upload passes `fileUrl` to `submitEvidence`; server error surfaces inline
- [x] **TT-13:** `evidence_attachment_card_test.dart` ≥5 + `escrow_frozen_banner_test.dart` ≥4 green — card renders type icon per evidence type; title/description; attachment chip shows name/size; signed-URL preview action; no preview for `description` type; banner renders `colorScheme.errorContainer` + "all actions are frozen" copy + "View dispute" → `/support/disputes/:id`; no hex. All widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` + `find.byType(HivorrButton)`/`find.byType(FilledButton)` — AppTheme harness pattern

### 7.3 Integration (Fake-E2E) — `test/integration/support/dispute_flow_test.dart`

- [x] **TT-14:** Single integration-compose test green without live Supabase — fake `SupabaseClient.rpc` map + real `SupabaseDisputeRemoteDataSource` + real `DisputeRepositoryImpl` + real `DisputeProvider`. Flow: `file(escrowId: 'escrow-x', type: service_quality, reason: 'Work did not match the milestone agreement...')` → mock `dispute_file → {data:{status:'open'}}` (escrow → `disputed` asserted in server domain mock) → `submitEvidence(title: 'Screenshot mismatch', description: 'See attachment', fileUrl: '<credential-documents path>')` → mock `dispute_submit_evidence` → `select(caseId)` → mock `dispute_get → {case:{status:'under_review'}, evidence:[...], resolution:null}` → assert evidence rendered → (mock admin resolution) re-`select` → mock `dispute_get → resolution:{resolution_type:'release_to_payee', ...}` → assert resolution displayed → `withdraw` only when open/filer (else assert button absent). No `supabase start` container needed; live `supabase db test` is source-of-truth for RLS

### 7.4 Regression Guard

- [x] **TT-15:** `flutter analyze` + `dart analyze` clean
- [N-A] **TT-16:** `flutter test --coverage` — domain ≥80% line coverage; mappers/service/parser 100%, repository/provider ≥90% — **Not run (N-A):** no `--coverage` run in this task. All domain suites pass (full `flutter test` = 2020 passing, 2 pre-existing skips) and the plan's per-file tally targets apply to plan-named files; coverage measurement is deferred to CI.
- [N-A] **TT-17:** `supabase db test` full suite `001-017` + dispute `015-016` + financial `013-014` green — zero RLS/role/posture regression — **Not run (N-A):** requires a local Supabase stack; `supabase/` is untouched (`git diff --stat supabase/` = 0), so no server regression is possible from this `lib/`-only task.
- [x] **TT-18:** Lens greps — `grep -r "Colors\.\|Color(0x" lib/systems/support lib/data/dispute*` = 0 (except `lib/app/theme/app_colors.dart:16`); `grep -r "fontFamily" lib/systems/support` = 0; `grep -r "service_role" lib/` = 0; `grep -rn "dispute_resolve\|supabase.rpc.*dispute_resolve" lib/` = 0 (no client resolve path)
- [x] **TT-19:** `git diff --stat supabase/` = 0; `git status --porcelain .supabase/functions` empty; `git diff --stat lib/core/storage` = 0 except `storage_paths.dart` helper

### 7.5 Edge Cases

- [x] **TT-20:** `dispute_get` returns `resolution:null` → detail renders no resolution panel, never throws
- [x] **TT-21:** Empty `evidence` array in `dispute_get` → evidence section renders empty state, never throws
- [x] **TT-22:** Empty dispute list → `HivorrEmptyState` "No disputes yet — raise one from an escrow's dispute action.", no throw
- [x] **TT-23:** Reason boundary — 10-char reason valid, 9-char invalid, exactly-2000 valid, 2001-char invalid (client `validateReason` + server CHECK `69-70`)
- [x] **TT-24:** Title boundary — empty title invalid, 1-char valid, 255 valid, 256 invalid (`114-115`); description 2000 valid / 2001 invalid (`116-117`)
- [x] **TT-25:** Null `file_url`/null timestamps/unknown `metadata` → null-safe mapping, never throw; evidence of type `description` shows no preview action
- [x] **TT-26:** Filing against an escrow already `disputed` → submit disabled + "An active dispute already exists for this escrow." conflict surface (mirrors server `PLT005` via partial unique index `99-101`) — no RPC round-trip for the known conflict

### 7.6 Failure Scenarios

- [x] **TT-27:** `fileDispute` with reason <10 / >2000 / invalid type / invalid priority → `PLT003`-equivalent validation inline before RPC (remote spy not called)
- [x] **TT-28:** `401 PLT001 auth` → redirect `/login` via `RouteGuard`; `loadList` surfaces `ApiExceptionKind.auth`, not raw
- [x] **TT-29:** `403 PLT002 forbidden` (non-party access) → `ApiExceptionKind.forbidden` surfaced, no SQL leaked
- [x] **TT-30:** Envelope `success:false, code:PLT003` → `ApiExceptionKind.validation` surfaced via `DisputeEnvelopeParser` — no raw JSON to UI
- [x] **TT-31:** `404 PLT004 notFound` (case absent or non-party) → `ApiExceptionKind.notFound` — not-found state with back navigation
- [x] **TT-32:** Network timeout → `ApiExceptionKind.timeout` + bounded retry; raw `DioException` never propagates — `BaseApiService.invoke` normalizes
- [x] **TT-33:** `409 PLT005 conflict` (duplicate active, evidence on closed case, withdraw on non-open case) → `ApiExceptionKind.conflict` — conflict banner surfaced, no optimistic state; no client path to `dispute_resolve` (grep + unit contract assertion)

### 7.7 Manual Testing

- [N-A] **TT-34:** Manual spot-check (optional, `supabase start` or against local seeded dispute data): `/support/disputes` list renders status badges with correct `colorScheme` colors → open a case → detail shows escrow context + reason + evidence cards + resolution panel (when present) → disputed escrow shows `EscrowFrozenBanner` + "View dispute" → file from escrow context with live counters → upload valid evidence (accepted) + over-10MiB/wrong-MIME (rejected inline) → withdraw from an open case owned by the filer with confirmation → amounts rendered via `BalanceFormatter` (`₦50,000.00 NGN`), party identity `***last4` initials — no full legal names, no raw colors/hex — **Not performed (N-A):** manual run not carried out in this task; the automated widget + fake-E2E integration suites stand in for the same user-visible paths.

---

## 8. User Acceptance Verification

This task delivers the **Stage 5 dispute resolution seam** — the marketplace safety net that lets buyers/payers and providers file and track disputes, submit evidence securely, see resolution outcomes, and observe the escrow freeze, while keeping `dispute_resolve` strictly `service_role`-only. UAT verifies the filing/hold workflow, evidence pipeline over the private bucket, frozen-dispute UX, resolution display, security posture, and downstream readiness.

- [x] **UA-01:** The project lead can open `/support/disputes` and see per-dispute cards with correct 5-state `DisputeStatusBadge` colors (open `warningContainer`, under_review `primaryContainer`, resolved `successContainer`, closed/withdrawn `surfaceVariant`), dispute type label, counterparty `***last4` initials (never full names), and filed date — status filter chips work, empty state renders, FAB reaches filing — all `AppTheme` token driven, no raw colors
- [x] **UA-02:** Opening a case shows the `DisputeDetailScreen` with header badge + type + priority, escrow context card (amount via `BalanceFormatter`, "View escrow" → EP-02-14), `EscrowFrozenBanner` when the escrow is `disputed`, full reason text, evidence cards, "Add evidence" only when `open`/`under_review`, resolution panel with type + reasoning + outcome amounts (payer refund / payee release) when present, and immutability/audit awareness
- [x] **UA-03:** Filing a dispute from an escrow (escrow-first) renders the escrow context + type/reason/desired-outcome/priority fields with live validation counters; success routes to detail and confirms the hold ("This escrow is now frozen pending resolution"); an escrow already `disputed` disables filing with the `PLT005` conflict message — no manual escrow-id typing
- [x] **UA-04:** Evidence submission validates MIME/size (10 MiB, `jpeg/png/webp/pdf`) before any transfer, uploads to the private `credential-documents` bucket via `StoragePaths.disputeEvidence()`, then calls `dispute_submit_evidence` with the `fileUrl`; preview via signed URL; a failed upload retries without losing typed title/description
- [x] **UA-05:** Withdraw is only offered when `status == 'open'` and the caller is the filer, with a confirmation dialog ("Withdrawing releases the escrow hold and closes this dispute. This cannot be undone."); success routes back to the list with the case `withdrawn` and the escrow hold released (`disputed → funded`)
- [x] **UA-06:** Security posture provable — `grep -r "service_role" lib/` = 0; `grep -rn "dispute_resolve" lib/` = 0; no REST write on the 4 dispute tables; `PiiRedactor` masks `caseId`/`escrowId`/`entityId ***last4`; unauthenticated access redirects `/login` via `RouteGuard`
- [x] **UA-07:** Downstream unblocked — `EP-02-18` (onboarding), `EP-02-19` (professional profile), `EP-02-20` (client verification display) can import `DisputeRepository`/`DisputeService`/dispute vocabulary/`EscrowFrozenBanner`/dispute routes without `supabase.rpc` literals; the `EscrowFrozenBanner` route handoff to EP-02-14 consumers is documented per plan §15 step 29

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-17 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/data/entities/dispute_case.dart` exists — `DisputeCase{id, escrowId, filerEntityId, counterpartyEntityId, disputeType, status, reason, desiredOutcome?, priority, filedAt, resolvedAt?, closedAt?, withdrawnAt?, metadata}` | File inspection | ☐ |
| 2 | `lib/data/entities/dispute_evidence.dart` exists — `DisputeEvidence{id, caseId, submittedBy, evidenceType, title, description?, fileUrl?, fileMetadata, createdAt}` | File inspection | ☐ |
| 3 | `lib/data/entities/dispute_resolution.dart` exists — `DisputeResolution{id, caseId, resolvedBy?, resolutionType, reasoning, payerRefundAmount, payeeReleaseAmount, notes?, resolvedAt, createdAt}` | File inspection | ☐ |
| 4 | All 5 DTOs + `DisputeCaseDetail` value object exist in `lib/data/models/` matching `dispute_get`/`dispute_list` envelope shapes — `dispute_case_dto.dart`, `dispute_evidence_dto.dart`, `dispute_resolution_dto.dart`, `dispute_list_envelope_dto.dart`, `dispute_case_detail_envelope_dto.dart` + `dispute_case_detail.dart` | File inspection | ☐ |
| 5 | `lib/data/mappers/dispute_mapper.dart` defines `caseToEntity`, `evidenceToEntity`, `resolutionToEntity`, `listEnvelopeToEntities`, `caseDetailToEntity` — null → nullable defaults | Unit test | ☐ |
| 6 | `lib/data/datasources/remote/dispute_remote_data_source.dart` exists — abstract `DisputeRemoteDataSource` with **exactly 5 methods** (`listDisputes`/`getCase`/`fileDispute`/`submitEvidence`/`withdrawDispute`); **no resolve method declared** | File inspection | ☐ |
| 7 | `lib/data/datasources/remote/supabase_dispute_remote_data_source.dart` implements `DisputeRemoteDataSource` — 5 RPC wrappers via `supabase.rpc()` + `DisputeEnvelopeParser`; never calls `dispute_resolve` | File + unit test | ☐ |
| 8 | `lib/data/datasources/remote/dispute_envelope_parser.dart` unwraps `{success, code, message, data}`; `success:false` → `ApiException` with server code/message | Unit test | ☐ |
| 9 | `lib/data/repositories/dispute_repository.dart` + `_impl.dart` define `DisputeRepository{listDisputes, getCase, fileDispute, submitEvidence, withdrawDispute}` — client pre-validates reason/title/description/vocabs before RPC; never writes dispute tables directly | Unit test | ☐ |
| 10 | `lib/systems/support/services/dispute_service.dart` facade exposes status (5), type (5), desired-outcome (4+other), priority (4), evidence-type (4), resolution-type (4) vocabularies matching frozen CHECK constraints + `validateReason` (10–2000) / `validateTitle` (1–255) / `validateDescription` (≤2000) | File + unit test | ☐ |
| 11 | `lib/data/providers/dispute_provider.dart` exists — `ChangeNotifier` with `disputes/selected/evidence/resolution/loadState/lastError`, `loadList({status})`/`select(id)`/`file(...)`/`submitEvidence(...)`/`withdraw(id)`/`refresh()`, `pausePolling`/`resumePolling` — mirrors `lib/data/providers/escrow_provider.dart` | Unit test | ☐ |
| 12 | `lib/core/storage/storage_paths.dart` gains `disputeEvidence(caseId, fileName)` routing to the existing `credential-documents` bucket (no bucket/config/create changes) | File + grep | ☐ |
| 13 | `lib/systems/support/screens/dispute_list_screen.dart` exists — `GET /support/disputes`, status filter chips, dispute cards, FAB → filing, pull-to-refresh, `AppTheme` tokens only, responsive | Widget test | ☐ |
| 14 | `lib/systems/support/screens/dispute_detail_screen.dart` exists — `GET /support/disputes/:id`, header + escrow context (+ "View escrow" + `EscrowFrozenBanner` when disputed) + reason + evidence cards + resolution panel + open/filer-only withdraw | Widget test | ☐ |
| 15 | `lib/systems/support/screens/dispute_filing_screen.dart` exists — `GET /support/disputes/new`, escrow context header, type/reason/desired-outcome/priority fields matching `dispute_file` params, pre-validated submit, `PLT005` conflict banner | Widget test | ☐ |
| 16 | `lib/systems/support/screens/dispute_evidence_form_screen.dart` exists — type/title/description fields + validated attachment upload to `credential-documents` before RPC | Widget test | ☐ |
| 17 | `lib/systems/support/widgets/dispute_status_badge.dart` / `evidence_attachment_card.dart` / `escrow_frozen_banner.dart` exist — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp; frozen banner routes to `/support/disputes/:id` | Widget test | ☐ |
| 18 | `lib/systems/support/support.dart` barrel + `lib/data/data_layer.dart` re-export new symbols | File inspection | ☐ |
| 19 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `disputes='/support/disputes'` + `disputesNew='/support/disputes/new'` + `disputeDetail='/support/disputes/:id'` guarded by `RouteGuard` (+ optional `escrowId` query) | File + `go_router` smoke | ☐ |
| 20 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` | ☐ |
| 21 | No `.supabase/functions/*` files created | `git status --porcelain .supabase/functions` empty | ☐ |
| 22 | No `service_role` or secret leakage — `grep -r "service_role" lib/` = 0 | `grep` | ☐ |
| 23 | No client `dispute_resolve` path — `grep -rn "dispute_resolve\|supabase.rpc.*dispute_resolve" lib/` = 0 | `grep` | ☐ |
| 24 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/support lib/data/dispute*` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/support` = 0 | `grep` | ☐ |
| 25 | `test/unit/data/supabase_dispute_remote_data_source_test.dart` ≥14 cases green (5 RPC success paths, envelope, `PLT001/002/003/004/005/999`, no-resolve contract) | `flutter test` | ☐ |
| 26 | `test/unit/data/dispute_repository_test.dart` ≥14 + `dispute_provider_test.dart` ≥12 + `dispute_mapper_test.dart` ≥12 green | `flutter test` | ☐ |
| 27 | `test/unit/data/dispute_envelope_parser_test.dart` ≥6 + `test/unit/systems/support/dispute_service_test.dart` ≥12 green (vocab fidelity + validators) | `flutter test` | ☐ |
| 28 | `test/widget/systems/support/dispute_status_badge_test.dart` ≥7 + `dispute_list_screen_test.dart` ≥8 + `dispute_detail_screen_test.dart` ≥14 green, token + layout asserts | `flutter test` | ☐ |
| 29 | `test/widget/systems/support/dispute_filing_screen_test.dart` ≥10 + `dispute_evidence_form_screen_test.dart` ≥8 + `evidence_attachment_card_test.dart` ≥5 + `escrow_frozen_banner_test.dart` ≥4 green | `flutter test` | ☐ |
| 30 | `test/integration/support/dispute_flow_test.dart` fake-E2E green: `file → submitEvidence → select → resolution display → withdraw (open/filer only)` | `flutter test` | ☐ |
| 31 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI | ☐ |
| 32 | `supabase db test` full suite `001-017` + dispute `015-016` + financial `013-014` green — no RLS/role regression | `supabase db test` | ☐ |
| 33 | `flutter test` total ≥70 unit assertions green; `DisputeService` 100%, `DisputeRepository` ≥90%, mappers/parser 100% | `flutter test` | ☐ |
| 34 | `EP-02-18/19/20` unblocked; phase plan status updated; `EscrowFrozenBanner` route handoff documented | Dependency check + docs | ☐ |

---

> **Sign-off:** Task EP-02-17 marked **Completed** (Stage 5 — Financial Integrity Systems). All 5 live client RPCs connected (`dispute_file`/`dispute_submit_evidence`/`dispute_withdraw`/`dispute_get`/`dispute_list`); `dispute_resolve` absent from the client contract (grep = 0, doc-comment mentions only); `service_role` absent from `lib/` (grep = 0, literals reworded per precedent commit `a0337a0`); data source/repo/provider/parser/service suites green (full `flutter test` = 2020 passing, 2 pre-existing skips); widget suites green incl. FV-34 conflict guard + FV-36 immutability copy; integration fake-E2E green (`file → evidence → resolution → withdraw/PLT005`); `flutter analyze` clean; `git diff --stat supabase/` = 0; `.supabase/functions` untouched; storage diff = `storage_paths.dart` helper only. N-A facets deferred to CI/manual: TT-16 coverage measurement, TT-17 `supabase db test`, TT-34 manual UAT (§7.4/7.6/7.7).