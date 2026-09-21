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

- `.github/workflows/reusable-supabase-migration.yml` — pinned `supabase/setup-cli@46f7f98…` + `supabase db push`. Its callers forward the **repo-level** `SUPABASE_ACCESS_TOKEN` through the reusable call's `secrets:` block.
- `.github/workflows/staging-deployment.yml` now runs `migrate → build → deploy`; `production-promotion.yml` runs `verify → migrate → build → manual_approval → deploy`.

**Required repo-level secrets** (repo Settings → Secrets → Actions — called workflows cannot resolve environment-scoped secrets):
- `SUPABASE_ACCESS_TOKEN` (repo secret — **required**; this is the token the migration pipeline uses for both projects)
- `SUPABASE_DB_PASSWORD` (repo secret, optional — link falls back to access-token pooler)
- `STAGING_SUPABASE_PROJECT_REF` / `PRODUCTION_SUPABASE_PROJECT_REF` (environment vars, optional; derived from `*_HIVORR_SUPABASE_URL` if empty)

Fail-closed: if the token is not passed, the migration job errors and build/deploy are skipped — drift protection can never silently deactivate.

> History: two environment-scoping attempts failed and are documented so they are not retried:
> 1. (#58) Forwarding the token through a relay job's `needs` outputs — GitHub suppresses job outputs containing secret values (`Skip output 'supabase-access-token' since it may contain secret`), so the reusable workflow received an empty token, warned and skipped, and run `35516728591` deployed `8be8f43` to production without its `20260920*` migrations.
> 2. (#61) Declaring `environment:` on the called workflow's migrate job — the token still resolved empty (run `35576656727`), so called workflows do not expose environment secrets this way either.
> The repo-level `secrets:` forwarding is the mechanism that successfully pushed to production (run `35504107176`) and staging on 2026-09-20.

## Post-fix verification

- Production is deployed via `production-promotion.yml` (verify → migrate → build → manual approval → deploy). As of 2026-09-21 production runs the `8be8f43` frontend with only 24 of 28 migrations applied (missing `20260920090001`–`20260920090004`, which `8be8f43`'s registration identity capture expects); re-running the promotion for `8be8f43` applies them. DB parity is verified with the anon probes below (`42501` = object exists, `42703`/`PGRST202`/`PGRST205` = drift).
- Post-deploy: `curl -s https://hivorr.pages.dev` 200, plus ephemeral signup smoke (see Investigation doc §18) — `entity_profile_update` → `entity_onboarding_status_update(p_capability:hire)` → `PLT000`.

## Rollback

Migrations are additive; no destructive `DROP`. Rollback is not needed. If a migration fails, `supabase db push` aborts before `deploy`; frontend remains at previous artifact (serialized `production` concurrency, `cancel-in-progress:false`).


<!-- trigger staging via PR for 45690b6 -->
