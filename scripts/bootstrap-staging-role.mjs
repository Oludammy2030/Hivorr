#!/usr/bin/env node
// Founder role bootstrap for an existing staging account.
//
// Run only through `.github/workflows/bootstrap-staging-role.yml`, which is
// restricted to FOUNDER_GITHUB_LOGIN and the staging environment. The script
// uses the staging migrator credential because the runtime role has no write
// grant on identity.grants or admin.role_assignments. It is idempotent and
// writes its own audit record.

import { Client } from "pg"

const email = (process.env.FOUNDER_EMAIL ?? "").trim().toLowerCase()
const connectionString = process.env.DATABASE_URL
const environment = process.env.HIVORR_ENV ?? "staging"

if (!email) {
  console.error("FOUNDER_EMAIL is required")
  process.exit(1)
}
if (!connectionString) {
  console.error("DATABASE_URL is required")
  process.exit(1)
}
if (environment !== "staging") {
  console.error("This bootstrap is staging-only")
  process.exit(1)
}

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
})

try {
  await client.connect()
  await client.query("begin")

  const user = await client.query(
    `select id, account_id
       from identity.users
      where lower(email) = $1
        and status <> 'closed'
      limit 1`,
    [email],
  )
  if (user.rowCount === 0) {
    throw new Error("No staging user exists for that email")
  }
  const userId = user.rows[0].id
  const accountId = user.rows[0].account_id

  const role = await client.query(
    `select id from admin.roles where key = 'founder'`,
  )
  if (role.rowCount === 0) {
    throw new Error("The founder role is not seeded")
  }
  const roleId = role.rows[0].id

  const scopes = ["admin.grant.manage", "admin.grant.read", "admin.audit.read"]
  let grantsInserted = 0
  for (const scope of scopes) {
    const inserted = await client.query(
      `insert into identity.grants
         (user_id, grant_type, scope, environment, granted_by)
       select $1, 'admin', $2, $3, null
       where not exists (
         select 1 from identity.grants
          where user_id = $1 and scope = $2 and environment = $3
            and revoked_at is null
       )`,
      [userId, scope, environment],
    )
    grantsInserted += inserted.rowCount
  }

  const assignment = await client.query(
    `insert into admin.role_assignments
       (user_id, role_id, scope_type, granted_by, reason)
     select $1, $2, 'platform', null, 'Founder staging bootstrap'
     where not exists (
       select 1 from admin.role_assignments
        where user_id = $1 and role_id = $2 and scope_type = 'platform'
          and revoked_at is null
     )`,
    [userId, roleId],
  )

  await client.query(
    `insert into platform.audit_log
       (actor_type, actor_id, actor_audience, environment, action,
        target_type, target_id, after_summary)
     values ('system', null, 'system', $1, 'system.bootstrap_founder_role',
             'user', $2, $3::jsonb)`,
    [
      environment,
      userId,
      JSON.stringify({
        accountId,
        grantsInserted,
        roleAssignmentInserted: assignment.rowCount,
      }),
    ],
  )

  await client.query("commit")
  console.log("bootstrap: ok")
  console.log(`grants_inserted=${grantsInserted}`)
  console.log(`role_assignments_inserted=${assignment.rowCount}`)
} catch (error) {
  await client.query("rollback").catch(() => undefined)
  console.error(
    "bootstrap: failed:",
    error instanceof Error ? error.message : "unknown error",
  )
  process.exitCode = 1
} finally {
  await client.end().catch(() => undefined)
}
