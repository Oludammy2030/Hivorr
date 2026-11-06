# VFD Authentication — Access Tokens

> **Source:** [Authorization](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Authorization/)
> **Retrieved:** 6 November 2026. **Documentation only.**

---

## 1. Purpose

Every documented VFD/PSL product endpoint expects an access token in an `AccessToken` request header.
This document records how that token is generated in the test and live environments, what the
documentation says about validity, and what it leaves unspecified.

**Confirmed:** authorization “involves utilizing an access token”, and the token “provides
authorization for making API calls”.

---

## 2. Token generation — test environment

**API URL:** `https://api-devapps.vfdbank.systems/vtech-wallet/api/v2/wallet2/token`

**Method:** `POST`

### 2.1 Request body

```json
{
  "consumerKey": "XXXXXXXXX",
  "consumerSecret": "XXXXXXXXX",
  "validityTime": "-1"
}
```

| Field | Type in example | Required | Description |
| --- | --- | --- | --- |
| `consumerKey` | string | Mandatory | Wallet-specific consumer key, generated under the API Keys section of the VBaaS portal. |
| `consumerSecret` | string | Mandatory | Wallet-specific consumer secret, generated under the API Keys section of the VBaaS portal. |
| `validityTime` | string | Mandatory | Token validity time in minutes. |

**Vendor note:** passing `validityTime` of `-1` returns a token that does not expire.

### 2.2 Sample response

```json
{
  "status": "00",
  "message": "Successful",
  "data": {
    "access_token": "XXXXXXXXXX",
    "scope": "am_application_scope default",
    "token_type": "Bearer",
    "expires_in": 9223372036854775807
  }
}
```

---

## 3. Token generation — live environment

**API URL:** `https://api-apps.vfdbank.systems/vtech-wallet/api/v2/wallet2/token`

**Method:** `POST`

The request body, field requirements and sample response are identical to the test environment.

```json
{
  "consumerKey": "XXXXXXXXX",
  "consumerSecret": "XXXXXXXXX",
  "validityTime": "-1"
}
```

---

## 4. Using the token

Every documented product endpoint shows the same request header:

| Key | Value |
| --- | --- |
| `AccessToken` | `{{token}}` |

**Confirmed:** the header name is `AccessToken`, not the standard `Authorization: Bearer ...` header,
for these API calls. The token response itself declares `token_type: "Bearer"`, but the product
documentation consistently instructs integrators to send the token in `AccessToken`.

> **Not documented:** whether an `Authorization: Bearer <token>` header is also accepted, or whether
> both are accepted by every product. Use `AccessToken` as documented.

The token endpoint is under the wallet path and is shared by the other products in the documentation;
the site does not publish product-specific token endpoints.

---

## 5. Token validity

| Item | Documented behaviour |
| --- | --- |
| `validityTime` unit | Minutes |
| Explicit expiry | Set by the value supplied at generation |
| Non-expiring option | `-1` produces a token that does not expire |
| Response field | `expires_in` |
| Sample `expires_in` | `9223372036854775807` (the maximum signed 64-bit integer, consistent with the non-expiring example) |
| `scope` | `am_application_scope default` |
| `token_type` | `Bearer` |

**Observation:** the sample uses `validityTime: "-1"` and returns a very large `expires_in`. Treat a
non-expiring token as a high-value secret. The documentation does not recommend one validity policy.

---

## 6. Authentication errors

**Not documented:** the Authorization page does not publish:

- an invalid-credentials response;
- an expired-token response;
- an HTTP `401`/`403` example;
- a token-refresh operation;
- a token-revocation operation;
- a “generate token” permission/scope model.

Do not infer these behaviours from other providers. They require vendor confirmation or sandbox
testing.

**Observation:** if the token endpoint returns the common `{ status, message, data }` envelope, a
non-`00` status is likely to indicate failure, but no failure example is published.

---

## 7. Security requirements and implementation notes

These are observations for review, not vendor requirements beyond the quoted text:

1. **Server-side only.** Consumer key and secret must never be shipped to a browser or mobile client.
   The Payment Widget page separately instructs integrators to place a wallet access token in browser
   code; see [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) for that exception and its risks.
2. **Secret storage.** Store credentials in a secret manager, not in source control, build output or
   logs.
3. **Least privilege.** The documentation does not describe scoped credentials per product. If all
   products share the same token, a leak exposes the entire wallet surface.
4. **Rotation.** Key generation/rotation is said to exist in the VBaaS Dashboard, but the procedure and
   overlap window are not documented.
5. **Transport.** All APIs are stated to be HTTPS. Do not disable certificate validation.
6. **Logging.** Never log the `consumerSecret`, `access_token`, card PAN/CVV/PIN, BVN/NIN images, or
   document-upload payloads.
7. **Non-expiring tokens.** Prefer a finite `validityTime` if the vendor supports refresh in practice;
   otherwise record the decision and compensating controls explicitly. This is an engineering
   recommendation, not a VFD requirement.

---

## 8. Related documents

- [VFD_OVERVIEW.md](VFD_OVERVIEW.md) — platform and environments.
- [VFD_PAYMENT_WIDGET.md](VFD_PAYMENT_WIDGET.md) — client-side token exposure.
- [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md) — security review checklist.
- [VFD_WEBHOOKS.md](VFD_WEBHOOKS.md) — webhook authentication is separately undocumented.
