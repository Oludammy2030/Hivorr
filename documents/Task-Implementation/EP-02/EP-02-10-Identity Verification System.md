# Task Implementation Plan — EP-02-10: Identity Verification System

**Task ID:** EP-02-10 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Completed | **Priority:** High | **Dependencies:** EP-02-03, EP-02-06, EP-02-07 | **Stage:** 4 — Trust & Verification Systems

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:346-356` | Architecture: `documents/Context/ARCHITECTURE.md:55-60,95-110,131-138`, `documents/Context/AGENT.md:7,16` | Dependencies: `EP-02:139` (`EP-02-10 → 06,07,03`), `EP-02:175-178` | Stack: `pubspec.yaml:43-53` (`dio 5.11.0`, `supabase_flutter 2.17.2`, `provider 6.1.5`), `lib/core/storage/storage_service.dart:16`, `supabase/migrations/20260829090003_verification_admin_review_schema.sql:1-816`, `supabase/config.toml:36-40`, `supabase/migrations/20260821090002_entity_core_tables.sql:120-168`

---

## 1. Task Objective

Build the client-side **Identity Verification System** in `lib/systems/verification/` plus its unified Data Layer in `lib/data/` — document-type selection (National ID, Passport, Driver's License, Voter's Card, NIN Slip), `credential-documents` upload via `StorageService` (`lib/core/storage/storage_service.dart:16`), `entity_credentials` creation, `verification_submit` queueing (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:323-406`), and real-time status tracking (`pending`→`in_review`→`approved`/`rejected`/`requires_resubmission`) with KYC tier assignment (`kyc_tiers`/`entity_kyc_levels` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-112`) and `lib/core/notifications/` integration. Connect the `EP-02-06` private bucket seam to the `EP-02-03` server-authoritative verification RPC engine. Zero `public.*` DDL. Zero financial math. Zero hardcoded `Colors.*`/hex.

Deliverables:
- Data layer: `VerificationSubmission` entity/DTO/mapper, `KycTier`/`KycLevel` models, `VerificationRemoteDataSource` (RPC-only), `VerificationRepository`, `VerificationProvider` in `lib/data/`
- Orchestration: `IdentityVerificationService` in `lib/systems/verification/` (storage → credential → submit → status)
- UI: `IdentityDocumentUploadScreen`, `VerificationStatusScreen`, `VerificationTimeline`/`IdentityVerifiedBadge` widgets (`lib/systems/verification/widgets/`)
- Routes: `/verification/identity` + `/verification/status` (`lib/app/router/app_router.dart:17`)
- Notification hook: verification decision → `HivorrNotification` (`lib/core/notifications/`)
- Unit + widget + integration test suite (mocked `SupabaseClient`, fake `StorageService`)

## 2. Business Problem Being Solved

`EP-02:32,353` mandates identity verification as the **first trust checkpoint** that gates financial features (`EP-02-13/16`) and trade verification (`EP-02-11`) per `AGENT.md:7` Rule 2 (`tradeVerificationStatus == APPROVED` unlocks bidding). Server infrastructure exists:

- `supabase/migrations/20260829090003_verification_admin_review_schema.sql:115-162` (`verification_submissions` + `verification_reviews` + `verification_audit_trail`) and `322-796` (6 RPCs: `verification_submit`, `verification_review_approve/reject` service-role only, `verification_status_get`, `verification_kyc_level_get`, `verification_limits_get`) — fully RLS default-deny, `SECURITY INVOKER`, envelope `{success,code,message,data}`.
- `supabase/config.toml:36-40` + `lib/core/storage/supabase_storage_service.dart:43` (`credential-documents` private, 10 MiB, `jpeg/png/webp/pdf`).

But no client system exists (`lib/systems/verification/.gitkeep` empty — 1 file per `glob lib/systems/verification/**`). Without EP-02-10:

- Every entity would `supabase.from('entity_credentials').insert(...)` + `supabase.rpc('verification_submit')` inline in onboarding/profile screens, duplicating storage path conventions (`storage_paths.dart` → `{entityId}/{submissionId}/{uuid}_{sanitized}`), MIME/size validation, envelope parsing (`taxonomy_envelope_parser.dart` pattern), and `ApiException` mapping (`api_exception_mapper.dart:15`) — violates `ARCHITECTURE.md:91-94` separation and `AGENT.md:6` server-side enforcement (client must never write `verification_submissions.status` or `entity_kyc_levels` directly; only RPC `EP-02-03:322` comment).
- No single source for document-type vocabulary (`national_id|passport|drivers_license`) — future `NIMC`/`BVN` KYC provider (`EP-02-12`) would require screen-by-screen edits, breaking `EP-02:204` domain separation.
- No status polling/timeline UX — `verification_submissions` is **excluded from `supabase_realtime`** (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:798-815`), so naive `RealtimeChannel` subscription silently fails; a designed poller + notification fallback is required.
- `lib/core/notifications/` (`lib/core/notifications/notifications.dart:1`) has no verification binding — admin `review_approved` never surfaces to the entity, degrading trust loop per `EP-02:32`.

This task is the **Stage 4 identity seam** that unblocks `EP-02-11` (trade proof builds on same queue), `EP-02-12` (KYC levels), and `EP-02-18` (onboarding flow `EP-02:143`).

## 3. Scope

| In Scope | Detail |
|---|---|
| `VerificationRemoteDataSource` abstract + `SupabaseVerificationRemoteDataSource` | Injects `SupabaseClient`+`Dio`+`ApiExceptionMapper` via `BaseApiService` pattern (`lib/core/api/services/base_api_service.dart:15`). Methods: `submit(credentialId, submissionType?)`, `getStatus(entityId?)`, `getKycLevel()`, `getLimits()`. All via `supabase.rpc` envelope → `TaxonomyEnvelopeParser` equivalent (`lib/data/datasources/remote/taxonomy_envelope_parser.dart`) + `DataExceptionMapper` (`lib/data/datasources/remote/data_exception_mapper.dart`) |
| `entity_credentials` insert for identity docs | `supabase.from('entity_credentials').insert({entity_id: auth.uid(), kind:'identity_document', title: documentTypeLabel, document_path: storageKey, profession_id:null})` — auth insert grant is self-scoped; `verification_status`/`reviewed_at` excluded (server-only `supabase/migrations/20260821090002_entity_core_tables.sql:120-168` + RLS `supabase/migrations/20260821090003_entity_model_rls_policies.sql`). Client never writes `verification_submissions.status` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:264-266` limited grant) |
| Domain models | `DocumentType` enum (`nationalId, passport, driversLicense, votersCard, ninSlip` → display label + allowed `kind='identity_document'`), `VerificationSubmission` entity, `VerificationReview`, `KycTier`/`KycLevel`, `VerificationStatus` aggregate (KYC + trade map + counts) — pure Dart, no provider DTO leakage |
| DTOs + mappers | `VerificationSubmissionDto.fromJson`, `KycLevelDto`, `VerificationStatusDto` with `mapper` to entity (`lib/data/mappers/industry_mapper.dart` pattern) |
| `VerificationRepository` | `submitIdentityDocument({DocumentType, Uint8List bytes, mimeType, fileName, onProgress})`, `getStatus()`, `getKycLevel()`, `getLimits()`, `pollStatus({interval, backoff})` — orchestrates `StorageService.upload(bucket: StorageBuckets.credentialDocuments)` → credential insert → `verification_submit` |
| `IdentityVerificationService` (`lib/systems/verification/`) | Thin orchestration facade over repository + `StorageService` + `StoragePaths.credentialDocument(entityId, submissionId, fileName)` (`lib/core/storage/storage_paths.dart`). Validates `validateForBucket` before network (`lib/core/storage/storage_validators.dart`), sanitizes fileName, propagates `StorageValidationException` as field errors |
| `VerificationProvider` | `ChangeNotifier` (`provider:6.1.5`) — `status: AsyncValue<VerificationStatus>`, `kycLevel`, `limits`, `submitState`, `pollTimer`. Invalidates via `notifyListeners()`; polling with `Duration 15s` + exponential backoff on `timeout/network`, stops on `approved/rejected` |
| UI screens + widgets | `IdentityDocumentUploadScreen` (type picker → file pick via `XFile.readAsBytes()` → preview → upload with `onProgress` linear indicator + `HivorrLoader`), `VerificationStatusScreen` (timeline: `submitted → pending → in_review → approved/rejected/requires_resubmission`, badge, CTA resubmit), `VerificationTimeline`, `IdentityVerifiedBadge`, `KycLevelCard` — responsive via `shared/layouts/`, tokens via `AppColors`/`AppThemeExtension` (`lib/app/theme/app_colors.dart:12`) |
| Notification integration | On `getStatus()` transition `pending→approved/rejected`, emit `HivorrNotification{priority:high, channel: system, title, body}` via `NotificationService` (`lib/core/notifications/services/notification_service.dart:1`) + `PushNotificationReceiver` seam for future Edge Function push (`lib/core/notifications/push/supabase_push_receiver.dart`) |
| Barrel + DI | `lib/systems/verification/verification.dart` + `lib/data/data_layer.dart:1` re-exports; factory `VerificationProvider.create(supabase: SupabaseClientProvider.client, storageService: SupabaseStorageService(...))` |
| Tests | Unit (repository + provider + mappers + validators), widget (screens with `AppTheme` token asserts), integration (fake Supabase RPC) |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL / RLS / RPC creation, `storage.buckets` change, `supabase/config.toml` edit | `EP-02-03` frozen (`20260829090003_verification_admin_review_schema.sql:1-816`); this task is `lib/` only. `git diff --stat supabase/` must be `0` |
| Trade verification workflow + `trade_verification_status` propagation (`entity_professions` gate) + bid-lock enforcement | `EP-02-11` — approving `identity_document` only assigns `tier_1` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:491-515` never downgrades); `trade_proof` + profession binding is `EP-02-11` |
| KYC tier definitions / `KycProvider` abstract / provider adapters (SmileID/Dojah) / `entity_kyc_levels` admin write | `EP-02-12` seam — this task **reads** `tier_1` via `verification_kyc_level_get`/`verification_limits_get`, never writes `kyc_tiers` |
| Financial ledger, `financial_*` tables, escrow, payout, deposit name-match | `EP-02-04/13/16` — no `financial_*` import; no money movement |
| Supabase Edge Functions for thumbnailing/virus scan/webhook HMAC | Deferred; `credential-documents` path helper + signed URL TTL 60-300s is sufficient (`lib/core/storage/supabase_storage_service.dart:274-293`) |
| Offline Sync action queue (`lib/core/sync/`) for deferred uploads | Uploads are online-only; queuing is EP-01-12 generic infra, not EP-02-10 requirement (parallels `EP-02-08:55`) |
| New `storage` bucket or `lib/integrations/cloud_storage/` adapter | `ARCHITECTURE.md:119` future; reuse `SupabaseStorageService` (`lib/core/storage/supabase_storage_service.dart:43`) |
| Direct `Paystack`/`Flutterwave`/`NIBSS` calls | `EP-02-09` `lib/integrations/payment_gateways/` — not used by identity path |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/verification/` vs `lib/data/` vs `lib/core/storage/`

`ARCHITECTURE.md:56,101-110,131-138` assigns `lib/core/storage/` = platform object store, `lib/data/` = DTO/entity/repository/provider, `lib/systems/verification/` = trust-gate business system. Identity verification straddles both: the **data layer** owns RPC transport + DTOs (reusable across `EP-02-11/12/18/19`), the **systems layer** owns the document-type vocabulary, path conventions, and UX orchestration (progress, timeline, badge). This mirrors `EP-02-07` taxonomy pattern (`SupabaseTaxonomyRemoteDataSource` `lib/data/datasources/remote/supabase_taxonomy_remote_data_source.dart:16` + `workspace/profession_registry` engine). The `Taxonomy` engine lives in `lib/workspace/profession_registry/` (`ARCHITECTURE.md:89`), but verification is a `systems/` business system (`ARCHITECTURE.md:105`).

No new top-level `lib/` directory is created.

### 5.2 Data Layer Contract

```dart
// lib/data/datasources/remote/verification_remote_data_source.dart
abstract class VerificationRemoteDataSource {
  Future<VerificationSubmissionDto> submit({required String credentialId, String? submissionType});
  Future<VerificationStatusDto> getStatus({String? entityId});
  Future<KycLevelDto> getKycLevel();
  Future<VerificationLimitsDto> getLimits();
}

// lib/data/models/verification_submission_dto.dart
class VerificationSubmissionDto {
  final String id; final String entityId; final String credentialId;
  final String submissionType; // identity_document
  final String status; // pending|in_review|approved|rejected|requires_resubmission
  final DateTime submittedAt; final DateTime? reviewedAt;
}

// lib/data/entities/verification_submission.dart
class VerificationSubmission { /* pure Dart, no json */ String id; DocumentType documentType; VerificationStatus status; … }

