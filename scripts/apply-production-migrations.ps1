# Apply missing production migrations to fxpcgtetvzlexbptqiwp (and staging if needed)
#
# Reuse-first: replays the exact versioned files in supabase/migrations/ that
# are absent on production (6 files, 20260913..20260917). No new tables/RPCs are
# created outside those files.
#
# Prerequisites (one-time, add to 1Password / .env.local — never commit):
#   - SUPABASE_ACCESS_TOKEN — from https://supabase.com/dashboard/account/tokens
#   - SUPABASE_DB_PASSWORD  — from Dashboard → Project Settings → Database → Connection string → postgres password
#     (same password for staging and production if projects share org; otherwise per-env)
#
# Usage (PowerShell):
#   $env:SUPABASE_ACCESS_TOKEN="sbp_..."
#   $env:SUPABASE_DB_PASSWORD="..."
#   ./scripts/apply-production-migrations.ps1 -ProjectRef fxpcgtetvzlexbptqiwp -Environment production
#
# Or for staging:
#   ./scripts/apply-production-migrations.ps1 -ProjectRef cgxkiczmwzydhoroclvf -Environment staging

param(
  [string]$ProjectRef = "fxpcgtetvzlexbptqiwp",
  [string]$Environment = "production"
)

$ErrorActionPreference = "Stop"

if (-not $env:SUPABASE_ACCESS_TOKEN) {
  Write-Error "SUPABASE_ACCESS_TOKEN not set. Export it first: `$env:SUPABASE_ACCESS_TOKEN='sbp_...'"
  exit 1
}
if (-not $env:SUPABASE_DB_PASSWORD) {
  Write-Error "SUPABASE_DB_PASSWORD not set. Export it first: `$env:SUPABASE_DB_PASSWORD='...'"
  exit 1
}

Write-Host "Linking to Supabase project $ProjectRef ($Environment)..."
supabase link --project-ref $ProjectRef --password $env:SUPABASE_DB_PASSWORD

Write-Host "Checking local migration count..."
$localCount = (Get-ChildItem supabase/migrations/*.sql | Measure-Object).Count
Write-Host "Local files: $localCount"
supabase migration list --linked

Write-Host "Pushing migrations (dry-run check)..."
# supabase db push --linked --dry-run is not a real flag; use `supabase db diff` for preview
supabase db diff --linked --schema public 2>&1 | Select-Object -First 100

Write-Host "Pushing..."
supabase db push --linked

Write-Host "Verifying..."
supabase migration list --linked
Write-Host "Done. Verify prod probes:"
Write-Host "  curl.exe -s `"https://$ProjectRef.supabase.co/rest/v1/entities?select=id,capability`" -H `"apikey: <anon>`" | should be 42501 not 42703"
Write-Host "  curl.exe -s -X POST `"https://$ProjectRef.supabase.co/rest/v1/rpc/entity_onboarding_status_get`" -H `"apikey: <anon>`" -d `"{}"` | should be 42501 not PGRST202"
