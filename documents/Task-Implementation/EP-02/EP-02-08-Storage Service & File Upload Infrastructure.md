# Task Implementation Plan — EP-02-08: Storage Service & File Upload Infrastructure

**Task ID:** EP-02-08 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Not Started | **Priority:** High | **Dependencies:** EP-02-06 | **Stage:** 3 — Client-Side Infrastructure

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:324-334` | Architecture: `documents/Context/ARCHITECTURE.md:55-60,119` , `documents/Context/AGENT.md:4-18` | Depends on: `supabase/migrations/20260830100001_storage_buckets.sql:47-83` , `supabase/config.toml:36-48` , `supabase/tests/database/017_storage_posture.sql:1-241` | Existing Core: `lib/core/storage/storage.dart:1-4` , `lib/core/storage/secure_storage.dart:12-116`

---

## 1. Task Objective

Extend `lib/core/storage/` with a Supabase Storage abstraction supporting file upload (with progress tracking), download, deletion, public URL generation, and signed URL generation for private buckets. Implement client-side file type validation, size limit enforcement, and path convention helpers. Integrate exclusively with the three RLS-protected buckets provisioned in EP-02-06 (`credential-documents`, `profile-avatars`, `portfolio-items`) via `supabase_flutter:2.17.2` `SupabaseClient.storage`. Zero new SQL/RPC. Zero `public.*` DDL.

Deliverables:
- Abstract `StorageService` contract + `SupabaseStorageService` implementation in `lib/core/storage/`.
- Bucket-scoped validators, path helpers, and typed exceptions.
- Barrel update `lib/core/storage/storage.dart:1`.
- Unit test suite with in-memory fake storage (no live Supabase required).

## 2. Business Problem Being Solved

EP-02-06 provisioned the server-side storage security gate (3 buckets + 12 `storage.objects` RLS policies `supabase/migrations/20260830100001_storage_buckets.sql:113-204`) and proved posture via `017_storage_posture.sql`. However, no client abstraction exists:

- `lib/core/storage/storage.dart:1` only re-exports `SecureStorage` (`flutter_secure_storage`) — there is no `Supabase Storage` client wrapper. Every trust workflow must directly call `Supabase.instance.client.storage.from(bucket).upload(...)`, leaking bucket names, path conventions, and MIME/size rules into `lib/systems/verification/` and `lib/systems/portfolio/` and violating ARCHITECTURE.md separation (`lib/core/storage/` = secure storage wrappers, `lib/integrations/cloud_storage/` = future S3/Cloudinary adapters).
- Verification workflows (EP-02-10/11: identity docs, trade proofs) require `credential-documents/{entity_id}/{submission_id}/{uuid}.{ext}` uploads (`EP-02:32`) with 10 MiB / `jpeg/png/webp/pdf` enforcement. Without a service, validation is duplicated and bypassable, and progress UX cannot be standardized.
- Onboarding (EP-02-18) avatar upload and professional profile (EP-02-19) portfolio showcase require `profile-avatars` (5 MiB, `jpeg/png/webp`, public read) and `portfolio-items` (10 MiB, public read) with canonical path helpers and `getPublicUrl`/`createSignedUrl` dispatch (private vs public bucket).
- Direct SDK use couples all 5 downstream consumers (EP-02-10/11/17/18/19) to `supabase_flutter` Storage API shape, preventing future provider swap via `lib/integrations/cloud_storage/` (ARCHITECTURE.md:119) without mass refactoring.
- Client-side fail-fast validation (MIME/size/path) is required for UX but must mirror server `storage.buckets.file_size_limit`/`allowed_mime_types` (`supabase/migrations/20260830100001_storage_buckets.sql:51-82`) — single source of truth needed.

This task is the **client-side storage infrastructure seam** — unblocks Stage 4 verification and Stage 7 onboarding/profile per `EP-02:138` (`EP-02-08 → EP-02-06`) and `EP-02:143` (`EP-02-18 → EP-02-08`).

## 3. Scope

| In Scope | Detail |
|---|---|
| `StorageService` abstract contract | `upload`, `uploadBinary` (Uint8List), `download`, `remove`/`delete`, `getPublicUrl`, `createSignedUrl`, `list` (optional prefix listing) |
| `SupabaseStorageService` implementation | Injects `SupabaseClient` via `lib/core/api/supabase/supabase_client_provider.dart:19` for testability; wraps `supabase.storage.from(bucket)` calls; delegates to `invoke`-style error normalization (see `lib/core/api/services/base_api_service.dart:33`) |
| File validation | Per-bucket MIME allowlist + `file_size_limit` enforcement mirroring `storage.buckets` (`credential-documents 10485760`, `profile-avatars 5242880`, `portfolio-items 10485760`); extension ↔ MIME mapping; magic-byte sniff stub for future depth |
| Path convention helpers | `StoragePaths.credentialDocument(entityId, submissionId, filename)`, `avatar(entityId, ext)`, `portfolioItem(entityId, itemId, filename)` — sanitizes filename, enforces `{entityId}/...` prefix matching `storage.foldername(name)[1] = auth.uid()::text` (`supabase/migrations/20260830100001_storage_buckets.sql:118`) |
| Progress tracking | `onProgress: (int sent, int total) => void` callback on upload; documented fallback if `supabase_flutter:2.17.2` `uploadBinary` lacks native progress (use Dio Storage REST endpoint with `onSendProgress` via injected `Dio` from `lib/core/api/api_initializer.dart:60`) |
| Typed errors | `StorageException` / `StorageValidationException` mapping to `lib/core/api/exceptions/api_exception.dart:6-32` kinds (`validation` for PLT003, `auth`/`forbidden` for 401/403, `network`/`timeout` for transport) |
| Bucket config constants | `lib/core/storage/storage_config.dart` single source for bucket IDs, size limits, MIME sets imported by validators + helpers |
| Barrel + DI | Update `lib/core/storage/storage.dart:1` exports; optional `Provider<StorageService>` registration pattern consistent with `provider:6.1.5` (`pubspec.yaml:50`) |
| Tests | Unit tests with fake `SupabaseClient`/`StorageClient` (see `test/support/fakes/fake_storage.dart:9` pattern, `test/support/fakes/fake_supabase.dart`); validator + path helper exhaustive tests |
| Logging/monitoring hygiene | Never log file bytes; log only bucket, path prefix, size, mime via `lib/core/logging/` (`pii_redactor.dart`) and `lib/core/monitoring/` |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| SQL migration / bucket creation / RLS policies / `supabase/config.toml` changes | EP-02-06 finalized — `20260830100001_storage_buckets.sql`, `supabase/config.toml:36-48`, `017_storage_posture.sql` are frozen; this task touches `lib/` only |
| `lib/integrations/cloud_storage/` S3/Cloudinary adapters | ARCHITECTURE.md:119 future provider abstraction; this task proves the `lib/core/storage/` seam |
| Edge Functions for thumbnailing, virus scanning, image transform, signed-URL minting | No EP-02 requirement; deferred |
| `public.*` tables, RPCs, realtime, financial/verification/dispute schemas | EP-02-03/04/05 domain — not modified |
| UI widgets/screens (onboarding, verification upload screens, portfolio grid) | EP-02-10/11/18/19 own presentation; this task provides the service they consume |
| Offline Sync queue integration for deferred uploads | `lib/core/sync/` owns action queue (EP-01-12); uploads are online-only in EP-02-08; queuing noted as future extension |
| Chunked/resumable upload for >10 MiB files | Size limits cap at 10 MiB; single-part upload sufficient; deferred to future large-file support |
| CDN configuration beyond `public` flag | ENV-009 concern — bucket `public` already determines CDN (`supabase/migrations/20260830100001_storage_buckets.sql:52-77`) |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/core/storage/` vs `lib/integrations/cloud_storage/`

