# VFD / PSL BaaS API — Technical Reference

> **Status: documentation only.** This collection records the official VFD / Product Studio Limited
> (PSL) Banking-as-a-Service API documentation as retrieved on **6 November 2026**. It contains no
> integration code, credentials, architectural decisions, or changes to Hivorr behaviour.
>
> **Primary source:** [VFD BaaS API documentation](https://vbaas-docs.vfdtech.ng/docs/category/api---docs)
> **Publisher shown on the site:** Product Studio Limited (PSL), a VFD Group subsidiary.
> **Banking partner named in the documentation:** VFD Microfinance Bank.

---

## 1. Purpose

This is a reusable technical reference for the VFD / PSL BaaS APIs. It is intended to let another
engineer or AI agent understand the documented capabilities without re-crawling the vendor site.

It does **not** decide which VFD products Hivorr will use. Product selection, custody scope, contract
terms, licensing, and architecture remain separate decisions.

---

## 2. Source coverage

The official Docusaurus sitemap exposed **18 URLs**: one category page, one getting-started page,
one authorization page, one wallet API page, and fourteen other product/KYC pages. All **17 content
pages** were successfully retrieved. No official documentation page returned an access failure.

| # | Page | Source URL | Local reference |
| --- | --- | --- | --- |
| 1 | API — Docs (category) | https://vbaas-docs.vfdtech.ng/docs/category/api---docs | This README |
| 2 | Getting Started | https://vbaas-docs.vfdtech.ng/docs/intro | [VFD_OVERVIEW.md](VFD_OVERVIEW.md) |
| 3 | Authorization | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Authorization/ | [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md) |
| 4 | Wallets | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/wallets-api | [VFD_WALLET.md](VFD_WALLET.md) |
| 5 | Bills Payment | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/bills-payment-api | [VFD_BILLS_PAYMENT.md](VFD_BILLS_PAYMENT.md) |
| 6 | Card Payment | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/card-api | [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md) |
| 7 | Debit Mandates | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/direct-debit | [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md) |
| 8 | Loans | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/loans-api | [VFD_LOANS.md](VFD_LOANS.md) |
| 9 | Payment Link | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/payment-link-api | [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) |
| 10 | Payment Widget | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/payment-widget | [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) |
| 11 | POS Infrastructure | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/vfd-pos | [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) |
| 12 | KYC Document Upload API | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/kyc-document-upload-api | [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md) |
| 13 | KYC — AML Verification | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/aml-verification | [VFD_KYC.md](VFD_KYC.md) |
| 14 | KYC — Driver License Verification | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/driverlicense-verfication | [VFD_KYC.md](VFD_KYC.md) |
| 15 | KYC — Image Match Verification | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/imagematch | [VFD_KYC.md](VFD_KYC.md) |
| 16 | KYC — Liveness Check | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/livenesscheck | [VFD_KYC.md](VFD_KYC.md) |
| 17 | KYC — NIN Verification | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/nin-api | [VFD_KYC.md](VFD_KYC.md) |
| 18 | Debit Cards | https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/debit-card | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) |

### External pages referenced by the official documentation

The POS page links to seven unique Lux/Notion documents across eight links (the Cashout document is
linked twice). These are **outside** the official documentation site and were not retrievable by the
extraction tool (transport error or client-rendered page with no content). They are recorded, not
reproduced, in [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md).

---

## 3. Documentation index

### Foundations

- **[VFD_OVERVIEW.md](VFD_OVERVIEW.md)** — platform, legal context, environments, base URLs, product
  inventory, wallet implementation models, conventions and coverage gaps.
- **[VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md)** — access-token generation for test and live,
  token validity, required header, and undocumented authentication details.

### Money movement and accounts

- **[VFD_WALLET.md](VFD_WALLET.md)** — individual/corporate account creation, tiers and upgrades,
  virtual accounts, BVN/KYC enquiry, account and beneficiary enquiry, bank list, single and bulk
  transfers, transfer status and reversal, simulated credits, transaction history, QR code services,
  account remediation, and Lux POS status endpoints.
- **[VFD_BILLS_PAYMENT.md](VFD_BILLS_PAYMENT.md)** — biller discovery, customer validation, bill
  payment, transaction status, and bill-payment response codes.
- **[VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md)** — non-tokenized card payment, redirect/OTP flows,
  test cards, payment status, and card-payment notifications.
- **[VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md)** — direct and e-mandate setup, account debit,
  mandate/account/debit status, response codes, and bank codes.
- **[VFD_LOANS.md](VFD_LOANS.md)** — loan creation and disbursement, transaction status, repayment
  schedule, and loan portfolio.
- **[VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md)** — merchant profile setup and shareable payment-link
  generation.
- **[VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md)** — browser SDK, React package, widget fields and
  payment methods.
- **[VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md)** — LUX POS onboarding, webhook payload,
  operational model and externally hosted integration documents.

