# VFD Debit Mandates API

> **Source:** [Debit Mandates](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/direct-debit)
> **Retrieved:** 6 November 2026. **Documentation only.**
>
> The vendor describes two collection options via debit mandate: a **direct mandate** (payer's bank
> contacts the payer; signature and witness required) and an **e-mandate** (payer funds a returned
> account with N50 to approve; no signature or witness).

---

## 1. Authorization and base URL

**Authorization:** `AccessToken: {{token}}`. See [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md).

| Environment | Base URL |
| --- | --- |
| Test | `https://api-devapps.vfdbank.systems/vtech-mandate/api/v2/directdebit` |
| Live | `https://api-apps.vfdbank.systems/vtech-mandate/api/v2/directdebit` |

All paths below are relative to this base URL.

---

## 2. Documented collection flow

For both mandate types:

1. Create the mandate (direct or e-mandate).
2. Call **Mandate Approval Status Query** to confirm the mandate status.
3. Only if the status is **Bank Approved**, call **Account Debit** to debit the customer's account.

**Vendor note for e-mandate:** in live, the account on which the e-mandate is set up must be used for
the N50 funding. The funding is the customer's approval. It must be done within **7 days** or the
mandate expires.

---

## 3. Direct mandate setup

**Path:** `/mandate/setup`
**Method:** `POST`

**Description:** sets up a debit mandate on a customer's bank account. The payer's bank typically
contacts the payer directly to confirm approval; payer signature and witness information are required.

### Sample request

```json
{
  "reference": "rosapay-202308191",
  "payerBank": "000007",
  "payerAccountNumber": "6170778639",
  "payerBvn": "222222222228",
  "payerAddress": "5, Ade Street, Lagos",
  "payerPhone": "09019056987",
  "payerEmailAddress": "odtest@gmail.com",
  "receiverBank": "999999",
  "receiverBvn": "22222222222",
  "receiverAccountNumber": "1001556881",
  "amount": "1000",
  "startDate": "02 June 2023",
  "endDate": "17 July 2023",
  "frequency": "1",
  "witnessName": "Joe Adams",
  "witnessAddress": "12, John Street, Lagos",
  "witnessOccupation": "Software Engineer",
  "payerSignature": "",
  "witnessSignature": ""
}
```

### Request fields as documented

| Field | Required | Description |
| --- | --- | --- |
| `reference` | Mandatory | Unique transaction reference, prefixed with the wallet name, e.g. `rosapay-202308191`. |
| `payerAccountNummber` | Mandatory | The account to initiate payment. **The field table spells it with a double “m”.** |
| `payerBank` | Mandatory | Payer's bank code. |
| `payerBvn` | Mandatory | Payer's BVN. |
| `payerAddress` | Mandatory | Payer's address. |
| `payerPhone` | Mandatory | Payer's phone. |
| `payerEmailAddress` | Mandatory | Payer's email address. |
| `payerAccountname` | Mandatory | Payer account name. |
| `receiverAccountNumber` | Mandatory | Account to receive payment. |
| `receiverBank` | Mandatory | Receiver's bank code. |
| `amount` | Mandatory | Maximum debit amount. |
| `startDate` | Mandatory | Mandate start date, e.g. `02 June 2023` (documented format). |
| `endDate` | Mandatory | Mandate end date, e.g. `17 July 2023` (documented format). |
| `frequency` | Mandatory | Debit recurrence: `1` daily, `2` weekly, `3` monthly. |
| `witnessName` | Mandatory | Witness name. |
| `witnessAddress` | Mandatory | Witness house address. |
| `witnessOccupation` | Mandatory | Witness occupation. |
| `payerSignature` | Mandatory | Payer signature as a base64 image. |
| `witnessSignature` | Mandatory | Witness signature as a base64 image. |

### Field-name discrepancies

**Observation — do not silently normalise:**

1. The table names `payerAccountNummber` (double “m”), but the sample JSON uses
   `payerAccountNumber`. The documentation does not say which the API accepts.
2. The table lists `payerAccountname` as mandatory, but the sample JSON does **not** include it.
3. The sample JSON includes `receiverBvn`, but the field table does **not** list it.

These must be verified in sandbox before implementation.

### Environment restrictions

**Confirmed:**

- In development, the mandate must be created with a **test VFD account** as both
  `payerAccountNumber` and `receiverAccountNumber`; other bank accounts are not supported in dev.
- In live, the payer bank must be a **commercial bank**.
- Minimum mandate amount is **NGN 1,000**.

### Sample response

