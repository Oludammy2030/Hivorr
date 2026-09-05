# Task Implementation Plan — EP-02-15: Currency Conversion Infrastructure

**Task ID:** EP-02-15 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Not Started | **Priority:** High | **Dependencies:** EP-02-13, EP-02-04 | **Stage:** 5 — Financial Integrity Systems

> **Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:401-410` | **Architecture:** `documents/Context/ARCHITECTURE.md:55-60,101-110,131-138`, `documents/Context/AGENT.md:4-8,15-17` | **Dependencies:** `EP-02:143-145` (`EP-02-15 → 13, 04`), `EP-02:405-410` | **Stack:** `pubspec.yaml:43-53` (`dio 5.11.0`, `supabase_flutter 2.17.2`, `provider 6.1.5`), `supabase/migrations/20260829100004_financial_integrity_schema.sql:355-382,1459-1563,1686,1731`, `lib/systems/finance/models/supported_currency.dart`, `lib/data/datasources/remote/financial_envelope_parser.dart`, `lib/core/api/services/base_api_service.dart:15`

---

## 1. Task Objective

Build the currency conversion infrastructure to enable user-initiated conversion between supported currency balances (e.g., GHS↔NGN, USD↔NGN) in `lib/systems/finance/` — rate sourcing (from a server-side config or provider seam), conversion preview with fee, conversion execution with audit trail, and conversion history display. Build the complete data layer for conversion records.

**Deliverables:**
- Data layer: `CurrencyConversion` entity + DTOs + mapper extensions, `ConversionRemoteDataSource` (RPC-only wrapper over `financial_convert_currency`), `ConversionRepository`, `ConversionProvider` in `lib/data/`
- Rate source seam: `ConversionRateSource` abstract + `ConfigConversionRateSource` (data-driven from server config/seed; provider seam for future)
- Orchestration: `ConversionService` facade in `lib/systems/finance/`
- UI: `ConversionScreen` (preview + confirm), `ConversionHistoryList`, `ConversionRateCard`, `ConversionResultCard` (`lib/systems/finance/widgets/` + `screens/`)
- Routes: `/finance/convert` (`lib/app/router/app_router.dart:17`)
- Barrel + DI: `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` re-exports
- Unit + widget + integration test suite (mocked `SupabaseClient`, fake `ConversionRateSource`, fake `ConversionRepository`)

---

## 2. Business Problem Being Solved

`EP-02:405-410` mandates **currency conversion infrastructure** as user-controlled conversion between supported balances (e.g., GHS↔NGN, USD↔NGN), server-side enforced with rate validation and fee calculation, extensible to future provider-based rate feeds. Server infrastructure exists and is frozen (`supabase/migrations/20260829100004_financial_integrity_schema.sql`):

- `financial_conversions` `355-382` — `entity_id FK entities`, `from_currency`/`to_currency FK financial_supported_currencies`, `from_amount >0`, `to_amount >0`, `exchange_rate >0`, `fee >=0`, `status in ('pending','completed','failed')` `370`, `completed_at`, `check (from_currency <> to_currency)` `375`, indexed `financial_conversions_entity_idx (entity_id, created_at desc)` `381-382`.
- `financial_convert_currency(char(3), char(3), numeric, numeric)` `1459-1563` — `p_from_currency`, `p_to_currency`, `p_amount`, `p_rate`. **Granted to `authenticated` + `service_role` `1686`** (unlike escrow writes which are `service_role`-only — the authenticated client CAN execute conversion directly). Validates supported currencies `1485-1491` (`PLT003`), `from <> to` `1492` (`PLT003`), `amount > 0` `1495` (`PLT003`), `rate > 0` `1498` (`PLT003`), self-scoped `v_actor=auth.uid()` `1472,1482` (`PLT001`). Requires existing profile `1502-1505` (`PLT004`). Locks source balance `1507-1510` `FOR UPDATE`, insufficient funds `1511-1513` (`PLT006`). Computes `v_to_amount := p_amount * p_rate - v_fee` `1515` (fee currently `v_fee := 0` `1479`). Writes double-entry `financial_transactions conversion_debit` `1526-1531` + `conversion_credit` `1533-1538`, updates source/dest balances under `FOR UPDATE` locks `1540-1548`, inserts `financial_conversions` `status='completed'` `1550-1552`, writes `financial_audit_trail conversion_executed` `1554-1556`. Returns `{conversion_id, from_amount, to_amount, rate}` `1558-1561`. `SECURITY INVOKER` `1468`, `VOLATILE` `1469`.
- RLS `620-623` — `financial_conversions_select` (entity self) + `financial_conversions_insert` (entity self) to `authenticated`, table `revoke all from anon, authenticated, service_role` `492-506`, narrow `grant select, insert to authenticated` `561-562`, `grant select, insert, update to service_role`.

**Critical rate-source decision:** `financial_convert_currency` accepts `p_rate` **as a caller-supplied parameter** — there is **no server-side rate-fetch RPC and no rate table** in the frozen migration. Per `EP-02:174` ("Conversion rules are server-side config-driven, not hardcoded") and the Engineering Purpose `EP-02:406` ("rate fetching (from server-side config or provider)"), the client **must never** accept a user-arbitrary rate. This task builds a **`ConversionRateSource` abstraction seam** — a domain-controlled, config-driven rate provider (single source of truth in a server-supplied seed/env), defaulting to guarded base rates, with a documented swap point for a future server rate RPC / provider feed (EP-02-16+ or a later financial rate provider). The rate supplied to `financial_convert_currency` originates exclusively from this seam, ensuring the client presents and executes the same trusted rate.

Without EP-02-15:

- Multi-currency balances (`EP-02-13`) exist but are **siloed** — an entity holding NGN cannot move funds to USD/GHS/GBP, breaking the unified financial profile's core promise and blocking `EP-02-16` payout/`EP-02-14` escrow cross-currency scenarios.
- Every future conversion screen would call `supabase.rpc('financial_convert_currency')` inline with a guessed rate, duplicate envelope parsing and `ApiException` mapping — violating `ARCHITECTURE.md:91-94` separation and `AGENT.md:4-6` Separation of Concerns, and risking an unstable/untrusted rate.
- No typed `CurrencyConversion` entity — the `{conversion_id, from_amount, to_amount, rate}` response and `financial_conversions` history have no client representation, forcing ad-hoc maps and schema drift.
- No preview/fee UX — entities cannot see the `to_amount` (net of fee) **before** committing, so users discover the effective rate only after a fund movement; poor trust UX and accuracy risk.
- No conversion history — no way to audit past conversions or reconcile `financial_status_get` balances against `financial_conversions` records.

This task is the **Stage 5 cross-balance mobility seam** that completes the multi-currency profile and unblocks `EP-02-16` payout planning across currencies.

---

## 3. Scope

| In Scope | Detail |
|---|---|
| `ConversionRemoteDataSource` abstract + `SupabaseConversionRemoteDataSource` | Injects `SupabaseClient`+`Dio`+`ApiExceptionMapper` via `BaseApiService` pattern (`lib/core/api/services/base_api_service.dart:15`). Methods: `convertCurrency({fromCurrency, toCurrency, amount, rate})` — via `supabase.rpc('financial_convert_currency')` envelope → `FinancialEnvelopeParser` + `DataExceptionMapper`. **No history-listing RPC exists** — history read via `financial_conversions` table `authenticated SELECT` RLS? (confirm at build: the table has an `authenticated select` policy `620`, but REST read requires the data-source policy; if a REST read is not permitted by the app's Supabase config, expose the seam as a future RPC — document decision) |
| Rate source seam | `ConversionRateSource` abstract (`lib/systems/finance/services/`) — `Future<double> rateFor({required String fromCurrency, required String toCurrency})`. `ConfigConversionRateSource` (default) — data-driven base rates from a single config/seed source, guarded (throws `ConversionRateUnavailableException` when a pair has no configured rate). No user-arbitrary rate path. Documented swap point for future provider feed / server RPC |
| Domain model | `CurrencyConversion` entity (`id, entityId, fromCurrency, toCurrency, fromAmount, toAmount, exchangeRate, fee, status, completedAt, createdAt`) — pure Dart, no DTO leakage. `ConversionPair` value object (validated from/to, precomputed display) |
| DTOs + mappers | `CurrencyConversionDto`, `ConversionPreviewDto` — DTO layer in `lib/data/models/`; mapper extensions in `lib/data/mappers/conversion_mapper.dart` |
| `ConversionRepository` | `getRate(from, to)`, `previewConversion({from, to, amount})`, `executeConversion({from, to, amount})`, `getHistory()`. Orchestrates `ConversionRemoteDataSource` + `ConversionRateSource`. Validates currencies against `SupportedCurrency`, `from != to`, `amount > 0`, rate `> 0` before RPC. Never writes `financial_balances`/`financial_conversions` directly |
| `ConversionService` facade (`lib/systems/finance/`) | Thin wrapper over `ConversionRepository`. Exposes `availablePairs`, `preview`, `execute`, `history`, rate + fee display helpers. Adds `HivorrLogger` + `PiiRedactor` redacted log (`entityId: ***last4`, amounts, pair). `PerformanceTracer` span `finance.conversion.preview.duration` / `finance.conversion.execute.duration` |
| `ConversionProvider` (`ChangeNotifier`) `lib/data/providers/conversion_provider.dart` | `fromCurrency`/`toCurrency`/`amount` selection state, `ConversionPreview? preview`, `List<CurrencyConversion> history`, `AsyncState loadState`, `bool converting`. `preview()`/`execute()`/`loadHistory()`. Mirrors `FinancialProvider` + `EscrowProvider` patterns with `WidgetsBindingObserver` lifecycle |
| UI screens + widgets | `ConversionScreen` (`GET /finance/convert`) — pair selector, amount input, `ConversionRateCard` (live rate), `ConversionPreviewCard` (gross → fees → net), confirm CTA, `ConversionResultCard` (post-execute). `ConversionHistoryList` — responsive via `shared/layouts/`, tokens via `AppTheme`/`AppThemeExtension` (`lib/app/theme/app_colors.dart:16`) |
| Barrel + DI | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` re-exports; factory `ConversionProvider.create(supabase: SupabaseClientProvider.client)` |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL / RLS / RPC creation, `financial_conversions` seed/trigger change, `supabase/config.toml` edit | `EP-02-04` frozen (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1-1764`); this task is `lib/` + `test/` only. `git diff --stat supabase/` must be `0` |
| Writing `financial_conversions` / `financial_balances` directly from client via REST | Server-authoritative — `financial_convert_currency` is the only conversion execution path; client reads history via seam only; no direct table INSERT/UPDATE from client `lib/` |
| **Server-side rate RPC / rate table creation** (e.g., `financial_conversion_rate_get`, a `financial_conversion_rates` table) | No such RPC/table exists in the frozen migration. This task defines the **client-side `ConversionRateSource` seam** (config-driven base rates) with a documented swap point; the server rate feed is deferred to a later financial-rate item / EP-02-16+ |
| **User-arbitrary exchange rates** | `EP-02:174` — conversion rules are server-side config-driven, never hardcoded or user-entered. The rate passed to `financial_convert_currency` originates from `ConversionRateSource` only |
| Live provider rate feed (Paystack/Flutterwave forex, external FX API) | Future integration owner; the seam isolates it — adding a provider requires only a new `ConversionRateSource` implementation, no repository/screen change |
| Cross-currency escrow funding, payout settlement in a converted currency | `EP-02-14` / `EP-02-16` — conversion here moves **available** balances between currencies; escrow/payout flows consume converted balances separately |
| Conversion of `held`/`pending` balances | `financial_convert_currency` operates on `available_balance` only `1530-1548`; `held`/`pending` are not convertible (frozen semantics) |
| Fee policy configuration (percent/flat, KYC-tier-based fees) | Server `v_fee := 0` `1479` is fixed in the frozen migration; client reflects `fee` from the RPC response and a config-driven display fee when present; dynamic fee policy is a future server change |
| Transaction/audit history rendering beyond conversion-scoped `financial_conversions` | The double-entry `financial_transactions` ledger is `EP-02-04` server-owned; client shows conversion-scoped history only |
| Dispute/name-matching integration | `EP-02-05` / `EP-02-16` own those; conversion history is read-only here |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/systems/finance/` vs `lib/data/` vs rate seam

`ARCHITECTURE.md:55-60,101-110,131-138` assigns `lib/core/` = platform, `lib/data/` = DTO/entity/repository/provider, `lib/systems/finance/` = financial business system, `lib/integrations/` = external adapters. Conversion follows the `EP-02-13`/`EP-02-14` split exactly: the **data layer** owns RPC transport + DTOs (reusable across `EP-02-16`), the **systems layer** owns rate-source seam, pair vocabulary, preview math, and UX orchestration.

No new top-level `lib/` directory. `lib/systems/finance/` is already populated by `EP-02-13/14`; new conversion files join `models/`, `screens/`, `services/`, `widgets/`, and the `lib/data/` subfolders.

### 5.2 Data Layer Contract

```dart
// lib/data/entities/currency_conversion.dart
class CurrencyConversion {
  final String id;
  final String entityId;
  final String fromCurrency;   // 'NGN','GHS','USD','GBP'
  final String toCurrency;
  final double fromAmount;
  final double toAmount;
  final double exchangeRate;
  final double fee;
  final String status;         // 'pending','completed','failed'
  final DateTime? completedAt;
  final DateTime createdAt;
}

// lib/data/entities/conversion_preview.dart
class ConversionPreview {
  final String fromCurrency;
  final String toCurrency;
  final double fromAmount;
  final double grossAmount;    // fromAmount * rate
  final double fee;
  final double toAmount;       // gross - fee
  final double exchangeRate;
}
```

Implementation `SupabaseConversionRemoteDataSource extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`) — constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`.

- `convertCurrency(...)` → `supabase.rpc<Map<String,dynamic>>('financial_convert_currency', params: {p_from_currency, p_to_currency, p_amount, p_rate})` → `FinancialEnvelopeParser.unwrap` → `CurrencyConversionDto.fromJson`. Confirms `status == 'completed'`.
- **History read seam:** there is no `financial_conversions_list` RPC in the frozen migration; `financial_conversions` has an `authenticated select` RLS policy `620`. The client must read conversion history through the `supabase.from('financial_conversions').select()` REST path — but the app's Supabase client may be restricted (EP-01 server-code / RLS posture may deny REST reads for financial tables; the table grants `561-562` allow authenticated select). **Decision gate at build:** whether the REST table query is permitted for the authenticated role in this Supabase project. If permitted → implement `getHistory()` via `supabase.from('financial_conversions').select().order('created_at', descending: true).eq('entity_id', ...)`; if not permitted → `getHistory()` is a seam returning `[]` with a documented future RPC swap point. **The plan's default is a REST-read datasource method gated by a `conversionHistoryRpcEnabled`/config check**, with the RPC path documented for future use. This keeps the marshalling and UI stable regardless of transport.

### 5.3 Rate Source Seam — `ConversionRateSource`

```dart
// lib/systems/finance/services/conversion_rate_source.dart
abstract class ConversionRateSource {
  /// Returns the current mid-market rate for converting up to a currency pair.
  /// `from`→`to`. Returns a positive double. Throws
  /// [ConversionRateUnavailableException] when the pair has no configured rate.
  Future<double> rateFor({
    required String fromCurrency,
    required String toCurrency,
  });
}
```

- `ConfigConversionRateSource` — default. Data-driven from a single, guarded config table (a `const Map<String, double>` of base cross-rates keyed by the sorted pair, or an injected function) seeded from the same values the server would use. **This is the single client rate authority.** It is never derived from user input.
- Rate direction correctness: `rateFor('GHS','NGN')` returns the rate that converts GHS→NGN (i.e., `toAmount = fromAmount * rate` as `financial_convert_currency:1515` computes). The inverse pair must be provided or computed only via a `double inverseRate` helper that is itself guarded (never divide where either rate is zero; throw `ConversionRateUnavailableException` on unsupported inverse rather than inventing a rate).
- `ConversionRateUnavailableException extends ApiException (kind: validation)` — surfaces "No conversion rate is currently available for this currency pair" — never a hardcoded/guess rate.
- **Documented swap point:** a future `ServerConversionRateSource` (calling a server rate RPC) or a `ProviderConversionRateSource` (external FX) replaces `ConfigConversionRateSource` via DI with no repository/screen change (`EP-02:406` provider-based rate feeds). The seam proves Open/Closed.

### 5.4 Repository — `ConversionRepository` (the unit-tested business contract)

```dart
abstract class ConversionRepository {
  Future<double> getRate({required String fromCurrency, required String toCurrency});
  Future<ConversionPreview> previewConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  });
  Future<CurrencyConversion> executeConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  });
  Future<List<CurrencyConversion>> getHistory();
}
```

`ConversionRepositoryImpl` (`lib/data/repositories/conversion_repository_impl.dart`):

1. `getRate` — validates `fromCurrency`/`toCurrency` in `SupportedCurrency`, `from != to`; delegates to `ConversionRateSource.rateFor`.
2. `previewConversion` — validates amount `> 0`, pair valid; fetches `rate` from `ConversionRateSource`; computes `gross = amount * rate`, `fee` from RPC-consistent source (default `0` matching `v_fee := 0`), `net = gross - fee`; returns `ConversionPreview`. **No RPC** — preview is pure local math against the trusted rate seam.
3. `executeConversion` — validates amount/pair/rate positive; fetches `rate` from `ConversionRateSource` (single source); calls `remote.convertCurrency(from, to, amount, rate)`; on success re-reads `financial_status_get` via `FinancialRepository` (injected) to refresh balances; returns mapped `CurrencyConversion`. **Prevents user-arbitrary rates.** Handles `PLT006 insufficient funds` (`1511-1513`).
4. `getHistory` — delegates to remote history seam; maps DTOs; empty list on no records.

Repository never imports `lib/systems/` widgets — unidirectional `data → systems`.

### 5.5 Systems Facade — `ConversionService` (`lib/systems/finance/`)

Thin wrapper used by `ConversionProvider` (ChangeNotifier) and future `EP-02-16` consumers:

- Exposes available pairs from `SupportedCurrency` — `availablePairs` (ordered, non-self pairs covering NGN↔GHS, NGN↔USD, NGN↔GBP, GHS↔USD, GHS↔GBP, USD↔GBP and inverses where rate exists).
- `previewConversion(from, to, amount)` / `executeConversion(from, to, amount)` / `getHistory()` → delegate to `ConversionRepository`.
- `ConversionPair` value object: `fromCurrency`, `toCurrency`, validated, `symbols` for display.
- `String formatPreview(ConversionPreview)` — locale-aware via `BalanceFormatter` (`lib/systems/finance/helpers/balance_formatter.dart` from `EP-02-13`): gross, fee, net each formatted with the destination currency symbol.
- Adds `HivorrLogger` + `PiiRedactor` redacted log (`entityId: ***last4`, `fromCurrency`, `toCurrency`, `fromAmount`, `toAmount`) — never `legal_name`. `PerformanceTracer` spans `finance.conversion.preview.duration` / `finance.conversion.execute.duration`.

### 5.6 State — `ConversionProvider` (`lib/data/providers/`)

```dart
class ConversionProvider extends ChangeNotifier {
  String? fromCurrency;
  String? toCurrency;
  double amount;
  ConversionPreview? preview;
  CurrencyConversion? lastConversion;
  List<CurrencyConversion> history;
  AsyncState loadState;
  bool converting;
  ApiException? lastError;

