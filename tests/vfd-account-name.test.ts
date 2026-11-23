import { describe, expect, it } from "vitest"

import {
  VfdAccountNameClient,
  type VfdAccountNameOptions,
} from "../server/src/integrations/vfd"
import {
  PaymentProviderError,
  isPaymentProviderError,
} from "../server/src/integrations/payments/payment-provider"

const ACCOUNT_NUMBER = "0123456789"

interface FetchCall {
  readonly url: string
  readonly init?: RequestInit
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  })
}

function options(
  overrides: Partial<VfdAccountNameOptions> = {},
): VfdAccountNameOptions {
  return {
    requestTimeoutMs: 1_000,
    maxRetries: 0,
    retryBaseMs: 10,
    ...overrides,
  }
}

function fakeAuth() {
  const calls = { invalidated: 0, tokens: 0 }
  return {
    calls,
    auth: {
      mode: "test" as const,
      async getToken() {
        calls.tokens += 1
        return "access-token"
      },
      invalidate() {
        calls.invalidated += 1
      },
    },
  }
}

function harness(
  handler: (url: string, init?: RequestInit) => Promise<Response>,
  overrides: Partial<VfdAccountNameOptions> = {},
) {
  const { auth, calls: authCalls } = fakeAuth()
  const calls: FetchCall[] = []
  const sleeps: number[] = []

  const client = new VfdAccountNameClient(auth as never, options(overrides), {
    fetchImpl: (async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init })
      return handler(String(url), init)
    }) as typeof fetch,
    sleep: async (milliseconds) => {
      sleeps.push(milliseconds)
    },
  })

  return { client, calls, sleeps, authCalls }
}

async function codeOf(promise: Promise<unknown>): Promise<string> {
  try {
    await promise
  } catch (error) {
    expect(isPaymentProviderError(error)).toBe(true)
    return (error as PaymentProviderError).code
  }
  throw new Error("expected the name enquiry to fail")
}

