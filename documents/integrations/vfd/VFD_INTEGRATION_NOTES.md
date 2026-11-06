# VFD Integration Notes — Relevance, Risks, and Open Questions

> **Status: documentation only.** This document does **not** select VFD products, approve an
> architecture, define data models, or authorize any code change. It synthesises the vendor material in
> this directory and records what must be verified before Hivorr could rely on it.
>
> **Retrieved:** 6 November 2026.

---

## 1. Scope and method

The assignment was to research the official VFD/PSL BaaS API and document it for future Hivorr
integration. The constraints were:

- documentation only;
- no integration code;
- no wallet, payment, or transaction changes;
- no authentication changes;
- no schema or migration changes;
- no new dependencies;
- no new functionality.

The vendor's official Docusaurus sitemap exposed **18 URLs**: one category page, one getting-started
page, one authorization page, and fifteen product/KYC pages. All **17 content pages** were retrieved
successfully. Seven further documents linked from the POS page are hosted on Lux/Notion and were
**not retrievable**. They are listed in §3.

**No application file was modified.** See §10.

---

## 2. What the documentation covers

| Area | Local reference | Vendor pages |
| --- | --- | --- |
| Platform, environments, base URLs | [VFD_OVERVIEW.md](VFD_OVERVIEW.md) | Getting Started, category index |
| Access tokens | [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md) | Authorization |
| Accounts, transfers, QR, status | [VFD_WALLET.md](VFD_WALLET.md) | Wallets |
| Bill payments | [VFD_BILLS_PAYMENT.md](VFD_BILLS_PAYMENT.md) | Bills Payment |
| Card acceptance | [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md) | Card Payment |
| Direct debits / mandates | [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md) | Debit Mandates |
| Lending | [VFD_LOANS.md](VFD_LOANS.md) | Loans |
| Payment links | [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) | Payment Link |
| Browser payment widget | [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) | Payment Widget |
| POS / LUX acquiring | [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) | POS Infrastructure |
| KYC document bundle | [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md) | KYC Document Upload |
| KYC verification | [VFD_KYC.md](VFD_KYC.md) | AML, Driver License, Image Match, Liveness, NIN |
| Card issuing | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) | Debit Cards |
| Webhooks | [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) | Cross-product |

---

## 3. Pages discovered but not retrieved

These are linked from the official POS page but hosted outside the documentation site. The tool
returned a transport error or a client-rendered page with no content. They are recorded, not mirrored.

| Title | URL | Access problem | Manual review |
| --- | --- | --- | --- |
| POS Device management | `https://www.notion.so/POS-Device-Management-19318e9298674c2c8f7e9b92200d1554` | Notion; not retrieved | Yes — terminal onboarding |
| Transaction Monitor | `https://www.notion.so/TransactionMonitor-83d454917891486eaa3cfefc9615be10` | Notion; not retrieved | Yes — monitoring |
| Lux SDK Doc / LUX Cashout | `https://www.notion.so/LUX-Cashout-4f3f5abb5e504f009b97788461f761fc` | Notion; not retrieved | Yes — cashout SDK |
| POS | `https://www.notion.so/POS-ecf196fdd0854c409081b6e5d07f296d` | Notion; not retrieved | Yes — POS SDK |
| Java Implementation | `https://www.notion.so/Java-Implementation-56968116c3e640769581b8473f37dcc2` | Notion; not retrieved | Yes — reference implementation |
| Triple DES encryption | `https://www.notion.so/Java-TripleDes-Encryption-a803c4008e0b48ce887987c52353d9aa` | Notion; not retrieved | Yes — encryption scheme |
| Terminal Type Topwise T1 | `https://www.notion.so/Big-Topwise-SDK-Usage-T1-a11f64db4e6440b8b988117cccbd1d47` | Notion; not retrieved | Yes — terminal SDK |

The POS page links the Cashout document twice (as "Lux SDK Doc" and "Cashout"), so there are seven
unique external documents across eight links.

**No official documentation page on `vbaas-docs.vfdtech.ng` returned an access failure.**

---

## 4. Relevance to Hivorr (mapping only — not a decision)

This table maps documented capabilities to Hivorr concerns. It is **not** a product selection.

