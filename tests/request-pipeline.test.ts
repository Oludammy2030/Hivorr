import type { FastifyRequest } from "fastify"
import { describe, expect, it } from "vitest"

import { paginationQuerySchema } from "@hivorr/shared"

import {
  AUDIENCE_METADATA,
  AudienceGuard,
  resolveRequestAudience,
  type RouteAudience,
} from "../server/src/common/audience"
import {
  ApiError,
  activityInactive,
  toErrorBody,
} from "../server/src/common/errors"
import {
  IDEMPOTENCY_HEADER,
  requireIdempotencyKey,
  requestFingerprint,
} from "../server/src/common/idempotency"
import {
  decodeCursor,
  encodeCursor,
  toPage,
} from "../server/src/common/pagination"
import { parseBody } from "../server/src/common/validation"
import { parseConfig, type ApiConfig } from "../server/src/config"

const stagingConfig: ApiConfig = parseConfig({
  HIVORR_ENV: "staging",
  BACKEND_ENVIRONMENT: "staging",
  SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
  DATABASE_URL:
    "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
  SESSION_ISSUER: "hivorr-staging",
  MFA_ENCRYPTION_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
  EDGE_SHARED_SECRET: "edge-secret-for-tests",
})

function request(overrides: Partial<FastifyRequest> = {}): FastifyRequest {
  return {
    headers: {},
    ip: "127.0.0.1",
    ...overrides,
  } as unknown as FastifyRequest
}

function contextFor(
  handler: (...args: never[]) => unknown,
  requestValue: FastifyRequest,
) {
  return {
    getHandler: () => handler,
    getClass: () => class TestController {},
    switchToHttp: () => ({ getRequest: () => requestValue }),
  } as never
}

function routeHandler(declared?: readonly RouteAudience[]) {
  const handler = () => undefined
  if (declared) Reflect.defineMetadata(AUDIENCE_METADATA, declared, handler)
  return handler
}

const reflector = {
  getAllAndOverride<T,>(key: string, targets: unknown[]): T | undefined {
    for (const target of targets) {
      const value = Reflect.getMetadata(key, target)
      if (value !== undefined) return value as T
    }
    return undefined
  },
} as never

describe("request validation", () => {
  const schema = paginationQuerySchema

  it("accepts a body that names only declared fields", () => {
    expect(parseBody(schema, { limit: "10" })).toEqual({ limit: 10 })
  })

  it("rejects an unknown field instead of ignoring it", () => {
    try {
      parseBody(schema, { limit: "10", offset: "20" })
      throw new Error("expected a validation failure")
    } catch (error) {
      expect(error).toBeInstanceOf(ApiError)
      expect((error as ApiError).code).toBe("VALIDATION_FAILED")
      expect((error as ApiError).statusCode).toBe(400)
      expect((error as ApiError).message).toContain("offset")
      expect((error as ApiError).message).not.toContain("zod")
    }
  })

  it("names an invalid field without exposing the internal reason", () => {
    try {
      parseBody(schema, { limit: "0" })
      throw new Error("expected a validation failure")
    } catch (error) {
      expect((error as ApiError).code).toBe("VALIDATION_FAILED")
      expect((error as ApiError).message).toContain("limit")
    }
  })
})

describe("error contract", () => {
  it("keeps the five distinguishable denial and validation outcomes distinct", () => {
    const errors = [
      new ApiError("UNAUTHENTICATED", "sign in", 401),
      new ApiError("FORBIDDEN", "denied", 403),
      activityInactive(),
      new ApiError("VALIDATION_FAILED", "invalid", 400),
      new ApiError("NOT_FOUND", "missing", 404),
    ]

    const bodies = errors.map((error) => toErrorBody(error, "correlation-1"))
    expect(new Set(bodies.map((body) => body.error.code)).size).toBe(5)
    expect(bodies.map((body) => body.error.code)).toEqual([
      "UNAUTHENTICATED",
      "FORBIDDEN",
      "ACTIVITY_INACTIVE",
      "VALIDATION_FAILED",
      "NOT_FOUND",
    ])
    expect(bodies[2].error.message).toContain("activity")
    for (const body of bodies) {
      expect(body.error.correlationId).toBe("correlation-1")
    }
  })
})

