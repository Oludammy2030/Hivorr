import { randomUUID } from "node:crypto"

import { describe, expect, it } from "vitest"

import type { DatabaseService } from "../server/src/db/database.service"
import type { SetFinanceLimitInput } from "../server/src/modules/finance/limit.service"
import { FinanceLimitService } from "../server/src/modules/finance/limit.service"
import {
  evaluateFinanceLimit,
  financeLimitPeriodStart,
  selectFinanceLimit,
  type FinanceLimitRule,
} from "../server/src/modules/finance/limits"

function rule(overrides: Partial<FinanceLimitRule> = {}): FinanceLimitRule {
  return {
    id: randomUUID(),
    tier: "tier_1",
    accountId: null,
    limitType: "deposit",
    period: "per_transaction",
    currency: "NGN",
    amountMinor: 1_000_000_000n,
    effectiveFrom: new Date("2026-01-01T00:00:00.000Z"),
    effectiveTo: null,
    ...overrides,
  }
}

describe("finance limit domain", () => {
  const at = new Date("2026-11-19T12:00:00.000Z")

  it("prefers an account override over a tier rule", () => {
    const tierRule = rule()
    const accountRule = rule({ accountId: "account-1", amountMinor: 5_000n })

    const selected = selectFinanceLimit([tierRule, accountRule], {
      tier: "tier_1",
      accountId: "account-1",
      limitType: "deposit",
      currency: "NGN",
      at,
    })

    expect(selected?.id).toBe(accountRule.id)
  })

  it("selects the newest effective rule and ignores future or expired rows", () => {
    const old = rule()
    const newest = rule({ effectiveFrom: new Date("2026-06-01T00:00:00.000Z") })
    const future = rule({
      effectiveFrom: new Date("2027-01-01T00:00:00.000Z"),
    })
    const expired = rule({
      effectiveFrom: new Date("2025-01-01T00:00:00.000Z"),
      effectiveTo: new Date("2025-12-31T00:00:00.000Z"),
    })

    const selected = selectFinanceLimit([old, newest, future, expired], {
      tier: "tier_1",
      accountId: "account-1",
      limitType: "deposit",
      currency: "NGN",
      at,
    })

    expect(selected?.id).toBe(newest.id)
  })

  it("matches only the requested type and currency", () => {
    const selected = selectFinanceLimit(
      [rule({ limitType: "payout" }), rule({ currency: "USD" })],
      {
        tier: "tier_1",
        accountId: "account-1",
        limitType: "deposit",
        currency: "NGN",
        at,
      },
    )
    expect(selected).toBeNull()
  })

  it("denies tier_0 regardless of configuration", () => {
    expect(
      evaluateFinanceLimit({
        tier: "tier_0",
        rule: rule(),
        amountMinor: 1n,
      }),
    ).toMatchObject({ allowed: false, reason: "kyc_required" })
  })

  it("denies an unset limit", () => {
    expect(
      evaluateFinanceLimit({
        tier: "tier_1",
        rule: null,
        amountMinor: 1n,
      }),
    ).toMatchObject({ allowed: false, reason: "not_configured" })
  })

  it("allows a tier_1 write up to the configured amount", () => {
    expect(
      evaluateFinanceLimit({
        tier: "tier_1",
        rule: rule({ amountMinor: 1_000n }),
        amountMinor: 1_000n,
      }).allowed,
    ).toBe(true)

    expect(
      evaluateFinanceLimit({
        tier: "tier_1",
        rule: rule({ amountMinor: 1_000n }),
        amountMinor: 1_001n,
      }).allowed,
    ).toBe(false)
  })

  it("counts usage inside a period", () => {
    expect(
      evaluateFinanceLimit({
        tier: "tier_1",
        rule: rule({ period: "daily", amountMinor: 10_000n }),
        amountMinor: 2_000n,
        usedMinor: 8_000n,
      }).allowed,
    ).toBe(true)

    expect(
      evaluateFinanceLimit({
        tier: "tier_1",
        rule: rule({ period: "daily", amountMinor: 10_000n }),
        amountMinor: 2_001n,
        usedMinor: 8_000n,
      }),
    ).toMatchObject({ allowed: false, reason: "exceeded" })
  })

  it("checks a wallet balance cap after the write", () => {
    const cap = rule({ limitType: "wallet_balance", amountMinor: 500_000n })

    expect(
      evaluateFinanceLimit({
        tier: "tier_1",
        rule: cap,
        amountMinor: 60_000n,
        balanceAfterMinor: 510_000n,
      }).allowed,
    ).toBe(false)
    expect(
      evaluateFinanceLimit({
        tier: "tier_1",
        rule: cap,
        amountMinor: 60_000n,
        balanceAfterMinor: 390_000n,
      }).allowed,
    ).toBe(true)
  })

  it("starts periods at UTC boundaries", () => {
    const at2 = new Date("2026-11-19T12:34:56.000Z")
    expect(financeLimitPeriodStart("daily", at2)?.toISOString()).toBe(
      "2026-11-19T00:00:00.000Z",
    )
    expect(financeLimitPeriodStart("weekly", at2)?.toISOString()).toBe(
      "2026-11-16T00:00:00.000Z",
    )
    expect(financeLimitPeriodStart("monthly", at2)?.toISOString()).toBe(
      "2026-11-01T00:00:00.000Z",
    )
    expect(financeLimitPeriodStart("per_transaction", at2)).toBeNull()
  })
})

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

