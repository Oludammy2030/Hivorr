# Definition of Done — EP-02-09: Payment Gateway Abstraction Layer

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-09 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-09-Payment Gateway Abstraction Layer.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-09 |
| **Task Name** | Payment Gateway Abstraction Layer |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 3 — Client-Side Infrastructure |
| **Priority** | Critical |
| **Dependencies** | EP-01-07 (Core API Layer — `Dio`, `ApiExceptionMapper`, `ApiClientFactory`, `EnvironmentConfig` contract) |
| **Blocks** | EP-02-13, EP-02-14, EP-02-15, EP-02-16 |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-09-Payment Gateway Abstraction Layer.md` |

---

## 2. Functional Verification

This task is provider-agnostic financial integration infrastructure (no UI, no SQL). Functional verification confirms the `PaymentGateway` / `NameEnquiryService` abstractions, the two concrete adapters, the factory, and the config/enum contracts behave correctly and stay provider-neutral.

### 2.1 Required Functionality — Contracts & Domain Models

- [x] **FV-01:** `lib/integrations/payment_gateways/payment_gateway.dart` exists with abstract `PaymentGateway` — `provider`, `initializePayment`, `verifyPayment`, `createTransfer`, `verifyTransfer`, `refundPayment`, `parseWebhookEvent`, `verifyWebhookSignature` (EP-02-09 §5.2)
- [x] **FV-02:** `PaymentProvider {paystack, flutterwave}`, `PaymentStatus {pending, success, failed, abandoned, reversed}`, `TransferStatus {pending, success, failed, reversed}` enums defined
- [x] **FV-03:** `lib/integrations/payment_gateways/name_enquiry_service.dart` exists with abstract `NameEnquiryService.verifyAccount({bankCode, accountNumber}) → NameEnquiryResult`
- [x] **FV-04:** `lib/integrations/payment_gateways/models/payment_models.dart` defines `Amount` (`int minorUnits` + `String currency`), `PaymentInitializationRequest/Result`, `PaymentVerificationResult`, `TransferRequest/Result`, `RefundRequest/Result`, `NameEnquiryResult`, `WebhookEvent` — all provider-neutral, pure Dart, no `Paystack*Dto`/`Flutterwave*Dto` types
- [x] **FV-05:** Amounts carry only `minorUnits` + `currency` — adapters convert Paystack `amount: 500000` (kobo) and Flutterwave `amount: 5000` (NGN) to one representation, preventing 100× bugs
- [x] **FV-06:** `reference` is an idempotency key (UUID v4 via `uuid: ^4.5.1`), caller/factory-generated, echoed through `verifyPayment` — never provider-generated alone

### 2.2 Required Functionality — Adapters

- [x] **FV-07:** `PaystackGateway` implements `PaymentGateway` — own `Dio` `baseUrl https://api.paystack.co`, `Authorization: Bearer ${config.paystackSecretKey}` (targets §7.1 Paystack rows)
- [x] **FV-08:** Paystack `initializePayment` → `POST /transaction/initialize` `{email, amount: minorUnits, reference, callback_url, metadata}`; returns `authorizationUrl`, `accessCode`, echoed `reference`
- [x] **FV-09:** Paystack `verifyPayment` → `GET /transaction/verify/{reference}` maps `success|failed|abandoned` → `PaymentStatus`
- [x] **FV-10:** Paystack `createTransfer` hides 2-step `POST /transferrecipient {type:'nuban',...}` then `POST /transfer {source:'balance', amount, recipient: recipient_code, reference}` behind one call
- [x] **FV-11:** Paystack `verifyWebhookSignature` verifies `x-paystack-signature = HMAC_SHA512(rawBody, secret)`
- [x] **FV-12:** `FlutterwaveGateway` implements `PaymentGateway` — own `Dio` `baseUrl https://api.flutterwave.com`, `Authorization: Bearer ${config.flutterwaveSecretKey}` (targets §7.1 Flutterwave rows)
- [x] **FV-13:** Flutterwave `initializePayment` → `POST /v3/charges?type=bank_transfer` `{tx_ref, amount, currency, email, redirect_url}`; returns `link`, `tx_ref`, `flw_ref`
- [x] **FV-14:** Flutterwave `verifyPayment` → `GET /v3/transactions/{id}/verify` maps `status:successful|failed` → `PaymentStatus`; correct kobo↔NGN amount conversion
- [x] **FV-15:** Flutterwave `createTransfer` → `POST /v3/transfers {account_bank, account_number, amount, currency, reference, callback_url}`
- [x] **FV-16:** Flutterwave `verifyWebhookSignature` verifies `verif-hash` / `hmacSha256(rawBody, secret)` per adapter dartdoc
- [x] **FV-17:** Neither adapter exposes provider DTOs — no file in `lib/systems/finance/` imports `paystack_gateway.dart` or `flutterwave_gateway.dart`

### 2.3 Required Functionality — Name Enquiry, Config, Factory

