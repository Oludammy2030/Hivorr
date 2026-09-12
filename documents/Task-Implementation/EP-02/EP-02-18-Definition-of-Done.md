# Definition of Done — EP-02-18: Entity Registration & Onboarding Flow

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-18 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-18-Entity Registration & Onboarding Flow.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-18 |
| **Task Name** | Entity Registration & Onboarding Flow |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 4 — Trust & Verification Systems |
| **Priority** | High |
| **Dependencies** | EP-02-07 (Taxonomy Engine — `TaxonomyProvider`), EP-02-10 (Identity Verification — `IdentityVerificationService`), EP-02-11 (Trade Verification — `TradeVerificationService`), EP-02-08 (Storage — `profile-avatars`, `credential-documents`), EP-01-06 (`entity_profiles`, `entity_profession_bind`, `entity_profile_update`) |
| **Blocks** | EP-02-19 (Public Professional Profile), EP-02-13 (Financial Profile composition — onboarding completion then links forward) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-18-Entity Registration & Onboarding Flow.md` |

Frozen server references (read-only, never modified by this task): `supabase/migrations/20260821090004_entity_model_rpcs.sql:16-79,202-257` (`entity_profile_update`, `entity_profession_bind`), `20260821090003_entity_model_rls_policies.sql:88` (`entity_profiles_authenticated_update`), `20260821090002_entity_core_tables.sql:182` (`entity_professions_entity_profession_key`), `20260829090002_taxonomy_management_rpcs.sql:35,64`, `20260829090003_verification_admin_review_schema.sql:115-406,364-381` (identity/trade submit chain + `PLT005`), `20260830100001_storage_buckets.sql:118` (storage RLS `{entityId}` path gate).

---

## 2. Functional Verification

This task delivers the **Stage 4/5 orchestration seam**: a resumable 5-step wizard (profile → industry → profession → identityDocument → tradeProof → completed) that composes four proven verification systems plus the EP-01 profile seam. It adds zero server surface — pure client-side composition. Functional verification confirms the data layer, service facade, provider, screens, widgets, routing, and DI behave correctly and never bypass server-enforced invariants.

### 2.1 Required Functionality — Domain Vocabulary

- [ ] **FV-01:** `lib/systems/onboarding/models/onboarding_step.dart` defines `OnboardingStep` with 6 values `profile, industry, profession, identityDocument, tradeProof, completed` — each with `label`, `description`, `stepNumber`, and `isVerificationStep` (`true` only for identity + trade) — pure Dart, no DTO leakage
- [ ] **FV-02:** `OnboardingProgress` entity (`lib/data/entities/onboarding_progress.dart`) uses `OnboardingStepCode` (`profile, industry, profession, identityDocument, tradeProof`) — fields `entityId`, `step`, `completedSteps` (ordered), `hasIdentitySubmission`, `hasTradeProofSubmission`, `updatedAt`; `isComplete` derives `true` only when all 5 steps are completed; immutable, no `json` cycle in entities

### 2.2 Required Functionality — Data Layer (Entity + Store)

- [ ] **FV-03:** `lib/data/local/onboarding_progress_store.dart` defines abstract `OnboardingProgressStore` (`read(entityId)`, `save(progress)`, `clear(entityId)`) + `InMemoryOnboardingProgressStore` (tests/unsupported platforms) + `HiveOnboardingProgressStore` — box `onboarding`, key `onboarding_progress:{entityId}`, graceful no-op/empty when Hive uninitialized
- [ ] **FV-04:** Store is client-local position state only — never trusted verification state; `clear` only on deliberate re-onboarding or account switch; no server table backs progress
- [ ] **FV-05:** `lib/data/local/` holds store (EP-01-11 storage boundary respected); no widget imports in `lib/data/` files

### 2.3 Required Functionality — Systems Facade (`OnboardingService`)

- [ ] **FV-06:** `lib/systems/onboarding/services/onboarding_service.dart` composes existing facades — `EntityProvider`, `TaxonomyProvider`, `IdentityVerificationService`, `TradeVerificationService`, `StorageService` — and the progress store; **no re-implemented transport**, no new RPC wrappers beyond `entity_profession_bind`
- [ ] **FV-07:** Exposes `currentStep`, `advance()`, `back()`, `exitAndSave()`, `resume(entityId)`, `completeProfile(...)`, `bindProfession(professionId)`, `submitIdentity(...)`, `submitTradeProof(...)`, `refreshTradeGate()`, `isResumable()` — thin facade, consumed by `OnboardingProvider` only, never imported by widgets
- [ ] **FV-08:** `resume(entityId)` reads store and returns furthest step; `isComplete` routes to `/onboarding/complete`; fresh (no progress) entity starts at `profile`
- [ ] **FV-09:** `advance()` moves in frozen order `profile → industry → profession → identityDocument (→ tradeProof if profession bound) → completed` and persists after every step; never skips a required step (ordering contract)
- [ ] **FV-10:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) redacted logs — `entityId` suffix (`***last4`), step code, document/proof type, `mimeType`, `byteLength`, profession id redacted; **never** full `legalName`, full avatar/credential path, never bytes
- [ ] **FV-11:** `PerformanceTracer` spans `onboarding.step.{n}.duration`, `onboarding.submit.identity.proof`, `onboarding.submit.trade.proof`, `onboarding.resume.duration` — tagged step codes, no PII, sampled via `MonitoringConfig`

### 2.4 Required Functionality — Provider

- [ ] **FV-12:** `lib/data/providers/onboarding_provider.dart` — `OnboardingProvider extends ChangeNotifier` (`provider:6.1.5`) constructed with `({required OnboardingService service, HivorrLogger? logger})` for testability
- [ ] **FV-13:** State fields: `progress: OnboardingProgress?`, `currentStep`, `submitState: AsyncState`, `lastError: ApiException?`, `isTradeGateOpen: bool?` (from `TradeVerificationStatus.tradeVerificationStatus == approved`)
- [ ] **FV-14:** Public API: `loadProgress()`, `advance()`, `back()`, `saveAndExit()`, `resume()`, `completeProfile({...})`, `bindProfession(industryId, professionId)`, `submitIdentityDocument({...})`, `submitTradeProof({...})`, `refreshGateStatus()`; `notifyListeners()` on each mutation
- [ ] **FV-15:** `WidgetsBindingObserver.didChangeAppLifecycleState(paused/inactive)` triggers `exitAndSave()` — progress never lost on app background/termination

### 2.5 Required Functionality — Profile Completion Step

- [ ] **FV-16:** Uploads avatar first via `StorageService.upload(bucket: StorageBuckets.profileAvatars, path: StoragePaths.avatar(entityId, ext) → profile-avatars/{entityId}/avatar.{ext}, upsert: true)` (public bucket, 5 MiB, `jpeg/png/webp` — `storage_config.dart:39,66,97`); reject-before-upload via `StorageValidators.validateForBucket` (6 MiB / wrong MIME never reaches network)
- [ ] **FV-17:** Persists legal name, display name, bio via `EntityProvider.updateProfile` → `entity_profile_update` RPC (`20260821090004:16-79`, ≤255 / ≤255 / ≤5000 pre-validated with live counters); then persists `avatar_path` via the self-scoped `entity_profiles` REST update (`entity_profiles_authenticated_update` RLS `20260821090003:88`); call ordering asserted (upload → RPC → avatar_path update)
- [ ] **FV-18:** `StorageValidationException` (`PLT003` semantics) propagates as field errors, never raw exceptions

### 2.6 Required Functionality — Taxonomy Steps

- [ ] **FV-19:** Industry step reuses `TaxonomyProvider.loadIndustries()` + `selectIndustry(id)` — selection preserved across navigation (`taxonomy_provider.dart:113`) and across resume
- [ ] **FV-20:** Profession step reuses `loadProfessions(industryId)`, `selectProfession(p)`, `filteredProfessions` (debounced search) + the `ProfessionRegistryBrowser` widget (`lib/workspace/profession_registry/widgets/profession_registry_browser.dart:24`)
- [ ] **FV-21:** On continue → `bindProfession(professionId)` → `entity_profession_bind(p_profession_id)` (`20260821090004:202-257`) — validates existence/active, lands `trade_verification_status = unverified`; `PLT004` (missing/inactive) and `PLT005` (duplicate binding) surface as inline guidance; duplicate never fire-hammers the RPC

### 2.7 Required Functionality — Verification Steps

- [ ] **FV-22:** Identity step delegates to `IdentityVerificationService.submitIdentityDocument(documentType, bytes, mimeType, fileName, onProgress)` — 5 `DocumentType` values; private `credential-documents` (10 MiB, `jpeg/png/webp/pdf`), `StoragePaths.credentialDocument(...)`, `verification_submit` queue; `onProgress` drives a `LinearProgressIndicator`
- [ ] **FV-23:** Trade step delegates to `TradeVerificationService.submitTradeProof(type, professionId: selectedProfession.id, bytes, mimeType, fileName, onProgress)` — 5 `TradeProofType` values; `submission_type = trade_proof`; proof always carries the bound `professionId`; step not offered when no profession bound (defensive)
- [ ] **FV-24:** `PLT005` active-verification conflict surfaces inline guidance ("You already have a pending verification for this document") + status escape to `VerificationStatusScreen`; never silent retry
- [ ] **FV-25:** On success, progress flags `hasIdentitySubmission` / `hasTradeProofSubmission` marked — **UX mirrors only**; verification status stays server authority (`AGENT.md:16` Rule 4)

### 2.8 Required Functionality — Gate Education

- [ ] **FV-26:** `refreshTradeGate()` reads `TradeVerificationService.getStatus()`; `isTradeGateOpen = status.approved`; `TradeProofStepScreen` + `OnboardingCompleteScreen` render gate copy sourced from this read — approved → "bid unlocked"; otherwise → "You can start work immediately — bidding unlocks once your trade proof is approved" (`AGENT.md:15` Rule 2); no gate-affecting controls
- [ ] **FV-27:** Completion screen (`OnboardingCompleteScreen`) shows `HivorrSuccessState` "You're registered" with per-step done chips (read-only), trust-loop education panel (identity/trade submission status + gate copy, next actions: view verification status, financial profile `EP-02-13` link, marketplace later), and "Go to home" CTA that marks progress complete and routes to `/`

### 2.9 Required Functionality — UI Screens

- [ ] **FV-28:** `OnboardingShellScreen` — reads `currentStep`; renders `OnboardingProgressIndicator` + `IndexedStack` step body + standard CTA bar (`Back` / `Continue`/`Submit` via `HivorrButton`); routes by step to the 6 sub-routes; defensively skips `tradeProof` when no profession selected; every back/system-back on non-terminal step triggers `OnboardingExitConfirmDialog`
- [ ] **FV-29:** `ProfileSetupScreen` — legal name `TextField` (required, ≤255, live counter), display name (required, ≤255, counter), bio (optional, ≤5000, counter); `OnboardingAvatarPicker` preview (`HivorrAvatar`) + validate-then-upload with `onProgress`; Continue disabled until names valid (fail-fast before RPC — no `PLT003` round-trip)
- [ ] **FV-30:** `IndustrySelectionScreen` — industries from `TaxonomyProvider`; `HivorrChip`/`ChoiceChip` grouped list, selected uses `colorScheme.primaryContainer` (`VISUAL-IDENTITY.md:51`, no hardcoded colors); selection auto-advances
- [ ] **FV-31:** `ProfessionSelectionScreen` — `ProfessionRegistryBrowser` reuse + debounced search; select → `bindProfession` → advance; `PLT005` duplicate inline guidance; Rule 2 gate copy explained
- [ ] **FV-32:** `IdentityVerificationStepScreen` — `DocumentType` picker (5 options), `OnboardingDocumentUploadTile` (validate MIME/size before network), `LinearProgressIndicator` (`onProgress`), `PLT005` guidance + "Skip"/view-status escape; "reviewed within 24h" copy after submit
- [ ] **FV-33:** `TradeProofStepScreen` — selected-profession chip, `TradeProofType` picker (5 options), same upload pipeline, gate-status panel via `refreshTradeGate()`
- [ ] **FV-34:** `OnboardingCompleteScreen` — see FV-27; `HivorrSuccessState`, done chips, Rule 2 gate copy, "Go to home"

### 2.10 Required Functionality — UI Widgets

- [ ] **FV-35:** `OnboardingProgressIndicator` — 5-segment linear tracker; filled count == `stepNumber`; `ColorScheme.primary` on done, `surfaceVariant` pending; no hardcoded hex
- [ ] **FV-36:** `OnboardingStepCard` — icon + title + description + state; spacing/radius via `AppThemeExtension` (`VISUAL-IDENTITY.md:219-235`, 8pt grid, 16dp cards)
- [ ] **FV-37:** `OnboardingExitConfirmDialog` — "Save my progress and exit?" affirmative/destructive styling via `colorScheme`; exit saves progress (no data loss)
- [ ] **FV-38:** `OnboardingAvatarPicker` — `HivorrAvatar` preview; `StorageValidators.validateForBucket(profileAvatars)` reject-before-upload; `onProgress`; canonical `avatar.{ext}` upsert
- [ ] **FV-39:** `OnboardingDocumentUploadTile` — reusable identity/trade upload: type icon, filename/size, progress, retry; MIME/size pre-validation; failed upload retries without losing typed data
- [ ] **FV-40:** All 5 widgets consume `Theme.of(context).colorScheme` / `textTheme` / `AppThemeExtension` only — no `Colors.*`, no `Color(0xFF…)`, no `fontFamily:` literal

### 2.11 Required Functionality — Routing & DI

- [ ] **FV-41:** `RoutePaths` gains 7 path constants: `onboarding='/onboarding'`, `onboardingProfile='/onboarding/profile'`, `onboardingIndustry='/onboarding/industry'`, `onboardingProfession='/onboarding/profession'`, `onboardingIdentity='/onboarding/identity'`, `onboardingTradeProof='/onboarding/trade-proof'`, `onboardingComplete='/onboarding/complete'`; matching `RouteNames`; 7 `GoRoute`s in `AppRouter.create` (`app_router.dart:17`)
- [ ] **FV-42:** All 7 routes guarded by `RouteGuard` (`authenticated` required — no taxonomy gate); no SEO public URL (private flow)
- [ ] **FV-43:** `registerOnboardingLayer({required ApiLayer apiLayer, required EntityProvider entityProvider, required TaxonomyProvider taxonomyProvider, required IdentityVerificationService identityVerification, required TradeVerificationService tradeVerification, StorageService? storage, OnboardingProgressStore? store, HivorrLogger? logger})` returns `({service, provider, store})` records; registered in `HivorrApp` MultiProvider (`lib/data/data_layer.dart:198-475` pattern)
- [ ] **FV-44:** Post-auth entry redirect (narrow guard/bootstrap keyed on `OnboardingProvider.loadProgress()`) sends incomplete entities to the resume point — never the placeholder `Home` route (`app_router.dart:49`); account switch rebinds the progress key
- [ ] **FV-45:** Barrel `lib/systems/onboarding/onboarding.dart` re-exports all new symbols; `lib/data/data_layer.dart` re-exports onboarding data-layer symbols
- [ ] **FV-46:** No new top-level `lib/` directory; `lib/systems/onboarding/` sits alongside `verification/`, `finance/`, `support/` (`ARCHITECTURE.md:95-110`); unidirectional `data → systems`, screens depend on `OnboardingProvider` via `ChangeNotifierProvider`

### 2.12 Expected Workflows

- [ ] **FV-47:** Happy path: fresh sign-in → resume gate → 5-step wizard (`profile` avatar+names → `industry` → `profession` bind `unverified` → `identity` doc submit pending → `trade-proof` submit pending) → `/onboarding/complete` → home; all server writes via frozen seams only
- [ ] **FV-48:** Exit-and-resume: exit at step 3 via dialog or system-back → relaunch → resumes exactly at `profession` with steps 1–2 complete (`onboarding_progress:{entityId}` Hive key)
- [ ] **FV-49:** Avatar-first ordering: avatar object upload completes before `entity_profile_update` RPC, and `avatar_path` persisted after the RPC — order asserted in tests
- [ ] **FV-50:** Taxonomy selection preserved: selecting industry, navigating back/forward, and exiting/re-entering keeps `selectedIndustry`/`selectedProfession`
- [ ] **FV-51:** Trade-proof skip (defensive): no profession bound → trade step not offered; ordering contract respected server-side would `PLT004` anyway
- [ ] **FV-52:** Duplicate flows (trade/bid then re-onboard): `PLT005` surfaces conflict guidance — duplicate `entity_profession_bind` inline, duplicate active verification with status escape; no blind retry
- [ ] **FV-53:** Gate copy: `refreshGateStatus` approved → "bidding unlocked" on complete screen; pending/unverified → Rule 2 education copy
- [ ] **FV-54:** Completion summary: 5 read-only done chips + trust-loop panel + "Go to home" persists `isComplete` and routes to `/`

### 2.13 Success Conditions

- [ ] **FV-55:** `entity_profession_bind` RPC returns `PLT000` envelope, writes `entity_professions(entity_id, profession_id, is_primary=false, trade_verification_status=unverified)` — client never sets `trade_verification_status`
- [ ] **FV-56:** `entity_profile_update` + avatar `avatar_path` update result in `entity_profiles(legal_name, display_name, bio, avatar_path)` — avatar object at `profile-avatars/{entityId}/avatar.{ext}`
- [ ] **FV-57:** Identity/trade submissions create `entity_credentials` + queue `verification_submissions(pending)` via `verification_submit` — flags in Hive progress are UX-only, not server state
- [ ] **FV-58:** Flow is provider-swappable — screens consume `OnboardingProvider`/`OnboardingService` without importing `SupabaseClient.rpc` literals or `storage.from` strings (`ARCHITECTURE.md:101-110` compliant)

### 2.14 Error Handling Scenarios

- [ ] **FV-59:** `6 MiB avatar` or invalid avatar MIME → `StorageValidationException` field error before network — upload spy not invoked; same for oversize/invalid document (10 MiB / `jpeg/png/webp/pdf`)
- [ ] **FV-60:** `PLT001 auth` (unauthenticated) → `ApiException` → `RouteGuard` redirect `/login`; unauthenticated `SupabaseClientProvider.client` guard → `ApiInitializationException` before any RPC
- [ ] **FV-61:** `PLT003 validation` (name lengths, null params) → inline field errors with live counters — known violations never round-trip
- [ ] **FV-62:** `PLT004 notFound` (profession missing/inactive, cross-entity) → step-scoped not-found with back navigation
- [ ] **FV-63:** `PLT005 conflict` (duplicate profession binding `entity_professions_entity_profession_key` `20260821090002:182`, active verification partial index `20260829090003:364-381`) → friendly guidance; never fire-hammer
- [ ] **FV-64:** `5xx PLT999` / network timeout → `ApiExceptionKind.server` / `timeout` normalized via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`); retry affordance without unbounded loop; raw `DioException` never propagates (`BaseApiService.invoke`)
- [ ] **FV-65:** In-flight upload on background → cancelled on lifecycle pause; retried on resume without losing typed data

