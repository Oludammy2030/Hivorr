# Definition of Done — EP-02-10: Identity Verification System

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-10 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-10-Identity Verification System.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-10 |
| **Task Name** | Identity Verification System |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 4 — Trust & Verification Systems |
| **Priority** | High |
| **Dependencies** | EP-02-03 (Verification Schema — 5 tables, 6 RPCs), EP-02-06 (Storage Infrastructure — `credential-documents` private bucket), EP-02-07 (Taxonomy Engine — envelope parser pattern) |
| **Blocks** | EP-02-11 (Trade Verification), EP-02-12 (KYC Framework), EP-02-18 (Onboarding Flow) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-10-Identity Verification System.md` |

---

## 2. Functional Verification

This task delivers a server-authoritative identity verification seam: document-type selection, `credential-documents` upload via `StorageService`, `entity_credentials` creation, `verification_submit` queueing, and real-time status tracking with KYC tier assignment and notification integration. Functional verification confirms the data layer, service facade, provider, screens, and routing behave correctly and never bypass server-enforced invariants.

### 2.1 Required Functionality — Domain Vocabulary

- [ ] **FV-01:** `lib/systems/verification/models/document_type.dart` defines `DocumentType` enum with 5 values: `nationalId`, `passport`, `driversLicense`, `votersCard`, `ninSlip` — each with display label (e.g. "National ID (NIN)", "Driver's License (FRSC)", "Voter's Card (INEC)") and `kind='identity_document'`, `submission_type='identity_document'` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:130`)
- [ ] **FV-02:** `DocumentType` extensible without schema change — adding `bvn` requires only an enum value + label; `kind` stays `identity_document` and `submission_type` stays `identity_document`

### 2.2 Required Functionality — Data Layer (Entities, DTOs, Mappers)