// lib/data/mappers/verification_mapper.dart — Dto → Entity
```

- Implementation `SupabaseVerificationRemoteDataSource extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`) — constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`. Each method `invoke(() => supabase.rpc<Map<String,dynamic>>('verification_submit', params:{p_credential_id, p_submission_type}))` then `EnvelopeParser.unwrapData` (validates `{success:true, code:PLT000, data:{...}}`), same envelope as `taxonomy_industries_list` (`lib/data/datasources/remote/supabase_taxonomy_remote_data_source.dart:38-44`). `DataExceptionMapper` maps `ApiException(PLT001/003/004/005/999)` to `DataException` (`lib/data/datasources/remote/data_exception_mapper.dart:1`).
- `getStatus` calls `verification_status_get(p_entity_id)` — self-scoped if `p_entity_id == null` (uses `auth.uid()`), service-role path when `entityId` supplied for admin preview (but client always calls without param; `supabase/migrations/20260829090003_verification_admin_review_schema.sql:592-681` enforces cross-entity `PLT004`).
- `StorageService` is **not** injected into the DataSource — it lives in the repository/systems layer to keep `lib/data/` persistence-agnostic (same as `taxonomy_local_data_source.dart`).

### 5.3 Repository — `VerificationRepository` (the unit-tested business contract)

```dart
abstract class VerificationRepository {
  Future<VerificationSubmission> submitIdentityDocument({
    required DocumentType documentType,
    required Uint8List bytes, required String mimeType, required String fileName,
    void Function(int,int)? onProgress,
  });
  Future<VerificationStatus> getStatus();
  Future<KycLevel> getKycLevel();
  Future<VerificationLimits> getLimits();
}
```

`VerificationRepositoryImpl` (`lib/data/repositories/verification_repository_impl.dart` style):

1. **Validate first** — `storageService.validateForBucket(bucket: StorageBuckets.credentialDocuments, mimeType: mimeType, byteLength: bytes.length)` (`lib/core/storage/storage_validators.dart:1`). On failure throw `DataValidationException(PLT003)` → provider surfaces inline field error, not generic toast. Mirrors `SupabaseStorageService.validateForBucket` (`lib/core/storage/supabase_storage_service.dart:96`).
2. **Reserve ID** — generate `submissionId = Uuid.v4()` ( `uuid: ^4.5.1` `pubspec.yaml:71`) for path helper `StoragePaths.credentialDocument(entityId: auth.uid(), submissionId: submissionId, fileName: fileName)` — produces `{entityId}/{submissionId}/{uuid}_{sanitized}` matching `storage.foldername(name)[1] == auth.uid()::text` (`supabase/migrations/20260830100001_storage_buckets.sql:118` analog). Sanitization strips `..`, `/`, control chars (`lib/core/storage/storage_paths.dart`).
3. **Upload** — `await storageService.upload(bucket: credentialDocuments, path: storagePath, bytes: bytes, mimeType: StorageValidators.normalizeMime(mimeType), fileName: fileName, onProgress: onProgress, upsert: false)` (`lib/core/storage/supabase_storage_service.dart:74-129`). Private bucket: future `createSignedUrl(60)` for preview, never `getPublicUrl` (which throws `StorageValidationException` `supabase_storage_service.dart:264` — defense-in-depth).
4. **Create credential** — `final cred = await supabase.from('entity_credentials').insert({entity_id: entityId, kind:'identity_document', title: documentType.label, document_path: storagePath, profession_id:null}).select().single()` — `entity_credentials` RLS (`supabase/migrations/20260821090003_entity_model_rls_policies.sql`) grants authenticated self-insert on `(entity_id, kind, title, document_path, profession_id)` only; `verification_status` excluded.
5. **Queue** — `await remote.submit(credentialId: cred['id'], submissionType:'identity_document')` → `PLT005` if active submission exists (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:364-381` unique partial index `credential_id where status in (pending,in_review)`), mapped to `ApiExceptionKind.conflict` friendly message "You already have a pending verification for this document."
6. **Return** — mapped `VerificationSubmission` + `verification_audit_trail` entry `submission_created` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:386-391`) is the immutable proof; no client audit write needed.
7. **Polling helper** — `pollStatus` is not repository-level polling but provider timer that calls `getStatus()` every 15s until terminal (`approved|rejected|requires_resubmission`), with `ApiConfig.forEnvironment` retry on `timeout/network` (`lib/core/api/api_config.dart:40`).

