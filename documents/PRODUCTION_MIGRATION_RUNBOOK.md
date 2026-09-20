# Production Migration Runbook — Fix `Resource not found` on Onboarding

**Incident:** `20260915090001_onboarding_authoritative_state.sql` (and 5 peers) not on production `fxpcgtetvzlexbptqiwp` → PostgREST `PGRST202`/`42703` → `Resource not found.` on capability/final submit. See `documents/Task-Implementation/INVESTIGATION-PRODUCTION-ONBOARDING-RESOURCE-NOT-FOUND.md`.

## One-time manual fix (until CI secrets are added)

### Option A — Supabase CLI (recommended, idempotent)

1. Ensure `supabase --version` is `2.115.0` (pinned).
2. Export credentials (do **not** commit):
   ```powershell
   $env:SUPABASE_ACCESS_TOKEN="sbp_..."   # Dashboard → Account → Access Tokens
   $env:SUPABASE_DB_PASSWORD="..."        # Dashboard → Project Settings → Database → DB password
   ```
3. Run (from repo root):
   ```powershell
   ./scripts/apply-production-migrations.ps1 -ProjectRef fxpcgtetvzlexbptqiwp -Environment production
   # same for staging if you want to verify staging (should be no-op):
   ./scripts/apply-production-migrations.ps1 -ProjectRef cgxkiczmwzydhoroclvf -Environment staging
   ```
   Script links, shows `supabase migration list --linked`, `supabase db diff`, then `supabase db push --linked`.

4. Verify (read-only, anon publishable keys):
   ```powershell
   # 42703 → 42501 confirms column now exists
   curl.exe -s "https://fxpcgtetvzlexbptqiwp.supabase.co/rest/v1/entities?select=id,capability" -H "apikey: sb_publishable_dp_FfxaYE00xDeonv0tbKg_hXtLuLSc" -H "Authorization: Bearer sb_publishable_dp_FfxaYE00xDeonv0tbKg_hXtLuLSc"

   # PGRST202 → 42501 confirms RPC now exists
   curl.exe -s -X POST "https://fxpcgtetvzlexbptqiwp.supabase.co/rest/v1/rpc/entity_onboarding_status_get" -H "apikey: sb_publishable_dp_FfxaYE00xDeonv0tbKg_hXtLuLSc" -H "Authorization: Bearer sb_publishable_dp_FfxaYE00xDeonv0tbKg_hXtLuLSc" -H "Content-Type: application/json" -d "{}"
   ```

### Option B — Dashboard SQL Editor (if CLI unavailable)

Apply the **6 missing files** in lexicographic order via `https://supabase.com/dashboard/project/fxpcgtetvzlexbptqiwp/sql/new` (paste each file's full content, Run). Order:

1. `supabase/migrations/20260913090001_portfolio_public_profile.sql`
2. `supabase/migrations/20260915090001_onboarding_authoritative_state.sql` — **critical for onboarding**
3. `supabase/migrations/20260916090001_super_admin_system.sql`
4. `supabase/migrations/20260916090002_super_admin_seed.sql`
5. `supabase/migrations/20260917090001_admin_review_contract_reconcile.sql`
6. `supabase/migrations/20260917090002_manage_user.sql`

Each is `create or replace function` / `alter table … add column` idempotent; safe to re-run. Verify via `supabase_migrations.schema_migrations` should show 24 rows after.

## CI hardening (already committed)

- `.github/workflows/reusable-supabase-migration.yml` — pinned `supabase/setup-cli@46f7f98…` + `supabase db push`.
- `.github/workflows/staging-deployment.yml` now runs `migrate → build → deploy`; `production-promotion.yml` runs `verify → migrate → build → manual_approval → deploy`.

**Required repo/environment secrets/vars** (add to `staging` and `production` environments, not repo-wide):
- `SUPABASE_ACCESS_TOKEN` (secret, env)
- `SUPABASE_DB_PASSWORD` (secret, env)
- `STAGING_SUPABASE_PROJECT_REF` / `PRODUCTION_SUPABASE_PROJECT_REF` (var, optional; derived from `*_HIVORR_SUPABASE_URL` if empty)

Until those secrets exist, the migration job logs `::warning::… skipped` and lets the build proceed (draft protection inactive) — add them to enable drift protection.

## Post-fix verification

- Re-trigger `Production Promotion` for `9ece964222a10c663373b053cd04b33379a4b0cc` (`gh workflow run production-promotion.yml -f commit_sha=9ece964…`) or approve existing run `35499187524` after DB push.
- Post-deploy: `curl -s https://hivorr.pages.dev` 200, plus ephemeral signup smoke (see Investigation doc §18) — `entity_profile_update` → `entity_onboarding_status_update(p_capability:hire)` → `PLT000`.

## Rollback

Migrations are additive; no destructive `DROP`. Rollback is not needed. If a migration fails, `supabase db push` aborts before `deploy`; frontend remains at previous artifact (serialized `production` concurrency, `cancel-in-progress:false`).


<!-- trigger staging via PR for 45690b6 -->
