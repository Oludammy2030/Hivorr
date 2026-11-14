import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

const baseUrl = process.env.IDENTITY_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip

const root = process.cwd()
const migrationsDirectory = path.join(root, "supabase", "migrations")

const denialMigrationSql = readFileSync(
  path.join(migrationsDirectory, "20261114001200_admin_add_access_denials.sql"),
  "utf8",
)

describe("access denial migration", () => {
  it("keeps a denial instead of deleting it", () => {
    expect(denialMigrationSql).toMatch(/add column revoked_at timestamptz/)
    expect(denialMigrationSql).toMatch(/add column revoked_reason text/)
    expect(denialMigrationSql).toMatch(/access_denials_revocation_shape/)
  })

  it("ignores a revoked denial in both permission checks", () => {
    // The new migration must replace both checks rather than add new ones,
    // because the originals live in earlier migrations.
    const replaced = denialMigrationSql.match(
      /create or replace function admin\.(actor_has_platform_permission|actor_holds_platform_permission)[\s\S]*?\$\$;/g,
    )
    expect(replaced).toHaveLength(2)
    for (const body of replaced ?? []) {
      expect(
        body,
        "a replaced permission check reads denials without honouring revocation",
      ).toMatch(/ad\.revoked_at is null/)
    }
  })

  it("refuses self-change in both directions", () => {
    const createBody = denialMigrationSql.slice(
      denialMigrationSql.indexOf("create function admin.create_access_denial"),
      denialMigrationSql.indexOf("create function admin.revoke_access_denial"),
    )
    const revokeBody = denialMigrationSql.slice(
      denialMigrationSql.indexOf("create function admin.revoke_access_denial"),
    )

    expect(createBody).toMatch(/self_denial_forbidden/)
    expect(revokeBody).toMatch(/self_denial_forbidden/)
    expect(createBody).toMatch(/last_permission_holder/)
  })

  it("gates the write functions on admin.role.manage", () => {
    expect(denialMigrationSql).toMatch(
      /create function admin\.create_access_denial[\s\S]*?admin\.actor_holds_platform_permission\(p_actor_user_id, 'admin\.role\.manage'\)/,
    )
    expect(denialMigrationSql).toMatch(
      /create function admin\.revoke_access_denial[\s\S]*?admin\.actor_holds_platform_permission\(p_actor_user_id, 'admin\.role\.manage'\)/,
    )
  })
})

describeIntegration("access denial lifecycle", () => {
  const databaseName = `hivorr_denials_test_${Date.now()}`
  let admin: Client
  let database: Client
  let operatorId: string
  let targetId: string

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

      const operator = await database.query<{ id: string }>(
        `with account as (insert into identity.accounts default values returning id)
       insert into identity.users (account_id, email, display_name)
       select account.id, 'operator@hivorr.com', 'Operator' from account
       returning id`,
      )
      operatorId = operator.rows[0]!.id

      const target = await database.query<{ id: string }>(
        `with account as (insert into identity.accounts default values returning id)
       insert into identity.users (account_id, email, display_name)
       select account.id, 'target@hivorr.com', 'Target' from account
       returning id`,
      )
      targetId = target.rows[0]!.id

      // Both hold the founder role at platform scope, so denial and revocation
      // can be exercised in both directions.
      await database.query(
        `insert into admin.role_assignments (user_id, role_id, scope_type, granted_by)
       select holder, r.id, 'platform', $1
         from admin.roles r, unnest(array[$1, $2]::uuid[]) as holder
        where r.key = 'founder'`,
        [operatorId, targetId],
      )
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

  it("denies a permission, and revocation restores it", async () => {
    const before = await database.query<{ allowed: boolean }>(
      "select admin.actor_holds_platform_permission($1, 'admin.user.read') as allowed",
      [targetId],
    )
    expect(before.rows[0]!.allowed).toBe(true)

    const created = await database.query<{ id: string }>(
      `select id from admin.create_access_denial(
         $1, 'target@hivorr.com', 'admin.user.read', 'platform', null, null,
         'temporary removal', 'staging')`,
      [operatorId],
    )
    const denialId = created.rows[0]!.id

    const denied = await database.query<{ allowed: boolean }>(
      "select admin.actor_holds_platform_permission($1, 'admin.user.read') as allowed",
      [targetId],
    )
    expect(denied.rows[0]!.allowed).toBe(false)

    await database.query(
      `select * from admin.revoke_access_denial($1, $2, 'restored', 'staging')`,
      [operatorId, denialId],
    )

    const restored = await database.query<{ allowed: boolean }>(
      "select admin.actor_holds_platform_permission($1, 'admin.user.read') as allowed",
      [targetId],
    )
    expect(restored.rows[0]!.allowed).toBe(true)
  })

  it("refuses a denial of the operator's own authority", async () => {
    await expect(
      database.query(
        `select * from admin.create_access_denial(
           $1, 'operator@hivorr.com', 'admin.user.read', 'platform', null, null,
           'self', 'staging')`,
        [operatorId],
      ),
    ).rejects.toMatchObject({ code: "42501" })
  })

  it("refuses to lift the operator's own denial", async () => {
    const created = await database.query<{ id: string }>(
      `select id from admin.create_access_denial(
         $1, 'target@hivorr.com', 'admin.audit.read', 'platform', null, null,
         'audit removal', 'staging')`,
      [operatorId],
    )

    await expect(
      database.query(
        `select * from admin.revoke_access_denial($1, $2, 'self', 'staging')`,
        [targetId, created.rows[0]!.id],
      ),
    ).rejects.toMatchObject({ code: "42501" })
  })

  it("refuses a duplicate active denial at the same scope", async () => {
    await database.query(
      `select * from admin.create_access_denial(
         $1, 'target@hivorr.com', 'admin.report.read', 'platform', null, null,
         'first', 'staging')`,
      [operatorId],
    )

    await expect(
      database.query(
        `select * from admin.create_access_denial(
           $1, 'target@hivorr.com', 'admin.report.read', 'platform', null, null,
           'second', 'staging')`,
        [operatorId],
      ),
    ).rejects.toMatchObject({ code: "23505" })
  })
})
