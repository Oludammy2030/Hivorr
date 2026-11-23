import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { API_CONFIG, type ApiConfig } from "../../config"
import { DatabaseService } from "../../db/database.service"
import type {
  AccountNameEnquiry,
  AccountNameEnquiryRequest,
} from "../../integrations/payments/payment-provider"
import { isPaymentProviderError } from "../../integrations/payments/payment-provider"
import { IdentityService, type RequestContext } from "../identity"
import { appendAudit } from "../platform"
import { FINANCIALLY_ELIGIBLE_TIERS } from "./limits"
import {
  PAYOUT_ACCOUNT_NUMBER_PATTERN,
  PAYOUT_BANK_CODE_PATTERN,
  PayoutAccountCipher,
  accountNamesMatch,
  normalizeAccountName,
} from "./payout-account-crypto"

/**
 * Payout-account binding (EP-02-050, partial increment).
 *
 * Binding is a privileged write: the caller must present `tier_1` or above, the
 * account must hold a verified legal name, and the provider-resolved account
 * name must match it. The account number is encrypted before it reaches the
 * database; neither the plaintext nor the ciphertext is ever projected. Only
 * the last four digits appear in a view or an audit summary.
 *
 * Payout execution, payer-name matching and reconciliation remain out of scope
 * and are not called from here.
 */
export interface PayoutAccountNameResolver {
  resolveAccountName(
    input: AccountNameEnquiryRequest,
  ): Promise<AccountNameEnquiry>
}

export const PAYOUT_ACCOUNT_NAME_RESOLVER =
  "HIVORR_PAYOUT_ACCOUNT_NAME_RESOLVER" as const

export interface BindPayoutAccountInput {
  readonly accountId: string
  readonly userId: string
  /**
   * The KYC tier resolved at the session boundary. `EP-02-014` will supply it;
   * until then the caller passes the trusted value and a missing tier is
   * `tier_0`.
   */
  readonly tier?: string | null
  readonly bankCode: string
  readonly bankName: string
  readonly accountNumber: string
  readonly reason?: string
  readonly context: RequestContext
}

export interface DisablePayoutAccountInput {
  readonly id: string
  readonly accountId: string
  readonly userId: string
  readonly reason: string
  readonly context: RequestContext
}

export interface PayoutAccountView {
  readonly id: string
  readonly bankCode: string
  readonly bankName: string
  readonly accountName: string
  /** Only the last four digits are ever exposed. */
  readonly accountNumberMasked: string
  readonly state: "pending" | "verified" | "rejected" | "disabled"
  readonly boundAt: string | null
  readonly createdAt: string
}

interface PayoutAccountRow {
  id: string
  bank_code: string
  bank_name: string
  account_name: string
  account_number_last4: string
  status: string
  verified_at: string | Date | null
  created_at: string | Date
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : value
}

function toView(row: PayoutAccountRow): PayoutAccountView {
  return {
    id: row.id,
    bankCode: row.bank_code,
    bankName: row.bank_name,
    accountName: row.account_name,
    accountNumberMasked: `******${row.account_number_last4}`,
    state: row.status as PayoutAccountView["state"],
    boundAt: row.verified_at === null ? null : toIso(row.verified_at),
    createdAt: toIso(row.created_at),
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function mapWriteError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to change payout destinations.",
        403,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "That payout destination is already bound.",
        409,
      )
    case "23503":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The account does not exist.",
        400,
      )
    case "23514":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The payout destination does not satisfy its database constraints.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The payout destination operation failed.")
  }
}