  Future<void> preview();        // recompute from current selection + amount
  Future<void> execute();        // execute + refresh balances (via FinancialProvider)
  Future<void> loadHistory();
  void setSource(String currencyCode);
  void setDestination(String currencyCode);
  void setAmount(double value);
}
```

- Constructor injection `({required ConversionRepository repo, required FinancialRepository financialRepo, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability (`provider:6.1.5`).
- Mirrors `FinancialProvider` (`lib/data/providers/financial_provider.dart:49`) + `EscrowProvider` patterns — `WidgetsBindingObserver` lifecycle, `pausePolling`/`resumePolling`, `_disposed` guard.
- `execute()` — sets `converting=true`, calls `repo.executeConversion`, then `financialRepo.getStatus()` refresh to update balances, emits one-shot `HivorrNotification` (`title: 'Currency converted'`, `body: '₦50,000.00 → $100.00'`, `actionRoute: '/finance/convert'`).
- No `SupabaseClientProvider` singleton inside provider — repository holds the client.

### 5.7 UI — `lib/systems/finance/screens/` + `widgets/`

- `ConversionScreen` (`GET /finance/convert`):
  1. `ConversionPairSelector` — source + destination pickers (only distinct pairs from `ConversionService.availablePairs`, self-pairs disallowed), each `DropdownButton`/custom `HivorrSelect`.
  2. Amount input — `HivorrTextField` numeric, validates `amount > 0`, currency-symbol prefix/suffix via `BalanceFormatter`.
  3. `ConversionRateCard` — live rate from `ConversionRateSource` (`1 NGN = 0.0007 USD`), fetched on pair change, `loading`/`unavailable` states.
  4. `ConversionPreviewCard` — gross → fee → **net** (`toAmount`) lines, net emphasized; "This is an estimate — the final amount is confirmed on execution."
  5. Confirm CTA `HivorrButton(variant: primary, isLoading: converting, isExpanded: true)` → `execute()`.
  6. `ConversionResultCard` — post-execute success with `toAmount` + `conversionId` reference + link to history.
- `ConversionHistoryList` — reverse-chronological conversion cards (pair, from/to amounts, rate, `completed`/`failed` status chip, date), `HivorrEmptyState` ("No conversions yet"), pull-to-refresh.

Responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp mobile / 24dp web. Branded primitives (`HivorrEmptyState`, `HivorrLoadingState`, `HivorrErrorState`, `HivorrSuccessState`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`).

### 5.8 Routing — `lib/app/router/`

Extend `AppRouter.create` (`lib/app/router/app_router.dart:17`) via `RoutePaths.convert = '/finance/convert'` and `RouteNames.convert`. Guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) — authenticated required; **taxonomy-independent but profile-dependent** (screen requires an existing `financial_profile`; route redirects to `/finance/create` when `profile == null`). No SEO public URL (private financial flow).

### 5.9 Config & Logging

- **`ConversionRateSource` config** — base cross-rates live in a single config/constant (`lib/config/` per repo convention) or injected at DI; never inline per-screen. No new secrets.
- Errors via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:15`) — `401→PLT001 auth`, `403→PLT002 forbidden`, `400/422→PLT003 validation`, `404→PLT004 notFound`, `409→PLT005 conflict`, `426 PLT006 insufficient funds` (extend mapper if `PLT006` maps to a distinct kind — confirm existing mapper), `5xx→PLT999 server`. `SupabaseConversionRemoteDataSource` rethrows normalized `ApiException`.
- `HivorrLogger` + `PiiRedactor` — log `entityId suffix`, pair, amounts; never `legal_name`, never raw account/bank data. `MonitoringService` spans `finance.conversion.execute` sampled.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `ConversionRemoteDataSource` abstract | `lib/data/datasources/remote/conversion_remote_data_source.dart` | **Create** — §5.2 |
| `SupabaseConversionRemoteDataSource` | `lib/data/datasources/remote/supabase_conversion_remote_data_source.dart` | **Create** — `BaseApiService` impl §5.2 (`financial_convert_currency` + history seam) |
| `CurrencyConversion` entity | `lib/data/entities/currency_conversion.dart` | **Create** — §5.2 |
| `ConversionPreview` entity | `lib/data/entities/conversion_preview.dart` | **Create** — §5.2 |
| `ConversionPair` value object | `lib/systems/finance/models/conversion_pair.dart` | **Create** — §5.5 |
| DTOs | `lib/data/models/currency_conversion_dto.dart`, `conversion_preview_dto.dart` | **Create** — §5.2 |
| Mappers | `lib/data/mappers/conversion_mapper.dart` | **Create** — `conversionToEntity`, `previewToEntity` |
| `ConversionRepository` abstract + impl | `lib/data/repositories/conversion_repository.dart` + `conversion_repository_impl.dart` | **Create** — §5.4 |
| `ConversionRateSource` abstract + `ConfigConversionRateSource` | `lib/systems/finance/services/conversion_rate_source.dart` | **Create** — §5.3 (seam) |
| `ConversionRateUnavailableException` | `lib/core/api/exceptions/` or `lib/data/datasources/remote/` (per repo exception placement) | **Create** — §5.3 |
| `ConversionProvider` (ChangeNotifier) | `lib/data/providers/conversion_provider.dart` | **Create** — §5.6 |
| `ConversionService` facade | `lib/systems/finance/services/conversion_service.dart` | **Create** — §5.5 |
| Screens | `lib/systems/finance/screens/conversion_screen.dart` | **Create** — §5.7 |
| Widgets | `lib/systems/finance/widgets/conversion_pair_selector.dart`, `conversion_rate_card.dart`, `conversion_preview_card.dart`, `conversion_result_card.dart`, `conversion_history_list.dart` | **Create** — §5.7 |
| Barrel | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` | **Update** — re-exports |
| Route extension | `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` | **Update** — add `convert` route, guard via `RouteGuard` |
| `FinancialEnvelopeParser` reuse | `lib/data/datasources/remote/financial_envelope_parser.dart` | **Reuse** — envelope unwrap |
| `BalanceFormatter` reuse | `lib/systems/finance/helpers/balance_formatter.dart` (EP-02-13) | **Reuse** — format amounts |
| `FinancialRepository` reuse | `lib/data/repositories/financial_repository.dart` (EP-02-13) | **Reuse** — post-execute `getStatus()` balance refresh |
| `SupportedCurrency` reuse | `lib/systems/finance/models/supported_currency.dart` (EP-02-13) | **Reuse** — pair vocabulary + validation |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — verify `git diff --stat supabase/` = 0 |
| Tests + fakes | `test/unit/data/finance/conversion_*`, `test/widget/systems/finance/conversion_*`, `test/support/fakes/fake_conversion_rate_source.dart` | **Create** — §14 |

No new `public.*` tables, no RPCs, no Edge Functions, no storage buckets.

## 7. Data Requirements

### 7.1 Conversion Records (write via `financial_convert_currency`; history read via seam)

`financial_conversions` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:355-382`): `entity_id uuid FK entities` `359` (self via `auth.uid()`), `from_currency`/`to_currency FK financial_supported_currencies` `361-364`, `from_amount numeric >0` `365`, `to_amount numeric >0` `366`, `exchange_rate numeric >0` `367`, `fee numeric >=0 default 0` `368`, `status in ('pending','completed','failed')` `369-370`, `completed_at timestamptz` `371`, `created_at`/`updated_at` `372-373`, `check (from_currency <> to_currency)` `375`. Indexed `financial_conversions_entity_idx (entity_id, created_at desc)` `381-382`. Client never writes this table directly — `financial_convert_currency` inserts it server-side `1550-1552` with `status='completed'`.

### 7.2 Conversion Result Payload

`financial_convert_currency` success envelope `1558-1561`: `data: {conversion_id, from_amount, to_amount, rate}` + `code PLT000`. Client maps to `CurrencyConversion` (`from_currency/from_amount`/`to_currency/to_amount`/`exchange_rate` known client-side; `fee=0` from `v_fee := 0` `1479`; `status='completed'`).

### 7.3 Source/Destination Balances (post-execution refresh)

`financial_balances` — `financial_convert_currency` decrements source `available_balance` `1540-1543` and increments destination `available_balance` `1545-1548` atomically under `FOR UPDATE`. Client refreshes via `financial_status_get` (EP-02-13 `FinancialRepository.getStatus`) to render up-to-date balances after execution. Client never writes balance columns.

### 7.4 Rate Source Data (config-driven, single source)

`ConfigConversionRateSource` base cross-rates: a guarded, data-driven `Map<String, double>` (e.g., seeded from a server/seed origin) covering the configured pairs. Direction: `rate = toAmount / fromAmount` per unit of `fromCurrency` (e.g., `1 USD = ₦1,500` → `rateFor('USD','NGN') == 1500`). Inverse pairs derived only via guarded `1/rate` where rate `> 0`, else `ConversionRateUnavailableException`. **This is the definitive client rate authority** — never user-entered.

### 7.5 Notification Payload (derived, not persisted)

`HivorrNotification{id: conversion.id.hashCode, title: 'Currency converted', body: '₦50,000.00 → $100.00 (0.0007 USD/NGN)', channel: system, priority: medium, actionRoute: '/finance/convert'}` — local notification only; no `supabase_realtime`.

## 8. Database Considerations

- **Zero DDL in this task.** `public.financial_conversions`, `public.financial_balances`, `public.financial_transactions`, `public.financial_audit_trail`, `public.financial_supported_currencies` all exist and are frozen (`supabase/migrations/20260829100004_financial_integrity_schema.sql`). No `ALTER`, `CREATE POLICY`, `GRANT`, index, trigger, or rate table added. Full pgTAP `001-017` + financial `013-014` suites must remain green.
- **RLS posture inherited:** `financial_conversions` `revoke all from anon, authenticated, service_role` `492-506` + narrow `grant select, insert to authenticated` `561-562` + `grant select, insert, update to service_role` `562`; RLS policies `financial_conversions_select` `620-621` (entity self) + `financial_conversions_insert` `622-623` (entity self). Balance/audit/transactions RLS inherited (`EP-02-04`).
- **Execution model respected:** `financial_convert_currency` `SECURITY INVOKER` `1468`, `VOLATILE` `1469`, self-scoped `v_actor=auth.uid()` `1472`, granted to `authenticated` + `service_role` `1686`. **Unlike escrow**, the authenticated client CAN invoke conversion directly — so no Edge Function proxy seam is required for this write (the rate, not the RPC, is the protected dimension, enforced via `ConversionRateSource`).
- **Atomic double-entry:** source decrement + destination increment + two `financial_transactions` ledger rows (conversion_debit `1526-1531`, conversion_credit `1533-1538`) all within the RPC's implicit transaction under `FOR UPDATE` locks `1510,1524` — no torn state, no client-side math required.
- **No service-role bypass in client:** adapters never hold `service_role` key; `SupabaseClientProvider.client` (`lib/core/api/supabase/supabase_client_provider.dart:19`) uses `anon`/`authenticated` role with RLS. `grep -r "service_role" lib/systems/finance lib/data` must be `0`.
- **History read gate:** `financial_conversions` REST select (policy `620`) — the app's Supabase REST read for this table is gated by a config/decision at build (see §5.2); if read is disallowed under the authenticated scope for financial tables in this project, `getHistory()` degrades to `[]` with a documented future RPC swap. It does not bypass RLS.
- **Audit:** `financial_audit_trail conversion_executed` `1554-1556` is written server-side by `financial_convert_currency`; client never inserts audit rows.

## 9. API Requirements

### 9.1 Supabase RPC (via `SupabaseConversionRemoteDataSource`)

| Operation | RPC | Params | Auth | Success Envelope | Error → ApiExceptionKind |
|---|---|---|---|---|---|
| Convert currency | `financial_convert_currency` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1459`) | `p_from_currency char(3)`, `p_to_currency char(3)`, `p_amount numeric`, `p_rate numeric` | `authenticated` self-scoped | `200 {success:true, code:PLT000, data:{conversion_id, from_amount, to_amount, rate}}` | `401 PLT001 auth`, `400/422 PLT003 validation` (unsupported pair / `from==to` / `amount<=0` / `rate<=0`), `404 PLT004 notFound` (no profile), `PLT006 insufficient funds`, `5xx PLT999` |

`supabase.rpc<Map<String,dynamic>>('financial_convert_currency', params: {p_from_currency, p_to_currency, p_amount, p_rate})` — unwrapped via `FinancialEnvelopeParser` `lib/data/datasources/remote/financial_envelope_parser.dart` (checks `success==true && code=='PLT000'`).

### 9.2 Conversion History Read (seam)

| Operation | Transport | Status | Notes |
|---|---|---|---|
| `getHistory()` | `supabase.from('financial_conversions').select().eq('entity_id',...).order('created_at', descending:true)` OR future `financial_conversions_list` RPC | Config-gated (see §5.2) | Returns `[]` when read seam disabled; RPC swap point documented. Never writes |

### 9.3 No Storage / No Edge Functions

No `Supabase Storage` REST (conversion is RPC-driven, no upload). No Edge Function. No live payment-provider SDK calls — the rate seam is client-side config-driven with a provider swap point, but the RPC itself is directly executable by the authenticated client.

### 9.4 Error Contract

Every public method throws only `ApiException` (`api_exception.dart:6-66` kinds) or `DataException` — never raw `Supabase`/`DioException`. `BaseApiService.invoke` normalizes `DioException` via `ApiExceptionMapper.map`. `ConversionRateUnavailableException` is an `ApiException` subclass (`kind: validation`) signaling "no rate available for pair" — distinct from a server `PLT003` so UI can show the rate-unavailable state rather than a generic validation error. Confirm `PLT006 insufficient funds` maps to an appropriate kind in the existing mapper (or add the mapping client-side — no server change).

## 10. User Interface Requirements

**Widgets introduce UI — `AGENT.md:17` Rule 5 applies (all `AppTheme` tokens `documents/Context/VISUAL-IDENTITY.md:176-190`).** Every widget in this task must:

- Source colors from `Theme.of(context).colorScheme` / `AppThemeExtension` (`lib/app/theme/app_colors.dart:16`, `lib/app/theme/app_theme_extension.dart`) — never `Colors.*` or `Color(0xFF...)` inline (hex lives only in `AppColors`).
- Source type via `Theme.of(context).textTheme` — never `TextStyle(fontFamily: 'Inter')` (delegated to `lib/app/theme/app_text_theme.dart`).
- Source spacing/radius/elevation/motion via `AppThemeExtension.spacing`/`radiusSm`/`radiusMd`/`elevation`/`duration` (`VISUAL-IDENTITY.md:219-235`).
- Handle 4 states via branded primitives (`lib/shared/widgets/hivorr_empty_state.dart`, `hivorr_loading_state.dart`, `hivorr_error_state.dart`, `hivorr_success_state.dart`) wrapping `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), not bare `CircularProgressIndicator`.

