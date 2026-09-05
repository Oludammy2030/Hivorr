# Task Implementation Plan — EP-02-12: KYC Integration Framework & Verification Level Management

**Task ID:** EP-02-12 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Completed | **Priority:** High | **Dependencies:** EP-02-10, EP-02-03 | **Stage:** 4 — Trust & Verification Systems

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:368-377` | Architecture: `documents/Context/ARCHITECTURE.md:55-60,95-110,131-138`, `documents/Context/AGENT.md:7,15,16` | Dependencies: `EP-02:140` (`EP-02-12 → 10, 03`), `EP-02:483` | Stack: `pubspec.yaml:43-53` (`dio 5.11.0`, `supabase_flutter 2.17.2`, `provider 6.1.5`), `lib/data/providers/verification_provider.dart:42`, `supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-112,687-796`, `lib/data/entities/kyc_level.dart:1`, `lib/data/models/kyc_level_dto.dart:1`

---

## 1. Task Objective

Build the client-side **KYC Integration Framework & Verification Level Management** in `lib/systems/verification/` plus its unified Data Layer in `lib/data/` — KYC level definitions (tier 0–3 with increasing verification depth per `supabase/migrations/20260829090003_verification_admin_review_schema.sql:228-234`), server-enforced limit retrieval (`daily/weekly/monthly/cashout` via `verification_kyc_level_get` / `verification_limits_get` / `verification_status_get` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:592-796`), KYC status tracking, limit visibility, upgrade flow, and the abstract `KycProvider` integration seam for future identity verification providers (SmileID, Dojah, NIBSS BVN). Connect the `EP-02-03` server-authoritative KYC schema to the `EP-02-10` identity-verification lifecycle. Zero `public.*` DDL — all KYC tables/RPCs from `EP-02-03` are frozen and reused. Zero financial math. Zero hardcoded `Colors.*`/hex.

Deliverables:
- Data layer: `KycTier`/`KycLevel`/`KycLimits`/`VerificationLimits` entities + DTOs + mapper extensions, `KycRemoteDataSource` (RPC-only wrapper over existing verification RPCs), `KycRepository`, `KycProvider` in `lib/data/`
- Orchestration: `KycService` + `KycProvider` abstract seam (`lib/systems/verification/` and `lib/integrations/kyc/`) with `MockKycProvider` adapter
- Gate logic: `KycLimitGuard` pure-function helpers (`canTransact(amount, tier)`, `remainingLimit(tier, spent)`, `isUpgradeRequired(requestedAmount, currentLimits)`)
- UI: `KycStatusScreen`, `KycLevelCard`/`KycLimitsCard`, `KycUpgradeFlow` (`lib/systems/verification/widgets/` + `screens/`)
- Routes: `/verification/kyc` + `/verification/kyc/upgrade` (`lib/app/router/app_router.dart:17`)
- Notification hook: KYC level upgrade → `HivorrNotification` (`lib/core/notifications/`)
- Unit + widget + integration test suite (mocked `SupabaseClient`, fake `KycProvider`)

## 2. Business Problem Being Solved

`EP-02:27,373` mandates KYC levels as the **proportional risk containment** mechanism — higher verification depth unlocks higher transaction/cashout limits. Server infrastructure exists:

- `supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-72` (`kyc_tiers` — `tier_0 Unverified 0/0/0/0`, `tier_1 Identity Verified 50k/200k/800k/100k`, `tier_2 Trade Verified 200k/800k/3M/500k`, `tier_3 Fully Verified 1M/4M/15M/2M` `228-234`) and `86-112` (`entity_kyc_levels` — `unique(entity_id)`, one row per entity, mutated only by service-role `verification_review_approve` `491-515` never downgrading) — fully RLS default-deny, `SECURITY INVOKER`.
- RPCs: `verification_kyc_level_get()` `687-735`, `verification_limits_get()` `740-782`, `verification_status_get(p_entity_id?)` `592-681` — granted `authenticated, service_role`, envelope `{success,code,message,data}` code `PLT000`.
- Identity verification (`EP-02-10` `lib/data/providers/verification_provider.dart:42`, `lib/data/entities/kyc_level.dart:1`, `lib/data/models/kyc_level_dto.dart:1`) reads `tier_1` but does not own tier vocabulary, limit display, or upgrade flow.

But no dedicated KYC framework exists. Without EP-02-12:

- Every finance screen (`EP-02-13` multi-currency profile, `EP-02-16` bound payouts `AGENT.md:7` Rule 3) would call `supabase.rpc('verification_limits_get')` inline, duplicate envelope parsing (`lib/data/datasources/remote/verification_envelope_parser.dart:1`), `ApiException` mapping, `KycLimits → KycLevel` transformation (`lib/data/mappers/verification_mapper.dart:45-57`), and `tierCodeCompare('tier_1')` `lib/data/entities/kyc_level.dart:28` — violates `ARCHITECTURE.md:91-94` separation and `AGENT.md:6` server-side enforcement (client must never write `entity_kyc_levels.tier_code`; only `verification_review_approve` service-role may).
- No single source for the 4-tier vocabulary and its limit semantics — future tier addition (`tier_4 Business KYC`) or `EP-02-16` currency-specific override would require screen-by-screen edits, breaking `EP-02:204` domain separation.
- No `KycProvider` abstract seam — future SmileID/Dojah BVN/NIN verification integration would require rewriting `systems/verification/` business code; provider selection is not deferred to an interface.
- No limit-aware guard — withdrawal/payout screens cannot pre-check `amount <= cashoutLimit` or surface `remainingHeadroom` without duplicating `AGENT.md:15` Rule 3 proportional-limit logic per screen; server `PLT006 insufficient funds` would be the first feedback, degrading UX on slow Nigerian networks.
- No KYC status display or upgrade CTA — entities cannot see current tier, applicable limits, or what verification step unlocks the next tier, blocking `EP-02-18` onboarding motivation.

This task is the **Stage 4 KYC seam** that unblocks `EP-02-16` KYC-driven cashout enforcement and completes the trust-gate narrative so `EP-02:32` limit proportionality is both server-enforced and client-visible.

## 3. Scope

