import { Inject, Injectable } from "@nestjs/common"
import {
  currencyCodeSchema,
  evaluateEscrowTransition,
  type EscrowState,
} from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import { appendAudit } from "../platform"
import type { LedgerPostingContext } from "./ledger.service"

/**
 * Escrow reservation lifecycle (EP-02-033).
 *
 * Opening a reservation creates its escrow ledger account and its metadata in
 * one transaction. The only enabled transition is `held -> disputed`; release,
 * refund and cancellation are defined but disabled until BD-D03 is decided.
 * The service refuses them, and the database trigger from
 * `20261118000400_finance_add_escrow_lifecycle.sql` refuses them again.
 *
 * This service does not post money. The hold, release and refund postings
 * belong to the money-flow tasks (`EP-02-052`/`053`), which remain blocked on
 * the decisions they depend on.
 */
export type EscrowWriteContext = LedgerPostingContext

export interface OpenEscrowInput {
  readonly activityId: string
  readonly activityRef: string
  readonly currency: string
}

export interface EscrowTransitionInput {
  readonly escrowId: string
  readonly toState: string
  readonly reason?: string
}

export interface EscrowView {
  readonly id: string
  readonly ledgerAccountId: string
  readonly payerAccountId: string
  readonly activityId: string
  readonly activityRef: string
  readonly currency: string
  readonly state: EscrowState
  readonly createdAt: string
  readonly updatedAt: string
  readonly resolvedAt: string | null
}

interface EscrowRow {
  id: string
  ledger_account_id: string
  payer_account_id: string
  activity_id: string
  activity_ref: string
  currency: string
  state: string
  created_at: string | Date
  updated_at: string | Date
  resolved_at: string | Date | null
}

export const ESCROW_ACTIVITIES = [
  "market.buy",
  "services.hire",
  "errands.request",
] as const

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const TERMINAL_STATES = new Set(["released", "refunded", "cancelled"])

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : value
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function messageOf(error: unknown): string | undefined {
  return error instanceof Error ? error.message : undefined
}

function toView(row: EscrowRow): EscrowView {
  return {
    id: row.id,
    ledgerAccountId: row.ledger_account_id,
    payerAccountId: row.payer_account_id,
    activityId: row.activity_id,
    activityRef: row.activity_ref,
    currency: row.currency,
    state: row.state as EscrowState,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    resolvedAt: row.resolved_at === null ? null : toIso(row.resolved_at),
  }
}

function validateOpenInput(input: OpenEscrowInput): OpenEscrowInput {
  if (!(ESCROW_ACTIVITIES as readonly string[]).includes(input.activityId)) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "Escrow is reserved against Buy, Hire or Errand.",
      400,
    )
  }
  if (!UUID_PATTERN.test(input.activityRef)) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "An escrow reference must name the activity record.",
      400,
    )
  }
  if (!currencyCodeSchema.safeParse(input.currency).success) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "An escrow currency must be an ISO-4217-shaped code.",
      400,
    )
  }
  return input
}

function mapEscrowError(error: unknown): never {
  const message = messageOf(error)
  if (message?.includes("escrow_transition_disabled")) {
    throw new ApiError(
      "CONFLICT",
      "Escrow release, refund and cancellation are disabled until BD-D03 is decided.",
      409,
    )
  }
  if (message?.includes("escrow_transition_invalid")) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "That escrow state transition is not defined.",
      400,
    )
  }
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to change this escrow.",
        403,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "An escrow reservation already exists for this activity and currency.",
        409,
      )
    case "23514":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The escrow change is not valid for this reservation.",
        400,
      )
    case "23503":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The account or activity record does not exist.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The escrow operation failed.")
  }
}

