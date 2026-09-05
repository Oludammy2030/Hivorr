# Definition of Done — EP-02-15: Currency Conversion Infrastructure

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-15 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-15-Currency Conversion Infrastructure.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-15 |
| **Task Name** | Currency Conversion Infrastructure |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 5 — Financial Integrity Systems |
| **Priority** | High |
| **Dependencies** | EP-02-04 (frozen `supabase/migrations/20260829100004_financial_integrity_schema.sql` — `financial_conversions` table `355-382`, `financial_convert_currency` RPC `1459-1563`, grant `1686`, RLS `620-623`), EP-02-13 (Multi-Currency Financial Profile — `SupportedCurrency`, `BalanceFormatter`, `FinancialRepository.getStatus`, `FinancialProvider:49`) |
| **Blocks** | EP-02-16 (Payouts & Deposit Verification — cross-currency payout planning consumes the conversion seam), EP-02-14 (escrow cross-currency scenarios) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-15-Currency Conversion Infrastructure.md` |

> Frozen server refs (reused, never modified): `supabase/migrations/20260829100004_financial_integrity_schema.sql:355-382` (`financial_conversions` — `status in ('pending','completed','failed')` `370`, `check (from_currency <> to_currency)` `375`, index `financial_conversions_entity_idx (entity_id, created_at desc)` `381-382`), `1459-1563` (`financial_convert_currency(char(3), char(3), numeric, numeric)` — `p_rate` caller-supplied, `v_fee := 0` `1479`, `to_amount = amount * rate - fee` `1515`, `PLT001/003/004/006`, `FOR UPDATE` locks, double-entry ledger `conversion_debit`/`conversion_credit`, `financial_audit_trail conversion_executed`, returns `{conversion_id, from_amount, to_amount, rate}`), `1686` (granted `authenticated` + `service_role`), `620-623` (`financial_conversions_select` + `financial_conversions_insert` RLS). **The RPC accepts `p_rate` directly — the Rate Source is the protected dimension. This task is `lib/` + `test/` only; `git diff --stat supabase/` must be `0`.**

---

## 2. Definition of Done — Task Overview

This DoD verifies the **currency conversion infrastructure**: user-initiated conversion between supported currency balances (e.g., GHS↔NGN, USD↔NGN) via the server-authoritative `financial_convert_currency` RPC, with a **trusted, config-driven rate source seam** (`ConversionRateSource` + `ConfigConversionRateSource`), local preview (gross → fee → net), execute with post-execution balance refresh, and conversion history via a transport seam. The single most important verification in this DoD is the **rate-integrity lens**: because `financial_convert_currency` accepts `p_rate` as a caller-supplied input, the client must **never** present or execute a user-arbitrary rate — every rate passed to the RPC must originate exclusively from `ConversionRateSource`. The client never writes `financial_conversions`/`financial_balances` directly; all balance mutation is server-authoritative under `FOR UPDATE` locks. There is **no server-side rate RPC or rate table** in the frozen migration, so the rate lives client-side behind a guarded seam with a documented swap point for a future server/provider rate feed (EP-02-16+).

---

## 3. Functional Verification

This task delivers the conversion system: data layer (`CurrencyConversion`/`ConversionPreview` entities + DTOs + mapper), rate-source seam, repository (the unit-tested business contract), systems facade, provider, UI (pair selector, rate card, preview card, confirm, result card, history list), and routing. Functional verification confirms these behave correctly end-to-end and never violate the server-authoritative balance + trusted-rate invariants.

### 3.1 Required Functionality — Domain Vocabulary (Pair/Currencies)

- [x] **FV-01:** `lib/systems/finance/models/conversion_pair.dart` defines the validated `ConversionPair{fromCurrency, toCurrency}` value object — self-pairs (`from == to`) disallowed at construction; exposes `symbols` for display; `from`/`to` validated against `SupportedCurrency` (EP-02-13)
- [x] **FV-02:** `availablePairs` from `ConversionService` is data-driven from `SupportedCurrency`, non-self only — covers NGN↔GHS, NGN↔USD, NGN↔GBP, GHS↔USD, GHS↔GBP, USD↔GBP and the inverses where a rate exists; total `availablePairs.length == 12` (6 ordered + 6 inverses) where all rates configured
- [x] **FV-03:** Rate direction correctness — `rateFor('GHS','NGN')` returns the rate that converts the `from` to the `to` (i.e., `toAmount = fromAmount * rate`, matching `financial_convert_currency:1515`); inverse pairs derived only via a guarded `1/rate` helper when `rate > 0`, else `ConversionRateUnavailableException` — never a fabricated rate

### 3.2 Required Functionality — Data Layer (Entities, DTOs, Mappers)

- [x] **FV-04:** `lib/data/entities/currency_conversion.dart` exists — `CurrencyConversion{id, entityId, fromCurrency, toCurrency, fromAmount, toAmount, exchangeRate, fee, status, completedAt?, createdAt}` — pure Dart, no Flutter/Supabase imports
- [x] **FV-05:** `lib/data/entities/conversion_preview.dart` exists — `ConversionPreview{fromCurrency, toCurrency, fromAmount, grossAmount, fee, toAmount, exchangeRate}` — `toAmount = grossAmount - fee`
- [x] **FV-06:** DTOs exist at `lib/data/models/currency_conversion_dto.dart` + `conversion_preview_dto.dart` — `fromJson` maps the `financial_convert_currency` success envelope `data:{conversion_id, from_amount, to_amount, rate}` `1558-1561`; null `completed_at` → `null`, not throw; `fee` defaults to `0` (matching `v_fee := 0` `1479`)
- [x] **FV-07:** `lib/data/mappers/conversion_mapper.dart` defines `conversionToEntity` (+ `CurrencyConversionDto.fromJson`) and `previewToEntity` (+ `ConversionPreviewDto.fromJson`) — maps DTO→Entity without leaking RPC JSON shape; null/missing fields → safe defaults

### 3.3 Required Functionality — Remote Data Source (RPC write + history seam)

- [x] **FV-08:** `lib/data/datasources/remote/conversion_remote_data_source.dart` abstract exists — methods `convertCurrency({required fromCurrency, required toCurrency, required amount, required rate})` and `getHistory()`
- [x] **FV-09:** `lib/data/datasources/remote/supabase_conversion_remote_data_source.dart` exists — `extends BaseApiService` (`lib/core/api/services/base_api_service.dart:15`), constructor `({required super.dio, required super.supabase, required super.exceptionMapper})`
- [x] **FV-10:** `convertCurrency` calls `supabase.rpc<Map<String,dynamic>>('financial_convert_currency', params: {p_from_currency, p_to_currency, p_amount, p_rate})`; unwraps via `FinancialEnvelopeParser` (`lib/data/datasources/remote/financial_envelope_parser.dart` — validates `success==true && code=='PLT000'`); confirms returned `status == 'completed'`; maps to `CurrencyConversionDto`
- [x] **FV-11:** History read transported through a **seam** — `getHistory()` reads via `supabase.from('financial_conversions').select().eq('entity_id',...).order('created_at', descending:true)` OR returns `[]` when the REST read is not permitted under the authenticated scope (build-time decision gate §5.2) — the future `financial_conversions_list` RPC swap point is documented in dartdoc; never writes
- [x] **FV-12:** No history-listing RPC is invented — there is no `financial_conversions_list` in the frozen migration; the datasource uses only `financial_convert_currency` (+ optional REST read); no new server RPC is called or assumed

### 3.4 Required Functionality — Rate Source Seam

- [x] **FV-13:** `lib/systems/finance/services/conversion_rate_source.dart` defines the abstract `ConversionRateSource` — `Future<double> rateFor({required String fromCurrency, required String toCurrency})` returning a positive double, throwing `ConversionRateUnavailableException` when a pair has no configured rate
- [x] **FV-14:** `ConfigConversionRateSource` (default) is data-driven from a single guarded config source (e.g., `const Map<String,double>` of base cross-rates seeded from server/seed origin) — **never derived from user input**; single client rate authority
- [x] **FV-15:** `ConversionRateUnavailableException` is an `ApiException` subclass (`kind: validation`) — message "No conversion rate is currently available for this currency pair" — never a hardcoded/guess rate; distinct from server `PLT003` so UI can render the rate-unavailable state
- [x] **FV-16:** The seam is Open/Closed — a future `ServerConversionRateSource` (server rate RPC) or `ProviderConversionRateSource` (external FX) can replace `ConfigConversionRateSource` via DI with **no** repository or screen change; the swap point is documented in dartdoc (§5.3)

### 3.5 Required Functionality — Repository

- [x] **FV-17:** `lib/data/repositories/conversion_repository.dart` abstract + `_impl.dart` exist — `getRate({from,to})`, `previewConversion({from,to,amount})`, `executeConversion({from,to,amount})`, `getHistory()`
- [x] **FV-18:** `getRate` validates `fromCurrency`/`toCurrency` against `SupportedCurrency` and `from != to` before delegating to `ConversionRateSource.rateFor` — no RPC
- [x] **FV-19:** `previewConversion` validates `amount > 0` and pair validity, fetches `rate` from `ConversionRateSource`, computes `gross = amount * rate`, `fee` (default `0` matching `v_fee := 0`), `net = gross - fee`; returns `ConversionPreview`; **performs zero RPCs** — pure local math against the trusted rate seam
- [x] **FV-20:** `executeConversion` validates pair/amount/rate-positive, fetches `rate` from `ConversionRateSource` (single source), calls `remote.convertCurrency(from, to, amount, rate)`; on success re-reads `financial_status_get` via injected `FinancialRepository` to refresh balances; returns mapped `CurrencyConversion`; **prevents user-arbitrary rates**
- [x] **FV-21:** `getHistory` delegates to the remote history seam; maps DTOs; returns empty list on no records
- [x] **FV-22:** Repository **never writes** `financial_conversions`/`financial_balances` directly — no REST `POST`/`UPDATE` on those tables; all balance/conversion mutation happens server-side inside `financial_convert_currency`; repository uses RPC + read-seam only
- [x] **FV-23:** Repository never imports `lib/systems/` widgets — unidirectional `data → systems`; no `SupabaseClientProvider` singleton inside repository (client held via datasource only)

### 3.6 Required Functionality — Systems Facade

- [x] **FV-24:** `lib/systems/finance/services/conversion_service.dart` exists — thin facade over `ConversionRepository`: `availablePairs`, `previewConversion(from,to,amount)`, `executeConversion(from,to,amount)`, `getHistory()`, `formatPreview(ConversionPreview)` — wrappers only, no business rules bypassed
- [x] **FV-25:** `formatPreview` is locale-aware via `BalanceFormatter` (EP-02-13) — gross, fee, net each formatted with the destination currency symbol (`₦50,000.00 → $100.00`) — never raw `double.toString()`
- [x] **FV-26:** `HivorrLogger` + `PiiRedactor` redacted logging (`entityId: ***last4`, pair, amounts) — never `legal_name`, never raw bank/account data; `PerformanceTracer` spans `finance.conversion.preview.duration` / `finance.conversion.execute.duration` tagged pair, no PII

### 3.7 Required Functionality — Provider (ChangeNotifier)

- [x] **FV-27:** `lib/data/providers/conversion_provider.dart` exists — `extends ChangeNotifier` (`provider:6.1.5`), mirrors `FinancialProvider` (`lib/data/providers/financial_provider.dart:49`) + `EscrowProvider` patterns
- [x] **FV-28:** State fields: `String? fromCurrency`, `String? toCurrency`, `double amount`, `ConversionPreview? preview`, `CurrencyConversion? lastConversion`, `List<CurrencyConversion> history`, `AsyncState loadState`, `bool converting`, `ApiException? lastError`
- [x] **FV-29:** Methods `preview()` (recompute from current selection + amount), `execute()` (set `converting=true`, call `repo.executeConversion`, refresh balances via `financialRepo.getStatus()`, emit one-shot `HivorrNotification` `title:'Currency converted'` `body:'₦50,000.00 → $100.00'` `actionRoute:'/finance/convert'`), `loadHistory()`, `setSource`, `setDestination`, `setAmount`
- [x] **FV-30:** Lifecycle `pausePolling()`/`resumePolling()` via `WidgetsBindingObserver.didChangeAppLifecycleState(background)`; `_disposed` guard; `dispose()` cancels; no `Timer.periodic` while idle
- [x] **FV-31:** Constructor injection `({required ConversionRepository repo, required FinancialRepository financialRepo, HivorrLogger? logger, NotificationProvider? notificationProvider})` for testability — no `SupabaseClientProvider` singleton inside provider

### 3.8 Required Functionality — UI Screens & Widgets

- [x] **FV-32:** `lib/systems/finance/screens/conversion_screen.dart` exists — `GET /finance/convert`: `ConversionPairSelector` (distinct pairs only, self-pairs disallowed), amount `HivorrTextField` (validates `amount > 0`, currency symbol via `BalanceFormatter`), `ConversionRateCard` (live rate full + inverse), `ConversionPreviewCard` (gross → fee → **net**, net emphasized), `HivorrButton(variant: primary, isLoading: converting, isExpanded: true)` confirm, `ConversionResultCard` (post-execute success with `toAmount` + `conversionId` + link to history)
- [x] **FV-33:** `lib/systems/finance/widgets/conversion_pair_selector.dart` — source/destination pickers over `ConversionService.availablePairs`, from != to enforced, currency symbols `₦/₵/$/£` via `SupportedCurrency`
- [x] **FV-34:** `lib/systems/finance/widgets/conversion_rate_card.dart` — renders `1 NGN = 0.0007 USD` + inverse; loading → `HivorrLoadingState`; rate-unavailable → `HivorrErrorState` "rate unavailable for this pair"; source label "platform rate" + "updated at" when available
- [x] **FV-35:** `lib/systems/finance/widgets/conversion_preview_card.dart` — gross → fee → net lines via `BalanceFormatter`; net = `toAmount` (`textTheme.titleMedium` `colorScheme.primary`); card `Card(elevation: ext.elevationSm, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.radiusMd)))` 16dp; "This is an estimate — the final amount is confirmed on execution." `labelSmall`
- [x] **FV-36:** `lib/systems/finance/widgets/conversion_result_card.dart` — post-execute `toAmount` emphasized + `conversionId` reference + "View history" action; `HivorrSuccessState` wrap
- [x] **FV-37:** `lib/systems/finance/widgets/conversion_history_list.dart` — reverse-chronological conversion cards (pair, from→to amounts, rate, status chip `completed successContainer`/`failed errorContainer`, date); `HivorrEmptyState` "No conversions yet"; pull-to-refresh triggers `loadHistory()`
- [x] **FV-38:** All widgets consume `AppTheme` tokens **only** — `colorScheme.*`, `textTheme.*`, `AppThemeExtension.spacing/radiusSm/radiusMd/elevation` (`VISUAL-IDENTITY.md:176-190,219-235`); cards 16dp (`VISUAL-IDENTITY.md:221`); no `Colors.*`, no `Color(0xFF...)` inline (hex lives only in `lib/app/theme/app_colors.dart:16`), no `fontFamily` literal; responsive via `ResponsiveScaffold`/`shared/layouts/` (`ARCHITECTURE.md:122-124`) 16dp mobile / 24dp web; amounts via `BalanceFormatter` only

### 3.9 Required Functionality — Routing & DI

- [x] **FV-39:** `RoutePaths.convert = '/finance/convert'` and `RouteNames.convert` added; `lib/app/router/app_router.dart:17` registers the route — guarded by `RouteGuard` (`lib/app/router/route_guard.dart:1`): authenticated required + **profile-dependent** (redirects to `/finance/create` when `profile == null`); private financial flow (not SEO `/p/:slug/...`)
- [x] **FV-40:** Barrels re-export all new symbols — `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1`
- [x] **FV-41:** DI factory `ConversionProvider.create(supabase: SupabaseClientProvider.client)` wired; screens consume `ConversionProvider`/`ConversionService` without importing `supabase.rpc` literals (`ARCHITECTURE.md:101-110`); no new `ENV` secrets

### 3.10 Expected Workflows

- [x] **FV-42:** Preview happy path: user picks `NGN→USD` + `amount 50000` → `previewConversion` computes `gross 35`, `fee 0`, `net 35` locally (zero RPC) → `ConversionPreviewCard` shows `₦50,000.00 → $35.00`
- [x] **FV-43:** Execute happy path: confirm → `executeConversion` pulls rate `0.0007` from `ConversionRateSource` → `financial_convert_currency → {conversion_id, from_amount:50000, to_amount:35, rate:0.0007}` `status:'completed'` → `financial_status_get` refresh → balances updated NGN + USD → `ConversionResultCard` shows `$35.00` + `conversionId` + "View history" → `HivorrNotification` emitted
- [x] **FV-44:** Rate-unavailable workflow: pair without configured rate → `ConversionRateSource.rateFor` throws `ConversionRateUnavailableException` → `ConversionRateCard` renders `HivorrErrorState` "rate unavailable"; preview/execute blocked; no guessed rate offered
- [x] **FV-45:** History workflow: `loadHistory()` → `getHistory()` seam → reverse-chronological cards; empty → `HivorrEmptyState` "No conversions yet"; pull-to-refresh re-reads
- [x] **FV-46:** Insufficient-funds workflow: execute on a balance below `amount` → server `PLT006` → surfaced inline "Insufficient [from] balance" with link to finance screen — no optimistic local balance decrement
- [x] **FV-47:** Rate-consistency between preview and execute: both read from the **same** `ConversionRateSource`; if the rate changes between preview and confirm, the confirm step re-pulls and re-renders the net before final execution — no executed-rate drift from the displayed rate

### 3.11 Success Conditions

- [x] **FV-48:** `financial_convert_currency` returns `{success:true, code:PLT000, data:{conversion_id, from_amount, to_amount, rate}}` when the actor has an existing profile, valid supported `from`/`to`, `from != to`, `amount > 0`, `rate > 0`, and sufficient source balance — client maps to `CurrencyConversion` `status:'completed'`
- [x] **FV-49:** Conversion is live and server-authoritative — client maps the RPC envelope to entities; balances mutate only inside the RPC under `FOR UPDATE`; client reflects post-execution balances via `financial_status_get` (EP-02-13)
- [x] **FV-50:** **Rate-integrity is provable** — no user-entered rate field exists in the UI; every `financial_convert_currency` call site supplies a rate obtained from `ConversionRateSource` (grep-lens §7.4); no inline literal/constant/user rate reaches the RPC

### 3.12 Error Handling Scenarios

- [x] **FV-51:** `401 PLT001 auth` → `ApiExceptionKind.auth` → redirect `/login` via `RouteGuard`
- [x] **FV-52:** `403 PLT002 forbidden` → `ApiExceptionKind.forbidden` — surfaced in `HivorrErrorState`, no SQL leaked
- [x] **FV-53:** `400/422 PLT003 validation` (unsupported pair / `from==to` / `amount<=0` / `rate<=0` `1485-1498`) → `ApiExceptionKind.validation` — inline, never toast; client pre-validates known violations before RPC (fail-fast)
- [x] **FV-54:** `404 PLT004 notFound` (no existing profile `1502-1505`) → `ApiExceptionKind.notFound` — route pre-gate redirects to `/finance/create` when `profile == null`; surfaced "Profile required" if reached
- [x] **FV-55:** `PLT006 insufficient funds` (`1511-1513`) → mapped to an appropriate kind in the existing `ApiExceptionMapper` (extend mapper if the kind is distinct, per plan §5.2/§9.4) — surfaced inline "Insufficient [from] balance" with finance-link; no client-side concurrent-guard reliance (server `FOR UPDATE` is the enforcement)
- [x] **FV-56:** `5xx PLT999 server` → `ApiExceptionKind.server` with bounded retry — no unbounded retry storm
- [x] **FV-57:** `ConversionRateUnavailableException` → surfaces the distinct rate-unavailable state (not a generic validation error); no guessed rate
- [x] **FV-58:** Network timeout → `ApiExceptionKind.timeout` mapped via `ApiExceptionMapper._mapTransport`; raw `DioException`/`SupabaseException` never propagates (`BaseApiService.invoke` normalizes)

### 3.13 Important User Interactions

- [x] **FV-59:** Fail-fast validation — pair distinctness (`from != to`) and `amount > 0` validated client-side before any RPC — no round-trip for known `PLT003`/`PLT006` violations
- [x] **FV-60:** Trust-the-rate-before-the-move — the preview (gross → fee → net) is shown before any funds move with explicit "estimate — confirmed on execution" microcopy; the user never commits to an unknown effective rate
- [x] **FV-61:** Rate transparency — `ConversionRateCard` shows both `1 from = X to` and inverse `1 to = Y from`; source labeled "platform rate" (not raw provider) with "updated at" when available
- [x] **FV-62:** No arbitrary-rate field — the UI has no "enter rate" input; user only picks pair + amount; platform supplies the rate (`AGENT.md:7` no client-side financial rules, `EP-02:174`)
- [x] **FV-63:** History as trust record — `ConversionHistoryList` gives a reconcilable record against `financial_status_get` balances; PII protected (entity `***last4`, never `legal_name`)
- [x] **FV-64:** Premium finish — `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), soft elevation, 8pt grid `AppThemeExtension`, ≥48dp touch targets, 16dp mobile / 24dp web responsive panes; every amount via `BalanceFormatter`

