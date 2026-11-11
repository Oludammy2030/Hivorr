import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

import {
  ACTIVITIES,
  ACTIVITY_IDS,
  API_ERROR_CODES,
  CAPABILITY_IDS,
  DEFAULT_PAGE_SIZE,
  ENVIRONMENT_IDS,
  GRANT_IDS,
  MAX_PAGE_SIZE,
  PORTALS,
  PORTAL_IDS,
  RELEASE_MANIFEST_VERSION,
  ROUTES,
  ROUTE_IDS,
  activityIdSchema,
  apiErrorBodySchema,
  capabilityIdSchema,
  environmentIdSchema,
  getPortal,
  getPortalByHost,
  grantIdSchema,
  isProductionHost,
  paginationQuerySchema,
  portalIdSchema,
  routeIdSchema,
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

describe("activity registry contract", () => {
  it("defines exactly the six approved activities in matrix order", () => {
    expect(ACTIVITY_IDS).toEqual([
      "market.buy",
      "services.hire",
      "errands.request",
      "market.sell",
      "services.offer",
      "logistics.provide",
    ])
    expect(Object.keys(ACTIVITIES)).toHaveLength(6)
  })

  it("gives every activity a direction, a dashboard label and an approved route", () => {
    const approvedPaths = new Set(ROUTE_IDS.map((id) => ROUTES[id].path))
    for (const id of ACTIVITY_IDS) {
      const activity = ACTIVITIES[id]
      expect(["explore", "earn"]).toContain(activity.direction)
      expect(activity.dashboard.length).toBeGreaterThan(0)
      expect(approvedPaths.has(activity.routePath)).toBe(true)
    }
  })

  it("keeps the explore and earn split exact", () => {
    expect(
      ACTIVITY_IDS.filter((id) => ACTIVITIES[id].direction === "explore"),
    ).toEqual(["market.buy", "services.hire", "errands.request"])
    expect(
      ACTIVITY_IDS.filter((id) => ACTIVITIES[id].direction === "earn"),
    ).toEqual(["market.sell", "services.offer", "logistics.provide"])
  })
})

describe("capability and grant contract", () => {
  it("exports the full capability matrix once", () => {
    expect(CAPABILITY_IDS).toHaveLength(66)
    expect(new Set(CAPABILITY_IDS).size).toBe(CAPABILITY_IDS.length)
    for (const capability of [
      "session.read",
      "activity.activate",
      "activity.deactivate",
      "market.product.publish",
      "logistics.assignment.accept",
      "wallet.withdraw",
      "admin.audit.read",
      "admin.user.read",
      "admin.case.investigate",
      "admin.report.export",
      "platform.engineering.access",
    ]) {
      expect(CAPABILITY_IDS).toContain(capability)
    }
  })

  it("exports the six grant identifiers once", () => {
    expect(GRANT_IDS).toEqual([
      "admin.audit.read",
      "admin.grant.read",
      "admin.grant.manage",
      "staff.support.handle",
      "partner.referral.read",
      "platform.engineering",
    ])
    expect(new Set(GRANT_IDS).size).toBe(GRANT_IDS.length)
  })

  it("rejects an unknown capability or grant", () => {
    expect(capabilityIdSchema.safeParse("session.read").success).toBe(true)
    expect(capabilityIdSchema.safeParse("session.write").success).toBe(false)
    expect(grantIdSchema.safeParse("admin.grant.manage").success).toBe(true)
    expect(grantIdSchema.safeParse("admin.grant.delete").success).toBe(false)
  })
})

describe("API error contract", () => {
  it("exports the nine stable error codes", () => {
    expect(API_ERROR_CODES).toEqual([
      "UNAUTHENTICATED",
      "FORBIDDEN",
      "ACTIVITY_INACTIVE",
      "VALIDATION_FAILED",
      "NOT_FOUND",
      "CONFLICT",
      "RATE_LIMITED",
      "SERVICE_UNAVAILABLE",
      "INTERNAL_ERROR",
    ])
    expect(new Set(API_ERROR_CODES).size).toBe(API_ERROR_CODES.length)
  })

  it("parses a valid error body and rejects an unknown code", () => {
    expect(
      apiErrorBodySchema.safeParse({
        error: { code: "FORBIDDEN", message: "Denied." },
      }).success,
    ).toBe(true)
    expect(
      apiErrorBodySchema.safeParse({
        error: { code: "NOPE", message: "Denied." },
      }).success,
    ).toBe(false)
  })
})

describe("pagination contract", () => {
  it("applies the shared default and maximum page size", () => {
    expect(paginationQuerySchema.parse({})).toEqual({
      limit: DEFAULT_PAGE_SIZE,
    })
    expect(DEFAULT_PAGE_SIZE).toBe(20)
    expect(MAX_PAGE_SIZE).toBe(100)
    expect(paginationQuerySchema.safeParse({ limit: "101" }).success).toBe(
      false,
    )
    expect(paginationQuerySchema.safeParse({ limit: "0" }).success).toBe(false)
  })

  it("rejects an unknown query field", () => {
    expect(
      paginationQuerySchema.safeParse({ limit: "10", offset: "20" }).success,
    ).toBe(false)
  })
})

describe("route manifest contract", () => {
  it("declares every approved URL family once", () => {
    expect(ROUTE_IDS).toHaveLength(20)
    expect(ROUTE_IDS).toEqual([
      "home",
      "login",
      "signup",
      "onboarding",
      "forgot-password",
      "reset-password",
      "verify-email",
      "activities",
      "explore-market",
      "explore-hire",
      "explore-errands",
      "earn-sell",
      "earn-services",
      "earn-logistics",
      "wallet",
      "messages",
      "profile",
      "product",
      "store",
      "admin",
    ])
    expect(new Set(ROUTE_IDS).size).toBe(ROUTE_IDS.length)
  })

  it("keeps portal and path pairs unique", () => {
    const pairs = ROUTE_IDS.map(
      (id) => `${ROUTES[id].portal}:${ROUTES[id].path}`,
    )
    expect(new Set(pairs).size).toBe(pairs.length)
    for (const id of ROUTE_IDS) {
      expect(ROUTES[id].path.startsWith("/")).toBe(true)
    }
  })

  it("belongs the admin route to the control portal only", () => {
    expect(ROUTES.admin.portal).toBe("control")
    const controlRoutes = ROUTE_IDS.filter(
      (id) => ROUTES[id].portal === "control",
    )
    expect(controlRoutes).toEqual(["admin"])
  })

  it("indexes only the URLs the architecture makes crawlable", () => {
    expect(
      ROUTE_IDS.filter((id) => ROUTES[id].indexable).map(
        (id) => ROUTES[id].path,
      ),
    ).toEqual(["/", "/p/:slug", "/store/:slug"])
  })

  it("rejects an unknown route id", () => {
    expect(routeIdSchema.safeParse("home").success).toBe(true)
    expect(routeIdSchema.safeParse("checkout").success).toBe(false)
  })
})

describe("shared enum schemas", () => {
  it("validate environments and portals", () => {
    for (const id of ENVIRONMENT_IDS) {
      expect(environmentIdSchema.safeParse(id).success).toBe(true)
    }
    for (const id of PORTAL_IDS) {
      expect(portalIdSchema.safeParse(id).success).toBe(true)
    }
    expect(environmentIdSchema.safeParse("local").success).toBe(false)
    expect(portalIdSchema.safeParse("admin").success).toBe(false)
  })

  it("validate activities", () => {
    for (const id of ACTIVITY_IDS) {
      expect(activityIdSchema.safeParse(id).success).toBe(true)
    }
    expect(activityIdSchema.safeParse("market.discover").success).toBe(false)
  })
})

describe("no duplicate vocabulary", () => {
  const read = (relative: string) =>
    readFileSync(path.join(process.cwd(), relative), "utf8")

  it("keeps capability and grant lists out of the server", () => {
    const source = read("server/src/domain/capabilities.ts")
    expect(source).not.toContain("export const CAPABILITY_IDS")
    expect(source).not.toContain("export type GrantId =")
  })

  it("keeps error codes out of the server", () => {
    const source = read("server/src/common/errors.ts")
    expect(source).not.toContain("export type ApiErrorCode =")
  })

  it("keeps the shared package free of React, Node and server imports", () => {
    for (const file of [
      "packages/shared/src/index.ts",
      "packages/shared/src/activities.ts",
      "packages/shared/src/capabilities.ts",
      "packages/shared/src/errors.ts",
      "packages/shared/src/pagination.ts",
      "packages/shared/src/routes.ts",
    ]) {
      const source = read(file)
      expect(source).not.toMatch(/from\s+["']react/)
      expect(source).not.toMatch(/from\s+["']node:/)
      expect(source).not.toMatch(/from\s+["']@hivorr\/server/)
      expect(source).not.toMatch(/from\s+["'](?:pg|@nestjs|fastify)/)
    }
  })
})
