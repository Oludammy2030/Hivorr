import { describe, expect, it } from "vitest"

import { FixedWindowRateLimiter } from "../server/src/common/rate-limiter"

describe("fixed-window rate limiter", () => {
  it("allows up to the limit and denies the next attempt", () => {
    const limiter = new FixedWindowRateLimiter()
    const options = { windowMs: 60_000, max: 3 }
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      expect(limiter.check("key", options, 1_000).allowed).toBe(true)
    }
    const denied = limiter.check("key", options, 1_000)
    expect(denied.allowed).toBe(false)
    expect(denied.retryAfterSeconds).toBe(60)
  })

  it("starts a fresh window after expiry", () => {
    const limiter = new FixedWindowRateLimiter()
    const options = { windowMs: 1_000, max: 1 }
    expect(limiter.check("key", options, 0).allowed).toBe(true)
    expect(limiter.check("key", options, 500).allowed).toBe(false)
    expect(limiter.check("key", options, 1_001).allowed).toBe(true)
  })

  it("keeps identifiers and IPs in separate buckets", () => {
    const limiter = new FixedWindowRateLimiter()
    const options = { windowMs: 60_000, max: 1 }
    expect(limiter.check("id:person@example.test", options, 0).allowed).toBe(
      true,
    )
    expect(limiter.check("ip:203.0.113.1", options, 0).allowed).toBe(true)
    expect(limiter.check("id:person@example.test", options, 1).allowed).toBe(
      false,
    )
  })

  it("resets all buckets", () => {
    const limiter = new FixedWindowRateLimiter()
    const options = { windowMs: 60_000, max: 1 }
    limiter.check("key", options, 0)
    limiter.reset()
    expect(limiter.check("key", options, 1).allowed).toBe(true)
  })
})