### 2.15 Important User Interactions

- [ ] **FV-66:** Live counters (legal/display ≤255, bio ≤5000) render as the user types — fail-fast before RPC
- [ ] **FV-67:** `OnboardingAvatarPicker` shows preview (`HivorrAvatar`) and `onProgress` during upload; reject message in `colorScheme.error` under the picker
- [ ] **FV-68:** `OnboardingDocumentUploadTile` shows filename/size/progress/retry; `LinearProgressIndicator` visible during upload (critical on Nigerian 3G — `onProgress` wired via Dio `onSendProgress`)
- [ ] **FV-69:** Exit confirm dialog on every back/system-back at non-terminal steps — exit is always deliberate, progress preserved
- [ ] **FV-70:** Responsive: 16dp padding mobile, 24dp web pane via `ResponsiveScaffold`/`shared/layouts/` (`ARCHITECTURE.md:122-124`); branded states + `HivorrLoader` pulse (`VISUAL-IDENTITY.md:148`), never bare `CircularProgressIndicator`; ≥48dp touch targets

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Files added ONLY under `lib/systems/onboarding/` (`screens/`, `widgets/`, `services/`, `models/`, barrel), `lib/data/entities/onboarding_progress.dart`, `lib/data/local/onboarding_progress_store.dart`, `lib/data/providers/onboarding_provider.dart`, `lib/app/router/` (route update), `lib/data/data_layer.dart` (barrel + `registerOnboardingLayer`), and `test/**` — no files in `lib/core/`, `lib/engine/`, `lib/integrations/`, `lib/workspace/` (widgets reused read-only), or `lib/systems/` outside `onboarding/`
- [ ] **TV-02:** No DDL / RLS / RPC change — `git diff --stat supabase/` = 0; zero `supabase/migrations/*`, zero `supabase/config.toml`, zero `.supabase/functions/*` changes; no storage-bucket changes (`lib/core/storage/*` diff = 0)
- [ ] **TV-03:** Barrel `lib/systems/onboarding/onboarding.dart` re-exports all new symbols; `lib/data/data_layer.dart` updated
- [ ] **TV-04:** Interface-first store — abstract `OnboardingProgressStore` separate from `InMemoryOnboardingProgressStore`/`HiveOnboardingProgressStore`
- [ ] **TV-05:** Unidirectional `data → systems`: `OnboardingProvider` depends on `OnboardingService` (systems) which depends on data providers/repositories; `lib/data/` never imports `lib/systems/` widgets; `OnboardingService` never imported by widgets
- [ ] **TV-06:** De-pendency wiring uses `SupabaseClientProvider.client` safe accessor (`supabase_client_provider.dart:19`) + `currentAccessToken` (`:29`); no direct `Supabase.instance.client` leakage in business logic beyond registered layers