---

## 4. Technical Verification

### 4.1 Architecture Compliance

- [x] **TV-01:** Files added ONLY under `lib/data/entities/currency_conversion.dart`, `lib/data/entities/conversion_preview.dart`, `lib/data/models/currency_conversion_dto.dart`, `lib/data/models/conversion_preview_dto.dart`, `lib/data/mappers/conversion_mapper.dart`, `lib/data/datasources/remote/conversion_remote_data_source.dart` + `supabase_conversion_remote_data_source.dart`, `lib/data/repositories/conversion_repository*.dart` (2), `lib/data/providers/conversion_provider.dart`, `lib/systems/finance/models/conversion_pair.dart`, `lib/systems/finance/services/conversion_rate_source.dart`, `lib/systems/finance/services/conversion_service.dart`, `lib/systems/finance/screens/conversion_screen.dart`, `lib/systems/finance/widgets/conversion_*.dart` (5), `lib/systems/finance/finance.dart` + `lib/data/data_layer.dart` (barrels), `lib/app/router/*` (route), `lib/config/` (rate config), `test/**` — no files in `lib/engine/`, `lib/integrations/payment_gateways/`, `lib/core/storage/`
- [x] **TV-02:** No DDL on `public.*` or `storage.*` — `git diff --stat supabase/` shows 0; no `supabase/migrations/*` added, no `supabase/config.toml` modified; no `.supabase/functions/*` created
- [x] **TV-03:** Module placement conforms to `ARCHITECTURE.md:56,101-138` — `lib/data/` owns RPC transport + DTOs + entities + repository + provider (reusable by `EP-02-16`), `lib/systems/finance/` owns rate-source seam + pair vocabulary + UX facade, `lib/integrations/` untouched (future provider rate feed lands there via the seam, not in this task)
- [x] **TV-04:** Interface-first — abstract `ConversionRemoteDataSource` separate from `SupabaseConversionRemoteDataSource`; abstract `ConversionRepository` separate from `ConversionRepositoryImpl`; abstract `ConversionRateSource` separate from `ConfigConversionRateSource`; repository never imports `lib/systems/` widgets (unidirectional `data → systems`)
- [x] **TV-05:** No `public.*` SECURITY DEFINER/GRANT/CREATE POLICY — `supabase/migrations/` untouched; the rate is a client-side guarded seam, not a server schema change
- [x] **TV-06:** Dependency wiring uses `SupabaseClientProvider.client` safe accessor (`lib/core/api/supabase/supabase_client_provider.dart:19`); no direct `Supabase.instance.client` leakage beyond datasource

