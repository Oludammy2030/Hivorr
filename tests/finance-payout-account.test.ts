import { describe, expect, it } from "vitest"

import { parseConfig } from "../server/src/config"
import { PaymentProviderError } from "../server/src/integrations/payments/payment-provider"
import { PayoutAccountCipher } from "../server/src/modules/finance/payout-account-crypto"
import { PayoutAccountService } from "../server/src/modules/finance/payout-account.service"

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111"
const USER_ID = "22222222-2222-4222-8222-222222222222"
const PAYOUT_ID = "33333333-3333-4333-8333-333333333333"
const ENCRYPTION_KEY = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
const FINGERPRINT_KEY = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="

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

function config(overrides: Record<string, string> = {}) {
  return parseConfig({
    HIVORR_ENV: "test",
    PAYOUT_ENCRYPTION_KEY: ENCRYPTION_KEY,
    PAYOUT_FINGERPRINT_KEY: FINGERPRINT_KEY,
    PAYOUT_ACCOUNT_MAX_ACTIVE: "2",
    ...overrides,
  })
}

function harness(
  options: {
    readonly legalName?: string | null
    readonly resolvedName?: string
    readonly resolverError?: Error
    readonly active?: number
    readonly insertError?: Error
    readonly updateRow?: Row | null
    readonly listRows?: Row[]
    readonly apiConfig?: ReturnType<typeof config>
  } = {},
) {
  const queries: QueryCall[] = []
  const audits: unknown[][] = []
  let insertValues: readonly unknown[] | undefined
  let resolverCalls = 0

  const legalName = options.legalName === undefined ? "Kuti Sema" : options.legalName

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
      if (text.includes("pg_advisory_xact_lock")) return { rows: [] }
      if (text.includes("count(*)::text as active")) {
        return { rows: [{ active: String(options.active ?? 0) }] }
      }
      if (text.includes("insert into finance.payout_accounts")) {
        if (options.insertError) throw options.insertError
        insertValues = values
        return {
          rows: [
            {
              id: PAYOUT_ID,
              bank_code: values?.[1],
              bank_name: values?.[2],
              account_name: values?.[3],
              account_number_last4: values?.[7],
              status: "verified",
              verified_at: "2026-11-23T10:00:00.000Z",
              created_at: "2026-11-23T10:00:00.000Z",
            },
          ],
        }
      }
      if (text.includes("update finance.payout_accounts")) {
        return { rows: options.updateRow ? [options.updateRow] : [] }
      }
      if (text.includes("from finance.payout_accounts")) {
        return { rows: options.listRows ?? [] }
      }
      throw new Error(`unexpected query: ${text}`)
    },
  }

  const database = {
    async withTransaction(_options: unknown, work: (tx: unknown) => Promise<unknown>) {
      return work(transaction)
    },
  }

  const identity = {
    async getAccountLegalName() {
      return legalName
    },
  }

  const resolver = {
    async resolveAccountName(input: { bankCode: string; accountNumber: string }) {
      resolverCalls += 1
      if (options.resolverError) throw options.resolverError
      return {
        accountName: options.resolvedName ?? "Kuti Sema",
        bankCode: input.bankCode,
        accountNumberLast4: input.accountNumber.slice(-4),
      }
    },
  }

  const service = new PayoutAccountService(
    database as never,
    options.apiConfig ?? config(),
    identity as never,
    resolver as never,
  )

  return {
    service,
    queries,
    audits,
    get insertValues() {
      return insertValues
    },
    get resolverCalls() {
      return resolverCalls
    },
  }
}

function bindInput(overrides: Record<string, unknown> = {}) {
  return {
    accountId: ACCOUNT_ID,
    userId: USER_ID,
    tier: "tier_1",
    bankCode: "999",
    bankName: "Example Bank",
    accountNumber: "0123456789",
    context,
    ...overrides,
  }
}