| Screen/Widget | Route | Purpose | Key Elements |
|---|---|---|---|
| `ConversionScreen` | `GET /finance/convert` | Pair + amount + rate + preview + confirm + result | `AppBar(title: Text('Convert Currency', style: textTheme.titleLarge))`, `ConversionPairSelector` (source/dest, self-pairs disallowed), `HivorrTextField` amount (`required`, `>0`, currency symbol), `ConversionRateCard` (live rate full + inverse), `ConversionPreviewCard` (gross/fee/net, net emphasized), `HivorrButton(variant: primary, isLoading: converting, isExpanded: true)` confirm, `ConversionResultCard` on success |

| `ConversionHistoryList` | (embedded) | Conversion history | Reverse-chronological cards (pair, from→to amounts, rate, status chip `completed successContainer`/`failed errorContainer`, date), `HivorrEmptyState` "No conversions yet", pull-to-refresh |

| `ConversionPairSelector` | — | Source/destination pickers | Dropdowns over `ConversionService.availablePairs`, distinct from/to enforced, symbols `₦/₵/$/£` via `SupportedCurrency` |

| `ConversionRateCard` | — | Live rate display | `1 NGN = 0.0007 USD` + inverse; loading state `HivorrLoadingState`; unavailable state `HivorrErrorState` with "rate unavailable for this pair" |

