import { describe, expect, it } from "vitest"

import { parseConfig } from "../server/src/config"
import { PaymentProviderError } from "../server/src/integrations/payments/payment-provider"
import { PayoutAccountCipher } from "../server/src/modules/finance/payout-account-crypto"
import { PayoutExecutionService } from "../server/src/modules/finance/payout-execution.service"

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111"
const USER_ID = "22222222-2222-4222-8222-222222222222"
const PAYOUT_ACCOUNT_ID = "33333333-3333-4333-8333-333333333333"
const REQUEST_ID = "44444444-4444-4444-8444-444444444444"
const REFERENCE = "PAY-44444444444444444444"
const ENCRYPTION_KEY = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
const FINGERPRINT_KEY = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="
const ACCOUNT_NUMBER = "0123456789"

const context = {
  audience: "main" as const,
  environment: "test" as const,
  correlationId: "corr-1",
}

const cipher = PayoutAccountCipher.fromConfig({
  encryptionKey: ENCRYPTION_KEY,
  encryptionKeyId: "v1",
  fingerprintKey: FINGERPRINT_KEY,
})
const ENCRYPTED = cipher.encrypt(ACCOUNT_NUMBER)

function apiConfig(overrides: Record<string, string> = {}) {
  return parseConfig({
    HIVORR_ENV: "test",
    PAYOUT_ENCRYPTION_KEY: ENCRYPTION_KEY,
    PAYOUT_FINGERPRINT_KEY: FINGERPRINT_KEY,
    PAYOUT_ACCOUNT_MAX_ACTIVE: "2",
    ...overrides,
  })
}

interface Row {
  [key: string]: unknown
}

interface LedgerCall {
  readonly kind: string
  readonly reversesEntryId?: string | null
}

interface ProviderCall {
  readonly input: unknown
  readonly context: unknown
}

function requestRow(overrides: Row = {}): Row {
  return {
    id: REQUEST_ID,
    reference: REFERENCE,
    account_id: ACCOUNT_ID,
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
    journal_entry_id: null,
    ...overrides,
  }
}

function destinationRow(overrides: Row = {}): Row {
  return {
    id: PAYOUT_ACCOUNT_ID,
    status: "verified",
    bank_code: "999",
    account_name: "Kuti Sema",
    account_number_ciphertext: ENCRYPTED.ciphertext,
    encryption_key_id: ENCRYPTED.keyId,
    account_number_last4: "6789",
    ...overrides,
  }
}

function successResult(overrides: Row = {}): Row {
  return {
    provider: "fake",
    reference: REFERENCE,
    providerReference: "FP-1",
    status: "paid",
    failureCode: null,
    failureMessage: null,
    occurredAt: "2026-11-23T10:00:00.000Z",
    ...overrides,
  }
}

