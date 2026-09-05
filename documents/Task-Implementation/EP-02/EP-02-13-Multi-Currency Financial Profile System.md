# Task Implementation Plan — EP-02-13: Multi-Currency Financial Profile System

**Task ID:** EP-02-13 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Completed | **Priority:** Critical | **Dependencies:** EP-02-04, EP-02-09 | **Stage:** 5 — Financial Integrity Systems

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:379-388` | Architecture: `documents/Context/ARCHITECTURE.md:55-60,95-110,131-138`, `documents/Context/AGENT.md:4-8,15-17` | Dependencies: `EP-02:143-145` (`EP-02-13 → 04, 09`), `EP-02:373` | Stack: `pubspec.yaml:43-53` (`dio 5.11.0`, `supabase_flutter 2.17.2`, `provider 6.1.5`), `lib/systems/finance/.gitkeep`, `supabase/migrations/20260829100004_financial_integrity_schema.sql:67-146,635-754,1566-1618`, `lib/integrations/payment_gateways/payment_gateway_factory.dart`, `lib/core/api/services/base_api_service.dart:15`

---

## 1. Task Objective

Build the unified multi-currency financial profile system in `lib/systems/finance/` — financial profile creation, currency-specific receiving account management (request, view, activate), multi-currency balance display (available, held, pending per currency), and financial preferences. Build the complete data layer for financial profiles, currency accounts, and balances.

Deliverables:
- Data layer: `FinancialProfile`, `CurrencyAccount`, `Balance` entities + DTOs + mapper extensions, `FinancialRemoteDataSource` (RPC-only wrapper over existing financial RPCs), `FinancialRepository`, `FinancialProvider` in `lib/data/`
- Orchestration: `FinancialService` facade in `lib/systems/finance/`
- UI: `FinancialProfileScreen`, `CurrencyAccountsList`, `BalanceDisplayPerCurrency`, `FinancialPreferencesScreen` (`lib/systems/finance/widgets/` + `screens/`)
- Routes: `/finance` + `/finance/accounts` (`lib/app/router/app_router.dart:17`)
- Barrel + DI: `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` re-exports
- Unit + widget + integration test suite (mocked `SupabaseClient`, fake `FinancialRepository`)

## 2. Business Problem Being Solved

`EP-02:373,44-87` mandates a **unified multi-currency financial profile** as the core business capability — each entity has one financial profile holding multiple currency accounts and balances. This is the foundation that escrow (`EP-02-14`), payouts (`EP-02-16`), conversions (`EP-02-15`), and deposits all operate against. Server infrastructure exists:

- `supabase/migrations/20260829100004_financial_integrity_schema.sql:67-78` (`financial_profiles` — `entity_id uuid unique`, `default_currency char(3)`, `status text`) and `89-115` (`financial_currency_accounts` — `unique(entity_id, currency_code)`, `account_status pending|active|suspended|closed`, `receiving_account_number`, `receiving_bank_name`, `provider_reference`, `activated_at`) — fully RLS default-deny, `SECURITY INVOKER`.
- RPCs: `financial_profile_create()` `635-680` (creates profile + default balance row, `PLT005` if exists), `financial_profile_get()` `683-714` (returns profile + `currency_accounts` array), `financial_balance_get(p_currency_code)` `717-754` (returns `available/held/pending` per currency, defaults zero), `financial_status_get()` `1566-1618` (aggregated: balances + active escrow count + cashout limit).
- `financial_supported_currencies` `37-62` seeds NGN ₦, GHS ₵, USD $, GBP £ — idempotent, `is_active` flag, `decimal_places`.
- `financial_balances` `120-146` — `available_balance`, `held_balance`, `pending_balance`, `total_deposited`, `total_withdrawn` per `(entity_id, currency_code)`, all `>=0`, double-entry enforced server-side.

But no client-side financial profile system exists. Without EP-02-13:

- Every finance screen (`EP-02-14` escrow, `EP-02-15` conversion, `EP-02-16` payouts) would call `supabase.rpc('financial_profile_get')` inline, duplicate envelope parsing, `ApiException` mapping, and `FinancialProfile → Entity` transformation — violates `ARCHITECTURE.md:91-94` separation and `AGENT.md:4-6` Separation of Concerns.
- No single source for the four-currency vocabulary (`NGN`, `GHS`, `USD`, `GBP`) and its display symbols — future currency addition or `EP-02-15` rate display would require screen-by-screen edits, breaking `EP-02:204` domain separation.
- No `FinancialProfile` entity — profile creation (`financial_profile_create`) and retrieval (`financial_profile_get`) have no typed client-side representation; every consumer builds its own ad-hoc map, risking silent schema drift.
- No multi-currency balance display — entities cannot see available/held/pending per currency in a unified view; `EP-02-16` payout screens cannot pre-check `available_balance >= amount` without duplicating balance-fetch logic per screen, degrading UX on slow Nigerian networks.
- No `PaymentGatewayFactory.resolveForCurrency` integration — `EP-02-09` factory exists but is not consumed; profile creation cannot suggest the correct payment provider per currency region.

This task is the **Stage 5 financial-profile seam** that unblocks `EP-02-14` escrow creation, `EP-02-15` currency conversion, and `EP-02-16` bound payouts + deposit verification.

## 3. Scope

| In Scope | Detail |
|---|---|
| `FinancialRemoteDataSource` abstract + `SupabaseFinancialRemoteDataSource` | Injects `SupabaseClient`+`Dio`+`ApiExceptionMapper` via `BaseApiService` pattern (`lib/core/api/services/base_api_service.dart:15`). Methods: `getProfile()`, `getBalance(currencyCode)`, `getStatus()` — all via `supabase.rpc` envelope → `VerificationEnvelopeParser` or financial envelope parser + `DataExceptionMapper` |
| Domain models | `FinancialProfile` entity (`id, entityId, status, defaultCurrency, createdAt`), `CurrencyAccount` entity (`id, financialProfileId, entityId, currencyCode, accountStatus, receivingAccountNumber, receivingBankName, providerReference, activatedAt`), `Balance` entity (`id, financialProfileId, entityId, currencyCode, availableBalance, heldBalance, pendingBalance, totalDeposited, totalWithdrawn, lastTransactionAt`), `FinancialStatus` aggregate (profile + balances array + activeEscrowCount + cashoutLimit) — pure Dart, no DTO leakage |
| DTOs + mappers | `FinancialProfileDto`, `CurrencyAccountDto`, `BalanceDto`, `FinancialStatusDto` — DTO layer in `lib/data/models/`; mapper extensions in `lib/data/mappers/financial_mapper.dart` mapping DTOs → entities |
| `FinancialRepository` | `getProfile()`, `getBalance(currencyCode)`, `getStatus()`, `createProfile({defaultCurrency})`, `requestAccountActivation({currencyCode})` (seam — validates currency supported, delegates to `PaymentGatewayFactory.resolveForCurrency` if configured, else surfaces guidance). Orchestrates `FinancialRemoteDataSource` + `PaymentGatewayFactory` |
| `FinancialService` facade (`lib/systems/finance/`) | Thin wrapper over `FinancialRepository`. Exposes `supportedCurrencies = ['NGN','GHS','USD','GBP']` with display labels ("Nigerian Naira", "Ghanaian Cedi", "US Dollar", "British Pound") and symbols ("₦","₵","$","£") from `financial_supported_currencies`. Adds `HivorrLogger` redacted log (`entityId: ***last4`, `currencyCode`, `balance.*`) via `pii_redactor.dart` — never logs `legal_name`. Wraps `PerformanceTracer` span `finance.profile.get.duration` |
| `FinancialProvider` (`ChangeNotifier`) `lib/data/providers/financial_provider.dart` | `FinancialProfile? profile`, `List<CurrencyAccount> accounts`, `Map<String,Balance> balances`, `AsyncState loadState`, `FinancialStatus? status`. Invalidates via `notifyListeners()`; `load()` fetches profile + status in parallel via `Future.wait`; `refreshStatus()` re-reads `financial_status_get`. Mirrors `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42-308`) with `WidgetsBindingObserver` lifecycle |
| UI screens + widgets | `FinancialProfileScreen` (profile overview + default currency + status chip), `CurrencyAccountsList` (per-currency account cards with activation status), `BalanceDisplayPerCurrency` (available/held/pending chips per currency), `FinancialPreferencesScreen` (default currency selector + profile settings) — responsive via `shared/layouts/`, tokens via `AppColors`/`AppThemeExtension` (`lib/app/theme/app_colors.dart:16`) |
| Barrel + DI | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` re-exports; factory `FinancialProvider.create(supabase: SupabaseClientProvider.client)` |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL / RLS / RPC creation, `financial_supported_currencies` seed change, `supabase/config.toml` edit | `EP-02-04` frozen (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1-1764`); this task is `lib/` only. `git diff --stat supabase/` must be `0` |
| Writing `financial_profiles`, `financial_currency_accounts`, `financial_balances` from the client | Server-authoritative only — `financial_profile_create` (`635-680`) is the only profile creation path; client reads only via `financial_profile_get`/`financial_balance_get`/`financial_status_get` |
| Escrow creation, funding, release, refund workflow | `EP-02-14` — this task **reads** profile/balance display-only, never writes escrow |
| Currency conversion rate fetching, conversion execution | `EP-02-15` — this task displays balances, does not convert |
| Payout account binding, withdrawal, deposit verification, name-matching | `EP-02-16` — this task shows account status, does not bind/withdraw |
| Live payment provider SDK integration (Paystack/Flutterwave account creation) | `EP-02-09` owns the abstraction; `requestAccountActivation` is a seam returning guidance, not a live provider call in this task |
| Currency-specific KYC limit overrides | `EP-02-16` extends per-currency cashout overrides — this task uses `financial_status_get.cashout_limit` read-only |
| Supabase Edge Functions for payment webhooks | Deferred; webhook handling is server-side |
| Direct `Paystack`/`Flutterwave`/`NIBSS` calls | `EP-02-09` `lib/integrations/payment_gateways/` |
| Financial transaction history display | `EP-02-14+` — current task shows balances and profile, not transaction list |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/finance/` vs `lib/data/` vs `lib/integrations/`

`ARCHITECTURE.md:55-60,101-110,131-138` assigns `lib/core/` = platform, `lib/data/` = DTO/entity/repository/provider, `lib/systems/finance/` = financial business system, `lib/integrations/` = external adapters (cf. `lib/integrations/payment_gateways/`). Financial profiles straddle data and systems: the **data layer** owns RPC transport + DTOs (reusable across `EP-02-14/15/16`), the **systems layer** owns currency vocabulary, balance display logic, and UX orchestration. This mirrors `EP-02-09` payment-gateway pattern and `EP-02-12` `KycService` facade.

No new top-level `lib/` directory. `lib/systems/finance/.gitkeep` is replaced by actual module code.

### 5.2 Data Layer Contract

```dart
// lib/data/datasources/remote/financial_remote_data_source.dart
abstract class FinancialRemoteDataSource {
  Future<FinancialProfileDto> getProfile();
  Future<BalanceDto> getBalance(String currencyCode);
  Future<FinancialStatusDto> getStatus();
}

// lib/data/entities/financial_profile.dart
class FinancialProfile {
  final String id;
  final String entityId;
  final String status; // 'active', 'suspended', 'closed'
  final String defaultCurrency; // 'NGN', 'GHS', 'USD', 'GBP'
  final DateTime createdAt;
}

// lib/data/entities/currency_account.dart
class CurrencyAccount {
  final String id;
  final String financialProfileId;
  final String entityId;
  final String currencyCode;
  final String accountStatus; // 'pending', 'active', 'suspended', 'closed'
  final String? receivingAccountNumber;
  final String? receivingBankName;
  final String? providerReference;
  final DateTime? activatedAt;
}

// lib/data/entities/balance.dart
class Balance {
  final String currencyCode;
  final double availableBalance;
  final double heldBalance;
  final double pendingBalance;
  final double totalDeposited;
  final double totalWithdrawn;
  final DateTime? lastTransactionAt;
}

// lib/data/entities/financial_status.dart
class FinancialStatus {
  final String defaultCurrency;
  final String profileStatus;
  final List<Balance> balances;
  final int activeEscrowCount;
  final double cashoutLimit;
}
```

- Implementation `SupabaseFinancialRemoteDataSource extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`) — constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`. Each method invokes `supabase.rpc<Map<String,dynamic>>('financial_profile_get' | 'financial_balance_get' | 'financial_status_get', ...)`, then envelope unwrap (validates `{success:true, code:PLT000, data:{...}}`), same envelope as `SupabaseVerificationRemoteDataSource` (`lib/data/datasources/remote/supabase_verification_remote_data_source.dart:16-90`). `DataExceptionMapper` maps `ApiException(PLT001/003/004/999)` to `DataException`.
- `FinancialRemoteDataSource` is intentionally thin — it reuses the same envelope contract already wrapped by verification RPCs. A dedicated datasource avoids `EP-02-12` coupling and allows `FinancialRepository` to evolve independently (future `financial_profile_update` RPC without touching verification).
- `SupabaseFinancialRemoteDataSource` reuses `VerificationEnvelopeParser` or a parallel financial envelope parser — no third parser needed.

### 5.3 Repository — `FinancialRepository` (the unit-tested business contract)

```dart
abstract class FinancialRepository {
  Future<FinancialProfile?> getProfile();
  Future<Balance?> getBalance(String currencyCode);
  Future<FinancialStatus> getStatus();
  Future<FinancialProfile> createProfile({String defaultCurrency});
  Future<CurrencyAccount> requestAccountActivation({required String currencyCode});
}
```

`FinancialRepositoryImpl` (`lib/data/repositories/financial_repository_impl.dart` style):

1. `getProfile()` → `remote.getProfile()` → `FinancialMapper.profileToEntity`. Returns `null` when `financial_profiles` has no row (entity has no profile yet — `financial_profile_create` has not been called).
2. `getBalance(currencyCode)` → `remote.getBalance(currencyCode)` → `FinancialMapper.balanceToEntity` — returns `Balance` with zero defaults when no row exists (`financial_balance_get` `742-744` returns `null` → `available_balance:0, held_balance:0, pending_balance:0`).
3. `getStatus()` → `remote.getStatus()` → `FinancialMapper.statusToEntity` — full aggregate including balances array, active escrow count, and KYC-derived cashout limit.
4. `createProfile({defaultCurrency})` — validates `defaultCurrency` is in supported set `['NGN','GHS','USD','GBP']` (from `financial_supported_currencies`); delegates to `supabase.rpc('financial_profile_create', params: {p_default_currency: defaultCurrency})` via envelope; re-reads `getProfile()` to confirm creation. If profile already exists (`PLT005 conflict`), returns existing profile with guidance.
5. `requestAccountActivation({currencyCode})` — seam:
   - Validates `currencyCode` is in supported set.
   - If `PaymentGatewayFactory.resolveForCurrency(currencyCode)` is available, delegates to the resolved gateway for account creation guidance.
   - If no live provider, returns `CurrencyAccount` status `pending` with guidance: "Connect your NGN bank account via Paystack to activate receiving."
   - **Never writes** `financial_currency_accounts` directly — activation is server-side via `financial_payout_account_bind` (`EP-02-16`). The repository only surfaces the account status and provider hint.

Repository never imports `lib/systems/` widgets — unidirectional `data → systems`.

### 5.4 Systems Facade — `FinancialService` (`lib/systems/finance/`)

Thin wrapper used by `FinancialProvider` (ChangeNotifier) and future `EP-02-14/15/16` consumers:

- Exposes `supportedCurrencies` with display metadata:
  ```dart
  const supportedCurrencies = [
    SupportedCurrency(code: 'NGN', name: 'Nigerian Naira', symbol: '₦', decimalPlaces: 2),
    SupportedCurrency(code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵', decimalPlaces: 2),
    SupportedCurrency(code: 'USD', name: 'US Dollar', symbol: '$', decimalPlaces: 2),
    SupportedCurrency(code: 'GBP', name: 'British Pound', symbol: '£', decimalPlaces: 2),
  ];
  ```
  Data-driven from `financial_supported_currencies` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:37-62`), not hardcoded per-screen.