| `ConversionPreviewCard` | — | Estimate breakdown | Gross → fee → **net**, net = `toAmount` (`textTheme.titleMedium` `colorScheme.primary`), card `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` 16dp, "estimate — confirmed on execution" `labelSmall` |

| `ConversionResultCard` | — | Post-execute success | `toAmount` emphasized + `conversionId` reference + "View history" action; `HivorrSuccessState` wrap |

All screens responsive via `ResponsiveScaffold` / `shared/layouts/` (`ARCHITECTURE.md:122-124`) — 16dp mobile / 24dp web. Amounts always rendered via `BalanceFormatter` (`EP-02-13`) — never raw `double.toString()`.

## 11. User Experience Considerations

- **Trust the rate before the move:** The primary UX is a preview that shows gross → fee → **net** (`toAmount`) before any funds move, with explicit "estimate — confirmed on execution" copy. The user never commits to an unknown effective rate (`EP-02:406` conversion preview with fees).
- **Rate transparency:** `ConversionRateCard` shows both `1 from = X to` and `1 to = Y from` so a user converting either direction understands the spread; source is labeled ("platform rate", not raw provider rate) with an "updated at" timestamp when available.
- **Single-rate authority:** The rate shown in `ConversionRateCard` is exactly the rate passed to `financial_convert_currency` — no drift between preview and execution (both read from the same `ConversionRateSource`). If the rate changes between preview and confirm, the confirm step re-pulls and re-renders the net before final execution.
- **Fail-fast validation:** Pair distinctness (`from != to`) and `amount > 0` validated client-side before any RPC — no `PLT003`/`PLT006` round-trip for known violations. Insufficient funds (`PLT006`) surfaces inline "Insufficient [from] balance" with a link to the finance screen.
- **No arbitrary rates:** The UI has no "enter rate" field — the user only picks a pair and amount; the platform supplies the rate. This reinforces `AGENT.md:7` (no client-side financial rules) and `EP-02:174`.
- **History as a trust record:** `ConversionHistoryList` gives a reconcilable record of every conversion against `financial_status_get` balances — mismatches are visible and auditable.
- **Profile gate:** `GET /finance/convert` requires an existing financial profile; redirects to `/finance/create` when `profile == null` (prevents `PLT004` not-found on the RPC).

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| **Server-authoritative balance mutation** `AGENT.md:16` Rule 4 | Client never writes `financial_balances.*` or `financial_conversions.*` directly — `financial_convert_currency` performs source decrement + destination increment + ledger + audit atomically under `FOR UPDATE` locks `1510,1524`. Client only reads balances via `financial_status_get` (EP-02-13) after execution. RLS grants `561-562` allow authenticated select/insert only within RPC semantics — no direct client `UPDATE` path. |
| **Rate integrity — the core security dimension** | `financial_convert_currency` accepts `p_rate` as an input; therefore the client **must not** accept a user-entered rate. All rates originate from `ConversionRateSource` (config-driven, domain-controlled). This is the single most important security control in this task — a client that lets a user set the rate could move funds at a manipulated price. The rate seam is the enforced boundary; `grep` lens proves no path supplies a rate not derived from `ConversionRateSource`. |
| **No `service_role` leak** | No `service_role` import in client data/systems; rate seam + RPC both operate under `authenticated` RLS scope. `grep lib/systems/finance lib/data "service_role"` = 0. |
| **PII exposure** | Conversion screens/logs render `entityId` suffix only; amounts are non-PII; `HivorrLogger` + `PiiRedactor` mask `entityId ***last4`, never log `legal_name`, never raw account/bank data, never the full history if it embeds contract terms. |
| **Rounding/precision** | `financial_convert_currency` computes `to_amount = amount * rate - fee` `1515` in `numeric` server-side; client preview uses `double` for display only. The authoritative `to_amount` comes from the RPC response `1558-1561`; client never displays a hand-computed amount as authoritative after execution. |
| **Insufficient-funds race** | `financial_convert_currency` locks the source balance `FOR UPDATE` `1507-1510` and checks `available_balance < amount` `1511-1513` (`PLT006`) — two concurrent conversions cannot double-spend. Client surfaces `PLT006` inline; no optimistic local balance decrement. |
| **Auth state isolation** | `AppEnvironment` `Development→Staging→Production` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); conversion across environments via migration + RPC, no cross-env read. |
| **Rounding precision in rate** | `exchange_rate numeric >0` `367`; client passes the rate from `ConversionRateSource` as a numeric; a malformed/negative/zero rate is rejected before RPC (`rate > 0` `PLT003` `1498`) and never user-derivable. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| **RPC cost** | One `financial_convert_currency` per execution, `VOLATILE` `1469` (necessary — mutates state) with source balance indexed (`financial_balances_entity_currency_key`). **Preview costs zero RPCs** — pure local math against the trusted rate seam. `financial_status_get` re-read after execution is one `STABLE` RPC `1569`. |
| **Rate seam cost** | `ConfigConversionRateSource.rateFor` is a guarded `Map` lookup `O(1)` — microseconds; no network. Live provider feed (future) would be async + cached; the seam isolates that. |
| **Preview math** | `amount * rate` with `double` — `O(1)`, local, no network; reuse `BalanceFormatter` for formatting. |
| **History** | Reverse-chronological list from `financial_conversions_entity_idx` `381-382` (indexed `entity_id, created_at desc`) — indexed read, no full scan; paginate/limit if needed (default limit documented). |
| **Lifecycle pause/resume** | `WidgetsBindingObserver` pauses `ConversionProvider` polling/refresh on background, resumes on foreground — no wasted preview/status RPCs while app backgrounded on slow networks. |
| **No polling storm** | `ConversionProvider` refreshes rate on pair change and status on execution only — no `Timer.periodic` while idle; no redundant RPCs per keystroke (debounced/preview-on-validate). |
| **Tracer overhead** | `PerformanceTracer` span (`lib/core/monitoring/performance_tracer.dart:1`) around `preview`/`execute`, sampled via `MonitoringConfig`, tags `finance.conversion.pair`, no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/data/finance/` + `test/unit/systems/finance/`

Pattern mirrors the EP-02-13/14 suites + `test/support/fakes/fake_supabase.dart` + `fake_conversion_rate_source.dart` — no live Supabase.

| File | Cases (min) | Method |
|---|---|---|
| `conversion_remote_data_source_test.dart` | 12 | Mock `SupabaseClient.rpc`: `financial_convert_currency → {success:true, code:PLT000, data:{conversion_id, from_amount, to_amount, rate}}` success; `amount<=0 → PLT003 validation`; `from==to → PLT003`; `unsupported currency → PLT003`; `no profile → PLT004 notFound`; `insufficient funds → PLT006`; `401 PLT001 auth`, `5xx PLT999`; history seam when disabled → `[]`; history seam enabled → maps rows |
| `conversion_repository_test.dart` | 14 | Fake datasource + fake `ConversionRateSource`. `getRate('NGN','USD')` returns positive rate; `getRate` unsupported/self-pair throws validation before RPC; `previewConversion` computes gross/fee/net locally, no RPC; `preview` amount<=0 throws; `executeConversion` pulls rate from seam, passes EXACT rate param to RPC (spy), maps result, re-reads `financial_status_get`; `execute` with rate>0 required; `PLT006` surfaces insufficient; `getHistory` returns list/[]; rate unavailable → `ConversionRateUnavailableException` |
| `conversion_provider_test.dart` | 12 | `ChangeNotifier` mock repo: `setSource/setDestination/setAmount` update state + `notifyListeners`; `preview()` recomputes; `execute()` sets `converting`, on success updates `lastConversion` + refreshes financial status + fires `HivorrNotification`; lifecycle `pausePolling`/`resumePolling`; error surfaces `lastError.message`; `_disposed` guard |
| `conversion_mapper_test.dart` | 10 | `CurrencyConversionDto.fromJson → CurrencyConversion` mapping `conversion_id, from_amount, to_amount, exchange_rate, fee, status`; `ConversionPreviewDto.fromJson → ConversionPreview`; null `completed_at` → null; status passthrough; fee default 0 |
| `conversion_service_test.dart` | 10 | `availablePairs.length == 12` (6 ordered + 6 inverses where rate exists); pair distinct; `previewConversion` delegates; `formatPreview` locale-aware via `BalanceFormatter`; rate-unavailable surfaces distinct message; `ConversionPair` validation |
| `config_conversion_rate_source_test.dart` | 10 | `rateFor('USD','NGN')` returns configured value `> 0`; inverse derived `1/rate` guarded; unsupported pair throws `ConversionRateUnavailableException`; zero/negative guard never returns a rate; single-source authority — no hardcoded inline rate in screens |
| `balance_refresh_after_conversion_test.dart` | 4 | Post-execute `financial_status_get` refresh updates balances map via injected `FinancialRepository` |

Target **≥72 unit assertions**; repository/provider ≥90%, mappers/service/rate-source 100%.

### 14.2 Widget Suite — `test/widget/systems/finance/`

| File | Cases (min) | Method |
|---|---|---|
| `conversion_screen_test.dart` | 14 | Pump with `Provider<ConversionProvider>` fake + `MaterialApp AppTheme.light` (`lib/app/theme/app_theme.dart:1`): pair selector disallows self-pair; amount input validates `>0`; `ConversionRateCard` renders `1 NGN = 0.0007 USD`; `ConversionPreviewCard` shows gross/fee/net with net `textTheme.titleMedium` `colorScheme.primary`; confirm `HivorrButton` visible, tap shows `HivorrLoader`; `ConversionResultCard` on success shows `toAmount` + reference; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily`), spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:220`); `grep Colors.` assert `0` |
| `conversion_rate_card_test.dart` | 8 | Rate + inverse displayed; loading state `HivorrLoadingState`; unavailable state `HivorrErrorState` with "rate unavailable"; no hardcoded hex |
| `conversion_preview_card_test.dart` | 8 | Gross/fee/net lines formatted via `BalanceFormatter` (`₦50,000.00 → $100.00`); net emphasized `colorScheme.primary`; "estimate" microcopy `labelSmall`; semantics |
| `conversion_history_list_test.dart` | 8 | Cards render pair + amounts + status chip (`completed successContainer`/`failed errorContainer`); empty → `HivorrEmptyState` "No conversions yet"; pull-to-refresh invokes provider `loadHistory` |

Widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` + `find.byType(HivorrButton)`.

