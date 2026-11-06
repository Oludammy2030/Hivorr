# VFD Webhooks and Notifications

> **Sources:** Wallets, Card Payment, Debit Cards, POS Infrastructure, Payment Link, and Payment Widget
> pages. Individual URLs are listed per section. **Retrieved:** 6 November 2026.
> **Documentation only.**
>
> This is a consolidated catalogue of every webhook, callback, and notification found in the official
> VFD/PSL documentation. It does not add fields or events that the vendor did not publish.

---

## 1. Summary

| # | Event / name | Product | Direction | Merchant must respond | Documented payload |
| --- | --- | --- | --- | --- | --- |
| 1 | Inward Credit Notification | Wallets / Widget (transfer, USSD, QR) | VFD → merchant | HTTP 200 | Yes |
| 2 | Initial Inward Credit Notification | Wallets | VFD → merchant | HTTP 200 | Yes |
| 3 | Transfer webhook (`payout.success` / `payout.failed`) | Wallets | VFD → merchant | HTTP 200 | Yes |
| 4 | Card payment notification | Card Payment / Widget (card) | VFD → merchant | HTTP 200 | Yes |
| 5 | Debit transaction notification | Debit Cards | VFD → merchant | HTTP 200 | Yes |
| 6 | Debit authorization webhook | Debit Cards (POOL) | VFD → merchant, synchronous decision callback | Yes, with balance | Yes |
| 7 | Balance check webhook | Debit Cards (POOL) | VFD → merchant, synchronous query | Yes, with balance | Yes |
| 8 | POS transaction webhook | POS / LUX | VFD → merchant | Not stated on POS page | Yes |
| 9 | Payment Link notification | Payment Link | VFD → merchant (asserted) | **Not documented** | **No** |
| 10 | Widget success callback (`onSuccess`) | Payment Widget | Browser callback | Not applicable | `{ method, reference }` |

**Observation:** items 1–8 are server-to-server webhooks. Item 10 is a browser callback, not a
webhook. Item 9 is mentioned in prose but has no contract.

---

## 2. Configuration model

The documentation describes three different configuration mechanisms:

| Product | How the webhook is configured |
| --- | --- |
| Wallets | "A webhook is to be shared both in the testing and production environments" — no portal or API described. |
| Card Payment | "A webhook must be configured by you on the baas portal"; shared in testing and production. |
| Debit Cards | Not explicitly stated; implies configuration with PSL. |
| POS | "Manually configured against your wallet profile" by PSL Integration Support. |
| Payment Link | Not documented. |

**Observation:** there is no documented self-service webhook-registration endpoint, no signing-secret
management, and no event-subscription API. Webhook setup is a manual/contractual step.

**Not documented:** whether multiple URLs per environment are supported, whether events can be
subscribed individually, or how to rotate a webhook URL safely.

---

## 3. Inward Credit Notification

