# VFD / PSL BaaS API Documentation Audit

> **Audit date:** 6 November 2026
> **Audit type:** documentation-only comparison of the local Markdown reference against the official
> VFD / Product Studio Limited (PSL) BaaS documentation.
> **Result:** **PARTIALLY COMPLETE** — all 17 retrievable official content pages were verified, but
> seven externally hosted Lux/Notion documents remain inaccessible and vendor ambiguities remain open.
>
> **No application code, schema, payment logic, wallet logic, dependency, or runtime behaviour was
> changed by this audit.** The only repository change is Markdown under `documents/integrations/vfd/`.

Status vocabulary used in this report:

| Status | Meaning |
| --- | --- |
| **COMPLETE** | The audit activity for that section is finished, with no known unverified item in scope. |
| **PARTIALLY COMPLETE** | Some in-scope items were verified, but at least one known item remains unverified or unresolved. |
| **INCOMPLETE** | The activity could not be completed, or the material required to complete it is unavailable. |

---

## 1. Scope and method

**Status: COMPLETE**

### 1.1 Objective

Verify that the local VFD reference in `documents/integrations/vfd/` accurately represents the official
VFD/PSL documentation; correct only genuine local errors; preserve vendor ambiguity rather than
inventing missing detail; and record everything that could not be verified.

### 1.2 In scope

- The official documentation site at `https://vbaas-docs.vfdtech.ng/`.
- The Docusaurus sitemap, which exposed **18 URLs**: one category page plus 17 content pages.
- The seven unique external Lux/Notion documents linked from the POS Infrastructure page, as
  discovered material (not as verified content).
- The local Markdown collection in `documents/integrations/vfd/`: `README.md` plus 15 topic documents.

### 1.3 Out of scope

- API implementation or client code.
- Application UI, wallet, payment, transfer, card, KYC, or lending functionality.
- Database schema, migrations, RLS policies, grants, or Supabase configuration.
- Commercial terms, pricing, contracts, licensing, and product selection.
- Adding dependencies or installing packages.
- Guessing undocumented behaviour, fields, endpoints, or error codes.

### 1.4 Method

1. Enumerated the official sitemap and recorded every URL.
2. Retrieved each official content page. Trailing-slash URLs were used because the non-trailing
   variants intermittently returned transport errors.
3. Extracted the rendered text of each page and compared it against the corresponding local
   Markdown document, section by section.
4. Re-checked endpoints, HTTP methods, paths, query parameters, request bodies, required/optional
   fields, headers, sample requests, sample responses, error examples, webhook payloads, security
   warnings, and test/live distinctions.
5. Cross-checked local internal links and section references mechanically.
6. Inspected the raw POS page HTML to distinguish rendered link text from the actual `href` values.
7. Attempted the seven external Lux/Notion links; none yielded retrievable content through the
   available tooling.
8. Applied only Markdown corrections that were directly supported by the official text.

### 1.5 Constraints and interpretation rules

- **Confirmed** = stated by the official documentation.
- **Observation** = an inference or inconsistency noted by the auditor, not a vendor guarantee.
- **Not documented** = the vendor does not state it; this is not proof that the capability is absent.
- Where vendor prose and examples disagree, both are recorded and the disagreement is flagged.
- No endpoint was inferred from naming convention alone.
- No credential, secret, token, or customer record is reproduced.

---

## 2. Pages discovered

**Status: COMPLETE**

### 2.1 Official sitemap URLs

The sitemap contained 18 URLs: one category page and 17 content pages.