### 14.3 Integration (Fake-E2E) — `test/integration/finance/conversion_flow_test.dart`

Single integration-compose test without live Supabase: fake `SupabaseClient.rpc` map + fake `ConversionRateSource` + real `ConversionRepositoryImpl` + real `FinancialRepositoryImpl` (fake datasource). Flow: `getRate('NGN','USD')` → `rate == 0.0007` → `previewConversion(from:'NGN', to:'USD', amount:50000)` → `preview.net == 50000 * 0.0007` (gross 35, fee 0) → `executeConversion(from:'NGN', to:'USD', amount:50000)` → mock `financial_convert_currency → {conversion_id, from_amount:50000, to_amount:35, rate:0.0007}` → mapped `CurrencyConversion.status == 'completed'` → `financial_status_get` refresh → balances reflect updated NGN + USD. No `supabase start` needed; live `supabase db test` is RLS truth.

### 14.4 Regression Guard

`flutter analyze` + `flutter test --coverage` (domain ≥80%) + `supabase db test` full suite `001..017` + financial `013-014` green. Lens `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/finance` = 0, `grep -r "service_role" lib/` = 0, **rate-integrity lens** `grep -rn "financial_convert_currency" lib/` — every call site passes a rate obtained from `ConversionRateSource` (no literal/constant rate inlined at call sites), `git diff --stat supabase/` = 0.