ARCHITECTURE.md:55-60 assigns `lib/core/storage/` = secure storage wrappers (currently `SecureStorage`/`SecureTokenStore`/`SupabaseSecureLocalStorage`) and ARCHITECTURE.md:119 assigns `lib/integrations/cloud_storage/` = S3/Cloudinary adapters. `supabase_flutter` Storage is the platform's primary object store (like Auth/Postgres) — it belongs in `lib/core/storage/` (same layer as `SupabaseClientProvider`), not `integrations/`. EP-02-06 TIP §5.5 confirms storage is accessed via `SupabaseClient.storage` not RPC. This preserves `integrations/cloud_storage/` for true third-party swaps without churn in `systems/verification/` and `systems/portfolio/`.

### 5.2 Interface-First Design — Abstract `StorageService`

Mirror `lib/core/storage/secure_storage.dart:12` pattern (abstract contract + impl separate):

```dart
// lib/core/storage/storage_service.dart
abstract class StorageService {
  Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
    void Function(int sent, int total)? onProgress,
    bool upsert = false, // true for profile-avatars canonical overwrite
  });
  Future<Uint8List> download({required String bucket, required String path});
  Future<void> remove({required String bucket, required List<String> paths});
  String getPublicUrl({required String bucket, required String path});
  Future<String> createSignedUrl({required String bucket, required String path, required int expiresInSeconds});
  Future<List<FileObject>> list({required String bucket, required String path, int limit = 100});
  // Validators exposed for UX fail-fast without network
  void validateForBucket({required String bucket, required String mimeType, required int byteLength});
}
```

- Accepts `Uint8List + mimeType + fileName` (platform-agnostic) — avoids `dart:io File` on Web; callers provide `XFile.readAsBytes()` upstream.
- Returns server path (storage key) on `upload` for persistence in `entity_credentials.document_path` / `dispute_evidence.file_url`.
- Injected `SupabaseClient` (constructor) enables fake injection; alternative constructor `StorageService.supabase(SupabaseClient)` + `SupabaseClientProvider.client` default for production (see `lib/core/api/supabase/supabase_client_provider.dart:19` safe accessor that fails closed with `ApiInitializationException`).

### 5.3 Implementation — `SupabaseStorageService`

`lib/core/storage/supabase_storage_service.dart`:

