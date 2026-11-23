import { Inject, Injectable } from "@nestjs/common"
import { moneyToMinorUnits } from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { API_CONFIG, type ApiConfig } from "../../config"
import { DatabaseService } from "../../db/database.service"
import type { TransactionContext } from "../../db/transaction"
import {
  isPaymentProviderError,
  type PaymentProviderError,
  type PayoutRequest,
  type PayoutResult,
  type ProviderOperationContext,
} from "../../integrations/payments/payment-provider"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"
import { FINANCIALLY_ELIGIBLE_TIERS } from "./limits"
import { LedgerService, type LedgerPostingContext } from "./ledger.service"
import { FinanceLimitService } from "./limit.service"
import {
  PayoutAccountCipher,
  type PayoutAccountKeys,
} from "./payout-account-crypto"
import {
  payoutRequestToView,
  type PayoutRequestRow,
  type PayoutRequestView,
} from "./payout-request.service"

/**
 * Payout execution (EP-02-053, second increment).
 *
 * The workflow reserves funds inside one transaction, calls the provider port
 * after that transaction commits, and settles in a second transaction:
 *
 *   REQUESTED -> RESERVED -> PROCESSING -> PAID
 *                                    \-> FAILED (with a reversal entry)
 *
 * A definitive provider failure posts a `reversal` entry in the same
 * transaction that marks the request `FAILED`, so no half-posted state remains.
 * A timeout or duplicate outcome is ambiguous: the request stays `PROCESSING`
 * and reconciliation must confirm it with the provider status query.
 *
 * This service never logs or projects the plaintext account number.
 */
export const PAYOUT_PROVIDER = "HIVORR_PAYOUT_PROVIDER" as const

export interface PayoutProviderPort {
  readonly provider: string
  initiatePayout(
    input: PayoutRequest,
    context: ProviderOperationContext,
  ): Promise<PayoutResult>
}

export interface ExecutePayoutInput {
  readonly accountId: string
  readonly userId: string
  readonly tier?: string | null
  readonly requestId: string
  readonly context: RequestContext
}

interface ExecutionRow extends PayoutRequestRow {
  readonly account_id: string
  readonly journal_entry_id: string | null
}

interface DestinationRow {
  id: string
  status: string
  bank_code: string
  account_name: string
  account_number_ciphertext: Buffer
  encryption_key_id: string
  account_number_last4: string
}

interface PostingRow {
  ledger_account_id: string
  direction: string
  amount: string
  currency: string
}

type PreparedPayout = {
  readonly final: true
  readonly view: PayoutRequestView
} | {
  readonly final: false
  readonly request: ExecutionRow
  readonly view: PayoutRequestView
  readonly bankCode: string
  readonly accountName: string
  readonly accountNumber: string
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function parseAmount(value: string | undefined): bigint {
  if (!value || /^0(\.0{1,4})?$/.test(value)) return 0n
  return moneyToMinorUnits(value) ?? 0n
}

function failureMessage(value: string | null | undefined): string | null {
  if (!value) return null
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed.slice(0, 200) : null
}

function mapExecutionError(error: unknown): never {
  if (typeof error === "object" && error !== null && "code" in error) {
    const code = (error as { code?: unknown }).code
    if (code === "42501") {
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to execute this payout.",
        403,
      )
    }
    if (code === "23514") {
      throw new ApiError(
        "CONFLICT",
        "The payout request is not in a state that can execute.",
        409,
      )
    }
    if (code === "23505") {
      throw new ApiError(
        "CONFLICT",
        "The payout execution already exists.",
        409,
      )
    }
  }
  throw error instanceof Error
    ? error
    : new Error("The payout execution failed.")
}

