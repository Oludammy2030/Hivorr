param(
  [string]$Email = "admin@hivorr.com"
)

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

const email = process.env.BOOTSTRAP_EMAIL
const scopes = ["admin.grant.manage", "admin.grant.read", "admin.audit.read"]

;(async () => {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  })
  await client.connect()
  try {
    const user = await client.query(
      "select id from identity.users where lower(email) = lower($1)",
      [email],
    )
    if (user.rowCount === 0) {
      console.log("user_not_found")
      return
    }
    const userId = user.rows[0].id
    let inserted = 0
    for (const scope of scopes) {
      const result = await client.query(
        `insert into identity.grants (user_id, grant_type, scope, environment, granted_by)
         select $1, 'admin', $2, 'staging', null
         where not exists (
           select 1 from identity.grants
           where user_id = $1 and scope = $2 and environment = 'staging' and revoked_at is null
         )`,
        [userId, scope],
      )
      inserted += result.rowCount
    }
    console.log("admin_grants_inserted=" + inserted)
    const role = await client.query(
      "select id from admin.roles where key = 'founder'",
    )
    if (role.rowCount === 0) {
      console.log("founder_role_missing")
      return
    }
    const assignment = await client.query(
      `insert into admin.role_assignments
         (user_id, role_id, scope_type, granted_by, reason)
       select $1, $2, 'platform', null, 'Founder bootstrap'
       where not exists (
         select 1 from admin.role_assignments
         where user_id = $1 and role_id = $2 and scope_type = 'platform'
           and revoked_at is null
       )`,
      [userId, role.rows[0].id],
    )
    console.log("founder_role_assignments_inserted=" + assignment.rowCount)
  } finally {
    await client.end()
  }
})().catch((error) => {
  console.error("ERR " + error.message)
  process.exit(1)
})
'@

$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($js))
$chunkLines = @("cd /app", "rm -f /tmp/bootstrap.b64")
for ($offset = 0; $offset -lt $b64.Length; $offset += 300) {
  $chunk = $b64.Substring($offset, [Math]::Min(300, $b64.Length - $offset))
  $operator = if ($offset -eq 0) { ">" } else { ">>" }
  $chunkLines += "echo $chunk $operator /tmp/bootstrap.b64"
}
$chunkLines += "base64 -d /tmp/bootstrap.b64 > /app/bootstrap.js"
$chunkLines += "BOOTSTRAP_EMAIL=$Email node /app/bootstrap.js"
$chunkLines += "rm -f /app/bootstrap.js /tmp/bootstrap.b64"
$chunkLines += "exit"
$commands = ($chunkLines -join "`n") + "`n"

$inputFile = Join-Path $env:TEMP ("hivorr-bootstrap-" + [guid]::NewGuid().ToString("N") + ".txt")
$outFile = Join-Path $env:TEMP ("hivorr-bootstrap-out-" + [guid]::NewGuid().ToString("N") + ".log")
$errFile = Join-Path $env:TEMP ("hivorr-bootstrap-err-" + [guid]::NewGuid().ToString("N") + ".log")
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

$output -split "`n" | Select-String "admin_grants_inserted=|founder_role_assignments_inserted=|founder_role_missing|user_not_found|ERR " | ForEach-Object { $_.Line }
