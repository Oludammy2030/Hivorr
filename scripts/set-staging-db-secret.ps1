$ErrorActionPreference = "Stop"
Set-Location "C:\Project\Hivorr"

Write-Host ""
Write-Host "Hivorr staging database secret" -ForegroundColor Cyan
Write-Host "------------------------------"
Write-Host "Step 1: in Supabase, open Connect -> Session pooler -> URI -> Copy."
Write-Host "Waiting for the clipboard to contain the pooler URI..."
Write-Host ""

$uri = ""
$deadline = (Get-Date).AddMinutes(10)
while ((Get-Date) -lt $deadline) {
  $current = (Get-Clipboard -Raw)
  if ($null -ne $current -and $current.Contains("pooler.supabase.com")) {
    $uri = $current.Trim()
    break
  }
  Start-Sleep -Seconds 2
}

if (-not $uri.Contains("pooler.supabase.com")) {
  Write-Host "No pooler URI arrived in the clipboard." -ForegroundColor Yellow
  Read-Host "Press Enter to close"
  exit 1
}

$start = $uri.IndexOf("postgresql://")
if ($start -lt 0) { $start = $uri.IndexOf("postgres://") }
if ($start -gt 0) { $uri = $uri.Substring($start) }

if (-not ($uri.StartsWith("postgresql://") -or $uri.StartsWith("postgres://"))) {
  Write-Host "The clipboard contains the pooler host but not a postgres:// URI." -ForegroundColor Yellow
  Read-Host "Press Enter to close"
  exit 1
}

Write-Host "URI found." -ForegroundColor Green

if ($uri.Contains("[YOUR-PASSWORD]")) {
  Write-Host ""
  Write-Host "Step 2: enter the database password. Input is hidden." -ForegroundColor Cyan
  $secure = Read-Host "Database password" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
  $uri = $uri.Replace("[YOUR-PASSWORD]", [uri]::EscapeDataString($plain))
  $plain = $null
  $secure = $null
}

$uri | gh secret set DATABASE_URL --env staging --repo Oludammy2030/Hivorr
if ($LASTEXITCODE -ne 0) {
  Write-Host "gh failed. The secret was not set." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

Remove-Variable uri
Write-Host ""
Write-Host "Secret set. Current staging secret names:" -ForegroundColor Green
gh secret list --env staging
Read-Host "Press Enter to close"
