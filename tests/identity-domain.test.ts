import { describe, expect, it } from "vitest"

import { GRANT_TYPE_VALUES } from "../server/src/contracts/schemas"
import {
  ACCOUNT_STATUSES,
  GRANT_SCOPES,
  GRANT_TYPES,
  REGISTRATION_CREATES_ACTIVITIES,
  REGISTRATION_CREATES_GRANTS,
  assertSingleOwner,
  grantIsActive,
  grantScopeIsValid,
  isAccountStatus,
  isUserStatus,
  normalizeEmail,
} from "../server/src/modules/identity/domain/identity"

describe("identity domain invariants", () => {
  it("normalizes an email before comparison or storage", () => {
    expect(normalizeEmail("  Founder@Example.Test ")).toBe(
      "founder@example.test",
    )
  })

  it("accepts only a scope that belongs to the grant type", () => {
    for (const grantType of GRANT_TYPES) {
      for (const scope of GRANT_SCOPES[grantType]) {
        expect(grantScopeIsValid(grantType, scope)).toBe(true)
      }
    }
    expect(grantScopeIsValid("staff", "admin.grant.manage")).toBe(false)
    expect(grantScopeIsValid("admin", "staff.support.handle")).toBe(false)
    expect(grantScopeIsValid("unknown", "admin.grant.read")).toBe(false)
  })

  it("keeps the domain grant types aligned with the API contract", () => {
    expect([...GRANT_TYPES].sort()).toEqual([...GRANT_TYPE_VALUES].sort())
  })

  it("treats an expired or revoked grant as inactive", () => {
    const now = new Date("2026-11-09T12:00:00.000Z")
    expect(grantIsActive({ expiresAt: null }, now)).toBe(true)
    expect(grantIsActive({ expiresAt: "2026-11-10T12:00:00.000Z" }, now)).toBe(
      true,
    )
    expect(grantIsActive({ expiresAt: "2026-11-08T12:00:00.000Z" }, now)).toBe(
      false,
    )
    expect(
      grantIsActive(
        { expiresAt: "2026-11-10T12:00:00.000Z", revokedAt: "2026-11-09" },
        now,
      ),
    ).toBe(false)
  })

  it("allows one owner and rejects two", () => {
    expect(() => assertSingleOwner(["owner", "member"])).not.toThrow()
    expect(() => assertSingleOwner(["member", "member"])).not.toThrow()
    expect(() => assertSingleOwner(["owner", "owner"])).toThrow(
      /at most one owner/,
    )
  })

  it("keeps registration free of grants and activity activation", () => {
    expect(REGISTRATION_CREATES_GRANTS).toBe(false)
    expect(REGISTRATION_CREATES_ACTIVITIES).toBe(false)
  })

  it("recognizes the declared statuses", () => {
    for (const status of ACCOUNT_STATUSES) {
      expect(isAccountStatus(status)).toBe(true)
    }
    expect(isAccountStatus("deleted")).toBe(false)
    expect(isUserStatus("suspended")).toBe(true)
    expect(isUserStatus("admin")).toBe(false)
  })
})
