import { describe, expect, it } from "vitest"

import { CaptureErrorTracker } from "../server/src/common/error-tracker"
import {
  SentryErrorTracker,
  createErrorTracker,
  parseSentryDsn,
  scrubSentryText,
  type SentryTransportRequest,
} from "../server/src/common/sentry-error-tracker"

const dsn = "https://0123456789abcdef0123456789abcdef@o1.ingest.sentry.io/42"

function recordingTransport(): {
  requests: SentryTransportRequest[]
  transport: (request: SentryTransportRequest) => Promise<unknown>
} {
  const requests: SentryTransportRequest[] = []
  return {
    requests,
    transport: async (request) => {
      requests.push(request)
      return {}
    },
  }
}

function eventOf(body: string): Record<string, unknown> {
  const lines = body.trim().split("\n")
  return JSON.parse(lines[2] ?? "{}") as Record<string, unknown>
}

interface SentryExceptionValue {
  type: string
  value: string
}

interface SentryEventException {
  exception: {
    values: SentryExceptionValue[]
  }
}

describe("sentry dsn", () => {
  it("builds the envelope endpoint and auth header", () => {
    const envelope = parseSentryDsn(dsn)
    expect(envelope).toEqual({
      url: "https://o1.ingest.sentry.io/api/42/envelope/",
      auth: expect.stringContaining("sentry_key=0123456789abcdef0123456789abcdef"),
    })
  })

  it("rejects anything that is not a Sentry DSN", () => {
    expect(parseSentryDsn("https://example.com/42")).toBeUndefined()
    expect(parseSentryDsn("http://key@o1.ingest.sentry.io/42")).toBeUndefined()
    expect(parseSentryDsn("")).toBeUndefined()
  })
})

describe("scrubbing", () => {
  it("removes addresses, credentialed urls and secret assignments", () => {
    const scrubbed = scrubSentryText(
      "user ana@example.com failed with postgresql://user:pw@db.internal:5432/app password=hunter2",
    )

    expect(scrubbed).not.toContain("ana@example.com")
    expect(scrubbed).not.toContain("pw@db.internal")
    expect(scrubbed).not.toContain("hunter2")
    expect(scrubbed).toContain("[redacted-email]")
    expect(scrubbed).toContain("[redacted-url]")
  })
})

describe("error tracker selection", () => {
  it("stays capture-only without a dsn", () => {
    expect(createErrorTracker({ environment: "staging" })).toBeInstanceOf(CaptureErrorTracker)
  })

  it("stays capture-only for an invalid dsn rather than crashing the boot", () => {
    expect(createErrorTracker({ environment: "production", dsn: "not-a-dsn" })).toBeInstanceOf(
      CaptureErrorTracker,
    )
  })

  it("returns the sentry sink for a valid dsn", () => {
    expect(createErrorTracker({ environment: "production", dsn })).toBeInstanceOf(
      SentryErrorTracker,
    )
  })
})

describe("sentry envelope", () => {
  it("posts a report carrying context but no request body", async () => {
    const { requests, transport } = recordingTransport()
    const tracker = new SentryErrorTracker({
      dsn,
      environment: "production",
      release: "sha-abc",
      transport,
      now: () => new Date("2026-11-15T10:00:00.000Z"),
    })

    tracker.capture(new Error("user_directory_forbidden"), {
      correlationId: "corr-1",
      method: "GET",
      route: "/v1/control/users",
      status: 403,
    })
    await tracker.flush()

    expect(requests).toHaveLength(1)
    const request = requests[0]!
    expect(request.url).toBe("https://o1.ingest.sentry.io/api/42/envelope/")
    expect(request.headers["x-sentry-auth"]).toContain("sentry_key=")

    const event = eventOf(request.body)
    expect(event.environment).toBe("production")
    expect(event.release).toBe("sha-abc")
    expect(event.transaction).toBe("/v1/control/users")
    expect(event.tags).toMatchObject({
      method: "GET",
      status: "403",
      correlationId: "corr-1",
    })
    expect(request.body).not.toContain("payload")
    expect(request.body).not.toContain("password")
    expect(event.exception).toBeDefined()
  })

  it("scrubs a message before it leaves the process", async () => {
    const { requests, transport } = recordingTransport()
    const tracker = new SentryErrorTracker({
      dsn,
      environment: "production",
      transport,
    })

    tracker.capture(new Error("failed for ana@example.com"), {})
    await tracker.flush()

    expect(requests[0]!.body).not.toContain("ana@example.com")
    const event = eventOf(requests[0]!.body) as SentryEventException
    expect(event.exception.values[0]!.value).toContain("[redacted-email]")
  })

  it("never throws or rejects when the transport fails", async () => {
    const tracker = new SentryErrorTracker({
      dsn,
      environment: "production",
      transport: async () => {
        throw new Error("network down")
      },
    })

    expect(() => tracker.capture(new Error("boom"), {})).not.toThrow()
    await expect(tracker.flush()).resolves.toBeUndefined()
  })

  it("accepts a non-error value without losing the event", async () => {
    const { requests, transport } = recordingTransport()
    const tracker = new SentryErrorTracker({
      dsn,
      environment: "production",
      transport,
    })

    tracker.capture("something odd", {})
    await tracker.flush()

    const event = eventOf(requests[0]!.body) as SentryEventException
    expect(event.exception.values[0]!.value).toContain("something odd")
  })
})
