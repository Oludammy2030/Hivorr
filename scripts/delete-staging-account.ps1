param(
  [string]$Email = "admin@hivorr.com",
  [switch]$Yes
)

$ErrorActionPreference = "Stop"

$fly = (Get-Command flyctl -ErrorAction SilentlyContinue).Source
if (-not $fly) {
  $fly = Join-Path $env:LOCALAPPDATA "Programs\flyctl\flyctl.exe"
}
if (-not (Test-Path $fly)) { throw "flyctl was not found." }

$app = "hivorr-staging-api"

if (-not $Yes) {
  Write-Host "This deletes the staging account $Email and its credentials, TOTP factors,"
  Write-Host "sessions, tokens and memberships. The audit log is retained."
  $answer = Read-Host "Type DELETE to continue"
  if ($answer -ne "DELETE") {
    Write-Host "Cancelled."
    exit 0
  }
}

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

if (-not (Wait-Started)) { throw "The API machine did not start." }

$js = @'
const { Client } = require("pg")

const email = process.env.DELETE_EMAIL

;(async () => {
  if (!email) {
    console.error("DELETE_EMAIL is missing")
    process.exit(1)
  }

  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  })
  await client.connect()

  try {
    const found = await client.query(
      "select id, account_id from identity.users where lower(email) = lower($1)",
      [email],
    )
    if (found.rowCount === 0) {
      console.log("account_not_found")
      return
    }

    const userId = found.rows[0].id
    const accountId = found.rows[0].account_id

    await client.query("begin")
    try {
      await client.query("delete from identity.memberships where user_id = $1", [userId])
      const users = await client.query(
        "delete from identity.users where id = $1",
        [userId],
      )
      const accounts = await client.query(
        `delete from identity.accounts
         where id = $1
           and not exists (select 1 from identity.users where account_id = $1)`,
        [accountId],
      )
      await client.query("commit")
      console.log(
        "deleted_users=" + users.rowCount + " deleted_accounts=" + accounts.rowCount,
      )
    } catch (error) {
      await client.query("rollback")
      throw error
    }
  } finally {
    await client.end()
  }
})().catch((error) => {
  console.error("ERR " + error.message)
  process.exit(1)
})
'@

$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($js))
$chunkLines = @("cd /app", "rm -f /tmp/delete.b64")
for ($offset = 0; $offset -lt $b64.Length; $offset += 300) {
  $chunk = $b64.Substring($offset, [Math]::Min(300, $b64.Length - $offset))
  $operator = if ($offset -eq 0) { ">" } else { ">>" }
  $chunkLines += "echo $chunk $operator /tmp/delete.b64"
}
$chunkLines += "base64 -d /tmp/delete.b64 > /app/delete.js"
$chunkLines += "DELETE_EMAIL=$Email node /app/delete.js"
$chunkLines += "rm -f /app/delete.js /tmp/delete.b64"
$chunkLines += "exit"
$commands = ($chunkLines -join "`n") + "`n"

$inputFile = Join-Path $env:TEMP ("hivorr-delete-" + [guid]::NewGuid().ToString("N") + ".txt")
$outFile = Join-Path $env:TEMP ("hivorr-delete-out-" + [guid]::NewGuid().ToString("N") + ".log")
$errFile = Join-Path $env:TEMP ("hivorr-delete-err-" + [guid]::NewGuid().ToString("N") + ".log")
[IO.File]::WriteAllText($inputFile, $commands, (New-Object System.Text.UTF8Encoding($false)))

try {
  Start-Process -FilePath $fly -ArgumentList @("ssh", "console", "-a", $app) `
    -RedirectStandardInput $inputFile `
    -RedirectStandardOutput $outFile `
    -RedirectStandardError $errFile `
    -NoNewWindow -Wait | Out-Null
  $output = [IO.File]::ReadAllText($outFile) + "`n" + [IO.File]::ReadAllText($errFile)
} finally {
  Remove-Item $inputFile, $outFile, $errFile -Force -ErrorAction SilentlyContinue
}

$output -split "`n" | Select-String "deleted_users=|account_not_found|ERR " | ForEach-Object { $_.Line }
Write-Host "--- remote output ---"
$output -split "`n" | Select-Object -Last 12 | ForEach-Object { Write-Host $_ }