| Hivorr concern | Potentially relevant VFD capability | Reference |
| --- | --- | --- |
| Collection accounts / virtual accounts | Individual and corporate account creation, virtual accounts, sub-accounts | [VFD_WALLET.md](VFD_WALLET.md) |
| Inbound payment detection | Inward Credit Notification, Initial Inward Credit Notification | [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) §3–4 |
| Outbound payouts | Single/bulk transfers, transfer status, payout webhook | [VFD_WALLET.md](VFD_WALLET.md), [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) §5 |
| Reconciliation | Transaction status query (TSQ), reversal status query, card transaction history | [VFD_WALLET.md](VFD_WALLET.md), [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) |
| Customer identity / KYC tiers | Account tiers, upgrades, BVN/KYC enquiry, NIN, liveness, image match, document bundle | [VFD_WALLET.md](VFD_WALLET.md), [VFD_KYC.md](VFD_KYC.md), [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md) |
| AML / sanctions screening | AML verification | [VFD_KYC.md](VFD_KYC.md) §2 |
| Card acceptance | Non-tokenized card payment, payment widget | [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md), [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) |
| Card issuing | Virtual debit cards | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) |
| Recurring collection | Direct debit / e-mandate | [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md) |
| Bill payments | Biller discovery, validation, payment | [VFD_BILLS_PAYMENT.md](VFD_BILLS_PAYMENT.md) |
| Merchant links | Payment Link | [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) |
| In-person acquiring | LUX POS | [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) |
| Lending | Loan creation, repayment schedule | [VFD_LOANS.md](VFD_LOANS.md) |

### 4.1 Related Hivorr context

These documents are Hivorr's own context, not vendor requirements:

- [`documents/Business-Roadmap/Business-Development-Roadmap.md`](../../Business-Roadmap/Business-Development-Roadmap.md)
  — records the VFD single payment/custody direction, conditional on written scope confirmation.
- [`documents/Context/ARCHITECTURE.md`](../../Context/ARCHITECTURE.md) — provider-agnostic
  ledger and the adapter boundary any provider must fit.
- [`documents/Context/Unified-Account-and-Activity-Permission-Matrix.md`](../../Context/Unified-Account-and-Activity-Permission-Matrix.md)
  — KYC tiers and capability gating.
- [`documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`](../../Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md)
  — audit, security, and third-party requirements.
- [`documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md`](../../Context/Database-Migration-and-Supabase-Data-API-Rules.md)
  — database governance; relevant if VFD identifiers are ever stored.

**Important:** the architecture's provider-agnostic ledger means VFD-specific payloads should not leak
into the domain model. Any future adapter would translate VFD envelopes into Hivorr's own transaction
states. This document does not design that adapter.

---

## 5. Security concerns

Ordered roughly by severity. Each is expanded in the linked document.

### 5.1 Critical / high

| # | Concern | Where |
| --- | --- | --- |
| 1 | **Non-expiring access tokens.** The token request accepts `validityTime: "-1"` for a token with no expiry. A leaked token grants indefinite access. | [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md) |
| 2 | **Wallet token in the browser.** The Payment Widget requires the wallet access token in client-side JavaScript. It is not described as scoped, short-lived, or origin-restricted. | [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) §8 |
| 3 | **Full card data returned.** Virtual-card creation returns full `pan`, `cvv`, `track2`, and `pinOffset`; activation returns the default PIN. This puts the integrator in PCI DSS scope. | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) §3, §4 |
| 4 | **Card data accepted by API.** Non-tokenized card payment sends PAN, PIN, CVV2, and expiry in the request body. | [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md) |
| 5 | **No webhook signature scheme.** No HMAC, shared secret, timestamp, event ID, or replay protection is documented for any webhook. | [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) §12 |
| 6 | **Unverifiable POS `hash`.** The POS payload contains a `hash` field with no algorithm or key. | [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) §3 |
| 7 | **Base64 PII in JSON.** KYC documents, biometric images, BVN, and NIN travel inline and can leak into logs and traces. | [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md) §7, [VFD_KYC.md](VFD_KYC.md) §8 |

### 5.2 Medium

| # | Concern | Where |
| --- | --- | --- |
| 8 | **No documented rate limits or lockouts.** Token, KYC, card, and transfer endpoints give no throttling or enumeration guidance. | Multiple |
| 9 | **Account enumeration via error messages.** KYC upload distinguishes "account not found" from validation failure. | [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md) §6.2 |
| 10 | **PINs in JSON.** PIN change sends old and new PIN in plaintext fields; no HSM/PIN-block format is documented. | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) §5 |
| 11 | **Synchronous authorization callback.** The debit-authorization webhook sits in the payment path; timeout and failure behaviour are undocumented. | [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) §7.2 |
| 12 | **No idempotency contract.** Card creation and transfers are stateful POSTs with no documented idempotency key. | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md), [VFD_WALLET.md](VFD_WALLET.md) |
| 13 | **AML outcome not exposed.** "Data added successfully" is not a screening pass. | [VFD_KYC.md](VFD_KYC.md) §2.2 |
| 14 | **Secrets in prose.** One transfer signature secret is described as "Contact admin" rather than provisioned through a documented channel. | [VFD_WALLET.md](VFD_WALLET.md) |

### 5.3 Lower, but still material

