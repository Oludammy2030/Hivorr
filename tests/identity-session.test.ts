import { describe, expect, it } from "vitest"

import {
  buildSessionCookie,
  clearSessionCookie,
  sessionCookieName,
  sessionPolicy,
} from "../server/src/modules/identity/session-policy"
import { resolveAudience } from "../server/src/modules/identity/portal"
import {
  createSessionToken,
  hashPassword,
  hashSessionToken,
  normalizeEmail,
  verifyPassword,
} from "../server/src/modules/identity/identity.service"

describe("identity session policy", () => {
  it("uses a shorter session on privileged portals", () => {
    expect(sessionPolicy("app")).toEqual({
      absoluteMs: 12 * 60 * 60 * 1000,
      idleMs: 30 * 60 * 1000,
    })
    expect(sessionPolicy("control")).toEqual({
      absoluteMs: 8 * 60 * 60 * 1000,
      idleMs: 15 * 60 * 1000,
    })
    expect(sessionPolicy("staff").idleMs).toBe(15 * 60 * 1000)
    expect(sessionPolicy("partner").idleMs).toBe(15 * 60 * 1000)
  })

  it("uses host-only cookie names and secure attributes", () => {
    expect(sessionCookieName("app")).toBe("__Host-hivorr_app_sid")
    expect(sessionCookieName("partner")).toBe("__Host-hivorr_partner_sid")

    const cookie = buildSessionCookie("__Host-hivorr_app_sid", "token", 3600)
    expect(cookie).toContain("__Host-hivorr_app_sid=token")
    expect(cookie).toContain("HttpOnly")
    expect(cookie).toContain("Secure")
    expect(cookie).toContain("SameSite=Lax")
    expect(cookie).toContain("Path=/")
    expect(cookie).toContain("Max-Age=3600")
    expect(clearSessionCookie("__Host-hivorr_app_sid")).toContain("Max-Age=0")
  })
})

describe("portal resolution", () => {
  it("maps production and staging hosts to audiences", () => {
    expect(resolveAudience("hivorr.com", "production")).toBe("app")
    expect(resolveAudience("control.hivorr.com:443", "production")).toBe(
      "control",
    )
    expect(resolveAudience("staff.staging.hivorr.com", "staging")).toBe("staff")
    expect(resolveAudience("partner.staging.hivorr.com", "staging")).toBe(
      "partner",
    )
  })

  it("rejects an unknown host or a non-hosted environment", () => {
    expect(resolveAudience("example.com", "production")).toBeUndefined()
    expect(resolveAudience("hivorr.com", "development")).toBeUndefined()
  })
})

describe("identity primitives", () => {
  it("normalises email and hashes tokens deterministically", () => {
    expect(normalizeEmail("  Founder@Example.Test ")).toBe(
      "founder@example.test",
    )
    const token = createSessionToken()
    expect(token.length).toBeGreaterThan(30)
    expect(hashSessionToken(token)).toBe(hashSessionToken(token))
    expect(hashSessionToken(token)).not.toBe(token)
  })

  it("hashes and verifies a password with Argon2id", async () => {
    const hash = await hashPassword("a-long-test-password")
    expect(hash.startsWith("$argon2id$")).toBe(true)
    await expect(verifyPassword(hash, "a-long-test-password")).resolves.toBe(
      true,
    )
    await expect(verifyPassword(hash, "wrong-password")).resolves.toBe(false)
  })
})
