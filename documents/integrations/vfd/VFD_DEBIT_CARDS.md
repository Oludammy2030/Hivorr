# VFD Debit Cards API

> **Source:** [Debit Cards](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/debit-card)
> **Retrieved:** 6 November 2026. **Documentation only.**
>
> The vendor describes this API as issuing debit cards linked to a merchant sub-account. The documented
> product is a **virtual** debit card with an activation and PIN-change lifecycle. Physical-card
> issuance, funding, and limits are not documented on this page.

---

## 1. Authorization and base URL

**Authorization:** `AccessToken: {{token}}`. See [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md).

| Environment | Base URL |
| --- | --- |
| Test | `https://api-devapps.vfdbank.systems/vtech-cards/api/v2/baascards` |
| Live | `https://api-apps.vfdbank.systems/vtech-cards/api/v2/baascards` |

**Observation:** the base path is `baascards` (no hyphen). The separate Card Payment API uses
`baas-cards` (with a hyphen). They are different products and different base paths:

| Product | Base path |
| --- | --- |
| Card Payment (accepting payments) | `/vtech-cards/api/v2/baas-cards` |
| Debit Cards (issuing cards) | `/vtech-cards/api/v2/baascards` |

Do not substitute one for the other.

---

## 2. Card lifecycle

**Confirmed:** the virtual-card process is:

1. Call **Create Virtual Card** (`/cardrequest?action=virtual`).
2. Call **Activate Debit Card** (`/cardaction/request`, `action: "ACTIVATE"`) — returns the default
   PIN.
3. Call **PIN Change** (`/cardaction/request`, `action: "PIN-CHANGE"`) with the default PIN and a new
   PIN. This completes activation.

**Confirmed:** the card is linked to a merchant sub-account (`accountNo`).

**Observation:** the lifecycle is stateful and relies on the caller retaining `cardId` and the default
PIN between steps. If step 2 succeeds but the response is lost, the caller may not know the default
PIN and may have to restart or contact support. No recovery flow is documented.

---

## 3. Create virtual card

**Path:** `/cardrequest?action=virtual`
**Method:** `POST`
**Headers:** `AccessToken: {{token}}`

| Query parameter | Description | Required |
| --- | --- | --- |
| `action` | Card creation type. | Mandatory |

### 3.1 Request

```json
{
  "accountNo": "1001555798",
  "primaryPhoneNo": "09023449092",
  "emailAddress": "afunbioluwa@gmail.com"
}
```

| Field | Description | Required |
| --- | --- | --- |
| `accountNo` | Sub-account of the merchant. | Mandatory |
| `primaryPhoneNo` | Creator's phone number. | Mandatory |
| `emailAddress` | Creator's email address. | Mandatory |

### 3.2 Response

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "maskedPan": "506124******6131",
    "track2": "5061240021356131=2612601001641398",
    "cvv": "123",
    "pinOffset": "1407",
    "expiryDate": "1204",
    "pan": "5061249421446131",
    "cardId": "11703"
  }
}
```

| Field | Meaning |
| --- | --- |
| `maskedPan` | Masked primary account number. |
| `track2` | Full magnetic-stripe track-2 equivalent data. |
| `cvv` | Card verification value. |
| `pinOffset` | PIN offset value. |
| `expiryDate` | Expiry in `MMYY` format (`1204` = December 2004 in the sample; likely a placeholder). |
| `pan` | Full primary account number. |
| `cardId` | Card identifier used in later calls. |

**Security — critical:** the creation response returns the **full PAN, CVV, track-2 data, and PIN
offset** in a JSON body. This is cardholder data. Handling it brings the caller into PCI DSS scope.
The vendor page gives no guidance on secure handling, storage, logging, or display. See §8.

**Observation:** the sample `expiryDate` (`1204`) is in the past and is presumably illustrative.
`pan` and `maskedPan` do not correspond (`5061249421446131` vs `506124******6131`), so at least one is
a placeholder.

**Not documented:** whether a physical card can be requested, card programme/BIN ranges, currency,
spending limits, card funding, or whether multiple cards per account are allowed.

---

## 4. Activate debit card

**Path:** `/cardaction/request`
**Method:** `POST`
**Headers:** `AccessToken: {{token}}`

### 4.1 Request

```json
{
  "action": "ACTIVATE",
  "accountNo": "1001555798",
  "cardId": "11703"
}
```

| Field | Description | Required |
| --- | --- | --- |
| `action` | Action to carry out on the card. | Mandatory |
| `accountNo` | Account number used to create the card. | Mandatory |
| `cardId` | Card ID returned at creation. | Mandatory |

### 4.2 Response

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "pin": "1234"
  }
}
```

**Confirmed:** activation returns the **default PIN** in plaintext. The next step must change it.

