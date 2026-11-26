import { createHmac } from "node:crypto"
import { createServer, type Server } from "node:http"

import { afterAll, beforeAll, describe, expect, it } from "vitest"

import type { ApiConfig } from "../server/src/config"
import type { DatabaseService } from "../server/src/db/database.service"
import type { IdentityService } from "../server/src/modules/identity"
import type { DepositEligibilityService } from "../server/src/modules/finance/deposit-eligibility.service"
import type { LedgerService } from "../server/src/modules/finance/ledger.service"
import { DepositPostingService } from "../server/src/modules/finance/deposit-posting.service"
import type { PaymentProviderSettingsService } from "../server/src/modules/platform"

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111"
const USER_ID = "22222222-2222-4222-8222-222222222222"
const REFERENCE_ID = "33333333-3333-4333-8333-333333333333"
const ENTRY_ID = "44444444-4444-4444-8444-444444444444"
const TEST_KEY = "sk_test_deposit_posting"
const LIVE_KEY = "sk_live_deposit_posting"

const context = {
  audience: "app" as const,
  environment: "staging" as const,
  correlationId: "corr-deposit",
}

interface QueryCall {
  readonly text: string
  readonly values?: readonly unknown[]
}

interface CollectionOwner {
  readonly account_id: string
  readonly owner_user_id: string
}

interface ProviderSetting {
  readonly provider: "paystack" | "vfd"
  readonly mode: "test" | "live"
}

interface DepositDecision {
  readonly allowed: boolean
  readonly reason: "within_limit" | "kyc_upgrade_required" | "kyc_required"
}

interface HarnessOptions {
  /** `none` makes the insert hit the conflict path. */
  readonly insert?: "new" | "none"
  readonly existing?: Record<string, unknown> | null
  readonly collection?: CollectionOwner | null
  readonly decision?: DepositDecision
  readonly throwCode?: string
  readonly baseUrl?: string
  readonly secretKeyTest?: string
  readonly settings?: ProviderSetting
}

function config(overrides: HarnessOptions = {}): ApiConfig {
  return {
    environment: "test",
    paystack: {
      baseUrl: overrides.baseUrl ?? "https://api.paystack.test",
      secretKeyTest: overrides.secretKeyTest ?? TEST_KEY,
      secretKeyLive: LIVE_KEY,
      preferredBank: "titan-paystack",
    },
    vfd: {
      requestTimeoutMs: 500,
      maxRetries: 0,
      retryBaseMs: 1,
    },
  } as unknown as ApiConfig
}

function harness(options: HarnessOptions = {}) {
  const queries: QueryCall[] = []
  const audits: unknown[][] = []
  const ledgerCalls: unknown[] = []
  const ledgerIds = ["ledger-wallet", "ledger-clearing"]

  const transaction = {
    client: {
      async query(text: string, values?: readonly unknown[]) {
        if (text.includes("platform.audit_log")) audits.push(values ?? [])
        return { rows: [], rowCount: 1 }
      },
    },
    async query(text: string, values?: readonly unknown[]) {
      if (options.throwCode) {
        throw Object.assign(new Error("database refused the write"), {
          code: options.throwCode,
        })
      }
      queries.push({ text, values })

      if (text.includes("insert into finance.provider_references")) {
        return {
          rows:
            options.insert === "none"
              ? []
              : [
                  {
                    id: REFERENCE_ID,
                    status: "received",
                    journal_entry_id: null,
                  },
                ],
        }
      }
      if (
        text.includes("from finance.provider_references") &&
        text.includes("for update")
      ) {
        return { rows: options.existing ? [options.existing] : [] }
      }
      if (text.includes("from finance.collection_accounts")) {
        return { rows: options.collection ? [options.collection] : [] }
      }
      if (text.includes("finance.ensure_ledger_account")) {
        const id = ledgerIds.shift() ?? "ledger-extra"
        return { rows: [{ id }] }
      }
      if (text.includes("update finance.provider_references")) {
        return { rows: [], rowCount: 1 }
      }
      return { rows: [], rowCount: 0 }
    },
  }

  const database = {
    withTransaction: async (
      _options: unknown,
      work: (value: typeof transaction) => Promise<unknown>,
    ) => work(transaction),
  } as unknown as DatabaseService

  const identity = {
    getKycTierInTransaction: async () => "tier_1",
  } as unknown as IdentityService

  const eligibility = {
    checkInTransaction: async () =>
      options.decision ?? { allowed: true, reason: "within_limit" },
  } as unknown as DepositEligibilityService

  const ledger = {
    postEntryInTransaction: async (
      _transaction: unknown,
      input: unknown,
      _context: unknown,
    ) => {
      ledgerCalls.push(input)
      return { id: ENTRY_ID }
    },
  } as unknown as LedgerService

  const settings = {
    activeSetting: async () =>
      options.settings ?? { provider: "paystack", mode: "test" },
  } as unknown as PaymentProviderSettingsService

  const service = new DepositPostingService(
    database,
    config(options),
    identity,
    eligibility,
    ledger,
    settings,
  )

  return { service, queries, audits, ledgerCalls }
}

