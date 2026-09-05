# Definition of Done — EP-02-11: Trade Verification Workflow & Admin Review Gate

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-11 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-11-Trade Verification Workflow & Admin Review Gate.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-11 |
| **Task Name** | Trade Verification Workflow & Admin Review Gate |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 4 — Trust & Verification Systems |
| **Priority** | Critical |
| **Dependencies** | EP-02-03 (Verification Schema — 5 tables, 6 RPCs `verification_*`), EP-02-06 (Storage Infrastructure — `credential-documents` private bucket), EP-02-10 (Identity Verification — `VerificationProvider` pattern `lib/data/providers/verification_provider.dart:42`) |
| **Blocks** | EP-03 marketplace bid-lock (server-enforced) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-11-Trade Verification Workflow & Admin Review Gate.md` |

> Frozen server refs (reused, never modified): `supabase/migrations/20260829090003_verification_admin_review_schema.sql:323-406,592-681,412-489` and `supabase/migrations/20260821090002_entity_core_tables.sql:170-186`

---

## 2. Functional Verification

This task delivers a server-authoritative trade verification seam: per-profession trade proof submission (certificates, licenses, work samples), `credential-documents` upload via `StorageService`, `entity_credentials` creation with `profession_id` binding, `verification_submit('trade_proof')` queueing, status tracking with `trade_verification_status` propagation, the `TradeVerificationGate.canBid` bid-lock, and a simplified admin review queue. Functional verification confirms the data layer, gate, service facade, provider, screens, and routing behave correctly and never bypass server-enforced invariants.

### 2.1 Required Functionality — Domain Vocabulary

- [ ] **FV-01:** `lib/systems/verification/models/trade_proof_type.dart` defines `TradeProofType` enum with 5 values: `certificate`, `license`, `workSample`, `portfolio`, `other` — each with display label (e.g. "Certificate", "License", "Work Sample", "Portfolio", "Other") and `entity_credentials.kind` mapping + `submission_type='trade_proof'`
- [ ] **FV-02:** `TradeProofType` extensible without schema change — adding a type requires only an enum value + label; `kind` and `submission_type` remain valid allowed values

### 2.2 Required Functionality — Data Layer (Entities, DTOs, Mappers)

- [ ] **FV-03:** `TradeVerificationDto` exists at `lib/data/models/trade_verification_dto.dart` — `fromJson` maps `profession_id`, `trade_verification_status`, optional `professionName` (resolved via `TaxonomyEngine`)
- [ ] **FV-04:** `TradeVerification` entity exists at `lib/data/entities/trade_verification.dart` — per-profession status, pure Dart
- [ ] **FV-05:** `TradeVerificationStatus` entity exists at `lib/data/entities/trade_verification_status.dart` — aggregates `List<TradeVerification> tradeVerifications` + `bool identityVerified`; pure Dart, no Flutter/Supabase imports
- [ ] **FV-06:** `lib/data/mappers/verification_mapper.dart` extended with trade methods mapping DTO→Entity per profession: `unverified|pending|approved|rejected`; `pending` derived client-side from `verification_submissions` status (Decision Log #2), no RPC JSON shape leak

### 2.3 Required Functionality — Remote Data Source

- [ ] **FV-07:** `TradeVerificationRemoteDataSource` abstract exists at `lib/data/datasources/remote/trade_verification_remote_data_source.dart` — methods `submit(credentialId, submissionType='trade_proof')`, `getStatus(entityId?)`
- [ ] **FV-08:** `SupabaseTradeVerificationRemoteDataSource` exists at `lib/data/datasources/remote/supabase_trade_verification_remote_data_source.dart` — `extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`), uses `supabase.rpc('verification_submit', params:{p_credential_id, p_submission_type:'trade_proof'})` + `supabase.rpc('verification_status_get', params:{p_entity_id})`
- [ ] **FV-09:** Envelope unwrap via `EnvelopeParser` validates `success==true && code==PLT000` before DTO mapping; `getStatus` extracts `trade_verifications:[{profession_id, trade_verification_status}]` array (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:592-681`)
- [ ] **FV-10:** Error mapping via `DataExceptionMapper` — `PLT001→auth`, `PLT002→forbidden`, `PLT003→validation`, `PLT004→notFound`, `PLT005→conflict`, `PLT999→server`; raw `DioException` never propagates

### 2.4 Required Functionality — Repository

- [ ] **FV-11:** `TradeVerificationRepository` abstract + `TradeVerificationRepositoryImpl` exist at `lib/data/repositories/trade_verification_repository.dart` + `trade_verification_repository_impl.dart`
- [ ] **FV-12:** `submitTradeProof({TradeProofType type, String professionId, Uint8List bytes, String mimeType, String fileName, void Function(int,int)? onProgress})` orchestrates: (1) `storageService.validateForBucket(bucket: StorageBuckets.credentialDocuments, mimeType, byteLength)` — throws `StorageValidationException` `PLT003` before network; (2) `TaxonomyEngine` validates `professionId` bound + resolves display name; (3) `submissionId = Uuid.v4()` → `StoragePaths.credentialDocument(entityId: auth.uid(), submissionId, fileName)` → `{entityId}/{submissionId}/{uuid}_{sanitized}`; (4) `storageService.upload(bucket: credentialDocuments, path, bytes, mimeType, fileName, onProgress, upsert: false)`; (5) `supabase.from('entity_credentials').insert({entity_id: auth.uid(), kind: tradeProofKind, title: 'professionName — tradeProofTypeLabel', document_path: storageKey, profession_id: professionId}).select().single()`; (6) `remote.submit(credentialId: cred['id'], submissionType: 'trade_proof')`
- [ ] **FV-13:** `getStatus()` delegates to `remote.getStatus()` and maps DTO→Entity (reuses `verification_status_get` aggregate `trade_verifications` array)
- [ ] **FV-14:** `pollStatus` is not repository-level — provider timer calls `getStatus()` every 15s until terminal (`approved|rejected`), with `ApiConfig.forEnvironment` retry on `timeout/network` (`lib/core/api/api_config.dart:40`)

### 2.5 Required Functionality — Trade Verification Gate (bid-lock)