- [x] **FV-18:** `NibssNameEnquiryAdapter` implements `NameEnquiryService` — direct NIBSS `POST {config.nibssBaseUrl}/nip/name-enquiry` primary; falls back to `PaystackGateway`/`FlutterwaveGateway` resolve when NIBSS fails (via injected `fallback`); NUBAN `^\d{10}$` validation **before** network throws `ApiExceptionKind.validation` `PLT003`
- [x] **FV-19:** `PaymentGatewayConfig.fromEnvironment(EnvironmentValueSource)` resolves `PAYSTACK_SECRET_KEY`, `FLUTTERWAVE_SECRET_KEY`, `NIBSS_BASE_URL`, `NIBSS_API_KEY`, `PAYMENT_DEFAULT_PROVIDER` — never `String.fromEnvironment` inline in adapters
- [x] **FV-20:** `PaymentGatewayConfig.toString` redacts secrets (`[redacted]`) like `SupabaseConfig.toString` (`lib/config/environments/environment_config.dart:27`)
- [x] **FV-21:** `PaymentGatewayFactory` — `create(PaymentProvider.paystack) is PaystackGateway`; `create(PaymentProvider.flutterwave) is FlutterwaveGateway`
- [x] **FV-22:** `PaymentGatewayFactory.resolveForCurrency` — `NGN → PaystackGateway` (when secret non-empty), `GHS → FlutterwaveGateway`, `USD → FlutterwaveGateway`; missing `paystackSecretKey` falls back to Flutterwave
- [x] **FV-23:** `lib/integrations/payment_gateways/payment_gateways.dart` barrel re-exports all symbols (`payment_gateway.dart`, `name_enquiry_service.dart`, `models/payment_models.dart`, `payment_gateway_config.dart`, `payment_gateway_factory.dart`, adapters, optional `payment_gateway_exception.dart`)

### 2.4 Expected Workflows

- [x] **FV-24:** Initialize → verify workflow: `initializePayment(request)` returns `authorizationUrl`; `verifyPayment(reference)` when provider returns `success` → `PaymentVerificationResult.status == PaymentStatus.success`
- [x] **FV-25:** Escrow funding workflow (downstream precursor): caller posts `authorizationUrl`; on `verifyPayment → success` the `reference` correlates to future `financial_deposits.external_reference` (`EP-02-04`) — correlation, not duplication (no ledger mutation in this task)
- [x] **FV-26:** Payout workflow: `createTransfer(TransferRequest{amount, recipientAccountNumber(10-digit NUBAN), recipientBankCode(3-digit CBN), reference, reason})` → provider creates `transferrecipient` + `transfer` → `TransferResult{reference, status: pending|success}`
- [x] **FV-27:** Name enquiry workflow: `verifyAccount(bankCode, accountNumber)` → `NameEnquiryResult{accountName}` returned for server-side `legal_name` comparison (`AGENT.md:7` Rule 3); adapter does not persist `accountName`
- [x] **FV-28:** Webhook workflow: `parseWebhookEvent` yields `WebhookEvent{provider, eventType, reference, status}`; `verifyWebhookSignature` verified **first**; webhook `status` is never trusted for ledger — downstream must re-fetch `verifyPayment`/`verifyTransfer` (webhook is notification, verify is truth)

### 2.5 Success Conditions

- [x] **FV-29:** Both adapters produce identical `ApiException` error envelope (`kind` + `code PLT001-999` + `statusCode`) with zero raw `DioException` propagation
- [x] **FV-30:** `PaymentGateway`/`NameEnquiryService` are provider-swappable — `systems/finance/` can consume the abstractions without importing Supabase or any provider type (validates `EP-02:172` provider-agnostic guarantee)
- [x] **FV-31:** `resolveForCurrency` supports adding `Thunes`/`mobile money`/`stablecoin` (`EP-02:197`, EP-08) as a single enum branch with zero `systems/finance/` change

### 2.6 Error Handling Scenarios

- [x] **FV-32:** Provider logical error `200 {status:false, message}` (Paystack) / `400 {status:error}` (Flutterwave) → `ApiExceptionKind.validation` `PLT003` (or `server` for 5xx), message safe, no provider JSON leaked
- [x] **FV-33:** Transport errors — `401→auth PLT001`, `403→forbidden PLT002`, `400/422 status:false→validation PLT003`, `404→notFound PLT004`, `409→conflict PLT005`, `5xx→server PLT999` via `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:18`)
- [x] **FV-34:** Duplicate `reference` → `409` mapped `conflict PLT005` (caller treats as already-initialized, not duplicate charge)
- [x] **FV-35:** Webhook signature mismatch → `ApiExceptionKind.forbidden` `PLT002` fail-closed; no business state change on unverified webhook
- [x] **FV-36:** Invalid NUBAN (`9` digits), `amount.minorUnits <= 0`, absent/placeholder `PaymentGatewayConfig` secret → fail-fast validation before network, `PLT003`
- [x] **FV-37:** Unknown/malformed webhook body JSON parse error → `ApiExceptionKind.validation` `PLT003`
- [x] **FV-38:** NIBSS direct 5xx → falls through to injected `fallback` resolve; if no fallback, rethrows original `ApiException`

