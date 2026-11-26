import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { API_CONFIG, type ApiConfig } from "../../config"
import { DatabaseService } from "../../db/database.service"
import {
  PaystackCollectionsClient,
  verifyPaystackSignature,
  type PaystackCollectionsOptions,
} from "../../integrations/paystack"
import type { DepositEvent } from "../../integrations/payments/payment-provider"
import type { RequestContext } from "../identity"
import { IdentityService } from "../identity"
import { PaymentProviderSettingsService } from "../platform"
import { appendAudit } from "../platform"
import { DepositEligibilityService } from "./deposit-eligibility.service"
import { LedgerService } from "./ledger.service"

/**
 * Deposit posting and Paystack webhook intake (EP-02-042/044/052).
 *
 * The webhook is a trigger, not an authority: the signature is verified and the
 * transaction is checked with Paystack before a deposit can post. The provider
 * reference is the idempotency key; the wallet debit and clearing credit share
 * one transaction with it.
 *
 * An over-limit deposit is recorded as failed and does not credit the wallet.
 * The account is put on the KYC-upgrade hold by the eligibility gate.
 */
export interface PostDepositInput {
  readonly accountId: string
  readonly userId: string
  readonly provider: string
  readonly providerReference: string
  readonly amount: string
  readonly currency: string
  readonly occurredAt: string
  readonly context: RequestContext
}

export interface DepositPostingView {
  readonly reference: string
  readonly accountId: string
  readonly amount: string
  readonly currency: string
  readonly status: "posted" | "replayed" | "blocked"
  readonly journalEntryId: string | null
  readonly reason?: string
}