- [ ] **FV-15:** `lib/systems/verification/gate/trade_verification_gate.dart` defines `TradeVerificationGate` with pure function `static bool canBid(TradeVerificationStatus status, String professionId)` — returns `true` iff the given profession's `trade_verification_status == 'approved'` (`AGENT.md:15` Rule 2)
- [ ] **FV-16:** Correct per-profession M:N lookup within `tradeVerifications` list; unknown/absent profession returns `false` (locked); no I/O, no globals — trivially testable; server enforced by marketplace `EP-03`

### 2.6 Required Functionality — Systems Facade

- [ ] **FV-17:** `TradeVerificationService` exists at `lib/systems/verification/services/trade_verification_service.dart` — thin facade over repository + `StorageService`
- [ ] **FV-18:** Exposes `supportedTradeProofTypes = TradeProofType.values` (extensible vocabulary)
- [ ] **FV-19:** `HivorrLogger` + `PiiRedactor` redacted logging (`entityId: ***last4`, `type`, `mimeType`, `byteLength`, `professionId`); never logs `document_path` full or bytes
- [ ] **FV-20:** `PerformanceTracer` span `trade.proof.submit.duration` tagged `type`

### 2.7 Required Functionality — Provider

- [ ] **FV-21:** `TradeVerificationProvider` exists at `lib/data/providers/trade_verification_provider.dart` — `extends ChangeNotifier` (`provider:6.1.5`), extends `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42`)
- [ ] **FV-22:** State fields: `status: TradeVerificationStatus?`, `submitState: AsyncState`, `pollTimer: Timer?`
- [ ] **FV-23:** `submitTradeProof({...})` sets `submitState=loading`, calls `repo.submitTradeProof(...)`, then `refreshStatus()`; on `ApiException` sets `submitState=error(e)`
- [ ] **FV-24:** `refreshStatus()` calls `repo.getStatus()`, then `maybeNotify(status)`
- [ ] **FV-25:** `startPolling()` starts `Timer.periodic(Duration(seconds: 15))` calling `refreshStatus()` only while status non-terminal and screen visible; pauses on `WidgetsBindingObserver.didChangeAppLifecycleState(background)`, cancels on `dispose()` / `AppRouter didPop`
- [ ] **FV-26:** `maybeNotify(TradeVerificationStatus next)` diffs previous→next terminal (`approved|rejected`); on change emits `HivorrNotification{id: submissionId, title: 'Trade verification approved'|'Trade verification requires attention', body: professionName + decisionNotes preview (≤120 chars), priority: high, channel: system}` via `NotificationProvider`

### 2.8 Required Functionality — UI Screens