| In Scope | Detail |
|---|---|
| `KycRemoteDataSource` abstract + `SupabaseKycRemoteDataSource` | Injects `SupabaseClient`+`Dio`+`ApiExceptionMapper` via `BaseApiService` pattern (`lib/core/api/services/base_api_service.dart:15`). Methods: `getKycLevel()`, `getLimits()`, `getStatus(entityId?)` — all via `supabase.rpc` envelope → `VerificationEnvelopeParser` (`lib/data/datasources/remote/verification_envelope_parser.dart:1`) + `DataExceptionMapper` (`lib/data/datasources/remote/data_exception_mapper.dart`) |
| Domain models | `KycTier` enum/reference (`tier_0..tier_3` + display label + `isVerified` helper), `KycLevel` entity (`tierCode,status,limits` `lib/data/entities/kyc_level.dart:1`), `KycLimits` value object, `VerificationLimits` aggregate — pure Dart, no DTO leakage |
| DTOs + mappers | Reuse `KycLevelDto`/`KycLimitsDto`/`TradeVerificationDto` (`lib/data/models/kyc_level_dto.dart:1`) + extend `VerificationStatusDto` mapping; extend `VerificationMapper` (`lib/data/mappers/verification_mapper.dart:1`) with `kycToEntity`, `limitsToEntity`, `tierFromCode` helpers |
| `KycRepository` | `getKycLevel()`, `getLimits()`, `getStatus()`, `requestLevelUpgrade({required String targetTier})` (seam — validates target > current, delegates to `KycProvider.verify(...)` if configured else surfaces guidance), `getUpgradePath()` (returns `List<KycTier> nextEligible`). Orchestrates `KycRemoteDataSource` + `KycProvider` |
| `KycProvider` abstract seam (`lib/integrations/kyc/` or `lib/systems/verification/providers/`) | `abstract class KycProvider { Future<KycVerificationResult> verify({required String entityId, required KycTier targetTier, Map<String,dynamic>? payload}); String get providerName; }` + `MockKycProvider` (in-memory stub returning `pending → approved` after delay) + `KycProviderRegistry` |
| `KycService` (`lib/systems/verification/`) | Thin orchestration facade over `KycRepository` + `KycProviderRegistry`. Exposes `supportedTiers = KycTier.values` (extensible — adding `tier_4` is enum + `kyc_tiers` seed, no screen edits). Adds `HivorrLogger` redacted log (`entityId: ***last4`, `tierCode`, `limits.*`) via `pii_redactor.dart` — never logs `legal_name`. Wraps `PerformanceTracer` span `kyc.level.get.duration` |
| `KycLimitGuard` | Pure-function limit helpers: `bool canTransact({required KycLimits limits, required num amount})`, `num remainingDaily(KycLimits, spentToday)`, `bool isCashoutAllowed(KycLimits limits, amount)`, `String? upgradeSuggestion(KycLevel current, num requestedAmount)` — unit-testable with no I/O |
| `KycProvider` (`ChangeNotifier`) `lib/data/providers/kyc_provider.dart` | `KycLevel? kycLevel`, `KycLimits? limits`, `VerificationStatus? status`, `AsyncState loadState`, `pollTimer`. Invalidates via `notifyListeners()`; polling 15s only while `kycLevel.status == pending` (mirrors `VerificationProvider` `lib/data/providers/verification_provider.dart:194-223`), `WidgetsBindingObserver` lifecycle, `HivorrNotification` on `tierCode` upgrade |
| UI screens + widgets | `KycStatusScreen` (tier badge, limits grid, verification progress), `KycLevelCard` (already `lib/systems/verification/widgets/kyc_level_card.dart` — extend/reuse), `KycLimitsCard` (daily/weekly/monthly/cashout chips), `KycUpgradeFlow` (eligible next tier + requirements checklist + CTA), `KycTierBadge` — responsive via `shared/layouts/`, tokens via `AppColors`/`AppThemeExtension` (`lib/app/theme/app_colors.dart:16`) |
| Notification integration | On `getStatus()` / `getKycLevel()` transition `tier_0 → tier_1` (or any upward tier change), emit `HivorrNotification{priority:high, channel: system, title, body, actionRoute: '/verification/kyc'}` via `NotificationService` |
| Barrel + DI | `lib/systems/verification/verification.dart:1` + `lib/data/data_layer.dart:1` re-exports; factory `KycProvider.create(supabase: SupabaseClientProvider.client, kycProvider: MockKycProvider())` |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL / RLS / RPC creation, `kyc_tiers` seed change, `supabase/config.toml` edit | `EP-02-03` frozen (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:1-816`); this task is `lib/` only. `git diff --stat supabase/` must be `0` |
| Writing `entity_kyc_levels.tier_code/status` or `kyc_tiers.*` from the client | Server-authoritative only — `verification_review_approve` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:491-515`) assigns `tier_1` (never downgrading); client reads only via `verification_kyc_level_get`/`verification_status_get` |
| Trade verification workflow + `trade_verification_status` propagation (`entity_professions` gate) + `TradeVerificationGate.canBid` | `EP-02-11` — this task **reads** `trade_verifications` display-only via `verification_status_get`, never writes |
| Financial ledger mutations, `financial_*` tables, escrow/payout/deposit creation, balance math | `EP-02-04/13/14/16` — no `financial_*` import; no money movement; limit check is read + guard, not ledger write |
| Live KYC provider SDK integration (SmileID, Dojah, NIP BVN fetch, liveness, document OCR) | `EP-02-12` delivers the **abstract seam + mock**; concrete provider adapter is deferred. NIBSS name enquiry belongs to `EP-02-09`/`EP-02-16` (`lib/integrations/payment_gateways/`) |
| Currency-specific limit overrides per `kyc_tiers` | `EP-02-16` extends per-currency cashout overrides — this task uses base NGN limits `supabase/migrations/20260829090003_verification_admin_review_schema.sql:46-53` |
| Supabase Edge Functions for KYC webhook/callback HMAC | Deferred; KYC callback is server-side webhook, not client |
| Supabase Storage bucket or `lib/integrations/cloud_storage/` adapter | Reuse `SupabaseStorageService` — no storage needed for KYC status (identity docs already in `EP-02-10`) |
| Direct `Paystack`/`Flutterwave`/`NIBSS` calls | `EP-02-09` `lib/integrations/payment_gateways/` |
| Offline Sync action queue (`lib/core/sync/`) for deferred KYC upgrade | Online-only; queuing is `EP-01-12` generic infra |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/verification/` vs `lib/data/` vs `lib/integrations/kyc/`

`ARCHITECTURE.md:56,101-110,131-138` assigns `lib/core/` = platform, `lib/data/` = DTO/entity/repository/provider, `lib/systems/verification/` = trust-gate business system, `lib/integrations/` = external adapters (cf. `lib/integrations/payment_gateways/`). KYC straddles verification and integrations: the **data layer** owns RPC transport + DTOs (reusable across `EP-02-10/11/16/18`), the **systems layer** owns tier vocabulary, limit-guard logic, upgrade flow, and UX orchestration, and the **integrations layer** (new `lib/integrations/kyc/`) owns the `KycProvider` abstract + mock/future adapters. This mirrors `EP-02-09` payment-gateway pattern and `EP-02-10` `IdentityVerificationService` (§5.4) seam.

No new top-level `lib/` directory beyond `lib/integrations/kyc/` (which is within the approved `ARCHITECTURE.md:112-120` integrations surface).

### 5.2 Data Layer Contract

```dart
// lib/data/datasources/remote/kyc_remote_data_source.dart
abstract class KycRemoteDataSource {
  Future<KycLevelDto> getKycLevel();
  Future<KycLevelDto> getLimits(); // same shape as kycLevel but limits-only
  Future<VerificationStatusDto> getStatus({String? entityId});
}

// lib/systems/verification/models/kyc_tier.dart  (or lib/data/entities/kyc_tier.dart)
enum KycTier { tier0, tier1, tier2, tier3 } // maps tier_code 'tier_0'..'tier_3'

// lib/data/entities/kyc_level.dart — REUSE existing KycLevel/KycLimits
// no new entity needed; KycLevel.isVerified uses tierCodeCompare('tier_1') :9-28

// lib/integrations/kyc/kyc_provider.dart
abstract class KycProvider {
  String get providerName;
  Future<KycVerificationResult> verify({
    required String entityId,
    required KycTier targetTier,
    Map<String, dynamic>? payload, // bvn, nin, dob etc. — provider-agnostic bag
  });
}
class KycVerificationResult {
  final String status; // pending|approved|rejected — display only
  final String? providerReference;
}
```

- Implementation `SupabaseKycRemoteDataSource extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`) — constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`. Each method invokes `supabase.rpc<Map<String,dynamic>>('verification_kyc_level_get' | 'verification_limits_get' | 'verification_status_get', ...)`, then `VerificationEnvelopeParser.unwrap` (`lib/data/datasources/remote/verification_envelope_parser.dart:29` — validates `{success:true, code:PLT000, data:{...}}`), same envelope as `SupabaseVerificationRemoteDataSource` (`lib/data/datasources/remote/supabase_verification_remote_data_source.dart:16-90`). `DataExceptionMapper` maps `ApiException(PLT001/003/004/999)` to `DataException`.
- `KycRemoteDataSource` is intentionally thin — it reuses the same RPCs already wrapped by `VerificationRemoteDataSource`. A dedicated datasource avoids `EP-02-10` coupling and allows `KycRepository` to evolve independently (future `kyc_upgrade_request` RPC without touching identity).
- `SupabaseKycRemoteDataSource` reuses `VerificationEnvelopeParser` — no second parser.

### 5.3 Repository — `KycRepository` (the unit-tested business contract)

```dart
abstract class KycRepository {
  Future<KycLevel> getKycLevel();
  Future<KycLimits> getLimits();
  Future<VerificationStatus> getStatus();
  Future<KycLevel> requestUpgrade({required KycTier targetTier, Map<String,dynamic>? payload});
  List<KycTier> eligibleUpgradePath(KycLevel current);
}
```

`KycRepositoryImpl` (`lib/data/repositories/kyc_repository_impl.dart` style):

1. `getKycLevel()` → `remote.getKycLevel()` → `VerificationMapper.kycToEntity` (`lib/data/mappers/verification_mapper.dart:45-49`). Returns `tier_0` all-zero when `entity_kyc_levels` has no row (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:633-637` default) — never throws for unassigned.
2. `getLimits()` → `remote.getLimits()` → `VerificationMapper.limitsToEntity` — same `tier_0` default (`740-782`).
3. `getStatus()` → `remote.getStatus()` → `VerificationMapper.statusToEntity` — full aggregate including `identityVerified = status=='active' && tier_code >= tier_1` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:639` string compare holds for `tier_0..tier_3`).
4. `requestUpgrade({targetTier})` — seam:
   - Validate `targetTier.code > current.tier_code` (string compare); if not greater, throw `DataValidationException(PLT003)` → provider surfaces inline field error, not toast.
   - If `kycProviderRegistry.hasProvider`, delegate `await kycProvider.verify(entityId: status.entityId, targetTier: targetTier, payload: payload)` — mock returns `KycVerificationResult(status: pending)` immediately; future live adapter will return provider reference for server polling.
   - If no live provider, return `KycLevel` unchanged and surface guidance: "Complete identity verification to unlock tier_1" — no network beyond the RPC already fetched. This keeps `EP-02-12` valuable without a live provider.
   - **Never writes** `entity_kyc_levels` — upgrade is server-side via `verification_review_approve`. The repository only initiates the provider check and re-reads `getKycLevel()` after provider signals approval.
