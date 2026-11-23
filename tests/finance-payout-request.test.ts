import { describe, expect, it } from "vitest"

import { ApiError } from "../server/src/common/errors"
import { PayoutRequestService } from "../server/src/modules/finance/payout-request.service"

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111"
const USER_ID = "22222222-2222-4222-8222-222222222222"
const PAYOUT_ACCOUNT_ID = "33333333-3333-4333-8333-333333333333"
const REQUEST_ID = "44444444-4444-4444-8444-444444444444"
const REFERENCE = `PAY-${REQUEST_ID.replaceAll("-", "").slice(0, 20).toUpperCase()}`

const context = {
  audience: "main" as const,
  environment: "test" as const,
  correlationId: "corr-1",
}

interface Row {
  [key: string]: unknown
}

interface QueryCall {
  readonly text: string
  readonly values?: readonly unknown[]
}

function requestInput(overrides: Record<string, unknown> = {}) {
  return {
    accountId: ACCOUNT_ID,
    userId: USER_ID,
    tier: "tier_1",
    payoutAccountId: PAYOUT_ACCOUNT_ID,
    amount: "50.0000",
    currency: "NGN",
    idempotencyKey: "payout-key-1",
    context,
    ...overrides,
  }
}

function requestRow(overrides: Row = {}): Row {
  return {
    id: REQUEST_ID,
    reference: REFERENCE,
    payout_account_id: PAYOUT_ACCOUNT_ID,
    account_number_last4: "6789",
    amount: "50.0000",
    currency: "NGN",
    status: "REQUESTED",
    provider: null,
    provider_reference: null,
    failure_code: null,
    created_at: "2026-11-23T10:00:00.000Z",
    completed_at: null,
    ...overrides,
  }
}

function harness(
  options: {
    readonly existing?: Row | null
    readonly destination?: Row | null
    readonly available?: string
    readonly denyLimit?: boolean
    readonly listRows?: Row[]
    readonly hold?: string | null
  } = {},
) {
  const queries: QueryCall[] = []
  const audits: unknown[][] = []
  const limitChecks: unknown[] = []
  let insertValues: readonly unknown[] | undefined

  const existing = options.existing === undefined ? null : options.existing
  const destination =
    options.destination === undefined
      ? {
          id: PAYOUT_ACCOUNT_ID,
          status: "verified",
          account_number_last4: "6789",
        }
      : options.destination

  const transaction = {
    client: {
      async query(text: string, values?: readonly unknown[]) {
        if (text.includes("platform.audit_log")) {
          audits.push(values ? [...values] : [])
        }
        return { rows: [], rowCount: 1 }
      },
    },
    async query(text: string, values?: readonly unknown[]) {
      queries.push({ text, values })
      if (
        text.includes("select financial_hold_reason from identity.accounts")
      ) {
        return {
          rows: [{ financial_hold_reason: options.hold ?? null }],
        }
      }
      if (text.includes("from finance.payout_requests pr")) {
        if (text.includes("idempotency_key")) {
          return { rows: existing ? [existing] : [] }
        }
        return { rows: options.listRows ?? [] }
      }
      if (text.includes("from finance.payout_accounts")) {
        return { rows: destination ? [destination] : [] }
      }
      if (text.includes("from finance.wallet_balances")) {
        return { rows: [{ available: options.available ?? "100.0000" }] }
      }
      if (text.includes("platform.uuidv7()")) {
        return { rows: [{ id: REQUEST_ID }] }
      }
      if (text.includes("insert into finance.payout_requests")) {
        insertValues = values
        return { rows: [requestRow()] }
      }
      throw new Error(`unexpected query: ${text}`)
    },
  }

  const database = {
    async withTransaction(
      _options: unknown,
      work: (tx: unknown) => Promise<unknown>,
    ) {
      return work(transaction)
    },
  }

  const limits = {
    async assertWithin(_transaction: unknown, input: unknown) {
      limitChecks.push(input)
      if (options.denyLimit) {
        throw new ApiError(
          "LIMIT_EXCEEDED",
          "No payout limit is configured for this action.",
          403,
        )
      }
    },
  }

  const service = new PayoutRequestService(database as never, limits as never)

  return {
    service,
    queries,
    audits,
    limitChecks,
    get insertValues() {
      return insertValues
    },
  }
}