### 4.2 Required System Behavior

- [x] **TV-07:** `SupabaseConversionRemoteDataSource` reuses `FinancialEnvelopeParser` (`lib/data/datasources/remote/financial_envelope_parser.dart`) — validates `success==true && code=='PLT000'`; no third parser created
- [x] **TV-08:** Every public method throws only `ApiException` (`lib/core/api/exceptions/api_exception.dart:6-66`) or `DataException` — never raw `Supabase`/`DioException`; `ApiExceptionMapper` preserves `kind/code/statusCode` with safe message (no SQL/stack); `ConversionRateUnavailableException` is an `ApiException` subclass `kind: validation`
- [x] **TV-09:** **Rate-integrity is enforced in code** — the only place a rate is supplied to `convertCurrency`/`financial_convert_currency` is `ConversionRepositoryImpl.executeConversion`, which obtains it from `ConversionRateSource.rateFor` — no literal/constant/user rate at any call site (verified by grep-lens §7.4 + code review)
- [x] **TV-10:** Client never writes `financial_conversions`/`financial_balances` — no REST `POST`/`UPDATE`/`PATCH` on those tables; all insertion/decrement/increment happen inside `financial_convert_currency` (`AGENT.md:16` Rule 4); `grep` proves no write-RPC string beyond `financial_convert_currency` in `lib/`
- [x] **TV-11:** `ConversionProvider.preview()` performs zero RPCs (pure local math); `execute()` = 1 `VOLATILE` `financial_convert_currency` + 1 `STABLE` `financial_status_get` refresh; rate seam = `O(1)` map lookup; no `Timer.periodic` while idle/backgrounded
- [x] **TV-12:** `ConversionRemoteDataSource` does NOT inject `StorageService`/`NotificationProvider`; `ConversionProvider` does not hold `SupabaseClientProvider` singleton — repository holds client
- [x] **TV-13:** `ConversionService`/`ConversionPreview` math is pure Dart (no I/O/globals/Flutter imports) — `gross = amount * rate`, `net = gross - fee`, `O(1)`, safe per render
- [x] **TV-14:** `HivorrLogger` + `PiiRedactor` (`lib/core/logging/pii_redactor.dart:1`) log `entityId ***last4`, pair, amounts — never `legal_name`, never raw bank/account data; `MonitoringService` spans `finance.conversion.preview.duration`/`finance.conversion.execute.duration` sampled via `MonitoringConfig`, tags `finance.conversion.pair`, no PII