@Injectable()
export class EscrowService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  /** Creates the escrow ledger account and its held reservation together. */
  async openEscrow(
    input: OpenEscrowInput,
    context: EscrowWriteContext,
  ): Promise<EscrowView> {
    const validated = validateOpenInput(input)

    try {
      return await this.database.withTransaction(
        {
          identity: {
            accountId: context.accountId,
            userId: context.userId,
          },
        },
        async (transaction) => {
          const ledger = await transaction.query<{ id: string }>(
            `insert into finance.ledger_accounts
               (kind, owner_type, owner_id, currency)
             values ('escrow', 'activity', $1, $2)
             returning id`,
            [validated.activityRef, validated.currency],
          )
          const ledgerAccountId = ledger.rows[0]?.id
          if (!ledgerAccountId) {
            throw new Error("The escrow ledger account insert returned no row.")
          }

          const escrow = await transaction.query<EscrowRow>(
            `insert into finance.escrow_accounts
               (ledger_account_id, payer_account_id, activity_id,
                activity_ref, currency)
             values ($1, $2, $3, $4, $5)
             returning id, ledger_account_id, payer_account_id, activity_id,
                       activity_ref, currency, state, created_at, updated_at,
                       resolved_at`,
            [
              ledgerAccountId,
              context.accountId,
              validated.activityId,
              validated.activityRef,
              validated.currency,
            ],
          )
          const row = escrow.rows[0]
          if (!row) {
            throw new Error("The escrow insert returned no row.")
          }

          const view = toView(row)
          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: context.userId,
            actorAudience: context.audience,
            environment: context.environment,
            action: "finance.escrow_opened",
            targetType: "escrow_account",
            targetId: view.id,
            afterSummary: {
              activityId: view.activityId,
              activityRef: view.activityRef,
              currency: view.currency,
              state: view.state,
            },
            ip: context.ip,
            userAgent: context.userAgent,
            correlationId: context.correlationId,
          })
          return view
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapEscrowError(error)
    }
  }

  /**
   * Applies one defined transition. A disabled transition is a conflict, not a
   * validation error: the request is well formed but the policy is not approved.
   */
  async transition(
    input: EscrowTransitionInput,
    context: EscrowWriteContext,
  ): Promise<EscrowView> {
    if (!UUID_PATTERN.test(input.escrowId)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The escrow reservation was not found.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        {
          identity: {
            accountId: context.accountId,
            userId: context.userId,
          },
        },
        async (transaction) => {
          const current = await transaction.query<EscrowRow>(
            `select id, ledger_account_id, payer_account_id, activity_id,
                    activity_ref, currency, state, created_at, updated_at,
                    resolved_at
               from finance.escrow_accounts
              where id = $1
              for update`,
            [input.escrowId],
          )
          const existing = current.rows[0]
          if (!existing) {
            throw new ApiError(
              "NOT_FOUND",
              "The escrow reservation was not found.",
              404,
            )
          }

          const evaluation = evaluateEscrowTransition(
            existing.state,
            input.toState,
          )
          if (evaluation.status === "disabled") {
            throw new ApiError(
              "CONFLICT",
              "Escrow release, refund and cancellation are disabled until BD-D03 is decided.",
              409,
            )
          }
          if (evaluation.status === "invalid") {
            throw new ApiError(
              "VALIDATION_FAILED",
              "That escrow state transition is not defined.",
              400,
            )
          }

          const updated = await transaction.query<EscrowRow>(
            `update finance.escrow_accounts
                set state = $2,
                    resolved_at = case
                      when $2 = any (array['released', 'refunded', 'cancelled'])
                        then now()
                      else resolved_at
                    end
              where id = $1
              returning id, ledger_account_id, payer_account_id, activity_id,
                        activity_ref, currency, state, created_at, updated_at,
                        resolved_at`,
            [input.escrowId, input.toState],
          )
          const row = updated.rows[0]
          if (!row) {
            throw new Error("The escrow update returned no row.")
          }

          const view = toView(row)
          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: context.userId,
            actorAudience: context.audience,
            environment: context.environment,
            action: "finance.escrow_state_changed",
            targetType: "escrow_account",
            targetId: view.id,
            beforeSummary: { state: existing.state },
            afterSummary: {
              state: view.state,
              terminal: TERMINAL_STATES.has(view.state),
            },
            reason: input.reason,
            ip: context.ip,
            userAgent: context.userAgent,
            correlationId: context.correlationId,
          })
          return view
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapEscrowError(error)
    }
  }
}