function listRow(overrides: Row = {}): Row {
  return {
    id: PAYOUT_ID,
    bank_code: "999",
    bank_name: "Example Bank",
    account_name: "Kuti Sema",
    account_number_last4: "6789",
    status: "verified",
    verified_at: "2026-11-23T10:00:00.000Z",
    created_at: "2026-11-23T10:00:00.000Z",
    ...overrides,
  }
}

describe("payout account binding", () => {
  it("refuses a caller below tier_1 before doing any work", async () => {
    const test = harness()

    await expect(test.service.bind(bindInput({ tier: "tier_0" }))).rejects.toMatchObject({
      code: "KYC_REQUIRED",
      statusCode: 403,
    })
    expect(test.resolverCalls).toBe(0)
    expect(test.queries).toHaveLength(0)
  })

  it("refuses to bind when the approved destination cap is unset", async () => {
    const test = harness({
      apiConfig: config({ PAYOUT_ACCOUNT_MAX_ACTIVE: "" }),
    })

    await expect(test.service.bind(bindInput())).rejects.toMatchObject({
      code: "SERVICE_UNAVAILABLE",
      statusCode: 503,
    })
  })

  it("refuses to bind when the payout keys are unset", async () => {
    const apiConfig = parseConfig({
      HIVORR_ENV: "test",
      PAYOUT_ACCOUNT_MAX_ACTIVE: "2",
    })
    const test = harness({ apiConfig })

    await expect(test.service.bind(bindInput())).rejects.toMatchObject({
      code: "SERVICE_UNAVAILABLE",
      statusCode: 503,
    })
  })

  it("refuses when the account has no verified legal name", async () => {
    const test = harness({ legalName: null })

    await expect(test.service.bind(bindInput())).rejects.toMatchObject({
      code: "KYC_REQUIRED",
      statusCode: 403,
    })
    expect(test.resolverCalls).toBe(0)
  })

  it("rejects a resolved name that does not match the legal name", async () => {
    const test = harness({ resolvedName: "Another Person" })

    await expect(test.service.bind(bindInput())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
      statusCode: 422,
    })
    expect(test.queries).toHaveLength(0)
  })

  it("matches a name that differs only in case and whitespace", async () => {
    const test = harness({ resolvedName: "  kuti   sema " })

    const view = await test.service.bind(bindInput())
    expect(view.accountName).toBe("kuti   sema")
    expect(view.state).toBe("verified")
  })

  it("encrypts the account number and projects only the last four", async () => {
    const test = harness()
    const view = await test.service.bind(bindInput())

    expect(view.accountNumberMasked).toBe("******6789")
    expect(JSON.stringify(view)).not.toContain("0123456789")

    const values = test.insertValues
    expect(values?.[3]).toBe("Kuti Sema")
    expect(values?.[7]).toBe("6789")
    expect(Buffer.isBuffer(values?.[5])).toBe(true)
    expect(JSON.stringify(values?.[5])).not.toContain("0123456789")

    const ciphertext = values?.[5] as Buffer
    const cipher = PayoutAccountCipher.fromConfig({
      encryptionKey: ENCRYPTION_KEY,
      encryptionKeyId: "v1",
      fingerprintKey: FINGERPRINT_KEY,
    })
    expect(cipher.decrypt(ciphertext, "v1")).toBe("0123456789")

    expect(test.audits).toHaveLength(1)
    const audit = JSON.stringify(test.audits[0])
    expect(audit).toContain("finance.payout_account_bound")
    expect(audit).toContain("6789")
    expect(audit).not.toContain("0123456789")
  })

  it("refuses a bind that would exceed the configured destination cap", async () => {
    const test = harness({ active: 2 })

    await expect(test.service.bind(bindInput())).rejects.toMatchObject({
      code: "LIMIT_EXCEEDED",
      statusCode: 409,
    })
    expect(test.insertValues).toBeUndefined()
  })

  it("maps a duplicate destination to a conflict", async () => {
    const duplicate = Object.assign(new Error("duplicate"), { code: "23505" })
    const test = harness({ insertError: duplicate })

    await expect(test.service.bind(bindInput())).rejects.toMatchObject({
      code: "CONFLICT",
      statusCode: 409,
    })
  })

  it("maps a provider failure without leaking its detail", async () => {
    const test = harness({
      resolverError: new PaymentProviderError(
        "PROVIDER_UNAVAILABLE",
        "raw vendor detail about 0123456789",
      ),
    })

    await expect(test.service.bind(bindInput())).rejects.toMatchObject({
      code: "PROVIDER_ERROR",
      statusCode: 502,
      message: "The bank could not confirm that account name.",
    })
  })

  it("lists destinations without ciphertext or a full account number", async () => {
    const test = harness({ listRows: [listRow()] })

    const rows = await test.service.list({
      accountId: ACCOUNT_ID,
      userId: USER_ID,
    })

    expect(rows).toEqual([
      {
        id: PAYOUT_ID,
        bankCode: "999",
        bankName: "Example Bank",
        accountName: "Kuti Sema",
        accountNumberMasked: "******6789",
        state: "verified",
        boundAt: "2026-11-23T10:00:00.000Z",
        createdAt: "2026-11-23T10:00:00.000Z",
      },
    ])
    expect(JSON.stringify(rows)).not.toContain("ciphertext")
  })
})