### 4.3 Module Integration

- [x] **TV-15:** No conflict with `FinancialRemoteDataSource` (`lib/data/datasources/remote/financial_remote_data_source.dart`) — dedicated `ConversionRemoteDataSource` reuses `FinancialEnvelopeParser` + `BalanceFormatter` without importing `financial_remote_data_source` internals; independent evolution (no change to EP-02-13)
- [x] **TV-16:** Envelope parser + `DataExceptionMapper` shared (not re-implemented) — single parsing path
- [x] **TV-17:** `ConversionProvider` mirrors `FinancialProvider` (`lib/data/providers/financial_provider.dart:49`) lifecycle pattern — no third timer, no notification duplication; integrates `FinancialRepository.getStatus()` post-execute refresh
- [x] **TV-18:** `lib/systems/finance/` imports `lib/data/entities/currency_conversion.dart`/`conversion_preview.dart` + `BalanceFormatter` + `SupportedCurrency` only — never imports `lib/systems/verification/widgets/`, Supabase SDK in the seam/math
- [x] **TV-19:** Consumable by `EP-02-16` (payouts cross-currency planning) without modification — `CurrencyConversion`/`ConversionPreview`/`ConversionPair`/`ConversionRateSource` reusable; the rate-source swap point is the documented integration surface
- [x] **TV-20:** No `lib/integrations/payment_gateways/*` mutation; no `supabase_realtime` payload (conversion events surface on next read); no Edge Function

### 4.4 Technical Requirements from Plan

- [x] **TV-21:** `flutter analyze` + `dart analyze` clean
- [x] **TV-22:** `SupabaseConversionRemoteDataSource` dartdoc documents the `financial_convert_currency` envelope contract, `FinancialEnvelopeParser` reuse, `BaseApiService.invoke` pattern, and the **history transport seam** (REST read current vs future `financial_conversions_list` RPC swap point)
- [x] **TV-23:** `ConversionRateSource`/`ConfigConversionRateSource` dartdoc documents the guarded config-driven rates, the **swap point** for a future server/provider rate feed (EP-02-16+), and that rates are never user-derived; `ConversionRepository` dartdoc documents rate-from-seam (never user-arbitrary), preview zero-RPC invariant, and never-writes-conversion-tables rule (`AGENT.md:16` Rule 4)
- [x] **TV-24:** `ConversionProvider` (ChangeNotifier) dartdoc documents `preview`/`execute`/`loadHistory` lifecycle + `pausePolling`/`resumePolling`/`dispose`; `CurrencyConversion`/`ConversionPreview`/`ConversionPair` dartdoc documents field contracts and invariants (`from_amount>0`, `to_amount>0`, `exchange_rate>0`, `from != to`)

---

## 5. Data Verification

### 5.1 Data Creation

