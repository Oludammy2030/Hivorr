# Task Implementation Plan — EP-02-11: Trade Verification Workflow & Admin Review Gate

**Task ID:** EP-02-11 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Not Started | **Priority:** Critical | **Dependencies:** EP-02-03, EP-02-06, EP-02-10 | **Stage:** 4 — Trust & Verification Systems

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:357-366` | Architecture: `documents/Context/ARCHITECTURE.md:55-60,95-110,131-138`, `documents/Context/AGENT.md:7,15,16,17` | Dependencies: `EP-02:139` (`EP-02-11 → 10, 06`), `EP-02:357-366`, `EP-02:483` | Stack: `pubspec.yaml:43-53` (`dio 5.11.0`, `supabase_flutter 2.17.2`, `provider 6.1.5`), `lib/core/storage/storage_service.dart:16`, `lib/data/providers/verification_provider.dart:42`, `supabase/migrations/20260829090003_verification_admin_review_schema.sql:1-816`, `supabase/migrations/20260821090002_entity_core_tables.sql:120-186`

---

## 1. Task Objective

Build the client-side **Trade Verification Workflow & Admin Review Gate** in `lib/systems/verification/` plus its unified Data Layer in `lib/data/` — per-profession trade proof submission (certificates, licenses, work samples), `.` upload via `StorageService` (`lib/core/storage/supabase_storage_service.dart:43`), `entity_credentials` creation (with `profession_id` binding), `verification_submit(p_credential_id, p_submission_type='trade_proof')` queueing (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:323-406`), real-time status tracking (`unverified → pending → approved/rejected`) with `trade_verification_status` propagation gated by the `AGENT.md:15` Rule 2 bid-lock, and an admin review queue interface (simplified for EP-02-02). Connect the `EP-02-06` private bucket seam to the `EP-02-03` server-authoritative verification RPC engine. Zero `public.*` DDL in this task — all server infrastructure from `EP-02-03` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql`) and `EP-01-06` (`supabase/migrations/20260821090002_entity_core_tables.sql`) is frozen and reused. Zero financial math. Zero hardcoded `Colors.*`/hex.

Deliverables:
- Data layer: `TradeProofType` enum, `TradeVerificationSubmission`/`TradeVerification` entities + DTOs + mapper extensions, `TradeVerificationRemoteDataSource` (RPC-only), `TradeVerificationRepository`, `TradeVerificationProvider` in `lib/data/`
- Orchestration: `TradeVerificationService` in `lib/systems/verification/` (profession binding → storage → credential → queue → status)
- Gate logic: `TradeVerificationGate.canBid(status, professionId)` pure-function bid-lock in `lib/systems/verification/`
- UI: `TradeProofUploadScreen`, `TradeVerificationStatusScreen`, `TradeVerificationTimeline`/`TradeVerifiedBadge` widgets (`lib/systems/verification/widgets/`)
- Admin: `AdminReviewQueueScreen` (simplified for EP-02-02) — pending submissions list, approve/reject with notes via service-role seam
- Routes: `/verification/trade-proof` + `/verification/trade/status` + `/admin/review-queue` (`lib/app/router/app_router.dart:17`)
- Notification hook: trade verification decision → `HivorrNotification` (`lib/core/notifications/`)
- Unit + widget + integration test suite (mocked `SupabaseClient`, fake `StorageService`)

## 2. Business Problem Being Solved

`EP-02:25,357-366` mandates trade verification as the **second trust checkpoint** — the marketplace participation gate. Per `AGENT.md:15` Rule 2, `tradeVerificationStatus == APPROVED` unlocks bidding for a given profession; unverified professionals have dashboard access but cannot participate in transactions. Server infrastructure exists:

- `supabase/migrations/20260829090003_verification_admin_review_schema.sql:115-162` (`verification_submissions` + `verification_reviews` + `verification_audit_trail`) and `322-796` (RPCs: `verification_submit`, `verification_review_approve/reject` service-role only, `verification_status_get`) — fully RLS default-deny, `SECURITY INVOKER`, envelope `{success,code,message,data}`.
- `supabase/migrations/20260821090002_entity_core_tables.sql:170-186` (`entity_professions.trade_verification_status` — allowed values, `unverified` default, RLS grant excludes) holds the per-profession gate.
- `supabase/config.toml:36-40` + `lib/core/storage/supabase_storage_service.dart:43` (`credential-documents` private, 10 MiB, `jpeg/png/webp/pdf`).
- `EP-02-10` delivers the `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42`) — 15s polling, `HivorrNotification` integration, `WidgetsBindingObserver` lifecycle — which `TradeVerificationProvider` extends.

But no client trade-verification system exists. Without EP-02-11:

- Every entity would inline `supabase.from('entity_credentials').insert(...)` + `supabase.rpc('verification_submit')` in profile/onboarding screens, duplicating storage path conventions (`storage_paths.dart` → `StoragePaths.credentialDocument`), MIME/size validation, envelope parsing, and `ApiException` mapping — violates `ARCHITECTURE.md:91-94` separation and `AGENT.md:6` server-side enforcement (client must never write `entity_professions.trade_verification_status` directly; only RPC flips it).
- No single source for the trade proof vocabulary (5 values: `certificate/license/workSample/portfolio/other`) — future profession subtypes would require screen-by-screen edits.
- No bid-lock gate — bidding screens would need `AGENT.md:15` Rule 2 logic duplicated per-screen, and `TradeVerificationGate.canBid(status, professionId)` would not exist as a single testable pure function.
- No admin review queue interface — `verification_review_approve/reject` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:412-489, 530-590`) requires the service-role path that no client seam exposes.

This task is the **Stage 4 trade seam** that unblocks marketplace `EP-03` bid-lock enforcement (server-side) and, together with `EP-02-10`, completes the trust gate so a string-comparable `trade_verification_status == 'approved'` unlocks bidding per `AGENT.md:15`.

## 3. Scope

