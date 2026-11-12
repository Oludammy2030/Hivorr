# New Machine Bootstrap

**Purpose:** everything a second workstation needs to inspect, verify and deploy Hivorr after cloning
the repository. No secret value is stored here.

## 1. What must exist before cloning

| Tool | Version / note |
| --- | --- |
| Git | Any recent version |
| Node | **22.x** (the contract is `>=22.0.0 <23`) |
| pnpm | **10.34.9** |
| GitHub CLI (`gh`) | For auth checks and workflow inspection |
| Fly CLI (`flyctl`) | Staging API and worker |
| Wrangler | Cloudflare Pages, Workers, R2 |
| Docker Desktop | Optional; required only for local database tests |
| Supabase CLI | Optional; only for migrations from a workstation |

The repository pins Node and pnpm in `package.json` and `.mise.toml`. `pnpm check:toolchain` fails
loudly on a mismatch.

## 2. Clone and enter the repository

```powershell
git clone https://github.com/Oludammy2030/Hivorr.git
cd Hivorr
git checkout staging
git pull
pnpm install --frozen-lockfile
```

Never commit `.env` files, credentials or connection strings.

## 3. Authenticate the tools

These are per-machine and never stored in the repository.

```powershell
gh auth status
flyctl auth whoami
wrangler whoami
```

If a tool is missing:

```powershell
# GitHub CLI
winget install --id GitHub.cli -e

# Fly CLI: download the Windows binary from the Fly releases page,
# then add its folder to the user PATH.
flyctl auth login

# Wrangler
npm install -g wrangler
wrangler login
```

`flyctl` is not always on PATH in an existing terminal after installation; open a new terminal or use
the full path.

## 4. Verify the checkout

```powershell
pnpm check:toolchain
pnpm topology:verify
pnpm typecheck
pnpm test
pnpm verify
```

`pnpm verify` runs the full local gate: toolchain, docs, lint, boundaries, migrations lint, topology,
config, typecheck, unit and contract tests, release and topology policy tests, secret scan,
OpenAPI check and diff, visual baseline, all four bundles, bundle targets, server build, API tests and
worker smoke.

Local database tests need Docker Desktop:

```powershell
$env:DATABASE_URL = "postgres://postgres:postgres@127.0.0.1:54322/postgres"
pnpm test:db
```

## 5. Current environment state

| Item | Value |
| --- | --- |
| Staging Supabase project ref | `hkswhaltyqfqkgswukfs` |
| Production Supabase project ref | `ahyizcwidkwyowroeqfp` |
| Fly apps | `hivorr-staging-api`, `hivorr-staging-worker` (region `jnb`) |
| Fly API hostname | `hivorr-staging-api.fly.dev` (internal origin; not a portal) |
| Pages projects | `hivorr-staging-main`, `hivorr-staging-control`, `hivorr-staging-staff`, `hivorr-staging-partner` |
| R2 buckets | `hivorr-staging-media`, `hivorr-staging-exports` |
| Staging hosts | `staging.hivorr.com`, `control-staging.hivorr.com`, `staff-staging.hivorr.com`, `partner-staging.hivorr.com` |
| Access | Control: founder only. Staff: `hajahlofah@gmail.com`. Partner: closed. |
| Onboarding | `https://staging.hivorr.com/onboarding` |
| API lifecycle | One machine, sleeps after 5 minutes idle, wakes in ~6 seconds |
| Worker | Scaled to zero; start it only when testing background jobs |

Production is **not provisioned**. Its hostnames do not resolve and no production release has been
approved.

## 6. Common commands

```powershell
# local checks
pnpm check:toolchain
pnpm typecheck
pnpm test
pnpm topology:verify
pnpm verify

# staging lifecycle
powershell -ExecutionPolicy Bypass -File scripts/staging-start.ps1
powershell -ExecutionPolicy Bypass -File scripts/staging-stop.ps1
powershell -ExecutionPolicy Bypass -File scripts/staging-offline.ps1

# staging account helpers
powershell -ExecutionPolicy Bypass -File scripts/staging-account-status.ps1
powershell -ExecutionPolicy Bypass -File scripts/bootstrap-staging-admin.ps1 -Email admin@hivorr.com

# deploy a portal by hand (only for recovery; CI deploys all four on every merge)
# see deploy-staging.yml "deploy staging portals to Pages"
wrangler pages deploy dist --project-name hivorr-staging-main --branch staging
wrangler pages deploy dist/portals/control --project-name hivorr-staging-control --branch staging

# deploy the API and worker through CI
# merge a PR into staging; the workflow applies migrations, builds one image, deploys both
# processes, smoke-tests the API, then scales the worker to zero
```

## 7. Secrets and credentials

- GitHub environment secrets hold `DATABASE_URL`, `MFA_ENCRYPTION_KEY` and `FLY_API_TOKEN` for
  staging. They are write-only and cannot be read back.
- Fly secrets hold the runtime values injected at deploy time.
- Cloudflare API tokens are created per task and are not stored in the repository.
- If a secret is lost, rotate it at the provider and update the corresponding secret store.
- Never paste a secret into an issue, a pull request, a commit, a chat or a log.

## 8. Security rules for this machine

- Stay on `staging`. Production changes require the founder-approved release gate.
- Do not bypass Cloudflare Access on the privileged hosts.
- Do not weaken the database TLS setting; `DATABASE_SSL_CA` is still outstanding.
- Treat the staging database as non-production: no real customer data.
- Run `pnpm security:secrets` before pushing if you touch configuration.

## 9. Tagging this document

After cloning and completing the checks, tag the commit you verified:

```powershell
git tag -a machine-bootstrap-2026-11 -m "Second workstation verified: toolchain, tests, staging access"
git push origin machine-bootstrap-2026-11
```

Use a date or machine name that identifies the workstation. Tags are references, not secrets.
