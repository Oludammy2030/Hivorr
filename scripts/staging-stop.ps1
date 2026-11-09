$ErrorActionPreference = "Stop"

$fly = (Get-Command flyctl -ErrorAction SilentlyContinue).Source
if (-not $fly) {
  $fly = Join-Path $env:LOCALAPPDATA "Programs\flyctl\flyctl.exe"
}
if (-not (Test-Path $fly)) {
  Write-Error "flyctl was not found. Install it or open a terminal with it on PATH."
  exit 1
}

Write-Host "Stopping staging machines..." -ForegroundColor Cyan
& $fly scale count 0 -a hivorr-staging-api --yes
& $fly scale count 0 -a hivorr-staging-worker --yes
Write-Host "Staging stopped. Compute cost is now zero." -ForegroundColor Green