describe("payout request eligibility", () => {
  it("refuses a caller below tier_1 before any database work", async () => {
    const test = harness()

    await expect(
      test.service.request(requestInput({ tier: "tier_0" })),
    ).rejects.toMatchObject({ code: "KYC_REQUIRED", statusCode: 403 })
    expect(test.queries).toHaveLength(0)
    expect(test.limitChecks).toHaveLength(0)
  })

  it("refuses an invalid destination identifier", async () => {
    const test = harness()

    await expect(
      test.service.request(requestInput({ payoutAccountId: "not-a-uuid" })),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
    expect(test.queries).toHaveLength(0)
  })

  it("refuses a non-NGN payout", async () => {
    const test = harness()

    await expect(
      test.service.request(requestInput({ currency: "USD" })),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
  })

  it("refuses an invalid amount", async () => {
    const test = harness()

    await expect(
      test.service.request(requestInput({ amount: "0.0000" })),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
  })

  it("refuses a short idempotency key", async () => {
    const test = harness()

    await expect(
      test.service.request(requestInput({ idempotencyKey: "short" })),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
  })

  it("refuses while a KYC-upgrade hold is active", async () => {
    const test = harness({ hold: "kyc_upgrade_required" })

    await expect(test.service.request(requestInput())).rejects.toMatchObject({
      code: "KYC_REQUIRED",
      statusCode: 403,
    })
    expect(test.insertValues).toBeUndefined()
  })

  it("refuses an unbound destination", async () => {
    const test = harness({ destination: null })
    await expect(test.service.request(requestInput())).rejects.toMatchObject({
      code: "PAYOUT_ACCOUNT_REQUIRED",
      statusCode: 403,
    })
  })

  it("refuses an unverified destination", async () => {
    const test = harness({
      destination: {
        id: PAYOUT_ACCOUNT_ID,
        status: "pending",
        account_number_last4: "6789",
      },
    })

    await expect(test.service.request(requestInput())).rejects.toMatchObject({
      code: "PAYOUT_ACCOUNT_REQUIRED",
    })
  })

  it("propagates a denied payout limit", async () => {
    const test = harness({ denyLimit: true })

    await expect(test.service.request(requestInput())).rejects.toMatchObject({
      code: "LIMIT_EXCEEDED",
      statusCode: 403,
    })
    expect(test.insertValues).toBeUndefined()
  })

  it("refuses an amount above the available balance", async () => {
    const test = harness({ available: "49.9999" })

    await expect(test.service.request(requestInput())).rejects.toMatchObject({
      code: "INSUFFICIENT_FUNDS",
      statusCode: 409,
    })
    expect(test.insertValues).toBeUndefined()
  })

  it("creates a REQUESTED row after every check", async () => {
    const test = harness()
    const view = await test.service.request(requestInput())

    expect(view).toEqual({
      id: REQUEST_ID,
      reference: REFERENCE,
      payoutAccountId: PAYOUT_ACCOUNT_ID,
      accountNumberLast4: "6789",
      amount: "50.0000",
      currency: "NGN",
      status: "REQUESTED",
      provider: null,
      providerReference: null,
      failureCode: null,
      createdAt: "2026-11-23T10:00:00.000Z",
      completedAt: null,
    })

    expect(test.insertValues?.[4]).toBe("50.0000")
    expect(test.insertValues?.[6]).toBe("payout-key-1")
    expect(test.limitChecks).toHaveLength(1)
    expect(test.limitChecks[0]).toMatchObject({
      limitType: "withdrawal",
      direction: "out",
      amount: "50.0000",
    })

    expect(test.audits).toHaveLength(1)
    const audit = JSON.stringify(test.audits[0])
    expect(audit).toContain("finance.payout_requested")
    expect(audit).toContain("6789")
    expect(audit).not.toContain("0123456789")
  })

  it("replays the same idempotency key without a second request", async () => {
    const test = harness({ existing: requestRow() })
    const view = await test.service.request(requestInput())

    expect(view.id).toBe(REQUEST_ID)
    expect(test.insertValues).toBeUndefined()
    expect(test.audits).toHaveLength(0)
  })

  it("rejects a reused key that describes a different payout", async () => {
    const test = harness({ existing: requestRow() })

    await expect(
      test.service.request(requestInput({ amount: "51.0000" })),
    ).rejects.toMatchObject({ code: "CONFLICT", statusCode: 409 })
  })

  it("lists requests with only the last four digits", async () => {
    const test = harness({ listRows: [requestRow()] })

    const rows = await test.service.list({
      accountId: ACCOUNT_ID,
      userId: USER_ID,
    })

    expect(rows).toHaveLength(1)
    expect(rows[0]?.accountNumberLast4).toBe("6789")
    expect(JSON.stringify(rows)).not.toContain("ciphertext")
    expect(JSON.stringify(rows)).not.toContain("0123456789")
  })
})
