import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { ApiError } from "../server/src/common/errors"
import { createApplication } from "../server/src/app"
import type { ApiConfig } from "../server/src/config"
import { DatabaseService } from "../server/src/db/database.service"
import { IdentityService } from "../server/src/modules/identity/identity.service"

const baseUrl = process.env.IDENTITY_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip
const databaseName = `hivorr_identity_test_${Date.now()}`

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

  it("refuses privileged sign-in until MFA is implemented", async () => {
    await expect(
      service.signIn(
        { email: "founder@example.test", password: "correct-horse-battery" },
        { ...context, audience: "control" },
      ),
    ).rejects.toMatchObject({ code: "SERVICE_UNAVAILABLE" })
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

    const setCookie = signedIn.headers["set-cookie"]
    expect(typeof setCookie).toBe("string")
    const cookie = String(setCookie).split(";")[0]
    expect(cookie).toContain("__Host-hivorr_app_sid=")

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
})