@Injectable()
export class PayoutAccountService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(PAYOUT_ACCOUNT_NAME_RESOLVER)
    private readonly resolver: PayoutAccountNameResolver,
  ) {}

  /** Lists the caller's destinations without any bank-detail material. */
  async list(input: {
    accountId: string
    userId: string
  }): Promise<PayoutAccountView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<PayoutAccountRow>(
            `select id, bank_code, bank_name, account_name,
                    account_number_last4, status, verified_at, created_at
               from finance.payout_accounts
              where account_id = $1
              order by created_at desc, id desc`,
            [input.accountId],
          )
          return result.rows.map(toView)
        },
      )
    } catch (error) {
      mapWriteError(error)
    }
  }

  /**
   * Binds one destination. The provider name must match the verified legal name;
   * a mismatch is refused before any row is written. `EP-02-043` (payout
   * execution) does not exist yet, so nothing debits a wallet from here.
   */
  async bind(input: BindPayoutAccountInput): Promise<PayoutAccountView> {
    const tier = input.tier ?? "tier_0"
    if (!FINANCIALLY_ELIGIBLE_TIERS.has(tier)) {
      throw new ApiError(
        "KYC_REQUIRED",
        "Binding a payout destination requires KYC tier_1 or above.",
        403,
      )
    }

    const bankCode = input.bankCode.trim()
    if (!PAYOUT_BANK_CODE_PATTERN.test(bankCode)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A bank code is three to ten digits.",
        400,
      )
    }
    const bankName = input.bankName.trim()
    if (bankName.length < 1 || bankName.length > 120) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A bank name is one to 120 characters.",
        400,
      )
    }
    if (!PAYOUT_ACCOUNT_NUMBER_PATTERN.test(input.accountNumber)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A payout account number is ten digits.",
        400,
      )
    }

    // The approved destination count is not decided. Unset config means the
    // capability is closed, not that a default is used.
    const maxActive = this.config.payout.maxActiveAccounts
    if (maxActive === undefined) {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        "Payout account binding is not enabled in this environment.",
        503,
      )
    }
    if (
      !this.config.payout.encryptionKey ||
      !this.config.payout.fingerprintKey
    ) {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        "Payout account protection is not configured.",
        503,
      )
    }
    const cipher = PayoutAccountCipher.fromConfig(this.config.payout)

    const legalName = await this.identity.getAccountLegalName(
      input.accountId,
      input.userId,
    )
    if (!legalName || normalizeAccountName(legalName).length === 0) {
      throw new ApiError(
        "KYC_REQUIRED",
        "A verified legal name is required before binding a payout destination.",
        403,
      )
    }

    let enquiry: AccountNameEnquiry
    try {
      enquiry = await this.resolver.resolveAccountName({
        bankCode,
        accountNumber: input.accountNumber,
      })
    } catch (error) {
      if (isPaymentProviderError(error)) {
        throw new ApiError(
          "PROVIDER_ERROR",
          "The bank could not confirm that account name.",
          502,
        )
      }
      throw error
    }

    if (!accountNamesMatch(enquiry.accountName, legalName)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The bank account name does not match the verified legal name.",
        422,
      )
    }

    const encrypted = cipher.encrypt(input.accountNumber)
    const accountName = enquiry.accountName.trim()

    try {
      return await this.database.withTransaction(
        {
          identity: { accountId: input.accountId, userId: input.userId },
        },
        async (transaction) => {
          // Serialise cap checks for this owner so two concurrent binds cannot
          // both observe room for one more destination.
          await transaction.query(
            "select pg_advisory_xact_lock(hashtextextended($1, 0))",
            [input.accountId],
          )

          const counted = await transaction.query<{ active: string }>(
            `select count(*)::text as active
               from finance.payout_accounts
              where account_id = $1 and status <> 'disabled'`,
            [input.accountId],
          )
          const active = Number(counted.rows[0]?.active ?? "0")
          if (active >= maxActive) {
            throw new ApiError(
              "LIMIT_EXCEEDED",
              "The approved number of payout destinations has been reached.",
              409,
            )
          }

          const result = await transaction.query<PayoutAccountRow>(
            `insert into finance.payout_accounts
               (account_id, bank_code, bank_name, account_name,
                account_name_normalized, account_number_ciphertext,
                encryption_key_id, account_number_last4,
                account_number_fingerprint, status, verified_at)
             values ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'verified', now())
             returning id, bank_code, bank_name, account_name,
                       account_number_last4, status, verified_at, created_at`,
            [
              input.accountId,
              bankCode,
              bankName,
              accountName,
              normalizeAccountName(accountName),
              encrypted.ciphertext,
              encrypted.keyId,
              encrypted.last4,
              encrypted.fingerprint,
            ],
          )
          const row = result.rows[0]
          if (!row)
            throw new Error("The payout destination insert returned no row.")
          const view = toView(row)

          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "finance.payout_account_bound",
            targetType: "payout_account",
            targetId: view.id,
            afterSummary: {
              bankCode: view.bankCode,
              bankName: view.bankName,
              accountName: view.accountName,
              accountNumberLast4: encrypted.last4,
              state: view.state,
            },
            reason: input.reason,
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })

          return view
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapWriteError(error)
    }
  }

  /**
   * Disables one destination. The database trigger refuses any other update, so
   * the encrypted bank fields cannot be rewritten through this path.
   */
  async disable(input: DisablePayoutAccountInput): Promise<PayoutAccountView> {
    if (!UUID_PATTERN.test(input.id)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The payout destination identifier is invalid.",
        400,
      )
    }
    if (input.reason.trim().length < 5) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "Disabling a payout destination needs a reason of at least five characters.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        {
          identity: { accountId: input.accountId, userId: input.userId },
        },
        async (transaction) => {
          const result = await transaction.query<PayoutAccountRow>(
            `update finance.payout_accounts
                set status = 'disabled', updated_at = now()
              where id = $1 and account_id = $2 and status <> 'disabled'
              returning id, bank_code, bank_name, account_name,
                        account_number_last4, status, verified_at, created_at`,
            [input.id, input.accountId],
          )
          const row = result.rows[0]
          if (!row) {
            throw new ApiError(
              "NOT_FOUND",
              "That payout destination does not exist.",
              404,
            )
          }
          const view = toView(row)

          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "finance.payout_account_disabled",
            targetType: "payout_account",
            targetId: view.id,
            afterSummary: {
              accountNumberLast4: row.account_number_last4,
              state: view.state,
            },
            reason: input.reason,
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })

          return view
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapWriteError(error)
    }
  }
}
