# Backend Environment Setup

**Status:** GitHub environment variables are configured, and both `staging` and `production` hold a
distinct `DATABASE_URL`. The MFA encryption key is still required before either API can serve
authenticator endpoints.

## 1. Public environment variables

These are already set as GitHub environment variables. They are public identifiers, not secrets.

| Variable | Staging | Production |
| --- | --- | --- |
| `BACKEND_ENVIRONMENT` | `staging` | `production` |
| `SUPABASE_PROJECT_REF` | `hkswhaltyqfqkgswukfs` | `ahyizcwidkwyowroeqfp` |
| `EXPECTED_SUPABASE_PROJECT_REF` | `hkswhaltyqfqkgswukfs` | `ahyizcwidkwyowroeqfp` |
| `STAGING_SUPABASE_PROJECT_REF` | `hkswhaltyqfqkgswukfs` | `hkswhaltyqfqkgswukfs` |
| `PRODUCTION_SUPABASE_PROJECT_REF` | `ahyizcwidkwyowroeqfp` | `ahyizcwidkwyowroeqfp` |

The committed source of truth is `config/backend-projects.json`. The deployment preflight reads it
and refuses a mismatched target.

## 2. Secrets to set after rotation

Set these **only** through the GitHub environment secret prompt or the repository settings UI. Do not
paste a connection string into a chat, an issue, a pull request, a commit, or a log.

| Secret | Environment | Notes |
| --- | --- | --- |
| `DATABASE_URL` | `staging` | Rotated staging connection string |
| `DATABASE_URL` | `production` | Rotated production connection string |
| `SESSION_SIGNING_KEY` | `staging` | Staging-only signing key |
| `SESSION_SIGNING_KEY` | `production` | Production-only signing key |
| `MFA_ENCRYPTION_KEY` | `staging` | 32 bytes, base64, staging-only |
| `MFA_ENCRYPTION_KEY` | `production` | 32 bytes, base64, production-only |
| `FLY_API_TOKEN` | `staging` | Staging deploy token, when the API is deployed |
| `FLY_API_TOKEN` | `production` | Production deploy token, when the API is deployed |

`MFA_ENCRYPTION_KEY` encrypts TOTP secrets with AES-256-GCM before they reach the database. Generate
it with `openssl rand -base64 32`. The two environments must never share a key, because a staging
ciphertext must not be readable in production.

Commands (they prompt for the value without echoing it):

```sh
gh secret set DATABASE_URL --env staging
gh secret set DATABASE_URL --env production
gh secret set SESSION_SIGNING_KEY --env staging
gh secret set SESSION_SIGNING_KEY --env production
gh secret set MFA_ENCRYPTION_KEY --env staging
gh secret set MFA_ENCRYPTION_KEY --env production
```

The current `SUPABASE_ACCESS_TOKEN` in the workstation environment is invalid. Replace it through the
secure environment if the CLI is needed for migrations.

## 3. Why GitHub environment secrets

GitHub environment secrets are encrypted at rest, scoped to one environment, and not exposed to pull
requests from forks. For this repository they are acceptable for deployment credentials provided:

- the repository stays private;
- only the founder can administer environments and workflows;
- the `staging` and `production` secrets never contain the same value;
- the deployment workflow runs `pnpm verify:backend-target` before reading `DATABASE_URL`;
- the runtime secret is injected into Fly.io at deploy time and is not baked into an artifact.

**Residual risk under GitHub Free:** environments have no required-reviewer protection, and an
administrator can change workflows or variables. The founder's account security is therefore part of
the control. GitHub Pro/Team would add enforceable environment review and branch protection.

Doppler remains the stronger runtime-secret option because it supports rotation and scoped service
tokens. If GitHub environment secrets are the chosen source, Fly.io secrets must be updated from them
at deploy time; they must never be embedded in a build.

## 4. Verification

```sh
# Public, non-secret values
gh variable list --env staging
gh variable list --env production

# Preflight in the deployment workflow; it prints no secret
HIVORR_ENV=staging \
BACKEND_ENVIRONMENT=staging \
SUPABASE_PROJECT_REF=hkswhaltyqfqkgswukfs \
DATABASE_URL="<from the secret store>" \
pnpm verify:backend-target
```

The command must print only the environment and project reference. If it prints a connection string,
that is a defect and must be fixed before deployment.

## 5. Bootstrapping the first control grant (out of band)

Grant management is control-portal only. Creating the first `admin.grant.manage` grant is therefore a
manual, out-of-band step. It is deliberately **never seeded by a migration**, so no founder identity
is written into migration history or source control.

Run this against one environment at a time, after the target user has registered and confirmed a TOTP
factor. Connect as the database superuser (not `hivorr_api`), through a secure channel:

```sql
insert into identity.grants (user_id, grant_type, scope, environment, granted_by)
select u.id, 'admin', 'admin.grant.manage', 'staging', null
from identity.users u
where lower(u.email) = lower('founder@hivorr.com')
on conflict do nothing;

select g.id, u.email, g.scope, g.environment, g.created_at
from identity.grants g
join identity.users u on u.id = g.user_id
where g.environment = 'staging' and g.revoked_at is null;
```

Rules:

- Replace `'staging'` with `'production'` only for the production bootstrap, and only after the
  founder has approved the production release.
- Issue exactly one bootstrap `admin.grant.manage` grant, then use the API for every other grant.
- Never grant `admin.grant.manage` to a service account, a shared mailbox, or an automation identity.
- The last active `admin.grant.manage` grant cannot be revoked; the API returns `409`.
- Every API-created or API-revoked grant writes `identity.grant_created` or `identity.grant_revoked`
  to `platform.audit_log`. The out-of-band insert above is the only grant change that is not audited
  by the API, so record it in the founder's change log.

After bootstrap, grant all further scopes through `POST /v1/control/grants` with a control-portal
session. Privileged sign-in requires a confirmed authenticator factor, so `MFA_ENCRYPTION_KEY` must be
set before the bootstrap can be exercised.

## 6. Local development

Copy `.env.example` to `.env.local`. Use a local container or a staging sandbox, never production
credentials. `.env*` is ignored except `.env.example`.

## 7. What is still required

1. Rotate both database passwords exposed on 2026-11-07. Done.
2. Set the rotated `DATABASE_URL` values as environment secrets. Done.
3. Generate separate `SESSION_SIGNING_KEY` values.
4. Generate separate `MFA_ENCRYPTION_KEY` values and set them per environment.
5. Wire `pnpm verify:backend-target` into the Fly.io deploy job when it exists.
6. Bootstrap the first `admin.grant.manage` grant per environment (§5) after `MFA_ENCRYPTION_KEY` is set.
7. Add required-reviewer protection when the GitHub plan supports it.