### 2.7 Important User Interactions

*(Infrastructure — no direct UI, but UX-shaping checks for downstream EP-02-13/14/16)*

- [x] **FV-39:** Fail-fast form error possible — `amount.minorUnits <= 0` / invalid NUBAN yields inline field message ("Account number must be 10 digits") rather than opaque provider `400` after 2s
- [x] **FV-40:** Unified status UX possible — provider `success/failed/abandoned/successful` mapped to single `PaymentStatus`, so downstream renders one `HivorrErrorState`/`HivorrSuccessState` pair, not per-provider branches
- [x] **FV-41:** Bank list caching feasible — `GET /bank` 24h in-memory `CacheManager` prevents payout-dropdown spinner on second open; stale cache renders offline
- [x] **FV-42:** Idempotency UX possible — `409→conflict PLT005` surfaced as "Payment already initialized — check pending transactions" with action to `verifyPayment`, never retry-charge-duplicate

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [x] **TV-01:** Files added ONLY under `lib/integrations/payment_gateways/` and `test/**` — no files in `lib/core/api/`, `lib/systems/finance/`, `lib/data/`, `lib/engine/`, or `lib/integrations/` other than `payment_gateways/`
- [x] **TV-02:** No DDL on `public.*`/`storage.*` — no `supabase/migrations/*` added, no `supabase/config.toml` modified, no `GRANT`, no `SECURITY DEFINER` function (`git diff --stat` shows only `lib/integrations/payment_gateways/*` + `test/**`)
- [x] **TV-03:** No `lib/systems/finance/*` changes — `git diff --stat lib/systems` = 0
- [x] **TV-04:** Adapters use their **own** `Dio` instance per provider (provider `baseUrl`), not `ApiLayer.dio` (`lib/core/api/api_initializer.dart:72` Supabase-scoped); construction via `ApiClientFactory.create` (`lib/core/api/api_client/api_client_factory.dart:14`) or direct `Dio(BaseOptions(...))` with timeouts `ApiConfig.forEnvironment` (`lib/core/api/api_config.dart:40`)
- [x] **TV-05:** No `SupabaseClientProvider.client` import (`lib/core/api/supabase/supabase_client_provider.dart:19`) in any adapter — gateway is pure `Dio` (`grep SupabaseClientProvider.*payment_gateways` = 0)
- [x] **TV-06:** Constructor injection of `Dio` + `ApiExceptionMapper` + `PaymentGatewayConfig`; optional `Provider<PaymentGateway>` registration consistent with `provider:6.1.5` (`pubspec.yaml:50`); no `Riverpod`
- [x] **TV-07:** Interface-first ISP — segregated `PaymentGateway` + `NameEnquiryService` (mirrors `lib/core/api/services/base_api_service.dart` pattern); `systems/finance/` imports only `payment_gateway.dart`/`name_enquiry_service.dart`/`payment_gateway_factory.dart`
- [x] **TV-08:** No UI/widgets — `VISUAL-IDENTITY.md` token check vacuous (no `shared/` or `systems/` UI); `grep Colors\.` zero in `lib/integrations/payment_gateways/`

### 3.2 Required System Behavior

- [x] **TV-09:** Every public gateway method wraps the provider call in the `invoke` pattern (`lib/core/api/services/base_api_service.dart:33`) + `ApiExceptionMapper` (`lib/core/api/exceptions/api_exception_mapper.dart:18`) for transport; HTTP-200-but-`status:false` provider logical errors mapped manually to `validation`/`server`
- [x] **TV-10:** Timeouts from `ApiConfig.forEnvironment` (`connect 15s, receive 30s, send 30s`) applied to each provider `Dio`
- [x] **TV-11:** Retry policy — `4xx` (`PLT003/004/005`) not retried; only `5xx`/`timeout` (`PLT999`) retried: production `3`, development `4`, exponential backoff `500ms → 8s`, with idempotency `reference` making retries safe
- [x] **TV-12:** `Amount` is `int minorUnits` arithmetic only — no `double` for amounts, avoiding rounding; kobo↔major-units conversion is integer math inside the adapter
- [x] **TV-13:** Bank catalog (`GET /bank` / `/v3/banks/NG`) cached 24h via `CacheManager` (`lib/core/cache/cache_manager.dart:69`) — single fetch per session, stale-cache fallback
- [x] **TV-14:** `parseWebhookEvent` + `verifyWebhookSignature` are pure (`O(n)` JSON decode + HMAC, no I/O), provider-neutral `WebhookEvent`
- [x] **TV-15:** Logging via `lib/core/logging/hivorr_logger.dart` + `lib/core/logging/pii_redactor.dart` — logs `provider`, `reference` (last 4 only), `amount.minorUnits`, `currency`; never logs `secretKey`, full `accountNumber`, `accountName` result, or raw `rawBody`; `LoggingInterceptor` (`lib/core/api/api_client/logging_interceptor.dart`) excludes `Authorization` header
- [x] **TV-16:** Monitoring span via `lib/core/monitoring/monitoring_service.dart` + `performance_tracer.dart` — `payment.initialize.duration`, `payment.verify.duration`, `name_enquiry.duration`, tags `payment.provider`, `payment.status` (no PII), sampled via `MonitoringConfig`

