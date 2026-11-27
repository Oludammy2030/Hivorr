import { Inject, Injectable } from "@nestjs/common"

import { currencyCodeSchema, minorUnitsToMoney, moneyToMinorUnits } from "@hivorr/shared"

import { ApiError } from "../../common/errors"

import { DatabaseService } from "../../db/database.service"

import { IdentityService, type RequestContext } from "../identity"

import { appendAudit } from "../platform"

import { FinanceLimitService } from "./limit.service"

import { FINANCIALLY_ELIGIBLE_TIERS } from "./limits"

/**
 * Payout request and eligibility (EP-02-053, first increment).
 *
 * The permission matrix makes a wallet withdrawal automatic once the account is
 * `tier_1`, the destination is bound and verified, the configured limit is met
 * and the available balance covers the amount. Manual payouts are the only ones
 * that require a second human, so maker-checker is not applied here.
 *
 * This increment creates the durable request row and audits it. It does not
 * reserve funds, call a provider or transition the status: execution and the
 * manual path land in later increments, through security-definer functions.
 */

export interface RequestPayoutInput {
  readonly accountId: string

  readonly userId: string

  readonly tier?: string | null

  readonly payoutAccountId: string

  readonly amount: string

  readonly currency: string

  readonly idempotencyKey: string

  readonly context: RequestContext
}

export interface PayoutRequestView {
  readonly id: string

  readonly reference: string

  readonly payoutAccountId: string

  /** The only account-number material a projection may carry. */

  readonly accountNumberLast4: string

  readonly amount: string

  readonly currency: string

  readonly status: string

  readonly provider: string | null

  readonly providerReference: string | null

  readonly failureCode: string | null

  readonly createdAt: string

  readonly completedAt: string | null
}

export interface PayoutRequestRow {
  id: string

  reference: string

  payout_account_id: string

  account_number_last4: string

  amount: string

  currency: string

  status: string

  provider: string | null

  provider_reference: string | null

  failure_code: string | null

  created_at: string | Date

  completed_at: string | Date | null
}

interface PayoutAccountRow {
  id: string

  status: string

  account_number_last4: string
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const PAYOUT_CURRENCY = "NGN"

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : value
}

export function payoutRequestToView(row: PayoutRequestRow): PayoutRequestView {
  return {
    id: row.id,

    reference: row.reference,

    payoutAccountId: row.payout_account_id,

    accountNumberLast4: row.account_number_last4,

    amount: row.amount,

    currency: row.currency,

    status: row.status,

    provider: row.provider,

    providerReference: row.provider_reference,

    failureCode: row.failure_code,

    createdAt: toIso(row.created_at),

    completedAt: row.completed_at === null ? null : toIso(row.completed_at),
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code

    return typeof value === "string" ? value : undefined
  }

  return undefined
}

function mapRequestError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",

        "You do not have permission to request a payout.",

        403,
      )

    case "23505":
      throw new ApiError(
        "CONFLICT",

        "That idempotency key already describes a different payout request.",

        409,
      )

    case "23503":
      throw new ApiError(
        "VALIDATION_FAILED",

        "The account, user or payout destination does not exist.",

        400,
      )

    case "23514":
      throw new ApiError(
        "VALIDATION_FAILED",

        "The payout request does not satisfy its database constraints.",

        400,
      )

    default:
      throw error instanceof Error ? error : new Error("The payout request operation failed.")
  }
}

function parseAvailable(value: string | undefined): bigint {
  if (!value || /^0(\.0{1,4})?$/.test(value)) return 0n

  return moneyToMinorUnits(value) ?? 0n
}

