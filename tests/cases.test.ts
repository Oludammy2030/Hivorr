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
const databaseName = `hivorr_cases_test_${Date.now()}`

type CookieJar = Record<string, string>

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

describeIntegration("case spine integration", () => {
  let admin: Client
  let setup: Client
  let database: DatabaseService
  let app: Awaited<ReturnType<typeof createApplication>>["app"]

  let managerCookie: string
  let workerCookie: string
  let caseId: string

  async function registerAndEnroll(email: string, password: string) {
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
    return {
      userId,
      cookie: cookieHeader(
        readCookies(verified.headers),
        "__Host-hivorr_control_sid",
      ),
    }
  }

  beforeAll(async () => {
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
        workerId: "cases-test-worker",
      },
    }
    database = new DatabaseService(config)
    const created = await createApplication(config)
    app = created.app
    await app.init()
    await app.getHttpAdapter().getInstance().ready()

    const manager = await registerAndEnroll(
      "manager@example.test",
      "manager-test-password",
    )
    managerCookie = manager.cookie
    const worker = await registerAndEnroll(
      "worker@example.test",
      "worker-test-password",
    )
    workerCookie = worker.cookie

    await setup.query(
      "insert into admin.permission_grants (user_id, permission_key, scope_type) values ($1, 'admin.case.assign', 'platform'), ($1, 'admin.case.read', 'platform')",
      [manager.userId],
    )
  }, 60_000)

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

  it("refuses case access without the permission", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/v1/control/cases",
      headers: { host: controlHost, cookie: workerCookie },
    })
    expect(response.statusCode).toBe(403)
  })

  it("opens a case and appends its first timeline event", async () => {
    const created = await app.inject({
      method: "POST",
      url: "/v1/control/cases",
      headers: { host: controlHost, cookie: managerCookie, ...json },
      payload: {
        caseType: "support",
        title: "Order arrived damaged",
        description: "Customer reports a broken item",
        priority: "high",
        severity: "medium",
        queueKey: "support.queue",
        reason: "Reported through the support inbox",
      },
    })
    expect(created.statusCode).toBe(201)
    const entry = created.json()
    expect(entry.reference).toMatch(/^CASE-/)
    expect(entry.status).toBe("RECEIVED")
    caseId = entry.id

    const events = await app.inject({
      method: "GET",
      url: `/v1/control/cases/${caseId}/events`,
      headers: { host: controlHost, cookie: managerCookie },
    })
    expect(events.statusCode).toBe(200)
    expect(
      (events.json() as Array<{ eventType: string }>).map(
        (row) => row.eventType,
      ),
    ).toContain("created")
  })

  it("lists cases with filters", async () => {
    const list = await app.inject({
      method: "GET",
      url: "/v1/control/cases?type=support&q=damaged",
      headers: { host: controlHost, cookie: managerCookie },
    })
    expect(list.statusCode).toBe(200)
    expect(
      (list.json() as Array<{ id: string }>).some((row) => row.id === caseId),
    ).toBe(true)

    const empty = await app.inject({
      method: "GET",
      url: "/v1/control/cases?status=CLOSED",
      headers: { host: controlHost, cookie: managerCookie },
    })
    expect(empty.statusCode).toBe(200)
    expect(empty.json()).toEqual([])
  })

  it("assigns, notes and moves the case", async () => {
    const note = await app.inject({
      method: "POST",
      url: `/v1/control/cases/${caseId}/events`,
      headers: { host: controlHost, cookie: managerCookie, ...json },
      payload: { summary: "Asked the customer for photographs" },
    })
    expect(note.statusCode).toBe(201)

    const assigned = await app.inject({
      method: "POST",
      url: `/v1/control/cases/${caseId}/assign`,
      headers: { host: controlHost, cookie: managerCookie, ...json },
      payload: { email: "worker@example.test", queueKey: "support.queue" },
    })
    expect(assigned.statusCode).toBe(200)
    expect(assigned.json()).toMatchObject({
      assigneeEmail: "worker@example.test",
      queueKey: "support.queue",
    })

    const moved = await app.inject({
      method: "POST",
      url: `/v1/control/cases/${caseId}/status`,
      headers: { host: controlHost, cookie: managerCookie, ...json },
      payload: { status: "INVESTIGATING", reason: "Evidence received" },
    })
    expect(moved.statusCode).toBe(200)
    expect(moved.json().status).toBe("INVESTIGATING")

    const events = await app.inject({
      method: "GET",
      url: `/v1/control/cases/${caseId}/events`,
      headers: { host: controlHost, cookie: managerCookie },
    })
    const types = (events.json() as Array<{ eventType: string }>).map(
      (row) => row.eventType,
    )
    expect(types).toContain("note")
    expect(types).toContain("assigned")
    expect(types).toContain("status_changed")

    const audit = await setup.query(
      "select action from platform.audit_log where target_type = 'case' and target_id = $1",
      [caseId],
    )
    expect(audit.rows.map((row) => row.action)).toContain("case.created")
    expect(audit.rows.map((row) => row.action)).toContain("case.status_changed")
  })
})