function depositInput(overrides: Record<string, unknown> = {}) {
  return {
    accountId: ACCOUNT_ID,
    userId: USER_ID,
    provider: "paystack",
    providerReference: "dep-1",
    amount: "50.0000",
    currency: "NGN",
    occurredAt: "2026-11-26T10:00:00.000Z",
    context,
    ...overrides,
  }
}

function existingRow(overrides: Record<string, unknown> = {}) {
  return {
    id: REFERENCE_ID,
    account_id: ACCOUNT_ID,
    direction: "deposit",
    status: "received",
    amount: "50.0000",
    currency: "NGN",
    journal_entry_id: null,
    ...overrides,
  }
}

describe("deposit posting", () => {
  it("posts a deposit, marks the reference and audits it", async () => {
    const { service, queries, audits, ledgerCalls } = harness()

    const result = await service.postDeposit(depositInput())

    expect(result).toEqual({
      reference: "dep-1",
      accountId: ACCOUNT_ID,
      amount: "50.0000",
      currency: "NGN",
      status: "posted",
      journalEntryId: ENTRY_ID,
    })
    expect(ledgerCalls).toHaveLength(1)
    expect(ledgerCalls[0]).toMatchObject({
      kind: "deposit",
      reference: "DEP-dep-1",
      idempotencyKey: "deposit:paystack:dep-1",
      postings: [
        { accountId: "ledger-wallet", direction: "debit", amount: "50.0000" },
        {
          accountId: "ledger-clearing",
          direction: "credit",
          amount: "50.0000",
        },
      ],
    })
    expect(
      queries.some(
        (call) =>
          call.text.includes("set status = 'posted'") &&
          call.values?.[1] === ENTRY_ID,
      ),
    ).toBe(true)
    expect(audits).toHaveLength(1)
    expect(audits[0]).toContain("finance.deposit_posted")
  })

  it("replays an already posted reference without posting again", async () => {
    const { service, ledgerCalls, queries } = harness({
      insert: "none",
      existing: existingRow({ status: "posted", journal_entry_id: ENTRY_ID }),
    })

    const result = await service.postDeposit(depositInput())

    expect(result.status).toBe("replayed")
    expect(result.journalEntryId).toBe(ENTRY_ID)
    expect(ledgerCalls).toHaveLength(0)
    expect(
      queries.some((call) =>
        call.text.includes("update finance.provider_references"),
      ),
    ).toBe(false)
  })

  it("keeps a held reference blocked without posting it", async () => {
    const { service, ledgerCalls, audits } = harness({
      insert: "none",
      existing: existingRow({ status: "failed" }),
    })

    const result = await service.postDeposit(depositInput())

    expect(result.status).toBe("blocked")
    expect(result.reason).toBe("kyc_upgrade_required")
    expect(ledgerCalls).toHaveLength(0)
    expect(audits).toHaveLength(0)
  })

  it("refuses an over-cap deposit and marks the reference failed", async () => {
    const { service, queries, audits, ledgerCalls } = harness({
      decision: { allowed: false, reason: "kyc_upgrade_required" },
    })

    const result = await service.postDeposit(
      depositInput({ amount: "90000.0000" }),
    )

    expect(result.status).toBe("blocked")
    expect(result.reason).toBe("kyc_upgrade_required")
    expect(result.journalEntryId).toBeNull()
    expect(ledgerCalls).toHaveLength(0)
    expect(audits).toHaveLength(0)
    expect(
      queries.some((call) => call.text.includes("set status = 'failed'")),
    ).toBe(true)
  })

  it("refuses a deposit when the account is not KYC verified", async () => {
    const { service, ledgerCalls } = harness({
      decision: { allowed: false, reason: "kyc_required" },
    })

    const result = await service.postDeposit(depositInput())

    expect(result).toMatchObject({
      status: "blocked",
      reason: "kyc_required",
    })
    expect(ledgerCalls).toHaveLength(0)
  })

  it("rejects a reference reused for a different movement", async () => {
    const { service } = harness({
      insert: "none",
      existing: existingRow({ amount: "10.0000" }),
    })

    await expect(service.postDeposit(depositInput())).rejects.toMatchObject({
      code: "CONFLICT",
      statusCode: 409,
    })
  })

  it("rejects a reference that cannot be resolved after a conflict", async () => {
    const { service } = harness({ insert: "none", existing: null })

    await expect(service.postDeposit(depositInput())).rejects.toMatchObject({
      code: "CONFLICT",
    })
  })

  it("maps a database permission denial to FORBIDDEN", async () => {
    const { service } = harness({ throwCode: "42501" })

    await expect(service.postDeposit(depositInput())).rejects.toMatchObject({
      code: "FORBIDDEN",
      statusCode: 403,
    })
  })

  it("maps a duplicate or check violation to CONFLICT", async () => {
    const { service } = harness({ throwCode: "23505" })

    await expect(service.postDeposit(depositInput())).rejects.toMatchObject({
      code: "CONFLICT",
    })
  })
})

