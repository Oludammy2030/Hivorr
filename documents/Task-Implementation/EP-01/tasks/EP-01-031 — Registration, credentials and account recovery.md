# EP-01-031 — Registration, credentials and account recovery

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-031` |
| **Task title** | Registration, credentials and account recovery |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — identity security |
| **Execution order** | 18 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage D |
| **Dependencies** | `EP-01-030` |

## 2. Objective

Registration creates an account, user, credential, profile and owner membership with zero activities
and zero grants. Credentials use the OWASP Argon2id minimum. Account recovery issues single-use,
expiring, hashed tokens; a password reset updates the credential and revokes every session. Delivery
is capture-only until a provider is selected.

## 3. Scope

### 3.1 Included

- Migration `20261109000500_identity_alter_recovery_tokens.sql`: narrow security-definer token
  lookups for password reset and email verification.
- `CaptureEmailAdapter` in `server/src/integrations/email`.
- Service methods: `requestPasswordReset`, `resetPassword`, `requestEmailVerification`, `verifyEmail`.
- HTTP endpoints under `/v1/auth` with strict request schemas.
- OpenAPI operations and regenerated client.
- Credential/token policy tests and DB integration tests.
- Audit entries for request and completion; no account enumeration.

### 3.2 Excluded

- A real email provider. The capture adapter records the message in memory; no token is logged.
- Rate limiting on recovery requests — `042`.
- Profile creation during registration. The profile table exists; the profile write is `033`/`053`
  when the flow is wired.
- Session endpoint and rotation — `032`.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Registration creates no activity and no grant. | Plan `031` outcome |
| R-02 | Argon2id uses at least 19 MiB, t=2, p=1. | OWASP; standards |
| R-03 | Recovery tokens are random, single-use, expiring and stored hashed. | Plan `031` outcome |
| R-04 | Tokens never appear in logs or audit detail. | SEC-27, AFS-LOG |
| R-05 | A reset revokes every active session. | Plan `031` outcome |
| R-06 | A reset request does not reveal whether the email exists. | Enumeration control |
| R-07 | Token lookups are narrow security-definer functions; writes use RLS. | `025`, `030` |
| R-08 | Delivery is capture-only until a provider adapter exists. | Plan `031` |
| R-09 | The four endpoints are documented and generated. | `013` |
| R-10 | No new dependency, secret or CI permission. | Standards §3.4, §4A |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-030` domain/repository | **REQUIRES_REVIEW** — registration path |
| `EP-01-025` RLS | **REQUIRES_REVIEW** — token/credential policies |
| `EP-01-013` contract | **REQUIRES_REVIEW** — generated client |
| CI Postgres 17 | Existing database job |

## 6. Implementation plan

1. Read the token table, identity policies and registration path.
2. Add the recovery token lookup functions and the owner-read policy.
3. Add the capture email adapter and provide it in `AppModule`.
4. Add the four service methods with audit and no enumeration.
5. Add the controller endpoints and contract schemas.
6. Regenerate OpenAPI and the client.
7. Add credential/token policy tests and DB integration tests.
8. Run local gates; record the integration evidence that needs CI.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `identity.tokens` | **Reuse** | Purpose, hash, expiry and consumption already modelled |
| `hashSessionToken` | **Reuse** | SHA-256 over a random token |
| `createSessionToken` | **Reuse** | 32 random bytes, base64url |
| `find_login_credential` | **Reuse** | Pre-auth email lookup |
| `withTransaction` | **Reuse** | Request and completion are units of work |
| `appendAudit` | **Reuse** | One audit path |
| `IdentityRepository` | **Reuse** | Registration stays on the repository |
| OpenAPI generator | **Reuse** | Four new operations |

**Must not be duplicated:** a second token table, a second hasher, a second reset flow, or a second
email adapter interface.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `supabase/migrations/20261109000500_identity_alter_recovery_tokens.sql` | **New** |
| `server/src/integrations/email/email.adapter.ts` | **New** |
| `server/src/modules/identity/identity.service.ts` | Recovery methods, TTLs, adapter |
| `server/src/modules/identity/identity.controller.ts` | Four endpoints |
| `server/src/contracts/schemas.ts` | Three request schemas |
| `server/src/openapi/operations.ts` | Four operations |
| `server/src/app.module.ts` | Email adapter provider |
| `openapi/openapi.json`, `packages/api-client/src/index.ts` | Regenerated |
| `tests/credentials.test.ts` | **New** |
| `tests/identity-integration.test.ts` | Recovery DB tests |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No dependency or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Registration creates no grant or activity. |
| DoD-02 | Argon2id parameters match the OWASP minimum. |
| DoD-03 | Reset/verification tokens are random, hashed, single-use and expiring. |
| DoD-04 | A reset request is 202 for known and unknown emails; no message for unknown. |
| DoD-05 | A completed reset revokes every session and invalidates the token. |
| DoD-06 | Email verification is single-use and sets `email_verified_at`. |
| DoD-07 | Tokens are absent from logs and audit fields. |
| DoD-08 | Four endpoints exist with strict schemas and generated client methods. |
| DoD-09 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates` pass. |
| DoD-10 | `pnpm test:identity` passes the recovery suite in CI. |
| DoD-11 | No new dependency, secret or permission. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged against `v0.0.1-bootstrap`. |

## 10. Acceptance criteria

- The capture adapter holds one message for a known email and none for an unknown one.
- The raw token is absent from `identity.tokens`; only a 64-character SHA-256 hash is stored.
- A replayed reset token returns 400; the old password no longer signs in; the new password does.
- A session cookie issued before the reset returns 401 afterwards.
- A verification token sets `email_verified_at` once and is refused on replay.
- The OpenAPI document and client contain the four operations.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/credentials.test.ts` |
| T-02 | `pnpm test -- tests/openapi-contract.test.ts tests/api-client.test.ts` |
| T-03 | `pnpm test:identity` — CI database job |
| T-04 | `pnpm lint:migrations`, `pnpm test:gates` |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check` |
| T-06 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| No real email provider. | Capture-only adapter, recorded as `F-34`; the service contract is provider-independent. |
| Password reset does not delete refresh-token rows. | Sessions are revoked; refresh checks session revocation and refuses. |
| Recovery requests can be abused. | Rate limiting is `042`; the endpoint is already enumeration-safe. |
| A token could leak through logs. | The service has no token logging; the adapter has no logging; the policy test checks both. |
| Security-definer lookups bypass RLS. | They return only the user/account/email for a valid token; writes run as the API with context. |
| No Postgres locally. | Policy tests are static; integration runs in CI. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-09 |
| **Code complete** | 2026-11-09 |
| **Closes when** | CI passes the recovery integration suite; a real provider replaces the capture adapter |
| **Execution record** | `execution-records/EP-01-031.md` |