- [ ] **FV-27:** `TradeProofUploadScreen` exists at `lib/systems/verification/screens/trade_proof_upload_screen.dart` — stateful: (1) profession selector via `TaxonomyEngine` bound professions (unbound shows "Add a profession" CTA), selected chip uses `colorScheme.primaryContainer`; (2) `TradeProofTypePicker` chip group (5 options); (3) file picker via `XFile.readAsBytes()`, preview (`Image.memory` for images, PDF icon for `application/pdf`); (4) `HivorrButton(isLoading: submitState.isLoading, onPressed: picked!=null && profession!=null ? submit : null)` + `LinearProgressIndicator(value: sent/total)` from `onProgress`; (5) success shows `HivorrSuccessState` "We'll review within 24h" + CTA to `TradeVerificationStatusScreen`
- [ ] **FV-28:** `TradeVerificationStatusScreen` exists at `lib/systems/verification/screens/trade_verification_status_screen.dart` — reads `provider.status`: `HivorrLoadingState` while null; per-profession `TradeVerificationTimeline` (`Unverified → Submitted → Pending → Approved/Rejected` with `submittedAt`/`reviewedAt` timestamps + `decisionNotes`); `TradeVerifiedBadge` (green check + profession name) on `approved`; bid-lock panel when `TradeVerificationGate.canBid == false` ("Bidding is locked until your trade is verified" + CTA); `HivorrErrorState` with `decisionNotes` + "Resubmit" CTA on `rejected` (creates **new** `entity_credentials` row, not UPDATE); poll lifecycle tied to `WidgetsBindingObserver` + `AppRouter didPush/didPop`; pull-to-refresh calls `provider.refreshStatus()`
- [ ] **FV-29:** `AdminReviewQueueScreen` exists (simplified EP-02, Decision Log #3) — pending `verification_submissions` list with credential/type/profession, "Review" detail, approve/reject with `decisionNotes` via service-role seam (`verification_review_approve/reject` which flips `entity_professions.trade_verification_status` to `approved` + writes `trade_status_propagated` audit `supabase/migrations/20260829090003_verification_admin_review_schema.sql:466-489`); no pagination/filters/bulk/image preview

### 2.9 Required Functionality — UI Widgets

- [ ] **FV-30:** `TradeProofTypePicker` exists at `lib/systems/verification/widgets/trade_proof_type_picker.dart` — `ChoiceChip`/`HivorrChip` group, labels from `TradeProofType.label`
- [ ] **FV-31:** `TradeVerificationTimeline` exists at `lib/systems/verification/widgets/trade_verification_timeline.dart` — per-profession vertical stepper: dots `primary` active, `outline` pending, `error` rejected, `successContainer` approved; connectors `Divider(color: colorScheme.outline)`; dates `onSurfaceVariant` caption; no hardcoded hex
- [ ] **FV-32:** `TradeVerifiedBadge` exists at `lib/systems/verification/widgets/trade_verified_badge.dart` — `Icons.verified` tinted `colorScheme.secondary`, container `colorScheme.successContainer` soft elevation

### 2.10 Required Functionality — Routing & DI

- [ ] **FV-33:** `RoutePaths.tradeProofUpload = '/verification/trade-proof'`, `RoutePaths.tradeVerificationStatus = '/verification/trade/status'`, `RoutePaths.adminReviewQueue = '/admin/review-queue'` added to `lib/app/router/route_paths.dart`; `RouteNames` added; `app_router.dart:17` registered — entity routes guarded by `RouteGuard` (authenticated), admin queue additionally role-gated (internal)
- [ ] **FV-34:** Barrel `lib/systems/verification/verification.dart` re-exports all new symbols; `lib/data/data_layer.dart:1` updated with new exports
- [ ] **FV-35:** `TradeVerificationProvider.create(supabase: SupabaseClientProvider.client, storageService: SupabaseStorageService(...))` factory wired in bootstrap

### 2.11 Expected Workflows

- [ ] **FV-36:** Happy path upload: select bound profession (via `TaxonomyEngine`) → pick proof type → pick file → preview shown → tap submit → `validateForBucket` passes → `StoragePaths.credentialDocument` → upload with progress → `entity_credentials.insert` (with `profession_id`) → `remote.submit('trade_proof')` → success screen → navigate to status
- [ ] **FV-37:** Status tracking: status screen shows per-profession `TradeVerificationTimeline` with `Unverified → Submitted → Pending → Approved` timestamps; `TradeVerifiedBadge` appears on approval; `TradeVerificationGate.canBid == true` → no bid-lock panel
- [ ] **FV-38:** Bid-lock: `TradeVerificationGate.canBid == false` for `unverified/pending/rejected` → bid-lock panel "Bidding is locked until your trade is verified" with CTA to `TradeProofUploadScreen`
- [ ] **FV-39:** Status polling: timer polls `verification_status_get` every 15s while status non-terminal and screen foreground; cancels on `approved/rejected` terminal or screen pop; resumes on lifecycle foreground
- [ ] **FV-40:** Rejection resubmit: `HivorrErrorState` shows `decisionNotes` → "Resubmit" CTA clears pick → new `entity_credentials` row created (not UPDATE) → new `verification_submit('trade_proof')` queued
- [ ] **FV-41:** Dedup active: attempting `submitTradeProof` when a `pending/in_review` submission exists → `PLT005 conflict` → dialog "An active submission already exists" with "View status" action navigating to `TradeVerificationStatusScreen`
- [ ] **FV-42:** Admin review: pending queue → "Review" → approve with optional `decisionNotes` → `entity_professions.trade_verification_status → approved` + `trade_status_propagated` audit server-side → entity polls → `canBid == true`
- [ ] **FV-43:** Notification integration: `pending→approved` terminal transition triggers `maybeNotify` → `HivorrNotification{priority:high, channel:system}` via `NotificationProvider` → UI re-fetches `verification_status_get` before badge render

### 2.12 Success Conditions

- [ ] **FV-44:** `verification_submit(p_credential_id, p_submission_type='trade_proof')` RPC returns `{success:true, code:PLT000, data: verification_submissions row}` and creates `verification_audit_trail` entry `submission_created` server-side
- [ ] **FV-45:** `verification_status_get` returns `trade_verifications:[{profession_id, trade_verification_status}]` aggregate; per-profession status accurate
- [ ] **FV-46:** Approved profession unlocks bidding (`TradeVerificationGate.canBid == true`) per `AGENT.md:15` Rule 2; service is provider-swappable — screens consume `TradeVerificationProvider`/`TradeVerificationService` without importing `SupabaseClient.rpc` literals or `storage.from` strings (`ARCHITECTURE.md:101-110` compliant)

### 2.13 Error Handling Scenarios

- [ ] **FV-47:** Oversize file `10485761 bytes` → `StorageValidationException` `PLT003` before network — upload spy not invoked
- [ ] **FV-48:** Invalid MIME `application/x-msdownload` → `StorageValidationException` `PLT003` before network
- [ ] **FV-49:** Unbound/unknown professionId → `TaxonomyEngine` validation error surfaced, upload never attempted
- [ ] **FV-50:** `401 PLT001 auth` (unauthenticated) → `ApiException` surfaced → redirect `/login`
- [ ] **FV-51:** `403 PLT002 forbidden` (credential not owned / column violation) → `ApiException` surfaced
- [ ] **FV-52:** `404 PLT004 notFound` (credential not found / cross-entity `p_entity_id≠auth.uid()`) → `ApiException` surfaced
- [ ] **FV-53:** `409 PLT005 conflict` (active duplicate submission `supabase/migrations/20260829090003_verification_admin_review_schema.sql:159-161` partial index) → mapped to "You already have a pending verification for this document." dialog with "View status" CTA
- [ ] **FV-54:** `5xx PLT999 server` → `ApiException` surfaced; retry 3x prod / 4x dev with `500ms→8s` backoff (`ApiConfig.maxRetries 3/4`)
- [ ] **FV-55:** Network timeout → `ApiExceptionKind.timeout` mapped via `ApiExceptionMapper._mapTransport`; backoff applied; no retry loop without bound
- [ ] **FV-56:** Raw `DioException` never propagates to provider — `BaseApiService.invoke` normalizes all transport errors
- [ ] **FV-57:** Client attempt to invoke `verification_review_approve/reject` → `42501 insufficient privilege` mapped to `PLT002 forbidden` (service-role only `supabase/migrations/20260829090003_verification_admin_review_schema.sql:792-793`)

### 2.14 Important User Interactions

- [ ] **FV-58:** Fail-fast inline validation: `StorageValidators.validateForBucket` runs on file pick (before upload) — invalid MIME/size produces inline `Text(error)` with `colorScheme.error` under picker
- [ ] **FV-59:** Progress feedback: `onProgress(sent,total)` wired via Dio `onSendProgress` streams bytes — `LinearProgressIndicator` visible during upload, critical on slow Nigerian 3G
- [ ] **FV-60:** "We'll review within 24h" guidance text on success screen — sets expectation that approval is admin-reviewed
- [ ] **FV-61:** Pull-to-refresh on status screen calls `provider.refreshStatus()` immediately — no waiting for next 15s poll tick
- [ ] **FV-62:** Dedup dialog uses "View status" action navigating to `TradeVerificationStatusScreen`, not retry that would loop on `PLT005`
- [ ] **FV-63:** Bid-lock panel copy "Unverified — bidding is locked until approved" clear and CTA to upload; guidance "Accepted: JPG, PNG, WebP, PDF up to 10 MB" matches server `file_size_limit`/`allowed_mime_types`

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Files added ONLY under `lib/data/datasources/remote/trade_verification_remote_data_source.dart`, `supabase_trade_verification_remote_data_source.dart`, `lib/data/models/trade_verification_dto.dart`, `lib/data/entities/trade_verification*.dart`, `lib/data/mappers/verification_mapper.dart` (extend), `lib/data/repositories/trade_verification_repository*.dart`, `lib/data/providers/trade_verification_provider.dart`, `lib/systems/verification/models/trade_proof_type.dart`, `lib/systems/verification/services/trade_verification_service.dart`, `lib/systems/verification/gate/trade_verification_gate.dart`, `lib/systems/verification/screens/trade_*.dart`, `lib/systems/verification/widgets/trade_*.dart`, `lib/systems/verification/verification.dart`, `lib/app/router/` (3 route updates), `lib/data/data_layer.dart` (barrel update), and `test/**` — no files in `lib/core/storage/`, `lib/engine/`, `lib/integrations/payment_gateways/`, or `lib/systems/` other than `verification/`
- [ ] **TV-02:** No DDL on `public.*` or `storage.*` — `git diff --stat supabase/` shows 0; no `supabase/migrations/*` added, no `supabase/config.toml` modified; `lib/core/storage/*` diff = 0 (reuses `SupabaseStorageService:43`)
- [ ] **TV-03:** `lib/systems/verification/verification.dart` barrel re-exports all new symbols; `lib/data/data_layer.dart:1` updated
- [ ] **TV-04:** Interface-first pattern — abstract `TradeVerificationRepository` separate from `TradeVerificationRepositoryImpl`; abstract `TradeVerificationRemoteDataSource` separate from `SupabaseTradeVerificationRemoteDataSource`
- [ ] **TV-05:** No `public.*` or `storage.*` `SECURITY DEFINER` functions created; no `GRANT` statements; no `CREATE POLICY` statements (`supabase/migrations/` untouched)
- [ ] **TV-06:** Dependency wiring uses `SupabaseClientProvider.client` safe accessor (`supabase_client_provider.dart:19`) + `SupabaseClientProvider.currentAccessToken` (`:29`); no direct `Supabase.instance.client` leakage in business logic beyond provider

### 3.2 Required System Behavior

- [ ] **TV-07:** `StorageService.validateForBucket` called before SDK upload — spy test proves oversize never reaches `uploadBinary`; `StoragePaths.credentialDocument` produces `{entityId}/{submissionId}/{uuid}_{sanitized}` path matching `storage.foldername(name)[1]==auth.uid()::text` owner prefix
- [ ] **TV-08:** `upsert: false` on `credential-documents` upload; `entity_credentials.insert` has no `verification_status` or `reviewed_at` (RLS limited grant excludes these columns)
- [ ] **TV-09:** Client never writes `verification_submissions.status` or `entity_professions.trade_verification_status` — `grep -r "trade_verification_status` assignment = 0; display-only read via `verification_status_get` is permitted
- [ ] **TV-10:** `TaxonomyEngine` imported from `lib/workspace/profession_registry/taxonomy_engine.dart:12` (not duplicated) for profession validation + name resolution
- [ ] **TV-11:** Polling `Timer.periodic(15s)` pauses on `WidgetsBindingObserver.didChangeAppLifecycleState` background and cancels on `AppRouter didPop` — respects `supabase_realtime` exclusion (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:798-815`)
- [ ] **TV-12:** `TradeVerificationRemoteDataSource` does NOT inject `StorageService` — storage lives in repository/systems layer for `lib/data/` persistence-agnostic pattern
- [ ] **TV-13:** Error normalization via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:18`) — preserves `kind`, `code`, `statusCode`; message safe (no SQL/stack leaked)
- [ ] **TV-14:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) log `entityId suffix (***last4)`, `type`, `mimeType`, `byteLength`, `professionId`; never logs `document_path` full, never bytes, never personal name; `MonitoringService` span `trade.proof.submit` sampled

