import { createHash } from "node:crypto"

import { describe, expect, it } from "vitest"

import { PaymentProviderError } from "../server/src/integrations/payments/payment-provider"
import {
  VfdPayoutClient,
  VfdSha512TransferSigner,
  type VfdPayoutOptions,
  type VfdRecipientDetails,
  type VfdSourceDetails,
  type VfdTransferSigner,
} from "../server/src/integrations/vfd"

const ACCOUNT_NUMBER = "0123456789"
const REFERENCE = "payout-1"
const SOURCE_ACCOUNT_NUMBER = "1000000001"

const SOURCE: VfdSourceDetails = {
  accountNumber: SOURCE_ACCOUNT_NUMBER,
  clientId: "client-source",
  clientName: "Hivorr Wallet",
  savingsId: "savings-source",
}

const RECIPIENT: VfdRecipientDetails = {
  accountName: "Kuti Sema",
  bankCode: "999",
  accountNumberLast4: "6789",
  clientId: "client-recipient",
  accountId: "account-recipient",
  bvn: "22222222222",
  bankName: "Example Bank",
}

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

function payoutInput(overrides: Record<string, unknown> = {}) {
  return {
    reference: REFERENCE,
    amount: "50.0000",
    currency: "NGN",
    bankCode: "999",
    accountNumber: ACCOUNT_NUMBER,
    accountName: "Kuti Sema",
    ...overrides,
  }
}

function harness(
  options: {
    readonly recipient?: Partial<VfdRecipientDetails>
    readonly sourceAccountNumber?: string | null
    readonly signer?: VfdTransferSigner
    readonly maxRetries?: number
    readonly requestTimeoutMs?: number
    readonly now?: number
    readonly handler?: (url: string) => Promise<Response>
  } = {},
) {
  const calls: FetchCall[] = []
  const sleeps: number[] = []
  const authCalls = { tokens: 0, invalidated: 0 }

  const auth = {
    mode: "test" as const,
    async getToken() {
      authCalls.tokens += 1
      return "access-token"
    },
    invalidate() {
      authCalls.invalidated += 1
    },
  }

  const recipient = { ...RECIPIENT, ...options.recipient }
  let recipientCalls = 0
  let sourceCalls = 0
  const accountNames = {
    async resolveAccountName() {
      recipientCalls += 1
      return {
        accountName: recipient.accountName,
        bankCode: recipient.bankCode,
        accountNumberLast4: recipient.accountNumberLast4,
      }
    },
    async enquireRecipient() {
      recipientCalls += 1
      return recipient
    },
    async enquireSource() {
      sourceCalls += 1
      return SOURCE
    },
  }

  const payoutOptions: VfdPayoutOptions = {
    requestTimeoutMs: options.requestTimeoutMs ?? 1_000,
    maxRetries: options.maxRetries ?? 0,
    retryBaseMs: 10,
    ...(options.sourceAccountNumber === null
      ? {}
      : {
          sourceAccountNumber: options.sourceAccountNumber ?? SOURCE_ACCOUNT_NUMBER,
        }),
    ...(options.signer ? { signer: options.signer } : {}),
  }

  const handler = options
  const client = new VfdPayoutClient(auth as never, accountNames as never, payoutOptions, {
    fetchImpl: (async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init })
      return handler.handler
        ? handler.handler(String(url))
        : jsonResponse({ status: "00", data: { txnId: "TX-1" } })
    }) as typeof fetch,
    sleep: async (milliseconds) => {
      sleeps.push(milliseconds)
    },
    now: () => options.now ?? 1_700_000_000_000,
  })

  return {
    client,
    calls,
    sleeps,
    authCalls,
    get recipientCalls() {
      return recipientCalls
    },
    get sourceCalls() {
      return sourceCalls
    },
  }
}