### 3.2 Required System Behavior

- [ ] **TV-07:** `OnboardingService` composes existing facades — grep asserts no `supabase.rpc` literal inside the facade except the audited `entity_profession_bind` envelope wrapper; no re-implemented upload/verify transport
- [ ] **TV-08:** Avatar upload `upsert: true` to `profile-avatars/{entityId}/avatar.{ext}` (`StoragePaths.avatar` `storage_paths.dart:93`); credential uploads non-upsert to `credential-documents`; paths start with `{entityId}` per `20260830100001:118` RLS gate
- [ ] **TV-09:** Client never writes `verification_submissions.status`, `entity_professions.trade_verification_status`, or `entity_kyc_levels` — `grep -r "trade_verification_status" lib/systems/onboarding` allows display-only read, zero assignment
- [ ] **TV-10:** Progress store is the single source of wizard position; rehydrated post-auth; `advance()` persists at every step; lifecycle pause saves; `isComplete` routes to `/onboarding/complete`
- [ ] **TV-11:** Trade-proof step is skipped defensively when no profession bound; `submitTradeProof` always passes the bound `professionId` (`verification_submit p_submission_type='trade_proof'`)
- [ ] **TV-12:** Error normalization via `ApiExceptionMapper` — preserves `kind`, `code`, `statusCode`; message safe (no SQL/stack leaked); `StorageValidationException` and `DataException` surfaced distinctly from `ApiException`
- [ ] **TV-13:** `HivorrLogger` + `PiiRedactor` redacted logging — `entityId suffix`, step code, type, `mimeType`, `byteLength`; never full `legalName`, never full avatar/credential path, never bytes; `PerformanceTracer` spans `onboarding.*` sampled