1. **Bucket allowlist** — constructor asserts `bucket ∈ {credential-documents, profile-avatars, portfolio-items}` (constants from `storage_config.dart`). Any other bucket throws `StorageValidationException` (prevents typo leakage).
2. **Validation first** — `validateForBucket` called before network: checks `byteLength <= file_size_limit` (10485760 / 5242880) and `mimeType ∈ allowed_mime_types` (same arrays as `supabase/migrations/20260830100001_storage_buckets.sql:54,65,76`). Extension-to-MIME map normalizes `fileName` extension vs `mimeType` mismatches. Validation maps to `ApiExceptionKind.validation` (`PLT003`).
3. **Path sanitization** — `StoragePaths` helpers strip `..`, `/`, whitespace, enforce lower-case, URL-safe, UUID filename retention; reject paths not starting with `{auth.uid()}/`. Prevents prefix-escape even though server RLS (`storage.foldername(name)[1] = auth.uid()::text`) is authoritative.
4. **SDK dispatch** — `supabase.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType, upsert: upsert))` for upload; `.download(path)` for private `credential-documents`; `.getPublicUrl(path)` for `profile-avatars`/`portfolio-items`; `.createSignedUrl(path, expiresIn)` for `credential-documents` preview (60–300s TTL documented for EP-02-10). `remove` via `.remove(paths)`.
5. **Progress** — Investigate `supabase_flutter:2.17.2` Storage API: if `uploadBinary` lacks `onProgress`, implement alternative path: use injected `Dio` (`lib/core/api/api_initializer.dart:60` `ApiLayer.dio`) to `POST /storage/v1/object/{bucket}/{path}` with `Authorization: Bearer ${supabase.auth.currentSession?.accessToken}` and `onSendProgress`. Document chosen path in class doc; expose uniform `onProgress` callback regardless. No polling hack.
6. **Error normalization** — Catch `StorageException` (Supabase) + `DioException`; map via `lib/core/api/exceptions/api_exception_mapper.dart:15` pattern into typed `ApiException` / `StorageException`: 401→`auth` PLT001, 403→`forbidden` PLT002 (RLS prefix violation surfaces as 403), 400/422→`validation` PLT003 (MIME/size), 404→`notFound` PLT004, 409→`conflict`, 5xx→`server` PLT999. Preserve `statusCode`, `code`, `message` without leaking stack/SQL.
7. **Upsert semantics** — `profile-avatars/{entityId}/avatar.{ext}` uses `upsert:true` (canonical single avatar, per `supabase/migrations/20260830100001_storage_buckets.sql:31` comment). `credential-documents` and `portfolio-items` use `upsert:false` (unique per submission/item).

### 5.4 Configuration — `lib/core/storage/storage_config.dart`

Single source of truth mirroring server bucket catalog; imported by service + validators + helpers; no duplication:

```dart
abstract class StorageBuckets { static const credentialDocuments='credential-documents'; ... }
abstract class StorageLimits { static const credentialDocuments=10485760; static const profileAvatars=5242880; ... }
abstract class StorageMimeTypes { static const credentialDocuments={'image/jpeg','image/png','image/webp','application/pdf'}; ... }
```

Enables `supabase/config.toml:36-48` drift detection via test asserting constants equal migration values.

### 5.5 Exceptions — `lib/core/storage/storage_exceptions.dart`

```dart
class StorageException implements Exception { final ApiExceptionKind kind; final String message; final String? code; final int? statusCode; }
class StorageValidationException extends StorageException { /* PLT003 */ }
class StorageAuthException extends StorageException { /* PLT001/002 */ }
```

Consumers handle `StorageValidationException` for form UX vs `StorageException` for retry/toast. Never embed raw SDK messages containing SQL/path internals.

### 5.6 Path Helpers — `lib/core/storage/storage_paths.dart`

Pure functions, no SDK dependency (testable in isolation):
- `credentialDocument({required String entityId, required String submissionId, required String fileName}) => '$entityId/$submissionId/${Uuid.v4()}_${sanitize(fileName)}'`
- `avatar({required String entityId, required String ext}) => '$entityId/avatar.$ext'` (lowercased ext)
- `portfolioItem({required String entityId, required String itemId, required String fileName}) => '$entityId/$itemId/${sanitize(fileName)}'`

All helpers call `sanitize` (remove `..`, `/`, control chars, truncate to 180 chars, enforce `a-z0-9._-`). Documented as client-side complement to server `WITH CHECK` `storage.foldername(name)[1]=auth.uid()`.

### 5.7 Logging / Monitoring / PII

- Use `lib/core/logging/hivorr_logger.dart` + `lib/core/logging/pii_redactor.dart` — log `bucket`, `pathPrefix` (entityId redacted to `***`), `byteLength`, `mimeType`; never log bytes or full path.
- `lib/core/monitoring/monitoring_service.dart` span around `upload`/`download` with `performance_tracer.dart` — record `storage.upload.duration`, `storage.download.duration`, `storage.error.kind` tags (no PII).

### 5.8 Dependency Wiring

- Production: `StorageService service = SupabaseStorageService(supabase: SupabaseClientProvider.client, dio: ApiLayer.dio)` initialized where `ApiInitializer.initializeApi` has run (same guard as `lib/core/api/supabase/supabase_client_provider.dart:21`).
- Tests: inject `FakeSupabaseClient` / in-memory `StorageFake` (new `test/support/fakes/fake_supabase_storage.dart` alongside `test/support/fakes/fake_storage.dart:9`).
- Provider registration (optional, for downstream screens): `Provider<StorageService>.value(value: service)` — consistent with `provider:6.1.5` (`pubspec.yaml:50`); no `Riverpod` introduction.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `StorageService` abstract | `lib/core/storage/storage_service.dart` | **Create** — contract (§5.2) |
| `SupabaseStorageService` | `lib/core/storage/supabase_storage_service.dart` | **Create** — impl (§5.3) |
| `StorageConfig` (bucket/limit/MIME constants) | `lib/core/storage/storage_config.dart` | **Create** |
| `StorageExceptions` | `lib/core/storage/storage_exceptions.dart` | **Create** |
| `StoragePaths` helpers | `lib/core/storage/storage_paths.dart` | **Create** |
| `StorageValidators` | `lib/core/storage/storage_validators.dart` | **Create** — pure MIME/size/extension validators |
| Barrel | `lib/core/storage/storage.dart` | **Update** — export new symbols (`storage.dart:1` currently only `secure_storage.dart`) |
| Fake storage for tests | `test/support/fakes/fake_supabase_storage.dart` | **Create** — in-memory bucket→path→bytes map, fake `StorageClient.from(bucket)` |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — EP-02-06 frozen |
| No `supabase/config.toml` | `supabase/config.toml` | **No change** — already declares 3 buckets |
| No `lib/integrations/cloud_storage/` | `lib/integrations/cloud_storage/` | **No change** — empty per `ARCHITECTURE.md:119` |