```json
{
  "status": "00",
  "message": "Mandate Created Successfully",
  "data": {
    "mandateCode": "RC1203338/1/19062023163120"
  }
}
```

### Sample failures

```json
{
  "status": "99",
  "message": "Invalid Payer Account Number"
}
```

```json
{
  "status": "98",
  "message": "Mandate Reference Exist"
}
```

```json
{
  "status": "99",
  "message": "Witness Signature must be in base64"
}
```

---

## 4. E-mandate setup

**Path:** `/mandate/setup?e-mandate=true`
**Method:** `POST`

**Description:** sets up a debit mandate on a customer's bank account without payer/witness signatures.
The response returns an account number that must be funded with N50 to approve the mandate.

### Query parameter

| Field | Required | Description |
| --- | --- | --- |
| `e-mandate` | Mandatory | Must be `true` to create an e-mandate. |

### Sample request

```json
{
  "reference": "rosapay-202308191",
  "payerBank": "999999",
  "payerAccountNumber": "1001555949",
  "payerPhone": "09019056987",
  "payerEmailAddress": "test@gmail.com",
  "payerAddress": "5, Johnson Street, Ikeja, Lagos",
  "receiverBank": "999999",
  "receiverAccountNumber": "1001556551",
  "amount": "1000",
  "startDate": "02 June 2023",
  "endDate": "17 July 2023",
  "frequency": "1"
}
```

### Request fields

| Field | Required | Description |
| --- | --- | --- |
| `reference` | Mandatory | Unique transaction reference, prefixed with the wallet name. |
| `payerAddress` | Mandatory | Payer's address. |
| `payerAccountNumber` | Mandatory | Account to initiate payment. |
| `payerBank` | Mandatory | Payer's bank code. |
| `payerPhone` | Mandatory | Payer's phone. |
| `payerEmailAddress` | Mandatory | Payer's email address. |
| `receiverAccountNumber` | Mandatory | Account to receive payment. |
| `receiverBank` | Mandatory | Receiver's bank code. |
| `amount` | Mandatory | Maximum debit amount. |
| `startDate` | Mandatory | Mandate start date, e.g. `02 June 2023`. |
| `endDate` | Mandatory | Mandate end date, e.g. `17 July 2023`. |
| `frequency` | Mandatory | `1` daily, `2` weekly, `3` monthly. |

### Sample response

```json
{
  "status": "00",
  "message": "Welcome to NIBSS e-mandate authentication service, a seamless and convenient authentication experience. Kindly proceed with a token payment of N50:00 into account number \"1000000000\" with PAYSTACK - TITAN, Account name is NIGERIA INTERBANK SETTLEMENT SYSTEM PLC. Note: The payment should be done from the account on which the mandate is setup. This payment will trigger the authentication of your mandate. Thank You",
  "data": {
    "mandateCode": "RC1000000/1111/0001110111"
  }
}
```

**Observation:** the N50 funding account is delivered inside a human-readable `message`, not as a
structured field. Parsing a bank account number out of prose is fragile; manual/vendor confirmation is
required.

### Environment restrictions

- Live: the account used for the e-mandate must be the account that funds the N50; funding must occur
  within 7 days.
- Live: the payer bank must be a commercial bank.
- Both environments: the receiver bank may be commercial or non-commercial.

### Sample failures

```json
{
  "status": "99",
  "message": "Invalid Payer Account Number"
}
```

```json
{
  "status": "98",
  "message": "Mandate Reference Exist"
}
```

---

## 5. Test mandate payer and receiver accounts

| S/N | Bank code | Account number |
| --- | --- | --- |
| 1 | `000002` | `1111111103` |
| 2 | `000006` | `1111111111` |

---

## 6. Account debit

**Path:** `/account/debit`
**Method:** `POST`

**Description:** debits the customer's account under the mandate.

### Sample request

