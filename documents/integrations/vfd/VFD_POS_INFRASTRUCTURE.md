# VFD POS Infrastructure (LUX)

> **Source:** [POS INFRASTRUCTURE](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/vfd-pos)
> **Retrieved:** 6 November 2026. **Documentation only.**
>
> This page describes a card-acquiring and terminal business operated under the LUX brand, not a
> conventional JSON API. Most of the integration detail is hosted outside the official documentation
> site and was **not retrievable** by the extraction tool. See §7.

---

## 1. What the page documents

**Confirmed:** PSL offers a POS infrastructure that processes card transactions through its card
infrastructure. It includes:

- a smart routing system intended to keep merchants able to collect payments;
- a bundled POS and inventory-management system;
- two integration approaches:
  1. use the default POS application for card transactions;
  2. build a custom POS application on top of the infrastructure.

**Observation:** this is a separate product line from the wallet, card-payment, and debit-card APIs. It
has no dedicated REST base URL on the official documentation site.

---

## 2. Onboarding

**Confirmed steps:**

1. Create a LUX profile at `https://trylux.africa/auth/register`.
2. Contact the PSL Integration Support team to set up the wallet profile for settlement. The merchant
   must provide:
   - a webhook URL;
   - a settlement account for POS transactions;
   - the type of settlement to configure.
3. Log in at `https://trylux.africa` and upload terminal data. The page links to a Notion guide,
   "POS Device management".
4. Perform a key exchange before using the device.

**Not documented:**

- terminal models supported beyond the Topwise T1 reference;
- key-exchange protocol, key hierarchy, or key rotation;
- settlement schedules and cut-off times;
- pricing, fees, chargebacks, or reserve requirements;
- sandbox/test terminals or test cards for POS;
- certification requirements for a custom POS application.

> **Observation:** the onboarding is human-assisted ("reach out to the PSL Integration Support team"),
> not self-service. This differs from the wallet APIs, which are documented as direct API calls.

---

## 3. Webhook integration

**Confirmed:** the webhook is configured manually against the wallet profile. It must be an HTTP
`POST` that accepts this body:

```json
{
  "amount": "800",
  "settledAmount": "990",
  "serialNumber": "XXXXXXXXXXXXXXXX",
  "cardType": "MasterCard",
  "terminalId": "2033XXXX",
  "rrn": "XXXXXXXXXXXXX",
  "reference": "XXXXXX-XXXXXXXXXXXXXXXX-XXXXXXXX-XXXXXXXXXX",
  "transactionType": "card",
  "statusDescription": "Approved",
  "merchantId": "XXXXXX",
  "stan": "000172",
  "statusCode": "00",
  "transactionDate": "2022-05-11T20:15:58.034+0100",
  "hash": "********************",
  "pan": "XXXXXX*********XXXX",
  "cardExpiry": "****"
}
```

| Field | Apparent meaning |
| --- | --- |
| `amount` | Transaction amount. |
| `settledAmount` | Amount after settlement/fees. The sample value is larger than `amount`, which is unexplained. |
| `serialNumber` | Terminal serial number. |
| `cardType` | Card network, e.g. `MasterCard`. |
| `terminalId` | Terminal identifier. |
| `rrn` | Retrieval reference number. |
| `reference` | LUX transaction reference. |
| `transactionType` | Sample value `card`. |
| `statusDescription` | Human-readable status, e.g. `Approved`. |
| `merchantId` | Merchant identifier. |
| `stan` | System trace audit number. |
| `statusCode` | Status code, e.g. `00`. |
| `transactionDate` | Timestamp with offset (`+0100`). |
| `hash` | Unexplained integrity field. |
| `pan` | Masked PAN. |
| `cardExpiry` | Masked expiry. |

> **Observation:** the page does not define the field semantics. The "apparent meaning" column is
> inferred from field names and standard card-processing terminology, not stated by the vendor.
>
> **Observation:** `settledAmount: "990"` against `amount: "800"` is counter-intuitive. It may be a
> documentation error or may include a different amount basis. Do not rely on either field until the
> vendor explains the calculation.
>
> **Open question — `hash`:** no algorithm, key, canonicalization, or validation procedure is given.
> An integrity field that cannot be verified is not a security control. Treat the payload as
> unauthenticated until the vendor documents verification.

**Confirmed:** the POS page itself does **not** restate the "respond with HTTP 200" requirement, an IP
allow-list, or a retry policy. The wallet and card pages advise authentication or IP whitelisting for
their webhooks (see [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md)); do not assume those apply automatically here.

---

## 4. Shared wallet endpoints for LUX

The Wallets page documents two endpoints for LUX POS partners (not on the POS page itself):

### 4.1 Webhook repush

**Path:** `/transactions/repush`
**Method:** `POST`
**Headers:** `AccessToken: {{token}}`

```json
{
  "reference": "408210-P051200150941-2057JVSC-012804578357",
  "transactionType": "card-payment",
  "pushIdentifier": "reference"
}
```

| Field | Description | Required | Note |
| --- | --- | --- | --- |
| `reference` | Unique LUX-generated transaction reference. | Mandatory | Must match the original transaction. |
| `transactionType` | Type of transaction. | Mandatory | Static value `card-payment`. |
| `pushIdentifier` | Identifier for the repush. | Mandatory | Static value `reference`. |

Successful response:

```json
{
  "status": "00",
  "message": "success",
  "data": [
    {
      "transactionId": "LUX-20250730123709648-012804578357",
      "transactionStatus": "00"
    }
  ]
}
```