**No new `public.*` tables, no RPCs, no Edge Functions, no `lib/systems/*` widgets in this task — pure `lib/core/storage/` extension.**

## 7. Data Requirements

### 7.1 Bucket Catalogue (mirrors `storage.buckets`)

| Bucket | public | file_size_limit | allowed_mime_types | Access Model |
|---|---|---|---|---|
| `credential-documents` | false | 10485760 (10 MiB) | `image/jpeg, image/png, image/webp, application/pdf` | Private — `authenticated` owner-only SELECT/INSERT/UPDATE/DELETE; no `anon`; `service_role` bypass |
| `profile-avatars` | true | 5242880 (5 MiB) | `image/jpeg, image/png, image/webp` | Public read (`anon, authenticated` SELECT), owner write/delete |
| `portfolio-items` | true | 10485760 (10 MiB) | `image/jpeg, image/png, image/webp, application/pdf` | Public read, owner write/delete |

Constants must equal `supabase/migrations/20260830100001_storage_buckets.sql:51-82` and `supabase/config.toml:36-48`; test asserts equality to prevent drift.

### 7.2 File Payload Shape

Client payload is `Uint8List bytes + String mimeType + String fileName + String bucket + String path`. No `dart:io File` dependency for Web compatibility. Size = `bytes.lengthInBytes`. MIME validated before network; extension validated via `fileName` fallback. No persistence of upload metadata beyond returned storage path string (upstream maps to `entity_credentials.document_path`, `dispute_evidence.file_url`, `entity_profiles.avatar_url`).

### 7.3 Path Vocabulary

- `credential-documents/{entity_id}/{submission_id}/{uuid}_{sanitized_filename}` — `{entity_id} == auth.uid()::text` (server enforced via `storage.foldername(name)[1]`).
- `profile-avatars/{entity_id}/avatar.{ext}` — canonical single avatar; `upsert:true` overwrite.
- `portfolio-items/{entity_id}/{item_id}/{sanitized_filename}` — multiple per entity.

Paths lower-case, URL-safe, `..`/`/` stripped; helpers produce compliant paths; validators reject non-compliant inputs with `StorageValidationException`.

## 8. Database Considerations

- **Schema boundary:** `storage.objects`/`storage.buckets` live in `storage` schema (Supabase-managed). This task performs zero DDL on `public.*` — no trigger, no RLS, no migration. Regression guard: `supabase/tests/database/017_storage_posture.sql:92-100` RLS-enabled assertion remains green.
- **RLS posture inherited:** `storage.objects` RLS enabled + 12 policies (`supabase/migrations/20260830100001_storage_buckets.sql:96-204`) already enforce owner-scoped writes + `bucket_id` conjunct on every policy. Client service is unprivileged — `service_role` bypass not exposed; `anon` zero write verified in `017_storage_posture.sql:108-117`.
- **No double-entry, no ledger:** Storage is object store, not financial ledger; no transaction atomicity beyond single-object upload atomicity via Storage API.
- **Listing:** `storage.list(path)` is prefix-scanned, paginated (`limit` param) — callers paginate; no DB joins; no N+1 beyond Storage API pagination.
- **Realtime:** `storage` schema not in `supabase_realtime` (`supabase/migrations/20260830100001_storage_buckets.sql:221-232` + `017_storage_posture.sql:200-208`) — no subscription; callers fetch via `getPublicUrl`/`download`/`createSignedUrl`.
- **Idempotency note:** Upload idempotency is via `upsert` flag, not DB `ON CONFLICT` — avatar overwrites, credential/portfolio inserts fail on duplicate path unless `upsert:true` explicitly passed.

## 9. API Requirements

### 9.1 Supabase Storage REST API (via `supabase_flutter` SDK)

All access via `SupabaseClient.storage.from(bucket)` (PostgREST Storage API, not Postgres RPC). Auth via `Authorization: Bearer <accessToken>` from `SupabaseClientProvider.currentAccessToken` (`lib/core/api/supabase/supabase_client_provider.dart:29`).

| Operation | SDK Call | Auth | Policy Gate | Notes |
|---|---|---|---|---|
| Upload (credential) | `from('credential-documents').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false))` | `authenticated` | `credential_documents_insert_owner` + `file_size_limit`/`allowed_mime_types` | `onProgress` via Dio fallback if SDK lacks it |
| Upload (avatar) | `from('profile-avatars').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: true))` | `authenticated` | `profile_avatars_insert_owner` | Canonical path `avatar.{ext}` |
| Upload (portfolio) | `from('portfolio-items').uploadBinary(...)` | `authenticated` | `portfolio_items_insert_owner` | |
| Download (credential) | `from('credential-documents').download(path)` | `authenticated` | `credential_documents_select_owner` | Private — `createSignedUrl` preferred for preview (60s TTL) |
| Delete | `from(bucket).remove([path1, path2])` | `authenticated` | `*_delete_owner` | Owner prefix check |
| Get public URL | `from('profile-avatars').getPublicUrl(path)` / `from('portfolio-items').getPublicUrl(path)` | `anon`/`authenticated` | `*_select_public` | No token; CDN cacheable |
| Create signed URL | `from('credential-documents').createSignedUrl(path, 60)` | `authenticated` | `credential_documents_select_owner` | Short TTL; no public leakage |
| List | `from(bucket).list(path: prefix)` | `authenticated` | `*_select_*` | Paginated |

