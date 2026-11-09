import { describe, expect, it } from "vitest"

import {
  ConfigurationError,
  databaseUrlMatchesProjectRef,
  parseConfig,
} from "../server/src/config"

describe("API configuration", () => {
  it("parses a test environment with development defaults", () => {
    const config = parseConfig({ HIVORR_ENV: "test" })
    expect(config.environment).toBe("test")
    expect(config.port).toBe(3000)
    expect(config.host).toBe("0.0.0.0")
    expect(config.sessionIssuer).toBe("hivorr-test")
    expect(config.databaseUrl).toBeUndefined()
  })

  it("requires a database and issuer in staging and production", () => {
    expect(() => parseConfig({ HIVORR_ENV: "staging" })).toThrow(
      ConfigurationError,
    )
    try {
      parseConfig({ HIVORR_ENV: "production" })
    } catch (error) {
      expect(error).toBeInstanceOf(ConfigurationError)
      expect(String(error)).toContain("DATABASE_URL")
      expect(String(error)).toContain("SESSION_ISSUER")
      expect(String(error)).toContain("MFA_ENCRYPTION_KEY")
    }
  })

  it("rejects an MFA key that is not 32 bytes", () => {
    expect(() =>
      parseConfig({
        HIVORR_ENV: "staging",
        BACKEND_ENVIRONMENT: "staging",
        SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
        DATABASE_URL:
          "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
        SESSION_ISSUER: "hivorr-staging",
        MFA_ENCRYPTION_KEY: Buffer.from("too-short").toString("base64"),
      }),
    ).toThrow(ConfigurationError)
  })

  it("accepts an explicit production configuration", () => {
    const config = parseConfig({
      HIVORR_ENV: "production",
      BACKEND_ENVIRONMENT: "production",
      SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
      DATABASE_URL:
        "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
      SESSION_ISSUER: "hivorr-production",
      MFA_ENCRYPTION_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
      API_PORT: "8080",
      CORS_ALLOWED_ORIGINS: "https://hivorr.com, https://control.hivorr.com",
    })
    expect(config.port).toBe(8080)
    expect(config.backendEnvironment).toBe("production")
    expect(config.supabaseProjectRef).toBe("abcdefghijklmnopqrst")
    expect(config.corsAllowedOrigins).toEqual([
      "https://hivorr.com",
      "https://control.hivorr.com",
    ])
  })

  it("rejects a backend environment that does not match the deployment", () => {
    expect(() =>
      parseConfig({
        HIVORR_ENV: "staging",
        BACKEND_ENVIRONMENT: "production",
        SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
        DATABASE_URL:
          "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
        SESSION_ISSUER: "hivorr-staging",
      }),
    ).toThrow(ConfigurationError)
  })

  it("rejects a database URL that belongs to another project", () => {
    expect(() =>
      parseConfig({
        HIVORR_ENV: "staging",
        BACKEND_ENVIRONMENT: "staging",
        SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
        DATABASE_URL:
          "postgresql://postgres:fake@db.zyxwvutsrqponmlkjihg.supabase.co:5432/postgres",
        SESSION_ISSUER: "hivorr-staging",
      }),
    ).toThrow(ConfigurationError)
  })

  it("never echoes a supplied value in a configuration error", () => {
    const secret = "postgres://user:super-secret@db.example/hivorr"
    try {
      parseConfig({ HIVORR_ENV: "staging", DATABASE_URL: secret })
    } catch (error) {
      expect(String(error)).not.toContain("super-secret")
    }
  })

  it("matches direct and pooler database URLs to their project reference", () => {
    expect(
      databaseUrlMatchesProjectRef(
        "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
        "abcdefghijklmnopqrst",
      ),
    ).toBe(true)
    expect(
      databaseUrlMatchesProjectRef(
        "postgresql://postgres.abcdefghijklmnopqrst:fake@aws-0-eu-west-1.pooler.supabase.com:6543/postgres",
        "abcdefghijklmnopqrst",
      ),
    ).toBe(true)
    expect(
      databaseUrlMatchesProjectRef(
        "postgresql://postgres:fake@db.zyxwvutsrqponmlkjihg.supabase.co:5432/postgres",
        "abcdefghijklmnopqrst",
      ),
    ).toBe(false)
  })

  it("provides safe worker defaults and falls back to the API database URL", () => {
    const config = parseConfig({
      HIVORR_ENV: "test",
      DATABASE_URL: "postgresql://postgres:fake@127.0.0.1:54322/postgres",
    })
    expect(config.worker.databaseUrl).toBe(config.databaseUrl)
    expect(config.worker.batchSize).toBe(20)
    expect(config.worker.maxAttempts).toBe(5)
    expect(config.worker.leaseMs).toBe(60_000)
    expect(config.worker.retryBaseMs).toBe(5_000)
    expect(config.worker.pollIntervalMs).toBe(1_000)
    expect(config.worker.healthPort).toBe(3001)
    expect(config.worker.workerId).toContain("hivorr-worker-test-")
  })

  it("uses a dedicated worker URL and rejects one from another project", () => {
    const workerUrl =
      "postgresql://postgres.abcdefghijklmnopqrst:fake@aws-0-eu-west-1.pooler.supabase.com:6543/postgres"
    const config = parseConfig({
      HIVORR_ENV: "staging",
      BACKEND_ENVIRONMENT: "staging",
      SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
      DATABASE_URL:
        "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
      WORKER_DATABASE_URL: workerUrl,
      SESSION_ISSUER: "hivorr-staging",
      MFA_ENCRYPTION_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    })
    expect(config.worker.databaseUrl).toBe(workerUrl)

    expect(() =>
      parseConfig({
        HIVORR_ENV: "staging",
        BACKEND_ENVIRONMENT: "staging",
        SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
        DATABASE_URL:
          "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
        WORKER_DATABASE_URL:
          "postgresql://postgres:fake@db.zyxwvutsrqponmlkjihg.supabase.co:5432/postgres",
        SESSION_ISSUER: "hivorr-staging",
        MFA_ENCRYPTION_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
      }),
    ).toThrow(ConfigurationError)
  })
})