interface Row {
  id: string
  tier: string | null
  account_id: string | null
  limit_type: string
  period: string
  currency: string
  amount: string
  effective_from: string
  effective_to: string | null
  created_at: string
}

function row(overrides: Partial<Row> = {}): Row {
  return {
    id: randomUUID(),
    tier: "tier_1",
    account_id: null,
    limit_type: "deposit",
    period: "per_transaction",
    currency: "NGN",
    amount: "1000.0000",
    effective_from: "2026-01-01T00:00:00.000Z",
    effective_to: null,
    created_at: "2026-01-01T00:00:00.000Z",
    ...overrides,
  }
}

class FakeTransaction {
  readonly calls: Call[] = []
  permission = true
  limitRows: Row[] = [row()]
  usedAmount = "0.0000"
  available = "0.0000"
  insertRow: Row | null = row()

  query = async (text: string, values?: readonly unknown[]) => {
    this.calls.push({ text, values })

    if (text.includes("actor_holds_platform_permission")) {
      return { rows: [{ allowed: this.permission }], rowCount: 1 }
    }
    if (text.includes("insert into platform.audit_log")) {
      return { rows: [], rowCount: 1 }
    }
    if (text.startsWith("insert into finance.limits")) {
      return {
        rows: this.insertRow ? [this.insertRow] : [],
        rowCount: this.insertRow ? 1 : 0,
      }
    }
    if (text.includes("coalesce(sum(p.amount)")) {
      return { rows: [{ used: this.usedAmount }], rowCount: 1 }
    }
    if (text.includes("from finance.wallet_balances")) {
      return { rows: [{ available: this.available }], rowCount: 1 }
    }
    if (text.includes("from finance.limits")) {
      return { rows: this.limitRows, rowCount: this.limitRows.length }
    }

    return { rows: [], rowCount: 0 }
  }

  readonly client = { query: this.query }
}

function serviceWith(transaction: FakeTransaction): FinanceLimitService {
  const database = {
    withTransaction: async (
      _options: unknown,
      work: (context: FakeTransaction) => Promise<unknown>,
    ) => work(transaction),
  } as unknown as DatabaseService
  return new FinanceLimitService(database)
}

const requestContext = {
  audience: "control" as const,
  environment: "test" as const,
}

function setInput(
  overrides: Partial<SetFinanceLimitInput> = {},
): SetFinanceLimitInput {
  return {
    actorAccountId: randomUUID(),
    actorUserId: randomUUID(),
    tier: "tier_1",
    limitType: "deposit",
    period: "daily",
    currency: "NGN",
    amount: "1000",
    reason: "configure the launch limit",
    context: requestContext,
    ...overrides,
  }
}