- [x] **DV-01:** No client creates `financial_conversions` rows — rows are inserted **server-side only** by `financial_convert_currency` (`1550-1552`, `status='completed'`); client maps the RPC response to a `CurrencyConversion` entity, it never REST-inserts; `git diff --stat supabase/` = 0
- [x] **DV-02:** `financial_conversions` server shape honored — `entity_id` self (via `auth.uid()`), `from_currency`/`to_currency` FK `financial_supported_currencies`, `from_amount numeric >0` `365`, `to_amount numeric >0` `366`, `exchange_rate numeric >0` `367`, `fee numeric >=0 default 0` `368`, `status in ('pending','completed','failed')` `370`, `check (from_currency <> to_currency)` `375` — client reflects these invariants, never invents amounts/rates

### 5.2 Data Updates

- [x] **DV-03:** Client **never** updates `financial_conversions`/`financial_balances` — no REST `PATCH`/`UPDATE`; source decrement + destination increment happen atomically inside `financial_convert_currency` under `FOR UPDATE` locks `1510,1524`; `grep` proves no table-update path in `lib/`
- [x] **DV-04:** Balance mutation is server-authoritative — `financial_convert_currency` locks source balance `FOR UPDATE` `1507-1510`, checks `available_balance < amount` `1511-1513` (`PLT006`), decrements source `1540-1543`, increments destination `1545-1548`, writes double-entry ledger rows (conversion_debit `1526-1531`, conversion_credit `1533-1538`) and audit `conversion_executed` `1554-1556` — all in one implicit transaction; client never performs local balance math as authoritative

### 5.3 Data Relationships

- [x] **DV-05:** Conversion record `entity_id` FK to `entities` `359` self-scoped via `auth.uid()` `1472,1482`; `from_currency`/`to_currency` FK to `financial_supported_currencies` `361-364` — client validates against `SupportedCurrency` (EP-02-13) and `from != to` before RPC
- [x] **DV-06:** History indexed read — `financial_conversions_entity_idx (entity_id, created_at desc)` `381-382` supports reverse-chronological history via the read seam; no full scan; paginate/limit if needed (default limit documented)
- [x] **DV-07:** Balance reflection after conversion — client re-reads `financial_status_get` (EP-02-13 `FinancialRepository.getStatus`) after execute to reflect updated source/destination balances; never nudges local balance state optimistically

### 5.4 Data Accuracy

- [x] **DV-08:** Amount math matches server — client preview computes `gross = amount * rate`, `net = gross - fee` matching `financial_convert_currency` `to_amount = amount * rate - fee` `1515`; `fee` defaults `0` matching `v_fee := 0` `1479`; the authoritative `to_amount` after execution comes from the RPC response `1558-1561`, never a client hand-computation displayed as authoritative
- [x] **DV-09:** Rate accuracy — `rateFor` returns positive doubles (`exchange_rate numeric >0`); a `rate <= 0` is rejected before RPC (fail-fast) and `financial_convert_currency` also guards `rate > 0` `1498` (`PLT003`); inverse derived via guarded `1/rate` where `rate > 0`
- [x] **DV-10:** Currency correctness — `from`/`to` codes aligned with supported currency seed (`37-62`) + `SupportedCurrency` vocab; displays always symbol + code via `BalanceFormatter` (`₦50,000.00 NGN`); no cross-currency confusion
- [x] **DV-11:** Timestamps — `completed_at` nullable `DateTime` (null → `null`, not throw); `created_at` required; null rendered "—" not crash

### 5.5 Data Integrity

- [x] **DV-12:** Zero DDL — no `ALTER`, `CREATE POLICY`, `GRANT`, index, or trigger; `git diff --stat supabase/` = 0; full pgTAP `001-017` + financial `013-014` suites must remain green
- [x] **DV-13:** Audit is server-written — `financial_audit_trail conversion_executed` `1554-1556` inserted by `financial_convert_currency`; client never inserts audit rows
- [x] **DV-14:** No disk persistence of conversion state (no Hive local data source) — `ConversionProvider` memoizes in memory only; history re-read on load/pull-to-refresh/lifecycle-resume; conversion is live financial state, not offline-cacheable
- [x] **DV-15:** History transport decision documented — whether REST reads of `financial_conversions` are permitted under the authenticated scope (policy `620`) OR `getHistory()` degrades to `[]` with the future RPC swap point, the marshalling and UI remain stable and RLS is never bypassed

---

## 6. Security Verification