@Injectable()
export class PayoutRequestService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,

    @Inject(FinanceLimitService)
    private readonly limits: FinanceLimitService,
    @Inject(IdentityService) private readonly identity: IdentityService,
  ) {}

  /** Lists the caller's payout requests without any bank-detail material. */

  async list(input: {
    accountId: string

    userId: string
  }): Promise<PayoutRequestView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },

        async (transaction) => {
          const result = await transaction.query<PayoutRequestRow>(
            `select pr.id, pr.reference, pr.payout_account_id,
                    pa.account_number_last4, pr.amount::text as amount,
                    pr.currency, pr.status, pr.provider,
                    pr.provider_reference, pr.failure_code,
                    pr.created_at, pr.completed_at
               from finance.payout_requests pr
               join finance.payout_accounts pa on pa.id = pr.payout_account_id
              where pr.account_id = $1
              order by pr.created_at desc, pr.id desc`,

            [input.accountId],
          )

          return result.rows.map(payoutRequestToView)
        },
      )
    } catch (error) {
      mapRequestError(error)
    }
  }

  /**
   * Creates a payout request after every eligibility check. A missing tier,
   * unbound or unverified destination, unmet limit, insufficient balance or
   * non-NGN currency is refused before a row is written.
   */

  async request(input: RequestPayoutInput): Promise<PayoutRequestView> {
    const tier = input.tier ?? "tier_0"

    if (!FINANCIALLY_ELIGIBLE_TIERS.has(tier)) {
      throw new ApiError(
        "KYC_REQUIRED",

        "A payout requires KYC tier_1 or above.",

        403,
      )
    }

    if (!UUID_PATTERN.test(input.payoutAccountId)) {
      throw new ApiError(
        "VALIDATION_FAILED",

        "The payout destination identifier is invalid.",

        400,
      )
    }

    const amountMinor = moneyToMinorUnits(input.amount)

    if (amountMinor === null) {
      throw new ApiError(
        "VALIDATION_FAILED",

        "A payout amount must be a positive numeric(20,4) value.",

        400,
      )
    }

    const amount = minorUnitsToMoney(amountMinor)

    if (!currencyCodeSchema.safeParse(input.currency).success) {
      throw new ApiError(
        "VALIDATION_FAILED",

        "A payout currency must be an ISO-4217-shaped code.",

        400,
      )
    }

    if (input.currency !== PAYOUT_CURRENCY) {
      throw new ApiError(
        "VALIDATION_FAILED",

        "A payout is currently NGN only.",

        400,
      )
    }

    const idempotencyKey = input.idempotencyKey.trim()

    if (idempotencyKey.length < 8 || idempotencyKey.length > 200) {
      throw new ApiError(
        "VALIDATION_FAILED",

        "A payout idempotency key is 8 to 200 characters.",

        400,
      )
    }

    try {
      return await this.database.withTransaction(
        {
          identity: { accountId: input.accountId, userId: input.userId },
        },

        async (transaction) => {
          const hold = await this.identity.readFinancialHoldInTransaction(
            transaction,
            input.accountId,
          )
          if (hold) {
            throw new ApiError(
              "KYC_REQUIRED",
              "A deposit above your tier limit requires a KYC upgrade before further fund transactions.",
              403,
            )
          }

          const existing = await transaction.query<PayoutRequestRow>(
            `select pr.id, pr.reference, pr.payout_account_id,
                    pa.account_number_last4, pr.amount::text as amount,
                    pr.currency, pr.status, pr.provider,
                    pr.provider_reference, pr.failure_code,
                    pr.created_at, pr.completed_at
               from finance.payout_requests pr
               join finance.payout_accounts pa on pa.id = pr.payout_account_id
              where pr.account_id = $1 and pr.idempotency_key = $2`,

            [input.accountId, idempotencyKey],
          )

          const replayed = existing.rows[0]

          if (replayed) {
            if (
              replayed.payout_account_id !== input.payoutAccountId ||
              replayed.amount !== amount ||
              replayed.currency !== input.currency
            ) {
              throw new ApiError(
                "CONFLICT",

                "That idempotency key already describes a different payout request.",

                409,
              )
            }

            return payoutRequestToView(replayed)
          }

          const destination = await transaction.query<PayoutAccountRow>(
            `select id, status, account_number_last4
               from finance.payout_accounts
              where id = $1 and account_id = $2`,

            [input.payoutAccountId, input.accountId],
          )

          const account = destination.rows[0]

          if (!account || account.status !== "verified") {
            throw new ApiError(
              "PAYOUT_ACCOUNT_REQUIRED",

              "Bind and verify a payout destination before requesting a payout.",

              403,
            )
          }

          await this.limits.assertWithin(transaction, {
            accountId: input.accountId,

            userId: input.userId,

            tier,

            limitType: "withdrawal",

            currency: input.currency,

            amount,

            direction: "out",
          })

          const balance = await transaction.query<{ available: string }>(
            `select available::text as available
               from finance.wallet_balances
              where account_id = $1 and currency = $2`,

            [input.accountId, input.currency],
          )

          const available = parseAvailable(balance.rows[0]?.available)

          if (available < amountMinor) {
            throw new ApiError(
              "INSUFFICIENT_FUNDS",

              "The available balance does not cover this payout.",

              409,
            )
          }

          const generated = await transaction.query<{ id: string }>(
            "select platform.uuidv7() as id",
          )

          const id = generated.rows[0]?.id

          if (!id) {
            throw new Error("The payout request identifier was not generated.")
          }

          const reference = `PAY-${id.replace(/-/g, "").slice(0, 20).toUpperCase()}`

          const inserted = await transaction.query<PayoutRequestRow>(
            `insert into finance.payout_requests
               (id, reference, account_id, payout_account_id, amount, currency,
                status, idempotency_key, requested_by)
             values ($1, $2, $3, $4, $5::numeric, $6, 'REQUESTED', $7, $8)
             returning id, reference, payout_account_id,
                       amount::text as amount, currency, status, provider,
                       provider_reference, failure_code, created_at, completed_at`,

            [
              id,

              reference,

              input.accountId,

              input.payoutAccountId,

              amount,

              input.currency,

              idempotencyKey,

              input.userId,
            ],
          )

          const insertedRow = inserted.rows[0]

          if (!insertedRow) {
            throw new Error("The payout request insert returned no row.")
          }

          const view = payoutRequestToView({
            ...insertedRow,

            account_number_last4: account.account_number_last4,
          })

          await appendAudit(transaction.client, {
            actorType: "user",

            actorId: input.userId,

            actorAudience: input.context.audience,

            environment: input.context.environment,

            action: "finance.payout_requested",

            targetType: "payout_request",

            targetId: view.id,

            afterSummary: {
              reference: view.reference,

              payoutAccountId: view.payoutAccountId,

              accountNumberLast4: view.accountNumberLast4,

              amount: view.amount,

              currency: view.currency,

              status: view.status,
            },

            ip: input.context.ip,

            userAgent: input.context.userAgent,

            correlationId: input.context.correlationId,
          })

          return view
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error

      mapRequestError(error)
    }
  }
}
