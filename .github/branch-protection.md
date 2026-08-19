# Branch Protection Requirements — EP-01-04

> **Document Type:** Operational Configuration Documentation
> **Task:** EP-01-04 — CI/CD Pipeline & Automated Deployment Framework
> **Purpose:** Defines the required branch protection rules the project lead must configure in GitHub repository settings.

---

## 1. Protected Branch: `master`

The `master` branch is the protected promotion branch. The following rules must be enforced:

### 1.1 Pull Request Requirements

| Rule | Required |
|---|---|
| Require pull request approval before merge | Yes |
| Required number of approvals | 1 (minimum) |
| Dismiss stale approvals when new commits are pushed | Yes |
| Require review from Code Owners | Recommended |
| Require resolution of review conversations before merge | Yes |

### 1.2 Status Check Requirements

| Required Check | Source Workflow |
|---|---|
| Format, Analyze, Test | `reusable-validation.yml` (via `pr-validation.yml`) |
| Build (web) | `reusable-validation.yml` (via `pr-validation.yml`) |
| Build (android) | `reusable-validation.yml` (via `pr-validation.yml`) |
| Build (ios) | `reusable-validation.yml` (via `pr-validation.yml`) |
| Build (windows) | `reusable-validation.yml` (via `pr-validation.yml`) |

- Require branches to be up to date before merging: Yes

### 1.3 Push Restrictions

| Rule | Required |
|---|---|
| Restrict direct pushes to `master` | Yes |
| Restrict force pushes to `master` | Yes |
| Restrict deletions of `master` | Yes |

### 1.4 Workflow Permissions

| Rule | Required |
|---|---|
| Default workflow permissions | Read-only |
| Allow write actions only for artifact/deployment jobs | Yes |
| Do not allow `pull_request_target` for build/execution | Yes |

---

## 2. GitHub Environments

Three isolated GitHub Environments must be configured:

### 2.1 Staging Environment

| Setting | Value |
|---|---|
| Name | `staging` |
| Required reviewers | Project Lead (or designated team) |
| Deployment branch | `master` only |
| Wait timer | 0 (automatic after checks pass) |

**Environment Variables:**
- `CLOUDFLARE_ACCOUNT_ID` — Cloudflare account ID
- `CLOUDFLARE_PAGES_PROJECT_NAME` — Cloudflare Pages project name for Staging (e.g., `hivorr-staging`)
- `DEPLOY_WEB_URL` — Staging URL for post-deployment smoke checks (e.g., `https://staging.hivorr.app`)

**Environment Secrets:**
- `CLOUDFLARE_API_TOKEN` — Cloudflare API token with Pages write permissions for the Staging project

**Repository-Level Variables (Staging-prefixed):**
- `STAGING_HIVORR_SUPABASE_URL` — Staging Supabase HTTPS URL
- `STAGING_HIVORR_CONFIG_SCHEMA_VERSION` — `1`
- `STAGING_HIVORR_FEATURE_ENABLE_VERBOSE_LOGGING` — `false` (or `true` for testing)
- `STAGING_HIVORR_FEATURE_ENABLE_OFFLINE_SYNC` — `false`
- `STAGING_HIVORR_FEATURE_ENABLE_ANALYTICS_TRACKING` — `false`
- `STAGING_HIVORR_FEATURE_ENABLE_DYNAMIC_WORKSPACE_LOADING` — `false`

**Repository-Level Secrets (Staging-prefixed):**
- `STAGING_HIVORR_SUPABASE_ANON_KEY` — Staging Supabase public anon key

### 2.2 Production Environment

| Setting | Value |
|---|---|
| Name | `production` |
| Required reviewers | Project Lead only |
| Deployment branch | `master` only |
| Wait timer | Recommended: 120 seconds (cooling period) |

**Environment Variables:**
- `CLOUDFLARE_ACCOUNT_ID` — Cloudflare account ID
- `CLOUDFLARE_PAGES_PROJECT_NAME` — Cloudflare Pages project name for Production (e.g., `hivorr`)
- `DEPLOY_WEB_URL` — Production URL for post-deployment smoke checks (e.g., `https://hivorr.app`)

**Environment Secrets:**
- `CLOUDFLARE_API_TOKEN` — Cloudflare API token with Pages write permissions for the Production project

**Repository-Level Variables (Production-prefixed):**
- `PRODUCTION_HIVORR_SUPABASE_URL` — Production Supabase HTTPS URL
- `PRODUCTION_HIVORR_CONFIG_SCHEMA_VERSION` — `1`
- `PRODUCTION_HIVORR_FEATURE_ENABLE_VERBOSE_LOGGING` — `false`
- `PRODUCTION_HIVORR_FEATURE_ENABLE_OFFLINE_SYNC` — `false`
- `PRODUCTION_HIVORR_FEATURE_ENABLE_ANALYTICS_TRACKING` — `false`
- `PRODUCTION_HIVORR_FEATURE_ENABLE_DYNAMIC_WORKSPACE_LOADING` — `false`