describe("finance limit service", () => {
  it("adds an effective-dated limit and audits the reason", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    const result = await service.setLimit(setInput())

    expect(result.tier).toBe("tier_1")
    expect(result.amount).toBe("1000.0000")
    const insert = transaction.calls.find((call) =>
      call.text.startsWith("insert into finance.limits"),
    )
    expect(insert?.values?.[0]).toBe("tier_1")
    expect(insert?.values?.[4]).toBe("1000.0000")
    const audit = transaction.calls.find((call) =>
      call.text.includes("insert into platform.audit_log"),
    )
    expect(audit?.values?.[4]).toBe("finance.limit_created")
  })

  it("refuses a configuration writer without the permission", async () => {
    const transaction = new FakeTransaction()
    transaction.permission = false
    const service = serviceWith(transaction)

    await expect(service.setLimit(setInput())).rejects.toMatchObject({
      code: "FORBIDDEN",
      statusCode: 403,
    })
    expect(
      transaction.calls.some((call) =>
        call.text.startsWith("insert into finance.limits"),
      ),
    ).toBe(false)
  })

  it("refuses a mixed scope, a bad amount or a missing reason", async () => {
    const service = serviceWith(new FakeTransaction())

    await expect(
      service.setLimit(
        setInput({ targetAccountId: randomUUID(), tier: "tier_1" }),
      ),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
    await expect(
      service.setLimit(setInput({ amount: "1.00001" })),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
    await expect(
      service.setLimit(setInput({ reason: "no" })),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
  })

  it("denies tier_0 and an unset limit with stable codes", async () => {
    const tierZero = new FakeTransaction()
    await expect(
      serviceWith(tierZero).check({
        accountId: randomUUID(),
        userId: randomUUID(),
        tier: "tier_0",
        limitType: "deposit",
        currency: "NGN",
        amount: "10",
        direction: "in",
      }),
    ).rejects.toMatchObject({ code: "KYC_REQUIRED", statusCode: 403 })

    const unset = new FakeTransaction()
    unset.limitRows = []
    await expect(
      serviceWith(unset).check({
        accountId: randomUUID(),
        userId: randomUUID(),
        tier: "tier_1",
        limitType: "deposit",
        currency: "NGN",
        amount: "10",
        direction: "in",
      }),
    ).rejects.toMatchObject({ code: "LIMIT_EXCEEDED", statusCode: 403 })
  })

  it("allows within the limit and denies above it", async () => {
    const transaction = new FakeTransaction()
    transaction.limitRows = [row({ amount: "100.0000" })]
    const service = serviceWith(transaction)
    const base = {
      accountId: randomUUID(),
      userId: randomUUID(),
      tier: "tier_1",
      limitType: "deposit",
      currency: "NGN",
      direction: "in" as const,
    }

    await expect(
      service.check({ ...base, amount: "100" }),
    ).resolves.toBeUndefined()

    await expect(
      service.check({ ...base, amount: "100.0001" }),
    ).rejects.toMatchObject({ code: "LIMIT_EXCEEDED" })
  })

  it("includes usage already recorded in the period", async () => {
    const transaction = new FakeTransaction()
    transaction.limitRows = [row({ period: "daily", amount: "100.0000" })]
    transaction.usedAmount = "90.0000"
    const service = serviceWith(transaction)

    await expect(
      service.check({
        accountId: randomUUID(),
        userId: randomUUID(),
        tier: "tier_1",
        limitType: "deposit",
        currency: "NGN",
        amount: "11",
        direction: "in",
      }),
    ).rejects.toMatchObject({ code: "LIMIT_EXCEEDED" })
  })

  it("checks a wallet balance cap in the write direction", async () => {
    const transaction = new FakeTransaction()
    transaction.limitRows = [
      row({
        limit_type: "wallet_balance",
        period: "per_transaction",
        amount: "500.0000",
      }),
    ]
    transaction.available = "450.0000"
    const service = serviceWith(transaction)
    const base = {
      accountId: randomUUID(),
      userId: randomUUID(),
      tier: "tier_1",
      limitType: "wallet_balance",
      currency: "NGN",
      amount: "60",
    }

    await expect(
      service.check({ ...base, direction: "in" }),
    ).rejects.toMatchObject({ code: "LIMIT_EXCEEDED" })
    await expect(
      service.check({ ...base, direction: "out" }),
    ).resolves.toBeUndefined()
  })
})
