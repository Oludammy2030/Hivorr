import { describe, expect, it } from "vitest"

import {
  VFD_TOKEN_URLS,
  type VfdAuthOptions,
  VfdAuthClient,
} from "../server/src/integrations/vfd"

interface FetchCall {
  readonly url: string
  readonly init?: RequestInit
}

function envelope(token = "token-1", expiresIn: unknown = 1800) {
  return {
    status: "00",
    message: "Successful",
    data: {
      access_token: token,
      token_type: "Bearer",
      expires_in: expiresIn,
    },
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  })
}

function options(overrides: Partial<VfdAuthOptions> = {}): VfdAuthOptions {
  return {
    mode: "test",
    consumerKey: "test-key",
    consumerSecret: "test-secret",
    tokenValidityMinutes: 30,
    requestTimeoutMs: 1_000,
    maxRetries: 0,
    retryBaseMs: 10,
    ...overrides,
  }
}

function harness(
  handler: (url: string, init?: RequestInit) => Promise<Response>,
  overrides: Partial<VfdAuthOptions> = {},
) {
  let now = 1_000_000
  const calls: FetchCall[] = []
  const sleeps: number[] = []

  const client = new VfdAuthClient(options(overrides), {
    fetchImpl: (async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init })
      return handler(String(url), init)
    }) as typeof fetch,
    now: () => now,
    sleep: async (milliseconds) => {
      sleeps.push(milliseconds)
    },
  })

  return {
    client,
    calls,
    sleeps,
    advance: (milliseconds: number) => {
      now += milliseconds
    },
  }
}

describe("VFD authentication client", () => {
  it("requests a finite validity and caches the token", async () => {
    const { client, calls } = harness(async () => jsonResponse(envelope()))

    expect(await client.getToken()).toBe("token-1")
    expect(await client.getToken()).toBe("token-1")

    expect(calls).toHaveLength(1)
    expect(calls[0]?.url).toBe(VFD_TOKEN_URLS.test)
    const body = JSON.parse(
      String(calls[0]?.init?.body),
    ) as Record<string, string>
    expect(body).toEqual({
      consumerKey: "test-key",
      consumerSecret: "test-secret",
      validityTime: "30",
    })
    expect(body.validityTime).not.toBe("-1")
  })

  it("uses the live URL when the mode is live", async () => {
    const { client, calls } = harness(async () => jsonResponse(envelope()), {
      mode: "live",
    })

    await client.getToken()

    expect(calls[0]?.url).toBe(VFD_TOKEN_URLS.live)
  })

  it("refreshes shortly before expiry", async () => {
    let issued = 0
    const { client, calls, advance } = harness(async () => {
      issued += 1
      return jsonResponse(envelope(`token-${issued}`, 120))
    })

    expect(await client.getToken()).toBe("token-1")
    advance(30_000)
    expect(await client.getToken()).toBe("token-1")
    expect(calls).toHaveLength(1)

    advance(31_000)
    expect(await client.getToken()).toBe("token-2")
    expect(calls).toHaveLength(2)
  })

  it("shares one refresh between concurrent callers", async () => {
    let resolveResponse: ((response: Response) => void) | undefined
    const { client, calls } = harness(
      () =>
        new Promise<Response>((resolve) => {
          resolveResponse = resolve
        }),
    )

    const first = client.getToken()
    const second = client.getToken()
    await Promise.resolve()
    resolveResponse?.(jsonResponse(envelope()))

    await expect(Promise.all([first, second])).resolves.toEqual([
      "token-1",
      "token-1",
    ])
    expect(calls).toHaveLength(1)
  })

  it("refuses rejected credentials without retrying and without leaking them", async () => {
    const { client, calls, sleeps } = harness(async () =>
      jsonResponse({ status: "01", message: "invalid" }, 401),
    )

    const error = await client.getToken().catch((value) => value)

    expect(error).toMatchObject({
      code: "PROVIDER_AUTH_FAILED",
      retryable: false,
    })
    expect(String(error.message)).not.toContain("test-secret")
    expect(String(error.message)).not.toContain("test-key")
    expect(calls).toHaveLength(1)
    expect(sleeps).toHaveLength(0)
  })

  it("retries a temporary failure and then succeeds", async () => {
    let attempt = 0
    const { client, calls, sleeps } = harness(
      async () => {
        attempt += 1
        return attempt === 1
          ? jsonResponse({ status: "99" }, 503)
          : jsonResponse(envelope("token-2"))
      },
      { maxRetries: 1 },
    )

    expect(await client.getToken()).toBe("token-2")
    expect(calls).toHaveLength(2)
    expect(sleeps).toEqual([10])
  })

  it("maps a timeout after the retry budget", async () => {
    const { client, calls } = harness(
      (_url, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new Error("aborted")),
          )
        }),
      { requestTimeoutMs: 10, maxRetries: 1, retryBaseMs: 5 },
    )

    await expect(client.getToken()).rejects.toMatchObject({
      code: "PROVIDER_TIMEOUT",
      retryable: true,
    })
    expect(calls).toHaveLength(2)
  })

  it("rejects a malformed token response", async () => {
    const { client } = harness(
      async () => new Response("not json", { status: 200 }),
    )

    await expect(client.getToken()).rejects.toMatchObject({
      code: "PROVIDER_INVALID_PAYLOAD",
      retryable: false,
    })
  })

  it("rejects a non-success envelope without retrying", async () => {
    const { client, calls } = harness(async () =>
      jsonResponse({ status: "05", message: "declined" }),
    )

    await expect(client.getToken()).rejects.toMatchObject({
      code: "PROVIDER_AUTH_FAILED",
      retryable: false,
    })
    expect(calls).toHaveLength(1)
  })

  it("ignores a non-expiring expires_in and caches for the requested lifetime", async () => {
    let issued = 0
    const { client, calls, advance } = harness(async () => {
      issued += 1
      return jsonResponse(envelope(`token-${issued}`, Number.MAX_SAFE_INTEGER))
    })

    await client.getToken()
    advance(28 * 60 * 1_000)
    await client.getToken()
    expect(calls).toHaveLength(1)

    advance(2 * 60 * 1_000)
    await client.getToken()
    expect(calls).toHaveLength(2)
  })

  it("fails closed when credentials are absent", async () => {
    const { client, calls } = harness(async () => jsonResponse(envelope()), {
      consumerKey: undefined,
      consumerSecret: undefined,
    })

    await expect(client.getToken()).rejects.toMatchObject({
      code: "PROVIDER_AUTH_FAILED",
    })
    expect(calls).toHaveLength(0)
  })

  it("refreshes after invalidation", async () => {
    let issued = 0
    const { client, calls } = harness(async () => {
      issued += 1
      return jsonResponse(envelope(`token-${issued}`))
    })

    await client.getToken()
    client.invalidate()
    expect(await client.getToken()).toBe("token-2")
    expect(calls).toHaveLength(2)
  })
})
