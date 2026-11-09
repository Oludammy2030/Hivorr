$ErrorActionPreference = "Stop"

$fly = (Get-Command flyctl -ErrorAction SilentlyContinue).Source
if (-not $fly) {
  $fly = Join-Path $env:LOCALAPPDATA "Programs\flyctl\flyctl.exe"
}
if (-not (Test-Path $fly)) {
  Write-Error "flyctl was not found. Install it or open a terminal with it on PATH."
  exit 1
}

Write-Host "Stopping the worker, leaving the API able to auto-wake..." -ForegroundColor Cyan
& $fly scale count 1 -a hivorr-staging-api --yes
& $fly scale count 0 -a hivorr-staging-worker --yes
Write-Host "Done. The API sleeps when idle and wakes on the next request." -ForegroundColor Green
Write-Host "For zero machines and zero cost, run scripts/staging-offline.ps1"