### 3.3 Module Integration

- [ ] **TV-15:** No conflict with existing `lib/core/storage/` — `SupabaseStorageService` consumed, not modified; `StorageBuckets.credentialDocuments` + `StoragePaths.credentialDocument` reused
- [ ] **TV-16:** No conflict with `lib/data/datasources/remote/taxonomy_envelope_parser.dart` — `EnvelopeParser` pattern reused (not re-implemented); `DataExceptionMapper` shared
- [ ] **TV-17:** No conflict with `lib/core/notifications/` — `NotificationProvider` consumed; `HivorrNotification` emitted via domain provider channel, not direct `flutter_local_notifications` plugin call
- [ ] **TV-18:** Reuses `VerificationProvider` pattern from `lib/data/providers/verification_provider.dart:42` — `TradeVerificationProvider` extends it (15s polling, `WidgetsBindingObserver`, notification hook)
- [ ] **TV-19:** `lib/systems/verification/` consumable by marketplace `EP-03` (bid-lock server-side) without modification; `TradeVerificationGate.canBid` reusable client-side mirror
- [ ] **TV-20:** Unidirectional dependency `data → systems` — repository never imports `lib/systems/` widgets

### 3.4 Technical Requirements from Plan

- [ ] **TV-21:** `flutter analyze` + `dart analyze` clean
- [ ] **TV-22:** `TradeVerificationRemoteDataSource` dartdoc documents RPC envelope contract, `BaseApiService.invoke` pattern, `DataExceptionMapper` error mapping
- [ ] **TV-23:** `TradeVerificationRepository` dartdoc documents `submitTradeProof` `Uint8List+onProgress+professionId`, `validateForBucket`-first, `TaxonomyEngine` profession resolve
- [ ] **TV-24:** `TradeVerificationProvider` dartdoc documents polling lifecycle, `maybeNotify` terminal diff, `Timer.periodic 15s` + backoff; `TradeVerificationGate.canBid` documented as `AGENT.md:15` Rule 2 mirror
- [ ] **TV-25:** `PerformanceTracer` span `trade.proof.submit.duration` tagged `type` (no PII), sampled via `MonitoringConfig`

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **DV-01:** `entity_credentials` insert shape: `{entity_id: auth.uid(), kind: (from TradeProofType), title: 'professionName — tradeProofTypeLabel', document_path: storageKey, profession_id: boundProfessionId}` — no `verification_status`, no `reviewed_at` (RLS limited grant excludes); `profession_id` FK → `professions(id)` (`supabase/migrations/20260821090002_entity_core_tables.sql:120-150`)
- [ ] **DV-02:** `verification_submissions` row created server-side via `verification_submit(p_credential_id, p_submission_type='trade_proof')` RPC — client never directly inserts; `submission_type` coalesced from `entity_credentials.kind` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:358`); `id, entity_id, credential_id, status, priority, submitted_at` populated; `reviewed_at, reviewed_by, decision_notes` default null

### 4.2 Data Updates

- [ ] **DV-03:** Client never updates `verification_submissions.status` — only service-role `review_approve/reject` RPCs (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:412,530`) can mutate status; authenticated `UPDATE` grant absent
- [ ] **DV-04:** Client never writes `entity_professions.trade_verification_status` — server-side RPC `review_approve` flips to `approved` and writes `trade_status_propagated` audit (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:466-489`); `pending` derived client-side from `verification_submissions` (Decision Log #2), DB default `unverified`
- [ ] **DV-05:** Resubmit after rejection creates **new** `entity_credentials` row (not UPDATE) — corrections are resubmissions per `supabase/migrations/20260821090002_entity_core_tables.sql:167` comment

### 4.3 Data Relationships

- [ ] **DV-06:** `entity_credentials.id` is FK for `verification_submit(p_credential_id)` — insert returned from `supabase.from('entity_credentials').insert(...).select().single()`
- [ ] **DV-07:** One-active-submission invariant: partial unique index `credential_id where status in (pending, in_review)` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:159-161`) enforced at DB level; client handles `PLT005` conflict dialog
- [ ] **DV-08:** Profession binding M:N `unique(entity_id, profession_id)` on `entity_professions` (`supabase/migrations/20260821090002_entity_core_tables.sql:170-186`) — per-profession gate; RLS grant **excludes** write (`supabase/migrations/20260821090003_entity_model_rls_policies.sql:125-127`)
- [ ] **DV-09:** `trade_verifications:[{profession_id, trade_verification_status}]` array from `verification_status_get` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:592-681`) is display-only; `unverified|pending|approved|rejected` values (`supabase/migrations/20260821090002_entity_core_tables.sql:170-186`)

### 4.4 Data Accuracy

- [ ] **DV-10:** Status enum mapping exact: `unverified|pending|approved|rejected` per profession — mapper unit test covers all 4 values
- [ ] **DV-11:** `decision_notes` null-safe, preview length ≤120 chars for notification body, full ≤5000 chars from `supabase/migrations/20260829090003_verification_admin_review_schema.sql:140-142`
- [ ] **DV-12:** `pending` derived correctly client-side from `verification_submissions` status when no explicit `trade_verification_status` advance; `unverified` remains DB default, never falsely promoted

### 4.5 Data Integrity

- [ ] **DV-13:** `verification_audit_trail` rows `submission_created|review_approved|trade_status_propagated` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:209-214`) written server-side by RPCs; client never inserts audit rows directly
- [ ] **DV-14:** Idempotency: submission idempotency is credential-scoped (`PLT005`); retry with same `credentialId` returns `409 conflict`, not duplicate queue
- [ ] **DV-15:** No `public.*` table mutation by client; `verification_submissions`, `verification_reviews`, `verification_audit_trail`, `entity_credentials`, `entity_professions` all unchanged by client RPC calls — `git diff --stat supabase/` = 0
- [ ] **DV-16:** `expires_at` NOT captured — no `expires_at` DDL, license-expiry tracking deferred (Decision Log #1)

---

## 5. Security Verification

- [ ] **SV-01:** Server-authoritative gate (`AGENT.md:16` Rule 4) — client never writes `verification_submissions.status` or `entity_professions.trade_verification_status`; `grep -r "trade_verification_status" assignment lib/{data,systems}/verification` = 0 (read-only display permitted)
- [ ] **SV-02:** All verification tables `revoke all from anon, authenticated` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:244-246`) + policies `to authenticated` only; `anon` zero read verified in `supabase/tests/database/021_*`; `RouteGuard` redirects to `/login`
- [ ] **SV-03:** Private credential isolation — `credential-documents public=false` (`supabase/config.toml:37`); `getPublicUrl` throws `StorageValidationException` (`supabase_storage_service.dart:264`); preview via `createSignedUrl(60)` short TTL HMAC-signed; `grep -r "getPublicUrl" lib/systems/verification` = 0
- [ ] **SV-04:** Path traversal / prefix escape blocked — `StoragePaths.sanitize` strips `..`, `/`, control chars; server `WITH CHECK (storage.foldername(name))[1]=auth.uid()::text` authoritative; owner prefix `{entityId}/{submissionId}/...` (analog `017_storage_posture.sql:118`)
- [ ] **SV-05:** Profession-binding integrity — `entity_credentials.profession_id` FK + `entity_professions` M:N + `unique(entity_id, profession_id)`; `TaxonomyEngine` validates the binding before upload, preventing cross-profession proof mis-attribution or unbound submissions
- [ ] **SV-06:** MIME/size DoS prevention — `StorageValidators.validateForBucket` blocks before SDK; server `file_size_limit 10485760` second gate; `text/html`, `application/x-msdownload` rejected client-side
- [ ] **SV-07:** Anon write DoS — `anon` zero INSERT/UPDATE/DELETE on verification tables; service requires `authenticated` (fails closed via `SupabaseClientProvider.client` guard)
- [ ] **SV-08:** Auth token protection — token via `SupabaseClientProvider.currentAccessToken:29` never logged; `PiiRedactor` masks `entityId` to `***last4`; never logs `document_path` full, bytes, or `decisionNotes` beyond preview length
- [ ] **SV-09:** No `service_role` in client code — `grep -r "service_role" lib/` = 0; `SupabaseClientProvider.client` uses `anon`/`authenticated` role with RLS; `review_approve/reject` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:792-793` granted to `service_role` only, admin UI role-gated without exposing the `service_role` key
- [ ] **SV-10:** Race condition — partial unique index `verification_submissions_one_active_credential_idx` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:159-161`) prevents parallel `submit` racing; second gets `PLT005 conflict` mapped to dialog
- [ ] **SV-11:** Auth state isolation — `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010`; `credential-documents` bucket per environment via migration, no cross-env read
- [ ] **SV-12:** No SQL injection — RPC calls use parameterized `supabase.rpc('verification_*', params:{...})`; `entity_credentials.insert` is SDK-constructed, not raw SQL; no dynamic query interpolation

---

## 6. Performance Verification

- [ ] **PV-01:** Polling cost — `Timer.periodic(15s)` only while status non-terminal and screen visible; 1 RPC/15s ≈ 240 req/hour peak; `verification_status_get` is `STABLE` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:598`) and indexed (`verification_submissions_entity_status_idx` `:150`)
- [ ] **PV-02:** Polling pause — `WidgetsBindingObserver.didChangeAppLifecycleState(background)` pauses timer; `AppRouter didPush/didPop` cancels on navigate away; no wasted RPCs on background/backgrounded screens
- [ ] **PV-03:** Backoff — `timeout/network` errors trigger exponential `500ms→8s` backoff (`ApiConfig.maxRetries 3/4`); no retry storm; terminal `approved/rejected` cancels timer immediately
- [ ] **PV-04:** Upload size — 10 MiB single-part, no chunking; `onProgress` Dio `onSendProgress` streams bytes; `Uint8List` single allocation; no base64 double-copy
- [ ] **PV-05:** Caching — `TradeVerificationProvider` memoizes `status` in memory (no Hive local data source); invalidate via `refreshStatus()` on resume, submit, or notification; no disk persistence of `document_path` beyond credential row
- [ ] **PV-06:** Signed URL — `createSignedUrl(60)` minimal signing overhead; short TTL prevents CDN caching of sensitive docs; `getPublicUrl` not used (throws)
- [ ] **PV-07:** Validation cost — `TaxonomyEngine` profession resolution O(log n) + `StorageValidators.validateForBucket` O(1) map lookup + timer; filename sanitize O(n) on <255 chars — negligible, avoids wasted multipart on slow 3G
- [ ] **PV-08:** Gate evaluation — `TradeVerificationGate.canBid` pure list scan O(n) over `trade_verifications` — free to call per screen render
- [ ] **PV-09:** `PerformanceTracer` span `trade.proof.submit.duration` sampled via `MonitoringConfig`, tags `trade.type`, no PII — lightweight overhead

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/data/verification/trade_*` + `test/unit/systems/verification/`

Pattern mirrors `EP-02-10` §14.1 + fakes (`test/support/fakes/`) — no live Supabase.

- [ ] **TT-01:** `trade_verification_remote_data_source_test.dart` ≥14 cases green — mock `SupabaseClient.rpc` via fake: `verification_submit('trade_proof') → {success:true, data:{id, status:pending}}` success; `{success:false, code:PLT005}` → `ApiExceptionKind.conflict PLT005`; `verification_status_get → {trade_verifications:[...]}` parse; envelope `success:false` → throws; `401→PLT001 auth`, `404→PLT004`, `409→PLT005`, `500→PLT999` via `ApiExceptionMapper`
- [ ] **TT-02:** `trade_verification_repository_test.dart` ≥20 cases green — fake `StorageService` + fake remote: validates `validateForBucket` called first (oversize `10485761` never hits fake upload spy); path `entityId/submissionId/uuid_name.jpg` regex; `profession_id` present in credential insert; `mimeType` normalized; `verification_submit('trade_proof')` invoked; duplicate `credentialId` surfaces `conflict`; `getStatus` maps `trade_verifications` array
- [ ] **TT-03:** `trade_verification_provider_test.dart` ≥14 cases green — `ChangeNotifier` with mocked repository: `submitTradeProof` sets `submitState=loading` then `idle`, calls `refreshStatus`; polling `Timer` mocked via `fakeAsync` — 15s ticks until `approved`, cancels on dispose; `maybeNotify` emits `HivorrNotification` only on terminal transition; `WidgetsBindingObserver` pause/resume
- [ ] **TT-04:** `trade_verification_gate_test.dart` ≥8 cases green — pure logic: `canBid(status, professionId)` returns `true` iff `trade_verification_status == approved`; returns `false` for `unverified/pending/rejected`; correct per-profession lookup with M:N; unknown/absent profession → `false` (locked) — 100% coverage (target)
- [ ] **TT-05:** `trade_proof_type_test.dart` ≥6 cases green — enum labels, `TradeProofType.fromTitle`, `kind` mapping, extensibility `values.length==5`
- [ ] **TT-06:** `trade_verification_mapper_test.dart` ≥8 cases green — DTO→entity mapping `unverified|pending|approved|rejected`, `decision_notes ≤5000` truncate, null handling
- [ ] **TT-07:** Total ≥70 unit assertions; repository/provider ≥90% coverage, gate 100%, mappers/DTOs 100% (`flutter test --coverage`)

### 7.2 Automated Widget Suite — `test/widget/systems/verification/trade_*`

- [ ] **TT-08:** `trade_proof_upload_screen_test.dart` ≥10 cases green — pump with `Provider<TradeVerificationProvider>` fake + `AppTheme.light`: profession chip + type chip selection highlight `colorScheme.primaryContainer` (no `Colors.*`), file pick mock sets preview, `HivorrButton.isLoading` shows `HivorrLoader`, progress `LinearProgressIndicator` visible when `onProgress` fired, error field shows `colorScheme.error` for oversize, `grep Colors.` assert = 0
- [ ] **TT-09:** `trade_verification_status_screen_test.dart` ≥12 cases green — mock `TradeVerificationStatus{pending→timeline 2 active dots, approved→TradeVerifiedBadge + no bid-lock, rejected→HivorrErrorState + decisionNotes + Resubmit, unverified→bid-lock panel + CTA}`; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily` literal), spacing = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:220`)
- [ ] **TT-10:** `trade_verification_timeline_test.dart` ≥8 cases green — timeline dot colors `primary/successContainer/error/outline` per status, no hardcoded hex, per-profession rendering
- [ ] **TT-11:** `admin_review_queue_screen_test.dart` ≥8 cases green — pending list renders, approve/reject with notes triggers service-role seam (fake), empty state `HivorrEmptyState`, role-gated access
- [ ] **TT-12:** All widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)` — AppTheme harness pattern from existing test suite

