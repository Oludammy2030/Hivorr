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
const databaseName = `hivorr_accounts_test_${Date.now()}`

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

describeIntegration("account governance integration", () => {
  let admin: Client
  let setup: Client
  let database: DatabaseService
  let app: Awaited<ReturnType<typeof createApplication>>["app"]

  let adminControlCookie: string
  let workerControlCookie: string
  let amaraControlCookie: string
  let adminId: string
  let amaraId: string
  let amaraSecret: string

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
          workerId: "accounts-test-worker",
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
      const workerUser = await registerAndEnroll(
        "worker@example.test",
        "worker-test-password",
      )
      const amaraUser = await registerAndEnroll(
        "amara@example.test",
        "amara-test-password",
      )
      amaraId = amaraUser.userId
      amaraSecret = amaraUser.secret

      // The account-governance permission is bootstrapped out of band.
      await setup.query(
        "insert into admin.permission_grants (user_id, permission_key, scope_type) values ($1, 'admin.user.manage', 'platform')",
        [adminId],
      )

      adminControlCookie = await controlCookie(
        "admin@example.test",
        "admin-test-password",
        adminUser.secret,
      )
      workerControlCookie = await controlCookie(
        "worker@example.test",
        "worker-test-password",
        workerUser.secret,
      )
      amaraControlCookie = await controlCookie(
        "amara@example.test",
        "amara-test-password",
        amaraSecret,
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

  it("refuses account actions without admin.user.manage", async () => {
    const response = await app.inject({
      method: "POST",
      url: `/v1/control/users/${amaraId}/suspend`,
      headers: { host: controlHost, cookie: workerControlCookie, ...json },
      payload: { reason: "Should be denied" },
    })
    expect(response.statusCode).toBe(403)
  })

  it("requires a reason and refuses self-action", async () => {
    const noReason = await app.inject({
      method: "POST",
      url: `/v1/control/users/${amaraId}/suspend`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: {},
    })
    expect(noReason.statusCode).toBe(400)

    const self = await app.inject({
      method: "POST",
      url: `/v1/control/users/${adminId}/suspend`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Suspending myself" },
    })
    expect(self.statusCode).toBe(403)
  })

  it("suspends an account, revokes its sessions and reactivates it", async () => {
    const suspended = await app.inject({
      method: "POST",
      url: `/v1/control/users/${amaraId}/suspend`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Fraud investigation opened" },
    })
    expect(suspended.statusCode).toBe(200)
    expect(suspended.json()).toMatchObject({
      userId: amaraId,
      status: "suspended",
    })
    expect(suspended.json().sessionsRevoked).toBeGreaterThanOrEqual(1)

    const blocked = await app.inject({
      method: "GET",
      url: "/v1/session",
      headers: { host: controlHost, cookie: amaraControlCookie },
    })
    expect(blocked.statusCode).toBe(401)

    const reactivated = await app.inject({
      method: "POST",
      url: `/v1/control/users/${amaraId}/reactivate`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Investigation closed with no finding" },
    })
    expect(reactivated.statusCode).toBe(200)
    expect(reactivated.json()).toMatchObject({ status: "active" })

    amaraControlCookie = await controlCookie(
      "amara@example.test",
      "amara-test-password",
      amaraSecret,
    )
    const allowed = await app.inject({
      method: "GET",
      url: "/v1/session",
      headers: { host: controlHost, cookie: amaraControlCookie },
    })
    expect(allowed.statusCode).toBe(200)
  })

  it("revokes every session for an account", async () => {
    const revoke = await app.inject({
      method: "POST",
      url: `/v1/control/users/${amaraId}/revoke-sessions`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { reason: "Device lost" },
    })
    expect(revoke.statusCode).toBe(200)
    expect(revoke.json().sessionsRevoked).toBeGreaterThanOrEqual(1)
  })

  it("records notes and a timeline with the operator and reason", async () => {
    const note = await app.inject({
      method: "POST",
      url: `/v1/control/users/${amaraId}/notes`,
      headers: { host: controlHost, cookie: adminControlCookie, ...json },
      payload: { body: "Closure confirmed by email on 13 November" },
    })
    expect(note.statusCode).toBe(201)

    const notes = await app.inject({
      method: "GET",
      url: `/v1/control/users/${amaraId}/notes`,
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    expect(notes.statusCode).toBe(200)
    expect(
      (notes.json() as Array<{ body: string }>).map((row) => row.body),
    ).toContain("Closure confirmed by email on 13 November")

    const timeline = await app.inject({
      method: "GET",
      url: `/v1/control/users/${amaraId}/timeline`,
      headers: { host: controlHost, cookie: adminControlCookie },
    })
    expect(timeline.statusCode).toBe(200)
    const actions = (timeline.json() as Array<{ action: string }>).map(
      (row) => row.action,
    )
    expect(actions).toContain("account.suspended")
    expect(actions).toContain("account.sessions_revoked")
    expect(actions).toContain("account.note_added")

    const audit = await setup.query(
      "select action, reason, capability from platform.audit_log where target_id = $1 and action like 'account.%' order by occurred_at",
      [amaraId],
    )
    expect(audit.rows.map((row) => row.action)).toContain(
      "account.sessions_revoked",
    )
    expect(
      audit.rows.every((row) => row.capability === "admin.user.manage"),
    ).toBe(true)
    expect(audit.rows.map((row) => row.reason)).toContain("Device lost")
  })
})
