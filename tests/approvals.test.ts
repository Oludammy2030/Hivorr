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
const databaseName = `hivorr_approvals_test_${Date.now()}`

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

describeIntegration("approval integration", () => {
  let admin: Client
  let setup: Client
  let database: DatabaseService
  let app: Awaited<ReturnType<typeof createApplication>>["app"]

  let requesterCookie: string
  let approverCookie: string
  let workerCookie: string
  let requesterId: string
  let targetId: string
  let secondTargetId: string
  let requestId: string

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
        workerId: "approvals-test-worker",
      },
    }
    database = new DatabaseService(config)
    const created = await createApplication(config)
    app = created.app
    await app.init()
    await app.getHttpAdapter().getInstance().ready()

    const requester = await registerAndEnroll(
      "requester@example.test",
      "requester-test-password",
    )
    requesterId = requester.userId
    requesterCookie = requester.cookie

    const approver = await registerAndEnroll(
      "approver@example.test",
      "approver-test-password",
    )
    approverCookie = approver.cookie

    const worker = await registerAndEnroll(
      "worker@example.test",
      "worker-test-password",
    )
    workerCookie = worker.cookie

    const target = await registerAndEnroll(
      "target@example.test",
      "target-test-password",
    )
    targetId = target.userId

    const second = await registerAndEnroll(
      "second@example.test",
      "second-test-password",
    )
    secondTargetId = second.userId

    await setup.query(
      "insert into identity.grants (user_id, grant_type, scope, environment) values ($1, 'staff', 'staff.support.handle', 'staging')",
      [targetId],
    )
    await setup.query(
      `insert into admin.role_assignments (user_id, role_id, scope_type)
         select $1, id, 'platform' from admin.roles where key = 'auditor'`,
      [targetId],
    )

    await setup.query(
      "insert into admin.permission_grants (user_id, permission_key, scope_type) values ($1, 'admin.user.manage', 'platform')",
      [requesterId],
    )
    await setup.query(
      "insert into admin.permission_grants (user_id, permission_key, scope_type) values ($1, 'admin.case.assign', 'platform'), ($1, 'admin.case.read', 'platform')",
      [requesterId],
    )
    await setup.query(
      "insert into admin.permission_grants (user_id, permission_key, scope_type) values ($1, 'admin.approval.decide', 'platform'), ($1, 'admin.approval.read', 'platform'), ($1, 'admin.user.manage', 'platform'), ($1, 'admin.case.approve', 'platform')",
      [approver.userId],
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

  it("refuses approval access without the permission", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/v1/control/approvals",
      headers: { host: controlHost, cookie: workerCookie },
    })
    expect(response.statusCode).toBe(403)
  })

  it("lets a manager request a closure but not approve it", async () => {
    const created = await app.inject({
      method: "POST",
      url: "/v1/control/approvals",
      headers: { host: controlHost, cookie: requesterCookie, ...json },
      payload: {
        actionType: "account.closure",
        targetType: "user",
        targetId,
        reason: "Customer asked us to close the account",
      },
    })
    expect(created.statusCode).toBe(201)
    const request = created.json()
    expect(request.status).toBe("pending")
    expect(request.reference).toMatch(/^APR-/)
    requestId = request.id

    const selfDecision = await app.inject({
      method: "POST",
      url: `/v1/control/approvals/${requestId}/decide`,
      headers: { host: controlHost, cookie: requesterCookie, ...json },
      payload: { decision: "approve", reason: "Approving my own request" },
    })
    expect(selfDecision.statusCode).toBe(403)

    const duplicate = await app.inject({
      method: "POST",
      url: "/v1/control/approvals",
      headers: { host: controlHost, cookie: requesterCookie, ...json },
      payload: {
        actionType: "account.closure",
        targetType: "user",
        targetId,
        reason: "Second request while one is pending",
      },
    })
    expect(duplicate.statusCode).toBe(409)
  })

  it("executes the closure only when another administrator approves", async () => {
    const approved = await app.inject({
      method: "POST",
      url: `/v1/control/approvals/${requestId}/decide`,
      headers: { host: controlHost, cookie: approverCookie, ...json },
      payload: { decision: "approve", reason: "Verified with the customer" },
    })
    expect(approved.statusCode).toBe(200)
    expect(approved.json().status).toBe("approved")

    const status = await setup.query(
      "select status from identity.users where id = $1",
      [targetId],
    )
    expect(status.rows[0].status).toBe("closed")

    const grants = await setup.query(
      "select revoked_at from identity.grants where user_id = $1",
      [targetId],
    )
    expect(grants.rows[0].revoked_at).not.toBeNull()
    const roles = await setup.query(
      "select revoked_at from admin.role_assignments where user_id = $1",
      [targetId],
    )
    expect(roles.rows[0].revoked_at).not.toBeNull()

    const audit = await setup.query(
      "select action from platform.audit_log where target_id = $1 and action like 'approval.%' order by occurred_at",
      [targetId],
    )
    expect(audit.rows.map((row) => row.action)).toContain("approval.requested")
    expect(audit.rows.map((row) => row.action)).toContain("approval.approved")
  })

  it("rejects a request without acting on the target", async () => {
    const created = await app.inject({
      method: "POST",
      url: "/v1/control/approvals",
      headers: { host: controlHost, cookie: requesterCookie, ...json },
      payload: {
        actionType: "account.closure",
        targetType: "user",
        targetId: secondTargetId,
        reason: "Suspected duplicate account",
      },
    })
    expect(created.statusCode).toBe(201)

    const rejected = await app.inject({
      method: "POST",
      url: `/v1/control/approvals/${created.json().id}/decide`,
      headers: { host: controlHost, cookie: approverCookie, ...json },
      payload: {
        decision: "reject",
        reason: "Evidence does not support closure",
      },
    })
    expect(rejected.statusCode).toBe(200)
    expect(rejected.json().status).toBe("rejected")

    const status = await setup.query(
      "select status from identity.users where id = $1",
      [secondTargetId],
    )
    expect(status.rows[0].status).toBe("active")
  })

  it("routes a case decision through a second administrator", async () => {
    const created = await app.inject({
      method: "POST",
      url: "/v1/control/cases",
      headers: { host: controlHost, cookie: requesterCookie, ...json },
      payload: {
        caseType: "dispute",
        title: "Refund dispute for order 8821",
        priority: "high",
        severity: "medium",
        reason: "Customer escalated the dispute",
      },
    })
    expect(created.statusCode).toBe(201)
    const caseId = created.json().id

    const requested = await app.inject({
      method: "POST",
      url: `/v1/control/cases/${caseId}/decision`,
      headers: { host: controlHost, cookie: requesterCookie, ...json },
      payload: {
        outcome: "Refund approved in full",
        reason: "Evidence supports the customer's claim",
      },
    })
    expect(requested.statusCode).toBe(201)
    expect(requested.json().actionType).toBe("case.decision")

    const selfDecision = await app.inject({
      method: "POST",
      url: `/v1/control/approvals/${requested.json().id}/decide`,
      headers: { host: controlHost, cookie: requesterCookie, ...json },
      payload: { decision: "approve", reason: "Approving my own decision" },
    })
    expect(selfDecision.statusCode).toBe(403)

    const approved = await app.inject({
      method: "POST",
      url: `/v1/control/approvals/${requested.json().id}/decide`,
      headers: { host: controlHost, cookie: approverCookie, ...json },
      payload: {
        decision: "approve",
        reason: "Reviewed the evidence independently",
      },
    })
    expect(approved.statusCode).toBe(200)
    expect(approved.json().status).toBe("approved")

    const decided = await setup.query(
      "select status, outcome from admin.cases where id = $1",
      [caseId],
    )
    expect(decided.rows[0].status).toBe("DECIDED")
    expect(decided.rows[0].outcome).toBe("Refund approved in full")

    const events = await setup.query(
      "select event_type from admin.case_events where case_id = $1",
      [caseId],
    )
    const types = events.rows.map((row) => row.event_type)
    expect(types).toContain("decision_requested")
    expect(types).toContain("decision_recorded")
  })
})
