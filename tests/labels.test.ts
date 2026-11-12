import { describe, expect, it } from "vitest"

import { CAPABILITY_IDS, capabilityLabel, grantTypeLabel } from "@hivorr/shared"

describe("presentation labels", () => {
  it("describes the governance capabilities in plain language", () => {
    expect(capabilityLabel("admin.audit.read")).toBe("Read the audit log")
    expect(capabilityLabel("admin.grant.read")).toBe("See grants")
    expect(capabilityLabel("admin.grant.manage")).toBe(
      "Create and revoke grants",
    )
    expect(capabilityLabel("session.read")).toBe("Use your signed-in session")
  })

  it("falls back to a humanised identifier for an unknown key", () => {
    expect(capabilityLabel("market.order.place")).toBe("Market order place")
    expect(capabilityLabel("unknown_key")).toBe("Unknown key")
  })

  it("names grant types", () => {
    expect(grantTypeLabel("admin")).toBe("Administrator")
    expect(grantTypeLabel("staff")).toBe("Staff")
    expect(grantTypeLabel("partner")).toBe("Partner")
    expect(grantTypeLabel("platform_engineering")).toBe("Engineering")
  })

  it("returns a non-empty label for every registered capability", () => {
    for (const capability of CAPABILITY_IDS) {
      const label = capabilityLabel(capability)
      expect(label.length).toBeGreaterThan(0)
      expect(label).not.toContain(".")
    }
  })
})
