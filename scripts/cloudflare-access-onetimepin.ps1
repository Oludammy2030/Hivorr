$ErrorActionPreference = "Stop"

function Read-SecretText([string]$prompt) {
  $secure = Read-Host $prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

$account = "e68bab6d47e7ecb3e15324f2a7a25ab0"
$hosts = @(
  "control-staging.hivorr.com",
  "staff-staging.hivorr.com",
  "partner-staging.hivorr.com"
)

Write-Host ""
Write-Host "Enable One-time PIN for the staging portals" -ForegroundColor Cyan
Write-Host "-------------------------------------------"
Write-Host "Token permissions needed:"
Write-Host "  Account -> Access: Apps and Policies -> Edit"
Write-Host "  Account -> Access: Identity Providers -> Edit (if shown)"
Write-Host ""
Write-Host "Paste the token below. Input is hidden and the token is not saved."
Write-Host ""

$token = Read-SecretText "Cloudflare API token"
$headers = @{
  Authorization  = "Bearer $token"
  Accept         = "application/json"
  "Content-Type" = "application/json"
}

try {
  Write-Host "Reading identity providers ..."
  $providers = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/identity_providers" -Headers $headers -Method Get -TimeoutSec 60
  $otp = $providers.result | Where-Object { $_.type -eq "onetimepin" } | Select-Object -First 1

  if (-not $otp) {
    Write-Host "Creating the One-time PIN provider ..."
    $body = @{ name = "One-time PIN"; type = "onetimepin"; config = @{} } | ConvertTo-Json -Depth 6
    $created = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/identity_providers" -Headers $headers -Method Post -Body $body -TimeoutSec 60
    $otp = $created.result
  }

  Write-Host "One-time PIN provider: $($otp.id)"

  $apps = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/apps" -Headers $headers -Method Get -TimeoutSec 60

  foreach ($hostName in $hosts) {
    $app = $apps.result | Where-Object { $_.domain -eq $hostName } | Select-Object -First 1
    if (-not $app) {
      Write-Host "$hostName -> no Access application" -ForegroundColor Yellow
      continue
    }

    $patch = @{
      allowed_idps                = @($otp.id)
      auto_redirect_to_identity   = $false
    } | ConvertTo-Json -Depth 6

    try {
      Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/apps/$($app.id)" -Headers $headers -Method Patch -Body $patch -TimeoutSec 60 | Out-Null
    } catch {
      # Fall back to a full update if PATCH is not supported.
      $full = @{
        name                      = $app.name
        domain                    = $app.domain
        type                      = $app.type
        session_duration          = $app.session_duration
        allowed_idps              = @($otp.id)
        auto_redirect_to_identity = $false
      } | ConvertTo-Json -Depth 6
      Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/apps/$($app.id)" -Headers $headers -Method Put -Body $full -TimeoutSec 60 | Out-Null
    }

    Write-Host "$hostName -> One-time PIN enabled" -ForegroundColor Green
  }

  Write-Host ""
  Write-Host "Done. Access should now offer an email code option." -ForegroundColor Green
} catch {
  Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
  if ($_.ErrorDetails.Message) {
    Write-Host $_.ErrorDetails.Message
  }
} finally {
  $token = $null
  Remove-Variable token, headers -ErrorAction SilentlyContinue
}

Read-Host "Press Enter to close"