describe("audience guard", () => {
  const guard = new AudienceGuard(reflector, stagingConfig)

  it("allows a declared audience on its own host", () => {
    const handler = routeHandler(["control"])
    const requestValue = request({
      headers: { host: "control-staging.hivorr.com" },
    })
    expect(guard.canActivate(contextFor(handler, requestValue))).toBe(true)
    expect(
      (requestValue as FastifyRequest & { audience?: string }).audience,
    ).toBe("control")
  })

  it("rejects the wrong portal audience", () => {
    const handler = routeHandler(["control"])
    const requestValue = request({ headers: { host: "staging.hivorr.com" } })
    expect(() => guard.canActivate(contextFor(handler, requestValue))).toThrow(
      /may not call/i,
    )
  })

  it("rejects an unrecognised host", () => {
    const handler = routeHandler(["control"])
    const requestValue = request({ headers: { host: "example.test" } })
    expect(() => guard.canActivate(contextFor(handler, requestValue))).toThrow(
      /not a recognised/i,
    )
  })

  it("rejects a route that declares no audience", () => {
    const handler = routeHandler()
    const requestValue = request({ headers: { host: "staging.hivorr.com" } })
    expect(() => guard.canActivate(contextFor(handler, requestValue))).toThrow(
      /does not declare an audience/i,
    )
  })

  it("allows a public route without a portal host", () => {
    const handler = routeHandler(["public"])
    const requestValue = request({ headers: { host: "127.0.0.1" } })
    expect(guard.canActivate(contextFor(handler, requestValue))).toBe(true)
  })

  it("rejects a portal route when the API is not in a deployed environment", () => {
    const testConfig = parseConfig({ HIVORR_ENV: "test" })
    const testGuard = new AudienceGuard(reflector, testConfig)
    const handler = routeHandler(["app"])
    const requestValue = request({ headers: { host: "staging.hivorr.com" } })
    expect(() =>
      testGuard.canActivate(contextFor(handler, requestValue)),
    ).toThrow(/not available/i)
  })

  it("honours a forwarded host only when the edge secret matches", () => {
    const trusted = request({
      headers: {
        host: "internal.fly.local",
        "x-hivorr-origin-host": "control-staging.hivorr.com",
        "x-hivorr-edge-secret": "edge-secret-for-tests",
      },
    })
    expect(resolveRequestAudience(stagingConfig, trusted)).toBe("control")

    const spoofed = request({
      headers: {
        host: "internal.fly.local",
        "x-hivorr-origin-host": "control-staging.hivorr.com",
        "x-hivorr-edge-secret": "wrong-secret",
      },
    })
    expect(resolveRequestAudience(stagingConfig, spoofed)).toBeUndefined()
  })
})

describe("pagination", () => {
  it("round-trips an opaque cursor", () => {
    const encoded = encodeCursor("2026-11-09T00:00:00.000Z|id-1")
    expect(decodeCursor(encoded)).toBe("2026-11-09T00:00:00.000Z|id-1")
  })

  it("rejects a malformed cursor with a stable validation code", () => {
    expect(() => decodeCursor("not-a-cursor")).toThrow(ApiError)
    try {
      decodeCursor("not-a-cursor")
    } catch (error) {
      expect((error as ApiError).code).toBe("VALIDATION_FAILED")
    }
  })

  it("returns a bounded page and a cursor for the last returned row", () => {
    const rows = [{ id: "row-1" }, { id: "row-2" }, { id: "row-3" }]
    const page = toPage(rows, 2, (row) => row.id)
    expect(page.data).toEqual([{ id: "row-1" }, { id: "row-2" }])
    expect(page.page.hasMore).toBe(true)
    expect(decodeCursor(page.page.nextCursor!)).toBe("row-2")
  })

  it("returns no cursor when the page is the end of the collection", () => {
    const page = toPage([{ id: "row-1" }, { id: "row-2" }], 2, (row) => row.id)
    expect(page.page).toEqual({ hasMore: false, nextCursor: null })
  })
})

describe("idempotency primitives", () => {
  const key = "order-123:retry-0001"

  it("requires a well-formed Idempotency-Key header", () => {
    expect(() => requireIdempotencyKey(request())).toThrow(/required/i)
    expect(() =>
      requireIdempotencyKey(
        request({ headers: { [IDEMPOTENCY_HEADER]: "short" } }),
      ),
    ).toThrow(/invalid/i)
    expect(
      requireIdempotencyKey(
        request({ headers: { [IDEMPOTENCY_HEADER]: key } }),
      ),
    ).toBe(key)
  })

  it("fingerprints the request independently of object key order", () => {
    const first = requestFingerprint("POST", "/v1/orders", {
      amount: 10,
      currency: "NGN",
    })
    const second = requestFingerprint("POST", "/v1/orders", {
      currency: "NGN",
      amount: 10,
    })
    expect(first).toBe(second)
    expect(first).not.toBe(
      requestFingerprint("POST", "/v1/orders", {
        amount: 11,
        currency: "NGN",
      }),
    )
    expect(first).not.toBe(
      requestFingerprint("PUT", "/v1/orders", {
        amount: 10,
        currency: "NGN",
      }),
    )
  })
})
