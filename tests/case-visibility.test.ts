import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

const baseUrl = process.env.IDENTITY_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip

const migrationsDirectory = path.join(process.cwd(), "supabase", "migrations")

describeIntegration("case visibility scope", () => {
  const databaseName = `hivorr_case_scope_test_${Date.now()}`
  let admin: Client
  let database: Client

  let careId: string
  let governanceId: string
  let careCaseId: string
  let governanceCaseId: string
  let unassignedCaseId: string

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

  async function grant(userId: string, ...permissions: string[]) {
    for (const permission of permissions) {
      await database.query(
        `insert into admin.permission_grants
           (user_id, permission_key, scope_type, reason)
         values ($1, $2, 'platform', 'integration test')`,
        [userId, permission],
      )
    }
  }

  async function join(userId: string, departmentKey: string) {
    await database.query(
      `insert into admin.department_members
         (department_id, user_id, membership_role, created_by)
       select d.id, $1, 'member', $1
         from admin.departments d
        where d.key = $2`,
      [userId, departmentKey],
    )
  }

  async function createCase(actorId: string, title: string): Promise<string> {
    const result = await database.query<{ id: string }>(
      `select id from admin.create_case(
         $1, 'support', $2, 'visibility test', 'normal', 'low', 'support',
         'integration test case')`,
      [actorId, title],
    )
    return result.rows[0]!.id
  }

  beforeAll(async () => {
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

    careId = await createUser("care@hivorr.com")
    governanceId = await createUser("governance@hivorr.com")

    await grant(careId, "admin.case.read", "admin.case.assign")
    await join(careId, "customer_care")
    await grant(governanceId, "admin.case.read", "admin.case.assign")
    await join(governanceId, "governance")

    careCaseId = await createCase(careId, "Care case")
    governanceCaseId = await createCase(
      governanceId,
      "Governance investigation",
    )
    unassignedCaseId = await createCase(careId, "Unfiled case")

    await database.query(
      `update admin.cases set department_id =
         (select id from admin.departments where key = 'customer_care')
       where id = $1`,
      [careCaseId],
    )
    await database.query(
      `update admin.cases set department_id =
         (select id from admin.departments where key = 'governance')
       where id = $1`,
      [governanceCaseId],
    )
  }, 60_000)

  afterAll(async () => {
    await database?.end()
    if (admin) {
      await admin.query(`drop database if exists "${databaseName}"`)
      await admin.end()
    }
  })

  async function visibleCaseIds(actorId: string): Promise<readonly string[]> {
    const result = await database.query<{ id: string }>(
      "select * from admin.list_cases($1, '', '', '')",
      [actorId],
    )
    return result.rows.map((row) => row.id)
  }

  it("shows a department member only their department and the unfiled pool", async () => {
    const visible = await visibleCaseIds(careId)

    expect(visible).toContain(careCaseId)
    expect(visible).toContain(unassignedCaseId)
    expect(visible).not.toContain(governanceCaseId)
  })

  it("shows the other department its own case only", async () => {
    const visible = await visibleCaseIds(governanceId)

    expect(visible).toContain(governanceCaseId)
    expect(visible).not.toContain(careCaseId)
  })

  it("reveals a case assigned across departments to its assignee", async () => {
    await database.query(
      "update admin.cases set assignee_id = $2 where id = $1",
      [governanceCaseId, careId],
    )

    const visible = await visibleCaseIds(careId)
    expect(visible).toContain(governanceCaseId)
  })

  it("answers not-found for the timeline of an invisible case", async () => {
    const error = await database
      .query("select * from admin.list_case_events($1, $2)", [
        careId,
        governanceCaseId,
      ])
      .catch((value: unknown) => value)

    expect(error).toMatchObject({ code: "P0002" })
  })

  it("answers not-found for evidence on an invisible case", async () => {
    const reviewerId = await createUser("evidence@hivorr.com")
    await grant(reviewerId, "admin.evidence.read")

    const error = await database
      .query("select * from admin.list_case_evidence($1, $2)", [
        reviewerId,
        careCaseId,
      ])
      .catch((value: unknown) => value)

    expect(error).toMatchObject({ code: "P0002" })
  })

  it("makes the unguarded case view internal only", async () => {
    const result = await database.query<{ callable: boolean }>(
      "select has_function_privilege('hivorr_api', 'admin.case_view(uuid)', 'execute') as callable",
    )
    expect(result.rows[0]!.callable).toBe(false)
  })
})
