#!/usr/bin/env node
// Apply forward-only SQL migrations to one database.
//
// Usage:
//   DATABASE_URL=... node scripts/apply-migrations.mjs
//
// Properties:
// - an advisory lock prevents two runners applying at once;
// - each file runs in its own transaction and is recorded only on success;
// - an already-applied file whose checksum changed is a refusal, never a
//   silent re-run;
// - the applied set and checksums live in platform.schema_migrations.
//
// This is the CI/deployment path. It never prints the connection string.

import { createHash } from "node:crypto"
import { lookup } from "node:dns/promises"
import { readdirSync, readFileSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"

const LOCK_KEY = 72_700_100
const databaseUrl = process.env.DATABASE_URL?.trim()

if (!databaseUrl) {
  console.error("apply-migrations: DATABASE_URL is required")
  process.exit(2)
}

if (!/^postgres(ql)?:\/\//i.test(databaseUrl)) {
  console.error(
    "apply-migrations: DATABASE_URL must be the full postgresql:// URI, not a password or a parameter list",
  )
  process.exit(2)
}

function isLocalHost(value) {
  try {
    const host = new URL(value).hostname
    return host === "127.0.0.1" || host === "localhost"
  } catch {
    return false
  }
}

const migrationsDir = path.join(process.cwd(), "supabase", "migrations")
const files = readdirSync(migrationsDir)
  .filter((file) => file.endsWith(".sql"))
  .sort()

if (files.length === 0) {
  console.error("apply-migrations: no migrations found")
  process.exit(2)
}

// Supabase's direct database host is IPv6-first. GitHub runners have no IPv6
// route, so resolve an IPv4 address explicitly and keep the original hostname
// as the TLS server name. A local container stays on loopback without TLS.
function connectionOptions(value) {
  const parsed = new URL(value)
  return {
    host: parsed.hostname,
    port: Number(parsed.port || 5432),
    user: decodeURIComponent(parsed.username),
    password: decodeURIComponent(parsed.password),
    database: parsed.pathname.replace(/^\//, "") || "postgres",
  }
}

const connection = connectionOptions(databaseUrl)
let ssl

if (!isLocalHost(databaseUrl)) {
  ssl = { rejectUnauthorized: true, servername: connection.host }
  try {
    const resolved = await lookup(connection.host, { family: 4 })
    connection.host = resolved.address
  } catch {
    throw new Error(
      `no IPv4 address for ${connection.host}; use the Supabase session pooler connection string`,
    )
  }
}

const client = new Client({
  ...connection,
  application_name: "hivorr-migrator",
  ssl,
})

let locked = false

try {
  await client.connect()
  await client.query("select pg_advisory_lock($1)", [LOCK_KEY])
  locked = true

  await client.query("create schema if not exists platform")
  await client.query(`
    create table if not exists platform.schema_migrations (
      filename text primary key,
      checksum text not null,
      applied_at timestamptz not null default now()
    )
  `)

  const applied = new Map(
    (
      await client.query(
        "select filename, checksum from platform.schema_migrations",
      )
    ).rows.map((row) => [row.filename, row.checksum]),
  )

  let count = 0
  for (const file of files) {
    const sql = readFileSync(path.join(migrationsDir, file), "utf8")
    const checksum = createHash("sha256").update(sql).digest("hex")

    if (applied.has(file)) {
      if (applied.get(file) !== checksum) {
        throw new Error(
          `${file} changed after it was applied; add a new migration instead`,
        )
      }
      continue
    }

    await client.query("begin")
    try {
      await client.query(sql)
      await client.query(
        "insert into platform.schema_migrations (filename, checksum) values ($1, $2)",
        [file, checksum],
      )
      await client.query("commit")
    } catch (error) {
      await client.query("rollback")
      throw error
    }

    console.log(`apply-migrations: applied ${file}`)
    count += 1
  }

  console.log(
    `apply-migrations: OK — ${count} applied, ${files.length - count} already present`,
  )
} catch (error) {
  console.error(
    `apply-migrations: FAILED — ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exitCode = 1
} finally {
  if (locked) {
    await client
      .query("select pg_advisory_unlock($1)", [LOCK_KEY])
      .catch(() => undefined)
  }
  await client.end().catch(() => undefined)
}