5. `eligibleUpgradePath(current)` — pure list: `tier_0 → [tier1,tier2,tier3]`, `tier_1 → [tier2,tier3]`, `tier_2 → [tier3]`, `tier_3 → []`.

Repository never imports `lib/systems/` widgets — unidirectional `data → systems`.

### 5.4 Systems Facade — `KycService` + `KycProvider` Registry (`lib/systems/verification/` + `lib/integrations/kyc/`)

Thin wrapper used by `KycProvider` (ChangeNotifier) and future `EP-02-18` onboarding + `EP-02-16` payout guard:

- Exposes `supportedTiers = KycTier.values` with display labels ("Unverified", "Identity Verified", "Trade Verified", "Fully Verified" `supabase/migrations/20260829090003_verification_admin_review_schema.sql:228-234`) and limit previews (from `VerificationStatus.kycLevel.limits`).
- Delegates to `KycRepository`; adds `HivorrLogger` + `PiiRedactor` redacted log (`entityId: ***last4`, `targetTier`, `providerName`) — never `legal_name`.
- `PerformanceTracer` spans `kyc.level.get.duration`, `kyc.limits.get.duration`, `kyc.upgrade.request.duration` (`lib/core/monitoring/performance_tracer.dart`).
- **`KycLimitGuard`** pure helpers (`lib/systems/verification/gate/kyc_limit_guard.dart`):
  ```dart
  abstract final class KycLimitGuard {
    static bool canTransact({required KycLimits limits, required num amount}) =>
        amount > 0 && amount <= limits.daily;
    static bool isCashoutAllowed({required KycLimits limits, required num amount}) =>
        amount > 0 && amount <= limits.cashout;
    static num remainingFor(String window, KycLimits limits, num spent) =>
        (window == 'daily' ? limits.daily : window == 'weekly' ? limits.weekly : limits.monthly) - spent;
    static KycTier? suggestedUpgrade(KycLevel current, num requestedAmount) {
      if (requestedAmount <= current.limits.cashout) return null;
      return KycTier.values.firstWhere((t) => t.limits.cashout >= requestedAmount);
    }
  }
  ```
  No I/O, no globals — trivially testable. Downstream `EP-02-16` payout screen uses `isCashoutAllowed` before calling `supabase.rpc`.

### 5.5 State — `KycProvider` (`lib/data/providers/`)

```dart
class KycProvider extends ChangeNotifier {
  KycLevel? kycLevel; KycLimits? limits; VerificationStatus? status;
  AsyncState loadState; ApiException? lastError; bool isRefreshing;
  Future<void> load(); // getKycLevel + getLimits + getStatus in parallel
  Future<void> refreshStatus(); // re-read status + kycLevel, maybeNotify
  Future<void> requestUpgrade({required KycTier targetTier, Map<String,dynamic>? payload});
  void startPolling(); void stopPolling(); // Timer.periodic 15s, cancel on dispose/terminal
  KycTier? get nextEligibleTier => eligibleUpgradePath(kycLevel).firstOrNull;
}
```

- Constructor injection `({required KycRepository repo, KycProviderRegistry? kycRegistry, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability (`provider:6.1.5`).
- Mirrors `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42-308`) — 15s polling while `kycLevel.status == pending` (or `verificationStatus.pendingSubmissions > 0`), `NotificationProvider` (`lib/core/notifications/providers/notification_provider.dart`) on tier upgrade, `WidgetsBindingObserver` pause/resume via `pausePolling`/`resumePolling`.
- Notification hook: `maybeNotify` diffs `prev.kycLevel.tierCode` → `next.tierCode`; if upgraded (string compare `>`), `notificationProvider.showLocal(HivorrNotification(title:'Verification upgraded — ${next.tierCode}', body:'Your limits increased to ₦${next.limits.cashout} cashout', priority: high))`.
- No `SupabaseClientProvider` singleton inside provider — repository holds the client.

### 5.6 KYC Provider Seam — `lib/integrations/kyc/`

```dart
// lib/integrations/kyc/kyc_provider.dart — abstract (above)
// lib/integrations/kyc/mock_kyc_provider.dart
class MockKycProvider implements KycProvider {
  @override String get providerName => 'mock';
  @override Future<KycVerificationResult> verify({...}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return const KycVerificationResult(status: 'pending');
  }
}
// lib/integrations/kyc/kyc_provider_registry.dart
class KycProviderRegistry {
  KycProviderRegistry({KycProvider? primary, List<KycProvider> fallbacks = const []});
  KycProvider? resolveForTier(KycTier tier) => primary; // extensible per-tier routing EP-08
}
```

- `MockKycProvider` proves the seam without live NIN/BVN credentials — `EP-02:175` deferred provider selection mitigation. Tests inject a fake that returns `approved` synchronously to assert `refreshStatus()` upgrade path.
- Future `SmileIdKycProvider` / `DojahKycProvider` add `dio.post('https://api.smileidentity.com/v1/id_verification', ...)` behind same interface; adding a provider is a new file + registry entry, zero `systems/` change (Open/Closed for EP-08 per `EP-02:197`).

### 5.7 UI — `lib/systems/verification/screens/` + `widgets/`

- `KycStatusScreen` (`GET /verification/kyc`):
  1. Tier header — `KycTierBadge` (tier label + status chip: `pending` amber `warningContainer`, `active` green `successContainer`, `expired/unassigned` grey `outline` `VISUAL-IDENTITY.md:72-79`). Uses `colorScheme.*`, not `Colors.*`.
  2. Limits grid — `KycLimitsCard` (4 chips: Daily / Weekly / Monthly / Cashout) formatted via `lib/shared/helpers/` number formatter (`₦50,000`), each chip `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` 16dp (`VISUAL-IDENTITY.md:221`).
  3. Progress — `VerificationTimeline` reuse (`lib/systems/verification/widgets/verification_timeline.dart`) showing `Submitted → Pending → In Review → Approved` for the last submission; `IdentityVerifiedBadge` when `identityVerified`.
  4. Upgrade CTA — if `nextEligibleTier != null`, "Unlock higher limits — verify your trade" button navigating to `KycUpgradeFlow`; if `tier_3`, "Fully verified — maximum limits" `HivorrSuccessState`.
- `KycUpgradeFlow` (`GET /verification/kyc/upgrade`):
  - Eligible tiers list (e.g., `tier_1 → tier_2 requires trade proof` `supabase/migrations/20260829090003_verification_admin_review_schema.sql:232`), requirements checklist (identity doc approved, trade proof pending), CTA "Start verification" → existing `IdentityDocumentUploadScreen` / `TradeProofUploadScreen` (`lib/systems/verification/screens/identity_document_upload_screen.dart:1`, `trade_proof_upload_screen.dart:1`).
  - No new file picker — reuses `EP-02-10`/`EP-02-11` upload paths; upgrade is a router, not a duplicate upload.
- `KycTierBadge` / `KycLimitsCard` are pure widgets, testable with `WidgetTester` and `AppTheme` token asserts (`ColorScheme.primary == #0B6E99` `VISUAL-IDENTITY.md:43-49`), never `Color(0xFF0B6E99)` inline — that hex lives only in `AppColors` `lib/app/theme/app_colors.dart:16`.

Responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web pane. Branded primitives (`HivorrEmptyState`, `HivorrLoadingState`, `HivorrErrorState`, `HivorrSuccessState`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

### 5.8 Routing — `lib/app/router/`

Extend `AppRouter.create` (`lib/app/router/app_router.dart:17`) via `RoutePaths.kycStatus = '/verification/kyc'`, `kycUpgrade = '/verification/kyc/upgrade'` and `RouteNames.kycStatus/kycUpgrade`. Guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) — authenticated required; no taxonomy gate (KYC is reachable from profile menu). No SEO public URL (private flow, not portfolio `/p/:slug/:id` `ARCHITECTURE.md:150`).

### 5.9 Config & Logging

