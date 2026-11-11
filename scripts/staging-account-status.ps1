$ErrorActionPreference = "Stop"

$fly = (Get-Command flyctl -ErrorAction SilentlyContinue).Source
if (-not $fly) { $fly = Join-Path $env:LOCALAPPDATA "Programs\flyctl\flyctl.exe" }
if (-not (Test-Path $fly)) { throw "flyctl was not found." }

$app = "hivorr-staging-api"

for ($attempt = 0; $attempt -lt 30; $attempt++) {
  $machines = (& $fly machine list -a $app --json | ConvertFrom-Json)
  if (-not $machines -or $machines.Count -eq 0) {
    & $fly scale count 1 -a $app --yes | Out-Null
  } elseif ($machines[0].state -eq "started") {
    break
  } else {
    & $fly machine start $machines[0].id -a $app | Out-Null
  }
  Start-Sleep -Seconds 3
}

$js = @'
const { Client } = require("pg")

;(async () => {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  })
  await client.connect()
  try {
    const result = await client.query(
      `select u.email, u.status,
              (select count(*) from identity.mfa_factors f
               where f.user_id = u.id and f.confirmed_at is not null) as confirmed_factors,
              (select count(*) from identity.credentials c where c.user_id = u.id) as credentials,
              c.failed_attempts, c.locked_until
       from identity.users u
       join identity.credentials c on c.user_id = u.id
       order by u.created_at desc
       limit 5`,
    )
    if (result.rowCount === 0) console.log("no_users")
    for (const row of result.rows) {
      console.log(
        "email=" + row.email +
        " status=" + row.status +
        " credentials=" + row.credentials +
        " confirmed_factors=" + row.confirmed_factors +
        " failed_attempts=" + row.failed_attempts +
        " locked_until=" + row.locked_until,
      )
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
$chunkLines = @("cd /app", "rm -f /tmp/status.b64")
for ($offset = 0; $offset -lt $b64.Length; $offset += 300) {
  $chunk = $b64.Substring($offset, [Math]::Min(300, $b64.Length - $offset))
  $operator = if ($offset -eq 0) { ">" } else { ">>" }
  $chunkLines += "echo $chunk $operator /tmp/status.b64"
}
$chunkLines += "base64 -d /tmp/status.b64 > /app/status.js"
$chunkLines += "node /app/status.js"
$chunkLines += "rm -f /app/status.js /tmp/status.b64"
$chunkLines += "exit"
$commands = ($chunkLines -join "`n") + "`n"

$inputFile = Join-Path $env:TEMP ("hivorr-status-" + [guid]::NewGuid().ToString("N") + ".txt")
$outFile = Join-Path $env:TEMP ("hivorr-status-out-" + [guid]::NewGuid().ToString("N") + ".log")
$errFile = Join-Path $env:TEMP ("hivorr-status-err-" + [guid]::NewGuid().ToString("N") + ".log")
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

$output -split "`n" | Select-String "email=|no_users|ERR " | ForEach-Object { $_.Line }
