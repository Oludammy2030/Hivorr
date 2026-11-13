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
const databaseName = `hivorr_partner_isolation_${Date.now()}`

type CookieJar = Record<string, string>

const mainHost = "staging.hivorr.com"
const partnerHost = "partner-staging.hivorr.com"
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

describeIntegration("partner isolation integration", () => {
  let admin: Client
  let setup: Client
  let database: DatabaseService
  let app: Awaited<ReturnType<typeof createApplication>>["app"]

  let partnerACookie: string
  let partnerBCookie: string
  let organisationA: string
  let organisationB: string

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
      headers: { host: partnerHost, ...json },
      payload: { email, password },
    })
    expect(challenge.statusCode).toBe(202)
    const verified = await app.inject({
      method: "POST",
      url: "/v1/auth/mfa/verify",
      headers: { host: partnerHost, ...json },
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
        "__Host-hivorr_partner_sid",
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
        workerId: "isolation-test-worker",
      },
    }
    database = new DatabaseService(config)
    const created = await createApplication(config)
    app = created.app
    await app.init()
    await app.getHttpAdapter().getInstance().ready()

    const a = await registerAndEnroll(
      "partner-a@example.test",
      "partner-a-password",
    )
    const b = await registerAndEnroll(
      "partner-b@example.test",
      "partner-b-password",
    )
    partnerACookie = a.cookie
    partnerBCookie = b.cookie

    const orgA = await setup.query(
      "insert into admin.partner_organisations (legal_name, status) values ('Alpha Supplies', 'active') returning id",
    )
    organisationA = orgA.rows[0].id
    const orgB = await setup.query(
      "insert into admin.partner_organisations (legal_name, status) values ('Beta Logistics', 'active') returning id",
    )
    organisationB = orgB.rows[0].id

    await setup.query(
      "insert into admin.partner_representatives (organisation_id, user_id, representative_role) values ($1, $2, 'owner')",
      [organisationA, a.userId],
    )
    await setup.query(
      "insert into admin.partner_representatives (organisation_id, user_id, representative_role) values ($1, $2, 'member')",
      [organisationB, b.userId],
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

  it("shows each partner only the organisation they represent", async () => {
    const a = await app.inject({
      method: "GET",
      url: "/v1/partner/organisations",
      headers: { host: partnerHost, cookie: partnerACookie },
    })
    expect(a.statusCode).toBe(200)
    expect(
      (a.json() as Array<{ organisationId: string }>).map(
        (row) => row.organisationId,
      ),
    ).toEqual([organisationA])

    const b = await app.inject({
      method: "GET",
      url: "/v1/partner/organisations",
      headers: { host: partnerHost, cookie: partnerBCookie },
    })
    expect(b.statusCode).toBe(200)
    expect(
      (b.json() as Array<{ organisationId: string }>).map(
        (row) => row.organisationId,
      ),
    ).toEqual([organisationB])
  })

  it("refuses the control surface to a partner session", async () => {
    const control = await app.inject({
      method: "GET",
      url: "/v1/control/partners",
      headers: { host: controlHost, cookie: partnerACookie },
    })
    expect(control.statusCode).toBeGreaterThanOrEqual(401)

    const wrongAudience = await app.inject({
      method: "GET",
      url: "/v1/partner/organisations",
      headers: { host: controlHost, cookie: partnerACookie },
    })
    expect(wrongAudience.statusCode).toBeGreaterThanOrEqual(401)
  })

  it("keeps activity and governance capabilities out of a partner session", async () => {
    const session = await app.inject({
      method: "GET",
      url: "/v1/session",
      headers: { host: partnerHost, cookie: partnerACookie },
    })
    expect(session.statusCode).toBe(200)
    const capabilities = session.json().capabilities as string[]
    expect(capabilities).toContain("session.read")
    const forbidden = capabilities.filter(
      (capability) =>
        capability.startsWith("admin.") ||
        capability.startsWith("staff.") ||
        capability === "activity.activate" ||
        capability === "activity.deactivate" ||
        capability === "market.order.place" ||
        capability === "market.cart.manage" ||
        capability.startsWith("services.") ||
        capability.startsWith("logistics."),
    )
    expect(forbidden).toEqual([])
  })

  it("hides a terminated partner from its representative", async () => {
    await setup.query(
      "update admin.partner_organisations set status = 'terminated' where id = $1",
      [organisationB],
    )
    const b = await app.inject({
      method: "GET",
      url: "/v1/partner/organisations",
      headers: { host: partnerHost, cookie: partnerBCookie },
    })
    expect(b.statusCode).toBe(200)
    expect(b.json()).toEqual([])
  })
})
