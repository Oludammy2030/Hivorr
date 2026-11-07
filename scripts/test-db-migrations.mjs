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

  const identityTables = await testClient.query(
    "select tablename from pg_tables where schemaname = 'identity'",
  )
  const identityTableNames = new Set(
    identityTables.rows.map((row) => row.tablename),
  )
  for (const table of [
    "accounts",
    "users",
    "credentials",
    "memberships",
    "grants",
    "devices",
    "sessions",
    "mfa_factors",
    "recovery_codes",
    "tokens",
  ]) {
    assert(identityTableNames.has(table), `identity.${table} exists`)
  }

  const uuid = await testClient.query(
    "select substring(platform.uuidv7()::text, 15, 1) as version, substring(platform.uuidv7()::text, 20, 1) as variant",
  )
  assert(uuid.rows[0].version === "7", "uuidv7 version nibble is 7")
  assert(
    ["8", "9", "a", "b"].includes(uuid.rows[0].variant),
    "uuidv7 variant nibble is RFC 9562",
  )

  const account = await testClient.query(
    "insert into identity.accounts default values returning id",
  )
  const accountId = account.rows[0].id
  const user = await testClient.query(
    "insert into identity.users (account_id, email) values ($1, $2) returning id",
    [accountId, "founder@example.test"],
  )
  const userId = user.rows[0].id
  await testClient.query(
    "insert into identity.credentials (user_id, password_hash) values ($1, $2)",
    [userId, "argon2id-placeholder"],
  )
  await testClient.query(
    "insert into identity.memberships (user_id, account_id, role) values ($1, $2, 'owner')",
    [userId, accountId],
  )
  await testClient.query(
    "insert into identity.sessions (user_id, audience, environment, refresh_token_hash, idle_expires_at, expires_at) values ($1, 'app', 'test', $2, now() + interval '30 minutes', now() + interval '12 hours')",
    [userId, "refresh-hash-test"],
  )
  await testClient.query(
    "insert into identity.grants (user_id, grant_type, scope, environment) values ($1, 'admin', 'admin.audit.read', 'test')",
    [userId],
  )

  let duplicateEmailRejected = false
  try {
    await testClient.query(
      "insert into identity.users (account_id, email) values ($1, $2)",
      [accountId, "FOUNDER@example.test"],
    )
  } catch {
    duplicateEmailRejected = true
  }
  assert(duplicateEmailRejected, "email uniqueness is case-insensitive")

  let invalidAudienceRejected = false
  try {
    await testClient.query(
      "insert into identity.sessions (user_id, audience, environment, refresh_token_hash, idle_expires_at, expires_at) values ($1, 'admin', 'test', $2, now(), now())",
      [userId, "invalid-audience-hash"],
    )
  } catch {
    invalidAudienceRejected = true
  }
  assert(invalidAudienceRejected, "session audience is constrained")

  const identityAccess = await testClient.query(
    "select has_table_privilege('hivorr_api', 'identity.users', 'select') as allowed",
  )
  assert(
    identityAccess.rows[0].allowed === true,
    "api role may read identity users",
  )

  const secondAccount = await testClient.query(
    "insert into identity.accounts default values returning id",
  )
  const secondAccountId = secondAccount.rows[0].id
  const secondUser = await testClient.query(
    "insert into identity.users (account_id, email) values ($1, $2) returning id",
    [secondAccountId, "other@example.test"],
  )
  const secondUserId = secondUser.rows[0].id

  await testClient.query("grant hivorr_api to postgres with set true")
  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [
    accountId,
    userId,
  ])
  const ownUsers = await testClient.query(
    "select count(*)::int as count from identity.users",
  )
  assert(
    ownUsers.rows[0].count === 1,
    "rls shows only the current account's users",
  )
  const ownCredentials = await testClient.query(
    "select count(*)::int as count from identity.credentials",
  )
  assert(
    ownCredentials.rows[0].count === 1,
    "rls shows only the current user's credential",
  )
  const crossAccountUpdate = await testClient.query(
    "update identity.users set display_name = 'blocked' where id = $1",
    [secondUserId],
  )
  assert(crossAccountUpdate.rowCount === 0, "rls blocks a cross-account update")
  const lookup = await testClient.query(
    "select user_id, account_id from identity.find_login_credential('founder@example.test')",
  )
  assert(lookup.rowCount === 1, "pre-auth lookup returns one credential")
  assert(
    lookup.rows[0].user_id === userId,
    "pre-auth lookup returns the right user",
  )
  await testClient.query("reset role")
  await testClient.query("commit")

  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  const noContext = await testClient.query(
    "select count(*)::int as count from identity.users",
  )
  assert(
    noContext.rows[0].count === 0,
    "rls denies without an identity context",
  )
  await testClient.query("reset role")
  await testClient.query("commit")

  const roleLogin = await testClient.query(
    "select rolname, rolcanlogin from pg_roles where rolname like 'hivorr_%'",
  )
  assert(roleLogin.rowCount === 5, "five application roles exist")
  assert(
    roleLogin.rows.every((row) => row.rolcanlogin === false),
    "application roles cannot log in directly",
  )

  console.log(
    "database: OK — schemas, platform tables, identity spine, roles, and append-only audit verified",
  )
} finally {
  if (testClient) await testClient.end()
  if (admin) {
    await admin.query(`drop database if exists "${databaseName}" with (force)`)
    await admin.end()
  }
}
