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

  const adminTables = await testClient.query(
    "select tablename from pg_tables where schemaname = 'admin'",
  )
  const adminTableNames = new Set(adminTables.rows.map((row) => row.tablename))
  for (const table of [
    "permissions",
    "roles",
    "role_permissions",
    "role_assignments",
    "permission_grants",
    "access_denials",
    "departments",
    "staff_profiles",
    "department_members",
    "partner_organisations",
    "partner_representatives",
    "partner_applications",
    "partner_agreements",
    "partner_scopes",
    "approval_requests",
    "approval_steps",
    "approval_decisions",
    "cases",
    "case_events",
    "case_links",
    "case_evidence",
    "case_findings",
    "case_recommendations",
    "case_decisions",
    "case_actions",
    "case_assignments",
    "case_team_members",
    "work_items",
    "configuration_entries",
    "configuration_versions",
  ]) {
    assert(adminTableNames.has(table), `admin.${table} exists`)
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

  let deleteRejected = false
  try {
    await testClient.query(
      "delete from platform.audit_log where action = 'test.action'",
    )
  } catch {
    deleteRejected = true
  }
  assert(deleteRejected, "audit_log rejects deletes")

  const auditColumns = await testClient.query(
    "select column_name from information_schema.columns where table_schema = 'platform' and table_name = 'audit_log'",
  )
  const auditColumnNames = new Set(
    auditColumns.rows.map((row) => row.column_name),
  )
  for (const column of [
    "actor_display_name",
    "actor_email",
    "actor_role_keys",
    "actor_role_scopes",
    "capability",
  ]) {
    assert(auditColumnNames.has(column), `audit_log has ${column}`)
  }

  const snapshotAccount = await testClient.query(
    "insert into identity.accounts (legal_name) values ('Audit Snapshot Ltd') returning id",
  )
  const snapshotActor = await testClient.query(
    "insert into identity.users (account_id, email, display_name) values ($1, 'snapshot@example.test', 'Snapshot Actor') returning id",
    [snapshotAccount.rows[0].id],
  )
  const actorId = snapshotActor.rows[0].id
  await testClient.query(
    `insert into admin.role_assignments (user_id, role_id, scope_type)
     select $1, id, 'platform' from admin.roles where key = 'founder'`,
    [actorId],
  )
  await testClient.query(
    `insert into admin.role_assignments (user_id, role_id, scope_type, scope_id)
     select $1, id, 'department', $2 from admin.roles where key = 'support_officer'`,
    [actorId, "00000000-0000-7000-8000-000000000123"],
  )
  const snapshot = await testClient.query(
    "select display_name, email, role_keys, role_scopes from platform.resolve_audit_actor($1)",
    [actorId],
  )
  assert(snapshot.rows.length === 1, "resolve_audit_actor returns one actor")
  assert(
    snapshot.rows[0].display_name === "Snapshot Actor",
    "resolve_audit_actor returns the display name",
  )
  assert(
    JSON.stringify(snapshot.rows[0].role_keys) ===
      JSON.stringify(["founder", "support_officer"]),
    "resolve_audit_actor returns the active role keys",
  )
  const scopes = snapshot.rows[0].role_scopes
  assert(
    Array.isArray(scopes) &&
      scopes.length === 2 &&
      scopes[0].scopeType === "platform" &&
      scopes[1].scopeType === "department" &&
      scopes[1].scopeId === "00000000-0000-7000-8000-000000000123",
    "resolve_audit_actor returns each role with its scope",
  )
  const nonUserActor = await testClient.query(
    "select display_name from platform.resolve_audit_actor('system')",
  )
  assert(
    nonUserActor.rows.length === 0,
    "resolve_audit_actor tolerates a non-user actor id",
  )

  await testClient.query(
    "insert into platform.outbox (event_type, aggregate_type, aggregate_id) values ('test.event', 'test', 'aggregate')",
  )
  const pending = await testClient.query(
    "select count(*)::int as count from platform.outbox where processed_at is null",
  )
  assert(pending.rows[0].count === 1, "outbox accepts a pending event")

  const outboxColumns = await testClient.query(
    "select column_name from information_schema.columns where table_schema = 'platform' and table_name = 'outbox'",
  )
  const outboxColumnNames = new Set(
    outboxColumns.rows.map((row) => row.column_name),
  )
  for (const column of ["locked_at", "locked_by", "dead_lettered_at"]) {
    assert(outboxColumnNames.has(column), `outbox has ${column}`)
  }
  const workerUpdate = await testClient.query(
    "select has_table_privilege('hivorr_worker', 'platform.outbox', 'update') as allowed",
  )
  assert(
    workerUpdate.rows[0].allowed === true,
    "worker role may update outbox delivery state",
  )
  const workerHealth = await testClient.query(
    "select has_function_privilege('hivorr_worker', 'platform.outbox_health()', 'execute') as allowed",
  )
  assert(
    workerHealth.rows[0].allowed === true,
    "worker role may read outbox health",
  )
  const workerInsert = await testClient.query(
    "select has_table_privilege('hivorr_worker', 'platform.outbox', 'insert') as allowed",
  )
  assert(
    workerInsert.rows[0].allowed === false,
    "worker role cannot produce outbox events",
  )

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

  const apiDelete = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.audit_log', 'delete') as allowed",
  )
  assert(
    apiDelete.rows[0].allowed === false,
    "api role cannot delete audit records",
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
    "mfa_challenges",
    "refresh_tokens",
  ]) {
    assert(identityTableNames.has(table), `identity.${table} exists`)
  }

  const identityRls = await testClient.query(
    "select tablename, rowsecurity from pg_tables where schemaname = 'identity' order by tablename",
  )
  assert(identityRls.rowCount === 12, "twelve identity tables exist")
  assert(
    identityRls.rows.every((row) => row.rowsecurity === true),
    "every identity table has row-level security enabled",
  )

  const identityComments = await testClient.query(
    "select c.relname, obj_description(c.oid, 'pg_class') as comment from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'identity' and c.relkind = 'r'",
  )
  assert(
    identityComments.rows.every((row) => Boolean(row.comment)),
    "every identity table has a comment",
  )

  const identityForeignKeys = await testClient.query(
    "select count(*)::int as count from pg_constraint c join pg_class t on t.oid = c.conrelid join pg_namespace n on n.oid = t.relnamespace where n.nspname = 'identity' and c.contype = 'f'",
  )
  assert(
    identityForeignKeys.rows[0].count >= 10,
    "identity tables declare foreign keys",
  )

  const uuidDefaults = await testClient.query(
    "select count(*)::int as count from information_schema.columns where table_schema = 'identity' and column_name = 'id' and column_default like '%uuidv7%'",
  )
  assert(uuidDefaults.rows[0].count === 11, "identity ids default to UUIDv7")

  const profileTables = await testClient.query(
    "select tablename, rowsecurity from pg_tables where schemaname = 'profile' order by tablename",
  )
  assert(profileTables.rowCount === 2, "two profile tables exist")
  assert(
    profileTables.rows.every((row) => row.rowsecurity === true),
    "every profile table has row-level security enabled",
  )

  const profileComments = await testClient.query(
    "select c.relname, obj_description(c.oid, 'pg_class') as comment from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'profile' and c.relkind = 'r'",
  )
  assert(
    profileComments.rows.every((row) => Boolean(row.comment)),
    "every profile table has a comment",
  )

  const profileIndexes = await testClient.query(
    "select indexname from pg_indexes where schemaname = 'profile'",
  )
  const profileIndexNames = new Set(
    profileIndexes.rows.map((row) => row.indexname),
  )
  for (const index of [
    "activity_activations_account_state_idx",
    "activity_activations_activity_state_idx",
  ]) {
    assert(profileIndexNames.has(index), `profile index ${index} exists`)
  }

  const readonlyProfile = await testClient.query(
    "select has_table_privilege('hivorr_readonly', 'profile.profiles', 'select') as allowed",
  )
  assert(
    readonlyProfile.rows[0].allowed === true,
    "readonly role may read profiles",
  )
  const apiActivationInsert = await testClient.query(
    "select has_table_privilege('hivorr_api', 'profile.activity_activations', 'insert') as allowed",
  )
  assert(
    apiActivationInsert.rows[0].allowed === true,
    "api role may create activations",
  )
  const readonlyContext = await testClient.query(
    "select has_function_privilege('hivorr_readonly', 'platform.current_account_id()', 'execute') as allowed",
  )
  assert(
    readonlyContext.rows[0].allowed === true,
    "readonly role may evaluate the account policy",
  )

  const forcedRls = await testClient.query(
    "select n.nspname as schema, c.relname as table_name, c.relforcerowsecurity as forced from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname in ('identity', 'profile') and c.relkind = 'r' order by 1, 2",
  )
  assert(forcedRls.rowCount === 14, "fourteen identity/profile tables exist")
  assert(
    forcedRls.rows.every((row) => row.forced === true),
    "every identity and profile table forces row-level security",
  )

  const expectedPolicies = {
    accounts: ["SELECT", "INSERT", "UPDATE"],
    users: ["SELECT", "INSERT", "UPDATE"],
    credentials: ["SELECT", "INSERT", "UPDATE"],
    memberships: ["SELECT", "INSERT", "UPDATE"],
    grants: ["SELECT"],
    devices: ["SELECT", "INSERT", "UPDATE"],
    sessions: ["SELECT", "INSERT", "UPDATE"],
    mfa_factors: ["SELECT", "INSERT", "UPDATE"],
    recovery_codes: ["SELECT", "INSERT", "UPDATE", "DELETE"],
    tokens: ["SELECT", "INSERT", "UPDATE", "DELETE"],
    mfa_challenges: ["SELECT", "INSERT", "UPDATE"],
    refresh_tokens: ["SELECT", "INSERT", "UPDATE"],
    profiles: ["SELECT", "INSERT", "UPDATE"],
    activity_activations: ["SELECT", "INSERT", "UPDATE"],
  }
  const policyRows = await testClient.query(
    "select tablename, cmd from pg_policies where schemaname in ('identity', 'profile')",
  )
  const policiesByTable = new Map()
  for (const row of policyRows.rows) {
    const operations = policiesByTable.get(row.tablename) ?? new Set()
    operations.add(row.cmd)
    policiesByTable.set(row.tablename, operations)
  }
  for (const [table, operations] of Object.entries(expectedPolicies)) {
    assert(
      policiesByTable.get(table) instanceof Set &&
        [...policiesByTable.get(table)].sort().join(",") ===
          [...operations].sort().join(","),
      `${table} has one policy per intended operation`,
    )
  }

  const privateHelper = await testClient.query(
    "select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'current_account_id'",
  )
  assert(
    privateHelper.rowCount === 1,
    "the private account policy helper exists",
  )

  const publicWrapper = await testClient.query(
    "select p.prosecdef as secdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'platform' and p.proname = 'current_account_id'",
  )
  assert(
    publicWrapper.rows[0]?.secdef === true,
    "the platform policy wrapper is security definer",
  )

  const definerPolicies = await testClient.query(
    "select count(*)::int as count from pg_policies where schemaname = 'identity' and policyname like '%_definer_select'",
  )
  assert(
    definerPolicies.rows[0].count === 8,
    "the definer owner has narrow read policies",
  )

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
    "insert into identity.sessions (user_id, audience, environment, refresh_token_hash, access_token_hash, access_expires_at, idle_expires_at, expires_at) values ($1, 'app', 'test', $2, $3, now() + interval '15 minutes', now() + interval '30 minutes', now() + interval '12 hours')",
    [userId, "refresh-hash-test", "access-hash-test"],
  )
  await testClient.query(
    "insert into identity.grants (user_id, grant_type, scope, environment) values ($1, 'admin', 'admin.audit.read', 'test')",
    [userId],
  )

  const validScope = await testClient.query(
    "select identity.grant_scope_is_valid('admin', 'admin.grant.manage') as valid, identity.grant_scope_is_valid('staff', 'admin.grant.manage') as invalid",
  )
  assert(validScope.rows[0].valid === true, "admin grant may manage grants")
  assert(
    validScope.rows[0].invalid === false,
    "a staff grant cannot hold an admin scope",
  )

  const grantColumns = await testClient.query(
    "select column_name from information_schema.columns where table_schema = 'identity' and table_name = 'grants'",
  )
  assert(
    grantColumns.rows.some((row) => row.column_name === "department_id"),
    "grants record the owning department",
  )

  const departments = await testClient.query(
    "select key, name from admin.departments order by key",
  )
  assert(
    JSON.stringify(departments.rows.map((row) => row.name)) ===
      JSON.stringify([
        "Customer Care",
        "Financial",
        "Governance",
        "Operations",
      ]),
    "the staging departments are seeded",
  )

  let departmentListDenied = false
  try {
    await testClient.query("select * from admin.list_departments($1, 'test')", [
      userId,
    ])
  } catch (error) {
    departmentListDenied = error?.code === "42501"
  }
  assert(
    departmentListDenied,
    "the department catalogue requires a grant-read capability",
  )

  let departmentWriteDenied = false
  try {
    await testClient.query(
      "select * from identity.set_grant_department($1, (select id from identity.grants where user_id = $1 limit 1), 'operations', 'test')",
      [userId],
    )
  } catch (error) {
    departmentWriteDenied = error?.code === "42501"
  }
  assert(
    departmentWriteDenied,
    "recording a department requires the grant-management capability",
  )

  const roleCatalogueDenied = await testClient
    .query("select * from admin.list_roles($1, 'test')", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(
    roleCatalogueDenied,
    "the role catalogue requires a role-management permission",
  )

  const roleAssignmentDenied = await testClient
    .query(
      `select * from admin.assign_role($1, 'founder@example.test', 'auditor', 'platform', null, null, 'test reason', 'test')`,
      [userId],
    )
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(roleAssignmentDenied, "assigning a role requires admin.role.manage")

  const assignableStaffDenied = await testClient
    .query("select * from admin.list_assignable_staff($1)", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(
    assignableStaffDenied,
    "the assignable staff list requires admin.role.manage",
  )

  const seededRoles = await testClient.query(
    "select count(*)::int as count from admin.roles",
  )
  assert(
    seededRoles.rows[0].count === 11,
    "the eleven governance roles are seeded",
  )

  await testClient.query(
    "insert into profile.profiles (account_id, display_name) values ($1, $2)",
    [accountId, "Founder"],
  )

  let invalidActivityRejected = false
  await testClient.query("begin")
  try {
    await testClient.query(
      "insert into profile.activity_activations (account_id, activity_id) values ($1, 'market.discover')",
      [accountId],
    )
  } catch (error) {
    invalidActivityRejected = error?.code === "23514"
  } finally {
    await testClient.query("rollback")
  }
  assert(invalidActivityRejected, "unknown activity IDs are refused")

  let invalidStateRejected = false
  await testClient.query("begin")
  try {
    await testClient.query(
      "insert into profile.activity_activations (account_id, activity_id, state) values ($1, 'market.buy', 'ON')",
      [accountId],
    )
  } catch (error) {
    invalidStateRejected = error?.code === "23514"
  } finally {
    await testClient.query("rollback")
  }
  assert(invalidStateRejected, "unknown activation states are refused")

  const activities = [
    "market.buy",
    "services.hire",
    "errands.request",
    "market.sell",
    "services.offer",
    "logistics.provide",
  ]
  for (const activity of activities) {
    await testClient.query(
      "insert into profile.activity_activations (account_id, activity_id) values ($1, $2)",
      [accountId, activity],
    )
  }
  const activationCount = await testClient.query(
    "select count(*)::int as count from profile.activity_activations where account_id = $1",
    [accountId],
  )
  assert(activationCount.rows[0].count === 6, "all six activities activate")

  let duplicateActivationRejected = false
  await testClient.query("begin")
  try {
    await testClient.query(
      "insert into profile.activity_activations (account_id, activity_id) values ($1, 'market.buy')",
      [accountId],
    )
  } catch (error) {
    duplicateActivationRejected = error?.code === "23505"
  } finally {
    await testClient.query("rollback")
  }
  assert(
    duplicateActivationRejected,
    "activating twice is refused by the unique constraint",
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
      "insert into identity.sessions (user_id, audience, environment, refresh_token_hash, access_token_hash, access_expires_at, idle_expires_at, expires_at) values ($1, 'admin', 'test', $2, $3, now(), now(), now())",
      [userId, "invalid-audience-hash", "invalid-audience-access-hash"],
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

  await testClient.query(
    "insert into profile.profiles (account_id, display_name) values ($1, 'Other')",
    [secondAccountId],
  )
  await testClient.query(
    "insert into profile.activity_activations (account_id, activity_id) values ($1, 'market.sell')",
    [secondAccountId],
  )

  await testClient.query(
    "insert into identity.sessions (user_id, audience, environment, refresh_token_hash, access_token_hash, access_expires_at, idle_expires_at, expires_at) values ($1, 'app', 'test', $2, $3, now() + interval '15 minutes', now() + interval '30 minutes', now() + interval '12 hours')",
    [secondUserId, "second-refresh-hash", "second-access-hash"],
  )

  const closedAccount = await testClient.query(
    "insert into identity.accounts default values returning id",
  )
  const closedAccountId = closedAccount.rows[0].id
  const closedUser = await testClient.query(
    "insert into identity.users (account_id, email, status) values ($1, $2, 'closed') returning id",
    [closedAccountId, "closed@example.test"],
  )
  await testClient.query(
    "insert into identity.credentials (user_id, password_hash) values ($1, $2)",
    [closedUser.rows[0].id, "argon2id-placeholder"],
  )

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

  const ownProfile = await testClient.query(
    "select count(*)::int as count from profile.profiles",
  )
  assert(
    ownProfile.rows[0].count === 1,
    "rls shows only the current account's profile",
  )
  const ownActivations = await testClient.query(
    "select count(*)::int as count from profile.activity_activations",
  )
  assert(
    ownActivations.rows[0].count === 6,
    "rls shows only the current account's activations",
  )
  const profileUpdate = await testClient.query(
    "update profile.profiles set display_name = 'Updated' where account_id = $1",
    [accountId],
  )
  assert(profileUpdate.rowCount === 1, "api may update its own profile")

  const ownSessions = await testClient.query(
    "select count(*)::int as count from identity.sessions",
  )
  assert(
    ownSessions.rows[0].count === 1,
    "rls shows only the current user's sessions",
  )

  const contextAccount = await testClient.query(
    "select platform.current_account_id() as account_id",
  )
  assert(
    contextAccount.rows[0].account_id === accountId,
    "the identity context is transaction-scoped",
  )

  const unknownLookup = await testClient.query(
    "select * from identity.find_login_credential('nobody@example.test')",
  )
  assert(
    unknownLookup.rowCount === 0,
    "pre-auth lookup returns nothing for an unknown email",
  )

  const closedLookup = await testClient.query(
    "select * from identity.find_login_credential('closed@example.test')",
  )
  assert(
    closedLookup.rowCount === 0,
    "pre-auth lookup refuses a closed account",
  )

  let crossProfileRejected = false
  await testClient.query("savepoint profile_cross_account")
  try {
    await testClient.query(
      "insert into profile.profiles (account_id, display_name) values ($1, 'Blocked')",
      [secondAccountId],
    )
  } catch (error) {
    crossProfileRejected = error?.code === "42501"
    await testClient.query("rollback to savepoint profile_cross_account")
  }
  assert(crossProfileRejected, "rls blocks a cross-account profile write")

  let grantListDenied = false
  await testClient.query("savepoint grant_list_denied")
  try {
    await testClient.query("select * from identity.list_grants($1, 'test')", [
      userId,
    ])
  } catch (error) {
    grantListDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint grant_list_denied")
  }
  assert(grantListDenied, "grant listing requires a grant-management grant")

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
  const noContextProfiles = await testClient.query(
    "select count(*)::int as count from profile.profiles",
  )
  assert(
    noContextProfiles.rows[0].count === 0,
    "profile rls denies without an identity context",
  )
  const noContextActivations = await testClient.query(
    "select count(*)::int as count from profile.activity_activations",
  )
  assert(
    noContextActivations.rows[0].count === 0,
    "activation rls denies without an identity context",
  )
  const noContextSessions = await testClient.query(
    "select count(*)::int as count from identity.sessions",
  )
  assert(
    noContextSessions.rows[0].count === 0,
    "session rls denies without an identity context",
  )
  await testClient.query("reset role")
  await testClient.query("commit")

  const roleAttributes = await testClient.query(
    "select rolname, rolcanlogin, rolsuper, rolbypassrls, rolcreatedb, rolcreaterole from pg_roles where rolname like 'hivorr_%' order by rolname",
  )
  assert(roleAttributes.rowCount === 5, "five application roles exist")
  for (const role of roleAttributes.rows) {
    assert(role.rolcanlogin === false, `${role.rolname} cannot log in`)
    assert(role.rolsuper === false, `${role.rolname} is not superuser`)
    assert(role.rolbypassrls === false, `${role.rolname} cannot bypass RLS`)
    assert(
      role.rolcreatedb === false,
      `${role.rolname} cannot create databases`,
    )
    assert(role.rolcreaterole === false, `${role.rolname} cannot create roles`)
  }

  // The API role has USAGE but not CREATE, and no TRUNCATE or ALTER rights.
  await testClient.query("begin")
  await testClient.query("set role hivorr_api")

  let ddlDenied = false
  await testClient.query("savepoint ddl_probe")
  try {
    await testClient.query("create table identity.ddl_probe (id int)")
  } catch (error) {
    ddlDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint ddl_probe")
  }
  assert(ddlDenied, "api role cannot create tables")

  let alterDenied = false
  await testClient.query("savepoint alter_probe")
  try {
    await testClient.query(
      "alter table platform.audit_log add column probe int",
    )
  } catch (error) {
    alterDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint alter_probe")
  }
  assert(alterDenied, "api role cannot alter tables")

  let truncateDenied = false
  await testClient.query("savepoint truncate_probe")
  try {
    await testClient.query("truncate platform.audit_log")
  } catch (error) {
    truncateDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint truncate_probe")
  }
  assert(truncateDenied, "api role cannot truncate audit records")

  await testClient.query("reset role")
  await testClient.query("commit")

  // A function created after the migrations inherits the closed default.
  await testClient.query(
    "create function platform.default_privilege_probe() returns int language sql as $$ select 1 $$",
  )
  const probe = await testClient.query(
    "select has_function_privilege('hivorr_api', 'platform.default_privilege_probe()', 'execute') as allowed",
  )
  assert(
    probe.rows[0].allowed === false,
    "new functions start closed to the api role",
  )
  await testClient.query("drop function platform.default_privilege_probe()")

  const workerIdentity = await testClient.query(
    "select has_table_privilege('hivorr_worker', 'identity.users', 'select') as allowed",
  )
  assert(
    workerIdentity.rows[0].allowed === false,
    "worker role cannot read identity users",
  )

  const readonlyAudit = await testClient.query(
    "select has_table_privilege('hivorr_readonly', 'platform.audit_log', 'insert') as allowed",
  )
  assert(
    readonlyAudit.rows[0].allowed === false,
    "readonly role cannot append audit records",
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
