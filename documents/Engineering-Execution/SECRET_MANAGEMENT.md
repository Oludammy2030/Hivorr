# Secret Management and Rotation

**Status:** Configuration contract enforced; secret inventory recorded. Provider ruling remains open as
`F-04`. Last reviewed 2026-11-10 (`EP-01-043`).

This document is the operational half of `EP-01-043`. The committed contract in
`config/configuration-contract.json` is the technical half: it names every configuration key, says
whether it is public or secret, and says in which environments a missing value must stop startup.
Neither file contains a value.

## 1. Provider position (open finding)

`ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md` §16 records Doppler as the managed secret store
(`DAT-23`, `API-33`). **On 10 November 2026 the founder ruled that Doppler is not adopted.** GitHub
environment secrets (CI) and Fly.io secrets (API and worker, injected at deploy time) are the provider
for staging and production, with the compensating controls in §3. That supersedes §16 #8; the standards
entry still needs a formal revision.

What this task guarantees regardless of the eventual provider:

- one declared key set for every environment;
- startup and deployment fail on a missing required secret;
- no secret lives in the repository, a bundle, an image or a log;
- rotation is a documented, repeatable procedure.

If the founder and architect ratify GitHub + Fly permanently, close `F-04` and update §16 #8. If
Doppler is adopted, the injection points in §3 change, the key names do not.

## 2. Inventory and classification

The contract is authoritative. Re-derive this summary with `pnpm config:check`.

| Class | Keys | Where stored |
| --- | --- | --- |
| Secret, runtime | `DATABASE_URL`, `MFA_ENCRYPTION_KEY`, `WORKER_DATABASE_URL`, `EDGE_SHARED_SECRET` | GitHub environment secret → Fly secret at deploy |
| Secret, deployment | `FLY_API_TOKEN` | GitHub environment secret; read only by the deploy workflow |
| Public, runtime | `HIVORR_ENV`, `BACKEND_ENVIRONMENT`, `SUPABASE_PROJECT_REF`, `API_*`, `LOG_LEVEL`, `SESSION_ISSUER`, `TRUST_PROXY`, `CORS_ALLOWED_ORIGINS`, `AUTH_*`, `WORKER_*`, `DATABASE_SSL_CA` | GitHub environment variable or Fly environment |
| Public, tooling | `EXPECTED_SUPABASE_PROJECT_REF`, `STAGING_SUPABASE_PROJECT_REF`, `PRODUCTION_SUPABASE_PROJECT_REF` | GitHub environment variable |

Rules:

- `DATABASE_URL` and `MFA_ENCRYPTION_KEY` are mandatory in staging and production; startup fails
  without them and the error names the key, never the value.
- `WORKER_DATABASE_URL` falls back to `DATABASE_URL`; use a dedicated least-privilege role where one
  is provisioned.
- `EDGE_SHARED_SECRET` is optional but required before the edge proxy may forward a browser host.
- Staging and production never share a value, including `MFA_ENCRYPTION_KEY`. A staging ciphertext
  must not be readable in production.
- `SESSION_ISSUER` is a label, not a key. Sessions are opaque random tokens stored as hashes; there is
  no `SESSION_SIGNING_KEY`.

## 3. Injection

**CI (GitHub Actions).** Environment secrets are available only to jobs that reference the target
environment. The deployment workflow runs `pnpm verify:backend-target` before reading `DATABASE_URL`,
so a staging job cannot silently deploy a production connection string.

**Runtime (Fly.io).** The workflow pushes the secret to the app immediately before release:

```sh
fly secrets set DATABASE_URL="$DATABASE_URL" --app hivorr-staging-api --stage
fly secrets set MFA_ENCRYPTION_KEY="$MFA_ENCRYPTION_KEY" --app hivorr-staging-api --stage
```

`--stage` defers the restart until the release step. The value is never written into the image, the
build arguments or the repository. Public keys may be set as Fly environment variables.