| # | Official page | URL | Local reference | Retrieval |
| --- | --- | --- | --- | --- |
| 1 | API — Docs (category) | `https://vbaas-docs.vfdtech.ng/docs/category/api---docs` | `README.md` | Retrieved |
| 2 | Getting Started | `https://vbaas-docs.vfdtech.ng/docs/intro` | `VFD_OVERVIEW.md` | Retrieved |
| 3 | Authorization | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Authorization/` | `VFD_AUTHENTICATION.md` | Retrieved |
| 4 | Wallets | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/wallets-api` | `VFD_WALLET.md` | Retrieved |
| 5 | Bills Payment | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/bills-payment-api` | `VFD_BILLS_PAYMENT.md` | Retrieved |
| 6 | Card Payment | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/card-api` | `VFD_CARD_PAYMENT.md` | Retrieved |
| 7 | Debit Mandates | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/direct-debit` | `VFD_DEBIT_MANDATES.md` | Retrieved |
| 8 | Loans | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/loans-api` | `VFD_LOANS.md` | Retrieved |
| 9 | Payment Link | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/payment-link-api` | `VFD_PAYMENT_LINK.md` | Retrieved |
| 10 | Payment Widget | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/payment-widget` | `VFD_PAYMENT_WIDGET.md` | Retrieved |
| 11 | POS Infrastructure | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/vfd-pos` | `VFD_POS_INFRASTRUCTURE.md` | Retrieved (body); external links not |
| 12 | KYC Document Upload | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/kyc-document-upload-api` | `VFD_KYC_DOCUMENT_UPLOAD.md` | Retrieved |
| 13 | KYC — AML Verification | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/aml-verification` | `VFD_KYC.md` | Retrieved |
| 14 | KYC — Driver License Verification | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/driverlicense-verfication` | `VFD_KYC.md` | Retrieved |
| 15 | KYC — Image Match Verification | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/imagematch` | `VFD_KYC.md` | Retrieved |
| 16 | KYC — Liveness Check | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/livenesscheck` | `VFD_KYC.md` | Retrieved |
| 17 | KYC — NIN Verification | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/KYC/nin-api` | `VFD_KYC.md` | Retrieved |
| 18 | Debit Cards | `https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/debit-card` | `VFD_DEBIT_CARDS.md` | Retrieved |

### 2.2 Externally hosted pages discovered

The POS Infrastructure page links to seven unique Lux/Notion documents across eight links. These are
outside the official documentation site:

| # | Title | Host |
| --- | --- | --- |
| 1 | POS Device Management | `www.notion.so` |
| 2 | Transaction Monitor | `www.notion.so` |
| 3 | LUX Cashout / Lux SDK Doc | `www.notion.so` |
| 4 | POS | `www.notion.so` |
| 5 | Java Implementation | `www.notion.so` |
| 6 | Triple DES Encryption | `www.notion.so` |
| 7 | Terminal Type Topwise T1 | `www.notion.so` |

**Note:** the rendered page text shows `trylux.notion.site` for these links, but the raw `href`
values use `www.notion.so`. The local document records the raw targets, which is correct.

### 2.3 Discovery result

| Item | Count |
| --- | --- |
| Sitemap URLs | 18 |
| Official content pages | 17 |
| Official content pages retrieved | 17 |
| External Lux/Notion documents discovered | 7 |
| External documents retrieved | 0 |

---

## 3. Pages verified

**Status: PARTIALLY COMPLETE** — 16 official content pages were fully verified; the POS page body was
verified but its seven external dependencies were not.

| # | Page | Verified scope | Status |
| --- | --- | --- | --- |
| 2 | Getting Started | Platform description, PSL/VFD relationship, environments, onboarding statements | **COMPLETE** |
| 3 | Authorization | Test/live token URLs, `POST`, `consumerKey`, `consumerSecret`, `validityTime`, `-1` non-expiring token, `AccessToken` header | **COMPLETE** |
| 4 | Wallets | Base URL, implementation models, account creation, five tier-upgrade variants under `/client/update`, corporate accounts, sub-accounts, virtual accounts, BVN consent/lookup, enquiries, bank list, single/bulk transfers, TSQ/TRSQ, simulated credit, transaction history, QR, `/client/upgrade`, Lux helpers, test data, webhooks, response codes | **COMPLETE** |
| 5 | Bills Payment | Base URL, six operations, biller discovery, customer validation, payment, status, response codes | **COMPLETE** |
| 6 | Card Payment | Base URL, notification payload, redirect/OTP flows, non-tokenized payment, OTP validation, status, test cards, response codes | **COMPLETE** |
| 7 | Debit Mandates | Base URL, direct and e-mandate setup, payer/receiver test accounts, account debit, balance, approval/debit status, response codes, bank codes | **COMPLETE** |
| 8 | Loans | Base URL, create/disburse, status, repayment schedule, portfolio | **COMPLETE** |
| 9 | Payment Link | Base URL, differing test/live paths, merchant setup, link generation, fields, response codes | **COMPLETE** |
| 10 | Payment Widget | SDK/React packages, initialization fields, payment methods, callback handling, test/live behaviour | **COMPLETE** |
| 11 | POS Infrastructure | Product description, onboarding, LUX portal, webhook payload, test/live statements, operational limits | **PARTIALLY COMPLETE** |
| 12 | KYC Document Upload | Base URL, bulk upload, document types, base64 handling, response, errors | **COMPLETE** |
| 13 | AML Verification | Base URL, request fields, non-standard response envelope, errors | **COMPLETE** |
| 14 | Driver License Verification | Base URL, request fields, success/failure responses | **COMPLETE** |
| 15 | Image Match Verification | Base URL, request fields, match response semantics | **COMPLETE** |
| 16 | Liveness Check | Base URL (wallet base), request field, probability/score/quality response | **COMPLETE** |
| 17 | NIN Verification | Base URL, request field, response fields, match flags | **COMPLETE** |
| 18 | Debit Cards | Base URL, virtual card creation, activation, PIN change, block/unblock, history, webhooks | **COMPLETE** |

**Why this section is not COMPLETE:** the POS page's substantive integration detail is hosted in the
seven external documents listed in §4, and those were not retrievable. The POS body itself was
verified, but the page's full documentation set was not.

---

## 4. Pages not accessible

**Status: INCOMPLETE**

The following externally hosted documents were discovered but could not be retrieved by the available
tooling. They returned transport failures or client-rendered pages with no extractable content.

| # | Document | Recorded URL | Access result |
| --- | --- | --- | --- |
| 1 | POS Device Management | `https://www.notion.so/POS-Device-Management-19318e9298674c2c8f7e9b92200d1554` | Not retrieved |
| 2 | Transaction Monitor | `https://www.notion.so/TransactionMonitor-83d454917891486eaa3cfefc9615be10` | Not retrieved |
| 3 | LUX Cashout / Lux SDK Doc | `https://www.notion.so/LUX-Cashout-4f3f5abb5e504f009b97788461f761fc` | Not retrieved |
| 4 | POS | `https://www.notion.so/POS-ecf196fdd0854c409081b6e5d07f296d` | Not retrieved |
| 5 | Java Implementation | `https://www.notion.so/Java-Implementation-56968116c3e640769581b8473f37dcc2` | Not retrieved |
| 6 | Triple DES Encryption | `https://www.notion.so/Java-TripleDes-Encryption-a803c4008e0b48ce887987c52353d9aa` | Not retrieved |
| 7 | Terminal Type Topwise T1 | `https://www.notion.so/Big-Topwise-SDK-Usage-T1-a11f64db4e6440b8b988117cccbd1d47` | Not retrieved |