| In Scope | Detail |
|---|---|
| `TradeVerificationRemoteDataSource` abstract + `SupabaseTradeVerificationRemoteDataSource` | Injects `SupabaseClient`+`Dio`+`ApiExceptionMapper` via `BaseApiService` pattern (`lib/core/api/services/base_api_service.dart:15`). Methods: `submit(credentialId, submissionType='trade_proof')`, `getStatus(entityId?)` (reuses `verification_status_get`). All via `supabase.rpc` envelope → `TaxonomyEnvelopeParser` equivalent + `DataExceptionMapper` (`lib/data/datasources/remote/data_exception_mapper.dart`) |
| `entity_credentials` insert for trade proofs | `supabase.from('entity_credentials').insert({entity_id: auth.uid(), kind: (maps from TradeProofType), title, document_path: storageKey, profession_id: boundProfessionId})` — auth insert grant is self-scoped; `verification_status`/`reviewed_at` excluded (server-only `supabase/migrations/20260821090002_entity_core_tables.sql:120-150` + RLS). Client never writes `verification_submissions.status` or `entity_professions.trade_verification_status` |
| Domain models | `TradeProofType` enum (`certificate, license, workSample, portfolio, other` → display label + allowed `kind`), `TradeVerificationSubmission` entity, `TradeVerification` entity (per-profession status), `TradeVerificationStatus` aggregate — pure Dart, no provider DTO leakage |
| DTOs + mappers | Extend `VerificationStatusDto`/`VerificationSubmissionDto` or add trade-specific `TradeVerificationDto` with `mapper` to entity (`lib/data/mappers/verification_mapper.dart` extension, `lib/data/mappers/industry_mapper.dart` pattern) |
| `TradeVerificationRepository` | `submitTradeProof({TradeProofType, Uint8List bytes, mimeType, fileName, professionId, onProgress})`, `getStatus()` (reuses `verification_status_get` aggregate `trade_verifications` array), `pollStatus({interval, backoff})` — orchestrates `StorageService.upload(bucket: StorageBuckets.credentialDocuments)` → credential insert (with `profession_id`) → `verification_submit('trade_proof')` |
| `TradeVerificationService` (`lib/systems/verification/`) | Thin orchestration facade over repository + `StorageService` + `StoragePaths.credentialDocument(entityId, submissionId, fileName)` (`lib/core/storage/storage_paths.dart`). Validates `validateForBucket` before network, sanitizes fileName, uses `TaxonomyEngine` (`lib/workspace/profession_registry/taxonomy_engine.dart:12`) to validate profession binding + resolve profession name |
| `TradeVerificationGate` | Pure-function bid-lock: `bool canBid(TradeVerificationStatus status, String professionId)` — returns `true` iff the given profession's `trade_verification_status == approved` (`AGENT.md:15` Rule 2). Marketplace `EP-03` enforces server-side; this is the client mirror. Unit-testable with no I/O |
| `TradeVerificationProvider` | `ChangeNotifier` extending `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42`) — `status: AsyncValue<TradeVerificationStatus>`, `submitState`, `pollTimer`. Polling 15s with exponential backoff on `timeout/network`, stops on `approved/rejected`, `WidgetsBindingObserver` lifecycle pause, `HivorrNotification` on terminal transition |
| UI screens + widgets | `TradeProofUploadScreen` (profession picker via `TaxonomyEngine` → type picker → file pick via `XFile.readAsBytes()` → preview → upload with `onProgress` linear indicator + `HivorrLoader`), `TradeVerificationStatusScreen` (per-profession timeline: `unverified → submitted → pending → approved/rejected`, `TradeVerifiedBadge`, CTA resubmit), `AdminReviewQueueScreen` (simplified internal screen — pending submissions list, approve/reject with notes via service-role seam) — responsive via `shared/layouts/`, tokens via `AppColors`/`AppThemeExtension` (`lib/app/theme/app_colors.dart:16`) |
| Notification integration | On `getStatus()` transition to `approved/rejected`, emit `HivorrNotification{priority:high, channel: system, title, body}` via `NotificationService` + `HivorrNotification` (`lib/core/notifications/notifications.dart`) — same pattern as `EP-02-10` |
| Barrel + DI | `lib/systems/verification/verification.dart` + `lib/data/data_layer.dart:1` re-exports; factory `TradeVerificationProvider.create(supabase: SupabaseClientProvider.client, storageService: SupabaseStorageService(...))` |
| Tests | Unit (gate pure logic, repository + provider + mappers + validators), widget (screens with `AppTheme` token asserts), integration (fake Supabase RPC, bind profession → submit → approve → bid-lock released) |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL / RLS / RPC creation, `storage.buckets` change, `supabase/config.toml` edit | `EP-02-03` frozen (`20260829090003_verification_admin_review_schema.sql:1-816`); this task is `lib/` only. `git diff --stat supabase/` must be `0`. All server infra reused as-is |
| Writing `entity_professions.trade_verification_status` from the client | Server-authoritative only — `verification_review_approve` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:412-489`) flips it and writes `trade_status_propagated` audit; `trade_verification_status` is **never written by client**. `pending` is derived client-side from `verification_submissions` status |
| Bid-lock server-side enforcement (marketplace) | `EP-03` marketplace enforces `canBid` server-side; `TradeVerificationGate.canBid` is the client pure-logic mirror only |
| KYC tier definitions / `KycProvider` abstract / provider adapters (SmileID/Dojah) / `entity_kyc_levels` admin write | `EP-02-12` seam — this task **reads** `kyc_tiers`/`entity_kyc_levels` display-only via `verification_status_get`, never writes |
| `expires_at` capture / license expiry tracking for `TradeProofType.license` | Open question #1 — default deferred unless user approves capturing `expires_at` for licenses. No `expires_at` DDL in this task |
| Amending `EP-02-03` to auto-persist `pending` on `verification_submit` | Open question #2 — default `pending` is derived client-side, not persisted (`supabase/migrations/20260829090003_verification_admin_review_schema.sql` unchanged) |
| Advanced admin review queue (pagination, filters, sorting, bulk ops, image preview) | Open question #3 — default: **simplified** internal screen in EP-02 (pending list + approve/reject with notes), advanced UI deferred |
| Bid-lock helper RPC `verification_can_bid(professionId)` | Open question #4 — default: reuse single `verification_status_get` aggregate (`trade_verifications` array), no new RPC |
| Financial ledger, `financial_*` tables, escrow, payout, deposit name-match | `EP-02-04/13/16` — no `financial_*` import; no money movement |
| Supabase Edge Functions for thumbnailing/virus scan/webhook HMAC | Deferred; `CredentialDocuments` path helper + signed URL TTL 60-300s is sufficient (`lib/core/storage/supabase_storage_service.dart:274-293`) |
| Direct `Paystack`/`Flutterwave`/`NIBSS` calls | `EP-02-09` `lib/integrations/payment_gateways/` — not used by trade proof path |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/verification/` vs `lib/data/` vs `lib/core/storage/`

`ARCHITECTURE.md:56,101-110,131-138` assigns `lib/core/storage/` = platform object store, `lib/data/` = DTO/entity/repository/provider, `lib/systems/verification/` = trust-gate business system. Trade verification mirrors the `EP-02-10` identity pattern (`lib/systems/verification/` + `lib/data/`): the **data layer** owns RPC transport + DTOs (reusable across `EP-02`/`EP-03`), the **systems layer** owns the trade proof vocabulary, profession binding, path conventions, bid-lock gate logic, and UX orchestration (progress, timeline, badge). The `TaxonomyEngine` (`lib/workspace/profession_registry/taxonomy_engine.dart:12`) lives in `lib/workspace/profession_registry/` per `ARCHITECTURE.md:89` and is **imported** (not duplicated) for profession validation + name resolution. This mirrors `EP-02-07` taxonomy pattern.

No new top-level `lib/` directory is created.

### 5.2 Data Layer Contract

```dart
// lib/data/datasources/remote/trade_verification_remote_data_source.dart
abstract class TradeVerificationRemoteDataSource {
  Future<VerificationSubmissionDto> submit({
    required String credentialId,
    String submissionType, // 'trade_proof'
  });
  Future<VerificationStatusDto> getStatus({String? entityId}); // reuse verification_status_get
}

// lib/data/models/trade_verification_dto.dart
class TradeVerificationDto {
  final String professionId;
  final String tradeVerificationStatus; // unverified|pending|approved|rejected
  final String? professionName; // resolved via TaxonomyEngine
}

// lib/data/entities/trade_verification_status.dart
class TradeVerificationStatus {
  final List<TradeVerification> tradeVerifications; // per-profession
  final bool identityVerified;
  // pure Dart, no json
}

// lib/data/mappers/verification_mapper.dart — extend with trade methods
```

