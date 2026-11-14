import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

const baseUrl = process.env.IDENTITY_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip

const migrationsDirectory = path.join(process.cwd(), "supabase", "migrations")

function migrationSqlBefore(prefix: string): string {
  const target = readdirSync(migrationsDirectory).find((entry) =>
    entry.startsWith(prefix),
  )
  if (!target) throw new Error(`migration ${prefix} not found`)
  return readFileSync(path.join(migrationsDirectory, target), "utf8")
}

describe("staff status revocation migration", () => {
  const sql = migrationSqlBefore("20261114001300")

  it("revokes individual permission grants on offboarding", () => {
    expect(sql).toMatch(
      /update admin\.permission_grants pg[\s\S]*?set revoked_at = now\(\)/,
    )
  })

  it("refuses self-change", () => {
    expect(sql).toMatch(/self_staff_change_forbidden/)
    expect(sql).toMatch(/p_user_id = v_actor/)
  })

  it("protects the last holder of a governance administration permission", () => {
    expect(sql).toMatch(/last_staff_manager/)
    expect(sql).toMatch(/platform_permission_holders/)
  })
})

describeIntegration("staff status guards", () => {
  const databaseName = `hivorr_staff_status_test_${Date.now()}`
  let admin: Client
  let database: Client

  let operatorId: string
  let accountId: string
  let revokeeId: string
  let lastHolderId: string

  async function createUser(email: string): Promise<string> {
    const result = await database.query<{ user_id: string account_id: string }>(
      `with account as (
         insert into identity.accounts default values returning id
       ), created as (
         insert into identity.users (account_id, email, display_name)
         select account.id, $1, $1 from account
         returning id, account_id
       ), profile as (
         insert into admin.staff_profiles (user_id, engagement_status)
         select created.id, 'active' from created
         returning user_id
       )
       select profile.user_id, created.account_id
         from profile, created`,
      [email],
    )
    const row = result.rows[0]!
    if (email === "operator@hivorr.com") accountId = row.account_id
    return row.user_id
  }

  beforeAll(
    async () => {
      admin = new Client({ connectionString: baseUrl })
      await admin.connect()
      await admin.query(`create database "${databaseName}"`)

      const url = new URL(baseUrl!)
      url.pathname = `/${databaseName}`
      database = new Client({ connectionString: url.toString() })
      await database.connect()

      for (const file of readdirSync(migrationsDirectory)
        .filter((entry) => entry.endsWith(".sql"))
        .sort()) {
        await database.query(
          readFileSync(path.join(migrationsDirectory, file), "utf8"),
        )
      }

      operatorId = await createUser("operator@hivorr.com")
      revokeeId = await createUser("revokee@hivorr.com")
      lastHolderId = await createUser("lastholder@hivorr.com")

      // The operator may administer staff, and holds no role beyond that, so the
      // governance role is held only by the two targets.
      await database.query(
        `insert into admin.permission_grants
         (user_id, permission_key, scope_type, reason)
       values ($1, 'admin.user.manage', 'platform', 'staff administration')`,
        [operatorId],
      )

      for (const userId of [revokeeId, lastHolderId]) {
        await database.query(
          `insert into admin.role_assignments
           (user_id, role_id, scope_type, granted_by, reason)
         select $1, r.id, 'platform', $2, 'governance administration'
           from admin.roles r where r.key = 'governance_admin'`,
          [userId, operatorId],
        )
        // Individual grants outside a role are the ones offboarding used to miss.
        await database.query(
          `insert into admin.permission_grants
           (user_id, permission_key, scope_type, reason)
         values ($1, 'admin.user.read', 'platform', 'read the directory')`,
          [userId],
        )
        await database.query(
          `insert into identity.grants
           (user_id, granted_by, grant_type, scope, environment)
         values ($1, $1, 'staff', 'staff.support.handle', 'staging')`,
          [userId],
        )
      }
    },
    60_000,
  )

  afterAll(async () => {
    await database?.end()
    if (admin) {
      await admin.query(`drop database if exists "${databaseName}"`)
      await admin.end()
    }
  })

  async function actAsOperator() {
    await database.query("select platform.set_identity_context($1, $2)", [
      accountId,
      operatorId,
    ])
  }

  it("refuses to change the operator's own staff status", async () => {
    await actAsOperator()
    await expect(
      database.query(
        "select * from admin.set_staff_status($1, 'suspended', 'testing self')",
        [operatorId],
      ),
    ).rejects.toMatchObject({ code: "42501" })
  })

  it("revokes individual permission grants when offboarding", async () => {
    await actAsOperator()
    const result = await database.query<{
      permission_grants_revoked: string
      grants_revoked: string
    }>(
      "select * from admin.set_staff_status($1, 'offboarded', 'left the company')",
      [revokeeId],
    )

    expect(Number(result.rows[0]!.permission_grants_revoked)).toBe(1)
    expect(Number(result.rows[0]!.grants_revoked)).toBe(1)

    const remaining = await database.query<{ count: string }>(
      `select count(*) from admin.permission_grants
        where user_id = $1 and revoked_at is null`,
      [revokeeId],
    )
    expect(Number(remaining.rows[0]!.count)).toBe(0)

    const roles = await database.query<{ count: string }>(
      `select count(*) from admin.role_assignments
        where user_id = $1 and revoked_at is null`,
      [revokeeId],
    )
    expect(Number(roles.rows[0]!.count)).toBe(0)

    const grants = await database.query<{ count: string }>(
      `select count(*) from identity.grants
        where user_id = $1 and revoked_at is null`,
      [revokeeId],
    )
    expect(Number(grants.rows[0]!.count)).toBe(0)
  })

  it("refuses to offboard the last governance administrator", async () => {
    await actAsOperator()
    await expect(
      database.query(
        "select * from admin.set_staff_status($1, 'offboarded', 'left the company')",
        [lastHolderId],
      ),
    ).rejects.toMatchObject({ code: "23514" })
  })
})