function harness(
  options: {
    readonly initialStatus?: string
    readonly initialJournalEntryId?: string | null
    readonly destination?: Row | null
    readonly available?: string
    readonly denyLimit?: boolean
    readonly providerResult?: Row
    readonly providerError?: Error
    readonly apiConfig?: ReturnType<typeof apiConfig>
  } = {},
) {
  const state = {
    status: options.initialStatus ?? "REQUESTED",
    journalEntryId:
      options.initialJournalEntryId === undefined
        ? options.initialStatus === "RESERVED"
          ? "entry-1"
          : null
        : options.initialJournalEntryId,
  }
  const audits: unknown[][] = []
  const ledgerCalls: LedgerCall[] = []
  const providerCalls: ProviderCall[] = []
  const limitChecks: unknown[] = []

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
      if (text.includes("from finance.payout_requests pr")) {
        return {
          rows: [
            requestRow({
              status: state.status,
              journal_entry_id: state.journalEntryId,
              provider: state.status === "PROCESSING" ? "fake" : null,
            }),
          ],
        }
      }
      if (text.includes("from finance.payout_accounts")) {
        const destination =
          options.destination === undefined
            ? destinationRow()
            : options.destination
        return { rows: destination ? [destination] : [] }
      }
      if (text.includes("from finance.wallet_balances")) {
        return { rows: [{ available: options.available ?? "100.0000" }] }
      }
      if (text.includes("finance.ensure_ledger_account")) {
        return {
          rows: [
            { id: values?.[0] === "user_wallet" ? "wallet-1" : "payable-1" },
          ],
        }
      }
      if (text.includes("from finance.postings")) {
        return {
          rows: [
            {
              ledger_account_id: "wallet-1",
              direction: "credit",
              amount: "50.0000",
              currency: "NGN",
            },
            {
              ledger_account_id: "payable-1",
              direction: "debit",
              amount: "50.0000",
              currency: "NGN",
            },
          ],
        }
      }
      if (text.includes("set status = 'RESERVED'")) {
        state.status = "RESERVED"
        state.journalEntryId = String(values?.[2])
        return {
          rows: [
            requestRow({
              status: "RESERVED",
              journal_entry_id: state.journalEntryId,
              provider: values?.[3] ?? "fake",
            }),
          ],
        }
      }
      if (text.includes("set status = 'PROCESSING'")) {
        state.status = "PROCESSING"
        return {
          rows: [
            requestRow({
              status: "PROCESSING",
              journal_entry_id: state.journalEntryId,
              provider: values?.[2] as string | null ?? "fake",
              provider_reference: values?.[3] as string | null ?? null,
            }),
          ],
        }
      }
      if (text.includes("set status = 'PAID'")) {
        state.status = "PAID"
        return {
          rows: [
            requestRow({
              status: "PAID",
              journal_entry_id: state.journalEntryId,
              provider: values?.[2],
              provider_reference: values?.[3],
              completed_at: "2026-11-23T10:00:01.000Z",
            }),
          ],
        }
      }
      if (text.includes("set status = 'FAILED'")) {
        state.status = "FAILED"
        return {
          rows: [
            requestRow({
              status: "FAILED",
              journal_entry_id: state.journalEntryId,
              provider: values?.[2],
              provider_reference: values?.[3],
              failure_code: values?.[4],
              completed_at: "2026-11-23T10:00:01.000Z",
            }),
          ],
        }
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

  const ledger = {
    async postEntryInTransaction(_transaction: unknown, input: LedgerCall) {
      ledgerCalls.push(input)
      return { id: input.kind === "reversal" ? "reversal-1" : "entry-1" }
    },
  }

  const limits = {
    async assertWithin(_transaction: unknown, input: unknown) {
      limitChecks.push(input)
      if (options.denyLimit) {
        throw new Error("limit denied")
      }
    },
  }

  const provider = {
    provider: "fake",
    async initiatePayout(input: unknown, providerContext: unknown) {
      providerCalls.push({ input, context: providerContext })
      if (options.providerError) throw options.providerError
      return options.providerResult ?? successResult()
    },
  }

  const service = new PayoutExecutionService(
    database as never,
    options.apiConfig ?? apiConfig(),
    ledger as never,
    limits as never,
    provider as never,
  )

  return {
    service,
    audits,
    ledgerCalls,
    providerCalls,
    limitChecks,
    get status() {
      return state.status
    },
  }
}

function executeInput(overrides: Record<string, unknown> = {}) {
  return {
    accountId: ACCOUNT_ID,
    userId: USER_ID,
    tier: "tier_1",
    requestId: REQUEST_ID,
    context,
    ...overrides,
  }
}

describe("payout execution", () => {
  it("refuses a caller below tier_1 before loading the request", async () => {
    const test = harness()

    await expect(
      test.service.execute(executeInput({ tier: "tier_0" })),
    ).rejects.toMatchObject({ code: "KYC_REQUIRED", statusCode: 403 })
    expect(test.providerCalls).toHaveLength(0)
    expect(test.ledgerCalls).toHaveLength(0)
  })

  it("refuses an unverified destination before reserving", async () => {
    const test = harness({
      destination: destinationRow({ status: "pending" }),
    })

    await expect(test.service.execute(executeInput())).rejects.toMatchObject({
      code: "PAYOUT_ACCOUNT_REQUIRED",
      statusCode: 403,
    })
    expect(test.ledgerCalls).toHaveLength(0)
    expect(test.providerCalls).toHaveLength(0)
  })

  it("refuses when the available balance is short", async () => {
    const test = harness({ available: "49.9999" })

    await expect(test.service.execute(executeInput())).rejects.toMatchObject({
      code: "INSUFFICIENT_FUNDS",
      statusCode: 409,
    })
    expect(test.ledgerCalls).toHaveLength(0)
  })

  it("refuses when payout encryption is not configured", async () => {
    const test = harness({
      apiConfig: parseConfig({ HIVORR_ENV: "test" }),
    })

    await expect(test.service.execute(executeInput())).rejects.toMatchObject({
      code: "SERVICE_UNAVAILABLE",
      statusCode: 503,
    })
  })

  it("reserves, calls the provider and marks the request paid", async () => {
    const test = harness()
    const view = await test.service.execute(executeInput())

    expect(view.status).toBe("PAID")
    expect(view.providerReference).toBe("FP-1")

    expect(test.ledgerCalls).toHaveLength(1)
    expect(test.ledgerCalls[0]).toMatchObject({ kind: "payout" })

    expect(test.providerCalls).toHaveLength(1)
    expect(test.providerCalls[0]?.context).toMatchObject({
      idempotencyKey: REQUEST_ID,
    })
    expect(test.providerCalls[0]?.input).toMatchObject({
      reference: REFERENCE,
      amount: "50.0000",
      currency: "NGN",
      bankCode: "999",
      accountNumber: ACCOUNT_NUMBER,
      accountName: "Kuti Sema",
    })

    const actions = test.audits.map((entry) => entry[4])
    expect(actions).toContain("finance.payout_reserved")
    expect(actions).toContain("finance.payout_execution_started")
    expect(actions).toContain("finance.payout_paid")
    expect(JSON.stringify(test.audits)).not.toContain(ACCOUNT_NUMBER)
  })

  it("keeps a pending provider result in PROCESSING without a reversal", async () => {
    const test = harness({
      providerResult: successResult({
        status: "processing",
        providerReference: "FP-2",
      }),
    })

    const view = await test.service.execute(executeInput())
    expect(view.status).toBe("PROCESSING")
    expect(test.ledgerCalls).toHaveLength(1)
    expect(test.ledgerCalls.some((call) => call.kind === "reversal")).toBe(
      false,
    )
    const actions = test.audits.map((entry) => entry[4])
    expect(actions).toContain("finance.payout_processing")
  })

  it("reverses the reserve when the provider definitively fails", async () => {
    const test = harness({
      providerResult: successResult({
        status: "failed",
        failureCode: "VFD_99",
        failureMessage: "Failed Transaction",
      }),
    })

    const view = await test.service.execute(executeInput())

    expect(view.status).toBe("FAILED")
    expect(test.ledgerCalls.map((call) => call.kind)).toEqual([
      "payout",
      "reversal",
    ])
    expect(test.ledgerCalls[1]?.reversesEntryId).toBe("entry-1")
    expect(view.failureCode).toBe("VFD_99")
  })

  it("treats a retryable provider error as ambiguous and does not reverse", async () => {
    const test = harness({
      providerError: new PaymentProviderError(
        "PROVIDER_TIMEOUT",
        "VFD did not answer in time.",
      ),
    })

    const view = await test.service.execute(executeInput())
    expect(view.status).toBe("PROCESSING")
    expect(test.ledgerCalls).toHaveLength(1)
    expect(test.status).toBe("PROCESSING")
  })

  it("treats a duplicate provider reference as ambiguous", async () => {
    const test = harness({
      providerError: new PaymentProviderError(
        "PROVIDER_DUPLICATE",
        "Already exists.",
      ),
    })

    const view = await test.service.execute(executeInput())
    expect(view.status).toBe("PROCESSING")
    expect(test.ledgerCalls).toHaveLength(1)
  })

  it("reverses the reserve on a non-retryable provider failure", async () => {
    const test = harness({
      providerError: new PaymentProviderError(
        "PROVIDER_AUTH_FAILED",
        "VFD rejected the transfer signature.",
      ),
    })

    const view = await test.service.execute(executeInput())
    expect(view.status).toBe("FAILED")
    expect(test.ledgerCalls.map((call) => call.kind)).toEqual([
      "payout",
      "reversal",
    ])
  })

  it("returns a final request without calling the provider again", async () => {
    const test = harness({
      initialStatus: "PAID",
      initialJournalEntryId: "entry-1",
    })

    const view = await test.service.execute(executeInput())
    expect(view.status).toBe("PAID")
    expect(test.providerCalls).toHaveLength(0)
    expect(test.ledgerCalls).toHaveLength(0)
  })

  it("continues a reserved request without posting a second reserve", async () => {
    const test = harness({
      initialStatus: "RESERVED",
      initialJournalEntryId: "entry-1",
    })

    const view = await test.service.execute(executeInput())
    expect(view.status).toBe("PAID")
    expect(test.ledgerCalls).toHaveLength(0)
    expect(test.providerCalls).toHaveLength(1)
  })
})