describe("VFD payout adapter", () => {
  it("sends the documented single-transfer payload", async () => {
    const test = harness()
    const result = await test.client.initiatePayout(payoutInput(), {
      idempotencyKey: "key-1",
    })

    expect(result).toMatchObject({
      provider: "vfd",
      reference: REFERENCE,
      providerReference: "TX-1",
      status: "pending",
      failureCode: null,
    })

    const body = JSON.parse(String(test.calls[0]?.init?.body)) as Record<string, unknown>
    expect(test.calls[0]?.url).toContain("/transfer")
    expect(body).toMatchObject({
      fromAccount: SOURCE.accountNumber,
      fromClientId: SOURCE.clientId,
      fromClient: SOURCE.clientName,
      fromSavingsId: SOURCE.savingsId,
      toClientId: RECIPIENT.clientId,
      toClient: RECIPIENT.accountName,
      toSession: RECIPIENT.accountId,
      toAccount: ACCOUNT_NUMBER,
      toBank: "999",
      signature: createHash("sha512")
        .update(`${SOURCE.accountNumber}${ACCOUNT_NUMBER}`, "utf8")
        .digest("hex"),
      amount: "50.0000",
      transferType: "inter",
      reference: REFERENCE,
    })
    expect(body).not.toHaveProperty("toSavingsId", RECIPIENT.accountId)
    expect(body).not.toHaveProperty("fromBvn")
    expect(test.sourceCalls).toBe(1)
    expect(JSON.stringify(result)).not.toContain(ACCOUNT_NUMBER)
  })

  it("uses the signature published in the vendor sample", () => {
    const signer = new VfdSha512TransferSigner()
    expect(
      signer.sign({
        fromAccount: "1001561522",
        toAccount: "1001561539",
        reference: "TestWallet-fhehfhgdrtrewe",
        amount: "1006765",
      }),
    ).toBe(
      "899358f98ae041aa7471bdc03797b1f64c6f96a542955023849d2dbddb1cf7318d8599e9692b1345b8383288dc8550ed70f1de6aa2ea6a149f48d515c9e6eb1e",
    )
  })

  it("replays the same idempotency key without a second transfer", async () => {
    const test = harness()
    const first = await test.client.initiatePayout(payoutInput(), {
      idempotencyKey: "key-1",
    })
    const replay = await test.client.initiatePayout(payoutInput(), {
      idempotencyKey: "key-1",
    })

    expect(replay).toEqual(first)
    expect(test.calls).toHaveLength(1)
  })

  it("rejects a reused key that describes a different payout", async () => {
    const test = harness()
    await test.client.initiatePayout(payoutInput(), { idempotencyKey: "key-1" })

    await expect(
      test.client.initiatePayout(payoutInput({ amount: "51.0000" }), {
        idempotencyKey: "key-1",
      }),
    ).rejects.toMatchObject({ code: "PROVIDER_DUPLICATE" })
    expect(test.calls).toHaveLength(1)
  })

  it("maps the vendor duplicate-reference code", async () => {
    const test = harness({
      handler: async () => jsonResponse({ status: "98", message: "Transaction Exist" }),
    })

    await expect(
      test.client.initiatePayout(payoutInput(), { idempotencyKey: "key-1" }),
    ).rejects.toMatchObject({ code: "PROVIDER_DUPLICATE" })
  })

  it("returns a mapped failed result without throwing", async () => {
    const test = harness({
      handler: async () => jsonResponse({ status: "99", message: "Failed Transaction" }),
    })

    const result = await test.client.initiatePayout(payoutInput(), {
      idempotencyKey: "key-1",
    })

    expect(result).toMatchObject({
      status: "failed",
      failureCode: "VFD_99",
    })
    expect(result.providerReference).toBe(REFERENCE)
  })

  it("maps a pending transfer code to processing", async () => {
    const test = harness({
      handler: async () =>
        jsonResponse({
          status: "09",
          message: "Request Processing in Progress",
        }),
    })

    const result = await test.client.initiatePayout(payoutInput(), {
      idempotencyKey: "key-1",
    })
    expect(result.status).toBe("processing")
    expect(result.failureCode).toBeNull()
  })

  it("refuses a signature mismatch", async () => {
    const test = harness({
      handler: async () => jsonResponse({ status: "02", message: "Signature Mismatch" }),
    })

    await expect(
      test.client.initiatePayout(payoutInput(), { idempotencyKey: "key-1" }),
    ).rejects.toMatchObject({ code: "PROVIDER_AUTH_FAILED" })
  })

  it("fails closed when the source wallet is not configured", async () => {
    const test = harness({ sourceAccountNumber: null })

    await expect(
      test.client.initiatePayout(payoutInput(), { idempotencyKey: "key-1" }),
    ).rejects.toMatchObject({ code: "PROVIDER_AUTH_FAILED" })
    expect(test.calls).toHaveLength(0)
    expect(test.recipientCalls).toBe(0)
  })

  it("refuses a non-NGN payout", async () => {
    const test = harness()

    await expect(
      test.client.initiatePayout(payoutInput({ currency: "USD" }), {
        idempotencyKey: "key-1",
      }),
    ).rejects.toMatchObject({ code: "PROVIDER_INVALID_PAYLOAD" })
    expect(test.calls).toHaveLength(0)
  })

  it("refuses a recipient without the identifiers a transfer needs", async () => {
    const test = harness({ recipient: { clientId: null } })

    await expect(
      test.client.initiatePayout(payoutInput(), { idempotencyKey: "key-1" }),
    ).rejects.toMatchObject({ code: "PROVIDER_INVALID_PAYLOAD" })
    expect(test.calls).toHaveLength(0)
  })

  it("invalidates the token when VFD rejects it", async () => {
    const test = harness({
      handler: async () => jsonResponse({ status: "401" }, 401),
      maxRetries: 2,
    })

    await expect(
      test.client.initiatePayout(payoutInput(), { idempotencyKey: "key-1" }),
    ).rejects.toMatchObject({ code: "PROVIDER_AUTH_FAILED" })
    expect(test.authCalls.invalidated).toBe(1)
  })

  it("retries an unavailable provider and then succeeds", async () => {
    let attempt = 0
    const test = harness({
      maxRetries: 2,
      handler: async () => {
        attempt += 1
        if (attempt === 1) return jsonResponse({ status: "500" }, 503)
        return jsonResponse({ status: "00", data: { txnId: "TX-2" } })
      },
    })

    const result = await test.client.initiatePayout(payoutInput(), {
      idempotencyKey: "key-1",
    })
    expect(result.providerReference).toBe("TX-2")
    expect(test.calls).toHaveLength(2)
    expect(test.sleeps).toHaveLength(1)
  })
})