describe("payout account encryption", () => {
  const cipher = () =>
    PayoutAccountCipher.fromConfig({
      encryptionKey: ENCRYPTION_KEY,
      encryptionKeyId: "v1",
      fingerprintKey: FINGERPRINT_KEY,
    })

  it("round-trips and refuses a tampered envelope", () => {
    const instance = cipher()
    const encrypted = instance.encrypt("0123 456 789")
    expect(instance.decrypt(encrypted.ciphertext, "v1")).toBe("0123456789")
    expect(encrypted.last4).toBe("6789")
    expect(encrypted.fingerprint).toMatch(/^[0-9a-f]{64}$/)

    const tampered = Buffer.from(encrypted.ciphertext)
    tampered[tampered.length - 1] ^= 0xff
    expect(() => instance.decrypt(tampered, "v1")).toThrow()
  })

  it("produces a stable fingerprint under a separate key", () => {
    const instance = cipher()
    expect(instance.fingerprint("0123456789")).toBe(instance.fingerprint("0123 456 789"))
    expect(instance.fingerprint("0123456789")).not.toBe(instance.fingerprint("9876543210"))
    expect(() => instance.decrypt(Buffer.alloc(40), "v2")).toThrow()
  })
})

describe("payout account disabling", () => {
  it("disables a destination and audits the change", async () => {
    const test = harness({
      updateRow: listRow({ status: "disabled" }),
    })

    const view = await test.service.disable({
      id: PAYOUT_ID,
      accountId: ACCOUNT_ID,
      userId: USER_ID,
      reason: "Closing the old bank account",
      context,
    })

    expect(view.state).toBe("disabled")
    expect(test.audits).toHaveLength(1)
    expect(JSON.stringify(test.audits[0])).toContain("finance.payout_account_disabled")
  })

  it("returns not found when the owner has no such destination", async () => {
    const test = harness({ updateRow: null })

    await expect(
      test.service.disable({
        id: PAYOUT_ID,
        accountId: ACCOUNT_ID,
        userId: USER_ID,
        reason: "Closing the old bank account",
        context,
      }),
    ).rejects.toMatchObject({ code: "NOT_FOUND", statusCode: 404 })
  })

  it("requires a reason for a change", async () => {
    const test = harness({ updateRow: listRow({ status: "disabled" }) })

    await expect(
      test.service.disable({
        id: PAYOUT_ID,
        accountId: ACCOUNT_ID,
        userId: USER_ID,
        reason: "no",
        context,
      }),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED", statusCode: 400 })
  })
})