- [x] **SV-01:** **Rate integrity is THE core security control (AGENT.md:16 Rule 4 / EP-02:174)** — `financial_convert_currency` accepts `p_rate` as a caller-supplied input (`1459-1467`, `1498`), so a user-arbitrary rate path would let a user move funds at a manipulated price. All rates originate **exclusively** from `ConversionRateSource`; the UI has **no "enter rate" field**; every call site passes a rate derived from the seam (rate-integrity grep-lens §7.4). This is the enforced boundary — the single most important security control in this task.
- [x] **SV-02:** No `service_role` leak — `grep -r "service_role" lib/systems/finance lib/data/finance lib/data/datasources lib/data/repositories lib/data/providers` = 0; `ConversionProvider`/`ConversionService`/`SupabaseConversionRemoteDataSource` never hold the `service_role` key; `SupabaseClientProvider.client` uses `anon`/`authenticated` role with RLS
- [x] **SV-03:** Server-authoritative balance mutation (`AGENT.md:16` Rule 4) — client never writes `financial_balances.*` or `financial_conversions.*` directly; `financial_convert_currency` performs source decrement + destination increment + ledger + audit atomically under `FOR UPDATE` locks `1510,1524`; client only reads balances via `financial_status_get` post-execution
- [x] **SV-04:** Authorization self-scope — `financial_convert_currency` self-scopes `v_actor = auth.uid()` `1472,1482`; RLS `financial_conversions_select`/`insert` `620-623` are entity-self (`authenticated`) `561-562`; `RouteGuard` requires authenticated (redirects `/login`); conversion route is profile-dependent (redirects `/finance/create` when `profile == null`)
- [x] **SV-05:** Insufficient-funds race prevented server-side — `financial_convert_currency` locks source balance `FOR UPDATE` `1507-1510` + checks `available_balance < amount` `1511-1513` (`PLT006`); two concurrent conversions cannot double-spend; client surfaces `PLT006` inline with no optimistic local balance decrement
- [x] **SV-06:** PII exposure minimal — conversion screens/logs render `entityId` suffix only; amounts are non-PII; `HivorrLogger` + `PiiRedactor` mask `entityId ***last4`, never log `legal_name`, never raw account/bank data; `MonitoringService` spans tagged by pair, no PII
- [x] **SV-07:** Rounding/precision — server computes `to_amount = amount * rate - fee` in `numeric`; client preview uses `double` for **display only**; the authoritative `to_amount` comes from the RPC response `1558-1561`; client never displays a hand-computed amount as authoritative after execution
- [x] **SV-08:** No SQL injection / no raw mutation — RPC calls use parameterized `supabase.rpc('financial_convert_currency', params: {...})`; no raw SQL, no dynamic query interpolation; no `POST /rest/v1/financial_conversions` / `financial_balances`
- [x] **SV-09:** Auth state isolation — `AppEnvironment` `Development→Staging→Production` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig` + Supabase URL per `ENV-001..010` (`ARCHITECTURE.md:164-172`); conversion across environments via migration + RPC, no cross-env read
- [x] **SV-10:** No server-side rate bypass — `grep -rn "financial_convert_currency" lib/` reviewed: every call site supplies a rate from `ConversionRateSource` (no literal/constant rate inlined); no config exposes a path for user-supplied rate

---

## 7. Performance Verification

- [x] **PV-01:** RPC cost — `execute` = 1 `financial_convert_currency` (`VOLATILE` `1469`, necessary — mutates state, source balance indexed) + 1 `financial_status_get` re-read (`STABLE` `1569`); **preview + getRate cost zero RPCs** (pure local `O(1)` math / guarded map lookup)
- [x] **PV-02:** Rate seam cost — `ConfigConversionRateSource.rateFor` is a guarded `Map` lookup `O(1)` — microseconds, no network; future provider feed (async + cached) is isolated behind the seam
- [x] **PV-03:** Preview math — `amount * rate` `double` `O(1)`, local, no network; `BalanceFormatter` reuse for formatting
- [x] **PV-04:** History — reverse-chronological list from `financial_conversions_entity_idx` `381-382` (indexed `entity_id, created_at desc`) — indexed read, no full scan; paginate/limit if needed (default limit documented)
- [x] **PV-05:** Lifecycle pause/resume — `WidgetsBindingObserver` pauses `ConversionProvider` refresh on background, resumes on foreground — no wasted preview/status RPCs while backgrounded (Nigerian 3G)
- [x] **PV-06:** No polling storm — `ConversionProvider` refreshes rate on pair change and status on execution only — no `Timer.periodic` while idle; no redundant RPCs per keystroke (debounced/preview-on-validate)
- [x] **PV-07:** `PerformanceTracer` spans `finance.conversion.preview.duration`/`finance.conversion.execute.duration` sampled via `MonitoringConfig`, tags `finance.conversion.pair`, no PII — lightweight
- [x] **PV-08:** Notification one-shot — one `HivorrNotification` per execute success, local-only, no `supabase_realtime`; conversion events surface on next read

---

## 8. Testing Verification

### 8.1 Automated Unit Suite — `test/unit/data/finance/` + `test/unit/systems/finance/`

Pattern mirrors the EP-02-13/14 suites + fakes (`test/support/fakes/fake_supabase.dart`, `fake_conversion_rate_source.dart`, `fake_conversion_remote_data_source.dart`) — no live Supabase.

- [x] **TT-01:** `conversion_remote_data_source_test.dart` ≥12 cases green — mock `SupabaseClient.rpc`: `financial_convert_currency → {success:true, code:PLT000, data:{conversion_id, from_amount, to_amount, rate}}` success; `amount<=0 → PLT003 validation`; `from==to → PLT003`; `unsupported currency → PLT003`; `no profile → PLT004 notFound`; `insufficient funds → PLT006`; `401 PLT001 auth`; `5xx PLT999`; history seam disabled → `[]`; history seam enabled → maps rows
- [x] **TT-02:** `conversion_repository_test.dart` ≥14 cases green — fake datasource + fake `ConversionRateSource`: `getRate('NGN','USD')` returns positive rate; `getRate` unsupported/self-pair throws validation before RPC; `previewConversion` computes gross/fee/net locally, no RPC; preview `amount<=0` throws; `executeConversion` pulls rate from seam, passes **EXACT rate param to RPC (spy)**, maps result, re-reads `financial_status_get`; execute with rate `>0` required; `PLT006` surfaces insufficient; `getHistory` returns list/`[]`; rate unavailable → `ConversionRateUnavailableException`
- [x] **TT-03:** `conversion_mapper_test.dart` ≥10 cases green — `CurrencyConversionDto.fromJson → CurrencyConversion` mapping `conversion_id, from_amount, from_currency, to_currency, to_amount, exchange_rate, fee, status`; `ConversionPreviewDto.fromJson → ConversionPreview`; null `completed_at` → null; status passthrough; fee default 0 — **100%**
- [x] **TT-04:** `conversion_service_test.dart` ≥10 cases green — `availablePairs.length == 12` (6 ordered + 6 inverses where rate exists); pair distinct; `previewConversion` delegates; `formatPreview` locale-aware via `BalanceFormatter`; rate-unavailable surfaces distinct message; `ConversionPair` validation — **100%**
- [x] **TT-05:** `config_conversion_rate_source_test.dart` ≥10 cases green — `rateFor('USD','NGN')` returns configured value `> 0`; inverse derived `1/rate` guarded; unsupported pair throws `ConversionRateUnavailableException`; zero/negative guard never returns a rate; single-source authority — no hardcoded inline rate in screens
- [x] **TT-06:** `balance_refresh_after_conversion_test.dart` ≥4 cases green — post-execute `financial_status_get` refresh updates balances map via injected `FinancialRepository`
- [x] **TT-07:** `conversion_provider_test.dart` ≥12 cases green — `ChangeNotifier` mock repo: `setSource/setDestination/setAmount` update state + `notifyListeners`; `preview()` recomputes; `execute()` sets `converting`, on success updates `lastConversion` + refreshes financial status + fires `HivorrNotification`; lifecycle `pausePolling`/`resumePolling`; error surfaces `lastError.message`; `_disposed` guard — **≥90%**
- [x] **TT-08:** Total **≥72 unit assertions** green; repository/provider ≥90%, mappers/service/rate-source 100%

### 8.2 Automated Widget Suite — `test/widget/systems/finance/`

- [x] **TT-09:** `conversion_screen_test.dart` ≥14 cases green — pump `MaterialApp AppTheme.light` (`lib/app/theme/app_theme.dart:1`) + `Provider<ConversionProvider>` fake: pair selector disallows self-pair; amount input validates `>0`; `ConversionRateCard` renders `1 NGN = 0.0007 USD`; `ConversionPreviewCard` shows gross/fee/net with net `textTheme.titleMedium` `colorScheme.primary`; confirm `HivorrButton` visible, tap shows `HivorrLoader`; `ConversionResultCard` on success shows `toAmount` + reference; asserts `TextTheme` via `Theme.of(context).textTheme.titleLarge` (no `fontFamily`), spacing `EdgeInsets` = `AppThemeExtension.spacing` multiples, `Card` radius 16dp (`VISUAL-IDENTITY.md:221`); `grep Colors.` assert = 0
- [x] **TT-10:** `conversion_rate_card_test.dart` ≥8 cases green — rate + inverse displayed; loading → `HivorrLoadingState`; unavailable → `HivorrErrorState` with "rate unavailable"; no hardcoded hex
- [x] **TT-11:** `conversion_preview_card_test.dart` ≥8 cases green — gross/fee/net lines formatted via `BalanceFormatter` (`₦50,000.00 → $100.00`); net emphasized `colorScheme.primary`; "estimate" microcopy `labelSmall`; semantics
- [x] **TT-12:** `conversion_history_list_test.dart` ≥8 cases green — cards render pair + amounts + status chip (`completed successContainer`/`failed errorContainer`); empty → `HivorrEmptyState` "No conversions yet"; pull-to-refresh invokes provider `loadHistory`
- [x] **TT-13:** All widget tests use `WidgetTester.pumpWidget(wrapWithTheme(...))` + `find.byType(HivorrButton)` — AppTheme harness pattern

### 8.3 Integration (Fake-E2E) — `test/integration/finance/`

- [x] **TT-14:** `test/integration/finance/conversion_flow_test.dart` green — fake `SupabaseClient.rpc` map + fake `ConversionRateSource` + real `ConversionRepositoryImpl` + real `FinancialRepositoryImpl` (fake datasource): `getRate('NGN','USD') == 0.0007` → `previewConversion(from:'NGN', to:'USD', amount:50000)` → `preview.net == 50000 * 0.0007` (gross 35, fee 0) → `executeConversion(from:'NGN', to:'USD', amount:50000)` → mock `financial_convert_currency → {conversion_id, from_amount:50000, to_amount:35, rate:0.0007}` → mapped `CurrencyConversion.status == 'completed'` → `financial_status_get` refresh → balances reflect updated NGN + USD; no `supabase start` needed (live `supabase db test` is RLS truth)

### 8.4 Regression Guard

- [x] **TT-15:** `flutter analyze` + `dart analyze` clean
- [x] **TT-16:** `flutter test --coverage` — domain ≥80% line coverage; mappers/service/rate-source 100%, provider ≥90%
- [x] **TT-17:** `supabase db test` full suite `001-017` + financial `013-014` green — zero RLS/role regression
- [x] **TT-18:** Lens greps — `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 (except `lib/app/theme/app_colors.dart:16`); `grep -r "fontFamily" lib/systems/finance` = 0; `grep -r "service_role" lib/systems/finance lib/data/finance lib/data/datasources lib/data/repositories lib/data/providers` = 0
- [x] **TT-19:** **Rate-integrity lens** — `grep -rn "financial_convert_currency" lib/` reviewed: every call site passes a rate obtained from `ConversionRateSource`; no literal/constant rate inlined at call sites; no user-input rate path (code review)
- [x] **TT-20:** `git diff --stat supabase/` = 0; `git status --porcelain .supabase/functions` empty; `git diff --stat lib/integrations/payment_gateways` = 0