- [ ] **FV-03:** `VerificationSubmissionDto` exists at `lib/data/models/verification_submission_dto.dart` — `fromJson` maps `entity_id`, `credential_id`, `submission_type`, `status`, `priority`, `submitted_at`, `reviewed_at`, `decision_notes`; handles null `reviewed_at` and `decision_notes`
- [ ] **FV-04:** `VerificationStatusDto` exists at `lib/data/models/verification_status_dto.dart` — `fromJson` maps `entity_id`, `identity_verified`, `kyc{tier_code, status, limits}`, `trade_verifications[]`, `pending_submissions`, `total_submissions`
- [ ] **FV-05:** `KycLevelDto` exists at `lib/data/models/kyc_level_dto.dart` — `fromJson` maps `tier_code`, `status`, `limits{daily, weekly, monthly, cashout}`
- [ ] **FV-06:** `VerificationLimitsDto` exists at `lib/data/models/verification_limits_dto.dart` — `fromJson` maps `tier_code`, `daily`, `weekly`, `monthly`, `cashout`
- [ ] **FV-07:** Entities `VerificationSubmission`, `VerificationStatus`, `KycLevel` exist at `lib/data/entities/` — pure Dart, no Flutter/Supabase imports; `VerificationSubmission` holds `DocumentType` enum (not raw string)
- [ ] **FV-08:** `lib/data/mappers/verification_mapper.dart` maps DTO→Entity with status enum conversion: `pending|in_review|approved|rejected|requires_resubmission` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:133-135`), `kyc limits` numeric, `decision_notes` null-safe

### 2.3 Required Functionality — Remote Data Source

- [ ] **FV-09:** `VerificationRemoteDataSource` abstract exists at `lib/data/datasources/remote/verification_remote_data_source.dart` — methods `submit(credentialId, submissionType?)`, `getStatus(entityId?)`, `getKycLevel()`, `getLimits()`
- [ ] **FV-10:** `SupabaseVerificationRemoteDataSource` exists at `lib/data/datasources/remote/supabase_verification_remote_data_source.dart` — `extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`), uses `supabase.rpc` for all 4 methods
- [ ] **FV-11:** Envelope unwrap via `EnvelopeParser` (pattern from `lib/data/datasources/remote/taxonomy_envelope_parser.dart`) validates `success==true && code==PLT000` before DTO mapping; malformed envelope throws `ApiExceptionKind.server`
- [ ] **FV-12:** Error mapping via `DataExceptionMapper` (`lib/data/datasources/remote/data_exception_mapper.dart:1`) — `PLT001→auth`, `PLT002→forbidden`, `PLT003→validation`, `PLT004→notFound`, `PLT005→conflict`, `PLT999→server`; raw `DioException` never propagates

### 2.4 Required Functionality — Repository

- [ ] **FV-13:** `VerificationRepository` abstract + `VerificationRepositoryImpl` exist at `lib/data/repositories/verification_repository.dart` + `verification_repository_impl.dart`
- [ ] **FV-14:** `submitIdentityDocument({DocumentType, Uint8List bytes, String mimeType, String fileName, void Function(int,int)? onProgress})` orchestrates: (1) `storageService.validateForBucket(bucket: StorageBuckets.credentialDocuments, mimeType, byteLength)` — throws `StorageValidationException` `PLT003` before network; (2) `submissionId = Uuid.v4()` → `StoragePaths.credentialDocument(entityId: auth.uid(), submissionId, fileName)` → `{entityId}/{submissionId}/{uuid}_{sanitized}`; (3) `storageService.upload(bucket: credentialDocuments, path, bytes, mimeType, fileName, onProgress, upsert: false)`; (4) `supabase.from('entity_credentials').insert({entity_id: auth.uid(), kind: 'identity_document', title: documentType.label, document_path: storageKey, profession_id: null}).select().single()`; (5) `remote.submit(credentialId: cred['id'], submissionType: 'identity_document')`
- [ ] **FV-15:** `getStatus()` delegates to `remote.getStatus()` and maps DTO→Entity; `getKycLevel()` and `getLimits()` similarly delegate
- [ ] **FV-16:** `pollStatus({interval, backoff})` is not repository-level — provider timer calls `getStatus()` every 15s until terminal (`approved|rejected|requires_resubmission`), with `ApiConfig.forEnvironment` retry on `timeout/network`

### 2.5 Required Functionality — Systems Facade

- [ ] **FV-17:** `IdentityVerificationService` exists at `lib/systems/verification/services/identity_verification_service.dart` — thin facade over repository + `StorageService`
- [ ] **FV-18:** Exposes `supportedDocumentTypes = DocumentType.values` (extensible vocabulary)
- [ ] **FV-19:** `HivorrLogger` + `PiiRedactor` redacted logging (`entityId: ***last4`, `documentType`, `mimeType`, `byteLength`); never logs `document_path` full or bytes or `legal_name`
- [ ] **FV-20:** `PerformanceTracer` span `verification.submit.duration` tagged `documentType`

### 2.6 Required Functionality — Provider

- [ ] **FV-21:** `VerificationProvider` exists at `lib/data/providers/verification_provider.dart` — `extends ChangeNotifier` (`provider:6.1.5`)
- [ ] **FV-22:** State fields: `status: VerificationStatus?`, `kycLevel: KycLevel?`, `limits: VerificationLimits?`, `submitState: AsyncState`, `pollTimer: Timer?`
- [ ] **FV-23:** `submitIdentityDocument({...})` sets `submitState=loading`, calls `repo.submitIdentityDocument(...)`, then `refreshStatus()`; on `ApiException` sets `submitState=error(e)`
- [ ] **FV-24:** `refreshStatus()` calls `repo.getStatus()` + `repo.getKycLevel()`, then `maybeNotify(status)`
- [ ] **FV-25:** `startPolling()` starts `Timer.periodic(Duration(seconds: 15))` calling `refreshStatus()` only while `status in (pending, in_review)` and screen visible; pauses on `WidgetsBindingObserver.didChangeAppLifecycleState(background)`, cancels on `dispose()`
- [ ] **FV-26:** `maybeNotify(VerificationStatus next)` diffs previous→next terminal (`approved|rejected|requires_resubmission`); on change emits `HivorrNotification{id: submissionId, title: 'Verification ${next}', body: ... (≤120 chars), priority: high, channel: system}` via `NotificationProvider` (`lib/core/notifications/providers/notification_provider.dart:1`)

### 2.7 Required Functionality — UI Screens

- [ ] **FV-27:** `IdentityDocumentUploadScreen` exists at `lib/systems/verification/screens/identity_document_upload_screen.dart` — stateful: (1) `DocumentTypePicker` chip group (5 options), selected chip uses `colorScheme.primaryContainer`; (2) file picker via `XFile.readAsBytes()`, preview (`Image.memory` for images, PDF icon for `application/pdf`); (3) `HivorrButton(isLoading: submitState.isLoading, onPressed: picked!=null ? submit : null)` + `LinearProgressIndicator(value: sent/total)` from `onProgress`; (4) success shows `HivorrSuccessState` "We'll review within 24h" + CTA to `VerificationStatusScreen`
- [ ] **FV-28:** `VerificationStatusScreen` exists at `lib/systems/verification/screens/verification_status_screen.dart` — reads `provider.status`: `HivorrLoadingState` while null; `VerificationTimeline` vertical stepper with `submittedAt`/`reviewedAt` timestamps; `IdentityVerifiedBadge` + `KycLevelCard` showing `tier_1 Identity Verified` + limits chips on `approved`; `HivorrErrorState` with `decisionNotes` + "Resubmit" CTA on `rejected/requires_resubmission`; poll lifecycle tied to `WidgetsBindingObserver` + `AppRouter didPush/didPop`; pull-to-refresh calls `provider.refreshStatus()`

### 2.8 Required Functionality — UI Widgets

- [ ] **FV-29:** `VerificationTimeline` exists at `lib/systems/verification/widgets/verification_timeline.dart` — vertical stepper: dots `primary` active, `outline` pending, `error` rejected, `successContainer` approved; connectors `Divider(color: colorScheme.outline)`; dates `onSurfaceVariant` caption; no hardcoded hex
- [ ] **FV-30:** `IdentityVerifiedBadge` exists at `lib/systems/verification/widgets/identity_verified_badge.dart` — `Icons.verified` tinted `colorScheme.secondary`, `KycLevelCard` container `colorScheme.successContainer` soft elevation not hard shadow (`VISUAL-IDENTITY.md:226`)
- [ ] **FV-31:** `KycLevelCard` exists at `lib/systems/verification/widgets/kyc_level_card.dart` — tier label + limits chips from `VerificationLimits`
- [ ] **FV-32:** `DocumentTypePicker` exists at `lib/systems/verification/widgets/document_type_picker.dart` — `ChoiceChip`/`HivorrChip` group, labels from `DocumentType.label`

### 2.9 Required Functionality — Routing & DI

- [ ] **FV-33:** `RoutePaths.verificationIdentity = '/verification/identity'` and `RoutePaths.verificationStatus = '/verification/status'` added to `lib/app/router/route_paths.dart`; `RouteNames` added; `app_router.dart:17` registered, guarded by `RouteGuard` (`authenticated` only — no taxonomy gate)
- [ ] **FV-34:** Barrel `lib/systems/verification/verification.dart` re-exports all new symbols; `lib/data/data_layer.dart:1` updated with new exports
- [ ] **FV-35:** `VerificationProvider.create(supabase: SupabaseClientProvider.client, storageService: SupabaseStorageService(...))` factory in bootstrap wiring

### 2.10 Expected Workflows

- [ ] **FV-36:** Happy path upload: select document type → pick file → preview shown → tap submit → `validateForBucket` passes → `StoragePaths.credentialDocument` → upload with progress indicator → `entity_credentials.insert` → `remote.submit(credentialId)` → success screen → navigate to status
- [ ] **FV-37:** Status tracking: status screen shows `VerificationTimeline` with `Submitted → Pending → In Review → Approved` timestamps; badge + `KycLevelCard` appears on approval; `IdentityVerifiedBadge` green check
- [ ] **FV-38:** Status polling: timer polls `verification_status_get` every 15s while `status in (pending, in_review)` and screen foreground; cancels on `approved/rejected` terminal or screen pop; resumes on lifecycle foreground
- [ ] **FV-39:** Rejection resubmit: `HivorrErrorState` shows `decisionNotes` → "Resubmit" CTA clears pick → new `entity_credentials` row created (not UPDATE) → new `verification_submit` queued
- [ ] **FV-40:** Dedup active: attempting `submitIdentityDocument` when a `pending/in_review` submission exists → `PLT005 conflict` → dialog "An active submission already exists" with "View status" action navigating to `VerificationStatusScreen`
- [ ] **FV-41:** KYC tier display: after approval `verification_kyc_level_get` returns `tier_1` with limits `daily=50k, weekly=200k, monthly=800k, cashout=100k` → `KycLevelCard` renders limits
- [ ] **FV-42:** Notification integration: `pending→approved` terminal transition triggers `maybeNotify` → `HivorrNotification{priority:high, channel:system}` via `NotificationProvider` → UI re-fetches truth before badge render

### 2.11 Success Conditions

- [ ] **FV-43:** `verification_submit` RPC returns `{success:true, code:PLT000, data: verification_submissions row}` and creates `verification_audit_trail` entry `submission_created` server-side
- [ ] **FV-44:** `verification_status_get` returns `identity_verified`, `kyc{tier_code, status, limits}`, `trade_verifications[]`, `pending/total` counts
- [ ] **FV-45:** Service is provider-swappable — screens consume `VerificationProvider`/`IdentityVerificationService` without importing `SupabaseClient.rpc` literals or `storage.from` strings (`ARCHITECTURE.md:101-110` compliant)

### 2.12 Error Handling Scenarios

- [ ] **FV-46:** Oversize file `10485761 bytes` → `StorageValidationException` `PLT003` before network — upload spy not invoked
- [ ] **FV-47:** Invalid MIME `application/x-msdownload` → `StorageValidationException` `PLT003` before network
- [ ] **FV-48:** `401 PLT001 auth` (unauthenticated) → `ApiException` surfaced → redirect `/login`
- [ ] **FV-49:** `403 PLT002 forbidden` (credential not owned / column violation) → `ApiException` surfaced
- [ ] **FV-50:** `404 PLT004 notFound` (credential not found / cross-entity `p_entity_id≠auth.uid()`) → `ApiException` surfaced
- [ ] **FV-51:** `409 PLT005 conflict` (active duplicate submission `159-161` partial index) → mapped to "An active submission already exists" dialog with "View status" CTA
- [ ] **FV-52:** `5xx PLT999 server` → `ApiException` surfaced; retry 3x prod / 4x dev with `500ms→8s` backoff (`ApiConfig.maxRetries 3/4:45-49`)
- [ ] **FV-53:** Network timeout → `ApiExceptionKind.timeout` mapped via `ApiExceptionMapper._mapTransport`; backoff applied; no retry loop without bound
- [ ] **FV-54:** Raw `DioException` never propagates to provider — `BaseApiService.invoke:33` normalizes all transport errors
- [ ] **FV-55:** Unauthenticated `SupabaseClientProvider.client` guard → `ApiInitializationException` before any RPC

### 2.13 Important User Interactions

- [ ] **FV-56:** Fail-fast inline validation: `StorageValidators.validateForBucket` runs on file pick (before upload 2-3s) — invalid MIME/size produces inline `Text(error)` with `colorScheme.error` under picker
- [ ] **FV-57:** Progress feedback: `onProgress(sent,total)` wired via Dio `onSendProgress` streams bytes deterministically — `LinearProgressIndicator` visible during upload, critical on slow Nigerian 3G
- [ ] **FV-58:** "We'll review within 24h" guidance text on success screen — sets expectation that approval is server-side admin-reviewed
- [ ] **FV-59:** Pull-to-refresh on status screen calls `provider.refreshStatus()` immediately — no waiting for next 15s poll tick
- [ ] **FV-60:** Dedup dialog uses "View status" action navigating to `VerificationStatusScreen`, not retry that would loop on `PLT005`
- [ ] **FV-61:** Document type labels include Nigeria-specific hints ("National ID (NIN)", "Driver's License (FRSC)", "Voter's Card (INEC)") with 1-line helper text

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Files are added ONLY under `lib/data/datasources/remote/verification_remote_data_source.dart`, `supabase_verification_remote_data_source.dart`, `lib/data/models/verification_*_dto.dart`, `lib/data/entities/verification_*.dart`, `lib/data/mappers/verification_mapper.dart`, `lib/data/repositories/verification_repository*.dart`, `lib/data/providers/verification_provider.dart`, `lib/systems/verification/models/document_type.dart`, `lib/systems/verification/services/identity_verification_service.dart`, `lib/systems/verification/screens/*.dart`, `lib/systems/verification/widgets/*.dart`, `lib/systems/verification/verification.dart`, `lib/app/router/` (2 route updates), `lib/data/data_layer.dart` (barrel update), and `test/**` — no files in `lib/core/storage/`, `lib/engine/`, `lib/integrations/payment_gateways/`, or `lib/systems/` other than `verification/`
- [ ] **TV-02:** No DDL on `public.*` or `storage.*` — `git diff --stat supabase/` shows 0; no `supabase/migrations/*` added, no `supabase/config.toml` modified; `lib/core/storage/*` diff = 0 (reuses `SupabaseStorageService:43`)
- [ ] **TV-03:** `lib/systems/verification/verification.dart` barrel re-exports all new symbols; `lib/data/data_layer.dart:1` updated
- [ ] **TV-04:** Interface-first pattern — abstract `VerificationRepository` separate from `VerificationRepositoryImpl`; abstract `VerificationRemoteDataSource` separate from `SupabaseVerificationRemoteDataSource`
- [ ] **TV-05:** No `public.*` or `storage.*` `SECURITY DEFINER` functions created; no `GRANT` statements; no `CREATE POLICY` statements (`supabase/migrations/` untouched)
- [ ] **TV-06:** Dependency wiring uses `SupabaseClientProvider.client` safe accessor (`supabase_client_provider.dart:19`) + `SupabaseClientProvider.currentAccessToken` (`:29`); no direct `Supabase.instance.client` leakage in business logic beyond provider

### 3.2 Required System Behavior

- [ ] **TV-07:** `StorageService.validateForBucket` called before SDK upload — spy test proves oversize never reaches `uploadBinary`; `StoragePaths.credentialDocument` produces `{entityId}/{submissionId}/{uuid}_{sanitized}` path matching `storage.foldername(name)[1]==auth.uid()::text` (`supabase/migrations/20260830100001_storage_buckets.sql:118`)
- [ ] **TV-08:** `upsert: false` on `credential-documents` upload; `entity_credentials.insert` has no `verification_status` or `reviewed_at` (RLS limited grant `supabase/migrations/20260829090003_verification_admin_review_schema.sql:264-266` blocks these columns)
- [ ] **TV-09:** Client never writes `verification_submissions.status`, `entity_kyc_levels.tier_code`, or `entity_professions.trade_verification_status` — `grep -r "trade_verification_status" lib/systems/verification` = 0 for assignment; display-only read is permitted
- [ ] **TV-10:** Polling `Timer.periodic(15s)` pauses on `WidgetsBindingObserver.didChangeAppLifecycleState` background and cancels on `AppRouter didPop` — respects `supabase_realtime` exclusion (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:798-815`)
- [ ] **TV-11:** `VerificationRemoteDataSource` does NOT inject `StorageService` — storage lives in repository/systems layer for `lib/data/` persistence-agnostic pattern
- [ ] **TV-12:** Error normalization via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:18`) — preserves `kind`, `code`, `statusCode`; message safe (no SQL/stack leaked)
- [ ] **TV-13:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) log `entityId suffix (***last4)`, `documentType`, `mimeType`, `byteLength`; never logs `document_path` full, never bytes, never `legal_name`; `MonitoringService` span `verification.submit` sampled

### 3.3 Module Integration

- [ ] **TV-14:** No conflict with existing `lib/core/storage/` — `SupabaseStorageService` consumed, not modified; `StorageBuckets.credentialDocuments` + `StoragePaths.credentialDocument` reused
- [ ] **TV-15:** No conflict with `lib/data/datasources/remote/taxonomy_envelope_parser.dart` — `EnvelopeParser` pattern reused (not re-implemented); `DataExceptionMapper` shared
- [ ] **TV-16:** No conflict with `lib/core/notifications/` — `NotificationProvider` consumed; `HivorrNotification` emitted via domain provider channel, not direct `flutter_local_notifications` plugin call
- [ ] **TV-17:** `lib/systems/verification/` is consumable by `EP-02-11` (trade proof same queue shape), `EP-02-12` (KYC reads `tier_1`), `EP-02-18` (onboarding flow imports `IdentityVerificationService`) without modification
- [ ] **TV-18:** Unidirectional dependency `data → systems` — repository never imports `lib/systems/` widgets

### 3.4 Technical Requirements from Plan

- [ ] **TV-19:** `flutter analyze` + `dart analyze` clean
- [ ] **TV-20:** `VerificationRemoteDataSource` dartdoc documents RPC envelope contract, `BaseApiService.invoke` pattern, `DataExceptionMapper` error mapping
- [ ] **TV-21:** `VerificationProvider` dartdoc documents polling lifecycle, `maybeNotify` terminal diff, `Timer.periodic 15s` + backoff on `timeout/network`
- [ ] **TV-22:** `PerformanceTracer` span `verification.submit.duration` tagged `documentType` (no PII), sampled via `MonitoringConfig`

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **DV-01:** `entity_credentials` insert shape: `{entity_id: auth.uid(), kind: 'identity_document', title: documentType.label, document_path: storageKey, profession_id: null}` — no `verification_status`, no `reviewed_at` (RLS limited grant `supabase/migrations/20260829090003_verification_admin_review_schema.sql:264-266` excludes these columns)
- [ ] **DV-02:** `verification_submissions` row created server-side via `verification_submit(p_credential_id)` RPC — client never directly inserts; `id, entity_id, credential_id, submission_type='identity_document', status, priority, submitted_at` populated; `reviewed_at, reviewed_by, decision_notes` default null

### 4.2 Data Updates

- [ ] **DV-03:** Client never updates `verification_submissions.status` — only service-role `review_approve/reject` RPCs (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:412,530`) can mutate status; authenticated `UPDATE` grant absent (`264-266`)
- [ ] **DV-04:** Client never writes `entity_kyc_levels.tier_code` — server-side RPC `review_approve` assigns `tier_1` never downgrading (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:491-515`); client reads via `verification_kyc_level_get`
- [ ] **DV-05:** Resubmit after rejection creates **new** `entity_credentials` row (not UPDATE) — corrections are resubmissions per `supabase/migrations/20260821090002_entity_core_tables.sql:167` comment

### 4.3 Data Relationships

- [ ] **DV-06:** `entity_credentials.id` is FK for `verification_submit(p_credential_id)` — insert returned from `supabase.from('entity_credentials').insert(...).select().single()`
- [ ] **DV-07:** One-active-submission invariant: partial unique index `credential_id where status in (pending, in_review)` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:159-161`) enforced at DB level; client handles `PLT005` conflict dialog
- [ ] **DV-08:** `entity_kyc_levels` one row per entity (`unique entity_id` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:98`) — `tier_1` assigned on identity approve, never downgrades; `tier_0` all-zero default (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:228-234`)
- [ ] **DV-09:** `kyc_tiers` seeded `tier_0..tier_3` with `tier_1 Identity Verified`: `daily=50000, weekly=200000, monthly=800000, cashout=100000` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:228-234`)

### 4.4 Data Accuracy

- [ ] **DV-10:** Status enum mapping exact: `pending|in_review|approved|rejected|requires_resubmission` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:133-135`) — mapper unit test covers all 5 values
- [ ] **DV-11:** `decision_notes` null-safe, preview length ≤120 chars for notification body, full ≤5000 chars from `supabase/migrations/20260829090003_verification_admin_review_schema.sql:140-142`
- [ ] **DV-12:** KYC limits numeric: `daily=50000, weekly=200000, monthly=800000, cashout=100000` for `tier_1` — mapper unit test asserts exact values
- [ ] **DV-13:** `identity_verified = status=='active' && tier_code >= tier_1` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:639`) — string compare holds for `tier_0..tier_3`

### 4.5 Data Integrity

- [ ] **DV-14:** `verification_audit_trail` rows `submission_created|kyc_level_assigned|trade_status_propagated` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:209-214`) written server-side by RPCs; client never inserts audit rows directly (policy exists but RPC is the path `320`)
- [ ] **DV-15:** Idempotency: `reference` not used — submission idempotency is credential-scoped (`PLT005`); retry with same `credentialId` returns `409 conflict`, not duplicate queue
- [ ] **DV-16:** No `public.*` table mutation by client; `verification_submissions`, `verification_reviews`, `verification_audit_trail`, `entity_kyc_levels`, `kyc_tiers` all unchanged by client RPC calls — `git diff --stat supabase/` = 0

---

## 5. Security Verification

- [ ] **SV-01:** Server-authoritative gate (`AGENT.md:16` Rule 4) — client never writes `verification_submissions.status`, `entity_kyc_levels.tier_code`, or `entity_professions.trade_verification_status`; `grep -r "trade_verification_status" lib/systems/verification` = 0 for assignment (display-only read permitted)
- [ ] **SV-02:** All verification tables `revoke all from anon, authenticated` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:244-246`) + policies `to authenticated` only; `anon` zero read verified in `supabase/tests/database/021_*`; `RouteGuard` redirects to `/login`
- [ ] **SV-03:** Private credential isolation — `credential-documents public=false` (`supabase/config.toml:37`); `getPublicUrl` throws `StorageValidationException` (`supabase_storage_service.dart:264`); preview via `createSignedUrl(600)` short TTL HMAC-signed; `grep -r "getPublicUrl" lib/systems/verification` = 0
- [ ] **SV-04:** Path traversal / prefix escape blocked — `StoragePaths.sanitize` strips `..`, `/`, control chars; server `WITH CHECK (storage.foldername(name))[1]=auth.uid()::text` authoritative (`supabase/migrations/20260830100001_storage_buckets.sql:118`); `evil-entity-id/` test coverage in `017_storage_posture.sql:210-237`
- [ ] **SV-05:** MIME/size DoS prevention — `StorageValidators.validateForBucket` blocks before SDK; server `file_size_limit 10485760` second gate; `text/html`, `application/x-msdownload` rejected client-side
- [ ] **SV-06:** Anon write DoS — `anon` zero INSERT/UPDATE/DELETE on verification tables; service requires `authenticated` (fails closed via `SupabaseClientProvider.client:21` guard)
- [ ] **SV-07:** Auth token protection — token via `SupabaseClientProvider.currentAccessToken:29` never logged; `PiiRedactor` masks `entityId` to `***last4`; never logs `document_path` full, bytes, or `decisionNotes` beyond preview length
- [ ] **SV-08:** No `service_role` in client code — `grep -r "service_role" lib/` = 0; `SupabaseClientProvider.client` uses `anon`/`authenticated` role with RLS; review_approve/reject `supabase/migrations/20260829090003_verification_admin_review_schema.sql:792-793` granted to `service_role` only
- [ ] **SV-09:** Race condition — partial unique index `verification_submissions_one_active_credential_idx` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:159-161`) prevents parallel `submit` racing; second gets `PLT005 conflict` mapped to dialog
- [ ] **SV-10:** Auth state isolation — `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); `credential-documents` bucket per environment via migration, no cross-env read
- [ ] **SV-11:** No SQL injection — RPC calls use parameterized `supabase.rpc('verification_*', params:{...})`; `entity_credentials.insert` is SDK-constructed, not raw SQL; no dynamic query interpolation

---

## 6. Performance Verification

- [ ] **PV-01:** Polling cost — `Timer.periodic(15s)` only while `status in (pending, in_review)` and screen visible; 1 RPC/15s ≈ 240 req/hour peak; `verification_status_get` is `STABLE` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:598`) and indexed `verification_submissions_entity_status_idx` (`:150`)
- [ ] **PV-02:** Polling pause — `WidgetsBindingObserver.didChangeAppLifecycleState(background)` pauses timer; `AppRouter didPush/didPop` cancels on navigate away; no wasted RPCs on background/backgrounded screens
- [ ] **PV-03:** Backoff — `timeout/network` errors trigger exponential `500ms→8s` backoff (`ApiConfig.maxRetries 3/4:45-49`); no retry storm; terminal `approved/rejected` cancels timer immediately
- [ ] **PV-04:** Upload size — 10 MiB single-part, no chunking; `onProgress` Dio `onSendProgress` streams bytes; `Uint8List` single allocation < Dart heap; no base64 double-copy
- [ ] **PV-05:** Caching — `VerificationProvider` memoizes `status` in memory (no Hive local data source); invalidate via `refreshStatus()` on resume, submit, or push notification; no disk persistence of `document_path` beyond credential row
- [ ] **PV-06:** Signed URL — `createSignedUrl(600)` minimal signing overhead; short TTL prevents CDN caching of sensitive docs; `getPublicUrl` not used (throws)
- [ ] **PV-07:** Validation cost — `StorageValidators.validateForBucket` is O(1) map lookup + int compare (microseconds); filename sanitize O(n) on <255 chars — negligible, avoids wasted multipart on slow 3G
- [ ] **PV-08:** `PerformanceTracer` span `verification.submit.duration` sampled via `MonitoringConfig`, tags `verification.document_type`, no PII — lightweight overhead

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/data/verification/` + `test/unit/systems/verification/`

Pattern mirrors `test/unit/core/api/api_exception_mapper_test.dart` + `test/support/fakes/fake_storage.dart` (`InMemorySecureStorage`) + `test/support/fakes/fake_supabase.dart` — no live Supabase.

- [ ] **TT-01:** `verification_remote_data_source_test.dart` ≥16 cases green — mock `SupabaseClient.rpc` via fake: `verification_submit → {success:true, data:{id, status:pending}}` success; `data: {success:false, code:PLT005}` → `ApiExceptionKind.conflict PLT005`; envelope `success:false` → throws; `verification_status_get → {kyc:{tier_code:tier_0}, identity_verified:false}` defaults; `401→PLT001 auth`, `404→PLT004`, `409→PLT005`, `500→PLT999` via `ApiExceptionMapper`
- [ ] **TT-02:** `verification_repository_test.dart` ≥20 cases green — fake `StorageService` + fake remote: validates `validateForBucket` called first (oversize `10485761` never hits fake upload spy); path `entityId/submissionId/uuid_name.jpg` regex; `mimeType` normalized; `credential insert` shape captured; `submit` with duplicate `credentialId` surfaces `conflict`; `getStatus` success maps DTO→entity, `trade_verifications` empty for identity-only
- [ ] **TT-03:** `verification_provider_test.dart` ≥14 cases green — `ChangeNotifier` with mocked repository: `submitIdentityDocument` sets `submitState=loading` then `idle`, calls `refreshStatus`; polling `Timer` mocked via `fakeAsync` — 15s ticks until `approved`, cancels on dispose; `maybeNotify` emits `HivorrNotification` only on terminal transition; cross-entity guard `PLT004`
- [ ] **TT-04:** `verification_mapper_test.dart` ≥8 cases green — `VerificationSubmissionDto.fromJson → VerificationSubmission` enum mapping all 5 statuses; `decision_notes` null/truncation; `kyc limits` numeric exact
- [ ] **TT-05:** `document_type_test.dart` ≥6 cases green — enum labels, `DocumentType.fromTitle`, `kind` always `identity_document`, extensibility `values.length==5`
- [ ] **TT-06:** Total ≥64 unit assertions; repository/provider ≥90% coverage, mappers/DTOs 100% (`flutter test --coverage`)

### 7.2 Automated Widget Suite — `test/widget/systems/verification/`

- [ ] **TT-07:** `identity_document_upload_screen_test.dart` ≥10 cases green — pump with `Provider<VerificationProvider>` fake + `MaterialApp` `AppTheme.light`: chip selection highlights `colorScheme.primaryContainer` (no `Colors.*`), file pick mock sets preview, `HivorrButton.isLoading` shows `HivorrLoader`, progress `LinearProgressIndicator` visible when `onProgress` fired, error field shows `colorScheme.error` for oversize, `grep Colors.` assert = 0
- [ ] **TT-08:** `verification_status_screen_test.dart` ≥12 cases green — mock `VerificationStatus{pending→timeline 2 active dots, approved→badge + KycLevelCard limits, rejected→HivorrErrorState + decisionNotes + Resubmit button}`; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily` literal), spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:220`)
- [ ] **TT-09:** `verification_timeline_test.dart` ≥8 cases green — timeline dot colors `primary/successContainer/error/outline` per status, no hardcoded hex, semantics `Semantics(label:'Approved')`
- [ ] **TT-10:** All widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)` — AppTheme harness pattern from existing test suite

### 7.3 Integration (Fake-E2E) — `test/integration/verification/`

- [ ] **TT-11:** `test/integration/verification/verification_flow_test.dart` green — fake `SupabaseStorageClient(from('credential-documents'))` (in-memory `Map<path, Uint8List>`) + fake `SupabaseClient.rpc` map (canned `verification_submit`/`verification_status_get` envelopes) + real `VerificationRepositoryImpl`: `repo.submitIdentityDocument(DocumentType.passport, bytes: Uint8List(1024), mimeType:'image/jpeg') → status pending → mock review_approve side-effect (inject `VerificationStatusDto{identity_verified:true, kyc:{tier_1,active,limits}}`) → `provider.refreshStatus()` → badge asserts `IdentityVerified`; no `supabase start` container needed

### 7.4 Regression Guard

- [ ] **TT-12:** `flutter analyze` + `dart analyze` clean
- [ ] **TT-13:** `flutter test --coverage` — domain ≥80% line coverage on verification slice; widgets theme-asserted
- [ ] **TT-14:** `supabase db test` full suite `001..017` + verification `021_*` green — zero regressions on `public.*` RLS/posture; `017_storage_posture.sql:60-241` (credential private, anon zero write) still green
- [ ] **TT-15:** `grep -r "Colors\.\|Color(0x" lib/systems/verification` = 0, `grep -r "fontFamily" lib/systems/verification` = 0, `grep -r "getPublicUrl" lib/systems/verification` = 0, `grep -r "service_role" lib/` = 0
- [ ] **TT-16:** `git diff --stat supabase/` = 0; `git diff --stat lib/core/storage` = 0

### 7.5 Edge Cases

- [ ] **TT-17:** Boundary sizes: 0 bytes, exactly 10485760 bytes (accepted), 10485761 bytes (rejected)
- [ ] **TT-18:** MIME case insensitivity: `IMAGE/JPEG` accepted; extension↔MIME mismatch normalization
- [ ] **TT-19:** Filename edge: empty, 300-char truncation to 180 chars, `../../etc/passwd` sanitized, `entityId//double-slash` sanitized
- [ ] **TT-20:** `requires_resubmission` status path — timeline renders, Resubmit CTA functional
- [ ] **TT-21:** `p_entity_id` null (self) vs supplied (admin) — `PLT004` on cross-entity; `getStatus` with null uses `auth.uid()`

### 7.6 Failure Scenarios

- [ ] **TT-22:** Duplicate active submission → `PLT005 conflict` dialog with "View status" navigation (not retry loop)
- [ ] **TT-23:** Network timeout → `PLT999` backoff `500ms→8s`; visible retry affordance
- [ ] **TT-24:** `401→PLT001` unauth → redirect to `/login` via `RouteGuard`
- [ ] **TT-25:** `403 PLT002` column violation (e.g. attempting `status:approved` in insert) → `ApiException` surfaced, not raw SQL
- [ ] **TT-26:** Envelope `success:false, code:PLT003` → `ApiExceptionKind.validation` surfaced; no raw JSON to UI

### 7.7 Manual Testing

- [ ] **TT-27:** Manual spot-check (optional, with `supabase start`): pick National ID → preview → upload 5 MiB → `onProgress` shows → submit → `pending` status visible → poll → badge on approval → rejection notes + resubmit → new `entity_credentials` row confirmed; signed URL preview renders within 600s then expires

---

## 8. User Acceptance Verification

This task delivers the identity verification seam — the first trust checkpoint that gates financial features. User acceptance is verified through document flow correctness, status tracking UX, and downstream readiness.

- [ ] **UA-01:** The project lead can browse 5 document types with Nigeria-specific labels ("National ID (NIN)", "Driver's License (FRSC)", "Voter's Card (INEC)") and submit any ≤10 MiB `jpeg/png/webp/pdf` with `onProgress` feedback without encountering raw `PLT003` errors
- [ ] **UA-02:** Guidance text "Accepted: JPG, PNG, WebP, PDF up to 10 MB" matches server `file_size_limit`/`allowed_mime_types`; fail-fast inline "File too large — please use a file under 10 MB" appears before network on 3G
- [ ] **UA-03:** Status screen shows `VerificationTimeline` with `Submitted → Pending → In Review → Approved/Rejected/requires_resubmission` with timestamps; pull-to-refresh immediate; badge `IdentityVerified` + `KycLevelCard tier_1 Identity Verified` + limits chips on approval
- [ ] **UA-04:** Rejection renders empathy `HivorrErrorState` + `decisionNotes` ("Image blurred — please retake") + single "Resubmit" CTA; dedup `PLT005` dialog has "View status" not loop retry
- [ ] **UA-05:** Notification high-priority on terminal `pending→approved/rejected`; UI re-fetches truth before badge render (prevents spoofed local state)
- [ ] **UA-06:** Premium finish — `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), `HivorrEmpty/Loading/Error/SuccessState` warm microcopy (`VISUAL-IDENTITY.md:241`), soft elevation not hard shadow, 8pt grid, ≥48dp touch targets, light/dark WCAG AA `#0B6E99`
- [ ] **UA-07:** No financial/escrow leakage — `grep -r "financial_\|escrow\|payout" lib/systems/verification` = 0; no `lib/integrations/payment_gateways` import
- [ ] **UA-08:** Downstream unblocked — `EP-02-11` (trade proof builds same queue shape), `EP-02-12` (KYC reads `tier_1` via `verification_kyc_level_get/limits_get`), `EP-02-18` (onboarding step imports `IdentityVerificationService` without `SupabaseClient.rpc` literals or `storage.from` strings)

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-10 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/data/datasources/remote/verification_remote_data_source.dart` exists — abstract `submit`, `getStatus`, `getKycLevel`, `getLimits` | File inspection | ☑ |
| 2 | `supabase_verification_remote_data_source.dart` extends `BaseApiService`, uses `supabase.rpc('verification_submit/status_get/kyc_level_get/limits_get')` + `EnvelopeParser` + `ApiExceptionMapper` | Code review + unit test | ☑ |
| 3 | DTOs `verification_submission_dto.dart`, `verification_status_dto.dart`, `kyc_level_dto.dart`, `verification_limits_dto.dart` + entities + `verification_mapper.dart` map 5 status enum + KYC limits numeric | File + mapper unit test | ☑ |
| 4 | `lib/systems/verification/models/document_type.dart` defines `DocumentType` enum (5 values, labels, `kind=identity_document`, `submission_type=identity_document`) — extensible without schema change | File inspection | ☑ |
| 5 | `VerificationRepository submitIdentityDocument` orchestrates: `validateForBucket` → `StoragePaths.credentialDocument` → `StorageService.upload` → `entity_credentials.insert` → `remote.submit`; validation called before network (spy test: oversize never hits upload) | Code + repo unit test | ☑ |
| 6 | `VerificationProvider` `ChangeNotifier` holds `VerificationStatus`, `KycLevel`, `AsyncState submitState`, `startPolling/stopPolling` 15s timer, `maybeNotify` terminal transition via `NotificationProvider` | Unit test (`fakeAsync` timer + notification diff) | ☑ |
| 7 | `IdentityVerificationService` facades repo + `HivorrLogger` redacted + `PerformanceTracer verification.submit.duration` | File inspection | ☑ |
| 8 | `IdentityDocumentUploadScreen` uploads with `onProgress LinearProgressIndicator` + `HivorrButton(isLoading)` + `HivorrLoader` breathing pulse; uses `credential-documents` private via `StorageService` only | Widget test + `grep getPublicUrl` = 0 | ☑ |
| 9 | `VerificationStatusScreen` renders `VerificationTimeline` + `IdentityVerifiedBadge` + `KycLevelCard` + `HivorrErrorState` for rejection with `decisionNotes`; poll lifecycle tied to visibility + app lifecycle; pull-to-refresh | Widget test | ☑ |
| 10 | All screens/widgets consume `AppTheme` tokens only — `colorScheme.*`, `textTheme.*`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` — no `Colors.*`, no `Color(0xFF…)`, no `fontFamily:` literal | `grep` + widget test token asserts | ☑ |
| 11 | Routes `/verification/identity` and `/verification/status` added to `route_paths.dart` + `route_names.dart` + `app_router.dart`, guarded by `RouteGuard` (authenticated), no SEO public route | File + router test | ☑ |
| 12 | Barrels `lib/systems/verification/verification.dart` and `lib/data/data_layer.dart` re-export all new symbols | File inspection | ☑ |
| 13 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat` shows only `lib/**` + `test/**` + `router/**` | `git diff --stat` | ☑ |
| 14 | No `lib/core/storage/*` changes — `git diff --stat lib/core/storage` = 0 (reuses `SupabaseStorageService`) | `git diff --stat` | ☑ |
| 15 | No financial/escrow logic — `grep -r "financial_\|escrow\|payout" lib/systems/verification` = 0; no `lib/integrations/payment_gateways/` import | `grep` | ☑ |
| 16 | No `service_role`/secret leak — `grep -r "service_role\|sk_live\|supabase_secret" lib/` = 0; `SupabaseClientProvider.client` only | `grep` + code review | ☑ |
| 17 | Error normalization `401→PLT001`, `403→PLT002`, `400/422→PLT003`, `404→PLT004`, `409→PLT005`, `5xx→PLT999` via `ApiExceptionMapper`; raw `DioException` never propagates | Unit test | ☑ |
| 18 | `verification_remote_data_source_test.dart` ≥16 cases green | `flutter test` | ☑ |
| 19 | `verification_repository_test.dart` ≥20 cases green | `flutter test` | ☑ |
| 20 | `verification_provider_test.dart` ≥14 cases green | `flutter test` | ☑ |
| 21 | `verification_mapper_test.dart` ≥8 + `document_type_test.dart` ≥6 green | `flutter test` | ☑ |
| 22 | `identity_document_upload_screen_test.dart` ≥10 + `verification_status_screen_test.dart` ≥12 + `verification_timeline_test.dart` ≥8 green | `flutter test` | ☑ |
| 23 | `verification_flow_test.dart` fake-E2E green (submit → pending → mockApprove → badge) | `flutter test` | ☑ |
| 24 | `flutter analyze` + `dart analyze` clean | CI | ☑ |
| 25 | `flutter test --coverage` domain ≥80%, widgets theme-asserted; `supabase db test` full suite `001..021` green | `supabase db test` | ☑ |
| 26 | Visual identity: `grep -r "Colors\.\|Color(0x" lib/systems/verification` = 0, `grep -r "fontFamily" lib/systems/verification` = 0, `grep -r "getPublicUrl" lib/systems/verification` = 0; premium finish (`HivorrLoader`, soft elevation, 48dp touch, 16dp/24dp padding, WCAG AA) | Code review | ☑ |
| 27 | `EP-02-11`, `EP-02-12`, `EP-02-18` unblocked — downstream can import `IdentityVerificationService`/`VerificationProvider` without modification | Dependency check | ☑ |

---

> **Sign-off:** Task EP-02-10 marked **Completed** -- all 27 conditions in the Final Approval Checklist are verified and signed off by the project lead.