- Delegates to `FinancialRepository`; adds `HivorrLogger` + `PiiRedactor` redacted log (`entityId: ***last4`, `currencyCode`, `balance.available`) — never `legal_name`.
- `PerformanceTracer` spans `finance.profile.get.duration`, `finance.balance.get.duration`, `finance.status.get.duration` (`lib/core/monitoring/performance_tracer.dart`).
- `BalanceFormatter` pure helper: `String formatBalance(double amount, String currencyCode)` → `₦50,000.00`, `₵1,200.00`, `$100.00`, `£75.50` — locale-aware via `intl` (`lib/shared/helpers/`).

### 5.5 State — `FinancialProvider` (`lib/data/providers/`)

```dart
class FinancialProvider extends ChangeNotifier {
  FinancialProfile? profile;
  List<CurrencyAccount> accounts;
  Map<String, Balance> balances;
  FinancialStatus? status;
  AsyncState loadState;
  ApiException? lastError;
  bool isRefreshing;

  Future<void> load(); // getProfile + getStatus in parallel
  Future<void> refreshStatus(); // re-read status + balances, maybeNotify
  Future<void> createProfile({String defaultCurrency = 'NGN'});
  void pausePolling();
  void resumePolling();
}
```

- Constructor injection `({required FinancialRepository repo, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability (`provider:6.1.5`).
- Mirrors `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42-308`) — `WidgetsBindingObserver` lifecycle, `NotificationProvider` (`lib/core/notifications/providers/notification_provider.dart`) on profile creation success, `pausePolling`/`resumePolling` via `didChangeAppLifecycleState`.
- `load()` calls `getProfile()` + `getStatus()` with `Future.wait` — 1 round-trip batch, not sequential; status already contains balances so `load()` may use `getStatus()` only and derive profile locally to save one RPC (decision at implementation time).
- No `SupabaseClientProvider` singleton inside provider — repository holds the client.

### 5.6 UI — `lib/systems/finance/screens/` + `widgets/`

- `FinancialProfileScreen` (`GET /finance`):
  1. Profile header — `FinancialProfileCard` showing `defaultCurrency` symbol + profile status chip (`active` green `successContainer`, `suspended` amber `warningContainer`, `closed` grey `outline` `VISUAL-IDENTITY.md:72-79`). Uses `colorScheme.*`, not `Colors.*`.
  2. Balance overview — `BalanceOverviewCard` (per-currency balance chips: available in `successContainer`, held in `primaryContainer`, pending in `warningContainer`) formatted via `BalanceFormatter`, each chip `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` 16dp (`VISUAL-IDENTITY.md:221`).
  3. Accounts list — `CurrencyAccountsList` showing each `CurrencyAccount` with status badge and bank name when activated.
  4. Create profile CTA — if `profile == null`, "Set up your financial profile" primary button navigating to profile creation flow; if `profile != null`, "Manage" secondary action.
- `FinancialProfileCreationFlow` (`GET /finance/create`):
  - Default currency selector (radio group of `supportedCurrencies` with symbols), "Create Profile" CTA `HivorrButton(variant: primary, isLoading, isExpanded:true)` → `financial_profile_create` via provider.
  - No new file picker — reuses `EP-02-09`/`EP-02-16` upload/binding paths; profile creation is a simple form, not a duplicate upload.
- `BalanceOverviewCard` / `CurrencyAccountCard` are pure widgets, testable with `WidgetTester` and `AppTheme` token asserts (`ColorScheme.primary == #0B6E99` `VISUAL-IDENTITY.md:43-49`), never `Color(0xFF0B6E99)` inline.

Responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web pane. Branded primitives (`HivorrEmptyState`, `HivorrLoadingState`, `HivorrErrorState`, `HivorrSuccessState`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

### 5.7 Routing — `lib/app/router/`

Extend `AppRouter.create` (`lib/app/router/app_router.dart:17`) via `RoutePaths.finance = '/finance'`, `financeCreate = '/finance/create'` and `RouteNames.finance/financeCreate`. Guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) — authenticated required; no taxonomy gate (finance is reachable from profile menu). No SEO public URL (private flow).

### 5.8 Config & Logging

- No new `ENV` keys — Supabase config covers it (`lib/config/environments/environment_config.dart:17`). `PaymentGatewayConfig` (`EP-02-09`) imported read-only via factory, not instantiated.
- Errors via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) — `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `409→PLT005 conflict`, `5xx→PLT999 server`. `FinancialRemoteDataSource` rethrows normalized `ApiException`; provider surfaces `message` without leaking `stack`/`SQL`.
- `HivorrLogger` + `PiiRedactor` (`lib/core/logging/`) — log `entityId suffix`, `currencyCode`, `balance values`; never `legal_name`, never raw account numbers. `MonitoringService` span `finance.profile.get` sampled.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `FinancialRemoteDataSource` abstract | `lib/data/datasources/remote/financial_remote_data_source.dart` | **Create** — §5.2 |
| `SupabaseFinancialRemoteDataSource` | `lib/data/datasources/remote/supabase_financial_remote_data_source.dart` | **Create** — `BaseApiService` impl §5.2 |
| `FinancialProfile` entity | `lib/data/entities/financial_profile.dart` | **Create** — §5.2 |
| `CurrencyAccount` entity | `lib/data/entities/currency_account.dart` | **Create** — §5.2 |
| `Balance` entity | `lib/data/entities/balance.dart` | **Create** — §5.2 |
| `FinancialStatus` entity | `lib/data/entities/financial_status.dart` | **Create** — §5.2 |
| `SupportedCurrency` value object | `lib/systems/finance/models/supported_currency.dart` | **Create** — §5.4 |
| DTOs | `lib/data/models/financial_profile_dto.dart`, `currency_account_dto.dart`, `balance_dto.dart`, `financial_status_dto.dart` | **Create** — §5.2 |
| Mappers | `lib/data/mappers/financial_mapper.dart` | **Create** — `profileToEntity`, `accountToEntity`, `balanceToEntity`, `statusToEntity` |
| `FinancialRepository` abstract + impl | `lib/data/repositories/financial_repository.dart` + `financial_repository_impl.dart` | **Create** — §5.3 |
| `FinancialProvider` (ChangeNotifier) | `lib/data/providers/financial_provider.dart` | **Create** — §5.5 (mirrors `VerificationProvider` `lib/data/providers/verification_provider.dart:42`) |
| `FinancialService` facade | `lib/systems/finance/services/financial_service.dart` | **Create** — §5.4 |
| `BalanceFormatter` | `lib/systems/finance/helpers/balance_formatter.dart` | **Create** — §5.4 pure logic |
| Screens | `lib/systems/finance/screens/financial_profile_screen.dart`, `financial_profile_creation_flow.dart` | **Create** — §5.6 |
| Widgets | `lib/systems/finance/widgets/financial_profile_card.dart`, `balance_overview_card.dart`, `currency_account_card.dart`, `balance_chip.dart` | **Create** — §5.6 |
| Barrel | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` | **Update** — re-exports |
| Route extension | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` | **Update** — add 2 routes, guard via `RouteGuard` |
| `PaymentGatewayFactory` reuse | `lib/integrations/payment_gateways/payment_gateway_factory.dart` | **Reuse** — read-only `resolveForCurrency` hint; no write path |
| `VerificationEnvelopeParser` reuse | `lib/data/datasources/remote/verification_envelope_parser.dart` | **Reuse** — envelope unwrap for financial RPCs |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — verify `git diff --stat supabase/` = 0 |
| No `lib/integrations/payment_gateways/*` mutation | `lib/integrations/payment_gateways/` | **No change** — `PaymentGatewayFactory` consumed, not modified |
| Tests + fakes | `test/unit/data/finance/financial_*`, `test/widget/systems/finance/financial_*`, `test/support/fakes/fake_financial_remote_data_source.dart` | **Create** — §14 |

No new `public.*` tables, no RPCs, no Edge Functions, no storage buckets.

## 7. Data Requirements

### 7.1 Supported Currencies (read-only reference)

Seeded `financial_supported_currencies` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:37-62`):

| currency_code | name | symbol | decimal_places | is_active |
|---|---|---|---|---|
| `NGN` | Nigerian Naira | ₦ | 2 | true |
| `GHS` | Ghanaian Cedi | ₵ | 2 | true |
| `USD` | US Dollar | $ | 2 | true |
| `GBP` | British Pound | £ | 2 | true |

Client treats `currency_code` as opaque 3-char ISO string + `SupportedCurrency.fromCode` + display label/symbol from `FinancialService.supportedCurrencies`. Currency list is **data-driven** — future additions (KES, ZAR) require only a seed insert + `SupportedCurrency` enum extension, not screen edits.

### 7.2 Per-Entity Financial Profile (read-only + create)

`financial_profiles` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:67-78`): `entity_id uuid unique` `69`, `status in ('active','suspended','closed')` `71-72`, `default_currency FK financial_supported_currencies` `73-74`. Exactly one row per entity, created via `financial_profile_create` (`635-680` — inserts profile + default balance row, `PLT005` if exists). Client reads via `financial_profile_get()` `683-714` → `{profile:{id,entity_id,status,default_currency,created_at}, currency_accounts:[{id,currency_code,account_status,receiving_account_number,receiving_bank_name,activated_at}]}`.

### 7.3 Per-Entity Currency Accounts (read-only display)

`financial_currency_accounts` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:89-115`): `unique(entity_id, currency_code)` `106`, `account_status in ('pending','active','suspended','closed')` `97-98`. One row per entity per currency. Returned as array in `financial_profile_get` response. Client displays status and bank details when activated; never writes directly.

### 7.4 Per-Entity Balances (read-only)

`financial_balances` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:120-146`): `available_balance >=0`, `held_balance >=0`, `pending_balance >=0`, `total_deposited >=0`, `total_withdrawn >=0`. One row per `(entity_id, currency_code)`. Client reads via `financial_balance_get(p_currency_code)` `717-754` (single currency, defaults zero) or `financial_status_get()` `1566-1618` (all currencies aggregated). Client never writes balance columns directly — all mutations via server-side RPCs (`EP-02-14/16`).

### 7.5 Financial Status Aggregate (read-only)

`financial_status_get()` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1566-1618`) returns: `{default_currency, profile_status, balances:[{currency_code,available_balance,held_balance,pending_balance}], active_escrow_count, cashout_limit}` — combines profile + balances + KYC-derived cashout limit in one call. Client uses this for the unified financial dashboard.

### 7.6 Profile Creation Payload (write via RPC)

`financial_profile_create(p_default_currency)` input: `defaultCurrency` (one of `NGN/GHS/USD/GBP`). Output `{success, code, message, data:{profile_id, default_currency, balance_id}}` — client re-reads `getProfile()` after creation to confirm (prevents spoofed local state).

### 7.7 Notification Payload (derived, not persisted)

`HivorrNotification{id: profile.id.hashCode, title: 'Financial profile created', body: 'Your default currency is ₦ NGN — start receiving payments', channel: system, priority: medium, actionRoute: '/finance'}` — local notification only; no `supabase_realtime` payload.

## 8. Database Considerations

- **Zero DDL in this task.** `public.financial_profiles`, `public.financial_currency_accounts`, `public.financial_balances`, `public.financial_transactions`, `public.financial_supported_currencies` all exist (`supabase/migrations/20260829100004_financial_integrity_schema.sql:37-176`). No `ALTER`, `CREATE POLICY`, `GRANT`, index, or trigger added. Full pgTAP `001-017` + financial `013-014` suites must remain green.
- **RLS posture inherited:** RLS enabled on all 12 financial tables (`479-490`) + default-deny `revoke all from anon, authenticated, service_role` (`492-506`) + narrow grants: `financial_profiles: authenticated SELECT/INSERT(entity_id, default_currency)` `513`, `financial_currency_accounts: authenticated SELECT/INSERT(entity_id, currency_code)` `517`, `financial_balances: authenticated SELECT/INSERT(limited)/UPDATE(balance columns)` `521-524`, `financial_supported_currencies: authenticated SELECT` `509`. Client profile creation is via `financial_profile_create` RPC only — direct `POST /rest/v1/financial_profiles` would hit RLS insert policy but is not the intended path (RPC handles idempotency + audit).
- **Execution model respected:** `financial_profile_create/get`, `financial_balance_get`, `financial_status_get` granted to `authenticated` (`635,683,717,1566`); `financial_profile_create` self-scoped via `auth.uid()` `642`. `financial_reconcile` granted to `service_role` only (`1621`). All RPCs `SECURITY INVOKER`, RLS applies inside function body.
- **Profile creation is idempotent:** `financial_profile_create` checks `exists (select 1 from financial_profiles where entity_id = v_actor)` `655` and returns `PLT005 conflict` — client surfaces "Profile already exists" inline, not toast.
- **No service-role bypass in client.** Adapters never hold `service_role` key; `SupabaseClientProvider.client` (`lib/core/api/supabase/supabase_client_provider.dart:19`) uses `anon`/`authenticated` role with RLS. `grep -r "service_role" lib/systems/finance lib/data/finance` must be `0`.
- **Currency-specific overrides deferred:** Base NGN limits are the source of truth here. `EP-02-16` layers per-currency cashout overrides; no `financial_*` FK mutation in this task.
- **Audit:** `financial_audit_trail` `profile_created` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:672`) is written server-side by `financial_profile_create`; client never inserts audit rows directly.

## 9. API Requirements

### 9.1 Supabase RPC (via `SupabaseFinancialRemoteDataSource`)

| Operation | RPC | Params | Auth | Success Envelope | Error → ApiExceptionKind |
|---|---|---|---|---|---|
| Create profile | `financial_profile_create` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:635`) | `p_default_currency char(3)` default `'NGN'` | `authenticated` (`auth.uid()`) | `200 {success:true, code:PLT000, data:{profile_id, default_currency, balance_id}}` | `409 PLT005 conflict` (profile exists), `400 PLT003 validation` (unsupported currency), `401 PLT001 auth` |
| Get profile + accounts | `financial_profile_get` (`683`) | — | `authenticated` self-scoped | `200 {success:true, code:PLT000, data:{profile:{id,entity_id,status,default_currency,created_at}, currency_accounts:[...]}}` | `401 PLT001 auth` |
| Get single-currency balance | `financial_balance_get` (`717`) | `p_currency_code char(3)` | `authenticated` self-scoped | `200 {success:true, code:PLT000, data:{currency_code, available_balance, held_balance, pending_balance}}` defaults zero | `404 PLT004 notFound` (unsupported currency), `401 PLT001 auth` |
| Get aggregated status | `financial_status_get` (`1566`) | — | `authenticated` self-scoped | `200 {success:true, code:PLT000, data:{default_currency, profile_status, balances:[...], active_escrow_count, cashout_limit}}` | `401 PLT001 auth` |
| (not invoked by client) | `financial_payout_account_bind` (`1150`) | `p_currency_code, p_bank_name, p_account_number, p_account_name` | `authenticated` self-scoped | `PLT000` + account created | `EP-02-16` path |

All `supabase.rpc<Map<String,dynamic>>('financial_*', params: {...})` unwrapped via financial envelope parser — checks `data['success']==true && data['code']=='PLT000'` else throws `ApiException` with extracted `code/message`.

### 9.2 Payment Gateway Seam (read-only hint)

| Operation | Interface | Params | Transport | Notes |
|---|---|---|---|---|
| Resolve provider for currency | `PaymentGatewayFactory.resolveForCurrency(currencyCode)` (`lib/integrations/payment_gateways/payment_gateway_factory.dart`) | `currencyCode` | In-memory factory lookup | Returns `PaymentGateway?` — used as hint for `requestAccountActivation` guidance; no network call in this task |

No Supabase REST `POST /rest/v1/financial_profiles` — client uses `financial_profile_create` RPC. No `lib/integrations/payment_gateways/` mutation.

### 9.3 No Storage / No Edge Functions

No `Supabase Storage` REST (profile is RPC, not upload). No Edge Function (webhook HMAC deferred). No live payment provider SDK calls — `requestAccountActivation` returns guidance, not a provider initiation.

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
| `FinancialProfileScreen` | `GET /finance` | Profile overview + balances + accounts | `AppBar(title: Text('Financial Profile', style: textTheme.titleLarge))`, `FinancialProfileCard` (default currency + status chip), `BalanceOverviewCard` (per-currency chips with ₦/₵/$/£ formatting), `CurrencyAccountsList` (account cards with status badges), create/manage CTA |
| `FinancialProfileCreationFlow` | `GET /finance/create` | Profile creation wizard | Default currency selector (radio group with symbols), "Create Profile" `HivorrButton(variant: primary, isLoading, isExpanded:true)` → `financial_profile_create` via provider |
| `BalanceOverviewCard` | — | Reusable balance grid | Per-currency `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` chips, value `textTheme.titleMedium`, label `textTheme.labelSmall` `colorScheme.onSurfaceVariant`, available `successContainer`, held `primaryContainer`, pending `warningContainer` |
| `FinancialProfileCard` | — | Reusable profile header | `Container(decoration: BoxDecoration(color: profile.status == 'active' ? colorScheme.successContainer : colorScheme.warningContainer, borderRadius: BorderRadius.circular(ext.radiusSm)))` — soft, not hard shadow (`VISUAL-IDENTITY.md:226`) |
| `CurrencyAccountCard` | — | Per-currency account card | `NGN — ₦ Nigerian Naira` + status badge (`active` green, `pending` amber, `closed` grey) + bank name when activated + lock/unlock icon `Icons.account_balance` tinted `colorScheme.secondary` when active |

All screens responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp padding mobile, 24dp web pane. Empty state: `HivorrEmptyState` with "Create your financial profile to start receiving payments" + branded illustration slot. Error state: `HivorrErrorState` with `decisionNotes` when `status == suspended/closed` + "Contact support" action.

## 11. User Experience Considerations

- **Progressive disclosure, not overwhelming:** Financial profile screen shows one profile card + balance overview + account list, not a wall of transaction history. Creation flow shows only default currency selector first, with "Add more currencies later" guidance — matches `EP-02:32` proportional-risk narrative without cognitive load.
- **Fail-fast balance preview:** `BalanceFormatter.formatBalance` runs locally — no RPC needed for display. Profile creation validates `defaultCurrency` against `supportedCurrencies` client-side before calling `financial_profile_create`, preventing `PLT003` server round-trip on invalid input.
- **Profile existence check:** On `FinancialProfileScreen` mount, `FinancialProvider.load()` calls `getProfile()` first; if `null`, shows creation CTA inline (no separate "no profile" screen). This prevents wasted `getStatus()` RPC when profile does not exist (`financial_status_get` would fail `PLT004`).
- **Currency clarity:** All balances show currency symbol + code (e.g., `₦50,000.00 NGN`) to prevent confusion between similar currencies. Default currency highlighted with `primaryContainer` background. Currency list is data-driven — future KES/ZAR additions require zero screen edits.
- **Account activation guidance:** `CurrencyAccountCard` for `pending` accounts shows "Connect your [currency] bank account" with provider hint from `PaymentGatewayFactory.resolveForCurrency` — guides user to `EP-02-16` binding flow without blocking profile display.
- **Profile status sensitivity:** `suspended` status renders with `HivorrErrorState` illustration + warm microcopy + "Contact support" CTA. `closed` status shows deactivation date with explanation. Neither status blocks balance viewing (read-only).

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Server-authoritative profiles** `AGENT.md:16` Rule 4 | Client never writes `financial_profiles.default_currency/status` or `financial_currency_accounts.*` directly via REST. All mutations via `financial_profile_create` RPC which handles idempotency (`PLT005 conflict`) and audit. RLS grant on `financial_profiles` is `authenticated SELECT/INSERT(entity_id, default_currency)` only `513`; attempt to `POST {status:'active'}` via REST returns RLS violation or `403 PLT002`. |
| **No anon access** | All 12 financial tables `revoke all from anon` (`492-506`) + policies `to authenticated` only; `financial_supported_currencies` `authenticated SELECT` `509`. App guards with `RouteGuard` redirect to `/login` (`lib/app/router/route_guard.dart:1`). |
| **No `service_role` leak** | No `service_role` import in client data/systems; `FinancialProvider` never holds `service_role` key. `grep lib/systems/finance lib/data "service_role"` = 0. |
| **PII exposure** | Token via `SupabaseClientProvider.currentAccessToken` never logged; `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) masks `entityId` to `***last4`, never logs `account_number`/`bank_name` full. Balance values logged for debugging but no PII. |
| **Balance enforcement is server-side** | `FinancialProvider` balance display is read-only; authoritative enforcement is `financial_balance_get` → `financial_withdraw` (`EP-02-16`) checking `amount <= available_balance` server-side. Client display mismatch does not grant funds — server returns `PLT006 insufficient funds`. No `financial_balances` client mutation in this task. |
| **Time-of-check / race** | `financial_profiles.entity_id` `unique` `69` + `financial_profile_create` conditional check `655` prevents duplicate profiles; client `createProfile` duplicate surfaces `PLT005 conflict` dialog via repository error mapping. |
| **Auth state isolation** | `AppEnvironment` `Development→Staging→Production` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); `financial_*` per environment via migration, no cross-env read. |
| **Currency validation** | `FinancialRepository.createProfile` validates `defaultCurrency` against `supportedCurrencies` list (data-driven from `financial_supported_currencies`) before RPC call — prevents `PLT003` server error and ensures client currency vocabulary matches server. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **Parallel fetch** | `FinancialProvider.load()` calls `getProfile()` + `getStatus()` with `Future.wait` — 1 round-trip batch via separate RPCs, not sequential; status already contains balances so `load()` may use `getStatus()` only and derive profile locally to save one RPC (decision at implementation time). |
| **Caching** | `FinancialProvider` memoizes `profile` + `accounts` + `balances` + `status` in memory (no Hive `lib/data/datasources/local/` needed — small aggregate). Invalidate via `refreshStatus()` on resume, profile creation, or pull-to-refresh. No disk persistence of profile beyond aggregate. |
| **Guard evaluation cost** | `BalanceFormatter.formatBalance` pure string formatting `O(n)` on ≤12-char output — free to call per render. `SupportedCurrency.fromCode` map lookup `O(1)` — microseconds. |
| **RPC cost** | `financial_profile_get` `STABLE` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:687`) + indexed `financial_profiles_entity_id_key` `83`, `financial_currency_accounts_entity_currency_key` `112`, `financial_balances_entity_currency_key` `143` — negligible. `financial_status_get` `STABLE` `1569` + indexed joins — sub-10ms typical. |
| **Lifecycle pause/resume** | `WidgetsBindingObserver` `didChangeAppLifecycleState` pauses `FinancialProvider` polling on background, resumes on foreground — no wasted RPCs while app is backgrounded on Nigerian 3G. |
| **Tracer overhead** | `PerformanceTracer` span (`lib/core/monitoring/performance_tracer.dart:1`) around `getProfile`/`getStatus` sampled via `MonitoringConfig`, tags `finance.profile.status`, `finance.currency.count`, no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/data/finance/` + `test/unit/systems/finance/`

Pattern mirrors `test/unit/core/api/api_exception_mapper_test.dart` + `test/support/fakes/fake_storage.dart:9` (`InMemorySecureStorage`) and `test/support/fakes/fake_supabase.dart` — no live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `financial_remote_data_source_test.dart` | 10 | Mock `SupabaseClient.rpc` via fake `SupabaseClient` (`fake_supabase.dart`): `financial_profile_get → {success:true, data:{profile:{...}, currency_accounts:[...]}}` success; `financial_balance_get('NGN') → {currency_code:NGN, available_balance:50000...}` success; `financial_balance_get('XYZ') → PLT004` → `ApiExceptionKind.notFound`; envelope `success:false → PLT003` → `validation`; `401→PLT001 auth`, `500→PLT999` via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:18`); `financial_status_get → {balances:[...], active_escrow_count:0, cashout_limit:100000}` success; `financial_profile_create('NGN') → {profile_id, default_currency:NGN}` success; `financial_profile_create existing → PLT005 conflict` |
| `financial_repository_test.dart` | 14 | Fake `SupabaseFinancialRemoteDataSource` + fake `PaymentGatewayFactory`. Validates `getProfile` maps profile + accounts; `getBalance('NGN')` returns balance entity; `getBalance('XYZ')` returns null (unsupported); `getStatus` maps full aggregate; `createProfile('NGN')` delegates to RPC and re-reads; `createProfile('XYZ')` throws validation before RPC; `requestAccountActivation('NGN')` returns guidance; profile null when no row; PLT005 conflict surfaces "already exists" |
| `financial_provider_test.dart` | 12 | `ChangeNotifier` with mocked repository: `load()` sets `loadState=loading` then `success`, calls `getProfile` + `getStatus`; `createProfile` delegates to repository and refreshes; lifecycle `pausePolling`/`resumePolling` via `WidgetsBindingObserver`; `refreshStatus` re-reads and `notifyListeners`; error state surfaces `lastError.message` |
| `financial_mapper_test.dart` | 10 | `FinancialProfileDto.fromJson → FinancialProfile` mapping `entity_id, status, default_currency, created_at`; `BalanceDto.fromJson → Balance` mapping `available_balance, held_balance, pending_balance`; `CurrencyAccountDto.fromJson → CurrencyAccount` mapping `account_status, receiving_account_number`; null handling → defaults; `FinancialStatusDto.fromJson → FinancialStatus` mapping balances array + `active_escrow_count` + `cashout_limit` |
| `balance_formatter_test.dart` | 8 | Pure logic: `formatBalance(50000, 'NGN') == '₦50,000.00'`; `formatBalance(1200, 'GHS') == '₵1,200.00'`; `formatBalance(100, 'USD') == '$100.00'`; `formatBalance(75.5, 'GBP') == '£75.50'`; `formatBalance(0, 'NGN') == '₦0.00'`; negative input throws `ArgumentError`; unsupported currency falls back to code-only |
| `supported_currency_test.dart` | 6 | Enum labels ("Nigerian Naira", "Ghanaian Cedi"), `fromCode('NGN')` returns correct instance, `values.length==4`, extensibility (adding KES requires only enum + seed) |

Target **≥60 unit assertions**; repository/provider ≥90%, mappers/formatter 100%.

### 14.2 Widget Suite — `test/widget/systems/finance/`

| File | Cases (min) | Method |
|---|---|---|
| `financial_profile_screen_test.dart` | 12 | Pump with `Provider<FinancialProvider>` fake + `MaterialApp` `AppTheme.light` (`lib/app/theme/app_theme.dart:1`): profile card renders `active` with `successContainer` when active, `warningContainer` when suspended; balance overview shows `₦50,000.00` available; `CurrencyAccountsList` visible; create CTA visible when `profile == null`, hidden when `profile != null`; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily` literal), spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:220`); `grep Colors.` assert `0` |
| `financial_profile_creation_flow_test.dart` | 8 | Pump with `FinancialProvider` mock `profile == null`: default currency radio shows NGN/GHS/USD/GBP with symbols; "Create Profile" `HivorrButton` visible, tap shows `HivorrLoader` (`lib/app/widgets/hivorr_loader.dart:1`); `profile != null` shows `HivorrSuccessState`; unsupported currency not in list |
| `balance_overview_card_test.dart` | 8 | Chips colors `successContainer` available vs `primaryContainer` held vs `warningContainer` pending, no hardcoded hex, semantics `Semantics(label:'Available balance ₦50,000.00')` |
| `currency_account_card_test.dart` | 8 | Badge colors `successContainer`/`warningContainer`/`outline` per status, no `Color(0xFF...)`, bank name visible when activated |

Widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` and `find.byType(HivorrButton)`.

### 14.3 Integration (Fake-E2E) — `test/integration/finance/financial_profile_flow_test.dart`

Single integration-compose test without live Supabase: fake `SupabaseClient.rpc` map + real `FinancialRepositoryImpl`. Flow: `getProfile() → null` (no profile) → `createProfile(defaultCurrency: 'NGN')` → mock `financial_profile_create → {profile_id, default_currency:NGN}` → re-read `getProfile()` → `profile.defaultCurrency == 'NGN'` + `profile.status == 'active'` → `getBalance('NGN')` → `balance.availableBalance == 0` + `balance.heldBalance == 0` → `getStatus()` → `status.balances.length == 1` + `status.cashoutLimit == 100000`. No `supabase start` container needed; live `supabase db test` is the source-of-truth for RLS.

### 14.4 Regression Guard

`flutter analyze` + `flutter test --coverage` (domain ≥80%) + `supabase db test` full suite `001..017` + financial `013-014` green. Lens `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 (private finance seam) except `lib/app/theme/app_colors.dart:16`, `grep -r "fontFamily" lib/systems/finance` = 0, `grep -r "service_role" lib/` = 0, `git diff --stat supabase/` = 0.

### 14.5 Lens Summary

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` RLS/posture. Add `test/support/fakes/fake_financial_remote_data_source.dart` export.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `supabase/migrations/20260829100004_financial_integrity_schema.sql:37-146,635-754,1566-1618`, `lib/systems/finance/.gitkeep`, `lib/integrations/payment_gateways/payment_gateway_factory.dart`, `lib/core/api/services/base_api_service.dart:15`, `lib/data/datasources/remote/verification_envelope_parser.dart`, `lib/data/providers/verification_provider.dart:42` posture | Baseline |
| 2 | Create `lib/data/entities/financial_profile.dart` — `FinancialProfile{id, entityId, status, defaultCurrency, createdAt}` entity | Entity |
| 3 | Create `lib/data/entities/currency_account.dart` — `CurrencyAccount{id, financialProfileId, entityId, currencyCode, accountStatus, receivingAccountNumber?, receivingBankName?, providerReference?, activatedAt?}` entity | Entity |
| 4 | Create `lib/data/entities/balance.dart` — `Balance{currencyCode, availableBalance, heldBalance, pendingBalance, totalDeposited, totalWithdrawn, lastTransactionAt?}` entity | Entity |
| 5 | Create `lib/data/entities/financial_status.dart` — `FinancialStatus{defaultCurrency, profileStatus, balances, activeEscrowCount, cashoutLimit}` aggregate entity | Entity |
| 6 | Create `lib/data/models/financial_profile_dto.dart`, `currency_account_dto.dart`, `balance_dto.dart`, `financial_status_dto.dart` — JSON serialization DTOs matching RPC response shapes | DTOs |
| 7 | Create `lib/data/mappers/financial_mapper.dart` — `profileToEntity`, `accountToEntity`, `balanceToEntity`, `statusToEntity` extension methods | Mappers |
| 8 | Create `lib/data/datasources/remote/financial_remote_data_source.dart` — abstract `FinancialRemoteDataSource` §5.2 | Contract |
| 9 | Create `lib/data/datasources/remote/supabase_financial_remote_data_source.dart` — `BaseApiService` impl: `financial_profile_get`, `financial_balance_get`, `financial_status_get`, `financial_profile_create` via envelope parser | Remote |
| 10 | Create `lib/data/repositories/financial_repository.dart` abstract + `lib/data/repositories/financial_repository_impl.dart` — §5.3 `getProfile/getBalance/getStatus/createProfile/requestAccountActivation`, never writes `financial_profiles`/`financial_currency_accounts` directly | Repository |
| 11 | Create `lib/systems/finance/models/supported_currency.dart` — `SupportedCurrency{code, name, symbol, decimalPlaces}` + `fromCode` + static `all` list | Currency vocab |
| 12 | Create `lib/systems/finance/services/financial_service.dart` — facade §5.4 + `lib/systems/finance/helpers/balance_formatter.dart` — pure `formatBalance(amount, currencyCode)` | Service + helper |
| 13 | Create `lib/data/providers/financial_provider.dart` — `ChangeNotifier` §5.5 (mirrors `VerificationProvider` `lib/data/providers/verification_provider.dart:42` lifecycle, `pausePolling`/`resumePolling`) | Provider |
| 14 | Create widgets `lib/systems/finance/widgets/financial_profile_card.dart`, `balance_overview_card.dart`, `currency_account_card.dart`, `balance_chip.dart` — `AppTheme` tokens only | Widgets |
| 15 | Create screens `lib/systems/finance/screens/financial_profile_screen.dart`, `financial_profile_creation_flow.dart` — §5.6 responsive, branded states | Screens |
| 16 | Update barrels `lib/systems/finance/finance.dart:1`, `lib/data/data_layer.dart:1` | Barrels |
| 17 | Update `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` — add `finance/financeCreate` routes guarded by `RouteGuard` | Routes |
| 18 | Create `test/support/fakes/fake_financial_remote_data_source.dart` + `test/support/fakes/fake_financial_repository.dart` | Test infra |
| 19 | Create `test/unit/data/finance/financial_remote_data_source_test.dart` (10) + `financial_repository_test.dart` (14) + `financial_mapper_test.dart` (10) + `balance_formatter_test.dart` (8) + `supported_currency_test.dart` (6) | Tests 1 |
| 20 | Create `test/unit/data/providers/financial_provider_test.dart` (12) | Tests 2 |
| 21 | Create `test/widget/systems/finance/financial_profile_screen_test.dart` (12) + `financial_profile_creation_flow_test.dart` (8) + `balance_overview_card_test.dart` (8) + `currency_account_card_test.dart` (8) | Tests 3 |
| 22 | Create `test/integration/finance/financial_profile_flow_test.dart` — fake-E2E no-profile → create → getProfile → getBalance → getStatus | Integration |
| 23 | `flutter analyze` + `flutter test --coverage` (≥60 assertions green, repository ≥90%, mapper 100%) | Verify |
| 24 | `supabase db test` full suite `001..017` + `013-014` green + `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 + `grep -r "service_role" lib/` = 0 + `git diff --stat supabase/` = 0 | Regression |
| 25 | Doc pass: dartdoc on `FinancialProfile`, `Balance`, `CurrencyAccount`, `SupportedCurrency`, `BalanceFormatter`, `FinancialRepository` contract | Docs |
| 26 | Tag `EP-02-14/15/16` unblocked; phase plan `EP-02-13` → `Completed` candidate pending review | Handoff |

## 16. Expected Outcome

- `lib/data/` exposes a single seam for financial profile state: `FinancialRepository` reads `financial_profiles`, `financial_currency_accounts`, and `financial_balances` via the frozen `financial_profile_get`/`financial_balance_get`/`financial_status_get` RPCs, maps via `FinancialMapper` to pure `FinancialProfile`/`CurrencyAccount`/`Balance`/`FinancialStatus`, and surfaces `createProfile` + `requestAccountActivation` through the `PaymentGatewayFactory` hint without writing tables directly.
- `lib/systems/finance/` provides a **currency-agnostic, data-driven** financial profile system — `data → systems → finance` is unidirectional; `SupportedCurrency` vocabulary is extensible by enum + seed, not screen edits (`ARCHITECTURE.md:112-114` analogue). `BalanceFormatter` is pure, testable, locale-aware.
- `FinancialProvider` (`ChangeNotifier`) owns parallel fetch, `WidgetsBindingObserver` lifecycle, and profile creation flow — mirroring the proven `VerificationProvider` (`lib/data/providers/verification_provider.dart:42`) pattern with no `supabase_realtime`.
- `FinancialProfileScreen` + `FinancialProfileCreationFlow` render profile card, balance overview, currency accounts, and creation wizard with **zero hardcoded `Colors.*`/hex/`fontFamily`** — all `Theme.of(context).colorScheme.*`/`textTheme.*`/`AppThemeExtension` tokens (`VISUAL-IDENTITY.md:176-190,219-235`), responsive via `shared/layouts/` (16dp mobile / 24dp web), branded states via `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`/`HivorrLoader`.
- Unit suite ≥60 assertions green with mocked `SupabaseClient`/`Dio`; `flutter analyze` clean; full pgTAP `001-017` + financial `013-014` green; `grep` proves no `service_role` or hardcoded color/font leakage; `git diff --stat supabase/` = 0.
- `EP-02-14` (Escrow), `EP-02-15` (Currency Conversion), `EP-02-16` (Payouts & Deposit Verification) unblocked — financial profile seam provides typed entities, repository, and provider for escrow creation, balance checks, payout binding, and conversion display.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/data/entities/financial_profile.dart` exists — `FinancialProfile{id, entityId, status, defaultCurrency, createdAt}` | File inspection |
| 2 | `lib/data/entities/currency_account.dart` exists — `CurrencyAccount{id, financialProfileId, entityId, currencyCode, accountStatus, receivingAccountNumber?, receivingBankName?, providerReference?, activatedAt?}` | File inspection |
| 3 | `lib/data/entities/balance.dart` exists — `Balance{currencyCode, availableBalance, heldBalance, pendingBalance, totalDeposited, totalWithdrawn, lastTransactionAt?}` | File inspection |
| 4 | `lib/data/entities/financial_status.dart` exists — `FinancialStatus{defaultCurrency, profileStatus, balances, activeEscrowCount, cashoutLimit}` | File inspection |
| 5 | `lib/data/datasources/remote/financial_remote_data_source.dart` exists — abstract `FinancialRemoteDataSource` with `getProfile`, `getBalance(currencyCode)`, `getStatus` | File inspection |
| 6 | `lib/data/datasources/remote/supabase_financial_remote_data_source.dart` implements `FinancialRemoteDataSource` — `extends BaseApiService`, `supabase.rpc('financial_profile_get'/'financial_balance_get'/'financial_status_get'/'financial_profile_create')`, envelope unwrap, `DataExceptionMapper` | File + unit test |
| 7 | `lib/data/mappers/financial_mapper.dart` defines `profileToEntity`, `accountToEntity`, `balanceToEntity`, `statusToEntity` — maps DTOs to entities, null → defaults | Unit test |
| 8 | `lib/data/repositories/financial_repository.dart` + `financial_repository_impl.dart` define `FinancialRepository{getProfile,getBalance,getStatus,createProfile,requestAccountActivation}` — validates currency before RPC, never writes `financial_profiles`/`financial_currency_accounts` directly | Unit test |
| 9 | `lib/systems/finance/models/supported_currency.dart` defines `SupportedCurrency{code, name, symbol, decimalPlaces}` + `fromCode` + `all` list matching `financial_supported_currencies` seed | File + unit test |
| 10 | `lib/systems/finance/services/financial_service.dart` facade + `lib/systems/finance/helpers/balance_formatter.dart` pure `formatBalance(amount, currencyCode)` | File + unit test (formatter 100%) |
| 11 | `lib/data/providers/financial_provider.dart` exists — `ChangeNotifier` with `profile/accounts/balances/status/loadState`, `load()`/`refreshStatus()`/`createProfile()`, `pausePolling`/`resumePolling`, `dispose` — mirrors `lib/data/providers/verification_provider.dart:42` | Unit test |
| 12 | `lib/systems/finance/screens/financial_profile_screen.dart` exists — `GET /finance`, profile card + balance overview + accounts list + create CTA, `AppTheme` tokens only, responsive | Widget test |
| 13 | `lib/systems/finance/screens/financial_profile_creation_flow.dart` exists — `GET /finance/create`, default currency selector + create CTA | Widget test |
| 14 | `lib/systems/finance/widgets/financial_profile_card.dart` / `balance_overview_card.dart` / `currency_account_card.dart` / `balance_chip.dart` exist — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp (`VISUAL-IDENTITY.md:221`) | Widget test |
| 15 | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` barrels re-export new symbols | File inspection |
| 16 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `finance='/finance'` + `financeCreate='/finance/create'` guarded by `RouteGuard` | File + `go_router` smoke |
| 17 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` |
| 18 | No `lib/integrations/payment_gateways/*` mutation — `git diff --stat lib/integrations/payment_gateways` = 0 | `git diff --stat` |
| 19 | No `service_role` or secret leakage — `grep -r "service_role" lib/systems/finance lib/data/finance` = 0 | `grep` |
| 20 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/finance` = 0 | `grep` |
| 21 | `test/unit/data/finance/financial_remote_data_source_test.dart` ≥10 cases green (RPC envelope, `PLT001/003/004/005/999`) | `flutter test` |
| 22 | `test/unit/data/finance/financial_repository_test.dart` ≥14 + `financial_mapper_test.dart` ≥10 + `balance_formatter_test.dart` ≥8 + `supported_currency_test.dart` ≥6 green | `flutter test` |
| 23 | `test/unit/data/providers/financial_provider_test.dart` ≥12 cases green (`load` parallel fetch, `createProfile`, lifecycle pause/resume) | `flutter test` |
| 24 | `test/widget/systems/finance/financial_profile_screen_test.dart` ≥12 + `financial_profile_creation_flow_test.dart` ≥8 + `balance_overview_card_test.dart` ≥8 + `currency_account_card_test.dart` ≥8 green, token + layout asserts | `flutter test` |
| 25 | `test/integration/finance/financial_profile_flow_test.dart` fake-E2E green: no-profile → create → getProfile → getBalance → getStatus | `flutter test` |
| 26 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI |
| 27 | `supabase db test` full suite `001-017` + financial `013-014` green — no RLS/role regression | `supabase db test` |
| 28 | `flutter test` total ≥60 unit assertions green; `BalanceFormatter` 100%, `FinancialProvider` ≥90%, mappers 100% | `flutter test` |

---

## Recommended Implementation AI Execution Profile

**Recommended Coding Reasoning Level:** **Very High**

**Reasoning Level Justification:**

| Dimension | Assessment | Rationale |
|---|---|---|
| Technical complexity | High | Thin RPC wrapper + currency vocabulary + entity definitions + `ChangeNotifier` provider + balance formatting — non-trivial but follows proven `EP-02-12` `KycService` + `EP-02-09` integration-seam patterns; no new SQL, no branch-heavy provider parsing. Below `EP-02-04` schema work but above CRUD. |
| Business impact | Very High | Financial profile is the foundation for escrow, payouts, conversions, and deposits — misrendered balances or broken profile creation directly blocks all `EP-02-14/15/16` tasks and the entire marketplace transaction flow. No money moves in this task, but incorrect profile state cascades catastrophically. |
| Security risk | High | Default-deny RLS + profile creation idempotency (`PLT005`) must not be violated — client must never write `financial_profiles.status` or `financial_currency_accounts.*` directly. Balance display is read-only; authoritative enforcement is server-side, but a client bypass bug would be a `403` caught in tests, not silent fraud. |
| Performance sensitivity | Medium | Parallel `Future.wait` fetch + `O(1)` guard + `BalanceFormatter` — trivial cost, but lifecycle pause/resume and profile null-check before `getStatus` must be correct to avoid wasted RPCs on Nigerian 3G. |
| Data complexity | Medium | 4-currency vocabulary + `FinancialProfile`/`CurrencyAccount`/`Balance`/`FinancialStatus` entities + DTO mapping — reuse of `VerificationEnvelopeParser` keeps transport narrow; no ledger double-entry in client. |
| Integration complexity | Very High | Drives currency-agnostic financial extensibility for EP-08 (KES/ZAR future), mirrors `EP-02-09` payment-gateway ISP with `PaymentGatewayFactory.resolveForCurrency` hint, and is consumed by `EP-02-14/15/16` — data-driven currency vocabulary with two read paths (profile + status) to prove Open/Closed. |

Overall the task establishes the financial-profile foundation (`AGENT.md:4-6` Separation of Concerns) with a data-driven currency system that must not couple `systems/finance/` to hardcoded currency lists — **Very High** reasoning ensures the entity/DTO/mapper chain is correctly typed, profile creation idempotency is handled gracefully, and zero client-side financial writes are rigorously enforced via tests and `grep` lenses.
