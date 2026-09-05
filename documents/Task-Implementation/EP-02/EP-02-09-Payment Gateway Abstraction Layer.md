# Task Implementation Plan — EP-02-09: Payment Gateway Abstraction Layer

**Task ID:** EP-02-09 | **Phase:** EP-02 Trust, Identity & Financial Integrity Engine | **Status:** Completed | **Priority:** Critical | **Dependencies:** EP-01-07 (Core API Layer) | **Stage:** 3 — Client-Side Infrastructure

> Source of Truth: `documents/Engineering-Execution/Engineering-Phase-Plan/EP-02 Trust, Identity & Financial Integrity Engine.md:335-345` | Architecture: `documents/Context/ARCHITECTURE.md:112-114,151-152` , `documents/Context/AGENT.md:4-8,16` | Dependencies: `EP-02:137` (`EP-02-09 → EP-01`), `EP-02:85` (Finance Infrastructure Strategy) | Stack: `pubspec.yaml:43` (`dio: 5.11.0`), `pubspec.yaml:53` (`supabase_flutter: 2.17.2`), `lib/core/api/services/base_api_service.dart:15` , `lib/core/api/api_initializer.dart:52-96` , `lib/config/environments/environment_config.dart:17`

---

## 1. Task Objective

Build the provider-agnostic payment gateway abstraction in `lib/integrations/payment_gateways/` — define abstract contracts for payment initialization, verification, transfer (payout), refund and webhook event parsing, plus a dedicated `NameEnquiryService` for NIBSS account-name verification. Implement concrete `PaystackGateway` and `FlutterwaveGateway` adapters over `Dio` and a `NibssNameEnquiryAdapter` (backed by provider resolve endpoints until direct NIBSS credential is provisioned). Expose a factory/registry for provider selection. Zero provider-specific types leak into `lib/systems/finance/`. Zero `public.*` DDL / RPC creation. Zero UI.

Deliverables:
- Abstract `PaymentGateway` + `NameEnquiryService` contracts in `lib/integrations/payment_gateways/`.
- `PaystackGateway` + `FlutterwaveGateway` adapters (`Dio` + `ApiExceptionMapper`).
- `PaymentGatewayFactory` / registry + `PaymentGatewayConfig` from `EnvironmentConfig`.
- Domain models for requests/results that are provider-neutral.
- Barrel update `lib/integrations/payment_gateways/payment_gateways.dart`.
- Unit test suite with mocked `Dio` responses (no live provider keys required).

## 2. Business Problem Being Solved

`EP-02:44,87` mandates **provider-agnostic, multi-currency financial infrastructure** and `ARCHITECTURE.md:151-152` forbids hardcoding `Paystack`/`Flutterwave`/`NIBSS` calls inside `lib/systems/finance/`:

- `lib/integrations/payment_gateways/.gitkeep` is empty — no abstraction exists. Without it every finance workflow (`EP-02-13` multi-currency profile, `EP-02-14` escrow, `EP-02-15` conversion, `EP-02-16` bound payouts + deposit name-matching) would `Dio.post('https://api.paystack.co/...')` directly, coupling business logic to one provider's path/shape/header/amount unit (kobo vs NGN) and violating `AGENT.md:4-6` Separation of Concerns + `AGENT.md:16` Rule 4 (no financial logic in client presentation — provider orchestration must be isolated behind an interface).
- `EP-02-09:340` explicitly requires **two adapters to validate the abstraction** — a single-provider wrapper proves nothing. Paystack (`/transaction/initialize`, `/transaction/verify/:ref`, `/transfer`, `/transfer/verify`, `/bank/resolve`, `/refund`) and Flutterwave (`/v3/charges?type=card|bank_transfer`, `/v3/transactions/:id/verify`, `/v3/transfers`, `/v3/accounts/resolve`, `/v3/transactions/:id/refund`) differ in auth header (`Authorization: Bearer sk_...` both, but different key), amount units, reference fields, status enums (`success` vs `successful`), and error envelopes — unification is non-trivial and must be designed before `EP-02-14`/`EP-02-16` consume it.
- `EP-02-16` deposit verification (`AGENT.md:7` Rule 3 `Payer Name == Entity Profile Name`) depends on the `NameEnquiryService` seam. Without `NIBSS`/resolve abstraction, payout account binding cannot verify ownership and deposit webhook cannot enforce name-matching server-side; both are deferred to ad-hoc client checks, a fraud vector.
- No factory/registry means `EP-02-13` cannot select provider per currency/region (NGN→Paystack, NGN/GHS→Flutterwave, future `Thunes`/`mobile money`/`stablecoin` per `EP-02:197` EP-08 scalability). Adding a provider would require editing `systems/finance/` business code, breaking Open/Closed.
- Webhook handling (`Paystack x-paystack-signature HMAC SHA512`, `Flutterwave verif-hash SHA256`) must have a provider-neutral `WebhookEvent` parser for future Edge Function (`EP-02:159`). Defining the contract now prevents business logic from parsing raw provider JSON.

This task is the **financial integration seam** — it unblocks `EP-02-13,14,15,16` per `EP-02:137,143-145` and proves the `EP-02:172` provider-agnostic design risk is mitigated.

## 3. Scope

| In Scope | Detail |
|---|---|
| `PaymentGateway` abstract contract | `initializePayment`, `verifyPayment`, `createTransfer`, `verifyTransfer`, `refundPayment`, `parseWebhookEvent` — all with provider-neutral models, `Future<T>` with `ApiException` error contract |
| `NameEnquiryService` abstract | `verifyAccount({bankCode, accountNumber}) → NameEnquiryResult(accountName, accountNumber, bankCode)` — used by `EP-02-16` payout binding + deposit verification |
| `PaystackGateway implements PaymentGateway` | `Dio` calls to `https://api.paystack.co` — `POST /transaction/initialize`, `GET /transaction/verify/:ref`, `POST /transfer`, `GET /transfer/verify/:ref`, `GET /bank/resolve?account_number&bank_code` (as NameEnquiry backing), `POST /refund` |
| `FlutterwaveGateway implements PaymentGateway` | `Dio` calls to `https://api.flutterwave.com` — `POST /v3/charges`, `GET /v3/transactions/:id/verify`, `POST /v3/transfers`, `GET /v3/transfers/:id`, `POST /v3/accounts/resolve`, `POST /v3/transactions/:id/refund` |
| `NibssNameEnquiryAdapter implements NameEnquiryService` | Primary: direct NIBSS `POST /nibss/bvnnip/VerifySingleBVN` or `GET /nip/name-enquiry` when credential available; fallback: delegates to `PaystackGateway.resolveAccount` / `FlutterwaveGateway.verifyAccount` behind same interface — seam proven without live NIBSS |
| Domain models | `PaymentInitializationRequest`, `PaymentInitializationResult`, `PaymentVerificationResult`, `TransferRequest`, `TransferResult`, `RefundRequest`, `RefundResult`, `NameEnquiryResult`, `WebhookEvent` — pure Dart, `kobo/cents` normalization internal, amount exposed as `Amount{valueMinor, currency}` |
| `PaymentGatewayConfig` | Typed config resolved from `EnvironmentConfig` via `EnvironmentValueSource` (`PAYSTACK_PUBLIC_KEY`, `PAYSTACK_SECRET_KEY`, `FLUTTERWAVE_PUBLIC_KEY`, `FLUTTERWAVE_SECRET_KEY`, `NIBSS_BASE_URL`, `NIBSS_API_KEY`, `PAYMENT_DEFAULT_PROVIDER`) — validated like `lib/config/environments/environment_loader.dart:40-53`, never hardcode |
| `PaymentGatewayFactory` / `PaymentGatewayRegistry` | `factory.get(PaymentProvider.paystack)` / `registry.resolve(currency, region, featureFlags)` — select adapter without `systems/finance/` knowing concrete type; env-driven default (`payment_default_provider`) |
| Error normalization | All `DioException` → `ApiException` via `lib/core/api/exceptions/api_exception_mapper.dart:15` (`401→auth PLT001`, `403→forbidden PLT002`, `400/422→validation PLT003`, `404→notFound PLT004`, `409→conflict PLT005`, `5xx→server PLT999`), plus provider-specific `status:false` envelope mapped to `validation`/`server` without leaking stack |
| Barrel + DI pattern | `lib/integrations/payment_gateways/payment_gateways.dart` barrel; constructor injection of `Dio` + `ApiExceptionMapper` + `PaymentGatewayConfig` (no `SupabaseClientProvider` singleton inside adapter — testable), optional `Provider<PaymentGateway>` registration |
| Tests | Unit tests with `Dio` `HttpClientAdapter` mock / `dio_mock_adapter` pattern, no live provider keys |