### 7.3 Integration (Fake-E2E) — `test/integration/verification/`

- [ ] **TT-13:** `test/integration/verification/trade_verification_flow_test.dart` green — fake `SupabaseStorageClient` + fake `SupabaseClient.rpc` map + real `TradeVerificationRepositoryImpl`: bind profession → `repo.submitTradeProof(...)` → status `pending` → mock `verification_review_approve` side-effect (inject `TradeVerificationDto{profession_id, trade_verification_status:approved}`) → `provider.refreshStatus()` → `TradeVerificationGate.canBid == true` (bid-lock released); no `supabase start` container needed; live `supabase db test` is the source-of-truth for RLS

### 7.4 Regression Guard

- [ ] **TT-14:** `flutter analyze` + `dart analyze` clean
- [ ] **TT-15:** `flutter test --coverage` — domain ≥80% line coverage, gate 100%; widgets theme-asserted
- [ ] **TT-16:** `supabase db test` full suite `001..017` + verification `021_*` green — zero regressions on `public.*` RLS/posture; `017_storage_posture.sql` (credential private, anon zero write) still green
- [ ] **TT-17:** `grep -r "Colors\.\|Color(0x" lib/systems/verification` = 0, `grep -r "fontFamily" lib/systems/verification` = 0, `grep -r "getPublicUrl" lib/systems/verification` = 0, `grep -r "service_role" lib/` = 0, `grep -r "trade_verification_status` assignment = 0
- [ ] **TT-18:** `git diff --stat supabase/` = 0; `git diff --stat lib/core/storage` = 0

