# Start the Hivorr app as a local web server (development env, Docker Supabase).
# Stable URL every time: http://localhost:8080
#
# Prerequisites on this machine:
#   - Docker Desktop running, `supabase start` already executed
#   - Flutter SDK + supabase CLI installed
#
# Does NOT touch staging or any cloud environment.

$ErrorActionPreference = 'Stop'

$port  = 8080
$url   = 'http://127.0.0.1:54321'
$schema = '1'

Write-Host "Reading local Supabase publishable key from 'supabase status'..."
$status = supabase status 2>&1
$anonMatch = $status | Select-String -Pattern 'sb_publishable\S+'
if (-not $anonMatch) {
    Write-Error "Could not find the publishable key. Is the local Supabase stack running? (Run 'supabase start' first.)"
    exit 1
}
$anon = $anonMatch.Matches[0].Value

Write-Host "Starting web server on http://localhost:$port (development env)..."
flutter run -d web-server --web-port=$port `
    --dart-define=HIVORR_ENV=development `
    --dart-define=HIVORR_SUPABASE_URL=$url `
    --dart-define=HIVORR_SUPABASE_ANON_KEY=$anon `
    --dart-define=HIVORR_CONFIG_SCHEMA_VERSION=$schema
