import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

const baseUrl = process.env.IDENTITY_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip

const migrationsDirectory = path.join(process.cwd(), "supabase", "migrations")

describeIntegration("directory search and staff status reads", () => {
  const databaseName = `hivorr_directory_test_${Date.now()}`
  let admin: Client
  let database: Client

  let operatorId: string
  let operatorAccountId: string
  let targetId: string

  async function createUser(email: string): Promise<string> {
    const result = await database.query<{ id: string }>(
      `with account as (insert into identity.accounts default values returning id)
       insert into identity.users (account_id, email, display_name)
       select account.id, $1, $1 from account
       returning id`,
      [email],
    )
    return result.rows[0]!.id
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
      targetId = await createUser("target@hivorr.com")

      const operator = await database.query<{ account_id: string }>(
        "select account_id from identity.users where id = $1",
        [operatorId],
      )
      operatorAccountId = operator.rows[0]!.account_id

      await database.query(
        `insert into admin.staff_profiles (user_id, engagement_status)
       values ($1, 'active')`,
        [targetId],
      )
      for (const permission of ["admin.user.read", "admin.user.manage"]) {
        await database.query(
          `insert into admin.permission_grants
           (user_id, permission_key, scope_type, reason)
         values ($1, $2, 'platform', 'integration test')`,
          [operatorId, permission],
        )
      }

      // Fixtures chosen so an unescaped pattern and a literal one disagree.
      await createUser("betaname@example.test")
      await createUser("weird%name@example.test")
      await createUser("underscore_holder@example.test")
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

  async function search(term: string): Promise<readonly string[]> {
    // `list_users` reads the caller from the transaction-scoped identity
    // context, exactly as the API sets it.
    await database.query("begin")
    try {
      await database.query("select platform.set_identity_context($1, $2)", [
        operatorAccountId,
        operatorId,
      ])
      const result = await database.query<{ email: string }>(
        "select * from admin.list_users($1, '', null, null, 50)",
        [term],
      )
      await database.query("commit")
      return result.rows.map((row) => row.email)
    } catch (error) {
      await database.query("rollback")
      throw error
    }
  }

  it("treats a percent in the search term as a literal character", async () => {
    const results = await search("%name")

    expect(results).toEqual(["weird%name@example.test"])
  })

  it("treats an underscore in the search term as a literal character", async () => {
    const results = await search("underscore_holder")

    expect(results).toEqual(["underscore_holder@example.test"])
  })

  it("still finds an ordinary substring", async () => {
    const results = await search("betaname")

    expect(results).toEqual(["betaname@example.test"])
  })

  it("returns an unfiltered page for an empty term", async () => {
    const results = await search("")

    expect(results.length).toBeGreaterThanOrEqual(5)
  })

  it("reads another staff member's status for the audit before-state", async () => {
    const result = await database.query<{ status: string }>(
      "select admin.staff_status_of($1, $2) as status",
      [operatorId, targetId],
    )

    expect(result.rows[0]!.status).toBe("active")
  })

  it("refuses the staff status read without the staff permission", async () => {
    const strangerId = await createUser("stranger@hivorr.com")

    const error = await database
      .query("select admin.staff_status_of($1, $2)", [strangerId, targetId])
      .catch((value: unknown) => value)

    expect(error).toMatchObject({ code: "42501" })
  })
})