/** Webhook intake: signature, event shape and provider configuration. */
describe("Paystack webhook intake", () => {
  let server: Server
  let baseUrl: string
  let verifyCalls = 0
  let authorization: string | undefined

  beforeAll(async () => {
    server = createServer((request, response) => {
      if (request.url?.startsWith("/transaction/verify/")) {
        verifyCalls += 1
        authorization = String(request.headers.authorization ?? "")
        response.writeHead(200, { "content-type": "application/json" })
        response.end(
          JSON.stringify({
            status: true,
            data: {
              reference: "dep-1",
              amount: 5000,
              currency: "NGN",
              status: "success",
              paid_at: "2026-11-26T10:00:00.000Z",
              customer: { email: "user@example.com", customer_code: "CUS_1" },
              authorization: { sender_name: "KUTI SEMA" },
              dedicated_account: { account_number: "1234567890" },
            },
          }),
        )
        return
      }
      response.writeHead(404, { "content-type": "application/json" })
      response.end(JSON.stringify({ status: false }))
    })
    await new Promise<void>((resolve) =>
      server.listen(0, "127.0.0.1", () => resolve()),
    )
    const address = server.address()
    if (!address || typeof address === "string") {
      throw new Error("the test server did not bind a port")
    }
    baseUrl = `http://127.0.0.1:${address.port}`
  })

  afterAll(async () => {
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    )
  })

  function webhookHarness(options: Omit<HarnessOptions, "baseUrl"> = {}) {
    return harness({ ...options, baseUrl })
  }

  function sign(body: string, key = TEST_KEY): string {
    return createHmac("sha512", key).update(Buffer.from(body)).digest("hex")
  }

  const depositBody = JSON.stringify({
    event: "charge.success",
    data: {
      reference: "dep-1",
      amount: 5000,
      currency: "NGN",
      status: "success",
      paid_at: "2026-11-26T10:00:00.000Z",
      dedicated_account: { account_number: "1234567890" },
    },
  })

  it("ignores a webhook while VFD is the active provider", async () => {
    const { service } = webhookHarness({
      settings: { provider: "vfd", mode: "test" },
    })

    await expect(
      service.handlePaystackWebhook(Buffer.from("{}"), "abc"),
    ).resolves.toEqual({
      accepted: false,
      posted: false,
      reason: "provider_paused",
    })
  })

  it("refuses to verify a webhook without a configured key", async () => {
    const { service } = webhookHarness({ secretKeyTest: "" })

    await expect(
      service.handlePaystackWebhook(Buffer.from("{}"), "abc"),
    ).rejects.toMatchObject({ code: "SERVICE_UNAVAILABLE", statusCode: 503 })
  })

  it("rejects a signature that does not match the body", async () => {
    const { service } = webhookHarness()
    const body = JSON.stringify({ event: "charge.success", data: {} })

    await expect(
      service.handlePaystackWebhook(Buffer.from(body), sign(`${body} `)),
    ).rejects.toMatchObject({ code: "UNAUTHENTICATED", statusCode: 401 })
  })

  it("rejects a signed body that is not JSON", async () => {
    const { service } = webhookHarness()
    const body = "not-json"

    await expect(
      service.handlePaystackWebhook(Buffer.from(body), sign(body)),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED", statusCode: 400 })
  })

  it("accepts but ignores a non-deposit event", async () => {
    const { service } = webhookHarness()
    const body = JSON.stringify({ event: "transfer.success", data: {} })

    await expect(
      service.handlePaystackWebhook(Buffer.from(body), sign(body)),
    ).resolves.toEqual({
      accepted: false,
      posted: false,
      reason: "not_a_deposit",
    })
  })

  it("verifies a signed deposit, resolves the owner and posts it", async () => {
    verifyCalls = 0
    authorization = undefined
    const { service, ledgerCalls } = webhookHarness({
      collection: { account_id: ACCOUNT_ID, owner_user_id: USER_ID },
    })

    const result = await service.handlePaystackWebhook(
      Buffer.from(depositBody),
      sign(depositBody),
    )

    expect(result).toEqual({ accepted: true, posted: true })
    expect(verifyCalls).toBe(1)
    expect(authorization).toBe(`Bearer ${TEST_KEY}`)
    expect(ledgerCalls).toHaveLength(1)
    expect(ledgerCalls[0]).toMatchObject({
      idempotencyKey: "deposit:paystack:dep-1",
      postings: [
        { direction: "debit", amount: "50.0000" },
        { direction: "credit", amount: "50.0000" },
      ],
    })
  })

  it("accepts a deposit it cannot attribute to a collection account", async () => {
    const { service, ledgerCalls } = webhookHarness({ collection: null })

    const result = await service.handlePaystackWebhook(
      Buffer.from(depositBody),
      sign(depositBody),
    )

    expect(result).toEqual({
      accepted: true,
      posted: false,
      reason: "collection_not_found",
    })
    expect(ledgerCalls).toHaveLength(0)
  })

  it("uses the live key when the active mode is live", async () => {
    authorization = undefined
    const { service } = webhookHarness({
      settings: { provider: "paystack", mode: "live" },
      collection: { account_id: ACCOUNT_ID, owner_user_id: USER_ID },
    })
    const body = depositBody

    await service.handlePaystackWebhook(Buffer.from(body), sign(body, LIVE_KEY))

    expect(authorization).toBe(`Bearer ${LIVE_KEY}`)
  })
})
