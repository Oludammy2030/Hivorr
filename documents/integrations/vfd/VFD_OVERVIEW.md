# VFD / PSL BaaS — Platform Overview

> **Source:** [Getting Started](https://vbaas-docs.vfdtech.ng/docs/intro) and the
> [API — Docs category](https://vbaas-docs.vfdtech.ng/docs/category/api---docs).
> **Retrieved:** 6 November 2026. **Documentation only — no integration code.**

---

## 1. What the platform is

The documentation is published as **“PSL API Documentation”** and describes the **Product Studio
Limited (PSL) BaaS Platform**. PSL describes itself as a VFD Group subsidiary whose Banking-as-a-Service
platform lets businesses (aggregators and fintechs) build financial products through APIs.

The platform targets fintech applications, marketplaces, ERP solutions, agency banking, and embedded
finance. Documented capability areas include:

- customer wallets and virtual accounts for collections;
- bank transfers and payouts;
- bank-account and customer-identity verification;
- card, transfer, USSD and QR payment acceptance;
- physical and virtual cards;
- bill payments and airtime;
- POS and offline payment services;
- agency-banking and merchant solutions.

**Confirmed banking relationship:** PSL provides the technology platform and API infrastructure.
Banking services are provided in partnership with **VFD Microfinance Bank**, also a VFD Group
subsidiary. Account details, bank names, transaction records and other financial data returned by the
platform may reference VFD Microfinance Bank as the underlying financial institution.

> This is vendor-stated context. It is **not** confirmation of Hivorr's contractual scope, licence
> coverage, escrow permission, or settlement terms. Those are separate decisions tracked in Hivorr's
> business and architecture documents.

---

## 2. Onboarding and credentials

The getting-started page states that an integrator needs:

1. a registered VFD Bank account;
2. access to the VBaaS Dashboard;
3. API credentials.

### 2.1 Onboarding steps documented by PSL

1. **Create a BaaS account.** Contact `Business@theproductstudiohq.com`. During onboarding PSL states
   it will understand the use case, share compliance/KYC documents, provide a business-profile setup
   link, and enable applicable products.
2. **Access the VBaaS Dashboard.** The dashboard is described as the management console for
   applications, API-key generation/rotation, sandbox and production credentials, webhooks, API
   activity, transaction logs, settlement accounts, reports, balances and integration status.
3. **Get API credentials.** The documentation names **Consumer Key**, **Consumer Secret**, and
   **API Key** as possible credentials depending on the service. Exact generation steps are said to
   be provided during onboarding and are **not published** on the documentation site.
4. **Choose an environment.** Sandbox for building and simulated transactions; production after PSL
   certification.
5. **Make a request.** All APIs are exposed over HTTPS and accept JSON. A typical request includes
   authorization credentials, `Content-Type: application/json`, and a payload.

> **Not documented:** the credential-to-product matrix, key rotation procedure, sandbox certification
> criteria, approval SLAs, and whether separate credentials exist per product. These require the
> onboarding pack or PSL confirmation.

---

## 3. Environments and base URLs

The documentation publishes separate test and live hosts. Product paths are not uniform; some differ
by more than the host.

| Product | Test base URL | Live base URL |
| --- | --- | --- |
| Authorization (token) | `https://api-devapps.vfdbank.systems/vtech-wallet/api/v2/wallet2/token` | `https://api-apps.vfdbank.systems/vtech-wallet/api/v2/wallet2/token` |
| Wallets / accounts / transfers | `https://api-devapps.vfdbank.systems/vtech-wallet/api/v2/wallet2` | `https://api-apps.vfdbank.systems/vtech-wallet/api/v2/wallet2` |
| Bills Payment | `https://api-devapps.vfdbank.systems/vtech-bills/api/v2/billspaymentstore` | `https://api-apps.vfdbank.systems/vtech-bills/api/v2/billspaymentstore` |
| Card Payment | `https://api-devapps.vfdbank.systems/vtech-cards/api/v2/baas-cards` | `https://api-apps.vfdbank.systems/vtech-cards/api/v2/baas-cards` |
| Debit Cards | `https://api-devapps.vfdbank.systems/vtech-cards/api/v2/baascards` | `https://api-apps.vfdbank.systems/vtech-cards/api/v2/baascards` |
| Debit Mandates | `https://api-devapps.vfdbank.systems/vtech-mandate/api/v2/directdebit` | `https://api-apps.vfdbank.systems/vtech-mandate/api/v2/directdebit` |
| Loans | `https://api-devapps.vfdbank.systems/vtech-credit/api/v2/credit` | `https://api-apps.vfdbank.systems/vtech-credit/api/v2/credit` |
| Payment Link | `https://api-devapps.vfdbank.systems/vtech-payment/api/v2/payments` | `https://api-apps.vfdbank.systems/vtech-payment-link/api/v2/payments` |
| KYC (AML, driver licence, image match, NIN) | `https://api-devapps.vfdbank.systems/vtech-kyc/api/v2/kyc` | `https://api-apps.vfdbank.systems/vtech-kyc/api/v2/kyc` |
| Liveness Check | `https://api-devapps.vfdbank.systems/vtech-wallet/api/v2/wallet2` | `https://api-apps.vfdbank.systems/vtech-wallet/api/v2/wallet2` |

### 3.1 Environment observations

- **Confirmed:** test and live use different hostnames: `api-devapps.vfdbank.systems` and
  `api-apps.vfdbank.systems`.
- **Confirmed:** the Payment Link live path is `/vtech-payment-link/...` while test uses
  `/vtech-payment/...`.
- **Confirmed:** Debit Cards uses `/baascards`, while Card Payment uses `/baas-cards`.
- **Observation:** sandbox behaviour differs from production in several documented areas: limited
  billers in development, mandate payer/receiver restrictions, simulated inbound credit via
  `/credit`, and test BVN/RC datasets. A sandbox pass does not prove production parity.

---

## 4. Product inventory

| Product area | Documented scope | Local reference |
| --- | --- | --- |
| Authorization | One token operation, shared by all documented products | [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md) |
| Wallets | Individual and corporate accounts, tiers, virtual accounts, BVN lookup, transfers, bulk transfers, transaction history, QR, account remediation, POS status helpers | [VFD_WALLET.md](VFD_WALLET.md) |
| Bills Payment | Biller categories/list/items, customer validation, payment, status | [VFD_BILLS_PAYMENT.md](VFD_BILLS_PAYMENT.md) |
| Card Payment | Non-tokenized card collection with redirect or OTP, status | [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md) |
| Debit Mandates | Direct mandate, e-mandate, account debit, mandate/account/debit status | [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md) |
| Loans | Create/disburse, status, repayment schedule, portfolio | [VFD_LOANS.md](VFD_LOANS.md) |
| Payment Link | Merchant setup, link generation | [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) |
| Payment Widget | Browser SDK and React package | [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) |
| POS Infrastructure | LUX onboarding, webhook, external SDK documentation | [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) |
| KYC Document Upload | One bulk bundle-upload endpoint | [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md) |
| KYC verification | AML, driver licence, image match, liveness, NIN | [VFD_KYC.md](VFD_KYC.md) |
| Debit Cards | Virtual-card create/activate/PIN/block/unblock/history | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) |
| Webhooks | Inward credit, payout, card, debit-card, POS; Payment Link notification is mentioned only | [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) |

---

## 5. Wallet implementation models

The wallet page documents two implementation models. They affect where funds sit, how charges are
deducted, and how transfers must be constructed.

### 5.1 POOL

- Funds entering sub-accounts are swept automatically to the corporate/pool account.
- Inward and outward charges are deducted from the corporate account.

### 5.2 1-1

- Funds entering sub-accounts remain in those accounts and are not swept to the corporate account.
- Outward charges are deducted from the customer's account.
- Inward charges are deducted from the corporate account.

> **Not documented:** how an integrator chooses or changes the model, whether both can coexist, the
> exact sweep timing, or reconciliation semantics. These require PSL confirmation.

The distinction appears again in the Debit Cards documentation: POOL merchants must expose
**debit-authorisation** and **balance-check** webhooks so VFD can validate card debits against the
merchant's ledger. See [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md).

---

## 6. Common request conventions

The getting-started page gives a general convention, but each product page repeats its own details.

| Convention | Documented position |
| --- | --- |
| Transport | HTTPS |
| Request body | JSON (`Content-Type: application/json` is stated in getting started and in the KYC upload page; not repeated on every page) |
| Authentication header | `AccessToken: {{token}}` on every documented product endpoint |
| Token type returned | `Bearer` |
| Reference format | Many products require a unique reference prefixed with the wallet name, e.g. `rosapay-1234` or `TestWallet-...` |
| Date formats | Product-specific and inconsistent; see each document |
| Amount format | Usually a JSON string in naira; some products use numbers |
| Response envelope | Usually `{ "status": "...", "message": "...", "data": ... }` |

### 6.1 Response envelope is not uniform

**Observation:** although most endpoints return a top-level `status` string, the documentation shows
exceptions:

- Debit mandate account balance and mandate status return `"status": "200"`.
- AML verification returns a top-level object with `responseCode`, `hasError`, `message` all `null`,
  and a nested `data.status` of `"200"`.
- Card initiation returns `success: true` plus a `data` object rather than a top-level `status`.
- KYC upload uses top-level `status` values `00`, `01`, `98`, `99`, `500`.
- Transfer and bill failures use domain codes such as `99`, `108`, `199`, `500`.

Do not build a single cross-product parser without mapping each product's documented shape.

### 6.2 HTTP status codes

The official documentation generally describes **business response codes in the JSON body**, not HTTP
status codes. It does not publish a per-endpoint HTTP status table, rate-limit status, or standard
error schema. See [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md).

---

## 7. Test data published by VFD

The documentation publishes sandbox data rather than a separate sandbox guide:

| Data | Where documented |
| --- | --- |
| BVN bio-data and OTPs for account/KYC testing | [VFD_WALLET.md](VFD_WALLET.md) §16.1 |
| RC numbers for corporate account testing | [VFD_WALLET.md](VFD_WALLET.md) §5.3 |
| Inter/intra transfer test accounts | [VFD_WALLET.md](VFD_WALLET.md) §9.7 |
| Simulated inbound credit sender account/bank | [VFD_WALLET.md](VFD_WALLET.md) §10 |
| Card test numbers (Verve, Visa, Mastercard) | [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md) §6 |
| Mandate payer/receiver test accounts | [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md) §5 |
| Driver-licence test payload | [VFD_KYC.md](VFD_KYC.md) §3 |

These values are vendor-published test data. They must never be used in production and do not imply
that the same identifiers work in every product.

---

## 8. What the documentation does not provide

The following are absent from the official site and are not invented here:

- an OpenAPI/Swagger/Postman collection;
- rate limits or quotas;
- request timeouts and retry guidance (beyond transfer-status polling guidance);
- idempotency keys or a deduplication window (references are described as unique, but the enforcement
  behaviour is not specified);
- webhook signature algorithm, timestamp tolerance or retry schedule;
- API versioning/deprecation policy;
- per-endpoint HTTP status codes;
- a complete cross-product error-code registry;
- data-retention or deletion rules for KYC documents and card data;
- PCI-DSS scope statements for card-data handling;
- service-level agreements.

---

## 9. Related documents

- [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md) — how requests are authorized.
- [VFD_WALLET.md](VFD_WALLET.md) — the largest product surface.
- [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) — event catalogue.
- [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md) — Hivorr relevance, security and open questions.
- [README.md](README.md) — navigation and coverage table.