| # | Concern | Where |
| --- | --- | --- |
| 15 | Error catalogues are incomplete and inconsistent across products. | Multiple |
| 16 | Some endpoints return HTTP-success envelopes with business failures; naive clients will misread them. | [VFD_BILLS_PAYMENT.md](VFD_BILLS_PAYMENT.md), [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) |
| 17 | Test and live base paths differ beyond the host for Payment Link and Liveness. | [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md), [VFD_KYC.md](VFD_KYC.md) §1 |
| 18 | No published OpenAPI/Swagger schema. | All |

---

## 6. Ambiguities and inconsistencies found

These are vendor-documentation issues, preserved rather than silently corrected.

| Area | Issue | Reference |
| --- | --- | --- |
| Token validity | `"-1"` is documented as non-expiring; no maximum lifetime is stated. | [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md) |
| Payment Link URLs | Test path `vtech-payment`, live path `vtech-payment-link`. Not host-only. | [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) §1 |
| Liveness base URL | Grouped under KYC but uses the wallet base. | [VFD_KYC.md](VFD_KYC.md) §1 |
| `firstname` vs `firstName` | AML uses lowercase; Driver License and NIN use camelCase. | [VFD_KYC.md](VFD_KYC.md) §7 |
| Date formats | `DD-Mon-YYYY`, `YYYY-MM-DD`, and `DD-MM-YYYY` all appear in the KYC set. | [VFD_KYC.md](VFD_KYC.md) §7 |
| AML response envelope | `responseCode`/`hasError`/`message` null; `data.status: "200"`. | [VFD_KYC.md](VFD_KYC.md) §2.2 |
| NIN echo | Request `11111222221`, response `idNumber: 45629461922`. | [VFD_KYC.md](VFD_KYC.md) §6.2 |
| NIN match flags | `firstNameMatch`/`lastNameMatch`/`dobMatch` are false with no comparison inputs in the request. | [VFD_KYC.md](VFD_KYC.md) §6.2 |
| Image match "success" | `status: "00"` and `"Successful"` even when `isMatch: false`. | [VFD_KYC.md](VFD_KYC.md) §4.2 |
| Liveness numeric strings | `probability`, `score`, `quality` are strings. | [VFD_KYC.md](VFD_KYC.md) §5.2 |
| Debit mandate fields | Conflicting names such as `payerAccountNummber`, `payerAccountname`, `receiverBvn`. | [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md) |
| Mandate balance/status | Response `status: "200"` instead of `"00"`. | [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md) |
| Card base paths | Accepting uses `baas-cards`; issuing uses `baascards`. | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) §1 |
| Card transaction history | `POST` with query parameters and no body. | [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) §8 |
| Card payment status | No HTTP method is stated for `/payment-details`. | [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md) |
| POS `settledAmount` | 990 against `amount` 800. | [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) §3 |
| POS field semantics | Not defined by the vendor. | [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) §3 |
| KYC document type case | Request camelCase; response `UPPER_SNAKE_CASE`. | [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md) §6.1 |
| KYC "resource identifiers" | Flow promises them; response shows none. | [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md) §6.1 |
| Loan onboarding | The loans page refers to an onboarding step that is not documented there. | [VFD_LOANS.md](VFD_LOANS.md) |
| Transfer signature secret | Described as "Contact admin". | [VFD_WALLET.md](VFD_WALLET.md) |
| Payment Link notification | Asserted in flow, no payload or event. | [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) §5 |

---

## 7. Missing specifications (consolidated)

| Category | Missing |
| --- | --- |
| Contract | OpenAPI/Swagger/JSON Schema |
| Environments | Sandbox data reset policy, test-vs-live behavioural differences |
| Limits | Rate limits, payload limits, pagination maxima, transfer limits |
| Reliability | Timeouts, retry policy, idempotency window, duplicate handling |
| Webhooks | Signature, secret rotation, retries, event IDs, ordering, replay window, source IPs |
| Errors | Complete per-product catalogues and HTTP-status mapping |
| Money | Fee rules, settlement timing, rounding, currency handling, reversal timing |
| Identity | AML outcome retrieval, image-match threshold, liveness quality threshold, retention |
| Cards | PCI guidance, tokenization, 3-D Secure details, card funding/limits |
| POS | Key exchange, terminal certification, settlement, chargebacks, SDK details (external) |
| Payment Link | Status endpoint, notification contract, link reuse/cancellation |
| Loans | Onboarding endpoint, eligibility, pricing, repayment mechanics |
| Operations | Support escalation, incident contacts, status page, change notifications |

---

## 8. Manual verification checklist

Questions to put to PSL/VFD before any integration decision. None of these are answered by the
published documentation.

### 8.1 Access and environments

- [ ] Provide the test and live credentials through an approved channel.
- [ ] Confirm which products are contractually available to Hivorr.
- [ ] Confirm test/live base URLs for every product, including Payment Link and Liveness.
- [ ] Confirm whether there is a sandbox reset schedule and whether test data persists.
- [ ] Provide a status page and incident contact.