## 4. Out of Scope

| Out of Scope | Reason / Owner |
|---|---|
| `supabase/migrations/*` DDL for financial ledger | `EP-02-04` owns 11 financial tables + double-entry RPCs — this task is `lib/` only |
| `lib/systems/finance/` providers, repositories, escrow/payout business logic | `EP-02-13,14,15,16` consume this abstraction; do not build finance orchestration here (would violate interface-first validation) |
| Supabase Edge Functions for payment webhooks / NIBSS callbacks | Edge runtime owns HMAC verification secret storage; this task defines `parseWebhookEvent` + `verifySignature` contract, not deployment |
| `lib/data/` DTOs/entities for financial ledger / escrow / payouts | `EP-02-04` schema-driven; provider models are separate integration-layer models |
| KYC provider integration `KycProvider` | `EP-02-11,12` seam — not payment gateway |
| UI widgets/screens (checkout, payout binding screens, deposit status) | No design tokens consumed; `AGENT.md:17` Rule 5 not applicable — pure integration layer |
| Direct `SupabaseClient` RPC for balance mutations | `EP-02-04` RPCs remain authoritative; gateway adapters move money with providers, ledger mutations stay server-side |
| Live provider credential provisioning / webhook URL registration | External infra; tests use sandbox header + mock |
| Currency conversion rate fetching / fee calc | `EP-02-15` — not gateway |

## 5. Recommended Technical Approach

### 5.1 Module Placement — `lib/integrations/payment_gateways/` vs `lib/core/api/`

`ARCHITECTURE.md:55-60` assigns `lib/core/api/` = transport (`Dio`, interceptors, `BaseApiService`, `SupabaseClient`) and `ARCHITECTURE.md:112-114` assigns `lib/integrations/payment_gateways/` = `Paystack, Flutterwave, NIBSS drivers`. Gateway adapters are **external platform adapters**, not core transport — they belong in `integrations/` with their own `Dio` instances (separate `baseUrl`, separate secret header, separate retry policy) rather than sharing `ApiLayer.dio` (`lib/core/api/api_initializer.dart:72`) which is Supabase-scoped. This enforces `systems/finance/` → `PaymentGateway` (abstract) → adapter (concrete), never `systems/finance/` → `Dio` directly.

### 5.2 Interface-First Design — Segregated Contracts

Two segregated abstractions (ISP) rather than one fat interface — single-responsibility and future provider may support only one:

```dart
// lib/integrations/payment_gateways/payment_gateway.dart
enum PaymentProvider { paystack, flutterwave }
enum PaymentStatus { pending, success, failed, abandoned, reversed }
enum TransferStatus { pending, success, failed, reversed }

abstract class PaymentGateway {
  PaymentProvider get provider;
  Future<PaymentInitializationResult> initializePayment(PaymentInitializationRequest request);
  Future<PaymentVerificationResult> verifyPayment(String reference); // provider ref or tx id
  Future<TransferResult> createTransfer(TransferRequest request);
  Future<TransferResult> verifyTransfer(String reference);
  Future<RefundResult> refundPayment(RefundRequest request);
  WebhookEvent parseWebhookEvent(Map<String, dynamic> rawBody, Map<String, String> headers);
  bool verifyWebhookSignature({required String rawBody, required String signatureHeader});
}

// lib/integrations/payment_gateways/name_enquiry_service.dart
abstract class NameEnquiryService {
  Future<NameEnquiryResult> verifyAccount({required String bankCode, required String accountNumber});
}
```

- Accepts/returns **provider-neutral domain models only** — no `PaystackTransactionDto` leaks. Adapters map internally.
- `verifyWebhookSignature` validates `x-paystack-signature = HMAC_SHA512(rawBody, secret)` and `verif-hash` for Flutterwave; mismatch throws `ApiExceptionKind.forbidden PLT002` — caller (Edge Function) fails closed.
- `NameEnquiryService` is separate so `EP-02-16` can inject a different NIBSS implementation without swapping the full payment gateway.

### 5.3 Domain Models — Provider-Neutral

```dart
// lib/integrations/payment_gateways/models/payment_models.dart
class Amount { final int minorUnits; final String currency; } // kobo/cents internally
class PaymentInitializationRequest {
  final Amount amount; final String email; final String reference; // idempotency key UUID
  final String callbackUrl; final Map<String,String>? metadata; final String? currency;
}
class PaymentInitializationResult { final String reference; final String authorizationUrl; final String accessCode; }
class PaymentVerificationResult { final String reference; final PaymentStatus status; final Amount amount; final String currency; final DateTime? paidAt; }
class TransferRequest { final Amount amount; final String recipientAccountNumber; final String recipientBankCode; final String reference; final String reason; }
class TransferResult { final String reference; final TransferStatus status; final Amount amount; }
class RefundRequest { final String transactionReference; final Amount? amount; /* partial refund */ }
class NameEnquiryResult { final String accountNumber; final String accountName; final String bankCode; }
class WebhookEvent { final String provider; final String eventType; final String reference; final PaymentStatus status; }
```

- Amount is always `minorUnits` (kobo/pesewas/cents) + `currency` — adapter converts Paystack `amount: 500000` (kobo) and Flutterwave `amount: 5000` (NGN) to single representation, preventing 100× bugs.
- `reference` is idempotency key (UUID v4 via `uuid: ^4.5.1` `pubspec.yaml:71`) generated by caller / factory, never provider-generated alone.

### 5.4 Adapter Implementation — `PaystackGateway` / `FlutterwaveGateway`

Pattern mirrors `lib/core/api/services/base_api_service.dart:33` `invoke` + `lib/core/api/exceptions/api_exception_mapper.dart:18`:

`lib/integrations/payment_gateways/paystack_gateway.dart`:
1. **Ctor:** `PaystackGateway({required Dio dio, required ApiExceptionMapper mapper, required PaymentGatewayConfig config})` — `dio.options.baseUrl = 'https://api.paystack.co'`, default headers `Authorization: Bearer ${config.paystackSecretKey}`, `Content-Type: application/json`. Not `ApiLayer.dio` (Supabase baseUrl) — own instance via `ApiClientFactory.create` (`lib/core/api/api_client/api_client_factory.dart:14`) or direct `Dio(BaseOptions(...))` with timeouts from `ApiConfig.forEnvironment`.
2. **Initialize:** `POST /transaction/initialize` body `{email, amount: minorUnits, reference, callback_url, metadata}` → response `{status:true, data:{authorization_url, access_code, reference}}`. On `status:false` → map `message` to `ApiExceptionKind.validation` with `code: PLT003`. Use `invoke(() => dio.post(...))` so `DioException` normalizes.
3. **Verify:** `GET /transaction/verify/{reference}` → `{data: {status: 'success'|'failed'|'abandoned', amount, currency, paid_at}}` → `PaymentVerificationResult`.
4. **Transfer:** `POST /transfer` with `source: balance`, `reason`, `amount`, `recipient` (requires `transferrecipient` creation — adapter hides: first `POST /transferrecipient {type:'nuban', name, account_number, bank_code, currency}` then `POST /transfer {source:'balance', amount, recipient: recipient_code, reference}`) — unified behind `createTransfer`.
5. **Name enquiry (also via gateway but primary is `NameEnquiryService`):** `GET /bank/resolve?account_number=...&bank_code=...` → `{data: {account_name, account_number}}`.
6. **Refund:** `POST /refund {transaction: reference, amount?, merchant_note}`.
7. **Webhook:** `parseWebhookEvent` inspects `rawBody['event']` (`charge.success`, `transfer.success`) + signature verify `Hmac(sha512, config.paystackSecretKey)`.

`lib/integrations/payment_gateways/flutterwave_gateway.dart`:
- `POST /v3/charges?type=card` (or `bank_transfer`/`account` per `metadata.chargeType`) body differs — adapter normalizes to one `initializePayment` shape, defaulting to `bank_transfer` for marketplace funding.
- `GET /v3/transactions/{id}/verify` and `POST /v3/transfers` → `POST /v3/accounts/resolve` body `{account_number, account_bank}` → `NameEnquiryResult`.

- Neither adapter exposes provider DTOs; tests assert no `Paystack*Dto` type import in `systems/finance/`.

### 5.5 NIBSS Name Enquiry — Dedicated Service

`lib/integrations/payment_gateways/nibss_name_enquiry_adapter.dart`:

```dart
class NibssNameEnquiryAdapter implements NameEnquiryService {
  NibssNameEnquiryAdapter({required Dio dio, required PaymentGatewayConfig config, this.fallback});
  final NameEnquiryService? fallback; // Paystack resolve when NIBSS unavailable
  @override Future<NameEnquiryResult> verifyAccount({required String bankCode, required String accountNumber}) async {
    try { // try NIBSS direct: dio.post('${config.nibssBaseUrl}/nip/name-enquiry', ...)
    } on ApiException catch (_) { if (fallback != null) return fallback!.verifyAccount(...); rethrow; }
  }
}
```

- Direct NIBSS is deferred (credential may not exist at EP-02-09) — fallback ensures `EP-02-16` still validates via Paystack/Flutterwave resolve without code change.
- Input validation: `accountNumber` must be `^\d{10}$` (NUBAN) — fail fast `ApiExceptionKind.validation PLT003` before network, same envelope as server `legal_name` checks.

### 5.6 Configuration — `PaymentGatewayConfig`

`lib/integrations/payment_gateways/payment_gateway_config.dart`:

```dart
class PaymentGatewayConfig {
  final String paystackPublicKey, paystackSecretKey, flutterwavePublicKey, flutterwaveSecretKey;
  final String? nibssBaseUrl, nibssApiKey;
  final PaymentProvider defaultProvider;
  static PaymentGatewayConfig fromEnvironment(EnvironmentValueSource source) { ... }
}
```

- Resolved via `EnvironmentLoader` pattern (`lib/config/environments/environment_loader.dart:40`) — strict `validateUrl` for baseUrls, placeholder detection via `_isPlaceholder` (`environment_loader.dart:229`), service-role rejection not needed but secret emptiness throws `EnvironmentConfigException`.
- `PaymentGatewayConfig.fromEnvironment` never logs secret values; `toString` redacts (`[redacted]`) like `SupabaseConfig.toString` (`lib/config/environments/environment_config.dart:27`).

### 5.7 Factory / Registry

`lib/integrations/payment_gateways/payment_gateway_factory.dart`:

```dart
class PaymentGatewayFactory {
  const PaymentGatewayFactory({required PaymentGatewayConfig config, required ApiExceptionMapper mapper});
  PaymentGateway create(PaymentProvider provider) => switch(provider) {
    PaymentProvider.paystack => PaystackGateway(dio: _dioFor(provider), mapper: mapper, config: config),
    PaymentProvider.flutterwave => FlutterwaveGateway(...),
  };
  PaymentGateway resolveForCurrency(String currency, {String? region}) { // NGN → paystack, GHS → flutterwave fallback
    if (currency == 'NGN' && config.paystackSecretKey.isNotEmpty) return create(PaymentProvider.paystack);
    return create(PaymentProvider.flutterwave);
  }
}
```

- No singleton global — factory is injected, supports per-environment provider enablement.
- `resolveForCurrency` is the extension point for EP-08 `Thunes`/`stablecoin` — new enum value + branch, zero `systems/finance/` change.

### 5.8 Exceptions & Logging

- New `lib/integrations/payment_gateways/payment_gateway_exception.dart` extends `ApiException` (or reuses it) — provider `status:false` maps to `ApiExceptionKind` via `ApiExceptionMapper._mapResponse` (`lib/core/api/exceptions/api_exception_mapper.dart:26`) or direct `ApiException` construction for provider logical errors (HTTP 200 but `status:false`).
- Use `lib/core/logging/hivorr_logger.dart` + `lib/core/logging/pii_redactor.dart` — log `provider`, `reference` (redacted to last 4), `amount.minorUnits`, `currency`; never log `secretKey`, `accountNumber` full, or raw `accountName` beyond verification result handling.
- Monitoring span via `lib/core/monitoring/monitoring_service.dart` — `payment.initialize.duration`, `payment.verify.duration`, `name_enquiry.duration`.

### 5.9 Dependency Wiring

- Production: `final cfg = PaymentGatewayConfig.fromEnvironment(CompileTimeEnvironmentValueSource()); final factory = PaymentGatewayFactory(config: cfg, mapper: const ApiExceptionMapper()); final gateway = factory.resolveForCurrency('NGN');`
- Tests: inject `Dio(BaseOptions())..httpClientAdapter = MockAdapter()` + fake `PaymentGatewayConfig` with `sk_test_...` placeholders; no `SupabaseClientProvider.client` (`lib/core/api/supabase/supabase_client_provider.dart:19`) needed — gateway is pure `Dio`.

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| `PaymentGateway` abstract | `lib/integrations/payment_gateways/payment_gateway.dart` | **Create** — contract §5.2 |
| `NameEnquiryService` abstract | `lib/integrations/payment_gateways/name_enquiry_service.dart` | **Create** — contract §5.2 |
| Domain models | `lib/integrations/payment_gateways/models/payment_models.dart` | **Create** — Amount, requests/results, WebhookEvent |
| `PaystackGateway` | `lib/integrations/payment_gateways/paystack_gateway.dart` | **Create** — impl §5.4 |
| `FlutterwaveGateway` | `lib/integrations/payment_gateways/flutterwave_gateway.dart` | **Create** — impl §5.4 |
| `NibssNameEnquiryAdapter` | `lib/integrations/payment_gateways/nibss_name_enquiry_adapter.dart` | **Create** — impl §5.5 with fallback |
| `PaymentGatewayConfig` | `lib/integrations/payment_gateways/payment_gateway_config.dart` | **Create** — ENV resolution §5.6 |
| `PaymentGatewayFactory` / `PaymentGatewayRegistry` | `lib/integrations/payment_gateways/payment_gateway_factory.dart` | **Create** — factory §5.7 |
| `PaymentGatewayException` (optional) | `lib/integrations/payment_gateways/payment_gateway_exception.dart` | **Create** — typed extension of `ApiException` if provider-specific codes needed |
| Barrel | `lib/integrations/payment_gateways/payment_gateways.dart` | **Update** — export all symbols (currently only `.gitkeep`) |
| No `supabase/migrations/*` | `supabase/migrations/` | **No change** — no financial DDL |
| No `lib/systems/finance/*` | `lib/systems/finance/.gitkeep` | **No change** — consumers only after this task |
| Tests + mocks | `test/unit/integrations/payment_gateways/*` | **Create** — see §14 |

