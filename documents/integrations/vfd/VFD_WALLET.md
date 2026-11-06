# VFD Wallets, Accounts, Transfers and Transaction Services

> **Source:** [Wallets API](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/wallets-api)
> **Retrieved:** 6 November 2026. **Documentation only — no integration code.**
>
> This is the largest VFD product page. It is treated as one document because the vendor publishes it
> as one page, but it covers account creation, virtual accounts, KYC enquiry, transfers, transaction
> history, QR codes, account remediation, and two Lux POS helpers. Read the section you need rather
> than assuming the whole surface is one coherent onboarding flow.

---

## Contents

1. [Base URL and authorization](#1-base-url-and-authorization)
2. [Wallet implementation models](#2-wallet-implementation-models)
3. [Operation inventory](#3-operation-inventory)
4. [Individual account creation and tiers](#4-individual-account-creation-and-tiers)
5. [Corporate accounts and sub-accounts](#5-corporate-accounts-and-sub-accounts)
6. [Virtual accounts](#6-virtual-accounts)
7. [KYC enquiry — BVN details, consent and account lookup](#7-kyc-enquiry--bvn-details-consent-and-account-lookup)
8. [Account and beneficiary enquiry](#8-account-and-beneficiary-enquiry)
9. [Transfers](#9-transfers)
10. [Simulated inbound credit (test only)](#10-simulated-inbound-credit-test-only)
11. [Transaction history](#11-transaction-history)
12. [QR code services](#12-qr-code-services)
13. [Account upgrade and remediation](#13-account-upgrade-and-remediation)
14. [Lux POS helper endpoints](#14-lux-pos-helper-endpoints)
15. [Transfer response codes](#15-transfer-response-codes)
16. [Test data published by VFD](#16-test-data-published-by-vfd)
17. [Webhooks on this page](#17-webhooks-on-this-page)
18. [Documentation gaps and ambiguities](#18-documentation-gaps-and-ambiguities)

---

## 1. Base URL and authorization

| Environment | Base URL |
| --- | --- |
| Test | `https://api-devapps.vfdbank.systems/vtech-wallet/api/v2/wallet2` |
| Live | `https://api-apps.vfdbank.systems/vtech-wallet/api/v2/wallet2` |

All requests require:

| Header | Value |
| --- | --- |
| `AccessToken` | `{{token}}` |

Token generation: [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md).

---

## 2. Wallet implementation models

### 2.1 POOL

- Funds entering sub-accounts are swept automatically to the corporate account.
- Inward and outward charges are deducted from the corporate account.

### 2.2 1-1

- Funds entering sub-accounts remain there and are not swept.
- Outward charges are deducted from the customer's account.
- Inward charges are deducted from the corporate account.

**Observation:** the transfer payload contains `uniqueSenderAccountId`, described as required only in
the **pool** implementation when a sub-account sends funds and the receiver should see the exact
sender. The documentation does not state how the model is selected.

---

## 3. Operation inventory

The wallet page groups operations as follows. All paths are relative to the base URL unless stated.

| Group | Operation | Method | Documented path |
| --- | --- | --- | --- |
| Account creation | Individual with NIN + DOB | POST | `/client/tiers/individual?nin={nin}&dateOfBirth={dateOfBirth}` |
| Account creation | Individual with BVN + DOB | POST | `/client/tiers/individual?bvn={bvn}&dateOfBirth={dateOfBirth}` |
| Account creation | Individual with NIN + BVN + DOB | POST | `/client/tiers/individual?bvn={bvn}&nin={nin}&dateOfBirth={dateOfBirth}` |
| Account creation | Individual with NIN + BVN + address + DOB | POST | `/client/tiers/individual?bvn={bvn}&nin={nin}&address={address}&dateOfBirth={dateOfBirth}` |
| Account creation | Duplicate individual | POST | `/client/tiers/individual?previousAccountNo={previousAccountNo}` |
| Account upgrade | Client tier upgrade | POST | `/client/update` |
| Corporate | Create corporate account / duplicate | POST | `/client/tiers/corporate` |
| Corporate | Create branch/purpose sub-account | POST | `/client/corporate/sub-account` |
| Virtual account | Create temporary virtual account | POST | `/virtualaccount` |
| Virtual account | Update amount | POST | `/virtualaccount/amountupdate` |
| KYC enquiry | Get client by BVN | GET | `/client?bvn={bvn}` |
| KYC enquiry | BVN consent | GET | `/bvn-consent?bvn={bvn}&type={type}&reference={reference}` |
| KYC enquiry | BVN account lookup | GET | `/bvn-account-lookup?bvn={bvn}` |
| Account enquiry | List virtual/individual/corporate accounts | GET | `/sub-accounts?entity={entity}&size={size}&page={page}` |
| Transfer | Account/source enquiry | GET | `/account/enquiry?accountNumber={accountNumber}` |
| Transfer | Beneficiary enquiry | GET | `/transfer/recipient?accountNo={accountNo}&bank={bank}&transfer_type={transfer_type}` |
| Transfer | Bank list | GET | `/bank` |
| Transfer | Single transfer | POST | `/transfer` |
| Transfer | Bulk transfer | POST | `/bulk/transfer` |
| Transfer | Bulk transfer enquiry | GET | `/bulk/transfers?batchId={batchId}` |
| Transfer | Transaction status query (TSQ) | GET | `/transactions?reference={reference}` or `/transactions?sessionId={sessionId}` |
| Transfer | Reversal status query | GET | `/transactions/reversal?reference={reference}` |
| Transfer | Simulated credit (test) | POST | `/credit` |
| Transactions | Account transactions | GET | `/account/transactions?...` |
| Transactions | Virtual account transactions | GET | `/virtualaccount/transactions?...` |
| QR | Generate QR code | POST | `/qrcode/generate` |
| QR | Query QR code | POST | `qrcode/query` (vendor text omits the leading slash) |
| QR | Pay with QR code | POST | `/qrcode/pay` |
| Account upgrade | Update/recomply/convert | POST | `/client/upgrade` |
| Lux POS | Webhook repush | POST | `/transactions/repush` |
| Lux POS | POS transaction status | GET | `/transactions?transactionType={type}&reference={reference}` |

**Observation:** the page's “Allowed Operations” list also names `/**transactions**` and
`/**transactions/reversal**`, which correspond to the TSQ and reversal endpoints above. The list is
descriptive, not a formal API index.

---

## 4. Individual account creation and tiers

**Method:** `POST` for all variants.
**Path:** `/client/tiers/individual`
**Headers:** `AccessToken`.

The KYC inputs supplied determine the account tier and limits:

| Inputs | Tier | Documented daily withdrawal limit | Documented maximum transaction limit |
| --- | --- | --- | --- |
| NIN + date of birth | 1 | ₦30,000 | ₦30,000 |
| BVN + date of birth | 1 | ₦30,000 | ₦30,000 |
| NIN + BVN + date of birth | 2 | ₦100,000 | ₦100,000 |
| NIN + BVN + address + date of birth | 3 | ₦10,000,000 | ₦1,000,000 |

The page says “daily withdrawal limit and max transaction limit”; the table above mirrors the exact
figures stated for each variant.

### 4.1 With NIN and date of birth

**Path:** `/client/tiers/individual?nin={nin}&dateOfBirth={dateOfBirth}`

| Field | Required | Description |
| --- | --- | --- |
| `nin` | Mandatory | Customer's National Identification Number. |
| `dateOfBirth` | Mandatory | DOB registered to the NIN, format `2002-01-20` as shown. |

Success:

```json
{
  "status": "00",
  "message": "Account created successfully",
  "data": {
    "firstname": "rosapay-Ronald",
    "middlename": "Segun",
    "lastname": "Kareem",
    "currentTier": "1",
    "accountNo": "1001640287"
  }
}
```

Documented failures include:

| Status | Message |
| --- | --- |
| `119` | `Not Authorized to Create Clients` |
| `199` | `dob is mandatory` |
| `01` | `Client Account Exists` (includes `data.accountNo`) |
| `102` | `Invalid nin: 88888888899` |
| `103` | `Date Of Birth Mismatch` |
| `929` | `Error creating client: Contact Admin` |
| `106` | `Client's BVN is not linked to any phone number.` |

### 4.2 With BVN and date of birth

**Path:** `/client/tiers/individual?bvn={bvn}&dateOfBirth={dateOfBirth}`

| Field | Required | Description |
| --- | --- | --- |
| `bvn` | Mandatory | Customer's Bank Verification Number, e.g. `22222222222`. |
| `dateOfBirth` | Mandatory | DOB registered to the BVN, e.g. `08-Mar-1995` (documented format). |

Success:

```json
{
  "status": "00",
  "message": "Account created successfully",
  "data": {
    "firstname": "rosapay-Zack",
    "middlename": "Rock",
    "lastname": "Doe",
    "currentTier": "1",
    "accountNo": "1001640304"
  }
}
```

Documented failures include `119`, `199` (`dob is mandatory`), `01` (account exists), `103`
(BVN not linked to a phone number, or date-of-birth mismatch), `929` (`Error creating client: Contact
Admin` or `Invalid BVN or Could Not Reach BVN Service`).

### 4.3 With NIN, BVN and date of birth

**Path:** `/client/tiers/individual?bvn={bvn}&nin={nin}&dateOfBirth={dateOfBirth}`

| Field | Required | Description |
| --- | --- | --- |
| `bvn` | Mandatory | Customer's BVN. |
| `dateOfBirth` | Mandatory | DOB registered to BVN or NIN, e.g. `08-Mar-1995`. |
| `nin` | Mandatory | Customer's National Identity Number. |

Success (tier 2):

```json
{
  "status": "00",
  "message": "Account created successfully",
  "data": {
    "firstname": "rosapay-Zack",
    "middlename": "Rock",
    "lastname": "Doe",
    "currentTier": "2",
    "ninVerification": "Successful",
    "ninValidation": "Successful",
    "bvnVerification": "Successful",
    "bvnValidation": "Successful",
    "accountNo": "1001640335",
    "nameMatch": "true"
  }
}
```

Documented failures include `119`, `199` (`dob is mandatory`, or `Invalid bvn: ..., Invalid nin: ...`),
`01`, `929`, `103`.

### 4.4 With NIN, BVN, address and date of birth

**Path:** `/client/tiers/individual?bvn={bvn}&nin={nin}&address={address}&dateOfBirth={dateOfBirth}`

| Field | Required | Description |
| --- | --- | --- |
| `bvn` | Mandatory | Customer's BVN. |
| `dateOfBirth` | Mandatory | DOB registered to BVN or NIN. |
| `nin` | Mandatory | Customer's NIN. |
| `address` | Mandatory | Customer's address. |

Success (tier 3):

```json
{
  "status": "00",
  "message": "Account created successfully",
  "data": {
    "firstname": "rosapay-Zack",
    "middlename": "Rock",
    "lastname": "Doe",
    "currentTier": "3",
    "ninVerification": "Successful",
    "ninValidation": "Successful",
    "bvnVerification": "Successful",
    "bvnValidation": "Successful",
    "accountNo": "1001640342",
    "nameMatch": "true",
    "address": "10, Johnson Street, Ikeja, Lagos"
  }
}
```

Documented failures are the same family as §4.3.

### 4.5 Duplicate individual account

**Path:** `/client/tiers/individual?previousAccountNo={previousAccountNo}`

| Field | Required | Description |
| --- | --- | --- |
| `previousAccountNo` | Mandatory | Individual client's previous account. |

Success:

```json
{
  "status": "00",
  "message": "Account created successfully",
  "data": {
    "firstname": "rosapay-Paul",
    "middlename": "Smith",
    "lastname": "Doe",
    "accountNo": "1001631397"
  }
}
```

Documented failures:

| Status | Message |
| --- | --- |
| `119` | `Not Authorized to Create Clients` |
| `929` | `Invalid Previous Account: 9001630761` |
| `929` | `Invalid Previous Account: 1001630761. Kindly update the previous account with its bvn or nin` |
| `929` | `Account under review: 1001630761. Contact admin` |

### 4.6 Tier upgrade (`/client/update`)

**Path:** `/client/update`
**Method:** `POST`

**Confirmed description:** upgrades the tier of an **existing individual account only**. Corporate
accounts are not covered by this endpoint. Five variants are documented.

Common fields:

| Field | Required | Description |
| --- | --- | --- |
| `accountNo` | Mandatory | Existing individual account. |
| `bvn` | Variant-dependent | Individual's BVN. Mandatory in the BVN variants. |
| `nin` | Variant-dependent | Individual's NIN. Mandatory in the NIN variants. |
| `address` | Variant-dependent | Individual's address. "Optional if it was passed during account creation else must be passed." |

**Variant 1 — tier 1 to tier 2, account created with NIN and date of birth:**

```json
{
  "accountNo": "1001637241",
  "bvn": "23448292110"
}
```

**Variant 2 — tier 1 to tier 3, account created with NIN and date of birth:**

```json
{
  "accountNo": "1001637241",
  "bvn": "23448292110",
  "address": "5, Johnson Str, Ikeja, Lagos"
}
```

**Variant 3 — tier 1 to tier 2, account created with BVN and date of birth:**

```json
{
  "accountNo": "1001640294",
  "nin": "22228819111"
}
```

**Variant 4 — tier 1 to tier 3, account created with BVN and date of birth:**

```json
{
  "accountNo": "1001640294",
  "nin": "22228819111",
  "address": "5, Johnson Str, Ikeja, Lagos"
}
```

**Variant 5 — tier 2 to tier 3:**

```json
{
  "accountNo": "1001640335",
  "address": "5, Johnson Str, Ikeja, Lagos"
}
```

All five variants return the same success envelope, with `currentTier` and the verification field
corresponding to the identity document supplied:

```json
{
  "status": "00",
  "message": "Account upgraded successfully",
  "data": {
    "firstname": "rosapay-Zack",
    "middlename": "Rock",
    "lastname": "Doe",
    "currentTier": "2",
    "bvnVerification": "Successful"
  }
}
```

The BVN variants return `bvnVerification`; the NIN variants return `ninVerification`. The tier-2 to
tier-3 variant uses the NIN response sample (`ninVerification`).

Documented failures:

| Status | Message |
| --- | --- |
| `199` | `No previous account found` |
| `199` | `Unable to upgrade account` |

> **Observation:** the endpoint name is `/client/update`, but a separate `/client/upgrade` endpoint
> (see §13) covers BVN remediation, compliance updates, and individual-to-corporate upgrades. Do not
> treat them as interchangeable.

---

## 5. Corporate accounts and sub-accounts

### 5.1 Create corporate account / duplicate

**Path:** `/client/tiers/corporate`
**Method:** `POST`

Create request:

```json
{
  "rcNumber": "9876212",
  "companyName": "Famous Technologies",
  "incorporationDate": "05 January 2005",
  "bvn": "22222222226",
  "tin": "",
  "nin": "24445678910",
  "address": "12, newton street, ikeja, lagos",
  "businessType": "RC",
  "state": "Lagos"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `rcNumber` | Mandatory | Company RC number. |
| `companyName` | Mandatory | Company name. |
| `incorporationDate` | Mandatory | Company incorporation date, e.g. `05 January 2021` (documented format). |
| `bvn` | Mandatory | BVN of one of the company's board of directors. |
| `nin` | Mandatory | NIN of one of the company's board of directors. |
| `tin` | Optional | Company Tax Identification Number. |
| `address` | Mandatory | Company address. |
| `businessType` | Mandatory | `RC` for limited liability companies (Ltd, PLC) or `BN` for sole proprietorships and partnerships. |
| `state` | Mandatory | State where the company is located. |

Success:

```json
{
  "status": "00",
  "message": "Successful Corporate Creation",
  "data": {
    "accountNo": "1000053589",
    "accountName": "Famous Technologies"
  }
}
```

Documented failures include `199` with `address is mandatory`, `incorporationNumber is mandatory`,
`bvn is mandatory`, `nin is mandatory`, `businessName is mandatory`, or
`incorporationDate is mandatory`; `01` `Client Account Exists`; `199` `Invalid Rc number: 000001`;
`199` `Invalid NIN: 1000000001`; `102` `Invalid BVN or Could Not Reach BVN Service`.

> **Observation:** the validation errors name `incorporationNumber` and `businessName`, while the
> sample request uses `rcNumber` and `companyName`. The documentation does not reconcile this.

**Duplicate corporate account** uses the same path with:

```json
{
  "previousAccountNo": "1001631690"
}
```

Success returns a new `accountNo` and `accountName`. The documented failures match the duplicate
individual failures (`119`, `929` invalid previous account, `929` account under review).

### 5.2 Corporate sub-account

**Path:** `/client/corporate/sub-account`
**Method:** `POST`

Two documented modes.

**Option 1 — branch account:**

```json
{
  "parentAccountNo": "1001631634",
  "branch": "Lekki"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `parentAccountNo` | Mandatory | Existing corporate client account. |
| `branch` | Mandatory | Branch name. |

The new account name is the parent company name plus the branch, e.g. `Roland Technologies-Lekki`.

**Option 2 — purpose account:**

```json
{
  "parentAccountNo": "1001631634",
  "type": "Settlement"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `parentAccountNo` | Mandatory | Existing corporate client account. |
| `type` | Mandatory | Purpose, e.g. `Settlement`, `Logistics`. |

The new account name is the parent company name plus the purpose, e.g.
`Roland Technologies-Settlement`.

Documented failures: `119` not authorized; `929` invalid parent account; `929` parent account must be
updated with BVN/NIN; `929` parent account under review.

### 5.3 Corporate test RC data

| RC Number | Company name | Business type |
| --- | --- | --- |
| 9889992 | Victory Technologies | RC |
| 9876555 | James Technologies | RC |
| 9876548 | APP Vest Ltd | RC |
| 9876543 | Famous Farms | RC |
| 9876522 | Chris Technologies | RC |
| 9876321 | Chris Farms | RC |
| 9876212 | Famous Technologies | RC |
| 9821543 | Kemi Technologies | RC |
| 9111998 | Dan gardens | RC |
| 3782902 | Sam gardens | RC |
| 2290991 | Ken gardens | RC |
| 0981771 | Zack Foods | RC |
| 0276543 | Dan Foods | RC |

---

## 6. Virtual accounts

### 6.1 Create a one-time temporary virtual account

**Path:** `/virtualaccount`
**Method:** `POST`

```json
{
  "amount": "5000",
  "merchantName": "Tunde merchant",
  "merchantId": "M0123444",
  "reference": "TundeWallet-212272727",
  "validityTime": "2400",
  "amountValidation": "A3"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `amount` | Mandatory | Amount to be paid into the account. |
| `merchantName` | Mandatory | Merchant name, e.g. customer's business name. |
| `merchantId` | Mandatory | Merchant's unique identifier. |
| `reference` | Mandatory | Unique transaction reference, prefixed with the wallet name. |
| `validityTime` | Optional | Account expiry in minutes. Default `4320`; maximum `4320`. |
| `amountValidation` | Optional | Funding-amount rule. Defaults to `A4` if not passed. |

`amountValidation` values:

| Value | Documented meaning |
| --- | --- |
| `A0` | Funded only with an amount **equal to** the amount specified at creation. |
| `A1` | Funded only with an amount **less than** the specified amount. |
| `A2` | Funded only with an amount **greater than** the specified amount. |
| `A3` | Funded only with an amount **equal to or less than** the specified amount. |
| `A4` | Funded only with an amount **equal to or greater than** the specified amount. |
| `A5` | Funded with **any** amount. |

Success:

```json
{
  "status": "00",
  "message": "Successful",
  "accountNumber": "4600070017",
  "reference": "TundeWallet-212272727"
}
```

Documented failures:

| Status | Message |
| --- | --- |
| `98` | `Reference Exist` |
| `01` | `ValidityTime must not be above 4320 minutes` |
| `01` | `Merchant Name is missing` |
| `01` | `Reference is missing` |

**Observation:** the success response places `accountNumber` and `reference` at the top level, not
inside `data`, unlike most other wallet endpoints.

### 6.2 Update virtual-account amount

**Path:** `/virtualaccount/amountupdate`
**Method:** `POST`

```json
{
  "amount": "5000",
  "reference": "TundeWallet-22222222223"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `amount` | Mandatory | Amount to update on the account. |
| `reference` | Mandatory | Unique reference used to create the virtual account. |

Success:

```json
{
  "status": "00",
  "message": "Amount updated successfully",
  "amount": "5000",
  "merchantAccountNo": "4600070017",
  "merchantId": "M0123444"
}
```

Failure:

```json
{
  "status": "01",
  "message": "Merchant account inactive"
}
```

---

## 7. KYC enquiry — BVN details, consent and account lookup

### 7.1 Get client by BVN

**Path:** `/client?bvn={bvn}`
**Method:** `GET`

| Query | Required | Description |
| --- | --- | --- |
| `bvn` | Documented as a query param | BVN to retrieve. The example uses `22222222229`. |

Success:

```json
{
  "status": "00",
  "message": "BVN Details Retrieved Successfully",
  "data": {
    "firstName": "DANIEL",
    "middleName": "MOSES",
    "lastName": "BABATUNDE",
    "gender": "Male",
    "dateOfBirth": "05-Oct-1988",
    "phoneNo": "09070658263",
    "pixBase64": ""
  }
}
```

Failure:

```json
{
  "status": "102",
  "message": "Invalid BVN or Could Not Reach BVN Service"
}
```

### 7.2 BVN consent

**Path:** `/bvn-consent?bvn={bvn}&type={type}&reference={reference}`
**Method:** `GET`

**Confirmed:** BVN account lookup requires consent first.

| Field | Required | Description |
| --- | --- | --- |
| `type` | Mandatory | Documented value `03`. |
| `bvn` | Mandatory | BVN, e.g. `22222222229`. |
| `reference` | Optional | Unique reference for the consent, maximum 250 characters. |

Consent given:

```json
{
  "status": "00",
  "message": "Consent response",
  "data": {
    "statusCode": "true",
    "reference": "595-22222222231-250927022024"
  }
}
```

Consent not given:

```json
{
  "status": "00",
  "message": "Consent response",
  "data": {
    "statusCode": "false",
    "url": "https://services.vfdtech.ng/",
    "reference": "595-22222222231-250927022024"
  }
}
```

If consent is not given, the documentation instructs the integrator to send the customer to the
returned URL to initiate the consent request.

Test BVNs/OTPs named for this call: `22222222223`/`111111`, `22222222224`/`111112`,
`22222222229`/`111115`.

### 7.3 BVN account lookup

**Path:** `/bvn-account-lookup?bvn={bvn}`
**Method:** `GET`

Retrieves all bank accounts linked to a BVN. Test BVNs: `22222222223`, `22222222224`,
`22222222229`.

Success (documented example contains three accounts; full structure preserved):

```json
{
  "status": "00",
  "message": "Successful",
  "data": [
    {
      "accountname": "TEST NAME ONE",
      "accountnumber": "0001091234",
      "accountDesignation": "2",
      "accountstatus": "1",
      "accounttype": "2",
      "institution": "9",
      "branch": "0491",
      "accounttier": "0",
      "nipCode": "000004",
      "BankCode": "033",
      "BankName": "UBA Bank",
      "AccountDesignationName": "INDIVIDUAL",
      "AccountTypeName": "SAVINGS"
    },
    {
      "accountname": "TEST NAME TWO",
      "accountnumber": "3090091234",
      "accountDesignation": "2",
      "accountstatus": "1",
      "accounttype": "2",
      "institution": "10",
      "branch": "4671683",
      "accounttier": "0",
      "nipCode": "000016",
      "BankCode": "011",
      "BankName": "First Bank",
      "AccountDesignationName": "INDIVIDUAL",
      "AccountTypeName": "SAVINGS"
    },
    {
      "accountname": "TEST NAME THREE",
      "accountnumber": "6090091234",
      "accountDesignation": "2",
      "accountstatus": "1",
      "accounttype": "2",
      "institution": "6",
      "branch": "0691",
      "accounttier": "0",
      "nipCode": "000007",
      "BankCode": "070",
      "BankName": "Fidelity Bank",
      "AccountDesignationName": "INDIVIDUAL",
      "AccountTypeName": "SAVINGS"
    }
  ]
}
```

### 7.4 List sub-accounts by entity

**Path:** `/sub-accounts?entity={entity}&size={size}&page={page}`
**Method:** `GET`

| Query | Required | Description |
| --- | --- | --- |
| `entity` | Mandatory | `virtual`, `individual`, or `corporate`. |
| `page` | Mandatory | Page number, starts at `0`. |
| `size` | Mandatory | Page size. |

Success:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "content": [
      {
        "lastName": "PETERSON",
        "phone": "Tes109019056926",
        "firstName": "TestWalletSteve",
        "createdDate": "2023-06-08 16:21:40.0",
        "clientId": "140009",
        "bvn": "Test122222222244",
        "accountNo": "1000000000"
      },
      {
        "lastName": "ABAH",
        "phone": "Tes09019056916",
        "firstName": "TestWalletSUNDAY",
        "createdDate": "2023-06-08 16:20:10.0",
        "clientId": "141000",
        "bvn": "Test122222222245",
        "accountNo": "1000000020"
      }
    ],
    "totalElements": 2,
    "totalPages": 1
  }
}
```

Failure:

```json
{
  "status": "500",
  "message": "Internal Server Error"
}
```

---

## 8. Account and beneficiary enquiry

### 8.1 Account/source enquiry

**Path:** `/account/enquiry?accountNumber={accountNumber}`
**Method:** `GET`

Returns the transfer sender's account details. When `accountNumber` is omitted, the pool account
details are returned.

| Query | Required | Description |
| --- | --- | --- |
| `accountNumber` | Optional | Customer's account number. |

Without account number:

```json
{
  "status": "00",
  "message": "Account Details",
  "data": {
    "accountNo": "1001554791",
    "accountBalance": "14764178.880000",
    "accountId": "155479",
    "client": "Kemi Sema",
    "clientId": "138421",
    "savingsProductName": "Corporate Current Account"
  }
}
```

With account number:

```json
{
  "status": "00",
  "message": "Account Details",
  "data": {
    "accountNo": "1001547795",
    "accountBalance": "0.000000",
    "accountId": "154779",
    "client": "ANNA OGECHI ABEL",
    "clientId": "5613",
    "savingsProductName": "Corporate Current Account"
  }
}
```

**Observation:** the transfer section says `fromBvn` can be obtained from pointer `(a) bvn`, but the
documented account-enquiry response has no `bvn` field. The sample transfer payload contains a
`fromBvn` value. The documentation does not explain the gap.

### 8.2 Beneficiary/recipient enquiry

**Path:** `/transfer/recipient?accountNo={accountNo}&bank={bank}&transfer_type={transfer_type}`
**Method:** `GET`

| Query | Required | Description |
| --- | --- | --- |
| `accountNo` | Mandatory | Customer's account number. |
| `bank` | Mandatory | Customer's bank code. |
| `transfer_type` | Mandatory | Transfer type. The page does not enumerate values here; the transfer payload uses `intra`/`inter`. |

Success:

```json
{
  "status": "00",
  "message": "Account Found",
  "data": {
    "name": "Kuti Sema",
    "clientId": "138421",
    "bvn": "22887650012",
    "account": {
      "number": "1001554818",
      "id": "155481"
    },
    "status": "active",
    "currency": "NGN",
    "bank": "VFD Microfinance Bank"
  }
}
```

Failures:

```json
{ "status": "104", "message": "Account Not Found" }
```

```json
{ "status": "500", "message": "Internal Server Error" }
```

### 8.3 Bank list

**Path:** `/bank`
**Method:** `GET`

**Confirmed description:** fetches the list of all Nigerian banks and bank codes.

> **Not documented:** no query parameters, response example, field list or error example is published
> for this endpoint. The bank codes also appear in the Debit Mandates page; see
> [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md) §11.

---

## 9. Transfers

### 9.1 How to make a transfer

The documented flow:

1. Call `/account/enquiry` to get the **from** details.
2. Call `/bank` to get bank codes.
3. Call `/transfer/recipient` to get the **to** (beneficiary) details.
4. Generate the signature as `SHA512(fromAccount + toAccount)` — the accounts concatenated together.
5. POST the transfer payload.

**Vendor warning:** the `signature` field is documented as “Contact admin”. The page does not publish
the shared secret, encoding (hex/base64), or key-management procedure. See
[VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md).

### 9.2 Single transfer

**Path:** `/transfer`
**Method:** `POST`

```json
{
  "fromAccount": "1001561522",
  "uniqueSenderAccountId": "",
  "fromClientId": "139213",
  "fromClient": "RolandPay-Roland Bright Doe",
  "fromSavingsId": "156152",
  "fromBvn": "Rolandpay-birght 221552585559",
  "toClientId": "139214",
  "toClient": "RolandPay-Roland Bright Doe",
  "toSavingsId": "156153",
  "toSession": "",
  "toBvn": "11111111111",
  "toAccount": "1001561539",
  "toBank": "999999",
  "signature": "899358f98ae041aa7471bdc03797b1f64c6f96a542955023849d2dbddb1cf7318d8599e9692b1345b8383288dc8550ed70f1de6aa2ea6a149f48d515c9e6eb1e",
  "amount": "1006765",
  "remark": "trf download",
  "transferType": "intra",
  "reference": "TestWallet-fhehfhgdrtrewe"
}
```

| Field | Required | Description | Source pointer |
| --- | --- | --- | --- |
| `fromAccount` | Mandatory | Account number to initiate disbursement from. | `(a) accountNo` |
| `fromClientId` | Mandatory | Client ID of the source account. | `(a) clientId` |
| `fromClient` | Mandatory | Client name of the source account. | `(a) client` |
| `fromSavingsId` | Mandatory | Savings ID of the source account. | `(a) accountId` |
| `uniqueSenderAccountId` | Optional | Savings ID of the customer's account initiating the disbursement. Required only in POOL when a sub-account sends funds and the receiving bank/recipient should see the exact sender. Obtained by account enquiry on the actual sender. | `(a) accountId` |
| `fromBvn` | If present, should be passed | BVN of the source account. | `(a) bvn` |
| `toClientId` | Mandatory (intra) | Beneficiary client ID. | `(b) clientId` |
| `toClient` | Mandatory | Beneficiary client name. | `(b) name` |
| `toSavingsId` | Mandatory (intra) | Beneficiary savings ID. | `(b) account.id` |
| `toSession` | Mandatory (inter) | Beneficiary session ID. | `(b) account.id` |
| `toBvn` | If present, should be passed | Beneficiary BVN. | `(b) bvn` |
| `toAccount` | Mandatory | Beneficiary account number. | `(b) account.number` |
| `toBank` | Mandatory | Beneficiary bank code from bank list. | — |
| `signature` | Mandatory | Signature; documentation says “Contact admin”. | — |
| `amount` | Mandatory | Transaction amount. | — |
| `remark` | Mandatory | Transaction remark/customer narration. | — |
| `transferType` | Mandatory | `intra` (VFD-to-VFD) or `inter` (VFD-to-other bank). | — |
| `reference` | Mandatory | Unique random string prefixed with the wallet name, e.g. `TestWallet-AWW3WDIUWU4U`. | — |

Success (inter):

```json
{
  "status": "00",
  "message": "Successful Transfer",
  "data": {
    "txnId": "TestWallet-AWW3WDIUWU4U",
    "sessionId": "090110220420225737701409365803",
    "reference": "1650491857685"
  }
}
```

Success (intra):

```json
{
  "status": "00",
  "message": "Successful Transfer",
  "data": {
    "txnId": "TestWallet-AWW3WDIUWU4U"
  }
}
```

Documented failures:

| Status | Message | Meaning |
| --- | --- | --- |
| `99` | `Failed Transaction` | Incorrect payload or source account on PND (Post No Debit). |
| `02` | `Signature Mismatch` | Incorrect signature. |
| `99` | `Invalid source account` | `fromSavingsId` does not match the `accountId` from `/account/enquiry`. |
| `99` | `Invalid source` | POOL: source is not the pool account. 1-1: source does not belong to the wallet. |
| `98` | `Invalid uniqueSenderAccountId` | Wrong savings ID, an account not created by the wallet, or the pool account's savings ID. |
| `99` | `Invalid transfer type` | Unsupported transfer type. |
| `98` | `Transaction Exist` | Reference already used. |

### 9.3 Bulk transfer

**Path:** `/bulk/transfer`
**Method:** `POST`

The request is a JSON **array** of transfer objects, each with the same fields as a single transfer.
The documented example repeats three objects with different `amount`/`reference` values. One object is
reproduced below; the array wrapper is the important structural difference.

```json
[
  {
    "fromSavingsId": "157448",
    "amount": "33400",
    "uniqueSenderAccountId": "",
    "toAccount": "1081696143",
    "signature": "xxxx",
    "fromAccount": "1001574489",
    "toBvn": "rosapay-222222",
    "remark": "test",
    "fromClientId": "140455",
    "fromClient": "John doe",
    "toKyc": "",
    "reference": "txn-gtxia7pmz5dsdds444g5ducy5gxprd",
    "toClientId": "154799",
    "toClient": "Rosapay-Phil Bull Holden",
    "toSession": "",
    "transferType": "intra",
    "toBank": "999999",
    "toSavingsId": "169614"
  }
]
```

Response:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "createdAt": "2026-07-31T12:46:23.766716",
    "batchId": "bd6b4ca2-432e-486d-a6f3-a7bd837f231e",
    "totalCount": 4,
    "status": "PROCESSING"
  }
}
```

**Observation:** the documented response says `totalCount: 4` although the sample array shows three
objects. Treat the count as echoed by the batch engine, not as a guarantee about the sample.

### 9.4 Bulk transfer enquiry

**Path:** `/bulk/transfers?batchId={batchId}`
**Method:** `GET`

| Query | Required | Description |
| --- | --- | --- |
| `batchId` | Mandatory | Transaction batch ID. |

Response (documented example has three records; one reproduced):

```json
{
  "status": "00",
  "message": "Transactions retrieved successfully",
  "data": [
    {
      "batchId": "bd91c058-c347-412b-b559-e859b3230b73",
      "reference": "TestWallet-8909203902",
      "fromAccount": "1001561522",
      "uniqueSenderAccountId": null,
      "fromClientId": "139213",
      "fromClient": "RolandPay-Roland Bright Doe",
      "fromSavingsId": "156152",
      "fromBvn": "Rolandpay-birght 221552585559",
      "toClientId": "139214",
      "toClient": "RolandPay-Roland Bright Doe",
      "toSavingsId": "156153",
      "toSession": "",
      "toBvn": "11111111111",
      "toAccount": "1001561539",
      "toBank": "999999",
      "amount": 1006765.00,
      "remark": "trf groceries",
      "signature": null,
      "transferType": "intra",
      "processState": "UNKNOWN",
      "transactionStatus": null,
      "createdAt": "2026-07-29T08:48:07",
      "updatedAt": null
    }
  ]
}
```

Documented `processState` values seen: `UNKNOWN`, `PROCESSED`. No enumeration is published.

### 9.5 Transfer status query (TSQ)

**Paths (documented):**

- `/transactions?reference={reference}`
- `/transactions?sessionId={sessionId}`

**Method:** `GET`

| Query | Required | Description |
| --- | --- | --- |
| `reference` | Optional, but one identifier is required | Transaction unique reference. |
| `sessionId` | Optional, but one identifier is required | Transaction unique session ID. |

Success:

```json
{
  "status": "00",
  "message": "Successful Transaction Retrieval",
  "data": {
    "TxnId": "TestWallet-1019101019100993",
    "amount": "500000.00",
    "accountNo": "1000058012",
    "fromAccountNo": "1000075901",
    "transactionStatus": "99",
    "transactionDate": "2023-01-11 08:05:25.0",
    "toBank": "999999",
    "fromBank": "999999",
    "sessionId": "",
    "bankTransactionId": "",
    "transactionType": "OUTFLOW"
  }
}
```

**Vendor note:** work with the `transactionStatus` field to confirm the transaction's current status.

Failures:

```json
{ "status": "108", "message": "No Transaction!" }
```

```json
{ "status": "199", "message": "TransactionId or SessionId Is Mandatory" }
```

> **Observation:** the query-parameter names in the path are `reference` and `sessionId`; the error
> message says `TransactionId or SessionId`. The documented TSQ response uses `TxnId`.

### 9.6 Transaction reversal status query (TRSQ)

**Path:** `/transactions/reversal?reference={reference}`
**Method:** `GET`

| Query | Required | Description |
| --- | --- | --- |
| `reference` | Mandatory | Transaction unique reference. |

Success:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "amount": "500",
    "reversalStatus": "00",
    "reversalDate": "2026-03-11 15:23:12",
    "reversalId": "2802306",
    "sessionId": "090110230930134752962090709204"
  }
}
```

Failures:

```json
{ "status": "404", "message": "Reversal Not Found" }
```

```json
{ "status": "199", "message": "Reference is Mandatory" }
```

```json
{ "status": "500", "message": "Internal Server Error" }
```

### 9.7 Transfer test accounts

**Confirmed:**

- Inter transfer: `accountNo = 1111111103`, `bank = 000002`.
- Intra transfer: `accountNo = 1000074944`, `bank = 999999`.

These are for retrieving transfer-recipient details in the test environment.

### 9.8 Transfer webhook

Documented events: `payout.success` and `payout.failed`, delivered as HTTP POST. Full payloads are in
[VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) §5.

---

## 10. Simulated inbound credit (test only)

**Path:** `/credit`
**Method:** `POST`

**Description:** simulates an inflow in the development environment. It is not documented as a
production operation.

```json
{
  "amount": "8000",
  "accountNo": "1003500000",
  "senderAccountNo": "5050104057",
  "senderBank": "999070",
  "senderNarration": "Test credit"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `amount` | Mandatory | Amount to fund. |
| `accountNo` | Mandatory | Account number to receive funding. |
| `senderAccountNo` | Mandatory | Sender account number. |
| `senderBank` | Mandatory | Sender bank code. |
| `senderNarration` | Mandatory | Sender narration. |

Vendor note: for `senderAccountNo` and `senderBank`, `5050104070` and `000002` may be used
respectively.

Success:

```json
{
  "status": "00",
  "message": "Successfully notified"
}
```

**Observation:** the sample request uses `5050104057`/`999070`, while the note recommends
`5050104070`/`000002`. Both are vendor-published; verify in sandbox.

---

## 11. Transaction history

### 11.1 Account transactions

**Path:** `/account/transactions`
**Method:** `GET`

Full documented query string:

`/account/transactions?accountNo={accountNo}&startDate={startDate}&endDate={endDate}&page=0&size=20&transactionType={transactionType}`

| Query | Required | Description |
| --- | --- | --- |
| `accountNo` | Mandatory | Customer's account number. |
| `startDate` | Mandatory | Start date, e.g. `2023-01-01 00:00:00`. |
| `endDate` | Mandatory | End date, e.g. `2023-03-01 23:59:59`. |
| `transactionType` | Mandatory | `wallet` for wallet-based transactions; `Bank` for a bank statement. |
| `page` | Optional | Page number, starts at `0`. |
| `size` | Optional | Page size. |

The endpoint returns transactions for the merchant's pool account, transit accounts, virtual accounts,
or sub-accounts.

Response when `transactionType = Bank`:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "content": [
      {
        "accountNo": "1001555750",
        "receiptNumber": "090110230522074319965480267793",
        "amount": "20.000000",
        "remarks": "Inward Credit Charge with reference: rosapay-20230522064320488",
        "createdDate": "2023-11-30 06:43:23.0",
        "transactionType": "DEBIT",
        "runningBalance": "1074467.000000",
        "currencyCode": "NGN",
        "id": "2603203"
      },
      {
        "remarks": "Funds Withdrawal For - rosapay-/trf download",
        "receiptNumber": "090110230518144841059905192360",
        "amount": "100.000000",
        "accountNo": "1001555750",
        "createdDate": "2023-11-29 16:53:50.0",
        "transactionType": "DEBIT",
        "runningBalance": "1074487.000000",
        "currencyCode": "NGN",
        "id": "2603203"
      },
      {
        "remarks": "Rosapay/trf/John_Doe",
        "receiptNumber": "090110230313215606726102172204",
        "amount": "400.000000",
        "accountNo": "1001555750",
        "createdDate": "2023-10-22 18:57:09.0",
        "transactionType": "CREDIT",
        "runningBalance": "1074587.000000",
        "currencyCode": "NGN",
        "id": "2603203"
      }
    ],
    "totalElements": 3,
    "totalPages": 1
  }
}
```

Response when `transactionType = Wallet`:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "content": [
      {
        "time": "2023-11-12 15:59:43.0",
        "transactionType": "OUTFLOW",
        "transactionId": "testing281",
        "walletName": "Victory",
        "amount": "80.00",
        "toAccountNo": "1111111106",
        "transactionResponse": "00",
        "fromBank": "999999",
        "fromAccountNo": "1001558751",
        "toBank": "000001",
        "sessionId": "090110231112165943586797955171"
      },
      {
        "time": "2023-11-11 14:55:00.0",
        "transactionType": "OUTFLOW",
        "transactionId": "testing280",
        "walletName": "Victory",
        "amount": "80.00",
        "toAccountNo": "1111111106",
        "transactionResponse": "00",
        "fromBank": "999999",
        "fromAccountNo": "1001558751",
        "toBank": "000001",
        "sessionId": "090110231111155500317071230464"
      }
    ],
    "totalElements": 69,
    "totalPages": 35
  }
}
```

**Observation:** the documented bank example repeats `id: "2603203"` across three different
transactions. Do not treat `id` as a unique transaction key without sandbox confirmation.

### 11.2 Virtual-account transactions

**Path:** `/virtualaccount/transactions`
**Method:** `GET`

Full documented query string:

`/virtualaccount/transactions?accountNumber={accountNumber}&startDate={startDate}&endDate={endDate}&page={page}&size={size}`

| Query | Required | Description |
| --- | --- | --- |
| `accountNumber` | Mandatory | Virtual account number. |
| `startDate` | Mandatory | Start date, e.g. `2022-01-01 00:00:00`. |
| `endDate` | Mandatory | End date, e.g. `2023-01-01 23:59:59`. |
| `page` | Optional | Page number, starts at `0`. |
| `size` | Optional | Page size. |

Success:

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "content": [
      {
        "reference": "rosapay-000917",
        "dateCreated": "2023-10-31 13:39:05.0",
        "merchantAccountNo": "6007026895",
        "merchantAccountName": "DSTV",
        "accountStatus": "09",
        "amount": "2000",
        "expired": "false",
        "amountValidation": "A3"
      }
    ],
    "totalElements": 1,
    "totalPages": 1
  }
}
```

---

## 12. QR code services

### 12.1 Generate QR code

**Path:** `/qrcode/generate`
**Method:** `POST`

```json
{
  "accountNo": "1001563612",
  "qrType": "2",
  "amount": "9000",
  "phone": "08135542267",
  "email": "shileroland@gmail.com"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `accountNo` | Mandatory | Test account number of merchant. |
| `qrType` | Mandatory | `1` = fixed, `2` = dynamic. |
| `amount` | Mandatory | Test amount to be sent. |
| `phone` | Mandatory | Test phone number. |
| `email` | Mandatory | Test email address. |

Success:

```json
{
  "status": "00",
  "message": "QRCode created successfully",
  "data": {
    "qrCode": "09875R12344554**99944T4T166**5747574****PKG000000090726720019NG.COM.NIBSS-PLC.QR0222S000000066302309665405200005802NG5916MUHAMMEDALEXIS6007Nigeria7304FB00"
  }
}
```

### 12.2 Query QR code

**Path:** `qrcode/query` (as printed; likely `/qrcode/query`, but the leading slash is missing in the
vendor text)
**Method:** `POST`

```json
{
  "qrCode": "09875R12344554**99944T4T166**5747574****PKG000000090726720019NG.COM.NIBSS-PLC.QR0222S000000066302309665405200005802NG5916MUHAMMEDALEXIS6007Nigeria7304FB00"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `qrCode` | Mandatory | QR code string. |

> **Not documented:** no sample response or error response is shown for QR query.

### 12.3 Pay with QR code

**Path:** `/qrcode/pay`
**Method:** `POST`

```json
{
  "amount": "9000",
  "merchantNo": "1002345667",
  "subMerchantNo": "",
  "subMerchantName": "",
  "qrType": "2",
  "orderSn": "",
  "signature": ""
}
```

| Field | Required | Description |
| --- | --- | --- |
| `amount` | Mandatory | Amount to be sent. |
| `merchantNo` | Mandatory | Merchant account number. |
| `subMerchantNo` | Mandatory | Sub-merchant account number. |
| `subMerchantName` | Mandatory | Sub-merchant name. |
| `qrType` | Mandatory | `1` = fixed, `2` = dynamic. |
| `orderSn` | Optional | Serial number. |
| `signature` | Mandatory | “To be given by admin.” |

> **Not documented:** no sample response or error response is shown for QR pay.

---

## 13. Account upgrade and remediation

**Path:** `/client/upgrade`
**Method:** `POST`

This endpoint performs three documented actions, selected by the `action` field.

### 13.1 Update account using BVN/NIN details

**Action:** `Update-BVN`

Verifies the existing account against BVN information and, on success, removes the account from PND
status.

```json
{
  "accountNo": "1000000000",
  "bvn": "20000000009",
  "action": "Update-BVN"
}
```

or

```json
{
  "accountNo": "1000000000",
  "nin": "20000000009",
  "action": "Update-BVN"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `accountNo` | Mandatory | Customer account number. |
| `bvn` | Mandatory (one of BVN/NIN) | Customer BVN. |
| `nin` | Mandatory (one of BVN/NIN) | Customer NIN. |
| `action` | Mandatory | `Update-BVN`. |

Response:

```json
{
  "status": "00",
  "message": "Account updated successfully"
}
```

### 13.2 Update account compliance

**Action:** `Recomply-With-BVN`

Regularizes the account against BVN details and releases it from PND on success.

```json
{
  "accountNo": "1000000000",
  "bvn": "20000000009",
  "dob": "08-Mar-1995",
  "action": "Recomply-With-BVN"
}
```

or with `nin` instead of `bvn`.

| Field | Required | Description |
| --- | --- | --- |
| `accountNo` | Mandatory | Customer account number. |
| `bvn` / `nin` | Mandatory (one of) | BVN or NIN. |
| `dob` | Mandatory | Date of birth on BVN or NIN. |
| `action` | Mandatory | `Recomply-With-BVN`. |

Response is the same success envelope.

### 13.3 Convert individual account to corporate

**Action:** `Convert-To-Corporate`

```json
{
  "accountNo": "1000000000",
  "companyName": "Rita and friends",
  "incorporationDate": "12-Oct-2007",
  "rcNumber": "123456",
  "action": "Convert-To-Corporate"
}
```

| Field | Required | Description |
| --- | --- | --- |
| `accountNo` | Mandatory | Customer account number. |
| `companyName` | Mandatory | Company name. |
| `incorporationDate` | Mandatory | Incorporation date, e.g. `12-Oct-2007`. |
| `rcNumber` | Mandatory | Company RC number. |
| `action` | Mandatory | `Convert-To-Corporate`. |

Response is the same success envelope.

> **Observation:** `Update-BVN` and `Recomply-With-BVN` are the action names shown. The section title
> says “using BVN details” but both BVN and NIN are accepted. No failure examples are published for
> this endpoint.

---

## 14. Lux POS helper endpoints

These two endpoints are documented on the wallet page under “Lux POS”. Product-level POS context is in
[VFD_POS_INFRASTRUCTURE.md](VFD_POS_INFRASTRUCTURE.md).

### 14.1 Webhook repush

**Path:** `/transactions/repush`
**Method:** `POST`

Retriggers Lux webhook notifications for successful and failed POS transactions.

```json
{
  "reference": "408210-P051200150941-2057JVSC-012804578357",
  "transactionType": "card-payment",
  "pushIdentifier": "reference"
}
```

| Field | Required | Description | Note |
| --- | --- | --- | --- |
| `reference` | Mandatory | Unique Lux-generated transaction reference. | Must match the original transaction. |
| `transactionType` | Mandatory | Type of transaction. | Static value `card-payment`. |
| `pushIdentifier` | Mandatory | Identifier for the repush. | Static value `reference`. |

Success:

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

Webhook not reachable: same envelope with `transactionStatus: "01"`.

Invalid transaction:

```json
{ "status": "99", "message": "Invalid transaction" }
```

Missing push identifier:

```json
{ "status": "99", "message": "transactionId is mandatory" }
```

### 14.2 Lux POS transaction status query

**Path:** `/transactions?transactionType={type}&reference={reference}`
**Method:** `GET`

| Query | Required | Description | Example |
| --- | --- | --- | --- |
| `transactionType` | Mandatory | Type of transaction. | `card-payment` |
| `reference` | Mandatory | Unique Lux-generated reference. | `450035-P051200150941-2057JVSC-751706450035` |

Success:

```json
{
  "status": "00",
  "message": "Successful Transaction Retrieval",
  "data": {
    "reference": "450035-P051200150941-2057JVSC-751706450035",
    "rrn": "751706450035",
    "transactionId": "LUX-20250705100740920-751706450035",
    "statusCode": "00",
    "amount": "0.01",
    "transactionType": "card",
    "transactionTime": "2025-07-05 09:07:40.0",
    "terminalId": "2057JVSC",
    "settledAmount": "0.01",
    "statusDescription": "Approved"
  }
}
```

Unsettled/failed:

```json
{
  "status": "00",
  "message": "Successful Transaction Retrieval",
  "data": {
    "reference": "837188-P051200150941-2057JVSC-881738996157",
    "rrn": "881738996157",
    "transactionId": "LUX-20250705081732019-881738996157",
    "statusCode": "25",
    "amount": "0.01",
    "transactionType": "card",
    "transactionTime": "2025-07-05 07:17:32.0",
    "terminalId": "2057JVSC",
    "settledAmount": "",
    "statusDescription": "Unable To Locate Record"
  }
}
```

No transaction:

```json
{ "status": "108", "message": "No Transaction!" }
```

**Observation:** this TSQ path collides with the wallet TSQ path (`/transactions`) but uses different
query parameters. A path-only router would confuse them; the product context must be explicit.

---

## 15. Transfer response codes

The page publishes a transfer-specific code table with categories and reversal instructions.

| Code | Description | Category | Reversal instruction | TSQ required |
| --- | --- | --- | --- | --- |
| 00 | Approved or Completed Successfully | SUCCESSFUL | No Reversal | No |
| 01 | Status Unknown, Please wait for Settlement Report | PENDING | No Reversal | Yes |
| 02 | Status Unknown, Please wait for Settlement Report | PENDING | No Reversal | Yes |
| 03 | Invalid Sender | FAILED | Reversal | No |
| 05 | Do not Honor | FAILED | Reversal | No |
| 06 | Dormant Account | FAILED | Reversal | No |
| 07 | Invalid Account | FAILED | Reversal | No |
| 08 | Account Name Mismatch | FAILED | Reversal | No |
| 09 | Request Processing in Progress | PENDING | No Reversal | Yes |
| 12 | Invalid Transaction | FAILED | Reversal | No |
| 13 | Invalid Amount | FAILED | Reversal | No |
| 14 | Invalid Batch Number | FAILED | Reversal | No |
| 15 | Invalid Session or Record ID | FAILED | Reversal | No |
| 16 | Unknown Bank Code | FAILED | Reversal | No |
| 17 | Invalid Channel | FAILED | Reversal | No |
| 18 | Wrong Method Call | FAILED | Reversal | No |
| 21 | Failed with reversal | FAILED | Reversal | No |
| 25 | Unable to Locate Record | PENDING | No Reversal | Yes |
| 26 | Successful | SUCCESSFUL | No Reversal | No |
| 30 | Format Error | FAILED | Reversal | No |
| 34 | Suspected Fraud | FAILED | No Reversal | No |
| 35 | Contact Sending Bank | FAILED | No Reversal | No |
| 51 | No Sufficient Funds | FAILED | No Debit | No |
| 57 | Transaction not Permitted to Sender | FAILED | Reversal | No |
| 58 | Transaction not Permitted on Channel | FAILED | Reversal | No |
| 61 | Transaction Limit Exceeded | FAILED | Reversal | No |
| 63 | Security Violation | FAILED | No Reversal | No |
| 65 | Exceeds Withdrawal Frequency | FAILED | Reversal | No |
| 68 | Response Received Too Late | FAILED | Reversal | No |
| 69 | Unsuccessful Account/Amount Block | FAILED | Reversal | No |
| 70 | Unsuccessful Account/Amount Block | FAILED | Reversal | No |
| 71 | Empty Mandate Reference Number | FAILED | Reversal | No |
| 81 | Transaction Failed | FAILED | Reversal | No |
| 91 | Beneficiary Bank Not Available | FAILED | Reversal | Yes |
| 92 | Routing Error | FAILED | Reversal | No |
| 94 | Duplicate Transaction | PENDING | No Reversal | Yes |
| 96 | System Malfunction | PENDING | No Reversal | Yes |
| 97 | Timeout Waiting for response from Destination | FAILED | Reversal | No |
| 98 | Transaction Exists | FAILED | No Debit | Yes |
| 99 | Transaction Failed | FAILED | No Debit | No |
| 500 | Internal server error | PENDING | No Reversal | Yes |
| null | Failed with reversal | FAILED | Reversal | Yes |

**Vendor handling guide (paraphrased only where the vendor is explicit):**

- FAILED → run TSQ to confirm; if confirmed failed or a failure response is returned, treat as failed.
- PENDING → keep running TSQ until SUCCESS or FAILED.
- Still pending after 24 hours → contact support with transaction details.
- SUCCESS (directly or via TSQ) → treat as successful (credit/fulfil).
- Other/undocumented errors → run TSQ to confirm actual status.
- Still unclear → share details with support.

> **Observation:** `null` is listed as a code. That is a data-quality issue in the source, not a code
> to implement literally.

---

## 16. Test data published by VFD

### 16.1 BVN bio-data

| BVN | OTP | BVN first name | BVN last name | BVN middle name | NIN | BVN DOB |
| --- | --- | --- | --- | --- | --- | --- |
| 22222222252 | 111162 | Phil | Holden | Bull | 23230042941 | 05-Apr-1994 |
| 22222222253 | 111161 | Golaith | David | Chesnut | 01947597293 | 05-Apr-1994 |
| 22222222254 | 111150 | Abdul | Ibrahim | Adesanya | 10392320193 | 05-Apr-1994 |
| 22222222255 | 111159 | Bobby | Tamil | Brown | 22310291001 | 05-Apr-1994 |
| 22222222256 | 111158 | Tom | Boderick | Phinea | 64797232424 | 05-Apr-1994 |
| 22222222257 | 111157 | Victory | Tim | Bucketson | 89475355532 | 05-Apr-1994 |
| 22222222258 | 111156 | Jamey | Combs | Jules | 55385399222 | 05-Apr-1994 |
| 22222222259 | 111155 | Teasy | Theresa | Plankton | 10929832955 | 05-Apr-1994 |
| 22222222260 | 111141 | Speed | Combell | Phils | 00929281923 | 05-Apr-1994 |
| 22222222261 | 111142 | Derick | Okeke | Charles | 23448292110 | 05-Apr-1994 |
| 22222222263 | 111145 | Golden | Tim | Rice | 11380234201 | 05-Apr-1994 |
| 22222222264 | 111143 | James | Raul | Steve | 74353922112 | 05-Apr-1994 |
| 22222222265 | 111136 | John | Raul | Tamas | 12193230212 | 05-Apr-1994 |
| 22222222266 | 111230 | Chris | Raul | Rock | 11392032221 | 05-Apr-1994 |
| 22222222267 | 111231 | Jeremy | Raul | Tamas | 90009123223 | 05-Apr-1994 |
| 22222222268 | 111232 | Peter | Raul | Tamas | 91192022012 | 05-Apr-1994 |
| 22222222269 | 111233 | Ade | Raul | Josh | 48439022212 | 05-Apr-1994 |
| 22222222270 | 111234 | Dan | Raul | Tamas | 23747281332 | 05-Apr-1994 |
| 22222222271 | 111235 | Frank | Raul | Tamas | 94221118383 | 05-Apr-1994 |
| 22222222272 | 111236 | Sarah | Raul | Tamas | 38238229133 | 05-Apr-1994 |
| 22222222273 | 111237 | Jane | Raul | Tamas | 29324824921 | 05-Apr-1994 |
| 22222222274 | 111238 | Hope | Raul | Tamas | 11100000984 | 05-Apr-1994 |
| 22222222275 | 111239 | Zainab | Raul | Tamas | 84532222323 | 05-Apr-1994 |
| 22222222276 | 111240 | Rita | Raul | Tamas | 11384244321 | 05-Apr-1994 |
| 22222222277 | 111240 | Paul | Raul | Tamas | 48024824321 | 05-Apr-1994 |
| 22222222223 | 111111 | MARIUS | PETERSON | DOE | 22345678910 | 08-Mar-1995 |
| 22222222224 | 111112 | FEMI | UCHECHUKWU | ZACK | 23230049900 | 17-Mar-1989 |
| 22222222229 | 111115 | JAMES | Tunde | TERRY | 29995678910 | 01-Oct-1988 |
| 22222222239 | 111114 | SUNDAY | ABAH | OJIMAOJO | 22345678111 | 05-Apr-1994 |
| 22222222235 | 111124 | JAMES | TERRY | Tunde | 74353922112 | 01-Oct-1988 |
| 22222222225 | 111113 | SUSAN | UCHECHUKWU | DOE | 22225678910 | 01-Oct-1988 |
| 22222222227 | 111116 | CHRISTOPHER | CHINONYE | OGBA | 23335678910 | 05-Apr-1994 |
| 22222222230 | 111117 | Steve | DOE | PETERSON | 29995678910 | 08-Mar-1980 |
| 22222222226 | 111118 | DAN | — | DOE | 24445678910 | 20-May-1995 |

**Observation:** duplicate OTP `111240` appears for `22222222276` and `22222222277`; `22222222226`
has an empty middle name. These are vendor data, reproduced as published.

### 16.2 Other test data

- Corporate RC numbers: §5.3.
- Transfer test accounts: §9.7.
- Simulated credit sender: §10.
- Card test data: [VFD_CARD_PAYMENT.md](VFD_CARD_PAYMENT.md).
- Mandate test accounts: [VFD_DEBIT_MANDATES.md](VFD_DEBIT_MANDATES.md).

---

## 17. Webhooks on this page

The wallet page documents three webhook behaviours:

1. **Inward credit notification** — sent when funds are transferred and settled into a wallet account.
2. **Initial inward credit notification** — sent before settlement, only if requested/activated.
3. **Transfer/payout notification** — `payout.success` or `payout.failed`.

It also documents a **retrigger API** at `/transactions/repush`.

Full payloads, field descriptions and security notes are consolidated in
[VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) §3–§5.

---

## 18. Documentation gaps and ambiguities

| Item | Status | Detail |
| --- | --- | --- |
| Signature secret/algorithm details | **Not documented** | Only `SHA512(fromAccount ToAccount)` and “Contact admin” are stated. Encoding and key distribution are absent. |
| Bank-list response | **Not documented** | No sample or fields. |
| QR query/pay responses | **Not documented** | Request fields only. |
| BVN source for transfers | **Ambiguous** | Account-enquiry response has no `bvn`, but `fromBvn` points to it. |
| `toSession` pointer | **Ambiguous** | Documented as `(b) account.id`, the same pointer as `toSavingsId`. |
| Tier limits | **Partially documented** | Only daily withdrawal and max transaction figures are given; no balance cap, tier upgrade KYC matrix, or fee schedule. |
| Account model selection | **Not documented** | How POOL vs 1-1 is chosen or changed. |
| Rate limits / retries | **Not documented** | No guidance beyond TSQ polling. |
| Idempotency | **Partially documented** | References are required to be unique; duplicate-reference responses exist (`Transaction Exist`, `Reference Exist`), but no idempotency key or replay semantics. |
| `bank` endpoint | **Incomplete** | Description only. |
| Transfer status naming | **Inconsistent** | `TxnId` in response, `reference`/`sessionId` in query, “TransactionId” in an error. |
| Lux TSQ path collision | **Ambiguous** | Same `/transactions` path with different parameters. |
| Test/live parity | **Not guaranteed** | Several sandbox restrictions are documented. |

For cross-product ambiguity and security review, see
[VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md).