**Security:** the default PIN is transmitted in the API response. If the response is logged or cached,
the PIN is exposed. The page gives no guidance on delivering the PIN to the cardholder securely.

---

## 5. PIN change

**Path:** `/cardaction/request`
**Method:** `POST`
**Headers:** `AccessToken: {{token}}`

### 5.1 Request

```json
{
  "action": "PIN-CHANGE",
  "cardId": "11703",
  "accountNo": "1001555798",
  "newCardPin": "1366",
  "cardPin": "1234"
}
```

| Field | Description | Required |
| --- | --- | --- |
| `accountNo` | Account number used to create the card. | Mandatory |
| `action` | Action to carry out. | Mandatory |
| `cardId` | Card ID. | Mandatory |
| `newCardPin` | New PIN. | Mandatory |
| `cardPin` | Default PIN received on activation. | Mandatory |

### 5.2 Response

```json
{
  "status": "00",
  "message": "Pin successfully changed"
}
```

**Security:** both the old and new PIN travel in the JSON body. There is no documented HSM-backed PIN
block, encryption, or re-authentication step. The page does not state whether PIN change requires the
cardholder's involvement or can be performed by the merchant alone.

**Not documented:** PIN retry limits, lockout behaviour, PIN reset, or whether weak PINs are rejected.

---

## 6. Block debit card

**Path:** `/cardaction/request`
**Method:** `POST`
**Headers:** `AccessToken: {{token}}`

### 6.1 Request

```json
{
  "action": "BLOCK",
  "cardId": "11703",
  "accountNo": "1001555798"
}
```

| Field | Description | Required |
| --- | --- | --- |
| `action` | Action to carry out. | Mandatory |
| `accountNo` | Account number used to create the card. | Mandatory |
| `cardId` | Card ID. | Mandatory |

### 6.2 Response

```json
{
  "status": "00",
  "message": "Successful"
}
```

**Not documented:** whether blocking is reversible, whether in-flight authorizations are declined,
whether a block reason is recorded, or whether the cardholder can self-service the block.

---

## 7. Unblock debit card

**Path:** `/cardaction/request`
**Method:** `POST`
**Headers:** `AccessToken: {{token}}`

### 7.1 Request

```json
{
  "action": "UNBLOCK",
  "cardId": "11703",
  "accountNo": "1001555798"
}
```

### 7.2 Responses

Success:

```json
{
  "status": "00",
  "message": "Successful"
}
```

Failure:

```json
{
  "status": "01",
  "message": "Invalid Account Number and Card Id Combination"
}
```

**Observation:** the unblock failure is the only documented error example for the card-action
endpoint. It uses `status: "01"`. No full error catalogue is published.

**Not documented:** whether unblock requires additional verification, whether a blocked card can be
unblocked after a fraud block, or whether there is a maximum number of block/unblock cycles.

---

## 8. Card transactions

**Path:** `/account/transactions?accountNumber={accountNumber}&startDate={startDate}&endDate={endDate}&page=0&size=20`
**Method:** `POST`
**Headers:** `AccessToken: {{token}}`

### 8.1 Query parameters

| Field | Description | Required |
| --- | --- | --- |
| `accountNumber` | Customer's account number. | Mandatory |
| `startDate` | Start date, e.g. `2025-04-15`. | Mandatory |
| `endDate` | End date, e.g. `2025-04-17`. The table repeats "start date", a documentation typo. | Mandatory |
| `page` | Page number, starts at 0. | Optional |
| `size` | Page size. | Optional |

**Observation:** the operation is `POST` but takes all inputs as query parameters and has no documented
request body. This is unusual but is stated explicitly. Do not change it to `GET` without vendor
confirmation.

