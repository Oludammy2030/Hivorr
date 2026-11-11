$ErrorActionPreference = "Stop"
# Windows PowerShell otherwise prepends a UTF-8 BOM to piped native input,
# which corrupts the first KEY in `flyctl secrets import`.
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function Read-SecretText([string]$prompt) {
  $secure = Read-Host $prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

$fly = (Get-Command flyctl -ErrorAction SilentlyContinue).Source
if (-not $fly) {
  $fly = Join-Path $env:LOCALAPPDATA "Programs\flyctl\flyctl.exe"
}
if (-not (Test-Path $fly)) {
  Write-Error "flyctl was not found."
  exit 1
}

$app = "hivorr-staging-api"

Write-Host ""
Write-Host "Hivorr staging password reset" -ForegroundColor Cyan
Write-Host "------------------------------"
Write-Host "This updates one account in the staging database."
Write-Host "The password is sent to Fly as a temporary secret, hashed on the machine,"
Write-Host "and the secret is removed afterwards. It is never printed."
Write-Host ""

$email = (Read-Host "Account email [admin@hivorr.com]").Trim()
if ([string]::IsNullOrWhiteSpace($email)) { $email = "admin@hivorr.com" }

$password = Read-SecretText "New password (12 characters or more)"
$confirm = Read-SecretText "Confirm new password"

if ($password.Length -lt 12) {
  Write-Host "The password must be at least 12 characters." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}
if ($password -ne $confirm) {
  Write-Host "The passwords do not match." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}
if ($password.Contains("`n") -or $password.Contains("`r")) {
  Write-Host "The password must not contain a newline." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

try {
  function Wait-Started {
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
      $machines = (& $fly machine list -a $app --json | ConvertFrom-Json)
      if (-not $machines -or $machines.Count -eq 0) {
        & $fly scale count 1 -a $app --yes | Out-Null
      } elseif ($machines[0].state -eq "started") {
        return $true
      } else {
        & $fly machine start $machines[0].id -a $app | Out-Null
      }
      Start-Sleep -Seconds 3
    }
    return $false
  }

  Write-Host "Starting the API machine ..."
  if (-not (Wait-Started)) { throw "The API machine did not start." }

  Write-Host "Staging the temporary reset values ..."
  $envLines = "RESET_PASSWORD=$password`nRESET_EMAIL=$email`n"
  $secretFile = Join-Path $env:TEMP ("hivorr-reset-" + [guid]::NewGuid().ToString("N") + ".env")
  [IO.File]::WriteAllText($secretFile, $envLines, (New-Object System.Text.UTF8Encoding($false)))
  try {
    cmd /c "`"$fly`" secrets import -a $app < `"$secretFile`""
    if ($LASTEXITCODE -ne 0) { throw "Could not set the temporary secrets." }
  } finally {
    Remove-Item $secretFile -Force -ErrorAction SilentlyContinue
  }
  Start-Sleep -Seconds 3
  Write-Host "Waiting for the API machine to come back ..."
  if (-not (Wait-Started)) { throw "The API machine did not restart after the secret update." }

  $js = @'
const { Client } = require("pg")
const {
  hashPassword,
  verifyPassword,
} = require("/app/server/dist/modules/identity/identity.service.js")

const password = process.env.RESET_PASSWORD
const email = process.env.RESET_EMAIL

;(async () => {
  if (!password || !email) {
    console.error("RESET_PASSWORD or RESET_EMAIL is missing")
    process.exit(1)
  }

  const passwordHash = await hashPassword(password)

  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  })
  await client.connect()
  try {
    const result = await client.query(
      `update identity.credentials c
       set password_hash = $1, failed_attempts = 0, locked_until = null
       from identity.users u
       where u.id = c.user_id and lower(u.email) = lower($2)`,
      [passwordHash, email],
    )
    console.log("credentials_updated=" + result.rowCount)

    console.log(
      "password_hash_verified=" + (await verifyPassword(passwordHash, password)),
    )

    const response = await fetch("http://127.0.0.1:3000/v1/auth/sign-in", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-hivorr-origin-host": "control-staging.hivorr.com",
        "x-hivorr-edge-secret": process.env.EDGE_SHARED_SECRET ?? "",
      },
      body: JSON.stringify({ email, password }),
    })
    console.log("sign_in_status=" + response.status)
  } finally {
    await client.end()
  }
})().catch((error) => {
  console.error("ERR " + error.message)
  process.exit(1)
})
'@

  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($js))
  $chunkLines = @("cd /app", "rm -f /tmp/reset.b64")
  for ($offset = 0; $offset -lt $b64.Length; $offset += 300) {
    $chunk = $b64.Substring($offset, [Math]::Min(300, $b64.Length - $offset))
    $operator = if ($offset -eq 0) { ">" } else { ">>" }
    $chunkLines += "echo $chunk $operator /tmp/reset.b64"
  }
  $chunkLines += "base64 -d /tmp/reset.b64 > /app/reset.js"
  $chunkLines += "node /app/reset.js"
  $chunkLines += "rm -f /app/reset.js /tmp/reset.b64"
  $chunkLines += "exit"
  $commands = ($chunkLines -join "`n") + "`n"

  $inputFile = Join-Path $env:TEMP ("hivorr-ssh-" + [guid]::NewGuid().ToString("N") + ".txt")
  $outFile = Join-Path $env:TEMP ("hivorr-ssh-out-" + [guid]::NewGuid().ToString("N") + ".log")
  $errFile = Join-Path $env:TEMP ("hivorr-ssh-err-" + [guid]::NewGuid().ToString("N") + ".log")
  [IO.File]::WriteAllText($inputFile, $commands, (New-Object System.Text.UTF8Encoding($false)))
  $outputText = ""
  try {
    Start-Process -FilePath $fly -ArgumentList @("ssh", "console", "-a", $app) `
      -RedirectStandardInput $inputFile `
      -RedirectStandardOutput $outFile `
      -RedirectStandardError $errFile `
      -NoNewWindow -Wait | Out-Null
    $outputText = [IO.File]::ReadAllText($outFile) + "`n" + [IO.File]::ReadAllText($errFile)
  } finally {
    Remove-Item $inputFile, $outFile, $errFile -Force -ErrorAction SilentlyContinue
  }
  $output = $outputText -split "`n"

  $output | Select-String "credentials_updated=|password_hash_verified=|sign_in_status=|ERR " | ForEach-Object { $_.Line }
  if (-not (($output -join "`n") -match "credentials_updated=")) {
    $output | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
  }

  if (-not ($output -match "credentials_updated=1")) {
    throw "The update did not affect exactly one account."
  }
  if (-not ($output -match "password_hash_verified=true")) {
    throw "The stored hash does not verify against the new password."
  }
  if (-not ($output -match "sign_in_status=(200|202)")) {
    throw "The local sign-in check did not accept the new password."
  }

  Write-Host ""
  Write-Host "Password updated." -ForegroundColor Green
  Write-Host "Sign in at https://control-staging.hivorr.com with:"
  Write-Host "  Email:    $email"
  Write-Host "  Password: the new one you just entered"
  Write-Host "  Code:     the current authenticator code"
} catch {
  Write-Host "Reset failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
  Write-Host "Removing the temporary secrets ..."
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & $fly secrets unset RESET_PASSWORD RESET_EMAIL -a $app 2>&1 | Out-Null
  $ErrorActionPreference = $previousPreference
  $password = $null
  $confirm = $null
  Remove-Variable password, confirm, envLines -ErrorAction SilentlyContinue
}

Read-Host "Press Enter to close"
