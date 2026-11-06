# VFD Loans API

> **Source:** [Loans](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/loans-api)
> **Retrieved:** 6 November 2026. **Documentation only.**
>
> The vendor documents loan **creation/disbursement**, transaction status, repayment schedule and
> portfolio enquiry. It does not document a loan application, eligibility, underwriting, approval, or
> repayment-collection endpoint.

---

## 1. Authorization and base URL

**Authorization:** `AccessToken: {{token}}`. See [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md).

| Environment | Base URL |
| --- | --- |
| Test | `https://api-devapps.vfdbank.systems/vtech-credit/api/v2/credit` |
| Live | `https://api-apps.vfdbank.systems/vtech-credit/api/v2/credit` |

All paths below are relative to this base URL.

**Vendor note:** call the **onboarding endpoint first** in the test environment only, after receiving
the consumer key and consumer secret, to ensure the wallet is set up properly.

> **Missing specification:** the onboarding endpoint's path, method, payload and response are **not
> documented on this page**, and no link is provided. This must be obtained from PSL before sandbox
> testing.

**Vendor tip:** accounts created under another wallet cannot be accessed under another profile.

---

## 2. Documented flow

1. Create an account using the Wallet API (see [VFD_WALLET.md](VFD_WALLET.md)).
2. Call **Create and Disburse Loan** to disburse to a wallet account.
3. Call **Loan Transaction Status Query** to confirm disbursement, especially when the create call
   returns `09`.
4. Optionally call **Loan Repayment Schedule** for a successful disbursement.
5. Optionally call **Loan Portfolio** for details such as amount disbursed and account number.

---

## 3. Create and disburse loan

**Path:** `/loan/create-and-disburse`
**Method:** `POST`

**Description:** creates a loan and disburses it to an account.

### Sample request

```json
{
  "transactionId": "wallnetname-000192",
  "accountNo": "1001552106",
  "amount": 50000,
  "duration": 1,
  "durationType": "0"
}
```

### Request fields

| Field | Required | Description |
| --- | --- | --- |
| `transactionId` | Mandatory | Unique transaction reference, prefixed with the wallet name. |
| `accountNo` | Mandatory | Account to disburse to. |
| `amount` | Mandatory | Amount to disburse. |
| `duration` | Mandatory | Loan duration, e.g. `3`. |
| `durationType` | Optional | `0` days, `1` weeks, `2` months. If omitted, defaults to months. |

**Observation:** the sample uses numeric `amount` and `duration`, not strings. Other VFD products use
string amounts. The documentation does not state accepted numeric types or precision.

### Sample response

```json
{
  "status": "00",
  "message": "Loan account created and amount disbursed successfully into 1001552106",
  "data": {
    "loanAccountNumber": "2001552106"
  }
}
```

### Sample failure

```json
{
  "status": "401",
  "message": "Not permitted for Loans"
}
```

> **Observation:** `status: "401"` is a business status value in the JSON body; the documentation does
> not say whether the HTTP response is also `401`. Do not treat it as an HTTP status without
> confirmation.

---

## 4. Loan transaction status query

**Path:** `/loan/transactions?identification={identification}`
**Method:** `GET`

**Description:** verifies the status of a loan transaction.

| Query | Required | Description |
| --- | --- | --- |
| `identification` | Documented as a field | Loan transaction ID. The table does not explicitly say “mandatory”; the flow implies it. |

The flow says to call this when the create endpoint returns `09`.

### Sample response

```json
{
  "status": "00",
  "message": "Successful Transaction Retrieval",
  "data": {
    "reference": "OdTechWallet2-20101010",
    "accountNo": "1000000301",
    "loanAccountNo": "2000019320",
    "amount": "2000",
    "duration": "3",
    "disburseDate": "2023-07-12 15:00:10",
    "status": "00",
    "statusDescription": "Loan Disbursed Successfully"
  }
}
```

**Observation:** the query parameter is `identification`, while the response exposes `reference`. The
documentation does not state whether the value to pass is the create-call `transactionId`, the
`reference`, or the `loanAccountNo`.

---

## 5. Loan repayment schedule

**Path:** `/loan/repayment-schedule?identification={identification}`
**Method:** `GET`

**Authorization shown:** Bearer Token (`AccessToken` is used elsewhere; the page says “Bearer Token”
here).

**Description:** returns the detailed repayment schedule for a loan, including total principal
disbursed, total interest charged and total repayment expected.

| Query | Required | Description |
| --- | --- | --- |
| `identification` | Mandatory | Transaction unique reference. |

### Sample response

