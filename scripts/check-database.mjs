#!/usr/bin/env node
// Validate the database connection and role for the current environment.
//
// This is the connection check EP-01-020 needs: it proves the URL reaches a
// database, reports the role actually in use, and refuses a remote
// staging/production connection that is not TLS. It never prints the URL or a
// credential.
//
// Usage:
//   DATABASE_URL=... node scripts/check-database.mjs
//   DATABASE_URL=... node scripts/check-database.mjs --expect-role hivorr_api
//   DATABASE_URL=... node scripts/check-database.mjs --expect-major 17
//
// Exit codes: 2 = missing configuration, 1 = check failed, 0 = ok.

import { Client } from "pg"

const args = process.argv.slice(2)
let expectedRole = ""
let expectedMajor = 0

for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--expect-role" && args[index + 1]) {
    expectedRole = args[index + 1]
    index += 1
  } else if (args[index] === "--expect-major" && args[index + 1]) {
    expectedMajor = Number(args[index + 1])
    index += 1
  }
}

const url = process.env.DATABASE_URL
if (!url) {
  console.error("db:check: DATABASE_URL is not set")
  process.exit(2)
}

const environment = process.env.HIVORR_ENV ?? "development"
const remote = environment === "staging" || environment === "production"
const ca = process.env.DATABASE_SSL_CA
const ssl = remote
  ? ca
    ? { ca, rejectUnauthorized: true }
    : { rejectUnauthorized: false }
  : undefined

function fail(message) {
  console.error(`db:check: FAILED - ${message}`)
  process.exitCode = 1
}

const client = new Client({
  connectionString: url,
  connectionTimeoutMillis: 5_000,
  application_name: "hivorr-db-check",
  ssl,
})

try {
  await client.connect()

  const identity = await client.query(
    `select current_database() as database,
            current_user as role,
            current_setting('server_version_num')::int as version
     from (select 1) as probe`,
  )
  const row = identity.rows[0]
  if (!row) throw new Error("the database returned no identity row")

  let tls = false
  try {
    const sslRow = await client.query(
      "select coalesce((select ssl from pg_stat_ssl where pid = pg_backend_pid()), false) as ssl",
    )
    tls = sslRow.rows[0]?.ssl === true
  } catch {
    // pg_stat_ssl is optional; the role may not read it.
    tls = false
  }

  if (!row.database || !row.role) {
    fail("the connection did not report a database and role")
  }

  if (expectedRole && row.role !== expectedRole) {
    fail(`expected role ${expectedRole}, connected as ${row.role}`)
  }

  if (remote && !tls) {
    fail("staging and production connections must use TLS")
  }

  if (expectedMajor > 0) {
    const major = Math.floor(Number(row.version) / 10_000)
    if (major !== expectedMajor) {
      fail(`expected PostgreSQL major ${expectedMajor}, found ${major}`)
    }
  }

  if (process.exitCode) {
    console.error(
      `db:check: identity database=${row.database} role=${row.role} tls=${tls}`,
    )
  } else {
    console.log(
      `db:check: OK - database=${row.database} role=${row.role} tls=${tls} server=${row.version}`,
    )
  }
} catch (error) {
  fail(error instanceof Error ? error.message : String(error))
} finally {
  await client.end().catch(() => undefined)
}
