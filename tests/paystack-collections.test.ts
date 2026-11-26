import { createHmac } from "node:crypto"

import { describe, expect, it } from "vitest"

import {
  PaystackCollectionsClient,
  verifyPaystackSignature,
} from "../server/src/integrations/paystack"

const SECRET = "sk_test_fake_paystack_key"

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  })
}

function options(overrides: Record<string, unknown> = {}) {
  return {
    baseUrl: "https://api.paystack.co",
    mode: "test" as const,
    secretKey: SECRET,
    preferredBank: "titan-paystack",
    requestTimeoutMs: 1_000,
    maxRetries: 0,
    retryBaseMs: 10,
    ...overrides,
  }
}

interface FetchCall {
  readonly url: string
  readonly init?: RequestInit
}

function harness(
  handler: (url: string, init?: RequestInit) => Promise<Response>,
  overrides: Record<string, unknown> = {},
) {
  const calls: FetchCall[] = []
  const client = new PaystackCollectionsClient(options(overrides) as never, {
    fetchImpl: (async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init })
      return handler(String(url), init)
    }) as typeof fetch,
    sleep: async () => undefined,
  })
  return { client, calls }
}

const event = {
  event: "charge.success",
  data: {
    reference: "dep-1",
    amount: 5000,
    currency: "NGN",
    status: "success",
    paid_at: "2026-11-26T10:00:00.000Z",
    customer: { email: "user@example.com", customer_code: "CUS_1" },
    authorization: {
      sender_name: "KUTI SEMA",
      sender_bank_account_number: "0123456789",
      receiver_bank_account_number: "1234567890",
    },
    dedicated_account: { account_number: "1234567890" },
  },
}

describe("Paystack collections adapter", () => {
  it("creates a customer and a dedicated virtual account", async () => {
    const { client, calls } = harness(async (url) => {
      if (url.endsWith("/customer")) {
        return jsonResponse({ status: true, data: { customer_code: "CUS_1" } })
      }
      return jsonResponse({
        status: true,
        data: {
          account_number: "1234567890",
          account_name: "Hivorr / Kuti Sema",
          bank: { name: "Titan Trust Bank" },
        },
      })
    })

    const account = await client.provisionCollectionAccount(
      {
        reference: "COL-1",
        accountName: "Kuti Sema",
        email: "user@example.com",
        currency: "NGN",
      },
      { idempotencyKey: "collection-1" },
    )

    expect(account).toMatchObject({
      provider: "paystack",
      reference: "COL-1",
      accountNumber: "1234567890",
      bankName: "Titan Trust Bank",
      status: "active",
    })
    expect(calls).toHaveLength(2)
    expect(calls[1]?.url).toContain("/dedicated_account")
  })

  it("normalises a charge into a neutral deposit event", () => {
    const { client } = harness(async () => jsonResponse({}))
    const deposit = client.normaliseDepositEvent(event)

    expect(deposit).toMatchObject({
      provider: "paystack",
      reference: "dep-1",
      collectionAccountReference: "1234567890",
      amount: "50.0000",
      currency: "NGN",
      payerName: "KUTI SEMA",
      payerAccountLast4: "6789",
      status: "received",
    })
  })

  it("verifies a transaction with Paystack", async () => {
    const { client, calls } = harness(async () => jsonResponse({ status: true, data: event.data }))

    const deposit = await client.verifyTransaction("dep-1")
    expect(deposit.amount).toBe("50.0000")
    expect(calls[0]?.url).toContain("/transaction/verify/dep-1")
  })

  it("verifies the webhook signature and rejects a mismatch", () => {
    const body = Buffer.from(JSON.stringify(event))
    const signature = createHmac("sha512", SECRET).update(body).digest("hex")

    expect(verifyPaystackSignature(body, signature, SECRET)).toBe(true)
    expect(verifyPaystackSignature(body, "00", SECRET)).toBe(false)
    expect(verifyPaystackSignature(body, signature, "other")).toBe(false)
  })

  it("fails closed without a secret key", async () => {
    const { client, calls } = harness(async () => jsonResponse({}), {
      secretKey: undefined,
    })

    await expect(
      client.provisionCollectionAccount(
        {
          reference: "COL-1",
          accountName: "Kuti Sema",
          email: "user@example.com",
          currency: "NGN",
        },
        { idempotencyKey: "collection-1" },
      ),
    ).rejects.toMatchObject({ code: "PROVIDER_AUTH_FAILED" })
    expect(calls).toHaveLength(0)
  })
})