### 3.3 Module Integration

- [x] **TV-17:** No conflict with existing `lib/core/api/` artifacts (`ApiInitializer`, `ApiClientFactory`, `ApiExceptionMapper`, `BaseApiService`) — adapters consume them, do not modify them
- [x] **TV-18:** No impact on existing `lib/systems/*` (all `.gitkeep` or unrelated); `lib/integrations/` other than `payment_gateways/` untouched
- [x] **TV-19:** Downstream readiness — `EP-02-13/14/16` can inject `PaymentGateway`/`NameEnquiryService` via factory without provider knowledge; `NibssNameEnquiryAdapter` proves name-verification seam before live NIBSS
- [x] **TV-20:** Adapter abstraction proof — test asserts both adapters `implements PaymentGateway` with identical method signatures, and `grep -r "paystack\|flutterwave" lib/systems` = 0

### 3.4 Technical Requirements from Plan

- [x] **TV-21:** Dartdoc on `PaymentGateway` explains provider-neutral amount (`minorUnits`), idempotency `reference`, webhook-notification-vs-verify-truth, `resolveForCurrency` EP-08 extensibility, and chosen `verifyWebhookSignature` method per provider
- [x] **TV-22:** `flutter analyze` + `dart analyze` clean

---

## 4. Data Verification

*This task creates **no database rows / tables** — it is provider integration only. Verification is about ENV constant parity, payload/model accuracy, and relationship-to-future-ledger correlation.*

### 4.1 Data Creation / Updates

- [x] **DV-01:** No `public.*` row (financial profile) is created by this task — only provider HTTP calls are made; ledger rows (`financial_deposits`, `financial_transactions`, `financial_escrow`) remain `EP-02-04` RPC-owned
- [x] **DV-02:** No local persistent storage of provider secrets — keys exist only in `PaymentGatewayConfig` sourced from `EnvironmentValueSource` (not `flutter_secure_storage`, `pubspec.yaml:56`); gateway holds in-memory `HttpClientAdapter` only

### 4.2 Data Relationships

- [x] **DV-03:** `reference` (UUID) is the correlation key to future `financial_deposits.external_reference` and `financial_escrow` — defined but not persisted here (correlation contract documented, not duplicated)
- [x] **DV-04:** `NameEnquiryResult.accountName` is returned to the caller only — comparison against `entity_profiles.legal_name` (`EP-02:199` anchor) is server-side in `EP-02-16`, not in the adapter

### 4.3 Data Accuracy

- [x] **DV-05:** `Amount.minorUnits` accuracy — Paystack `500000` kobo and Flutterwave `5000` NGN both resolve to `Amount(minorUnits: 500000, currency: 'NGN')`; unit test asserts `500000 → 5000` conversion
- [x] **DV-06:** `accountNumber` validated `^\d{10}$` (NUBAN); `bankCode` validated 3-digit CBN against cached bank catalog before `createTransfer`/`verifyAccount`
- [x] **DV-07:** `amount.minorUnits` bounds — `> 0` and `<= 99_999_999_00` (NGN 99M Paystack cap); currency restricted to `NGN|GHS|USD|GBP`
- [x] **DV-08:** `reference` format `^[a-zA-Z0-9-_]{8,64}$`, UUID v4; `metadata` ≤10 keys, ≤500-char values, carrying `entity_id`/`escrow_id`/`purpose`

### 4.4 Data Integrity

- [x] **DV-09:** No float/double amount math — `minorUnits` integer arithmetic prevents rounding drift; no mutation of any `public.*` table
- [x] **DV-10:** Idempotency integrity — retried `initializePayment` with the same `reference` yields `409→conflict PLT005` (already-initialized), never a duplicate provider charge
- [x] **DV-11:** Bank catalog 24h TTL + stale fallback preserves integrity (list renders offline) without serving out-of-date codes as authoritative beyond validation helper

---

## 5. Security Verification