```json
{
  "amount": "1000",
  "narration": "mandate test via nibsseasypay",
  "mandateReference": "rosapay-2023089819319021212",
  "transactionReference": "rosapay-202308981931902"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `amount` | Mandatory | Amount to debit; must not exceed the amount specified at mandate creation. |
| `narration` | Optional | Transaction narration. |
| `mandateReference` | Mandatory | Reference used at mandate creation. |
| `transactionReference` | Mandatory | Unique transaction reference, prefixed with the wallet name. |

### Sample response

```json
{
  "status": "00",
  "message": "Mandate Account Transfer",
  "data": {
    "sessionId": "99999903232323200620230840476432023",
    "paymentReference": "BAAS-DD-2023062008452",
    "mandateCode": "RC1203338/1/19062023163120"
  }
}
```

### Sample failure

```json
{
  "status": "108",
  "message": "Invalid Reference!"
}
```

---

## 7. Account balance for a mandate

**Path:** `/account/balance?reference={reference}`
**Method:** `GET`

**Description:** returns the payer's account balance for a created mandate.

| Query | Required | Description |
| --- | --- | --- |
| `reference` | Mandatory | Reference used at mandate creation. |

### Sample response

```json
{
  "status": "200",
  "message": "Account Balance Retrieval For - John Doe",
  "data": {
    "accountNo": "1001573671",
    "availableBalance": "5000",
    "sessionId": "099090322109909032210990903221"
  }
}
```

Failure:

```json
{
  "status": "108",
  "message": "Invalid Reference!"
}
```

**Observation:** `status` is `"200"` here, not `"00"`. Do not reuse the transfer/bill status parser.

---

## 8. Mandate approval status query

**Path:** `/mandate/status`
**Method:** `GET`

**Description:** views the approval status of a mandate.

| Query | Required | Description |
| --- | --- | --- |
| `reference` | Mandatory | Reference used at mandate creation. |

### Sample response

```json
{
  "status": "200",
  "message": "Mandate Created Successfully",
  "data": {
    "mandateState": "ACTIVE",
    "mandateWorkflowStatus": "MANDATE_APPROVED_BY_BANK",
    "mandateWorkflowStatusDescription": "Bank Approved"
  }
}
```

Documented values:

- `mandateState`: `ACTIVE`
- `mandateWorkflowStatus`: `MANDATE_APPROVED_BY_BANK`
- `mandateWorkflowStatusDescription`: `Bank Approved`

> **Not documented:** the full enumeration of mandate states/workflow statuses, rejection reasons, or
> expiry states. `status: "200"` is also not explained.

---

## 9. Mandate debit status query

**Path:** `/transaction/status`
**Method:** `GET`

**Description:** views the transaction status of a mandate debit.

| Query | Required | Description |
| --- | --- | --- |
| `reference` | Mandatory | Reference used in the mandate debit. |

### Sample response

```json
{
  "status": "00",
  "message": "Successful Transaction Retrieval",
  "data": {
    "TxnId": "rosapay-098388438",
    "amount": "1000.00",
    "fromAccount": "1001648379",
    "fromBank": "090110",
    "toAccount": "1001649376",
    "toBank": "090110",
    "mandateReference": "rosapay-202308191509",
    "transactionStatus": "00",
    "transactionDate": "2025-05-28T17:39:11",
    "sessionId": "99999903232323280520251839116472025"
  }
}
```

**Vendor note:** `transactionStatus` represents the mandate debit transaction status.

**Observation:** the query parameter table says `reference`, but the sample response exposes
`TxnId` and `mandateReference`. The documentation does not state whether `reference` means
`transactionReference` from `/account/debit` or `mandateReference`.

---

## 10. Response codes

The page publishes a combined code table for debit mandates. It is reproduced as published.

| S/N | Description | Code |
| --- | --- | --- |
| 1 | Approved or completed successfully | 00 |
| 2 | Status unknown, please wait for settlement report | 01 |
| 3 | Invalid Sender | 03 |
| 4 | Do not honor | 05 |
| 5 | Dormant Account | 06 |
| 6 | Invalid Account | 07 |
| 7 | Account Name Mismatch | 08 |
| 8 | Request processing in progress | 09 |
| 9 | Invalid transaction | 12 |
| 10 | Invalid Amount | 13 |
| 11 | Invalid Batch Number | 14 |
| 12 | Invalid Session or Record | 15 |
| 13 | Unknown Bank Code | 16 |
| 14 | Invalid Channel | 17 |
| 15 | Wrong Method Call | 18 |
| 16 | No action taken | 21 |
| 17 | Unable to locate record | 25 |
| 18 | Duplicate record | 26 |
| 19 | Format error | 30 |
| 20 | Suspected fraud | 34 |
| 21 | Contact sending bank | 35 |
| 22 | EXPIRED MANDATE | 40 |
| 23 | DEBIT AMOUNT GREATER THAN MANDATE | 41 |
| 24 | PREMATURE MANDATE | 42 |
| 25 | UNAPPROVED MANDATE | 43 |
| 26 | SUSPENDED DELETED MANDATE | 44 |
| 27 | NOT VARIABLE FREQUENCY MANDATE | 45 |
| 28 | NOT VARIABLE AMOUNT MANDATE | 46 |
| 29 | No sufficient funds | 51 |
| 30 | Transaction not permitted to sender | 57 |
| 31 | Transaction not permitted on channel | 58 |
| 32 | Transfer limit Exceeded | 61 |
| 33 | Security violation | 63 |
| 34 | Exceeds withdrawal frequency | 65 |
| 35 | Response received too late | 68 |
| 36 | Unsuccessful Account/Amount block | 69 |
| 37 | Unsuccessful Account/Amount unblock | 70 |
| 38 | Empty Mandate Reference Number | 71 |
| 39 | Beneficiary Bank not available | 91 |
| 40 | Routing error | 92 |
| 41 | Duplicate | 94 |
| 42 | Payment was not completed. Contact the bank. | 95 |
| 43 | System malfunction | 96 |
| 44 | Timeout waiting for response from destination | 97 |
| 45 | Client Disabled | A1 |
| 46 | Not found | A2 |
| 47 | Mandate Expired | A3 |
| 48 | Empty Value | A4 |
| 49 | Invalid Value | A5 |
| 50 | Invalid Data Provided | A6 |
| 51 | Remote IP not Permited | A7 |
| 52 | Invalid Client id | A8 |
| 53 | Unable to Process request, please try again | A9 |
| 54 | Mandate Bank Mismatch | B0 |
| 55 | Mandate Account Mismatch | B1 |

**Observation:** code `26` is “Duplicate record” in this table, while the transfer table uses `26` for
“Successful”. Codes are scoped by product; do not share a global meaning.

---

## 11. Bank codes published on this page

| Bank | Code |
| --- | --- |
| ACCESS BANK PLC | 000014 |
| CITI BANK | 000009 |
| Coronation Merchant Bank | 060001 |
| EcoBank Plc | 000010 |
| FBNQUEST Merchant Bank | 060002 |
| FIDELITY BANK PLC | 000007 |
| FIRST BANK OF NIGERIA PLC | 000016 |
| FIRST CITY MONUMENT BANK PLC | 000003 |
| FSDH MERCHANT BANK | 400001 |
| Globus Bank Ltd | 000027 |
| GUARANTY TRUST BANK PLC | 000013 |
| JAIIZ Bank | 000006 |
| KEYSTONE BANK PLC | 000002 |
| Kuda Microfinance Bank | 090267 |
| LOTUS Bank | 000029 |
| MAINSTREET BANK PLC | 999014 |
| OPTIMUS BANK LIMITED | 000036 |
| PARALLEX BANK | 000030 |
| POLARIS BANK LIMITED | 000008 |
| PremiumTrust Bank Limited | 000031 |
| Providus Bank | 000023 |
| Rand Merchant Bank | 000024 |
| Stanbic IBTC | 000012 |
| STANDARD CHARTERED BANK PLC | 000021 |
| STERLING BANK PLC | 000001 |
| SUNTRUST BANK | 000022 |
| TAJBank Ltd | 000026 |
| The Alternative Bank Limited | 000037 |
| TITAN TRUST BANK | 000025 |
| UBA Plc | 000004 |
| UNION BANK OF NIGERIA PLC | 000018 |
| UNITY BANK PLC | 000011 |
| Wema Bank | 000017 |
| ZENITH INTERNATIONAL BANK | 000015 |

> **Observation:** the wallet page's `/bank` endpoint is the documented general bank list, but this
> static table is the only published bank-code dataset. It may not match the live `/bank` response.
> The list includes microfinance and merchant banks; the mandate text separately restricts payer
> banks to commercial banks in live.

---

## 12. Missing and ambiguous specifications

| Item | Status |
| --- | --- |
| Full mandate state/workflow enumeration | **Not documented** |
| Mandate cancellation/revocation | **Not documented** |
| Mandate amendment (amount/frequency/end date) | **Not documented** |
| Payer-approval webhook | **Not documented** |
| Idempotency semantics | **Not documented** (duplicate-reference response exists) |
| Field-name conflict (`payerAccountNummber` vs `payerAccountNumber`) | **Ambiguous** |
| `payerAccountname` requirement | **Ambiguous** (table says mandatory; sample omits it) |
| `receiverBvn` requirement | **Ambiguous** (sample includes it; table omits it) |
| N50 funding account structure | **Not documented** (delivered in prose) |
| `reference` semantics on debit-status query | **Ambiguous** |
| HTTP status codes | **Not documented** |
| Webhooks | **None documented** for mandates |
| Fees/charges | **Not documented** |

For security and Hivorr relevance, see [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md).
