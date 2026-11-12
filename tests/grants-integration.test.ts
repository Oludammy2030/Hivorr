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
const databaseName = `hivorr_grants_test_${Date.now()}`

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

describeIntegration("grant management integration", () => {
  let admin: Client
  let setup: Client
  let database: DatabaseService
  let app: Awaited<ReturnType<typeof createApplication>>["app"]

  let adminId: string
  let workerId: string
  let adminSecret: string
  let workerControlCookie: string
  let adminControlCookie: string
  let staffGrantId: string

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
          workerId: "grants-test-worker",
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
      workerId = workerUser.userId

      // First admin grant is bootstrapped out of band, never by a migration.
      await setup.query(
        "insert into identity.grants (user_id, grant_type, scope, environment) values ($1, 'admin', 'admin.grant.manage', 'staging')",
        [adminId],
      )

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

  it("lists the bootstrap grant and computes the manager capability", async () => {
    const list = await app.inject({
      method: "GET",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    expect(list.statusCode).toBe(200)
    const grants = list.json()
    expect(grants).toHaveLength(1)
    expect(grants[0]).toMatchObject({
      userId: adminId,
      email: "admin@example.test",
      grantType: "admin",
      scope: "admin.grant.manage",
      environment: "staging",
      revokedAt: null,
    })

    const own = await app.inject({
      method: "GET",
      url: "/v1/grants",
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    expect(own.statusCode).toBe(200)
    expect(own.json().capabilities).toContain("admin.grant.manage")
  })

  it("denies grant management to a control session without a grant", async () => {
    const list = await app.inject({
      method: "GET",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: workerControlCookie },
    })
    expect(list.statusCode).toBe(403)

    const create = await app.inject({
      method: "POST",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: workerControlCookie, ...json },
      payload: {
        email: "worker@example.test",
        grantType: "admin",
        scope: "admin.grant.manage",
        reason: "Test denying an unauthorised caller",
      },
    })
    expect(create.statusCode).toBe(403)
  })

  it("creates a scoped grant and rejects duplicates and invalid scopes", async () => {
    const created = await app.inject({
      method: "POST",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "worker@example.test",
        grantType: "staff",
        scope: "staff.support.handle",
        reason: "Support queue coverage",
      },
    })
    expect(created.statusCode).toBe(201)
    const grant = created.json()
    expect(grant).toMatchObject({
      userId: workerId,
      email: "worker@example.test",
      grantType: "staff",
      scope: "staff.support.handle",
      environment: "staging",
      grantedBy: adminId,
      revokedAt: null,
    })
    staffGrantId = grant.id

    const noReason = await app.inject({
      method: "POST",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "worker@example.test",
        grantType: "staff",
        scope: "staff.support.handle",
      },
    })
    expect(noReason.statusCode).toBe(400)

    const duplicate = await app.inject({
      method: "POST",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "worker@example.test",
        grantType: "staff",
        scope: "staff.support.handle",
        reason: "Duplicate request",
      },
    })
    expect(duplicate.statusCode).toBe(409)

    const wrongScope = await app.inject({
      method: "POST",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "worker@example.test",
        grantType: "staff",
        scope: "admin.grant.manage",
        reason: "Invalid scope test",
      },
    })
    expect(wrongScope.statusCode).toBe(400)

    const unknownUser = await app.inject({
      method: "POST",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {
        email: "missing@example.test",
        grantType: "partner",
        scope: "partner.referral.read",
        reason: "Unknown user test",
      },
    })
    expect(unknownUser.statusCode).toBe(404)
  })

  it("does not let a grant from another environment widen a staging session", async () => {
    await setup.query(
      "insert into identity.grants (user_id, grant_type, scope, environment) values ($1, 'admin', 'admin.audit.read', 'production')",
      [adminId],
    )

    const own = await app.inject({
      method: "GET",
      url: "/v1/grants",
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    expect(own.statusCode).toBe(200)
    const body = own.json()
    expect(
      body.grants.some(
        (g: { environment: string }) => g.environment === "production",
      ),
    ).toBe(false)
    expect(body.capabilities).not.toContain("admin.audit.read")
  })

  it("revokes a grant but refuses to remove the last manager", async () => {
    const revoked = await app.inject({
      method: "POST",
      url: `/v1/control/grants/${staffGrantId}/revoke`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Support coverage ended" },
    })
    expect(revoked.statusCode).toBe(200)
    expect(revoked.json().revokedAt).toBeTruthy()

    const again = await app.inject({
      method: "POST",
      url: `/v1/control/grants/${staffGrantId}/revoke`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Second revocation attempt" },
    })
    expect(again.statusCode).toBe(404)

    const list = await app.inject({
      method: "GET",
      url: "/v1/control/grants",
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    const bootstrap = list
      .json()
      .find(
        (g) => g.scope === "admin.grant.manage" && g.environment === "staging",
      )

    const lastManager = await app.inject({
      method: "POST",
      url: `/v1/control/grants/${bootstrap.id}/revoke`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Last manager guard test" },
    })
    expect(lastManager.statusCode).toBe(409)
  })

  it("audits every grant change with a reason", async () => {
    const rows = await setup.query(
      "select action, actor_id, target_type, reason from platform.audit_log where action like 'identity.grant_%' order by action",
    )
    const actions = rows.rows.map((row) => row.action)
    expect(actions).toContain("identity.grant_created")
    expect(actions).toContain("identity.grant_revoked")
    expect(
      rows.rows.every(
        (row) => row.actor_id === adminId && row.target_type === "grant",
      ),
    ).toBe(true)
    expect(rows.rows.map((row) => row.reason)).toContain(
      "Support queue coverage",
    )
    expect(rows.rows.map((row) => row.reason)).toContain(
      "Support coverage ended",
    )
  })
})