@Injectable()
export class PayoutExecutionService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
    @Inject(LedgerService) private readonly ledger: LedgerService,
    @Inject(FinanceLimitService) private readonly limits: FinanceLimitService,
    @Inject(PAYOUT_PROVIDER) private readonly provider: PayoutProviderPort,
  ) {}

  /** Executes an existing request. A repeat returns the current state. */
  async execute(input: ExecutePayoutInput): Promise<PayoutRequestView> {
    const tier = input.tier ?? "tier_0"
    if (!FINANCIALLY_ELIGIBLE_TIERS.has(tier)) {
      throw new ApiError(
        "KYC_REQUIRED",
        "A payout requires KYC tier_1 or above.",
        403,
      )
    }
    if (!UUID_PATTERN.test(input.requestId)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The payout request identifier is invalid.",
        400,
      )
    }

    const cipher = this.cipher()
    const prepared = await this.reserve(input, tier, cipher)
    if (prepared.final) return prepared.view

    let result: PayoutResult
    try {
      result = await this.provider.initiatePayout(
        {
          reference: prepared.request.reference,
          amount: prepared.request.amount,
          currency: prepared.request.currency,
          bankCode: prepared.bankCode,
          accountNumber: prepared.accountNumber,
          accountName: prepared.accountName,
          narration: "Hivorr payout",
        },
        {
          idempotencyKey: prepared.request.id,
          correlationId: input.context.correlationId,
        },
      )
    } catch (error) {
      if (isPaymentProviderError(error)) {
        return this.handleProviderError(input, prepared.request, error)
      }
      throw error
    }

    return this.settle(input, prepared.request, result)
  }

  private async reserve(
    input: ExecutePayoutInput,
    tier: string,
    cipher: PayoutAccountCipher,
  ): Promise<PreparedPayout> {
    try {
      return await this.database.withTransaction(
        {
          identity: { accountId: input.accountId, userId: input.userId },
        },
        async (transaction) => {
          const hold = await transaction.query<{
            financial_hold_reason: string | null
          }>(
            "select financial_hold_reason from identity.accounts where id = $1",
            [input.accountId],
          )
          if (hold.rows[0]?.financial_hold_reason) {
            throw new ApiError(
              "KYC_REQUIRED",
              "A deposit above your tier limit requires a KYC upgrade before further fund transactions.",
              403,
            )
          }

          const request = await this.loadRequest(
            transaction,
            input.requestId,
            input.accountId,
          )
          if (!request) {
            throw new ApiError(
              "NOT_FOUND",
              "That payout request does not exist.",
              404,
            )
          }

          if (
            request.status === "PROCESSING" ||
            request.status === "PAID" ||
            request.status === "FAILED" ||
            request.status === "CANCELLED"
          ) {
            return { final: true, view: payoutRequestToView(request) }
          }
          if (request.status !== "REQUESTED" && request.status !== "RESERVED") {
            throw new ApiError(
              "CONFLICT",
              "The payout request is not ready to execute.",
              409,
            )
          }

          const destination = await this.loadDestination(
            transaction,
            request.payout_account_id,
            input.accountId,
          )
          if (!destination || destination.status !== "verified") {
            throw new ApiError(
              "PAYOUT_ACCOUNT_REQUIRED",
              "The payout destination is not verified.",
              403,
            )
          }

          let current = request
          if (request.status === "REQUESTED") {
            await this.limits.assertWithin(transaction, {
              accountId: input.accountId,
              userId: input.userId,
              tier,
              limitType: "withdrawal",
              currency: request.currency,
              amount: request.amount,
              direction: "out",
            })

            const balance = await transaction.query<{ available: string }>(
              `select available::text as available
                 from finance.wallet_balances
                where account_id = $1 and currency = $2`,
              [input.accountId, request.currency],
            )
            const amountMinor = moneyToMinorUnits(request.amount)
            if (amountMinor === null) {
              throw new ApiError(
                "CONFLICT",
                "The payout amount is not readable.",
                409,
              )
            }
            if (parseAmount(balance.rows[0]?.available) < amountMinor) {
              throw new ApiError(
                "INSUFFICIENT_FUNDS",
                "The available balance does not cover this payout.",
                409,
              )
            }

            const walletId = await this.ensureAccount(
              transaction,
              "user_wallet",
              "account",
              input.accountId,
              request.currency,
            )
            const payableId = await this.ensureAccount(
              transaction,
              "payout_payable",
              "platform",
              null,
              request.currency,
            )

            const entry = await this.ledger.postEntryInTransaction(
              transaction,
              {
                kind: "payout",
                reference: request.reference,
                currency: request.currency,
                idempotencyKey: `payout-reserve:${request.id}`,
                postings: [
                  {
                    accountId: walletId,
                    direction: "credit",
                    amount: request.amount,
                    currency: request.currency,
                  },
                  {
                    accountId: payableId,
                    direction: "debit",
                    amount: request.amount,
                    currency: request.currency,
                  },
                ],
              },
              this.ledgerContext(input),
            )

            current = await this.markReserved(
              transaction,
              request,
              entry.id,
              this.provider.provider,
            )
            await this.audit(
              transaction,
              input,
              "finance.payout_reserved",
              current,
              { journalEntryId: entry.id },
            )
          }

          const processing = await this.markProcessing(
            transaction,
            current,
            this.provider.provider,
            current.provider_reference,
          )
          await this.audit(
            transaction,
            input,
            "finance.payout_execution_started",
            processing,
          )

          return {
            final: false,
            request: processing,
            view: payoutRequestToView(processing),
            bankCode: destination.bank_code,
            accountName: destination.account_name,
            accountNumber: cipher.decrypt(
              destination.account_number_ciphertext,
              destination.encryption_key_id,
            ),
          }
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapExecutionError(error)
    }
  }

  private async settle(
    input: ExecutePayoutInput,
    prepared: ExecutionRow,
    result: PayoutResult,
  ): Promise<PayoutRequestView> {
    try {
      return await this.database.withTransaction(
        {
          identity: { accountId: input.accountId, userId: input.userId },
        },
        async (transaction) => {
          const request = await this.loadRequest(
            transaction,
            prepared.id,
            input.accountId,
          )
          if (!request) {
            throw new ApiError(
              "NOT_FOUND",
              "That payout request does not exist.",
              404,
            )
          }
          if (request.status !== "PROCESSING") {
            return payoutRequestToView(request)
          }

          if (result.status === "failed") {
            const reversal = await this.reverse(transaction, request, input)
            const failed = await this.markFailed(
              transaction,
              request,
              result.provider,
              result.providerReference,
              result.failureCode ?? "PROVIDER_FAILED",
              result.failureMessage,
              reversal.id,
            )
            await this.audit(
              transaction,
              input,
              "finance.payout_failed",
              failed,
              { reversalEntryId: reversal.id },
            )
            return payoutRequestToView(failed)
          }

          if (result.status === "paid") {
            const paid = await this.markPaid(
              transaction,
              request,
              result.provider,
              result.providerReference ?? request.reference,
            )
            await this.audit(transaction, input, "finance.payout_paid", paid)
            return payoutRequestToView(paid)
          }

          const processing = await this.markProcessing(
            transaction,
            request,
            result.provider,
            result.providerReference,
          )
          await this.audit(
            transaction,
            input,
            "finance.payout_processing",
            processing,
          )
          return payoutRequestToView(processing)
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapExecutionError(error)
    }
  }

  private async handleProviderError(
    input: ExecutePayoutInput,
    prepared: ExecutionRow,
    error: PaymentProviderError,
  ): Promise<PayoutRequestView> {
    const ambiguous = error.retryable || error.code === "PROVIDER_DUPLICATE"

    try {
      return await this.database.withTransaction(
        {
          identity: { accountId: input.accountId, userId: input.userId },
        },
        async (transaction) => {
          const request = await this.loadRequest(
            transaction,
            prepared.id,
            input.accountId,
          )
          if (!request) {
            throw new ApiError(
              "NOT_FOUND",
              "That payout request does not exist.",
              404,
            )
          }
          if (request.status !== "PROCESSING") {
            return payoutRequestToView(request)
          }

          if (ambiguous) {
            const processing = await this.markProcessing(
              transaction,
              request,
              request.provider,
              request.provider_reference,
            )
            await this.audit(
              transaction,
              input,
              "finance.payout_processing",
              processing,
              { failureCode: error.code },
            )
            return payoutRequestToView(processing)
          }

          const reversal = await this.reverse(transaction, request, input)
          const failed = await this.markFailed(
            transaction,
            request,
            request.provider,
            request.provider_reference,
            error.code,
            error.message,
            reversal.id,
          )
          await this.audit(
            transaction,
            input,
            "finance.payout_failed",
            failed,
            { reversalEntryId: reversal.id, failureCode: error.code },
          )
          return payoutRequestToView(failed)
        },
      )
    } catch (inner) {
      if (inner instanceof ApiError) throw inner
      mapExecutionError(inner)
    }
  }

  private cipher(): PayoutAccountCipher {
    const keys: PayoutAccountKeys = this.config.payout
    if (!keys.encryptionKey || !keys.fingerprintKey) {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        "Payout account protection is not configured.",
        503,
      )
    }
    return PayoutAccountCipher.fromConfig(keys)
  }

  private ledgerContext(input: ExecutePayoutInput): LedgerPostingContext {
    return {
      accountId: input.accountId,
      userId: input.userId,
      audience: input.context.audience,
      environment: input.context.environment,
      ip: input.context.ip,
      userAgent: input.context.userAgent,
      correlationId: input.context.correlationId,
    }
  }

  private async loadRequest(
    transaction: TransactionContext,
    requestId: string,
    accountId: string,
  ): Promise<ExecutionRow | undefined> {
    const result = await transaction.query<ExecutionRow>(
      `select pr.id, pr.reference, pr.account_id, pr.payout_account_id,
              pa.account_number_last4, pr.amount::text as amount,
              pr.currency, pr.status, pr.provider, pr.provider_reference,
              pr.failure_code, pr.created_at, pr.completed_at,
              pr.journal_entry_id
         from finance.payout_requests pr
         join finance.payout_accounts pa on pa.id = pr.payout_account_id
        where pr.id = $1 and pr.account_id = $2
        for update of pr`,
      [requestId, accountId],
    )
    return result.rows[0]
  }

  private async loadDestination(
    transaction: TransactionContext,
    payoutAccountId: string,
    accountId: string,
  ): Promise<DestinationRow | undefined> {
    const result = await transaction.query<DestinationRow>(
      `select id, status, bank_code, account_name,
              account_number_ciphertext, encryption_key_id,
              account_number_last4
         from finance.payout_accounts
        where id = $1 and account_id = $2
        for update`,
      [payoutAccountId, accountId],
    )
    return result.rows[0]
  }

  private async ensureAccount(
    transaction: TransactionContext,
    kind: string,
    ownerType: string,
    ownerId: string | null,
    currency: string,
  ): Promise<string> {
    const result = await transaction.query<{ id: string }>(
      "select finance.ensure_ledger_account($1, $2, $3::uuid, $4) as id",
      [kind, ownerType, ownerId, currency],
    )
    const id = result.rows[0]?.id
    if (!id) {
      throw new Error("The ledger account could not be provisioned.")
    }
    return id
  }

  private async markReserved(
    transaction: TransactionContext,
    request: ExecutionRow,
    journalEntryId: string,
    provider: string,
  ): Promise<ExecutionRow> {
    const result = await transaction.query<PayoutRequestRow>(
      `update finance.payout_requests
          set status = 'RESERVED', journal_entry_id = $3, provider = $4,
              updated_at = now()
        where id = $1 and account_id = $2
        returning id, reference, payout_account_id, amount::text as amount,
                  currency, status, provider, provider_reference, failure_code,
                  created_at, completed_at`,
      [request.id, request.account_id, journalEntryId, provider],
    )
    const merged = this.mergeLast4(result.rows[0], request)
    return { ...merged, journal_entry_id: journalEntryId }
  }

  private async markProcessing(
    transaction: TransactionContext,
    request: ExecutionRow,
    provider: string | null,
    providerReference: string | null,
  ): Promise<ExecutionRow> {
    const result = await transaction.query<PayoutRequestRow>(
      `update finance.payout_requests
          set status = 'PROCESSING',
              provider = coalesce($3, provider),
              provider_reference = coalesce($4, provider_reference),
              updated_at = now()
        where id = $1 and account_id = $2
        returning id, reference, payout_account_id, amount::text as amount,
                  currency, status, provider, provider_reference, failure_code,
                  created_at, completed_at`,
      [request.id, request.account_id, provider, providerReference],
    )
    return this.mergeLast4(result.rows[0], request)
  }

  private async markPaid(
    transaction: TransactionContext,
    request: ExecutionRow,
    provider: string,
    providerReference: string,
  ): Promise<ExecutionRow> {
    const result = await transaction.query<PayoutRequestRow>(
      `update finance.payout_requests
          set status = 'PAID', provider = $3, provider_reference = $4,
              completed_at = now(), updated_at = now()
        where id = $1 and account_id = $2
        returning id, reference, payout_account_id, amount::text as amount,
                  currency, status, provider, provider_reference, failure_code,
                  created_at, completed_at`,
      [request.id, request.account_id, provider, providerReference],
    )
    return this.mergeLast4(result.rows[0], request)
  }

  private async markFailed(
    transaction: TransactionContext,
    request: ExecutionRow,
    provider: string | null,
    providerReference: string | null,
    failureCode: string,
    message: string | null,
    reversalEntryId: string,
  ): Promise<ExecutionRow> {
    const result = await transaction.query<PayoutRequestRow>(
      `update finance.payout_requests
          set status = 'FAILED', provider = $3, provider_reference = $4,
              failure_code = $5, failure_message = $6, reversal_entry_id = $7,
              completed_at = now(), updated_at = now()
        where id = $1 and account_id = $2
        returning id, reference, payout_account_id, amount::text as amount,
                  currency, status, provider, provider_reference, failure_code,
                  created_at, completed_at`,
      [
        request.id,
        request.account_id,
        provider,
        providerReference,
        failureCode,
        failureMessage(message),
        reversalEntryId,
      ],
    )
    return this.mergeLast4(result.rows[0], request)
  }

  private mergeLast4(
    row: PayoutRequestRow | undefined,
    source: ExecutionRow,
  ): ExecutionRow {
    if (!row) {
      throw new Error("The payout request update returned no row.")
    }
    return {
      ...row,
      account_number_last4: source.account_number_last4,
      account_id: source.account_id,
      journal_entry_id: source.journal_entry_id,
    }
  }

  private async reverse(
    transaction: TransactionContext,
    request: ExecutionRow,
    input: ExecutePayoutInput,
  ): Promise<{ id: string }> {
    if (!request.journal_entry_id) {
      throw new ApiError(
        "CONFLICT",
        "The payout has no reserve entry to reverse.",
        409,
      )
    }

    const original = await transaction.query<PostingRow>(
      `select ledger_account_id, direction, amount::text as amount, currency
         from finance.postings
        where entry_id = $1
        order by created_at, id`,
      [request.journal_entry_id],
    )
    if (original.rows.length < 2) {
      throw new ApiError(
        "CONFLICT",
        "The payout reserve entry is incomplete.",
        409,
      )
    }

    const reversal = await this.ledger.postEntryInTransaction(
      transaction,
      {
        kind: "reversal",
        reference: `${request.reference}-REV`,
        currency: request.currency,
        idempotencyKey: `payout-reversal:${request.id}`,
        reversesEntryId: request.journal_entry_id,
        postings: original.rows.map((posting) => ({
          accountId: posting.ledger_account_id,
          direction: posting.direction === "debit" ? "credit" : "debit",
          amount: posting.amount,
          currency: posting.currency,
        })),
      },
      this.ledgerContext(input),
    )

    return { id: reversal.id }
  }

  private async audit(
    transaction: TransactionContext,
    input: ExecutePayoutInput,
    action: string,
    row: ExecutionRow,
    extra: Record<string, unknown> = {},
  ): Promise<void> {
    await appendAudit(transaction.client, {
      actorType: "user",
      actorId: input.userId,
      actorAudience: input.context.audience,
      environment: input.context.environment,
      action,
      targetType: "payout_request",
      targetId: row.id,
      afterSummary: {
        reference: row.reference,
        accountNumberLast4: row.account_number_last4,
        amount: row.amount,
        currency: row.currency,
        status: row.status,
        provider: row.provider,
        providerReference: row.provider_reference,
        failureCode: row.failure_code,
        ...extra,
      },
      ip: input.context.ip,
      userAgent: input.context.userAgent,
      correlationId: input.context.correlationId,
    })
  }
}