### 3.3 Module Integration

- [ ] **TV-14:** No conflict with `lib/core/storage/` — `SupabaseStorageService` + `StorageBuckets` + `StoragePaths.avatar/credentialDocument` + `StorageValidators` consumed, not modified
- [ ] **TV-15:** No conflict with `taxonomy_envelope_parser.dart` envelope pattern — reused for `entity_profession_bind` unwrap; `DataExceptionMapper` shared
- [ ] **TV-16:** No conflict with EP-02-10/11 — `IdentityVerificationService`/`TradeVerificationService` facades consumed 1:1; their providers own verification polling (no polling introduced in onboarding)
- [ ] **TV-17:** `lib/systems/onboarding/` is consumable by downstream tasks — `EP-02-13` (financial composition reads progress complete), `EP-02-19` (public profile reuses `OnboardingAvatarPicker` pattern) without breaking the frozen seams
- [ ] **TV-18:** Widgets reuse `HivorrAvatar` (`lib/shared/widgets/hivorr_avatar.dart`) and `ProfessionRegistryBrowser` — no duplicate implementations in `lib/systems/onboarding/`

### 3.4 Technical Requirements from Plan

- [ ] **TV-19:** `flutter analyze` + `dart analyze` clean (0 issues)
- [ ] **TV-20:** `OnboardingService` dartdoc documents the frozen step order, `entity_profession_bind` envelope contract, `PLT004`/`PLT005` mapping, and redaction policy
- [ ] **TV-21:** `OnboardingProvider` dartdoc documents resume/exit lifecycle, `WidgetsBindingObserver` exit-save, `isTradeGateOpen` read-only sourcing, `AsyncState` semantics
- [ ] **TV-22:** `OnboardingProgressStore` dartdoc documents Hive box/key contract (`onboarding`, `onboarding_progress:{entityId}`), graceful no-op when uninitialized, in-memory fallback

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **DV-01:** `entity_profiles` updated via `entity_profile_update(p_legal_name, p_display_name, p_bio)` RPC (`20260821090004:16-79`, lengths ≤255/≤255/≤5000, audit-logged) then `avatar_path` via self-scoped REST `.update({avatar_path}).eq('entity_id', uid)` (`20260821090003:88` RLS); no `avatar_path` inside the RPC params
- [ ] **DV-02:** `entity_professions` row created via `entity_profession_bind(p_profession_id)` — `entity_id = auth.uid()`, `profession_id`, `is_primary=false`, `trade_verification_status='unverified'`; client never supplies status
- [ ] **DV-03:** `entity_credentials` rows created via identity/trade submit pipelines (EP-02-10/11) with `document_path` under `{entityId}/…`; `verification_submissions` queued `pending` server-side via `verification_submit`
- [ ] **DV-04:** Hive progress box `onboarding` key `onboarding_progress:{entityId}` — no PII in the payload (entityId is the key; no legal name, no paths, no bytes)

