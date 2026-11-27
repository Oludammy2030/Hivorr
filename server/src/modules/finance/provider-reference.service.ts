import { Inject, Injectable } from "@nestjs/common"
import { currencyCodeSchema, minorUnitsToMoney, moneyToMinorUnits } from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import { appendAudit } from "../platform"
import type { LedgerPostingContext } from "./ledger.service"

/**
 * Provider reference model (EP-02-034).
 *
 * A provider event is identified by `(provider, provider_reference)` and belongs
 * to one account. Recording the same event twice returns the first record; a
 * changed amount, currency, direction or account under the same reference is a
 * conflict. Linking is the only update, and it points the reference at the
 * journal entry it produced.
 *
 * The adapter that receives a real event arrives in `EP-02-040` to `EP-02-044`.
 * This service defines the storage and replay contract those tasks consume.
 */
export type ProviderReferenceContext = LedgerPostingContext

export interface RecordProviderReferenceInput {
  readonly provider: string
  readonly providerReference: string
  readonly direction: string
  readonly amount: string
  readonly currency: string
}

export interface LinkProviderReferenceInput {
  readonly provider: string
  readonly providerReference: string
  readonly journalEntryId: string
}

export interface ProviderReferenceView {
  readonly id: string
  readonly accountId: string
  readonly provider: string
  readonly providerReference: string
  readonly direction: string
  readonly status: string
  readonly amount: string
  readonly currency: string
  readonly journalEntryId: string | null
  readonly createdAt: string
  readonly updatedAt: string
}

export interface RecordProviderReferenceResult {
  readonly reference: ProviderReferenceView
  readonly replayed: boolean
}

const PROVIDER_PATTERN = /^[a-z][a-z0-9_-]{1,39}$/
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const DIRECTIONS = ["deposit", "payout", "refund"]

interface ProviderReferenceRow {
  id: string
  account_id: string
  provider: string
  provider_reference: string
  direction: string
  status: string
  amount: string
  currency: string
  journal_entry_id: string | null
  created_at: string | Date
  updated_at: string | Date
}

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : value
}

function toView(row: ProviderReferenceRow): ProviderReferenceView {
  return {
    id: row.id,
    accountId: row.account_id,
    provider: row.provider,
    providerReference: row.provider_reference,
    direction: row.direction,
    status: row.status,
    amount: row.amount,
    currency: row.currency,
    journalEntryId: row.journal_entry_id,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function mapProviderError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to record this provider reference.",
        403,
      )
    case "23505":
      throw new ApiError("CONFLICT", "That provider reference is already recorded.", 409)
    case "23514":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The provider reference is not valid for this account.",
        400,
      )
    case "23503":
      throw new ApiError("VALIDATION_FAILED", "The account or journal entry does not exist.", 400)
    default:
      throw error instanceof Error ? error : new Error("The provider reference operation failed.")
  }
}

function validateProvider(provider: string): string {
  const trimmed = provider.trim()
  if (!PROVIDER_PATTERN.test(trimmed)) {
    throw new ApiError("VALIDATION_FAILED", "A provider key is 2–40 lowercase characters.", 400)
  }
  return trimmed
}

function validateReference(reference: string): string {
  const trimmed = reference.trim()
  if (trimmed.length < 1 || trimmed.length > 200) {
    throw new ApiError("VALIDATION_FAILED", "A provider reference is 1–200 characters.", 400)
  }
  return trimmed
}

@Injectable()
export class ProviderReferenceService {
  constructor(@Inject(DatabaseService) private readonly database: DatabaseService) {}

