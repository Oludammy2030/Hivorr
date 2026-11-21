/**
 * Financial limit resolution and evaluation (EP-02-035).
 *
 * Configuration holds the numbers; this module holds no threshold. It resolves
 * the effective rule for a tier or account override and decides whether a write
 * fits. `tier_1` is the only financially eligible tier in the approved shared
 * contract; the ladder above it is still open, so anything else is denied rather
 * than guessed.
 *
 * The caller performs the check inside the same transaction as the write. The
 * database still owns the effective-dated rows and the permission to add one.
 */
export const FINANCE_LIMIT_TYPES = [
  "deposit",
  "withdrawal",
  "payout",
  "wallet_balance",
] as const

export type FinanceLimitType = typeof FINANCE_LIMIT_TYPES[number]

export const FINANCE_LIMIT_PERIODS = [
  "per_transaction",
  "daily",
  "weekly",
  "monthly",
] as const

export type FinanceLimitPeriod = typeof FINANCE_LIMIT_PERIODS[number]

/** The approved contract has exactly these tiers today. */
export const FINANCIALLY_ELIGIBLE_TIERS: ReadonlySet<string> = new Set([
  "tier_1",
])

export interface FinanceLimitRule {
  readonly id: string
  readonly tier: string | null
  readonly accountId: string | null
  readonly limitType: FinanceLimitType
  readonly period: FinanceLimitPeriod
  readonly currency: string
  readonly amountMinor: bigint
  readonly effectiveFrom: Date
  readonly effectiveTo: Date | null
}

export interface FinanceLimitSelection {
  readonly tier: string
  readonly accountId: string
  readonly limitType: string
  readonly currency: string
  readonly at: Date
}

function isLimitType(value: string): value is FinanceLimitType {
  return (FINANCE_LIMIT_TYPES as readonly string[]).includes(value)
}

/**
 * Returns the most specific effective rule: an account override beats a tier
 * rule, and the newest `effectiveFrom` beats an older one. A rule whose window
 * has not started or has ended is ignored.
 */
export function selectFinanceLimit(
  rules: readonly FinanceLimitRule[],
  input: FinanceLimitSelection,
): FinanceLimitRule | null {
  if (!isLimitType(input.limitType)) return null

  const candidates = rules.filter((rule) => {
    if (rule.currency !== input.currency) return false
    if (rule.limitType !== input.limitType) return false
    if (rule.accountId !== null) return rule.accountId === input.accountId
    return rule.tier === input.tier
  })

  const effective = candidates.filter(
    (rule) =>
      rule.effectiveFrom.getTime() <= input.at.getTime() &&
      (rule.effectiveTo === null ||
        rule.effectiveTo.getTime() > input.at.getTime()),
  )

  effective.sort((left, right) => {
    const leftSpecific = left.accountId !== null ? 1 : 0
    const rightSpecific = right.accountId !== null ? 1 : 0
    if (leftSpecific !== rightSpecific) return rightSpecific - leftSpecific
    const byFrom = right.effectiveFrom.getTime() - left.effectiveFrom.getTime()
    if (byFrom !== 0) return byFrom
    return left.id.localeCompare(right.id)
  })

  return effective[0] ?? null
}

export type FinanceLimitDenialReason = "kyc_required" | "not_configured" | "exceeded"

export type FinanceLimitDecision = {
  readonly allowed: true
  readonly rule: FinanceLimitRule
} | {
  readonly allowed: false
  readonly reason: FinanceLimitDenialReason
  readonly rule: FinanceLimitRule | null
}

export interface FinanceLimitEvaluation {
  readonly tier: string
  readonly rule: FinanceLimitRule | null
  readonly amountMinor: bigint
  /** Already counted in the same period; ignored for `per_transaction`. */
  readonly usedMinor?: bigint
  /** Required for a `wallet_balance` rule: the balance after the write. */
  readonly balanceAfterMinor?: bigint
}

export function evaluateFinanceLimit(
  input: FinanceLimitEvaluation,
): FinanceLimitDecision {
  if (!FINANCIALLY_ELIGIBLE_TIERS.has(input.tier)) {
    return { allowed: false, reason: "kyc_required", rule: input.rule }
  }

  if (!input.rule) {
    return { allowed: false, reason: "not_configured", rule: null }
  }

  if (input.rule.limitType === "wallet_balance") {
    if (input.balanceAfterMinor === undefined) {
      return { allowed: false, reason: "not_configured", rule: input.rule }
    }
    return input.balanceAfterMinor <= input.rule.amountMinor
      ? { allowed: true, rule: input.rule }
      : { allowed: false, reason: "exceeded", rule: input.rule }
  }

  const used = input.usedMinor ?? 0n
  return used + input.amountMinor <= input.rule.amountMinor
    ? { allowed: true, rule: input.rule }
    : { allowed: false, reason: "exceeded", rule: input.rule }
}

/** UTC period start; the ledger stores timestamps in UTC. */
export function financeLimitPeriodStart(
  period: FinanceLimitPeriod,
  at: Date,
): Date | null {
  if (period === "per_transaction") return null

  const start = new Date(
    Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), at.getUTCDate()),
  )

  if (period === "daily") return start

  if (period === "weekly") {
    const day = start.getUTCDay()
    const offset = day === 0 ? 6 : day - 1
    start.setUTCDate(start.getUTCDate() - offset)
    return start
  }

  start.setUTCDate(1)
  return start
}
