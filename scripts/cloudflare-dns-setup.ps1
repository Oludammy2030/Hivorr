$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Hivorr staging DNS setup" -ForegroundColor Cyan
Write-Host "------------------------"
Write-Host "Create a Cloudflare API token with:"
Write-Host "  Zone -> DNS -> Edit"
Write-Host "  Zone -> Zone -> Read"
Write-Host "  Zone Resources: Include -> hivorr.com"
Write-Host ""
Write-Host "Paste the token below. Input is hidden and the token is not saved."
Write-Host ""

$secure = Read-Host "Cloudflare API token" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$headers = @{
  Authorization  = "Bearer $token"
  Accept         = "application/json"
  "Content-Type" = "application/json"
}

try {
  $zones = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones?name=hivorr.com" -Headers $headers -Method Get -TimeoutSec 60
  if (-not $zones.result -or $zones.result.Count -eq 0) {
    throw "The token cannot see the hivorr.com zone."
  }
  $zone = $zones.result[0].id

  $records = @(
    @{ name = "staging"; target = "hivorr-staging-main.pages.dev" },
    @{ name = "control-staging"; target = "hivorr-staging-control.pages.dev" },
    @{ name = "staff-staging"; target = "hivorr-staging-staff.pages.dev" },
    @{ name = "partner-staging"; target = "hivorr-staging-partner.pages.dev" }
  )

  foreach ($record in $records) {
    $fqdn = "$($record.name).hivorr.com"
    $existing = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zone/dns_records?type=CNAME&name=$fqdn" -Headers $headers -Method Get -TimeoutSec 60
    $body = @{
      type    = "CNAME"
      name    = $fqdn
      content = $record.target
      proxied = $true
      ttl     = 1
    } | ConvertTo-Json

    if ($existing.result.Count -gt 0) {
      $id = $existing.result[0].id
      Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zone/dns_records/$id" -Headers $headers -Method Put -Body $body -TimeoutSec 60 | Out-Null
      Write-Host "updated $fqdn -> $($record.target)" -ForegroundColor Green
    } else {
      Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zone/dns_records" -Headers $headers -Method Post -Body $body -TimeoutSec 60 | Out-Null
      Write-Host "created $fqdn -> $($record.target)" -ForegroundColor Green
    }
  }

  Write-Host ""
  Write-Host "Done. DNS can take a minute or two to resolve." -ForegroundColor Green
} catch {
  Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
  if ($_.ErrorDetails.Message) {
    Write-Host $_.ErrorDetails.Message
  }
} finally {
  $token = $null
  $secure = $null
  Remove-Variable token, secure, headers -ErrorAction SilentlyContinue
}

Read-Host "Press Enter to close"