@Injectable()
export class DepositPostingService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(DepositEligibilityService)
    private readonly eligibility: DepositEligibilityService,
    @Inject(LedgerService) private readonly ledger: LedgerService,
    @Inject(PaymentProviderSettingsService)
    private readonly settings: PaymentProviderSettingsService,
  ) {}

  /** Handles a raw Paystack webhook. Returns without posting for ignored events. */
  async handlePaystackWebhook(rawBody: Buffer, signature: string): Promise<{
    accepted: boolean
    posted: boolean
    reason?: string
  }> {
    const active = await this.settings.activeSetting()
    if (active.provider !== "paystack") {
      return { accepted: false, posted: false, reason: "provider_paused" }
    }
    const secretKey =
      active.mode === "live"
        ? this.config.paystack.secretKeyLive
        : this.config.paystack.secretKeyTest
    if (!secretKey) {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        `The Paystack ${active.mode} secret key is not configured.`,
        503,
      )
    }
    if (!verifyPaystackSignature(rawBody, signature, secretKey)) {
      throw new ApiError(
        "UNAUTHENTICATED",
        "The webhook signature is not valid.",
        401,
      )
    }

    let parsed: unknown
    try {
      parsed = JSON.parse(rawBody.toString("utf8"))
    } catch {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The webhook body is not valid JSON.",
        400,
      )
    }

    const client = this.client(active.mode, secretKey)
    let event: DepositEvent
    try {
      event = client.normaliseDepositEvent(parsed)
    } catch (error) {
      if (error instanceof ApiError) throw error
      return { accepted: false, posted: false, reason: "not_a_deposit" }
    }
    if (event.status !== "received") {
      return { accepted: true, posted: false, reason: "not_received" }
    }

    const verified = await client.verifyTransaction(event.reference)
    if (verified.status !== "received") {
      return { accepted: true, posted: false, reason: "not_verified" }
    }

    const collection = await this.database.withTransaction({}, (transaction) =>
      transaction.query<{
        account_id: string
        owner_user_id: string
      }>(
        `select account_id, owner_user_id
           from finance.collection_accounts
          where account_number = $1
             or provider_customer_code = $1
          limit 1`,
        [verified.collectionAccountReference],
      ),
    )
    const target = collection.rows[0]
    if (!target) {
      return { accepted: true, posted: false, reason: "collection_not_found" }
    }

    const result = await this.postDeposit({
      accountId: target.account_id,
      userId: target.owner_user_id,
      provider: verified.provider,
      providerReference: verified.reference,
      amount: verified.amount,
      currency: verified.currency,
      occurredAt: verified.occurredAt,
      context: {
        audience: "app",
        environment:
          this.config.environment === "production" ? "production" : "staging",
        correlationId: undefined,
      },
    })
    return {
      accepted: true,
      posted: result.status !== "blocked",
      reason: result.reason,
    }
  }

  async postDeposit(input: PostDepositInput): Promise<DepositPostingView> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const inserted = await transaction.query<{
            id: string
            status: string
            journal_entry_id: string | null
          }>(
            `insert into finance.provider_references
               (account_id, provider, provider_reference, direction, status,
                amount, currency)
             values ($1, $2, $3, 'deposit', 'received', $4::numeric, $5)
             on conflict (provider, provider_reference) do nothing
             returning id, status, journal_entry_id`,
            [
              input.accountId,
              input.provider,
              input.providerReference,
              input.amount,
              input.currency,
            ],
          )

          let referenceId = inserted.rows[0]?.id
          if (!referenceId) {
            const existing = await transaction.query<{
              id: string
              account_id: string
              direction: string
              status: string
              amount: string
              currency: string
              journal_entry_id: string | null
            }>(
              `select id, account_id, direction, status, amount::text as amount,
                      currency, journal_entry_id
                 from finance.provider_references
                where provider = $1 and provider_reference = $2
                for update`,
              [input.provider, input.providerReference],
            )
            const row = existing.rows[0]
            if (!row) {
              throw new ApiError(
                "CONFLICT",
                "The provider reference could not be resolved.",
                409,
              )
            }
            if (
              row.account_id !== input.accountId ||
              row.direction !== "deposit" ||
              row.currency !== input.currency ||
              row.amount !== input.amount
            ) {
              throw new ApiError(
                "CONFLICT",
                "That provider reference already describes a different movement.",
                409,
              )
            }
            if (row.journal_entry_id) {
              return {
                reference: input.providerReference,
                accountId: input.accountId,
                amount: input.amount,
                currency: input.currency,
                status: "replayed",
                journalEntryId: row.journal_entry_id,
              }
            }
            if (row.status === "failed") {
              return {
                reference: input.providerReference,
                accountId: input.accountId,
                amount: input.amount,
                currency: input.currency,
                status: "blocked",
                journalEntryId: null,
                reason: "kyc_upgrade_required",
              }
            }
            referenceId = row.id
          }

          const tier = await this.identity.getKycTierInTransaction(
            transaction,
            input.accountId,
          )
          const decision = await this.eligibility.checkInTransaction(
            transaction,
            {
              accountId: input.accountId,
              userId: input.userId,
              tier,
              amount: input.amount,
              currency: input.currency,
              context: input.context,
            },
          )
          if (!decision.allowed) {
            await transaction.query(
              `update finance.provider_references
                  set status = 'failed', updated_at = now()
                where id = $1`,
              [referenceId],
            )
            return {
              reference: input.providerReference,
              accountId: input.accountId,
              amount: input.amount,
              currency: input.currency,
              status: "blocked",
              journalEntryId: null,
              reason: decision.reason,
            }
          }

          const walletId = await this.ensureAccount(
            transaction,
            "user_wallet",
            "account",
            input.accountId,
            input.currency,
          )
          const clearingId = await this.ensureAccount(
            transaction,
            "platform_clearing",
            "platform",
            null,
            input.currency,
          )

          const entry = await this.ledger.postEntryInTransaction(
            transaction,
            {
              kind: "deposit",
              reference: `DEP-${input.providerReference}`.slice(0, 64),
              currency: input.currency,
              idempotencyKey: `deposit:${input.provider}:${input.providerReference}`,
              postings: [
                {
                  accountId: walletId,
                  direction: "debit",
                  amount: input.amount,
                  currency: input.currency,
                },
                {
                  accountId: clearingId,
                  direction: "credit",
                  amount: input.amount,
                  currency: input.currency,
                },
              ],
            },
            {
              accountId: input.accountId,
              userId: input.userId,
              audience: input.context.audience,
              environment: input.context.environment,
              ip: input.context.ip,
              userAgent: input.context.userAgent,
              correlationId: input.context.correlationId,
            },
          )

          await transaction.query(
            `update finance.provider_references
                set status = 'posted', journal_entry_id = $2, updated_at = now()
              where id = $1`,
            [referenceId, entry.id],
          )

          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "finance.deposit_posted",
            targetType: "journal_entry",
            targetId: entry.id,
            afterSummary: {
              provider: input.provider,
              providerReference: input.providerReference,
              amount: input.amount,
              currency: input.currency,
              occurredAt: input.occurredAt,
            },
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })

          return {
            reference: input.providerReference,
            accountId: input.accountId,
            amount: input.amount,
            currency: input.currency,
            status: "posted",
            journalEntryId: entry.id,
          }
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      const code =
        typeof error === "object" && error !== null && "code" in error
          ? (error as { code?: unknown }).code
          : undefined
      if (code === "42501") {
        throw new ApiError(
          "FORBIDDEN",
          "You do not have permission to post this deposit.",
          403,
        )
      }
      if (code === "23505" || code === "23514") {
        throw new ApiError(
          "CONFLICT",
          "The deposit conflicts with an existing record.",
          409,
        )
      }
      throw error instanceof Error
        ? error
        : new Error("The deposit posting failed.")
    }
  }

  private client(
    mode: "test" | "live",
    secretKey: string,
  ): PaystackCollectionsClient {
    const options: PaystackCollectionsOptions = {
      baseUrl: this.config.paystack.baseUrl,
      mode,
      secretKey,
      preferredBank: this.config.paystack.preferredBank,
      requestTimeoutMs: this.config.vfd.requestTimeoutMs,
      maxRetries: this.config.vfd.maxRetries,
      retryBaseMs: this.config.vfd.retryBaseMs,
    }
    return new PaystackCollectionsClient(options)
  }

  private async ensureAccount(
    transaction: Parameters<LedgerService["postEntryInTransaction"]>[0],
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
}
