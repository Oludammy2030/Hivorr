# Definition of Done — EP-02-13: Multi-Currency Financial Profile System

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-13 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-13-Multi-Currency Financial Profile System.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-13 |
| **Task Name** | Multi-Currency Financial Profile System |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 5 — Financial Integrity Systems |
| **Priority** | Critical |
| **Dependencies** | EP-02-04 (Financial Schema — `financial_profiles` `financial_currency_accounts` `financial_balances` `financial_supported_currencies` + RPCs `financial_profile_create` `financial_profile_get` `financial_balance_get` `financial_status_get` `supabase/migrations/20260829100004_financial_integrity_schema.sql:37-146,635-754,1566-1618`), EP-02-09 (Payment Gateway Abstraction — `PaymentGatewayFactory.resolveForCurrency` read-only hint `lib/integrations/payment_gateways/payment_gateway_factory.dart`) |
| **Blocks** | EP-02-14 (Escrow & Milestone), EP-02-15 (Currency Conversion), EP-02-16 (Payouts & Deposit Verification) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-13-Multi-Currency Financial Profile System.md` |

> Frozen server refs (reused, never modified): `supabase/migrations/20260829100004_financial_integrity_schema.sql:37-62` (4-currency seed NGN/GHS/USD/GBP), `67-78` (financial_profiles), `89-115` (financial_currency_accounts), `120-146` (financial_balances), `635-680` (financial_profile_create), `683-714` (financial_profile_get), `717-754` (financial_balance_get), `1566-1618` (financial_status_get), `479-526` (RLS/grants), `1621` (service_role reconcile) — task is `lib/` + `test/` only; `git diff --stat supabase/` must be `0`.

---

## 2. Functional Verification

This task delivers the unified multi-currency financial profile system: one `FinancialProfile` per entity holding `CurrencyAccount` and `Balance` per currency (`NGN`/`GHS`/`USD`/`GBP`), server-enforced profile creation, balance display (available/held/pending), and the payment-gateway hint seam. Functional verification confirms the data layer, repository, service facade, change-notifier provider, screens, widgets, and routing behave correctly and never bypass server invariants.

### 2.1 Required Functionality — Currency Vocabulary

- [ ] **FV-01:** `lib/systems/finance/models/supported_currency.dart` defines `SupportedCurrency` value object with exactly 4 instances: `NGN` (Nigerian Naira, `₦`, 2), `GHS` (Ghanaian Cedi, `₵`, 2), `USD` (US Dollar, `$`, 2), `GBP` (British Pound, `£`, 2) matching `financial_supported_currencies` `37-62` — each with `code`, `name`, `symbol`, `decimalPlaces`, `fromCode(String)` lookup
- [ ] **FV-02:** `SupportedCurrency` is extensible data-driven — adding `KES`/`ZAR` requires only `SupportedCurrency` entry + `financial_supported_currencies` seed row; no screen or repository edits (Open/Closed per `EP-02:197`); `values.length==4` asserted in unit test
- [ ] **FV-03:** `FinancialService.supportedCurrencies` exposes the 4-currency list as single source of truth — screens never hardcode `['NGN','GHS','USD','GBP']` inline; data-driven from reference table, not per-screen constant

### 2.2 Required Functionality — Data Layer (Entities, DTOs, Mappers)

- [ ] **FV-04:** `FinancialProfile` entity exists at `lib/data/entities/financial_profile.dart:1` — `id, entityId, status ('active'|'suspended'|'closed'), defaultCurrency, createdAt` — pure Dart, no Flutter/Supabase imports
- [ ] **FV-05:** `CurrencyAccount` entity at `lib/data/entities/currency_account.dart` — `id, financialProfileId, entityId, currencyCode, accountStatus ('pending'|'active'|'suspended'|'closed'), receivingAccountNumber?, receivingBankName?, providerReference?, activatedAt?`
- [ ] **FV-06:** `Balance` entity at `lib/data/entities/balance.dart` — `currencyCode, availableBalance, heldBalance, pendingBalance, totalDeposited, totalWithdrawn, lastTransactionAt?` all `>=0` invariant
- [ ] **FV-07:** `FinancialStatus` aggregate at `lib/data/entities/financial_status.dart` — `defaultCurrency, profileStatus, balances List<Balance>, activeEscrowCount, cashoutLimit`
- [ ] **FV-08:** DTOs exist at `lib/data/models/financial_profile_dto.dart`, `currency_account_dto.dart`, `balance_dto.dart`, `financial_status_dto.dart` — `fromJson` maps `financial_profile_get` `{profile:{id,entity_id,status,default_currency,created_at}, currency_accounts:[...]}` and `financial_balance_get` `{currency_code, available_balance, held_balance, pending_balance}`
- [ ] **FV-09:** `FinancialMapper` at `lib/data/mappers/financial_mapper.dart` defines `profileToEntity`, `accountToEntity`, `balanceToEntity`, `statusToEntity` — maps DTO→Entity without leaking RPC JSON shape; null/missing row → zero defaults
- [ ] **FV-10:** Zero balance defaults handled at mapper/repository — `financial_balance_get` `742-744` returns `null` → `available_balance:0, held_balance:0, pending_balance:0` never throws for unactivated currency

### 2.3 Required Functionality — Remote Data Source

- [ ] **FV-11:** `FinancialRemoteDataSource` abstract exists at `lib/data/datasources/remote/financial_remote_data_source.dart` — methods `getProfile()`, `getBalance(String currencyCode)`, `getStatus()`
- [ ] **FV-12:** `SupabaseFinancialRemoteDataSource` exists at `lib/data/datasources/remote/supabase_financial_remote_data_source.dart` — `extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`), constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`, uses `supabase.rpc<Map<String,dynamic>>` for all 4 RPCs
- [ ] **FV-13:** RPC mapping exact: `financial_profile_get` (`683-714` no params), `financial_balance_get` (`717-754` `params:{p_currency_code}`), `financial_status_get` (`1566-1618` no params), `financial_profile_create` (`635-680` `params:{p_default_currency}`)
- [ ] **FV-14:** Envelope unwrap via financial envelope parser (reuses `VerificationEnvelopeParser.unwrap` `lib/data/datasources/remote/verification_envelope_parser.dart:29`) validates `success==true && code=='PLT000'` before DTO mapping; malformed/`success:false` envelope throws `ApiException` with extracted `code/message` — no third parser created
- [ ] **FV-15:** Error mapping via `DataExceptionMapper` (`lib/data/datasources/remote/data_exception_mapper.dart`) — `PLT001→auth`, `PLT003→validation`, `PLT004→notFound`, `PLT005→conflict`, `PLT999→server`; raw `DioException` never propagates (`BaseApiService.invoke:33` normalizes)

