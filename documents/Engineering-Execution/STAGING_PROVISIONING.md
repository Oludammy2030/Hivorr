# Staging Provisioning Runbook (EP-01-060)

**Status:** Blocked. The topology is recorded in `config/environments.json` and validated by
`pnpm topology:verify`, but **no host, database, bucket, certificate, DNS record or credential has
been created**. This runbook is the reproducible sequence for the founder to execute when the
blockers clear.

## 1. Blocker — do not provision until it is closed

| Blocker | What it means | Source |
| --- | --- | --- |
| `TEC-12` | Vendor data-processing approval must record what data leaves the system, where it goes, the legal basis, processing terms, failure behaviour and exit path before Supabase, Cloudflare, Fly.io, Doppler or Sentry is integrated. | EP-01 entry record §10.3 |

The former #26 TLS blocker is **resolved**: the three privileged staging hosts are flattened to
first-level names and are covered by Cloudflare Universal SSL. The validator refuses to mark staging
`verified` while `TEC-12` remains open.

The Fly.io region is recorded as **`jnb` (Johannesburg)** in `config/environments.json`.

One further choice is not yet recorded:

- **[OPEN] Cloudflare Pages project names and R2 bucket names** — naming is operational, but the
  names must stay environment-scoped and must never be shared with production.

`TEC-12` is drafted at `TEC-12-VENDOR-DATA-PROCESSING.md`. It is **not approved** until the founder
signs it; the legal basis, DPAs, Supabase region, and R2 jurisdiction remain open in that record.

## 2. Non-negotiables

- Staging and production never share a Supabase project, database, credential, signing key, bucket,
  queue namespace, or certificate.
- No production DNS, hosting, database, or credential change is made while provisioning staging.
- No secret is written to the repository, an Issue, a pull request, a log, or a chat. Secrets enter
  only through the GitHub environment secret prompt and `fly secrets set`.
- The API has **no public hostname**. Each application host rewrites `/api/*` at the Cloudflare edge
  to that environment's Fly.io origin.
- Cloudflare Access protects `control.`, `staff.`, and `partner.` in staging.
- `partner.` is singular. There is no `partners.` host and no wildcard DNS.

## 3. Topology under test

| Application | Staging host |
| --- | --- |
| Main | `staging.hivorr.com` |
| Control | `control-staging.hivorr.com` |
| Staff | `staff-staging.hivorr.com` |
| Partner | `partner-staging.hivorr.com` |

| Resource | Staging |
| --- | --- |
| Supabase project ref | `hkswhaltyqfqkgswukfs` |
| Object storage | Cloudflare R2, prefix `hivorr-staging` |
| API origin | Fly.io, internal only |
| Worker | Fly.io, internal only |
| Access-protected hosts | control, staff, partner |

Production hosts are recorded as `reserved` and are not touched.

## 4. Preflight

```sh
pnpm topology:verify     # committed record is coherent and still blocked
pnpm verify              # repository gates
gh variable list --env staging
gh secret list --env staging
```

Expected: `topology:verify` prints eight hosts and the open blockers. It must **not** print a
connection string, token, or key.

Before any deploy, each environment must also pass:

```sh
HIVORR_ENV=staging \
BACKEND_ENVIRONMENT=staging \
SUPABASE_PROJECT_REF=hkswhaltyqfqkgswukfs \
DATABASE_URL="<from the secret store>" \
pnpm verify:backend-target
```

## 5. Provisioning sequence

Run with the founder's own provider sessions. The repository contains no provider token and no
automation that performs these steps.

### 5.1 Supabase (managed PostgreSQL only)

1. Open project `hkswhaltyqfqkgswukfs`; confirm it is the staging project and not production.
2. Disable the Data API, Supabase Auth, and Supabase Storage. Position A allows PostgreSQL only.
3. Restrict network access to the Fly.io egress addresses and the migration runner; do not leave
   `0.0.0.0/0` in place for a hosted environment.
4. Enable TLS enforcement and confirm the CA is verifiable by `pg` with `rejectUnauthorized: true`.
5. Apply every migration in `supabase/migrations` in filename order as `hivorr_migrator`. Record the
   applied set and its digest from the staging release manifest.
6. Confirm `hivorr_api`, `hivorr_worker`, `hivorr_readonly` and `hivorr_migrator` exist and that only
   the migrator may alter schema. `hivorr_worker` must not insert outbox events.
7. Set `DATABASE_URL` (API role) and `WORKER_DATABASE_URL` (worker role) as `staging` environment
   secrets. Never reuse the superuser URL at runtime.
8. Bootstrap exactly one `admin.grant.manage` grant out of band after the founder has registered and
   confirmed a TOTP factor — see `BACKEND_ENVIRONMENT_SETUP.md` §5. Record it in the change log.

