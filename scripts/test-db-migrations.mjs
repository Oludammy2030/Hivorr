#!/usr/bin/env node
// Apply every migration to a temporary database, assert the foundation, and
// drop the database. This proves the SQL is self-contained and repeatable.
//
// Local default: the fresh Supabase container on 127.0.0.1:54322.
// CI: set DATABASE_URL to the postgres service.

import { readdirSync, readFileSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"

const baseUrl =
  process.env.DATABASE_URL ??
  "postgres://postgres:postgres@127.0.0.1:54322/postgres"
const migrationsDirectory = path.join(process.cwd(), "supabase", "migrations")
const databaseName = `hivorr_migration_test_${Date.now()}`
const admin = new Client({ connectionString: baseUrl })
let testClient

function assert(condition, message) {
  if (!condition) throw new Error(`database assertion failed: ${message}`)
}

try {
  await admin.connect()
  await admin.query(`create database "${databaseName}"`)

  const url = new URL(baseUrl)
  url.pathname = `/${databaseName}`
  testClient = new Client({ connectionString: url.toString() })
  await testClient.connect()

  const files = readdirSync(migrationsDirectory)
    .filter((file) => file.endsWith(".sql"))
    .sort()

  for (const file of files) {
    const sql = readFileSync(path.join(migrationsDirectory, file), "utf8")
    await testClient.query(sql)
    console.log(`database: applied ${file}`)
  }

  const requiredSchemas = [
    "identity",
    "profile",
    "market",
    "services",
    "errands",
    "logistics",
    "finance",
    "messaging",
    "admin",
    "platform",
    "private",
  ]
  const schemas = await testClient.query(
    "select nspname from pg_namespace where nspname = any($1::text[])",
    [requiredSchemas],
  )
  assert(
    schemas.rowCount === requiredSchemas.length,
    "all module schemas exist",
  )

  const tables = await testClient.query(
    "select tablename from pg_tables where schemaname = 'platform'",
  )
  const tableNames = new Set(tables.rows.map((row) => row.tablename))
  for (const table of [
    "audit_log",
    "outbox",
    "idempotency_keys",
    "feature_flags",
    "reference_counters",
  ]) {
    assert(tableNames.has(table), `platform.${table} exists`)
  }

  await testClient.query(
    "insert into platform.audit_log (actor_type, environment, action) values ('system', 'test', 'test.action')",
  )
  let appendOnly = false
  try {
    await testClient.query(
      "update platform.audit_log set action = 'changed' where action = 'test.action'",
    )
  } catch {
    appendOnly = true
  }
  assert(appendOnly, "audit_log rejects updates")

  await testClient.query(
    "insert into platform.outbox (event_type, aggregate_type, aggregate_id) values ('test.event', 'test', 'aggregate')",
  )
  const pending = await testClient.query(
    "select count(*)::int as count from platform.outbox where processed_at is null",
  )
  assert(pending.rows[0].count === 1, "outbox accepts a pending event")

  const apiInsert = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.audit_log', 'insert') as allowed",
  )
  assert(
    apiInsert.rows[0].allowed === true,
    "api role may append audit records",
  )
  const apiUpdate = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.audit_log', 'update') as allowed",
  )
  assert(
    apiUpdate.rows[0].allowed === false,
    "api role cannot update audit records",
  )

  const roleLogin = await testClient.query(
    "select rolname, rolcanlogin from pg_roles where rolname like 'hivorr_%'",
  )
  assert(roleLogin.rowCount === 5, "five application roles exist")
  assert(
    roleLogin.rows.every((row) => row.rolcanlogin === false),
    "application roles cannot log in directly",
  )

  console.log(
    "database: OK — schemas, platform tables, roles, and append-only audit verified",
  )
} finally {
  if (testClient) await testClient.end()
  if (admin) {
    await admin.query(`drop database if exists "${databaseName}" with (force)`)
    await admin.end()
  }
}
