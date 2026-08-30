# Definition of Done — EP-02-08: Storage Service & File Upload Infrastructure

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-08 | **Status:** Not Started
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-08-Storage Service & File Upload Infrastructure.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-08 |
| **Task Name** | Storage Service & File Upload Infrastructure |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 3 — Client-Side Infrastructure |
| **Priority** | High |
| **Dependencies** | EP-02-06 (Supabase Storage Infrastructure — 3 buckets + 12 `storage.objects` policies) |
| **Blocks** | EP-02-10, EP-02-11, EP-02-17, EP-02-18, EP-02-19 |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-08-Storage Service & File Upload Infrastructure.md` |

---

## 2. Functional Verification

This task is client-side storage infrastructure (no UI, no SQL). Functional verification confirms the `StorageService` abstraction correctly validates, sanitizes, and dispatches to `SupabaseClient.storage.from(bucket)` per bucket contract.

### 2.1 Required Functionality

- [ ] **FV-01:** `lib/core/storage/storage_service.dart` exists with abstract methods `upload`, `download`, `remove`, `getPublicUrl`, `createSignedUrl`, `list`, `validateForBucket` (EP-02-08 §5.2)
- [ ] **FV-02:** `lib/core/storage/supabase_storage_service.dart` exists, injects `SupabaseClient` (and optional `Dio`) and allowlists exactly 3 buckets (`credential-documents`, `profile-avatars`, `portfolio-items`) via `StorageBuckets` constants — unknown bucket throws `StorageValidationException`
- [ ] **FV-03:** `upload` accepts `Uint8List bytes + String mimeType + String path + String bucket (+ fileName, onProgress, upsert)` — no `dart:io File` dependency (Web-safe)
- [ ] **FV-04:** `validateForBucket` enforces per-bucket `file_size_limit` (10485760 / 5242880 / 10485760) and `allowed_mime_types` (4/3/4) matching `storage.buckets`; called **before** network
- [ ] **FV-05:** `StorageValidators` extension↔MIME mapping rejects `text/html`, `application/octet-stream`, `application/x-msdownload` before network
- [ ] **FV-06:** `StoragePaths.credentialDocument(entityId, submissionId, fileName)` formats `{entityId}/{submissionId}/{uuid}_{sanitized}` with UUID
- [ ] **FV-07:** `StoragePaths.avatar(entityId, ext)` produces `{entityId}/avatar.{ext}` lowercased, `upsert:true` semantics
- [ ] **FV-08:** `StoragePaths.portfolioItem(entityId, itemId, fileName)` formats `{entityId}/{itemId}/{sanitized}`
- [ ] **FV-09:** `sanitize` strips `..`, `/`, whitespace, control chars, truncates >180 chars, enforces `a-z0-9._-` — traversal payload `../../etc/passwd` collapsed to single segment
- [ ] **FV-10:** `onProgress(sent,total)` callback wired on `upload` — either native SDK or Dio `onSendProgress` fallback, documented in dartdoc (no polling)
- [ ] **FV-11:** `getPublicUrl` **only** for `profile-avatars`/`portfolio-items` (returns `/storage/v1/object/public/...`); calling on `credential-documents` throws `StorageValidationException`
- [ ] **FV-12:** `createSignedUrl(path, 60-300)` for `credential-documents` private preview; `download` for authenticated fetch
- [ ] **FV-13:** `remove` deletes owner-scoped paths via `from(bucket).remove([...])`
- [ ] **FV-14:** `StorageConfig` constants equal migration/config values — parity test asserts `StorageBuckets.credentialDocuments == 'credential-documents'`, `StorageLimits.profileAvatars == 5242880`, etc.

### 2.2 Expected Workflows

- [ ] **FV-15:** Credential upload workflow: `validateForBucket` → `StoragePaths.credentialDocument` → `uploadBinary(bucket: credential-documents, upsert:false)` → returns storage key for `entity_credentials.document_path`
- [ ] **FV-16:** Avatar upload workflow: `avatar(entityId, ext)` → `upload(upsert:true)` overwrites canonical path; `getPublicUrl` returns deterministic CDN URL for `<img src>` on `/p/:profession_slug/:entity_id`
- [ ] **FV-17:** Portfolio upload workflow: `portfolioItem` → `upload` → `getPublicUrl` public read
- [ ] **FV-18:** Private credential preview workflow: `createSignedUrl(60)` short TTL — no public link, HMAC-signed
- [ ] **FV-19:** Download workflow: `download(bucket, path)` for `credential-documents` returns `Uint8List` bytes
- [ ] **FV-20:** Validation fail-fast workflow: oversized/invalid MIME throws `StorageValidationException` **before** fake SDK invoked (spy `capturedUpsert` not set)

### 2.3 Success Conditions

- [ ] **FV-21:** All 3 bucket workflows succeed with valid payloads via fake storage (bytes round-trip integrity)
- [ ] **FV-22:** `getPublicUrl` is sync string concat — no network, memoizable; `createSignedUrl` is async
- [ ] **FV-23:** Service is provider-swappable — downstream `lib/systems/verification/` and `lib/systems/portfolio/` can consume `StorageService` without importing `supabase_flutter` directly

### 2.4 Error Handling Scenarios

- [ ] **FV-24:** Oversize: `credential-documents` 10485761 bytes → `StorageValidationException` `kind==validation` `code==PLT003` before network
- [ ] **FV-25:** Invalid MIME: `profile-avatars` with `application/pdf` → `StorageValidationException` (pdf allowed only on credential/portfolio)
- [ ] **FV-26:** Unknown bucket: `upload(bucket:'evil-bucket')` → `StorageValidationException`
- [ ] **FV-27:** Storage 403 (RLS prefix violation `storage.foldername(name)[1]!=auth.uid()`) → mapped to `ApiExceptionKind.forbidden` PLT002
- [ ] **FV-28:** Storage 401/404/409/5xx → mapped to `auth` PLT001 / `notFound` PLT004 / `conflict` / `server` PLT999 per `api_exception_mapper.dart:31-82`; message safe (no SQL/stack)
- [ ] **FV-29:** Unauthenticated use before `ApiInitializer.initializeApi` → `ApiInitializationException` via `SupabaseClientProvider.client` guard (`supabase_client_provider.dart:21`)

### 2.5 Important User Interactions

*(Infrastructure — no direct UI, but UX-shaping checks)*

- [ ] **FV-30:** Inline form error possible: `validateForBucket` provides field-level message for MIME/size before upload (enables “PDF or image up to 10 MB” UX in EP-02-10/11)
- [ ] **FV-31:** Progress indicator feasible: `onProgress` enables `HivorrLoader` + linear indicator on slow networks
- [ ] **FV-32:** Clear recovery messages: 403→“You can only upload to your own folder.” 413/size→“File too large — max 5 MB for avatars.” — service does **not** auto-retry uploads (avoids duplicate objects)

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Files located exactly at `lib/core/storage/` — 6 new files + barrel update; no files in `lib/integrations/cloud_storage/` (must remain empty per `ARCHITECTURE.md:119`)
- [ ] **TV-02:** `lib/core/storage/storage.dart:1` barrel re-exports all new symbols (not stale `secure_storage.dart` only)
- [ ] **TV-03:** Interface-first pattern mirrors `lib/core/storage/secure_storage.dart:12` — abstract `StorageService` separate from `SupabaseStorageService` impl
- [ ] **TV-04:** No DDL on `public.*` or `storage.*` — `git diff --stat` shows only `lib/core/storage/*` + `test/**`; no `supabase/migrations/*` added, no `supabase/config.toml` modified
- [ ] **TV-05:** No `SECURITY DEFINER` functions, no `GRANT` on `public.*`/`storage.*` created
- [ ] **TV-06:** Dependency wiring uses `SupabaseClientProvider.client` safe accessor (`supabase_client_provider.dart:19`) + `SupabaseClientProvider.currentAccessToken` (`:29`) for auth header; optional `Dio` from `ApiLayer.dio` (`api_initializer.dart:60`) for progress fallback — no direct `Supabase.instance.client` leakage in business logic beyond provider
- [ ] **TV-07:** Optional `Provider<StorageService>.value` registration consistent with `provider:6.1.5` (`pubspec.yaml:50`); no `Riverpod` introduced
- [ ] **TV-08:** No UI/widgets in `lib/shared/` or `lib/systems/*` — task is infrastructure-only, so `VISUAL-IDENTITY.md` token check vacuous; `grep Colors\.` zero in `lib/core/storage/`

### 3.2 Required System Behavior

- [ ] **TV-09:** Bucket allowlist enforced in service constructor — constants from `storage_config.dart`
- [ ] **TV-10:** `validateForBucket` is O(1) map lookup + int compare (no regex/network)
- [ ] **TV-11:** Upload dispatch uses `supabase.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType, upsert: bool))` (or Dio fallback)
- [ ] **TV-12:** `upsert` semantics: `profile-avatars` canonical `avatar.{ext}` = `true`; `credential-documents`/`portfolio-items` = `false`
- [ ] **TV-13:** `getPublicUrl` vs `createSignedUrl` dispatch correct per bucket public/private flag
- [ ] **TV-14:** Error normalization via `ApiExceptionMapper` pattern (`api_exception_mapper.dart:15`) — preserves `kind`, `code`, `statusCode`
- [ ] **TV-15:** Logging via `lib/core/logging/hivorr_logger.dart` + `pii_redactor.dart` — logs `bucket`, redacted `pathPrefix` (`***`), `byteLength`, `mimeType`; never logs bytes/full path
- [ ] **TV-16:** Monitoring span via `lib/core/monitoring/monitoring_service.dart` + `performance_tracer.dart` — `storage.upload.duration`, `storage.download.duration`, `storage.error.kind` (no PII)

### 3.3 Module Integration

- [ ] **TV-17:** No conflict with existing `lib/core/storage/secure_storage.dart`, `secure_token_store.dart`, `supabase_secure_local_storage.dart`
- [ ] **TV-18:** Service consumable by downstream `lib/systems/verification/` (EP-02-10/11), `lib/systems/portfolio/` (EP-02-19), `lib/systems/support/` (dispute evidence) without direct SDK import
- [ ] **TV-19:** Future `lib/integrations/cloud_storage/` adapters can implement `StorageService` without modifying this task
- [ ] **TV-20:** Offline Sync (`lib/core/sync/`) not coupled — uploads are online-only; queuing noted as future extension

### 3.4 Technical Requirements from Plan

- [ ] **TV-21:** Service dartdoc documents progress fallback decision (SDK vs Dio `onSendProgress`) and bucket public/private guidance (TTL 60–300s)
- [ ] **TV-22:** `flutter analyze` + `dart analyze` clean

---

## 4. Data Verification

*This task creates **no database rows** — storage objects live in `storage.objects` (existing buckets). Verification is about constant parity and payload handling, not new tables.*

### 4.1 Constant Parity

- [ ] **DV-01:** `StorageBuckets` constants equal exact bucket IDs (`credential-documents`, `profile-avatars`, `portfolio-items`)
- [ ] **DV-02:** `StorageLimits` equal exact `file_size_limit` bytes (10485760 / 5242880 / 10485760)
- [ ] **DV-03:** `StorageMimeTypes` sets equal exact `allowed_mime_types` arrays (credential 4: `jpeg,png,webp,pdf`; avatar 3: `jpeg,png,webp`; portfolio 4 inc. pdf) — mirrors `storage.buckets` and `supabase/config.toml:36-48`
- [ ] **DV-04:** Parity test asserts constants vs live-equivalent values — catches drift if EP-02-06 migration amended

### 4.2 Data Relationships

- [ ] **DV-05:** No FK to `public.entities` — storage path string persisted upstream (`entity_credentials.document_path = 'credential-documents/<entity_id>/...'`), not FK constraint (consistent with EP-02-06 §12)

### 4.3 Data Accuracy

- [ ] **DV-06:** File payload shape correct: `Uint8List bytes` length = `bytes.lengthInBytes`; `mimeType` validated before network; `fileName` sanitized; no base64 double-copy
- [ ] **DV-07:** Path vocabulary exact per §7.3 of plan: credential `{entity_id}/{submission_id}/{uuid}_{sanitized}`, avatar `{entityId}/avatar.{ext}`, portfolio `{entityId}/{itemId}/{sanitized}` — all lower-case, URL-safe

### 4.4 Data Integrity

- [ ] **DV-08:** Data integrity via fake storage: `upload` bytes round-trip via `download` identical (`Uint8List` equality); `remove` deletes; `list` paginated prefix scan (no N+1, `limit` param)
- [ ] **DV-09:** No mutation of `public.*` tables; `supabase/tests/database/017_storage_posture.sql:92-100` RLS-enabled still green
- [ ] **DV-10:** Upload idempotency via `upsert` flag only — avatar overwrites, credential/portfolio duplicate path fails unless `upsert:true` (not DB `ON CONFLICT`)

---

## 5. Security Verification

- [ ] **SV-01:** Private credential isolation — service never calls `getPublicUrl` on `credential-documents`; only `download`/`createSignedUrl` (60–300s TTL); credential-documents `public=false` (`supabase/config.toml:37`) + owner-only SELECT (`20260830100001_storage_buckets.sql:113`)
- [ ] **SV-02:** Cross-bucket leakage prevented — service allowlist + server `bucket_id = '<bucket>'` conjunct on every `storage.objects` policy (`:116,124,135,143`); test validates via `017_storage_posture.sql:189-198`
- [ ] **SV-03:** Path traversal / prefix escape blocked — `sanitize` + validators reject `../`/absolute; server `WITH CHECK (storage.foldername(name))[1]=auth.uid()::text` authoritative; service test covers `evil-entity-id/` attempt (mirrors `017_storage_posture.sql:210-237`)
- [ ] **SV-04:** MIME spoofing defense — client extension→MIME map + `fileName` sanitization (UX), server `allowed_mime_types` authoritative; client rejects `application/x-msdownload`, `text/html` before network
- [ ] **SV-05:** Size DoS prevention — `validateSize` blocks oversize before SDK (spy `capturedUpsert` not set); server `file_size_limit` second gate
- [ ] **SV-06:** Anon write DoS — `anon` zero INSERT/UPDATE/DELETE (`017_storage_posture.sql:108-117`); service requires `authenticated` (fails closed via `SupabaseClientProvider.client` guard)
- [ ] **SV-07:** Auth token protection — token via `SupabaseClientProvider.currentAccessToken` / `auth.currentSession`; never logged, never in public URL; signed URL is short-lived HMAC; PII redaction via `pii_redactor.dart`
- [ ] **SV-08:** No `public.*` grant drift — no `GRANT`; `storage.*` access via RLS only; full suite `001–017` regression (`017_storage_posture.sql:166-172` `storage_%` SECURITY DEFINER =0)
- [ ] **SV-09:** No SQL injection — bucket names are constants; paths are parameterized SDK calls, not interpolated SQL
- [ ] **SV-10:** No secrets in validators/paths — no hardcoded `service_role` key; ENV isolation per ENV-002/008 via `EnvironmentConfig`

---

## 6. Performance Verification

- [ ] **PV-01:** Public buckets `public=true` enable Supabase CDN + `Cache-Control` via `getPublicUrl` — no `Authorization` header on reads (suitable for `/p/:profession_slug/:entity_id`)
- [ ] **PV-02:** Private `createSignedUrl(60)` minimal signing overhead; short TTL prevents CDN caching of sensitive docs
- [ ] **PV-03:** Pre-network validation O(1) — microseconds; avoids wasted multipart on slow networks
- [ ] **PV-04:** 10 MiB `Uint8List` single allocation — acceptable mobile heap; no base64 double-copy; Web `XFile.readAsBytes()` no extra copy
- [ ] **PV-05:** Single-part upload only (5–10 MiB limit) — no chunked/resumable needed; progress via `onSendProgress` streaming, not polling
- [ ] **PV-06:** Client path sanitization O(n) on filename (<255 chars) — negligible; policy evaluation is server-side indexed (`storage.objects.name` trigram)
- [ ] **PV-07:** `getPublicUrl` deterministic string concat `/storage/v1/object/public/{bucket}/{path}` — no network, memoizable; tracer span lightweight via `PerformanceTracer` + `MonitoringConfig`

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/core/storage/`

- [ ] **TT-01:** `storage_validators_test.dart` ≥18 cases green — credential accept 4 MIMEs to 10485760, reject `text/html`/`octet-stream`/oversize+1, avatar reject pdf/5242880 cap, portfolio accept pdf, case-insensitive, 0-byte boundary, `StorageValidationException` `kind==validation` `code==PLT003`
- [ ] **TT-02:** `storage_paths_test.dart` ≥16 cases green — `credentialDocument`/`avatar`/`portfolioItem` formatting, sanitization of `..`/`/`/spaces/upper-case/control chars/truncate, traversal payload
- [ ] **TT-03:** `supabase_storage_service_test.dart` ≥28 cases green — fake `SupabaseStorageClient` injected: upload success returns path, validation-first (oversize never hits fake), unknown bucket throws, avatar `upsert:true` captured, credential `getPublicUrl` throws, public `getPublicUrl` returns `.../object/public/...`, `download` private success, `remove` owner prefix, `createSignedUrl` HMAC, `onProgress` invoked, error mapping 403→PLT002/401→auth/413→validation/5xx→server, `ApiInitializationException` guard, `Uint8List` integrity
- [ ] **TT-04:** Total ≥60 assertions; validators/paths 100% coverage, service branches ≥90% (`flutter test --coverage`)
- [ ] **TT-05:** `test/support/fakes/fake_supabase_storage.dart` exists — `Map<String, Map<String, Uint8List>> buckets` + `from(bucket)` → `FakeStorageFileApi` (`uploadBinary`, `download`, `remove`, `getPublicUrl`, `createSignedUrl`, `list`) + spy `capturedUpsert`
- [ ] **TT-06:** Contract parity assertion — `StorageConfig` constants equal live-equivalent values (mirrors `017_storage_posture.sql:60-90`)
- [ ] **TT-07:** `flutter analyze` clean, `dart analyze` clean, `flutter test` green

### 7.2 Regression

- [ ] **TT-08:** `supabase db test` full suite `001–017` green — specifically `017_storage_posture.sql` (credential private, avatar/portfolio public, anon zero write, `bucket_id` conjunct, no `storage_%` SECURITY DEFINER) — zero regressions on `public.*` RLS/posture
- [ ] **TT-09:** `git diff --stat` confirms only `lib/core/storage/*` + `test/**` touched (no `supabase/migrations/*`, no `supabase/config.toml`, no `lib/integrations/cloud_storage/`)

### 7.3 Edge Cases

- [ ] **TT-10:** Boundary sizes: 0 bytes, exactly `file_size_limit`, `limit+1` byte
- [ ] **TT-11:** MIME case insensitivity (`IMAGE/JPEG` accepted), extension↔MIME mismatch normalization
- [ ] **TT-12:** Filename edge: empty, 300-char name truncation, `avatar` with uppercase `JPG` → `avatar.jpg`, empty `entityId` rejected
- [ ] **TT-13:** Traversal: `../../etc/passwd`, `/absolute/path`, `entityId//double-slash` sanitized

### 7.4 Failure Scenarios

- [ ] **TT-14:** Oversize/invalid MIME throws before fake SDK — spy not invoked
- [ ] **TT-15:** Unknown bucket, credential `getPublicUrl` misuse, prefix-escape `evil-entity-id/` all throw `StorageValidationException`
- [ ] **TT-16:** Fake throws `StorageException(status 403/401/422/404/5xx)` → correct `ApiExceptionKind` mapping
- [ ] **TT-17:** Unauthenticated `SupabaseClientProvider.client` guard → `ApiInitializationException` (not raw Supabase assert)

### 7.5 Manual Testing

- [ ] **TT-18:** Manual spot-check (optional, with `supabase start`): `supabase storage` upload via service in staging — credential upload + `createSignedUrl(60)` preview renders, avatar `getPublicUrl` renders in `<img>` without auth, oversize in UI shows inline error before network

---

## 8. User Acceptance Verification

*This task has no direct UI — acceptance is indirect via correctness, hygiene, and downstream readiness.*

- [ ] **UA-01:** Fail-fast UX — MIME/size rejection yields immediate `StorageValidationException` with field-level message (not opaque `PLT003` after network)
- [ ] **UA-02:** Public avatar/portfolio renders via `getPublicUrl` without auth — SEO-friendly, no token refresh on `/p/:profession_slug/:entity_id` (ARCHITECTURE.md:150)
- [ ] **UA-03:** Private credential preview uses `download`/`createSignedUrl` (60s TTL) — no public link leakage if upstream mistakenly uses `getPublicUrl` on credential bucket (service throws)
- [ ] **UA-04:** Progress feedback feasible — `onProgress` enables downstream `HivorrLoader` + linear indicator on slow Nigerian networks
- [ ] **UA-05:** Idempotent avatar overwrite via `upsert:true` prevents stale duplicates; cache invalidation via `?t=` query param documented
- [ ] **UA-06:** Error messages safe and actionable — 403→“You can only upload to your own folder.” size→“File too large — max 5/10 MB.” network/timeout→retry affordance (service does not auto-retry)
- [ ] **UA-07:** No UI introduced — `VISUAL-IDENTITY.md` / AGENT.md Rule 5 (`AppTheme` tokens, no `Colors.*`/raw hex) vacuously satisfied (`grep Colors\.` zero in `lib/core/storage/`)
- [ ] **UA-08:** Downstream unblocked — `lib/systems/verification/` (EP-02-10/11), `lib/systems/portfolio/` (EP-02-19), `lib/systems/support/` (dispute evidence), and onboarding (EP-02-18) can import `StorageService` without SDK churn; last Stage 3 dependency satisfied

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-08 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/core/storage/storage_service.dart` exists with abstract contract (`upload`, `download`, `remove`, `getPublicUrl`, `createSignedUrl`, `list`, `validateForBucket`) | File inspection | ☐ |
| 2 | `lib/core/storage/supabase_storage_service.dart` exists, injects `SupabaseClient` (+ optional `Dio`), allowlists 3 buckets (`credential-documents`, `profile-avatars`, `portfolio-items`) | File inspection + grep `StorageBuckets` | ☐ |
| 3 | `lib/core/storage/storage_config.dart` declares bucket IDs, limits (10485760/5242880/10485760), MIME allowlists exactly matching `20260830100001_storage_buckets.sql:51-82` and `supabase/config.toml:36-48` | Code review + parity test | ☐ |
| 4 | `lib/core/storage/storage_exceptions.dart` defines `StorageException` hierarchy (`validation` PLT003, `auth` PLT001, `forbidden` PLT002) | File inspection | ☐ |
| 5 | `lib/core/storage/storage_paths.dart` defines pure `credentialDocument`, `avatar`, `portfolioItem` + `sanitize` (strips `..`/`/`/control chars) | File + unit test | ☐ |
| 6 | `lib/core/storage/storage_validators.dart` validates per-bucket MIME/size before network (credential 10 MiB + 4 MIMEs, avatar 5 MiB + 3 MIMEs, portfolio 10 MiB + 4 MIMEs) | Unit test | ☐ |
| 7 | `lib/core/storage/storage.dart:1` barrel re-exports all new symbols | File inspection | ☐ |
| 8 | No DDL on `public.*` or `storage.*` — `git diff --stat` shows only `lib/core/storage/*` + `test/**` | `git diff --stat` | ☐ |
| 9 | No `lib/integrations/cloud_storage/` changes | `git diff --stat` | ☐ |
| 10 | `upload` accepts `Uint8List`+`mimeType` (platform-agnostic), validates before SDK, supports `upsert` (avatar=`true`) | Code + unit test | ☐ |
| 11 | `onProgress(sent,total)` wired (SDK or Dio `POST /storage/v1/object/...` fallback); dartdoc explains choice | Code review + test | ☐ |
| 12 | `download`/`createSignedUrl` for `credential-documents` (private); `getPublicUrl` only for `profile-avatars`/`portfolio-items`; misuse throws | Unit test | ☐ |
| 13 | Path helpers enforce `{entityId}/...` prefix and sanitize traversal; service rejects prefix-escape | Unit + service test | ☐ |
| 14 | Error normalization maps to `PLT001`/`PLT002`/`PLT003`/`PLT004`/`PLT999` per `api_exception_mapper.dart:31-82` | Unit test | ☐ |
| 15 | No raw SDK messages/SQL leaked; no PII logged (only bucket/pathPrefix/size/mime) | Code review | ☐ |
| 16 | `SupabaseClientProvider.client` guard — unauthenticated throws `ApiInitializationException` (`:21`) | Unit test | ☐ |
| 17 | `test/unit/core/storage/storage_validators_test.dart` ≥18 cases green | `flutter test` | ☐ |
| 18 | `test/unit/core/storage/storage_paths_test.dart` ≥16 cases green | `flutter test` | ☐ |
| 19 | `test/unit/core/storage/supabase_storage_service_test.dart` ≥28 cases green | `flutter test` | ☐ |
| 20 | `test/support/fakes/fake_supabase_storage.dart` exists (in-memory buckets) | File inspection | ☐ |
| 21 | `flutter analyze` + `dart analyze` clean | CI | ☐ |
| 22 | `flutter test --coverage` validators/paths 100%, service ≥90% | Coverage report | ☐ |
| 23 | `supabase db test` 001–017 green — `017_storage_posture.sql` (credential private, avatar/portfolio public, anon zero write, bucket_id conjunct, no `storage_%` SECURITY DEFINER) | `supabase db test` | ☐ |
| 24 | No `VISUAL-IDENTITY.md` violations (no UI) + `grep Colors\.` zero in storage layer | grep | ☐ |
| 25 | Dartdoc explains progress fallback, bucket public/private guidance, TTL 60–300s | Code review | ☐ |
| 26 | EP-02-10/11/18/19 unblocked | Dependency check | ☐ |

---

> **Approval:** Task EP-02-08 is marked **Completed** only when all 26 conditions in the Final Approval Checklist are verified and signed off by the project lead.