  async record(
    input: RecordProviderReferenceInput,
    context: ProviderReferenceContext,
  ): Promise<RecordProviderReferenceResult> {
    const provider = validateProvider(input.provider)
    const providerReference = validateReference(input.providerReference)

    if (!DIRECTIONS.includes(input.direction)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A provider reference is a deposit, payout or refund.",
        400,
      )
    }
    const minor = moneyToMinorUnits(input.amount)
    if (minor === null) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A provider amount must be a positive numeric(20,4) value.",
        400,
      )
    }
    if (!currencyCodeSchema.safeParse(input.currency).success) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A provider currency must be an ISO-4217-shaped code.",
        400,
      )
    }

    const amount = minorUnitsToMoney(minor)

    try {
      return await this.database.withTransaction(
        {
          identity: {
            accountId: context.accountId,
            userId: context.userId,
          },
        },
        async (transaction) => {
          const generated = await transaction.query<{ id: string }>(
            "select platform.uuidv7() as id",
          )
          const id = generated.rows[0]?.id
          if (!id) {
            throw new Error("The provider reference identifier was not generated.")
          }

          const inserted = await transaction.query<ProviderReferenceRow>(
            `insert into finance.provider_references
               (id, account_id, provider, provider_reference, direction,
                status, amount, currency)
             values ($1, $2, $3, $4, $5, 'received', $6, $7)
             on conflict (provider, provider_reference) do nothing
             returning id, account_id, provider, provider_reference, direction,
                       status, amount::text as amount, currency,
                       journal_entry_id, created_at, updated_at`,
            [
              id,
              context.accountId,
              provider,
              providerReference,
              input.direction,
              amount,
              input.currency,
            ],
          )

          const insertedRow = inserted.rows[0]
          if (insertedRow) {
            const view = toView(insertedRow)
            await appendAudit(transaction.client, {
              actorType: "user",
              actorId: context.userId,
              actorAudience: context.audience,
              environment: context.environment,
              action: "finance.provider_reference_recorded",
              targetType: "provider_reference",
              targetId: view.id,
              afterSummary: {
                provider: view.provider,
                direction: view.direction,
                amount: view.amount,
                currency: view.currency,
              },
              ip: context.ip,
              userAgent: context.userAgent,
              correlationId: context.correlationId,
            })
            return { reference: view, replayed: false }
          }

          const existing = await transaction.query<ProviderReferenceRow>(
            `select id, account_id, provider, provider_reference, direction,
                    status, amount::text as amount, currency,
                    journal_entry_id, created_at, updated_at
               from finance.provider_references
              where provider = $1 and provider_reference = $2
              for update`,
            [provider, providerReference],
          )
          const row = existing.rows[0]
          if (!row) {
            throw new ApiError("CONFLICT", "That provider reference could not be resolved.", 409)
          }

          const sameMovement =
            row.account_id === context.accountId &&
            row.direction === input.direction &&
            row.currency === input.currency &&
            row.amount === amount

          if (!sameMovement) {
            throw new ApiError(
              "CONFLICT",
              "That provider reference already describes a different movement.",
              409,
            )
          }

          return { reference: toView(row), replayed: true }
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapProviderError(error)
    }
  }

  async linkEntry(
    input: LinkProviderReferenceInput,
    context: ProviderReferenceContext,
  ): Promise<ProviderReferenceView> {
    const provider = validateProvider(input.provider)
    const providerReference = validateReference(input.providerReference)
    if (!UUID_PATTERN.test(input.journalEntryId)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A linked journal entry must be an entry identifier.",
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
          const current = await transaction.query<ProviderReferenceRow>(
            `select id, account_id, provider, provider_reference, direction,
                    status, amount::text as amount, currency,
                    journal_entry_id, created_at, updated_at
               from finance.provider_references
              where provider = $1 and provider_reference = $2
              for update`,
            [provider, providerReference],
          )
          const row = current.rows[0]
          if (!row) {
            throw new ApiError("NOT_FOUND", "The provider reference was not found.", 404)
          }

          if (row.journal_entry_id === input.journalEntryId) {
            return toView(row)
          }
          if (row.journal_entry_id !== null) {
            throw new ApiError(
              "CONFLICT",
              "That provider reference is already linked to a different entry.",
              409,
            )
          }

          const entry = await transaction.query<{ currency: string }>(
            "select currency from finance.journal_entries where id = $1",
            [input.journalEntryId],
          )
          const entryRow = entry.rows[0]
          if (!entryRow) {
            throw new ApiError("NOT_FOUND", "The journal entry was not found.", 404)
          }
          if (entryRow.currency !== row.currency) {
            throw new ApiError(
              "VALIDATION_FAILED",
              "The provider reference and the journal entry use different currencies.",
              400,
            )
          }

          const updated = await transaction.query<ProviderReferenceRow>(
            `update finance.provider_references
                set status = 'posted',
                    journal_entry_id = $3,
                    updated_at = now()
              where provider = $1 and provider_reference = $2
              returning id, account_id, provider, provider_reference, direction,
                        status, amount::text as amount, currency,
                        journal_entry_id, created_at, updated_at`,
            [provider, providerReference, input.journalEntryId],
          )
          const linked = updated.rows[0]
          if (!linked) {
            throw new Error("The provider reference link returned no row.")
          }

          const view = toView(linked)
          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: context.userId,
            actorAudience: context.audience,
            environment: context.environment,
            action: "finance.provider_reference_linked",
            targetType: "provider_reference",
            targetId: view.id,
            afterSummary: {
              journalEntryId: view.journalEntryId,
              status: view.status,
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
      mapProviderError(error)
    }
  }
}