### 9.2 No RPC / No Edge Function

No `public.*` RPC created. Do not create `storage_*` RPC wrappers — service encapsulates SDK per `EP-02-06:175`. Webhook/Edge for thumbnails/virus scan deferred.

### 9.3 Error Contract

Service surfaces `ApiExceptionKind`-aligned errors (HTTP status from Storage API → `PLT001`/`PLT002`/`PLT003`/`PLT004`/`PLT999` per `lib/core/api/exceptions/api_exception_mapper.dart:31-82`). Callers receive safe `message` (never raw SDK HTML/SQL), `code`, `statusCode`.

## 10. User Interface Requirements

**None.** This task produces no widgets, screens, or design tokens. All EP-02 UI that consumes this service (EP-02-10/11/18/19) must consume `AppTheme` tokens per `documents/Context/AGENT.md:5` (`VISUAL-IDENTITY.md`) — but no UI is introduced here, so no token consumption and no `shared/widgets/` changes. This matches EP-02-06 TIP §10 pattern.

## 11. User Experience Considerations

While server-side validation is authoritative (`storage.buckets.file_size_limit`/`allowed_mime_types` + `storage.objects` RLS), this service shapes downstream UX consumed in EP-02-10/11/18/19:

- **Fail-fast client validation:** MIME/size violation throws `StorageValidationException` with field-level message before network round-trip, enabling inline form error (e.g., “PDF or image up to 10 MB”) rather than opaque `PLT003` after upload.
- **Progress feedback:** `onProgress(sent,total)` enables `HivorrLoader` + linear indicator in upstream screens; avatar/portfolio uploads show determinate progress on slow Nigerian networks. If progress falls back to Dio `onSendProgress`, fidelity is byte-accurate; if SDK simulate, document indeterminate mode.
- **Public vs private URL semantics:** `getPublicUrl` for `profile-avatars`/`portfolio-items` yields SEO-friendly, no-auth `<img src>` for `/p/:profession_slug/:entity_id` (ARCHITECTURE.md:150) without token refresh. `createSignedUrl` for `credential-documents` yields short-lived preview (60s) — no public link leakage. Service docs call out which method per bucket to prevent credential exposure via `getPublicUrl` misuse.
- **Idempotent avatar overwrite:** `upsert:true` on `profile-avatars/{entity_id}/avatar` prevents stale duplicates; upstream cache invalidation appends `?t=DateTime.now().millisecondsSinceEpoch` to `getPublicUrl`.
- **Clear error recovery:** 403 (RLS prefix violation) → “You can only upload to your own folder.” 413/size → “File too large — max 5 MB for avatars.” Timeout/network → retry affordance via upstream retry button (service does not auto-retry uploads to avoid duplicate objects).

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Private credential isolation | `credential-documents` `public=false` (`supabase/config.toml:37`) + `credential_documents_select_owner` owner-only SELECT (`supabase/migrations/20260830100001_storage_buckets.sql:113`). Service never calls `getPublicUrl` on this bucket; only `download`/`createSignedUrl`. Test asserts `credential-documents` MIME/size via `017_storage_posture.sql:60-80`. |
| Cross-bucket leakage | Every `storage.objects` policy carries `bucket_id='<bucket>'` conjunct (`supabase/migrations/20260830100001_storage_buckets.sql:116,124,135,143`). Service allowlists buckets; test validates via `017_storage_posture.sql:189-198` `bucket_id` conjunct count. |
| Path traversal / prefix escape | Helpers sanitize `..`/`/`/control chars; validators reject `../` or absolute paths; `WITH CHECK (storage.foldername(name))[1]=auth.uid()` blocks writing outside own prefix even if sanitization fails. Service test covers `evil-entity-id/` attempt (like `017_storage_posture.sql:210-237` leakage simulation). |
| MIME spoofing | Client extension→MIME map + `fileName` sanitization is UX only; server `storage.buckets.allowed_mime_types` is authoritative. Client rejects `application/x-msdownload`, `text/html` before network. Future: magic-byte sniff in `storage_validators.dart`. |
| Size DoS / cost blow-up | Client `StorageValidators.validateSize(bucket, byteLength)` blocks before SDK call (5242880/10485760). Server `file_size_limit` is second gate. Service test asserts oversized `Uint8List` throws before fake SDK invoked. |
| Anon write DoS | No policy grants `anon` INSERT/UPDATE/DELETE (`017_storage_posture.sql:108-117`); service requires `authenticated` — unauthenticated call fails closed via `SupabaseClientProvider.client` guard (`lib/core/api/supabase/supabase_client_provider.dart:21` throws `ApiInitializationException`). |
| Auth token exposure | Token retrieved via `SupabaseClientProvider.currentAccessToken` / `Supabase.instance.client.auth.currentSession` — never logged, never embedded in URL for private bucket (signed URL is server-minted HMAC, short TTL). PII redaction via `lib/core/logging/pii_redactor.dart`. |
| No `public.*` grant drift | No `GRANT` on `public.*`; `GRANT` on `storage.*` not needed (RLS via API roles). Full suite `001–017` regression (`017_storage_posture.sql:166-172` `storage_%` SECURITY DEFINER =0) must stay green. |
| SQL injection | No dynamic SQL; bucket names are constants; paths are parameterized SDK calls, not interpolated SQL. |
| Secret exposure | No keys in validators/paths; no hardcoded `service_role` key. ENV isolation per ENV-002/008 — buckets per environment via migration, service uses active `EnvironmentConfig` (`lib/config/environments/environment_config.dart`). |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Public bucket CDN | `profile-avatars`/`portfolio-items` `public=true` enables Supabase CDN + browser `Cache-Control` via `getPublicUrl`; no `Authorization` header overhead on reads; suitable for public profile `/p/:profession_slug/:entity_id`. |
| Private signed URL TTL | `createSignedUrl(60)` minimal signing overhead; short TTL prevents CDN caching of sensitive docs; acceptable for admin review preview. |
| Pre-network validation | MIME/size check is O(1) map lookup + int compare — microseconds; avoids wasted multipart upload on slow networks. |
| Memory for 10 MiB payloads | `Uint8List` single allocation; acceptable on mobile (10 MiB < Dart heap budget); document streaming alternative for future >10 MiB. Avoid double-copy (do not base64). On Web, `Uint8List` from `XFile` is already in memory — no extra copy. |
| No chunked upload | 5–10 MiB limits keep multipart single-part; no resumable protocol needed. Progress via `onSendProgress` streaming upload bytes, not polling. |
| Policy evaluation cost | Not client concern — server `storage.foldername(name)[1]` indexed (`storage.objects.name` trigram). Client path sanitization is O(n) on filename (<255 chars). |
| Caching `getPublicUrl` | Public URL is deterministic (`/storage/v1/object/public/{bucket}/{path}`) — callers can memoize; service `getPublicUrl` is sync string concat, no network. |
| Tracer overhead | `PerformanceTracer` span lightweight; sampling via `MonitoringConfig` (`lib/core/monitoring/performance_tracer.dart`). |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/core/storage/`

Pattern mirrors `test/support/fakes/fake_storage.dart:9` (`InMemorySecureStorage`) + `test/unit/core/api/api_exception_mapper_test.dart`. No live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `storage_validators_test.dart` | 18 | `credential-documents` accept `jpeg/png/webp/pdf` up to 10485760, reject `text/html`, `application/octet-stream`, oversize +1 byte; `profile-avatars` accept `jpeg/png/webp` only (pdf rejected), 5242880 cap; `portfolio-items` accept pdf; case-insensitive MIME; boundary 0 bytes; `validateForBucket` throws `StorageValidationException` with `kind==validation`/`code==PLT003` |
| `storage_paths_test.dart` | 16 | `credentialDocument` formats `entityId/submissionId/uuid_filename`, sanitizes `..`, `/`, spaces, upper-case ext, control chars, truncates >180 chars; `avatar` lowercases ext, rejects empty entityId; `portfolioItem` similar; traversal payload `../../etc/passwd` sanitized to single segment |
| `supabase_storage_service_test.dart` | 28 | Fake `SupabaseStorageClient` injected: `upload` success returns path, calls `validateForBucket` first (oversize never hits fake); `upload` with wrong bucket throws; `avatar` upsert flag true; `credential-documents` `getPublicUrl` throws (must use `createSignedUrl`); public buckets `getPublicUrl` returns `.../object/public/...`; `download` private succeeds, anon fails; `remove` owner prefix; `createSignedUrl` returns HMAC url; `onProgress` callback invoked (Dio fallback path mocked); error mapping: fake throws `StorageException(status 403)` → `ApiExceptionKind.forbidden` PLT002, 401→auth, 413→validation, 5xx→server; unauthenticated `SupabaseClientProvider` guard → `ApiInitializationException`; byte-level `Uint8List` payload integrity |

Target **≥60 unit assertions**; coverage of validators/paths 100%, service branches ≥90%.

### 14.2 Fake — `test/support/fakes/fake_supabase_storage.dart`

Extends `test/support/fakes/fake_supabase.dart` pattern: `FakeSupabaseStorage` with `Map<String, Map<String, Uint8List>> buckets` (bucket→path→bytes), `Map<String,String> contentTypes`, `from(bucket)` returns `FakeStorageFileApi` implementing `uploadBinary`, `download`, `remove`, `getPublicUrl`, `createSignedUrl`, `list`. Enforces fake limits/MIME if desired (optional strict mode). Records calls for spy assertions (e.g., `capturedUpsert` flag).

### 14.3 Contract Parity Assertion

Single test asserts `StorageConfig` constants equal live-equivalent values from EP-02-06: `StorageBuckets.credentialDocuments == 'credential-documents'`, `StorageLimits.profileAvatars == 5242880`, `StorageMimeTypes.credentialDocuments.contains('application/pdf')` — mirrors `017_storage_posture.sql:60-90` bucket config checks to catch drift if migration amended.

### 14.4 No Storage API E2E in This Task

Live `supabase start` container E2E (upload/download via real `supabase_flutter`) is deferred to EP-02-10/11/18 integration tests that compose this service with real Storage API; EP-02-08 unit suite is sufficient posture gate. Full suite `flutter test` + `supabase db test` (`001–017`) must remain green — no `storage_%` SECURITY DEFINER drift (`017_storage_posture.sql:166-172`).

### 14.5 Lens Summary (for review tooling)

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` RLS/posture. Add `test/support/support.dart` export for fake.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `lib/core/storage/` (current barrel `storage.dart:1`, `secure_storage.dart:12`), `supabase/migrations/20260830100001_storage_buckets.sql:47-83`, `supabase/config.toml:36-48`, `lib/core/api/supabase/supabase_client_provider.dart:19` | Baseline |
| 2 | Draft `lib/core/storage/storage_config.dart` — bucket IDs, `file_size_limit` bytes, MIME sets (mirror migration/config values) | Config |
| 3 | Create `lib/core/storage/storage_exceptions.dart` — `StorageException` hierarchy mapping to `ApiExceptionKind` | Errors |
| 4 | Create `lib/core/storage/storage_validators.dart` — `validateMime`, `validateSize`, `validateForBucket`, extension↔MIME map | Validators |
| 5 | Create `lib/core/storage/storage_paths.dart` — `sanitize`, `credentialDocument`, `avatar`, `portfolioItem` + doc on server `foldername` gate | Paths |
| 6 | Create `lib/core/storage/storage_service.dart` — abstract contract (§5.2), `upload`/`download`/`remove`/`getPublicUrl`/`createSignedUrl`/`list`/`validateForBucket` | Contract |
| 7 | Create `lib/core/storage/supabase_storage_service.dart` — injection (`SupabaseClient`, `Dio`), allowlist, validate-first, sanitize, SDK dispatch, progress fallback, error normalization via `ApiExceptionMapper` | Impl |
| 8 | Update `lib/core/storage/storage.dart:1` barrel exports (re-export `storage_service.dart`, `supabase_storage_service.dart`, `storage_config.dart`, `storage_exceptions.dart`, `storage_paths.dart`, `storage_validators.dart`) | Barrel |
| 9 | Create `test/support/fakes/fake_supabase_storage.dart` (in-memory buckets, spy capture) | Fake |
| 10 | Create `test/unit/core/storage/storage_validators_test.dart` (18 cases) | Tests 1 |
| 11 | Create `test/unit/core/storage/storage_paths_test.dart` (16 cases) | Tests 2 |
| 12 | Create `test/unit/core/storage/supabase_storage_service_test.dart` (28 cases) | Tests 3 |
| 13 | `flutter analyze` + `flutter test --coverage` (unit suite green, no violations) | Verify |
| 14 | `supabase db test` full suite `001–017` green (no regression) | Regression |
| 15 | Doc pass: service dartdoc on progress fallback decision, bucket public/private guidance, PII note | Docs |
| 16 | Tag EP-02-10/11/18/19 unblocked in phase plan | Handoff |