### 2.4 Required Functionality — Repository

- [ ] **FV-16:** `FinancialRepository` abstract + `FinancialRepositoryImpl` exist at `lib/data/repositories/financial_repository.dart` + `financial_repository_impl.dart`
- [ ] **FV-17:** `getProfile()` delegates to `remote.getProfile()` → `FinancialMapper.profileToEntity`; entity with no `financial_profiles` row returns `null` (not throw) — `financial_profile_create` has not been called
- [ ] **FV-18:** `getBalance(currencyCode)` delegates to `remote.getBalance(currencyCode)` → `balanceToEntity`; unactivated currency returns `Balance` zero defaults `742-744`; unsupported `XYZ` throws validation before RPC (`supportedCurrencies` check)
- [ ] **FV-19:** `getStatus()` delegates to `remote.getStatus()` → `statusToEntity` — full aggregate `{default_currency, profile_status, balances:[{currency_code,available,held,pending}], active_escrow_count, cashout_limit}` `1607-1615`
- [ ] **FV-20:** `createProfile({String defaultCurrency})` validates `defaultCurrency` in `supportedCurrencies` first — invalid throws `DataValidationException PLT003` **before** RPC (spy not called); valid delegates to `supabase.rpc('financial_profile_create', {p_default_currency})` via envelope then re-reads `getProfile()` to confirm; `PLT005` conflict (profile exists `655`) returns existing profile with guidance, not throw-as-toast
- [ ] **FV-21:** `requestAccountActivation({required String currencyCode})` — seam: validates currency supported, if `PaymentGatewayFactory.resolveForCurrency(currencyCode)` available returns guidance hint ("Connect NGN via Paystack"), else returns `CurrencyAccount` `pending` with generic guidance; **never writes `financial_currency_accounts` directly** (activation is `financial_payout_account_bind` `EP-02-16`)
- [ ] **FV-22:** Repository never imports `lib/systems/` widgets — unidirectional `data → systems`; no `SupabaseClientProvider` singleton inside repository (client held via datasource only)

### 2.5 Required Functionality — Systems Facade

- [ ] **FV-23:** `FinancialService` exists at `lib/systems/finance/services/financial_service.dart` — thin facade over `FinancialRepository`, consumed by `FinancialProvider` and future `EP-02-14/15/16` without modification
- [ ] **FV-24:** Exposes `supportedCurrencies` list with display metadata (code/name/symbol/decimalPlaces `37-62`); adding `KES` is enum + seed only — no screen edits
- [ ] **FV-25:** `HivorrLogger` + `PiiRedactor` redacted logging (`entityId: ***last4`, `currencyCode`, `balance.available`) — never logs `legal_name`, never raw `account_number`/`bank_name`; `PerformanceTracer` spans `finance.profile.get.duration` / `finance.balance.get.duration` / `finance.status.get.duration` sampled via `MonitoringConfig`
- [ ] **FV-26:** `BalanceFormatter` pure helper at `lib/systems/finance/helpers/balance_formatter.dart` — `String formatBalance(double amount, String currencyCode)` → `₦50,000.00`, `₵1,200.00`, `$100.00`, `£75.50` — locale-aware via `intl` `lib/shared/helpers/`, `0 → ₦0.00`, negative throws `ArgumentError`, unsupported code falls back to code-only

### 2.6 Required Functionality — Provider (ChangeNotifier)

- [ ] **FV-27:** `FinancialProvider` exists at `lib/data/providers/financial_provider.dart` — `extends ChangeNotifier` (`provider:6.1.5`), mirrors `VerificationProvider` pattern (`lib/data/providers/verification_provider.dart:42-308`)
- [ ] **FV-28:** State fields: `FinancialProfile? profile`, `List<CurrencyAccount> accounts`, `Map<String,Balance> balances`, `FinancialStatus? status`, `AsyncState loadState`, `ApiException? lastError`, `bool isRefreshing`
- [ ] **FV-29:** `load()` fetches `getProfile()` + `getStatus()` in parallel via `Future.wait` (status already contains balances so `getStatus()` may serve profile to save RPC); sets `loadState=loading` → `success`, `lastError` on failure; no-op second call coalesced
- [ ] **FV-30:** `refreshStatus()` re-reads status + profile then `notifyListeners()`; `createProfile({defaultCurrency})` delegates to repository then `refreshStatus()`; surface `lastError.message` without `stack`/`SQL`
- [ ] **FV-31:** Lifecycle: `pausePolling()`/`resumePolling()` exposed, `WidgetsBindingObserver.didChangeAppLifecycleState(background)` pauses, `AppRouter didPush/didPop` cancels, `dispose()` cancels; no `Timer.periodic` leak while `profile==null` or terminal `suspended/closed`
- [ ] **FV-32:** Constructor injection `({required FinancialRepository repo, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability; no `SupabaseClientProvider` singleton inside provider (repository holds client); `HivorrNotification` on `profile_created` via `NotificationProvider` (`lib/core/notifications/providers/notification_provider.dart`) — `title:'Financial profile created'`

### 2.7 Required Functionality — UI Screens

- [ ] **FV-33:** `FinancialProfileScreen` exists at `lib/systems/finance/screens/financial_profile_screen.dart` (`GET /finance`): `AppBar(title: Text('Financial Profile', style: textTheme.titleLarge))`, `FinancialProfileCard` (default currency symbol + status chip: `active` green `successContainer`, `suspended` amber `warningContainer`, `closed` grey `outline` `VISUAL-IDENTITY.md:72-79`), `BalanceOverviewCard` (per-currency chips ₦/₵/$/£ via `BalanceFormatter`), `CurrencyAccountsList` (each `CurrencyAccount` with status badge + bank name when activated), create/manage CTA
- [ ] **FV-34:** Create CTA present when `profile == null` ("Set up your financial profile" primary button → `/finance/create`); hidden and replaced by "Manage" secondary action when `profile != null`; `suspended` shows `HivorrErrorState` + "Contact support", `closed` shows deactivation explanation — neither blocks balance viewing (read-only)
- [ ] **FV-35:** `FinancialProfileCreationFlow` exists at `lib/systems/finance/screens/financial_profile_creation_flow.dart` (`GET /finance/create`): default-currency radio group over `supportedCurrencies` with symbols (`₦ NGN Nigerian Naira` etc), CTA `HivorrButton(variant: primary, isLoading, isExpanded:true)` → `provider.createProfile` → `financial_profile_create`; **no file picker** — creation is a form, not upload

### 2.8 Required Functionality — UI Widgets

- [ ] **FV-36:** `FinancialProfileCard` at `lib/systems/finance/widgets/financial_profile_card.dart` — `Container(decoration: BoxDecoration(color: status=='active'? colorScheme.successContainer : warningContainer, borderRadius: BorderRadius.circular(ext.radiusSm)))` soft not hard shadow (`VISUAL-IDENTITY.md:226`)
- [ ] **FV-37:** `BalanceOverviewCard` at `lib/systems/finance/widgets/balance_overview_card.dart` — per-currency `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` chips, value `textTheme.titleMedium`, label `textTheme.labelSmall` `colorScheme.onSurfaceVariant`; `available` `successContainer`, `held` `primaryContainer`, `pending` `warningContainer` 16dp (`VISUAL-IDENTITY.md:221`)
- [ ] **FV-38:** `CurrencyAccountCard` at `lib/systems/finance/widgets/currency_account_card.dart` — `NGN — ₦ Nigerian Naira` + status badge (`active` green, `pending` amber, `closed` grey) + bank name when `activatedAt != null` + `Icons.account_balance` tinted `colorScheme.secondary` when active
- [ ] **FV-39:** `BalanceChip` at `lib/systems/finance/widgets/balance_chip.dart` — semantics `Semantics(label:'Available balance ₦50,000.00')`
- [ ] **FV-40:** All widgets consume `AppTheme` tokens **only** — `Theme.of(context).colorScheme`, `textTheme`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` (`VISUAL-IDENTITY.md:176-190,219-235`); no `Colors.*`, no `Color(0xFF0B6E99)` inline (hex lives only in `lib/app/theme/app_colors.dart:16`), no `fontFamily` literal; responsive via `ResponsiveScaffold`/`shared/layouts/` (`ARCHITECTURE.md:122-124`) 16dp mobile / 24dp web; branded `HivorrEmptyState`/`HivorrLoadingState`/`HivorrErrorState`/`HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`)