### 7.5 Edge Cases

- [ ] **TT-19:** Boundary sizes: 0 bytes, exactly 10485760 bytes (accepted), 10485761 bytes (rejected)
- [ ] **TT-20:** MIME case insensitivity: `IMAGE/JPEG` accepted; extension↔MIME mismatch normalization
- [ ] **TT-21:** Filename edge: empty, 300-char truncation to 180 chars, `../../etc/passwd` sanitized, `entityId//double-slash` sanitized
- [ ] **TT-22:** All 5 `TradeProofType` values accepted → correct `kind` mapping in credential insert
- [ ] **TT-23:** Per-profession M:N — multiple professions, one `approved`, one `unverified`: `canBid` true only for the approved profession
- [ ] **TT-24:** `p_entity_id` null (self) vs supplied (admin) — no cross-entity read via client; `PLT004` if forced

### 7.6 Failure Scenarios

- [ ] **TT-25:** Duplicate active submission → `PLT005 conflict` dialog with "View status" navigation (not retry loop)
- [ ] **TT-26:** Network timeout → `PLT999` backoff `500ms→8s`; visible retry affordance
- [ ] **TT-27:** `401→PLT001` unauth → redirect to `/login` via `RouteGuard`
- [ ] **TT-28:** `403 PLT002` column violation (e.g. attempting `status:approved` in insert) → `ApiException` surfaced, not raw SQL
- [ ] **TT-29:** Envelope `success:false, code:PLT003` → `ApiExceptionKind.validation` surfaced; no raw JSON to UI
- [ ] **TT-30:** Client attempt to invoke `verification_review_approve` → `42501` mapped to `PLT002 forbidden`