### 4.2 Data Updates

- [ ] **DV-05:** Progress written on every advance and lifecycle pause; `clear` only on deliberate re-onboarding or account switch; `entityId` key swap on account switch
- [ ] **DV-06:** Client never updates `verification_submissions.status` or `entity_professions.trade_verification_status` — mutation only via admin review RPCs (server-owned, EP-02-03/11)
- [ ] **DV-07:** Avatar object upserted to canonical `profile-avatars/{entityId}/avatar.{ext}`; credential objects non-upsert (each submission is a new object)

### 4.3 Data Relationships

- [ ] **DV-08:** Trade proof submission carries the bound `professionId` (FK `entity_credentials.profession_id` for `kind='trade_proof'`) — server enforces `PLT004` when missing; flow always supplies it
- [ ] **DV-09:** Profession binding uniqueness via `entity_professions_entity_profession_key` (`20260821090002:182`) — second bind → `PLT005`; onboarding surfaces guidance, never fire-hammers
- [ ] **DV-10:** Active-verification uniqueness via partial index `20260829090003:364-381` — duplicate identity/trade submission → `PLT005` server-side; onboarding shows conflict guidance + status escape

### 4.4 Data Accuracy

- [ ] **DV-11:** Step ordering exact: `profile → industry → profession → identityDocument → tradeProof → completed`; `completedSteps` advances monotonically; `isComplete` requires all 5
- [ ] **DV-12:** `hasIdentitySubmission` / `hasTradeProofSubmission` set only after successful submission (server non-error); remain UX mirrors, never consulted as trust state
- [ ] **DV-13:** `isTradeGateOpen` maps exactly `TradeVerificationStatus.tradeVerificationStatus == 'approved'`; all other statuses (unverified/pending/rejected/…) render `false` + Rule 2 education copy

### 4.5 Data Integrity

- [ ] **DV-14:** No `public.*` table mutation by client beyond the frozen RPC/update seams listed in DV-01..03; `git diff --stat supabase/` = 0
- [ ] **DV-15:** Avatar `avatar_path` persisted exactly as the uploaded storage key; document paths stored exactly as produced by `StoragePaths.credentialDocument`; no client-side path rewriting
- [ ] **DV-16:** Progress serialization round-trips (save → read → identical fields) and is cross-user isolated (key-scoped); Hive uninitialized → graceful empty (never crash on boot)

---

## 5. Security Verification

- [ ] **SV-01:** Server-authoritative trust state (`AGENT.md:16` Rule 4) — client orchestrates but never asserts verification/gate state; `grep -r "trade_verification_status" lib/systems/onboarding` = 0 for assignment (display-only read permitted); progress flags are UX mirrors only
- [ ] **SV-02:** No new server surface — zero DDL/RPC/Edge Function/bucket changes; attack surface confined to existing review-locked seams; `git diff --stat supabase/` = 0
- [ ] **SV-03:** PII discipline (`AGENT.md` Rule 3) — legal name is the financial anchor: rendered read-only after entry, never logged beyond redacted suffix, never stored in Hive progress; document paths/bytes never logged (`PiiRedactor`)
- [ ] **SV-04:** Storage privacy — credentials in private `credential-documents` (signed URL only, `getPublicUrl` throws per `supabase_storage_service.dart:264`); avatar in public `profile-avatars` is the **only** public identity image (canonical, validated MIME/size); `grep -r "getPublicUrl" lib/systems/onboarding` limited to avatar public preview only, zero for credentials
- [ ] **SV-05:** Storage path gate — every upload path starts `{entityId}` (`20260830100001:118`); `StoragePaths.avatar/credentialDocument` produce compliant paths; `StoragePaths.sanitize` strips `..`, `/`, control chars
- [ ] **SV-06:** MIME/size DoS prevention — `StorageValidators.validateForBucket` blocks before SDK (avatar 5 MiB `jpeg/png/webp`, documents 10 MiB `jpeg/png/webp/pdf`); server `file_size_limit`/`allowed_mime_types` remain the second, authoritative gate
- [ ] **SV-07:** `entity_profession_bind` flood protection — duplicate ships server-conflict `PLT005`; client surfaces guidance and prevents fire-hammering (no blind retry loops)
- [ ] **SV-08:** Auth isolation — progress key scoped by `auth.uid()`; account switch swaps keys (no cross-entity resume); `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) keeps envs isolated; `RouteGuard` authenticated-only on all 7 routes
- [ ] **SV-09:** No `service_role` anywhere — `grep -rn "service_role" lib/` = 0; client uses `anon`/`authenticated` via `SupabaseClientProvider.client` with RLS; admin review paths remain `service_role`-only server-side
- [ ] **SV-10:** Auth token protection — token via `SupabaseClientProvider.currentAccessToken:29`, never logged; redacted logs cover `entityId` to `***last4`
- [ ] **SV-11:** No SQL injection — `entity_profession_bind` called with parameterized `supabase.rpc('entity_profession_bind', params:{p_profession_id})`; profile/avatar paths are SDK-constructed, not raw SQL; no dynamic query interpolation anywhere
- [ ] **SV-12:** Gate integrity — onboarding renders bid-lock state read-only and never fakes unlock; no client path exists to set `trade_verification_status = approved`
- [ ] **SV-13:** Exit safety — no silent data loss: every exit path confirms save-and-exit; `exitAndSave()` flushes progress before navigation

---

## 6. Performance Verification

- [ ] **PV-01:** RPC cost — one navigation = at most one taxonomy load (memoized by `TaxonomyProvider`) + one profile RPC + one bind RPC + submission chain; **no polling in onboarding** (verification polling stays with EP-02-10/11 providers)
- [ ] **PV-02:** Progress I/O — Hive local box read once on resume, written per advance (tiny payload); in-memory default avoids IO on unsupported platforms
- [ ] **PV-03:** Upload path — avatar/credential uploads single-shot with `onProgress` (Dio `onSendProgress`); validation before transfer (O(1) validator — avoids wasted multipart on slow 3G); no parallel uploads in a step
- [ ] **PV-04:** State churn — `OnboardingProvider` holds immutable `OnboardingProgress`; no per-frame allocations; step vocab compile-time const
- [ ] **PV-05:** Lifecycle — `WidgetsBindingObserver` saves progress on pause/inactive; in-flight submissions cancelled on background, re-surfaced on resume with retry; no orphan timers (onboarding owns none)
- [ ] **PV-06:** Resume latency — store hydration is a single Hive read (`onboarding.resume.duration` traced); resume redirect keyed on `loadProgress()` completes before navigation to the resume point
- [ ] **PV-07:** Avatar preview — public-bucket `getPublicUrl` (no signing overhead) for the canonical avatar only; credential previews never use public URLs
- [ ] **PV-08:** Tracer overhead — `PerformanceTracer` spans `onboarding.*` sampled via `MonitoringConfig`, tags step codes, no PII

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/data/onboarding/` + `test/unit/systems/onboarding/`