### 5.2 Fly.io API and worker

1. Create two apps, for example `hivorr-staging-api` and `hivorr-staging-worker`, in `jnb`
   (Johannesburg). The worker must not have a public service.
2. Build and deploy the API and worker from the release commit. Production promotion reuses the
   recorded artifact; staging may build from `staging`.
3. Inject `HIVORR_ENV=staging`, `BACKEND_ENVIRONMENT=staging`,
   `SUPABASE_PROJECT_REF=hkswhaltyqfqkgswukfs`, `SESSION_ISSUER`, `MFA_ENCRYPTION_KEY`,
   `DATABASE_URL`, `WORKER_DATABASE_URL`, and the worker settings as Fly secrets. They must never be
   baked into an image or written to a build log.
4. Confirm the API serves `/health/live` and `/health/ready` only on the internal origin.
5. Confirm the worker serves `/health/queue` only on the private network, and that
   `WORKER_ID` is unique per machine.
6. Record the deployed machine image digest. It belongs in the release record.

### 5.3 Cloudflare Pages (four staging projects)

1. Create one Pages project per application, each bound to `staging.hivorr.com` or its
   `*.staging.hivorr.com` custom domain. `staging.` is a deployment target, not a path rewrite.
2. Deploy the four bundles from the same staging release artifact. Do not rebuild for a host.
3. Add security headers at the edge: HSTS without `preload`, CSP, frame protection, permissions
   policy, and `noindex` for the privileged and staging hosts.
4. Add the `/api/*` rewrite to the staging Fly.io API origin. No other path may reach the API.
5. Confirm no bundle contains an API origin, a token, or an environment secret.

### 5.4 Cloudflare Access

1. Protect `control-staging.hivorr.com`, `staff-staging.hivorr.com`, and
   `partner-staging.hivorr.com` with an Access application.
2. Allow only the founder identity for the control host at first; staff and partner allowlists are
   added when those roles exist.
3. Verify an unauthenticated request is challenged before the bundle loads, not after.
4. Do not protect the main staging host with Access; `/api/*` authorization remains the API's job.

### 5.5 Cloudflare R2

1. Create staging buckets under the `hivorr-staging` prefix. Never reuse a production bucket name.
2. Keep buckets private. Public media is served through the CDN, not by direct bucket access.
3. Issue a staging-only S3-compatible token; store it as a staging environment secret.
4. Confirm a production token cannot read a staging bucket and the reverse.

### 5.6 DNS and TLS

1. Create explicit A/AAAA or CNAME records for the four staging hosts only. No wildcard DNS records.
2. Confirm the Universal SSL certificate covers the flattened names. `control-staging`,
   `staff-staging`, and `partner-staging` are first-level and covered by `*.hivorr.com`; no ACM
   subscription is needed.
3. Confirm TLS terminates at the edge and the origin is not directly reachable.
4. Do not create or change any production record.

### 5.7 Repository variables and smoke

Set the public, non-secret staging variables:

```sh
gh variable set STAGING_DEPLOY_TARGET --env staging --body "<the staging target>"
gh variable set STAGING_SUPABASE_PROJECT_REF --env staging --body "hkswhaltyqfqkgswukfs"
gh variable set FOUNDER_GITHUB_LOGIN --body "<founder login>"
```

Then push a merged change to `staging` and confirm:

- `deploy-staging.yml` builds once, writes and verifies the manifest, uploads both artifacts, and
  creates the `release-candidate` Issue;
- every staging host serves the expected bundle over valid TLS;
- `/api/*` reaches only the staging API;
- an unauthenticated privileged host is blocked by Access;
- the deny probe fails on staging and cannot reach production;
- no staging credential or bucket reaches production.

## 6. Evidence for EP-01-060

Capture, without secrets:

- `pnpm topology:verify` output;
- the certificate SAN list for the four hosts;
- the four host responses and their security headers;
- the Access challenge response;
- migration set and digest from the release manifest;
- the Fly.io image digest;
- the backend-target preflight output;
- the release workflow run URL and the created Issue number.

## 7. Teardown and rollback

Before cutover, staging has no users. A failed provisioning attempt is torn down by deleting the
staging Pages projects, Fly apps, Access applications, R2 buckets and DNS records created in that
attempt, and by leaving the Supabase project intact but unused. Never delete the production project,
production buckets, or production DNS. Record the teardown and the reason.

## 8. What this runbook does not do

- It does not approve `TEC-12`.
- It does not choose the Cloudflare Pages project or R2 bucket names.
- It does not create anything by itself, and no workflow performs these steps yet.
- It does not make staging "ready": after provisioning, `config/environments.json` moves staging to
  `verified` only when `TEC-12` is closed and the evidence above exists.
