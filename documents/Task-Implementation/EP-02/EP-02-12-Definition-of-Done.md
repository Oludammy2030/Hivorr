# Definition of Done — EP-02-12: KYC Integration Framework & Verification Level Management

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-12 | **Status:** Not Started
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-12-KYC Integration Framework & Verification Level Management.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-12 |
| **Task Name** | KYC Integration Framework & Verification Level Management |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 4 — Trust & Verification Systems |
| **Priority** | High |
| **Dependencies** | EP-02-03 (Verification Schema — `kyc_tiers`, `entity_kyc_levels`, 3 read RPCs `verification_kyc_level_get`/`verification_limits_get`/`verification_status_get`), EP-02-10 (Identity Verification — `VerificationProvider` pattern `lib/data/providers/verification_provider.dart:42`, `KycLevel`/`KycLimits` entity + DTO reuse) |
| **Blocks** | EP-02-16 (Bound Payout Accounts & Deposit Name Verification — KYC-driven cashout enforcement), EP-02-18 (Onboarding Flow) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-12-KYC Integration Framework & Verification Level Management.md` |

> Frozen server refs (reused, never modified): `supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-112` (`kyc_tiers` + `entity_kyc_levels`), `228-234` (4-tier seed), `592-681` (`verification_status_get`), `687-735` (`verification_kyc_level_get`), `740-782` (`verification_limits_get`), `794-796` (grace/execution-grant) — task is `lib/` + `test/` only; `git diff --stat supabase/` must be `0`.

---

## 2. Functional Verification

This task delivers the client-side **KYC Integration Framework & Verification Level Management**: the tier vocabulary (`tier_0..tier_3` with proportional NGN limits), server-enforced limit retrieval via the frozen `EP-02-03` RPCs, KYC status tracking, limit visibility UX, the upgrade flow seam, and the abstract `KycProvider` integration seam for future identity-verification providers (SmileID, Dojah, NIBSS BVN). Functional verification confirms the data layer, repository, provider-seam registry, service facade, limit guard, change-notifier provider, screens, widgets, and routing behave correctly and never bypass server-enforced KYC invariants.

### 2.1 Required Functionality — Domain Vocabulary

- [ ] **FV-01:** `lib/systems/verification/models/kyc_tier.dart` defines `KycTier` enum with exactly 4 values: `tier0`..`tier3` — each with `code` getter mapping `'tier_0'..'tier_3'`, `displayLabel` ("Unverified", "Identity Verified", "Trade Verified", "Fully Verified" `supabase/migrations/20260829090003_verification_admin_review_schema.sql:228-234`), `isVerified` helper, `fromCode(String)` lookup, and `cashoutLimit` preview
- [ ] **FV-02:** `KycTier` is extensible without schema change — adding `tier_4` (Business KYC) requires only an enum value + label + `kyc_tiers` seed row; no screen or repository edits (Open/Closed per `EP-02:197`)
- [ ] **FV-03:** `tierCodeCompare('tier_1')` lexicographic string compare holds for `tier_0..tier_3` (single-digit codes) at `lib/data/entities/kyc_level.dart:28` — `isVerified` derives from the existing entity helper, not a new comparison

### 2.2 Required Functionality — Data Layer (Entities, DTOs, Mappers)

- [ ] **FV-04:** Existing `KycLevelDto`/`KycLimitsDto`/`VerificationStatusDto`/`TradeVerificationDto` (`lib/data/models/kyc_level_dto.dart:1`) are **reused** (no new DTO file) — `fromJson` maps `tier_code`, `status`, `limits{daily, weekly, monthly, cashout}`, `identity_verified`, `trade_verifications[]`
- [ ] **FV-05:** Existing entities `KycLevel` (`tierCode, status, limits`), `KycLimits`, `VerificationStatus` reused at `lib/data/entities/` — pure Dart, no Flutter/Supabase imports; no new entity file
- [ ] **FV-06:** `VerificationMapper` (`lib/data/mappers/verification_mapper.dart:1`) extended with KYC helpers `kycToEntity`, `limitsToEntity`, `statusToEntity`, `kycTierFromCode`, tier label helpers — maps DTO→Entity without leaking RPC JSON shape
- [ ] **FV-07:** `tier_0` all-zero default handled at mapper/repository layer (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:633-637,764-768`) — `tier_0` returned (never thrown) when `entity_kyc_levels` has no row
- [ ] **FV-08:** `identity_verified` derivation matches server `status=='active' && tier_code >= 'tier_1'` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:639` string compare holds for `tier_0..tier_3`)

### 2.3 Required Functionality — Remote Data Source

- [ ] **FV-09:** `KycRemoteDataSource` abstract exists at `lib/data/datasources/remote/kyc_remote_data_source.dart` — methods `getKycLevel()`, `getLimits()`, `getStatus({String? entityId})`
- [ ] **FV-10:** `SupabaseKycRemoteDataSource` exists at `lib/data/datasources/remote/supabase_kyc_remote_data_source.dart` — `extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`), constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`, uses `supabase.rpc<Map<String,dynamic>>` for all 3 read RPCs
- [ ] **FV-11:** RPC mapping exact: `verification_kyc_level_get` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:688-735`), `verification_limits_get` (`740-782`), `verification_status_get` (`592-681`, `params:{p_entity_id}`, null = self)
- [ ] **FV-12:** Envelope unwrap via `VerificationEnvelopeParser.unwrap` (`lib/data/datasources/remote/verification_envelope_parser.dart:29`) validates `success==true && code=='PLT000'` before DTO mapping; malformed/`success:false` envelope throws `ApiException` with extracted `code/message` — no second parser created
- [ ] **FV-13:** Error mapping via `DataExceptionMapper` (`lib/data/datasources/remote/data_exception_mapper.dart`) — `PLT001→auth`, `PLT003→validation`, `PLT004→notFound`, `PLT999→server`; raw `DioException` never propagates (`BaseApiService.invoke:33` normalizes)

### 2.4 Required Functionality — Repository

- [ ] **FV-14:** `KycRepository` abstract + `KycRepositoryImpl` exist at `lib/data/repositories/kyc_repository.dart` + `kyc_repository_impl.dart`
- [ ] **FV-15:** `getKycLevel()` delegates to `remote.getKycLevel()` → `VerificationMapper.kycToEntity`; unassigned entity returns `tier_0` all-zero defaults — never throws `supabase/migrations/20260829090003_verification_admin_review_schema.sql:633-637`
- [ ] **FV-16:** `getLimits()` delegates to `remote.getLimits()` → `limitsToEntity`; `tier_1` maps `daily=50000, weekly=200000, monthly=800000, cashout=100000` (`740-782`)
- [ ] **FV-17:** `getStatus()` delegates to `remote.getStatus()` → `statusToEntity` — full aggregate including `kyc{tier_code,status,limits}`, `identity_verified`, `trade_verifications[]`, `pending/total` (`659-680`)
- [ ] **FV-18:** `requestUpgrade({required KycTier targetTier, Map<String,dynamic>? payload})` validates `targetTier.code > current.tier_code` (string compare) first — invalid/non-upgrade target throws `DataValidationException` `PLT003` **before** `KycProvider.verify` is invoked (provider spy not called); if provider configured, delegates to `kycRegistry.resolveForTier(targetTier).verify(...)`; if none, returns `KycLevel` unchanged + surfaces guidance ("Complete identity verification to unlock tier_1"); **never writes `entity_kyc_levels`**
- [ ] **FV-19:** `eligibleUpgradePath(KycLevel current)` pure list: `tier_0 → [tier1,tier2,tier3]`, `tier_1 → [tier2,tier3]`, `tier_2 → [tier3]`, `tier_3 → []` — `KycProvider.nextEligibleTier` uses `.firstOrNull`
- [ ] **FV-20:** Repository never imports `lib/systems/` widgets — unidirectional dependency `data → systems`; `pexel` no `SupabaseClientProvider` singleton inside repository (client held via datasource only)

### 2.5 Required Functionality — Provider Seam (`lib/integrations/kyc/`)

- [ ] **FV-21:** `lib/integrations/kyc/kyc_provider.dart` defines abstract `KycProvider` — `String get providerName; Future<KycVerificationResult> verify({required String entityId, required KycTier targetTier, Map<String,dynamic>? payload})`
- [ ] **FV-22:** `KycVerificationResult` value type exists — `final String status;` (`pending|approved|rejected`, display only) + `final String? providerReference`
- [ ] **FV-23:** `lib/integrations/kyc/mock_kyc_provider.dart` defines `MockKycProvider implements KycProvider` — `providerName == 'mock'`, `verify` returns `KycVerificationResult(status:'pending')` after `Future.delayed(Duration(milliseconds: 800))`; holds no `SupabaseClient`/`service_role` key
- [ ] **FV-24:** `lib/integrations/kyc/kyc_provider_registry.dart` defines `KycProviderRegistry({KycProvider? primary, List<KycProvider> fallbacks})` with `KycProvider? resolveForTier(KycTier tier)` → primary; extensible per-tier routing for `EP-08` SmileID/Dojah (new provider = new file + registry entry, zero `systems/` change)

### 2.6 Required Functionality — Systems Facade

- [ ] **FV-25:** `KycService` exists at `lib/systems/verification/services/kyc_service.dart` — thin facade over `KycRepository` + `KycProviderRegistry`, consumed by `KycProvider` (ChangeNotifier) and future `EP-02-16` payout guard + `EP-02-18` onboarding without modification
- [ ] **FV-26:** Exposes `supportedTiers = KycTier.values` with display labels + limit previews (from `VerificationStatus.kycLevel.limits`); adding `tier_4` is enum + seed only — no screen edits
- [ ] **FV-27:** `HivorrLogger` + `PiiRedactor` redacted logging (`entityId: ***last4`, `targetTier`, `providerName`, `limits.*`) — never logs `legal_name`, never raw `bvn`/`nin`/`dob`; `PerformanceTracer` spans `kyc.level.get.duration` / `kyc.limits.get.duration` / `kyc.upgrade.request.duration` sampled via `MonitoringConfig`

### 2.7 Required Functionality — Gate (Pure Limit Logic)

- [ ] **FV-28:** `lib/systems/verification/gate/kyc_limit_guard.dart` defines `abstract final class KycLimitGuard` pure helpers — `static bool canTransact({required KycLimits limits, required num amount}) => amount > 0 && amount <= limits.daily`
- [ ] **FV-29:** `static bool isCashoutAllowed({required KycLimits limits, required num amount}) => amount > 0 && amount <= limits.cashout`; `static num remainingFor(String window, KycLimits limits, num spent)` computes `limit - spent` for `daily|weekly|monthly`
- [ ] **FV-30:** `static KycTier? suggestedUpgrade(KycLevel current, num requestedAmount)` — returns `null` when `requestedAmount <= current.limits.cashout`, else first `KycTier` whose `cashoutLimit >= requestedAmount`; no I/O, no globals, O(1) — trivially testable per keystroke; downstream `EP-02-16` uses `isCashoutAllowed` before `supabase.rpc('financial_withdraw')`

### 2.8 Required Functionality — Provider (ChangeNotifier)

- [ ] **FV-31:** `KycProvider` exists at `lib/data/providers/kyc_provider.dart` — `extends ChangeNotifier` (`provider:6.1.5`), mirrors `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42-308`)
- [ ] **FV-32:** State fields: `KycLevel? kycLevel`, `KycLimits? limits`, `VerificationStatus? status`, `AsyncState loadState`, `ApiException? lastError`, `bool isRefreshing`, `Timer? pollTimer`
- [ ] **FV-33:** `load()` fetches `getKycLevel()` + `getLimits()` + `getStatus()` in parallel via `Future.wait` (status already contains `kyc` so `getStatus()` may serve `kycLevel` to save one RPC); sets `loadState=loading` → `success`, `lastError` on failure
- [ ] **FV-34:** `refreshStatus()` re-reads status + `kycLevel`, then `maybeNotify(...)`; `requestUpgrade({targetTier, payload})` delegates to repository
- [ ] **FV-35:** `startPolling()` starts `Timer.periodic(Duration(seconds: 15))` calling `refreshStatus()` **only while** `kycLevel.status == pending` (or `status.pendingSubmissions > 0`) and screen visible; pauses via `WidgetsBindingObserver.didChangeAppLifecycleState(background)`, cancels on `AppRouter didPush/didPop` + `dispose()`; `pausePolling()`/`resumePolling()` exposed
- [ ] **FV-36:** `maybeNotify(...)` diffs `prev.kycLevel.tierCode → next.kycLevel.tierCode`; emits exactly one `HivorrNotification{priority: high, channel: system, title: 'Verification upgraded — tier_1', body: 'Your limits increased to ₦100,000 cashout', actionRoute: '/verification/kyc'}` via `NotificationProvider` (`lib/core/notifications/providers/notification_provider.dart`) **only** on upward tier transition — idempotent, no duplicate on repeat poll
- [ ] **FV-37:** Constructor injection `({required KycRepository repo, KycProviderRegistry? kycRegistry, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability; no `SupabaseClientProvider` singleton inside provider (repository holds client)

### 2.9 Required Functionality — UI Screens

- [ ] **FV-38:** `KycStatusScreen` exists at `lib/systems/verification/screens/kyc_status_screen.dart` (`GET /verification/kyc`): `AppBar(title: Text('Verification & limits', style: textTheme.titleLarge))`, `KycTierBadge` (tier label + status chip: `pending` amber `warningContainer`, `active` green `successContainer`, `expired/unassigned` grey `outline` `VISUAL-IDENTITY.md:72-79`), `KycLimitsCard` (4 chips Daily/Weekly/Monthly/Cashout `₦`-formatted via `lib/shared/helpers/`), `VerificationTimeline` reuse (`lib/systems/verification/widgets/verification_timeline.dart`) showing `Submitted → Pending → In Review → Approved`, `IdentityVerifiedBadge` when `isVerified`
- [ ] **FV-39:** Upgrade CTA present when `nextEligibleTier != null` ("Unlock higher limits — verify your trade") navigating to `KycUpgradeFlow`; hidden and replaced by `HivorrSuccessState` "Fully verified — maximum limits" when `tier_3`
- [ ] **FV-40:** `KycUpgradeFlow` exists at `lib/systems/verification/screens/kyc_upgrade_flow.dart` (`GET /verification/kyc/upgrade`): eligible-tier selector (radio/stepper over `tier_1..tier_3`), requirements checklist (identity doc ✓/pending, trade proof ✓/pending per `supabase/migrations/20260829090003_verification_admin_review_schema.sql:232`), CTA `HivorrButton(variant: primary, isLoading, isExpanded: true)` navigating to existing `IdentityDocumentUploadScreen` / `TradeProofUploadScreen` (`lib/systems/verification/screens/identity_document_upload_screen.dart:1`); **no new file picker** — upgrade is a router, not a duplicate upload

### 2.10 Required Functionality — UI Widgets

- [ ] **FV-41:** `KycLimitsCard` exists at `lib/systems/verification/widgets/kyc_limits_card.dart` — 4 `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` chips, value `textTheme.titleMedium`, label `textTheme.labelSmall` `colorScheme.onSurfaceVariant`; pending limits `outline` tint, approved `successContainer`
- [ ] **FV-42:** `KycTierBadge` exists at `lib/systems/verification/widgets/kyc_tier_badge.dart` — `Container(decoration: BoxDecoration(color: isVerified ? colorScheme.successContainer : colorScheme.primaryContainer, borderRadius: BorderRadius.circular(ext.radiusSm)))` soft, not hard shadow (`VISUAL-IDENTITY.md:226`)
- [ ] **FV-43:** `KycUpgradeCard` exists at `lib/systems/verification/widgets/kyc_upgrade_card.dart` — per-tier card ("tier_2 Trade Verified — ₦500k cashout" + "Unlocks: higher withdrawal limits" + `Icons.verified` tinted `colorScheme.secondary` when achieved); `KycLevelCard` (`lib/systems/verification/widgets/kyc_level_card.dart:1`) extended/reused, not duplicated
- [ ] **FV-44:** All widgets consume `AppTheme` tokens **only** — `Theme.of(context).colorScheme`, `textTheme`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` (`VISUAL-IDENTITY.md:176-190,219-235`); no `Colors.*`, no `Color(0xFF0B6E99)` inline (hex lives only in `lib/app/theme/app_colors.dart:16`), no `fontFamily` literal; responsive via `ResponsiveScaffold`/`shared/layouts/` (`ARCHITECTURE.md:122-124`) 16dp mobile / 24dp web pane

### 2.11 Required Functionality — Routing & DI

- [ ] **FV-45:** `RoutePaths.kycStatus = '/verification/kyc'` and `RoutePaths.kycUpgrade = '/verification/kyc/upgrade'` added to `lib/app/router/route_paths.dart`; `RouteNames.kycStatus`/`kycUpgrade` added; `app_router.dart:17` registers both — guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) authenticated only, no taxonomy gate, private flow (not SEO `/p/:slug/:id` `ARCHITECTURE.md:150`)
- [ ] **FV-46:** Barrels re-export all new symbols: `lib/systems/verification/verification.dart:1`, `lib/data/data_layer.dart:1`, new `lib/integrations/kyc/kyc.dart`
- [ ] **FV-47:** Factory `KycProvider.create(supabase: SupabaseClientProvider.client, kycProvider: MockKycProvider())` wired in bootstrap; screens consume `KycProvider`/`KycService` without importing `supabase.rpc` literals (`ARCHITECTURE.md:101-110`)

### 2.12 Expected Workflows

- [ ] **FV-48:** Happy path: `tier_0` all-zero defaults → `KycProvider.load()` fetches kycLevel + limits + status in parallel → status screen renders tier badge (unassigned grey) + 4 zero-limit chips + upgrade CTA → user opens upgrade flow → `requestUpgrade(targetTier: tier1)` validates `tier_1 > tier_0` → mock provider returns `pending` → screen shows "Verification in progress — we'll notify you" → admin approves server-side → `refreshStatus()` → `tier_1 active` badge `successContainer` + limits `₦50,000` daily / `₦100,000` cashout + `HivorrNotification`
- [ ] **FV-49:** Limit-guard workflow: `KycLimitGuard.isCashoutAllowed(limits: tier1, amount: 50000) == true`, `isCashoutAllowed(limits: tier1, amount: 600000) == false` — `suggestedUpgrade` surfaces `tier_2` guidance inline before any server call
- [ ] **FV-50:** Polling lifecycle: `Timer.periodic(15s)` while `pending` and screen foreground; cancels on terminal (`active`/`expired`) or screen pop; resumes on lifecycle foreground; pull-to-refresh calls `refreshStatus()` immediately (no wait for next tick)
- [ ] **FV-51:** Upgrade motivation: `tier_0` shows aspirational preview ("Verify identity → unlock ₦100k cashout") with primary CTA (not warning red); `tier_3` shows `HivorrSuccessState` celebration "Fully verified — maximum limits"
- [ ] **FV-52:** Rejection empathy: `status == rejected` renders `HivorrErrorState` with `decisionNotes` preview + single "Resubmit" CTA navigating to `IdentityDocumentUploadScreen`/`TradeProofUploadScreen` (new `entity_credentials` resubmission, not overwriting the reviewed row)
- [ ] **FV-53:** Notification integration: `tier_0 → tier_1` transition triggers `maybeNotify` exactly once → `HivorrNotification{priority: high, channel: system}` → UI re-fetches `getKycLevel()` from RPC before rendering upgraded badge (prevents spoofed local state)

### 2.13 Success Conditions

- [ ] **FV-54:** `verification_kyc_level_get` returns `{success:true, code:PLT000, data:{tier_code, status, limits:{daily, weekly, monthly, cashout}}}` with `tier_0` all-zero defaults when `entity_kyc_levels` has no row (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:712-718`)
- [ ] **FV-55:** `verification_status_get` returns aggregate `{kyc:{tier_code,status,limits}, identity_verified, trade_verifications:[...], pending/total}` (`659-680`) — `identity_verified = status=='active' && tier_code >= 'tier_1'` (`639`)
- [ ] **FV-56:** Service is provider-swappable — screens/systems consume `KycProvider`/`KycService`/`KycLimitGuard` without importing `SupabaseClient.rpc` literals or raw `verification_*` strings (`ARCHITECTURE.md:101-110`); `KycRepository.requestUpgrade` never performs `POST /rest/v1/entity_kyc_levels` (grant is `authenticated SELECT` only `:254`)

### 2.14 Error Handling Scenarios

- [ ] **FV-57:** `401 PLT001 auth` (unauthenticated) → `ApiExceptionKind.auth` surfaced → redirect `/login` via `RouteGuard`
- [ ] **FV-58:** `403 PLT002 forbidden` (client attempt to write `entity_kyc_levels.tier_code` / invoke `verification_review_approve`) → `ApiExceptionKind.forbidden` surfaced — no SQL leaked
- [ ] **FV-59:** `400/422 PLT003 validation` (invalid `targetTier` ≤ current, malformed envelope `success:false`) → `ApiExceptionKind.validation` — inline field error, never toast; envelope `success:false` → `ApiException` from `VerificationEnvelopeParser.unwrap`
- [ ] **FV-60:** `404 PLT004 notFound` (cross-entity `p_entity_id ≠ auth.uid()` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:622`) → `ApiExceptionKind.notFound` surfaced; null `p_entity_id` resolves to self only
- [ ] **FV-61:** `5xx PLT999 server` → `ApiExceptionKind.server` surfaced; retry 3x prod / 4x dev with `500ms → 8s` backoff (`lib/core/api/api_config.dart:40-49`); no unbounded retry storm
- [ ] **FV-62:** Network timeout → `ApiExceptionKind.timeout` mapped via `ApiExceptionMapper._mapTransport`; backoff applied; raw `DioException` never propagates — `BaseApiService.invoke:33` normalizes all transport errors
- [ ] **FV-63:** `supabase.rpc` invoked with `params: {p_entity_id}` correctly; invalid/empty payload for `KycProvider.verify` validated before network (`PLT003` before `dio` spy is called)

### 2.15 Important User Interactions

- [ ] **FV-64:** Fail-fast limit preview: amount field helper invokes `KycLimitGuard` per keystroke — `₦600k` on `tier_1` (cashout 100k) shows inline `HelperText` with `colorScheme.error` "Your tier_1 cashout limit is ₦100,000 — verify your trade to unlock ₦500,000" instead of waiting for server `PLT006` — critical on Nigerian 3G
- [ ] **FV-65:** Pull-to-refresh on status screen calls `provider.refreshStatus()` immediately — no waiting for the next 15s poll tick
- [ ] **FV-66:** Upgrade path clarity: first eligible tier shown first (`eligibleUpgradePath` `.first`), "See all tiers" expansion for `tier_3` preview; CTA is `HivorrButton(isLoading)` showing `HivorrLoader` during request; `tier_3` shows `HivorrSuccessState` (no dead-end)
- [ ] **FV-67:** Premium branded states — `HivorrEmptyState` "Verify your identity to unlock higher limits", `HivorrLoadingState`, `HivorrErrorState` with `decisionNotes`, `HivorrSuccessState` — wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), never bare `CircularProgressIndicator`

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Files added ONLY under `lib/data/datasources/remote/kyc_remote_data_source.dart`, `supabase_kyc_remote_data_source.dart`, `lib/data/repositories/kyc_repository*.dart`, `lib/data/providers/kyc_provider.dart`, `lib/data/mappers/verification_mapper.dart` (extend), `lib/systems/verification/models/kyc_tier.dart`, `lib/systems/verification/services/kyc_service.dart`, `lib/systems/verification/gate/kyc_limit_guard.dart`, `lib/systems/verification/screens/kyc_*.dart`, `lib/systems/verification/widgets/kyc_*.dart`, `lib/systems/verification/verification.dart`, `lib/integrations/kyc/*.dart` (+ `kyc.dart` barrel), `lib/app/router/` (2 route updates), `lib/data/data_layer.dart` (barrel update), `test/**` — no files in `lib/core/storage/`, `lib/engine/`, `lib/integrations/payment_gateways/`, `lib/systems/finance/`, or `lib/systems/` other than `verification/`
- [ ] **TV-02:** No DDL on `public.*` or `storage.*` — `git diff --stat supabase/` shows 0; no `supabase/migrations/*` added, no `supabase/config.toml` modified; no `lib/core/storage/*` modification (reuses `SupabaseStorageService:43`)
- [ ] **TV-03:** Module placement conforms to `ARCHITECTURE.md:56,101-138` — `lib/data/` owns RPC transport + DTOs (reusable across EP-02-10/11/16/18), `lib/systems/verification/` owns tier vocabulary + guard + upgrade UX, `lib/integrations/kyc/` owns provider seam (within approved integrations surface `112-120`); no new top-level `lib/` directory beyond `lib/integrations/kyc/`
- [ ] **TV-04:** Interface-first pattern — abstract `KycRemoteDataSource` separate from `SupabaseKycRemoteDataSource`; abstract `KycRepository` separate from `KycRepositoryImpl`; abstract `KycProvider` (integration seam) separate from `MockKycProvider`; repository never imports `lib/systems/` widgets (unidirectional `data → systems`)
- [ ] **TV-05:** No `public.*`/`storage.*` SECURITY DEFINER functions, no `GRANT`, no `CREATE POLICY` — `supabase/migrations/` untouched
- [ ] **TV-06:** Dependency wiring uses `SupabaseClientProvider.client` safe accessor (`lib/core/api/supabase/supabase_client_provider.dart:19`) + `SupabaseClientProvider.currentAccessToken` (`:29`); no direct `Supabase.instance.client` leakage in business logic beyond datasource

### 3.2 Required System Behavior

- [ ] **TV-07:** `SupabaseKycRemoteDataSource` reuses `VerificationEnvelopeParser.unwrap` (`lib/data/datasources/remote/verification_envelope_parser.dart:29`) — validates `success==true && code=='PLT000'`; no second/duplicate parser implementation
- [ ] **TV-08:** Every public method throws only `ApiException` (`lib/core/api/exceptions/api_exception.dart:6-66`) or `DataException` — never raw `Supabase`/`DioException`; `ApiExceptionMapper` preserves `kind`, `code`, `statusCode` with safe message (no SQL/stack leaked)
- [ ] **TV-09:** `KycRepository.requestUpgrade` validates `targetTier.code > current.tier_code` (string compare) BEFORE provider delegation — unit test proves provider spy not invoked on `targetTier <= current`
- [ ] **TV-10:** Client never writes `entity_kyc_levels.tier_code/status/assigned_at` or `kyc_tiers.*` — `grep -r "tier_code.*=" lib/systems/verification lib/integrations/kyc lib/data` = 0 for assignment (read-only display permitted via RPC)
- [ ] **TV-11:** Polling `Timer.periodic(15s)` pauses on `WidgetsBindingObserver.didChangeAppLifecycleState` background and cancels on `AppRouter didPush/didPop` + `dispose()` — respects `supabase_realtime` exclusion (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:798-815`)
- [ ] **TV-12:** `KycRemoteDataSource` does NOT inject `StorageService` or `NotificationProvider` (persistence-agnostic `lib/data/` pattern); `KycProvider` ChangeNotifier does not hold `SupabaseClientProvider` singleton — repository holds the client
- [ ] **TV-13:** `KycLimitGuard` is pure Dart (`abstract final class`) — no I/O, no globals, no Flutter imports; O(1) safe to evaluate per keystroke
- [ ] **TV-14:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) log `entityId suffix (***last4)`, `tierCode`, `providerName`, `limits.*` — never logs `legal_name`, raw `bvn`/`nin`/`dob`, or `providerReference` beyond preview; `MonitoringService` spans `kyc.*` sampled via `MonitoringConfig`

### 3.3 Module Integration

- [ ] **TV-15:** No conflict with `VerificationRemoteDataSource` (`lib/data/datasources/remote/supabase_verification_remote_data_source.dart:16-90`) — `KycRemoteDataSource` is a dedicated thin wrapper over the same frozen RPCs enabling `KycRepository` to evolve independently (future `kyc_upgrade_request` RPC without touching `EP-02-10`)
- [ ] **TV-16:** `VerificationEnvelopeParser` + `DataExceptionMapper` shared (not re-implemented) with `lib/data/datasources/remote/` — single parsing path
- [ ] **TV-17:** `KycProvider` ChangeNotifier mirrors `VerificationProvider` (`lib/data/providers/verification_provider.dart:42`) read/poll pattern — no third polling timer, no notification duplication
- [ ] **TV-18:** `lib/integrations/kyc/` imports `lib/systems/verification/models/kyc_tier.dart` (or `lib/data/entities/kyc_tier.dart`) only for the `enum` — never imports `lib/systems/verification/widgets/`, `lib/data/providers/`, or Supabase SDK (mock is SDK-free)
- [ ] **TV-19:** `lib/systems/verification/` consumable by `EP-02-16` (payout guard `isCashoutAllowed`) and `EP-02-18` (onboarding imports `KycService`) without modification; `KycLimitGuard` reusable client-side mirror of server-enforced limits
- [ ] **TV-20:** No `lib/integrations/payment_gateways/*` import (`EP-02-09`); no `financial_*` import; no NIBSS BFN name enquiry in this task (`EP-02-09/16`)

### 3.4 Technical Requirements from Plan

- [ ] **TV-21:** `flutter analyze` + `dart analyze` clean
- [ ] **TV-22:** `KycRemoteDataSource`/`SupabaseKycRemoteDataSource` dartdoc documents RPC envelope contract, `VerificationEnvelopeParser.unwrap` reuse, `DataExceptionMapper` mapping, `BaseApiService.invoke` pattern
- [ ] **TV-23:** `KycRepository` dartdoc documents `requestUpgrade` validation-before-provider, `eligibleUpgradePath`, never-writes-`entity_kyc_levels` server-authoritative rule (`AGENT.md:16` Rule 4); `KycLimitGuard` dartdoc documents all 4 pure helpers
- [ ] **TV-24:** `KycProvider` (ChangeNotifier) dartdoc documents 15s polling lifecycle, `maybeNotify` tier-diff idempotence, `pausePolling`/`resumePolling`; `KycProvider`/`MockKycProvider`/`KycProviderRegistry` dartdoc documents the deferred-provider seam (SmileID/Dojah EP-08) and extensibility
- [ ] **TV-25:** `PerformanceTracer` spans `kyc.level.get.duration`, `kyc.limits.get.duration`, `kyc.upgrade.request.duration` tagged `kyc.tier`/`kyc.status` (no PII), sampled via `MonitoringConfig`

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **DV-01:** `kyc_tiers` seed exact — `tier_0` all-zero, `tier_1` (50000/200000/800000/100000), `tier_2` (200000/800000/3000000/500000), `tier_3` (1000000/4000000/15000000/2000000) with `daily_limit/weekly_limit/monthly_limit/cashout_limit numeric >= 0` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:46-63,228-234`) — created by `EP-02-03`, read-only here; `is_active, sort_order` index `kyc_tiers_is_active_sort_idx` `:70-71`
- [ ] **DV-02:** `entity_kyc_levels` one row per entity (`unique(entity_id)` `:98`), FK to `entities(id)` + `kyc_tiers(tier_code)`, `status in ('pending','active','expired')` `:99` — assigned server-side only by `verification_review_approve` (`:491-515` conditional `tier_code < excluded.tier_code`, never downgrading); client creates **no** rows

### 4.2 Data Updates

- [ ] **DV-03:** Client never updates `entity_kyc_levels.tier_code/status/assigned_at` or `kyc_tiers.*` — `authenticated` grants are `SELECT` only (`:250`, `:254`); the only mutation path is service-role `verification_review_approve` (`:491-515`) which is never invoked by client code (`service_role` grants `:792-793`)
- [ ] **DV-04:** Upgrade state transition is server-authoritative — `requestUpgrade` initiates provider check + re-reads `getKycLevel()` after provider signals approval; no local `tier_code` write; spoofed local state prevented by re-fetch before badge render

### 4.3 Data Relationships

- [ ] **DV-05:** `verification_status_get` aggregate includes `kyc:{tier_code, status, limits:{daily, weekly, monthly, cashout}}`, `identity_verified` bool (`:639`), `trade_verifications:[{profession_id, trade_verification_status}]`, `pending/total` counts (`:659-680`) — display-only
- [ ] **DV-06:** `verification_kyc_level_get` returns `{tier_code, status, limits}` (`:719-733`); `verification_limits_get` returns `{tier_code, daily, weekly, monthly, cashout}` (`:770-779`) — both default to `tier_0` all-zero when no `entity_kyc_levels` row (`:633-637, :764-768`)
- [ ] **DV-07:** `identity_verified` string-compare invariant holds — `tier_code >= 'tier_1'` is valid only because `tier_0..tier_3` are single-digit; documented + covered by `kyc_tier_test` and `kyc_mapper_test`

### 4.4 Data Accuracy

- [ ] **DV-08:** Tier mapping exact: `KycTier.fromCode('tier_0') == tier0` … `fromCode('tier_3') == tier3`; null/missing tier resolves to `tier_0` defaults — mapper unit test covers all 4 values
- [ ] **DV-09:** Limit values exact per tier — `tier_1` daily 50000 / weekly 200000 / monthly 800000 / cashout 100000 asserted in `kyc_repository_test` and integration test (`cyc_flow_test` asserts `limits.cashout == 100000`)
- [ ] **DV-10:** `status` mapping `pending|active|expired` handled; `KycVerificationResult.status` `pending|approved|rejected` is **display-only** — no privilege derived from provider `approved` without server `getKycLevel()` re-read
- [ ] **DV-11:** `decision_notes` null-safe, preview length ≤120 chars for notification body; `providerReference` nullable

### 4.5 Data Integrity

- [ ] **DV-12:** `verification_audit_trail` `kyc_level_assigned` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:212`) written server-side by `verification_review_approve` (`:510-515`) — client never inserts audit rows directly
- [ ] **DV-13:** Idempotency — `maybeNotify` fires once per aggregate tier transition (prev→next diff), never per poll tick; duplicate `requestUpgrade` for same `targetTier` surfaces conflict via `maybeNotify` idempotence, not a second notification
- [ ] **DV-14:** No `public.*` table mutation by client — `verification_kyc_level_get`, `verification_limits_get`, `verification_status_get` invoked with read grant only; `git diff --stat supabase/` = 0
- [ ] **DV-15:** No persistence of `tier_code`/limits to disk (no Hive local data source) — `KycProvider` memoizes in memory only; invalidation via `refreshStatus()` on resume/submit/notification
- [ ] **DV-16:** No currency-specific override data — base NGN limits are the single source of truth (`EP-02-16` layers per-currency overrides later, no `financial_*` FK in this task)

---

## 5. Security Verification

- [ ] **SV-01:** Server-authoritative KYC (`AGENT.md:16` Rule 4) — client never writes `entity_kyc_levels.tier_code/status/assigned_at` or `kyc_tiers.*`; `grep -r "tier_code.*=" lib/systems/verification lib/integrations/kyc lib/data` = 0 for assignment (read-only display permitted); all transitions via service-role `verification_review_approve` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:491-515`)
- [ ] **SV-02:** RLS default-deny inherited — all 5 verification tables `revoke all from anon, authenticated` (`:244-246`) + policies `to authenticated` only; `kyc_tiers` `authenticated SELECT` (`:250`, policy `kyc_tiers_authenticated_select` `:279-281`) and `entity_kyc_levels` `authenticated SELECT` (`:254`); `anon` zero read verified in `supabase/tests/database/021_*`; `RouteGuard` redirects `/login`
- [ ] **SV-03:** Client `POST {tier_code:'tier_3'}` to `/rest/v1/entity_kyc_levels` would return `403 PLT002` — no `authenticated` INSERT/UPDATE grant (`:254` is SELECT only); `grep` + unit test proves repository never issues such call
- [ ] **SV-04:** No `service_role` leak — `grep -r "service_role" lib/` = 0; `KycProvider.verify`/`MockKycProvider` never hold `service_role` key; `SupabaseClientProvider.client` uses `anon`/`authenticated` role with RLS
- [ ] **SV-05:** Review/admin RPCs not invocable by client — `verification_review_approve/reject` granted `service_role` only (`:792-793`); authenticated attempt → `42501` mapped to `PLT002 forbidden` (unit test `kyc_remote_data_source` / seam)
- [ ] **SV-06:** Execution model respected — all 3 read RPCs `SECURITY INVOKER` (`:598, :691, :746`), RLS applies inside body; granted `authenticated, service_role` (`:794-796`)
- [ ] **SV-07:** Auth token protection — token via `SupabaseClientProvider.currentAccessToken:29` never logged; `PiiRedactor` masks `entityId` to `***last4`; never logs `legal_name`, raw `bvn`/`nin`/`dob`, or `providerReference` beyond redacted form
- [ ] **SV-08:** PII scope minimal — KYC status is RPC-derived aggregate; no identity document bytes, `document_path`, or storage URLs pass through this task (`EP-02-10/11` own uploads)
- [ ] **SV-09:** Limit guard is client convenience, NOT authority — authoritative enforcement is server-side `verification_limits_get` → `financial_withdraw` (`EP-02-16`) checking `amount <= cashout_limit`; client guard mismatch never grants funds (server returns `PLT006`)
- [ ] **SV-10:** Time-of-check/race — server `entity_kyc_levels` `unique(entity_id)` + conditional `tier_code < excluded.tier_code` (`:494-508`) prevents downgrade races; client emits one notification via `maybeNotify` idempotence
- [ ] **SV-11:** Auth state isolation — `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); `kyc_tiers` per-environment via EP-02-03 migration, no cross-env read
- [ ] **SV-12:** No SQL injection / no REST write — RPC calls use parameterized `supabase.rpc('verification_*', params: {...})`; no raw SQL, no dynamic query interpolation; no `POST /rest/v1/entity_kyc_levels`

---

## 6. Performance Verification

- [ ] **PV-01:** Polling cost — `Timer.periodic(15s)` only while `kycLevel.status == pending` (or `status.pendingSubmissions > 0`) and screen visible; 1 RPC/15s ≈ 240 req/hour peak; all 3 read RPCs `STABLE` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:598,691,746`) and indexed (`kyc_tiers_is_active_sort_idx` `:70`, `entity_kyc_levels_entity_id_key` `:98`) — negligible load
- [ ] **PV-02:** Polling pause — `WidgetsBindingObserver.didChangeAppLifecycleState(background)` pauses timer; `AppRouter didPush/didPop` cancels on navigate away; `dispose()` cancels; no wasted RPCs on background/backgrounded screens
- [ ] **PV-03:** Backoff — `timeout/network` errors trigger exponential `500ms → 8s` backoff (`lib/core/api/api_config.dart:45-49`, `maxRetries 3 prod / 4 dev`); no retry storm; terminal `active/expired` cancels timer immediately
- [ ] **PV-04:** Parallel fetch — `KycProvider.load()` uses `Future.wait` over `getKycLevel()` + `getLimits()` + `getStatus()` (or derives `kycLevel` from `getStatus()` to save one RPC); no sequential round-trips
- [ ] **PV-05:** Caching — `KycProvider` memoizes `kycLevel` + `limits` + `status` in memory (no Hive local data source); invalidate via `refreshStatus()` on resume, submit, or push notification
- [ ] **PV-06:** Guard evaluation cost — `KycLimitGuard` pure arithmetic O(1) — free to call per keystroke in amount field for live limit preview
- [ ] **PV-07:** Validation cost — `KycTier.fromCode` map lookup O(1) + `tierCodeCompare` string compare O(n) on ≤6-char string — microseconds, avoids wasted RPC on invalid upgrade target
- [ ] **PV-08:** `PerformanceTracer` spans (`kyc.level.get.duration`, `kyc.limits.get.duration`, `kyc.upgrade.request.duration`) sampled via `MonitoringConfig`, tags `kyc.tier`/`kyc.status`, no PII — lightweight overhead
- [ ] **PV-09:** Notification overhead — one `HivorrNotification` per upward tier transition (idempotent diff), no per-tick noise; local-only, no `supabase_realtime` payload

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/data/verification/kyc_*` + `test/unit/data/providers/` + `test/unit/systems/verification/` + `test/unit/integrations/kyc/`

Pattern mirrors `test/unit/core/api/api_exception_mapper_test.dart` + fakes (`test/support/fakes/fake_supabase.dart`, `fake_kyc_remote_data_source.dart`, `fake_kyc_provider.dart`) — no live Supabase.

- [ ] **TT-01:** `kyc_remote_data_source_test.dart` ≥12 cases green — mock `SupabaseClient.rpc` via fake: `verification_kyc_level_get → {success:true, code:PLT000, data:{tier_code:tier_0, status:pending, limits:{daily:0...}}}` success; `verification_limits_get → {tier_code:tier_1, daily:50000...}` success; `verification_status_get(p_entity_id ≠ auth.uid()) → PLT004 → ApiExceptionKind.notFound`; envelope `success:false → PLT003 → validation`; `401→PLT001 auth`, `500→PLT999` via `ApiExceptionMapper`
- [ ] **TT-02:** `kyc_repository_test.dart` ≥16 cases green — fake `SupabaseKycRemoteDataSource` + fake `KycProvider`: validates `getKycLevel` maps `tier_0` all-zero defaults; `getLimits` maps `tier_1` 50k/200k/800k/100k; `getStatus` maps `trade_verifications` empty for KYC-only; `requestUpgrade` with `targetTier <= current` throws `validation` **before** provider spy called; `eligibleUpgradePath(tier_1) == [tier2, tier3]`; cross-entity `getStatus(entityId)` rejected
- [ ] **TT-03:** `kyc_provider_test.dart` ≥14 cases green — `ChangeNotifier` with mocked repository: `load()` sets `loadState=loading` then `success`, fetches kycLevel + limits + status; polling `Timer` mocked via `fakeAsync` — 15s ticks until `tier_1 active`, cancels on dispose/terminal; `maybeNotify` emits exactly one `HivorrNotification` on tier upgrade (`tier_0 → tier_1`); `requestUpgrade` delegates to `kycProviderRegistry.resolveForTier`; `pausePolling`/`resumePolling` via `WidgetsBindingObserver`
- [ ] **TT-04:** `kyc_limit_guard_test.dart` ≥10 cases green — pure logic: `isCashoutAllowed` `true` iff `amount <= cashout`; `remainingFor` computes `limit - spent` for daily/weekly/monthly; `suggestedUpgrade` returns `null` when `amount <= current.cashout` else next covering tier; `canTransact` respects `daily`; boundary `amount == limits` → true, `amount == 0`/negative → false — **100% coverage**
- [ ] **TT-05:** `kyc_provider_seam_test.dart` ≥10 cases green — `MockKycProvider.verify` returns `pending` after 800ms; `KycProviderRegistry.resolveForTier(tier2) == mock`; invalid `payload` before network → `validation`; `verify` with `targetTier == tier0` throws before `dio` spy called
- [ ] **TT-06:** `kyc_mapper_test.dart` ≥8 cases green — `KycLevelDto.fromJson → KycLevel` enum mapping `tier_0..tier_3`, limits `daily/weekly/monthly/cashout` exact, status `pending|active|expired`, null handling → `tier_0` defaults; `KycTier.fromCode('tier_2') == tier2`; `tierCodeCompare` lexicographic holds — **100%**
- [ ] **TT-07:** `kyc_tier_test.dart` ≥6 cases green — enum labels ("Identity Verified", "Trade Verified"), `isVerified` (`tier_0` false, `tier_1` true), `values.length == 4`, extensibility (new enum value doesn't break `fromCode`) — **100%**
- [ ] **TT-08:** Total **≥76 unit assertions** green; repository/provider ≥90%, mappers/tier 100%, guard 100% (`flutter test --coverage`)

### 7.2 Automated Widget Suite — `test/widget/systems/verification/kyc_*`

- [ ] **TT-09:** `kyc_status_screen_test.dart` ≥12 cases green — pump with `Provider<KycProvider>` fake + `MaterialApp` `AppTheme.light`: tier badge renders `tier_1` with `successContainer` when active, `warningContainer` when pending; limits grid shows `₦50,000` daily; `VerificationTimeline` visible; upgrade CTA visible when `nextEligibleTier != null`, hidden when `tier_3`; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily` literal), spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:220`); `grep Colors.` assert = 0
- [ ] **TT-10:** `kyc_upgrade_flow_test.dart` ≥10 cases green — pump with `KycProvider` mock `tier_1`: first eligible `tier_2` selected, requirements checklist shows identity ✓, trade proof pending; `HivorrButton.isLoading` shows `HivorrLoader` (`lib/app/widgets/hivorr_loader.dart:1`), tap navigates to `TradeProofUploadScreen`; `tier_0` shows identity CTA; `tier_3` shows `HivorrSuccessState`
- [ ] **TT-11:** `kyc_limits_card_test.dart` ≥8 cases green — chips colors `primaryContainer` selected tier vs `outline` unachieved, no hardcoded hex, semantics `Semantics(label: 'Daily limit ₦50,000')`
- [ ] **TT-12:** `kyc_tier_badge_test.dart` ≥8 cases green — badge colors `successContainer`/`primaryContainer`/`outline` per status, no `Color(0x...)`, soft elevation (no hard shadow)
- [ ] **TT-13:** All widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)` — AppTheme harness pattern from existing verification test suite

### 7.3 Integration (Fake-E2E) — `test/integration/verification/`

- [ ] **TT-14:** `test/integration/verification/kyc_flow_test.dart` green — fake `SupabaseClient.rpc` map (canned `verification_kyc_level_get`/`verification_limits_get`/`verification_status_get` envelopes) + real `KycRepositoryImpl` + `MockKycProvider`: `getStatus() → tier_0` → `repo.requestUpgrade(targetTier: KycTier.tier1)` → `mock.verify → pending` → mock `verification_review_approve` side-effect (inject `KycLevelDto{tier_code: tier_1, status: active}`) → `provider.refreshStatus()` → `kycLevel.tierCode == tier_1` + `limits.cashout == 100000` + `KycLimitGuard.isCashoutAllowed(amount: 50000) == true`, `600000 == false`; no `supabase start` container needed (live `supabase db test` is source-of-truth for RLS)

### 7.4 Regression Guard

- [ ] **TT-15:** `flutter analyze` + `dart analyze` clean
- [ ] **TT-16:** `flutter test --coverage` — domain ≥80% line coverage on KYC slice; guard 100%, provider ≥90%, mappers/tier 100%; widgets theme-asserted
- [ ] **TT-17:** `supabase db test` full suite `001..017` + verification `021_*` green — zero regressions on `public.*` RLS/posture
- [ ] **TT-18:** Lens greps — `grep -r "Colors\.\|Color(0x" lib/systems/verification lib/integrations/kyc lib/data` = 0 (except `lib/app/theme/app_colors.dart:16`); `grep -r "fontFamily" lib/systems/verification lib/integrations/kyc` = 0; `grep -r "service_role" lib/` = 0; `grep -r "tier_code" lib/systems/verification lib/integrations/kyc lib/data` read-only display (no assignment)
- [ ] **TT-19:** `git diff --stat supabase/` = 0; `git diff --stat lib/core/storage` = 0; `git diff --stat lib/integrations/payment_gateways` = 0; `git diff --stat lib/systems/finance` = 0

### 7.5 Edge Cases

- [ ] **TT-20:** `tier_3` → `eligibleUpgradePath == []` → status screen hides CTA, shows `HivorrSuccessState` "Fully verified — maximum limits"
- [ ] **TT-21:** `tier_0` (no `entity_kyc_levels` row) → all-zero defaults from all 3 RPCs — screen renders zero-value chips + upgrade CTA, never throws
- [ ] **TT-22:** Exact-tier boundary — `amount == cashout` allowed, `amount == cashout + 1` denied; `amount == 0`/negative denied by `canTransact`/`isCashoutAllowed`
- [ ] **TT-23:** `p_entity_id` null (self) vs supplied (admin) — no cross-entity read via client; `PLT004` if forced; null resolves `auth.uid()`
- [ ] **TT-24:** `KycVerificationResult.status` variants `pending|approved|rejected` mapped display-only; `providerReference` null-safe
- [ ] **TT-25:** Duplicate `requestUpgrade` same `targetTier` poll — `maybeNotify` idempotent (one notification total)
- [ ] **TT-26:** `status: expired` (grey `outline` badge) renders + upgrade CTA available (re-verification path)

### 7.6 Failure Scenarios

- [ ] **TT-27:** `requestUpgrade` with `targetTier == current` or lower → `DataValidationException(PLT003)` inline field error, provider spy **not** called
- [ ] **TT-28:** `401 → PLT001` unauth → redirect `/login` via `RouteGuard`; `load()` surfaces `ApiExceptionKind.auth`, not raw error
- [ ] **TT-29:** Client attempt to invoke `verification_review_approve/reject` → `42501` mapped to `PLT002 forbidden` (grants `:792-793` service_role only)
- [ ] **TT-30:** Envelope `success:false, code:PLT003` → `ApiExceptionKind.validation` surfaced — no raw JSON to UI
- [ ] **TT-31:** Network timeout → `ApiExceptionKind.timeout` + backoff `500ms→8s`; visible retry affordance (pull-to-refresh / error state)
- [ ] **TT-32:** `5xx PLT999` retry 3x prod / 4x dev bounded; no infinite retry loop

### 7.7 Manual Testing

- [ ] **TT-33:** Manual spot-check (optional, with `supabase start`): `tier_0` view → upgrade flow → `requestUpgrade(tier1)` → mock `pending` → "Verification in progress — we'll notify you" → admin approves via `verification_review_approve` → 15s poll → `tier_1 active` badge + limits `₦100,000` cashout + notification → guard allows `₦50,000`, blocks `₦600,000` with inline upgrade suggestion

---

## 8. User Acceptance Verification

This task delivers the **Stage 4 KYC seam** — the proportional risk-containment trust gate (`AGENT.md:15` Rule 2) that makes server-enforced tier limits visible to the entity and unblocks KYC-driven cashout enforcement. User acceptance is verified through tier-vocabulary correctness, limit visibility, upgrade-flow motivation, polling behavior, and downstream readiness.

- [ ] **UA-01:** The project lead can open `/verification/kyc` and see their current tier badge (amber `warningContainer` when pending, green `successContainer` when active, grey `outline` when unassigned/expired), the 4 limit chips formatted in NGN (`₦50,000` daily / `₦200,000` weekly / `₦800,000` monthly / `₦100,000` cashout for `tier_1`), and the `VerificationTimeline` — all AppTheme-token driven, no raw colors
- [ ] **UA-02:** Upgrade flow is motivational not shaming — `tier_0` shows "Verify identity → unlock ₦100k cashout" with primary CTA; `tier_1` shows next eligible `tier_2` requirements (identity doc ✓, trade proof pending); `tier_3` shows `HivorrSuccessState` "Fully verified — maximum limits"; "See all tiers" expansion previews `tier_3`
- [ ] **UA-03:** Fail-fast limit preview — entering `₦600k` on `tier_1` shows inline `colorScheme.error` helper "Your tier_1 cashout limit is ₦100,000 — verify your trade to unlock ₦500,000" instantly (no 2s server `PLT006`), critical on Nigerian 3G
- [ ] **UA-04:** Polling is user-expected — "Verification in progress — we'll notify you" copy sets expectation; 15s poll while pending; pull-to-refresh immediate; notification arrives once on upgrade; badge only renders upgraded tier after re-fetch (no spoofed local state)
- [ ] **UA-05:** Rejection empathy — `HivorrErrorState` shows `decisionNotes` (e.g., "NIN photo blurred — please retake") + single "Resubmit" CTA routing to existing upload screens without overwriting reviewed rows
- [ ] **UA-06:** Premium finish — `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), warm microcopy (`VISUAL-IDENTITY.md:241`), soft elevation not hard shadow, 8pt grid, ≥48dp touch targets, 16dp mobile / 24dp web responsive panes, light/dark WCAG AA `#0B6E99`
- [ ] **UA-07:** No financial/escrow leakage — `grep -r "financial_\|escrow\|payout" lib/systems/verification lib/integrations/kyc` = 0; no `lib/integrations/payment_gateways` import; no ledger write, no `financial_*` mutation (limit guard is read + convenience, not a money-movement path)
- [ ] **UA-08:** Security posture transparent — `grep -r "service_role" lib/` = 0, `grep -r "tier_code.*="` assignment = 0; client reads KYC state via RPC only, never writes; anonymous/unauthenticated access redirects to `/login`
- [ ] **UA-09:** Downstream unblocked — `EP-02-16` (payouts) can consume `KycLimitGuard.isCashoutAllowed`/`suggestedUpgrade` before `financial_withdraw`; `EP-02-18` (onboarding) imports `KycService`/`KycProvider` without `supabase.rpc` literals; future SmileID/Dojah provider = new file + registry entry, zero `systems/` change (Open/Closed)

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-12 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/data/datasources/remote/kyc_remote_data_source.dart` exists — abstract `KycRemoteDataSource{getKycLevel, getLimits, getStatus({entityId})}` | File inspection | ☐ |
| 2 | `lib/data/datasources/remote/supabase_kyc_remote_data_source.dart` exists — `extends BaseApiService`, `supabase.rpc('verification_kyc_level_get'/'verification_limits_get'/'verification_status_get')`, `VerificationEnvelopeParser.unwrap`, `DataExceptionMapper` | Code review + unit test | ☐ |
| 3 | `lib/systems/verification/models/kyc_tier.dart` defines `KycTier` enum (`tier0..tier3` ↔ `'tier_0'..'tier_3'`, `displayLabel`, `isVerified`, `fromCode`, `cashoutLimit`) — extensible without schema | File + unit test | ☐ |
| 4 | `lib/integrations/kyc/kyc_provider.dart` defines abstract `KycProvider{providerName, verify({entityId, targetTier, payload}) → KycVerificationResult{status, providerReference}}` | File inspection | ☐ |
| 5 | `lib/integrations/kyc/mock_kyc_provider.dart` implements `KycProvider` — `MockKycProvider` returns `pending` after 800ms, no `SupabaseClient`/`service_role` | File + unit test | ☐ |
| 6 | `lib/integrations/kyc/kyc_provider_registry.dart` defines `KycProviderRegistry.resolveForTier` — per-tier routing seam, mock primary by default | Unit test | ☐ |
| 7 | `lib/data/repositories/kyc_repository.dart` + `kyc_repository_impl.dart` define `KycRepository{getKycLevel, getLimits, getStatus, requestUpgrade, eligibleUpgradePath}` — validates `targetTier > current` before provider (spy test), never writes `entity_kyc_levels` | Unit test | ☐ |
| 8 | `lib/systems/verification/services/kyc_service.dart` facade (redacted logging + tracer) + `lib/systems/verification/gate/kyc_limit_guard.dart` pure `canTransact`/`isCashoutAllowed`/`remainingFor`/`suggestedUpgrade` | File + unit test (guard 100%) | ☐ |
| 9 | `lib/data/providers/kyc_provider.dart` `ChangeNotifier` holds `kycLevel/limits/status/loadState`, `load()`/`refreshStatus()`/`requestUpgrade()`, `Timer.periodic(15s)` while `pending`, `pausePolling`/`resumePolling`, `maybeNotify` tier-upgrade `HivorrNotification`, `dispose` cancels — mirrors `lib/data/providers/verification_provider.dart:42` | Unit test via `fakeAsync` | ☐ |
| 10 | `lib/systems/verification/screens/kyc_status_screen.dart` exists — `GET /verification/kyc`, tier badge + limits grid + timeline + upgrade CTA, `AppTheme` tokens only, responsive | Widget test | ☐ |
| 11 | `lib/systems/verification/screens/kyc_upgrade_flow.dart` exists — `GET /verification/kyc/upgrade`, eligible tiers + requirements checklist + CTA to existing upload screens (no new file picker) | Widget test | ☐ |
| 12 | `lib/systems/verification/widgets/kyc_limits_card.dart` / `kyc_tier_badge.dart` / `kyc_upgrade_card.dart` exist (or `kyc_level_card.dart` extended) — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp (`VISUAL-IDENTITY.md:221`) | Widget test | ☐ |
| 13 | Barrels `lib/systems/verification/verification.dart:1` + `lib/data/data_layer.dart:1` + `lib/integrations/kyc/kyc.dart` re-export all new symbols | File inspection | ☐ |
| 14 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `kycStatus='/verification/kyc'` + `kycUpgrade='/verification/kyc/upgrade'` guarded by `RouteGuard` (authenticated) | File + `go_router` smoke | ☐ |
| 15 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` | ☐ |
| 16 | No `lib/core/storage/*`, `lib/integrations/payment_gateways/*`, `lib/systems/finance/*` changes — diffs = 0 | `git diff --stat` | ☐ |
| 17 | No `service_role`/secret leakage — `grep -r "service_role" lib/` = 0; no client `tier_code`/`entity_kyc_levels` write (`grep -r "tier_code.*="` assignment = 0, read-only display) | `grep` + code review | ☐ |
| 18 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/verification lib/integrations/kyc lib/data` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/verification lib/integrations/kyc` = 0 | `grep` | ☐ |
| 19 | `test/unit/data/verification/kyc_remote_data_source_test.dart` ≥12 cases green (RPC envelope, `PLT001/003/004/999`) | `flutter test` | ☐ |
| 20 | `test/unit/data/verification/kyc_repository_test.dart` ≥16 + `kyc_mapper_test.dart` ≥8 + `kyc_tier_test.dart` ≥6 green | `flutter test` | ☐ |
| 21 | `test/unit/systems/verification/kyc_limit_guard_test.dart` ≥10 (100%) + `test/unit/integrations/kyc/kyc_provider_seam_test.dart` ≥10 green | `flutter test` | ☐ |
| 22 | `test/unit/data/providers/kyc_provider_test.dart` ≥14 cases green (`fakeAsync` 15s ticks until `active`, `maybeNotify` once per upgrade, lifecycle pause/resume) | `flutter test` | ☐ |
| 23 | `test/widget/systems/verification/kyc_status_screen_test.dart` ≥12 + `kyc_upgrade_flow_test.dart` ≥10 + `kyc_limits_card_test.dart` ≥8 + `kyc_tier_badge_test.dart` ≥8 green — token + layout + `grep Colors.` = 0 asserts | `flutter test` | ☐ |
| 24 | `test/integration/verification/kyc_flow_test.dart` fake-E2E green: tier0 → upgrade → verify → tier1 → guard allows/denies cashout | `flutter test` | ☐ |
| 25 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI | ☐ |
| 26 | `supabase db test` full suite `001-017` + verification `021_*` green — no RLS/role regression | `supabase db test` | ☐ |
| 27 | `flutter test` total **≥76 unit assertions** green; `KycLimitGuard` 100%, `KycProvider` ≥90%, mappers/tier 100% | `flutter test` | ☐ |
| 28 | Documentation: dartdoc on `KycTier`, `KycLimitGuard`, `KycProvider` contract, `MockKycProvider` deferred-provider note, `KycProviderRegistry` extensibility note | File inspection | ☐ |

---

> **Approval:** Task EP-02-12 is marked **Completed** only when all 28 conditions in the Final Approval Checklist are verified and signed off by the project lead.