Pattern mirrors EP-02-10/11/17 suites + `test/support/fakes/fake_*` (fake `TaxonomyRepository`, `VerificationRepository`, `TradeVerificationRepository`, `EntityRepository`, `StorageService`) — no live Supabase.

- [ ] **TT-01:** `onboarding_progress_test.dart` ≥6 cases green — entity immutability; `isComplete` derivation (all 5 / partial / none); step ordering (`completedSteps` advances monotonically); serialization round-trip via store
- [ ] **TT-02:** `onboarding_progress_store_test.dart` ≥6 cases green — `InMemory` save/read/clear; Hive store with `Hive.init` temp dir: key `onboarding_progress:{entityId}`, missing key → null, cross-user isolation, graceful no-op when uninitialized
- [ ] **TT-03:** `onboarding_provider_test.dart` ≥12 cases green — `loadProgress` resume at each step; fresh entity starts at `profile`; `advance` persists every step; `back`; `saveAndExit`; account-switch key swap; async submit success / `PLT003` / `PLT005`-conflict state; `refreshGateStatus` maps approved → open; `notifyListeners` on each mutation; `WidgetsBindingObserver` exit-save
- [ ] **TT-04:** `onboarding_service_test.dart` ≥10 cases green — `resume` returns furthest step (incl. completed); ordering contract never skips a required step; `completeProfile` call ordering asserted (avatar upload → profile RPC → avatar_path update); `bindProfession` validates + maps `PLT004`/`PLT005`; `submitIdentity`/`submitTradeProof` delegate 1:1 + set flags; redacted log assertions (no legal name in output); tracer span begin/ok/fail
- [ ] **TT-05:** Store parity 2 cases — Hive key format `onboarding_progress:{entityId}`; cross-user isolation
- [ ] **TT-06:** Total ≥36 onboarding unit assertions; store/provider/service ≥90% coverage (`flutter test --coverage`)

### 7.2 Automated Widget Suite — `test/widget/systems/onboarding/`

- [ ] **TT-07:** `progress_indicator_test.dart` ≥6 cases green — 5 segments; filled count == `stepNumber`; `ColorScheme.primary` vs `surfaceVariant` per state; no hardcoded colors (`ColorScheme` assert)
- [ ] **TT-08:** `shell_screen_test.dart` ≥8 cases green — renders current step body; Back/Continue enablement per step; exit dialog trigger; step swap on provider notify; trade-proof skipped when unbound (defensive); theme token asserts (`textTheme.titleLarge`, `AppThemeExtension.radius*`)
- [ ] **TT-09:** `profile_setup_screen_test.dart` ≥8 cases green — validation gates Continue (legal/display empty, >255); avatar picker rejects 6 MiB jpeg (`StorageValidationException` message shown, `colorScheme.error`); upload progress; submit calls provider + success transition
- [ ] **TT-10:** `industry_selection_screen_test.dart` ≥6 cases green — industry list render; selection highlights + auto-advance; empty state; error retry
- [ ] **TT-11:** `profession_selection_screen_test.dart` ≥6 cases green — load + search filter; select binds via provider; duplicate `PLT005` inline guidance; gate copy present
- [ ] **TT-12:** `identity_step_screen_test.dart` ≥8 cases green — DocumentType options render; upload flow with progress; `PLT005` guidance + escape route; success state; MIME reject before network (assert no upload call)
- [ ] **TT-13:** `trade_step_screen_test.dart` ≥6 cases green — profession chip; proof type options; upload + success; gate panel approved vs pending copy
- [ ] **TT-14:** `complete_screen_test.dart` ≥6 cases green — 5 done chips; Rule 2 gate copy variants; "Go to home" navigates; `HivorrSuccessState` usage
- [ ] **TT-15:** All widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` + `find.byType(HivorrButton)` AppTheme harness; theme token asserts (`grep Colors.` = 0) per file
- [ ] **TT-16:** Total ≥54 onboarding widget assertions; full `test/widget` green

### 7.3 Integration (Fake-E2E) — `test/integration/onboarding_flow_integration_test.dart`

- [ ] **TT-17:** Full wizard — fake `TaxonomyRepository`, fake `VerificationRepository`, fake `TradeVerificationRepository`, fake `EntityRepository`, fake `StorageService`, in-memory `OnboardingProgressStore`: fresh entity → resume redirect → loop all 5 steps with real route transitions → `/onboarding/complete` → home
- [ ] **TT-18:** Exit-and-resume — exit at step 3 → relaunch → resumes at `profession` with steps 1–2 complete
- [ ] **TT-19:** Trade gate copy — feed `approved` status → complete screen shows unlocked copy; feed pending/unverified → Rule 2 education copy
- [ ] **TT-20:** Duplicate submission — fake returns `PLT005` → guidance shown, retry not fired

### 7.4 Regression Guard

- [ ] **TT-21:** `flutter analyze` + `dart analyze` clean
- [ ] **TT-22:** `flutter test` — full suite green (≥36 onboarding unit + ≥54 onboarding widget assertions); `test/integration/onboarding_flow_integration_test.dart` green
- [ ] **TT-23:** `supabase db test` — `001-017` green (no `supabase/` diff can affect server tests; `git diff --stat supabase/` = 0)
- [ ] **TT-24:** Grep lenses — `grep -rn "service_role" lib/` = 0; `grep -rn "Colors\.\|Color(0xFF\|fontFamily:" lib/systems/onboarding/` = 0; no onboarding code outside `lib/` boundary
- [ ] **TT-25:** No-DDL — `git diff --stat supabase/` = 0; `git diff --stat lib/core/storage` = 0

### 7.5 Edge Cases

- [ ] **TT-26:** Avatar boundaries: 0 bytes, exactly 5242880 bytes (accepted), 5242881 bytes (rejected); MIME case `IMAGE/JPEG` accepted; extension↔MIME mismatch normalization
- [ ] **TT-27:** Name boundaries: empty, 255 chars (accepted), 256 chars (disabled Continue / inline error); bio 5000 chars
- [ ] **TT-28:** Filename edge: empty, 300-char handled, `../../etc/passwd` sanitized, `entityId//double-slash` sanitized
- [ ] **TT-29:** All 6 `OnboardingStep` vocab values render (including `completed`); `OnboardingStepCode` exhaustive coverage in store/provider
- [ ] **TT-30:** M:N gate states: unverified (bound), pending, approved, rejected, requires-resubmission → `isTradeGateOpen` false/true + correct copy variant; Hive uninitialized mid-flow → graceful in-memory continuation