describe("VFD account-name enquiry", () => {
  it("calls the documented recipient endpoint with transfer_type=inter", async () => {
    const { client, calls } = harness(async () =>
      jsonResponse({
        status: "00",
        message: "Account Found",
        data: {
          name: "  Kuti Sema  ",
          account: { number: ACCOUNT_NUMBER },
          currency: "NGN",
        },
      }),
    )

    const result = await client.resolveAccountName({
      bankCode: "999",
      accountNumber: ACCOUNT_NUMBER,
    })

    expect(result).toEqual({
      accountName: "Kuti Sema",
      bankCode: "999",
      accountNumberLast4: "6789",
    })

    const url = new URL(calls[0]?.url ?? "")
    expect(url.pathname).toContain("/transfer/recipient")
    expect(url.searchParams.get("accountNo")).toBe(ACCOUNT_NUMBER)
    expect(url.searchParams.get("bank")).toBe("999")
    expect(url.searchParams.get("transfer_type")).toBe("inter")
    expect(
      (calls[0]?.init?.headers as Record<string, string>).AccessToken,
    ).toBe("access-token")
  })

  it("maps an account-not-found envelope without retrying", async () => {
    const { client, calls } = harness(async () =>
      jsonResponse({ status: "104", message: "Account Not Found" }),
    )

    await expect(
      codeOf(
        client.resolveAccountName({
          bankCode: "999",
          accountNumber: ACCOUNT_NUMBER,
        }),
      ),
    ).resolves.toBe("PROVIDER_NOT_FOUND")
    expect(calls).toHaveLength(1)
  })

  it("invalidates the token when the provider rejects it", async () => {
    const { client, authCalls } = harness(
      async () => jsonResponse({ status: "401" }, 401),
      { maxRetries: 2 },
    )

    await expect(
      codeOf(
        client.resolveAccountName({
          bankCode: "999",
          accountNumber: ACCOUNT_NUMBER,
        }),
      ),
    ).resolves.toBe("PROVIDER_AUTH_FAILED")
    expect(authCalls.invalidated).toBe(1)
  })

  it("retries an unavailable provider and then succeeds", async () => {
    let attempt = 0
    const { client, calls, sleeps } = harness(
      async () => {
        attempt += 1
        if (attempt === 1) return jsonResponse({ status: "500" }, 503)
        return jsonResponse({
          status: "00",
          data: { name: "Kuti Sema", account: { number: ACCOUNT_NUMBER } },
        })
      },
      { maxRetries: 2 },
    )

    const result = await client.resolveAccountName({
      bankCode: "999",
      accountNumber: ACCOUNT_NUMBER,
    })

    expect(result.accountName).toBe("Kuti Sema")
    expect(calls).toHaveLength(2)
    expect(sleeps).toHaveLength(1)
  })

  it("refuses a payload without a name", async () => {
    const { client } = harness(async () =>
      jsonResponse({ status: "00", data: {} }),
    )

    await expect(
      codeOf(
        client.resolveAccountName({
          bankCode: "999",
          accountNumber: ACCOUNT_NUMBER,
        }),
      ),
    ).resolves.toBe("PROVIDER_INVALID_PAYLOAD")
  })

  it("maps a timeout to a retryable provider timeout", async () => {
    const { client } = harness(
      async (_url, init) => {
        await new Promise((resolve, reject) => {
          const signal = init?.signal
          if (signal?.aborted) {
            reject(new Error("aborted"))
            return
          }
          signal?.addEventListener("abort", () => reject(new Error("aborted")))
          setTimeout(resolve, 5_000)
        })
        return jsonResponse({})
      },
      { requestTimeoutMs: 10 },
    )

    await expect(
      codeOf(
        client.resolveAccountName({
          bankCode: "999",
          accountNumber: ACCOUNT_NUMBER,
        }),
      ),
    ).resolves.toBe("PROVIDER_TIMEOUT")
  })

  it("rejects a malformed request before contacting the provider", async () => {
    const { client, calls } = harness(async () => jsonResponse({}))

    await expect(
      codeOf(
        client.resolveAccountName({
          bankCode: "99",
          accountNumber: "123",
        }),
      ),
    ).resolves.toBe("PROVIDER_INVALID_PAYLOAD")
    expect(calls).toHaveLength(0)
  })

  it("returns the recipient identifiers a transfer needs", async () => {
    const { client } = harness(async () =>
      jsonResponse({
        status: "00",
        data: {
          name: "Kuti Sema",
          clientId: "138421",
          bvn: "22887650012",
          bank: "VFD Microfinance Bank",
          account: { number: ACCOUNT_NUMBER, id: "155481" },
        },
      }),
    )

    const recipient = await client.enquireRecipient({
      bankCode: "999",
      accountNumber: ACCOUNT_NUMBER,
    })

    expect(recipient).toEqual({
      accountName: "Kuti Sema",
      bankCode: "999",
      accountNumberLast4: "6789",
      clientId: "138421",
      accountId: "155481",
      bvn: "22887650012",
      bankName: "VFD Microfinance Bank",
    })
  })

  it("resolves the documented source wallet profile", async () => {
    const { client, calls } = harness(async () =>
      jsonResponse({
        status: "00",
        message: "Account Details",
        data: {
          accountNo: ACCOUNT_NUMBER,
          accountId: "154779",
          client: "ANNA OGECHI ABEL",
          clientId: "5613",
          savingsProductName: "Corporate Current Account",
        },
      }),
    )

    const source = await client.enquireSource(ACCOUNT_NUMBER)

    expect(source).toEqual({
      accountNumber: ACCOUNT_NUMBER,
      clientId: "5613",
      clientName: "ANNA OGECHI ABEL",
      savingsId: "154779",
    })
    const url = new URL(calls[0]?.url ?? "")
    expect(url.pathname).toContain("/account/enquiry")
    expect(url.searchParams.get("accountNumber")).toBe(ACCOUNT_NUMBER)
  })

  it("refuses an incomplete source profile", async () => {
    const { client } = harness(async () =>
      jsonResponse({
        status: "00",
        data: { accountNo: ACCOUNT_NUMBER, clientId: "5613" },
      }),
    )

    await expect(codeOf(client.enquireSource(ACCOUNT_NUMBER))).resolves.toBe(
      "PROVIDER_INVALID_PAYLOAD",
    )
  })

  it("refuses a source response for a different account", async () => {
    const { client } = harness(async () =>
      jsonResponse({
        status: "00",
        data: {
          accountNo: "1000000002",
          accountId: "154779",
          client: "ANNA OGECHI ABEL",
          clientId: "5613",
        },
      }),
    )

    await expect(codeOf(client.enquireSource(ACCOUNT_NUMBER))).resolves.toBe(
      "PROVIDER_INVALID_PAYLOAD",
    )
  })
})