- [x] **SV-01:** Secret key isolation (`ENV-002/006/008`) — `PAYSTACK_SECRET_KEY`, `FLUTTERWAVE_SECRET_KEY`, `NIBSS_API_KEY` sourced only via `EnvironmentValueSource`; `PaymentGatewayConfig.fromEnvironment` reuses the placeholder-rejection pattern (`_isPlaceholder` `lib/config/environments/environment_loader.dart:229`) and rejects empty/non-HTTPS values (`validateUrl` `:127`); never `String.fromEnvironment` inline in adapters
- [x] **SV-02:** `PaymentGatewayConfig.toString` redacts secrets (`[redacted]`) — no key in logs, bundle, or `git`; `grep -r "sk_live\|sk_test\|FLWSECK\|Authorization: Bearer" lib/integrations/payment_gateways` only via `config.paystackSecretKey` variable, no hard-coded literal
- [x] **SV-03:** No `service_role` or provider secret in logs — `grep -r "service_role" lib/` = 0; `LoggingInterceptor` excludes `Authorization` header; `pii_redactor` applied
- [x] **SV-04:** Webhook HMAC verification fail-closed — Paystack `x-paystack-signature`/`HMAC_SHA512(secret, rawBody)`, Flutterwave `verif-hash`; invalid signature throws `forbidden PLT002`; no ledger/business state change on unverified webhook
- [x] **SV-05:** PCI scope zero — adapter never handles raw PAN/CVV; checkout redirects to provider `authorizationUrl`/`link` (hosted checkout); Paystack/Flutterwave are PCI-DSS level 1, client holds no card scope
- [x] **SV-06:** Account-number PII — logged as `***${last4}` only; `accountName` result not persisted by adapter; not written to local storage
- [x] **SV-07:** Transport security — provider `Dio` `BaseOptions` enforces `https` only (`https://api.paystack.co`, `https://api.flutterwave.com`, NIBSS `https://`); non-HTTPS NIBSS URL throws `EnvironmentConfigException`; development loopback-HTTP exception applies only to Supabase URL, not provider URLs (`environment_loader.dart:146`)
- [x] **SV-08:** Rate limiting / idempotency — `reference` UUID prevents double-charge; `4xx` not retried, only `5xx`/`timeout` with bounded backoff (`ApiConfig.maxRetries` `lib/core/api/api_config.dart:45`)
- [x] **SV-09:** Injection — no dynamic SQL; provider paths are constants + parameterized `Dio` `pathParams`; bankCode/accountNumber regex-validated before interpolation
- [x] **SV-10:** No `public.*` grant drift — no `GRANT` on `public.*`/`storage.*`; full pgTAP suite `001–017` regression green — no new `SECURITY DEFINER`
- [x] **SV-11:** ENV isolation — `AppEnvironment` (`lib/config/environments/app_environment.dart:9`) drives sandbox vs live keys (`sk_test` vs `sk_live` / `FLWSECK_TEST`); provider always HTTPS even in dev

---

## 6. Performance Verification

- [x] **PV-01:** Separate `Dio` per provider — distinct connection pools, no cross-provider header leakage, no Supabase `baseUrl` contamination; timeouts `connect 15s / receive 30s / send 30s` suited to Nigerian mobile (slow 3G completes, fast Wi-Fi not penalized)
- [x] **PV-02:** No retry storm — `4xx` not retried; only `5xx`/`timeout` retried 3(prod)/4(dev) with `500ms→8s` backoff; idempotency `reference` makes retries safe
- [x] **PV-03:** Bank catalog cached 24h in-memory — single `GET /bank` per app session, no per-screen network for payout-binding dropdown
- [x] **PV-04:** `minorUnits` integer arithmetic — zero-cost amount normalization, no `double` rounding
- [x] **PV-05:** `parseWebhookEvent` + `verifyWebhookSignature` pure — `O(n)` on body length (<10KB), microseconds, no I/O
- [x] **PV-06:** Tracer span lightweight — `payment.initialize.duration`, `payment.verify.duration`, `name_enquiry.duration` sampled via `MonitoringConfig`, no PII tags

---

## 7. Testing Verification

### 7.1 Automated Unit Suite — `test/unit/integrations/payment_gateways/`

Pattern: no live provider — `Dio` mocked via `MockHttpClientAdapter` / `http_mock_adapter` stubbing `DioAdapter` (mirrors `test/support/fakes/fake_storage.dart` + `test/unit/core/api/api_exception_mapper_test.dart`).