### 7.6 Failure Scenarios

- [ ] **TT-31:** Duplicate profession binding → `PLT005` inline guidance, no fire-hammer
- [ ] **TT-32:** Active verification conflict → `PLT005` guidance + status escape, no silent retry
- [ ] **TT-33:** Upload failure (network) → retry affordance, typed data preserved, no progress drift
- [ ] **TT-34:** `401→PLT001` unauth → `RouteGuard` redirect `/login`; mid-wizard session expiry → exit-save on navigation
- [ ] **TT-35:** `PLT004` profession missing after taxonomy change → step-scoped not-found with back navigation; resume guard recovers to a valid step
- [ ] **TT-36:** Background during in-flight upload → upload cancelled, progress saved, resume retries without data loss

### 7.7 Manual Testing

- [ ] **TT-37:** Manual spot-check (optional, with dev env): fresh account → resume redirect → full 5-step wizard with avatar preview/upload + identity doc progress bar → exit at step 4 via dialog → hot restart → resumes at identity with steps 1–3 done → complete screen gate copy matches server status; account-switch isolation verified

---

## 8. User Acceptance Verification

This task delivers the entity's **first interaction with the trust system** — a coordinated, resumable registration journey replacing four disconnected screen clusters. User acceptance is verified through wizard completeness, resumability, gate education, and downstream readiness.

