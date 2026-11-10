import { describe, expect, it } from "vitest"

import { ApiError, requireCapability } from "../server/src/common/errors"
import {
  computeCapabilities,
  type AccessContext,
} from "../server/src/domain/capabilities"

const appContext: AccessContext = {
  authenticated: true,
  audience: "app",
  environment: "staging",
  grants: [],
}

describe("capability enforcement", () => {
  it("allows a capability the context holds", () => {
    expect(() =>
      requireCapability(computeCapabilities(appContext), "activity.activate"),
    ).not.toThrow()
  })

  it("denies with the stable FORBIDDEN code", () => {
    try {
      requireCapability(computeCapabilities(appContext), "admin.audit.read")
      throw new Error("expected a denial")
    } catch (error) {
      expect(error).toBeInstanceOf(ApiError)
      expect((error as ApiError).code).toBe("FORBIDDEN")
      expect((error as ApiError).statusCode).toBe(403)
    }
  })

  it("allows an audit read only for a control session with the grant", () => {
    const withoutGrant: AccessContext = {
      ...appContext,
      audience: "control",
    }
    expect(() =>
      requireCapability(computeCapabilities(withoutGrant), "admin.audit.read"),
    ).toThrow(ApiError)

    const withGrant: AccessContext = {
      ...withoutGrant,
      grants: ["admin.audit.read"],
    }
    expect(() =>
      requireCapability(computeCapabilities(withGrant), "admin.audit.read"),
    ).not.toThrow()
  })
})