```json
{
  "status": "00",
  "message": "Repayment Schedule for rosapay-11111pqqp3",
  "data": {
    "repaymentSchedule": {
      "currency": {
        "code": "NGN",
        "name": "Nigerian Naira",
        "decimalPlaces": 2,
        "inMultiplesOf": 2,
        "nameCode": "currency.NGN",
        "displayLabel": "Nigerian Naira [NGN]"
      },
      "loanTermInDays": 91,
      "totalPrincipalDisbursed": 50000.00,
      "totalPrincipalExpected": 50000.00,
      "totalPrincipalPaid": 0.00,
      "totalInterestCharged": 1003.32,
      "totalFeeChargesCharged": 0.00,
      "totalPenaltyChargesCharged": 0.00,
      "totalWaived": 0.00,
      "totalWrittenOff": 0.00,
      "totalRepaymentExpected": 51003.32,
      "totalRepayment": 0.00,
      "totalPaidInAdvance": 0.00,
      "totalPaidLate": 0.00,
      "totalOutstanding": 51003.32,
      "totalOverdueInterest": 0.00,
      "periods": [
        {
          "dueDate": [2023, 12, 28],
          "principalDisbursed": 50000.000000,
          "principalLoanBalanceOutstanding": 50000.000000,
          "feeChargesDue": 0.000000,
          "feeChargesPaid": 0.000000,
          "totalOriginalDueForPeriod": 0.000000,
          "totalDueForPeriod": 0.000000,
          "totalPaidForPeriod": 0.000000,
          "totalActualCostOfLoanForPeriod": 0.000000
        },
        {
          "period": 1,
          "fromDate": [2023, 12, 28],
          "dueDate": [2024, 1, 28],
          "complete": false,
          "daysInPeriod": 31,
          "principalOriginalDue": 16501.000000,
          "principalDue": 16501.000000,
          "principalPaid": 0,
          "principalWrittenOff": 0,
          "principalOutstanding": 16501.000000,
          "principalLoanBalanceOutstanding": 33499.000000,
          "interestOriginalDue": 500.000000,
          "interestDue": 500.000000,
          "interestPaid": 0,
          "interestWaived": 0,
          "interestWrittenOff": 0,
          "interestOutstanding": 500.000000,
          "feeChargesDue": 0,
          "feeChargesPaid": 0,
          "feeChargesWaived": 0,
          "feeChargesWrittenOff": 0,
          "feeChargesOutstanding": 0,
          "penaltyChargesDue": 0,
          "penaltyChargesPaid": 0,
          "penaltyChargesWaived": 0,
          "penaltyChargesWrittenOff": 0,
          "penaltyChargesOutstanding": 0,
          "overdueInterest": 0,
          "totalOriginalDueForPeriod": 17001.000000,
          "totalDueForPeriod": 17001.000000,
          "totalPaidForPeriod": 0,
          "totalPaidInAdvanceForPeriod": 0,
          "totalPaidLateForPeriod": 0,
          "totalWaivedForPeriod": 0,
          "totalWrittenOffForPeriod": 0,
          "totalOutstandingForPeriod": 17001.000000,
          "totalOverdue": 17001.000000,
          "totalActualCostOfLoanForPeriod": 500.000000,
          "totalInstallmentAmountForPeriod": 17001.00
        },
        {
          "period": 2,
          "fromDate": [2024, 1, 28],
          "dueDate": [2024, 2, 28],
          "complete": false,
          "daysInPeriod": 31,
          "principalOriginalDue": 16666.010000,
          "principalDue": 16666.010000,
          "principalPaid": 0,
          "principalWrittenOff": 0,
          "principalOutstanding": 16666.010000,
          "principalLoanBalanceOutstanding": 16832.990000,
          "interestOriginalDue": 334.990000,
          "interestDue": 334.990000,
          "interestPaid": 0,
          "interestWaived": 0,
          "interestWrittenOff": 0,
          "interestOutstanding": 334.990000,
          "feeChargesDue": 0,
          "feeChargesPaid": 0,
          "feeChargesWaived": 0,
          "feeChargesWrittenOff": 0,
          "feeChargesOutstanding": 0,
          "penaltyChargesDue": 0,
          "penaltyChargesPaid": 0,
          "penaltyChargesWaived": 0,
          "penaltyChargesWrittenOff": 0,
          "penaltyChargesOutstanding": 0,
          "overdueInterest": 0,
          "totalOriginalDueForPeriod": 17001.000000,
          "totalDueForPeriod": 17001.000000,
          "totalPaidForPeriod": 0,
          "totalPaidInAdvanceForPeriod": 0,
          "totalPaidLateForPeriod": 0,
          "totalWaivedForPeriod": 0,
          "totalWrittenOffForPeriod": 0,
          "totalOutstandingForPeriod": 17001.000000,
          "totalOverdue": 17001.000000,
          "totalActualCostOfLoanForPeriod": 334.990000,
          "totalInstallmentAmountForPeriod": 17001.00
        },
        {
          "period": 3,
          "fromDate": [2024, 2, 28],
          "dueDate": [2024, 3, 28],
          "complete": false,
          "daysInPeriod": 29,
          "principalOriginalDue": 16832.990000,
          "principalDue": 16832.990000,
          "principalPaid": 0,
          "principalWrittenOff": 0,
          "principalOutstanding": 16832.990000,
          "principalLoanBalanceOutstanding": 0.000000,
          "interestOriginalDue": 168.330000,
          "interestDue": 168.330000,
          "interestPaid": 0,
          "interestWaived": 0,
          "interestWrittenOff": 0,
          "interestOutstanding": 168.330000,
          "feeChargesDue": 0,
          "feeChargesPaid": 0,
          "feeChargesWaived": 0,
          "feeChargesWrittenOff": 0,
          "feeChargesOutstanding": 0,
          "penaltyChargesDue": 0,
          "penaltyChargesPaid": 0,
          "penaltyChargesWaived": 0,
          "penaltyChargesWrittenOff": 0,
          "penaltyChargesOutstanding": 0,
          "overdueInterest": 0,
          "totalOriginalDueForPeriod": 17001.320000,
          "totalDueForPeriod": 17001.320000,
          "totalPaidForPeriod": 0,
          "totalPaidInAdvanceForPeriod": 0,
          "totalPaidLateForPeriod": 0,
          "totalWaivedForPeriod": 0,
          "totalWrittenOffForPeriod": 0,
          "totalOutstandingForPeriod": 17001.320000,
          "totalOverdue": 17001.320000,
          "totalActualCostOfLoanForPeriod": 168.330000,
          "totalInstallmentAmountForPeriod": 17001.32
        }
      ]
    }
  }
}
```