### 8.2 Authentication

- [ ] What is the maximum supported token lifetime?
- [ ] Can tokens be scoped to specific products or operations?
- [ ] Is there a short-lived, origin-restricted token for the Payment Widget?
- [ ] How are `consumerKey`/`consumerSecret` rotated?
- [ ] What are the authentication error codes and HTTP statuses?

### 8.3 Webhooks

- [ ] Is there a signature scheme (HMAC/RSA)? Provide the algorithm and test vectors.
- [ ] Provide the source IP ranges for allow-listing.
- [ ] What are the retry schedule, timeout, and maximum attempts?
- [ ] Is delivery at-least-once? Provide event/delivery IDs.
- [ ] How should duplicate and out-of-order events be handled?
- [ ] Provide the Payment Link notification contract.
- [ ] Explain the POS `hash` field and how to verify it.
- [ ] Explain the debit-authorization decision semantics and timeout.
- [ ] Can card-payment failures be notified?

### 8.4 Money movement

- [ ] Provide the complete fee, settlement, and reversal rules.
- [ ] Is there an idempotency key for transfers and card creation?
- [ ] What are the transfer and balance limits per tier?
- [ ] What is the reconciliation source of truth: webhook or status query?
- [ ] How are partial failures and reversals represented?

### 8.5 Identity and cards

- [ ] How is the AML screening result retrieved?
- [ ] What similarity threshold does image match use, and can it be configured?
- [ ] What quality threshold should be applied to liveness?
- [ ] Is image match liveness-bound?
- [ ] Is there a PCI-compliant card-issuing mode without full PAN/CVV?
- [ ] How is the default PIN delivered to the cardholder?
- [ ] What are the document size/format limits for KYC upload?
- [ ] What is the retention and deletion policy for KYC documents?

### 8.6 Operations

- [ ] Who supports each product (PSL vs VFD)?
- [ ] What are the escalation paths for failed transfers, stuck cards, and missing webhooks?
- [ ] Are there change-notification and deprecation policies?

---

## 9. Documentation quality assessment

**Strengths**

- Broad product coverage across collections, payouts, cards, KYC, mandates, and lending.
- Consistent `AccessToken` header and mostly consistent `status`/`message`/`data` envelope.
- Concrete request/response examples for most operations.
- Error tables for bills, transfers, mandates, and KYC upload.
- Explicit warnings about test/live URL differences in several places.

**Weaknesses**

- No machine-readable specification.
- No cross-product consistency for envelopes, codes, field casing, or date formats.
- No webhook security contract.
- No operational contract (limits, retries, idempotency, settlement).
- Several copy/paste errors in field descriptions and samples.
- Critical card and identity data handled in plain JSON without guidance.
- POS integration detail is external and inaccessible.
- Some products (Payment Link) are described as complete flows but lack verification.

**Overall:** sufficient to understand the product surface and plan due diligence; **not** sufficient to
build a production integration without vendor clarification and a security review.

---

## 10. Explicit confirmation of no code change

This task created documentation only.

- **No application code was added or modified.**
- **No wallet, payment, or transaction logic was changed.**
- **No authentication or authorization behaviour was changed.**
- **No database schema, migration, RLS policy, or Supabase configuration was changed.**
- **No dependency was added or upgraded.**
- **No new runtime functionality was introduced.**
- **No credentials, secrets, tokens, or customer data were written to the repository.**

The only repository change is the new `documents/integrations/vfd/` directory containing these Markdown
files. This can be confirmed with `git status --short`, which should show only untracked documentation.

---

## 11. Suggested next steps (non-binding)

1. **Internal review** of this collection by product, compliance, and security.
2. **Vendor clarification** using the checklist in §8.
3. **Contract review** of the products Hivorr actually needs, including settlement and support terms.
4. **Security review** of token scope, card-data handling, webhook authentication, and KYC data
   retention.
5. **Only then**, if approved, design a VFD adapter behind the provider-agnostic ledger boundary —
   as a separate, explicitly authorized task.

No step above is authorized by this document.

---

## 12. Document index

- [README.md](README.md)
- [VFD_OVERVIEW.md](VFD_OVERVIEW.md)
- [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md)
- [VFD_WALLET.md](VFD_WALLET.md)
- [VFD_BILLS_PAYMENT.md](VFD_BILLS_PAYMENT.md)
- [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md)
- [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md)
- [VFD_LOANS.md](VFD_LOANS.md)
- [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md)
- [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md)
- [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md)
- [VFD_KYC_DOCUMENT_UPLOAD.md](VFD_KYC_DOCUMENT_UPLOAD.md)
- [VFD_KYC.md](VFD_KYC.md)
- [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md)
- [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md)