**Repository-Level Secrets (Production-prefixed):**
- `PRODUCTION_HIVORR_SUPABASE_ANON_KEY` — Production Supabase public anon key

### 2.3 Isolation Rules

- Staging and Production secrets must never share the same values.
- Staging and Production Supabase URLs must point to separate Supabase projects.
- PR validation workflows must not receive Staging or Production secrets.
- No service-role keys or private backend secrets may be stored in any GitHub Environment or repository secret.

---

## 3. Configuration Instructions

1. Navigate to **Repository Settings → Branches → Branch protection rules**.
2. Click **Add rule** and enter `master` as the branch name pattern.
3. Enable all rules listed in §1.
4. Navigate to **Repository Settings → Environments**.
5. Create the `staging` and `production` environments with the settings listed in §2.
6. Configure repository-level variables and secrets under **Repository Settings → Secrets and variables → Actions**.
7. Configure Cloudflare Pages projects:
   - Create a Cloudflare account at https://dash.cloudflare.com (if not already present).
   - Navigate to **Workers & Pages → Create application → Pages**.
   - Create a Staging project named `hivorr-staging` (or your preferred name).
   - Create a Production project named `hivorr` (or your preferred name).
   - Generate an API token at **My Profile → API Tokens → Create Token** with Pages write permissions.
   - Note the Account ID from the Cloudflare dashboard.
8. Add the Cloudflare variables and secrets to the corresponding GitHub Environments:
   - `CLOUDFLARE_ACCOUNT_ID` as an environment variable.
   - `CLOUDFLARE_PAGES_PROJECT_NAME` as an environment variable.
   - `CLOUDFLARE_API_TOKEN` as an environment secret.
   - `DEPLOY_WEB_URL` as an environment variable.
9. Verify that no real `.env` files or service-account credentials are committed to the repository.

---

## 4. Configuration Notes

- The Supabase anon key is a public client key, not a server secret. It is safe for client distribution. However, it is stored as a GitHub secret to prevent accidental exposure in workflow logs and to ensure environment-specific keys are used.
- Cloudflare API tokens are environment-scoped secrets stored within the `staging` and `production` GitHub Environments. Staging and Production must use separate tokens or a single token scoped to both Pages projects.
- The `CLOUDFLARE_PAGES_PROJECT_NAME` variable is required for deployment. If not set, the workflow publishes artifacts but skips deployment with a warning.
- The `DEPLOY_WEB_URL` variable is optional but recommended. If set, the workflow runs a post-deployment HTTP 200 smoke check. If not set, the smoke check is skipped with a warning.
- Cloudflare Pages deploys to the `main` branch within each Pages project, which maps to the production deployment in Cloudflare's model. Preview deployments are not used in this CI/CD framework.

---

## 5. Enforcement Status on the GitHub Free Plan

This private repository runs on the GitHub Free plan, where branch protection rules **cannot be enforced** on private repositories (DoD deviation D-01). Until the account is upgraded to GitHub Pro or the repository is made public, the following pipeline-level guards substitute for real branch protection:

### 5.1 Protect Master Workflow

- File: `.github/workflows/protect-master.yml` (uses `.github/workflows/reusable-master-guard.yml`)
- Runs on every push to `master`.
- Fails loudly if the pushed commit did not originate from a merged pull request (direct push detected).

### 5.2 Staging Guard

- The Staging Deployment workflow runs the same guard (`.github/workflows/reusable-master-guard.yml`) as its first job.
- A direct push to `master` therefore fails the Staging guard, so the commit is never staged — and the Production Promotion verify job (which requires a successful Staging run) will never accept it.
- Net effect: **a commit that did not arrive via a merged PR can never reach Production**, even without GitHub-enforced branch protection.

### 5.3 Branch Protection Reminder

- File: `.github/workflows/branch-protection-reminder.yml`
- Runs every Monday 09:00 UTC (and manually via `workflow_dispatch`).
- If branch protection for `master` is not configured, it opens (or keeps open) a reminder issue: *"Branch protection is not enforced on master"*.
- Once protection is detected (after a plan upgrade or public visibility change), the issue is closed automatically.

### 5.4 Enabling Real Protection Later

When the plan is upgraded (or the repository is made public):

1. Apply the rules in §1 and §2 of this document (Settings → Branches / Environments).
2. Re-run the `Branch Protection Reminder` workflow — the reminder issue closes automatically.
3. The `protect-master` and staging guards remain active as defense-in-depth; they pass for any merged-PR commit, so they do not conflict with GitHub's own enforcement.