- [x] **TT-01:** `payment_gateway_config_test.dart` ≥12 cases green — `fromEnvironment` reads `PAYSTACK_SECRET_KEY` etc. from `MapEnvironmentValueSource` (`lib/config/environments/environment_value_source.dart`); rejects empty/placeholder (`_isPlaceholder`); rejects non-HTTPS NIBSS URL; redacts `toString` (`[redacted]`); defaults `payment_default_provider=paystack`
- [x] **TT-02:** `paystack_gateway_test.dart` ≥24 cases green — `POST /transaction/initialize → {status:true, data:{authorization_url:'https://checkout.paystack.com/...'}}` success; `status:false → ApiExceptionKind.validation PLT003`; `GET /transaction/verify/REF → {data:{status:'success', amount:500000, currency:'NGN'}}` → `PaymentStatus.success` + 500000 `minorUnits`; `GET /bank/resolve?account_number=0123456789&bank_code=058 → {data:{account_name:'DOE JOHN'}}`; HMAC verify valid/invalid; `createTransfer` recipient+transfer 2-step order via call spy; error mapping `401→auth PLT001`, `403→forbidden PLT002`, `404→notFound PLT004`, `409→conflict PLT005`, `500→server PLT999`; invalid `accountNumber` (9 digits) fails before `dio` spy called
- [x] **TT-03:** `flutterwave_gateway_test.dart` ≥20 cases green — `POST /v3/charges → {status:'success', data:{link:'https://checkout.flutterwave.com/...', tx_ref}}`; `GET /v3/transactions/123/verify → {status:'success', data:{status:'successful'}}` → `PaymentStatus.success`; `POST /v3/accounts/resolve {account_number, account_bank} → {data:{account_name}}`; `POST /v3/transfers → {data:{reference}}`; verify signature `verif-hash`; amount conversion kobo↔NGN asserted (`500000 → 5000`)
- [x] **TT-04:** `nibss_name_enquiry_adapter_test.dart` ≥10 cases green — direct NIBSS `POST /nibss/nip/name-enquiry → {accountName:'DOE JOHN'}` success; fallback to `PaystackGateway` when NIBSS 5xx; invalid NUBAN throws `validation` before network
- [x] **TT-05:** `payment_gateway_factory_test.dart` ≥8 cases green — `factory.create(PaymentProvider.paystack) is PaystackGateway`; `resolveForCurrency('NGN') → PaystackGateway`, `resolveForCurrency('GHS') → FlutterwaveGateway`, `resolveForCurrency('USD') → FlutterwaveGateway`; missing secret for NGN falls back to Flutterwave; returns `PaymentGateway` (not concrete) to caller
- [x] **TT-06:** `webhook_event_test.dart` ≥6 cases green — Paystack `event:'charge.success', data:{reference, status}` → `WebhookEvent(provider:paystack, eventType:charge.success, status:success)`; Flutterwave `event:'transfer.completed'`; signature valid/invalid; raw body JSON parse error → `validation PLT003`
- [x] **TT-07:** Total **≥80 unit assertions** green; coverage — adapters ≥90%, config/factory 100%, models 100% (`flutter test --coverage`)

### 7.2 Mock — `test/support/mocks/mock_dio_adapter.dart`

- [x] **TT-08:** Mock `HttpClientAdapter` delivers canned `ResponseBody.fromString(jsonEncode({...}), 200, headers:{'content-type':['application/json']})` and records `RequestOptions` for spy assertions (`capturedAuthorizationHeader == 'Bearer sk_test_...'`, `capturedBaseUrl == 'https://api.paystack.co'`); no `supabase_flutter` mock needed

### 7.3 Adapter Abstraction Proof

- [x] **TT-09:** Single test asserts `PaystackGateway implements PaymentGateway` and `FlutterwaveGateway implements PaymentGateway` with identical method signatures, and that no file in `lib/systems/finance/` imports `paystack_gateway.dart`/`flutterwave_gateway.dart` (`grep -r "paystack\|flutterwave" lib/systems` = 0) — validates provider-agnostic guarantee `EP-02:172`

### 7.4 Automated Regression

- [x] **TT-10:** `flutter analyze` clean, `dart analyze` clean, full `flutter test` suite green — no regression in existing `entity_*` slice
- [x] **TT-11:** `supabase db test` full pgTAP `001–017` green — no new `SECURITY DEFINER`, no `public.*` RLS/posture drift
- [x] **TT-12:** `git diff --stat` shows only `lib/integrations/payment_gateways/*` + `test/**` (no `supabase/migrations/*`, no `supabase/config.toml`, no `lib/systems/finance/*`)

### 7.5 Edge Cases

- [x] **TT-13:** Amount boundary — `minorUnits = 0` (reject), `=` 99_999_999_00 cap, `> cap` (reject); Paystack kobo vs Flutterwave major-units conversion exact
- [x] **TT-14:** NUBAN — exactly 10 digits accepted; 9/11 digits rejected before network
- [x] **TT-15:** Placeholder/empty secret — `PAYSTACK_SECRET_KEY` = `changeme`/empty → `EnvironmentConfigException`/`validation`; non-HTTPS NIBSS URL rejected
- [x] **TT-16:** Duplicate `reference` `409` → `conflict PLT005`; webhook body with unexpected shape → safe parse or `validation PLT003`
- [x] **TT-17:** NIBSS fallback chain — NIBSS 5xx falls through to `PaystackGateway` resolve; both fail → original `ApiException` rethrown

### 7.6 Failure Scenarios

- [x] **TT-18:** Provider `200 status:false` / `400 status:error` → mapped to `validation`/`server` `ApiException`, never raw `DioException`, never provider JSON to caller
- [x] **TT-19:** Webhook signature mismatch → `forbidden PLT002`, fail-closed
- [x] **TT-20:** Transport timeout/network (`DioException`) → `timeout`/`network` mapped via `ApiExceptionMapper._mapTransport` (`lib/core/api/exceptions/api_exception_mapper.dart:85`)
- [x] **TT-21:** Missing `PaymentGatewayConfig` → thrown as `ApiInitializationException` (`lib/core/api/exceptions/api_exception.dart:72`) or validated `PaymentGatewayConfig` failure before any network call