**No new `public.*` tables, no RPCs, no Edge Functions, no UI widgets.**

## 7. Data Requirements

### 7.1 Payment Initialization

| Field | Type | Validation | Notes |
|---|---|---|---|
| `amount.minorUnits` | `int` | `>0`, `<= 99_999_999_00` (NGN 99M cap Paystack) | Normalized — adapter sends `minorUnits` to Paystack, `value = minorUnits/100` to Flutterwave where required |
| `amount.currency` | `String` | `NGN\|GHS\|USD\|GBP` (`EP-02:189` 4-currency) | NGN default; GHS/USD via Flutterwave; GBP future |
| `email` | `String` | RFC 5322 | Payer email for Paystack `customer.email` |
| `reference` | `String` | UUID v4, `^[a-zA-Z0-9-_]{8,64}$` | Idempotency key — caller-generated, echoed in `verifyPayment` |
| `callbackUrl` | `String` | HTTPS, not loopback unless `isDevelopment` | Provider redirect after 3DS |
| `metadata` | `Map<String,String>?` | max 10 keys, 500 char values | `entity_id`, `escrow_id`, `purpose` |

Response: `authorizationUrl` (Paystack) / `link` (Flutterwave), `accessCode`, echoed `reference` — stored for verification.

### 7.2 Verification / Transfer / Refund

- `verifyPayment(reference)` → `PaymentVerificationResult{reference, status, amount, currency, paidAt, gatewayFee?}` — fee extracted from `data.fees` (Paystack) for audit trail input to `EP-02-04` ledger (not ledger mutation here).
- `createTransfer(TransferRequest{amount, recipientAccountNumber(10-digit NUBAN), recipientBankCode(3-digit CBN code), reference, reason})` → `TransferResult{reference, status: pending|success, amount}` — bank code catalog from `paystack.co/bank` / Flutterwave `/v3/banks/NG`; validate code exists via allowlist or live `GET /bank` cache.
- `refundPayment(RefundRequest{transactionReference, amount?})` → partial refund if `amount < original`, full if `null`.
- `verifyAccount(bankCode, accountNumber)` → `NameEnquiryResult{accountName}` — name compared server-side in `EP-02-16` against `entity_profiles.legal_name` (`EP-02:199` anchor), not within adapter beyond returning.

### 7.3 Webhook Event

`WebhookEvent{provider, eventType: 'charge.success'|'transfer.success'|'charge.failed', reference, status, raw}` — parsed without trusting `status` for ledger; verification status re-fetched via `verifyPayment`/`verifyTransfer` before any business action (webhook is notification, verify is truth).

### 7.4 Bank Catalog (auxiliary)

Cached `GET /bank` (Paystack) / `GET /v3/banks/NG` (Flutterwave) → `List<Bank{code,name}>` — TTL 24h, used to validate `bankCode` client-side before `createTransfer`/`verifyAccount`; falls back to network if stale.

## 8. Database Considerations

- **Schema boundary:** Financial ledger `financial_transactions`/`financial_escrow`/`financial_balances` lives in `public` (`EP-02-04` 11 tables, double-entry, server-side RPC only `EP-02:40,195`). This task performs **zero DDL** on `public.*` or `storage.*` — no migration, no RLS, no trigger, no `GRANT`.
- **No direct DB access:** Adapters are HTTP-only (`Dio` to provider baseUrl) — never `SupabaseClient.from('financial_transactions')` or `supabase.rpc`. Ledger mutations are `EP-02-04` RPCs (`financial_*`); this task only moves money externally.
- **Future integration point:** `EP-02-13/14` will call `PaymentGateway.initializePayment` client-side to get `authorizationUrl`, then on `verifyPayment → success` call `supabase.rpc('financial_deposit_record', ...)` / `financial_escrow_fund` server-side. The gateway result `reference` becomes the provider `external_reference` in `financial_deposits.external_reference` — correlation, not duplication.
- **Idempotency:** Provider `reference` is the shared idempotency key. If adapter retries `initializePayment` with same `reference`, Paystack returns `409` mapped to `ApiExceptionKind.conflict PLT005` — caller treats as already-initialized, not duplicate charge.
- **Audit:** No audit trail in this task — `financial_audit_trail` (`EP-02-04`) is written by financial RPCs, not gateway adapters.

If applicable — none beyond boundary statement; no migrations produced.

## 9. API Requirements

### 9.1 Provider HTTP Contracts (via `Dio` adapters)

| Operation | Gateway | Method & Path | Auth | Success | Error Shape |
|---|---|---|---|---|---|
| Initialize payment | Paystack | `POST https://api.paystack.co/transaction/initialize` | `Authorization: Bearer sk_...` | `200 {status:true, message, data:{authorization_url, access_code, reference}}` | `200 {status:false, message}` → `PLT003` |
| Verify payment | Paystack | `GET https://api.paystack.co/transaction/verify/:reference` | same | `200 {status:true, data:{reference, status, amount, currency, paid_at, gateway_response}}` | `404` → `notFound PLT004` |
| Create recipient + Transfer | Paystack | `POST https://api.paystack.co/transferrecipient` then `POST https://api.paystack.co/transfer {source, amount, recipient: recipient_code, reference}` | same | `200 {status:true, data:{reference, status, amount}}` | `400 insufficient balance` → `validation PLT003` |
| Resolve account | Paystack | `GET https://api.paystack.co/bank/resolve?account_number=...&bank_code=...` | same | `200 {status:true, data:{account_name, account_number}}` | `400 invalid` → `PLT003` |
| Refund | Paystack | `POST https://api.paystack.co/refund {transaction, amount?, merchant_note}` | same | `200 {status:true, data:{status}}` | — |
| Initialize charge | Flutterwave | `POST https://api.flutterwave.com/v3/charges?type=bank_transfer` body `{tx_ref, amount, currency, email, redirect_url}` | `Authorization: Bearer FLWSECK_...` | `200 {status:success, data:{id, tx_ref, flw_ref, link}}` | `400 {status:error}` → `PLT003` |
| Verify transaction | Flutterwave | `GET https://api.flutterwave.com/v3/transactions/:id/verify` | same | `200 {status:success, data:{tx_ref, status:successful\|failed, currency, amount}}` | `404` → `PLT004` |
| Create transfer | Flutterwave | `POST https://api.flutterwave.com/v3/transfers {account_bank, account_number, amount, currency, reference, callback_url}` | same | `200 {status:success, data:{id, reference, status}}` | — |
| Verify account | Flutterwave | `POST https://api.flutterwave.com/v3/accounts/resolve {account_number, account_bank}` | same | `200 {status:success, data:{account_name, account_number}}` | — |
| Refund | Flutterwave | `POST https://api.flutterwave.com/v3/transactions/:id/refund {amount?}` | same | `200 {status:success, data:{wallet_id}}` | — |
| List banks | Both | `GET https://api.paystack.co/bank` / `GET https://api.flutterwave.com/v3/banks/NG` | same | `200 [...]` | — |

