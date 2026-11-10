import { describe, expect, it } from "vitest"

import { parseConfig } from "../server/src/config"
import { createDatabasePool } from "../server/src/db/pool"

const staging = parseConfig({
  HIVORR_ENV: "staging",
  BACKEND_ENVIRONMENT: "staging",
  SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
  DATABASE_URL:
    "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
  SESSION_ISSUER: "hivorr-staging",
  MFA_ENCRYPTION_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
})

const certificate =
  "-----BEGIN CERTIFICATE-----\nMIIBfake\n-----END CERTIFICATE-----"

interface PoolOptionsInput {
  applicationName: string
  max?: number
  databaseUrl?: string
}

function poolFor(
  config: ReturnType<typeof parseConfig>,
  options: PoolOptionsInput,
) {
  return createDatabasePool(config, options)
}

describe("database pool configuration", () => {
  it("encrypts a remote staging connection without a CA", async () => {
    const pool = poolFor(staging, { applicationName: "hivorr-api-staging" })
    try {
      expect(pool.options.ssl).toEqual({ rejectUnauthorized: false })
      expect(pool.options.connectionTimeoutMillis).toBe(5_000)
      expect(pool.options.idleTimeoutMillis).toBe(30_000)
      expect(pool.options.max).toBe(10)
      expect(pool.options.application_name).toBe("hivorr-api-staging")
    } finally {
      await pool.end()
    }
  })

  it("verifies the server when DATABASE_SSL_CA is supplied", async () => {
    const withCa = parseConfig({
      HIVORR_ENV: "staging",
      BACKEND_ENVIRONMENT: "staging",
      SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
      DATABASE_URL:
        "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
      DATABASE_SSL_CA: certificate,
      SESSION_ISSUER: "hivorr-staging",
      MFA_ENCRYPTION_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    })
    const pool = poolFor(withCa, { applicationName: "hivorr-api-staging" })
    try {
      expect(pool.options.ssl).toEqual({
        ca: certificate,
        rejectUnauthorized: true,
      })
    } finally {
      await pool.end()
    }
  })

  it("does not force TLS for a loopback container", async () => {
    // The config contract keeps staging on the managed project; this manual
    // config covers the pool's defensive loopback branch (a tunnel or a local
    // staging sandbox).
    const local = {
      ...staging,
      databaseUrl: "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
    }
    const pool = poolFor(local, { applicationName: "hivorr-api-local" })
    try {
      expect(pool.options.ssl).toBeUndefined()
    } finally {
      await pool.end()
    }
  })

  it("keeps development and test connections unencrypted", async () => {
    const test = parseConfig({ HIVORR_ENV: "test" })
    const pool = poolFor(test, {
      applicationName: "hivorr-api-test",
      max: 3,
      databaseUrl: "postgresql://postgres:fake@db.example.test:5432/postgres",
    })
    try {
      expect(pool.options.ssl).toBeUndefined()
      expect(pool.options.max).toBe(3)
    } finally {
      await pool.end()
    }
  })
})