### 8.2 Response

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "content": [
      {
        "transactionStatus": "success",
        "transactionType": "cashWithdrawal",
        "amount": "23.00",
        "sourceAccountno": "1001626656",
        "transmissionDate": "2025-03-14 10:20:18.0",
        "transactionFee": "0.00",
        "beneficiaryAccountno": null,
        "retrievalReferenceNumber": "847571200968",
        "card_acceptorTerminalid": "3IPG0001"
      },
      {
        "transactionStatus": "success",
        "transactionType": "debitGoodsAndServices",
        "amount": "21.00",
        "sourceAccountno": "1001626656",
        "transmissionDate": "2025-03-14 10:20:18.0",
        "transactionFee": "0.00",
        "beneficiaryAccountno": null,
        "retrievalReferenceNumber": "847571200967",
        "card_acceptorTerminalid": "3IPG0001"
      }
    ],
    "totalElements": 10,
    "totalPages": 2
  }
}
```

| Field | Description |
| --- | --- |
| `transactionStatus` | Status string, e.g. `success`. |
| `transactionType` | e.g. `cashWithdrawal`, `debitGoodsAndServices`. |
| `amount` | Transaction amount as a string. |
| `sourceAccountno` | Source account. Note the lower-case `no`. |
| `transmissionDate` | Timestamp with a trailing `.0`. |
| `transactionFee` | Fee as a string. |
| `beneficiaryAccountno` | Beneficiary account or `null`. |
| `retrievalReferenceNumber` | Retrieval reference. |
| `card_acceptorTerminalid` | Terminal ID. Note the mixed snake/camel casing. |
| `totalElements` | Total records. |
| `totalPages` | Total pages. |

**Observation:** response field names are inconsistent (`sourceAccountno`, `beneficiaryAccountno`,
`card_acceptorTerminalid`). Map them explicitly rather than generating names from a convention.

**Not documented:** maximum page size, default page size, sort order, date range limits, timezone of
`transmissionDate`, or a transaction-detail endpoint.

---

## 9. Webhooks

Three card-management webhooks are documented. All require an HTTP `POST` endpoint that returns
HTTP 200 on success.

### 9.1 Debit transaction notification

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

### 9.2 Debit authorization webhook

**Confirmed:** required to validate a debit request on the merchant's sub-account. Specifically needed
for merchants on the **POOL** implementation.

Request:

```json
{
  "accountNo": "1001626656",
  "amount": "200"
}
```

| Field | Description |
| --- | --- |
| `accountNo` | Account number of the card that initiated the request. |
| `amount` | Requested debit amount. |

The page also shows a second payload shape containing only `accountNo`.

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

**Observation:** the webhook is described as "required to validate the debit request", but the expected
response supplies a balance, not an approve/decline decision. How the balance authorizes or refuses the
debit is **not documented**.

**Observation:** two request shapes are shown (`accountNo` + `amount`, and `accountNo` alone) without
explaining when each is used.

### 9.3 Balance check webhook

**Confirmed:** used to retrieve the current balance of a merchant sub-account. Specifically needed for
merchants on the **POOL** implementation.

Request:

```json
{
  "accountNo": "1001626656"
}
```

Expected response is identical to the debit-authorization response:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "accountBalance": "125000.50"
  }
}
```

**Observation:** the debit-authorization and balance-check webhooks share a response shape and an
`accountNo` request. The page does not explain how the caller distinguishes them, or whether they can
be the same URL.

### 9.4 Webhook security guidance

**Confirmed:** "When sharing a webhook with us, security measures such as Authentication or IP
whitelisting are advised to be in place. Also, your webhook url should respond with a 200 status code
once notified successfully."

**Not documented:** signature algorithm, shared secret, timestamp, replay protection, retry schedule,
or delivery timeout. See [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md).

---

## 10. Security review

| Issue | Detail |
| --- | --- |
| Full card data in response | Create returns `pan`, `cvv`, `track2`, `pinOffset`. This is cardholder data and brings the integrator into PCI DSS scope. |
| Default PIN in response | Activation returns `pin` in plaintext. |
| PINs in request bodies | PIN change sends `cardPin` and `newCardPin`. |
| No documented PCI guidance | The page does not mention PCI DSS, tokenization, HSMs, or secure storage. |
| No documented webhook authentication | Only advice to use authentication or IP allow-listing. |
| Account/card enumeration | The unblock error distinguishes an invalid account/card combination. |
| No idempotency | Card creation is a stateful POST; a retry could create duplicate cards. |
| No maker-checker | Any holder of the token can create, activate, block, unblock, and change PINs. |
| Token scope | The wallet access token appears to authorize card issuance; no narrower scope is documented. |

**Open questions for the vendor:**

1. Is there a PCI-compliant mode that returns only a masked PAN and a token?
2. Can card creation and PIN change be separated by role or approval?
3. Are PAN/CVV ever needed by the integrator, or can they be delivered directly to the cardholder?
4. Is the default PIN single-use and time-limited?
5. Are card actions idempotent?
6. What webhook authentication is supported?

---

## 11. Missing and ambiguous specifications

| Item | Status |
| --- | --- |
| Physical card issuance | **Not documented** |
| Card funding / loading | **Not documented** |
| Spending limits / controls | **Not documented** |
| Card list / get-by-id | **Not documented** |
| Card replacement / termination | **Not documented** |
| Full error catalogue | **Not documented** |
| Idempotency | **Not documented** |
| Webhook signature | **Not documented** |
| Request/response encryption | **Not documented** |
| PIN delivery to cardholder | **Not documented** |
| Test data | **Not documented** |
| Pagination limits | **Not documented** |

---

## 12. Related documents

- [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md) — accepting card payments (different base path).
- [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) — consolidated webhook catalogue.
- [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md) — access token.
- [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md) — security review and open questions.