describe("VFD payout status query", () => {
  it("maps a completed transaction and normalises its amount", async () => {
    const test = harness({
      handler: async () =>
        jsonResponse({
          status: "00",
          data: {
            TxnId: "TX-1",
            amount: "500000.00",
            transactionStatus: "00",
            transactionDate: "2023-01-11 08:05:25.0",
          },
        }),
    })

    const status = await test.client.getPaymentStatus({
      providerReference: "TX-1",
      reference: REFERENCE,
    })

    expect(status).toMatchObject({
      provider: "vfd",
      reference: REFERENCE,
      providerReference: "TX-1",
      status: "paid",
      amount: "500000.0000",
      currency: "NGN",
    })
    expect(status.occurredAt).toBe("2023-01-11T08:05:25.000Z")

    const url = new URL(test.calls[0]?.url ?? "")
    expect(url.pathname).toContain("/transactions")
    expect(url.searchParams.get("reference")).toBe(REFERENCE)
  })

  it("maps a failed transaction status", async () => {
    const test = harness({
      handler: async () =>
        jsonResponse({
          status: "00",
          data: {
            TxnId: "TX-1",
            amount: "50.00",
            transactionStatus: "99",
            transactionDate: "2023-01-11 08:05:25.0",
          },
        }),
    })

    const status = await test.client.getPaymentStatus({
      providerReference: "TX-1",
    })
    expect(status.status).toBe("failed")
  })

  it("reports an unknown reference as not found", async () => {
    const test = harness({
      handler: async () => jsonResponse({ status: "108", message: "No Transaction!" }),
    })

    await expect(
      test.client.getPaymentStatus({ providerReference: "missing" }),
    ).rejects.toMatchObject({ code: "PROVIDER_NOT_FOUND" })
  })

  it("refuses a status response without a status code", async () => {
    const test = harness({
      handler: async () =>
        jsonResponse({
          status: "00",
          data: { TxnId: "TX-1", amount: "50.00" },
        }),
    })

    await expect(
      test.client.getPaymentStatus({ providerReference: "TX-1" }),
    ).rejects.toBeInstanceOf(PaymentProviderError)
  })

  it("delegates the account-name enquiry without returning a full number", async () => {
    const test = harness()
    const enquiry = await test.client.resolveAccountName({
      bankCode: "999",
      accountNumber: ACCOUNT_NUMBER,
    })

    expect(enquiry.accountName).toBe(RECIPIENT.accountName)
    expect(enquiry.accountNumberLast4).toBe("6789")
    expect(JSON.stringify(enquiry)).not.toContain(ACCOUNT_NUMBER)
    expect(test.calls).toHaveLength(0)
  })
})
