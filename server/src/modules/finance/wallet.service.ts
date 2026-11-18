import { Inject, Injectable } from "@nestjs/common"
import {
  activityIdSchema,
  currencyCodeSchema,
  type WalletBalanceView,
  type WalletStatementEntry,
} from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"

/**
 * Wallet read model (EP-02-032).
 *
 * The figures come from `finance.wallet_balances`, which is a `security_invoker`
 * view over the append-only postings. There is no balance column and no write
 * method: a wallet changes only when the posting engine records an entry.
 *
 * The caller never supplies the account: it comes from the authenticated
 * session, and the transaction identity makes RLS filter the view a second
 * time.
 */
export interface WalletReadContext {
  readonly accountId: string
  readonly userId: string
}

export interface WalletStatementQuery {
  readonly currency?: string
  readonly activityId?: string
  /** Keyset cursor: the last `occurredAt` already shown. */
  readonly before?: string
  /** Keyset cursor: the last `postingId` already shown. Required with `before`. */
  readonly beforeId?: string
  readonly limit?: number
}

export const DEFAULT_STATEMENT_LIMIT = 50
export const MAXIMUM_STATEMENT_LIMIT = 100

const ZERO = "0.0000"

interface BalanceRow {
  currency: string
  available: string
  pending: string
  total: string
  withdrawable: string
}

interface StatementRow {
  posting_id: string
  entry_id: string
  reference: string
  entry_kind: string
  currency: string
  direction: string
  amount: string
  signed_amount: string
  activity_id: string | null
  occurred_at: string | Date
}

function zeroBalance(currency: string): WalletBalanceView {
  return {
    currency,
    total: ZERO,
    available: ZERO,
    pending: ZERO,
    withdrawable: ZERO,
  }
}

function toBalance(row: BalanceRow): WalletBalanceView {
  return {
    currency: row.currency,
    total: row.total,
    available: row.available,
    pending: row.pending,
    withdrawable: row.withdrawable,
  }
}

function toStatementEntry(row: StatementRow): WalletStatementEntry {
  return {
    postingId: row.posting_id,
    entryId: row.entry_id,
    reference: row.reference,
    entryKind: row.entry_kind as WalletStatementEntry["entryKind"],
    currency: row.currency,
    direction: row.direction as WalletStatementEntry["direction"],
    amount: row.amount,
    signedAmount: row.signed_amount,
    activityId: row.activity_id as WalletStatementEntry["activityId"],
    occurredAt:
      row.occurred_at instanceof Date
        ? row.occurred_at.toISOString()
        : row.occurred_at,
  }
}

function requireCurrency(currency: string): string {
  if (!currencyCodeSchema.safeParse(currency).success) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "A wallet currency must be an ISO-4217-shaped code.",
      400,
    )
  }
  return currency
}

function resolveLimit(limit: number | undefined): number {
  if (limit === undefined) return DEFAULT_STATEMENT_LIMIT
  if (
    !Number.isInteger(limit) ||
    limit < 1 ||
    limit > MAXIMUM_STATEMENT_LIMIT
  ) {
    throw new ApiError(
      "VALIDATION_FAILED",
      `A statement page is between 1 and ${MAXIMUM_STATEMENT_LIMIT} rows.`,
      400,
    )
  }
  return limit
}

@Injectable()
export class WalletService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  /** Every currency the account currently holds a wallet figure for. */
  async balances(context: WalletReadContext): Promise<WalletBalanceView[]> {
    return this.database.withTransaction(
      { identity: { accountId: context.accountId, userId: context.userId } },
      async (transaction) => {
        const result = await transaction.query<BalanceRow>(
          `select currency, available, pending, total, withdrawable
             from finance.wallet_balances
            where account_id = $1
            order by currency`,
          [context.accountId],
        )
        return result.rows.map(toBalance)
      },
    )
  }

  /**
   * One currency's figures. An account with no posting yet reads zero rather
   * than "not found": a wallet exists from registration, its ledger account and
   * postings arrive with the first money movement.
   */
  async balance(
    context: WalletReadContext,
    currency: string,
  ): Promise<WalletBalanceView> {
    const code = requireCurrency(currency)

    return this.database.withTransaction(
      { identity: { accountId: context.accountId, userId: context.userId } },
      async (transaction) => {
        const result = await transaction.query<BalanceRow>(
          `select currency, available, pending, total, withdrawable
             from finance.wallet_balances
            where account_id = $1 and currency = $2`,
          [context.accountId, code],
        )
        const row = result.rows[0]
        return row ? toBalance(row) : zeroBalance(code)
      },
    )
  }

  /**
   * A keyset-paginated statement, newest first. `before` and `beforeId` must be
   * supplied together; the pair is the last row already shown.
   */
  async statement(
    context: WalletReadContext,
    query: WalletStatementQuery = {},
  ): Promise<WalletStatementEntry[]> {
    const limit = resolveLimit(query.limit)
    const currency =
      query.currency === undefined ? null : requireCurrency(query.currency)

    let activityId: string | null = null
    if (query.activityId !== undefined) {
      if (!activityIdSchema.safeParse(query.activityId).success) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "The statement filter names an unknown activity.",
          400,
        )
      }
      activityId = query.activityId
    }

    let before: string | null = null
    let beforeId: string | null = null
    if (query.before !== undefined || query.beforeId !== undefined) {
      if (!query.before || !query.beforeId) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "A statement cursor needs both the timestamp and the posting id.",
          400,
        )
      }
      const parsed = new Date(query.before)
      if (Number.isNaN(parsed.getTime())) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "The statement cursor timestamp is not a date.",
          400,
        )
      }
      if (!/^[0-9a-f-]{36}$/i.test(query.beforeId)) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "The statement cursor does not name a posting.",
          400,
        )
      }
      before = parsed.toISOString()
      beforeId = query.beforeId
    }

    return this.database.withTransaction(
      { identity: { accountId: context.accountId, userId: context.userId } },
      async (transaction) => {
        const result = await transaction.query<StatementRow>(
          `select posting_id, entry_id, reference, entry_kind, currency,
                  direction, amount::text as amount,
                  signed_amount::text as signed_amount,
                  activity_id, occurred_at
             from finance.wallet_statement
            where account_id = $1
              and ($2::text is null or currency = $2)
              and ($3::text is null or activity_id = $3)
              and ($4::timestamptz is null
                   or (occurred_at, posting_id) < ($4, $5::uuid))
            order by occurred_at desc, posting_id desc
            limit $6`,
          [context.accountId, currency, activityId, before, beforeId, limit],
        )
        return result.rows.map(toStatementEntry)
      },
    )
  }
}
