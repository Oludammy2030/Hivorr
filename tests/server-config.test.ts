import { describe, expect, it } from "vitest"

import { parseConfig, ConfigurationError } from "../server/src/config"

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
    }
  })

  it("accepts an explicit production configuration", () => {
    const config = parseConfig({
      HIVORR_ENV: "production",
      DATABASE_URL: "postgres://user:pass@db.example/hivorr",
      SESSION_ISSUER: "hivorr-production",
      API_PORT: "8080",
      CORS_ALLOWED_ORIGINS: "https://hivorr.com, https://control.hivorr.com",
    })
    expect(config.port).toBe(8080)
    expect(config.corsAllowedOrigins).toEqual([
      "https://hivorr.com",
      "https://control.hivorr.com",
    ])
  })

  it("never echoes a supplied value in a configuration error", () => {
    const secret = "postgres://user:super-secret@db.example/hivorr"
    try {
      parseConfig({ HIVORR_ENV: "staging", DATABASE_URL: secret })
    } catch (error) {
      expect(String(error)).not.toContain("super-secret")
    }
  })
})
