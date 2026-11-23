import { Inject, Injectable } from "@nestjs/common"
import {
  currencyCodeSchema,
  kycTierSchema,
  minorUnitsToMoney,
  moneyToMinorUnits,
} from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { TransactionContext } from "../../db/transaction"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"
import {
  FINANCE_LIMIT_PERIODS,
  FINANCE_LIMIT_TYPES,
  evaluateFinanceLimit,
  financeLimitPeriodStart,
  selectFinanceLimit,
  type FinanceLimitDecision,
  type FinanceLimitPeriod,
  type FinanceLimitRule,
  type FinanceLimitType,
} from "./limits"

/**
 * Financial limits and tier gating (EP-02-035).
 *
 * Configuration holds every number. `tier_0` (and a missing tier) is denied, a
 * `tier_1` write is allowed only inside an effective configured limit, and an
 * unset limit denies. The evaluation runs on the caller's transaction so the
 * check and the write share one snapshot; `EP-02-014` will supply the verified
 * tier at the session boundary.
 *
 * This task adds no money flow, so no endpoint calls the check yet.
 */
export interface SetFinanceLimitInput {
  readonly actorAccountId: string
  readonly actorUserId: string
  readonly tier?: string | null
  readonly targetAccountId?: string | null
  readonly limitType: string
  readonly period: string
  readonly currency: string
  readonly amount: string
  readonly isUnlimited?: boolean
  readonly effectiveFrom?: string | null
  readonly effectiveTo?: string | null
  readonly reason: string
  readonly context: RequestContext
}

export interface FinanceLimitCheckInput {
  readonly accountId: string
  readonly userId: string
  readonly tier?: string | null
  readonly limitType: string
  readonly currency: string
  readonly amount: string
  readonly direction: "in" | "out"
  readonly at?: string
}

export interface FinanceLimitView {
  readonly id: string
  readonly tier: string | null
  readonly accountId: string | null
  readonly limitType: string
  readonly period: string
  readonly currency: string
  readonly amount: string
  readonly isUnlimited: boolean
  readonly effectiveFrom: string
  readonly effectiveTo: string | null
  readonly createdAt: string
}

interface FinanceLimitRow {
  id: string
  tier: string | null
  account_id: string | null
  limit_type: string
  period: string
  currency: string
  amount: string
  is_unlimited: boolean
  effective_from: string
  effective_to: string | null
  created_at: string
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function parseLimitAmount(value: string): bigint | null {
  if (/^0(\.0{1,4})?$/.test(value)) return 0n
  return moneyToMinorUnits(value)
}

function toView(row: FinanceLimitRow): FinanceLimitView {
  return {
    id: row.id,
    tier: row.tier,
    accountId: row.account_id,
    limitType: row.limit_type,
    period: row.period,
    currency: row.currency,
    amount: row.amount,
    isUnlimited: row.is_unlimited === true,
    effectiveFrom: row.effective_from,
    effectiveTo: row.effective_to,
    createdAt: row.created_at,
  }
}

function toRule(row: FinanceLimitRow): FinanceLimitRule | null {
  const amountMinor = parseLimitAmount(row.amount)
  if (amountMinor === null) return null
  return {
    id: row.id,
    tier: row.tier,
    accountId: row.account_id,
    limitType: row.limit_type as FinanceLimitType,
    period: row.period as FinanceLimitPeriod,
    currency: row.currency,
    amountMinor,
    isUnlimited: row.is_unlimited === true,
    effectiveFrom: new Date(row.effective_from),
    effectiveTo: row.effective_to === null ? null : new Date(row.effective_to),
  }
}

function mapLimitError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to change financial limits.",
        403,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "A limit with the same scope, type and effective date already exists.",
        409,
      )
    case "23503":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The account or staff member does not exist.",
        400,
      )
    case "23514":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit does not satisfy its database constraints.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The financial limit operation failed.")
  }
}

function deny(decision: FinanceLimitDecision): never {
  if (decision.allowed) {
    throw new Error("A permitted decision cannot be denied.")
  }
  if (decision.reason === "kyc_required") {
    throw new ApiError(
      "KYC_REQUIRED",
      "This financial action requires KYC tier_1 or above.",
      403,
    )
  }
  if (decision.reason === "not_configured") {
    throw new ApiError(
      "LIMIT_EXCEEDED",
      "No financial limit is configured for this action.",
      403,
    )
  }
  throw new ApiError(
    "LIMIT_EXCEEDED",
    "This amount exceeds the configured financial limit.",
    403,
  )
}