**Observation:** the first `periods` entry has no `period` number and represents disbursement. Do not
assume every array element is an instalment.

---

## 6. Loan portfolio

**Path:** `/loan/portfolio`
**Method:** `GET`

Full documented query string:

`/loan/portfolio?endDate={endDate}&startDate={startDate}&page={page}&size={size}&search={search}&filterBy={filterBy}`

**Description:** returns amount disbursed, account disbursed to, date disbursed, loan duration, duration
type, loan status, etc. for all loans or a specific loan.

### Query parameters

| Field | Required | Description |
| --- | --- | --- |
| `endDate` | Mandatory | End date, e.g. `2024-05-22 23:59:59`. |
| `startDate` | Mandatory | Start date, e.g. `2024-05-20 00:00:00`. |
| `size` | Optional | Page size. |
| `page` | Optional | Page number, starts at `0`. |
| `filterBy` | Optional | `amount`, `transactionId`, `status`, or `accountNo`. |
| `search` | Optional | The value for `filterBy`, e.g. `5000` when filtering by amount. |

**Vendor note:** pass `filterBy` and `search` only when returning a specific transaction/amount/
account/status.

### Sample response

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "content": [
      {
        "duration": "3",
        "disburseDate": "06 October 2023",
        "loanAccountNo": "1000090481",
        "clientName": "Dan Doe",
        "walletName": "rosapay",
        "transactionId": "rosapay-01HC2B8FHT0BYY6TYQCQT57GXN",
        "status": "00",
        "amount": "191000",
        "accountNo": "1001191458",
        "walletId": "100",
        "statusDescription": "Loan Disbursed Successfully",
        "interestFrequency": "Per month",
        "interest": "1.0",
        "durationType": "months"
      }
    ],
    "totalElements": 1,
    "totalPages": 1
  }
}
```

**Observation:** sample `loanAccountNo` in the portfolio (`1000090481`) has a different prefix from the
create response (`2001552106`). The documentation does not define the loan-account numbering scheme.

---

## 7. Missing and ambiguous specifications

| Item | Status |
| --- | --- |
| Onboarding endpoint | **Missing** — referenced but not documented |
| Loan application/eligibility/underwriting | **Not documented** |
| Loan approval/rejection | **Not documented** |
| Interest rate/fee configuration | **Not documented** — response exposes `interest`/`interestFrequency`, request does not |
| Loan repayment/collection endpoint | **Not documented** |
| Loan cancellation/closure | **Not documented** |
| Repayment schedule pagination | **Not documented** |
| `identification` value definition | **Ambiguous** — `transactionId`, `reference`, or `loanAccountNo` |
| Response-code catalogue | **Not documented** beyond `00`, `09` (pending context), `401` |
| HTTP status codes | **Not documented** |
| Webhooks | **None documented for loans** |
| Currency/multi-currency | Only NGN appears; no statement |
| Rate limits | **Not documented** |

For Hivorr relevance, see [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md).