**Consequences for the local reference:**

- The custom-POS SDK path, key exchange, encryption implementation, terminal certification, and
  device-management behaviour cannot be confirmed from official content.
- The local document deliberately does **not** invent those details. It records the links and marks
  them for manual review.
- This is the principal reason the overall audit cannot be declared COMPLETE.

**Recommended action:** obtain the seven documents through an authenticated Lux/Notion account or
directly from PSL, then perform a separate review of the POS integration path.

---

## 5. Missing documentation

**Status: PARTIALLY COMPLETE**

### 5.1 Local gap found and closed

The wallet operation inventory listed `POST /client/update` but the document had no section for it.
The five documented tier-upgrade variants were therefore absent from the local reference. This was
the only substantive local content omission found.

It has been added as **§4.6 Tier upgrade (`/client/update`)** in `VFD_WALLET.md`, covering:

- tier 1 → tier 2 for an account created with NIN and date of birth (BVN supplied);
- tier 1 → tier 3 for an account created with NIN and date of birth (BVN plus address);
- tier 1 → tier 2 for an account created with BVN and date of birth (NIN supplied);
- tier 1 → tier 3 for an account created with BVN and date of birth (NIN plus address);
- tier 2 → tier 3 (address only);
- common fields and their conditional requirements;
- the success envelope and `currentTier`/verification fields;
- failures `199 No previous account found` and `199 Unable to upgrade account`;
- the distinction from the separate `/client/upgrade` remediation endpoint.

### 5.2 Vendor documentation that remains missing

These gaps exist in the official documentation, not only in the local copy. They are recorded, not
filled in.

