import { describe, expect, it, vi } from "vitest"

import { ApiErrorFilter } from "../server/src/common/api-error.filter"
import { CaptureErrorTracker } from "../server/src/common/error-tracker"
import { ApiError, rateLimited } from "../server/src/common/errors"
import { createLogger } from "../server/src/common/logger"

function loggerWith(level: "debug" | "error" = "debug") {
  const lines: string[] = []
  const logger = createLogger({
    service: "hivorr-api",
    environment: "staging",
    level,
    sink: (line) => lines.push(line),
  })
  return { logger, lines }
}

function filterHarness() {
  const captured: unknown[] = []
  const logged: unknown[] = []
  const logger = {
    info: vi.fn(),
    warn: vi.fn(),
    error: (event: string, fields?: Record<string, unknown>) => {
      logged.push({ event, fields })
    },
    debug: vi.fn(),
  }
  const tracker = {
    capture: (error: unknown, context?: unknown) => {
      captured.push({ error, context })
    },
  }
  const filter = new ApiErrorFilter(logger as never, tracker as never)
  return { filter, captured, logged }
}

function hostFor(url = "/v1/secret?token=abc") {
  interface Sent {
    status?: number
    body?: unknown
    headers?: Record<string, string>
  }
  const sent: Sent = {}
  const reply = {
    headers(values: Record<string, string>) {
      sent.headers = values
      return reply
    },
    status(code: number) {
      sent.status = code
      return reply
    },
    send(body: unknown) {
      sent.body = body
      return reply
    },
  }
  const request = {
    correlationId: "correlation-1",
    method: "GET",
    url,
    headers: {},
  }
  const host = {
    switchToHttp: () => ({
      getResponse: () => reply,
      getRequest: () => request,
    }),
  } as unknown as never
  return { host, sent }
}

describe("structured logger", () => {
  it("writes one JSON line with service, environment, level and event", () => {
    const { logger, lines } = loggerWith()
    logger.info("http.request", { route: "/v1/session", statusCode: 200 })
    expect(lines).toHaveLength(1)
    expect(JSON.parse(lines[0]!)).toMatchObject({
      level: "info",
      service: "hivorr-api",
      environment: "staging",
      event: "http.request",
      route: "/v1/session",
      statusCode: 200,
    })
  })

  it("redacts credentials and personal data at every depth", () => {
    const { logger, lines } = loggerWith()
    logger.info("test.event", {
      email: "person@example.test",
      token: "secret-token",
      correlationId: "keep-me",
      nested: { password: "secret", phone: "+234000" },
    })
    const line = JSON.parse(lines[0]!)
    expect(line.email).toBe("[redacted]")
    expect(line.token).toBe("[redacted]")
    expect(line.correlationId).toBe("keep-me")
    expect(line.nested).toEqual({
      password: "[redacted]",
      phone: "[redacted]",
    })
    expect(lines[0]).not.toContain("secret-token")
    expect(lines[0]).not.toContain("person@example.test")
  })

  it("honours the configured level", () => {
    const { logger, lines } = loggerWith("error")
    logger.info("hidden")
    logger.error("shown")
    expect(lines).toHaveLength(1)
    expect(JSON.parse(lines[0]!).event).toBe("shown")
  })
})

describe("error tracker", () => {
  it("captures the raw error and correlation without serialising it", () => {
    const tracker = new CaptureErrorTracker()
    const error = new Error("provider exploded")
    tracker.capture(error, {
      correlationId: "correlation-1",
      method: "POST",
      route: "/v1/x",
      status: 500,
    })
    const captured = tracker.captured()
    expect(captured).toHaveLength(1)
    expect(captured[0]?.error).toBe(error)
    expect(captured[0]?.context).toEqual({
      correlationId: "correlation-1",
      method: "POST",
      route: "/v1/x",
      status: 500,
    })
  })
})

describe("error filter reporting", () => {
  it("captures and logs an unknown error with a correlation id", () => {
    const { filter, captured, logged } = filterHarness()
    const { host, sent } = hostFor()
    filter.catch(new Error("boom"), host)

    expect(sent.status).toBe(500)
    expect(sent.body).toMatchObject({
      error: { code: "INTERNAL_ERROR", correlationId: "correlation-1" },
    })
    expect(captured).toHaveLength(1)
    expect(captured[0]).toMatchObject({
      context: {
        correlationId: "correlation-1",
        route: "/v1/secret",
        status: 500,
      },
    })
    expect(logged[0]).toMatchObject({
      event: "http.unhandled_error",
      fields: { correlationId: "correlation-1", status: 500 },
    })
    expect(JSON.stringify(logged)).not.toContain("token=abc")
  })

  it("does not track a normal denial", () => {
    const { filter, captured } = filterHarness()
    const { host, sent } = hostFor()
    filter.catch(new ApiError("UNAUTHENTICATED", "Sign in.", 401), host)
    expect(sent.status).toBe(401)
    expect(captured).toHaveLength(0)
  })

  it("sets Retry-After on a rate-limit denial", () => {
    const { filter } = filterHarness()
    const { host, sent } = hostFor()
    filter.catch(rateLimited(42), host)
    expect(sent.status).toBe(429)
    expect(sent.headers).toMatchObject({ "retry-after": "42" })
  })
})
