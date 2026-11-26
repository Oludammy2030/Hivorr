import { Inject, Injectable } from "@nestjs/common"
import {
  currencyCodeSchema,
  minorUnitsToMoney,
  moneyToMinorUnits,
} from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import { IdentityService, type RequestContext } from "../identity"
import { appendAudit } from "../platform"
import { FinanceLimitService } from "./limit.service"
import { FINANCIALLY_ELIGIBLE_TIERS } from "./limits"

/**
 * Deposit eligibility and the KYC-upgrade hold (EP-02-014 / EP-02-053).
 *
 * CBN sets a maximum single deposit per tier (Level 1: NGN 20,000; Level 2:
 * NGN 50,000; Level 3: no cap). When a deposit would exceed the account's tier
 * cap, the deposit is refused, the account is put on a `kyc_upgrade_required`
 * hold, and every fund transaction is blocked until a verifier upgrades the
 * tier. The hold is cleared by `identity.set_kyc_tier`.
 *
 * Deposits arrive from the bank, so "refused" means Hivorr does not credit the
 * wallet; the collection account and reconciliation must handle the unmatched
 * credit. This service is the gate the deposit-posting path must call.
 */
export type DepositBlockReason = "kyc_upgrade_required" | "kyc_required" | "not_configured"

export interface DepositCheckInput {
  readonly accountId: string
  readonly userId: string
  readonly tier?: string | null
  readonly amount: string
  readonly currency: string
  readonly context: RequestContext
}

export interface DepositDecision {
  readonly allowed: boolean
  readonly reason: "within_limit" | DepositBlockReason
  readonly cap: string | null
}

@Injectable()
export class DepositEligibilityService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(FinanceLimitService) private readonly limits: FinanceLimitService,
    @Inject(IdentityService) private readonly identity: IdentityService,
  ) {}

  /** Evaluates a deposit without throwing; the caller maps the reason. */
  async check(input: DepositCheckInput): Promise<DepositDecision> {
    const tier = input.tier ?? "tier_0"
    if (!FINANCIALLY_ELIGIBLE_TIERS.has(tier)) {
      return { allowed: false, reason: "kyc_required", cap: null }
    }

    const amountMinor = moneyToMinorUnits(input.amount)
    if (amountMinor === null) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A deposit amount must be a positive numeric(20,4) value.",
        400,
      )
    }
    if (!currencyCodeSchema.safeParse(input.currency).success) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A deposit currency must be an ISO-4217-shaped code.",
        400,
      )
    }

    return this.database.withTransaction(
      { identity: { accountId: input.accountId, userId: input.userId } },
      async (transaction) => {
        const hold = await this.identity.readFinancialHoldInTransaction(
          transaction,
          input.accountId,
        )
        if (hold) {
          return {
            allowed: false,
            reason: "kyc_upgrade_required",
            cap: null,
          }
        }

        const decision = await this.limits.evaluateWithin(transaction, {
          accountId: input.accountId,
          userId: input.userId,
          tier,
          limitType: "deposit",
          currency: input.currency,
          amount: minorUnitsToMoney(amountMinor),
          direction: "in",
        })

        if (decision.allowed) {
          return {
            allowed: true,
            reason: "within_limit",
            cap: decision.rule.isUnlimited
              ? null
              : minorUnitsToMoney(decision.rule.amountMinor),
          }
        }

        if (decision.reason === "kyc_required") {
          return { allowed: false, reason: "kyc_required", cap: null }
        }
        if (decision.reason === "not_configured") {
          return { allowed: false, reason: "not_configured", cap: null }
        }

        const cap = decision.rule
          ? minorUnitsToMoney(decision.rule.amountMinor)
          : null
        await this.identity.holdForKycUpgradeInTransaction(
          transaction,
          input.accountId,
        )
        await appendAudit(transaction.client, {
          actorType: "user",
          actorId: input.userId,
          actorAudience: input.context.audience,
          environment: input.context.environment,
          action: "finance.deposit_blocked_kyc_upgrade",
          targetType: "account",
          targetId: input.accountId,
          afterSummary: {
            amount: minorUnitsToMoney(amountMinor),
            currency: input.currency,
            tier,
            cap,
            hold: "kyc_upgrade_required",
          },
          ip: input.context.ip,
          userAgent: input.context.userAgent,
          correlationId: input.context.correlationId,
        })
        return {
          allowed: false,
          reason: "kyc_upgrade_required",
          cap,
        }
      },
    )
  }

  /** Throws the stable error a deposit-posting caller should surface. */
  async assertAllowed(input: DepositCheckInput): Promise<void> {
    const decision = await this.check(input)
    if (decision.allowed) return
    if (decision.reason === "kyc_upgrade_required") {
      throw new ApiError(
        "KYC_REQUIRED",
        "This deposit exceeds your tier limit. Complete a KYC upgrade before further fund transactions.",
        403,
      )
    }
    if (decision.reason === "kyc_required") {
      throw new ApiError(
        "KYC_REQUIRED",
        "A deposit requires KYC tier_1 or above.",
        403,
      )
    }
    throw new ApiError(
      "LIMIT_EXCEEDED",
      "No deposit limit is configured for this tier.",
      403,
    )
  }
}