**Local development.** Copy `.env.example` to `.env.local`. Local values are development values only.
`.env*` is ignored except `.env.example`. A filled `.env` in a commit is a defect (`API-36`).

## 4. Rotation

Rotate on schedule, on suspicion, and immediately after any exposure (`API-35`). Every rotation is
recorded in the founder's change log with date, key, environment, reason and operator. Values are
never recorded.

### 4.1 `DATABASE_URL`

1. Create the replacement credential in the Supabase dashboard for the matching project. Do not
   reuse a password across staging and production.
2. Overlap: keep the old credential valid until the new deployment reports healthy.
3. Set the new value as the GitHub environment secret for the target environment only.
4. Run the deployment workflow. It verifies the target and injects the secret.
5. Confirm `GET /v1/health/ready` (API) and `GET /health/ready` (worker) succeed, then check the
   structured log for a successful database probe.
6. Revoke the old credential. If the worker uses a separate role, rotate it in the same change.
7. Record the rotation.

### 4.2 `MFA_ENCRYPTION_KEY`

This key encrypts TOTP secrets, so a naive replacement locks every enrolled user out.

1. Generate a new key: `openssl rand -base64 32`. It must decode to exactly 32 bytes.
2. A rotation **requires re-enrolment** until a key-versioning scheme exists. Announce the window.
3. Set the new value as the environment secret and deploy.
4. Affected users re-enrol their authenticator. Privileged sign-in stays blocked until they do.
5. Revoke the old key material and record the rotation.

A key-versioned re-encryption migration is not implemented. Until it is, treat this key as
long-lived, store it only in the secret store, and never copy it between environments.

### 4.3 `WORKER_DATABASE_URL`

Rotate exactly like `DATABASE_URL`, against the worker role. Deploy the worker first, then the API if
the API also uses the role.

### 4.4 `EDGE_SHARED_SECRET`

1. Generate a new random value.
2. Deploy the new value to the API.
3. Deploy the same value to the edge proxy in the same change window.
4. Confirm a forwarded-host request resolves the intended portal; a mismatch falls back to the
   `Host` header, which fails closed for unknown hosts.
5. Record the rotation. A brief window where the edge presents the old value degrades to the
   `Host` header rather than opening access.

### 4.5 `FLY_API_TOKEN`

1. Create a new token scoped to the target app, with the shortest practical expiry.
2. Set it as the GitHub environment secret.
3. Run one deployment to prove it.
4. Revoke the previous token in Fly.io.
5. Record the rotation. A staging token must never reach a production app.

## 5. Break-glass

Break-glass access is held by the founder and recorded per `standards` §16 #8. Use it only when the
normal path is unavailable. Any break-glass action is recorded in the change log, and the exposed
credential is rotated afterwards even if it was read-only.

## 6. Verification and evidence

| Check | Command | Proves |
| --- | --- | --- |
| Contract matches the schema, template and topology | `pnpm config:check` | No drift, no secret value in the template |
| Seeded failure | `pnpm test:gates` | The contract gate can fail |
| Startup behaviour | `pnpm test -- tests/configuration-contract.test.ts` | Missing required secret stops startup without echoing a value |
| Repository scan | `pnpm security:secrets` | No credential pattern in tracked content |
| Client bundle | `pnpm config:check` | No secret key name in client source |
| Deployment target | `pnpm verify:backend-target` | The deployment owns its project reference |

`config:check` runs in CI before typecheck. It reads only committed names and placeholders; it never
contacts a provider.

## 7. What is not covered

- Automated rotation. Rotation is manual and recorded.
- A key-versioned re-encryption path for `MFA_ENCRYPTION_KEY`.
- Provider-side secret scanning (unavailable on the current plan); the local scan is a guard, not a
  guarantee.
- Doppler migration. Blocked on the `F-04` ruling and on a `TEC-12` addendum covering the vendor.
