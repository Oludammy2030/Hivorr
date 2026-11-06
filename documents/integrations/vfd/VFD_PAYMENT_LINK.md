# VFD Payment Link API

> **Source:** [Payment Link](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/payment-link-api)
> **Retrieved:** 6 November 2026. **Documentation only.**
>
> The vendor describes this API as generating secure, shareable payment links, with merchant branding
> and time-bound links that support flexible amount validation.

---

## 1. Authorization and base URL

**Authorization:** `AccessToken: {{token}}`. See [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md).

| Environment | Base URL |
| --- | --- |
| Test | `https://api-devapps.vfdbank.systems/vtech-payment/api/v2/payments` |
| Live | `https://api-apps.vfdbank.systems/vtech-payment-link/api/v2/payments` |

**Confirmed:** the test and live paths differ (`vtech-payment` vs `vtech-payment-link`). Do not derive
the live URL by replacing only the host.

All paths below are relative to this base URL.

---

## 2. Documented flow

1. Call **Merchant Setup** to configure the merchant profile with name and logo.
2. Call **Generate Payment Link** with amount, description, reference and validity.
3. Share the returned `paymentLink` through any channel.
4. The customer completes payment on the link.
5. The merchant receives a notification when payment is completed.

**Observation:** step 5 is asserted in the flow, but the page does **not** document a webhook payload,
event name, signature, or delivery contract. See §5 and §7.

---

## 3. Merchant setup

**Path:** `/merchant/setup`
**Method:** `POST`

**Description:** sets up or updates merchant information (name, ID, logo). The logo is uploaded to
secure storage and displayed on the payment page for branding.

### Sample request

```json
{
  "merchantName": "MyStore Limited",
  "merchantId": "12345",
  "merchantLogo": "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAIBAQEBAQIBAQECAgIC..."
}
```

### Request fields

| Field | Required | Description |
| --- | --- | --- |
| `merchantName` | Mandatory | Merchant/business name displayed on the payment page. |
| `merchantId` | Optional | Unique merchant identifier. If updating an existing merchant, use the existing ID. |
| `merchantLogo` | Optional | Base64-encoded merchant logo image (JPEG format), displayed on the payment page. |

### Sample response

```json
{
  "status": "00",
  "message": "Merchant setup successful",
  "merchantId": "12346",
  "merchantLogo": "wallet-name-a1b2c3d4e5f6g7h.jpeg"
}
```

| Field | Description |
| --- | --- |
| `status` | Response status code (`00` indicates success). |
| `message` | Response message. |
| `merchantId` | Newly generated or existing merchant ID. |
| `merchantLogo` | Filename reference for the uploaded logo. |

**Observation:** `merchantId` and `merchantLogo` are top-level, not inside `data`, unlike most other
VFD endpoints.

### Error response

```json
{
  "status": "99",
  "message": "merchantName is mandatory"
}
```

> **Not documented:** supported image size/dimensions, whether non-JPEG formats are accepted, how to
> remove/replace a logo, or how `merchantId` is generated.

---

## 4. Generate payment link

**Path:** `/generate-link`
**Method:** `POST`

**Description:** generates a unique payment link with fixed or flexible amount, optional merchant
charge, and an expiry time.

### Sample request

```json
{
  "amount": "5000.00",
  "amountValidation": "A0",
  "description": "Payment for Order #12345",
  "paymentReference": "WalletName-12345",
  "merchantId": "12346",
  "merchantName": "MyStore Limited",
  "merchantCharge": "50.00",
  "validityTime": "1440"
}
```

### Request fields

| Field | Required | Description |
| --- | --- | --- |
| `amount` | Mandatory | Payment amount in naira. |
| `amountValidation` | Mandatory | `A0` exact amount, `A1` less than, `A2` greater than. |
| `description` | Mandatory | Payment purpose, displayed to the customer. |
| `paymentReference` | Mandatory | Unique payment reference, prefixed with the wallet name (e.g. `WalletName-12345`). |
| `merchantId` | Mandatory | Merchant ID from merchant setup. |
| `merchantName` | Mandatory | Merchant name displayed on the payment page. |
| `merchantCharge` | Optional | Optional charge amount added by the merchant, in naira. |
| `validityTime` | Optional | Link validity in minutes. Maximum `4320` (72 hours). Default `120` minutes if omitted. |

**Observation:** `amountValidation` has only three values here (`A0`, `A1`, `A2`). The virtual-account
API documents six (`A0`–`A5`). They are different fields with different accepted ranges.

**Open question:** the flow says links can have a “fixed or flexible amount”, but only three validation
modes are documented. `A1`/`A2` are inequalities, not a freely chosen amount; whether the payer can
enter any amount within that rule is not explained.

### Sample response

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "merchantName": "MyStore Limited",
    "paymentReference": "WalletName-12345",
    "paymentLink": "https://payment.vfdbank.systems/pay/abc123xyz456",
    "expireAt": "2026-01-09T10:30:00Z"
  }
}
```

| Field | Description |
| --- | --- |
| `status` | Response status code (`00` indicates success). |
| `message` | Response message. |
| `data.merchantName` | Merchant name associated with the payment. |
| `data.paymentReference` | Unique payment reference supplied in the request. |
| `data.paymentLink` | Generated payment link URL to share with the customer. |
| `data.expireAt` | Expiry date/time in ISO 8601 format. |

### Error responses

Missing required field:

```json
{
  "status": "99",
  "message": "amount is mandatory"
}
```

Invalid merchant:

```json
{
  "status": "99",
  "message": "Invalid merchant ID"
}
```

---

## 5. Payment and verification

**Not documented on this page:**

- a payment-status endpoint for a payment link;
- a transaction-verification endpoint;
- a webhook event name and payload;
- how a completed payment maps back to `paymentReference`;
- whether the link supports partial payments or multiple uses;
- what the payer sees after success/failure;
- expiry behaviour after `expireAt`.

The flow's “merchant receives a notification” is the only statement. Do not invent a status endpoint.
Ask PSL for the payment-link notification contract and a verification method.

---

## 6. Response codes

Only `00` (success) and `99` (validation/business failure) are shown. No full catalogue is published,
and no HTTP status mapping is given.

---

## 7. Missing and ambiguous specifications

| Item | Status |
| --- | --- |
| Payment status/verification endpoint | **Not documented** |
| Webhook contract | **Not documented** (notification asserted only) |
| Amount-validation semantics for `A1`/`A2` | **Partially documented** |
| Merchant logo constraints | **Not documented** |
| Link reuse/partial payment | **Not documented** |
| Link cancellation | **Not documented** |
| Expiry cleanup behaviour | **Not documented** |
| Fees/settlement timing | **Not documented** |
| HTTP status codes | **Not documented** |
| Test/live path difference | **Confirmed but easy to miss** |

---

## 8. Related documents

- [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md)
- [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) — alternative collection surface.
- [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) — what is and is not documented.
- [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md) — open questions.
