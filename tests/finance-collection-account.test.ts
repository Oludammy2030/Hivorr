import { afterEach, describe, expect, it, vi } from "vitest"

import type { ApiConfig } from "../server/src/config"
import type { DatabaseService } from "../server/src/db/database.service"
import { CollectionAccountService } from "../server/src/modules/finance/collection-account.service"
import type { PaymentProviderSettingsService } from "../server/src/modules/platform"

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111"
const USER_ID = "22222222-2222-4222-8222-222222222222"
const COLLECTION_ID = "33333333-3333-4333-8333-333333333333"
const TEST_KEY = "sk_test_collection_account"

const context = {
  audience: "app" as const,
  environment: "staging" as const,
  correlationId: "corr-collection",
}

interface QueryCall {
  readonly text: string
  readonly values?: readonly unknown[]
}

interface FetchCall {
  readonly url: string
  readonly authorization: string
}

function config(secretKeyTest = TEST_KEY): ApiConfig {
  return {
    environment: "test",
    paystack: {
      baseUrl: "https://api.paystack.test",
      secretKeyTest,
      secretKeyLive: "sk_live_collection_account",
      preferredBank: "titan-paystack",
    },
    vfd: {
      requestTimeoutMs: 500,
      maxRetries: 0,
      retryBaseMs: 1,
    },
  } as unknown as ApiConfig
}

function accountRow(overrides: Record<string, unknown> = {}) {
  return {
    id: COLLECTION_ID,
    provider: "paystack",
    reference: `COL-${ACCOUNT_ID}`,
    account_number: "1234567890",
    account_name: "Hivorr / Kuti Sema",
    bank_name: "Titan Trust Bank",
    currency: "NGN",
    status: "active",
    ...overrides,
  }
}

function harness(
  options: {
    readonly existing?: Record<string, unknown> | null
    readonly inserted?: Record<string, unknown> | null
    readonly afterInsert?: Record<string, unknown> | null
    readonly provider?: "paystack" | "vfd"
    readonly mode?: "test" | "live"
    readonly secretKeyTest?: string
  } = {},
) {
  const queries: QueryCall[] = []
  const audits: unknown[][] = []

  const transaction = {
    client: {
      async query(text: string, values?: readonly unknown[]) {
        if (text.includes("platform.audit_log")) audits.push(values ?? [])
        return { rows: [], rowCount: 1 }
      },
    },
    async query(text: string, values?: readonly unknown[]) {
      queries.push({ text, values })
      if (text.includes("insert into finance.collection_accounts")) {
        const row =
          options.inserted === undefined ? accountRow() : options.inserted
        return { rows: row ? [row] : [] }
      }
      if (text.includes("from finance.collection_accounts")) {
        const row = options.existing === undefined ? null : options.existing
        if (row) return { rows: [row] }
        const after =
          options.afterInsert === undefined ? null : options.afterInsert
        return { rows: after ? [after] : [] }
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

  const settings = {
    activeSetting: async () => ({
      provider: options.provider ?? "paystack",
      mode: options.mode ?? "test",
    }),
  } as unknown as PaymentProviderSettingsService

  const service = new CollectionAccountService(
    database,
    config(options.secretKeyTest),
    settings,
  )

  return { service, queries, audits }
}

function input() {
  return {
    accountId: ACCOUNT_ID,
    userId: USER_ID,
    email: "user@example.com",
    accountName: "Kuti Sema",
    context,
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  })
}

function stubProvider() {
  const calls: FetchCall[] = []
  const fetchImpl = vi.fn(
    async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({
        url: String(url),
        authorization: String(
          (init?.headers as Record<string, string> | undefined)
            ?.authorization ?? "",
        ),
      })
      if (String(url).endsWith("/customer")) {
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
    },
  )
  vi.stubGlobal("fetch", fetchImpl)
  return { fetchImpl, calls }
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("collection account read", () => {
  it("returns nothing when the account has no virtual account", async () => {
    const { service } = harness()

    await expect(
      service.get({ accountId: ACCOUNT_ID, userId: USER_ID }),
    ).resolves.toBeNull()
  })

  it("projects the stored number and bank to the owner", async () => {
    const { service } = harness({ existing: accountRow() })

    await expect(
      service.get({ accountId: ACCOUNT_ID, userId: USER_ID }),
    ).resolves.toEqual({
      id: COLLECTION_ID,
      provider: "paystack",
      reference: `COL-${ACCOUNT_ID}`,
      accountNumber: "1234567890",
      accountName: "Hivorr / Kuti Sema",
      bankName: "Titan Trust Bank",
      currency: "NGN",
      status: "active",
    })
  })
})

describe("collection account creation", () => {
  it("returns the existing account without calling the provider", async () => {
    const { fetchImpl } = stubProvider()
    const { service } = harness({ existing: accountRow() })

    const result = await service.create(input())

    expect(result.accountNumber).toBe("1234567890")
    expect(fetchImpl).not.toHaveBeenCalled()
  })

  it("refuses to provision while VFD is the active provider", async () => {
    const { fetchImpl } = stubProvider()
    const { service } = harness({ provider: "vfd" })

    await expect(service.create(input())).rejects.toMatchObject({
      code: "SERVICE_UNAVAILABLE",
      statusCode: 503,
    })
    expect(fetchImpl).not.toHaveBeenCalled()
  })

  it("refuses to provision without a configured key", async () => {
    const { fetchImpl } = stubProvider()
    const { service } = harness({ secretKeyTest: "" })

    await expect(service.create(input())).rejects.toMatchObject({
      code: "SERVICE_UNAVAILABLE",
      statusCode: 503,
    })
    expect(fetchImpl).not.toHaveBeenCalled()
  })

  it("provisions a virtual account and audits the last four digits", async () => {
    const { calls } = stubProvider()
    const { service, audits } = harness()

    const result = await service.create(input())

    expect(calls.map((call) => call.url)).toEqual([
      "https://api.paystack.test/customer",
      "https://api.paystack.test/dedicated_account",
    ])
    expect(
      calls.every((call) => call.authorization === `Bearer ${TEST_KEY}`),
    ).toBe(true)
    expect(result).toMatchObject({
      provider: "paystack",
      accountNumber: "1234567890",
      bankName: "Titan Trust Bank",
      currency: "NGN",
    })
    expect(audits).toHaveLength(1)
    expect(audits[0]).toContain("finance.collection_account_created")
    expect(JSON.stringify(audits[0])).toContain("7890")
  })

  it("keeps the account a concurrent insert won", async () => {
    stubProvider()
    const { service, audits } = harness({
      inserted: null,
      afterInsert: accountRow({ id: "44444444-4444-4444-8444-444444444444" }),
    })

    const result = await service.create(input())

    expect(result.id).toBe("44444444-4444-4444-8444-444444444444")
    expect(audits).toHaveLength(0)
  })

  it("maps a provider rejection to PROVIDER_ERROR", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        jsonResponse({ status: false, message: "invalid key" }, 401),
      ),
    )
    const { service } = harness()

    await expect(service.create(input())).rejects.toMatchObject({
      code: "PROVIDER_ERROR",
      statusCode: 502,
    })
  })
})
