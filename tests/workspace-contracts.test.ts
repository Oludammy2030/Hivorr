import { describe, expect, it } from "vitest"

import {
  ENVIRONMENT_IDS,
  PORTALS,
  PORTAL_IDS,
  RELEASE_MANIFEST_VERSION,
  getPortal,
  getPortalByHost,
  isProductionHost,
} from "@hivorr/shared"

describe("four portals, two environments", () => {
  it("defines exactly four portals", () => {
    expect(PORTAL_IDS).toEqual(["app", "control", "staff", "partner"])
    expect(Object.keys(PORTALS)).toHaveLength(4)
  })

  it("defines production and staging hosts for every portal", () => {
    for (const id of PORTAL_IDS) {
      const portal = getPortal(id)
      expect(portal.hosts.production).toBeTruthy()
      expect(portal.hosts.staging).toBeTruthy()
      expect(portal.hosts.production).not.toBe(portal.hosts.staging)
    }
  })

  it("keeps every host unique across the eight deployments", () => {
    const hosts = PORTAL_IDS.flatMap((id) =>
      ENVIRONMENT_IDS.map((environment) => getPortal(id).hosts[environment]),
    )
    expect(new Set(hosts).size).toBe(8)
  })

  it("uses the approved partner hostnames", () => {
    expect(getPortal("partner").hosts.production).toBe("partner.hivorr.com")
    expect(getPortal("partner").hosts.staging).toBe(
      "partner-staging.hivorr.com",
    )
  })

  it("keeps one audience per portal and never shares it", () => {
    const audiences = PORTAL_IDS.map((id) => getPortal(id).audience)
    expect(audiences).toEqual(["app", "control", "staff", "partner"])
    expect(new Set(audiences).size).toBe(4)
  })

  it("marks only the main portal as indexable", () => {
    expect(getPortal("app").noindex).toBe(false)
    for (const id of ["control", "staff", "partner"] as const) {
      expect(getPortal(id).noindex).toBe(true)
    }
  })

  it("resolves a host to its portal and environment", () => {
    expect(getPortalByHost("hivorr.com", "production")?.id).toBe("app")
    expect(getPortalByHost("control-staging.hivorr.com", "staging")?.id).toBe(
      "control",
    )
    expect(
      getPortalByHost("control-staging.hivorr.com", "production"),
    ).toBeUndefined()
  })

  it("distinguishes a production host from a staging host", () => {
    expect(isProductionHost("hivorr.com")).toBe(true)
    expect(isProductionHost("staging.hivorr.com")).toBe(false)
  })

  it("uses a versioned release manifest", () => {
    expect(RELEASE_MANIFEST_VERSION).toBe(1)
  })
})