All calls go through adapter-constructed `Dio` (baseUrl provider-specific, timeouts `ApiConfig.forEnvironment` `lib/core/api/api_config.dart:40`) + `invoke` wrapper (`lib/core/api/services/base_api_service.dart:33` pattern) → `ApiExceptionMapper.map` (`lib/core/api/exceptions/api_exception_mapper.dart:18`) for transport → `200 status:false` logical error mapped manually to `ApiExceptionKind.validation/server`.

### 9.2 No Supabase REST / RPC

No `supabase.rpc('...')` (`EP-02-04` RPCs) in this task. `SupabaseClientProvider.client` (`lib/core/api/supabase/supabase_client_provider.dart:19`) is not imported by adapters.

### 9.3 Webhook Signature Contract

`verifyWebhookSignature` pure function (no network):
- Paystack: `hmacSha512 = HMAC_SHA512(secretKey, rawBody); signatureHeader == 'sha512=' + hex(hmacSha512)` (or header `x-paystack-signature`).
- Flutterwave: `header['verif_hash'] == config.flutterwaveSecretKey` or `hmacSha256(rawBody, secret)` per provider docs — document chosen verification in adapter dartdoc.

### 9.4 Error Contract

Every public method throws only `ApiException` (`ApiExceptionKind` `lib/core/api/exceptions/api_exception.dart:6` + `code PLT001/002/003/004/005/999` + `statusCode`) or `ApiInitializationException` (`lib/core/api/exceptions/api_exception.dart:72`) when `PaymentGatewayConfig` missing. Never raw `DioException`, never provider JSON.

## 10. User Interface Requirements

**None.** This task produces no widgets, screens, or design tokens — identical to `EP-02-08:10` storage service. All downstream UI (`EP-02-13` financial profile, `EP-02-14` escrow, `EP-02-16` payout) that consumes this gateway must consume `AppTheme` tokens per `documents/Context/AGENT.md:17` Rule 5 (`VISUAL-IDENTITY.md:42-44`), but no UI is introduced here so no token consumption and no `shared/widgets/` changes. `VISUAL-IDENTITY.md:176-190` anti-patterns not applicable.

## 11. User Experience Considerations

While the gateway is invisible to users, it shapes downstream UX in `EP-02-13/14/16`:

