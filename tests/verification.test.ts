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
const databaseName = `hivorr_verification_${Date.now()}`

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

describeIntegration("verification review integration", () => {
  let admin: Client
  let setup: Client
  let database: DatabaseService
  let app: Awaited<ReturnType<typeof createApplication>>["app"]

  let managerCookie: string
  let officerCookie: string
  let workerCookie: string
  let reviewedCaseId: string
  let emptyCaseId: string

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
        workerId: "verification-test-worker",
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
    const officer = await registerAndEnroll(
      "officer@example.test",
      "officer-test-password",
    )
    officerCookie = officer.cookie
    const worker = await registerAndEnroll(
      "worker@example.test",
      "worker-test-password",
    )
    workerCookie = worker.cookie

    await setup.query(
      "insert into admin.permission_grants (user_id, permission_key, scope_type) values ($1, 'admin.case.assign', 'platform'), ($1, 'admin.case.read', 'platform')",
      [manager.userId],
    )
    await setup.query(
      "insert into admin.permission_grants (user_id, permission_key, scope_type) values ($1, 'admin.verification.review', 'platform')",
      [officer.userId],
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

  it("refuses the verification queue without the permission", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/v1/control/verification",
      headers: { host: controlHost, cookie: workerCookie },
    })
    expect(response.statusCode).toBe(403)
  })

  it("approves a verification case that has evidence", async () => {
    const created = await app.inject({
      method: "POST",
      url: "/v1/control/cases",
      headers: { host: controlHost, cookie: managerCookie, ...json },
      payload: {
        caseType: "verification_review",
        title: "Identity verification for Amara",
        priority: "normal",
        severity: "medium",
        reason: "Submitted identity document",
      },
    })
    expect(created.statusCode).toBe(201)
    reviewedCaseId = created.json().id

    const evidence = await app.inject({
      method: "POST",
      url: `/v1/control/cases/${reviewedCaseId}/evidence`,
      headers: { host: controlHost, cookie: managerCookie, ...json },
      payload: {
        storageKey: `cases/${reviewedCaseId}/id.pdf`,
        fileName: "id.pdf",
        sha256: "c".repeat(64),
        reason: "Customer uploaded an identity document",
      },
    })
    expect(evidence.statusCode).toBe(201)

    const queue = await app.inject({
      method: "GET",
      url: "/v1/control/verification?status=pending",
      headers: { host: controlHost, cookie: officerCookie },
    })
    expect(queue.statusCode).toBe(200)
    const entry = (queue.json() as Array<{
      caseId: string
      evidenceCount: number
    }>).find((row) => row.caseId === reviewedCaseId)
    expect(entry?.evidenceCount).toBe(1)

    const approved = await app.inject({
      method: "POST",
      url: `/v1/control/verification/${reviewedCaseId}/decision`,
      headers: { host: controlHost, cookie: officerCookie, ...json },
      payload: {
        decision: "approve",
        reason: "Document matches the submitted details",
      },
    })
    expect(approved.statusCode).toBe(200)
    expect(approved.json()).toMatchObject({
      reviewStatus: "approved",
      caseStatus: "DECIDED",
    })

    const decided = await setup.query(
      "select status, outcome from admin.cases where id = $1",
      [reviewedCaseId],
    )
    expect(decided.rows[0]).toMatchObject({
      status: "DECIDED",
      outcome: "verification_approved",
    })

    const audit = await setup.query(
      "select action, capability from platform.audit_log where target_id = $1 and action like 'verification.%'",
      [reviewedCaseId],
    )
    expect(audit.rows[0]?.capability).toBe("admin.verification.review")
  })

  it("refuses approval without evidence and can request information", async () => {
    const created = await app.inject({
      method: "POST",
      url: "/v1/control/cases",
      headers: { host: controlHost, cookie: managerCookie, ...json },
      payload: {
        caseType: "verification_review",
        title: "Address verification",
        priority: "low",
        severity: "low",
        reason: "No document uploaded yet",
      },
    })
    expect(created.statusCode).toBe(201)
    emptyCaseId = created.json().id

    const refused = await app.inject({
      method: "POST",
      url: `/v1/control/verification/${emptyCaseId}/decision`,
      headers: { host: controlHost, cookie: officerCookie, ...json },
      payload: {
        decision: "approve",
        reason: "Trying to approve without evidence",
      },
    })
    expect(refused.statusCode).toBe(409)

    const requested = await app.inject({
      method: "POST",
      url: `/v1/control/verification/${emptyCaseId}/decision`,
      headers: { host: controlHost, cookie: officerCookie, ...json },
      payload: {
        decision: "request_information",
        reason: "Please upload a proof of address",
      },
    })
    expect(requested.statusCode).toBe(200)
    expect(requested.json()).toMatchObject({
      reviewStatus: "information_requested",
      caseStatus: "PENDING_INFORMATION",
    })
  })
})