## 16. Expected Outcome

- `lib/core/storage/` provides a provider-agnostic (interface-first) StorageService ready for `lib/systems/verification/` (EP-02-10/11), `lib/systems/portfolio/` (EP-02-19), and `lib/systems/support/` (dispute evidence) without direct `Supabase.instance.client.storage` coupling.
- Bucket-scoped validation (5242880/10485760, MIME sets) mirrors server `storage.buckets` (`supabase/migrations/20260830100001_storage_buckets.sql:54-76`) — oversized/invalid-type files rejected client-side before network, with `PLT003`-aligned messages.
- Path helpers produce `storage.foldername(name)[1]=auth.uid()`-compliant paths (`entity_id/...` prefix) for all three buckets, documented for downstream consumers.
- `upload` supports `onProgress` (Dio `onSendProgress` if SDK lacks it), `download`/`remove` are owner-scoped, `getPublicUrl` only for `profile-avatars`/`portfolio-items`, `createSignedUrl(60-300s)` for `credential-documents` — no credential leakage via public URL.
- Typed errors (`StorageValidationException`/`StorageException`) map to `ApiExceptionKind` (`PLT001`/`PLT002`/`PLT003`/`PLT004`/`PLT999`) without leaking SDK internals.
- Unit suite ≥60 assertions green with in-memory fake; `flutter analyze` clean; full pgTAP suite `001–017` green.
- EP-02-07/10/11/17/18/19 unblocked — storage client seam is the last Stage 3 dependency.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/core/storage/storage_service.dart` exists with abstract contract (`upload`, `download`, `remove`, `getPublicUrl`, `createSignedUrl`, `list`, `validateForBucket`) | File inspection |
| 2 | `lib/core/storage/supabase_storage_service.dart` exists, injects `SupabaseClient` (+ optional `Dio` for progress), allowlists 3 buckets (`credential-documents`, `profile-avatars`, `portfolio-items`) | File inspection + grep `StorageBuckets` |
| 3 | `lib/core/storage/storage_config.dart` declares bucket IDs, limits (10485760/5242880/10485760), MIME allowlists exactly matching `supabase/migrations/20260830100001_storage_buckets.sql:51-82` and `supabase/config.toml:36-48` | Code review + parity test |
| 4 | `lib/core/storage/storage_exceptions.dart` defines `StorageException` hierarchy mapping to `ApiExceptionKind` (`validation` PLT003, `auth` PLT001, `forbidden` PLT002) | File inspection |
| 5 | `lib/core/storage/storage_paths.dart` defines pure `credentialDocument`, `avatar`, `portfolioItem` + `sanitize` (strips `..`/`/`/control chars) | File + unit test |
| 6 | `lib/core/storage/storage_validators.dart` validates per-bucket MIME/size before network (credential 10 MiB + 4 MIMEs, avatar 5 MiB + 3 MIMEs, portfolio 10 MiB + 4 MIMEs) | Unit test |
| 7 | `lib/core/storage/storage.dart:1` barrel re-exports all new symbols (no stale `export 'secure_storage.dart'` only) | File inspection |
| 8 | No DDL on `public.*` or `storage.*` — `git diff --stat` shows only `lib/core/storage/*` + `test/**` | `git diff --stat` |
| 9 | No `lib/integrations/cloud_storage/` changes | `git diff --stat` |
| 10 | `upload` accepts `Uint8List` + `mimeType` (platform-agnostic), validates before SDK, supports `upsert` flag (avatar=`true`) | Code + unit test |
| 11 | `onProgress(sent,total)` callback wired — either via SDK or Dio `POST /storage/v1/object/{bucket}/{path}` fallback with `onSendProgress`; doc explains choice | Code review + test (callback invoked) |
| 12 | `download` and `createSignedUrl` used for `credential-documents` (private); `getPublicUrl` only for `profile-avatars`/`portfolio-items`; misuse throws | Unit test (credential `getPublicUrl` → throw) |
| 13 | Path helpers enforce `{entityId}/...` prefix and sanitize traversal; service rejects prefix-escape before network | Unit + service test |
| 14 | Error normalization maps Storage/Dio errors to `PLT001`/`PLT002`/`PLT003`/`PLT004`/`PLT999` (HTTP→kind per `lib/core/api/exceptions/api_exception_mapper.dart:31-82`) | Unit test (403→forbidden, oversize→validation) |
| 15 | No raw SDK messages/SQL leaked; `PII` not logged (only bucket/pathPrefix/size/mime via `pii_redactor`) | Code review |
| 16 | `SupabaseClientProvider.client` guard respected — unauthenticated use throws `ApiInitializationException` (`lib/core/api/supabase/supabase_client_provider.dart:21`) | Unit test |
| 17 | `test/unit/core/storage/storage_validators_test.dart` ≥18 cases green | `flutter test` |
| 18 | `test/unit/core/storage/storage_paths_test.dart` ≥16 cases green | `flutter test` |
| 19 | `test/unit/core/storage/supabase_storage_service_test.dart` ≥28 cases green (success, validation-first, error mapping, progress, auth guard) | `flutter test` |
| 20 | `test/support/fakes/fake_supabase_storage.dart` exists and is used (in-memory bucket→path→bytes map) | File inspection |
| 21 | `flutter analyze` clean, `dart analyze` clean | CI |
| 22 | `flutter test --coverage` validators/paths 100%, service ≥90% | Coverage report |
| 23 | Regression: `supabase db test` full suite `001–017` green — specifically `017_storage_posture.sql` (credential private, avatar/portfolio public, anon zero write, bucket_id conjunct, no `storage_%` SECURITY DEFINER) | `supabase db test` |
| 24 | No `VISUAL-IDENTITY.md` token violations (no UI introduced) + no hardcoded `Colors.*`/raw hex in storage layer | `grep Colors.` zero |
| 25 | Doc: service dartdoc explains progress fallback decision, bucket public/private guidance, TTL recommendation (60–300s) | Code review |
| 26 | EP-02-10/11/18/19 unblocked (phase plan dependency audit) | Dependency check |

---

## 18. Implementation AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

| Factor | Assessment |
|---|---|
| **Technical complexity** | **High** — SDK dispatch (`supabase_flutter:2.17.2` StorageClient vs Dio REST fallback), progress abstraction, platform-agnostic `Uint8List` vs `File`, and the `lib/core/storage/` vs `lib/integrations/cloud_storage/` boundary (ARCHITECTURE.md:55-60,119). Not Very High — no `storage.*` RLS/pgTAP authoring (EP-02-06 owned). |
| **Business impact** | **High** — Blocks 5 downstream flows (EP-02-10/11/17/18/19); if MIME/size/path helpers are wrong, verification uploads either fail opaquely or leak credentials via `getPublicUrl` misuse. Not Critical/Extremely High — server RLS (`017_storage_posture.sql`) remains authoritative security gate. |
| **Security risk** | **High** — Client must not expose `credential-documents` via `getPublicUrl`, must enforce `entity_id/` prefix complementing `storage.foldername(name)[1]=auth.uid()` (`supabase/migrations/20260830100001_storage_buckets.sql:118`), and must not log bytes/PII. Not Very High — server `storage.objects` default-deny is proven; client validation is defense-in-depth. |
| **Performance sensitivity** | **Low-Medium** — 10 MiB single-part upload, pre-network O(1) validation, CDN for public buckets; tracer overhead trivial. |
| **Data complexity** | **Medium** — `Uint8List` + MIME + path string only; no ledger/audit trail; path sanitization + extension↔MIME map is the main data shape. |
| **Integration complexity** | **High** — Injects `SupabaseClientProvider` (`lib/core/api/supabase/supabase_client_provider.dart:19`) + `ApiLayer.dio` (`lib/core/api/api_initializer.dart:60`), maps to `ApiException` (`lib/core/api/exceptions/api_exception.dart:6`), must integrate with `lib/core/logging/`+`lib/core/monitoring/` without PII, and remain swappable for future `cloud_storage` adapters. |

The Approved Phase Plan assigns EP-02-08 **Planning: High / Coding: High** (`EP-02:480` — 6 High items including EP-02-08; distinct from EP-02-06/02/09/10/11/12/13/15/17 Very High and EP-02-03/04/05/09/14/16 Extremely High). Storage service is client-side infrastructure (no financial atomicity, no new RLS) — **High** is calibrated; Very High would over-index.

---

> **Next Step:** Awaiting your approval to proceed to implementation. No files will be created or migrations applied until confirmed. Questions before green-light:
> 1. Confirm `Uint8List + mimeType + fileName` payload shape (vs `File`/`XFile`) for Web compatibility — or mandate `dart:io File` with conditional import?
> 2. Confirm upload progress fallback: if `supabase_flutter:2.17.2` `uploadBinary` lacks `onProgress`, authorize Dio `POST /storage/v1/object/{bucket}/{path}` with `onSendProgress` (requires `Authorization: Bearer` from `SupabaseClientProvider.currentAccessToken`) vs documenting indeterminate progress?
> 3. Confirm `profile-avatars/{entityId}/avatar.{ext}` canonical single-avatar (`upsert:true`) vs versioned `avatar_{uuid}.{ext}` — former simplifies cache invalidation, latter preserves history?
