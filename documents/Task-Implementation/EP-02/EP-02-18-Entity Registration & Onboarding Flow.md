# Task Implementation Plan — EP-02-18: Entity Registration & Onboarding Flow

**Task ID:** EP-02-18 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Completed | **Priority:** High | **Dependencies:** EP-02-07, EP-02-10, EP-02-11, EP-02-08 | **Stage:** 4 — Trust & Verification Systems

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:434-443` | Architecture: `documents/Context/ARCHITECTURE.md:55-60,95-110,131-138`, `documents/Context/AGENT.md:15-17` | Stack: `pubspec.yaml:43-53` (`dio 5.11.0`, `supabase_flutter 2.17.2`, `provider 6.1.5`, `go_router`, `hive: ^2.2.3` :66) | Storage: `lib/core/storage/storage_service.dart`, `storage_paths.dart`, `storage_config.dart` | Taxonomby: `lib/data/providers/taxonomy_provider.dart`, `lib/workspace/profession_registry/` | Verification: `lib/systems/verification/services/identity_verification_service.dart`, `trade_verification_service.dart`

---

## 1. Objective

Build the end-to-end **entity registration & onboarding flow** in a new `lib/systems/onboarding/` system — the first thing a newly-registered, just-signed-in entity experiences after authentication (EP-01). The flow is a multi-step wizard that guides the entity through five structured steps per `EP-02:438`:

1. **Profile completion** — legal name, display name, bio, optional avatar upload (`profile-avatars` bucket).
2. **Industry selection** — from the `TaxonomyProvider` (EP-02-07) two-tier registry (Industry → Profession).
3. **Profession selection** — binding via `entity_profession_bind` (lands as `trade_verification_status = unverified`, `AGENT.md:15` Rule 2).
4. **Identity document upload** — via the EP-02-10 `IdentityVerificationService` (private `credential-documents` upload → `entity_credentials` → `verification_submit`).
5. **Trade proof upload (professional role)** — via the EP-02-11 `TradeVerificationService` (per-profession proof → `verification_submit` with `submission_type = trade_proof`).

The flow includes a **progress indicator**, form validation, and **resumability** (Hive-backed progress store — the entity can exit at any step and return without losing work), GoRouter route integration, and an explicit completion screen that teaches the bidirectional trust loop (work immediately as an unverified pro; bidding unlocks when `tradeVerificationStatus == approved`).

Deliverables:
- Data layer: `OnboardingProgress` entity + `OnboardingProgressStore` (Hive-backed, `lib/data/local/`), `OnboardingProvider` (ChangeNotifier, `lib/data/providers/`).
- Orchestration: `OnboardingService` facade in `lib/systems/onboarding/`.
- UI: 7 screens (`OnboardingShellScreen`, `ProfileSetupScreen`, `IndustrySelectionScreen`, `ProfessionSelectionScreen`, `IdentityVerificationStepScreen`, `TradeProofStepScreen`, `OnboardingCompleteScreen`) + 3+ widgets (`OnboardingProgressIndicator`, `OnboardingStepCard`, `OnboardingExitConfirmDialog`) in `lib/systems/onboarding/screens/` + `widgets/`.
- Routes: `/onboarding/*` (7 GoRoutes) in `lib/app/router/app_router.dart:17` (private authenticated flow, no SEO URL).
- Barrel: `lib/systems/onboarding/onboarding.dart` (new) + `lib/data/data_layer.dart` re-exports + `registerOnboardingLayer` DI factory.
- Unit + widget + integration test suite (fake `TaxonomyRepository`/`VerificationRepository`/`TradeVerificationRepository`/`EntityRepository`/`StorageService`).

**Zero** `supabase/migrations/*`, **zero** RPCs, **zero** Edge Functions, **zero** bucket changes — pure client-side composition of four proven seams (EP-02-07/08/10/11) plus the EP-01 entity-profile seam. `git diff --stat supabase/` must be `0`.

## 2. Business Problem Being Solved

`EP-02:434-443` assigns EP-02-18 as the entity's **first interaction with the trust system**. The server infrastructure for every step already exists and is frozen:

- EP-01-06 entity profile: `entity_profiles` table + `entity_profile_update(p_legal_name, p_display_name, p_bio)` RPC (`20260821090004_entity_model_rpcs.sql:16-79`) + self-scoped `entity_profiles_authenticated_update` RLS (`20260821090003_entity_model_rls_policies.sql:88`); `EntityProfile.avatar_path` column exists (`entity_profile.dart:24`).
- EP-02-07 taxonomy: `TaxonomyProvider` (`lib/data/providers/taxonomy_provider.dart:31`) already holds `selectedIndustry`/`selectedProfession` across navigation, explicitly documented for onboarding (`line 29`).
- EP-02-03/10 identity: `IdentityVerificationService.submitIdentityDocument(...)` (`identity_verification_service.dart:43`) + `DocumentType` vocabulary (`document_type.dart`).
- EP-02-03/11 trade: `TradeVerificationService.submitTradeProof(...)` (`trade_verification_service.dart:45`) + `TradeProofType` vocabulary (`trade_proof_type.dart`).
- EP-02-08 storage: `StoragePaths.avatar(entityId, ext)` (`storage_paths.dart:93`) canonical `profile-avatars/{entityId}/avatar.{ext}` object + `credential-documents` private bucket (10 MiB, `jpeg/png/webp/pdf`).
- Profession binding: `entity_profession_bind(p_profession_id)` RPC (`20260821090004_entity_model_rpcs.sql:202`) — validates profession exists/active, lands `trade_verification_status = unverified`, duplicate binding → `PLT005`.

**No orchestration exists.** Without EP-02-18:

- Every new entity lands on the placeholder `Home` route (`app_router.dart:49`) with no structured first-run path — profile, profession binding, and verification submission each remain hidden single-purpose screens with no shared progress narrative (`EP-02:438` "multi-step wizard" is unimplemented).
- There is no **resumability** — a partially-filled registration is lost on app close; the entity must hunt down four separate screen clusters (`/verification/*`, taxonomy, profile) and re-enter everything manually.
- There is no **ordering contract** — nothing guarantees profile → industry → profession happens before trade-proof submission (trade proof requires a bound `professionId`, so step order matters and is server-enforced at `PLT004` when missing).
- There is no **trade-proof gating education** — `AGENT.md:15` Rule 2 ("Unverified pros receive dashboard access immediately, but job bidding/accepting is locked until `tradeVerificationStatus == APPROVED`") is a server contract but the client never surfaces it, so unverified entities do not know why bidding is locked.
- Every screen cluster would hand-roll progress persistence, duplicating Hive/`shared_preferences` access and fracturing the EP-01-11 storage boundary.

This task is the **Stage 4/5 orchestration seam** that turns four proven, independent verification systems into one coherent, resumable registration experience while keeping all proprietary logic server-side.

## 3. Scope

| In Scope | Detail |
|---|---|
| `OnboardingProgress` entity + `OnboardingProgressStore` | `lib/data/entities/onboarding_progress.dart` + `lib/data/local/onboarding_progress_store.dart`. Immutable entity: `entityId?`, `step` (enum, 5 steps + completed), per-step `isComplete`, `completedSteps` (ordered list), `hasIdentitySubmission`, `hasTradeProofSubmission`, `updatedAt`. Store abstraction with Hive-backed impl (`OnboardingProgressHiveStore`) persisting under box key `onboarding_progress:{entityId}`; in-memory impl for tests/unsupported platforms; graceful no-op when Hive unavailable |
| `OnboardingStep` enum | `lib/systems/onboarding/models/onboarding_step.dart` — `profile, industry, profession, identityDocument, tradeProof, completed` with `label`, `description`, `stepNumber`, and `isVerificationStep` flag (identity + trade); pure Dart, no DTO leakage |
| `OnboardingService` facade (`lib/systems/onboarding/services/`) | Composes `EntityProvider` (profile update), `TaxonomyProvider` (industry/profession selection), `IdentityVerificationService` (identity doc), `TradeVerificationService` (trade proof), `StorageService` (avatar upload) and the progress store. Exposes `currentStep`, `advance()`, `exitAndSave()`, `resume()`, `completeProfile(...)`, `bindProfession(...)`, `submitIdentity(...)`, `submitTradeProof(...)`, `isResumable()`. Adds `HivorrLogger` redacted logs + `PerformanceTracer` spans |
| `OnboardingProvider` (ChangeNotifier) `lib/data/providers/onboarding_provider.dart` | `OnboardingProgress progress`, `OnboardingStep currentStep`, `AsyncState submitState`, `ApiException? lastError`, `bool? tradeGateOpen` (from `TradeVerificationStatus.tradeVerificationStatus == approved`). `loadProgress()`, `advance()`, `back()`, `exit()`, `resume()`, `completeProfile({...})`, `submitIdentityDocument({...})`, `submitTradeProof({...})` — internal `notifyListeners()`, `WidgetsBindingObserver` lifecycle for graceful exit-save |
| Avatar upload | `StoragePaths.avatar(entityId, ext)` (`storage_paths.dart:93`) → `StorageBuckets.profileAvatars` (public-read, 5 MiB, `jpeg/png/webp` — `storage_config.dart:39,66,97`) via `StorageService.upload(upsert: true)`; upload before profile save; resulting path persisted to `entity_profiles.avatar_path` via the existing self-scoped REST update path (RLS `entity_profiles_authenticated_update`) |
| Profile completion step | Uses `EntityProvider.updateProfile({entityId, legalName, displayName, bio})` (`entity_provider.dart:60`) → `entity_profile_update` RPC. Avatar upload precedes the RPC; the RPC itself accepts no avatar param, so `avatar_path` is written via the self-scoped `entity_profiles` update grant after the RPC (validated at build time against the migration grant) |
| Industry selection step | Reuses `TaxonomyProvider.loadIndustries()`, `selectIndustry(id)` — fires `taxonomy_industries_list`; selection preserved across navigation (`taxonomy_provider.dart:29`) |
| Profession selection step | Reuses `TaxonomyProvider.loadProfessions(industryId)`, `selectProfession(p)`, `filteredProfessions` + the `ProfessionRegistryBrowser` widget (`lib/workspace/profession_registry/widgets/profession_registry_browser.dart:24`). On selection/continue → `entity_profession_bind(p_profession_id)` via `OnboardingService` (new RPC wrapper inside the facade's composition, audited — or reused repository path if a binding repository exists) |
| Identity verification step | Delegates to `IdentityVerificationService.submitIdentityDocument(documentType, bytes, mimeType, fileName, onProgress)` — 5 `DocumentType` values; private `credential-documents` upload at `StoragePaths.credentialDocument(...)`; `verification_submit` queue; `PLT005` duplicate-active surfaces as inline guidance |
| Trade proof step (conditional) | `TradeProofVerificationStepScreen` shown only when a profession is selected (always in this flow — profession is step 3). Delegates to `TradeVerificationService.submitTradeProof(type, professionId: selectedProfession.id, bytes, mimeType, fileName, onProgress)` — 5 `TradeProofType` values; `submission_type = trade_proof`; proof bound to the selected profession |
| UI screens | `OnboardingShellScreen` (hosts `OnboardingProgressIndicator` + step routing), `ProfileSetupScreen`, `IndustrySelectionScreen`, `ProfessionSelectionScreen`, `IdentityVerificationStepScreen`, `TradeProofStepScreen`, `OnboardingCompleteScreen` — all responsive via `shared/layouts/`, tokens via `AppColors`/`AppThemeExtension` (`lib/app/theme/app_colors.dart:16`), branded primitives + `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`) |
| UI widgets | `OnboardingProgressIndicator` (5-step linear progress), `OnboardingStepCard` (step title/description/state), `OnboardingExitConfirmDialog` (exit-and-save confirmation), `OnboardingAvatarPicker` (image pick → validate `StorageConfig` → preview → upload), `OnboardingDocumentUploadTile` (reusable identity/trade upload with `onProgress`) |
| Routes | `/onboarding` (redirect/landing), `/onboarding/profile`, `/onboarding/industry`, `/onboarding/profession`, `/onboarding/identity`, `/onboarding/trade-proof`, `/onboarding/complete` — `RoutePaths` + `RouteNames` + `GoRoute` in `lib/app/router/`, guarded by `RouteGuard` (authenticated required); no taxonomy gate, no SEO public URL |
| Barrel + DI | `lib/systems/onboarding/onboarding.dart` (new) + `lib/data/data_layer.dart` re-exports + `registerOnboardingLayer(ApiLayer, {required providers...})` factory |
| Tests | Unit (store + provider + service + step ordering), widget (screens + progress indicator + theme compliance), integration (mock-heavy stack, fake `SupabaseClient`/repos driving the full wizard) |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL / RLS / RPC creation or modification | All seams frozen (`20260821090004` profile RPCs, `20260829090002` taxonomy, `20260829090003` verification, `20260830100001` buckets). This task is `lib/` only. `git diff --stat supabase/` = 0 |
| `entity_profession_bind` changes or status flows | Server-owned. Binding lands `unverified`; `pending/approved` moves only through the EP-02 admin gate. Client never touches `trade_verification_status` columns |
| Trade-verification admin review, bid-lock UI, or gate screens | `EP-02-11` completed; this task only *submits* the proof and *reports* gate status (approved = bidding unlocked) |
| KYC tier/level changes, provider adapters (SmileID/Dojah), limit display | `EP-02-12` — onboarding *triggers* tier assignment via identity approval; it does not manage KYC |
| Financial profile, escrow, payout creation from onboarding | `EP-02-13/14/16` — onboarding completes at verification-submission; finance onboarding is out of scope (future composition) |
| Public professional profile / portfolio display | `EP-02-19` — `/p/:slug/:id` not in this task |
| New storage bucket or Edge Functions (avatar thumbnailing, virus scan) | Deferred; canonical avatar object + existing validators suffice |
| Offline upload queueing (`lib/core/sync/`) | Uploads are online-only; resumability is *progress* persistence, not offline action queueing |
| Changing `DocumentType`/`TradeProofType` vocabularies | Reused as-is from EP-02-10/11 |
| Multi-profile / multi-profession management UI | Onboarding binds one profession; multi-binding is a profile feature (`EP-02-19`) |
| Any hardcoded business logic in UI components | All vocabulary/validation/ordering via `OnboardingService`/providers |
| Creating files outside `lib/`, `test/`, and `documents/Task-Implementation/EP-02/` | Scope boundary |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/onboarding/` vs `lib/data/`

`ARCHITECTURE.md:55-60,95-110,131-138` assigns `lib/data/` = DTO/entity/repository/provider and `lib/systems/<name>/` = business systems. The onboarding system straddles the existing systems it orchestrates. Rules:

- **Data layer** (`lib/data/`) owns the resumability entity + store (`OnboardingProgress`, `OnboardingProgressStore`) and the `OnboardingProvider` state machine — reusable, no widgets import.
- **Systems layer** (`lib/systems/onboarding/`) owns the wizard orchestration (`OnboardingService`, `OnboardingStep` vocabulary), screens, and widgets. It *composes* existing facades (`EntityProvider`, `TaxonomyProvider`, `IdentityVerificationService`, `TradeVerificationService`, `StorageService`) — it does **not** re-implement their transport.
- **Unidirectional** `data → systems`: `OnboardingProvider` depends on `OnboardingService` (systems) which depends on data providers/repositories; screens depend on `OnboardingProvider` via `provider:6.1.5` `ChangeNotifierProvider`.

No new top-level `lib/` directory. No `.supabase/functions/`. No `supabase/migrations/*` change. `lib/systems/onboarding/` is a new barrel alongside `verification/`, `finance/`, `support/` (`ARCHITECTURE.md:95-110`).

### 5.2 Server-Side Contract (Frozen — Read-Only Reference)

All seams are inherited and must be referenced, never modified:

| Seam | Reference | Client path |
|---|---|---|
| `entity_profile_update(p_legal_name, p_display_name, p_bio)` | `20260821090004_entity_model_rpcs.sql:16-79` — validates lengths (legal/display ≤255, bio ≤5000), audit-logged | `EntityProvider.updateProfile` → `supabase.rpc('entity_profile_update')` (`supabase_entity_remote_data_source.dart:51-71`) |
| `entity_profiles.avatar_path` (self-scoped update) | `entity_profile.dart:24`, `20260821090003_entity_model_rls_policies.sql:88` | REST `.update({avatar_path})` `.eq('entity_id', uid)` after avatar object upload |
| `entity_profession_bind(p_profession_id)` | `20260821090004_entity_model_rpcs.sql:202-257` — validates existence/active, `PLT004` missing, `PLT005` duplicate, lands `unverified` | `OnboardingService.bindProfession` → `supabase.rpc('entity_profession_bind')` (envelope unwrap) |
| `taxonomy_industries_list` / `taxonomy_professions_list` | `20260829090002_taxonomy_management_rpcs.sql:35,64` | `TaxonomyProvider.loadIndustries` / `loadProfessions` (existing) |
| Identity submit chain | `20260829090003_verification_admin_review_schema.sql:115-406` (tables) + `verification_submit` | `IdentityVerificationService.submitIdentityDocument` (existing EP-02-10) |
| Trade submit chain | same schema, `submission_type = trade_proof`, profession-bound | `TradeVerificationService.submitTradeProof` (existing EP-02-11) |
| Storage buckets | `20260830100001_storage_buckets.sql`, `storage_config.dart` | `StorageService.upload` — `profile-avatars` (public, 5 MiB, jpeg/png/webp, `avatar.{ext}` canonical) + `credential-documents` (private, 10 MiB, jpeg/png/webp/pdf) |

**Error envelope:** all RPCs return `{success, code, message, data}`; `PLT000` success, `PLT001` auth, `PLT003` validation, `PLT004` not found, `PLT005` conflict, `PLT999` internal. Client unwraps via the existing `TaxonomyEnvelopeParser` pattern.

### 5.3 Data Layer Contract

```dart
// lib/data/entities/onboarding_progress.dart
enum OnboardingStepCode { profile, industry, profession, identityDocument, tradeProof }

class OnboardingProgress {
  final String entityId;
  final OnboardingStepCode step;           // furthest step reached (resume point)
  final Set<OnboardingStepCode> completedSteps; // ordered by definition
  final bool hasIdentitySubmission;
  final bool hasTradeProofSubmission;
  final DateTime updatedAt;

  bool get isComplete; // all 5 steps completed
}
```

```dart
// lib/data/local/onboarding_progress_store.dart
abstract class OnboardingProgressStore {
  OnboardingProgress? read(String entityId);
  Future<void> save(OnboardingProgress progress);
  Future<void> clear(String entityId);
}

class InMemoryOnboardingProgressStore implements OnboardingProgressStore { ... }

class HiveOnboardingProgressStore implements OnboardingProgressStore {
  // box: Hive.box<Map>('onboarding'), key 'onboarding_progress:{entityId}'
  // graceful when Hive not initialized -> falls back to no-op/empty
}
```

- Immutable entity, no `json` cycle in entities (DTO/mapper only if persistence needs a serializable form — use a private `Map` store serialization inside the Hive impl).
- `OnboardingProvider` (`lib/data/providers/onboarding_provider.dart`): constructor injection `({required OnboardingService service, HivorrLogger? logger})` for testability; mirrors `TaxonomyProvider`/`VerificationProvider` patterns (`WidgetsBindingObserver` lifecycle → `exitAndSave()` on `didChangeAppLifecycleState` paused/inactive).

```dart
class OnboardingProvider extends ChangeNotifier {
  OnboardingProgress? progress;
  OnboardingStepCode currentStep;
  AsyncState submitState;
  ApiException? lastError;
  bool? isTradeGateOpen; // TradeVerificationStatus.approved

  Future<void> loadProgress();          // resume() or start fresh at profile
  void advance();                       // advance + persist progress
  void back();
  Future<void> saveAndExit();
  Future<void> completeProfile({required String legalName, required String displayName, String? bio, String? avatarPath});
  Future<void> bindProfession(String industryId, String professionId);
  Future<void> submitIdentityDocument({required DocumentType type, required Uint8List bytes, required String mimeType, required String fileName, void Function(int,int)? onProgress});
  Future<void> submitTradeProof({required TradeProofType type, required Uint8List bytes, required String mimeType, required String fileName, void Function(int,int)? onProgress});
  Future<void> refreshGateStatus();     // from TradeVerificationProvider
}
```

### 5.4 Systems Facade — `OnboardingService` (`lib/systems/onboarding/services/`)

Thin orchestration wrapper consumed by `OnboardingProvider` only — it must never be imported by widgets:

- `OnboardingStep` vocabulary (`lib/systems/onboarding/models/onboarding_step.dart`): 5 steps + `completed`, each with `label`, `description`, `stepNumber`, `isVerificationStep`.
- `resume(entityId)` → reads store; returns furthest step; if `isComplete`, routes to `/onboarding/complete`.
- `advance()` → next step in frozen order `profile → industry → profession → identityDocument (→ tradeProof if profession bound) → completed`; persists.
- `completeProfile(...)` — uploads avatar first (`StorageService.upload(bucket: profileAvatars, path: StoragePaths.avatar(entityId, ext), upsert: true)`), then `EntityProvider.updateProfile`, then persists `avatar_path` via self-scoped REST update; propagates `StorageValidationException` (5 MiB / `jpeg/png/webp`) as field errors.
- `bindProfession(professionId)` — validates selection non-null → calls `entity_profession_bind` RPC; surfaces `PLT005` duplicate as friendly guidance.
- `submitIdentityDocument(...)` / `submitTradeProof(professionId, ...)` — delegate 1:1 to `IdentityVerificationService`/`TradeVerificationService`; mark `hasIdentitySubmission`/`hasTradeProofSubmission` in progress on success (verification status itself remains the server authority; flags are UX-only).
- `refreshTradeGate()` — reads `TradeVerificationService.getStatus()`; `isTradeGateOpen = status.approved`.
- Adds `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) redacted logs (`entityId suffix`, step code, `byteLength`, `mimeType`, profession id redacted — never full legal name, never document path, never bytes). `PerformanceTracer` spans `onboarding.step.{n}.duration`, `onboarding.submit.identity/trade.proof`.
- `PerformanceTracer` `onboarding.resume.duration` for store hydration.

### 5.5 State — Step Machine + Resumability

- `OnboardingProgressStore` is the **single source of truth for wizard position**; the provider rehydrates on every app start (post-auth home redirect).
- **Entry gate:** after authentication, `RouteGuard`/bootstrap redirects a user with `!progress.isComplete` to `/onboarding` (resume point) instead of the placeholder home. This redirect lives in a narrow guard (mirroring `RouteGuard`) keyed on `OnboardingProvider.loadProgress()` — never inside a screen.
- **Exit protocol:** every back-button / system-back on a non-terminal step triggers `OnboardingExitConfirmDialog` ("Save my progress and exit?"); accept → `saveAndExit()` → navigate home. Progress is persisted at *every* advance, so abrupt termination still resumes.
- **Cross-session identity:** progress is keyed by `auth.uid()`; switching accounts swaps the key via `OnboardingProvider.loadProgress(newEntityId)`.
- **Trade gate education:** `TradeProofStepScreen` + `OnboardingCompleteScreen` render `TradeVerifiedBadge` state (approved → bidding unlocked; otherwise → "You can start work immediately — bidding unlocks once your trade proof is approved") sourced from `isTradeGateOpen` (`AGENT.md:15` Rule 2 copy, no business logic embed).

### 5.6 UI — `lib/systems/onboarding/screens/` + `widgets/`

- `OnboardingShellScreen` (`GET /onboarding`):
  1. Reads `currentStep`; renders `OnboardingProgressIndicator` + `IndexedStack`/step body + standard CTA bar (`Back` / `Continue`/`Submit` via `HivorrButton`).
  2. Routes By Step: `/onboarding/profile`, `/onboarding/industry`, `/onboarding/profession`, `/onboarding/identity`, `/onboarding/trade-proof`, and final `/onboarding/complete`.
  3. Guards: `tradeProof` step is skipped if no profession selected (defensive; ordering contract is service-side).
- `ProfileSetupScreen` (`GET /onboarding/profile`):
  1. Legal name (`TextField`, required, ≤255 — mirrors RPC `20260821090004:40`), display name (required ≤255, `line 51`), bio (optional ≤5000, `line 59`), live counters.
  2. `OnboardingAvatarPicker` — image pick → `StorageValidators.validateForBucket(profileAvatars)` reject-before-upload → preview (`HivorrAvatar`) → upload with `onProgress` → canonical `avatar.{ext}`.
  3. Continue disabled until legal + display names valid (`OnboardingService` polish, fail-fast before RPC — no `PLT003` round-trip).
- `IndustrySelectionScreen` (`GET /onboarding/industry`):
  1. Loads industries via `TaxonomyProvider.loadIndustries()`; branded list/chips (`ChoiceChip` `ColorScheme.primaryContainer` for selected — `VISUAL-IDENTITY.md:51`, no hardcoded colors).
  2. Selection → `selectIndustry(id)` (provider already preserves across navigation, `taxonomy_provider.dart:113`) → auto-advance.
- `ProfessionSelectionScreen` (`GET /onboarding/profession`):
  1. `loadProfessions(industryId)` + search (reuses `filteredProfessions`, debounced `taxonomy_provider.dart:37`).
  2. `ProfessionRegistryBrowser` reuse (`profession_registry/`).
  3. On select → `OnboardingService.bindProfession(id)` → advance; `PLT005` duplicate surfaces inline.
- `IdentityVerificationStepScreen` (`GET /onboarding/identity`):
  1. `DocumentType` picker (5 options) → file pick → validate (10 MiB, `jpeg/png/webp/pdf`) → preview → upload with `LinearProgressIndicator` (`onProgress`) → `IdentityVerificationService.submitIdentityDocument`.
  2. `PLT005` active-submission conflict → inline guidance "You already have a pending verification for this document" + "Skip"/view-status escape to `VerificationStatusScreen`.
- `TradeProofStepScreen` (`GET /onboarding/trade-proof`):
  1. Shows selected profession chip; `TradeProofType` picker (5 options); same upload pipeline via `TradeVerificationService.submitTradeProof(type, professionId: selected.id, ...)`.
  2. Explains Rule 2 gate: proof "pending" clears bidding immediately upon approval; screen renders current gate status via `refreshTradeGate()`.
- `OnboardingCompleteScreen` (`GET /onboarding/complete`):
  1. `HivorrSuccessState` — "You're registered" summary of all 5 completed steps (read-only chips per step).
  2. Trust-loop education panel: identity/trade submission status + gate copy, next actions (view verification status, create financial profile `EP-02-13` link, browse marketplace later).
  3. "Go to home" CTA → marks progress complete and routes to `/`.

All states via branded primitives (`HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`/`HivorrSuccessState`) wrapping `HivorrLoader` pulse (`VISUAL-IDENTITY.md:148`), never bare `CircularProgressIndicator`. Tokens from `Theme.of(context).colorScheme`/`textTheme`/`AppThemeExtension.spacing` via `VISUAL-IDENTITY.md:219-235`.

### 5.7 Routing — `lib/app/router/`

Add to `RoutePaths` (`route_paths.dart`):
```
onboarding = '/onboarding'
onboardingProfile = '/onboarding/profile'
onboardingIndustry = '/onboarding/industry'
onboardingProfession = '/onboarding/profession'
onboardingIdentity = '/onboarding/identity'
onboardingTradeProof = '/onboarding/trade-proof'
onboardingComplete = '/onboarding/complete'
```
Matching `RouteNames` + 7 `GoRoute`s in `AppRouter.create` (`app_router.dart:17`). Guarded by `RouteGuard` (`route_guard.dart:1`) — authenticated required; no taxonomy gate; `onboarding` step routes are backgrounded by the shell and may read query params for context (none required). No SEO public URL (private flow).

### 5.8 DI — `registerOnboardingLayer`

Mirror the `data_layer.dart` pattern (`lib/data/data_layer.dart:198-475`):
```dart
({OnboardingService service, OnboardingProvider provider, OnboardingProgressStore store})
registerOnboardingLayer({
  required ApiLayer apiLayer,
  required EntityProvider entityProvider,
  required TaxonomyProvider taxonomyProvider,
  required IdentityVerificationService identityVerification,
  required TradeVerificationService tradeVerification,
  StorageService? storage,
  OnboardingProgressStore? store,
  HivorrLogger? logger,
}) { ... }
```
Registered in `HivorrApp` MultiProvider; the full 5-step composition is injectable records of the existing registered layers (no new network client branches). The **entry redirect** reads the returned `OnboardingProvider`.

### 5.9 Config & Logging

- No new feature flags or `ENV` keys (all four seams live & authenticated-accessible).
- Errors via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) — `401→PLT001`, `403→PLT002`, `400/422→PLT003`, `404→PLT004`, `409→PLT005`, `5xx→PLT999`. `OnboardingService` rethrows normalized `ApiException`; provider surfaces `message` without leaking `stack`/`SQL`.
- `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) — log `entityId suffix`, step code, document/proof type, `byteLength`, `mimeType`, profession id redacted; **never** full `legalName`, full avatar/credential path, never bytes.
- `PerformanceTracer` spans `onboarding.*` sampled via `MonitoringConfig`, tags step codes, no PII.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `OnboardingProgress` entity | `lib/data/entities/onboarding_progress.dart` | **Create** — §5.3 |
| `OnboardingProgressStore` abstract + impls | `lib/data/local/onboarding_progress_store.dart` | **Create** — §5.3 (`InMemory` + `Hive`) |
| `OnboardingProvider` | `lib/data/providers/onboarding_provider.dart` | **Create** — §5.3/§5.5 |
| `OnboardingStep` enum + vocab | `lib/systems/onboarding/models/onboarding_step.dart` | **Create** — §5.4 |
| `OnboardingService` facade | `lib/systems/onboarding/services/onboarding_service.dart` | **Create** — §5.4 |
| Screens | `lib/systems/onboarding/screens/onboarding_shell_screen.dart`, `profile_setup_screen.dart`, `industry_selection_screen.dart`, `profession_selection_screen.dart`, `identity_verification_step_screen.dart`, `trade_proof_step_screen.dart`, `onboarding_complete_screen.dart` | **Create** — §5.6 |
| Widgets | `lib/systems/onboarding/widgets/onboarding_progress_indicator.dart`, `onboarding_step_card.dart`, `onboarding_exit_confirm_dialog.dart`, `onboarding_avatar_picker.dart`, `onboarding_document_upload_tile.dart` | **Create** — §5.6 |
| Barrel | `lib/systems/onboarding/onboarding.dart` (new) + `lib/data/data_layer.dart` | **Create/Update** — re-exports |
| DI factory | `registerOnboardingLayer(...)` in `lib/data/data_layer.dart` | **Create** — §5.8 |
| Route extension | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` | **Update** — 7 routes, `RouteGuard` |
| Entry redirect | Onboarding resume gate (narrow guard or bootstrap redirect keyed on `OnboardingProvider`) | **Update** — post-auth resume |
| Reuses (no change) | `TaxonomyProvider`, `ProfessionRegistryBrowser`, `IdentityVerificationService`, `TradeVerificationService`, `EntityProvider`, `StorageService` + `StoragePaths.avatar/credentialDocument`, `DocumentType`, `TradeProofType`, `HivorrAvatar` (`lib/shared/widgets/hivorr_avatar.dart`) | **Reuse** |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — `git diff --stat supabase/` = 0 |
| No `.supabase/functions/*` | `.supabase/functions/` | **No change** |
| Tests + fakes | `test/unit/data/onboarding/*`, `test/unit/systems/onboarding/*`, `test/widget/systems/onboarding/*`, `test/integration/onboarding_flow_integration_test.dart`, `test/support/fakes/fake_*` | **Create** — §14 |

## 7. Data Requirements

### 7.1 Onboarding Progress (client-local, Hive)

| Element | Detail |
|---|---|
| Storage | Hive box `onboarding` (via `lib/core/database/` EP-01-11 engine), key `onboarding_progress:{entityId}` |
| Entity | `OnboardingProgress` — `entityId`, `step`, `completedSteps`, `hasIdentitySubmission`, `hasTradeProofSubmission`, `updatedAt` |
| Mutation | Append-only position; `clear` only on deliberate re-onboarding or account switch; no server table (not trusted state — verification status is the server authority) |
| Lifecycle | Hydrated on boot (post-auth), saved on every advance, written on exit; graceful in-memory fallback |

### 7.2 Server Data Written by This Flow (all via frozen seams)

| Table / column | Written by | Seam |
|---|---|---|
| `entity_profiles` (legal_name, display_name, bio, avatar_path) | `entity_profile_update` RPC + self-scoped REST update | EP-01-06 |
| `entity_professions` (entity_id, profession_id, is_primary=false, `trade_verification_status=unverified`) | `entity_profession_bind` RPC | EP-01/02 (`20260821090004:202`) |
| `entity_credentials` (kind, title, document_path, profession_id?) | identity/trade submit pipeline | EP-02-10/11 |
| `verification_submissions` (queued pending) | `verification_submit` | EP-02-10/11 |

No new table columns; no new storage objects beyond the canonical avatar (`profile-avatars/{entityId}/avatar.{ext}`) which is already part of the EP-02-06/08 bucket contract.

## 8. Database Considerations

- **Zero DDL / DML-policy change in this task.** All serverside surfaces referenced are frozen (`20260821090004`, `20260829090002`, `20260829090003`, `20260830100001`). `git diff --stat supabase/` = 0.
- **RLS posture inherited:** `entity_profiles` self-scoped select/insert/update (`20260821090003:80-88`); `entity_professions` self CRUD on permitted columns with `trade_verification_status` server-gated (`:123-139`); `entity_credentials` + `verification_submissions` self-scoped per EP-02-03.
- **`trade_verification_status` boundary absolute:** the client never writes the gate columns; `entity_profession_bind` lands `unverified` and only the admin review path moves it. Onboarding only *reports* the gate via a read (`TradeVerificationStatus`).
- **`verification_submissions` uniqueness (`PLT005`):** partial unique index on active submissions (`20260829090003:364-381`) — duplicate identity/trade submissions are rejected server-side; onboarding surfaces the conflict as guidance, never retries blindly.
- **Storage RLS path gate:** every upload path starts with `{entityId}` (`20260830100001:118`); `StoragePaths.avatar`/`credentialDocument` produce compliant paths; avatar is upsert (canonical object), credentials are non-upsert.
- **Avatar `avatar_path` write:** `entity_profile_update` accepts no avatar param — the flow persists `avatar_path` via the self-scoped `entity_profiles` update grant (verified against the migration grant; if the update policy excludes `avatar_path`, a minimal read-only dependency review is required in implementation, with no migration change).
- **Full pgTAP suite stays green:** `supabase db test` regression gate `001-017`; no client change can affect server tests.

## 9. API Requirements

### 9.1 Existing seams invoked (no new RPCs)

| Operation | Seam | Params | Error → ApiExceptionKind |
|---|---|---|---|
| Update profile | `entity_profile_update` | `p_legal_name, p_display_name, p_bio` | `PLT003` (length), `PLT001` |
| Persist avatar path | `entity_profiles` self-scoped update | `avatar_path` | `PLT001`, `PLT004` |
| Bind profession | `entity_profession_bind` | `p_profession_id` | `PLT001`, `PLT003` (null), `PLT004` (missing/inactive), `PLT005` (duplicate) |
| List industries | `taxonomy_industries_list` | `p_include_inactive=false` | `PLT003` |
| List professions | `taxonomy_professions_list` | `p_industry_id` | `PLT003`, `PLT004` |
| Identity submit | `verification_submit` (via EP-02-10) | `p_credential_id, p_submission_type='identity_document'` | `PLT003`, `PLT005` (active exists) |
| Trade submit | `verification_submit` (via EP-02-11) | `p_credential_id, p_submission_type='trade_proof'` | `PLT003`, `PLT004`, `PLT005` |
| Trade gate read | `verification_status_get` (via EP-02-11) | — | `PLT001` |

### 9.2 Storage API (existing)

- Avatar: `StorageService.upload(bucket: StorageBuckets.profileAvatars, path: StoragePaths.avatar(entityId, ext), bytes, mimeType: image/*, fileName, onProgress, upsert: true)`; preview via `getPublicUrl` (public bucket). 5 MiB / `jpeg/png/webp` (`storage_config.dart:39,66,97`).
- Identity/trade docs: `StorageService.upload(bucket: StorageBuckets.credentialDocuments, path: StoragePaths.credentialDocument(...), ...)`; signed URL only (private bucket, `storage_service.dart:53` public-path throws).

### 9.3 Error Contract

Every public `OnboardingService` method throws only `ApiException` (normalized kinds) or `DataException`/`StorageValidationException` — never raw Supabase/Dio exceptions. `PLT003` → inline field errors; `PLT004` → step-scoped not-found with back navigation; `PLT005` → conflict guidance cards (duplicate profession binding / active verification); network → retry state.

## 10. User Interface Requirements

**Widgets introduce UI — `AGENT.md:17` Rule 5 applies.** Every widget must use `Theme.of(context).colorScheme` / `AppThemeExtension` (`lib/app/theme/app_colors.dart:16`, `app_theme_extension.dart`) — never `Colors.*`/raw hex; `Theme.of(context).textTheme` — never per-widget `TextStyle(fontFamily: 'Inter')`; spacing/radius/elevation via `AppThemeExtension` (`VISUAL-IDENTITY.md:219-235`), cards 16dp, 8pt grid; the 4 states via branded primitives wrapping `HivorrLoader` pulse (`VISUAL-IDENTITY.md:148`), never bare loaders.

| Screen/Widget | Route | Purpose | Key Elements |
|---|---|---|---|
| `OnboardingShellScreen` | `GET /onboarding` | Wizard host + progress | `OnboardingProgressIndicator`, step body (`IndexedStack`), `Back`/`Continue` bar, exit guard |
| `ProfileSetupScreen` | `GET /onboarding/profile` | Names/bio/avatar | Legal + display `TextField` w/ counters (≤255), bio (≤5000), `OnboardingAvatarPicker` + preview, `FilledButton` Continue |
| `IndustrySelectionScreen` | `GET /onboarding/industry` | Pick industry | `HivorrChip`/`ChoiceChip` grouped list, selected uses `primaryContainer`, auto-advance |
| `ProfessionSelectionScreen` | `GET /onboarding/profession` | Pick + bind profession | `ProfessionRegistryBrowser` reuse, search, selection → bind → advance, `PLT005` inline |
| `IdentityVerificationStepScreen` | `GET /onboarding/identity` | Upload identity doc | `DocumentType` picker, `OnboardingDocumentUploadTile`, `LinearProgressIndicator`, `PLT005` guidance, status escape |
| `TradeProofStepScreen` | `GET /onboarding/trade-proof` | Upload trade proof | Selected-profession chip, `TradeProofType` picker, upload tile, gate-status panel |
| `OnboardingCompleteScreen` | `GET /onboarding/complete` | Success + trust education | `HivorrSuccessState`, per-step done chips, Rule 2 gate copy, "Go to home" |
| `OnboardingProgressIndicator` | — | 5-step linear tracker | Segment row filled by `stepNumber`; `ColorScheme.primary` on done, `surfaceVariant` pending |
| `OnboardingStepCard` | — | Step meta | Icon + title + description + state; spacing via `AppThemeExtension` |
| `OnboardingExitConfirmDialog` | — | Exit-and-save confirm | "Save my progress and exit?" affirmative/destructive styling via `colorScheme` |
| `OnboardingAvatarPicker` | — | Avatar pick/upload | `HivorrAvatar` preview, validate-then-upload, `onProgress` |
| `OnboardingDocumentUploadTile` | — | Reusable upload | Type icon, filename/size, progress, retry; MIME/size pre-validation |

360dp? No — widths/breakpoints via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`): 16dp padding mobile, 24dp web pane. All numeric money/identity never surfaced here (no financials; identity shown as initials suffix when relevant).

## 11. User Experience Considerations

- **One coherent journey:** five steps, one shell, one progress tracker; each step explains *why* (e.g. profession step explains bidding gate — `AGENT.md:15` Rule 2).
- **Resumability is invisible-but-reliable:** progress persists on every advance; the resume redirect brings the entity back to exactly where they left, so exiting mid-verification is always safe.
- **Fail-fast validation:** name lengths, avatar MIME/size, and document MIME/size pre-validated before any RPC/upload — known `PLT003` violations never round-trip.
- **Uploads staged & non-blocking:** doc uploads happen before submission; failed upload shows retry without losing typed data.
- **Order enforcement:** the service enforces the frozen step order; defensive skip for trade-proof if no profession is bound (server would `PLT004` anyway — ordering contract respected both sides).
- **Transparent verification state:** after submission the entity sees pending status + expected outcome ("reviewed within 24h" from EP-02-10 copy) and can deep-link to `VerificationStatusScreen`.
- **Gate education, not gate UI:** the flow never fakes bid-lock state; it reports server status read-only and explains the unlock condition.
- **Exit is deliberate:** every exit path confirms save-and-exit; no silent data loss.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Server-authoritative trust state** `AGENT.md:16` Rule 4 | The client orchestrates, it never asserts verification/gate state. Progress flags (`hasIdentitySubmission`) are UX mirrors only; `verification_submissions.status` and `entity_professions.trade_verification_status` are server-only. |
| **No new server surface** | Zero DDL/RPC/Edge Function changes — reduces attack surface to existing, review-locked seams. `git diff --stat supabase/` = 0; grep lens `grep -rn "service_role" lib/` = 0. |
| **PII handling** | Legal name is the Rule 3 financial anchor — rendered read-only after entry, never logged beyond redacted suffix, never stored in Hive progress (only the profile RPC writes it). Document paths/bytes never logged. |
| **Storage privacy** | Credentials in private `credential-documents` (signed URL only); avatar in public `profile-avatars` is intentionally the only public identity image (canonical, validated MIME/size). Paths always `{entityId}/...` per RLS gate (`20260830100001:118`). |
| **`entity_profession_bind` duplicate protection** | Server unique constraint (`entity_professions_entity_profession_key`, `20260821090002:182`) + `PLT005`; client surfaces duplicate guidance and prevents fire-hammering. |
| **Auth isolation** | Progress key scoped by `auth.uid()`; account switch swaps keys; `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) keeps envs isolated. |
| **Validation fidelity** | Client mirrors server constraints exactly (legal/display ≤255, bio ≤5000, 5 MiB avatar MIME whitelist, 10 MiB doc whitelist) — server remains single authority; client pre-validation is UX fast-fail only. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **RPC cost** | One navigation = at most one taxonomy load (industries/professions per step, memoized by `TaxonomyProvider`) + one profile RPC + one bind RPC + submission chain. No polling in onboarding; verification polling stays with EP-02-10/11 providers. |
| **Progress I/O** | Hive local box read once on resume, written per advance (tiny payload); in-memory default avoids IO on unsupported platforms. |
| **Upload path** | Avatar/credential uploads single-shot with `onProgress`; validation before transfer; no parallel uploads in the step. |
| **State churn** | `OnboardingProvider` holds immutable `OnboardingProgress`; no per-frame allocations; step vocab is compile-time const. |
| **Lifecycle** | `WidgetsBindingObserver` saves progress on pause/inactive; in-flight submissions cancelled on background and re-surfaced on resume with retry. |
| **Tracer overhead** | `PerformanceTracer` spans sampled via `MonitoringConfig`; tags step codes; no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/data/onboarding/` + `test/unit/systems/onboarding/`

Pattern mirrors EP-02-10/11/17 suites + `test/support/fakes/` — no live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `onboarding_progress_test.dart` | 6 | Entity immutability, `isComplete` derivation, step ordering (`completedSteps` advances monotonically), serialization round-trip via store |
| `onboarding_progress_store_test.dart` | 6 | `InMemory` save/read/clear; Hive store with `Hive.init` temp dir (key scoping by entityId; missing key → null; graceful no-op when uninitialized) |
| `onboarding_provider_test.dart` | 12 | `loadProgress` resume at each step; fresh entity starts at `profile`; `advance` persists every step; `back`; `saveAndExit`; account-switch key swap; async submit success/`PLT003`/`PLT005`-conflict state; `refreshGateStatus` maps approved→open; `notifyListeners` on each mutation; `WidgetsBindingObserver` exit-save |
| `onboarding_service_test.dart` | 10 | `resume` returns furthest step (incl. completed); ordering contract never skips a required step; `completeProfile` uploads avatar first then RPC then avatar_path update (call ordering asserted); `bindProfession` validates + maps `PLT005`; `submitIdentity`/`submitTradeProof` delegate + set flags; redacted log assertions (no legal name in output); tracer span begin/ok/fail |
| Store parity | 2 | Hive key format `onboarding_progress:{entityId}`; cross-user isolation |

≥36 unit assertions.

### 14.2 Widget Suite — `test/widget/systems/onboarding/`

| File | Cases (min) | Method |
|---|---|---|
| `progress_indicator_test.dart` | 6 | 5 segments; filled count == `stepNumber`; `colorScheme.primary` vs `surfaceVariant` per state; no hardcoded colors (`ColorScheme` assert) |
| `shell_screen_test.dart` | 8 | Renders current step body; Back/Continue enablement per step; exit dialog trigger; step swap on provider notify; trade-proof skipped when unbound (defensive); theme token asserts (`textTheme.titleLarge`, `AppThemeExtension.radius*`) |
| `profile_setup_screen_test.dart` | 8 | Validation gates Continue (legal/display empty, >255); avatar picker rejects 6 MiB jpeg (`StorageValidationException` message shown, `colorScheme.error`); upload progress; submit calls provider + success transition |
| `industry_selection_screen_test.dart` | 6 | Industry list render; selection highlights + auto-advance; empty state; error retry |
| `profession_selection_screen_test.dart` | 6 | Load + search filter; select binds via provider; duplicate `PLT005` inline guidance; gate copy present |
| `identity_step_screen_test.dart` | 8 | DocumentType options render; upload flow with progress; `PLT005` guidance + escape route; success state; MIME reject before network (assert no upload call) |
| `trade_step_screen_test.dart` | 6 | Profession chip; proof type options; upload + success; gate panel approved vs pending copy |
| `complete_screen_test.dart` | 6 | 5 done chips; Rule 2 gate copy variants; "Go to home" navigates; HivorrSuccessState usage |

≥54 widget assertions.

### 14.3 Integration — `test/integration/onboarding_flow_integration_test.dart`

Full wizard with fake `TaxonomyRepository`, fake `VerificationRepository`, fake `TradeVerificationRepository`, fake `EntityRepository`, fake `StorageService`, in-memory store:

1. Fresh entity → resume redirect → loop all 5 steps with real route transitions → `/onboarding/complete` → home.
2. Exit at step 3 → relaunch → resumes at profession with step 1/2 complete.
3. Trade proof gate: feed approved status → complete screen shows unlocked copy.
4. Duplicate submission path: fake returns `PLT005` — guidance shown, retry not fired.

### 14.4 Verification Gates

| Gate | Command / Assertion |
|---|---|
| Analyzer clean | `flutter analyze` — 0 issues |
| Unit | `flutter test test/unit` — all green; ≥36 onboarding unit assertions |
| Widget | `flutter test test/widget` — all green; ≥54 onboarding widget assertions |
| Integration | `flutter test test/integration/onboarding_flow_integration_test.dart` |
| Full suite | `flutter test` — regression green |
| DB regression | `supabase db test` — `001-017` green (no `supabase/` diff, `git diff --stat supabase/` = 0) |
| Grep lenses | `grep -rn "service_role" lib/` = 0; no onboarding code outside `lib/` boundary |
| No-DDL | `git diff --stat supabase/` = 0 |

## 15. Definition of Done (24 criteria)

**Architecture & Boundaries**
- [ ] **DoD-1:** New `lib/systems/onboarding/` barrel with `screens/`, `widgets/`, `services/`, `models/` — no top-level `lib/` directories added.
- [ ] **DoD-2:** `OnboardingProgressStore` lives in `lib/data/local/` (abstract + `InMemory` + Hive impl); `OnboardingProvider` in `lib/data/providers/`; unidirectional `data → systems`, no widget import in data-layer files.
- [ ] **DoD-3:** `OnboardingService` composes existing facades (`EntityProvider`, `TaxonomyProvider`, `IdentityVerificationService`, `TradeVerificationService`, `StorageService`) — no re-implemented transport, no new RPC wrappers beyond `entity_profession_bind`.
- [ ] **DoD-4:** Zero `supabase/` changes verified (`git diff --stat supabase/` = 0); zero Edge Functions; zero storage-bucket changes.

**Server Authority & Trust**
- [ ] **DoD-5:** Client never writes `verification_submissions.status`, `entity_professions.trade_verification_status`, or `entity_kyc_levels`; submission/gate states only rendered read-only from server reads.
- [ ] **DoD-6:** No `service_role` string anywhere in `lib/` (grep lens clean).
- [ ] **DoD-7:** Flow never bypasses the frozen step order; trade-proof submission always carries the bound `profession_id`; unbound profession → step not offered (defensive).

**Profile Step**
- [ ] **DoD-8:** `ProfileSetupScreen` persists legal name, display name, bio via `entity_profile_update` (≤255 / ≤255 / ≤5000 pre-validated) and displays live counters.
- [ ] **DoD-9:** Avatar uploads to `profile-avatars/{entityId}/avatar.{ext}` (public bucket, 5 MiB, jpeg/png/webp, upsert) with reject-before-upload validation; resulting `avatar_path` persisted on `entity_profiles`.
- [ ] **DoD-10:** Avatar preview uses `HivorrAvatar`; avatar is the only public image surfaced; credential documents never use public URLs.

**Taxonomy Steps**
- [ ] **DoD-11:** Industry + profession selection reuse `TaxonomyProvider` (`loadIndustries`, `loadProfessions`, `selectIndustry`, `selectProfession`) and the `ProfessionRegistryBrowser`; selection survives navigation and resume.
- [ ] **DoD-12:** Profession bind calls `entity_profession_bind` and maps `PLT004`/`PLT005` to inline guidance; duplicate binding never fire-hammers the RPC.

**Verification Steps**
- [ ] **DoD-13:** Identity step delegates to `IdentityVerificationService` (5 `DocumentType` values, private `credential-documents`, `verification_submit`, `onProgress`).
- [ ] **DoD-14:** Trade step delegates to `TradeVerificationService` (5 `TradeProofType` values, `submission_type=trade_proof`, profession-bound).
- [ ] **DoD-15:** Active-verification `PLT005` surfaces conflict guidance + status escape, never silent retry.
- [ ] **DoD-16:** `OnboardingCompleteScreen` reports trade-gate status read-only and explains Rule 2 (unverified pros work immediately; bidding unlocks on approval) — no gate-affecting controls.

**Resumability & Routing**
- [ ] **DoD-17:** Progress persists on every advance (Hive, keyed `onboarding_progress:{entityId}`) and on lifecycle pause; relaunch resumes at the exact step; `isComplete` routes to `/onboarding/complete`.
- [ ] **DoD-18:** Account switch rebinds the progress key; a fresh account starts at `profile`.
- [ ] **DoD-19:** 7 GoRoutes registered under `/onboarding/*`, guarded by `RouteGuard` (authenticated only), named + path-constant in `RoutePaths`/`RouteNames`.
- [ ] **DoD-20:** Post-auth entry redirect sends incomplete entities to the resume point (never the placeholder home); no SEO public URL introduced.

**Identity, UX & Tests**
- [ ] **DoD-21:** All widgets consume theme tokens only (`colorScheme`/`textTheme`/`AppThemeExtension` — `VISUAL-IDENTITY.md`) and branded states/`HivorrLoader`; grep asserts no `Colors.*`/`Color(0xFF`/`fontFamily:` in onboarding widgets.
- [ ] **DoD-22:** Exit is always explicit (confirm dialog) with progress preserved; in-flight uploads cancelled on background, retried on resume without data loss.
- [ ] **DoD-23:** Test suite meets targets — ≥36 onboarding unit assertions, ≥54 onboarding widget assertions, fake-E2E integration wizard (full run + resume + gate-copy + `PLT005`), full `flutter test` green.
- [ ] **DoD-24:** `flutter analyze` clean; documentation of the DI wiring in `data_layer.dart` matches the frozen seam contracts; plan sections implemented as specified.

## 16. Review & Approval

| Role | Action |
|---|---|
| Task Lead | Assemble implementation in dev env; run gate suite; self-review DoD checklist |
| Architecture Review | Confirm zero server-surface change, `lib/` placement, unidirectional deps, reuse contracts |
| Security Review | Redacted-log sampling; no PII in Hive progress; privacy of credential paths; gate authority server-side |
| Lead Approval | Sign off DoD 1–24 before transfer to code review |

Approved plan — implementation begins in the Development environment. This document is owned by `documents/Task-Implementation/EP-02/`; server-chain changes require a new migration proposal, never an edit here.

## 17. Post-Implementation Audit Checklist

```
[ ] flutter analyze       -> 0 issues
[ ] flutter test          -> all green (unit ≥36 + widget ≥54 onboarding assertions)
[ ] supabase db test      -> 001-017 green
[ ] git diff --stat supabase/  -> 0
[ ] grep -rn "service_role" lib/  -> 0
[ ] grep -rn "Colors\.\|Color(0xFF\|fontFamily:" lib/systems/onboarding/  -> 0
[ ] Resume-from-exit verified manually (Hive box persists across hot restart)
[ ] Account-switch key isolation verified
[ ] Rule 2 gate copy rendered for approved vs pending states
```