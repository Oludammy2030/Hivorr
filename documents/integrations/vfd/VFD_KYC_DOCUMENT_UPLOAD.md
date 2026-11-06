# VFD KYC Document Upload API

> **Source:** [KYC Document Upload API](https://vbaas-docs.vfdtech.ng/docs/wallets-api/Products/kyc-document-upload-api)
> **Retrieved:** 6 November 2026. **Documentation only.**
>
> The vendor describes this API as allowing merchants and account holders to upload KYC documents
> for compliance and verification. It supports individual and corporate account holders.

---

## 1. Authorization and base URL

**Authorization:** `AccessToken: {{token}}`. See [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md).

| Environment | Base URL |
| --- | --- |
| Test | `https://api-devapps.vfdbank.systems/vtech-kyc/api/v2/kyc` |
| Live | `https://api-apps.vfdbank.systems/vtech-kyc/api/v2/kyc` |

All paths below are relative to this base URL.

---

## 2. Documented flow

1. Ensure you have a valid customer account number.
2. Determine which documents are required for the account type (individual or corporate).
3. Prepare the documents in the expected format — base64-encoded images or structured data.
4. Call **Bulk Upload KYC Bundle** with `accountNo` and the document fields.
5. Receive a confirmation response with upload details and resource identifiers.

**Confirmed:** "Include only the document fields required for your use case."

---

## 3. Bulk upload KYC bundle

**Path:** `/bulk-upload/kyc-bundle`
**Method:** `POST`
**Headers:**

| Key | Value |
| --- | --- |
| `AccessToken` | `{{token}}` |
| `Content-Type` | `application/json` |

**Confirmed:** the API validates the account information and verifies document types against the
account classification (individual or corporate).

### 3.1 Request envelope

| Field | Description | Required |
| --- | --- | --- |
| `accountNo` | Customer's account number. | Mandatory |
| `documentType` | The primary document type being uploaded. | Mandatory |
| Document field(s) | One or more document fields as described below. | At least one required |

**Observation:** the endpoint is named "bulk upload", but the envelope carries a single
`documentType`. The samples each show one document field matching that type. Whether multiple
different document types can be sent in one request is **not documented**.

### 3.2 Individual account samples

**Utility bill**

```json
{
  "accountNo": "1234567890",
  "documentType": "utilityBill",
  "utilityBill": {
    "base64Image": "data:image/png;base64,..."
  }
}
```

**Account opening data**

```json
{
  "accountNo": "1234567890",
  "documentType": "accountOpeningData",
  "accountOpeningData": {
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "phoneNumber": "08012345678",
    "bvn": "12345678901"
  }
}
```

**Confirmed:** "Include any additional key-value pairs relevant to your account opening information.
The fields shown are examples; you can submit any custom fields needed."

**Identity documents**

```json
{
  "accountNo": "1234567890",
  "documentType": "identityDocuments",
  "identityDocuments": [
    {
      "identityType": "NIN",
      "frontImage": {
        "base64Image": "data:image/png;base64,..."
      },
      "backImage": {
        "base64Image": "data:image/png;base64,..."
      }
    }
  ]
}
```

### 3.3 Corporate account samples

**Business registration document**

```json
{
  "accountNo": "9876543210",
  "documentType": "cacCertificate",
  "cacCertificate": {
    "base64Image": "data:image/png;base64,..."
  }
}
```

**KYC of signatories**

```json
{
  "accountNo": "9876543210",
  "documentType": "signatories",
  "signatories": [
    {
      "name": "Jane Director",
      "bvn": "99988877766",
      "address": {
        "base64Image": "data:image/png;base64,..."
      },
      "validId": {
        "identityType": "Driver License",
        "frontImage": {
          "base64Image": "data:image/png;base64,..."
        },
        "backImage": {
          "base64Image": "data:image/png;base64,..."
        }
      }
    }
  ]
}
```

**Beneficial owners details**

```json
{
  "accountNo": "9876543210",
  "documentType": "beneficialOwners",
  "beneficialOwners": [
    {
      "ownerName": "Test Holdings Ltd",
      "cacCertificate": {
        "base64Image": "data:image/png;base64,..."
      },
      "statusReport": {
        "base64Image": "data:image/png;base64,..."
      },
      "memorandumArticles": {
        "base64Image": "data:image/png;base64,..."
      }
    }
  ]
}
```

---

## 4. Document field patterns

**Confirmed:** five patterns are documented.

### 4.1 Simple document type

Structure:

```json
{ "base64Image": "data:image/png;base64,..." }
```

Applied to: `utilityBill`, `cacCertificate`, `memorandumArticles`, `statusReport`,
`boardResolution`, `tin`, `companyProofOfAddress`, `operatingLicense`, `scumlCertificate`,
`addressVisitationReport`, `sanctionPepReport`.

### 4.2 Account opening data

A flexible key-value object. Common individual fields: `firstName`, `lastName`, `otherNames`,
`dateOfBirth`, `gender`, `email`, `phoneNumber`, `address`, `state`, `city`, `nationality`, `nin`,
`bvn`, `occupation`.

Common corporate fields: `businessName`, `businessType`, `rcNumber`, `taxId`, `email`,
`phoneNumber`, `address`, `state`, `city`, `nationality`.

**Confirmed:** field selection is not restricted to the list above.

### 4.3 Identity documents

An array of identity objects with `identityType`, `frontImage`, and optional `backImage`. Supported
types named in prose: BVN, International Passport, Driver License, National ID, etc.

### 4.4 Signatories (corporate)

An array of signatory objects with `name`, `bvn`, address proof (`address.base64Image`), and a
`validId` object containing `identityType`, `frontImage`, and `backImage`.

### 4.5 Beneficial owners (corporate)

An array of beneficial-owner objects with `ownerName` and supporting documents
(`cacCertificate`, `statusReport`, `memorandumArticles`).

---

## 5. Supported document types

### 5.1 Individual accounts

| Document type | Description |
| --- | --- |
| `utilityBill` | Utility bill (electricity, water, gas). |
| `accountOpeningData` | Form with key account-creation information such as name, BVN/NIN, phone, email, and residential address. |
| `identityDocuments` | Government-issued ID documents. |

### 5.2 Corporate accounts

| Document type | Description |
| --- | --- |
| `utilityBill` | Utility bill (electricity, water, gas). |
| `accountOpeningData` | Form with business name, registration, phone, email, and company address. |
| `identityDocuments` | Government-issued ID documents. |
| `cacCertificate` | CAC (Corporate Affairs Commission) certificate. |
| `memorandumArticles` | Memorandum and Articles of Association. |
| `statusReport` | Company status report. |
| `boardResolution` | Board resolution authorizing the account. |
| `tin` | Tax Identification Number certificate. |
| `companyProofOfAddress` | Company proof of address or business premises. |
| `operatingLicense` | Operating license or business permit. |
| `scumlCertificate` | SCUML certificate (anti-money laundering). |
| `addressVisitationReport` | Address visitation report. |
| `sanctionPepReport` | Sanctions and PEP (politically exposed person) report. |
| `beneficialOwners` | Beneficial-owner information and supporting documents. |
| `signatories` | Signatory information and supporting documents. |

**Observation:** `scumlCertificate` is spelled as published. SCUML is the Special Control Unit against
Money Laundering; the vendor's spelling should be preserved in any integration mapping unless the API
accepts an alternative.

**Observation:** `accountOpeningData`, `identityDocuments`, `signatories`, and `beneficialOwners`
appear both as document types and as the names of the payload objects/arrays. The samples follow that
convention consistently.

---

## 6. Responses

### 6.1 Success

```json
{
  "status": "00",
  "message": "Document upload successful.",
  "data": {
    "uploadResults": [
      {
        "documentType": "UTILITY_BILL",
        "status": "SUCCESS"
      }
    ]
  }
}
```

| Field | Description |
| --- | --- |
| `status` | Response status code (`00` = success). |
| `message` | Response message. |
| `uploadResults` | Array of results, one per uploaded document. |
| `documentType` | Uploaded document type, uppercase with underscores. |
| `status` | Per-document status (`SUCCESS`/`FAILED`). |

**Observation:** the request uses camelCase (`utilityBill`) while the response uses
`UPPER_SNAKE_CASE` (`UTILITY_BILL`). Callers need an explicit mapping.

**Observation:** `data.uploadResults` is described as "resource identifiers" in the flow, but the
sample returns only a document type and status. No file ID, URL, or reference is shown.

**Observation:** the top-level `status` and the per-document `status` share a field name but have
different value spaces (`"00"` vs `"SUCCESS"`).

### 6.2 Errors

| HTTP/business code | Message | Meaning |
| --- | --- | --- |
| `01` | `No client found for account number.` | Account not found. |
| `98` | `accountNo is mandatory.` | Missing required field. |
| `98` | `Document type not allowed for this account type.` | Document/account-type mismatch. |
| `99` | `Document upload failed` | Upload failure. |
| `500` | `Internal server Error` | Service error. |

```json
{
  "status": "01",
  "message": "No client found for account number."
}
```

```json
{
  "status": "98",
  "message": "accountNo is mandatory."
}
```

```json
{
  "status": "98",
  "message": "Document type not allowed for this account type."
}
```

```json
{
  "status": "99",
  "message": "Document upload failed"
}
```

```json
{
  "status": "500",
  "message": "Internal server Error"
}
```

### 6.3 Response code table

| Code | Description | Action |
| --- | --- | --- |
| `00` | Success | None. |
| `01` | Account not found | Verify account number. |
| `98` | Validation failed | Check document type validity. |
| `99` | Document upload failed | Retry upload. |
| `500` | Internal server error | Contact support. |

**Observation:** the codes look like business codes, but `500` mirrors an HTTP status. The page does
not state whether codes are returned in the HTTP status line, the body, or both.

---

## 7. Security notes

- **Base64 PII in JSON.** Identity documents, utility bills, signatures, and beneficial-owner records
  are sent as base64 strings inside a JSON body. This increases payload size and means sensitive data
  is present in request logs, proxies, and error traces unless explicitly redacted.
- **BVN and NIN in plaintext fields.** `bvn`, `nin`, and `idNumber` are ordinary JSON strings.
- **No documented encryption beyond TLS.** The page gives no field-level encryption, tokenization, or
  retention guidance.
- **No documented file constraints.** Format, size, resolution, and malware scanning are not specified
  for this endpoint (the separate KYC verification pages document some image rules — see
  [VFD_KYC.md](VFD_KYC.md)).
- **No documented retrieval/deletion API.** Uploaded documents cannot be listed, downloaded, or
  deleted through a documented endpoint.
- **Error messages** confirm whether an account number exists (`01` vs `98`), which is useful to an
  attacker enumerating account numbers. Consider generic external errors.

---

## 8. Missing and ambiguous specifications

| Item | Status |
| --- | --- |
| Multiple document types in one request | **Not documented** |
| Maximum file size | **Not documented** |
| Accepted image formats | **Only shown by example** (`data:image/png;base64,...`) |
| Resolution requirements | **Not documented** for this endpoint |
| Malware/content scanning | **Not documented** |
| Document retrieval/list/delete | **Not documented** |
| Upload status check | **Not documented** |
| Retention period | **Not documented** |
| Encryption at rest | **Not documented** |
| Idempotency | **Not documented** |
| HTTP status mapping | **Not documented** |
| Result identifiers | **Not shown** despite the flow text |

---

## 9. Related documents

- [VFD_KYC.md](VFD_KYC.md) — AML, driver licence, image match, liveness, and NIN verification.
- [VFD_AUTHENTICATION.md](VFD_AUTHENTICATION.md) — access token.
- [VFD_INTEGRATION_NOTES.md](VFD_INTEGRATION_NOTES.md) — security review and Hivorr relevance.