### 2.9 Required Functionality — Routing & DI

- [ ] **FV-41:** `RoutePaths.finance = '/finance'` and `RoutePaths.financeCreate = '/finance/create'` added to `lib/app/router/route_paths.dart`; `RouteNames.finance`/`financeCreate` added; `app_router.dart:17` registers both — guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`) authenticated only, no taxonomy gate, private flow (not SEO `/p/:slug/:id` `ARCHITECTURE.md:150`)
- [ ] **FV-42:** Barrels re-export all new symbols: `lib/systems/finance/finance.dart:1`, `lib/data/data_layer.dart:1`
- [ ] **FV-43:** Factory `FinancialProvider.create(supabase: SupabaseClientProvider.client)` wired in bootstrap; screens consume `FinancialProvider`/`FinancialService` without importing `supabase.rpc` literals (`ARCHITECTURE.md:101-110`)

### 2.10 Expected Workflows

- [ ] **FV-44:** Happy path: `profile==null` → `FinancialProvider.load()` → `getProfile()==null` shows creation CTA inline (no separate no-profile screen, prevents wasted `getStatus` `PLT004`) → user selects `NGN` → `createProfile(defaultCurrency:'NGN')` validates `NGN` in `supportedCurrencies` → `financial_profile_create` → `{profile_id, default_currency:NGN}` → re-read `getProfile()` → `profile.defaultCurrency=='NGN'` + `status=='active'` + `Balance NGN available 0` → `getStatus()` → `balances.length==1` + `cashoutLimit` → screen renders profile card `successContainer` + `₦0.00` + `HivorrNotification`
- [ ] **FV-45:** Existing profile: `getProfile()` → profile + `currency_accounts:[NGN active, GHS pending...]` → screen renders `NGN` card with bank name + `GHS` pending "Connect your GHS account" guidance with `PaymentGatewayFactory.resolveForCurrency('GHS')` hint
- [ ] **FV-46:** Balance display workflow: `getStatus()` aggregate renders per-currency `available/held/pending` chips correctly formatted `₦50,000.00`; default currency highlighted `primaryContainer`; future `KES` appears automatically via data-driven list
- [ ] **FV-47:** Profile exists retry: `createProfile` when profile already exists → `PLT005` conflict surfaced inline "Profile already exists" not toast; existing profile returned

### 2.11 Success Conditions

- [ ] **FV-48:** `financial_profile_create` returns `{success:true, code:PLT000, data:{profile_id, default_currency, balance_id}}` `675-678` with profile+default balance row created atomically
- [ ] **FV-49:** `financial_profile_get` returns `{success:true, code:PLT000, data:{profile:{id,entity_id,status,default_currency,created_at}, currency_accounts:[{id,currency_code,account_status,receiving_account_number,receiving_bank_name,activated_at}]}}` `709-712`
- [ ] **FV-50:** `financial_balance_get('NGN')` returns `{currency_code:NGN, available_balance, held_balance, pending_balance}` `746-753` defaults zero; unsupported `XYZ` → `PLT004`
- [ ] **FV-51:** `financial_status_get` returns `{default_currency, profile_status, balances:[...], active_escrow_count, cashout_limit}` `1607-1615` — KYC-derived `cashout_limit` joined via `entity_kyc_levels:kyc_tiers` `1601-1605`
- [ ] **FV-52:** Service is provider-swappable — screens/systems consume `FinancialRepository`/`FinancialService`/`BalanceFormatter` without importing `SupabaseClient.rpc` literals or raw `financial_*` strings; `requestAccountActivation` never `POST /rest/v1/financial_currency_accounts`

### 2.12 Error Handling Scenarios

- [ ] **FV-53:** `401 PLT001 auth` (unauthenticated `v_actor is null` `647,694,728,1579`) → `ApiExceptionKind.auth` → redirect `/login` via `RouteGuard`
- [ ] **FV-54:** `403 PLT002 forbidden` (client attempt to write `financial_profiles.status` via REST) → `ApiExceptionKind.forbidden` — no SQL leaked; grant is `INSERT(entity_id, default_currency)` only `513`
- [ ] **FV-55:** `400/422 PLT003 validation` (unsupported `defaultCurrency XYZ` `651` or `currencyCode XYZ` for `financial_balance_get` `734`, malformed envelope `success:false`) → `ApiExceptionKind.validation` — inline field error, never toast; envelope `success:false` → `ApiException` from parser
- [ ] **FV-56:** `404 PLT004 notFound` (unsupported currency `XYZ` `734`) → `ApiExceptionKind.notFound`; null/missing profile → `null` not `PLT004`
- [ ] **FV-57:** `409 PLT005 conflict` (duplicate `financial_profile_create` `655,664`) → `ApiExceptionKind.conflict` → inline "Profile already exists" via repository, not toast; no duplicate row (`unique entity_id` `69`)
- [ ] **FV-58:** `5xx PLT999 server` → `ApiExceptionKind.server` — retry 3x prod / 4x dev with `500ms→8s` backoff (`lib/core/api/api_config.dart:40-49`); no unbounded storm
- [ ] **FV-59:** Network timeout → `ApiExceptionKind.timeout` mapped via `ApiExceptionMapper._mapTransport`; backoff; raw `DioException` never propagates — `BaseApiService.invoke:33` normalizes

### 2.13 Important User Interactions

- [ ] **FV-60:** Fail-fast currency validation: creation flow validates `defaultCurrency` against `supportedCurrencies` client-side before RPC — invalid `XYZ` shows inline `HelperText` `colorScheme.error` without server `PLT003` round-trip
- [ ] **FV-61:** Profile null guard: `FinancialProfileScreen` mount `load()` checks `getProfile()==null` first and shows creation CTA inline — prevents wasted `getStatus()` (`financial_status_get` would need profile)
- [ ] **FV-62:** Currency clarity: all balances show `symbol + code` e.g. `₦50,000.00 NGN` to prevent confusion; default currency highlighted `primaryContainer` background
- [ ] **FV-63:** Premium branded states — `HivorrEmptyState` "Create your financial profile to start receiving payments", `HivorrLoadingState` wrapping `HivorrLoader`, `HivorrErrorState` when `status==suspended/closed` + "Contact support", `HivorrSuccessState` after creation — wrapping breathing pulse (`VISUAL-IDENTITY.md:148`), never bare `CircularProgressIndicator`

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Files added ONLY under `lib/data/entities/financial_*.dart` (4), `lib/data/models/financial_*.dart` (4 DTOs), `lib/data/mappers/financial_mapper.dart`, `lib/data/datasources/remote/financial_remote_data_source.dart` + `supabase_financial_remote_data_source.dart`, `lib/data/repositories/financial_repository*.dart` (2), `lib/data/providers/financial_provider.dart`, `lib/systems/finance/models/supported_currency.dart`, `lib/systems/finance/services/financial_service.dart`, `lib/systems/finance/helpers/balance_formatter.dart`, `lib/systems/finance/screens/financial_*.dart` (2), `lib/systems/finance/widgets/*.dart` (4), `lib/systems/finance/finance.dart`, `lib/data/data_layer.dart` (barrel), `lib/app/router/*` (2 routes), `test/**` — no files in `lib/core/storage/`, `lib/engine/`, `lib/integrations/payment_gateways/`, `lib/systems/verification/`, `lib/ai/`
- [ ] **TV-02:** No DDL on `public.*` or `storage.*` — `git diff --stat supabase/` shows 0; no `supabase/migrations/*` added, no `supabase/config.toml` modified; no `lib/core/storage/*` modification
- [ ] **TV-03:** Module placement conforms to `ARCHITECTURE.md:56,101-138` — `lib/data/` owns RPC + DTOs (reusable `EP-02-14/15/16`), `lib/systems/finance/` owns currency vocabulary + formatter + UX, `lib/integrations/` untouched (within `112-120` surface); no new top-level `lib/` beyond `lib/systems/finance/` (already exists as `.gitkeep` → replaced)
- [ ] **TV-04:** Interface-first — abstract `FinancialRemoteDataSource` separate from `Supabase...`; abstract `FinancialRepository` separate from `Impl`; repository never imports `lib/systems/` widgets (unidirectional `data → systems`); service consumes `PaymentGatewayFactory` interface only (ISP)
- [ ] **TV-05:** No `public.*`/`storage.*` SECURITY DEFINER, no `GRANT`, no `CREATE POLICY` — `supabase/migrations/` untouched
- [ ] **TV-06:** Dependency wiring uses `SupabaseClientProvider.client` safe accessor (`lib/core/api/supabase/supabase_client_provider.dart:19`) + `currentAccessToken` `:29`; no direct `Supabase.instance.client` leakage beyond datasource

### 3.2 Required System Behavior

- [ ] **TV-07:** `SupabaseFinancialRemoteDataSource` reuses envelope parser (financial or `VerificationEnvelopeParser.unwrap` `29`) — validates `success==true && code=='PLT000'`; no duplicate parser
- [ ] **TV-08:** Every public method throws only `ApiException` (`lib/core/api/exceptions/api_exception.dart:6-66`) or `DataException` — never raw `Supabase`/`DioException`; `ApiExceptionMapper` preserves `kind/code/statusCode` with safe message (no SQL/stack)
- [ ] **TV-09:** `FinancialRepository.createProfile` validates `defaultCurrency` in `supportedCurrencies` BEFORE RPC — unit test proves RPC spy not invoked on `XYZ`
- [ ] **TV-10:** Client never writes `financial_profiles.status/default_currency` or `financial_currency_accounts.*` or `financial_balances.*` via REST — `grep -r "financial_profiles.*=" lib/systems/finance lib/data` = 0 for assignment; all via `financial_profile_create` RPC audit `672`
- [ ] **TV-11:** `FinancialProvider.load()` uses `Future.wait` not sequential; status already contains balances — may derive profile locally to save RPC (implementation decision documented)
- [ ] **TV-12:** `FinancialRemoteDataSource` does NOT inject `StorageService` or `NotificationProvider`; `FinancialProvider` does not hold `SupabaseClientProvider` singleton — repository holds client
- [ ] **TV-13:** `BalanceFormatter`/`SupportedCurrency` pure Dart — no I/O, no globals, no Flutter imports; `O(n)` ≤12 chars safe per render
- [ ] **TV-14:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) log `entityId ***last4`, `currencyCode`, `balance.available` — never `legal_name`, `account_number`, `bank_name`; `MonitoringService` spans `finance.profile.get.*` sampled via `MonitoringConfig`

### 3.3 Module Integration

- [ ] **TV-15:** No conflict with `VerificationRemoteDataSource` `16-90` — `FinancialRemoteDataSource` dedicated thin wrapper enables independent evolution (future `financial_profile_update` without touching verification)
- [ ] **TV-16:** Envelope parser + `DataExceptionMapper` shared (not re-implemented) — single parsing path
- [ ] **TV-17:** `FinancialProvider` mirrors `VerificationProvider` `42` read/poll pattern — no third timer, no notification duplication
- [ ] **TV-18:** `lib/systems/finance/` imports `lib/data/entities/*.dart` + `PaymentGatewayFactory` interface only — never imports `lib/systems/verification/widgets/`, Supabase SDK (formatter is SDK-free)
- [ ] **TV-19:** Consumable by `EP-02-14/15/16` without modification; `BalanceFormatter` + `SupportedCurrency` reusable client-side mirror of server `financial_supported_currencies`
- [ ] **TV-20:** No `lib/integrations/payment_gateways/*` mutation; no `financial_escrow`/`financial_payouts` import; no `financial_transactions` ledger read in this task

### 3.4 Technical Requirements from Plan

- [ ] **TV-21:** `flutter analyze` + `dart analyze` clean
- [ ] **TV-22:** `FinancialRemoteDataSource`/`Supabase...` dartdoc documents RPC envelope contract, parser reuse, `BaseApiService.invoke` pattern, 4 RPCs with `PLT00x` codes
- [ ] **TV-23:** `FinancialRepository` dartdoc documents validation-before-RPC, `PLT005` conflict handling, never-writes rule (`AGENT.md:16` Rule 4); `BalanceFormatter` dartdoc documents 4 currency symbols; `SupportedCurrency` dartdoc documents data-driven extensibility
- [ ] **TV-24:** `FinancialProvider` dartdoc documents `load()` parallel fetch, `pausePolling/resumePolling` lifecycle; `FinancialService` dartdoc documents data-driven `supportedCurrencies`

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **DV-01:** `financial_supported_currencies` seed exact — `NGN ₦ 2`, `GHS ₵ 2`, `USD $ 2`, `GBP £ 2` `is_active true, decimal_places 2, sort_order` `37-62` — created by `EP-02-04`, read-only here; `financial_supported_currencies_active_sort_idx` `52-53`
- [ ] **DV-02:** `financial_profiles` one row per entity (`unique(entity_id)` `69`), FK `entities(id)` + `financial_supported_currencies(currency_code)` `73`, `status in ('active','suspended','closed')` `71` — created server-side only by `financial_profile_create` `660-672` (inserts profile + default `financial_balances` row + `financial_audit_trail profile_created`); client creates **only** via RPC, never REST `POST`
- [ ] **DV-03:** `financial_balances` one row per `(entity_id,currency_code)` `137` `>=0` `128-132`, FK `financial_profiles(id)` `122`, created atomically with profile `668-670`

### 4.2 Data Updates

- [ ] **DV-04:** Client never updates `financial_profiles.status/default_currency` or `financial_currency_accounts.*` or `financial_balances.*` via REST — grants `authenticated SELECT/INSERT(entity_id, default_currency)` `513`, `SELECT/INSERT(entity_id,currency_code)` `517`, `SELECT/INSERT(limited)/UPDATE(balance cols)` `521-524` respectively; mutation path is RPC only
- [ ] **DV-05:** Profile creation idempotent — `financial_profile_create` checks `exists ... entity_id=v_actor` `655` and `unique_violation` `664` → `PLT005`; client surfaces inline not toast, no duplicate row
- [ ] **DV-06:** `financial_currency_accounts` never written by `EP-02-13` — `requestAccountActivation` is guidance seam only; actual `financial_payout_account_bind` is `EP-02-16` path

### 4.3 Data Relationships

- [ ] **DV-07:** `financial_profile_get` aggregate `709-712` includes `profile{...}` + `currency_accounts[]` via `financial_currency_accounts where entity_id=v_actor order by currency_code` `704-706` — display-only
- [ ] **DV-08:** `financial_balance_get` returns `{currency_code, available_balance, held_balance, pending_balance}` `746-753` coalesced zero `742-744`; `financial_status_get` `1585-1593` returns `balances jsonb_agg order by currency_code` + `active_escrow_count` `1595-1599` + `cashout_limit` `1601-1605` via `entity_kyc_levels:kyc_tiers` join
- [ ] **DV-09:** FK chain: `financial_balances.financial_profile_id → financial_profiles.id cascade`, `entity_id → entities cascade`, `currency_code → financial_supported_currencies` — all enforced at migration, not client

### 4.4 Data Accuracy

- [ ] **DV-10:** `SupportedCurrency.fromCode('NGN')==NGN_symbol ₦` … `fromCode('GBP')==GBP_symbol £`; missing `XYZ` validation fails before RPC; mapper unit test covers all 4
- [ ] **DV-11:** Balance values exact — `financial_balance_get('NGN')` `available 50000` etc asserted in `financial_repository_test` and integration `status.balances` length + `availableBalance==0` new profile
- [ ] **DV-12:** `status` enum `active|suspended|closed` mapped; `account_status` `pending|active|suspended|closed` `97-98` mapped display-only; no privilege from local `active` without RPC re-read
- [ ] **DV-13:** Decimal precision `decimal_places 2` `37-46` preserved — `BalanceFormatter` renders `₦50,000.00` not `50000`; `numeric` not `double` loss verified in mapper test

### 4.5 Data Integrity

- [ ] **DV-14:** `financial_audit_trail profile_created` `672` written server-side by `financial_profile_create`; client never inserts audit rows
- [ ] **DV-15:** No `public.*` table mutation by client — `financial_profile_get/balance_get/status_get/profile_create` via RPC read/insert grant only; `git diff --stat supabase/` 0
- [ ] **DV-16:** No persistence of `profile`/`balances` to disk (no Hive) — `FinancialProvider` memoizes in memory only; invalidation via `refreshStatus()` on resume/create/pull-to-refresh
- [ ] **DV-17:** No currency conversion data — `financial_conversions` untouched; base balances single source of truth (`EP-02-15` layers conversion later, no FK in this task)

---

## 5. Security Verification

- [ ] **SV-01:** Server-authoritative profiles (`AGENT.md:16` Rule 4) — client never writes `financial_profiles.status/default_currency` or `financial_currency_accounts.*` — `grep -r "financial_.*=.*" lib/systems/finance lib/data --include="*.dart"` assignment 0 (read-only display via `financial_profile_get`); all transitions via `financial_profile_create` `635-672`
- [ ] **SV-02:** RLS default-deny inherited — 12 financial tables `revoke all from anon,authenticated,service_role` `492-506` + narrow grants `509-525`; `financial_supported_currencies authenticated SELECT` `509`, `financial_profiles authenticated SELECT/INSERT(limited)` `513`; policies remain `EP-02-04` frozen; `RouteGuard` redirects `/login`
- [ ] **SV-03:** Client `POST {default_currency:'XYZ', status:'active'}` to `/rest/v1/financial_profiles` fails — no grant for `status` column, `default_currency` validated `651` → `PLT003`; `grep` + unit test proves repository never issues REST write
- [ ] **SV-04:** No `service_role` leak — `grep -r "service_role" lib/` 0; `FinancialProvider`/`FinancialService` never hold `service_role` key; `SupabaseClientProvider.client` uses `anon`/`authenticated` RLS scope
- [ ] **SV-05:** Admin `financial_reconcile` not invocable — granted `service_role` only `1621`; authenticated attempt → `PLT002` forbidden via `ApiExceptionMapper`; `financial_status_get` remains `authenticated` `1566`
- [ ] **SV-06:** Execution model respected — all 4 RPCs `SECURITY INVOKER` `638,686,719,1569`, RLS applies inside body; granted `authenticated` (`635-680` self-scoped `v_actor=auth.uid()`)
- [ ] **SV-07:** Auth token protection — `SupabaseClientProvider.currentAccessToken:29` never logged; `PiiRedactor` masks `entityId ***last4`; never `legal_name`, `account_number`, `bank_name` raw
- [ ] **SV-08:** PII scope minimal — financial profile is aggregate; no bank account full numbers in logs; `BalanceFormatter` logs `available` numeric not PII
- [ ] **SV-09:** Balance guard is convenience, NOT authority — authoritative check is server `financial_balance_get` → `financial_withdraw` (`EP-02-16`) `PLT006 insufficient funds`; client display mismatch never grants funds
- [ ] **SV-10:** Time-of-check/race — `financial_profiles unique(entity_id)` `69` + `financial_profile_create` `exists` check `655` + `unique_violation` exception `664` prevents duplicate; client surfaces `PLT005` idempotence
- [ ] **SV-11:** Auth state isolation — `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL `ENV-001..010` `ARCHITECTURE.md:164-172`; `financial_*` per-env via migration, no cross-env read
- [ ] **SV-12:** No SQL injection — RPC uses parameterized `supabase.rpc('financial_*', params:{p_default_currency, p_currency_code})`; no raw SQL, no dynamic interpolation

---

## 6. Performance Verification

- [ ] **PV-01:** Parallel fetch — `FinancialProvider.load()` `Future.wait` over `getProfile()` + `getStatus()`; 2 RPCs not sequential; may derive profile from `getStatus` to save 1 RPC; no wasted `getStatus` when `profile==null` guard
- [ ] **PV-02:** Caching — `FinancialProvider` memoizes `profile` + `accounts` + `balances` + `status` in memory (no Hive); invalidate via `refreshStatus()` on resume/create/pull-to-refresh
- [ ] **PV-03:** Formatter cost — `BalanceFormatter.formatBalance` pure `O(n)` ≤12 chars + `SupportedCurrency.fromCode O(1)` — free per render, no RPC per balance chip
- [ ] **PV-04:** RPC cost — all 4 RPCs `STABLE` `686,719,1569` indexed `financial_profiles_entity_id_key 83`, `financial_currency_accounts_entity_currency_key 112`, `financial_balances_entity_currency_key 143` — sub-10ms typical
- [ ] **PV-05:** No polling storm — `FinancialProvider` has no `Timer.periodic` while `profile==null` or suspended/closed (unlike KYC 15s poll); pause/resume via `WidgetsBindingObserver`; no 240 req/hr waste
- [ ] **PV-06:** Backoff — `timeout/network` → `500ms→8s` exponential `lib/core/api/api_config.dart:45-49` `maxRetries 3 prod/4 dev`; no retry storm; terminal `suspended/closed` no poll
- [ ] **PV-07:** `PerformanceTracer` spans `finance.profile.get.duration` etc sampled via `MonitoringConfig`, tags `finance.profile.status`/`finance.currency.count`, no PII — lightweight
- [ ] **PV-08:** Notification one-shot — one `HivorrNotification` per `profile_created` (not per poll tick); local-only, no `supabase_realtime`

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/data/finance/` + `test/unit/systems/finance/`

Pattern mirrors `test/unit/core/api/api_exception_mapper_test.dart` + fakes (`test/support/fakes/fake_supabase.dart`, `fake_financial_remote_data_source.dart`) — no live Supabase.

- [ ] **TT-01:** `financial_remote_data_source_test.dart` ≥10 cases green — `financial_profile_get → {success:true, code:PLT000, data:{profile:{...}, currency_accounts:[]}}` success; `financial_balance_get('NGN')→{currency_code:NGN, available:50000...}` success; `financial_balance_get('XYZ')→PLT004 notFound`; envelope `success:false→PLT003 validation`; `401→PLT001 auth`, `500→PLT999`, `financial_status_get→{balances:[...], active_escrow_count:0, cashout_limit:100000}` success; `financial_profile_create('NGN')→{profile_id}` success; `financial_profile_create existing→PLT005 conflict` via `ApiExceptionMapper`
- [ ] **TT-02:** `financial_repository_test.dart` ≥14 cases green — fake `SupabaseFinancialRemoteDataSource` + `PaymentGatewayFactory`: `getProfile` maps profile+accounts; `getBalance NGN` entity; `getBalance XYZ` null before RPC; `getStatus` aggregate; `createProfile NGN` delegates then re-reads; `createProfile XYZ` throws validation before spy; `requestAccountActivation NGN` guidance; `profile null` when no row; `PLT005` surfaces "already exists"
- [ ] **TT-03:** `financial_provider_test.dart` ≥12 cases green — `ChangeNotifier` mock repo: `load()` → `loading→success` calls `getProfile`+`getStatus`; `createProfile` delegates + refreshes; `refreshStatus` re-reads `notifyListeners`; `pausePolling/resumePolling`; error `lastError.message`
- [ ] **TT-04:** `financial_mapper_test.dart` ≥10 cases green — `FinancialProfileDto.fromJson→FinancialProfile` `entity_id/status/default_currency/created_at`; `BalanceDto→Balance` `available/held/pending`; `CurrencyAccountDto→CurrencyAccount` `account_status/receiving_*`; null→defaults; `FinancialStatusDto→FinancialStatus` `balances[] + active_escrow_count + cashout_limit` — **100%**
- [ ] **TT-05:** `balance_formatter_test.dart` ≥8 cases green — `format(50000,NGN)=='₦50,000.00'`, `1200 GHS=='₵1,200.00'`, `100 USD=='$100.00'`, `75.5 GBP=='£75.50'`, `0 NGN=='₦0.00'`, negative→`ArgumentError`, unsupported→code-only — **100%**
- [ ] **TT-06:** `supported_currency_test.dart` ≥6 cases green — labels `Nigerian Naira` etc, `fromCode('NGN')==NGN`, `values.length==4`, extensibility — **100%**
- [ ] **TT-07:** Total **≥60 unit assertions** green; repository/provider ≥90%, mappers/formatter 100%

### 7.2 Automated Widget Suite — `test/widget/systems/finance/`

- [ ] **TT-08:** `financial_profile_screen_test.dart` ≥12 cases green — `Provider<FinancialProvider>` fake + `MaterialApp AppTheme.light`: `FinancialProfileCard` `active successContainer` vs `suspended warningContainer`; `BalanceOverviewCard` shows `₦50,000.00`; `CurrencyAccountsList` visible; create CTA `profile==null` visible hidden when `!=null`; asserts `TextTheme titleLarge` (no `fontFamily`), `EdgeInsets==AppThemeExtension.spacing` multiples, `Card` radius 16dp `VISUAL-IDENTITY.md:220`; `grep Colors.` 0
- [ ] **TT-09:** `financial_profile_creation_flow_test.dart` ≥8 cases green — `profile==null`: radio shows NGN/GHS/USD/GBP symbols; `HivorrButton` visible tap shows `HivorrLoader` `lib/app/widgets/hivorr_loader.dart:1`; `profile!=null` → `HivorrSuccessState`; unsupported not in list
- [ ] **TT-10:** `balance_overview_card_test.dart` ≥8 cases green — chips `successContainer` available vs `primaryContainer` held vs `warningContainer` pending, no hex, semantics `Semantics(label:'Available balance ₦50,000.00')`
- [ ] **TT-11:** `currency_account_card_test.dart` ≥8 cases green — badges `successContainer`/`warningContainer`/`outline` per status, no `Color(0xFF...)`, bank name when activated
- [ ] **TT-12:** All widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` + `find.byType(HivorrButton)` — AppTheme harness pattern

### 7.3 Integration (Fake-E2E) — `test/integration/finance/`

- [ ] **TT-13:** `test/integration/finance/financial_profile_flow_test.dart` green — fake `SupabaseClient.rpc` map + real `FinancialRepositoryImpl`: `getProfile()→null` → `createProfile(NGN)→{profile_id}` → `getProfile()→active NGN` → `getBalance(NGN)→0/0/0` → `getStatus()→1 balance + cashoutLimit`; no `supabase start` needed (live `supabase db test` is RLS truth)

### 7.4 Regression Guard

- [ ] **TT-14:** `flutter analyze` + `dart analyze` clean
- [ ] **TT-15:** `flutter test --coverage` domain ≥80% line; mapper/formatter 100%, provider ≥90%
- [ ] **TT-16:** `supabase db test` full suite `001-017` + financial `013-014` green — zero RLS regression
- [ ] **TT-17:** Lens greps — `grep -r "Colors\.|Color(0x" lib/systems/finance lib/data` 0 (except `lib/app/theme/app_colors.dart:16`); `grep -r "fontFamily" lib/systems/finance` 0; `grep -r "service_role" lib/` 0; `grep -r "financial_.*=" lib/systems/finance lib/data` write 0
- [ ] **TT-18:** `git diff --stat supabase/` 0; `git diff --stat lib/core/storage` 0; `git diff --stat lib/integrations/payment_gateways` 0; `git diff --stat lib/systems/verification` 0 for `financial_` leakage

### 7.5 Edge Cases

- [ ] **TT-19:** `profile==null` (no row) → CTA inline, no throw, no wasted `getStatus`
- [ ] **TT-20:** `financial_balance_get` unactivated currency → zero defaults `0/0/0` chip renders `₦0.00` not error
- [ ] **TT-21:** All 4 currencies render `₦/₵/$/£` + `NGN/GHS/USD/GBP` code; default highlighted `primaryContainer`
- [ ] **TT-22:** `status==suspended/closed` grey/amber badge + "Contact support" but balances still visible read-only
- [ ] **TT-23:** `CurrencyAccount pending` shows "Connect your NGN account via Paystack" hint with `PaymentGatewayFactory` result; `active` shows bank name + `activated_at`
- [ ] **TT-24:** Duplicate `createProfile` → `PLT005` inline guidance, no duplicate row, no second notification

### 7.6 Failure Scenarios

- [ ] **TT-25:** `createProfile XYZ` → validation inline before RPC (spy not called)
- [ ] **TT-26:** `401 PLT001` → redirect `/login` via `RouteGuard`; `load()` surfaces `auth` not raw
- [ ] **TT-27:** Client REST `POST /rest/v1/financial_profiles` → RLS/grant fails or `PLT002` forbidden
- [ ] **TT-28:** Envelope `success:false PLT003` → `validation` surfaced — no raw JSON to UI
- [ ] **TT-29:** Network timeout → `timeout` + backoff `500ms→8s` visible pull-to-refresh/error state
- [ ] **TT-30:** `5xx PLT999` retry 3x bounded no infinite loop

### 7.7 Manual Testing

- [ ] **TT-31:** Manual spot-check (optional `supabase start`): `no-profile` view → `/finance/create` select `NGN` → `Create` → `pending→active` → `GET /finance` shows `₦0.00` available + `pending` GHS card with guidance → `getStatus` shows `active_escrow_count` + `cashout_limit`

---

## 8. User Acceptance Verification

This task delivers Stage 5 financial foundation — the data-driven multi-currency profile that escrow/payouts/conversions operate against. UAT verifies currency vocabulary, profile lifecycle, balance visibility, and downstream readiness.

- [ ] **UA-01:** Lead can open `/finance` with no profile → sees `FinancialProfileCard` absent + CTA "Set up your financial profile" + `HivorrEmptyState`; with profile `NGN active` → green `successContainer` card `₦ NGN` + `BalanceOverviewCard` `₦0.00` available all `AppTheme` token no raw colors
- [ ] **UA-02:** Creation flow motivational — 4 radio options with correct symbols `₦/₵/$/£` + names `Nigerian Naira` etc; primary CTA creates via `financial_profile_create`; no financial math in client per `AGENT.md:7` Rule 4
- [ ] **UA-03:** Balance clarity — per-currency `available successContainer`/`held primaryContainer`/`pending warningContainer` chips formatted `₦50,000.00 NGN`; default currency highlighted; future `KES` appears without code change
- [ ] **UA-04:** Account guidance — `pending` card shows "Connect your [currency] bank account" with provider hint `resolveForCurrency`; `active` shows `receiving_bank_name` + `receiving_account_number` masked; no NIBSS name enquiry here (`EP-02-16`)
- [ ] **UA-05:** Status sensitivity — `suspended` warm `HivorrErrorState` + "Contact support"; `closed` deactivated explanation; balances still read-only visible — no blocked view
- [ ] **UA-06:** Premium finish — `HivorrLoader` breathing pulse `148`, soft elevation not hard shadow, 8pt grid, ≥48dp targets, 16dp mobile/24dp web, light/dark WCAG AA `#0B6E99`/`#10B981`
- [ ] **UA-07:** No escrow/payout leakage — `grep -r "escrow|payout|conversion|financial_transactions" lib/systems/finance` 0 for writes; no `lib/integrations/payment_gateways` write; balance is read+display not money-movement
- [ ] **UA-08:** Security transparent — `grep service_role` 0, `grep financial_.*=` write 0; anonymous redirects `/login`; profile creation is RPC idempotent `PLT005`
- [ ] **UA-09:** Downstream unblocked — `EP-02-14` escrow can import `FinancialRepository`/`FinancialProfile` without `supabase.rpc` literals; `EP-02-16` payout can `getBalance` before `financial_withdraw`; new currency = enum+seed zero `systems/` change (Open/Closed)

---

## 9. Final Approval Checklist

All conditions must be satisfied before EP-02-13 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/data/entities/financial_profile.dart` `FinancialProfile{id,entityId,status,defaultCurrency,createdAt}` | File inspection | ☑ |
| 2 | `lib/data/entities/currency_account.dart` `CurrencyAccount{...accountStatus,receiving*,providerReference,activatedAt}` | File inspection | ☑ |
| 3 | `lib/data/entities/balance.dart` `Balance{currencyCode,available,held,pending,totalDeposited/Withdrawn,lastTransactionAt}` | File inspection | ☑ |
| 4 | `lib/data/entities/financial_status.dart` `FinancialStatus{defaultCurrency,profileStatus,balances,activeEscrowCount,cashoutLimit}` | File inspection | ☑ |
| 5 | `lib/data/datasources/remote/financial_remote_data_source.dart` abstract `getProfile/getBalance/getStatus` + `supabase_financial_remote_data_source.dart extends BaseApiService supabase.rpc(financial_profile_get/balance_get/status_get/profile_create) envelope unwrap` | Code review + unit test | ☑ |
| 6 | `lib/data/mappers/financial_mapper.dart` `profile/account/balance/statusToEntity` null→defaults | Unit test | ☑ |
| 7 | `lib/data/repositories/financial_repository.dart + _impl.dart` `getProfile/getBalance/getStatus/createProfile/requestAccountActivation` validates before RPC, never writes tables directly | Unit test | ☑ |
| 8 | `lib/systems/finance/models/supported_currency.dart` `SupportedCurrency code/name/symbol/decimalPlaces fromCode all==4 KES-extensible` | File + unit test | ☑ |
| 9 | `lib/systems/finance/services/financial_service.dart` facade (redacted log+tracer) + `helpers/balance_formatter.dart formatBalance pure` | File + unit test (formatter 100%) | ☑ |
| 10 | `lib/data/providers/financial_provider.dart` `ChangeNotifier profile/accounts/balances/status/loadState load/refreshStatus/createProfile pause/resume dispose` | Unit test | ☑ |
| 11 | `lib/systems/finance/screens/financial_profile_screen.dart` `GET /finance` profile card+balance overview+accounts list+CTA `AppTheme` responsive | Widget test | ☑ |
| 12 | `lib/systems/finance/screens/financial_profile_creation_flow.dart` `GET /finance/create` currency radio+CTA via provider | Widget test | ☑ |
| 13 | `lib/systems/finance/widgets/financial_profile_card.dart / balance_overview_card.dart / currency_account_card.dart / balance_chip.dart` `colorScheme/textTheme/AppThemeExtension` 16dp | Widget test | ☑ |
| 14 | Barrels `lib/systems/finance/finance.dart` + `lib/data/data_layer.dart` re-export new symbols | File inspection | ☑ |
| 15 | `lib/app/router/route_paths.dart/route_names.dart/app_router.dart:17` `finance='/finance' financeCreate='/finance/create'` `RouteGuard` authenticated | File + go_router smoke | ☑ |
| 16 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` 0 | `git diff --stat` | ☑ |
| 17 | No `lib/integrations/payment_gateways/*` mutation — `git diff --stat lib/integrations/payment_gateways` 0 | `git diff --stat` | ☑ |
| 18 | No `service_role`/secret leakage — `grep -r "service_role" lib/` 0; write `grep financial_.*=` 0 | `grep` + code review | ☑ |
| 19 | No hardcoded tokens — `grep -r "Colors.\|Color(0x" lib/systems/finance lib/data` 0 (except `app_colors.dart:16`), `grep fontFamily lib/systems/finance` 0 | `grep` | ☑ |
| 20 | `test/unit/data/finance/financial_remote_data_source_test.dart` ≥10 cases green (`PLT001/003/004/005/999` envelope) | `flutter test` | ☑ |
| 21 | `test/unit/data/finance/financial_repository_test.dart` ≥14 + `financial_mapper_test.dart` ≥10 + `balance_formatter_test.dart` ≥8 + `supported_currency_test.dart` ≥6 green | `flutter test` | ☑ |
| 22 | `test/unit/data/providers/financial_provider_test.dart` ≥12 green (parallel load, create, lifecycle) | `flutter test` | ☑ |
| 23 | `test/widget/systems/finance/financial_profile_screen_test.dart` ≥12 + `financial_profile_creation_flow_test.dart` ≥8 + `balance_overview_card_test.dart` ≥8 + `currency_account_card_test.dart` ≥8 green token+layout | `flutter test` | ☑ |
| 24 | `test/integration/finance/financial_profile_flow_test.dart` fake-E2E green: null→create NGN→getProfile active→getBalance 0→getStatus 1 balance | `flutter test` | ☑ |
| 25 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI | ☑ |
| 26 | `supabase db test` full suite `001-017` + financial `013-014` green — no RLS regression | `supabase db test` | ☑ |
| 27 | `flutter test` total **≥60 unit assertions** green; `BalanceFormatter` 100%, `FinancialProvider` ≥90%, mappers 100% | `flutter test` | ☑ |
| 28 | Documentation: dartdoc on `FinancialProfile`, `Balance`, `CurrencyAccount`, `SupportedCurrency`, `BalanceFormatter`, `FinancialRepository` contract + data-driven currency note | File inspection | ☑ |

---

> **Sign-off:** Task EP-02-13 marked **Completed** -- all 28 conditions in the Final Approval Checklist are verified and signed off by the project lead.
