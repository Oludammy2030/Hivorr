import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { createApplication } from "../server/src/app"
import type { ApiConfig } from "../server/src/config"
import { DatabaseService } from "../server/src/db/database.service"
import { currentTimeStep, totpCode } from "../server/src/modules/identity/totp"

const baseUrl = process.env.IDENTITY_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip
const databaseName = `hivorr_roles_test_${Date.now()}`

type CookieJar = Record<string, string>

interface EnrolledUser {
  userId: string
  secret: string
}

const mainHost = "staging.hivorr.com"
const controlHost = "control-staging.hivorr.com"
const json = { "content-type": "application/json" }

function readCookies(headers: Record<string, unknown>): CookieJar {
  const raw = headers["set-cookie"]
  const entries = Array.isArray(raw) ? raw : raw ? [raw] : []
  const jar: CookieJar = {}
  for (const entry of entries) {
    const pair = String(entry).split(";")[0]
    const index = pair.indexOf("=")
    if (index > 0) jar[pair.slice(0, index)] = pair.slice(index + 1)
  }
  return jar
}

function cookieHeader(jar: CookieJar, name: string): string {
  return `${name}=${jar[name]}`
}

describeIntegration("role administration integration", () => {
  let admin: Client
  let setup: Client
  let database: DatabaseService
  let app: Awaited<ReturnType<typeof createApplication>>["app"]

  let adminId: string
  let adminSecret: string
  let adminControlCookie: string
  let workerControlCookie: string
  let auditorAssignmentId: string
  let founderAssignmentId: string
  let financialDepartmentId: string

  async function registerAndEnroll(
    email: string,
    password: string,
  ): Promise<EnrolledUser> {
    const registered = await app.inject({
      method: "POST",
      url: "/v1/auth/register",
      headers: { host: mainHost, ...json },
      payload: { email, password, displayName: email },
    })
    expect(registered.statusCode).toBe(201)
    const userId: string = registered.json().userId

    const signedIn = await app.inject({
      method: "POST",
      url: "/v1/auth/sign-in",
      headers: { host: mainHost, ...json },
      payload: { email, password },
    })
    expect(signedIn.statusCode).toBe(200)
    const appCookie = cookieHeader(
      readCookies(signedIn.headers),
      "__Host-hivorr_app_sid",
    )

    const enrollment = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/totp/enroll",
      headers: { host: mainHost, cookie: appCookie },
    })
    expect(enrollment.statusCode).toBe(201)
    const { factorId, secret } = enrollment.json()

    const confirmation = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/totp/confirm",
      headers: { host: mainHost, cookie: appCookie, ...json },
      payload: { factorId, code: totpCode(secret, currentTimeStep()) },
    })
    expect(confirmation.statusCode).toBe(200)

    return { userId, secret }
  }

  async function controlCookie(
    email: string,
    password: string,
    secret: string,
  ) {
    const challenge = await app.inject({
      method: "POST",
      url: "/v1/auth/sign-in",
      headers: { host: controlHost, ...json },
      payload: { email, password },
    })
    expect(challenge.statusCode).toBe(202)
    const verified = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/verify",
      headers: { host: controlHost, ...json },
      payload: {
        challengeToken: challenge.json().challengeToken,
        code: totpCode(secret, currentTimeStep()),
      },
    })
    expect(verified.statusCode).toBe(200)
    return cookieHeader(
      readCookies(verified.headers),
      "__Host-hivorr_control_sid",
    )
  }

  beforeAll(
    async () => {
      admin = new Client({ connectionString: baseUrl })
      await admin.connect()
      await admin.query(`create database "${databaseName}"`)

      const url = new URL(baseUrl!)
      url.pathname = `/${databaseName}`
      const testUrl = url.toString()

      setup = new Client({ connectionString: testUrl })
      await setup.connect()

      const migrationsDirectory = path.join(
        process.cwd(),
        "supabase",
        "migrations",
      )
      for (const file of readdirSync(migrationsDirectory)
        .filter((entry) => entry.endsWith(".sql"))
        .sort()) {
        await setup.query(
          readFileSync(path.join(migrationsDirectory, file), "utf8"),
        )
      }

      const config: ApiConfig = {
        environment: "staging",
        backendEnvironment: "staging",
        supabaseProjectRef: "abcdefghijklmnopqrst",
        port: 3000,
        host: "127.0.0.1",
        logLevel: "silent",
        sessionIssuer: "hivorr-staging",
        mfaEncryptionKey: Buffer.alloc(32, 7).toString("base64"),
        databaseUrl: testUrl,
        corsAllowedOrigins: [],
        trustProxy: false,
        auth: {
          rateLimitWindowMs: 60_000,
          identifierMax: 100,
          ipMax: 1_000,
          lockoutAttempts: 5,
          lockoutMs: 15 * 60 * 1_000,
        },
        worker: {
          databaseUrl: testUrl,
          pollIntervalMs: 1_000,
          batchSize: 20,
          leaseMs: 60_000,
          maxAttempts: 5,
          retryBaseMs: 5_000,
          healthPort: 3001,
          healthHost: "127.0.0.1",
          workerId: "roles-test-worker",
        },
      }
      database = new DatabaseService(config)
      const created = await createApplication(config)
      app = created.app
      await app.init()
      await app.getHttpAdapter().getInstance().ready()

      const adminUser = await registerAndEnroll(
        "admin@example.test",
        "admin-test-password",
      )
      adminId = adminUser.userId
      adminSecret = adminUser.secret

      const workerUser = await registerAndEnroll(
        "worker@example.test",
        "worker-test-password",
      )

      await registerAndEnroll("amara@example.test", "amara-test-password")

      // The first role assignment is bootstrapped out of band, never by a
      // migration: the founder role carries admin.role.manage.
      const founder = await setup.query(
        `insert into admin.role_assignments
           (user_id, role_id, scope_type, granted_by, reason)
         select $1, r.id, 'platform', $1, 'Test bootstrap'
           from admin.roles r
          where r.key = 'founder'
         returning id`,
        [adminId],
      )
      founderAssignmentId = founder.rows[0].id

      const department = await setup.query(
        "select id from admin.departments where key = 'financial'",
      )
      financialDepartmentId = department.rows[0].id

      adminControlCookie = await controlCookie(
        "admin@example.test",
        "admin-test-password",
        adminSecret,
      )
      workerControlCookie = await controlCookie(
        "worker@example.test",
        "worker-test-password",
        workerUser.secret,
      )
    },
    60_000,
  )

  afterAll(async () => {
    if (app) await app.close()
    if (database) await database.onApplicationShutdown()
    if (setup) await setup.end()
    if (admin) {
      await admin.query(
        `drop database if exists "${databaseName}" with (force)`,
      )
      await admin.end()
    }
  })

  it("refuses role reads without a governance role", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/v1/control/roles",
      headers: { host: controlHost, cookie: workerControlCookie },
    })
    expect(response.statusCode).toBe(403)
  })

  it("lists the seeded catalogue with its permissions", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/v1/control/roles",
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    expect(response.statusCode).toBe(200)
    const roles = response.json() as Array<{
      key: string
      permissions: string[]
      activeAssignments: number
    }>
    const founder = roles.find((role) => role.key === "founder")
    expect(founder).toBeDefined()
    expect(founder?.permissions).toContain("admin.role.manage")
    expect(founder?.activeAssignments).toBeGreaterThanOrEqual(1)
    expect(roles.some((role) => role.key === "auditor")).toBe(true)
  })

  it("assigns a seeded role and refuses duplicates, self-change and unknown targets", async () => {
    const created = await app.inject({
      method: "POST",
      url: "/v1/control/role-assignments",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "amara@example.test",
        roleKey: "auditor",
        scopeType: "platform",
        reason: "Independent audit review",
      },
    })
    expect(created.statusCode).toBe(201)
    const assignment = created.json()
    expect(assignment).toMatchObject({
      email: "amara@example.test",
      roleKey: "auditor",
      roleName: "Auditor",
      scopeType: "platform",
      revokedAt: null,
    })
    auditorAssignmentId = assignment.id

    const duplicate = await app.inject({
      method: "POST",
      url: "/v1/control/role-assignments",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "amara@example.test",
        roleKey: "auditor",
        scopeType: "platform",
        reason: "Duplicate request",
      },
    })
    expect(duplicate.statusCode).toBe(409)

    const self = await app.inject({
      method: "POST",
      url: "/v1/control/role-assignments",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "admin@example.test",
        roleKey: "governance_admin",
        scopeType: "platform",
        reason: "Self escalation",
      },
    })
    expect(self.statusCode).toBe(403)

    const unknownRole = await app.inject({
      method: "POST",
      url: "/v1/control/role-assignments",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "amara@example.test",
        roleKey: "not_a_role",
        scopeType: "platform",
        reason: "Unknown role",
      },
    })
    expect(unknownRole.statusCode).toBe(404)

    const unknownUser = await app.inject({
      method: "POST",
      url: "/v1/control/role-assignments",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "missing@example.test",
        roleKey: "auditor",
        scopeType: "platform",
        reason: "Unknown user",
      },
    })
    expect(unknownUser.statusCode).toBe(404)

    const noReason = await app.inject({
      method: "POST",
      url: "/v1/control/role-assignments",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "worker@example.test",
        roleKey: "auditor",
        scopeType: "platform",
      },
    })
    expect(noReason.statusCode).toBe(400)
  })

  it("scopes an assignment to a real department and lists scope targets", async () => {
    const departments = await app.inject({
      method: "GET",
      url: "/v1/control/roles/scope-targets?type=department",
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    expect(departments.statusCode).toBe(200)
    expect(
      (departments.json() as Array<{ name: string }>).map((row) => row.name),
    ).toContain("Financial")

    const organisations = await app.inject({
      method: "GET",
      url: "/v1/control/roles/scope-targets?type=organisation",
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    expect(organisations.statusCode).toBe(200)

    const scoped = await app.inject({
      method: "POST",
      url: "/v1/control/role-assignments",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "worker@example.test",
        roleKey: "support_officer",
        scopeType: "department",
        scopeId: financialDepartmentId,
        reason: "Financial support queue",
      },
    })
    expect(scoped.statusCode).toBe(201)
    expect(scoped.json()).toMatchObject({
      roleKey: "support_officer",
      scopeType: "department",
      scopeId: financialDepartmentId,
    })

    const missingTarget = await app.inject({
      method: "POST",
      url: "/v1/control/role-assignments",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "worker@example.test",
        roleKey: "operations_officer",
        scopeType: "department",
        reason: "No target",
      },
    })
    expect(missingTarget.statusCode).toBe(400)
  })

  it("revokes an assignment with a reason and refuses self-revocation", async () => {
    const self = await app.inject({
      method: "POST",
      url: `/v1/control/role-assignments/${founderAssignmentId}/revoke`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Removing my own founder role" },
    })
    expect(self.statusCode).toBe(403)

    const revoked = await app.inject({
      method: "POST",
      url: `/v1/control/role-assignments/${auditorAssignmentId}/revoke`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Audit engagement ended" },
    })
    expect(revoked.statusCode).toBe(200)
    expect(revoked.json().revokedAt).toBeTruthy()

    const again = await app.inject({
      method: "POST",
      url: `/v1/control/role-assignments/${auditorAssignmentId}/revoke`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Second revoke" },
    })
    expect(again.statusCode).toBe(404)

    const rows = await setup.query(
      "select action, reason, capability, after_summary from platform.audit_log where action like 'identity.role_%' order by occurred_at",
    )
    expect(rows.rows.map((row) => row.action)).toContain(
      "identity.role_assigned",
    )
    expect(rows.rows.map((row) => row.action)).toContain(
      "identity.role_revoked",
    )
    expect(
      rows.rows.every((row) => row.capability === "admin.role.manage"),
    ).toBe(true)
    expect(rows.rows.map((row) => row.reason)).toContain(
      "Audit engagement ended",
    )
    expect(
      rows.rows.some((row) => row.after_summary?.roleKey === "support_officer"),
    ).toBe(true)
  })
})