| Category | Missing from vendor documentation |
| --- | --- |
| Contract | OpenAPI/Swagger/JSON Schema |
| Environments | Sandbox reset policy; behavioural differences between test and live |
| Limits | Rate limits, payload limits, pagination maxima, transfer/balance limits |
| Reliability | Timeouts, retry policy, idempotency window, duplicate handling |
| Webhooks | Signature algorithm, secret rotation, retries, event IDs, ordering, replay window, source IPs |
| Errors | Complete per-product catalogues and HTTP-status mapping |
| Money | Fee rules, settlement timing, rounding, currency handling, reversal timing |
| Identity | AML outcome retrieval, image-match threshold, liveness quality threshold, retention |
| Cards | PCI guidance, tokenization, 3-D Secure detail, card funding and limits |
| POS | Key exchange, terminal certification, settlement, chargebacks, SDK details (external) |
| Payment Link | Status/verification endpoint, notification contract, link reuse and cancellation |
| Loans | Onboarding endpoint, eligibility, pricing, repayment mechanics |
| Operations | Support escalation, incident contacts, status page, change notification |

### 5.3 Coverage of local documents

All 15 topic documents correspond to at least one official page or to a cross-cutting consolidation.
`VFD_WEBHOOKS.md` and `VFD_INTEGRATION_NOTES.md` are deliberate cross-page syntheses rather than
one-to-one mirrors. No official content page lacks a local reference.

---

## 6. Technical discrepancies

**Status: PARTIALLY COMPLETE** — local errors were fully identified and corrected, but the
vendor-side ambiguities remain unresolved by design.

### 6.1 Local documentation errors found and corrected

| # | File and location | Severity | Problem | Correction |
| --- | --- | --- | --- | --- |
| 1 | `VFD_WALLET.md` §4 | **High** | `/client/update` appeared in the operation inventory but had no body section; five documented upgrade variants were missing | Added §4.6 with all five variants, fields, success and failure responses |
| 2 | `VFD_WALLET.md` §9.8 | Medium | Transfer-webhook cross-reference pointed to `VFD_WEBHOOKS.md` §4 (Initial Inward Credit) instead of §5 (transfer webhook) | Changed §4 → §5 |
| 3 | `VFD_WALLET.md` §8.3 | Low | Bank-code note pointed to `VFD_DEBIT_MANDATES.md` §7 (account balance) instead of §11 (bank codes) | Changed §7 → §11 |
| 4 | `VFD_PAYMENT_LINK.md` §2 | Low | Webhook-gap sentence said "See §6" (response codes); the relevant material is in §5 and §7 | Changed to "See §5 and §7" |
| 5 | `VFD_OVERVIEW.md` §7 | Medium | Five test-data references pointed to the wrong sections | BVN §13 → §16.1; RC §5.4 → §5.3; transfer accounts §8.9 → §9.7; simulated credit §8.12 → §10; card test data §5 → §6 |
| 6 | `VFD_WEBHOOKS.md` §4 | Low | Said "All other fields are identical to §3" while the reproduced initial-credit sample omits `transaction_channel` | Qualified the statement to note the omission in the vendor sample |

All six corrections are supported directly by the official text. No new endpoint, field, status code,
or behaviour was introduced.

### 6.2 Vendor ambiguities preserved (not "corrected")

| Area | Ambiguity |
| --- | --- |
| Authentication | `validityTime: "-1"` is described as non-expiring; no maximum lifetime is stated |
| Payment Link | Test path `vtech-payment` and live path `vtech-payment-link` are not host-only variants |
| Liveness | Grouped under KYC but uses the wallet base URL |
| KYC field casing | AML uses `firstname`; Driver License and NIN use `firstName` |
| KYC date formats | `DD-Mon-YYYY`, `YYYY-MM-DD`, and `DD-MM-YYYY` all appear |
| AML envelope | `responseCode`, `hasError`, and `message` are null while `data.status` is `"200"` |
| NIN echo | Request `11111222221`; response `idNumber: 45629461922` |
| NIN match flags | `firstNameMatch`/`lastNameMatch`/`dobMatch` are false with no comparison inputs in the request |
| Image match | Returns `status: "00"` / `"Successful"` even when `isMatch: false` |
| Liveness types | `probability`, `score`, and `quality` are strings, not numbers |
| Mandate field names | `payerAccountNummber`, `payerAccountname`, and `receiverBvn` are irregular |
| Mandate status | Balance/status responses use `status: "200"` instead of `"00"` |
| Card base paths | Accepting uses `baas-cards`; issuing uses `baascards` |
| Card history | `POST` with query parameters and no body |
| Card-payment status | No HTTP method is stated for `/payment-details` |
| POS `settledAmount` | Sample shows `990` against `amount` `800` |
| POS `hash` | Webhook hash algorithm is undefined |
| KYC upload types | Request uses camelCase; response uses `UPPER_SNAKE_CASE` |
| KYC upload identifiers | Flow promises resource identifiers; the sample response shows none |
| Loans | The page refers to an onboarding step that it does not document |
| Transfer signature | The signing secret is described only as "Contact admin" |
| Payment Link notification | Asserted in the flow, but no event name or payload is published |
| Simulated credit | Sample sender account/bank differs from the vendor's recommended note |

