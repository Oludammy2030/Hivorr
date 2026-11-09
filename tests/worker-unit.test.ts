import { describe, expect, it } from "vitest"

import { OutboxHandlers, retryDelayMs } from "../server/src/worker/outbox"

describe("outbox retry policy", () => {
  it("backs off exponentially and caps the delay", () => {
    expect(retryDelayMs(0, 1_000)).toBe(1_000)
    expect(retryDelayMs(1, 1_000)).toBe(2_000)
    expect(retryDelayMs(3, 1_000)).toBe(8_000)
    expect(retryDelayMs(30, 1_000)).toBe(60 * 60 * 1000)
    expect(retryDelayMs(0, 1_000, 5_000)).toBe(1_000)
    expect(retryDelayMs(10, 1_000, 5_000)).toBe(5_000)
  })
})

describe("outbox handler registry", () => {
  it("registers a handler per event type and rejects duplicates", () => {
    const handlers = new OutboxHandlers()
    handlers.register("identity.user_registered", async () => undefined)
    expect(handlers.get("identity.user_registered")).toBeTypeOf("function")
    expect(handlers.get("unknown.event")).toBeUndefined()
    expect(() =>
      handlers.register("identity.user_registered", async () => undefined),
    ).toThrow()
    expect(handlers.types()).toEqual(["identity.user_registered"])
  })

  it("rejects an empty event type", () => {
    expect(() =>
      new OutboxHandlers().register("  ", async () => undefined),
    ).toThrow()
  })
})
