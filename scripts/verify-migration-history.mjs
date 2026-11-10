#!/usr/bin/env node
// Verify that every migration file is recorded in platform.schema_migrations
// with the checksum it had when it was applied. This proves the runner's
// history is complete and that no applied file was edited afterwards.
//
// Usage:
//   DATABASE_URL=... node scripts/verify-migration-history.mjs
//
// The connection is never printed.

import { readdirSync, readFileSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"

import {
  migrationChecksum,
  verifyMigrationHistory,
} from "./lib/migration-history.mjs"

const databaseUrl = process.env.DATABASE_URL?.trim()
if (!databaseUrl) {
  console.error("migrations:verify: DATABASE_URL is required")
  process.exit(2)
}

const migrationsDirectory = path.join(process.cwd(), "supabase", "migrations")
const files = readdirSync(migrationsDirectory)
  .filter((file) => file.endsWith(".sql"))
  .sort()
  .map((filename) => ({
    filename,
    checksum: migrationChecksum(
      readFileSync(path.join(migrationsDirectory, filename), "utf8"),
    ),
  }))

const local = /^(?:127\.0\.0\.1|localhost)$/i.test(
  new URL(databaseUrl).hostname,
)
const ca = process.env.DATABASE_SSL_CA?.replace(/\\n/g, "\n")
const ssl = local
  ? undefined
  : ca
    ? { ca, rejectUnauthorized: true }
    : { rejectUnauthorized: false }

const client = new Client({
  connectionString: databaseUrl,
  connectionTimeoutMillis: 5_000,
  application_name: "hivorr-migration-history",
  ssl,
})

try {
  await client.connect()
  const result = await client.query(
    "select filename, checksum from platform.schema_migrations order by filename",
  )
  const verdict = verifyMigrationHistory({ files, applied: result.rows })

  if (!verdict.ok) {
    console.error("migrations:verify: REFUSED")
    for (const issue of verdict.issues) console.error(`- ${issue}`)
    process.exitCode = 1
  } else {
    console.log(
      `migrations:verify: OK - ${verdict.applied} applied, ${verdict.files} file(s)`,
    )
  }
} catch (error) {
  console.error(
    `migrations:verify: FAILED - ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exitCode = 1
} finally {
  await client.end().catch(() => undefined)
}