Repository never imports `lib/systems/` widgets — unidirectional `data → systems`.

### 5.4 Systems Facade — `IdentityVerificationService` (`lib/systems/verification/services/`)

Thin wrapper used by `VerificationProvider` and future `EP-02-18` onboarding flow:

- Exposes `supportedDocumentTypes = DocumentType.values` (extensible — adding `bvn` is enum + label, no schema change because `kind` stays `identity_document` and `submission_type` is `identity_document` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:130-131` already extensible).
- Delegates to repository; adds `HivorrLogger` (`lib/core/logging/hivorr_logger.dart`) redacted log (`entityId: ***last4`, `documentType`, `byteLength`, `mimeType`) via `pii_redactor.dart` — never logs `document_path` full or bytes.
- `PerformanceTracer` span `verification.submit.duration` tagged `documentType` (`lib/core/monitoring/performance_tracer.dart`).

### 5.5 State — `VerificationProvider` (`lib/data/providers/`)

```dart
class VerificationProvider extends ChangeNotifier {
  VerificationStatus? status; KycLevel? kycLevel; AsyncState submitState;
  Future<void> submitIdentityDocument({...}) async { submitState=loading; try { await repo.submitIdentityDocument(...); await refreshStatus(); } on ApiException catch(e){ submitState=error(e);} }
  Future<void> refreshStatus() async { status = await repo.getStatus(); kycLevel = await repo.getKycLevel(); maybeNotify(status); }
  void startPolling(); void stopPolling(); // Timer.periodic 15s, cancel on dispose/terminal
}
```

- Constructor injection `({required VerificationRepository repo, HivorrLogger? logger})` for testability (`provider:6.1.5` `Provider<VerificationProvider>.value`).
- Notification hook: `maybeNotify` diffs `prev.status` → `next` terminal; if changed, `notificationProvider.show(HivorrNotification(title:'Verification ${next}', body: ..., priority: high))` via `NotificationProvider` (`lib/core/notifications/providers/notification_provider.dart:1`). No direct `flutter_local_notifications` plugin call — goes through domain provider for testability.
- No `SupabaseClientProvider` singleton inside provider — repository holds the client.

### 5.6 UI — `lib/systems/verification/screens/` + `widgets/`

- `IdentityDocumentUploadScreen` (stateful):
  1. Document type selector — `ChoiceChip` / `HivorrChip` group (5 options). Selected chip uses `ColorScheme.primaryContainer` (`VISUAL-IDENTITY.md:51`), not hardcoded `Colors.blue`. Labels via `AppTextTheme`.
  2. File picker — `XFile` (platform package `file_picker` or `image_picker` — both return `Uint8List` via `readAsBytes()` for Web compat `lib/core/storage/storage_service.dart:14` contract). Shows preview (`Image.memory` for images, PDF icon for `application/pdf`). Reject before upload via `StorageValidators.validateForBucket` message (field-level `Text(error)` with `ColorScheme.error`).
  3. Upload — `HivorrButton(isLoading: submitState.isLoading, onPressed: pick != null ? submit : null)` + `LinearProgressIndicator(value: sent/total)` from `onProgress`. Uses `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not `CircularProgressIndicator`.
  4. Success — `HivorrSuccessState` / `HivorrEmptyState` with branded illustration slot + "We'll review within 24h" guidance + CTA to `VerificationStatusScreen`.
- `VerificationStatusScreen`:
  - Reads `provider.status` — shows `HivorrLoadingState` while null, `VerificationTimeline` (vertical stepper: Submitted → Pending → In Review → Approved/Rejected with timestamps `submittedAt`/`reviewedAt`, `decisionNotes` for rejection/requires_resubmission `supabase/migrations/20260829090003_verification_admin_review_schema.sql:120-143`).
  - `IdentityVerifiedBadge` (green check + `KycLevelCard` showing `tier_1 Identity Verified` + `limits.daily/weekly/monthly/cashout` from `verification_limits_get` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:740-796`) on `approved`.
  - Rejection view: `HivorrErrorState` with `decisionNotes`, "Resubmit" CTA re-invokes repository (creates **new** `entity_credentials` row, not UPDATE — corrections are resubmissions `supabase/migrations/20260821090002_entity_core_tables.sql:167` comment).
  - No raw hex/Fonts: all `Theme.of(context).colorScheme.*`, `Theme.of(context).textTheme.*`, spacing via `AppThemeExtension.spacing` (`VISUAL-IDENTITY.md:219`), radius `AppThemeExtension.radiusSm/Md` (cards 16dp, sheets 24dp `VISUAL-IDENTITY.md:221`).
- `VerificationTimeline` / `IdentityVerifiedBadge` are pure widgets, testable with `WidgetTester` and `AppTheme` assertions (`ColorScheme.primary == #0B6E99`).

### 5.7 Routing — `lib/app/router/`

Extend `AppRouter.create` (`lib/app/router/app_router.dart:17`) via `RoutePaths.verificationIdentity = '/verification/identity'`, `verificationStatus = '/verification/status'` and `RouteNames.verificationIdentity/Status`. Guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) — `authProvider` requires authenticated; no taxonomy gate (identity is the first gate). SEO public URL not required (private flow, not portfolio `/p/:slug/:id` `ARCHITECTURE.md:150`), so no `publicProfileRoute` pattern.

### 5.8 Config & Logging

- No new `ENV` keys — storage and Supabase config cover it (`lib/config/environments/environment_config.dart:17`). `PaymentGatewayConfig` (`EP-02-09`) not imported.
- Errors via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) — `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `409→PLT005 conflict`, `5xx→PLT999 server`. `VerificationRemoteDataSource` rethrows normalized `ApiException`; provider surfaces `message` without leaking `stack`/`SQL` (`api_exception.dart:35-66`).
- `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) — log `entityId suffix`, `documentType`, `mimeType`, `byteLength`; never `document_path` full, never bytes, never `legal_name`. `MonitoringService` span `verification.submit` sampled (`lib/core/monitoring/monitoring_service.dart`).

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `VerificationRemoteDataSource` abstract | `lib/data/datasources/remote/verification_remote_data_source.dart` | **Create** — §5.2 |
| `SupabaseVerificationRemoteDataSource` | `lib/data/datasources/remote/supabase_verification_remote_data_source.dart` | **Create** — `BaseApiService` impl §5.2 |
| DTOs | `lib/data/models/verification_submission_dto.dart`, `verification_status_dto.dart`, `kyc_level_dto.dart` | **Create** |
| Entities | `lib/data/entities/verification_submission.dart`, `verification_status.dart`, `kyc_level.dart` | **Create** |
| Mappers | `lib/data/mappers/verification_mapper.dart` | **Create** |
| `VerificationRepository` abstract + impl | `lib/data/repositories/verification_repository.dart` + `verification_repository_impl.dart` | **Create** — §5.3 |
| `VerificationProvider` | `lib/data/providers/verification_provider.dart` | **Create** — §5.5 |
| `DocumentType` enum + helpers | `lib/systems/verification/models/document_type.dart` | **Create** |
| `IdentityVerificationService` facade | `lib/systems/verification/services/identity_verification_service.dart` | **Create** — §5.4 |
| Screens | `lib/systems/verification/screens/identity_document_upload_screen.dart`, `verification_status_screen.dart` | **Create** — §5.6 |
| Widgets | `lib/systems/verification/widgets/verification_timeline.dart`, `identity_verified_badge.dart`, `document_type_picker.dart`, `kyc_level_card.dart` | **Create** |
| Barrel | `lib/systems/verification/verification.dart` + update `lib/data/data_layer.dart` | **Create/Update** |
| Route extension | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` | **Update** — add 2 routes, guard via `RouteGuard` |
| `StorageService` reuse | `lib/core/storage/supabase_storage_service.dart:43` | **Reuse** — no new storage code |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — verify `git diff --stat supabase/` = 0 |
| No `lib/integrations/payment_gateways/*` | `lib/integrations/payment_gateways/` | **No change** |
| Tests + fakes | `test/unit/data/verification/*`, `test/widget/systems/verification/*`, `test/support/fakes/fake_verification_remote_data_source.dart` | **Create** — §14 |

No new `public.*` tables, no RPCs, no Edge Functions, no third-party provider.

## 7. Data Requirements

### 7.1 Identity Document Submission (client → storage → credential → RPC)

| Field | Type | Validation | Notes |
|---|---|---|---|
| `documentType` | `DocumentType` enum | required, `nationalId|passport|driversLicense|votersCard|ninSlip` | Display label e.g. "National ID (NIN)" — maps to `kind='identity_document'`, `submission_type='identity_document'` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:130`) |
| `bytes` | `Uint8List` | `1..10485760` (10 MiB `supabase/config.toml:38` `credential-documents` limit) | From `XFile.readAsBytes()` — platform-agnostic (`lib/core/storage/storage_service.dart:31`) |
| `mimeType` | `String` | `image/jpeg|image/png|image/webp|application/pdf` (`supabase/config.toml:39`) | Normalized via `StorageValidators.normalizeMime` (`lib/core/storage/storage_validators.dart:1`) |
| `fileName` | `String` | `1..180 chars` sanitized, ext ↔ MIME consistency | `StoragePaths.sanitize` strips `..`, `/`, control chars |
| `storagePath` | `String` | `{entityId}/{submissionId}/{uuid}_{sanitized}` | `StoragePaths.credentialDocument` — enforces `storage.foldername(name)[1]==auth.uid()` (`supabase/migrations/20260830100001_storage_buckets.sql:118`) |
| `credentialId` | `uuid` | FK `entity_credentials.id` | Created via `supabase.from('entity_credentials').insert` — returned `id` is `verification_submit(p_credential_id)` arg (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:323`) |
| `submission_type` | `text` | `identity_document` (coalesced from `entity_credentials.kind` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:358`) | Client may omit (null default) — server derives from credential `kind` |

Server response envelope `verification_submit`: `{success:true, code:PLT000, message, data: verification_submissions row}` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:399-404`).

### 7.2 Verification Aggregate (RPC read models)

- `verification_status_get(p_entity_id?)` → `VerificationStatusDto{entity_id, kyc:{tier_code,status,limits{daily,weekly,monthly,cashout}}, identity_verified:bool, trade_verifications:[{profession_id, trade_verification_status}], pending_submissions:int, total_submissions:int}` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:592-681`). `identity_verified = status=='active' && tier_code >= tier_1` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:639` — string compare holds for `tier_0..tier_3`).
- `verification_kyc_level_get()` → `{tier_code, status, limits}` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:687-735`).
- `verification_limits_get()` → same limits without `status` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:740-782`).
- `verification_submissions` row: `id, entity_id, credential_id, submission_type, status, priority, submitted_at, reviewed_at, reviewed_by, decision_notes` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:115-143`); `decision_notes ≤5000` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:140-142`).

### 7.3 `kyc_tiers` Reference (read-only)

Seeded `tier_0..tier_3` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:228-234`): `tier_0` all-zero, `tier_1 Identity Verified` `50k/200k/800k/100k`, `tier_2 Trade Verified`, `tier_3 Fully Verified`. `entity_kyc_levels` holds one row per entity (`unique entity_id` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:98`), mutated only by service-role approve (never downgrades `supabase/migrations/20260829090003_verification_admin_review_schema.sql:494-506`).

### 7.4 Notification Payload (derived, not persisted)

`HivorrNotification{id: submissionId, title: 'Verification approved'|'Verification requires attention', body: tier label or decisionNotes preview (≤120 chars), channel: system, priority: high}` — local notification only; no `supabase_realtime` payload (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:798`).

## 8. Database Considerations

- **Zero DDL in this task.** `public.kyc_tiers`, `public.entity_kyc_levels`, `public.verification_submissions`, `public.verification_reviews`, `public.verification_audit_trail`, `public.entity_credentials`, `public.entity_professions` already exist (`supabase/migrations/20260821090002_entity_core_tables.sql:120`, `supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-225`). No `ALTER`, `CREATE POLICY`, `GRANT`, or trigger added. Full pgTAP `001-017` + EP-02 `018-021` suites must remain green (especially `supabase/tests/database/017_storage_posture.sql:60-241` and verification posture `supabase/tests/database/021_*`).
- **RLS posture inherited:** RLS enabled on all 5 verification tables (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:237-241`) + default-deny `revoke all from anon, authenticated` (`243-246`) + grants self-read/insert only on limited columns (`249-276`) + policies `entity_id = auth.uid()` (`279-320`). Authenticated **cannot** write `verification_submissions.status/reviewed_at/reviewed_by` (excluded columns `265`), cannot `UPDATE` `verification_reviews` (no update grant `195`), `verification_audit_trail` append-only. Client verification state is **RPC-or-nothing** (`AGENT.md:16` Rule 4 database-first).
- **Execution model respected:** `verification_submit/status_get/kyc_level_get/limits_get` granted to `authenticated, service_role` (`789-796`); `review_approve/reject` granted to `service_role` only (`792-793`) — client cannot invoke admin path ( `42501 insufficient privilege`). All RPCs `SECURITY INVOKER` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:329`), so RLS applies inside function body.
- **One-active-submission invariant:** Partial unique index `credential_id where status in (pending,in_review)` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:159-161`) enforces dedup at DB level beyond RPC `PLT005` (`364-372`). Client handles `PLT005` as resubmit-after-decision (new credential) UX.
- **No service-role bypass in client.** Adapters never hold `service_role` key; `SupabaseClientProvider.client` (`lib/core/api/supabase/supabase_client_provider.dart:19`) uses `anon`/`authenticated` role with RLS. `grep -r "service_role" lib/systems/verification` must be `0`.
- **Idempotency:** `reference` concept not used here — submission idempotency is credential-scoped (`PLT005`). Retry of `verification_submit` with same `credentialId` returns `409→PLT005` (mapped to `conflict`), not duplicate queue.
- **Audit:** `verification_audit_trail` `submission_created|review_approved|kyc_level_assigned|trade_status_propagated` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:209-214`) is written server-side by RPCs (`386-391`, `466-489`); client never inserts audit rows directly (policy `verification_audit_trail_authenticated_insert` exists for cross-system consistency but RPC is the path `320`).

If applicable — no migrations produced; regression only.

## 9. API Requirements

### 9.1 Supabase RPC (via `SupabaseVerificationRemoteDataSource`)

| Operation | RPC | Params | Auth | Success Envelope | Error → ApiExceptionKind |
|---|---|---|---|---|---|
| Queue submission | `verification_submit` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:323`) | `p_credential_id uuid!, p_submission_type text?` | `authenticated` (`platform_is_authenticated()`) | `200 {success:true, code:PLT000, data: verification_submissions}` | `401 PLT001 auth` (unauth), `404 PLT004 notFound` (credential not owned), `409 PLT005 conflict` (active dup), `422 PLT003 validation` (bad type) |
| Get aggregate | `verification_status_get` (`592`) | `p_entity_id uuid?` (null = self) | `authenticated` self-scoped, `service_role` admin | `{kyc, identity_verified, trade_verifications, pending/total}` | `403 PLT004` (cross-entity `p_entity_id ≠ auth.uid()`) |
| Get KYC | `verification_kyc_level_get` (`687`) | — | `authenticated` | `{tier_code,status,limits}` defaults `tier_0` all-zero | `401 PLT001` |
| Get limits | `verification_limits_get` (`740`) | — | `authenticated` | `{tier_code,daily,weekly,monthly,cashout}` | `401 PLT001` |
| (not invoked by client) | `verification_review_approve/reject` (`412,530`) | `p_submission_id, p_notes?` | `service_role` only | `PLT000` | `42501 → PLT002 forbidden` (client receives `403` if attempted) |

All `supabase.rpc<Map<String,dynamic>>('verification_*', params: {...})` unwrapped via `EnvelopeParser.unwrapData` (checks `data['success']==true && data['code']=='PLT000'` else throws `ApiException` with extracted `code/message` `api_exception_mapper.dart:31-82`).

### 9.2 Supabase REST — `entity_credentials` Insert (credential creation)

`POST /rest/v1/entity_credentials` body `{entity_id, kind:'identity_document', title, document_path, profession_id:null}` (`supabase/migrations/20260821090002_entity_core_tables.sql:137-138` `kind allowed`). Auth `Bearer <accessToken>` from `SupabaseClientProvider.currentAccessToken` (`lib/core/api/supabase/supabase_client_provider.dart:29`). Error: `403 PLT002` if RLS column violation, `409 PLT005` on duplicate? Not emitted — unique is `entity_credentials` not constrained except `credential_id` dedup on submission. Client maps via `DataExceptionMapper`.

### 9.3 Supabase Storage REST (via `StorageService`)

| Bucket | Operation | SDK | Auth | Policy |
|---|---|---|---|---|
| `credential-documents` | `uploadBinary(path, bytes, FileOptions(contentType, upsert:false))` | `storage.from('credential-documents')` (`lib/core/storage/supabase_storage_service.dart:155`) | `authenticated` | `credential_documents_insert_owner` (owner prefix) |
| `credential-documents` | `createSignedUrl(path, 60)` (preview) (`lib/core/storage/supabase_storage_service.dart:274`) | same | `authenticated` | owner-only SELECT |

No `getPublicUrl` on this bucket — throws `StorageValidationException` (`lib/core/storage/supabase_storage_service.dart:264`).

### 9.4 No Edge / No Payment Gateway

No `lib/integrations/payment_gateways/` RPC; no `public.financial_*`; no webhook HMAC.

### 9.5 Error Contract

Every public method throws only `ApiException` (`api_exception.dart:6-66` kinds) or `StorageException` (subtype `StorageValidationException` maps to `PLT003`) — never raw `Supabase`/`DioException`. `BaseApiService.invoke` (`lib/core/api/services/base_api_service.dart:33`) normalizes `DioException` via `ApiExceptionMapper.map` (`lib/core/api/exceptions/api_exception_mapper.dart:18`).

## 10. User Interface Requirements

**Widgets introduce UI — `AGENT.md:17` Rule 5 applies (all `AppTheme` tokens `documents/Context/VISUAL-IDENTITY.md:176-190`).** Every widget in this task must:

- Source colors from `Theme.of(context).colorScheme` / `AppThemeExtension` (`lib/app/theme/app_colors.dart:36`, `lib/app/theme/app_theme_extension.dart`) — never `Colors.*` or `Color(0xFF0B6E99)` inline (that hex lives only in `AppColors` `lib/app/theme/app_colors.dart:16`).
- Source type via `Theme.of(context).textTheme` — never `TextStyle(fontFamily: 'Inter')` (delegated to `lib/app/theme/app_text_theme.dart`).
- Source spacing/radius/elevation/motion via `AppThemeExtension.spacing`/`radiusSm`/`radiusMd`/`elevation`/`duration` (`VISUAL-IDENTITY.md:219-235`) — 8pt grid, cards 16dp, sheets 24dp top.
- Handle 4 states via branded primitives (`lib/shared/widgets/hivorr_empty_state.dart`, `hivorr_loading_state.dart`, `hivorr_error_state.dart`, `hivorr_success_state.dart`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

| Screen/Widget | Route | Purpose | Key Elements |
|---|---|---|---|
| `IdentityDocumentUploadScreen` | `GET /verification/identity` (`app_router.dart:26` pattern) | Type selection + upload + queue | `AppBar(title: Text('Verify identity', style: textTheme.titleLarge))`, `DocumentTypePicker` (chips), `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` preview, `HivorrButton(variant: primary, isLoading, isExpanded:true)`, `LinearProgressIndicator` for `onProgress`, field errors `colorScheme.error` |
| `VerificationStatusScreen` | `GET /verification/status` | Status tracking; deep-linkable share of submission id `?id=` (optional) | `VerificationTimeline` (vertical `Stepper`-like), `IdentityVerifiedBadge` (icon `Icons.verified` tinted `colorScheme.secondary`), `KycLevelCard` (tier label + `limits` chips), `HivorrErrorState` for `rejected/requires_resubmission` with `decisionNotes` + "Resubmit" action |
| `VerificationTimeline` | — | Reusable timeline | Dots: `primary` active, `outline` pending, `error` rejected, `successContainer` approved (`VISUAL-IDENTITY.md:68-79`). Connectors `Divider(color: colorScheme.outline)`. Dates `onSurfaceVariant` caption. |
| `IdentityVerifiedBadge` + `KycLevelCard` | — | Trust signal | `Container(decoration: BoxDecoration(color: colorScheme.successContainer, borderRadius: BorderRadius.circular(ext.radiusSm)))` — soft, not hard shadow (`VISUAL-IDENTITY.md:226`) |

All screens responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web pane.

## 11. User Experience Considerations

- **Progressive disclosure, not overwhelming:** Onboarding calls this in isolation before trade proof (`EP-02:143` `EP-02-18 depends on 10`); the upload screen shows one primary action ("Upload & submit") and guidance "Accepted: JPG, PNG, WebP, PDF up to 10 MB" — matches server `file_size_limit`/`allowed_mime_types` to prevent late rejection. Error copy is human: "This file is too large — please use a file under 10 MB" vs raw `PLT003`.
- **Fail-fast inline validation:** `StorageValidators.validateForBucket` runs on file pick (before upload 2-3s) — invalid MIME/size produces inline `HelperText` under picker; `onProgress` progress is deterministic streaming (`lib/core/storage/supabase_storage_service.dart:112-120` Dio `onSendProgress`), not polling spinner — critical on slow Nigerian 3G.
- **Status determinism vs polling optimism:** Because `verification_submissions` has no realtime, the status screen **polls** `verification_status_get` every 15s until terminal, with backoff on `timeout/network` (`ApiConfig.maxRetries 3/4, baseRetryDelay 500ms` `lib/core/api/api_config.dart:40-49`). The "Pending review — we'll notify you" copy sets expectation; a "Refresh" pull-to-refresh calls `provider.refreshStatus()` immediately. Notifications are the push complement, not the source of truth — UI always re-fetches before rendering badge to prevent spoofed local state.
- **Rejection sensitivity:** `rejected` with `decision_notes` (e.g. "Image blurred — please retake") renders with empathy (`HivorrErrorState` illustration + warm microcopy `VISUAL-IDENTITY.md:241` "friendly microcopy, warm empty/success/error states") and single "Resubmit" CTA that clears old pick (new `entity_credentials` resubmission, not overwriting the reviewed row `supabase/migrations/20260821090002_entity_core_tables.sql:167`).
- **Deduplication UX:** `PLT005` "An active submission already exists" surfaces as dialog with "View status" action that navigates to `verificationStatus`, not retry that would loop.
- **Cultural / jurisdiction clarity:** Document type labels include Nigeria-specific hints ("National ID (NIN)", "Driver's License (FRSC)", "Voter's Card (INEC)") with 1-line helper, without embedding KYC-provider-specific logic.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Server-authoritative gate** `AGENT.md:16` Rule 4 | Client never writes `verification_submissions.status`, `entity_kyc_levels.tier_code`, or `entity_professions.trade_verification_status`. All transitions via RPC (`verification_submit` self, `review_approve/reject` service-role). RLS policy `verification_submissions_authenticated_insert with check (entity_id = auth.uid())` + limited column grant (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:264-266`) enforces prefix; attempt to POST `status:approved` returns `403 PLT002`. `grep -r "trade_verification_status" lib/systems/verification` must be read-only display, never assignment. |
| **No anon access** | All verification tables `revoke all from anon` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:244-246`) + policies `to authenticated` only; `anon` zero read verified in `supabase/tests/database/021_*`. App guards with `RouteGuard` redirect to `/login` (`lib/app/router/route_guard.dart:1`). |
| **Private credential isolation** | `credential-documents public=false` (`supabase/config.toml:37`) + `credential_documents_*_owner` policies. Service never calls `getPublicUrl` (`lib/core/storage/supabase_storage_service.dart:264` throws). Preview via `createSignedUrl(60)` (short TTL, `lib/core/storage/supabase_storage_service.dart:274-293`) — no public link leakage; `HMAC` signed URL is server-minted HMAC per `supabase_storage_service.dart:288` |
| **Path traversal / prefix escape** | Helpers sanitize `..`, `/`, control chars; `with check (storage.foldername(name))[1]=auth.uid()` (`supabase/migrations/20260830100001_storage_buckets.sql:118`) blocks writing outside own prefix even if sanitization fails. `StorageService` test `evil-entity-id/` analog (`supabase/tests/database/017_storage_posture.sql:210-237`) |
| **MIME/size DoS** | `StorageValidators.validateForBucket` blocks before SDK (`supabase_storage_service.dart:96`); server `file_size_limit` 10485760 is second gate. No `application/x-msdownload`/`text/html` before network. |
| **PII exposure** | Token via `SupabaseClientProvider.currentAccessToken` (`lib/core/api/supabase/supabase_client_provider.dart:29`) never logged; `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) masks `entityId` to `***last4`, never logs `document_path` full or `decisionNotes` beyond preview length, never bytes. |
| **No `service_role` or secret billing leak** | No `service_role` import; `grep lib/ "service_role"` = 0; no `PAYSTACK_*` etc. this task. `PaymentGatewayException` not imported. |
| **Time-of-check / race** | `verification_submissions_one_active_credential_idx` partial unique (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:159-161`) prevents two parallel `submit` racing to queue; second gets `PLT005` which maps to `conflict` dialog. |
| **Auth state isolation** | `AppEnvironment` `Development→Staging→Production` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); `credential-documents` bucket per environment via migration, no cross-env read. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **Polling cost** | `Timer.periodic(15s)` only while `status in (pending,in_review)` and screen visible (`WidgetsBindingObserver` `didChangeAppLifecycleState` pauses on background, `AppRouter` `didPush`/`didPop` cancels on navigate). 1 RPC/15s ≈ 240 req/hour peak — `verification_status_get` is `STABLE` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:598`) and indexed `verification_submissions_entity_status_idx` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:150`), negligible. Backoff `500ms→8s` on `timeout/network` (`lib/core/api/api_config.dart:45-49`). |
| **Upload size on 3G** | 10 MiB single-part, no chunking (EP-02-08 defer `353`). `onProgress` Dio path streams bytes, not in-memory copy (`lib/core/storage/supabase_storage_service.dart:112-120` `MultipartFile.fromBytes`). `Uint8List` single allocation < Dart heap; Web `XFile` already in memory, no extra copy. |
| **Caching** | `VerificationProvider` memoizes `status` in memory (no Hive `lib/data/datasources/local/` needed — small aggregate). Invalidate via `refreshStatus()` on resume, submit, or push notification. No disk persistence of `document_path` beyond credential row (source of truth is DB). |
| **Public vs private URL** | `getPublicUrl` not used; `createSignedUrl(60)` minimal signing overhead, short TTL prevents CDN caching of sensitive docs (`lib/core/storage/supabase_storage_service.dart:264`). Public avatar/portfolio remain CDN-cached (`EP-02-08:258`), no cross-talk. |
| **Validation cost** | MIME/size map lookup `O(1)` + sanitize `O(n)` filename (<255 chars) — microseconds, avoids wasted multipart on slow networks (`lib/core/storage/storage_validators.dart:1`). |
| **Tracer overhead** | `PerformanceTracer` span (`lib/core/monitoring/performance_tracer.dart:1`) around `submit`/`getStatus` sampled via `MonitoringConfig`, tags `verification.document_type`, `verification.status`, no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/data/verification/` + `test/unit/systems/verification/`

Pattern mirrors `test/unit/core/api/api_exception_mapper_test.dart` + `test/support/fakes/fake_storage.dart:9` (`InMemorySecureStorage`) and `test/support/fakes/fake_supabase.dart` — no live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `verification_remote_data_source_test.dart` | 16 | Mock `SupabaseClient.rpc` via fake `SupabaseClient` (`fake_supabase.dart`): `verification_submit → {success:true, data:{id, status:pending}}` success; `data: {success:false, code:PLT005}` → `ApiExceptionKind.conflict PLT005`; envelope `success:false` → throws; `verification_status_get → {kyc:{tier_code:tier_0}, identity_verified:false}` defaults; `401→PLT001 auth`, `404→PLT004`, `409→PLT005`, `500→PLT999` via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:18`) |
| `verification_repository_test.dart` | 20 | Fake `StorageService` (`fake_supabase_storage.dart` `test/support/fakes/fake_supabase_storage.dart:1`) + fake remote. Validates `validateForBucket` called first (oversize `10 MiB+1` never hits fake upload spy). Path `entityId/submissionId/uuid_name.jpg` regex; `mimeType` normalized; `credential insert` shape captured; `submit` with duplicate `credentialId` surfaces `conflict` dialog data; `getStatus` success maps DTO→entity, `trade_verifications` empty for identity-only |
| `verification_provider_test.dart` | 14 | `ChangeNotifier` with mocked repository: `submitIdentityDocument` sets `submitState=loading` then `idle`, calls `refreshStatus`; polling `Timer` mocked via `fakeAsync` — 15s ticks until `approved`, cancels on dispose; `maybeNotify` emits `HivorrNotification` only on terminal transition; cross-entity guard `verification_status_get(p_entity_id≠auth.uid()) → PLT004` |
| `verification_mapper_test.dart` | 8 | `VerificationSubmissionDto.fromJson → VerificationSubmission` enum mapping `pending|in_review|approved|rejected|requires_resubmission` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:133-135`), `decision_notes` ≤5000 truncate, null handling |
| `document_type_test.dart` | 6 | Enum labels, `DocumentType.fromTitle`, `kind` always `identity_document`, extensibility `values.length==5` |

Target **≥64 unit assertions**; repository/provider ≥90%, mappers/DTOs 100%.

### 14.2 Widget Suite — `test/widget/systems/verification/`

| File | Cases (min) | Method |
|---|---|---|
| `identity_document_upload_screen_test.dart` | 10 | Pump with `Provider<VerificationProvider>` fake + `MaterialApp` `AppTheme.light` (`lib/app/theme/app_theme.dart:1`): chip selection highlights `colorScheme.primaryContainer` (no `Colors.*`), file pick mock sets preview, `HivorrButton.isLoading` shows `HivorrLoader` (`lib/app/widgets/hivorr_loader.dart:1`), progress `LinearProgressIndicator` visible when `onProgress` fired, error field shows `colorScheme.error` for `oversize`, `grep Colors.` assert `0` |
| `verification_status_screen_test.dart` | 12 | Mock `VerificationStatus{pending→timeline 2 active dots, approved→badge + KycLevelCard limits, rejected→HivorrErrorState + decisionNotes + Resubmit button}`; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily` literal), spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:220`) |
| `verification_timeline_test.dart` | 8 | Timeline dot colors `primary/successContainer/error/outline` per status, no hardcoded hex, semantics `Semantics(label:'Approved')` |

Widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)`.

### 14.3 Integration (Fake-E2E) — `test/integration/verification/verification_flow_test.dart`

Single integration-compose test without live Supabase: fake `SupabaseStorageClient(from('credential-documents'))` (in-memory `Map<path, Uint8List>`, see `fake_supabase_storage.dart`) + fake `SupabaseClient.rpc` map (canned `verification_submit`/`verification_status_get` envelopes) + real `VerificationRepositoryImpl`. Flow: `repo.submitIdentityDocument(DocumentType.passport, bytes: Uint8List(1024), mimeType:'image/jpeg') → status pending → mock `review_approve` side-effect (inject `VerificationStatusDto{identity_verified:true, kyc:{tier_1,active,limits}}`) → `provider.refreshStatus()` → badge asserts `IdentityVerified`. No `supabase start` container needed; live `supabase db test` is the source-of-truth for RLS.

### 14.4 Regression Guard

`flutter analyze` + `flutter test --coverage` (domain ≥80%) + `supabase db test` full suite `001..017` + verification `021_*` green. Lens `grep -r "Colors\.\|Color(0x" lib/systems/verification` = 0, `grep -r "fontFamily" lib/systems/verification` = 0, `grep -r "getPublicUrl" lib/systems/verification` = 0 (private bucket), `grep -r "service_role" lib/` = 0, `git diff --stat supabase/` = 0.

### 14.5 Lens Summary

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` RLS/posture. Add `test/support/fakes/fake_verification_remote_data_source.dart` export.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `lib/systems/verification/.gitkeep`, `lib/data/data_layer.dart:1`, `supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-816`, `lib/core/storage/supabase_storage_service.dart:43`, `lib/core/storage/storage_config.dart:11`, `lib/data/datasources/remote/supabase_taxonomy_remote_data_source.dart:16`, `lib/core/api/services/base_api_service.dart:15`, `lib/app/router/app_router.dart:17`, `lib/app/theme/app_colors.dart:12`, `lib/core/notifications/notifications.dart:1` | Baseline |
| 2 | Draft `lib/systems/verification/models/document_type.dart` — `DocumentType` enum, labels, `kind='identity_document'`, `submission_type='identity_document'` | Vocabulary |
| 3 | Create `lib/data/models/verification_submission_dto.dart`, `verification_status_dto.dart`, `kyc_level_dto.dart`, `verification_limits_dto.dart` — `fromJson` envelope-safe | DTOs |
| 4 | Create `lib/data/entities/verification_submission.dart`, `verification_status.dart`, `kyc_level.dart` — pure Dart | Entities |
| 5 | Create `lib/data/mappers/verification_mapper.dart` — DTO→Entity (status enum, limits numeric) | Mappers |
| 6 | Create `lib/data/datasources/remote/verification_remote_data_source.dart` — abstract §5.2 | Contract |
| 7 | Create `lib/data/datasources/remote/supabase_verification_remote_data_source.dart` — `BaseApiService` impl, `supabase.rpc` + `EnvelopeParser` + `DataExceptionMapper` | DataSource |
| 8 | Create `lib/data/repositories/verification_repository.dart` — abstract §5.3 | Contract |
| 9 | Create `lib/data/repositories/verification_repository_impl.dart` — validate → storage upload (`StoragePaths.credentialDocument`) → credential insert → `remote.submit`, `getStatus`/`getKycLevel`/`getLimits` passthrough | Repo |
| 10 | Create `lib/systems/verification/services/identity_verification_service.dart` — facade §5.4 (logger + tracer) | Facade |
| 11 | Create `lib/data/providers/verification_provider.dart` — `ChangeNotifier` §5.5 + polling timer + notification `maybeNotify` | Provider |
| 12 | Create `lib/systems/verification/widgets/document_type_picker.dart`, `verification_timeline.dart`, `identity_verified_badge.dart`, `kyc_level_card.dart` — tokens `colorScheme`/`textTheme`/`AppThemeExtension` | Widgets |
| 13 | Create `lib/systems/verification/screens/identity_document_upload_screen.dart` — picker → file → `onProgress` → success | Screen 1 |
| 14 | Create `lib/systems/verification/screens/verification_status_screen.dart` — timeline + badge + error/resubmit, poll lifecycle hooks | Screen 2 |
| 15 | Update `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` — add 2 routes guarded by `RouteGuard` | Routes |
| 16 | Update barrels `lib/systems/verification/verification.dart`, `lib/data/data_layer.dart` | Barrels |
| 17 | Create `test/support/fakes/fake_verification_remote_data_source.dart` — canned `verification_submit/status_get/kyc_level_get` envelopes with spy capture | Fake |
| 18 | Create `test/unit/data/verification/verification_remote_data_source_test.dart` (16) + `verification_repository_test.dart` (20) + `verification_provider_test.dart` (14) | Tests 1 |
| 19 | Create `test/unit/data/verification/verification_mapper_test.dart` (8) + `document_type_test.dart` (6) | Tests 2 |
| 20 | Create `test/widget/systems/verification/identity_document_upload_screen_test.dart` (10) + `verification_status_screen_test.dart` (12) + `verification_timeline_test.dart` (8) | Tests 3 |
| 21 | Create `test/integration/verification/verification_flow_test.dart` (fake-E2E submit→pending→mockApprove→status) | Tests 4 |
| 22 | `flutter analyze` + `flutter test --coverage` (≥64 asserts green, domain ≥80%, widgets theme assert) | Verify |
| 23 | Regression: `supabase db test` full suite green + `grep Colors.|Color(0x / fontFamily / getPublicUrl / service_role` = 0 + `git diff --stat supabase/` = 0 | Regression |
| 24 | Doc pass: dartdoc on `DocumentType`, `VerificationRepository.submitIdentityDocument` `Uint8List+onProgress`, `VerificationProvider.polling`, `VISUAL-IDENTITY` guidance, PII note | Docs |
| 25 | Tag `EP-02-11`/`EP-02-18` unblocked in phase plan | Handoff |

## 16. Expected Outcome

- `lib/systems/verification/` + `lib/data/` provide a **server-authoritative, provider-agnostic identity verification seam** — screens depend only on `VerificationProvider`/`IdentityVerificationService`, never `SupabaseClient.rpc` literals or `storage.from` strings (`ARCHITECTURE.md:101-110` compliant).
- Identity document flows validate before network (`10 MiB`, `jpeg/png/webp/pdf` `supabase/config.toml:38-40`, `StorageValidators` `lib/core/storage/storage_validators.dart:1`), upload to private `credential-documents` with compliant `{entityId}/{submissionId}/{uuid}_sanitized` path, create `entity_credentials(kind:identity_document)` (`supabase/migrations/20260821090002_entity_core_tables.sql:137-138`), and queue `verification_submit` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:323`) — duplicate active `credential_id` returns `conflict PLT005` dialog.
- Status tracking polls `verification_status_get` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:592`) with 15s + backoff (`ApiConfig` `lib/core/api/api_config.dart:40`) and renders `VerificationTimeline` (submitted→pending→in_review→approved/rejected) + `KycLevelCard` (`tier_1` limits `50k/200k/800k/100k` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:231`) without `supabase_realtime` (excluded `supabase/migrations/20260829090003_verification_admin_review_schema.sql:798`).
- Approval side-effects (existing server behavior) assign `entity_kyc_levels tier_1 active` never downgrading (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:494-506`) and `verification_audit_trail` rows (`submission_created,kyc_level_assigned` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:209-214`) — visible via `VerificationStatus.identity_verified`.
- Notification hook diffs terminal transitions and emits `HivorrNotification` (`lib/core/notifications/notifications.dart:1`) via provider channel — future Edge push can replace without screen changes.
- Unit+widget+integration suite ≥64 asserts green with fakes; `flutter analyze` clean; full pgTAP `001..017` + verification `021_*` green; `grep` proves no `Colors.*`, no `fontFamily`, no `getPublicUrl` misuse, no `service_role` leakage, no `supabase/` drift.
- `EP-02-11` (trade proof builds same queue shape), `EP-02-12` (KYC seam reads this tier), and `EP-02-18` (onboarding flow step 4) are unblocked — verified entity can proceed to `tier_1` gated financial access.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/data/datasources/remote/verification_remote_data_source.dart` exists — abstract `submit`, `getStatus`, `getKycLevel`, `getLimits` | File inspection |
| 2 | `lib/data/datasources/remote/supabase_verification_remote_data_source.dart` extends `BaseApiService` (`lib/core/api/services/base_api_service.dart:15`), uses `supabase.rpc('verification_submit/status_get/kyc_level_get/limits_get')` + envelope parser + `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) | Code review + unit test |
| 3 | DTOs `verification_submission_dto.dart`, `verification_status_dto.dart`, `kyc_level_dto.dart` + `lib/data/entities/verification_submission.dart/status/kyc_level.dart` + `verification_mapper.dart` map `pending|in_review|approved|rejected|requires_resubmission` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:133-135`) and `kyc limits numeric` without leaking RPC JSON shape | File + mapper unit test |
| 4 | `lib/systems/verification/models/document_type.dart` defines `DocumentType` enum (5 values, labels, `kind=identity_document`, `submission_type=identity_document`) — extensible without schema | File inspection |
| 5 | `lib/data/repositories/verification_repository.dart` + `verification_repository_impl.dart` implement `submitIdentityDocument({DocumentType, Uint8List, mimeType, fileName, onProgress})` → `StorageService.upload` (`StorageBuckets.credentialDocuments`, `StoragePaths.credentialDocument`) → `entity_credentials.insert` → `remote.submit` with `validateForBucket` before network | Code + repo unit test (spy: validation called first, oversize never hits upload) |
| 6 | `lib/data/providers/verification_provider.dart` `ChangeNotifier` holds `VerificationStatus`, `KycLevel`, `AsyncState submitState`, `startPolling/stopPolling` 15s timer, `maybeNotify` on terminal transition via `NotificationProvider` (`lib/core/notifications/providers/notification_provider.dart:1`) | Unit test (fakeAsync timer + notification diff) |
| 7 | `lib/systems/verification/services/identity_verification_service.dart` facades repo + `HivorrLogger` redacted + `PerformanceTracer` `verification.submit.duration` | File inspection |
| 8 | `lib/systems/verification/screens/identity_document_upload_screen.dart` uploads with `onProgress` `LinearProgressIndicator` + `HivorrButton(isLoading)` + `HivorrLoader` breathing pulse, uses `credential-documents` private (`StorageBucketVisibilities` `lib/core/storage/storage_config.dart:90`) via `StorageService` only | Widget test + `grep getPublicUrl` = 0 |
| 9 | `lib/systems/verification/screens/verification_status_screen.dart` renders `VerificationTimeline` + `IdentityVerifiedBadge` + `KycLevelCard` + `HivorrErrorState` for `rejected` with `decisionNotes`, poll lifecycle tied to widget visibility + app lifecycle, pull-to-refresh | Widget test |
| 10 | All screens/widgets consume `AppTheme` tokens only — `Theme.of(context).colorScheme.*`, `Theme.of(context).textTheme.*`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` (`VISUAL-IDENTITY.md:3-9,219-241`) — no `Colors.*`, no `Color(0xFF…)`, no `fontFamily:` literal | `grep` + widget test token asserts |
| 11 | `lib/app/router/route_paths.dart` + `route_names.dart` + `app_router.dart:17` add `/verification/identity` and `/verification/status` guarded by `RouteGuard` (authenticated), no SEO public route, no `/p/:slug/:id` collision | File + router test |
| 12 | Barrels `lib/systems/verification/verification.dart` and `lib/data/data_layer.dart` re-export all new symbols (no stale `.gitkeep` only) | File inspection |
| 13 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat` shows only `lib/**` + `test/**` + `lib/app/router/**` | `git diff --stat` |
| 14 | No `lib/core/storage/*` changes except future import — `git diff --stat lib/core/storage` = 0 (reuses `SupabaseStorageService` `lib/core/storage/supabase_storage_service.dart:43`) | `git diff --stat` |
| 15 | No financial/escrow logic — `grep -r "financial_\|escrow\|payout" lib/systems/verification` = 0; no `lib/integrations/payment_gateways/` import | `grep` |
| 16 | No `service_role`/secret leak — `grep -r "service_role\|sk_live\|supabase_secret" lib/` = 0; `SupabaseClientProvider.client` only (`lib/core/api/supabase/supabase_client_provider.dart:19`) | `grep` + code review |
| 17 | Error normalization `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `409→PLT005 conflict`, `5xx→PLT999 server` via `ApiExceptionMapper` + logical-error branch; raw `DioException` never propagates | Unit test |
| 18 | `test/unit/data/verification/verification_remote_data_source_test.dart` ≥16 cases green | `flutter test` |
| 19 | `test/unit/data/verification/verification_repository_test.dart` ≥20 cases green | `flutter test` |
| 20 | `test/unit/data/verification/verification_provider_test.dart` ≥14 cases green | `flutter test` |
| 21 | `test/unit/data/verification/verification_mapper_test.dart` ≥8 + `document_type_test.dart` ≥6 green | `flutter test` |
| 22 | `test/widget/systems/verification/identity_document_upload_screen_test.dart` ≥10 + `verification_status_screen_test.dart` ≥12 + `verification_timeline_test.dart` ≥8 green | `flutter test` |
| 23 | `test/integration/verification/verification_flow_test.dart` fake-E2E green (submit → pending → mockApprove → badge) | `flutter test` |
| 24 | `flutter analyze` / `dart analyze` clean | CI |
| 25 | `flutter test --coverage` domain ≥80%, widgets theme-asserted; `supabase db test` full suite `001..021` green | `supabase db test` |
| 26 | Visual-identity enforcement: `grep -r "Colors\.\|Color(0x" lib/systems/verification` = 0, `grep -r "fontFamily" lib/systems/verification` = 0, `VISUAL-IDENTITY.md:9` premium finish (soft elevation, `HivorrEmpty/Loading/Error/SuccessState`, ≥48dp touch, 16dp/24dp padding) | Code review |

---

## 18. Implementation AI Execution Profile

### Recommended Coding Reasoning Level: **Very High**

### Reasoning Level Justification

| Factor | Assessment |
|---|---|
| **Technical complexity** | **Very High** — Storage → credential → RPC envelope chain (`lib/core/storage/supabase_storage_service.dart:74` progress fallback, `lib/data/datasources/remote/taxonomy_envelope_parser.dart` pattern, `supabase/migrations/20260829090003_verification_admin_review_schema.sql:364` dedup + `PLT005` conflict), polling without realtime (`supabase_realtime` excluded `20260829090003:798`), `BaseApiService` + `DataExceptionMapper` + provider timer lifecycle, Web-compatible `Uint8List` payload. Not `Extremely High` (no `SECURITY DEFINER`/pgTAP authoring — `EP-02-03` owns that). |
| **Business impact** | **Critical** — First trust gate; failure blocks `EP-02-11/12/13/16/18/19` (6 downstream items `EP-02:139`). Identity fraud vector if storage path/MIME bypassed or status client-writable. |
| **Security risk** | **Very High** — Private `credential-documents` (`public:false` `supabase/config.toml:37`) must never leak via `getPublicUrl`; `verification_submissions.status` is `service_role`-only (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:792-793`) + limited insert grant (`264-266`); cross-entity `verification_status_get` must enforce `PLT004` (`622`). PII logging via `pii_redactor` is mandatory. |
| **Performance sensitivity** | **Medium** — 15s polling (`STABLE` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:598`) + 10 MiB single-part upload on Nigerian 3G; tracer `verification.submit.duration` is lightweight. |
| **Data complexity** | **High** — 5 RPC envelopes + `entity_credentials` insert shape + DTO↔entity enums (`pending|in_review|requires_resubmission`), `kyc_tiers` numeric limits, `verification_audit_trail` append-only, partial unique index semantics. |
| **Integration complexity** | **Very High** — Injects `SupabaseClientProvider` (`lib/core/api/supabase/supabase_client_provider.dart:19`) + `StorageService` (`lib/core/storage/storage_service.dart:16`) + `AccessTokenProvider` + `NotificationProvider` (`lib/core/notifications/providers/notification_provider.dart:1`) + `ApiConfig.forEnvironment` (`lib/core/api/api_config.dart:40`), must remain swappable for future `KycProvider` (`EP-02-12`). |

The Approved Phase Plan assigns EP-02-10 **Planning: Very High / Coding: Very High** (`EP-02 Trust, Identity & Financial Integrity Engine.md:355-356` — 1 of 8 `Very High` items, distinct from 6 `Extremely High` financial items `EP-02:498` `03/04/05/09/14/16`). **Very High** is calibrated: `High` would under-index the trust-gate, private-storage, and envelope invariants; `Extremely High` is reserved for double-entry ledger/escrow (`EP-02-04/14`).

---

> **Decision Log (approved):** Questions resolved and implementation green-lit.
> 1. **DocumentType vocabulary:** **Standard (5-8 types)** — locked to the 5-value vocabulary (National ID / Passport / Driver's License / Voter's Card / NIN Slip). Extensible via enum + label for future `EP-02-12` KYC providers.
> 2. **Signed URL TTL:** **10 minutes (600s)** for `credential-documents` preview via `createSignedUrl(600)` — more forgiving on slow Nigerian 3G while remaining private/owner-only.
> 3. **Status tracking:** **Push via Supabase Realtime** as the primary strategy — though `verification_submissions` is currently excluded from `supabase_realtime` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:798`), the provider uses Realtime subscription on the app `HivorrNotification` channel as the push complement, while polling `verification_status_get` every 15s (foreground, pausing on background) remains the **source of truth**. UI always re-fetches before rendering badge to prevent spoofed local state.
>
> **Next Step:** Implementation in progress per §15 sequence.