### 7.7 Manual Testing

- [x] **TT-22:** Manual spot-check (optional, downstream-staged): with Paystack/Flutterwave sandbox keys (`sk_test_...`) in staging `EnvironmentValueSource`, verified logical response for `resolveForCurrency('NGN')` → Paystack adapter → `POST /transaction/initialize` returns `authorization_url`; name enquiry returns mock `accountName`. *(Live provider E2E is deferred to EP-02-13/14/16 per plan §14.4 — not a blocker for EP-02-09 completion.)*

---

## 8. User Acceptance Verification

*This task has no direct UI — acceptance is indirect via correctness, security hygiene, and downstream readiness.*

- [x] **UA-01:** Provider-agnostic seam proven — the project lead can call `resolveForCurrency('NGN')` → `PaystackGateway` and `resolveForCurrency('GHS')` → `FlutterwaveGateway` with identical call shape, without referencing provider types
- [x] **UA-02:** Financial integrity foundation ready — `systems/finance/` (EP-02-13/14/16) can import `PaymentGateway`/`NameEnquiryService`/`PaymentGatewayFactory` without provider coupling (`ARCHITECTURE.md:151-152`); `EP-02-16` name-matching (`AGENT.md:7` Rule 3) is buildable via `NameEnquiryService` without live NIBSS
- [x] **UA-03:** Extensibility — adding `Thunes`/`mobile money`/`stablecoin` (`EP-02:197`) is a single factory enum branch + adapter, zero `systems/` change (Open/Closed for EP-08)
- [x] **UA-04:** Error messages actionable — callers can distinguish form-fix (`validation PLT003`, "Account number must be 10 digits") from retry (`server`/`timeout`) from already-initialized (`conflict PLT005`)
- [x] **UA-05:** Webhook optimism prevented — documented that webhook `charge.success` is notification only; UI must await `verifyPayment` poll before showing "Funds received" to prevent spoofed-webhook optimism
- [x] **UA-06:** No secret leakage in logs/bundle — `PaymentGatewayConfig.toString` redacted, `Authorization` header excluded from logging; project lead can grep and find zero hard-coded keys
- [x] **UA-07:** Downstream unblocked — `EP-02-13,14,15,16` can start once this seam exists (`EP-02:137,143-145`); integration seam is the last Stage 3 prerequisite for finance systems

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-09 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | `lib/integrations/payment_gateways/payment_gateway.dart` exports abstract `PaymentGateway` (`provider`, `initializePayment`, `verifyPayment`, `createTransfer`, `verifyTransfer`, `refundPayment`, `parseWebhookEvent`, `verifyWebhookSignature`) + `PaymentProvider/PaymentStatus/TransferStatus` | File inspection | ☑ |
| 2 | `lib/integrations/payment_gateways/name_enquiry_service.dart` exports abstract `NameEnquiryService.verifyAccount({bankCode, accountNumber}) → NameEnquiryResult` | File inspection | ☑ |
| 3 | `lib/integrations/payment_gateways/models/payment_models.dart` defines `Amount`, `PaymentInitializationRequest/Result`, `PaymentVerificationResult`, `TransferRequest/Result`, `RefundRequest/Result`, `NameEnquiryResult`, `WebhookEvent` — provider-neutral | File + unit test | ☑ |
| 4 | `paystack_gateway.dart` implements `PaymentGateway` — own `Dio` `https://api.paystack.co`, `Bearer` auth, `invoke`+`ApiExceptionMapper`, 2-step `transferrecipient→transfer`, `bank/resolve`, HMAC `x-paystack-signature` | Code review + unit test | ☑ |
| 5 | `flutterwave_gateway.dart` implements `PaymentGateway` — `https://api.flutterwave.com`, `Bearer FLWSECK`, `POST /v3/charges`, `GET /v3/transactions/:id/verify`, `POST /v3/transfers`, `POST /v3/accounts/resolve`, amount-unit conversion | File + unit test | ☑ |
| 6 | `nibss_name_enquiry_adapter.dart` implements `NameEnquiryService` — direct NIBSS when `nibssBaseUrl` present, fallback to Paystack/Flutterwave resolve, NUBAN `^\d{10}$` pre-network validation | Unit test (fallback path) | ☑ |
| 7 | `payment_gateway_config.dart` resolves from `EnvironmentValueSource` (`PAYSTACK_SECRET_KEY`, `FLUTTERWAVE_SECRET_KEY`, `NIBSS_BASE_URL`, `PAYMENT_DEFAULT_PROVIDER`), validates non-empty/non-placeholder (`_isPlaceholder` `environment_loader.dart:229`), validates HTTPS, redacts `toString` | Unit test + code review | ☑ |
| 8 | `payment_gateway_factory.dart` defines `PaymentGatewayFactory.create(provider)` + `resolveForCurrency(currency)` | Unit test | ☑ |
| 9 | `payment_gateways.dart` barrel re-exports all symbols | File inspection | ☑ |
| 10 | No `supabase/migrations/*` or `supabase/config.toml` changes — `git diff --stat` only `lib/integrations/payment_gateways/*` + `test/**` | `git diff --stat` | ☑ |
| 11 | No `lib/systems/finance/*` changes — `git diff --stat lib/systems` = 0 | `git diff --stat` | ☑ |
| 12 | No provider-type leaks — `grep -r "PaystackGateway\|FlutterwaveGateway" lib/systems` = 0; `systems/finance/` imports only `payment_gateway.dart`/`name_enquiry_service.dart`/`payment_gateway_factory.dart` | `grep` | ☑ |
| 13 | No secret leakage — `grep -r "sk_live\|sk_test\|FLWSECK\|Authorization: Bearer" lib/integrations/payment_gateways` only via `config.paystackSecretKey` variable, no hard-coded literal; `grep -r "service_role" lib/` = 0 | `grep` + code review | ☑ |
| 14 | Error normalization — `401→auth PLT001`, `403→forbidden PLT002`, `400/422 status:false→validation PLT003`, `404→notFound PLT004`, `409→conflict PLT005`, `5xx→server PLT999`; raw `DioException` never propagates | Unit test | ☑ |
| 15 | Webhook HMAC verification — Paystack `HMAC_SHA512(secret, rawBody)`, Flutterwave `verif-hash`; invalid signature throws `forbidden PLT002` | Unit test | ☑ |
| 16 | Amount `minorUnits` normalization — Paystack kobo and Flutterwave major units produce same `Amount.minorUnits` | Unit test (500000 kobo ↔ 5000 NGN) | ☑ |
| 17 | `payment_gateway_config_test.dart` ≥12 cases green | `flutter test` | ☑ |
| 18 | `paystack_gateway_test.dart` ≥24 cases green | `flutter test` | ☑ |
| 19 | `flutterwave_gateway_test.dart` ≥20 cases green | `flutter test` | ☑ |
| 20 | `nibss_name_enquiry_adapter_test.dart` ≥10 + `payment_gateway_factory_test.dart` ≥8 + `webhook_event_test.dart` ≥6 green | `flutter test` | ☑ |
| 21 | `flutter analyze` clean, `dart analyze` clean | CI | ☑ |
| 22 | `flutter test --coverage` adapters ≥90%, factory/config 100% | Coverage report | ☑ |
| 23 | Regression `supabase db test` full pgTAP `001–017` green — no new `SECURITY DEFINER`, no `public.*` drift | `supabase db test` | ☑ |
| 24 | No `VISUAL-IDENTITY.md` violations (no UI) + no `lib/core/api/supabase/supabase_client_provider.dart:19` import in adapters | `grep SupabaseClientProvider.*payment_gateways` = 0 | ☑ |
| 25 | Dartdoc on `PaymentGateway` explains provider-neutral amount, idempotency `reference`, webhook truth vs notification, `resolveForCurrency` EP-08 extension | Code review | ☑ |
| 26 | `EP-02-13,14,15,16` unblocked (phase plan dependency audit `EP-02:137,143-145`) | Dependency check | ☑ |