- No new `ENV` keys — storage and Supabase config cover it (`lib/config/environments/environment_config.dart:17`). `PaymentGatewayConfig` (`EP-02-09`) not imported.
- Errors via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) — `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `5xx→PLT999 server`. `KycRemoteDataSource` rethrows normalized `ApiException`; provider surfaces `message` without leaking `stack`/`SQL`.
- `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) — log `entityId suffix`, `tierCode`, `providerName`, `limit values`; never `legal_name`, never raw NIN/BVN, never `decisionNotes` beyond preview. `MonitoringService` span `kyc.level.get` sampled.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `KycRemoteDataSource` abstract | `lib/data/datasources/remote/kyc_remote_data_source.dart` | **Create** — §5.2 |
| `SupabaseKycRemoteDataSource` | `lib/data/datasources/remote/supabase_kyc_remote_data_source.dart` | **Create** — `BaseApiService` impl §5.2 |
| `KycTier` enum + helpers | `lib/systems/verification/models/kyc_tier.dart` (or `lib/data/entities/kyc_tier.dart`) | **Create** — tier vocabulary + display labels |
| Entities reuse | `lib/data/entities/kyc_level.dart:1` / `verification_status.dart:1` | **Reuse** — no new entity file; extend if needed |
| DTOs reuse | `lib/data/models/kyc_level_dto.dart:1`, `verification_status_dto.dart:1` | **Reuse** — no new DTO; reuse `KycLevelDto`/`VerificationStatusDto` |
| Mappers | `lib/data/mappers/verification_mapper.dart:1` | **Update** — add `kycTierFromCode`, tier label helpers |
| `KycRepository` abstract + impl | `lib/data/repositories/kyc_repository.dart` + `kyc_repository_impl.dart` | **Create** — §5.3 |
| `KycProvider` (ChangeNotifier) | `lib/data/providers/kyc_provider.dart` | **Create** — §5.5 (mirrors `VerificationProvider` `lib/data/providers/verification_provider.dart:42`) |
| `KycProvider` abstract seam | `lib/integrations/kyc/kyc_provider.dart` | **Create** — §5.6 |
| `MockKycProvider` | `lib/integrations/kyc/mock_kyc_provider.dart` | **Create** — §5.6 |
| `KycProviderRegistry` | `lib/integrations/kyc/kyc_provider_registry.dart` | **Create** — §5.6 |
| `KycService` facade | `lib/systems/verification/services/kyc_service.dart` | **Create** — §5.4 |
| `KycLimitGuard` | `lib/systems/verification/gate/kyc_limit_guard.dart` | **Create** — §5.4 pure logic |
| Screens | `lib/systems/verification/screens/kyc_status_screen.dart`, `kyc_upgrade_flow.dart` (or `screens/kyc/kyc_status_screen.dart`) | **Create** — §5.7 |
| Widgets | `lib/systems/verification/widgets/kyc_level_card.dart` (extend `kyc_level_card.dart`), `kyc_limits_card.dart`, `kyc_tier_badge.dart`, `kyc_upgrade_card.dart` | **Create/Update** |
| Barrel | `lib/systems/verification/verification.dart:1` + `lib/data/data_layer.dart:1` + `lib/integrations/kyc/kyc.dart` | **Update** — re-exports |
| Route extension | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` | **Update** — add 2 routes, guard via `RouteGuard` |
| `VerificationProvider` reuse | `lib/data/providers/verification_provider.dart:42` | **Reuse** — `KycProvider` mirrors its polling/notification pattern |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — verify `git diff --stat supabase/` = 0 |
| No `lib/integrations/payment_gateways/*` | `lib/integrations/payment_gateways/` | **No change** |
| Tests + fakes | `test/unit/data/verification/kyc_*`, `test/widget/systems/verification/kyc_*`, `test/support/fakes/fake_kyc_remote_data_source.dart` | **Create** — §14 |

No new `public.*` tables, no RPCs, no Edge Functions, no storage buckets.

## 7. Data Requirements

### 7.1 KYC Tier Reference (read-only)

Seeded `tier_0..tier_3` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:228-234`):

| tier_code | name | daily | weekly | monthly | cashout |
|---|---|---|---|---|---|
| `tier_0` | Unverified | 0 | 0 | 0 | 0 |
| `tier_1` | Identity Verified | 50000 | 200000 | 800000 | 100000 |
| `tier_2` | Trade Verified | 200000 | 800000 | 3000000 | 500000 |
| `tier_3` | Fully Verified | 1000000 | 4000000 | 15000000 | 2000000 |

`kyc_tiers` `tier_code ~ '^tier_[0-9]+$'` `58`, limits `>=0` `60-62`, `is_active, sort_order` index `70-71`. Client treats tier_code as opaque string + `KycTier.fromCode` + `tierCodeCompare('tier_1')` (`lib/data/entities/kyc_level.dart:28` — lexicographic holds for `tier_0..tier_3` because single digit).

### 7.2 Per-Entity KYC Assignment (read-only)

`entity_kyc_levels` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:87-112`): `unique(entity_id)` `98`, `status in ('pending','active','expired')` `99`, `tier_code FK kyc_tiers`. Exactly one row per entity, mutated only by service-role `verification_review_approve` (`491-508` never downgrading higher tier). Client reads via `verification_kyc_level_get()` → `{tier_code, status, limits:{daily,weekly,monthly,cashout}}` `719-733`, `verification_limits_get()` → `{tier_code,daily,weekly,monthly,cashout}` `770-779`, and `verification_status_get` aggregate → `{kyc:{tier_code,status,limits}, identity_verified, trade_verifications, pending/total}` `659-680`. `tier_0` all-zero defaults when no row (`633-637`, `764-768`).

### 7.3 Upgrade Seam Payload

`KycProvider.verify` input: `entityId` (from `verification_status_get` `659`), `targetTier` (`tier_1..tier_3`), optional `payload: {bvn?, nin?, dob?, documentType?}` — validated per-provider, not persisted by this task. Output `KycVerificationResult{status, providerReference}` — display-only; server re-reads `getKycLevel()` after provider signals `approved` before UI shows new badge (prevents spoofed local state).

### 7.4 Notification Payload (derived, not persisted)

`HivorrNotification{id: entityId.hashCode, title: 'Verification upgraded — tier_1', body: 'Your cashout limit is now ₦100,000', channel: system, priority: high, actionRoute: '/verification/kyc'}` — local notification only; no `supabase_realtime` payload (excluded `supabase/migrations/20260829090003_verification_admin_review_schema.sql:798-815`).

## 8. Database Considerations

- **Zero DDL in this task.** `public.kyc_tiers`, `public.entity_kyc_levels`, `public.verification_submissions`, `public.verification_reviews`, `public.verification_audit_trail` all exist (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-225`). No `ALTER`, `CREATE POLICY`, `GRANT`, index, or trigger added. Full pgTAP `001-017` + EP-02 `018-021` suites must remain green.
- **RLS posture inherited:** RLS enabled on all 5 verification tables (`237-241`) + default-deny `revoke all from anon, authenticated` (`244-246`) + grants: `kyc_tiers: authenticated SELECT` `250`, `entity_kyc_levels: authenticated SELECT` `254`, `service_role SELECT/INSERT/UPDATE/DELETE` `255`. `entity_professions` trade gate flipped only via service-role UPDATE `262` (`EP-02-03:257-262` comment). Authenticated **cannot** write `entity_kyc_levels.tier_code/status/assigned_at` — no update grant (`254` is SELECT only). Client KYC state is **RPC-or-nothing** (`AGENT.md:16` Rule 4 database-first).
- **Execution model respected:** `verification_kyc_level_get/limits_get/status_get` granted to `authenticated, service_role` (`794-796`); `review_approve/reject` granted to `service_role` only (`792-793`) — client cannot invoke admin path (`42501 insufficient privilege`). All RPCs `SECURITY INVOKER`, RLS applies inside function body.
- **Upgrade is server-side only:** `entity_kyc_levels` assignment is `insert ... on conflict entity_id do update where tier_code < excluded.tier_code` (`494-508` — conditional, never downgrading). Client `KycRepository.requestUpgrade` never `UPDATE public.entity_kyc_levels`; it delegates to `KycProvider.verify` and then re-reads `getKycLevel()` after server review approves.
- **No service-role bypass in client.** Adapters never hold `service_role` key; `SupabaseClientProvider.client` (`lib/core/api/supabase/supabase_client_provider.dart:19`) uses `anon`/`authenticated` role with RLS. `grep -r "service_role" lib/systems/verification lib/integrations/kyc lib/data` must be `0`.
- **Currency-specific overrides deferred:** Base NGN limits (`kyc_tiers.daily/weekly/monthly/cashout`) are the source of truth here. `EP-02-16` layers per-currency overrides; no `financial_*` FK in this task.
- **Audit:** `verification_audit_trail` `kyc_level_assigned` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:212`) is written server-side by `verification_review_approve` `510-515`; client never inserts audit rows directly (policy `verification_audit_trail_authenticated_insert` `304-305` is self-scoped but RPC is the path).

## 9. API Requirements

### 9.1 Supabase RPC (via `SupabaseKycRemoteDataSource`)

| Operation | RPC | Params | Auth | Success Envelope | Error → ApiExceptionKind |
|---|---|---|---|---|---|
| Get current tier+limits | `verification_kyc_level_get` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:688`) | — | `authenticated` (`platform_is_authenticated()`) | `200 {success:true, code:PLT000, data:{tier_code,status,limits:{daily,weekly,monthly,cashout}}}` defaults `tier_0` all-zero `712-718` | `401 PLT001 auth` (unauth) |
| Get limits | `verification_limits_get` (`740`) | — | `authenticated` | `200 {success:true, code:PLT000, data:{tier_code,daily,weekly,monthly,cashout}}` defaults `tier_0` `765-768` | `401 PLT001` |
| Get aggregate | `verification_status_get` (`592`) | `p_entity_id uuid?` (null = self) | `authenticated` self-scoped, `service_role` admin | `{kyc:{tier_code,status,limits}, identity_verified, trade_verifications:[{profession_id, trade_verification_status}], pending/total}` `659-680` | `403 PLT004` (cross-entity `p_entity_id ≠ auth.uid()` `622`), `401 PLT001` |
| (not invoked by client) | `verification_review_approve/reject` (`412,530`) | `p_submission_id, p_notes?` | `service_role` only | `PLT000` + `kyc_level_assigned` audit + `tier_code` propagation `491-515` | `42501 → PLT002 forbidden` (client receives `403` if attempted) |

All `supabase.rpc<Map<String,dynamic>>('verification_*', params: {...})` unwrapped via `VerificationEnvelopeParser.unwrap` (`lib/data/datasources/remote/verification_envelope_parser.dart:29` — checks `data['success']==true && data['code']=='PLT000'` else throws `ApiException` with extracted `code/message`).

### 9.2 KYC Provider Seam (future — mock in this task)

| Operation | Interface | Params | Transport | Notes |
|---|---|---|---|---|
| Verify for tier | `KycProvider.verify` (`lib/integrations/kyc/kyc_provider.dart`) | `entityId, targetTier, payload?` | In-memory mock (`Future.delayed 800ms → pending`) | Real adapter (SmileID `POST /v1/id_verification`) deferred; no `supabase.rpc` in this path |

No Supabase REST `POST /rest/v1/entity_kyc_levels` — client never writes `entity_kyc_levels` (grant is SELECT only `254`).

### 9.3 No Storage / No Payment Gateway

No `Supabase Storage` REST (KYC status is RPC, not upload — uploads are `EP-02-10`). No `lib/integrations/payment_gateways/` (`EP-02-09`). No Edge Function (KYC webhook HMAC deferred).

### 9.4 Error Contract

Every public method throws only `ApiException` (`api_exception.dart:6-66` kinds) or `DataException` — never raw `Supabase`/`DioException`. `BaseApiService.invoke` normalizes `DioException` via `ApiExceptionMapper.map`.

## 10. User Interface Requirements

**Widgets introduce UI — `AGENT.md:17` Rule 5 applies (all `AppTheme` tokens `documents/Context/VISUAL-IDENTITY.md:176-190`).** Every widget in this task must:

- Source colors from `Theme.of(context).colorScheme` / `AppThemeExtension` (`lib/app/theme/app_colors.dart:16`, `lib/app/theme/app_theme_extension.dart`) — never `Colors.*` or `Color(0xFF0B6E99)` inline (that hex lives only in `AppColors`).
- Source type via `Theme.of(context).textTheme` — never `TextStyle(fontFamily: 'Inter')` (delegated to `lib/app/theme/app_text_theme.dart`).
- Source spacing/radius/elevation/motion via `AppThemeExtension.spacing`/`radiusSm`/`radiusMd`/`elevation`/`duration` (`VISUAL-IDENTITY.md:219-235`) — 8pt grid, cards 16dp, sheets 24dp top.
- Handle 4 states via branded primitives (`lib/shared/widgets/hivorr_empty_state.dart`, `hivorr_loading_state.dart`, `hivorr_error_state.dart`, `hivorr_success_state.dart`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

| Screen/Widget | Route | Purpose | Key Elements |
|---|---|---|---|
| `KycStatusScreen` | `GET /verification/kyc` | Current tier + limits + progress | `AppBar(title: Text('Verification & limits', style: textTheme.titleLarge))`, `KycTierBadge` (tier label + status chip), `KycLimitsCard` (4 chips: Daily/Weekly/Monthly/Cashout with `₦` formatting), `VerificationTimeline` reuse (`lib/systems/verification/widgets/verification_timeline.dart`), `IdentityVerifiedBadge` when `isVerified` |
| `KycUpgradeFlow` | `GET /verification/kyc/upgrade` | Eligible next tier + requirements | Tier selector (radio or stepper of `tier_1..tier_3`), requirements checklist (identity doc ✓/pending, trade proof ✓/pending), CTA `HivorrButton(variant: primary, isLoading, isExpanded:true)` → existing upload screens |
| `KycLimitsCard` | — | Reusable limits grid | 4 `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` chips, value `textTheme.titleMedium`, label `textTheme.labelSmall` `colorScheme.onSurfaceVariant`, pending limits `outline` tint, approved `successContainer` |
| `KycTierBadge` | — | Reusable tier badge | `Container(decoration: BoxDecoration(color: isVerified ? colorScheme.successContainer : colorScheme.primaryContainer, borderRadius: BorderRadius.circular(ext.radiusSm)))` — soft, not hard shadow (`VISUAL-IDENTITY.md:226`) |
| `KycUpgradeCard` | — | Per-tier upgrade card | `tier_2 Trade Verified — ₦500k cashout` + "Unlocks: higher withdrawal limits" + lock/unlock icon `Icons.verified` tinted `colorScheme.secondary` when achieved |

All screens responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web pane. Empty state: `HivorrEmptyState` with "Verify your identity to unlock higher limits" + branded illustration slot. Error state: `HivorrErrorState` with `decisionNotes` when `status == rejected` + "Resubmit" action.

## 11. User Experience Considerations

- **Progressive disclosure, not overwhelming:** Onboarding calls KYC after identity (`EP-02:144` `EP-02-12 depends on 10`); the status screen shows one tier badge + 4 limit chips + timeline, not a wall of legal text. Upgrade flow shows only the next eligible tier first (`eligibleUpgradePath` first element), with "See all tiers" expansion for `tier_3` preview — matches `EP-02:32` proportional-risk narrative without cognitive load.
- **Fail-fast limit preview:** `KycLimitGuard.isCashoutAllowed(limits, amount)` runs before payout screen calls `supabase.rpc('financial_withdraw')` (`EP-02-16`). Invalid amount (e.g., ₦600k on `tier_1` cashout 100k) produces inline `HelperText` under amount field (`colorScheme.error`) with "Your tier_1 cashout limit is ₦100,000 — verify your trade to unlock ₦500,000" guidance, not a 2s server `PLT006` after submit — critical on Nigerian 3G.
- **Status determinism vs polling optimism:** Because `verification_submissions` has no realtime (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:798-815` excluded), the KYC screen **polls** `verification_status_get` every 15s while `kycLevel.status == pending` (same `Timer.periodic` as `VerificationProvider` `lib/data/providers/verification_provider.dart:227`), with backoff on `timeout/network` (`ApiConfig.maxRetries 3/4, baseRetryDelay 500ms` `lib/core/api/api_config.dart:40-49`). "Verification in progress — we'll notify you" copy sets expectation; pull-to-refresh calls `provider.refreshStatus()` immediately. Notifications are push complement, not source of truth — UI re-fetches `getKycLevel()` before rendering upgraded badge to prevent spoofed local state.
- **Cultural / jurisdiction clarity:** Tier labels include Nigeria-specific hints ("Identity Verified — NIN/Passport approved", "Trade Verified — profession credential approved") with 1-line helper, without embedding KYC-provider-specific logic. Cashout limits shown in NGN (`₦`) with locale-aware grouping.
- **Rejection sensitivity:** `rejected` with `decision_notes` (e.g., "NIN photo blurred — please retake") renders with empathy (`HivorrErrorState` illustration + warm microcopy `VISUAL-IDENTITY.md:241`) and single "Resubmit" CTA that navigates to `IdentityDocumentUploadScreen` / `TradeProofUploadScreen` (new `entity_credentials` resubmission, not overwriting the reviewed row `supabase/migrations/20260821090002_entity_core_tables.sql:167`).
- **Upgrade motivation without shaming:** `tier_0` shows aspirational preview ("Verify identity → unlock ₦100k cashout") with primary CTA, not warning red. `tier_3` shows celebration (`HivorrSuccessState` + "Fully verified — maximum limits").

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Server-authoritative KYC** `AGENT.md:16` Rule 4 | Client never writes `entity_kyc_levels.tier_code/status/assigned_at` or `kyc_tiers.*`. All transitions via `verification_review_approve` service-role (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:491-508` conditional `tier_code < excluded.tier_code`). RLS grant on `entity_kyc_levels` is `authenticated SELECT` only `254`; attempt to `POST {tier_code:'tier_3'}` returns `403 PLT002`. `grep -r "tier_code" lib/systems/verification lib/integrations/kyc lib/data` must be read-only display, never assignment. |
| **No anon access** | All 5 verification tables `revoke all from anon` (`244-246`) + policies `to authenticated` only; `kyc_tiers` `authenticated SELECT` `250` + `kyc_tiers_authenticated_select using (true)` `279-281` but no `anon` grant. App guards with `RouteGuard` redirect to `/login` (`lib/app/router/route_guard.dart:1`). |
| **No `service_role` leak** | No `service_role` import in client data/systems/integrations; `KycProvider.verify` never holds `service_role` key. `grep lib/ "service_role"` = 0. |
| **PII exposure** | Token via `SupabaseClientProvider.currentAccessToken` never logged; `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) masks `entityId` to `***last4`, never logs `bvn`/`nin`/`dob` full or `legal_name`. Mock provider payload redacted in logs. |
| **Limit enforcement is server-side** | `KycLimitGuard` is a client convenience; authoritative enforcement is `verification_limits_get` → `financial_withdraw` (`EP-02-16`) checking `amount <= cashout_limit` server-side. Client guard mismatch does not grant funds — server returns `PLT006`. No `financial_*` client mutation in this task. |
| **Time-of-check / race** | `entity_kyc_levels` `unique(entity_id)` + `verification_review_approve` conditional `tier_code < excluded.tier_code` (`494-508`) prevents two parallel approves racing to downgrade; client `requestUpgrade` duplicate with same `targetTier` surfaces `conflict` dialog via `maybeNotify` idempotence. |
| **Auth state isolation** | `AppEnvironment` `Development→Staging→Production` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); `kyc_tiers` per environment via migration, no cross-env read. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **Polling cost** | `Timer.periodic(15s)` only while `kycLevel.status == pending` or `status.pendingSubmissions > 0` and screen visible (`WidgetsBindingObserver` `didChangeAppLifecycleState` pauses on background, `AppRouter` `didPush`/`didPop` cancels on navigate). 1 RPC/15s ≈ 240 req/hour peak — `verification_kyc_level_get`/`verification_status_get` are `STABLE` (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:598,691,746`) and indexed `kyc_tiers_is_active_sort_idx` `70`, `entity_kyc_levels_entity_id_key` `98`, negligible. Backoff `500ms→8s` on `timeout/network` (`lib/core/api/api_config.dart:45-49`). |
| **Parallel fetch** | `KycProvider.load()` calls `getKycLevel()` + `getLimits()` + `getStatus()` with `Future.wait` — 1 round-trip batch via separate RPCs, not sequential; status already contains `kyc` so `load()` may use `getStatus()` only and derive `kycLevel` locally to save one RPC (decision at implementation time). |
| **Caching** | `KycProvider` memoizes `kycLevel` + `limits` + `status` in memory (no Hive `lib/data/datasources/local/` needed — small aggregate). Invalidate via `refreshStatus()` on resume, submit, or push notification. No disk persistence of `tier_code` beyond aggregate. |
| **Guard evaluation cost** | `KycLimitGuard` pure arithmetic `O(1)` — free to call per keystroke in amount field for live limit preview. |
| **Validation cost** | `KycTier.fromCode` map lookup `O(1)` + `tierCodeCompare` string compare `O(n)` on ≤6-char string — microseconds, avoids wasted RPC on invalid upgrade target. |
| **Tracer overhead** | `PerformanceTracer` span (`lib/core/monitoring/performance_tracer.dart:1`) around `getKycLevel`/`getLimits`/`getStatus` sampled via `MonitoringConfig`, tags `kyc.tier`, `kyc.status`, no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/data/verification/kyc_*` + `test/unit/systems/verification/` + `test/unit/integrations/kyc/`

Pattern mirrors `test/unit/core/api/api_exception_mapper_test.dart` + `test/support/fakes/fake_storage.dart:9` (`InMemorySecureStorage`) and `test/support/fakes/fake_supabase.dart` — no live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `kyc_remote_data_source_test.dart` | 12 | Mock `SupabaseClient.rpc` via fake `SupabaseClient` (`fake_supabase.dart`): `verification_kyc_level_get → {success:true, data:{tier_code:tier_0, status:pending, limits:{daily:0...}}}` success; `verification_limits_get → {tier_code:tier_1, daily:50000...}` success; `verification_status_get(p_entity_id≠auth.uid()) → PLT004` → `ApiExceptionKind.notFound`; envelope `success:false → PLT003` → `validation`; `401→PLT001 auth`, `500→PLT999` via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:18`) |
| `kyc_repository_test.dart` | 16 | Fake `SupabaseKycRemoteDataSource` + fake `KycProvider`. Validates `getKycLevel` maps `tier_0` all-zero defaults; `getLimits` `tier_1 50k/200k/800k/100k`; `getStatus` maps `trade_verifications` empty for KYC-only; `requestUpgrade` with `targetTier <= current` throws `validation` before provider spy not called; `eligibleUpgradePath(tier_1) == [tier2,tier3]`; cross-entity `getStatus(entityId)` rejected |
| `kyc_provider_test.dart` | 14 | `ChangeNotifier` with mocked repository: `load()` sets `loadState=loading` then `success`, calls `getKycLevel` + `getStatus`; polling `Timer` mocked via `fakeAsync` — 15s ticks until `tier_1 active`, cancels on dispose; `maybeNotify` emits `HivorrNotification` only on tier upgrade (`tier_0→tier_1` once); `requestUpgrade` delegates to `kycProviderRegistry.resolveForTier`; `pausePolling`/`resumePolling` via `WidgetsBindingObserver` |
| `kyc_limit_guard_test.dart` | 10 | Pure logic: `isCashoutAllowed` returns `true` iff `amount <= cashout`; `remainingFor` computes `limit - spent`; `suggestedUpgrade` returns `null` when `amount <= current.cashout`, else next tier covering `amount`; `canTransact` respects `daily` |
| `kyc_provider_seam_test.dart` | 10 | `MockKycProvider.verify` returns `pending` after 800ms; `KycProviderRegistry.resolveForTier(tier2) == mock`; invalid `payload` (empty) before network → `validation`; `verify` with `targetTier==tier0` throws before `dio` spy not called |
| `kyc_mapper_test.dart` | 8 | `KycLevelDto.fromJson → KycLevel` enum mapping `tier_0..tier_3`, limits `daily/weekly/monthly/cashout`, `status` `pending|active|expired`, null handling → `tier_0` defaults; `KycTier.fromCode('tier_2') == tier2`; `tierCodeCompare` lexicographic holds |
| `kyc_tier_test.dart` | 6 | Enum labels ("Identity Verified", "Trade Verified"), `isVerified` (`tier_0 false`, `tier_1 true`), `values.length==4`, extensibility |

Target **≥76 unit assertions**; repository/provider ≥90%, mappers/tier 100%, guard 100%.

### 14.2 Widget Suite — `test/widget/systems/verification/kyc_*`

| File | Cases (min) | Method |
|---|---|---|
| `kyc_status_screen_test.dart` | 12 | Pump with `Provider<KycProvider>` fake + `MaterialApp` `AppTheme.light` (`lib/app/theme/app_theme.dart:1`): tier badge renders `tier_1` with `successContainer` when active, `warningContainer` when pending; limits grid shows `₦50,000` daily; `VerificationTimeline` visible; upgrade CTA visible when `nextEligibleTier != null`, hidden when `tier_3`; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily` literal), spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:220`); `grep Colors.` assert `0` |
| `kyc_upgrade_flow_test.dart` | 10 | Pump with `KycProvider` mock `tier_1`: firsteligible `tier_2` selected, requirements checklist shows identity ✓, trade proof pending; `HivorrButton.isLoading` shows `HivorrLoader` (`lib/app/widgets/hivorr_loader.dart:1`), tap navigates to `TradeProofUploadScreen`; `tier_0` shows identity CTA; `tier_3` shows `HivorrSuccessState` |
| `kyc_limits_card_test.dart` | 8 | Chips colors `primaryContainer` selected tier vs `outline` unachieved, no hardcoded hex, semantics `Semantics(label:'Daily limit ₦50,000')` |
| `kyc_tier_badge_test.dart` | 8 | Badge colors `successContainer`/`primaryContainer`/`outline` per status, no `Color(0xFF...)` |

Widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)`.

### 14.3 Integration (Fake-E2E) — `test/integration/verification/kyc_flow_test.dart`

Single integration-compose test without live Supabase: fake `SupabaseClient.rpc` map + real `KycRepositoryImpl` + `MockKycProvider`. Flow: `getStatus() → tier_0` → `repo.requestUpgrade(targetTier: KycTier.tier1)` → `mock.verify → pending` → mock `verification_review_approve` side-effect (inject `KycLevelDto{tier_code:tier_1, status:active}`) → `provider.refreshStatus()` → `kycLevel.tierCode == tier_1` + `limits.cashout == 100000` + `KycLimitGuard.isCashoutAllowed(amount: 50000) == true`, `600000 == false`. No `supabase start` container needed; live `supabase db test` is the source-of-truth for RLS.

### 14.4 Regression Guard

`flutter analyze` + `flutter test --coverage` (domain ≥80%) + `supabase db test` full suite `001..017` + verification `021_*` green. Lens `grep -r "Colors\.\|Color(0x" lib/systems/verification lib/integrations/kyc lib/data` = 0 (private KYC seam) except `lib/app/theme/app_colors.dart:16`, `grep -r "fontFamily" lib/systems/verification lib/integrations/kyc` = 0, `grep -r "service_role" lib/` = 0, `git diff --stat supabase/` = 0.

### 14.5 Lens Summary

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` RLS/posture. Add `test/support/fakes/fake_kyc_remote_data_source.dart` export.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-112,687-796`, `lib/data/entities/kyc_level.dart:1`, `lib/data/models/kyc_level_dto.dart:1`, `lib/data/mappers/verification_mapper.dart:1`, `lib/data/providers/verification_provider.dart:42`, `lib/data/datasources/remote/supabase_verification_remote_data_source.dart:16`, `lib/systems/verification/verification.dart:1`, `supabase/tests/database/021_*` posture | Baseline |
| 2 | Create `lib/systems/verification/models/kyc_tier.dart` — enum `KycTier{tier0,tier1,tier2,tier3}` with `code` getter (`'tier_0'`..), `displayLabel`, `isVerified`, `fromCode(String)`, `cashoutLimit` preview | Tier vocabulary |
| 3 | Create `lib/data/datasources/remote/kyc_remote_data_source.dart` — abstract `KycRemoteDataSource` §5.2 | Contract |
| 4 | Create `lib/data/datasources/remote/supabase_kyc_remote_data_source.dart` — `BaseApiService` impl: `verification_kyc_level_get`, `verification_limits_get`, `verification_status_get` via `VerificationEnvelopeParser.unwrap` | Remote |
| 5 | Create `lib/integrations/kyc/kyc_provider.dart` — abstract `KycProvider` + `KycVerificationResult` §5.6 | Seam contract |
| 6 | Create `lib/integrations/kyc/mock_kyc_provider.dart` — `MockKycProvider` §5.6 + `lib/integrations/kyc/kyc_provider_registry.dart` — `KycProviderRegistry` | Seam impl |
| 7 | Create `lib/data/repositories/kyc_repository.dart` abstract + `lib/data/repositories/kyc_repository_impl.dart` — §5.3 `getKycLevel/getLimits/getStatus/requestUpgrade/eligibleUpgradePath`, never writes `entity_kyc_levels` | Repository |
| 8 | Create `lib/systems/verification/services/kyc_service.dart` — facade §5.4 + `lib/systems/verification/gate/kyc_limit_guard.dart` — pure limit guard | Service + guard |
| 9 | Create `lib/data/providers/kyc_provider.dart` — `ChangeNotifier` §5.5 (mirrors `VerificationProvider` `lib/data/providers/verification_provider.dart:42` 15s polling, `HivorrNotification` on tier upgrade, lifecycle pause/resume) | Provider |
| 10 | Update `lib/data/mappers/verification_mapper.dart:1` — add `kycTierFromCode`, tier label helpers | Mappers |
| 11 | Create widgets `lib/systems/verification/widgets/kyc_tier_badge.dart`, `kyc_limits_card.dart` (or extend `kyc_level_card.dart:1`), `kyc_upgrade_card.dart` — `AppTheme` tokens only | Widgets |
| 12 | Create screens `lib/systems/verification/screens/kyc_status_screen.dart`, `kyc_upgrade_flow.dart` — §5.7 responsive, branded states | Screens |
| 13 | Update barrels `lib/systems/verification/verification.dart:1`, `lib/data/data_layer.dart:1`, create `lib/integrations/kyc/kyc.dart` | Barrels |
| 14 | Update `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` — add `kycStatus/kycUpgrade` routes guarded by `RouteGuard` | Routes |
| 15 | Create `test/support/fakes/fake_kyc_remote_data_source.dart` + `test/support/fakes/fake_kyc_provider.dart` | Test infra |
| 16 | Create `test/unit/data/verification/kyc_remote_data_source_test.dart` (12) + `kyc_repository_test.dart` (16) + `kyc_mapper_test.dart` (8) + `kyc_tier_test.dart` (6) | Tests 1 |
| 17 | Create `test/unit/systems/verification/kyc_limit_guard_test.dart` (10) + `test/unit/integrations/kyc/kyc_provider_seam_test.dart` (10) | Tests 2 |
| 18 | Create `test/unit/data/providers/kyc_provider_test.dart` (14 via `fakeAsync` 15s ticks, `maybeNotify` tier upgrade) | Tests 3 |
| 19 | Create `test/widget/systems/verification/kyc_status_screen_test.dart` (12) + `kyc_upgrade_flow_test.dart` (10) + `kyc_limits_card_test.dart` (8) + `kyc_tier_badge_test.dart` (8) | Tests 4 |
| 20 | Create `test/integration/verification/kyc_flow_test.dart` — fake-E2E tier0→upgrade→verify→tier1→limit guard | Integration |
| 21 | `flutter analyze` + `flutter test --coverage` (≥76 assertions green, guard 100%, provider ≥90%) | Verify |
| 22 | `supabase db test` full suite `001..017` + `021_*` green + `grep -r "Colors\.\|Color(0x" lib/systems/verification lib/integrations/kyc` = 0 + `grep -r "service_role" lib/` = 0 + `git diff --stat supabase/` = 0 | Regression |
| 23 | Doc pass: dartdoc on `KycTier`, `KycLimitGuard`, `KycProvider` contract, `MockKycProvider` deferred-provider note, `VerificationEnvelopeParser` reuse | Docs |
| 24 | Tag `EP-02-16` unblocked; phase plan `EP-02-12` → `Completed` candidate pending review | Handoff |

## 16. Expected Outcome

- `lib/data/` exposes a single seam for KYC state: `KycRepository` reads `tier_0..tier_3` and `daily/weekly/monthly/cashout` via the frozen `verification_kyc_level_get`/`verification_limits_get`/`verification_status_get` RPCs, maps via `VerificationMapper` to pure `KycLevel`/`KycLimits`/`VerificationStatus`, and surfaces `eligibleUpgradePath` + `requestUpgrade` through the abstract `KycProvider` without writing `entity_kyc_levels`.
- `lib/integrations/kyc/` provides a **provider-agnostic, interface-first** KYC integration seam — `systems/verification/` imports only `KycProvider`/`KycProviderRegistry`, never `SmileIdKycProvider`/`DojahKycProvider` directly (`ARCHITECTURE.md:112-114` analogue). `MockKycProvider` proves the seam without live credentials (`EP-02:175` risk mitigated).
- `KycLimitGuard` pure functions enable `EP-02-16` payout screens to gate `createTransfer`/`financial_withdraw` before network, with `isCashoutAllowed`/`suggestedUpgrade` displayed inline, reducing `PLT006` server rejections and user friction on slow networks.
- `KycProvider` (`ChangeNotifier`) owns 15s polling while `pending`, `WidgetsBindingObserver` lifecycle, and a single terminal `HivorrNotification` on tier upgrade — mirroring the proven `VerificationProvider` (`lib/data/providers/verification_provider.dart:42`) pattern with no `supabase_realtime` (queue excluded `supabase/migrations/20260829090003_verification_admin_review_schema.sql:798-815`).
- `KycStatusScreen` + `KycUpgradeFlow` render tier badge, limits grid, timeline, and requirements checklist with **zero hardcoded `Colors.*`/hex/`fontFamily`** — all `Theme.of(context).colorScheme.*`/`textTheme.*`/`AppThemeExtension` tokens (`VISUAL-IDENTITY.md:176-190,219-235`), responsive via `shared/layouts/` (16dp mobile / 24dp web), branded states via `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`/`HivorrLoader`.
- Unit suite ≥76 assertions green with mocked `SupabaseClient`/`Dio`; `flutter analyze` clean; full pgTAP `001-017` + verification `021_*` green; `grep` proves no `service_role` or hardcoded color/font leakage; `git diff --stat supabase/` = 0.
- `EP-02-16` (Bound Payout Accounts & Deposit Name Verification) unblocked — KYC-driven cashout limits enforceable with a real, tested seam.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/data/datasources/remote/kyc_remote_data_source.dart` exists — abstract `KycRemoteDataSource` with `getKycLevel`, `getLimits`, `getStatus({entityId})` | File inspection |
| 2 | `lib/data/datasources/remote/supabase_kyc_remote_data_source.dart` implements `KycRemoteDataSource` — `extends BaseApiService`, `supabase.rpc('verification_kyc_level_get'/'verification_limits_get'/'verification_status_get')`, `VerificationEnvelopeParser.unwrap`, `DataExceptionMapper` | File + unit test |
| 3 | `lib/systems/verification/models/kyc_tier.dart` (or `lib/data/entities/kyc_tier.dart`) defines `KycTier` enum (`tier0..tier3` ↔ `'tier_0'..'tier_3'`), `displayLabel`, `isVerified`, `KycTier.fromCode` | File + unit test |
| 4 | `lib/integrations/kyc/kyc_provider.dart` exists — abstract `KycProvider{providerName, verify({entityId,targetTier,payload})→KycVerificationResult}` | File inspection |
| 5 | `lib/integrations/kyc/mock_kyc_provider.dart` implements `KycProvider` — `MockKycProvider` returns `pending` after delay, no `SupabaseClient`/`service_role` | File + unit test |
| 6 | `lib/integrations/kyc/kyc_provider_registry.dart` defines `KycProviderRegistry.resolveForTier` — per-tier routing seam, mock primary by default | Unit test |
| 7 | `lib/data/repositories/kyc_repository.dart` + `kyc_repository_impl.dart` define `KycRepository{getKycLevel,getLimits,getStatus,requestUpgrade,eligibleUpgradePath}` — validates `targetTier > current` before provider, never writes `entity_kyc_levels` | Unit test |
| 8 | `lib/systems/verification/services/kyc_service.dart` facade + `lib/systems/verification/gate/kyc_limit_guard.dart` pure `KycLimitGuard.canTransact/isCashoutAllowed/remainingFor/suggestedUpgrade` | File + unit test (guard 100%) |
| 9 | `lib/data/providers/kyc_provider.dart` exists — `ChangeNotifier` with `kycLevel/limits/status/loadState`, `load()`/`refreshStatus()`/`requestUpgrade()`, `Timer.periodic(15s)` polling while `pending`, `pausePolling`/`resumePolling`, `maybeNotify` tier-upgrade `HivorrNotification`, `dispose` cancels timer — mirrors `lib/data/providers/verification_provider.dart:42` | Unit test via `fakeAsync` |
| 10 | `lib/systems/verification/screens/kyc_status_screen.dart` exists — `GET /verification/kyc`, tier badge + limits grid + timeline + upgrade CTA, `AppTheme` tokens only, responsive | Widget test |
| 11 | `lib/systems/verification/screens/kyc_upgrade_flow.dart` (or `screens/kyc/kyc_upgrade_flow.dart`) exists — `GET /verification/kyc/upgrade`, eligible tiers + requirements checklist + CTA to existing upload screens | Widget test |
| 12 | `lib/systems/verification/widgets/kyc_limits_card.dart` / `kyc_tier_badge.dart` / `kyc_upgrade_card.dart` exist (or `kyc_level_card.dart` extended) — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp (`VISUAL-IDENTITY.md:221`) | Widget test |
| 13 | `lib/systems/verification/verification.dart:1` + `lib/data/data_layer.dart:1` + `lib/integrations/kyc/kyc.dart` barrels re-export new symbols (no stale `.gitkeep` only) | File inspection |
| 14 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `kycStatus='/verification/kyc'` + `kycUpgrade='/verification/kyc/upgrade'` guarded by `RouteGuard` | File + `go_router` smoke |
| 15 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` |
| 16 | No `lib/systems/finance/*` or `financial_*` changes — `git diff --stat lib/systems/finance` = 0 | `git diff --stat` |
| 17 | No `service_role` or secret leakage — `grep -r "service_role" lib/` = 0, `grep -r "tier_code.*=" lib/systems/verification lib/integrations/kyc lib/data` assignment = 0 (read-only) | `grep` + code review |
| 18 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/verification lib/integrations/kyc lib/data` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/verification lib/integrations/kyc` = 0 | `grep` |
| 19 | `test/unit/data/verification/kyc_remote_data_source_test.dart` ≥12 cases green (RPC envelope, `PLT001/003/004/999`) | `flutter test` |
| 20 | `test/unit/data/verification/kyc_repository_test.dart` ≥16 + `kyc_mapper_test.dart` ≥8 + `kyc_tier_test.dart` ≥6 green | `flutter test` |
| 21 | `test/unit/systems/verification/kyc_limit_guard_test.dart` ≥10 (100%) + `test/unit/integrations/kyc/kyc_provider_seam_test.dart` ≥10 green | `flutter test` |
| 22 | `test/unit/data/providers/kyc_provider_test.dart` ≥14 cases green (`fakeAsync` 15s ticks until active, `maybeNotify` once per upgrade, lifecycle pause/resume) | `flutter test` |
| 23 | `test/widget/systems/verification/kyc_status_screen_test.dart` ≥12 + `kyc_upgrade_flow_test.dart` ≥10 + `kyc_limits_card_test.dart` ≥8 + `kyc_tier_badge_test.dart` ≥8 green, token + layout asserts | `flutter test` |
| 24 | `test/integration/verification/kyc_flow_test.dart` fake-E2E green: tier0 → upgrade → verify → tier1 → guard allows/denies cashout | `flutter test` |
| 25 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI |
| 26 | `supabase db test` full suite `001-017` + verification `021_*` green — no RLS/role regression | `supabase db test` |
| 27 | `flutter test` total ≥76 unit assertions green; `KycLimitGuard` 100%, `KycProvider` ≥90%, mappers/tier 100% | `flutter test` |
| 28 | Documentation: dartdoc on `KycTier`, `KycLimitGuard`, `KycProvider` contract, `MockKycProvider` deferred-provider note, `KycProviderRegistry` extensibility note | File inspection |

---

## Recommended Implementation AI Execution Profile

**Recommended Coding Reasoning Level:** **Very High**

**Reasoning Level Justification:**

| Dimension | Assessment | Rationale |
|---|---|---|
| Technical complexity | High | Thin RPC wrapper + tier vocabulary + abstract provider seam + polling `ChangeNotifier` + limit-guard pure logic — non-trivial but follows proven `EP-02-10` `VerificationProvider` + `EP-02-09` integration-seam patterns; no new SQL, no branch-heavy provider parsing. Below `EP-02-03/04` schema work but above CRUD. |
| Business impact | High | Tier-proportional limits are the financial risk containment for `EP-02-16` payouts — misrendered `cashout` or broken upgrade CTA directly blocks withdrawal UX and trust narrative, though no money moves in this task. |
| Security risk | High | Default-deny RLS + `entity_kyc_levels` write ban must not be violated — client must never assign `tier_code`. Guard is convenience; authoritative enforcement is server-side, but a client bypass bug (writing `tier_3`) would be a `403` caught in tests, not silent fraud. |
| Performance sensitivity | Medium | 15s polling + `Future.wait` parallel fetch + `O(1)` guard — trivial cost, but lifecycle pause/resume and backoff on Nigerian 3G must be correct to avoid 240 req/hr waste. |
| Data complexity | Medium | 4-tier vocabulary + `KycLevel` aggregate + `trade_verifications` display-only slice — reuse of `KycLevelDto`/`VerificationStatusDto` keeps mapping narrow; no ledger double-entry. |
| Integration complexity | Very High | Drives provider-agnostic KYC extensibility for EP-08 (SmileID/Dojah future), mirrors `EP-02-09` payment-gateway ISP with fallback registry, and is consumed by `EP-02-16` + `EP-02-18` — interface-first validation with two read paths (RPC + mock) to prove Open/Closed. |

Overall the task blends the financial-limit trust gate (`AGENT.md:15` Rule 2 proportionality) with a future-facing external-provider abstraction that must not couple `systems/` to a concrete vendor — **Very High** reasoning ensures the seam is genuinely extensible (mock proves abstraction), polling/notification idempotence is correct, and zero client-side KYC writes are rigorously enforced via tests and `grep` lenses.