- Implementation `SupabaseTradeVerificationRemoteDataSource extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`) — constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`. `submit` invokes `supabase.rpc<Map<String,dynamic>>('verification_submit', params:{p_credential_id, p_submission_type:'trade_proof'})` then `EnvelopeParser.unwrapData` (validates `{success:true, code:PLT000, data:{...}}`). `getStatus` invokes `supabase.rpc<Map<String,dynamic>>('verification_status_get', params:{p_entity_id})` and extracts the `trade_verifications:[{profession_id, trade_verification_status}]` array (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:592-681`). `DataExceptionMapper` maps `ApiException(PLT001/003/004/005/999)` to `DataException`.
- Client only ever calls `getStatus` without entityId (self-scoped via `auth.uid()`); cross-entity `p_entity_id` returns `PLT004` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:622`).
- `StorageService` is **not** injected into the DataSource — it lives in the repository/systems layer to keep `lib/data/` persistence-agnostic (same as `EP-02-10` §5.2).

### 5.3 Repository — `TradeVerificationRepository` (the unit-tested business contract)

```dart
abstract class TradeVerificationRepository {
  Future<VerificationSubmission> submitTradeProof({
    required TradeProofType type,
    required String professionId,
    required Uint8List bytes, required String mimeType, required String fileName,
    void Function(int,int)? onProgress,
  });
  Future<TradeVerificationStatus> getStatus();
}
```

`TradeVerificationRepositoryImpl` (`lib/data/repositories/trade_verification_repository_impl.dart` style):

1. **Validate first** — `storageService.validateForBucket(bucket: StorageBuckets.credentialDocuments, mimeType: mimeType, byteLength: bytes.length)` (`lib/core/storage/storage_validators.dart:1`). On failure throw `DataValidationException(PLT003)` → provider surfaces inline field error. Mirrors `SupabaseStorageService.validateForBucket` (`lib/core/storage/supabase_storage_service.dart:96`).
2. **Resolve profession** — use `TaxonomyEngine` (`lib/workspace/profession_registry/taxonomy_engine.dart:12`) to validate the `professionId` is bound and resolve display name for title.
3. **Reserve ID** — generate `submissionId = Uuid.v4()` (`uuid: ^4.5.1` `pubspec.yaml:71`) for path helper `StoragePaths.credentialDocument(entityId: auth.uid(), submissionId: submissionId, fileName: fileName)` — produces `{entityId}/{submissionId}/{uuid}_{sanitized}` matching `storage.foldername(name)[1] == auth.uid()::text` owner prefix.
4. **Upload** — `await storageService.upload(bucket: credentialDocuments, path: storagePath, bytes: bytes, mimeType: StorageValidators.normalizeMime(mimeType), fileName: fileName, onProgress: onProgress, upsert: false)` (`lib/core/storage/supabase_storage_service.dart:74-129`). Private bucket: preview only via `createSignedUrl(60)`, never `getPublicUrl` (throws `StorageValidationException`).
5. **Create credential with profession binding** — `final cred = await supabase.from('entity_credentials').insert({entity_id: entityId, kind: tradeProofKind, title: 'professionName — tradeProofTypeLabel', document_path: storagePath, profession_id: professionId}).select().single()` — `profession_id` FK → `professions(id)` (`supabase/migrations/20260821090002_entity_core_tables.sql:120-150`), RLS self-insert.
6. **Queue** — `await remote.submit(credentialId: cred['id'], submissionType:'trade_proof')` → `PLT005` if active submission exists (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:364-381`), mapped to friendly "You already have a pending verification for this document."
7. **Return** — mapped `VerificationSubmission`; `verification_audit_trail` `submission_created` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:386-391`) is the immutable proof; no client audit write needed.
8. **Polling helper** — provider timer calls `getStatus()` every 15s until terminal, `ApiConfig.forEnvironment` retry on `timeout/network` (`lib/core/api/api_config.dart:40`).

Repository never imports `lib/systems/` widgets — unidirectional `data → systems`.

### 5.4 Systems Facade — `TradeVerificationService` + `TradeVerificationGate` (`lib/systems/verification/`)

Thin wrapper used by `TradeVerificationProvider` and future onboarding flow:

- Exposes `supportedTradeProofTypes = TradeProofType.values` (extensible — adding a type is enum + label; `kind` maps to allowed `entity_credentials.kind` value).
- Delegates to repository; adds `HivorrLogger` (`lib/core/logging/hivorr_logger.dart`) redacted log (`entityId: ***last4`, `type`, `byteLength`, `mimeType`, `professionId`) via `pii_redactor.dart` — never logs `document_path` full or bytes.
- `PerformanceTracer` span `trade.proof.submit.duration` tagged `type` (`lib/core/monitoring/performance_tracer.dart`).
- **`TradeVerificationGate`** — pure-function bid-lock:
  ```dart
  class TradeVerificationGate {
    static bool canBid(TradeVerificationStatus status, String professionId) {
      final t = status.tradeVerifications.firstWhere(
        (e) => e.professionId == professionId, orElse: () => unverified);
      return t.tradeVerificationStatus == 'approved'; // AGENT.md:15 Rule 2
    }
  }
  ```
  No I/O, no globals — trivially testable. Marketplace `EP-03` enforces server-side; this is the client mirror.

### 5.5 State — `TradeVerificationProvider` (`lib/data/providers/`)

```dart
class TradeVerificationProvider extends ChangeNotifier {
  TradeVerificationStatus? status; AsyncState submitState;
  Future<void> submitTradeProof({TradeProofType, professionId, Uint8List, mimeType, fileName}) async {
    submitState=loading; try { await repo.submitTradeProof(...); await refreshStatus(); } on ApiException catch(e){ submitState=error(e); }
  }
  Future<void> refreshStatus() async { status = await repo.getStatus(); maybeNotify(status); }
  void startPolling(); void stopPolling(); // Timer.periodic 15s, cancel on dispose/terminal
  // WidgetsBindingObserver pauses on background; AppRouter didPush/didPop cancels on navigate
}
```

- Constructor injection `({required TradeVerificationRepository repo, HivorrLogger? logger})` for testability (`provider:6.1.5`).
- Extends the `EP-02-10` `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42`) — 15s polling, `HivorrNotification` on terminal transition via `NotificationProvider`, `WidgetsBindingObserver` lifecycle.
- Notification hook: `maybeNotify` diffs `prev.status` → `next` terminal; if changed, `notificationProvider.show(HivorrNotification(title:'Trade verification ${next}', body: ..., priority: high))`.
- No `SupabaseClientProvider` singleton inside provider — repository holds the client.

### 5.6 UI — `lib/systems/verification/screens/` + `widgets/`

- `TradeProofUploadScreen` (stateful):
  1. Profession selector — bound professions from `TaxonomyEngine` (`lib/workspace/profession_registry/taxonomy_engine.dart:12`); unbound shows "Add a profession" CTA. Selected chip uses `ColorScheme.primaryContainer` (`VISUAL-IDENTITY.md:51`), not hardcoded `Colors.blue`.
  2. Proof type selector — `ChoiceChip`/`HivorrChip` group (5 options: `certificate/license/workSample/portfolio/other`).
  3. File picker — `XFile` (`readAsBytes()` for Web compat). Shows preview (`Image.memory` for images, PDF icon for `application/pdf`). Reject before upload via `StorageValidators.validateForBucket` message (field-level `Text(error)` with `ColorScheme.error`).
  4. Upload — `HivorrButton(isLoading: submitState.isLoading, onPressed: pick != null && profession != null ? submit : null)` + `LinearProgressIndicator(value: sent/total)` from `onProgress`. Uses `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not `CircularProgressIndicator`.
  5. Success — `HivorrSuccessState`/`HivorrEmptyState` with branded illustration slot + "We'll review within 24h" guidance + CTA to `TradeVerificationStatusScreen`.
- `TradeVerificationStatusScreen`:
  - Reads `provider.status` — shows `HivorrLoadingState` while null, per-profession `TradeVerificationTimeline` (vertical stepper: `Unverified → Submitted → Pending → Approved/Rejected`, timestamps `submittedAt`/`reviewedAt`, `decisionNotes` for rejection `supabase/migrations/20260829090003_verification_admin_review_schema.sql:120-143`).
  - `TradeVerifiedBadge` (green check + profession name) on `approved`; bid-lock state shown when `TradeVerificationGate.canBid == false` ("Unverified — bidding is locked until approved").
  - Rejection view: `HivorrErrorState` with `decisionNotes`, "Resubmit" CTA re-invokes repository (creates **new** `entity_credentials` row, not UPDATE).
  - No raw hex/Fonts: all `Theme.of(context).colorScheme.*`, `textTheme.*`, spacing via `AppThemeExtension.spacing` (`VISUAL-IDENTITY.md:219`), radius `AppThemeExtension.radiusSm/Md` (cards 16dp, sheets 24dp).