**Confirmed:** `transactionStatus: "01"` is returned when the webhook is not reachable;
`status: "99"` with `"Invalid transaction"` for an invalid transaction; `status: "99"` with
`"transactionId is mandatory"` when the push identifier is missing.

**Observation:** a repush is a manual retry mechanism. The page does not document automatic retries,
backoff, or a maximum attempt count.

### 4.2 Transaction status query (TSQ)

**Path:** `/transactions?transactionType={type}&reference={reference}`
**Method:** `GET`
**Headers:** `AccessToken: {{token}}`

| Query parameter | Description | Required | Example |
| --- | --- | --- | --- |
| `transactionType` | Type of transaction. | Mandatory | `card-payment` |
| `reference` | Unique LUX-generated reference. | Mandatory | `450035-P051200150941-2057JVSC-751706450035` |

Successful response includes `reference`, `rrn`, `transactionId`, `statusCode`, `amount`,
`transactionType`, `transactionTime`, `terminalId`, `settledAmount`, `statusDescription`.

**Confirmed other responses:**

- unsettled or failed transaction: HTTP-level success with `data.statusCode: "25"` and
  `statusDescription: "Unable To Locate Record"`;
- no transaction found: `status: "108"`, `message: "No Transaction!"`.

**Observation:** the endpoint returns business outcomes inside a successful response envelope. Callers
must inspect `status`, `data.statusCode`, and `statusDescription`, not only the HTTP status.

**Base URL:** the wallet page places these endpoints under the wallet base URL
(`.../vtech-wallet/api/v2/wallet2`). See [VFD_WALLET.md](VFD_WALLET.md).

---

## 5. Portals

**Confirmed:**

| Purpose | System |
| --- | --- |
| View POS transactions | LUX portal (`https://trylux.africa`) |
| Settlement and dispute escalation | BaaS portal (`https://vbaas.vfdtech.ng/`) |

---

## 6. Operational model

**Observation:** the product combines hardware/terminal management, acquiring, settlement, and
inventory management. It is not a pure API product. A Hivorr integration would depend on commercial
terms, terminal logistics, settlement-account arrangements, and support processes that are outside the
documentation.

---

## 7. External documents referenced by the page

These links are **outside** the official documentation site and were **not retrievable** by the
extraction tool. They are recorded for manual review, not mirrored or summarised.

| Title | URL | Access result |
| --- | --- | --- |
| POS Device management | `https://www.notion.so/POS-Device-Management-19318e9298674c2c8f7e9b92200d1554` | Not retrieved (transport/client-render failure) |
| Transaction Monitor | `https://www.notion.so/TransactionMonitor-83d454917891486eaa3cfefc9615be10` | Not retrieved |
| Lux SDK Doc / LUX Cashout | `https://www.notion.so/LUX-Cashout-4f3f5abb5e504f009b97788461f761fc` | Not retrieved |
| POS | `https://www.notion.so/POS-ecf196fdd0854c409081b6e5d07f296d` | Not retrieved |
| Java Implementation | `https://www.notion.so/Java-Implementation-56968116c3e640769581b8473f37dcc2` | Not retrieved |
| Triple DES encryption | `https://www.notion.so/Java-TripleDes-Encryption-a803c4008e0b48ce887987c52353d9aa` | Not retrieved |
| Terminal Type Topwise T1 | `https://www.notion.so/Big-Topwise-SDK-Usage-T1-a11f64db4e6440b8b988117cccbd1d47` | Not retrieved |

The page links the Cashout document twice (as "Lux SDK Doc" and "Cashout"), so there are seven unique
external documents across eight links.

**Manual review required:** the external set is likely to contain the SDK, encryption, terminal, and
key-exchange details that the official page omits. Until reviewed:

- do not infer SDK methods, key formats, or encryption schemes;
- do not assume Triple DES is the only or current algorithm;
- treat the custom-POS path as undocumented.

---

## 8. Security notes

- **Webhook authentication is undefined.** `hash` has no documented algorithm; IP allow-listing and
  authentication are not stated on this page. Verify the source before trusting a POS notification.
- **Card data:** the sample masks `pan` (`XXXXXX*********XXXX`) and `cardExpiry` (`****`), but the
  page does not state that PAN is always masked. Treat POS payloads as cardholder data until confirmed.
- **Key exchange:** required before device use, but the mechanism is undocumented on the official site.
- **Settlement account:** supplied manually to PSL support; the page gives no verification or
  change-control process.
- **Manual configuration:** the webhook is configured manually against the wallet profile, so
  environment separation and change audit are process controls, not API controls.

---

## 9. Missing and ambiguous specifications

| Item | Status |
| --- | --- |
| Dedicated POS REST API | **Not documented** (two shared wallet endpoints only) |
| Webhook signature algorithm | **Not documented** (`hash` unexplained) |
| Webhook retry policy | **Not documented** (manual repush exists) |
| Settlement schedule | **Not documented** |
| Key exchange / key rotation | **Not documented** on the official site |
| Terminal certification | **Not documented** |
| Test environment for POS | **Not documented** |
| `settledAmount` calculation | **Not documented** |
| Custom POS SDK details | **External only, not retrieved** |
| Chargebacks / disputes API | **Not documented** |

---

## 10. Related documents

- [VFD_WALLET.md](VFD_WALLET.md) — wallet base URL, TSQ, and repush endpoints.
- [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) — POS payload alongside the other webhooks.
- [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md) — relevance and manual verification.
