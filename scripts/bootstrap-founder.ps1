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

function Show-ApiError($errorRecord) {
  $status = $null
  if ($errorRecord.Exception.Response) {
    $status = $errorRecord.Exception.Response.StatusCode.value__
  }
  if ($errorRecord.ErrorDetails.Message) {
    Write-Host "API error ($status): $($errorRecord.ErrorDetails.Message)" -ForegroundColor Red
  } else {
    Write-Host "Request failed ($status): $($errorRecord.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "Hivorr founder bootstrap" -ForegroundColor Cyan
Write-Host "------------------------"
Write-Host "Creates the main-portal account, enrols TOTP, and prints recovery codes."
Write-Host "The control portal requires this factor before it will sign you in."
Write-Host ""

$origin = "https://staging.hivorr.com"
Write-Host "Portal: $origin" -ForegroundColor Cyan

$email = (Read-Host "Founder email").Trim()
if ([string]::IsNullOrWhiteSpace($email)) {
  Write-Host "An email is required." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

$password = Read-SecretText "Password (12 characters or more)"
$jsonHeaders = @{ "Content-Type" = "application/json" }

try {
  Write-Host ""
  Write-Host "Registering $email ..."
  $registerBody = @{
    email       = $email
    password    = $password
    displayName = "Founder"
  } | ConvertTo-Json

  try {
    Invoke-RestMethod -Uri "$origin/api/v1/auth/register" -Method Post -Headers $jsonHeaders -Body $registerBody -TimeoutSec 45 | Out-Null
    Write-Host "Account created." -ForegroundColor Green
  } catch {
    $status = $null
    if ($_.Exception.Response) { $status = $_.Exception.Response.StatusCode.value__ }
    if ($status -eq 409) {
      Write-Host "Account already exists; continuing." -ForegroundColor Yellow
    } else {
      Show-ApiError $_
      throw
    }
  }

  Write-Host "Signing in on the main portal ..."
  $signInBody = @{ email = $email; password = $password } | ConvertTo-Json
  $signIn = Invoke-RestMethod -Uri "$origin/api/v1/auth/sign-in" -Method Post -Headers $jsonHeaders -Body $signInBody -SessionVariable webSession -TimeoutSec 45

  if ($signIn.mfaRequired) {
    Write-Host ""
    Write-Host "This account already has a confirmed authenticator." -ForegroundColor Yellow
    Write-Host "Sign in at the control portal with that code."
    Read-Host "Press Enter to close"
    exit 0
  }

  Write-Host "Enrolling the authenticator ..."
  $enrollment = Invoke-RestMethod -Uri "$origin/api/v1/auth/mfa/totp/enroll" -Method Post -WebSession $webSession -Headers $jsonHeaders -Body "{}" -TimeoutSec 45

  Write-Host ""
  Write-Host "Add this to your authenticator app now." -ForegroundColor Cyan
  Write-Host "Use 'Enter a setup key' if the app cannot open the URI."
  Write-Host ""
  Write-Host "Secret: $($enrollment.secret)" -ForegroundColor Yellow
  Write-Host "URI:    $($enrollment.otpauthUri)"
  Write-Host ""
  Write-Host "Save the secret in your password manager before continuing." -ForegroundColor Yellow
  Write-Host ""

  $code = (Read-Host "Enter the current 6-digit code").Trim()
  if ($code -notmatch "^\d{6}$") {
    Write-Host "That is not a 6-digit code. The factor was not confirmed." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
  }

  $confirmBody = @{ factorId = $enrollment.factorId; code = $code } | ConvertTo-Json
  $confirmed = Invoke-RestMethod -Uri "$origin/api/v1/auth/mfa/totp/confirm" -Method Post -WebSession $webSession -Headers $jsonHeaders -Body $confirmBody -TimeoutSec 45

  Write-Host ""
  Write-Host "Authenticator confirmed." -ForegroundColor Green
  Write-Host ""
  Write-Host "Recovery codes. Save these in your password manager now." -ForegroundColor Cyan
  Write-Host "Each code works once. The window will not show them again."
  Write-Host ""
  foreach ($recoveryCode in $confirmed.recoveryCodes) {
    Write-Host "  $recoveryCode"
  }
  Write-Host ""

  try {
    Invoke-RestMethod -Uri "$origin/api/v1/auth/sign-out" -Method Post -WebSession $webSession -Headers $jsonHeaders -TimeoutSec 30 | Out-Null
  } catch {
    Write-Host "Sign-out failed; close the browser session if needed." -ForegroundColor Yellow
  }

  Write-Host "Done." -ForegroundColor Green
  Write-Host "Sign in at https://control-staging.hivorr.com with the password and the 6-digit code."
  Write-Host "Clear this window after saving the secret and recovery codes."
} catch {
  Show-ApiError $_
} finally {
  $password = $null
  Remove-Variable password, webSession, enrollment -ErrorAction SilentlyContinue
}

Read-Host "Press Enter to close"