### 6.3 Suspected issues checked and found correct

| Item | Result |
| --- | --- |
| POS external links | Raw `href` values use `www.notion.so`; rendered text shows `trylux.notion.site`. The local URLs match the raw links. No change needed. |
| `baas-cards` vs `baascards` | Genuinely different products and base paths; already documented correctly. |
| Payment Link test/live paths | Genuinely different path segments; already documented correctly. |
| `/client/update` vs `/client/upgrade` | Separate endpoints with different purposes; now distinguished explicitly. |
| Test-data section references | Local references were stale, not the data itself. Data matched the vendor tables. |
| Liveness base URL | Officially uses the wallet base; local document already records this. |
| BaaS portal URL | `https://vbaas.vfdtech.ng/` matches the official link. |

---

## 7. Corrections made

**Status: COMPLETE**

| File | Section | Change |
| --- | --- | --- |
| `VFD_WALLET.md` | New §4.6 | Added the missing `/client/update` tier-upgrade documentation |
| `VFD_WALLET.md` | §9.8 | Corrected transfer-webhook cross-reference to `VFD_WEBHOOKS.md` §5 |
| `VFD_WALLET.md` | §8.3 | Corrected bank-code cross-reference to `VFD_DEBIT_MANDATES.md` §11 |
| `VFD_PAYMENT_LINK.md` | §2 | Corrected "See §6" to "See §5 and §7" |
| `VFD_OVERVIEW.md` | §7 | Corrected five test-data section references |
| `VFD_WEBHOOKS.md` | §4 | Qualified the "identical to §3" statement for the omitted `transaction_channel` |

**Verification of corrections:**

- All 43 cross-document section references resolve to an existing numbered heading.
- All 19 in-page anchor links resolve to an existing heading.
- All internal `.md` links resolve to existing files.
- No application file, schema, migration, dependency, or configuration file was touched.
- No vendor ambiguity was silently "fixed"; each remains flagged in the relevant document.

---

## 8. Outstanding questions

**Status: INCOMPLETE** — these require answers from PSL/VFD or access to the external documents.

### 8.1 Access, environments, and operations

- Which products are contractually available to Hivorr?
- What are the test and live credentials, and through which approved channel are they issued?
- Is there a sandbox reset schedule or data-retention policy?
- Are there rate limits, payload limits, pagination maxima, or per-tier transfer limits?
- Who supports each product (PSL vs VFD), and what are the escalation paths?
- Is there a status page and a change/deprecation notification process?

### 8.2 Authentication and webhooks

- What is the maximum supported token lifetime?
- Can tokens be scoped to specific products or operations?
- Is there a short-lived, origin-restricted token for the Payment Widget?
- Is there a webhook signature scheme (HMAC/RSA)? What algorithm and test vectors apply?
- What are the webhook source IP ranges, retry schedule, timeout, and maximum attempts?
- Is delivery at-least-once? Are event or delivery IDs provided?
- How should duplicate and out-of-order events be handled?
- What is the Payment Link notification payload and verification method?
- What does the POS `hash` field contain, and how is it verified?
- What are the debit-authorization decision semantics and timeout?
- Can card-payment failures be notified?

### 8.3 Money movement, identity, and cards

- What are the complete fee, settlement, and reversal rules?
- Is there an idempotency key for transfers, card creation, or mandate debits?
- Which is the reconciliation source of truth: webhook or status query?
- How are partial failures and reversals represented?
- How is the AML screening result retrieved after submission?
- What image-match similarity threshold is used, and is it configurable?
- What liveness quality threshold should be applied?
- Is image match liveness-bound?
- Is there a PCI-compliant card-issuing mode that does not return full PAN/CVV?
- How is the default card PIN delivered to the cardholder?
- What are the KYC document size/format limits and the retention/deletion policy?

### 8.4 POS external documentation

- What SDK methods, terminal types, and device-management operations are documented externally?
- What key-exchange and key-rotation mechanism is required?
- Which encryption algorithm is current — is Triple DES still used?
- What terminal certification is required?
- What are the settlement, chargeback, and dispute processes?

