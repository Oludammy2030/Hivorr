import { CAPABILITY_IDS, type CapabilityId } from "@hivorr/shared"
import { describe, expect, it } from "vitest"

import {
  CAPABILITY_DENY_REASONS,
  CAPABILITY_RULES,
  computeCapabilities,
  evaluateCapability,
  type AccessContext,
  type CapabilityRule,
} from "../server/src/domain/capabilities"

function audienceOutside(
  allowed: readonly string[],
): "app" | "control" | "staff" | "partner" {
  if (!allowed.includes("control")) return "control"
  if (!allowed.includes("app")) return "app"
  if (!allowed.includes("staff")) return "staff"
  return "partner"
}

function allowedContextFor(capability: CapabilityId): AccessContext {
  const rule: CapabilityRule = CAPABILITY_RULES[capability]
  return {
    authenticated: true,
    audience: rule.audience === "any" ? "app" : rule.audience[0]!,
    environment: "staging",
    grants: rule.grant ? [rule.grant] : [],
    activities: rule.activity ? [rule.activity] : [],
    verification: rule.verification ? { [rule.verification]: true } : {},
    kycTier: rule.kyc ? "tier_1" : "tier_0",
    adminPermissions: rule.permission ? [rule.permission] : [],
    deniedPermissions: [],
    adminRoles: rule.adminRole ? [rule.adminRole] : [],
    member: rule.requiresMember === true,
    businessApproved: rule.requiresBusinessUnapproved ? false : true,
    payoutAccountBound: rule.requiresPayoutAccount === true,
  }
}

function denyVariants(
  capability: CapabilityId,
  allowed: AccessContext,
): AccessContext[] {
  const rule = CAPABILITY_RULES[capability]
  const variants: AccessContext[] = []

  if (rule.audience !== "any") {
    variants.push({
      ...allowed,
      audience: audienceOutside(rule.audience),
    })
  }
  if (rule.grant) variants.push({ ...allowed, grants: [] })
  if (rule.permission) {
    variants.push({ ...allowed, adminPermissions: [] })
    variants.push({
      ...allowed,
      deniedPermissions: [rule.permission],
    })
  }
  if (rule.adminRole) variants.push({ ...allowed, adminRoles: [] })
  if (rule.requiresMember) variants.push({ ...allowed, member: false })
  if (rule.requiresBusinessUnapproved) {
    variants.push({ ...allowed, businessApproved: true })
  }
  if (rule.activity) variants.push({ ...allowed, activities: [] })
  if (rule.verification) variants.push({ ...allowed, verification: {} })
  if (rule.kyc) variants.push({ ...allowed, kycTier: "tier_0" })
  if (rule.requiresPayoutAccount) {
    variants.push({ ...allowed, payoutAccountBound: false })
  }
  if (variants.length === 0) {
    variants.push({ ...allowed, authenticated: false })
  }
  return variants
}

describe("capability registry", () => {
  it("has exactly one rule for every shared capability ID", () => {
    expect(Object.keys(CAPABILITY_RULES).sort()).toEqual(
      [...CAPABILITY_IDS].sort(),
    )
    expect(new Set(CAPABILITY_IDS).size).toBe(CAPABILITY_IDS.length)
    expect(new Set(CAPABILITY_DENY_REASONS).size).toBe(
      CAPABILITY_DENY_REASONS.length,
    )
  })

  it("allows every capability when all of its inputs are supplied", () => {
    for (const capability of CAPABILITY_IDS) {
      const decision = evaluateCapability(
        allowedContextFor(capability),
        capability,
      )
      expect(decision, capability).toEqual({ allowed: true })
    }
  })

  it("denies every capability when any one of its inputs is missing", () => {
    for (const capability of CAPABILITY_IDS) {
      const allowed = allowedContextFor(capability)
      for (const denied of denyVariants(capability, allowed)) {
        expect(evaluateCapability(denied, capability).allowed, capability).toBe(
          false,
        )
      }
    }
  })

  it("returns a stable deny reason for each requirement family", () => {
    const base: AccessContext = {
      authenticated: true,
      audience: "app",
      environment: "staging",
      grants: [],
    }
    expect(
      evaluateCapability({ ...base, authenticated: false }, "session.read"),
    ).toEqual({ allowed: false, reason: "UNAUTHENTICATED" })
    expect(evaluateCapability(base, "admin.audit.read")).toEqual({
      allowed: false,
      reason: "WRONG_AUDIENCE",
    })
    expect(
      evaluateCapability({ ...base, audience: "control" }, "admin.audit.read"),
    ).toEqual({ allowed: false, reason: "MISSING_GRANT" })
    expect(
      evaluateCapability(
        { ...base, audience: "control" },
        "admin.verification.review",
      ),
    ).toEqual({ allowed: false, reason: "MISSING_PERMISSION" })
    expect(
      evaluateCapability(
        {
          ...base,
          audience: "control",
          adminPermissions: ["admin.verification.review"],
          deniedPermissions: ["admin.verification.review"],
        },
        "admin.verification.review",
      ),
    ).toEqual({ allowed: false, reason: "EXPLICIT_DENY" })
    expect(evaluateCapability(base, "market.cart.manage")).toEqual({
      allowed: false,
      reason: "ACTIVITY_INACTIVE",
    })
    expect(
      evaluateCapability(
        { ...base, activities: ["market.sell"] },
        "market.product.publish",
      ),
    ).toEqual({ allowed: false, reason: "VERIFICATION_REQUIRED" })
    expect(
      evaluateCapability({ ...base, kycTier: "tier_0" }, "wallet.withdraw"),
    ).toEqual({ allowed: false, reason: "KYC_REQUIRED" })
    expect(evaluateCapability(base, "not.a.capability")).toEqual({
      allowed: false,
      reason: "UNKNOWN_CAPABILITY",
    })
  })

  it("computes a set from the same decisions", () => {
    const context: AccessContext = {
      authenticated: true,
      audience: "app",
      environment: "staging",
      grants: [],
      activities: ["market.buy"],
    }
    const capabilities = computeCapabilities(context)
    for (const capability of CAPABILITY_IDS) {
      expect(capabilities.has(capability), capability).toBe(
        evaluateCapability(context, capability).allowed,
      )
    }
    expect(capabilities.has("session.read")).toBe(true)
    expect(capabilities.has("market.cart.manage")).toBe(true)
    expect(capabilities.has("market.product.publish")).toBe(false)
  })

  it("does not widen from an untyped request-shaped field", () => {
    const context = {
      authenticated: true,
      audience: "app",
      environment: "staging",
      grants: [],
      body: { grants: ["admin.audit.read"], adminRoles: ["account.manage"] },
    } as unknown as AccessContext

    expect(evaluateCapability(context, "admin.account.suspend").allowed).toBe(
      false,
    )
    expect(computeCapabilities(context).has("admin.account.suspend")).toBe(
      false,
    )
  })
})
