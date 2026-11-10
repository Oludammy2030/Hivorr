import { describe, expect, it } from "vitest"

import {
  ApiClientError,
  createHivorrClient,
} from "../packages/api-client/src/index"

interface CapturedCall {
  readonly url: string
  readonly init: RequestInit | undefined
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  })
}

function harness(response: Response | (() => Response)) {
  const calls: CapturedCall[] = []
  const fetchImpl = (async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ url: String(input), init })
    return typeof response === "function" ? response() : response
  }) as typeof fetch
  const client = createHivorrClient({
    baseUrl: "https://api.test/",
    fetch: fetchImpl,
  })
  return { client, calls }
}

describe("generated API client", () => {
  it("calls the health endpoint with cookie credentials", async () => {
    const { client, calls } = harness(
      jsonResponse({
        status: "ok",
        service: "hivorr-api",
        version: "v1",
        environment: "staging",
        time: "2026-11-09T00:00:00.000Z",
      }),
    )

    const health = await client.health()
    expect(health.status).toBe("ok")
    expect(calls).toHaveLength(1)
    expect(calls[0]?.url).toBe("https://api.test/v1/health")
    expect(calls[0]?.init?.method).toBe("GET")
    expect(calls[0]?.init?.credentials).toBe("include")
  })

  it("sends a JSON body for a mutation", async () => {
    const { client, calls } = harness(
      jsonResponse({ accountId: "a", userId: "u", email: "a@b.test" }, 201),
    )

    await client.register({
      email: "a@b.test",
      password: "correct-horse-battery",
    })

    const init = calls[0]?.init
    expect(init?.method).toBe("POST")
    expect(init?.headers).toMatchObject({ "content-type": "application/json" })
    expect(JSON.parse(String(init?.body))).toEqual({
      email: "a@b.test",
      password: "correct-horse-battery",
    })
  })

  it("encodes a path parameter", async () => {
    const { client, calls } = harness(new Response(null, { status: 204 }))
    await client.revokeSession({ id: "a b/c" })
    expect(calls[0]?.url).toBe("https://api.test/v1/auth/sessions/a%20b%2Fc")
  })

  it("throws the stable error envelope as ApiClientError", async () => {
    const { client } = harness(
      jsonResponse(
        {
          error: {
            code: "FORBIDDEN",
            message: "Denied.",
            correlationId: "correlation-1",
          },
        },
        403,
      ),
    )

    let caught: unknown
    try {
      await client.listGrants()
    } catch (error) {
      caught = error
    }

    expect(caught).toBeInstanceOf(ApiClientError)
    expect(caught).toMatchObject({
      status: 403,
      code: "FORBIDDEN",
      correlationId: "correlation-1",
      message: "Denied.",
    })
  })

  it("returns an expected non-2xx readiness body instead of throwing", async () => {
    const { client } = harness(
      jsonResponse(
        {
          status: "not_ready",
          service: "hivorr-api",
          checks: {
            configuration: "ok",
            database: "not_implemented",
          },
        },
        503,
      ),
    )

    const readiness = await client.healthReady()
    expect(readiness.status).toBe("not_ready")
  })
})
