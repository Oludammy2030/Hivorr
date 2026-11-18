import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { TransactionContext } from "../../db/transaction"
import { claimIdempotency, completeIdempotency, appendAudit } from "../platform"
import {
  LEDGER_IDEMPOTENCY_SCOPE,
  hashLedgerEntry,
  ledgerIdempotencyKey,
} from "./idempotency"
import {
  LedgerValidationError,
  deriveAccountEffects,
  validateJournalEntry,
  type LedgerAccountEffect,
  type LedgerEntryInput,
  type LedgerReversalTarget,
  type ValidatedPosting,
} from "./ledger"

/**
 * Ledger write path (EP-02-031).
 *
 * One transaction holds the reversal lookup, the entry, every posting and the
 * audit record. The pure domain validates first; the database constraint
 * validates again at commit. There is no update or delete method.
 */
export interface LedgerPostingContext {
  readonly accountId: string
  readonly userId: string
  readonly audience: string
  readonly environment: string
  readonly ip?: string
  readonly userAgent?: string
  readonly correlationId?: string
}

export interface PostedJournalEntry {
  readonly id: string
  readonly kind: string
  readonly reference: string
  readonly currency: string
  readonly createdAt: string
  readonly effects: readonly LedgerAccountEffect[]
}

interface EntryRow {
  id: string
  created_at: string | Date
}

interface ReversalRow {
  entry_currency: string
  ledger_account_id: string
  direction: string
  amount: string
  currency: string
  activity_id: string | null
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : value
}

function validationToApiError(error: LedgerValidationError): ApiError {
  switch (error.code) {
    case "LEDGER_REVERSAL_TARGET_MISSING":
      return new ApiError(
        "NOT_FOUND",
        "The journal entry to reverse was not found.",
        404,
      )
    case "LEDGER_REVERSAL_MISMATCH":
    case "LEDGER_REVERSAL_TARGET_INVALID":
      return new ApiError(
        "CONFLICT",
        "A reversal must exactly invert the original entry.",
        409,
      )
    default:
      return new ApiError("VALIDATION_FAILED", error.message, 400)
  }
}

function sqlToApiError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to post to the ledger.",
        403,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "That ledger reference or idempotency key is already in use.",
        409,
      )
    case "23514":
      throw new ApiError(
        "CONFLICT",
        "The ledger rejected the entry as invalid.",
        409,
      )
    case "23503":
      throw new ApiError(
        "VALIDATION_FAILED",
        "A ledger account, user or entry referenced by this request does not exist.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The ledger operation failed.")
  }
}

@Injectable()
export class LedgerService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async postEntry(
    input: LedgerEntryInput,
    context: LedgerPostingContext,
  ): Promise<PostedJournalEntry> {
    const clientKey = input.idempotencyKey?.trim()
    if (!clientKey) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "Every money movement needs an idempotency key.",
        400,
      )
    }

    const idempotencyKey = ledgerIdempotencyKey(context.accountId, clientKey)
    const requestHash = hashLedgerEntry(input)

    try {
      return await this.database.withTransaction(
        {
          identity: {
            accountId: context.accountId,
            userId: context.userId,
          },
        },
        async (transaction) => {
          const claim = await claimIdempotency(transaction.client, {
            key: idempotencyKey,
            scope: LEDGER_IDEMPOTENCY_SCOPE,
            requestHash,
            expiresAt: "infinity",
          })

          if (claim.status === "conflict") {
            throw new ApiError(
              "CONFLICT",
              "That idempotency key was already used for a different request.",
              409,
            )
          }
          if (claim.status === "replay") {
            return claim.responseBody as PostedJournalEntry
          }

          const reversalTarget = input.reversesEntryId
            ? await this.loadReversalTarget(transaction, input.reversesEntryId)
            : undefined

          const entry = validateJournalEntry(input, { reversalTarget })

          const inserted = await transaction.query<EntryRow>(
            `insert into finance.journal_entries
               (kind, reference, currency, activity_id, idempotency_key,
                reverses_entry_id, created_by, correlation_id)
             values ($1, $2, $3, $4, $5, $6, $7, $8)
             returning id, created_at`,
            [
              entry.kind,
              entry.reference,
              entry.currency,
              entry.activityId,
              entry.idempotencyKey,
              entry.reversesEntryId,
              context.userId,
              context.correlationId ?? null,
            ],
          )

          const row = inserted.rows[0]
          if (!row) {
            throw new Error("The ledger entry insert returned no row.")
          }

          await this.insertPostings(transaction, row.id, entry.postings)

          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: context.userId,
            actorAudience: context.audience,
            environment: context.environment,
            action: "finance.entry_posted",
            targetType: "journal_entry",
            targetId: row.id,
            afterSummary: {
              kind: entry.kind,
              reference: entry.reference,
              currency: entry.currency,
              postingCount: entry.postings.length,
              reversal: entry.reversesEntryId !== null,
            },
            ip: context.ip,
            userAgent: context.userAgent,
            correlationId: context.correlationId,
          })

          const posted = {
            id: row.id,
            kind: entry.kind,
            reference: entry.reference,
            currency: entry.currency,
            createdAt: toIso(row.created_at),
            effects: deriveAccountEffects(entry.postings),
          }

          await completeIdempotency(transaction.client, {
            key: idempotencyKey,
            responseStatus: 201,
            responseBody: posted,
          })

          return posted
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      if (error instanceof LedgerValidationError) {
        throw validationToApiError(error)
      }
      sqlToApiError(error)
    }
  }

  private async loadReversalTarget(
    transaction: TransactionContext,
    entryId: string,
  ): Promise<LedgerReversalTarget> {
    const result = await transaction.query<ReversalRow>(
      `select je.currency as entry_currency,
              p.ledger_account_id,
              p.direction,
              p.amount::text as amount,
              p.currency,
              p.activity_id
         from finance.journal_entries je
         join finance.postings p on p.entry_id = je.id
        where je.id = $1
        order by p.id`,
      [entryId],
    )

    if (result.rows.length === 0) {
      throw new ApiError(
        "NOT_FOUND",
        "The journal entry to reverse was not found.",
        404,
      )
    }

    return {
      currency: result.rows[0]!.entry_currency,
      postings: result.rows.map((row) => ({
        accountId: row.ledger_account_id,
        direction: row.direction,
        amount: row.amount,
        currency: row.currency,
        activityId: row.activity_id,
      })),
    }
  }

  /**
   * One multi-row insert. The column list is static and every value is a bound
   * parameter, so the statement is safe even at the 100-posting maximum.
   */
  private async insertPostings(
    transaction: TransactionContext,
    entryId: string,
    postings: readonly ValidatedPosting[],
  ): Promise<void> {
    const values: unknown[] = []
    const tuples = postings.map((posting, index) => {
      const offset = index * 6
      values.push(
        entryId,
        posting.accountId,
        posting.direction,
        posting.amount,
        posting.currency,
        posting.activityId,
      )
      return `($${offset + 1}, $${offset + 2}::uuid, $${offset + 3}, $${offset + 4}::numeric, $${offset + 5}, $${offset + 6})`
    })

    await transaction.query(
      `insert into finance.postings
         (entry_id, ledger_account_id, direction, amount, currency, activity_id)
       values ${tuples.join(", ")}`,
      values,
    )
  }
}