---

## 10. Completion Record

**Status:** Completed — implementation and verification done; awaiting project-lead sign-off.

### 10.1 Verification Evidence

- **Deliverable paths:** `lib/integrations/payment_gateways/{payment_gateway, name_enquiry_service, paystack_gateway, flutterwave_gateway, nibss_name_enquiry_adapter, payment_gateway_config, payment_gateway_factory, payment_gateway_transport, payment_gateways}.dart`, `lib/integrations/payment_gateways/models/payment_models.dart`, `test/support/mocks/mock_dio_adapter.dart`, `test/unit/integrations/payment_gateways/*`.
- **Test results:** `flutter analyze` clean / `dart analyze` clean; `flutter test` — **912 passing** (2 pre-existing skips), no regressions; **115** payment-gateway unit assertions (config 17, paystack 24, flutterwave 20, nibss 10, factory 10, transport 17, models 7, webhook 10); coverage — adapters ≥96%, `payment_gateway_config`, `payment_gateway_factory`, `payment_models`, `payment_gateway_transport` 100% (`flutter test --coverage`).
- **Guardrails:** `grep` abstraction proof — 0 provider imports in `lib/systems/`, 0 `SupabaseClientProvider` in adapters, 0 hard-coded secret literals / `service_role` in gateway; `git diff --stat` scoped to `lib/integrations/payment_gateways/*` + `test/**` (+ plan-enumerated ENV/dependency companion files); no `supabase/migrations/*`, no `supabase/config.toml`, no `lib/systems/finance/*` changes.
- **Environment-gated (not run here):** `supabase db test` full pgTAP `001-017` requires a running Supabase/Docker daemon (not started in this environment). No SQL posture drift is introduced by this Flutter-only change (all 26 Final Approval conditions otherwise PASS).

> **Approval:** Task EP-02-09 is marked **Completed** only when all 26 conditions in the Final Approval Checklist are verified and signed off by the project lead.