---

## 9. Security considerations

**Status: PARTIALLY COMPLETE** — risks were identified, but the vendor documentation does not supply
enough detail to close them.

| # | Consideration | Finding |
| --- | --- | --- |
| 1 | Webhook authenticity | No signature, shared secret, timestamp, event ID, or replay protection is documented for any webhook |
| 2 | POS webhook `hash` | Field exists but the algorithm is undefined; source verification is impossible from the documentation alone |
| 3 | Card data in responses | Virtual-card creation returns full `pan`, `cvv`, and expiry in plain JSON |
| 4 | Card payment | The documented flow is non-tokenized; the payer supplies full card details for each payment, with no PCI guidance |
| 5 | Browser token exposure | The Payment Widget requires a wallet access token in client-side JavaScript; scoping and expiry are not specified |
| 6 | Transfer signing | The request-signature secret is described only as "Contact admin"; no rotation or storage guidance |
| 7 | KYC PII | Identity documents and images are uploaded as base64 JSON; retention, deletion, and access controls are undocumented |
| 8 | Token lifetime | `-1` creates a non-expiring token; no maximum lifetime or revocation process is stated |
| 9 | Authorization callback | The debit-authorization webhook sits in the payment path; timeout and failure behaviour are undocumented |
| 10 | Transport | Base URLs are HTTPS, but TLS version, certificate pinning, and IP allow-listing are not specified |
| 11 | Environment separation | Several products require a webhook to be shared between test and production; no environment-scoped secret is documented |
| 12 | PII in examples | Vendor samples contain test BVNs, NINs, names, and account numbers. These must never be treated as production data |

**Security conclusion:** the documentation is sufficient to identify risk areas, but not sufficient to
design a production integration without vendor clarification, a PCI review, and an independent
webhook-authenticity design.

---

## 10. Overall assessment

**Status: PARTIALLY COMPLETE**

### 10.1 Result summary

| Measure | Result |
| --- | --- |
| Official sitemap URLs discovered | 18 (1 category + 17 content pages) |
| Official content pages retrieved | 17 of 17 |
| Official content pages verified | 17 of 17 (POS body verified; external dependencies not) |
| External Lux/Notion documents discovered | 7 |
| External documents retrieved and verified | 0 of 7 |
| Local content omissions found | 1 (`/client/update`) |
| Local content omissions corrected | 1 |
| Local cross-reference errors corrected | 8 |
| Local statements qualified for accuracy | 1 |
| Broken internal file links after correction | 0 |
| Broken internal section references after correction | 0 |
| Broken in-page anchors after correction | 0 |
| Application code or functionality changed | **None** |

### 10.2 Assessment

The local collection accurately represents **all retrievable official VFD/PSL documentation**. Every
one of the 17 official content pages was retrieved and compared. Endpoint paths, methods, parameters,
sample payloads, response and error examples, webhook payloads, test/live distinctions, and security
warnings were checked. The only substantive content omission was the `/client/update` tier-upgrade
operation, which has been added. Eight cross-reference errors and one over-broad statement were also
corrected.

The review **cannot** be declared **COMPLETE** for two reasons:

1. Seven externally hosted Lux/Notion documents linked from the POS Infrastructure page were not
   retrievable. The POS body is verified, but the custom-POS SDK, encryption, terminal, and
   device-management detail remains unverified.
2. The vendor documentation itself leaves material gaps — webhook security, limits, settlement,
   idempotency, PCI guidance, Payment Link verification, and several response-contract ambiguities.
   These are preserved and flagged rather than invented.

The local reference is therefore **trustworthy as a record of the published API surface**, and
**not yet sufficient as the sole basis for a production integration**.

### 10.3 Explicit confirmation of no application change

This audit changed **documentation only**.

- No application code was added, removed, or modified.
- No wallet, payment, transfer, card, mandate, loan, or KYC functionality was changed.
- No authentication or authorization behaviour was changed.
- No database schema, migration, grant, RLS policy, or Supabase configuration was changed.
- No dependency was added, removed, or upgraded.
- No runtime behaviour or user-facing functionality was introduced.
- No credential, secret, token, or customer data was written to the repository.

The only changes are Markdown files under `documents/integrations/vfd/`.

### 10.4 Recommended next step

Obtain the seven external Lux/Notion documents through an authenticated account or directly from PSL,
then perform a focused POS follow-up audit. Until that is done, the POS external integration path
should be treated as undocumented.
