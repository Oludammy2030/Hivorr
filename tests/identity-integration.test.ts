import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { ApiError } from "../server/src/common/errors"
import { createApplication } from "../server/src/app"
import type { ApiConfig } from "../server/src/config"
import { DatabaseService } from "../server/src/db/database.service"
import {
  hashSessionToken,
  IdentityService,
} from "../server/src/modules/identity/identity.service"
import { currentTimeStep, totpCode } from "../server/src/modules/identity/totp"

const baseUrl = process.env.IDENTITY_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip
const databaseName = `hivorr_identity_test_${Date.now()}`

type CookieJar = Record<string, string>

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

describeIntegration("identity service integration", () => {
  let admin: Client
  let setup: Client
  let database: DatabaseService
  let service: IdentityService
  let testUrl: string
  let app: Awaited<ReturnType<typeof createApplication>>["app"]

  const context = {
    audience: "app" as const,
    environment: "staging" as const,
    ip: "127.0.0.1",
    userAgent: "vitest",
    correlationId: "identity-integration",
  }

  beforeAll(async () => {
    admin = new Client({ connectionString: baseUrl })
    await admin.connect()
    await admin.query(`create database "${databaseName}"`)

    const url = new URL(baseUrl!)
    url.pathname = `/${databaseName}`
    testUrl = url.toString()

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
    }
    database = new DatabaseService(config)
    service = new IdentityService(database, config)
    const created = await createApplication(config)
    app = created.app
    await app.init()
    await app.getHttpAdapter().getInstance().ready()
  }, 30_000)

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

  it("registers an account with a credential and owner membership", async () => {
    const result = await service.register(
      {
        email: "  Founder@Example.Test ",
        password: "correct-horse-battery",
        displayName: "Founder",
      },
      context,
    )
    expect(result.email).toBe("founder@example.test")
    expect(result.accountId).toBeTruthy()
    expect(result.userId).toBeTruthy()

    const rows = await setup.query(
      "select count(*)::int as count from platform.audit_log where action = 'identity.register'",
    )
    expect(rows.rows[0].count).toBe(1)
  })

  it("rejects a duplicate email without leaking the account", async () => {
    await expect(
      service.register(
        {
          email: "FOUNDER@example.test",
          password: "another-long-password",
        },
        context,
      ),
    ).rejects.toMatchObject({ code: "CONFLICT" })
  })

  it("rejects a wrong password", async () => {
    await expect(
      service.signIn(
        { email: "founder@example.test", password: "wrong-password" },
        context,
      ),
    ).rejects.toBeInstanceOf(ApiError)
  })

  it("requires a confirmed authenticator for privileged sign-in", async () => {
    await expect(
      service.signIn(
        { email: "founder@example.test", password: "correct-horse-battery" },
        { ...context, audience: "control" },
      ),
    ).rejects.toMatchObject({ code: "FORBIDDEN" })
  })

  it("issues a session, resolves it, and rejects another audience", async () => {
    const issued = await service.signIn(
      {
        email: "founder@example.test",
        password: "correct-horse-battery",
        deviceName: "vitest-device",
      },
      context,
    )
    expect(issued.token).toBeTruthy()
    expect(issued.audience).toBe("app")

    const resolved = await service.getSession(issued.token, context)
    expect(resolved.userId).toBe(issued.userId)
    expect(resolved.accountId).toBe(issued.accountId)

    await expect(
      service.getSession(issued.token, { ...context, audience: "control" }),
    ).rejects.toMatchObject({ code: "FORBIDDEN" })

    await service.signOut(issued.token, context)
    await expect(
      service.getSession(issued.token, context),
    ).rejects.toMatchObject({
      code: "UNAUTHENTICATED",
    })
  })

  it("serves registration, sign-in and session over HTTP without exposing the token in the body", async () => {
    const host = "staging.hivorr.com"
    const headers = { host, "content-type": "application/json" }

    const registered = await app.inject({
      method: "POST",
      url: "/v1/auth/register",
      headers,
      payload: {
        email: "http@example.test",
        password: "http-test-password",
        displayName: "HTTP Test",
      },
    })
    expect(registered.statusCode).toBe(201)

    const signedIn = await app.inject({
      method: "POST",
      url: "/v1/auth/sign-in",
      headers,
      payload: {
        email: "http@example.test",
        password: "http-test-password",
      },
    })
    expect(signedIn.statusCode).toBe(200)
    expect(signedIn.json()).not.toHaveProperty("token")

    const jar = readCookies(signedIn.headers)
    expect(jar["__Host-hivorr_app_sid"]).toBeTruthy()
    expect(jar["hivorr_app_rt"]).toBeTruthy()
    const cookie = cookieHeader(jar, "__Host-hivorr_app_sid")

    const session = await app.inject({
      method: "GET",
      url: "/v1/auth/session",
      headers: { host, cookie },
    })
    expect(session.statusCode).toBe(200)
    expect(session.json()).toMatchObject({
      email: "http@example.test",
      audience: "app",
      environment: "staging",
    })

    const signedOut = await app.inject({
      method: "POST",
      url: "/v1/auth/sign-out",
      headers: { host, cookie },
    })
    expect(signedOut.statusCode).toBe(204)

    const afterSignOut = await app.inject({
      method: "GET",
      url: "/v1/auth/session",
      headers: { host, cookie },
    })
    expect(afterSignOut.statusCode).toBe(401)
  })

  it("enrols TOTP, gates a privileged portal, and hardens sessions over HTTP", async () => {
    const mainHost = "staging.hivorr.com"
    const controlHost = "control.staging.hivorr.com"
    const staffHost = "staff.staging.hivorr.com"
    const json = { "content-type": "application/json" }

    const signedIn = await app.inject({
      method: "POST",
      url: "/v1/auth/sign-in",
      headers: { host: mainHost, ...json },
      payload: {
        email: "http@example.test",
        password: "http-test-password",
      },
    })
    expect(signedIn.statusCode).toBe(200)
    const appJar = readCookies(signedIn.headers)
    const appCookie = cookieHeader(appJar, "__Host-hivorr_app_sid")

    const enrollment = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/totp/enroll",
      headers: { host: mainHost, cookie: appCookie },
    })
    expect(enrollment.statusCode).toBe(201)
    const { factorId, secret, otpauthUri } = enrollment.json()
    expect(otpauthUri).toContain("otpauth://totp/")
    expect(secret).toMatch(/^[A-Z2-7]+$/)

    const wrongConfirm = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/totp/confirm",
      headers: { host: mainHost, cookie: appCookie, ...json },
      payload: { factorId, code: "000000" },
    })
    expect(wrongConfirm.statusCode).toBe(401)

    const confirmation = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/totp/confirm",
      headers: { host: mainHost, cookie: appCookie, ...json },
      payload: { factorId, code: totpCode(secret, currentTimeStep()) },
    })
    expect(confirmation.statusCode).toBe(200)
    const { recoveryCodes } = confirmation.json()
    expect(recoveryCodes).toHaveLength(10)

    const appSessions = await app.inject({
      method: "GET",
      url: "/v1/auth/sessions",
      headers: { host: mainHost, cookie: appCookie },
    })
    expect(appSessions.statusCode).toBe(200)
    const appSessionList = appSessions.json()
    expect(
      appSessionList.some((session: { current: boolean }) => session.current),
    ).toBe(true)
    const appSessionId = appSessionList.find(
      (session: { current: boolean }) => session.current,
    ).sessionId

    const challenge = await app.inject({
      method: "POST",
      url: "/v1/auth/sign-in",
      headers: { host: controlHost, ...json },
      payload: {
        email: "http@example.test",
        password: "http-test-password",
      },
    })
    expect(challenge.statusCode).toBe(202)
    const challengeBody = challenge.json()
    expect(challengeBody.mfaRequired).toBe(true)
    expect(challengeBody).not.toHaveProperty("token")

    const wrongCode = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/verify",
      headers: { host: controlHost, ...json },
      payload: { challengeToken: challengeBody.challengeToken, code: "000000" },
    })
    expect(wrongCode.statusCode).toBe(401)

    const crossPortal = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/verify",
      headers: { host: staffHost, ...json },
      payload: {
        challengeToken: challengeBody.challengeToken,
        code: totpCode(secret, currentTimeStep()),
      },
    })
    expect(crossPortal.statusCode).toBe(403)

    const verified = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/verify",
      headers: { host: controlHost, ...json },
      payload: {
        challengeToken: challengeBody.challengeToken,
        code: totpCode(secret, currentTimeStep()),
      },
    })
    expect(verified.statusCode).toBe(200)
    expect(verified.json()).toMatchObject({
      audience: "control",
      environment: "staging",
    })
    const controlCookie = cookieHeader(
      readCookies(verified.headers),
      "__Host-hivorr_control_sid",
    )
    expect(controlCookie).toContain("__Host-hivorr_control_sid=")

    const replayedChallenge = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/verify",
      headers: { host: controlHost, ...json },
      payload: {
        challengeToken: challengeBody.challengeToken,
        code: totpCode(secret, currentTimeStep()),
      },
    })
    expect(replayedChallenge.statusCode).toBe(401)

    const controlSessions = await app.inject({
      method: "GET",
      url: "/v1/auth/sessions",
      headers: { host: controlHost, cookie: controlCookie },
    })
    const controlCurrent = controlSessions
      .json()
      .find((session: { current: boolean }) => session.current)
    expect(controlCurrent).toMatchObject({
      audience: "control",
      environment: "staging",
      mfaSatisfied: true,
    })

    const steppedUp = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/step-up",
      headers: { host: mainHost, cookie: appCookie, ...json },
      payload: { code: recoveryCodes[0] },
    })
    expect(steppedUp.statusCode).toBe(200)

    const reusedRecovery = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/step-up",
      headers: { host: mainHost, cookie: appCookie, ...json },
      payload: { code: recoveryCodes[0] },
    })
    expect(reusedRecovery.statusCode).toBe(401)

    const revokedOthers = await app.inject({
      method: "DELETE",
      url: "/v1/auth/sessions",
      headers: { host: mainHost, cookie: appCookie },
    })
    expect(revokedOthers.statusCode).toBe(200)
    expect(revokedOthers.json().revoked).toBeGreaterThanOrEqual(1)

    const controlAfterRevoke = await app.inject({
      method: "GET",
      url: "/v1/auth/session",
      headers: { host: controlHost, cookie: controlCookie },
    })
    expect(controlAfterRevoke.statusCode).toBe(401)

    const revokedCurrent = await app.inject({
      method: "DELETE",
      url: `/v1/auth/sessions/${appSessionId}`,
      headers: { host: mainHost, cookie: appCookie },
    })
    expect(revokedCurrent.statusCode).toBe(204)

    const appAfterRevoke = await app.inject({
      method: "GET",
      url: "/v1/auth/session",
      headers: { host: mainHost, cookie: appCookie },
    })
    expect(appAfterRevoke.statusCode).toBe(401)
  })

  it("rotates refresh tokens and revokes the session when an old token is reused", async () => {
    const host = "staging.hivorr.com"
    const json = { "content-type": "application/json" }

    const signedIn = await app.inject({
      method: "POST",
      url: "/v1/auth/sign-in",
      headers: { host, ...json },
      payload: {
        email: "http@example.test",
        password: "http-test-password",
      },
    })
    expect(signedIn.statusCode).toBe(200)
    const original = readCookies(signedIn.headers)
    const oldAccess = cookieHeader(original, "__Host-hivorr_app_sid")
    const oldRefresh = cookieHeader(original, "hivorr_app_rt")
    expect(oldRefresh).toContain("hivorr_app_rt=")

    const beforeRefresh = await app.inject({
      method: "GET",
      url: "/v1/auth/session",
      headers: { host, cookie: oldAccess },
    })
    expect(beforeRefresh.statusCode).toBe(200)

    const refreshed = await app.inject({
      method: "POST",
      url: "/v1/auth/refresh",
      headers: { host, cookie: oldRefresh },
    })
    expect(refreshed.statusCode).toBe(200)
    expect(refreshed.json()).not.toHaveProperty("refreshToken")
    expect(refreshed.json()).not.toHaveProperty("token")
    const rotated = readCookies(refreshed.headers)
    expect(rotated["hivorr_app_rt"]).toBeTruthy()
    expect(rotated["hivorr_app_rt"]).not.toBe(original["hivorr_app_rt"])
    const newAccess = cookieHeader(rotated, "__Host-hivorr_app_sid")

    const staleAccess = await app.inject({
      method: "GET",
      url: "/v1/auth/session",
      headers: { host, cookie: oldAccess },
    })
    expect(staleAccess.statusCode).toBe(401)

    const afterRefresh = await app.inject({
      method: "GET",
      url: "/v1/auth/session",
      headers: { host, cookie: newAccess },
    })
    expect(afterRefresh.statusCode).toBe(200)

    // Reusing the spent token outside the retry leeway is treated as theft.
    await setup.query(
      "update identity.refresh_tokens set used_at = now() - interval '1 minute' where token_hash = $1",
      [hashSessionToken(original["hivorr_app_rt"])],
    )
    const replay = await app.inject({
      method: "POST",
      url: "/v1/auth/refresh",
      headers: { host, cookie: oldRefresh },
    })
    expect(replay.statusCode).toBe(401)

    const revoked = await app.inject({
      method: "GET",
      url: "/v1/auth/session",
      headers: { host, cookie: newAccess },
    })
    expect(revoked.statusCode).toBe(401)

    const reuseAudit = await setup.query(
      "select count(*)::int as count from platform.audit_log where action = 'identity.refresh_reuse_detected'",
    )
    expect(reuseAudit.rows[0].count).toBeGreaterThanOrEqual(1)
  })

  it("refuses refresh without a refresh cookie", async () => {
    const response = await app.inject({
      method: "POST",
      url: "/v1/auth/refresh",
      headers: { host: "staging.hivorr.com" },
    })
    expect(response.statusCode).toBe(401)
  })
})