### 7.7 Manual Testing

- [ ] **TT-31:** Manual spot-check (optional, with `supabase start`): select bound profession → pick proof type → preview → upload 5 MiB → `onProgress` shows → submit → `pending` status visible → bid-lock panel present → admin approves → poll → `TradeVerifiedBadge` + bid-lock released; signed URL preview renders within 60s then expires

---

## 8. User Acceptance Verification

This task delivers the trade verification seam — the marketplace participation gate. User acceptance is verified through per-profession proof flow correctness, bid-lock behavior, admin review, and downstream readiness.

- [ ] **UA-01:** The project lead can select a bound profession via `TaxonomyEngine` (unbound shows "Add a profession" CTA), pick any of 5 proof types, and submit any ≤10 MiB `jpeg/png/webp/pdf` with `onProgress` feedback without encountering raw `PLT003` errors
- [ ] **UA-02:** Guidance text "Accepted: JPG, PNG, WebP, PDF up to 10 MB" matches server `file_size_limit`/`allowed_mime_types`; fail-fast inline "File too large — please use a file under 10 MB" appears before network on 3G
- [ ] **UA-03:** Status screen shows per-profession `TradeVerificationTimeline` with `Unverified → Submitted → Pending → Approved/Rejected` with timestamps; pull-to-refresh immediate; badge `TradeVerifiedBadge` + profession name on approval; bid-lock panel `Bidding is locked until your trade is verified` when `canBid == false`
- [ ] **UA-04:** Rejection renders empathy `HivorrErrorState` + `decisionNotes` + single "Resubmit" CTA; dedup `PLT005` dialog has "View status" not loop retry
- [ ] **UA-05:** Notification high-priority on terminal `pending→approved/rejected`; UI re-fetches truth before badge render (prevents spoofed local state)
- [ ] **UA-06:** Admin review queue (simplified) shows pending submissions first, one-step approve/reject with optional `decisionNotes`; approval flips `entity_professions.trade_verification_status → approved` + `trade_status_propagated` audit; bid-lock released server-side
- [ ] **UA-07:** Premium finish — `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), `HivorrEmpty/Loading/Error/SuccessState` warm microcopy (`VISUAL-IDENTITY.md:241`), soft elevation not hard shadow, 8pt grid, ≥48dp touch targets, light/dark WCAG AA `#0B6E99`
- [ ] **UA-08:** No financial/escrow leakage — `grep -r "financial_\|escrow\|payout" lib/systems/verification` = 0; no `lib/integrations/payment_gateways` import; no `expires_at` DDL (Decision Log #1 deferred); no `verification_can_bid` RPC (Decision Log #4 — single `verification_status_get` aggregate)
- [ ] **UA-09:** Downstream unblocked — marketplace `EP-03` (bid-lock server-side) can consume `TradeVerificationGate`/`TradeVerificationStatus`; verified professional can bid on approved professions per `AGENT.md:15` Rule 2

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-11 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/data/datasources/remote/trade_verification_remote_data_source.dart` exists — abstract `submit`, `getStatus` | File inspection | ☑ |
| 2 | `supabase_trade_verification_remote_data_source.dart` extends `BaseApiService`, uses `supabase.rpc('verification_submit')` with `submission_type='trade_proof'` + `verification_status_get` + `EnvelopeParser` + `ApiExceptionMapper` | Code review + unit test | ☑ |
| 3 | DTOs `trade_verification_dto.dart` + entities `trade_verification_status.dart`/`trade_verification.dart` + `verification_mapper.dart` trade methods map `unverified|pending|approved|rejected` per profession without leaking RPC JSON shape | File + mapper unit test | ☑ |
| 4 | `lib/systems/verification/models/trade_proof_type.dart` defines `TradeProofType` enum (5 values: `certificate/license/workSample/portfolio/other`, labels, `kind` mapping) — extensible without schema | File inspection | ☑ |
| 5 | `TradeVerificationRepository submitTradeProof` orchestrates: `validateForBucket` → `TaxonomyEngine` resolve → `StoragePaths.credentialDocument` → `StorageService.upload` → `entity_credentials.insert` (with `profession_id`) → `remote.submit('trade_proof')`; validation before network (spy test: oversize never hits upload, profession_id in insert) | Code + repo unit test | ☑ |
| 6 | `TradeVerificationProvider` `ChangeNotifier` holds `TradeVerificationStatus`, `AsyncState submitState`, `startPolling/stopPolling` 15s timer, `maybeNotify` terminal transition, `WidgetsBindingObserver` lifecycle | Unit test (`fakeAsync` timer + notification diff) | ☑ |
| 7 | `TradeVerificationGate.canBid(status, professionId)` pure function — `true` iff `approved`, correct per-profession M:N lookup, absent → `false` | Unit test | ☑ |
| 8 | `TradeVerificationService` facades repo + `HivorrLogger` redacted + `PerformanceTracer trade.proof.submit.duration` | File inspection | ☑ |
| 9 | `TradeProofUploadScreen` uploads with `onProgress LinearProgressIndicator` + `HivorrButton(isLoading)` + `HivorrLoader`, profession + type selectors, uses `credential-documents` private via `StorageService` only | Widget test + `grep getPublicUrl` = 0 | ☑ |
| 10 | `TradeVerificationStatusScreen` renders per-profession `TradeVerificationTimeline` + `TradeVerifiedBadge` + bid-lock panel when `canBid==false` + `HivorrErrorState` for `rejected` with `decisionNotes`, poll lifecycle + pull-to-refresh | Widget test | ☑ |
| 11 | `AdminReviewQueueScreen` lists pending submissions + approve/reject with `decisionNotes` via service-role seam (simplified EP-02) | Widget test + code review | ☑ |
| 12 | All screens/widgets consume `AppTheme` tokens only — `colorScheme.*`, `textTheme.*`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` — no `Colors.*`, no `Color(0xFF…)`, no `fontFamily:` literal | `grep` + widget test token asserts | ☑ |
| 13 | Routes `/verification/trade-proof`, `/verification/trade/status`, `/admin/review-queue` added to `route_paths.dart` + `route_names.dart` + `app_router.dart`, guarded by `RouteGuard` (authenticated; admin role for queue) | File + router test | ☑ |
| 14 | Barrels `lib/systems/verification/verification.dart` and `lib/data/data_layer.dart` re-export all new symbols | File inspection | ☑ |
| 15 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat` shows only `lib/**` + `test/**` + `router/**` | `git diff --stat` | ☑ |
| 16 | No `lib/core/storage/*` changes — `git diff --stat lib/core/storage` = 0 (reuses `SupabaseStorageService`) | `git diff --stat` | ☑ |
| 17 | No financial/escrow logic — `grep -r "financial_\|escrow\|payout" lib/systems/verification` = 0; no `lib/integrations/payment_gateways/` import | `grep` | ☑ |
| 18 | No `service_role`/secret leak — `grep -r "service_role\|sk_live\|supabase_secret" lib/` = 0; `SupabaseClientProvider.client` only | `grep` + code review | ☑ |
| 19 | `entity_professions.trade_verification_status` never assigned by client — read-only display only, no DB write | `grep` + code review | ☑ |
| 20 | Error normalization `401→PLT001`, `403→PLT002`, `400/422→PLT003`, `404→PLT004`, `409→PLT005`, `5xx→PLT999` via `ApiExceptionMapper`; raw `DioException` never propagates | Unit test | ☑ |
| 21 | `trade_verification_remote_data_source_test.dart` ≥14 cases green | `flutter test` | ☑ |
| 22 | `trade_verification_repository_test.dart` ≥20 cases green | `flutter test` | ☑ |
| 23 | `trade_verification_provider_test.dart` ≥14 cases green | `flutter test` | ☑ |
| 24 | `trade_verification_gate_test.dart` ≥8 + `trade_proof_type_test.dart` ≥6 + `trade_verification_mapper_test.dart` ≥8 green | `flutter test` | ☑ |
| 25 | `trade_proof_upload_screen_test.dart` ≥10 + `trade_verification_status_screen_test.dart` ≥12 + `trade_verification_timeline_test.dart` ≥8 + `admin_review_queue_screen_test.dart` ≥8 green | `flutter test` | ☑ |
| 26 | `trade_verification_flow_test.dart` fake-E2E green (bind → submit → pending → mockApprove → `canBid==true`) | `flutter test` | ☑ |
| 27 | `flutter analyze` + `dart analyze` clean | CI | ☑ |
| 28 | `flutter test --coverage` domain ≥80%, gate 100%; `supabase db test` full suite `001..021` green | `supabase db test` | ☑ |
| 29 | Visual identity: `grep -r "Colors\.\|Color(0x" lib/systems/verification` = 0, `grep -r "fontFamily" lib/systems/verification` = 0, `grep -r "getPublicUrl" lib/systems/verification` = 0; premium finish (`HivorrLoader`, soft elevation, 48dp touch, 16dp/24dp padding, WCAG AA) | Code review | ☑ |

---

> **Sign-off:** Task EP-02-11 marked **Completed** -- all 29 conditions in the Final Approval Checklist are verified and signed off by the project lead.