- **Fail-fast validation:** `PaymentGatewayConfig` missing or `amount.minorUnits <=0` or `accountNumber` not `^\d{10}$` throws `ApiExceptionKind.validation PLT003` before network — upstream forms show inline field error ("Account number must be 10 digits") rather than opaque provider `400` after 2s.
- **Unified status UX:** Provider `success`/`failed`/`abandoned`/`successful` mapped to `PaymentStatus success|failed|pending|abandoned` — screens show single `HivorrErrorState`/`HivorrSuccessState` pair, not per-provider branches.
- **Reference idempotency feedback:** Duplicate `reference` `409→conflict PLT005` surfaced as "Payment already initialized — check pending transactions" with action to `verifyPayment`, not retry-charge-duplicate.
- **Webhook vs verification truth:** Docs call out that webhook `charge.success` is notification only — UI must await `verifyPayment` poll (`pending → success`) before showing "Funds received" to prevent spoofed webhook optimism.
- **Bank list caching UX:** `GET /bank` 24h cache prevents bank dropdown spinner on every payout screen open; offline stale cache still renders list on flaky Nigerian networks.

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Secret key isolation `ENV-002, ENV-006, ENV-008` | Keys sourced only from `EnvironmentValueSource` (`PAYSTACK_SECRET_KEY`, `FLUTTERWAVE_SECRET_KEY`, `NIBSS_API_KEY`) — never `String.fromEnvironment` inline in adapters. `EnvironmentLoader._validateAnonKey` pattern (`lib/config/environments/environment_loader.dart:167`) extended to reject empty/placeholder secrets (`_isPlaceholder` `229`). `PaymentGatewayConfig.toString` redacts secrets like `SupabaseConfig.toString` `lib/config/environments/environment_config.dart:27`. |
| No `service_role` or provider secret in logs/bundle | `pii_redactor` (`lib/core/logging/pii_redactor.dart`) + `DeveloperLogSink` (`lib/core/api/logging/api_log_sink.dart`) — log `provider`, `reference` suffix, `amount.minorUnits`, `currency`; never log header `Authorization`, `accountName`, raw `rawBody`. `dio` `LoggingInterceptor` (`lib/core/api/api_client/logging_interceptor.dart`) excludes `Authorization` header. |
| Webhook HMAC verification | `verifyWebhookSignature` computed server-side in Edge Function using raw body bytes — client adapter exposes pure verifier for Edge reuse, never trusts `X-Signature` from inbound JSON alone. Mismatch → `ApiExceptionKind.forbidden PLT002` fail-closed; no business state change on unverified webhook. |
| PCI / card data | Adapter never handles raw PAN/CVV — initialization redirects to provider `authorizationUrl` / `link` (hosted checkout). `EP-02:154-156` Paystack/Flutterwave are PCI-DSS level 1; client holds no card scope. |
| Account number PII | `verifyAccount` input `accountNumber` logged as `***${last4}` only; `accountName` result is not persisted by adapter — `EP-02-16` passes it to server RPC for `legal_name` comparison, not local storage. `flutter_secure_storage: 11.0.0` (`pubspec.yaml:56`) not used for gateway (secrets are env, not secure storage). |
| No `public.*` grant drift | No `GRANT` on `public.*` or `storage.*` — adapters are HTTP clients. Full pgTAP suite `001–017` regression must stay green — no new `SECURITY DEFINER` introduced. |
| Transport security | `Dio` `BaseOptions` enforces `https` only for provider baseUrls (Paystack `https://api.paystack.co`, Flutterwave `https://api.flutterwave.com`, NIBSS `https://` ) — `EnvironmentLoader._validateUrl` (`environment_loader.dart:127`) pattern reused for NIBSS URL; non-HTTPS throws `EnvironmentConfigException`. `SecurityConfig` (`lib/config/environments/security_config.dart`) pinning applied via `ApiClientFactory.create` `baseUrl`. |
| Rate limiting / idempotency | `reference` UUID prevents double-charge on retry; `RetryInterceptor` (`lib/core/api/api_client/retry_interceptor.dart`) maxRetries `ApiConfig.maxRetries` `lib/core/api/api_config.dart:45` but adapter disables retry on `4xx` (validation/notFound/conflict) — only `5xx`/`timeout` (`PLT999`) retried with `baseRetryDelay 500ms` / `maxRetryDelay 8s`. |
| Injection | No dynamic SQL — provider paths are constants + parameterized `Dio` `pathParams`; bankCode/accountNumber validated regex before interpolation; never `query?account_number=${unsanitized}` raw. |
| ENV isolation | `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) drives `ApiConfig.forEnvironment` timeouts/retries and `PaymentGatewayConfig` sandbox vs live keys (`sk_test` vs `sk_live` / `FLWSECK_TEST`). Development loopback HTTP exception (`environment_loader.dart:146`) applies only to Supabase URL, not provider URLs — provider always HTTPS even in dev. |

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Separate `Dio` per provider | Paystack and Flutterwave get own `Dio` instance (`baseUrl` distinct, connection pool distinct) — no cross-provider header leakage, no Supabase baseUrl contamination (`ApiLayer.dio` `lib/core/api/api_initializer.dart:72` is Supabase-only). Timeouts `ApiConfig` `connect 15s, receive 30s, send 30s` `lib/core/api/api_config.dart:42-44` suitable for Nigerian mobile — slow 3G still completes, fast Wi-Fi not penalized. |
| No retry storm | `4xx` (`PLT003/004/005`) not retried; only `5xx`/`timeout` retried 3( prod)/4(dev) times with exponential backoff `500ms→8s` (`ApiConfig`). Idempotency `reference` ensures retried `initializePayment` is safe (Paystack returns existing). |
| Bank catalog cache | `GET /bank` 24h in-memory `CacheManager` (`lib/core/cache/cache_manager.dart:69`) — single fetch per app session, avoids per-screen network for payout binding dropdown. |
| Amount normalization zero-cost | `minorUnits` int arithmetic (`lib/core/api/api_config` no float) avoids `double` rounding; conversion `amountNGN *100` inside adapter is `int` only. |
| Webhook parse sync | `parseWebhookEvent` + `verifyWebhookSignature` are pure HMAC + JSON decode — `O(n)` on body length (<10KB), microseconds, no I/O. |
| Tracer overhead | `PerformanceTracer` span (`lib/core/monitoring/performance_tracer.dart`) around `initialize/verify/transfer` sampled via `MonitoringConfig`, tag `payment.provider`, `payment.status`, no PII. |

## 14. Testing Strategy

### 14.1 Unit Suite — `test/unit/integrations/payment_gateways/`

Pattern mirrors `test/support/fakes/fake_storage.dart:9` + `test/unit/core/api/api_exception_mapper_test.dart` — no live provider, `Dio` mocked via `http_mock_adapter` / `MockHttpClientAdapter` stubbing `DioAdapter`.

| File | Cases (min) | Method |
|---|---|---|
| `payment_gateway_config_test.dart` | 12 | `fromEnvironment` reads `PAYSTACK_SECRET_KEY` etc. from `MapEnvironmentValueSource` (`lib/config/environments/environment_value_source.dart`), rejects empty/placeholder (`_isPlaceholder`), rejects non-HTTPS NIBSS URL, redacts `toString` (`[redacted]`), defaults `payment_default_provider=paystack` |
| `paystack_gateway_test.dart` | 24 | Mock `Dio` stub `POST /transaction/initialize → {status:true, data:{authorization_url:'https://checkout.paystack.com/...'}}` success; `status:false` → `ApiExceptionKind.validation PLT003`; `GET /transaction/verify/REF → {data:{status:'success', amount:500000, currency:'NGN'}}` → `PaymentStatus.success` + amount 500000 minorUnits; `GET /bank/resolve?account_number=0123456789&bank_code=058 → {data:{account_name:'DOE JOHN'}}`; `Hmac verify` valid/invalid signature; `createTransfer` recipient+transfer 2-step order asserted via call spy; error mapping 401→`auth PLT001`, 403→`forbidden PLT002`, 404→`notFound PLT004`, 409→`conflict PLT005`, 500→`server PLT999`; invalid `accountNumber` (9 digits) fails before `dio` spy not called |
| `flutterwave_gateway_test.dart` | 20 | `POST /v3/charges → {status:'success', data:{link:'https://checkout.flutterwave.com/...', tx_ref}}`; `GET /v3/transactions/123/verify → {status:'success', data:{status:'successful'}}` → `PaymentStatus.success`; `POST /v3/accounts/resolve {account_number, account_bank} → {data:{account_name}}`; `POST /v3/transfers → {data:{reference}}`; verify signature `verif-hash`; amount conversion kobo↔NGN asserted (500000→5000) |
| `nibss_name_enquiry_adapter_test.dart` | 10 | Direct NIBSS `POST /nibss/nip/name-enquiry → {accountName:'DOE JOHN'}` success; fallback to `PaystackGateway` when NIBSS 500; invalid NUBAN throws `validation` before network |
| `payment_gateway_factory_test.dart` | 8 | `factory.create(PaymentProvider.paystack) is PaystackGateway`; `resolveForCurrency('NGN') → PaystackGateway`, `resolveForCurrency('GHS') → FlutterwaveGateway`, `resolveForCurrency('USD') → FlutterwaveGateway`; missing secret for NGN fallback to Flutterwave; registry memoization not leaking provider type to caller (returns `PaymentGateway`) |
| `webhook_event_test.dart` | 6 | Paystack `event:'charge.success', data:{reference, status}` → `WebhookEvent(provider:paystack, eventType:charge.success, status:success)`; Flutterwave `event:'transfer.completed'`; signature valid/invalid; raw body JSON parse error → `validation PLT003` |

Target **≥80 unit assertions**; coverage of adapters ≥90%, config/factory 100%, models 100%.

### 14.2 Mock — `test/support/mocks/mock_dio_adapter.dart`

Thin wrapper around `Dio` `HttpClientAdapter` delivering canned `ResponseBody.fromString(jsonEncode({...}), 200, headers:{'content-type':['application/json']})`; records `RequestOptions` for spy assertions (`capturedAuthorizationHeader == 'Bearer sk_test_...'`, `capturedBaseUrl == 'https://api.paystack.co'`). No `supabase_flutter` mock needed.

### 14.3 Adapter Abstraction Proof

Single test asserts `PaystackGateway implements PaymentGateway` and `FlutterwaveGateway implements PaymentGateway` share identical `PaymentGateway` method signatures, and that no file in `lib/systems/finance/.gitkeep` imports `paystack_gateway.dart` or `flutterwave_gateway.dart` (import ban verified via `grep -r "paystack\|flutterwave" lib/systems` = 0). This validates provider-agnostic guarantee `EP-02:172`.

### 14.4 No Provider E2E in This Task

Live `paystack test` / `flutterwave sandbox` E2E (real `POST /transaction/initialize` with `sk_test`) is deferred to `EP-02-13/14/16` integration tests that compose gateway with financial RPCs. EP-02-09 unit suite is sufficient seam validation. Full `flutter test` + `supabase db test` (`001–017`) must remain green — no `public.*` RLS regression.

### 14.5 Lens Summary (for review tooling)

`flutter test --coverage` + `supabase db test` — zero regressions on `public.*` posture. Add `test/support/mocks/mock_dio_adapter.dart` export.

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Inspect `lib/integrations/payment_gateways/.gitkeep`, `lib/core/api/services/base_api_service.dart:15`, `lib/core/api/exceptions/api_exception*.dart`, `lib/core/api/api_client/api_client_factory.dart:14`, `lib/config/environments/environment_loader.dart:40`, `lib/config/environments/environment_config.dart:17`, `pubspec.yaml:43-71` | Baseline |
| 2 | Draft `lib/integrations/payment_gateways/models/payment_models.dart` — `Amount`, `PaymentInitializationRequest/Result`, `PaymentVerificationResult`, `TransferRequest/Result`, `RefundRequest/Result`, `NameEnquiryResult`, `WebhookEvent`, `PaymentProvider/Status` enums | Domain models |
| 3 | Create `lib/integrations/payment_gateways/payment_gateway_exception.dart` (or reuse `ApiException`) — `PLT001/002/003/004/005/999` mapping helpers | Errors |
| 4 | Create `lib/integrations/payment_gateways/payment_gateway.dart` — abstract `PaymentGateway` (§5.2) | Contract |
| 5 | Create `lib/integrations/payment_gateways/name_enquiry_service.dart` — abstract `NameEnquiryService` | Contract |
| 6 | Create `lib/integrations/payment_gateways/payment_gateway_config.dart` — `fromEnvironment(EnvironmentValueSource)`, validation, redacted `toString` | Config |
| 7 | Create `lib/integrations/payment_gateways/paystack_gateway.dart` — `Dio` init, `invoke` + `ApiExceptionMapper`, 6 methods + HMAC (§5.4) | Adapter 1 |
| 8 | Create `lib/integrations/payment_gateways/flutterwave_gateway.dart` — same pattern, amount unit conversion + `charges`/`transfers` (§5.4) | Adapter 2 |
| 9 | Create `lib/integrations/payment_gateways/nibss_name_enquiry_adapter.dart` — direct NIBSS + fallback (§5.5) | Adapter 3 |
| 10 | Create `lib/integrations/payment_gateways/payment_gateway_factory.dart` — factory/registry `create` + `resolveForCurrency` (§5.7) | Factory |
| 11 | Update `lib/integrations/payment_gateways/payment_gateways.dart` barrel (`export 'payment_gateway.dart'`, `export 'name_enquiry_service.dart'`, `...`) | Barrel |
| 12 | Create `test/support/mocks/mock_dio_adapter.dart` — canned `HttpClientAdapter` with spy capture | Test infra |
| 13 | Create `test/unit/integrations/payment_gateways/payment_gateway_config_test.dart` (12 cases) | Tests 1 |
| 14 | Create `test/unit/integrations/payment_gateways/paystack_gateway_test.dart` (24 cases) | Tests 2 |
| 15 | Create `test/unit/integrations/payment_gateways/flutterwave_gateway_test.dart` (20 cases) | Tests 3 |
| 16 | Create `test/unit/integrations/payment_gateways/nibss_name_enquiry_adapter_test.dart` (10) + `payment_gateway_factory_test.dart` (8) + `webhook_event_test.dart` (6) | Tests 4 |
| 17 | `flutter analyze` + `flutter test --coverage` (≥80 assertions green, adapter ≥90%) | Verify |
| 18 | `supabase db test` full suite `001–017` green (no regression) + `grep -r "paystack\|flutterwave" lib/systems` = 0 (abstraction proof) + `grep -r "service_role\|sk_live" lib/integrations` = 0 (secret leak check) | Regression |
| 19 | Doc pass: dartdoc on `PaymentGateway` contract, HMAC verification, `Amount` minorUnits note, `resolveForCurrency` extensibility note | Docs |
| 20 | Tag `EP-02-13,14,15,16` unblocked in phase plan | Handoff |

## 16. Expected Outcome

- `lib/integrations/payment_gateways/` provides a **provider-agnostic, interface-first** financial integration seam — `systems/finance/` imports only `PaymentGateway`/`NameEnquiryService`/`PaymentGatewayFactory`, never `PaystackGateway`/`FlutterwaveGateway` directly (`ARCHITECTURE.md:151-152` compliant).
- `PaystackGateway` and `FlutterwaveGateway` each fully implement the 6-method contract over provider-specific `Dio` instances (`baseUrl` + `Bearer` secret + timeouts from `ApiConfig` `lib/core/api/api_config.dart:40`) with identical `ApiException` error envelope (`PLT001/002/003/004/005/999` via `ApiExceptionMapper` `lib/core/api/exceptions/api_exception_mapper.dart:18`).
- Amounts unified as `Amount{minorUnits, currency}` (kobo/pesewas/cents) — internal conversion prevents 100× mismatch between Paystack (kobo) and Flutterwave (major units).
- `NibssNameEnquiryAdapter` implements `NameEnquiryService` with direct NIBSS primary + Paystack/Flutterwave resolve fallback, proving `EP-02-16` name-matching (`AGENT.md:7` Rule 3) can be built without live NIBSS at `EP-02-09`.
- `PaymentGatewayConfig.fromEnvironment` sources secrets from `EnvironmentValueSource` (`lib/config/environments/environment_value_source.dart`) with placeholder/empty validation + redacted `toString` — no secret in logs, bundle, or `git`.
- `PaymentGatewayFactory.resolveForCurrency` selects adapter per currency/region — adding `Thunes`/`mobile money` (`EP-02:197`) is a single enum branch, zero `systems/` change (Open/Closed for EP-08).
- Webhook parsing + HMAC verification are pure, provider-neutral `WebhookEvent` — Edge Function can reuse without business-logic coupling.
- Unit suite ≥80 assertions green with mocked `Dio`; `flutter analyze` clean; full pgTAP `001–017` green; `grep` proves no provider import in `systems/` and no secret leakage.
- `EP-02-13,14,15,16` unblocked — financial integrity systems have the integration seam required before ledger + escrow + payout implementation.

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | `lib/integrations/payment_gateways/payment_gateway.dart` exists — abstract `PaymentGateway` with `provider`, `initializePayment`, `verifyPayment`, `createTransfer`, `verifyTransfer`, `refundPayment`, `parseWebhookEvent`, `verifyWebhookSignature` | File inspection |
| 2 | `lib/integrations/payment_gateways/name_enquiry_service.dart` exists — abstract `NameEnquiryService.verifyAccount({bankCode, accountNumber}) → NameEnquiryResult` | File inspection |
| 3 | `lib/integrations/payment_gateways/models/payment_models.dart` defines `Amount`, `PaymentInitializationRequest/Result`, `PaymentVerificationResult`, `TransferRequest/Result`, `RefundRequest/Result`, `NameEnquiryResult`, `WebhookEvent`, `PaymentProvider`, `PaymentStatus`, `TransferStatus` | File + unit test |
| 4 | `lib/integrations/payment_gateways/paystack_gateway.dart` implements `PaymentGateway` — own `Dio` `baseUrl https://api.paystack.co`, `Authorization Bearer`, `invoke` + `ApiExceptionMapper`, 2-step `transferrecipient→transfer`, `bank/resolve`, HMAC `x-paystack-signature` | Code review + unit test |
| 5 | `lib/integrations/payment_gateways/flutterwave_gateway.dart` implements `PaymentGateway` — `baseUrl https://api.flutterwave.com`, `Authorization Bearer FLWSECK`, `POST /v3/charges`, `GET /v3/transactions/:id/verify`, `POST /v3/transfers`, `POST /v3/accounts/resolve`, amount unit conversion | File + unit test |
| 6 | `lib/integrations/payment_gateways/nibss_name_enquiry_adapter.dart` implements `NameEnquiryService` — direct NIBSS call when `nibssBaseUrl` present, fallback to `PaystackGateway`/`FlutterwaveGateway` resolve, NUBAN `^\d{10}$` validation before network | Unit test (fallback path) |
| 7 | `lib/integrations/payment_gateways/payment_gateway_config.dart` resolves from `EnvironmentValueSource` (`PAYSTACK_SECRET_KEY`, `FLUTTERWAVE_SECRET_KEY`, `NIBSS_BASE_URL`, `PAYMENT_DEFAULT_PROVIDER`), validates non-empty/non-placeholder (`_isPlaceholder` `environment_loader.dart:229`), validates HTTPS, redacts `toString` | Unit test + code review |
| 8 | `lib/integrations/payment_gateways/payment_gateway_factory.dart` defines `PaymentGatewayFactory.create(provider)` + `resolveForCurrency(currency)` | Unit test |
| 9 | `lib/integrations/payment_gateways/payment_gateways.dart` barrel re-exports all symbols (no stale `.gitkeep` only) | File inspection |
| 10 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat` shows only `lib/integrations/payment_gateways/*` + `test/**` | `git diff --stat` |
| 11 | No `lib/systems/finance/*` changes — `git diff --stat lib/systems` = 0 | `git diff --stat` |
| 12 | No provider-specific type leaks — `grep -r "PaystackGateway\|FlutterwaveGateway" lib/systems` = 0, `lib/systems/finance/` imports only `payment_gateway.dart`/`name_enquiry_service.dart`/`payment_gateway_factory.dart` | `grep` |
| 13 | No secret leakage — `grep -r "sk_live\|sk_test\|FLWSECK\|Authorization: Bearer" lib/integrations/payment_gateways` only via `config.paystackSecretKey` variable, no hard-coded key literal; `grep -r "service_role" lib/` = 0 | `grep` + code review |
| 14 | Error normalization — `401→auth PLT001`, `403→forbidden PLT002`, `400/422 status:false→validation PLT003`, `404→notFound PLT004`, `409→conflict PLT005`, `5xx→server PLT999` via `ApiExceptionMapper` + logical-error branch; raw `DioException` never propagates | Unit test |
| 15 | Webhook HMAC verification implemented — Paystack `HMAC_SHA512(secret, rawBody)`, Flutterwave `verif-hash`; invalid signature throws `forbidden PLT002` | Unit test |
| 16 | Amount `minorUnits` normalization — Paystack kobo and Flutterwave major units both produce same `Amount.minorUnits` | Unit test (500000 kobo ↔ 5000 NGN) |
| 17 | `test/unit/integrations/payment_gateways/payment_gateway_config_test.dart` ≥12 cases green | `flutter test` |
| 18 | `test/unit/integrations/payment_gateways/paystack_gateway_test.dart` ≥24 cases green (init/verify/transfer/resolve/refund/signature/error mapping/pre-validation) | `flutter test` |
| 19 | `test/unit/integrations/payment_gateways/flutterwave_gateway_test.dart` ≥20 cases green | `flutter test` |
| 20 | `test/unit/integrations/payment_gateways/nibss_name_enquiry_adapter_test.dart` ≥10 + `payment_gateway_factory_test.dart` ≥8 + `webhook_event_test.dart` ≥6 green | `flutter test` |
| 21 | `flutter analyze` clean, `dart analyze` clean | CI |
| 22 | `flutter test --coverage` adapters ≥90%, factory/config 100% | Coverage report |
| 23 | Regression `supabase db test` full suite `001–017` green — no new `SECURITY DEFINER`, no `public.*` drift | `supabase db test` |
| 24 | No `VISUAL-IDENTITY.md` violations (no UI in this task) + no `lib/core/api/supabase/supabase_client_provider.dart:19` import in adapters | `grep SupabaseClientProvider.*payment_gateways` = 0 |
| 25 | Doc: `PaymentGateway` dartdoc explains provider-neutral amount, idempotency `reference`, webhook truth vs notification, `resolveForCurrency` EP-08 extension | Code review |
| 26 | `EP-02-13,14,15,16` unblocked (phase plan dependency audit `EP-02:137,143-145`) | Dependency check |

---

## 18. Implementation AI Execution Profile

### Recommended Coding Reasoning Level: **Extremely High**

### Reasoning Level Justification

| Factor | Assessment |
|---|---|
| **Technical complexity** | **Extremely High** — Two provider API shape unification (Paystack kobo vs Flutterwave major units, divergent paths/envelopes/status enums, 2-step `transferrecipient→transfer` hidden behind `createTransfer`, HMAC `SHA512` vs `verif-hash`), own `Dio` per provider (not `ApiLayer.dio` `lib/core/api/api_initializer.dart:72`), bank catalog 24h cache, idempotency `reference` UUID, and `NameEnquiryService` fallback chain (NIBSS → Paystack resolve) prove genuine provider-agnostic design — unlike `High` taxonomy engine `EP-02-07` with 54-row in-memory filter. |
| **Business impact** | **Critical** — Per `EP-02:481` matrix `EP-02-09` is 1 of 6 `Critical` items. Every financial flow (`EP-02-13` profile, `EP-02-14` escrow fund/release, `EP-02-15` conversion, `EP-02-16` payouts + deposit `AGENT.md:7` Rule 3) depends on this seam; incorrect amount unit (100×) or leaked provider type or missing `reference` idempotency causes direct financial loss and double-charge, blocking all marketplace phases `EP-02:5` Phase Objective. |
| **Security risk** | **Extremely High** — `PAYSTACK_SECRET_KEY`/`FLUTTERWAVE_SECRET_KEY`/`NIBSS_API_KEY` are live money-movement secrets (equivalent to `service_role` risk `lib/config/environments/environment_loader.dart:251`). HMAC webhook bypass allows spoofed `charge.success` → false ledger credit if signature not enforced. PCI scope must stay zero (redirect to `authorizationUrl`). Any log/headers leak is catastrophic financial fraud vector. |
| **Performance sensitivity** | **Medium-High** — Not hot path but provider round-trips on Nigerian mobile (15s connect / 30s receive `lib/core/api/api_config.dart:42-44`) require precise retry (no `4xx` retry, backoff `500ms→8s`) and idempotent retry safety; webhook parse must be `O(n)` on <10KB body. |
| **Data complexity** | **Very High** — 7 domain models (`Amount`, `PaymentInitialization*`, `PaymentVerificationResult`, `Transfer*`, `Refund*`, `NameEnquiryResult`, `WebhookEvent`) with provider ↔ neutral bidirectional mapping, currency + CBN `bankCode` validation, fee extraction, and `reference` correlation to `financial_deposits.external_reference` (`EP-02-04`). Unlike `EP-02-08` storage `Uint8List+mime` shape, this is a financial domain language. |
| **Integration complexity** | **Extremely High** — Spans `lib/integrations/payment_gateways/` seam + `lib/config/environments/` ENV resolution + `lib/core/api/` transport (`Dio`, `ApiExceptionMapper`, `ApiClientFactory`, interceptors) + `lib/core/logging/` PII redaction + future `systems/finance/` (`EP-02-13/14/16`) + Edge Function webhook HMAC + external Paystack `api.paystack.co` + Flutterwave `api.flutterwave.com` + NIBSS `nip/name-enquiry` — 6+ integration surfaces, most `Very High` items touch ≤3. Phase Plan assigns `EP-02-09` **Planning: Extremely High / Coding: Extremely High** (`EP-02:336,481,498,505`) — one of only 6 Extremely High items, alongside `EP-02-04` financial schema and `EP-02-16` bound payouts. **Extremely High** is therefore the only calibrated level; `Very High` would under-index catastrophic financial/security risk. |

---

> **Next Step:** Awaiting your approval to proceed to implementation. No files will be created or provider credentials configured until confirmed. Questions before green-light:
> 1. Confirm ENV variable names (`PAYSTACK_SECRET_KEY`, `FLUTTERWAVE_SECRET_KEY`, `NIBSS_BASE_URL`, `PAYMENT_DEFAULT_PROVIDER`) or prefer `PAYSTACK_SK`/`FLW_SK` short form to align with existing `AppConstants.env*` (`lib/config/constants/app_constants.dart`) naming?
> 2. Confirm `direct NIBSS` primary for `NameEnquiryService` vs **always delegating to Paystack `bank/resolve`** in EP-02-09 (direct NIBSS deferred to staging/production credential)?
> 3. Confirm provider `Dio` construction: reuse `ApiClientFactory.create` (`lib/core/api/api_client/api_client_factory.dart:14`) with provider `baseUrl` vs standalone `Dio(BaseOptions(...))` to keep `interceptors` (logging, retry) consistent with `ApiLayer` chain (`lib/core/api/api_initializer.dart:87`)?