### 8.5 Edge Cases

- [x] **TT-21:** Self-pair `from == to` → rejected client-side before RPC (fail-fast), no round-trip
- [x] **TT-22:** `amount <= 0` → inline validation error, no RPC attempt
- [x] **TT-23:** Zero/negative rate guarded — `ConfigConversionRateSource` never returns a non-positive rate; inverse derivation guarded (`1/rate` only when `rate > 0`)
- [x] **TT-24:** Unsupported pair (no configured rate) → `ConversionRateUnavailableException`, distinct rate-unavailable UI state, no guessed rate
- [x] **TT-25:** Empty conversion history → `[]`/`HivorrEmptyState` "No conversions yet", no throw
- [x] **TT-26:** Null `completed_at` → null-safe mapping, rendered "—" not crash
- [x] **TT-27:** History read seam disabled → `getHistory()` returns `[]` gracefully with documented RPC swap point — no RLS bypass
- [x] **TT-28:** Rate changes between preview and confirm → confirm re-pulls and re-renders net before final execution — no executed-rate drift

### 8.6 Failure Scenarios

- [x] **TT-29:** `401 → PLT001` unauth → redirect `/login` via `RouteGuard`; surfaces `ApiExceptionKind.auth`, not raw
- [x] **TT-30:** `PLT006` insufficient funds → mapped, surfaced inline "Insufficient [from] balance" with finance-link; no optimistic local decrement; no double-spend (server `FOR UPDATE` guards)
- [x] **TT-31:** Envelope `success:false, code:PLT003` → `ApiExceptionKind.validation` surfaced — no raw JSON to UI
- [x] **TT-32:** Network timeout → `ApiExceptionKind.timeout` + backoff `500ms→8s`; visible error state
- [x] **TT-33:** `5xx PLT999` bounded retry — no infinite retry loop
- [x] **TT-34:** No direct `financial_conversions`/`financial_balances` REST write — unit/grep proves repository never issues a table write

### 8.7 Manual Testing

- [x] **TT-35:** Manual spot-check (optional, `supabase start` or against local service-role seeded balances + configured rate): `/finance/convert` opens → pick `NGN→USD` + `amount 50000` → `ConversionRateCard` shows `1 NGN = 0.0007 USD` + inverse → `ConversionPreviewCard` shows gross `$35.00`, fee `$0.00`, net `$35.00` → confirm → `ConversionResultCard` shows `$35.00` + `conversionId` → finance screen balances NGN + USD updated → `ConversionHistoryList` shows the completed record → amounts rendered `₦50,000.00 NGN` / `$35.00 USD` → entity `***last4`, no legal names

---

## 9. User Acceptance Verification

This task delivers the **Stage 5 cross-balance mobility seam** — it lets an entity convert between its own supported currency balances with a transparent preview, trusted platform rate, and a reconcilable history, unblocking `EP-02-16` payout planning. UAT verifies the trust-through-preview UX, rate transparency, fail-fast validation, history trust record, and security posture.

- [x] **UA-01:** The project lead can open `/finance/convert` (authenticated with an existing financial profile) and pick a source + destination pair (self-pairs disallowed), enter an amount, and see the live `ConversionRateCard` (`1 NGN = 0.0007 USD` + inverse, "platform rate" label) with `ConversionPreviewCard` showing gross → fee → net (`₦50,000.00 → $35.00`, net emphasized) — all AppTheme-token driven, no raw colors — before any funds move
- [x] **UA-02:** Preview shows the **net** (`toAmount`) clearly as an estimate ("This is an estimate — the final amount is confirmed on execution"), and the rate shown equals the rate passed to execution — no drift; the user never commits to an unknown effective rate
- [x] **UA-03:** Confirming executes the conversion — `ConversionResultCard` shows the final `toAmount` + `conversionId` + "View history"; the finance screen balances (NGN + USD) update via `financial_status_get` refresh; a `HivorrNotification` "Currency converted" is emitted — no client-side balance fabrication
- [x] **UA-04:** `ConversionHistoryList` (embedded / via pull-to-refresh) renders reverse-chronological cards with pair, from→to amounts, rate, `completed`/`failed` status chip, and date; empty state `HivorrEmptyState` "No conversions yet" — a reconcilable trust record against `financial_status_get`
- [x] **UA-05:** Rate-unavailable pair shows `HivorrErrorState` "rate unavailable for this pair" (loading `HivorrLoadingState` while fetching) — no guessed/hardcoded rate is offered; the UI has **no "enter rate" field** (rate is platform-supplied per `AGENT.md:7` / `EP-02:174`)
- [x] **UA-06:** Fail-fast validation — selecting `from == to` and entering `amount <= 0` are blocked inline before any RPC; insufficient funds (`PLT006`) surfaces inline "Insufficient [from] balance" with a finance-screen link — no round-trip for known violations
- [x] **UA-07:** Premium finish — `HivorrLoader` breathing pulse (`VISUAL-IDENTITY.md:148`), soft elevation not hard shadow, 8pt grid `AppThemeExtension`, ≥48dp touch targets, 16dp mobile / 24dp web responsive panes, `BalanceFormatter` amounts with symbol + code (`₦50,000.00 NGN`) — no raw `Colors.*`/hex/`fontFamily` per `AGENT.md:17` Rule 5
- [x] **UA-08:** Security transparent — `grep -r "service_role" lib/` = 0; no client write path to `financial_conversions`/`financial_balances` (all mutation server-side in `financial_convert_currency` per `AGENT.md:16` Rule 4); rate-integrity lens proves every `financial_convert_currency` call site uses `ConversionRateSource`; unauthenticated access redirects `/login`; no-profile redirects `/finance/create`
- [x] **UA-09:** No PII leakage — entity `***last4`, amounts non-PII, no `legal_name`, no raw account/bank data in UI or logs
- [x] **UA-10:** Downstream unblocked — `EP-02-16` (payouts) and `EP-02-14` (escrow cross-currency) can import `CurrencyConversion`/`ConversionPreview`/`ConversionPair`/`ConversionRateSource` without `supabase.rpc` literals; the rate-source swap point is documented so a future server/provider rate feed (EP-02-16+) is a DI change, not a repository/screen change

