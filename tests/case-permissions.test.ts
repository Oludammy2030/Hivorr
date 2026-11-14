import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

const baseUrl = process.env.IDENTITY_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip

const migrationsDirectory = path.join(process.cwd(), "supabase", "migrations")
const gateSql = readFileSync(
  path.join(
    migrationsDirectory,
    "20261114001400_admin_alter_case_permission_gates.sql",
  ),
  "utf8",
)

function functionBody(name: string): string {
  const start = gateSql.indexOf(`function admin.${name}`)
  if (start < 0) throw new Error(`function ${name} not found`)
  return gateSql.slice(start, gateSql.indexOf("$$;", start))
}

describe("case permission gates", () => {
  it("gates evidence reads on the evidence permission", () => {
    for (const name of ["list_case_evidence", "record_evidence_access"]) {
      expect(functionBody(name)).toMatch(
        /actor_holds_platform_permission\(p_actor_user_id, 'admin\.evidence\.read'\)/,
      )
    }
  })

  it("gates a decision request on the recommend permission", () => {
    expect(functionBody("request_case_decision")).toMatch(
      /actor_holds_platform_permission\(p_actor_user_id, 'admin\.case\.recommend'\)/,
    )
  })

  it("no longer admits evidence through the case permission", () => {
    expect(functionBody("list_case_evidence")).not.toMatch(
      /'admin\.case\.read'/,
    )
  })
})

describeIntegration("case permission enforcement", () => {
  const databaseName = `hivorr_case_gates_test_${Date.now()}`
  let admin: Client
  let database: Client

  let managerId: string
  let supportId: string
  let reviewerId: string
  let caseId: string

  async function createUser(email: string): Promise<string> {
    const result = await database.query<{
      user_id: string
      account_id: string
    }>(
      `with account as (
         insert into identity.accounts default values returning id
       ), created as (
         insert into identity.users (account_id, email, display_name)
         select account.id, $1, $1 from account
         returning id
       )
       select created.id as user_id, account.id as account_id
         from created, account`,
      [email],
    )
    return result.rows[0]!.user_id
  }

  async function grant(userId: string, permission: string) {
    await database.query(
      `insert into admin.permission_grants
         (user_id, permission_key, scope_type, reason)
       values ($1, $2, 'platform', 'integration test')`,
      [userId, permission],
    )
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

      managerId = await createUser("manager@hivorr.com")
      supportId = await createUser("support@hivorr.com")
      reviewerId = await createUser("reviewer@hivorr.com")

      // A case worker: may work cases but was never given evidence access.
      await grant(managerId, "admin.case.assign")
      await grant(supportId, "admin.case.read")
      await grant(supportId, "admin.case.assign")
      // A reviewer: evidence and recommendation authority, no case assignment.
      await grant(reviewerId, "admin.case.read")
      await grant(reviewerId, "admin.evidence.read")
      await grant(reviewerId, "admin.case.recommend")

      const created = await database.query<{ id: string }>(
        `select id from admin.create_case(
         $1, 'support', 'Integration case',
         'A case created to prove the permission gates.',
         'normal', 'low', 'support', 'integration test case')`,
        [managerId],
      )
      caseId = created.rows[0]!.id

      await database.query(
        `select * from admin.add_case_evidence(
         $1, $2, 'staging/evidence/integration.pdf', 'integration.pdf',
         'application/pdf', 1024, repeat('a', 64), 'sensitive',
         'attach evidence')`,
        [managerId, caseId],
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

  it("refuses evidence to a case worker without the evidence permission", async () => {
    const error = await database
      .query("select * from admin.list_case_evidence($1, $2)", [
        supportId,
        caseId,
      ])
      .catch((value: unknown) => value)

    expect(error).toMatchObject({ code: "42501" })
    expect(String((error as Error).message)).toContain(
      "evidence_read_forbidden",
    )
  })

  it("allows evidence to a holder of the evidence permission", async () => {
    const result = await database.query<{ file_name: string }>(
      "select * from admin.list_case_evidence($1, $2)",
      [reviewerId, caseId],
    )
    expect(result.rows).toHaveLength(1)
    expect(result.rows[0]!.file_name).toBe("integration.pdf")
  })

  it("refuses a decision request without the recommendation permission", async () => {
    const error = await database
      .query("select * from admin.request_case_decision($1, $2, $3, $4)", [
        supportId,
        caseId,
        "resolved",
        "requesting a decision",
      ])
      .catch((value: unknown) => value)

    expect(error).toMatchObject({ code: "42501" })
  })

  it("allows a decision request from a recommender", async () => {
    const result = await database.query<{ status: string }>(
      "select * from admin.request_case_decision($1, $2, $3, $4)",
      [reviewerId, caseId, "resolved", "recommending a resolution"],
    )
    expect(result.rows[0]!.status).toBe("pending")
  })
})
