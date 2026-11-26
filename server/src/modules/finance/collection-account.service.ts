import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { API_CONFIG, type ApiConfig } from "../../config"
import { DatabaseService } from "../../db/database.service"
import {
  PaystackCollectionsClient,
  type PaystackCollectionsOptions,
} from "../../integrations/paystack"
import { isPaymentProviderError } from "../../integrations/payments/payment-provider"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"
import { PaymentProviderSettingsService } from "../platform"

/**
 * Dedicated collection account (EP-02-042, Paystack active).
 *
 * One virtual account per account. The row stores the bank-issued number and
 * the owner user; the provider secret stays in the secret store. The account
 * number is returned to its owner so they can fund the wallet.
 */
export interface CollectionAccountView {
  readonly id: string
  readonly provider: string
  readonly reference: string
  readonly accountNumber: string
  readonly accountName: string
  readonly bankName: string | null
  readonly currency: string
  readonly status: string
}

export interface CreateCollectionAccountInput {
  readonly accountId: string
  readonly userId: string
  readonly email: string
  readonly accountName: string
  readonly context: RequestContext
}

interface CollectionAccountRow {
  id: string
  provider: string
  reference: string
  account_number: string
  account_name: string
  bank_name: string | null
  currency: string
  status: string
}

function toView(row: CollectionAccountRow): CollectionAccountView {
  return {
    id: row.id,
    provider: row.provider,
    reference: row.reference,
    accountNumber: row.account_number,
    accountName: row.account_name,
    bankName: row.bank_name,
    currency: row.currency,
    status: row.status,
  }
}

@Injectable()
export class CollectionAccountService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
    @Inject(PaymentProviderSettingsService)
    private readonly settings: PaymentProviderSettingsService,
  ) {}

  async get(input: { accountId: string; userId: string }): Promise<CollectionAccountView | null> {
    return this.database.withTransaction(
      { identity: { accountId: input.accountId, userId: input.userId } },
      async (transaction) => {
        const result = await transaction.query<CollectionAccountRow>(
          `select id, provider, reference, account_number, account_name,
                  bank_name, currency, status
             from finance.collection_accounts
            where account_id = $1 and provider = 'paystack'`,
          [input.accountId],
        )
        return result.rows[0] ? toView(result.rows[0]) : null
      },
    )
  }

  async create(input: CreateCollectionAccountInput): Promise<CollectionAccountView> {
    const existing = await this.get(input)
    if (existing) return existing

    const active = await this.settings.activeSetting()
    if (active.provider !== "paystack") {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        "Collections are Paystack-only while VFD is paused.",
        503,
      )
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

    const options: PaystackCollectionsOptions = {
      baseUrl: this.config.paystack.baseUrl,
      mode: active.mode,
      secretKey,
      preferredBank: this.config.paystack.preferredBank,
      requestTimeoutMs: this.config.vfd.requestTimeoutMs,
      maxRetries: this.config.vfd.maxRetries,
      retryBaseMs: this.config.vfd.retryBaseMs,
    }
    const client = new PaystackCollectionsClient(options)

    let account
    try {
      account = await client.provisionCollectionAccount(
        {
          reference: `COL-${input.accountId}`,
          accountName: input.accountName,
          email: input.email,
          currency: "NGN",
        },
        { idempotencyKey: `collection-${input.accountId}` },
      )
    } catch (error) {
      if (isPaymentProviderError(error)) {
        throw new ApiError("PROVIDER_ERROR", "Paystack could not create a collection account.", 502)
      }
      throw error
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const inserted = await transaction.query<CollectionAccountRow>(
            `insert into finance.collection_accounts
               (account_id, owner_user_id, provider, reference,
                account_number, account_name, bank_name, currency)
             values ($1, $2, 'paystack', $3, $4, $5, $6, $7)
             on conflict (account_id, provider) do nothing
             returning id, provider, reference, account_number, account_name,
                       bank_name, currency, status`,
            [
              input.accountId,
              input.userId,
              account.reference,
              account.accountNumber,
              account.accountName,
              account.bankName,
              account.currency,
            ],
          )
          const row = inserted.rows[0]
          if (!row) {
            const current = await transaction.query<CollectionAccountRow>(
              `select id, provider, reference, account_number, account_name,
                      bank_name, currency, status
                 from finance.collection_accounts
                where account_id = $1 and provider = 'paystack'`,
              [input.accountId],
            )
            if (!current.rows[0]) {
              throw new Error("The collection account insert returned no row.")
            }
            return toView(current.rows[0])
          }

          const view = toView(row)
          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "finance.collection_account_created",
            targetType: "collection_account",
            targetId: view.id,
            afterSummary: {
              provider: view.provider,
              accountNumberLast4: view.accountNumber.slice(-4),
              bankName: view.bankName,
              currency: view.currency,
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
      if (isPaymentProviderError(error)) {
        throw new ApiError("PROVIDER_ERROR", "Paystack could not create a collection account.", 502)
      }
      throw error
    }
  }
}
