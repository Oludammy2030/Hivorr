#!/usr/bin/env node
// Apply every migration to a temporary database, assert the foundation, and
// drop the database. This proves the SQL is self-contained and repeatable.
//
// Local default: the fresh Supabase container on 127.0.0.1:54322.
// CI: set DATABASE_URL to the postgres service.

import { readdirSync, readFileSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"

const baseUrl = process.env.DATABASE_URL ?? "postgres://postgres:postgres@127.0.0.1:54322/postgres"
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
  assert(schemas.rowCount === requiredSchemas.length, "all module schemas exist")

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
    "disputes",
  ]) {
    assert(adminTableNames.has(table), `admin.${table} exists`)
  }

  const platformTables = await testClient.query(
    "select tablename from pg_tables where schemaname = 'platform'",
  )
  const platformTableNames = new Set(platformTables.rows.map((row) => row.tablename))
  for (const table of ["taxonomy_nodes", "taxonomy_attributes"]) {
    assert(platformTableNames.has(table), `platform.${table} exists`)
  }

  // ---- Finance ledger foundation (EP-02-030) ----
  const financeTables = await testClient.query(
    "select tablename from pg_tables where schemaname = 'finance'",
  )
  const financeTableNames = new Set(financeTables.rows.map((row) => row.tablename))
  const expectedFinanceTables = [
    "ledger_accounts",
    "journal_entries",
    "postings",
    "provider_references",
    "escrow_accounts",
    "payout_accounts",
    "payout_requests",
    "collection_accounts",
    "limits",
    "reconciliation_runs",
    "reconciliation_items",
  ]
  for (const table of expectedFinanceTables) {
    assert(financeTableNames.has(table), `finance.${table} exists`)
  }

  const financeColumnResult = await testClient.query(
    `select table_name, column_name, data_type, numeric_precision, numeric_scale
       from information_schema.columns
      where table_schema = 'finance'`,
  )
  const financeColumns = financeColumnResult.rows
  const moneyColumnNames = new Set([
    "amount",
    "provider_total",
    "ledger_total",
    "difference",
    "provider_amount",
    "ledger_amount",
  ])
  const moneyColumns = financeColumns.filter((row) => moneyColumnNames.has(row.column_name))
  assert(moneyColumns.length >= 7, "finance money columns exist")
  for (const column of moneyColumns) {
    assert(
      column.data_type === "numeric" &&
        column.numeric_precision === 20 &&
        column.numeric_scale === 4,
      `finance.${column.table_name}.${column.column_name} is numeric(20,4)`,
    )
  }
  assert(
    !financeColumns.some((row) =>
      ["balance", "available_balance", "wallet_balance"].includes(row.column_name),
    ),
    "no mutable balance column exists in finance",
  )

  const payoutColumns = new Set(
    financeColumns
      .filter((row) => row.table_name === "payout_accounts")
      .map((row) => row.column_name),
  )
  for (const column of [
    "account_number_ciphertext",
    "encryption_key_id",
    "account_number_last4",
    "account_number_fingerprint",
  ]) {
    assert(payoutColumns.has(column), `payout_accounts has ${column}`)
  }
  assert(
    !payoutColumns.has("account_number") && !payoutColumns.has("account_number_plaintext"),
    "payout account numbers are never stored in plaintext",
  )

  const financeRls = await testClient.query(
    `select relname, relrowsecurity
       from pg_class
      where relnamespace = 'finance'::regnamespace and relkind = 'r'`,
  )
  const financeRlsByTable = new Map(financeRls.rows.map((row) => [row.relname, row.relrowsecurity]))
  for (const table of expectedFinanceTables) {
    assert(financeRlsByTable.get(table) === true, `finance.${table} has row level security`)
  }

  // The API role's finance surface, per table. Column-level grants (escrow
  // state, provider-reference status) leave the table-level update privilege
  // false; they are asserted separately below.
  const financeTableGrants = {
    ledger_accounts: { insert: true, update: false, select: true },
    journal_entries: { insert: true, update: false, select: true },
    postings: { insert: true, update: false, select: true },
    provider_references: { insert: true, update: false, select: true },
    escrow_accounts: { insert: true, update: false, select: true },
    payout_accounts: { insert: true, update: true, select: true },
    payout_requests: { insert: true, update: true, select: true },
    collection_accounts: { insert: true, update: false, select: true },
    limits: { insert: true, update: false, select: true },
    reconciliation_runs: { insert: false, update: false, select: false },
    reconciliation_items: { insert: false, update: false, select: false },
  }
  for (const [table, grants] of Object.entries(financeTableGrants)) {
    for (const privilege of ["insert", "update", "select"]) {
      const result = await testClient.query(
        `select has_table_privilege('hivorr_api', 'finance.${table}', '${privilege}') as allowed`,
      )
      assert(
        result.rows[0].allowed === grants[privilege],
        `api role ${privilege} grant on finance.${table} matches the approved surface`,
      )
    }
    const deletion = await testClient.query(
      `select has_table_privilege('hivorr_api', 'finance.${table}', 'delete') as allowed`,
    )
    assert(deletion.rows[0].allowed === false, `api role cannot delete finance.${table}`)
  }

  const escrowStateUpdate = await testClient.query(
    "select has_column_privilege('hivorr_api', 'finance.escrow_accounts', 'state', 'update') as allowed",
  )
  assert(escrowStateUpdate.rows[0].allowed === true, "api role may update the escrow state column")
  for (const column of ["payer_account_id", "ledger_account_id", "currency"]) {
    const mutation = await testClient.query(
      `select has_column_privilege('hivorr_api', 'finance.escrow_accounts', '${column}', 'update') as allowed`,
    )
    assert(mutation.rows[0].allowed === false, `api role cannot rewrite escrow ${column}`)
  }

  const financeViews = await testClient.query(
    "select viewname from pg_views where schemaname = 'finance'",
  )
  const financeViewNames = new Set(financeViews.rows.map((row) => row.viewname))
  for (const view of ["wallet_balances", "wallet_statement"]) {
    assert(financeViewNames.has(view), `finance.${view} exists`)
  }

  const viewOptions = await testClient.query(
    `select relname, reloptions
       from pg_class
      where relnamespace = 'finance'::regnamespace and relkind = 'v'`,
  )
  const optionsByView = new Map(viewOptions.rows.map((row) => [row.relname, row.reloptions ?? []]))
  for (const view of ["wallet_balances", "wallet_statement"]) {
    const options = optionsByView.get(view) ?? []
    assert(options.includes("security_invoker=true"), `finance.${view} is security_invoker`)
    const read = await testClient.query(
      `select has_table_privilege('hivorr_api', 'finance.${view}', 'select') as allowed`,
    )
    assert(read.rows[0].allowed === true, `api may read finance.${view}`)
    for (const privilege of ["insert", "update", "delete"]) {
      const write = await testClient.query(
        `select has_table_privilege('hivorr_api', 'finance.${view}', '${privilege}') as allowed`,
      )
      assert(write.rows[0].allowed === false, `api cannot ${privilege} finance.${view}`)
    }
  }

  const industry = await testClient.query(
    `insert into platform.taxonomy_nodes (taxonomy, level, slug, name)
     values ('profession', 'industry', 'construction', 'Construction')
     returning id`,
  )
  const industryId = industry.rows[0].id
  const profession = await testClient.query(
    `insert into platform.taxonomy_nodes (taxonomy, level, parent_id, slug, name)
     values ('profession', 'profession', $1, 'electrician', 'Electrician')
     returning id`,
    [industryId],
  )
  assert(profession.rowCount === 1, "taxonomy accepts a profession node")

  let duplicateSibling = false
  try {
    await testClient.query(
      `insert into platform.taxonomy_nodes (taxonomy, level, parent_id, slug, name)
       values ('profession', 'profession', $1, 'electrician', 'Electrician 2')`,
      [industryId],
    )
  } catch {
    duplicateSibling = true
  }
  assert(duplicateSibling, "taxonomy rejects a duplicate sibling slug")

  let orphanRejected = false
  try {
    await testClient.query(
      `insert into platform.taxonomy_nodes (taxonomy, level, parent_id, slug, name)
       values ('product', 'category', '00000000-0000-7000-8000-000000000999', 'grocery', 'Grocery')`,
    )
  } catch {
    orphanRejected = true
  }
  assert(orphanRejected, "taxonomy rejects an orphan node")

  let invalidLevelRejected = false
  try {
    await testClient.query(
      `insert into platform.taxonomy_nodes (taxonomy, level, parent_id, slug, name)
       values ('profession', 'category', $1, 'bad-level', 'Bad level')`,
      [industryId],
    )
  } catch {
    invalidLevelRejected = true
  }
  assert(invalidLevelRejected, "taxonomy rejects a cross-taxonomy level")

  const productType = await testClient.query(
    `insert into platform.taxonomy_nodes (taxonomy, level, slug, name)
     values ('product', 'vertical', 'electronics', 'Electronics')
     returning id`,
  )
  const category = await testClient.query(
    `insert into platform.taxonomy_nodes (taxonomy, level, parent_id, slug, name)
     values ('product', 'category', $1, 'audio', 'Audio')
     returning id`,
    [productType.rows[0].id],
  )
  const subcategory = await testClient.query(
    `insert into platform.taxonomy_nodes (taxonomy, level, parent_id, slug, name)
     values ('product', 'subcategory', $1, 'headphones', 'Headphones')
     returning id`,
    [category.rows[0].id],
  )
  const leaf = await testClient.query(
    `insert into platform.taxonomy_nodes (taxonomy, level, parent_id, slug, name)
     values ('product', 'product_type', $1, 'wireless', 'Wireless')
     returning id`,
    [subcategory.rows[0].id],
  )
  await testClient.query(
    `insert into platform.taxonomy_attributes (node_id, key, label, data_type, is_required)
     values ($1, 'colour', 'Colour', 'text', true)`,
    [leaf.rows[0].id],
  )
  const attributes = await testClient.query(
    "select count(*)::int as count from platform.taxonomy_attributes",
  )
  assert(attributes.rows[0].count === 1, "taxonomy accepts a typed attribute")

  let attributeLevelRejected = false
  try {
    await testClient.query(
      `insert into platform.taxonomy_attributes (node_id, key, label, data_type)
       values ($1, 'size', 'Size', 'text')`,
      [category.rows[0].id],
    )
  } catch {
    attributeLevelRejected = true
  }
  assert(attributeLevelRejected, "taxonomy rejects an attribute on a category node")

  const taxonomyWrite = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.taxonomy_nodes', 'insert') as allowed",
  )
  assert(taxonomyWrite.rows[0].allowed === false, "api role cannot write taxonomy nodes directly")
  const taxonomyRead = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.taxonomy_nodes', 'select') as allowed",
  )
  assert(taxonomyRead.rows[0].allowed === true, "api role may read taxonomy nodes")

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
    await testClient.query("delete from platform.audit_log where action = 'test.action'")
  } catch {
    deleteRejected = true
  }
  assert(deleteRejected, "audit_log rejects deletes")

  const auditColumns = await testClient.query(
    "select column_name from information_schema.columns where table_schema = 'platform' and table_name = 'audit_log'",
  )
  const auditColumnNames = new Set(auditColumns.rows.map((row) => row.column_name))
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

  const createdByAdmin = await testClient.query(
    `select id from platform.create_taxonomy_node(
       $1, 'profession', 'industry', null, 'legal', 'Legal', null, 1, now()
     )`,
    [actorId],
  )
  assert(createdByAdmin.rowCount === 1, "an authorised administrator can create a taxonomy node")
  const outsider = await testClient.query(
    "insert into identity.users (account_id, email, display_name) values ($1, 'outsider@example.test', 'Outsider') returning id",
    [snapshotAccount.rows[0].id],
  )
  let outsideWriteRejected = false
  try {
    await testClient.query(
      `select id from platform.create_taxonomy_node(
         $1, 'profession', 'industry', null, 'outside', 'Outside', null, 1, now()
       )`,
      [outsider.rows[0].id],
    )
  } catch {
    outsideWriteRejected = true
  }
  assert(outsideWriteRejected, "a user without configuration.write cannot create a taxonomy node")

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
    JSON.stringify(snapshot.rows[0].role_keys) === JSON.stringify(["founder", "support_officer"]),
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
  assert(nonUserActor.rows.length === 0, "resolve_audit_actor tolerates a non-user actor id")

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
  const outboxColumnNames = new Set(outboxColumns.rows.map((row) => row.column_name))
  for (const column of ["locked_at", "locked_by", "dead_lettered_at"]) {
    assert(outboxColumnNames.has(column), `outbox has ${column}`)
  }
  const workerUpdate = await testClient.query(
    "select has_table_privilege('hivorr_worker', 'platform.outbox', 'update') as allowed",
  )
  assert(workerUpdate.rows[0].allowed === true, "worker role may update outbox delivery state")
  const workerHealth = await testClient.query(
    "select has_function_privilege('hivorr_worker', 'platform.outbox_health()', 'execute') as allowed",
  )
  assert(workerHealth.rows[0].allowed === true, "worker role may read outbox health")
  const workerInsert = await testClient.query(
    "select has_table_privilege('hivorr_worker', 'platform.outbox', 'insert') as allowed",
  )
  assert(workerInsert.rows[0].allowed === false, "worker role cannot produce outbox events")

  const apiInsert = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.audit_log', 'insert') as allowed",
  )
  assert(apiInsert.rows[0].allowed === true, "api role may append audit records")
  const apiUpdate = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.audit_log', 'update') as allowed",
  )
  assert(apiUpdate.rows[0].allowed === false, "api role cannot update audit records")

  const apiDelete = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.audit_log', 'delete') as allowed",
  )
  assert(apiDelete.rows[0].allowed === false, "api role cannot delete audit records")

  const identityTables = await testClient.query(
    "select tablename from pg_tables where schemaname = 'identity'",
  )
  const identityTableNames = new Set(identityTables.rows.map((row) => row.tablename))
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
  assert(identityForeignKeys.rows[0].count >= 10, "identity tables declare foreign keys")

  const uuidDefaults = await testClient.query(
    "select count(*)::int as count from information_schema.columns where table_schema = 'identity' and column_name = 'id' and column_default like '%uuidv7%'",
  )
  assert(uuidDefaults.rows[0].count === 11, "identity ids default to UUIDv7")

  const profileTables = await testClient.query(
    "select tablename, rowsecurity from pg_tables where schemaname = 'profile' order by tablename",
  )
  assert(profileTables.rowCount === 8, "eight profile tables exist")
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
  const profileIndexNames = new Set(profileIndexes.rows.map((row) => row.indexname))
  for (const index of [
    "activity_activations_account_state_idx",
    "activity_activations_activity_state_idx",
  ]) {
    assert(profileIndexNames.has(index), `profile index ${index} exists`)
  }

  const readonlyProfile = await testClient.query(
    "select has_table_privilege('hivorr_readonly', 'profile.profiles', 'select') as allowed",
  )
  assert(readonlyProfile.rows[0].allowed === true, "readonly role may read profiles")
  const apiActivationInsert = await testClient.query(
    "select has_table_privilege('hivorr_api', 'profile.activity_activations', 'insert') as allowed",
  )
  assert(apiActivationInsert.rows[0].allowed === true, "api role may create activations")
  const readonlyContext = await testClient.query(
    "select has_function_privilege('hivorr_readonly', 'platform.current_account_id()', 'execute') as allowed",
  )
  assert(readonlyContext.rows[0].allowed === true, "readonly role may evaluate the account policy")

  const forcedRls = await testClient.query(
    "select n.nspname as schema, c.relname as table_name, c.relforcerowsecurity as forced from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname in ('identity', 'profile') and c.relkind = 'r' order by 1, 2",
  )
  assert(forcedRls.rowCount === 20, "twenty identity/profile tables exist")
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
    businesses: ["SELECT", "INSERT", "UPDATE"],
    verification_lanes: ["SELECT"],
    verification_cases: ["SELECT", "INSERT", "UPDATE"],
    verification_submissions: ["SELECT", "INSERT", "UPDATE"],
    verification_evidence: ["SELECT", "INSERT"],
    verification_decisions: ["SELECT"],
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
        [...policiesByTable.get(table)].sort().join(",") === [...operations].sort().join(","),
      `${table} has one policy per intended operation`,
    )
  }

  const privateHelper = await testClient.query(
    "select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'current_account_id'",
  )
  assert(privateHelper.rowCount === 1, "the private account policy helper exists")

  const publicWrapper = await testClient.query(
    "select p.prosecdef as secdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'platform' and p.proname = 'current_account_id'",
  )
  assert(publicWrapper.rows[0]?.secdef === true, "the platform policy wrapper is security definer")

  const definerPolicies = await testClient.query(
    "select count(*)::int as count from pg_policies where schemaname = 'identity' and policyname like '%_definer_select'",
  )
  assert(definerPolicies.rows[0].count === 8, "the definer owner has narrow read policies")

  const uuid = await testClient.query(
    "select substring(platform.uuidv7()::text, 15, 1) as version, substring(platform.uuidv7()::text, 20, 1) as variant",
  )
  assert(uuid.rows[0].version === "7", "uuidv7 version nibble is 7")
  assert(["8", "9", "a", "b"].includes(uuid.rows[0].variant), "uuidv7 variant nibble is RFC 9562")

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
  assert(validScope.rows[0].invalid === false, "a staff grant cannot hold an admin scope")

  const grantColumns = await testClient.query(
    "select column_name from information_schema.columns where table_schema = 'identity' and table_name = 'grants'",
  )
  assert(
    grantColumns.rows.some((row) => row.column_name === "department_id"),
    "grants record the owning department",
  )

  const departments = await testClient.query("select key, name from admin.departments order by key")
  assert(
    JSON.stringify(departments.rows.map((row) => row.name)) ===
      JSON.stringify(["Customer Care", "Financial", "Governance", "Operations"]),
    "the staging departments are seeded",
  )

  let departmentListDenied = false
  try {
    await testClient.query("select * from admin.list_departments($1, 'test')", [userId])
  } catch (error) {
    departmentListDenied = error?.code === "42501"
  }
  assert(departmentListDenied, "the department catalogue requires a grant-read capability")

  let departmentWriteDenied = false
  try {
    await testClient.query(
      "select * from identity.set_grant_department($1, (select id from identity.grants where user_id = $1 limit 1), 'operations', 'test')",
      [userId],
    )
  } catch (error) {
    departmentWriteDenied = error?.code === "42501"
  }
  assert(departmentWriteDenied, "recording a department requires the grant-management capability")

  const roleCatalogueDenied = await testClient
    .query("select * from admin.list_roles($1, 'test')", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(roleCatalogueDenied, "the role catalogue requires a role-management permission")

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
  assert(assignableStaffDenied, "the assignable staff list requires admin.role.manage")

  const accountGovernDenied = await testClient
    .query("select * from admin.govern_user($1, $1, 'suspend', 'test reason')", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(accountGovernDenied, "account governance requires admin.user.manage")

  const notesTable = await testClient.query(
    "select 1 from information_schema.tables where table_schema = 'admin' and table_name = 'user_notes'",
  )
  assert(notesTable.rowCount === 1, "operator notes are stored in admin.user_notes")

  const approvalListDenied = await testClient
    .query("select * from admin.list_approval_requests($1)", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(approvalListDenied, "the approval register requires an approval permission")

  const approvalPermission = await testClient.query(
    "select 1 from admin.permissions where key = 'admin.approval.decide'",
  )
  assert(approvalPermission.rowCount === 1, "the approval decision permission is registered")

  const partnerListDenied = await testClient
    .query("select * from admin.list_partner_organisations($1)", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(partnerListDenied, "the partner register requires a partner permission")

  const partnerPermission = await testClient.query(
    "select 1 from admin.permissions where key = 'admin.partner.manage'",
  )
  assert(partnerPermission.rowCount === 1, "the partner management permission is registered")

  const ownPartner = await testClient.query(
    "select * from admin.list_own_partner_organisations('00000000-0000-7000-8000-000000000000')",
  )
  assert(ownPartner.rowCount === 0, "the partner read model is scoped to the user id")

  const caseListDenied = await testClient
    .query("select * from admin.list_cases($1, '', '', '')", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(caseListDenied, "the case register requires a case permission")

  const evidenceDenied = await testClient
    .query("select * from admin.list_case_evidence($1, '00000000-0000-7000-8000-000000000000')", [
      userId,
    ])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(evidenceDenied, "the evidence register requires a case permission")

  const disputeTableGrant = await testClient.query(
    "select has_table_privilege('hivorr_api', 'admin.disputes', 'select') as allowed",
  )
  assert(
    disputeTableGrant.rows[0].allowed === false,
    "the api role has no direct dispute table grant",
  )

  const disputeListDenied = await testClient
    .query("select * from admin.list_disputes($1, null)", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(disputeListDenied, "the dispute register requires a dispute permission")

  const disputeCase = await testClient.query(
    `select * from admin.create_case(
       $1, 'dispute', 'Damaged item', 'Buyer reports damage',
       'normal', 'medium', null, 'open a dispute test case'
     )`,
    [actorId],
  )
  const disputeCaseId = disputeCase.rows[0].id
  const disputeRespondent = await testClient.query(
    "insert into identity.accounts default values returning id",
  )
  const disputeActivityRef = "00000000-0000-7000-8000-00000000d5a0"

  const openedDispute = await testClient.query(
    `select * from admin.open_dispute(
       $1, $2, 'market.buy', $3, $4, $5, 'NGN', 500.0000, null,
       'buyer reports a damaged item'
     )`,
    [actorId, disputeCaseId, disputeActivityRef, accountId, disputeRespondent.rows[0].id],
  )
  const disputeId = openedDispute.rows[0].id
  assert(
    openedDispute.rows[0].status === "OPENED" &&
      openedDispute.rows[0].claimed_amount === "500.0000",
    "a dispute opens with a procedural status and the claimed amount",
  )
  assert(openedDispute.rows[0].reference.startsWith("DSP-"), "a dispute carries its own reference")

  const disputeView = await testClient.query("select * from admin.dispute_view($1, $2)", [
    actorId,
    disputeId,
  ])
  assert(disputeView.rowCount === 1, "a scoped admin can read the dispute")
  assert(disputeView.rows[0].case_id === disputeCaseId, "the dispute points at its case")

  const disputeList = await testClient.query("select * from admin.list_disputes($1, $2)", [
    actorId,
    disputeCaseId,
  ])
  assert(disputeList.rowCount === 1, "the dispute register lists the case")

  const awaitingEvidence = await testClient.query(
    `select * from admin.set_dispute_status(
       $1, $2, 'AWAITING_EVIDENCE', 'request photographs from the buyer'
     )`,
    [actorId, disputeId],
  )
  assert(
    awaitingEvidence.rows[0].status === "AWAITING_EVIDENCE",
    "a procedural status change is allowed",
  )

  const backwardsTransition = await testClient
    .query(
      `select * from admin.set_dispute_status(
         $1, $2, 'OPENED', 'attempt to move backwards'
       )`,
      [actorId, disputeId],
    )
    .then(
      () => false,
      (error) => error?.code === "22023",
    )
  assert(backwardsTransition, "a backwards procedural transition is refused")

  const resolutionStatus = await testClient
    .query(
      `select * from admin.set_dispute_status(
         $1, $2, 'RESOLVED', 'attempt an outcome'
       )`,
      [actorId, disputeId],
    )
    .then(
      () => false,
      (error) => error?.code === "22023",
    )
  assert(resolutionStatus, "no resolved outcome status exists while BD-D03 is open")

  const disputeEvidence = await testClient.query(
    `select * from admin.add_case_evidence(
       $1, $2, 'disputes/evidence-1.pdf', 'damage.pdf', 'application/pdf',
       1024, $3, 'sensitive', 'evidence for the dispute test'
     )`,
    [actorId, disputeCaseId, "a".repeat(64)],
  )
  const disputeEvidenceId = disputeEvidence.rows[0].id
  await testClient.query("select admin.record_dispute_evidence_access($1, $2, $3, 'review')", [
    actorId,
    disputeId,
    disputeEvidenceId,
  ])
  const evidenceAccessed = await testClient.query(
    `select count(*)::int as count
       from admin.case_events
      where case_id = $1 and event_type = 'evidence_accessed'`,
    [disputeCaseId],
  )
  assert(
    evidenceAccessed.rows[0].count === 1,
    "access through a dispute is recorded on the case timeline",
  )

  const foreignEvidence = await testClient
    .query("select admin.record_dispute_evidence_access($1, $2, $3, 'review')", [
      actorId,
      disputeId,
      "00000000-0000-7000-8000-00000000e999",
    ])
    .then(
      () => false,
      (error) => error?.code === "P0002",
    )
  assert(foreignEvidence, "evidence outside the dispute's case cannot be accessed")

  const verificationDenied = await testClient
    .query("select * from admin.list_verification_queue($1, '')", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(verificationDenied, "the verification queue requires admin.verification.review")

  const seededRoles = await testClient.query("select count(*)::int as count from admin.roles")
  assert(seededRoles.rows[0].count === 11, "the eleven governance roles are seeded")

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
  assert(duplicateActivationRejected, "activating twice is refused by the unique constraint")

  let duplicateEmailRejected = false
  try {
    await testClient.query("insert into identity.users (account_id, email) values ($1, $2)", [
      accountId,
      "FOUNDER@example.test",
    ])
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
  assert(identityAccess.rows[0].allowed === true, "api role may read identity users")

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

  // ---- Finance ledger fixtures and invariants (EP-02-030) ----
  const walletAccount = await testClient.query(
    `insert into finance.ledger_accounts (kind, owner_type, owner_id, currency)
     values ('user_wallet', 'account', $1, 'NGN')
     returning id`,
    [accountId],
  )
  const walletLedgerId = walletAccount.rows[0].id

  const clearingAccount = await testClient.query(
    `insert into finance.ledger_accounts (kind, owner_type, currency)
     values ('platform_clearing', 'platform', 'NGN')
     returning id`,
  )
  const clearingLedgerId = clearingAccount.rows[0].id

  const escrowRef = "00000000-0000-7000-8000-000000000e5c"
  const escrowLedger = await testClient.query(
    `insert into finance.ledger_accounts (kind, owner_type, owner_id, currency)
     values ('escrow', 'activity', $1, 'NGN')
     returning id`,
    [escrowRef],
  )
  const escrowLedgerId = escrowLedger.rows[0].id

  let unknownKindRejected = false
  try {
    await testClient.query(
      `insert into finance.ledger_accounts (kind, owner_type, owner_id, currency)
       values ('wallet', 'account', $1, 'NGN')`,
      [accountId],
    )
  } catch (error) {
    unknownKindRejected = error?.code === "23514"
  }
  assert(unknownKindRejected, "unknown ledger account kinds are refused")

  await testClient.query("begin")
  const depositEntry = await testClient.query(
    `insert into finance.journal_entries
       (kind, reference, currency, activity_id, idempotency_key, created_by)
     values ('deposit', 'DEP-TEST-0001', 'NGN', 'market.buy',
             'idem-deposit-0001', $1)
     returning id`,
    [userId],
  )
  const depositEntryId = depositEntry.rows[0].id
  await testClient.query(
    `insert into finance.postings
       (entry_id, ledger_account_id, direction, amount, currency, activity_id)
     values ($1, $2, 'debit', 100.0000, 'NGN', 'market.buy')`,
    [depositEntryId, walletLedgerId],
  )
  await testClient.query(
    `insert into finance.postings
       (entry_id, ledger_account_id, direction, amount, currency, activity_id)
     values ($1, $2, 'credit', 100.0000, 'NGN', 'market.buy')`,
    [depositEntryId, clearingLedgerId],
  )
  await testClient.query("commit")

  const derivedBalance = await testClient.query(
    `select coalesce(sum(
              case direction when 'debit' then amount else -amount end
            ), 0)::text as balance
       from finance.postings
      where ledger_account_id = $1`,
    [walletLedgerId],
  )
  assert(derivedBalance.rows[0].balance === "100.0000", "wallet balance is derived from postings")

  await testClient.query("begin")
  const reversalEntry = await testClient.query(
    `insert into finance.journal_entries
       (kind, reference, currency, reverses_entry_id, created_by)
     values ('reversal', 'REV-TEST-0001', 'NGN', $1, $2)
     returning id`,
    [depositEntryId, userId],
  )
  const reversalEntryId = reversalEntry.rows[0].id
  await testClient.query(
    `insert into finance.postings
       (entry_id, ledger_account_id, direction, amount, currency)
     values ($1, $2, 'credit', 100.0000, 'NGN'),
            ($1, $3, 'debit', 100.0000, 'NGN')`,
    [reversalEntryId, walletLedgerId, clearingLedgerId],
  )
  await testClient.query("commit")

  const reversedBalance = await testClient.query(
    `select coalesce(sum(
              case direction when 'debit' then amount else -amount end
            ), 0)::text as balance
       from finance.postings
      where ledger_account_id = $1`,
    [walletLedgerId],
  )
  assert(
    reversedBalance.rows[0].balance === "0.0000",
    "a reversal restores the derived balance without editing a posting",
  )

  let duplicateReversalRejected = false
  try {
    await testClient.query(
      `insert into finance.journal_entries
         (kind, reference, currency, reverses_entry_id)
       values ('reversal', 'REV-TEST-0002', 'NGN', $1)`,
      [depositEntryId],
    )
  } catch (error) {
    duplicateReversalRejected = error?.code === "23505"
  }
  assert(duplicateReversalRejected, "an entry can be reversed only once")

  let unbalancedRejected = false
  await testClient.query("begin")
  try {
    const unbalanced = await testClient.query(
      `insert into finance.journal_entries (kind, reference, currency)
       values ('adjustment', 'ADJ-TEST-0001', 'NGN')
       returning id`,
    )
    await testClient.query(
      `insert into finance.postings
         (entry_id, ledger_account_id, direction, amount, currency)
       values ($1, $2, 'debit', 40.0000, 'NGN')`,
      [unbalanced.rows[0].id, walletLedgerId],
    )
    await testClient.query("commit")
  } catch (error) {
    unbalancedRejected = error?.code === "23514"
    await testClient.query("rollback")
  }
  assert(unbalancedRejected, "the ledger rejects an unbalanced entry")

  let currencyMismatchRejected = false
  await testClient.query("begin")
  try {
    const mismatched = await testClient.query(
      `insert into finance.journal_entries (kind, reference, currency)
       values ('adjustment', 'ADJ-TEST-0002', 'NGN')
       returning id`,
    )
    await testClient.query(
      `insert into finance.postings
         (entry_id, ledger_account_id, direction, amount, currency)
       values ($1, $2, 'debit', 10.0000, 'USD')`,
      [mismatched.rows[0].id, walletLedgerId],
    )
  } catch (error) {
    currencyMismatchRejected = error?.code === "23514"
  } finally {
    await testClient.query("rollback")
  }
  assert(currencyMismatchRejected, "a posting must match its entry currency")

  const depositPosting = await testClient.query(
    "select id from finance.postings where entry_id = $1 and ledger_account_id = $2",
    [depositEntryId, walletLedgerId],
  )
  const depositPostingId = depositPosting.rows[0].id

  let postingUpdateRejected = false
  try {
    await testClient.query("update finance.postings set amount = 1.0000 where id = $1", [
      depositPostingId,
    ])
  } catch (error) {
    postingUpdateRejected = error?.code === "42501"
  }
  assert(postingUpdateRejected, "postings are append-only")

  let entryDeleteRejected = false
  try {
    await testClient.query("delete from finance.journal_entries where id = $1", [depositEntryId])
  } catch (error) {
    entryDeleteRejected = error?.code === "42501"
  }
  assert(entryDeleteRejected, "journal entries are append-only")

  let truncateRejected = false
  try {
    await testClient.query("truncate finance.postings")
  } catch (error) {
    truncateRejected = error?.code === "42501"
  }
  assert(truncateRejected, "ledger tables reject truncate")

  const escrow = await testClient.query(
    `insert into finance.escrow_accounts
       (ledger_account_id, payer_account_id, activity_id, activity_ref, currency)
     values ($1, $2, 'services.hire', $3, 'NGN')
     returning id`,
    [escrowLedgerId, accountId, escrowRef],
  )
  const escrowId = escrow.rows[0].id

  let escrowStateRejected = false
  try {
    await testClient.query("update finance.escrow_accounts set state = 'lost' where id = $1", [
      escrowId,
    ])
  } catch (error) {
    escrowStateRejected = error?.code === "23514"
  }
  assert(escrowStateRejected, "unknown escrow states are refused")

  const payoutAccount = await testClient.query(
    `insert into finance.payout_accounts
       (account_id, bank_code, bank_name, account_name, account_name_normalized,
        account_number_ciphertext, encryption_key_id, account_number_last4,
        account_number_fingerprint, status, verified_at)
     values ($1, '058', 'Test Bank', 'Test Account', 'test account',
             $2, 'test-key-1', '0123', $3, 'verified', now())
     returning id`,
    [accountId, Buffer.alloc(32, 7), "a".repeat(64)],
  )
  assert(payoutAccount.rowCount === 1, "a verified payout account is accepted")

  let unverifiedPayoutRejected = false
  try {
    await testClient.query(
      `insert into finance.payout_accounts
         (account_id, bank_code, bank_name, account_name, account_name_normalized,
          account_number_ciphertext, encryption_key_id, account_number_last4,
          account_number_fingerprint)
       values ($1, '058', 'Test Bank', 'Test Account', 'test account',
               $2, 'test-key-1', '0123', $3)`,
      [accountId, Buffer.alloc(32, 9), "b".repeat(64)],
    )
  } catch (error) {
    unverifiedPayoutRejected = error?.code === "23514"
  }
  assert(unverifiedPayoutRejected, "a payout destination must be verified before it is stored")

  let duplicatePayoutRejected = false
  try {
    await testClient.query(
      `insert into finance.payout_accounts
         (account_id, bank_code, bank_name, account_name, account_name_normalized,
          account_number_ciphertext, encryption_key_id, account_number_last4,
          account_number_fingerprint, status, verified_at)
       values ($1, '058', 'Test Bank', 'Test Account', 'test account',
               $2, 'test-key-1', '0123', $3, 'verified', now())`,
      [accountId, Buffer.alloc(32, 8), "a".repeat(64)],
    )
  } catch (error) {
    duplicatePayoutRejected = error?.code === "23505"
  }
  assert(duplicatePayoutRejected, "duplicate payout destinations are refused")

  // ---- Collection accounts, provider setting and KYC gating (2026-11-26) ----
  const collectionRls = await testClient.query(
    "select relrowsecurity from pg_class where oid = 'finance.collection_accounts'::regclass",
  )
  assert(
    collectionRls.rows[0]?.relrowsecurity === true,
    "collection accounts have row level security",
  )

  for (const privilege of ["select", "insert"]) {
    const allowed = await testClient.query(
      `select has_table_privilege('hivorr_api', 'finance.collection_accounts', '${privilege}') as allowed`,
    )
    assert(allowed.rows[0].allowed === true, `api role may ${privilege} collection accounts`)
  }
  for (const privilege of ["update", "delete"]) {
    const allowed = await testClient.query(
      `select has_table_privilege('hivorr_api', 'finance.collection_accounts', '${privilege}') as allowed`,
    )
    assert(allowed.rows[0].allowed === false, `api role cannot ${privilege} collection accounts`)
  }

  const collectionPolicies = await testClient.query(
    "select cmd from pg_policies where schemaname = 'finance' and tablename = 'collection_accounts'",
  )
  assert(
    JSON.stringify([...new Set(collectionPolicies.rows.map((row) => row.cmd))].sort()) ===
      JSON.stringify(["INSERT", "SELECT"]),
    "collection accounts expose select and insert policies only",
  )

  const collectionColumns = await testClient.query(
    "select column_name from information_schema.columns where table_schema = 'finance' and table_name = 'collection_accounts'",
  )
  const collectionColumnNames = new Set(collectionColumns.rows.map((row) => row.column_name))
  for (const column of [
    "account_id",
    "owner_user_id",
    "provider",
    "account_number",
    "account_name",
    "bank_name",
    "currency",
    "status",
  ]) {
    assert(collectionColumnNames.has(column), `collection accounts store ${column}`)
  }
  assert(
    ![...collectionColumnNames].some((column) => /secret|token|key/i.test(column)),
    "collection accounts hold no provider secret",
  )

  const collectionInsert = await testClient.query(
    `insert into finance.collection_accounts
       (account_id, owner_user_id, provider, reference, account_number,
        account_name, bank_name)
     values ($1, $2, 'paystack', $3, '1234567890', 'Hivorr / Test', 'Titan Trust Bank')
     returning id`,
    [accountId, userId, `COL-${accountId}`],
  )
  assert(collectionInsert.rowCount === 1, "a collection account is stored for the account")

  let duplicateCollectionRejected = false
  try {
    await testClient.query(
      `insert into finance.collection_accounts
         (account_id, owner_user_id, provider, reference, account_number,
          account_name)
       values ($1, $2, 'paystack', $3, '0987654321', 'Hivorr / Other')`,
      [accountId, userId, `COL-other-${accountId}`],
    )
  } catch (error) {
    duplicateCollectionRejected = error?.code === "23505"
  }
  assert(duplicateCollectionRejected, "one collection account per account and provider")

  const providerSetting = await testClient.query(
    "select active_provider, active_mode from platform.payment_provider_setting",
  )
  assert(providerSetting.rowCount === 1, "the provider setting is one row")
  assert(
    providerSetting.rows[0].active_provider === "paystack",
    "Paystack is the default active provider",
  )
  assert(providerSetting.rows[0].active_mode === "test", "the default provider mode is test")

  const providerColumns = await testClient.query(
    "select column_name from information_schema.columns where table_schema = 'platform' and table_name = 'payment_provider_setting'",
  )
  assert(
    !providerColumns.rows.some((row) => /secret|token|key/i.test(row.column_name)),
    "the provider setting holds no secret",
  )

  const providerDirectUpdate = await testClient.query(
    "select has_table_privilege('hivorr_api', 'platform.payment_provider_setting', 'update') as allowed",
  )
  assert(
    providerDirectUpdate.rows[0].allowed === false,
    "the api role cannot update the provider setting directly",
  )

  const providerReadDenied = await testClient
    .query("select * from platform.get_payment_provider($1)", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(providerReadDenied, "reading the provider setting requires admin.configuration.read")

  const providerWriteDenied = await testClient
    .query("select * from platform.set_payment_provider($1, 'vfd', 'test')", [userId])
    .then(
      () => false,
      (error) => error?.code === "42501",
    )
  assert(providerWriteDenied, "switching the provider requires admin.configuration.write")

  const accountColumns = await testClient.query(
    "select column_name, column_default from information_schema.columns where table_schema = 'identity' and table_name = 'accounts'",
  )
  const accountColumnNames = new Set(accountColumns.rows.map((row) => row.column_name))
  for (const column of [
    "kyc_tier",
    "kyc_tier_updated_at",
    "financial_hold_reason",
    "financial_hold_at",
  ]) {
    assert(accountColumnNames.has(column), `identity.accounts has ${column}`)
  }

  const defaultTier = await testClient.query(
    "select kyc_tier from identity.accounts where id = $1",
    [accountId],
  )
  assert(defaultTier.rows[0].kyc_tier === "tier_0", "a new account starts at tier_0")

  let invalidTierRejected = false
  try {
    await testClient.query("update identity.accounts set kyc_tier = 'tier_9' where id = $1", [
      accountId,
    ])
  } catch (error) {
    invalidTierRejected = error?.code === "23514"
  }
  assert(invalidTierRejected, "an unknown KYC tier is refused")

  let invalidHoldRejected = false
  try {
    await testClient.query(
      "update identity.accounts set financial_hold_reason = 'manual' where id = $1",
      [accountId],
    )
  } catch (error) {
    invalidHoldRejected = error?.code === "23514"
  }
  assert(invalidHoldRejected, "only the KYC-upgrade hold reason is representable")

  const cbnWithdrawal = await testClient.query(
    `select tier, amount::text as amount, is_unlimited
       from finance.limits
      where limit_type = 'withdrawal' and period = 'daily'
        and currency = 'NGN' and account_id is null
        and tier in ('tier_1', 'tier_2', 'tier_3')
        and effective_to is null
      order by tier`,
  )
  assert(
    JSON.stringify(cbnWithdrawal.rows.map((row) => [row.tier, row.amount, row.is_unlimited])) ===
      JSON.stringify([
        ["tier_1", "30000.0000", false],
        ["tier_2", "100000.0000", false],
        ["tier_3", "1000000.0000", false],
      ]),
    "the CBN daily withdrawal caps are seeded per tier",
  )

  const cbnDeposits = await testClient.query(
    `select tier, amount::text as amount, is_unlimited
       from finance.limits
      where limit_type = 'deposit'
        and currency = 'NGN' and account_id is null
        and tier in ('tier_1', 'tier_2', 'tier_3')
        and effective_to is null
      order by tier`,
  )
  assert(
    JSON.stringify(cbnDeposits.rows.map((row) => [row.tier, row.amount, row.is_unlimited])) ===
      JSON.stringify([
        ["tier_1", "20000.0000", false],
        ["tier_2", "50000.0000", false],
        ["tier_3", "0.0000", true],
      ]),
    "the CBN single-deposit caps are seeded per tier",
  )

  await testClient.query(
    `insert into finance.provider_references
       (account_id, provider, provider_reference, direction, status, amount,
        currency, journal_entry_id)
     values ($1, 'vfd', 'VFD-TEST-0001', 'deposit', 'posted', 100.0000, 'NGN', $2)`,
    [accountId, depositEntryId],
  )

  let duplicateProviderReferenceRejected = false
  try {
    await testClient.query(
      `insert into finance.provider_references
         (account_id, provider, provider_reference, direction, status, amount,
          currency, journal_entry_id)
       values ($1, 'vfd', 'VFD-TEST-0001', 'deposit', 'posted', 100.0000, 'NGN', $2)`,
      [accountId, depositEntryId],
    )
  } catch (error) {
    duplicateProviderReferenceRejected = error?.code === "23505"
  }
  assert(duplicateProviderReferenceRejected, "provider references are unique per provider")

  await testClient.query(
    `insert into finance.limits
       (tier, limit_type, currency, amount, period)
     values ('tier_1', 'deposit', 'NGN', 50000.0000, 'daily')`,
  )
  await testClient.query(
    `insert into finance.limits
       (account_id, limit_type, currency, amount, period)
     values ($1, 'withdrawal', 'NGN', 1000.0000, 'daily')`,
    [secondAccountId],
  )

  let mixedLimitRejected = false
  try {
    await testClient.query(
      `insert into finance.limits
         (tier, account_id, limit_type, currency, amount, period)
       values ('tier_1', $1, 'payout', 'NGN', 10.0000, 'daily')`,
      [secondAccountId],
    )
  } catch (error) {
    mixedLimitRejected = error?.code === "23514"
  }
  assert(mixedLimitRejected, "a limit targets a tier or an account, never both")

  await testClient.query("begin")
  const walletDepositEntry = await testClient.query(
    `insert into finance.journal_entries
       (kind, reference, currency, created_by)
     values ('deposit', 'WAL-TEST-0001', 'NGN', $1)
     returning id`,
    [userId],
  )
  await testClient.query(
    `insert into finance.postings
       (entry_id, ledger_account_id, direction, amount, currency)
     values ($1, $2, 'debit', 10.0000, 'NGN'),
            ($1, $3, 'credit', 10.0000, 'NGN')`,
    [walletDepositEntry.rows[0].id, walletLedgerId, clearingLedgerId],
  )
  await testClient.query("commit")

  await testClient.query("begin")
  const escrowHoldEntry = await testClient.query(
    `insert into finance.journal_entries
       (kind, reference, currency, activity_id, created_by)
     values ('escrow_hold', 'WAL-TEST-0002', 'NGN', 'services.hire', $1)
     returning id`,
    [userId],
  )
  await testClient.query(
    `insert into finance.postings
       (entry_id, ledger_account_id, direction, amount, currency, activity_id)
     values ($1, $2, 'credit', 3.0000, 'NGN', 'services.hire'),
            ($1, $3, 'debit', 3.0000, 'NGN', 'services.hire')`,
    [escrowHoldEntry.rows[0].id, walletLedgerId, escrowLedgerId],
  )
  await testClient.query("commit")

  const walletBalance = await testClient.query(
    `select currency, available::text, pending::text, total::text,
            withdrawable::text
       from finance.wallet_balances
      where account_id = $1 and currency = 'NGN'`,
    [accountId],
  )
  assert(walletBalance.rowCount === 1, "a wallet balance row is derived")
  assert(walletBalance.rows[0].available === "7.0000", "available is the net of wallet postings")
  assert(walletBalance.rows[0].pending === "3.0000", "pending is the held escrow amount")
  assert(walletBalance.rows[0].total === "10.0000", "total is available plus pending")
  assert(
    walletBalance.rows[0].withdrawable === "7.0000",
    "withdrawable equals available until payout reservations exist",
  )

  const walletStatement = await testClient.query(
    `select reference, entry_kind, direction, signed_amount::text,
            activity_id
       from finance.wallet_statement
      where account_id = $1 and currency = 'NGN'
      order by occurred_at desc, posting_id desc`,
    [accountId],
  )
  assert(
    walletStatement.rowCount === 4,
    "the statement lists every wallet posting, not the counterparty lines",
  )
  const statementTotal = walletStatement.rows.reduce(
    (sum, row) => sum + Number(row.signed_amount),
    0,
  )
  assert(statementTotal === 7, "the statement's signed amounts reconcile to the derived balance")
  const escrowStatement = walletStatement.rows.filter((row) => row.activity_id === "services.hire")
  assert(
    escrowStatement.length === 1 &&
      escrowStatement[0].entry_kind === "escrow_hold" &&
      escrowStatement[0].signed_amount === "-3.0000",
    "statement rows carry activity attribution",
  )

  const emptyAccount = await testClient.query(
    "insert into identity.accounts default values returning id",
  )
  const emptyBalance = await testClient.query(
    "select count(*)::int as count from finance.wallet_balances where account_id = $1",
    [emptyAccount.rows[0].id],
  )
  assert(
    emptyBalance.rows[0].count === 0,
    "an account with no ledger history has no stored wallet row",
  )

  await testClient.query("grant hivorr_api to postgres with set true")
  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [accountId, userId])
  const ownUsers = await testClient.query("select count(*)::int as count from identity.users")
  assert(ownUsers.rows[0].count === 1, "rls shows only the current account's users")
  const ownCredentials = await testClient.query(
    "select count(*)::int as count from identity.credentials",
  )
  assert(ownCredentials.rows[0].count === 1, "rls shows only the current user's credential")
  const crossAccountUpdate = await testClient.query(
    "update identity.users set display_name = 'blocked' where id = $1",
    [secondUserId],
  )
  assert(crossAccountUpdate.rowCount === 0, "rls blocks a cross-account update")

  const ownProfile = await testClient.query("select count(*)::int as count from profile.profiles")
  assert(ownProfile.rows[0].count === 1, "rls shows only the current account's profile")
  const ownActivations = await testClient.query(
    "select count(*)::int as count from profile.activity_activations",
  )
  assert(ownActivations.rows[0].count === 6, "rls shows only the current account's activations")
  const profileUpdate = await testClient.query(
    "update profile.profiles set display_name = 'Updated' where account_id = $1",
    [accountId],
  )
  assert(profileUpdate.rowCount === 1, "api may update its own profile")

  const ownSessions = await testClient.query("select count(*)::int as count from identity.sessions")
  assert(ownSessions.rows[0].count === 1, "rls shows only the current user's sessions")

  const ownLedgerAccounts = await testClient.query(
    "select count(*)::int as count from finance.ledger_accounts",
  )
  assert(
    ownLedgerAccounts.rows[0].count === 1,
    "rls shows only the current account's ledger account",
  )

  const ownPostings = await testClient.query("select count(*)::int as count from finance.postings")
  assert(
    ownPostings.rows[0].count === 5,
    "rls shows only postings on the current account's ledger and escrow",
  )

  const ownEntries = await testClient.query(
    "select count(*)::int as count from finance.journal_entries",
  )
  assert(
    ownEntries.rows[0].count === 4,
    "rls shows only journal entries touching the current account",
  )

  const ownProviderReferences = await testClient.query(
    "select count(*)::int as count from finance.provider_references",
  )
  assert(
    ownProviderReferences.rows[0].count === 1,
    "rls shows only provider references linked to the current account",
  )

  const ownEscrowAccounts = await testClient.query(
    "select count(*)::int as count from finance.escrow_accounts",
  )
  assert(
    ownEscrowAccounts.rows[0].count === 1,
    "rls shows only the current account's escrow reservations",
  )

  const ownPayoutAccounts = await testClient.query(
    "select count(*)::int as count from finance.payout_accounts",
  )
  assert(
    ownPayoutAccounts.rows[0].count === 1,
    "rls shows only the current account's payout accounts",
  )

  // Tier rows are visible to every account; the CBN seeds make the count
  // configuration-dependent, so assert the shape rather than a literal.
  const ownLimitRows = await testClient.query("select account_id, tier from finance.limits")
  assert(ownLimitRows.rows.length > 0, "rls shows the tier limits to the current account")
  assert(
    ownLimitRows.rows.every((row) => row.account_id === null && row.tier !== null),
    "rls shows tier limits and no other account's overrides",
  )

  const ownWalletBalance = await testClient.query(
    `select available::text, pending::text, total::text
       from finance.wallet_balances
      where currency = 'NGN'`,
  )
  assert(ownWalletBalance.rowCount === 1, "the wallet view shows only the current account")
  assert(
    ownWalletBalance.rows[0].available === "7.0000" &&
      ownWalletBalance.rows[0].pending === "3.0000" &&
      ownWalletBalance.rows[0].total === "10.0000",
    "the wallet figures reconcile to the current account's postings",
  )

  const ownStatement = await testClient.query(
    "select count(*)::int as count from finance.wallet_statement",
  )
  assert(
    ownStatement.rows[0].count === 4,
    "the statement is owner-scoped and lists only wallet postings",
  )

  let reconciliationReadDenied = false
  await testClient.query("savepoint finance_reconciliation_denied")
  try {
    await testClient.query("select count(*)::int as count from finance.reconciliation_runs")
  } catch (error) {
    reconciliationReadDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint finance_reconciliation_denied")
  }
  assert(reconciliationReadDenied, "reconciliation records require an audited administrator read")

  let ledgerInsertDenied = false
  await testClient.query("savepoint finance_insert_denied")
  try {
    await testClient.query(
      `insert into finance.ledger_accounts (kind, owner_type, owner_id, currency)
       values ('user_wallet', 'account', $1, 'NGN')`,
      [accountId],
    )
  } catch (error) {
    ledgerInsertDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint finance_insert_denied")
  }
  assert(ledgerInsertDenied, "the api role cannot create a ledger account")

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
  assert(unknownLookup.rowCount === 0, "pre-auth lookup returns nothing for an unknown email")

  const closedLookup = await testClient.query(
    "select * from identity.find_login_credential('closed@example.test')",
  )
  assert(closedLookup.rowCount === 0, "pre-auth lookup refuses a closed account")

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
    await testClient.query("select * from identity.list_grants($1, 'test')", [userId])
  } catch (error) {
    grantListDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint grant_list_denied")
  }
  assert(grantListDenied, "grant listing requires a grant-management grant")

  const lookup = await testClient.query(
    "select user_id, account_id from identity.find_login_credential('founder@example.test')",
  )
  assert(lookup.rowCount === 1, "pre-auth lookup returns one credential")
  assert(lookup.rows[0].user_id === userId, "pre-auth lookup returns the right user")
  await testClient.query("reset role")
  await testClient.query("commit")

  // The write path is tested in its own transaction: the service always starts
  // a fresh transaction, sets the identity, inserts the entry and postings, and
  // commits once.
  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [accountId, userId])
  const writeContext = await testClient.query("select platform.current_account_id() as account_id")
  assert(
    writeContext.rows[0].account_id === accountId,
    "the write transaction carries the account context",
  )
  const apiEntry = await testClient.query(
    `insert into finance.journal_entries
       (kind, reference, currency, created_by)
     values ('deposit', 'DEP-API-0001', 'NGN', $1)
     returning id`,
    [userId],
  )
  assert(
    apiEntry.rowCount === 1,
    "the api role may append a journal entry with an identity context",
  )
  const apiPostings = await testClient.query(
    `insert into finance.postings
       (entry_id, ledger_account_id, direction, amount, currency)
     values ($1, $2, 'debit', 7.0000, 'NGN'),
            ($1, $3, 'credit', 7.0000, 'NGN')`,
    [apiEntry.rows[0].id, walletLedgerId, clearingLedgerId],
  )
  assert(
    apiPostings.rowCount === 2,
    "the api role may append balanced postings with an identity context",
  )
  await testClient.query("reset role")
  await testClient.query("commit")

  // Escrow lifecycle: the API may open an escrow reservation and flag a
  // dispute, but release, refund and cancellation are disabled until BD-D03.
  const lifecycleRef = "00000000-0000-7000-8000-0000000000aa"
  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [accountId, userId])

  let nonEscrowLedgerDenied = false
  await testClient.query("savepoint ledger_kind_guard")
  try {
    await testClient.query(
      `insert into finance.ledger_accounts (kind, owner_type, owner_id, currency)
       values ('user_wallet', 'account', $1, 'NGN')`,
      [accountId],
    )
  } catch (error) {
    nonEscrowLedgerDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint ledger_kind_guard")
  }
  assert(nonEscrowLedgerDenied, "the api may create an escrow ledger account but no other kind")

  const lifecycleLedgerId = (await testClient.query("select platform.uuidv7() as id")).rows[0].id
  await testClient.query(
    `insert into finance.ledger_accounts
       (id, kind, owner_type, owner_id, currency)
     values ($1, 'escrow', 'activity', $2, 'NGN')`,
    [lifecycleLedgerId, lifecycleRef],
  )
  const lifecycleEscrow = await testClient.query(
    `insert into finance.escrow_accounts
       (ledger_account_id, payer_account_id, activity_id, activity_ref, currency)
     values ($1, $2, 'services.hire', $3, 'NGN')
     returning id`,
    [lifecycleLedgerId, accountId, lifecycleRef],
  )
  const lifecycleEscrowId = lifecycleEscrow.rows[0].id
  assert(lifecycleEscrow.rowCount === 1, "the api may open an escrow reservation")

  const disputed = await testClient.query(
    "update finance.escrow_accounts set state = 'disputed' where id = $1",
    [lifecycleEscrowId],
  )
  assert(disputed.rowCount === 1, "a held escrow may be flagged as disputed")

  let releaseDenied = false
  await testClient.query("savepoint escrow_release_guard")
  try {
    await testClient.query("update finance.escrow_accounts set state = 'released' where id = $1", [
      lifecycleEscrowId,
    ])
  } catch (error) {
    releaseDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint escrow_release_guard")
  }
  assert(releaseDenied, "a release is refused while the release policy is undecided")

  let invalidTransitionRejected = false
  await testClient.query("savepoint escrow_invalid_transition")
  try {
    await testClient.query("update finance.escrow_accounts set state = 'held' where id = $1", [
      lifecycleEscrowId,
    ])
  } catch (error) {
    invalidTransitionRejected = error?.code === "23514"
    await testClient.query("rollback to savepoint escrow_invalid_transition")
  }
  assert(invalidTransitionRejected, "an undefined escrow transition is refused")

  const providerReferenceRow = await testClient.query(
    `insert into finance.provider_references
       (account_id, provider, provider_reference, direction, status, amount,
        currency)
     values ($1, 'vfd', 'VFD-API-0001', 'deposit', 'received', 7.0000, 'NGN')
     returning id`,
    [accountId],
  )
  assert(
    providerReferenceRow.rowCount === 1,
    "the api may record a provider reference for its account",
  )

  const linkedProviderReference = await testClient.query(
    `update finance.provider_references
        set status = 'posted',
            journal_entry_id = $1,
            updated_at = now()
      where provider = 'vfd' and provider_reference = 'VFD-API-0001'`,
    [depositEntryId],
  )
  assert(
    linkedProviderReference.rowCount === 1,
    "the api may link a provider reference to its journal entry",
  )

  let duplicateProviderEventRejected = false
  await testClient.query("savepoint provider_reference_duplicate")
  try {
    await testClient.query(
      `insert into finance.provider_references
         (account_id, provider, provider_reference, direction, status, amount,
          currency)
       values ($1, 'vfd', 'VFD-API-0001', 'deposit', 'received', 7.0000, 'NGN')`,
      [accountId],
    )
  } catch (error) {
    duplicateProviderEventRejected = error?.code === "23505"
    await testClient.query("rollback to savepoint provider_reference_duplicate")
  }
  assert(duplicateProviderEventRejected, "a provider reference is stored once")

  await testClient.query("reset role")
  await testClient.query("commit")

  const adjustmentLedger = await testClient.query(
    `insert into finance.ledger_accounts (kind, owner_type, currency)
     values ('adjustment', 'platform', 'NGN')
     returning id`,
  )
  const adjustmentLedgerId = adjustmentLedger.rows[0].id

  await testClient.query("begin")
  const scopedKeyEntry = await testClient.query(
    `insert into finance.journal_entries
       (kind, reference, currency, idempotency_key, created_by)
     values ('adjustment', 'IDEM-SCOPE-0001', 'NGN', 'IDEM-SCOPE-1', $1)
     returning id`,
    [userId],
  )
  await testClient.query(
    `insert into finance.postings
       (entry_id, ledger_account_id, direction, amount, currency)
     values ($1, $2, 'debit', 1.0000, 'NGN'),
            ($1, $3, 'credit', 1.0000, 'NGN')`,
    [scopedKeyEntry.rows[0].id, clearingLedgerId, adjustmentLedgerId],
  )
  await testClient.query("commit")

  let duplicateIdempotencyKeyRejected = false
  try {
    await testClient.query(
      `insert into finance.journal_entries
         (kind, reference, currency, idempotency_key, created_by)
       values ('adjustment', 'IDEM-SCOPE-0002', 'NGN', 'IDEM-SCOPE-1', $1)`,
      [userId],
    )
  } catch (error) {
    duplicateIdempotencyKeyRejected = error?.code === "23505"
  }
  assert(duplicateIdempotencyKeyRejected, "the same creator cannot reuse an idempotency key")

  await testClient.query("begin")
  const otherCreatorEntry = await testClient.query(
    `insert into finance.journal_entries
       (kind, reference, currency, idempotency_key, created_by)
     values ('adjustment', 'IDEM-SCOPE-0003', 'NGN', 'IDEM-SCOPE-1', $1)
     returning id`,
    [secondUserId],
  )
  await testClient.query(
    `insert into finance.postings
       (entry_id, ledger_account_id, direction, amount, currency)
     values ($1, $2, 'debit', 1.0000, 'NGN'),
            ($1, $3, 'credit', 1.0000, 'NGN')`,
    [otherCreatorEntry.rows[0].id, clearingLedgerId, adjustmentLedgerId],
  )
  await testClient.query("commit")
  assert(otherCreatorEntry.rowCount === 1, "two creators may use the same idempotency key")

  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [
    secondAccountId,
    secondUserId,
  ])
  const foreignLedgerAccounts = await testClient.query(
    "select count(*)::int as count from finance.ledger_accounts",
  )
  assert(foreignLedgerAccounts.rows[0].count === 0, "rls hides another account's ledger account")
  const foreignPostings = await testClient.query(
    "select count(*)::int as count from finance.postings",
  )
  assert(foreignPostings.rows[0].count === 0, "rls hides another account's postings")
  const foreignLimitRows = await testClient.query("select account_id, tier from finance.limits")
  assert(foreignLimitRows.rows.length > 0, "tier limits are visible to every account")
  assert(
    foreignLimitRows.rows.every(
      (row) => row.account_id === null || row.account_id === secondAccountId,
    ),
    "rls hides another account's limit overrides",
  )
  assert(
    foreignLimitRows.rows.filter((row) => row.account_id === secondAccountId).length === 1,
    "rls shows this account's own override",
  )
  const foreignWallet = await testClient.query(
    "select count(*)::int as count from finance.wallet_balances",
  )
  assert(foreignWallet.rows[0].count === 0, "the wallet view hides another account's figures")
  const foreignStatement = await testClient.query(
    "select count(*)::int as count from finance.wallet_statement",
  )
  assert(
    foreignStatement.rows[0].count === 0,
    "the statement view hides another account's postings",
  )
  const foreignEscrowUpdate = await testClient.query(
    "update finance.escrow_accounts set state = 'disputed' where id = $1",
    [lifecycleEscrowId],
  )
  assert(foreignEscrowUpdate.rowCount === 0, "rls blocks another account's escrow transition")
  const foreignProviderReferences = await testClient.query(
    "select count(*)::int as count from finance.provider_references",
  )
  assert(
    foreignProviderReferences.rows[0].count === 0,
    "rls hides another account's provider references",
  )
  await testClient.query("reset role")
  await testClient.query("commit")

  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  const noContext = await testClient.query("select count(*)::int as count from identity.users")
  assert(noContext.rows[0].count === 0, "rls denies without an identity context")
  const noContextProfiles = await testClient.query(
    "select count(*)::int as count from profile.profiles",
  )
  assert(noContextProfiles.rows[0].count === 0, "profile rls denies without an identity context")
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
  assert(noContextSessions.rows[0].count === 0, "session rls denies without an identity context")
  const noContextLedger = await testClient.query(
    "select count(*)::int as count from finance.ledger_accounts",
  )
  assert(noContextLedger.rows[0].count === 0, "ledger rls denies without an identity context")
  const noContextPostings = await testClient.query(
    "select count(*)::int as count from finance.postings",
  )
  assert(noContextPostings.rows[0].count === 0, "posting rls denies without an identity context")
  const noContextLimits = await testClient.query(
    "select count(*)::int as count from finance.limits",
  )
  assert(noContextLimits.rows[0].count === 0, "limit rls denies without an identity context")
  const noContextWallet = await testClient.query(
    "select count(*)::int as count from finance.wallet_balances",
  )
  assert(noContextWallet.rows[0].count === 0, "wallet view rls denies without an identity context")
  const noContextStatement = await testClient.query(
    "select count(*)::int as count from finance.wallet_statement",
  )
  assert(
    noContextStatement.rows[0].count === 0,
    "statement view rls denies without an identity context",
  )

  let noContextEntryDenied = false
  await testClient.query("savepoint finance_no_context_insert")
  try {
    await testClient.query(
      `insert into finance.journal_entries (kind, reference, currency)
       values ('adjustment', 'ADJ-NO-CONTEXT', 'NGN')`,
    )
  } catch (error) {
    noContextEntryDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint finance_no_context_insert")
  }
  assert(noContextEntryDenied, "the ledger insert policy fails closed without an identity context")
  await testClient.query("reset role")
  await testClient.query("commit")

  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [accountId, userId])

  let limitWriteDenied = false
  await testClient.query("savepoint limit_permission_guard")
  try {
    await testClient.query(
      `insert into finance.limits
         (account_id, limit_type, currency, amount, period, effective_from)
       values ($1, 'deposit', 'NGN', 10.0000, 'daily', '2030-01-01')`,
      [accountId],
    )
  } catch (error) {
    limitWriteDenied = error?.code === "42501"
    await testClient.query("rollback to savepoint limit_permission_guard")
  }
  assert(limitWriteDenied, "a user without configuration.write cannot create a limit")

  await testClient.query("reset role")
  await testClient.query("commit")

  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [accountId, actorId])
  const writtenLimit = await testClient.query(
    `insert into finance.limits
       (account_id, limit_type, currency, amount, period, effective_from,
        created_by)
     values ($1, 'deposit', 'NGN', 123.0000, 'daily', '2030-01-01', $2)
     returning id`,
    [emptyAccount.rows[0].id, actorId],
  )
  assert(writtenLimit.rowCount === 1, "a configuration writer may add an effective-dated limit")

  let duplicateLimitRejected = false
  await testClient.query("savepoint limit_duplicate_guard")
  try {
    await testClient.query(
      `insert into finance.limits
         (account_id, limit_type, currency, amount, period, effective_from,
          created_by)
       values ($1, 'deposit', 'NGN', 123.0000, 'daily', '2030-01-01', $2)`,
      [emptyAccount.rows[0].id, actorId],
    )
  } catch (error) {
    duplicateLimitRejected = error?.code === "23505"
    await testClient.query("rollback to savepoint limit_duplicate_guard")
  }
  assert(duplicateLimitRejected, "a duplicate limit scope and effective date is refused")

  await testClient.query("reset role")
  await testClient.query("commit")

  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [accountId, userId])
  const foreignLimit = await testClient.query(
    "select count(*)::int as count from finance.limits where account_id = $1",
    [emptyAccount.rows[0].id],
  )
  assert(
    foreignLimit.rows[0].count === 0,
    "an ordinary account cannot read another account's limit override",
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
    assert(role.rolcreatedb === false, `${role.rolname} cannot create databases`)
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
    await testClient.query("alter table platform.audit_log add column probe int")
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
  assert(probe.rows[0].allowed === false, "new functions start closed to the api role")
  await testClient.query("drop function platform.default_privilege_probe()")

  const workerIdentity = await testClient.query(
    "select has_table_privilege('hivorr_worker', 'identity.users', 'select') as allowed",
  )
  assert(workerIdentity.rows[0].allowed === false, "worker role cannot read identity users")

  const readonlyAudit = await testClient.query(
    "select has_table_privilege('hivorr_readonly', 'platform.audit_log', 'insert') as allowed",
  )
  assert(readonlyAudit.rows[0].allowed === false, "readonly role cannot append audit records")

  // ---- Verification lanes, cases, submissions, evidence and decisions (EP-02-010) ----
  const lanes = await testClient.query(
    "select key from profile.verification_lanes order by sort_order",
  )
  assert(
    JSON.stringify(lanes.rows.map((row) => row.key)) ===
      JSON.stringify(["identity", "kyc", "trade", "seller", "logistics", "business"]),
    "the six verification lanes are seeded in display order",
  )

  const laneWrite = await testClient.query(
    "select has_table_privilege('hivorr_api', 'profile.verification_lanes', 'insert') as allowed",
  )
  assert(laneWrite.rows[0].allowed === false, "the api role cannot add a verification lane")

  const business = await testClient.query(
    `insert into profile.businesses
       (account_id, trading_name, legal_name, registration_number)
     values ($1, 'Kuti Sema Trading', 'Kuti Sema Enterprises Ltd', 'RC-1234567')
     returning id`,
    [accountId],
  )
  assert(business.rowCount === 1, "a business profile is stored for the account")

  let duplicateBusinessRejected = false
  try {
    await testClient.query(
      `insert into profile.businesses
         (account_id, trading_name, legal_name, registration_number)
       values ($1, 'Second Trading', 'Second Legal Ltd', 'RC-7654321')`,
      [accountId],
    )
  } catch (error) {
    duplicateBusinessRejected = error?.code === "23505"
  }
  assert(duplicateBusinessRejected, "one business profile exists per account")

  let invalidBusinessRejected = false
  try {
    await testClient.query(
      `insert into profile.businesses
         (account_id, trading_name, legal_name, registration_number)
       values ($1, '   ', 'Legal Ltd', 'RC-1')`,
      [secondAccountId],
    )
  } catch (error) {
    invalidBusinessRejected = error?.code === "23514"
  }
  assert(invalidBusinessRejected, "a business requires a trading name")

  let invalidLaneRejected = false
  try {
    await testClient.query(
      "insert into profile.verification_cases (account_id, lane) values ($1, 'address')",
      [accountId],
    )
  } catch (error) {
    invalidLaneRejected = error?.code === "23503"
  }
  assert(invalidLaneRejected, "an unknown verification lane is refused")

  const verificationCase = await testClient.query(
    "insert into profile.verification_cases (account_id, lane) values ($1, 'identity') returning id",
    [accountId],
  )
  const verificationCaseId = verificationCase.rows[0].id

  let duplicateCaseRejected = false
  try {
    await testClient.query(
      "insert into profile.verification_cases (account_id, lane) values ($1, 'identity')",
      [accountId],
    )
  } catch (error) {
    duplicateCaseRejected = error?.code === "23505"
  }
  assert(duplicateCaseRejected, "one verification case exists per account and lane")

  const openSubmission = await testClient.query(
    `insert into profile.verification_submissions
       (case_id, account_id, lane, state, submitted_at)
     values ($1, $2, 'identity', 'SUBMITTED', now()) returning id`,
    [verificationCaseId, accountId],
  )
  const submissionId = openSubmission.rows[0].id

  let secondOpenRejected = false
  try {
    await testClient.query(
      `insert into profile.verification_submissions (case_id, account_id, lane, state)
       values ($1, $2, 'identity', 'DRAFT')`,
      [verificationCaseId, accountId],
    )
  } catch (error) {
    secondOpenRejected = error?.code === "23505"
  }
  assert(secondOpenRejected, "one active submission per lane is enforced")

  await testClient.query(
    "update profile.verification_submissions set state = 'UNDER_REVIEW' where id = $1",
    [submissionId],
  )
  await testClient.query(
    "update profile.verification_submissions set state = 'REJECTED', decided_at = now() where id = $1",
    [submissionId],
  )
  const resubmission = await testClient.query(
    `insert into profile.verification_submissions
       (case_id, account_id, lane, state, submitted_at)
     values ($1, $2, 'identity', 'SUBMITTED', now()) returning id`,
    [verificationCaseId, accountId],
  )
  assert(resubmission.rowCount === 1, "a rejected attempt frees the lane for resubmission")

  let badDigestRejected = false
  try {
    await testClient.query(
      `insert into profile.verification_evidence
         (submission_id, account_id, object_key, content_type, size_bytes, sha256)
       values ($1, $2, 'kyc/bad.pdf', 'application/pdf', 1024, 'not-a-digest')`,
      [submissionId, accountId],
    )
  } catch (error) {
    badDigestRejected = error?.code === "23514"
  }
  assert(badDigestRejected, "evidence requires a sha-256 digest")

  const evidence = await testClient.query(
    `insert into profile.verification_evidence
       (submission_id, account_id, object_key, content_type, size_bytes, sha256)
     values ($1, $2, 'kyc/id.pdf', 'application/pdf', 2048, $3) returning id`,
    [submissionId, accountId, "c".repeat(64)],
  )
  assert(evidence.rowCount === 1, "evidence stores a private object reference")
  const evidenceId = evidence.rows[0].id

  const decision = await testClient.query(
    `insert into profile.verification_decisions
       (case_id, submission_id, account_id, lane, decision, reason_code, reason, decided_by)
     values ($1, $2, $3, 'identity', 'APPROVED', 'evidence_verified',
             'all documents verified', $4)
     returning id`,
    [verificationCaseId, submissionId, accountId, actorId],
  )
  const decisionId = decision.rows[0].id

  let decisionUpdateRejected = false
  try {
    await testClient.query(
      "update profile.verification_decisions set reason = 'edited' where id = $1",
      [decisionId],
    )
  } catch (error) {
    decisionUpdateRejected = error?.code === "P0001"
  }
  assert(decisionUpdateRejected, "verification decisions are append-only")

  const decisionInsert = await testClient.query(
    "select has_table_privilege('hivorr_api', 'profile.verification_decisions', 'insert') as allowed",
  )
  assert(
    decisionInsert.rows[0].allowed === false,
    "the api role cannot record a verification decision directly",
  )

  // The control portal shares the lane vocabulary (CP-019): the review table now
  // references the registry instead of carrying its own list.
  const reviewCase = await testClient.query(
    `select * from admin.create_case(
       $1, 'verification_review', 'Seller verification', 'seller lane review',
       'normal', 'medium', null, 'control review lane test'
     )`,
    [actorId],
  )
  await testClient.query(
    "insert into admin.verification_reviews (case_id, lane) values ($1, 'seller')",
    [reviewCase.rows[0].id],
  )
  const reviewLane = await testClient.query(
    "select lane from admin.verification_reviews where case_id = $1",
    [reviewCase.rows[0].id],
  )
  assert(reviewLane.rows[0].lane === "seller", "a review records an approved lane")

  const legacyReviewCase = await testClient.query(
    `select * from admin.create_case(
       $1, 'verification_review', 'Legacy lane', 'legacy lane review',
       'normal', 'medium', null, 'legacy lane refusal test'
     )`,
    [actorId],
  )
  let legacyLaneRejected = false
  try {
    await testClient.query(
      "insert into admin.verification_reviews (case_id, lane) values ($1, 'address')",
      [legacyReviewCase.rows[0].id],
    )
  } catch (error) {
    legacyLaneRejected = error?.code === "23503"
  }
  assert(legacyLaneRejected, "a control review cannot name a lane outside the approved six")

  // ---- Lane transitions, independence and the review freeze (EP-02-011) ----
  const laneStates = [
    "NOT_STARTED",
    "DRAFT",
    "SUBMITTED",
    "UNDER_REVIEW",
    "APPROVED",
    "REJECTED",
    "EXPIRED",
  ]
  const approvedPairs = new Set([
    "NOT_STARTED->DRAFT",
    "DRAFT->SUBMITTED",
    "DRAFT->NOT_STARTED",
    "SUBMITTED->UNDER_REVIEW",
    "SUBMITTED->DRAFT",
    "SUBMITTED->EXPIRED",
    "UNDER_REVIEW->APPROVED",
    "UNDER_REVIEW->REJECTED",
    "APPROVED->EXPIRED",
    "REJECTED->DRAFT",
    "EXPIRED->DRAFT",
  ])
  for (const from of laneStates) {
    for (const to of laneStates) {
      const result = await testClient.query(
        "select profile.verification_transition_allowed($1, $2) as allowed",
        [from, to],
      )
      assert(
        result.rows[0].allowed === (from === to || approvedPairs.has(`${from}->${to}`)),
        `lane transition ${from}->${to} matches the approved table`,
      )
    }
  }

  const resubmissionId = resubmission.rows[0].id
  let earlyApprovalRejected = false
  try {
    await testClient.query(
      "update profile.verification_submissions set state = 'APPROVED' where id = $1",
      [resubmissionId],
    )
  } catch (error) {
    earlyApprovalRejected = error?.code === "23514"
  }
  assert(earlyApprovalRejected, "a submission cannot be approved before it is under review")

  await testClient.query(
    "update profile.verification_submissions set state = 'UNDER_REVIEW' where id = $1",
    [resubmissionId],
  )

  let frozenRejected = false
  try {
    await testClient.query(
      "update profile.profiles set display_name = 'Changed During Review' where account_id = $1",
      [accountId],
    )
  } catch (error) {
    frozenRejected = error?.code === "23514"
  }
  assert(frozenRejected, "identity fields are frozen while a submission is under review")

  const bioDuringReview = await testClient.query(
    "update profile.profiles set bio = 'updated during review' where account_id = $1 returning bio",
    [accountId],
  )
  assert(bioDuringReview.rowCount === 1, "non-identity profile fields stay editable during review")

  await testClient.query(
    "update profile.verification_submissions set state = 'REJECTED', decided_at = now() where id = $1",
    [resubmissionId],
  )
  const afterReject = await testClient.query(
    "update profile.profiles set display_name = 'Changed After Review' where account_id = $1 returning display_name",
    [accountId],
  )
  assert(afterReject.rowCount === 1, "the freeze lifts after rejection")

  await testClient.query(
    "insert into profile.verification_cases (account_id, lane) values ($1, 'trade')",
    [accountId],
  )
  for (const state of ["DRAFT", "SUBMITTED", "UNDER_REVIEW", "APPROVED"]) {
    await testClient.query(
      "update profile.verification_cases set state = $2 where account_id = $1 and lane = 'identity'",
      [accountId, state],
    )
  }
  const tradeState = await testClient.query(
    "select state from profile.verification_cases where account_id = $1 and lane = 'trade'",
    [accountId],
  )
  assert(tradeState.rows[0].state === "NOT_STARTED", "approving one lane leaves another untouched")

  let reopenRejected = false
  try {
    await testClient.query(
      "update profile.verification_cases set state = 'DRAFT' where account_id = $1 and lane = 'identity'",
      [accountId],
    )
  } catch (error) {
    reopenRejected = error?.code === "23514"
  }
  assert(reopenRejected, "an approved lane cannot be reopened")

  let skippedStateRejected = false
  try {
    await testClient.query(
      "update profile.verification_cases set state = 'APPROVED' where account_id = $1 and lane = 'trade'",
      [accountId],
    )
  } catch (error) {
    skippedStateRejected = error?.code === "23514"
  }
  assert(skippedStateRejected, "a lane cannot skip straight to approved")

  // ---- Evidence scan transitions (EP-02-012, scanning slice) ----
  const scanStates = ["PENDING", "CLEAN", "INFECTED", "FAILED"]
  const approvedScans = new Set(["PENDING->CLEAN", "PENDING->INFECTED", "PENDING->FAILED"])
  for (const from of scanStates) {
    for (const to of scanStates) {
      const result = await testClient.query(
        "select profile.evidence_scan_transition_allowed($1, $2) as allowed",
        [from, to],
      )
      assert(
        result.rows[0].allowed === (from === to || approvedScans.has(`${from}->${to}`)),
        `scan transition ${from}->${to} matches the approved table`,
      )
    }
  }

  const scanDecision = await testClient.query(
    "update profile.verification_evidence set scan_state = 'CLEAN' where id = $1 returning scan_state",
    [evidenceId],
  )
  assert(scanDecision.rows[0].scan_state === "CLEAN", "a pending file may be decided clean")

  let rescannedRejected = false
  try {
    await testClient.query(
      "update profile.verification_evidence set scan_state = 'INFECTED' where id = $1",
      [evidenceId],
    )
  } catch (error) {
    rescannedRejected = error?.code === "23514"
  }
  assert(rescannedRejected, "a decided scan cannot be changed")

  // A decided attempt must record when it was decided, and nothing else may.
  const businessCase = await testClient.query(
    "insert into profile.verification_cases (account_id, lane) values ($1, 'business') returning id",
    [accountId],
  )
  const businessSubmission = await testClient.query(
    `insert into profile.verification_submissions
       (case_id, account_id, lane, state, submitted_at)
     values ($1, $2, 'business', 'SUBMITTED', now()) returning id`,
    [businessCase.rows[0].id, accountId],
  )
  const businessSubmissionId = businessSubmission.rows[0].id
  await testClient.query(
    "update profile.verification_submissions set state = 'UNDER_REVIEW' where id = $1",
    [businessSubmissionId],
  )
  let undatedDecisionRejected = false
  try {
    await testClient.query(
      "update profile.verification_submissions set state = 'APPROVED' where id = $1",
      [businessSubmissionId],
    )
  } catch (error) {
    undatedDecisionRejected = error?.code === "23514"
  }
  assert(undatedDecisionRejected, "a decided attempt must record its decision time")

  let strayDecisionTimeRejected = false
  try {
    await testClient.query(
      "update profile.verification_submissions set decided_at = now() where id = $1",
      [businessSubmissionId],
    )
  } catch (error) {
    strayDecisionTimeRejected = error?.code === "23514"
  }
  assert(strayDecisionTimeRejected, "only a decided attempt carries a decision time")

  await testClient.query("begin")
  await testClient.query("set role hivorr_api")
  await testClient.query("select platform.set_identity_context($1, $2)", [accountId, userId])
  const ownCase = await testClient.query(
    "select count(*)::int as count from profile.verification_cases where id = $1",
    [verificationCaseId],
  )
  assert(ownCase.rows[0].count === 1, "an account reads its own verification case")
  const ownEvidence = await testClient.query(
    "select count(*)::int as count from profile.verification_evidence where id = $1",
    [evidenceId],
  )
  assert(ownEvidence.rows[0].count === 1, "an account reads its own evidence reference")
  const ownDecision = await testClient.query(
    "select count(*)::int as count from profile.verification_decisions where id = $1",
    [decisionId],
  )
  assert(ownDecision.rows[0].count === 1, "an account reads its own verification decision")
  const lanesVisible = await testClient.query(
    "select count(*)::int as count from profile.verification_lanes",
  )
  assert(lanesVisible.rows[0].count === 6, "every authenticated account reads the lane registry")
  const ownBusiness = await testClient.query(
    "select count(*)::int as count from profile.businesses",
  )
  assert(ownBusiness.rows[0].count === 1, "an account reads its own business profile")

  await testClient.query("select platform.set_identity_context($1, $2)", [
    secondAccountId,
    secondUserId,
  ])
  const foreignCase = await testClient.query(
    "select count(*)::int as count from profile.verification_cases",
  )
  assert(foreignCase.rows[0].count === 0, "rls hides another account's verification case")
  const foreignVerificationEvidence = await testClient.query(
    "select count(*)::int as count from profile.verification_evidence",
  )
  assert(
    foreignVerificationEvidence.rows[0].count === 0,
    "rls hides another account's evidence reference",
  )
  const foreignDecision = await testClient.query(
    "select count(*)::int as count from profile.verification_decisions",
  )
  assert(foreignDecision.rows[0].count === 0, "rls hides another account's verification decision")
  const foreignBusiness = await testClient.query(
    "select count(*)::int as count from profile.businesses",
  )
  assert(foreignBusiness.rows[0].count === 0, "rls hides another account's business profile")

  let crossAccountInsertRejected = false
  await testClient.query("savepoint verification_insert_guard")
  try {
    await testClient.query(
      "insert into profile.verification_cases (account_id, lane) values ($1, 'trade')",
      [accountId],
    )
  } catch (error) {
    crossAccountInsertRejected = error?.code === "42501"
    await testClient.query("rollback to savepoint verification_insert_guard")
  }
  assert(crossAccountInsertRejected, "rls refuses a case written for another account")
  await testClient.query("rollback")

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
