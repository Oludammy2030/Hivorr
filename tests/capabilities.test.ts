import { describe, expect, it } from "vitest"

import {
  can,
  computeCapabilities,
  type AccessContext,
} from "../server/src/domain/capabilities"

const base: AccessContext = {
  authenticated: true,
  audience: "app",
  environment: "staging",
  grants: [],
}

describe("capability computation", () => {
  it("denies everything before authentication", () => {
    const capabilities = computeCapabilities({ ...base, authenticated: false })
    expect(capabilities.size).toBe(0)
    expect(can({ ...base, authenticated: false }, "session.read")).toBe(false)
  })

  it("allows a main-portal session to read the session and activate activities", () => {
    const capabilities = computeCapabilities(base)
    expect(capabilities.has("session.read")).toBe(true)
    expect(capabilities.has("activity.activate")).toBe(true)
    expect(capabilities.has("admin.audit.read")).toBe(false)
  })

  it("does not grant control capabilities from an app session", () => {
    const context: AccessContext = {
      ...base,
      grants: ["admin.audit.read", "platform.engineering"],
    }
    const capabilities = computeCapabilities(context)
    expect(capabilities.has("admin.audit.read")).toBe(false)
    expect(capabilities.has("platform.engineering.access")).toBe(false)
  })

  it("allows control audit access only with the control audience and grant", () => {
    expect(can({ ...base, audience: "control" }, "admin.audit.read")).toBe(
      false,
    )
    expect(
      can(
        { ...base, audience: "control", grants: ["admin.audit.read"] },
        "admin.audit.read",
      ),
    ).toBe(true)
  })

  it("allows control grant access only with the control audience and grant", () => {
    expect(can({ ...base, audience: "control" }, "admin.grant.read")).toBe(
      false,
    )
    expect(
      can(
        { ...base, audience: "control", grants: ["admin.grant.read"] },
        "admin.grant.read",
      ),
    ).toBe(true)
    expect(
      can(
        { ...base, audience: "control", grants: ["admin.grant.manage"] },
        "admin.grant.manage",
      ),
    ).toBe(true)
    expect(
      can(
        { ...base, audience: "control", grants: ["admin.grant.manage"] },
        "admin.grant.read",
      ),
    ).toBe(false)
  })

  it("requires a governance permission for administrative capabilities", () => {
    expect(
      can(
        { ...base, audience: "control", adminPermissions: ["admin.user.read"] },
        "admin.user.read",
      ),
    ).toBe(true)
    expect(
      can(
        {
          ...base,
          audience: "control",
          adminPermissions: ["admin.user.read"],
          deniedPermissions: ["admin.user.read"],
        },
        "admin.user.read",
      ),
    ).toBe(false)
    expect(
      can(
        {
          ...base,
          audience: "control",
          adminPermissions: ["admin.user.read"],
        },
        "admin.user.manage",
      ),
    ).toBe(false)
  })

  it("keeps staff, partner and engineering grants in their own audiences", () => {
    const staff = computeCapabilities({
      ...base,
      audience: "staff",
      grants: ["staff.support.handle"],
    })
    expect(staff.has("staff.support.handle")).toBe(true)
    expect(staff.has("partner.referral.read")).toBe(false)

    const partner = computeCapabilities({
      ...base,
      audience: "partner",
      grants: ["partner.referral.read"],
    })
    expect(partner.has("partner.referral.read")).toBe(true)
    expect(partner.has("activity.activate")).toBe(false)

    const engineering = computeCapabilities({
      ...base,
      audience: "control",
      grants: ["platform.engineering"],
    })
    expect(engineering.has("platform.engineering.access")).toBe(true)
    expect(engineering.has("admin.audit.read")).toBe(false)
  })

  it("ignores a grant that belongs to another audience", () => {
    const capabilities = computeCapabilities({
      ...base,
      audience: "staff",
      grants: ["admin.audit.read", "partner.referral.read"],
    })
    expect(capabilities.has("admin.audit.read")).toBe(false)
    expect(capabilities.has("partner.referral.read")).toBe(false)
  })
})