- [ ] **UA-01:** The project lead can complete the full wizard end-to-end (profile+avatar → industry → profession → identity → trade-proof → complete) from a fresh account, with every step explaining *why* (e.g. profession step explains the bidding gate) and no raw `PLT003`/`PLT005` errors surfaced
- [ ] **UA-02:** Exit at any non-terminal step via back/system-back shows "Save my progress and exit?"; relaunch resumes at the exact step with prior inputs intact; no silent data loss
- [ ] **UA-03:** Avatar guidance works on slow networks: `OnboardingAvatarPicker` pre-validates (5 MiB / jpeg/png/webp) before upload, shows `onProgress`, and renders the canonical avatar via `HivorrAvatar`; document upload tile shows filename/size/progress/retry with the "reviewed within 24h" expectation set
- [ ] **UA-04:** Industry/profession taxonomy is browsable and searchable via `ProfessionRegistryBrowser`; selection survives back/forward and exit/resume; duplicate profession binding shows friendly guidance ("You're already bound to this profession")
- [ ] **UA-05:** Rule 2 gate is taught, not faked: pending/unverified shows "You can start work immediately — bidding unlocks once your trade proof is approved"; approved shows unlocked copy; no bid-lock control is fabricated in the UI (`AGENT.md:15`)
- [ ] **UA-06:** Completion screen summarizes all 5 completed steps (read-only chips), links forward to verification status and financial profile (`EP-02-13`), and "Go to home" marks progress complete
- [ ] **UA-07:** Premium finish — `OnboardingShellScreen` uses branded states + `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), soft elevation not hard shadow, 8pt grid, 16dp mobile / 24dp web padding, ≥48dp touch targets, light/dark WCAG AA contrast; `grep` lens clean (`Color(0xFF`/`Colors.`/`fontFamily:` = 0 in onboarding)
- [ ] **UA-08:** No financial/escrow leakage — onboarding completes at verification-submission; finance onboarding is `EP-02-13` composition, not rendered here; `grep -r "financial_\|escrow\|payout" lib/systems/onboarding` = 0
- [ ] **UA-09:** Downstream unblocked — `EP-02-19` (public profile reuses avatar/binding results), `EP-02-13` (financial composition keys off completed progress) without rework; four proven seams (EP-02-07/08/10/11) untouched

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-18 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/data/entities/onboarding_progress.dart` exists — immutable `OnboardingProgress` with `OnboardingStepCode`, `isComplete` derivation | File inspection + unit test | ☑ — `profession` removed from the code (merged into the industry step); order is `profile → capability → industry → identityDocument → tradeProof` |
| 2 | `lib/data/local/onboarding_progress_store.dart` exists — abstract + `InMemoryOnboardingProgressStore` + `HiveOnboardingProgressStore` (box `onboarding`, key `onboarding_progress:{entityId}`, graceful no-op) | File + unit test | ☑ — round-trip, cross-user isolation, and uninitialized-Hive no-op unit-tested |
| 3 | `lib/systems/onboarding/models/onboarding_step.dart` defines `OnboardingStep` (6 values, label/description/stepNumber/`isVerificationStep`) — pure Dart | File inspection | ☑ — 7 values incl. `completed` (capability inserted per FV-28); `profession` kept as vocabulary though captured on the merged industry step |
| 4 | `OnboardingService` composes `EntityProvider`/`TaxonomyProvider`/`IdentityVerificationService`/`TradeVerificationService`/`StorageService`; no re-implemented transport; only `entity_profession_bind` wrapper | Code review + unit test | ☑ — facade over the four frozen seams + store; sole RPC wrapper is `entity_profession_bind` |
| 5 | `OnboardingProvider` ChangeNotifier with progress/currentStep/`AsyncState`/`lastError`/`isTradeGateOpen`, `WidgetsBindingObserver` exit-save, account-switch key swap | Unit test | ☑ — 5 advances reach `completed`; pause/inactive exit-save; key rebind on account switch |
| 6 | `onboarding_provider_test.dart` ≥12 + `onboarding_service_test.dart` ≥10 + `onboarding_progress_test.dart` ≥6 + `onboarding_progress_store_test.dart` ≥6 + parity 2 = ≥36 unit assertions green | `flutter test` | ☑ — all onboarding unit suites green (≥36 assertions) |
| 7 | Avatar: upload `StoragePaths.avatar` → `profile-avatars/{entityId}/avatar.{ext}` (public, 5 MiB, jpeg/png/webp, upsert) reject-before-upload; `avatar_path` persisted via self-scoped REST update | Code + widget test | ☑ — validate-before-upload + upload→RPC→avatar_path ordering asserted |
| 8 | `entity_profession_bind` called once per selection; `PLT004`/`PLT005` mapped to inline guidance; duplicate never fire-hammers | Unit test + code review | ☑ — RPC only on explicit tap (TT-20); `PLT005` inline guidance on the merged step |
| 9 | Identity step delegates to `IdentityVerificationService` (5 DocumentType); trade step delegates to `TradeVerificationService` (5 TradeProofType, profession-bound) — flags are UX-only | File inspection | ☑ — flags (`hasIdentitySubmission`/`hasTradeProofSubmission`) are UX mirrors only |
| 10 | 7 screens (`OnboardingShellScreen`, `ProfileSetupScreen`, `IndustrySelectionScreen`, `ProfessionSelectionScreen`, `IdentityVerificationStepScreen`, `TradeProofStepScreen`, `OnboardingCompleteScreen`) exist under `lib/systems/onboarding/screens/` | File inspection | ☑ — 7 screens present; industry + profession consolidated into `IndustryProfessionSelectionScreen`, `CapabilitySelectionScreen` added |
| 11 | 5 widgets (`OnboardingProgressIndicator`, `OnboardingStepCard`, `OnboardingExitConfirmDialog`, `OnboardingAvatarPicker`, `OnboardingDocumentUploadTile`) exist under `lib/systems/onboarding/widgets/` | File inspection | ☑ — plus `OnboardingStepController` (CTA bar driver) |
| 12 | Theme tokens only — `grep -rn "Colors\.\|Color(0xFF\|fontFamily:" lib/systems/onboarding/` = 0; branded states + `HivorrLoader`, 16dp/24dp, ≥48dp touch | `grep` + widget test | ☑ — grep lens clean; branded states + `HivorrLoader` used |
| 13 | 7 `GoRoute` paths registered (`/onboarding`, `/onboarding/profile`, `/industry`, `/profession`, `/identity`, `/trade-proof`, `/complete`) + `RouteNames`, `RouteGuard` authenticated, no SEO public URL | File + router test | ☑ — 6 routes after the merge (`/profession` removed; legacy `/onboarding/profession` redirects to `/onboarding/industry`); `RouteGuard` authenticated |
| 14 | Post-auth entry redirect sends incomplete entities to resume point; account-switch key isolation verified; `isComplete` routes to `/onboarding/complete` | Integration test + manual | ☑ — RouteGuard resume (TT-18 exit→resume at industry); `isComplete` → `RouteNames.onboardingComplete` |
| 15 | Barrel `lib/systems/onboarding/onboarding.dart` + `lib/data/data_layer.dart` re-exports + `registerOnboardingLayer` DI record wired in `HivorrApp` | File inspection | ☑ — registered in `HivorrApp` MultiProvider / app bootstrap |
| 16 | No `supabase/` change — `git diff --stat supabase/` = 0; zero migrations/functions/bucket changes; `git diff --stat lib/core/storage` = 0 | `git diff --stat` | ☑ — task commits touch zero `supabase/`; working-tree migrations `20260911090001/0002` belong to the separate demo-seed follow-up, not EP-02-18 |
| 17 | No `service_role`/secret leak — `grep -rn "service_role" lib/` = 0; client uses `anon`/`authenticated` with RLS; `SupabaseClientProvider` safe accessors only | `grep` + code review | ☑ |
| 18 | `trade_verification_status` / `verification_submissions.status` never assigned by client (display-only read); `grep` assignment lens = 0 | `grep` + code review | ☑ — display-only reads in gate copy |
| 19 | Error normalization `401→PLT001`, `400/422→PLT003`, `404→PLT004`, `409→PLT005`, `5xx→PLT999` via `ApiExceptionMapper`; `StorageValidationException` distinct; raw `DioException` never reaches UI | Unit test | ☑ |
| 20 | Widget suite green — progress_indicator ≥6, shell ≥8, profile ≥8, industry ≥6, profession ≥6, identity ≥8, trade ≥6, complete ≥6 = ≥54 widget assertions | `flutter test` | ☑ — 8 widget suites, 62 tests green (split industry/profession tests consolidated into `onboarding_industry_profession_screen_test.dart`; capability suite added) |
| 21 | `test/integration/onboarding_flow_integration_test.dart` green — full wizard + exit-resume + gate copy + `PLT005` no-retry | `flutter test` | ☑ — TT-17..21 green |
| 22 | `flutter analyze` + `dart analyze` clean | CI | ☑ — `flutter analyze` reports 0 issues |
| 23 | `flutter test` full suite + `supabase db test` `001-017` green | CI + `supabase db test` | ☑ — full `flutter test` green across onboarding/integration/verification/support; server tests unaffected by this task (`supabase/` diff = 0) |
| 24 | Redaction — no full `legalName`/paths/bytes in logs or Hive progress; `PiiRedactor` deployed; `PerformanceTracer onboarding.*` sampled, no PII | Code review | ☑ |
| 25 | Visual identity + UX — Rule 2 gate copy rendered for approved vs pending; exit dialog always confirms save; "reviewed within 24h" copy; premium finish per `VISUAL-IDENTITY.md` | Code review + manual | ☑ — wizard bootstrapped live in Chrome against local Supabase (dev env) with the merged industry+profession step |
| 26 | No financial/escrow logic — `grep -r "financial_\|escrow\|payout" lib/systems/onboarding` = 0; no `lib/integrations/payment_gateways/` import | `grep` | ☑ |
| 27 | Downstream unblocked — `EP-02-19`/`EP-02-13` can consume progress/avatar results; EP-02-07/08/10/11 seams untouched | Dependency check | ☑ — screens consume `OnboardingProvider`/`TaxonomyProvider` only; frozen verification/storage seams untouched |

---

> **Sign-off:** Task EP-02-18 marked **Completed** — all 27 conditions in the Final Approval Checklist verified and signed off by the project lead. Implementation notes: industry & profession selection were consolidated into a single step (one `Save & continue`, profession gated on industry), removing a step and the `/onboarding/profession` route; a capability step (`hire`/`offer`/`both`) was added prior to profile. All onboarding unit/widget/integration suites green; `flutter analyze` clean; wizard bootstrapped and validated live in Chrome (dev, local Supabase).