---

## 10. Final Approval Checklist

All conditions below must be satisfied before EP-02-15 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/data/entities/currency_conversion.dart` exists — `CurrencyConversion{id, entityId, fromCurrency, toCurrency, fromAmount, toAmount, exchangeRate, fee, status, completedAt?, createdAt}` | File inspection | ✅ |
| 2 | `lib/data/entities/conversion_preview.dart` exists — `ConversionPreview{fromCurrency, toCurrency, fromAmount, grossAmount, fee, toAmount, exchangeRate}` | File inspection | ✅ |
| 3 | `lib/systems/finance/models/conversion_pair.dart` exists — validated `ConversionPair{fromCurrency, toCurrency}`, self-pair disallowed | File + unit test | ✅ |
| 4 | `lib/data/datasources/remote/conversion_remote_data_source.dart` abstract exists — `convertCurrency` + `getHistory` | File inspection | ✅ |
| 5 | `lib/data/datasources/remote/supabase_conversion_remote_data_source.dart` `extends BaseApiService` — `supabase.rpc('financial_convert_currency', params:{p_from_currency, p_to_currency, p_amount, p_rate})` + `FinancialEnvelopeParser` unwrap + `DataExceptionMapper`; history transport seam (REST read current / future RPC swap point) | Code review + unit test | ✅ |
| 6 | `lib/data/mappers/conversion_mapper.dart` defines `conversionToEntity`/`previewToEntity` — maps DTOs to entities, null → defaults, fee default 0 | Unit test | ✅ |
| 7 | `lib/data/repositories/conversion_repository.dart + _impl.dart` — `getRate/previewConversion/executeConversion/getHistory`; rate from `ConversionRateSource` (never user-arbitrary); validates pair/amount/rate before RPC; post-execute `financial_status_get` refresh; never writes `financial_conversions`/`financial_balances` directly | Unit test + rate-integrity lens | ✅ |
| 8 | `lib/systems/finance/services/conversion_rate_source.dart` defines abstract `ConversionRateSource` + `ConfigConversionRateSource` + `ConversionRateUnavailableException` — guarded, data-driven, documented swap point | File + unit test (100%) | ✅ |
| 9 | `lib/systems/finance/services/conversion_service.dart` facade exposes `availablePairs`/`preview`/`execute`/`history`/`formatPreview` (thin, no business rules bypassed) | File + unit test (100%) | ✅ |
| 10 | `lib/data/providers/conversion_provider.dart` exists — `ChangeNotifier` with pair/amount/preview/lastConversion/history/loadState/converting, `preview()`/`execute()`/`loadHistory()`, `pausePolling`/`resumePolling`/`dispose` — mirrors `lib/data/providers/financial_provider.dart:49` | Unit test (≥90%) | ✅ |
| 11 | `lib/systems/finance/screens/conversion_screen.dart` exists — `GET /finance/convert`, pair selector + amount + rate + preview + confirm + result, `AppTheme` tokens only, responsive | Widget test | ✅ |
| 12 | `lib/systems/finance/widgets/conversion_pair_selector.dart` / `conversion_rate_card.dart` / `conversion_preview_card.dart` / `conversion_result_card.dart` / `conversion_history_list.dart` exist — `colorScheme`/`textTheme`/`AppThemeExtension` only, cards 16dp (`VISUAL-IDENTITY.md:221`) | Widget test | ✅ |
| 13 | Barrels `lib/systems/finance/finance.dart:1` + `lib/data/data_layer.dart:1` re-export new symbols | File inspection | ✅ |
| 14 | `lib/app/router/route_paths.dart`/`route_names.dart`/`app_router.dart:17` expose `convert='/finance/convert'` guarded by `RouteGuard` (authenticated + profile gate) | File + `go_router` smoke | ✅ |
| 15 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat supabase/` = 0 | `git diff --stat` | ✅ |
| 16 | No `.supabase/functions/*` or `lib/integrations/payment_gateways/*` mutation | `git status --porcelain` / `git diff --stat` | ✅ |
| 17 | No `service_role`/secret leakage — `grep -r "service_role" lib/systems/finance lib/data/finance lib/data/datasources lib/data/repositories lib/data/providers` = 0 | grep | ✅ |
| 18 | **Rate-integrity** — every `financial_convert_currency` call site supplies a rate from `ConversionRateSource` — no inline literal/constant/user rate; no "enter rate" UI field; `grep -rn "financial_convert_currency" lib/` reviewed | grep + code review | ✅ |
| 19 | No hardcoded design tokens — `grep -r "Colors\.\|Color(0x" lib/systems/finance lib/data/finance` = 0 (except `lib/app/theme/app_colors.dart:16`), `grep -r "fontFamily" lib/systems/finance` = 0 | grep | ✅ |
| 20 | `test/unit/data/finance/conversion_remote_data_source_test.dart` ≥12 cases green (RPC envelope, `PLT001/003/004/006/999`, history seam) | `flutter test` | ✅ |
| 21 | `test/unit/data/finance/conversion_repository_test.dart` ≥14 + `conversion_mapper_test.dart` ≥10 + `conversion_service_test.dart` ≥10 + `config_conversion_rate_source_test.dart` ≥10 + `balance_refresh_after_conversion_test.dart` ≥4 green | `flutter test` | ✅ |
| 22 | `test/unit/data/providers/conversion_provider_test.dart` ≥12 green (pair selection, preview, execute + refresh + notification, lifecycle) | `flutter test` | ✅ |
| 23 | `test/widget/systems/finance/conversion_screen_test.dart` ≥14 + `conversion_rate_card_test.dart` ≥8 + `conversion_preview_card_test.dart` ≥8 + `conversion_history_list_test.dart` ≥8 green, token + layout asserts | `flutter test` | ✅ |
| 24 | `test/integration/finance/conversion_flow_test.dart` fake-E2E green: rate → preview → execute → status refresh | `flutter test` | ✅ |
| 25 | `flutter analyze` clean, `dart analyze` clean, `flutter test --coverage` domain ≥80% | CI | ✅ |
| 26 | `supabase db test` full suite `001-017` + financial `013-014` green — no RLS/role regression | `supabase db test` | ✅ |
| 27 | `flutter test` total **≥72 unit assertions** green; `ConversionRateSource` 100%, mappers 100%, `ConversionProvider` ≥90% | `flutter test` | ✅ |
| 28 | Documentation: dartdoc on `CurrencyConversion`, `ConversionPreview`, `ConversionPair`, `ConversionRateSource` (seam + swap point), `ConversionRepository` contract (rate-integrity + preview zero-RPC + never-write rule), `ConversionService`, `ConversionProvider`, `SupabaseConversionRemoteDataSource` (RPC envelope + history transport seam) | File inspection | ✅ |

---

> **Sign-off:** Task EP-02-15 marked **Completed** (Stage 5 — Financial Integrity Systems) — all 28 Final Approval Checklist conditions verified and signed off by the project lead: `financial_convert_currency` conversion live, `ConversionRateSource` seam enforced (rate-integrity lens clean — no user-arbitrary rate reaches the RPC), preview zero-RPC, full suite green, coverage targets met, `supabase db test` green, `git diff --stat supabase/` = 0, `EP-02-16` handed the rate-source swap-point contract.
