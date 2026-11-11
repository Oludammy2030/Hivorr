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
Write-Host "Hivorr staging Access policy" -ForegroundColor Cyan
Write-Host "----------------------------"
Write-Host "Restricts the three privileged staging hosts to one email address."
Write-Host ""
Write-Host "Token permissions needed:"
Write-Host "  Account -> Access: Apps and Policies -> Edit"
Write-Host ""
Write-Host "Paste the token below. Input is hidden and the token is not saved."
Write-Host ""

$founderEmail = (Read-Host "Founder email [oludammy2030@gmail.com]").Trim()
if ([string]::IsNullOrWhiteSpace($founderEmail)) {
  $founderEmail = "oludammy2030@gmail.com"
}

$staffEmail = (Read-Host "Staff email [hajahlofah@gmail.com]").Trim()
if ([string]::IsNullOrWhiteSpace($staffEmail)) {
  $staffEmail = "hajahlofah@gmail.com"
}

$token = Read-SecretText "Cloudflare API token"
$headers = @{
  Authorization  = "Bearer $token"
  Accept         = "application/json"
  "Content-Type" = "application/json"
}

try {
  Write-Host "Reading Access applications ..."
  $apps = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/apps" -Headers $headers -Method Get -TimeoutSec 60

  foreach ($hostName in $hosts) {
    $app = $apps.result | Where-Object { $_.domain -eq $hostName } | Select-Object -First 1
    if (-not $app) {
      Write-Host "$hostName -> no Access application found" -ForegroundColor Yellow
      continue
    }

    $isControl = $hostName -eq "control-staging.hivorr.com"
    $isStaff = $hostName -eq "staff-staging.hivorr.com"

    if ($isControl -or ($isStaff -and $staffEmail)) {
      $allowed = if ($isControl) { $founderEmail } else { $staffEmail }
      $policyName = if ($isControl) { "Founder" } else { "Staff" }
      $policyBody = @{
        name     = $policyName
        decision = "allow"
        include  = @(@{ email = @{ email = $allowed } })
        require  = @()
        exclude  = @()
      } | ConvertTo-Json -Depth 8
    } else {
      $policyBody = @{
        name     = "Closed until identities exist"
        decision = "deny"
        include  = @(@{ everyone = @{} })
        require  = @()
        exclude  = @()
      } | ConvertTo-Json -Depth 8
    }

    $policies = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/apps/$($app.id)/policies" -Headers $headers -Method Get -TimeoutSec 60
    foreach ($policy in @($policies.result)) {
      Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/apps/$($app.id)/policies/$($policy.id)" -Headers $headers -Method Delete -TimeoutSec 60 | Out-Null
    }

    Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$account/access/apps/$($app.id)/policies" -Headers $headers -Method Post -Body $policyBody -TimeoutSec 60 | Out-Null

    if ($isControl) {
      Write-Host "$hostName -> allow $founderEmail" -ForegroundColor Green
    } elseif ($isStaff -and $staffEmail) {
      Write-Host "$hostName -> allow $staffEmail" -ForegroundColor Green
    } else {
      Write-Host "$hostName -> denied for everyone" -ForegroundColor Green
    }
  }

  Write-Host ""
  Write-Host "Done. Control allows $founderEmail; staff allows $staffEmail; partner is closed." -ForegroundColor Green
  Write-Host "Open https://control-staging.hivorr.com in a new incognito window to verify."
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
