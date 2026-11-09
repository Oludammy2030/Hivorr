$ErrorActionPreference = "Stop"

$fly = (Get-Command flyctl -ErrorAction SilentlyContinue).Source
if (-not $fly) {
  $fly = Join-Path $env:LOCALAPPDATA "Programs\flyctl\flyctl.exe"
}
if (-not (Test-Path $fly)) {
  Write-Error "flyctl was not found. Install it or open a terminal with it on PATH."
  exit 1
}

Write-Host "Starting staging machines..." -ForegroundColor Cyan
& $fly scale count 1 -a hivorr-staging-api --yes
& $fly scale count 1 -a hivorr-staging-worker --yes

for ($attempt = 1; $attempt -le 30; $attempt++) {
  try {
    $response = Invoke-WebRequest -UseBasicParsing `
      https://hivorr-staging-api.fly.dev/v1/health/live -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
      Write-Host "Staging is up." -ForegroundColor Green
      Write-Host "API: https://hivorr-staging-api.fly.dev"
      exit 0
    }
  } catch {
    Start-Sleep -Seconds 5
  }
}

Write-Error "Staging did not become healthy. Check: flyctl logs -a hivorr-staging-api"
exit 1
