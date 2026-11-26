import { describe, expect, it } from "vitest"

import { PaystackPayoutClient } from "../server/src/integrations/paystack"
import { PaymentProviderError } from "../server/src/integrations/payments/payment-provider"

const ACCOUNT_NUMBER = "0123456789"
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
  const client = new PaystackPayoutClient(options(overrides) as never, {
    fetchImpl: (async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init })
      return handler(String(url), init)
    }) as typeof fetch,
    sleep: async () => undefined,
    now: () => 1_700_000_000_000,
  })
  return { client, calls }
}

function payoutInput(overrides: Record<string, unknown> = {}) {
  return {
    reference: "payout-1",
    amount: "50.0000",
    currency: "NGN",
    bankCode: "058",
    accountNumber: ACCOUNT_NUMBER,
    accountName: "Kuti Sema",
    ...overrides,
  }
}

async function codeOf(promise: Promise<unknown>): Promise<string> {
  try {
    await promise
  } catch (error) {
    expect(error).toBeInstanceOf(PaymentProviderError)
    return (error as PaymentProviderError).code
  }
  throw new Error("expected the call to fail")
}

describe("Paystack payout adapter", () => {
  it("resolves an account name with the secret key", async () => {
    const { client, calls } = harness(async () =>
      jsonResponse({
        status: true,
        data: { account_number: ACCOUNT_NUMBER, account_name: "KUTI SEMA" },
      }),
    )

    const enquiry = await client.resolveAccountName({
      bankCode: "058",
      accountNumber: ACCOUNT_NUMBER,
    })

    expect(enquiry.accountName).toBe("KUTI SEMA")
    expect(enquiry.accountNumberLast4).toBe("6789")
    const url = new URL(calls[0]?.url ?? "")
    expect(url.pathname).toBe("/bank/resolve")
    expect(url.searchParams.get("account_number")).toBe(ACCOUNT_NUMBER)
    expect(url.searchParams.get("bank_code")).toBe("058")
    expect(
      (calls[0]?.init?.headers as Record<string, string>).authorization,
    ).toBe(`Bearer ${SECRET}`)
  })

  it("creates a recipient, sends kobo and maps a successful transfer", async () => {
    const { client, calls } = harness(async (url) => {
      if (url.includes("/transferrecipient")) {
        return jsonResponse({ status: true, data: { recipient_code: "RCP_1" } })
      }
      return jsonResponse({
        status: true,
        data: {
          transfer_code: "TRF_1",
          reference: "payout-1",
          status: "success",
        },
      })
    })

    const result = await client.initiatePayout(payoutInput(), {
      idempotencyKey: "key-1",
    })

    expect(result).toMatchObject({
      provider: "paystack",
      reference: "payout-1",
      providerReference: "TRF_1",
      status: "paid",
    })

    const recipient = JSON.parse(
      String(calls[0]?.init?.body),
    ) as Record<string, unknown>
    expect(recipient).toMatchObject({
      type: "nuban",
      account_number: ACCOUNT_NUMBER,
      bank_code: "058",
      currency: "NGN",
    })

    const transfer = JSON.parse(
      String(calls[1]?.init?.body),
    ) as Record<string, unknown>
    expect(transfer).toMatchObject({
      source: "balance",
      amount: 5000,
      recipient: "RCP_1",
      reference: "payout-1",
    })
  })

  it("maps a duplicate reference", async () => {
    const { client } = harness(async (url) => {
      if (url.includes("/transferrecipient")) {
        return jsonResponse({ status: true, data: { recipient_code: "RCP_1" } })
      }
      return jsonResponse(
        { status: false, message: "Duplicate transfer reference" },
        400,
      )
    })

    await expect(
      codeOf(client.initiatePayout(payoutInput(), { idempotencyKey: "key-1" })),
    ).resolves.toBe("PROVIDER_DUPLICATE")
  })

  it("maps a failed transfer result", async () => {
    const { client } = harness(async (url) => {
      if (url.includes("/transferrecipient")) {
        return jsonResponse({ status: true, data: { recipient_code: "RCP_1" } })
      }
      return jsonResponse({
        status: true,
        data: { transfer_code: "TRF_1", status: "failed" },
      })
    })

    const result = await client.initiatePayout(payoutInput(), {
      idempotencyKey: "key-1",
    })
    expect(result.status).toBe("failed")
    expect(result.failureCode).toBe("PAYSTACK_FAILED")
  })

  it("refuses a sub-kobo amount", async () => {
    const { client, calls } = harness(async () => jsonResponse({}))

    await expect(
      codeOf(
        client.initiatePayout(payoutInput({ amount: "1.0001" }), {
          idempotencyKey: "key-1",
        }),
      ),
    ).resolves.toBe("PROVIDER_INVALID_PAYLOAD")
    expect(calls).toHaveLength(0)
  })

  it("fails closed without a secret key", async () => {
    const { client, calls } = harness(async () => jsonResponse({}), {
      secretKey: undefined,
    })

    await expect(
      codeOf(
        client.resolveAccountName({
          bankCode: "058",
          accountNumber: ACCOUNT_NUMBER,
        }),
      ),
    ).resolves.toBe("PROVIDER_AUTH_FAILED")
    expect(calls).toHaveLength(0)
  })

  it("verifies a transfer status and normalises the amount", async () => {
    const { client } = harness(async () =>
      jsonResponse({
        status: true,
        data: {
          reference: "payout-1",
          transfer_code: "TRF_1",
          status: "success",
          amount: 5000,
          currency: "NGN",
          transferred_at: "2026-11-26T10:00:00.000Z",
        },
      }),
    )

    const status = await client.getPaymentStatus({
      providerReference: "TRF_1",
      reference: "payout-1",
    })

    expect(status).toMatchObject({
      provider: "paystack",
      reference: "payout-1",
      providerReference: "TRF_1",
      status: "paid",
      amount: "50.0000",
      currency: "NGN",
    })
  })
})
