import { describe, expect, it } from "vitest"

import { DepositEligibilityService } from "../server/src/modules/finance/deposit-eligibility.service"
import type { FinanceLimitDecision, FinanceLimitRule } from "../server/src/modules/finance/limits"

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111"
const USER_ID = "22222222-2222-4222-8222-222222222222"

const context = {
  audience: "main" as const,
  environment: "test" as const,
  correlationId: "corr-1",
}

interface QueryCall {
  readonly text: string
  readonly values?: readonly unknown[]
}

function rule(overrides: Partial<FinanceLimitRule> = {}): FinanceLimitRule {
  return {
    id: "limit-1",
    tier: "tier_1",
    accountId: null,
    limitType: "deposit",
    period: "per_transaction",
    currency: "NGN",
    amountMinor: 200000000n,
    isUnlimited: false,
    effectiveFrom: new Date("2026-11-23T00:00:00.000Z"),
    effectiveTo: null,
    ...overrides,
  }
}

function harness(
  options: {
    readonly hold?: string | null
    readonly decision?: FinanceLimitDecision
  } = {},
) {
  const audits: unknown[][] = []
  const updates: QueryCall[] = []
  const limitCalls: unknown[] = []

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
      if (text.includes("select financial_hold_reason")) {
        return { rows: [{ financial_hold_reason: options.hold ?? null }] }
      }
      if (text.includes("update identity.accounts")) {
        updates.push({ text, values })
        return { rows: [], rowCount: 1 }
      }
      throw new Error(`unexpected query: ${text}`)
    },
  }

  const database = {
    async withTransaction(_options: unknown, work: (tx: unknown) => Promise<unknown>) {
      return work(transaction)
    },
  }

  const limits = {
    async evaluateWithin(_transaction: unknown, input: unknown) {
      limitCalls.push(input)
      return (
        options.decision ?? {
          allowed: true,
          rule: rule(),
        }
      )
    },
  }

  const identity = {
    async readFinancialHoldInTransaction() {
      return options.hold ?? null
    },
    async holdForKycUpgradeInTransaction() {
      updates.push({ text: "financial_hold_reason" })
    },
  }

  const service = new DepositEligibilityService(
    database as never,
    limits as never,
    identity as never,
  )

  return { service, audits, updates, limitCalls }
}

function input(overrides: Record<string, unknown> = {}) {
  return {
    accountId: ACCOUNT_ID,
    userId: USER_ID,
    tier: "tier_1",
    amount: "20000.0000",
    currency: "NGN",
    context,
    ...overrides,
  }
}

describe("deposit eligibility", () => {
  it("allows a deposit within the tier cap", async () => {
    const test = harness()
    const decision = await test.service.check(input())

    expect(decision).toEqual({
      allowed: true,
      reason: "within_limit",
      cap: "20000.0000",
    })
    expect(test.updates).toHaveLength(0)
    expect(test.audits).toHaveLength(0)
  })

  it("allows an unlimited tier_3 deposit", async () => {
    const test = harness({
      decision: {
        allowed: true,
        rule: rule({ tier: "tier_3", isUnlimited: true }),
      },
    })
    const decision = await test.service.check(input({ tier: "tier_3" }))

    expect(decision).toEqual({
      allowed: true,
      reason: "within_limit",
      cap: null,
    })
  })

  it("sets the KYC-upgrade hold when the cap is exceeded", async () => {
    const test = harness({
      decision: { allowed: false, reason: "exceeded", rule: rule() },
    })
    const decision = await test.service.check(input({ amount: "25000.0000" }))

    expect(decision).toEqual({
      allowed: false,
      reason: "kyc_upgrade_required",
      cap: "20000.0000",
    })
    expect(test.updates).toHaveLength(1)
    expect(test.updates[0]?.text).toContain("financial_hold_reason")
    expect(test.audits).toHaveLength(1)
    expect(JSON.stringify(test.audits[0])).toContain("finance.deposit_blocked_kyc_upgrade")
  })

  it("throws the KYC_REQUIRED denial from the assertion path", async () => {
    const test = harness({
      decision: { allowed: false, reason: "exceeded", rule: rule() },
    })

    await expect(test.service.assertAllowed(input({ amount: "25000.0000" }))).rejects.toMatchObject(
      { code: "KYC_REQUIRED", statusCode: 403 },
    )
  })

  it("refuses a deposit while the account is already held", async () => {
    const test = harness({ hold: "kyc_upgrade_required" })
    const decision = await test.service.check(input())

    expect(decision.reason).toBe("kyc_upgrade_required")
    expect(test.limitCalls).toHaveLength(0)
  })

  it("refuses tier_0 before evaluating a limit", async () => {
    const test = harness()
    const decision = await test.service.check(input({ tier: "tier_0" }))

    expect(decision.reason).toBe("kyc_required")
    expect(test.limitCalls).toHaveLength(0)
  })

  it("fails closed when no deposit limit is configured", async () => {
    const test = harness({
      decision: { allowed: false, reason: "not_configured", rule: null },
    })
    const decision = await test.service.check(input())

    expect(decision.reason).toBe("not_configured")
    await expect(test.service.assertAllowed(input())).rejects.toMatchObject({
      code: "LIMIT_EXCEEDED",
    })
  })

  it("rejects a malformed amount", async () => {
    const test = harness()

    await expect(test.service.check(input({ amount: "0.0000" }))).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
  })
})