### Identity and cards

- **[VFD_KYC.md](VFD_KYC.md)** — AML screening, driver-license verification, image match, liveness
  check, and NIN verification.
- **[VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md)** — bulk KYC document bundle upload for
  individual and corporate accounts.
- **[VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md)** — virtual debit-card issuance, activation, PIN change,
  block/unblock, card transaction history, and card-management webhooks.

### Cross-cutting

- **[VFD_WEBHOOKS.md](VFD_WEBHOOKS.md)** — consolidated catalogue of every webhook, request/response
  webhook and notification found in the official documentation.
- **[VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md)** — Hivorr relevance (not a decision),
  security considerations, ambiguities, missing specifications and manual-verification checklist.
- **[VFD_DOCUMENTATION_AUDIT.md](VFD_DOCUMENTATION_AUDIT.md)** — audit of this collection against the
  official documentation, corrections applied, unverified external material and outstanding questions.

---

## 4. How to read this collection

Each document uses these labels:

| Label | Meaning |
| --- | --- |
| **Confirmed** | Stated by the official VFD/PSL documentation. |
| **Observation** | A pattern, inconsistency or inference drawn from the documentation, not a vendor guarantee. |
| **Not documented** | The official documentation does not state this. It is not a claim that the capability does not exist. |
| **Open question** | Requires vendor, contract, legal or engineering clarification. |

Rules applied during extraction:

1. Endpoints, fields and response values are reproduced only where the official documentation states
   them.
2. Where examples and prose disagree, both are recorded and the discrepancy is flagged.
3. JSON examples are preserved in fenced code blocks. Placeholder credentials are left as `XXXXXX`,
   matching the vendor documentation.
4. No live credential, secret, token or customer data is included.
5. No endpoint was inferred from naming conventions alone.

---

## 5. Coverage summary

| Area | Documented pages | Endpoints documented |
| --- | --- | --- |
| Authentication | 1 | 2 (test + live token URLs, same operation) |
| Wallets / accounts / transfers / QR | 1 | 30+ operations (see wallet document) |
| Bills Payment | 1 | 6 |
| Card Payment | 1 | 3 |
| Debit Mandates | 1 | 6 |
| Loans | 1 | 4 |
| Payment Link | 1 | 2 |
| Payment Widget | 1 | 0 REST endpoints; browser SDK only |
| POS Infrastructure | 1 | 0 dedicated REST endpoints; 2 shared wallet endpoints + external docs |
| KYC Document Upload | 1 | 1 |
| KYC verification | 5 | 5 |
| Debit Cards | 1 | 6 + 3 card webhooks |

Exact endpoint counts are deliberately conservative: the wallet page groups many operations under
one page and some listed operations have no request/response sample.

---

## 6. Important limitations of the source

The official documentation is uneven. The following gaps affect any future integration and are
expanded in [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md):

- No OpenAPI/Swagger specification is published on the documentation site.
- No rate limits, retry policy, idempotency window, request timeout, or pagination defaults are stated.
- No webhook signature algorithm is documented. One POS payload contains an unexplained `hash` field.
- Error catalogues exist for bills, transfers, mandates and KYC upload, but not for every product.
- Some endpoints state a method that conflicts with their query-string shape.
- Some base URLs differ between test and live beyond the host name.
- Payment Link has no documented status-verification endpoint.
- Loans refer to an onboarding endpoint that is not documented on the loans page.
- The Payment Widget places a wallet access token in browser code by design; this needs a security
  review before Hivorr considers it.

---

## 7. Related Hivorr context (not part of the VFD source)

These existing Hivorr documents provide the surrounding decisions. They are **not** vendor
documentation and must not be read as VFD requirements:

- [`documents/Business-Roadmap/Business-Development-Roadmap.md`](../../Business-Roadmap/Business-Development-Roadmap.md)
  — BD-D11 selects VFD as the single payment and custody partner, conditional on written scope
  confirmation.
- [`documents/Context/ARCHITECTURE.md`](../../Context/ARCHITECTURE.md) — provider-agnostic
  ledger and the VFD adapter boundary.
- [`documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`](../../Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md)
  — audit-readiness, security and third-party requirements.
- [`documents/Context/Unified-Account-and-Activity-Permission-Matrix.md`](../../Context/Unified-Account-and-Activity-Permission-Matrix.md)
  — KYC tiers and capability gating.

See [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md) for the relevance mapping and the explicit
list of decisions that remain outside this documentation task.

---

## 8. Maintenance

If the vendor site changes:

1. Re-check the sitemap at `https://vbaas-docs.vfdtech.ng/sitemap.xml`.
2. Record the retrieval date and the changed page URL.
3. Update the affected document and the coverage table above.
4. Keep discrepancies visible rather than silently "fixing" them.

**Retrieval date:** 6 November 2026.