**Source:** [Wallets — Inward Credit Notification](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/wallets-api#inward-credit-notification)

**Confirmed:** sent when funds are transferred to a wallet account **and the funds settled** in the
account. HTTP method `POST`.

```json
{
  "reference": "uniquevalue-(Randomly generated value)",
  "amount": "1000",
  "account_number": "1010123498",
  "originator_account_number": "2910292882",
  "originator_account_name": "AZUBUIKE MUSA DELE",
  "originator_bank": "000004",
  "originator_narration": "test",
  "timestamp": "2021-01-11T09:34:55.879Z",
  "transaction_channel": "EFT",
  "session_id": "00001111222233334455"
}
```

| Field | Description |
| --- | --- |
| `reference` | Prefixed by the wallet name followed by a random string. |
| `amount` | Amount sent to the wallet account. |
| `account_number` | Account number credited with the inward transfer. |
| `originator_account_number` | Initiator's account number. |
| `originator_account_name` | Initiator's name. |
| `originator_bank` | Initiator's bank code. |
| `originator_narration` | Narration supplied by the originator. |
| `timestamp` | The table says "This is the initiator's name" — a copy/paste error in the vendor documentation. The example is an ISO 8601 timestamp. |
| `transaction_channel` | `EFT` (Electronic Funds Transfer), `USSD`, or `NQR`. |
| `session_id` | Session identifier. |

**Observation:** the `timestamp` description is wrong in the source. The example value is treated as a
timestamp here, but the vendor should confirm.

**Observation:** the payload has **no event name**, no event ID, no delivery ID, and no signature.
Deduplication must rely on `reference`/`session_id`.

---

## 4. Initial Inward Credit Notification

**Source:** [Wallets — Initial Inward Credit Notification](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/wallets-api#initial-inward-credit-notification)

**Confirmed:** sent when funds are transferred to a wallet account **even though the funds might not
have settled**. It must be explicitly activated by request, and a webhook must be shared for both
testing and production. HTTP method `POST`.

```json
{
  "reference": "uniquevalue-(Randomly generated value)",
  "amount": "1000",
  "account_number": "1010123498",
  "originator_account_number": "2910292882",
  "originator_account_name": "AZUBUIKE MUSA DELE",
  "originator_bank": "000004",
  "originator_narration": "test",
  "timestamp": "2021-01-11T09:34:55.879Z",
  "session_id": "00001111222233334455",
  "initialCreditRequest": true
}
```

| Field | Description |
| --- | --- |
| `initialCreditRequest` | `true` when the notification is an initial inward credit notification. |

All other fields are identical to §3, but the vendor's sample payload above omits
`transaction_channel`, which is present in the settled-credit sample.

**Observation:** the payloads for the settled and unsettled notifications differ only by
`initialCreditRequest`. A receiver that does not check the flag can easily treat an unsettled credit as
final. If both webhooks are enabled, the same transaction may produce two notifications.

**Not documented:** ordering guarantees between initial and settled notifications, the delay between
them, or how to reconcile them.

---

## 5. Transfer webhook (`payout.success` / `payout.failed`)

**Source:** [Wallets — Transfer Webhook Notification](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/wallets-api#7-transfer-webhook-notification)

**Confirmed:** sent when an outbound transfer has been processed. HTTP method `POST`.

**Event names:** `payout.success` or `payout.failed`.

### 5.1 Success

```json
{
  "status": "00",
  "message": "success",
  "event": "payout.success",
  "data": {
    "reference": "TestWallet-AWW3WDIUWU4U",
    "amount": "1000",
    "account_number": "1001561539",
    "originator_account_number": "1001561522",
    "originator_account_name": "RolandPay-Roland Bright Doe",
    "originator_bank": "999999",
    "timestamp": "2026-08-14T10:00:00.000Z",
    "session_id": "090110220420225737701409365803",
    "transfer_type": "intra",
    "charge": "20",
    "batchId": "BATCH-001"
  }
}
```

| Field | Description |
| --- | --- |
| `status` | Transfer status returned by the payout engine. |
| `message` | Status message. |
| `event` | Webhook event name. |
| `data.reference` | Unique transfer reference. |
| `data.amount` | Transfer amount. |
| `data.account_number` | Beneficiary account number. |
| `data.originator_account_number` | Sender account number. |
| `data.originator_account_name` | Sender account name. |
| `data.originator_bank` | Sender bank code. |
| `data.timestamp` | Notification timestamp. |
| `data.session_id` | Transaction session ID. |
| `data.transfer_type` | Transfer type, such as `intra` or `inter`. |
| `data.charge` | Applied transfer charge. |
| `data.batchId` | Batch identifier for a bulk transfer, when applicable. |

### 5.2 Failure

```json
{
  "status": "99",
  "message": "failed",
  "event": "payout.failed",
  "data": {
    "reference": "TestWallet-AWW3WDIUWU4U",
    "batchId": "BATCH-001"
  }
}
```

**Observation:** the failure payload omits amount, beneficiary, timestamp, and reason. It identifies the
transfer only by `reference` and `batchId`, and gives no failure reason. Reconciliation must fall back
to the transfer status endpoint. See [VFD_WALLET.md](VFD_WALLET.md).

**Observation:** `originator_*` names in a payout notification refer to the **sender**; the beneficiary
is `account_number`. This is the reverse of the inward-credit payload, where `account_number` is the
creditor and `originator_*` is the payer.

---

## 6. Card payment notification

**Source:** [Card Payment — Notifications](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/card-api#30-notifications)

**Confirmed:** the webhook is configured on the BaaS portal and shared in both testing and production.
HTTP method `POST`.

```json
{
  "status": "00",
  "message": "Success",
  "data": {
    "reference": "rosapay-01919",
    "paymentReference": "202405020958548EOVV",
    "amountCollected": "990",
    "amountCredited": "985"
  }
}
```

| Field | Description |
| --- | --- |
| `reference` | The unique reference passed when making the card payment. |
| `paymentReference` | VFD-generated identifier for the card transaction. |
| `amountCollected` | Amount collected by VFD. |
| `amountCredited` | Amount credited to the merchant's collections account. |

**Observation:** there is no event name, card metadata, payer identity, currency, timestamp, or failure
notification. The payload is success-only in the sample. `amountCollected` vs `amountCredited` exposes
the fee but the fee rule is not documented.

**Observation:** no signature, so any party that learns the URL could post a fake "success" payload.
Treat the webhook as a trigger and verify with the payment-status endpoint
(`/payment-details?reference=...`) before crediting an account.

---

## 7. Debit card webhooks

**Source:** [Debit Cards — Webhook setup](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/debit-card#60-debit-card-webhook-setup)

All three require an HTTP `POST` endpoint that returns HTTP 200.

### 7.1 Debit transaction notification

Sent when funds are debited from the account.

```json
{
  "availableBalance": "15004.00",
  "ledgerBalance": "15004.00",
  "accountNumber": "1001626656",
  "retrievalReferenceNumber": "847571200976",
  "cardAcceptorTerminalId": "3IPG0001",
  "transactionStatus": "withdrawal_performed",
  "amount": "210.0",
  "charge": "10.0"
}
```

| Field | Description |
| --- | --- |
| `availableBalance` | For pool transactions, the account balance returned by the merchant; for 1-1 transactions, the sub-account balance. |
| `ledgerBalance` | Same distinction as `availableBalance`. |
| `accountNumber` | Account number on the card used. |
| `retrievalReferenceNumber` | Transaction reference. |
| `cardAcceptorTerminalId` | Channel ID through which the transaction was carried out. |
| `transactionStatus` | Status, e.g. `withdrawal_performed`. |
| `amount` | Initiator's amount. |
| `charge` | Transaction fee. |

### 7.2 Debit authorization webhook

**Confirmed:** "required to validate the debit request initiated on the merchant's sub-account. It is
specifically needed for merchants on POOL implementation." HTTP method `POST`.

Request (two shapes are shown):

```json
{
  "accountNo": "1001626656",
  "amount": "200"
}
```

```json
{
  "accountNo": "1001626656"
}
```

| Field | Description |
| --- | --- |
| `accountNo` | Account number of the card that initiated the request. |
| `amount` | Requested debit amount. |

Expected response:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "accountBalance": "125000.50"
  }
}
```

**Observation:** this is a **synchronous decision callback**, not a notification. The merchant must
answer while the authorization is in progress, presumably with a short timeout. The page does not give
the timeout, retry behaviour, or what happens if the merchant does not respond.

**Observation:** the response communicates a balance, not an explicit approve/decline. The decision
semantics are **not documented**. It is unclear whether returning a low balance declines the debit, or
whether `status: "00"` always approves.

### 7.3 Balance check webhook

**Confirmed:** used to retrieve the current balance of a merchant sub-account. Specifically needed for
POOL implementation. HTTP method `POST`.

Request:

```json
{
  "accountNo": "1001626656"
}
```

Expected response:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "accountBalance": "125000.50"
  }
}
```

**Observation:** the balance-check and debit-authorization webhooks have the same request shape (in one
variant), the same response shape, and both target POOL merchants. The documentation does not state
how the receiver distinguishes them — by URL, by a header, or by configuration.

---

## 8. POS transaction webhook

**Source:** [POS Infrastructure — Webhook Integration](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/vfd-pos#webhook-integration)

**Confirmed:** manually configured against the wallet profile. HTTP method `POST`.

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

Field meanings are inferred in [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) §3. The
official page does not define them.

**Observation:** `hash` is an unexplained integrity field. No algorithm or key is documented.

**Observation:** `settledAmount` (990) is larger than `amount` (800). Unexplained.

**Observation:** the POS page does **not** state the HTTP 200 requirement, unlike the wallet and
debit-card pages.

---

## 9. Payment Link notification

**Source:** [Payment Link](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/payment-link-api)

**Confirmed only as prose:** the documented flow says the merchant "receives a notification when
payment is completed".

**Not documented:**

- event name;
- payload;
- HTTP method;
- signature;
- configuration mechanism;
- retry behaviour;
- whether the notification is server-to-server or browser-based.

Do not implement against an assumed payload. See [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) §5.

---

## 10. Payment Widget callback

**Source:** [Payment Widget](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/payment-widget)

The widget's `onSuccess` callback receives:

```js
{ method, reference }
```

**Confirmed:** `method` is the payment method; `reference` is the VFD-generated transaction reference.

**Confirmed routing:** transfer/USSD/QR payments produce the Inward Credit Notification (§3); debit-card
payments produce the Card Payment notification (§6).

**Observation:** `onSuccess` is a browser callback and can be spoofed or suppressed by the client. It
must not be treated as proof of payment. Use the webhook plus a server-side status check.

---

## 11. Retry and repush

| Product | Mechanism | Source |
| --- | --- | --- |
| Wallets | `POST /transactions/repush` with `reference`, `transactionType`, `pushIdentifier` | [Wallets](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/wallets-api#retrigger-webhook-notification) |
| POS / LUX | `POST /transactions/repush` with `reference`, `transactionType: "card-payment"`, `pushIdentifier: "reference"` | [POS](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/vfd-pos) |
| Card Payment | **Not documented** | — |
| Debit Cards | **Not documented** | — |
| Payment Link | **Not documented** | — |

**Confirmed wallet repush request:**

```json
{
  "reference": "408210-P051200150941-2057JVSC-012804578357",
  "transactionType": "card-payment",
  "pushIdentifier": "reference"
}
```

**Confirmed:** `transactionStatus: "01"` means the webhook was not reachable; `status: "99"` with
`"Invalid transaction"` means an invalid transaction; `status: "99"` with
`"transactionId is mandatory"` means a missing push identifier.

**Observation:** repush is manual. Automatic retries, backoff, and maximum attempts are **not
documented** for any product.

---

## 12. Security analysis

### 12.1 What the documentation advises

It repeatedly advises:

- authentication or IP whitelisting on the merchant's webhook endpoint;
- responding with HTTP 200 once notified successfully.

That is the full extent of the guidance.

### 12.2 What is not documented

| Control | Status |
| --- | --- |
| Signature algorithm (HMAC, RSA, etc.) | **Not documented** |
| Shared secret provisioning/rotation | **Not documented** |
| Timestamp header and replay window | **Not documented** |
| Event ID / delivery ID | **Not documented** |
| At-least-once vs exactly-once delivery | **Not documented** |
| Retry schedule and timeout | **Not documented** |
| Source IP ranges | **Not documented** |
| mTLS | **Not documented** |
| Payload encryption | **Not documented** |
| Ordering guarantees | **Not documented** |

### 12.3 Consequences

1. **Spoofing.** Without a signature, anyone who learns a webhook URL can post a forged credit, payout,
   or card-success event. IP allow-listing helps only if the vendor publishes stable ranges and the
   receiver enforces them at the edge.
2. **Replay.** No timestamp or nonce is specified. A captured payload can be replayed. Receivers must
   deduplicate on `reference`/`session_id`/`retrievalReferenceNumber` and store processed IDs.
3. **Lost events.** With no documented retry contract, the receiver cannot assume delivery. Every
   webhook needs a reconciliation job against the corresponding status endpoint.
4. **False settles.** The initial-credit webhook can arrive before settlement. Receivers must not credit
   a spendable balance on an unsettled notification.
5. **Browser callback spoofing.** `onSuccess` is not authoritative.
6. **Cardholder data.** POS and debit-card payloads may contain PAN fragments. Treat them as
   cardholder data and keep them out of logs.
7. **Synchronous authorization.** The debit-authorization webhook is in the payment path. If the
   receiver is slow or down, card transactions may fail. Availability and timeout requirements are not
   documented.

### 12.4 Recommended posture for any future integration

- Verify every webhook against a status API before changing a ledger.
- Enforce IP allow-listing at the edge if VFD publishes the ranges.
- Deduplicate on a stable transaction identifier.
- Persist raw payloads in a restricted, redacted store.
- Never log full PAN, CVV, track-2, PINs, BVN, or NIN.
- Treat `onSuccess` and redirects as UX only.
- Require vendor confirmation of signature support before go-live.

---

## 13. Missing and ambiguous specifications

| Item | Status |
| --- | --- |
| Webhook signature scheme | **Not documented** |
| Retry policy | **Not documented** |
| Delivery timeout | **Not documented** |
| Event IDs / idempotency keys | **Not documented** |
| Ordering guarantees | **Not documented** |
| Source IP ranges | **Not documented** |
| Payment Link webhook contract | **Not documented** |
| Card-payment failure webhook | **Not documented** |
| Debit authorization decision semantics | **Not documented** |
| POS `hash` validation | **Not documented** |
| POS HTTP 200 requirement | **Not stated on POS page** |
| Webhook registration API | **Not documented** |
| Multiple endpoints / subscriptions | **Not documented** |

---

## 14. Related documents

- [VFD_WALLET.md](VFD_WALLET.md) — inward credit, transfer, and repush context.
- [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md) — card payment flow and status check.
- [VFD_DEBIT_CARDS.md](VFD_DEBIT_CARDS.md) — card lifecycle and the three card webhooks.
- [VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md) — LUX onboarding and POS payload.
- [VFD_PAYMENT_LINK.md](VFD_PAYMENT_LINK.md) — missing notification contract.
- [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) — `onSuccess` callback.
- [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md) — security review and reconciliation design.