### 14.5 Lens Summary

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` RLS/posture. Add `test/support/fakes/fake_conversion_rate_source.dart` (+ `fake_conversion_remote_data_source.dart` if the normal fake pattern requires it). Static grep lens proves the client never supplies a user-arbitrary rate and holds no `service_role` key.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `supabase/migrations/20260829100004_financial_integrity_schema.sql:355-382,1459-1563,1686,1731`, `lib/data/providers/financial_provider.dart:49`, `lib/data/repositories/financial_repository.dart`, `lib/systems/finance/models/supported_currency.dart`, `lib/systems/finance/helpers/balance_formatter.dart`, `lib/data/datasources/remote/financial_envelope_parser.dart`, `lib/core/api/services/base_api_service.dart:15`, config convention for rates/flags | Baseline |
| 2 | Create `lib/data/entities/currency_conversion.dart` — `CurrencyConversion{id, entityId, fromCurrency, toCurrency, fromAmount, toAmount, exchangeRate, fee, status, completedAt?, createdAt}` entity | Entity |
| 3 | Create `lib/data/entities/conversion_preview.dart` — `ConversionPreview{fromCurrency, toCurrency, fromAmount, grossAmount, fee, toAmount, exchangeRate}` entity | Entity |
| 4 | Create `lib/data/models/currency_conversion_dto.dart`, `conversion_preview_dto.dart` — JSON serialization DTOs matching `financial_convert_currency` response + history row shapes | DTOs |
| 5 | Create `lib/data/mappers/conversion_mapper.dart` — `conversionToEntity`, `previewToEntity` extension methods | Mappers |
| 6 | Create `lib/systems/finance/models/conversion_pair.dart` — `ConversionPair{fromCurrency, toCurrency}` validated value object | Pair vocab |
| 7 | Create `lib/systems/finance/services/conversion_rate_source.dart` — abstract `ConversionRateSource` + `ConfigConversionRateSource` + `ConversionRateUnavailableException` | Rate seam |
| 8 | Create `lib/data/datasources/remote/conversion_remote_data_source.dart` — abstract `ConversionRemoteDataSource` (§5.2: `convertCurrency`, `getHistory`) | Contract |
| 9 | Create `lib/data/datasources/remote/supabase_conversion_remote_data_source.dart` — `BaseApiService` impl: `financial_convert_currency` via envelope parser; history seam (REST gate/config) | Remote |
| 10 | Create `lib/data/repositories/conversion_repository.dart` abstract + `lib/data/repositories/conversion_repository_impl.dart` — §5.4 `getRate/preview/execute/getHistory`; rate from seam, never user-arbitrary; post-execute status refresh | Repository |
| 11 | Create `lib/systems/finance/services/conversion_service.dart` — facade §5.5: `availablePairs`, `preview`, `execute`, `history`, `formatPreview` | Service |
| 12 | Create `lib/system/finance` helpers: reuse `BalanceFormatter`; add `formatPreview` pure helper | Helper |
| 13 | Create `lib/data/providers/conversion_provider.dart` — `ChangeNotifier` §5.6 (mirrors `FinancialProvider` `lib/data/providers/financial_provider.dart:49` lifecycle + `EscrowProvider`) | Provider |
| 14 | Create widgets `lib/systems/finance/widgets/conversion_pair_selector.dart`, `conversion_rate_card.dart`, `conversion_preview_card.dart`, `conversion_result_card.dart`, `conversion_history_list.dart` — `AppTheme` tokens only | Widgets |
| 15 | Create screen `lib/systems/finance/screens/conversion_screen.dart` — §5.7 responsive, branded states, rate/preview/confirm/result | Screen |
| 16 | Update barrels `lib/systems/finance/finance.dart:1`, `lib/data/data_layer.dart:1` | Barrels |
| 17 | Update `lib/app/router/route_paths.dart`, `route_names.dart`, `app_router.dart:17` — add `convert='/finance/convert'` route guarded by `RouteGuard` (authenticated + profile gate) | Routes |
| 18 | Create `test/support/fakes/fake_conversion_rate_source.dart` + `test/support/fakes/fake_conversion_remote_data_source.dart` (+ `fake_conversion_repository.dart` if needed) | Test infra |
| 19 | Create `test/unit/data/finance/conversion_remote_data_source_test.dart` (12) + `conversion_repository_test.dart` (14) + `conversion_mapper_test.dart` (10) + `conversion_service_test.dart` (10) + `config_conversion_rate_source_test.dart` (10) + `balance_refresh_after_conversion_test.dart` (4) | Tests 1 |
| 20 | Create `test/unit/data/providers/conversion_provider_test.dart` (12) | Tests 2 |
| 21 | Create `test/widget/systems/finance/conversion_screen_test.dart` (14) + `conversion_rate_card_test.dart` (8) + `conversion_preview_card_test.dart` (8) + `conversion_history_list_test.dart` (8) | Tests 3 |
| 22 | Create `test/integration/finance/conversion_flow_test.dart` — fake-E2E rate → preview → execute → status refresh | Integration |
| 23 | `flutter analyze` + `flutter test --coverage` (≥72 assertions green, repository ≥90%, mapper/service/rate-source 100%) | Verify |
| 24 | `supabase db test` full suite `001..017` + `013-014` green + grep lenses: `Colors.\|Color(0x` = 0, `service_role` in `lib/systems/finance lib/data` = 0, rate-integrity lens (rates from `ConversionRateSource`), `git diff --stat supabase/` = 0 | Regression |
| 25 | Doc pass: dartdoc on `CurrencyConversion`, `ConversionPreview`, `ConversionRateSource` (seam + swap point), `ConversionRepository` contract, `ConversionService`, `ConversionPair` | Docs |
| 26 | Tag `EP-02-16` unblocked; phase plan `EP-02-15` → `Completed` candidate pending review; hand the rate-source swap-point contract to the future server-rate owner | Handoff |

## 16. Expected Outcome

- `lib/data/` exposes a single seam for conversion state: `ConversionRepository` fetches the trusted rate from `ConversionRateSource`, previews locally (zero RPC), executes through `financial_convert_currency` with the RPC-supplied rate, and reads history via the configured seam — mapping to pure `CurrencyConversion`/`ConversionPreview`/`Currency` entities. **No user-arbitrary rate ever reaches the RPC.**
- `lib/systems/finance/` provides the **rate-source seam** (`ConversionRateSource` abstract + `ConfigConversionRateSource`) — data-driven, guarded, with a documented swap point for a future provider/server rate feed (`EP-02:406`, `EP-02:174` config-driven not hardcoded). `ConversionPair` vocabulary is data-driven from `SupportedCurrency`; preview math is pure and local.
- `ConversionProvider` (`ChangeNotifier`) owns pair/amount/preview/history state, post-execution `financial_status_get` balance refresh, `WidgetsBindingObserver` lifecycle, and a one-shot `HivorrNotification` — mirroring the proven `FinancialProvider` (`lib/data/providers/financial_provider.dart:49`) pattern with no `supabase_realtime`.
- `ConversionScreen` renders pair selector, live rate card, preview (gross→fee→net), confirm, and result with **zero hardcoded `Colors.*`/hex/`fontFamily`** — all `colorScheme.*`/`textTheme.*`/`AppThemeExtension` tokens (`VISUAL-IDENTITY.md:176-190,219-235`), responsive via `shared/layouts/` (16dp mobile / 24dp web), branded states.
- Unit suite ≥72 assertions green with mocked `SupabaseClient`/`Dio`; `flutter analyze` clean; full pgTAP `001-017` + financial `013-014` green; grep lenses prove no `service_role`, no hardcoded color/font leakage, and rate-integrity (no user-set rate); `git diff --stat supabase/` = 0.
- `EP-02-16` (payouts, deposit verification) unblocked — converted balances are visible via `financial_status_get`, and the conversion seam provides typed entities + rate source for cross-currency payout planning.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/data/entities/currency_conversion.dart` exists — `CurrencyConversion{id, entityId, fromCurrency, toCurrency, fromAmount, toAmount, exchangeRate, fee, status, completedAt?, createdAt}` | File inspection |
| 2 | `lib/data/entities/conversion_preview.dart` exists — `ConversionPreview{fromCurrency, toCurrency, fromAmount, grossAmount, fee, toAmount, exchangeRate}` | File inspection |
| 3 | `lib/systems/finance/models/conversion_pair.dart` exists — validated `ConversionPair{fromCurrency, toCurrency}`, self-pair disallowed | File + unit test |
| 4 | `lib/data/datasources/remote/conversion_remote_data_source.dart` exists — abstract `ConversionRemoteDataSource` with `convertCurrency`, `getHistory` | File inspection |
| 5 | `lib/data/datasources/remote/supabase_conversion_remote_data_source.dart` implements it — `extends BaseApiService`, `supabase.rpc('financial_convert_currency', params: {...})`, `FinancialEnvelopeParser` unwrap, `DataExceptionMapper`; history seam | File + unit test |
| 6 | `lib/data/mappers/conversion_mapper.dart` defines `conversionToEntity`, `previewToEntity` — maps DTOs to entities, null → defaults | Unit test |
| 7 | `lib/data/repositories/conversion_repository.dart` + `_impl.dart` define `ConversionRepository{getRate, previewConversion, executeConversion, getHistory}` — rate from seam, never user-arbitrary; validates pair/amount/rate before RPC; post-execute status refresh; never writes `financial_balances`/`financial_conversions` directly | Unit test + rate-integrity lens |
| 8 | `lib/systems/finance/services/conversion_rate_source.dart` defines abstract `ConversionRateSource` + `ConfigConversionRateSource` + `ConversionRateUnavailableException` — guarded, data-driven, documented swap point | File + unit test (100%) |
| 9 | `lib/systems/finance/services/conversion_service.dart` facade exposes `availablePairs`, `preview`, `execute`, `history`, `formatPreview` | File + unit test |
| 10 | `lib/data/providers/conversion_provider.dart` exists — `ChangeNotifier` with pair/amount/preview/lastConversion/history/loadState/converting, `preview()`/`execute()`/`loadHistory()`, `pausePolling`/`resumePolling`, `dispose` — mirrors `lib/data/providers/financial_provider.dart:49` | Unit test |
| 11 | `lib/systems/finance/screens/conversion_screen.dart` exists — `GET /finance/convert`, pair selector + amount + rate + preview + confirm + result, `AppTheme` tokens only, responsive | Widget test |
| 12 | `lib/systems/finance/widgets/conversion_pair_selector.dart` / `conversion_rate_card.dart` / `conversion_preview_card.dart` / `conversion_result_card.dart` / `conversion_history_list.dart` exist — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp (`VISUAL-IDENTITY.md:221`) | Widget test |
| 13 | `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` barrels re-export new symbols | File inspection |
| 14 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `convert='/finance/convert'` guarded by `RouteGuard` (authenticated + profile gate) | File + `go_router` smoke |
| 15 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` |
| 16 | No `lib/integrations/payment_gateways/*` mutation | `git diff --stat` |
| 17 | No `service_role`/secret leakage — `grep -r "service_role" lib/systems/finance lib/data/finance` = 0 | `grep` |
| 18 | Rate-integrity: every `financial_convert_currency` call site supplies a rate from `ConversionRateSource` — no inline literal/constant/user rate; `grep -rn "financial_convert_currency" lib/` reviewed | `grep` + code review |
| 19 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/finance` = 0 | `grep` |
| 20 | `test/unit/data/finance/conversion_remote_data_source_test.dart` ≥12 cases green (RPC envelope, `PLT001/003/004/006/999`, history seam) | `flutter test` |
| 21 | `test/unit/data/finance/conversion_repository_test.dart` ≥14 + `conversion_mapper_test.dart` ≥10 + `conversion_service_test.dart` ≥10 + `config_conversion_rate_source_test.dart` ≥10 + `balance_refresh_after_conversion_test.dart` ≥4 green | `flutter test` |
| 22 | `test/unit/data/providers/conversion_provider_test.dart` ≥12 green (pair selection, preview, execute + refresh + notification, lifecycle) | `flutter test` |
| 23 | `test/widget/systems/finance/conversion_screen_test.dart` ≥14 + `conversion_rate_card_test.dart` ≥8 + `conversion_preview_card_test.dart` ≥8 + `conversion_history_list_test.dart` ≥8 green, token + layout asserts | `flutter test` |
| 24 | `test/integration/finance/conversion_flow_test.dart` fake-E2E green: rate → preview → execute → status refresh | `flutter test` |
| 25 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI |
| 26 | `supabase db test` full suite `001-017` + financial `013-014` green — no RLS/role regression | `supabase db test` |
| 27 | `flutter test` total **≥72 unit assertions** green; `ConversionRateSource` 100%, mappers 100%, `ConversionProvider` ≥90% | `flutter test` |

---

## Recommended Implementation AI Execution Profile

**Recommended Coding Reasoning Level:** **Very High**

**Reasoning Level Justification:**

| Dimension | Assessment | Rationale |
|---|---|---|
| Technical complexity | High | One live RPC (`financial_convert_currency`) + entity/DTO/mapper chain + `ChangeNotifier` provider — follows proven `EP-02-13`/`EP-02-14` patterns. Elevated by the **rate-source seam** (`ConversionRateSource` + `ConfigConversionRateSource` + `ConversionRateUnavailableException`) with a documented swap point, preview-vs-execute rate-consistency correctness, and the history seam whose transport (REST vs future RPC) is a build-time decision gate. Below server schema work but above plain CRUD. |
| Business impact | Very High | Conversion is the cross-balance mobility that completes the multi-currency profile (`EP-02:405-410`). Broken preview (wrong `toAmount`), executed-rate drift, or history/balance mismatch directly undermines trust in every financial screen. No money is "created" in conversion (it moves between the entity's own balances), but incorrect net-amount display or a manipulated rate path is a visible product-level financial integrity breach. |
| Security risk | High | The **rate dimension is the security anchor**: `financial_convert_currency` accepts `p_rate` as a caller-supplied input, so a user-arbitrary rate path would let a user convert at a self-favorable price. The rate must originate exclusively from `ConversionRateSource` — the rate-integrity lens and `grep` guard are the enforcement. Balances themselves are server-authoritative under `FOR UPDATE` (`PLT006` guards double-spend); client never writes `financial_conversions`/`financial_balances`. RLS is inherited; no `service_role` in client. |
| Performance sensitivity | Medium | Preview = zero RPCs (pure local `O(1)` math); execute = 1 `VOLATILE` RPC + 1 `STABLE` `financial_status_get` refresh; rate seam = `O(1)` map lookup. Lifecycle pause/resume avoids wasted RPCs on slow networks. No polling storm. |
| Data complexity | Medium | `CurrencyConversion`/`ConversionPreview`/`ConversionPair` entities + DTO mapping + guarded rate map + `from_amount >0/to_amount >0/exchange_rate >0` invariants — reuse of `FinancialEnvelopeParser` and `BalanceFormatter` keeps the surface narrow; no ledger double-entry in the client. |
| Integration complexity | High | Consumes the frozen `financial_convert_currency` RPC + `financial_conversions` table; reuses `FinancialRepository` (post-execute status refresh) and `SupportedCurrency`/`BalanceFormatter` from `EP-02-13`; defines the **rate-source swap point** for future server/provider rate feeds (`EP-02:406`, `EP-02:174`) that must not require repository/screen changes. History transport is a documented decision gate. Unblocks `EP-02-16` cross-currency payout planning. |

Overall this task introduces a **security-sensitive rate seam** (`AGENT.md:16` Rule 4 server-authoritative balances + `EP-02:174` config-driven rates) around a directly-executable RPC — **Very High** reasoning ensures the rate can never be user-arbitrary (rate-integrity lens), preview and executed net are identical to the RPC's `to_amount`, the rate-source seam stays Open/Closed for a future provider, and post-execution balance refresh keeps every financial screen consistent.