@Injectable()
export class FinanceLimitService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  /** Lists limits; RLS shows tier rows and own overrides, and all rows to a writer. */
  async list(input: {
    accountId: string
    userId: string
  }): Promise<FinanceLimitView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<FinanceLimitRow>(
            `select id, tier, account_id, limit_type, period, currency,
                    amount::text as amount, is_unlimited,
                    effective_from, effective_to, created_at
               from finance.limits
              order by effective_from desc, id desc`,
          )
          return result.rows.map(toView)
        },
      )
    } catch (error) {
      mapLimitError(error)
    }
  }

  /** Adds an effective-dated limit. A change is a new row, never an update. */
  async setLimit(input: SetFinanceLimitInput): Promise<FinanceLimitView> {
    const tier = input.tier ?? null
    const targetAccountId = input.targetAccountId ?? null
    const hasTier = tier !== null
    const hasAccount = targetAccountId !== null

    if (hasTier === hasAccount) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A limit targets a tier or an account, never both.",
        400,
      )
    }
    if (hasTier && !kycTierSchema.safeParse(tier).success) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit names an unknown KYC tier.",
        400,
      )
    }
    if (hasAccount && !UUID_PATTERN.test(targetAccountId)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit names an invalid account.",
        400,
      )
    }
    if (!(FINANCE_LIMIT_TYPES as readonly string[]).includes(input.limitType)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit type is not defined.",
        400,
      )
    }
    if (!(FINANCE_LIMIT_PERIODS as readonly string[]).includes(input.period)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit period is not defined.",
        400,
      )
    }
    if (!currencyCodeSchema.safeParse(input.currency).success) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit currency must be an ISO-4217-shaped code.",
        400,
      )
    }
    const amountMinor = parseLimitAmount(input.amount)
    if (amountMinor === null || amountMinor < 0n) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit amount must be a non-negative numeric(20,4) value.",
        400,
      )
    }
    if (input.reason.trim().length < 5) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A limit change needs a reason of at least five characters.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        {
          identity: {
            accountId: input.actorAccountId,
            userId: input.actorUserId,
          },
        },
        async (transaction) => {
          const permission = await transaction.query<{ allowed: boolean }>(
            "select admin.actor_holds_platform_permission($1, $2) as allowed",
            [input.actorUserId, "admin.configuration.write"],
          )
          if (permission.rows[0]?.allowed !== true) {
            throw new ApiError(
              "FORBIDDEN",
              "You do not have permission to change financial limits.",
              403,
            )
          }

          const result = await transaction.query<FinanceLimitRow>(
            `insert into finance.limits
               (tier, account_id, limit_type, currency, amount, period,
                is_unlimited, effective_from, effective_to, created_by)
             values ($1, $2, $3, $4, $5::numeric, $6, $7,
                     coalesce($8::timestamptz, now()), $9::timestamptz, $10)
             returning id, tier, account_id, limit_type, period, currency,
                       amount::text as amount, is_unlimited, effective_from,
                       effective_to, created_at`,
            [
              input.tier ?? null,
              input.targetAccountId ?? null,
              input.limitType,
              input.currency,
              input.isUnlimited ? "0.0000" : minorUnitsToMoney(amountMinor),
              input.period,
              input.isUnlimited === true,
              input.effectiveFrom ?? null,
              input.effectiveTo ?? null,
              input.actorUserId,
            ],
          )
          const row = result.rows[0]
          if (!row) throw new Error("The limit insert returned no row.")
          const view = toView(row)

          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.actorUserId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "finance.limit_created",
            targetType: "finance_limit",
            targetId: view.id,
            afterSummary: {
              tier: view.tier,
              accountId: view.accountId,
              limitType: view.limitType,
              period: view.period,
              currency: view.currency,
              amount: view.amount,
              isUnlimited: view.isUnlimited,
              effectiveFrom: view.effectiveFrom,
              effectiveTo: view.effectiveTo,
            },
            reason: input.reason,
            capability: "admin.configuration.write",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })

          return view
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapLimitError(error)
    }
  }

  /**
   * Evaluates a financial write on the caller's transaction. The caller passes
   * the tier it resolved from the session; a missing tier is `tier_0`.
   */
  async assertWithin(
    transaction: TransactionContext,
    input: FinanceLimitCheckInput,
  ): Promise<void> {
    const decision = await this.evaluate(transaction, input)
    if (!decision.allowed) deny(decision)
  }

  /**
   * The decision without throwing, for a caller that must branch on the reason
   * (the deposit cap sets a KYC-upgrade hold instead of only denying).
   */
  async evaluateWithin(
    transaction: TransactionContext,
    input: FinanceLimitCheckInput,
  ): Promise<FinanceLimitDecision> {
    return this.evaluate(transaction, input)
  }

  /** Read-only check in its own transaction, for a preflight or a test. */
  async check(input: FinanceLimitCheckInput): Promise<void> {
    try {
      await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const decision = await this.evaluate(transaction, input)
          if (!decision.allowed) deny(decision)
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapLimitError(error)
    }
  }

  private async evaluate(
    transaction: TransactionContext,
    input: FinanceLimitCheckInput,
  ): Promise<FinanceLimitDecision> {
    const amountMinor = moneyToMinorUnits(input.amount)
    if (amountMinor === null) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A limited amount must be a positive numeric(20,4) value.",
        400,
      )
    }
    if (!currencyCodeSchema.safeParse(input.currency).success) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A limit currency must be an ISO-4217-shaped code.",
        400,
      )
    }
    if (!(FINANCE_LIMIT_TYPES as readonly string[]).includes(input.limitType)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit type is not defined.",
        400,
      )
    }

    const at = input.at ? new Date(input.at) : new Date()
    if (Number.isNaN(at.getTime())) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The limit check timestamp is not a date.",
        400,
      )
    }

    const tier = input.tier ?? "tier_0"
    const rules = await transaction.query<FinanceLimitRow>(
      `select id, tier, account_id, limit_type, period, currency,
              amount::text as amount, is_unlimited, effective_from,
              effective_to, created_at
         from finance.limits
        where currency = $1
          and limit_type = $2
          and (tier = $3 or account_id = $4)`,
      [input.currency, input.limitType, tier, input.accountId],
    )

    const rule = selectFinanceLimit(
      rules.rows.flatMap((row) => {
        const parsed = toRule(row)
        return parsed ? [parsed] : []
      }),
      {
        tier,
        accountId: input.accountId,
        limitType: input.limitType,
        currency: input.currency,
        at,
      },
    )

    if (!rule) {
      return evaluateFinanceLimit({
        tier,
        rule: null,
        amountMinor,
      })
    }

    if (rule.limitType === "wallet_balance") {
      const balance = await transaction.query<{ available: string }>(
        `select available::text as available
           from finance.wallet_balances
          where account_id = $1 and currency = $2`,
        [input.accountId, input.currency],
      )
      const available = parseLimitAmount(balance.rows[0]?.available ?? "0.0000")
      const current = available ?? 0n
      const after =
        input.direction === "in" ? current + amountMinor : current - amountMinor
      return evaluateFinanceLimit({
        tier,
        rule,
        amountMinor,
        balanceAfterMinor: after,
      })
    }

    const start = financeLimitPeriodStart(rule.period, at)
    let usedMinor = 0n
    if (start) {
      const used = await transaction.query<{ used: string }>(
        `select coalesce(sum(p.amount), 0)::text as used
           from finance.postings p
           join finance.journal_entries je on je.id = p.entry_id
           join finance.ledger_accounts la on la.id = p.ledger_account_id
          where la.owner_type = 'account'
            and la.owner_id = $1
            and la.kind = 'user_wallet'
            and la.currency = $2
            and p.currency = $2
            and p.created_at >= $3
            and (
              ($4 = 'deposit' and je.kind = 'deposit' and p.direction = 'debit')
              or (
                $4 in ('withdrawal', 'payout')
                and je.kind in ('withdrawal', 'payout')
                and p.direction = 'credit'
              )
            )`,
        [input.accountId, input.currency, start.toISOString(), input.limitType],
      )
      usedMinor = parseLimitAmount(used.rows[0]?.used ?? "0.0000") ?? 0n
    }

    return evaluateFinanceLimit({
      tier,
      rule,
      amountMinor,
      usedMinor,
    })
  }
}
