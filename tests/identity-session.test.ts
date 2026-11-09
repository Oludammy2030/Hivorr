import { describe, expect, it } from "vitest"

import {
  buildRefreshCookie,
  buildSessionCookie,
  clearRefreshCookie,
  clearSessionCookie,
  refreshCookieName,
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
import {
  generateRecoveryCodes,
  hashRecoveryCode,
  MfaCipher,
} from "../server/src/modules/identity/mfa-crypto"
import {
  base32Decode,
  base32Encode,
  generateTotpSecret,
  totpCode,
  totpUri,
  verifyTotp,
} from "../server/src/modules/identity/totp"

describe("identity session policy", () => {
  it("uses a shorter session on privileged portals", () => {
    expect(sessionPolicy("app")).toEqual({
      absoluteMs: 12 * 60 * 60 * 1000,
      idleMs: 30 * 60 * 1000,
      accessMs: 30 * 60 * 1000,
    })
    expect(sessionPolicy("control")).toEqual({
      absoluteMs: 8 * 60 * 60 * 1000,
      idleMs: 15 * 60 * 1000,
      accessMs: 15 * 60 * 1000,
    })
    expect(sessionPolicy("staff").idleMs).toBe(15 * 60 * 1000)
    expect(sessionPolicy("partner").idleMs).toBe(15 * 60 * 1000)
    expect(sessionPolicy("app").accessMs).toBeLessThan(
      sessionPolicy("app").absoluteMs,
    )
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

    expect(refreshCookieName("app")).toBe("hivorr_app_rt")
    const refresh = buildRefreshCookie("hivorr_app_rt", "refresh", 7200)
    expect(refresh).toContain("hivorr_app_rt=refresh")
    expect(refresh).toContain("HttpOnly")
    expect(refresh).toContain("Secure")
    expect(refresh).toContain("SameSite=Strict")
    expect(refresh).toContain("Path=/v1/auth")
    expect(refresh).toContain("Max-Age=7200")
    expect(clearRefreshCookie("hivorr_app_rt")).toContain("Max-Age=0")
  })
})

describe("portal resolution", () => {
  it("maps production and staging hosts to audiences", () => {
    expect(resolveAudience("hivorr.com", "production")).toBe("app")
    expect(resolveAudience("control.hivorr.com:443", "production")).toBe(
      "control",
    )
    expect(resolveAudience("staff-staging.hivorr.com", "staging")).toBe("staff")
    expect(resolveAudience("partner-staging.hivorr.com", "staging")).toBe(
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

describe("TOTP", () => {
  it("round-trips base32", () => {
    const bytes = Buffer.from("hivorr-totp-test-secret")
    expect(base32Decode(base32Encode(bytes))).toEqual(bytes)
  })

  it("matches the RFC 6238 SHA-1 vector at six digits", () => {
    const secret = base32Encode(Buffer.from("12345678901234567890"))
    expect(secret).toBe("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ")
    expect(totpCode(secret, 1)).toBe("287082")
    expect(verifyTotp(secret, "287082", 59_000)).toBe(true)
    expect(verifyTotp(secret, "287083", 59_000)).toBe(false)
  })

  it("rejects malformed codes and builds an otpauth URI", () => {
    const secret = generateTotpSecret()
    expect(verifyTotp(secret, "abcdef")).toBe(false)
    expect(verifyTotp(secret, "12345")).toBe(false)

    const uri = totpUri(secret, "founder@example.test")
    expect(uri).toContain("otpauth://totp/Hivorr%3Afounder%40example.test")
    expect(uri).toContain(`secret=${secret}`)
    expect(uri).toContain("issuer=Hivorr")
    expect(uri).toContain("period=30")
  })
})

describe("MFA secret handling", () => {
  const key = Buffer.alloc(32, 3).toString("base64")

  it("encrypts with authenticated encryption and decrypts", () => {
    const cipher = MfaCipher.fromBase64(key)!
    const encrypted = cipher.encrypt("JBSWY3DPEHPK3PXP")
    expect(encrypted.ciphertext).not.toContain("JBSWY3DPEHPK3PXP")
    expect(encrypted.keyVersion).toBe("v1")
    expect(cipher.decrypt(encrypted.ciphertext)).toBe("JBSWY3DPEHPK3PXP")
  })

  it("fails closed with the wrong key or a tampered ciphertext", () => {
    const cipher = MfaCipher.fromBase64(key)!
    const other = MfaCipher.fromBase64(Buffer.alloc(32, 9).toString("base64"))!
    const encrypted = cipher.encrypt("secret")

    expect(() => other.decrypt(encrypted.ciphertext)).toThrow()
    const parts = encrypted.ciphertext.split(":")
    parts[3] = `${parts[3][0] === "A" ? "B" : "A"}${parts[3].slice(1)}`
    expect(() => cipher.decrypt(parts.join(":"))).toThrow()
  })

  it("rejects a key that is not 32 bytes", () => {
    expect(() =>
      MfaCipher.fromBase64(Buffer.from("too-short").toString("base64")),
    ).toThrow()
    expect(MfaCipher.fromBase64(undefined)).toBeUndefined()
  })

  it("generates distinct, normalisable recovery codes", () => {
    const codes = generateRecoveryCodes()
    expect(codes).toHaveLength(10)
    expect(new Set(codes).size).toBe(10)
    expect(codes[0]).toMatch(/^[2-9A-HJ-NP-Z]{5}-[2-9A-HJ-NP-Z]{5}$/)
    expect(hashRecoveryCode(codes[0])).toBe(
      hashRecoveryCode(codes[0].toLowerCase().replace("-", " ")),
    )
    expect(hashRecoveryCode(codes[0])).not.toBe(hashRecoveryCode(codes[1]))
  })
})