- `AdminReviewQueueScreen` (simplified internal screen, §10):
  - Pending submissions list with credential/type/profession, "Review" → approve/reject with `decisionNotes` via service-role seam (`verification_review_approve/reject`).
  - EP-02 scope = simplified; advanced pagination/filters/bulk/image preview deferred (open question #3 default).

### 5.7 Routing — `lib/app/router/`

Extend `AppRouter.create` (`lib/app/router/app_router.dart:17`) via `RoutePaths.tradeProofUpload = '/verification/trade-proof'`, `tradeVerificationStatus = '/verification/trade/status'`, `adminReviewQueue = '/admin/review-queue'` and `RouteNames.*`. Guards: entity routes via `RouteGuard` (`lib/app/router/route_guard.dart:1`, authenticated); admin route additionally gated for admin role (internal). No SEO public URL (private flow).

### 5.8 Config & Logging

- No new `ENV` keys — storage and Supabase config cover it.
- Errors via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) — `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `409→PLT005 conflict`, `5xx→PLT999 server`. `TradeVerificationRemoteDataSource` rethrows normalized `ApiException`.
- `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) — log `entityId suffix`, `type`, `mimeType`, `byteLength`, `professionId`; never `document_path` full, never bytes, never personal name. `MonitoringService` span `trade.proof.submit` sampled.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `TradeVerificationRemoteDataSource` abstract | `lib/data/datasources/remote/trade_verification_remote_data_source.dart` | **Create** — §5.2 |
| `SupabaseTradeVerificationRemoteDataSource` | `lib/data/datasources/remote/supabase_trade_verification_remote_data_source.dart` | **Create** — `BaseApiService` impl §5.2 |
| Trade DTOs | `lib/data/models/trade_verification_dto.dart` | **Create** — §5.2 |
| Trade entities | `lib/data/entities/trade_verification_status.dart`, `trade_verification.dart` | **Create** |
| Mappers | `lib/data/mappers/verification_mapper.dart` | **Update** — extend with trade methods |
| `TradeVerificationRepository` abstract + impl | `lib/data/repositories/trade_verification_repository.dart` + `trade_verification_repository_impl.dart` | **Create** — §5.3 |
| `TradeVerificationProvider` | `lib/data/providers/trade_verification_provider.dart` | **Create** — §5.5 (extends `VerificationProvider` pattern) |
| `TradeProofType` enum + helpers | `lib/systems/verification/models/trade_proof_type.dart` | **Create** — §5.4 |
| `TradeVerificationService` facade | `lib/systems/verification/services/trade_verification_service.dart` | **Create** — §5.4 |
| `TradeVerificationGate` bid-lock | `lib/systems/verification/gate/trade_verification_gate.dart` | **Create** — §5.4 |
| Screens | `lib/systems/verification/screens/trade_proof_upload_screen.dart`, `trade_verification_status_screen.dart`, `lib/data/.../admin_review_queue_screen.dart` | **Create** — §5.6, §10 |
| Widgets | `lib/systems/verification/widgets/trade_verification_timeline.dart`, `trade_verified_badge.dart`, `trade_proof_type_picker.dart` | **Create** |
| Barrel | `lib/systems/verification/verification.dart` + update `lib/data/data_layer.dart` | **Create/Update** |
| Route extension | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` | **Update** — add 3 routes, guard via `RouteGuard` |
| `StorageService` reuse | `lib/core/storage/supabase_storage_service.dart:43` | **Reuse** — no new storage code |
| `TaxonomyEngine` import | `lib/workspace/profession_registry/taxonomy_engine.dart:12` | **Import** — profession validation + name resolution |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — verify `git diff --stat supabase/` = 0 |
| No `lib/integrations/payment_gateways/*` | `lib/integrations/payment_gateways/` | **No change** |
| Tests + fakes | `test/unit/data/verification/trade_*`, `test/widget/systems/verification/trade_*`, `test/support/fakes/` | **Create** — §14 |

No new `public.*` tables, no RPCs, no Edge Functions, no third-party provider.

## 7. Data Requirements

### 7.1 Trade Proof Submission (client → storage → credential(with profession) → RPC)

| Field | Type | Validation | Notes |
|---|---|---|---|
| `professionId` | `uuid` | required, FK `professions(id)`, must be entity-bound | Resolved via `TaxonomyEngine` (`lib/workspace/profession_registry/taxonomy_engine.dart:12`); `entity_professions` M:N `unique(entity_id, profession_id)` |
| `TradeProofType` | enum | required, `certificate|license|workSample|portfolio|other` | Display label e.g. "Certificate", "License", "Work Sample", "Portfolio", "Other" — maps `entity_credentials.kind` + `submission_type='trade_proof'` |
| `bytes` | `Uint8List` | `1..10485760` (10 MiB `supabase/config.toml:38`) | From `XFile.readAsBytes()` |
| `mimeType` | `String` | `image/jpeg|image/png|image/webp|application/pdf` (`supabase/config.toml:39`) | Normalized via `StorageValidators.normalizeMime` |
| `fileName` | `String` | `1..180 chars` sanitized, ext ↔ MIME consistency | `StoragePaths.sanitize` |
| `storagePath` | `String` | `{entityId}/{submissionId}/{uuid}_{sanitized}` | `StoragePaths.credentialDocument` — owner prefix |
| `credentialId` | `uuid` | FK `entity_credentials.id` | `profession_id` set; `kind` from `TradeProofType`; `verification_status`/`reviewed_at` excluded |
| `submission_type` | `text` | `trade_proof` | Client passes `p_submission_type='trade_proof'`; server derives/validates via `entity_credentials.kind` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:358`) |
| `expires_at` | `timestamptz`? | (open question #1) | **Default deferred** — not captured unless user approves license-expiry tracking; no DDL |

### 7.2 Trade Verification Aggregate (RPC read models)

- `verification_status_get(p_entity_id?)` returns `trade_verifications:[{profession_id, trade_verification_status}]` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:592-681`) — display-only. `trade_verification_status ∈ {unverified, pending, approved, rejected}` (`supabase/migrations/20260821090002_entity_core_tables.sql:170-186`); `pending` is **derived client-side** from `verification_submissions` status (open question #2 default), `unverified` is the DB default.
- `verification_submissions` row: `id, entity_id, credential_id, submission_type, status, priority, submitted_at, reviewed_at, reviewed_by, decision_notes` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:115-143`); `decision_notes ≤5000`.

### 7.3 Profession Binding (`entity_professions`)

`entity_professions` holds the per-profession gate with `unique(entity_id, profession_id)` (`supabase/migrations/20260821090002_entity_core_tables.sql:170-186`). `trade_verification_status` default `unverified`, RLS grant **excludes** write (`supabase/migrations/20260821090003_entity_model_rls_policies.sql:125-127`) — client reads only via `verification_status_get`, never assigns.

### 7.4 Notification Payload (derived, not persisted)

`HivorrNotification{id: submissionId, title: 'Trade verification approved'|'Trade verification requires attention', body: professionName + decisionNotes preview (≤120 chars), channel: system, priority: high}` — local notification only; no `supabase_realtime` payload (excluded `supabase/migrations/20260829090003_verification_admin_review_schema.sql:798`).

## 8. Database Considerations

- **Zero DDL in this task.** `public.verification_submissions`, `public.verification_reviews`, `public.verification_audit_trail`, `public.entity_credentials`, `public.entity_professions` (`trade_verification_status` column) all exist (`supabase/migrations/20260821090002_entity_core_tables.sql:120-186`, `supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-225`). No `ALTER`, `CREATE POLICY`, `GRANT`, or trigger added. Full pgTAP `001-017` + EP-02 `018-021` suites must remain green.
- **RLS posture inherited:** RLS enabled on all 5 verification tables (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:237-241`) + default-deny + limited grants + policies `entity_id = auth.uid()`. Authenticated cannot write `verification_submissions.status/reviewed_at/reviewed_by` (excluded columns), cannot `UPDATE` `verification_reviews`, cannot write `entity_professions.trade_verification_status` (grant excludes, `supabase/migrations/20260821090003_entity_model_rls_policies.sql:125-127`). Client verification state is **RPC-or-nothing** (`AGENT.md:16` Rule 4).
- **Execution model respected:** `verification_submit/status_get` granted to `authenticated, service_role`; `review_approve/reject` granted to `service_role` only (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:789-796`) — client cannot invoke admin path (`42501 insufficient privilege`). All RPCs `SECURITY INVOKER`, RLS applies inside function body.
- **One-active-submission invariant:** Partial unique index `credential_id where status in (pending,in_review)` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:159-161`) enforces dedup; client handles `PLT005` as resubmit-after-decision (new credential) UX.
- **No service-role bypass in client.** Adapters never hold `service_role` key; `SupabaseClientProvider.client` uses `anon`/`authenticated` role with RLS. `grep -r "service_role" lib/systems/verification` must be `0`.
- **Trade gate server-authoritative:** `entity_professions.trade_verification_status` is never written client-side. `pending` derived client-side from `verification_submissions` (open question #2 default). `unverified` is DB default. Only `verification_review_approve` (service-role) flips to `approved` and writes `trade_status_propagated` audit (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:466-489`).
- **Audit:** `verification_audit_trail` `submission_created|review_approved|trade_status_propagated` is written server-side by RPCs; client never inserts audit rows directly.

If applicable — no migrations produced; regression only.

## 9. API Requirements

### 9.1 Supabase RPC (via `SupabaseTradeVerificationRemoteDataSource`)

| Operation | RPC | Params | Auth | Success Envelope | Error → ApiExceptionKind |
|---|---|---|---|---|---|
| Queue trade proof | `verification_submit` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:323`) | `p_credential_id uuid!, p_submission_type='trade_proof'` | `authenticated` | `200 {success:true, code:PLT000, data: verification_submissions}` | `401 PLT001 auth`, `404 PLT004 notFound` (credential not owned), `409 PLT005 conflict` (active dup), `422 PLT003 validation` (bad type) |
| Get aggregate | `verification_status_get` (`592`) | `p_entity_id?` (null = self) | `authenticated` self-scoped | `{kyc, identity_verified, trade_verifications:[{profession_id, trade_verification_status}], pending/total}` | `403 PLT004` (cross-entity) |
| (not invoked by client) | `verification_review_approve/reject` (`412,530`) | `p_submission_id, p_notes?` | `service_role` only | `PLT000` + `trade_status_propagated` audit | `42501 → PLT002 forbidden` (client receives `403` if attempted) |

All `supabase.rpc<Map<String,dynamic>>('verification_*', params: {...})` unwrapped via `EnvelopeParser.unwrapData` (checks `data['success']==true && data['code']=='PLT000'` else throws `ApiException` with extracted `code/message`).

### 9.2 Supabase REST — `entity_credentials` Insert (with profession binding)

`POST /rest/v1/entity_credentials` body `{entity_id, kind, title, document_path, profession_id}` (`supabase/migrations/20260821090002_entity_core_tables.sql:120-150` `kind` allowed, `profession_id` FK). Auth `Bearer <accessToken>` from `SupabaseClientProvider.currentAccessToken`. Error `403 PLT002` if RLS column violation. Client maps via `DataExceptionMapper`.

### 9.3 Supabase Storage REST (via `StorageService`)

| Bucket | Operation | SDK | Auth | Policy |
|---|---|---|---|---|
| `credential-documents` | `uploadBinary(path, bytes, FileOptions(contentType, upsert:false))` | `storage.from('credential-documents')` (`lib/core/storage/supabase_storage_service.dart:155`) | `authenticated` | `credential_documents_insert_owner` (owner prefix) |
| `credential-documents` | `createSignedUrl(path, 60)` (preview) | same | `authenticated` | owner-only SELECT |

No `getPublicUrl` on this bucket — throws `StorageValidationException`.

### 9.4 No Edge / No Payment Gateway

No `lib/integrations/payment_gateways/`; no `public.financial_*`; no webhook HMAC.

### 9.5 Error Contract

Every public method throws only `ApiException` (`api_exception.dart:6-66` kinds) or `StorageException` (subtype `StorageValidationException` maps to `PLT003`) — never raw `Supabase`/`DioException`. `BaseApiService.invoke` normalizes `DioException` via `ApiExceptionMapper.map`.

## 10. User Interface Requirements

**Widgets introduce UI — `AGENT.md:17` Rule 5 applies (all `AppTheme` tokens `documents/Context/VISUAL-IDENTITY.md:176-190`).** Every widget in this task must:

- Source colors from `Theme.of(context).colorScheme` / `AppThemeExtension` (`lib/app/theme/app_colors.dart:16`) — never `Colors.*` or `Color(0xFF...)` inline.
- Source type via `Theme.of(context).textTheme` — never `TextStyle(fontFamily: 'Inter')`.
- Source spacing/radius/elevation via `AppThemeExtension.spacing`/`radiusSm`/`radiusMd`/`elevation` — 8pt grid, cards 16dp, sheets 24dp top.
- Handle 4 states via branded primitives (`HivorrEmptyState`, `HivorrLoadingState`, `HivorrErrorState`, `HivorrSuccessState`) wrapping `HivorrLoader` breathing pulse.

| Screen/Widget | Route | Purpose | Key Elements |
|---|---|---|---|
| `TradeProofUploadScreen` | `GET /verification/trade-proof` | Profession + proof type selection + upload + queue | `AppBar(title: Text('Verify your trade', style: textTheme.titleLarge))`, `ProfessionSelector` (via `TaxonomyEngine` bound professions), `TradeProofTypePicker` (chips), `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` preview, `HivorrButton(variant: primary, isLoading, isExpanded:true)`, `LinearProgressIndicator` for `onProgress`, field errors `colorScheme.error` |
| `TradeVerificationStatusScreen` | `GET /verification/trade/status` | Per-profession status tracking + bid-lock state | `TradeVerificationTimeline` (per profession: `Unverified → Submitted → Pending → Approved/Rejected`), `TradeVerifiedBadge` (icon `Icons.verified` tinted `colorScheme.secondary`), bid-lock panel when `TradeVerificationGate.canBid == false`, `HivorrErrorState` for `rejected` with `decisionNotes` + "Resubmit" |
| `AdminReviewQueueScreen` | `GET /admin/review-queue` | Pending submissions list + approve/reject | Pending `verification_submissions` list (credential/type/profession), "Review" detail, approve/reject with `decisionNotes` via service-role seam. **Simplified for EP-02** — no pagination/filters/bulk/image preview (open question #3 default) |
| `TradeVerificationTimeline` / `TradeVerifiedBadge` | — | Reusable widgets | Dots: `primary` active, `outline` pending, `error` rejected, `successContainer` approved. Connectors `Divider(color: colorScheme.outline)`. Dates `onSurfaceVariant` caption. Badge soft `successContainer` container |

All screens responsive via `ResponsiveScaffold` / `shared/layouts/` — 16dp padding mobile, 24dp web pane.

## 11. User Experience Considerations

- **Per-profession, progressive disclosure:** Because `entity_professions` is M:N (`unique(entity_id, profession_id)`), the gate is per profession. The status screen groups by profession and shows locked (unverified) vs unlocked (approved). Upload screen shows one primary action ("Upload & submit") and guidance "Accepted: JPG, PNG, WebP, PDF up to 10 MB".
- **Fail-fast inline validation:** `StorageValidators.validateForBucket` runs on file pick (before upload) — invalid MIME/size produces inline `HelperText` under picker; `onProgress` progress is deterministic streaming (`supabase_storage_service.dart:112-120` Dio `onSendProgress`), not polling spinner — critical on slow Nigerian 3G.
- **Bid-lock clarity:** When `TradeVerificationGate.canBid == false`, the status screen surfaces a "Bidding is locked until your trade is verified" panel with a CTA to `TradeProofUploadScreen`. This mirrors `AGENT.md:15` Rule 2 and sets the marketplace `EP-03` expectation.
- **Status determinism vs polling optimism:** Because trade verification has no realtime, the status screen **polls** `verification_status_get` every 15s until terminal, with backoff on `timeout/network`. "Pending review — we'll notify you" copy sets expectation; "Refresh" pull-to-refresh calls `provider.refreshStatus()` immediately. Notifications are the push complement, not the source of truth — UI always re-fetches before rendering badge to prevent spoofed local state.
- **Rejection sensitivity:** `rejected` with `decision_notes` renders with empathy (`HivorrErrorState` + warm microcopy) and single "Resubmit" CTA that creates a **new** `entity_credentials` row (not overwriting the reviewed row).
- **Deduplication UX:** `PLT005` surfaces as dialog with "View status" action that navigates to `tradeVerificationStatus`, not retry that would loop.
- **Admin review efficiency (simplified):** Admin queue shows pending first with the exact `verification_review_approve/reject` seam, one-step approve/reject with optional notes — prioritizing the human-approval gate over admin power-features in EP-02.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Server-authoritative gate** `AGENT.md:16` Rule 4 | Client never writes `verification_submissions.status`, `entity_kyc_levels.tier_code`, or `entity_professions.trade_verification_status`. All transitions via RPC (`verification_submit` self, `review_approve/reject` service-role). RLS + limited column grant enforce prefix; attempt to POST `status:approved` returns `403 PLT002`. `grep -r "trade_verification_status" lib/systems/verification` must be read-only display, never assignment. |
| **No anon access** | All verification tables `revoke all from anon` + policies `to authenticated` only. App guards with `RouteGuard`. |
| **Private credential isolation** | `credential-documents public=false` + `credential_documents_*_owner` policies. Service never calls `getPublicUrl` (`supabase_storage_service.dart:264` throws). Preview via `createSignedUrl(60)` — no public link leakage. |
| **Path traversal / prefix escape** | Helpers sanitize `..`, `/`, control chars; `with check (storage.foldername(name))[1]=auth.uid()` blocks writing outside own prefix. |
| **Profession-binding integrity** | `entity_credentials.profession_id` FK + `entity_professions` M:N + `unique(entity_id, profession_id)`. `TaxonomyEngine` validates the binding before upload, preventing cross-profession proof mis-attribution or unbound submissions. |
| **MIME/size DoS** | `StorageValidators.validateForBucket` blocks before SDK; server `file_size_limit` 10485760 is second gate. |
| **PII exposure** | Token via `SupabaseClientProvider.currentAccessToken` never logged; `HivorrLogger` + `PiiRedactor` masks `entityId` to `***last4`, never logs `document_path` full or `decisionNotes` beyond preview length, never bytes. |
| **No `service_role` or secret billing leak** | No `service_role` import in client data/systems; admin review seam is the service-role path but never exposes the `service_role` key — admin UI gated by role. `grep lib/ "service_role"` = 0. |
| **Time-of-check / race** | `verification_submissions_one_active_credential_idx` partial unique prevents two parallel `submit` racing to queue; second gets `PLT005` mapped to `conflict` dialog. |
| **Auth state isolation** | `AppEnvironment` `Development→Staging→Production` drives `ApiConfig` + Supabase URL per `ENV-001..010`; `credential-documents` bucket per environment, no cross-env read. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **Polling cost** | `Timer.periodic(15s)` only while `status in (pending,in_review)` and screen visible (`WidgetsBindingObserver` pauses on background, `AppRouter` `didPush`/`didPop` cancels on navigate). 1 RPC/15s ≈ 240 req/hour peak — `verification_status_get` is `STABLE` and indexed, negligible. Backoff `500ms→8s` on `timeout/network`. |
| **Upload size on 3G** | 10 MiB single-part, no chunking. `onProgress` Dio path streams bytes; `Uint8List` single allocation. |
| **Caching** | `TradeVerificationProvider` memoizes `status` in memory; invalidate via `refreshStatus()` on resume, submit, or notification. No disk persistence of `document_path` beyond credential row. |
| **Public vs private URL** | `getPublicUrl` not used; `createSignedUrl(60)` minimal signing overhead, short TTL prevents CDN caching of sensitive docs. |
| **Validation cost** | `TaxonomyEngine` profession resolution O(log n) + MIME/size map lookup `O(1)` + sanitize `O(n)` filename — microseconds, avoids wasted multipart. |
| **Gate evaluation cost** | `TradeVerificationGate.canBid` is pure list scan O(n) over `trade_verifications` — free to call per screen render. |
| **Tracer overhead** | `PerformanceTracer` span (`trade.proof.submit`) sampled via `MonitoringConfig`, tags `trade.type`, `trade.status`, no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/data/verification/trade_*` + `test/unit/systems/verification/`

Pattern mirrors `EP-02-10` §14.1 + fakes (`test/support/fakes/`) — no live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `trade_verification_remote_data_source_test.dart` | 14 | Mock `SupabaseClient.rpc` via fake: `verification_submit('trade_proof') → {success:true, data:{id, status:pending}}` success; `{success:false, code:PLT005}` → `ApiExceptionKind.conflict`; `verification_status_get → {trade_verifications:[...]}` parse; envelope `success:false` → throws; `401→PLT001 auth`, `404→PLT004`, `409→PLT005`, `500→PLT999` |
| `trade_verification_repository_test.dart` | 20 | Fake `StorageService` + fake remote. Validates `validateForBucket` first (oversize never hits upload spy); path `entityId/submissionId/uuid_name.jpg` regex; `profession_id` present in credential insert; `mimeType` normalized; `verification_submit('trade_proof')` invoked; duplicate `credentialId` surfaces `conflict`; `getStatus` maps `trade_verifications` array |
| `trade_verification_provider_test.dart` | 14 | `ChangeNotifier` with mocked repository: `submitTradeProof` sets `submitState=loading` then `idle`, calls `refreshStatus`; polling `Timer` via `fakeAsync` — 15s ticks until `approved`, cancels on dispose; `maybeNotify` emits `HivorrNotification` on terminal transition; `WidgetsBindingObserver` pause/resume |
| `trade_verification_gate_test.dart` | 8 | Pure logic: `canBid(status, professionId)` returns `true` iff `trade_verification_status == approved`; returns `false` for `unverified/pending/rejected`; correct per-profession lookup with M:N; unknown/absent profession → `false` (locked) |
| `trade_proof_type_test.dart` | 6 | Enum labels, `TradeProofType.fromTitle`, `kind` mapping, extensibility `values.length==5` |
| `trade_verification_mapper_test.dart` | 8 | DTO→entity mapping `pending|approved|rejected|unverified`, `decision_notes ≤5000` truncate, null handling |

Target **≥70 unit assertions**; gate 100%, repository/provider ≥90%.

### 14.2 Widget Suite — `test/widget/systems/verification/trade_*`

| File | Cases (min) | Method |
|---|---|---|
| `trade_proof_upload_screen_test.dart` | 10 | Pump with `Provider<TradeVerificationProvider>` fake + `AppTheme.light`: profession chip + type chip selection highlight `colorScheme.primaryContainer`; file pick mock sets preview; `HivorrButton.isLoading` shows `HivorrLoader`; progress `LinearProgressIndicator` visible; error field shows `colorScheme.error` for oversize; `grep Colors.` assert `0` |
| `trade_verification_status_screen_test.dart` | 12 | Mock `TradeVerificationStatus{pending→timeline 2 active dots, approved→TradeVerifiedBadge + no bid-lock, rejected→HivorrErrorState + decisionNotes + Resubmit, unverified→bid-lock panel + CTA}`; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge`; spacing = `AppThemeExtension.spacing` multiples; `Card` radius 16dp |
| `trade_verification_timeline_test.dart` | 8 | Timeline dot colors `primary/successContainer/error/outline` per status, no hardcoded hex, per-profession rendering |
| `admin_review_queue_screen_test.dart` | 8 | Pending list renders, approve/reject with notes triggers service-role seam (fake), empty state `HivorrEmptyState`, role-gated access |

Widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)`.

### 14.3 Integration (Fake-E2E) — `test/integration/verification/trade_verification_flow_test.dart`

Single integration-compose test without live Supabase: fake `SupabaseStorageClient` + fake `SupabaseClient.rpc` map + real `TradeVerificationRepositoryImpl`. Flow: bind profession → `repo.submitTradeProof(...)` → status `pending` → mock `verification_review_approve` side-effect (inject `TradeVerificationDto{profession_id, trade_verification_status:approved}`) → `provider.refreshStatus()` → `TradeVerificationGate.canBid == true` (bid-lock released). No `supabase start` container needed; live `supabase db test` is the source-of-truth for RLS.

### 14.4 Regression Guard

`flutter analyze` + `flutter test --coverage` (domain ≥80%) + `supabase db test` full suite `001..017` + verification `021_*` green. Lens `grep -r "Colors\.\|Color(0x" lib/systems/verification` = 0, `grep -r "fontFamily" lib/systems/verification` = 0, `grep -r "getPublicUrl" lib/systems/verification` = 0 (private bucket), `grep -r "service_role" lib/` = 0, `git diff --stat supabase/` = 0.

### 14.5 Lens Summary

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` RLS/posture. Add `test/support/fakes/fake_trade_verification_remote_data_source.dart` export.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `lib/data/providers/verification_provider.dart:42`, `supabase/migrations/20260829090003_verification_admin_review_schema.sql:115-816`, `supabase/migrations/20260821090002_entity_core_tables.sql:120-186`, `lib/core/storage/supabase_storage_service.dart:43`, `lib/core/storage/storage_paths.dart`, `lib/workspace/profession_registry/taxonomy_engine.dart:12`, `lib/core/api/services/base_api_service.dart:15`, `lib/app/router/app_router.dart:17`, `lib/app/theme/app_colors.dart:16` | Baseline |
| 2 | Draft `lib/systems/verification/models/trade_proof_type.dart` — `TradeProofType` enum (`certificate/license/workSample/portfolio/other`), labels, `kind` mapping | Vocabulary |
| 3 | Create `lib/data/models/trade_verification_dto.dart` + entities `trade_verification_status.dart`/`trade_verification.dart` — pure Dart | DTOs/entities |
| 4 | Update `lib/data/mappers/verification_mapper.dart` — trade DTO→entity methods | Mappers |
| 5 | Create `lib/data/datasources/remote/trade_verification_remote_data_source.dart` — abstract §5.2 | Contract |
| 6 | Create `lib/data/datasources/remote/supabase_trade_verification_remote_data_source.dart` — `BaseApiService` impl, `verification_submit('trade_proof')` + `verification_status_get` + `EnvelopeParser` + `DataExceptionMapper` | DataSource |
| 7 | Create `lib/data/repositories/trade_verification_repository.dart` — abstract §5.3 | Contract |
| 8 | Create `lib/data/repositories/trade_verification_repository_impl.dart` — validate → `TaxonomyEngine` profession resolve → storage upload (`StoragePaths.credentialDocument`) → credential insert (with `profession_id`) → `remote.submit('trade_proof')`, `getStatus` passthrough | Repo |
| 9 | Create `lib/systems/verification/gate/trade_verification_gate.dart` — `canBid(status, professionId)` pure logic | Gate |
| 10 | Create `lib/systems/verification/services/trade_verification_service.dart` — facade §5.4 (logger + tracer) | Facade |
| 11 | Create `lib/data/providers/trade_verification_provider.dart` — `ChangeNotifier` §5.5 + polling timer + notification `maybeNotify` + `WidgetsBindingObserver` | Provider |
| 12 | Create `lib/systems/verification/widgets/trade_proof_type_picker.dart`, `trade_verification_timeline.dart`, `trade_verified_badge.dart` — tokens `colorScheme`/`textTheme`/`AppThemeExtension` | Widgets |
| 13 | Create `lib/systems/verification/screens/trade_proof_upload_screen.dart` — profession picker + type picker → file → `onProgress` → success | Screen 1 |
| 14 | Create `lib/systems/verification/screens/trade_verification_status_screen.dart` — per-profession timeline + badge + bid-lock panel + error/resubmit, poll lifecycle hooks | Screen 2 |
| 15 | Create admin review queue screen — pending submissions list + approve/reject with notes via service-role seam (simplified EP-02) | Screen 3 |
| 16 | Update `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` — add `/verification/trade-proof`, `/verification/trade/status`, `/admin/review-queue` guarded by `RouteGuard` | Routes |
| 17 | Update barrels `lib/systems/verification/verification.dart`, `lib/data/data_layer.dart` | Barrels |
| 18 | Create `test/support/fakes/fake_trade_verification_remote_data_source.dart` — canned envelopes with spy capture | Fake |
| 19 | Create `test/unit/data/verification/trade_verification_remote_data_source_test.dart` (14) + `trade_verification_repository_test.dart` (20) + `trade_verification_provider_test.dart` (14) | Tests 1 |
| 20 | Create `test/unit/systems/verification/trade_verification_gate_test.dart` (8) + `trade_proof_type_test.dart` (6) + `trade_verification_mapper_test.dart` (8) | Tests 2 |
| 21 | Create `test/widget/systems/verification/trade_proof_upload_screen_test.dart` (10) + `trade_verification_status_screen_test.dart` (12) + `trade_verification_timeline_test.dart` (8) + `admin_review_queue_screen_test.dart` (8) | Tests 3 |
| 22 | Create `test/integration/verification/trade_verification_flow_test.dart` (fake-E2E bind→submit→pending→mockApprove→canBid==true) | Tests 4 |
| 23 | `flutter analyze` + `flutter test --coverage` (≥70 asserts green, domain ≥80%, widgets theme assert) | Verify |
| 24 | Regression: `supabase db test` full suite green + `grep Colors.|Color(0x / fontFamily / getPublicUrl / service_role / trade_verification_status assignment` = 0 + `git diff --stat supabase/` = 0 | Regression |
| 25 | Doc pass: dartdoc on `TradeProofType`, `TradeVerificationRepository.submitTradeProof`, `TradeVerificationGate.canBid`, `VISUAL-IDENTITY` guidance, PII note | Docs |
| 26 | Tag `EP-03` (marketplace bid-lock) + downstream unblocked in phase plan | Handoff |

## 16. Expected Outcome

- `lib/systems/verification/` + `lib/data/` provide a **server-authoritative, provider-agnostic trade verification seam** — screens depend only on `TradeVerificationProvider`/`TradeVerificationService`, never `SupabaseClient.rpc` literals or `storage.from` strings (`ARCHITECTURE.md:101-110` compliant).
- Per-profession trade proofs validate before network (`10 MiB`, `jpeg/png/webp/pdf`, `StorageValidators`), upload to private `credential-documents` (`StoragePaths.credentialDocument` `{entityId}/{submissionId}/{uuid}_sanitized`), create `entity_credentials` with `profession_id` binding (`supabase/migrations/20260821090002_entity_core_tables.sql:120-150`), and queue `verification_submit('trade_proof')` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:323`) — duplicate active `credential_id` returns `conflict PLT005` dialog.
- `TradeVerificationGate.canBid(status, professionId)` (`AGENT.md:15` Rule 2) is a pure, unit-tested function returning `true` only for `approved` — mirrored client-side on the status screen (bid-lock panel) and enforced server-side by marketplace `EP-03`.
- Status tracking polls `verification_status_get` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:592`) with 15s + backoff and renders per-profession `TradeVerificationTimeline` (`unverified → pending → approved/rejected`) + `TradeVerifiedBadge` without `supabase_realtime` (excluded).
- Admin review queue (simplified) lists pending submissions and invokes the `verification_review_approve/reject` service-role seam with `decisionNotes`; `verification_review_approve` flips `entity_professions.trade_verification_status` to `approved` and writes `trade_status_propagated` audit (existing server behavior `supabase/migrations/20260829090003_verification_admin_review_schema.sql:466-489`) — bid-lock released.
- Notification hook emits `HivorrNotification` on terminal transitions (`approved`/`rejected`) via provider channel — future Edge push can replace without screen changes.
- Unit+widget+integration suite ≥70 asserts green with fakes; `flutter analyze` clean; full pgTAP `001..017` + verification `021_*` green; `grep` proves no `Colors.*`, no `fontFamily`, no `getPublicUrl` misuse, no `service_role` leakage, no `trade_verification_status` client assignment, no `supabase/` drift.
- Marketplace `EP-03` bid-lock (server-side) is unblocked — verified professional can bid on approved professions per `AGENT.md:15` Rule 2.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/data/datasources/remote/trade_verification_remote_data_source.dart` exists — abstract `submit`, `getStatus` | File inspection |
| 2 | `lib/data/datasources/remote/supabase_trade_verification_remote_data_source.dart` extends `BaseApiService`, uses `supabase.rpc('verification_submit')` with `submission_type='trade_proof'` + `verification_status_get` + envelope parser + `ApiExceptionMapper` | Code review + unit test |
| 3 | DTOs `trade_verification_dto.dart` + entities `trade_verification_status.dart`/`trade_verification.dart` + `verification_mapper.dart` trade methods map `unverified|pending|approved|rejected` per profession without leaking RPC JSON shape | File + mapper unit test |
| 4 | `lib/systems/verification/models/trade_proof_type.dart` defines `TradeProofType` enum (5 values: `certificate/license/workSample/portfolio/other`, labels, `kind` mapping) — extensible without schema | File inspection |
| 5 | `lib/data/repositories/trade_verification_repository.dart` + `trade_verification_repository_impl.dart` implement `submitTradeProof({TradeProofType, Uint8List, mimeType, fileName, professionId, onProgress})` → `TaxonomyEngine` resolve → `StorageService.upload` (`StorageBuckets.credentialDocuments`, `StoragePaths.credentialDocument`) → `entity_credentials.insert` (with `profession_id`) → `remote.submit('trade_proof')` with `validateForBucket` before network | Code + repo unit test (spy: validation called first, oversize never hits upload, profession_id in insert) |
| 6 | `lib/data/providers/trade_verification_provider.dart` `ChangeNotifier` holds `TradeVerificationStatus`, `AsyncState submitState`, `startPolling/stopPolling` 15s timer, `maybeNotify` on terminal transition, `WidgetsBindingObserver` lifecycle | Unit test (fakeAsync timer + notification diff) |
| 7 | `lib/systems/verification/gate/trade_verification_gate.dart` `canBid(status, professionId)` pure function — `true` iff `approved`, correct per-profession M:N lookup, absent → `false` | Unit test |
| 8 | `lib/systems/verification/services/trade_verification_service.dart` facades repo + `HivorrLogger` redacted + `PerformanceTracer` `trade.proof.submit.duration` | File inspection |
| 9 | `lib/systems/verification/screens/trade_proof_upload_screen.dart` uploads with `onProgress` `LinearProgressIndicator` + `HivorrButton(isLoading)` + `HivorrLoader`, profession + type selectors, uses `credential-documents` private via `StorageService` only | Widget test + `grep getPublicUrl` = 0 |
| 10 | `lib/systems/verification/screens/trade_verification_status_screen.dart` renders per-profession `TradeVerificationTimeline` + `TradeVerifiedBadge` + bid-lock panel when `canBid==false` + `HivorrErrorState` for `rejected` with `decisionNotes`, poll lifecycle + pull-to-refresh | Widget test |
| 11 | Admin review queue screen lists pending submissions + approve/reject with `decisionNotes` via service-role seam (simplified EP-02) | Widget test + code review |
| 12 | All screens/widgets consume `AppTheme` tokens only — `colorScheme.*`, `textTheme.*`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` — no `Colors.*`, no `Color(0xFF…)`, no `fontFamily:` literal | `grep` + widget test token asserts |
| 13 | `lib/app/router/route_paths.dart` + `route_names.dart` + `app_router.dart:17` add `/verification/trade-proof`, `/verification/trade/status`, `/admin/review-queue` guarded by `RouteGuard` (authenticated; admin role for queue) | File + router test |
| 14 | Barrels `lib/systems/verification/verification.dart` and `lib/data/data_layer.dart` re-export all new symbols (no stale `.gitkeep` only) | File inspection |
| 15 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat` shows only `lib/**` + `test/**` + `lib/app/router/**` | `git diff --stat` |
| 16 | No `lib/core/storage/*` changes — `git diff --stat lib/core/storage` = 0 (reuses `SupabaseStorageService`) | `git diff --stat` |
| 17 | No financial/escrow logic — `grep -r "financial_\|escrow\|payout" lib/systems/verification` = 0; no `lib/integrations/payment_gateways/` import | `grep` |
| 18 | No `service_role`/secret leak — `grep -r "service_role\|sk_live\|supabase_secret" lib/` = 0; `SupabaseClientProvider.client` only | `grep` + code review |
| 19 | `entity_professions.trade_verification_status` never assigned by client — `grep -r "trade_verification_status"` in `lib/systems/verification`/`lib/data` shows read-only display only, no DB write | `grep` + code review |
| 20 | Error normalization `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `409→PLT005 conflict`, `5xx→PLT999 server` via `ApiExceptionMapper`; raw `DioException` never propagates | Unit test |
| 21 | `test/unit/data/verification/trade_verification_remote_data_source_test.dart` ≥14 cases green | `flutter test` |
| 22 | `test/unit/data/verification/trade_verification_repository_test.dart` ≥20 cases green | `flutter test` |
| 23 | `test/unit/data/verification/trade_verification_provider_test.dart` ≥14 cases green | `flutter test` |
| 24 | `test/unit/systems/verification/trade_verification_gate_test.dart` ≥8 + `trade_proof_type_test.dart` ≥6 + `trade_verification_mapper_test.dart` ≥8 green | `flutter test` |
| 25 | `test/widget/systems/verification/trade_proof_upload_screen_test.dart` ≥10 + `trade_verification_status_screen_test.dart` ≥12 + `trade_verification_timeline_test.dart` ≥8 + `admin_review_queue_screen_test.dart` ≥8 green | `flutter test` |
| 26 | `test/integration/verification/trade_verification_flow_test.dart` fake-E2E green (bind → submit → pending → mockApprove → `canBid==true`) | `flutter test` |
| 27 | `flutter analyze` / `dart analyze` clean | CI |
| 28 | `flutter test --coverage` domain ≥80%, gate 100%; `supabase db test` full suite `001..021` green | `supabase db test` |
| 29 | Visual-identity enforcement: `grep -r "Colors\.\|Color(0x" lib/systems/verification` = 0, `grep -r "fontFamily" lib/systems/verification` = 0, premium finish (soft elevation, `HivorrEmpty/Loading/Error/SuccessState`, ≥48dp touch, 16dp/24dp padding) | Code review |

---

## 18. Implementation AI Execution Profile

### Recommended Coding Reasoning Level: **Very High**

### Reasoning Level Justification

| Factor | Assessment |
|---|---|
| **Technical complexity** | **Very High** — Per-profession trade proof chain (`TaxonomyEngine` binding → storage → `entity_credentials` with `profession_id` → `verification_submit('trade_proof')` envelope), polling without realtime (`supabase_realtime` excluded `20260829090003:798`), `TradeVerificationGate` pure bid-lock, admin review service-role seam. Not `Extremely High` (no `SECURITY DEFINER`/pgTAP authoring — `EP-02-03` owns that). |
| **Business impact** | **Critical** — Trade verification is the marketplace participation gate (`AGENT.md:15` Rule 2). Failure blocks `EP-03` bid-lock and the trust loop. Trade-proof fraud vector if profession binding/path/MIME bypassed or `trade_verification_status` client-writable. |
| **Security risk** | **Very High** — Private `credential-documents` must never leak via `getPublicUrl`; `entity_professions.trade_verification_status` is service-role-only (`supabase/migrations/20260821090003_entity_model_rls_policies.sql:125-127`); `verification_review_approve/reject` is service-role only (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:792-793`); cross-entity `verification_status_get` must enforce `PLT004`. PII logging via `pii_redactor` is mandatory. |
| **Performance sensitivity** | **Medium** — 15s polling (`STABLE` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:598`) + 10 MiB single-part upload on Nigerian 3G; gate evaluation is O(n) over `trade_verifications`. |
| **Data complexity** | **High** — `verification_submissions` + `entity_credentials` (with `profession_id` FK) + `entity_professions` M:N gate + `trade_verifications` array envelope + DTO↔entity per-profession status, partial unique index semantics, audit `trade_status_propagated`. |
| **Integration complexity** | **Very High** — Injects `SupabaseClientProvider` + `StorageService` + `TaxonomyEngine` (`lib/workspace/profession_registry/taxonomy_engine.dart:12`) + `NotificationProvider` + `ApiConfig.forEnvironment`, must remain swappable for marketplace `EP-03` and future onboarding; reuses `EP-02-10` `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42`). |

The Approved Phase Plan assigns EP-02-11 **Planning: Very High / Coding: Very High** (`EP-02 Trust, Identity & Financial Integrity Engine.md:365` — 1 of 8 `Very High` items, distinct from 6 `Extremely High` financial items). **Very High** is calibrated: `High` would under-index the marketplace-gate, private-storage, and profession-binding invariants; `Extremely High` is reserved for double-entry ledger/escrow (`EP-02-04/14`).

---

> **Decision Log (approved):** Questions resolved and implementation green-lit.
> 1. **Trade proof vocabulary:** **Standard (5 values)** — locked to `certificate / license / workSample / portfolio / other`. `expires_at` capture for licenses **deferred** (no DDL); extensible via enum + label.
> 2. **`trade_verification_status` `pending`:** **Derived client-side** from `verification_submissions` status — no `EP-02-03` amendment, `supabase/migrations/*` remains frozen. `unverified` is the DB default; `pending` computed in the DTO/mapper.
> 3. **Admin review queue:** **Simplified internal screen in EP-02** — pending submissions list + approve/reject with notes via the service-role seam. Advanced pagination/filters/bulk/image-preview deferred.
> 4. **Bid-lock:** **Reuse single `verification_status_get` aggregate** (`trade_verifications` array) — no `verification_can_bid(professionId)` helper RPC; `TradeVerificationGate.canBid(status, professionId)` derives bid-lock client-side, server enforced by `EP-03`.
>
> **Next Step:** Implementation in progress per §15 sequence.
