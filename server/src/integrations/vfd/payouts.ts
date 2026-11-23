import { createHash } from "node:crypto"

import {
  currencyCodeSchema,
  minorUnitsToMoney,
  moneyToMinorUnits,
} from "@hivorr/shared"

import {
  PaymentProviderError,
  type AccountNameEnquiry,
  type AccountNameEnquiryRequest,
  type PaymentProvider,
  type PaymentProviderErrorCode,
  type PaymentStatus,
  type PaymentStatusQuery,
  type PayoutRequest,
  type PayoutResult,
  type ProviderOperationContext,
} from "../payments/payment-provider"
import { VFD_WALLET_BASE_URLS, type VfdAccountNameClient } from "./account-name"
import { type VfdAuthClient } from "./auth"

/**
 * VFD single-transfer payout adapter (EP-02-043).
 *
 * The documented flow is: query the beneficiary, sign, then `POST /transfer`.
 * This client implements that flow behind the payout slice of `PaymentProvider`.
 * The collections slice (`provisionCollectionAccount`/`normaliseDepositEvent`)
 * belongs to `EP-02-042`; a composition satisfies the full port once both
 * halves exist.
 *
 * Deliberately explicit about vendor facts:
 *
 * - the documented signature is `SHA512(fromAccount + toAccount)` hex. The
 *   published sample transfer's signature is exactly that value, so the default
 *   signer implements it and no secret is invented. A deployment may still
 *   inject a different signer.
 * - the source wallet profile is read from the documented `/account/enquiry`
 *   endpoint; only the source account number is configuration.
 * - the transfer amount unit is not documented. The canonical decimal amount is
 *   sent unchanged and the ambiguity is recorded for `EP-02-045`.
 * - only `NGN` is accepted, because the VFD wallet has no documented currency
 *   field in the transfer payload.
 *
 * No credential, account number or response body is logged.
 */
export const VFD_TRANSFER_TYPE = "inter"

export type VfdPayoutPort = Pick<PaymentProvider, "provider" | "initiatePayout" | "getPaymentStatus" | "resolveAccountName">

export interface VfdTransferSignatureInput {
  readonly fromAccount: string
  readonly toAccount: string
  readonly reference: string
  /** Canonical `numeric(20,4)` string, as sent in the transfer payload. */
  readonly amount: string
}

export interface VfdTransferSigner {
  sign(input: VfdTransferSignatureInput): string
}

/**
 * The signature documented for a single transfer. The vendor page says
 * `SHA512(fromAccount + toAccount)` and its own sample value is exactly that
 * digest, so the adapter follows the published value rather than assuming an
 * unreferenced secret.
 */
export class VfdSha512TransferSigner implements VfdTransferSigner {
  sign(input: VfdTransferSignatureInput): string {
    return createHash("sha512")
      .update(`${input.fromAccount}${input.toAccount}`, "utf8")
      .digest("hex")
  }
}

export interface VfdPayoutOptions {
  readonly requestTimeoutMs: number
  readonly maxRetries: number
  readonly retryBaseMs: number
  /** The wallet account that funds a payout. Unset refuses to send. */
  readonly sourceAccountNumber?: string
  readonly signer?: VfdTransferSigner
}

export interface VfdPayoutDependencies {
  readonly fetchImpl?: typeof fetch
  readonly sleep?: (milliseconds: number) => Promise<void>
  readonly now?: () => number
}

interface VfdTransferEnvelope {
  readonly status?: unknown
  readonly message?: unknown
  readonly data?: {
    readonly txnId?: unknown
    readonly sessionId?: unknown
    readonly reference?: unknown
  }
}

interface VfdStatusEnvelope {
  readonly status?: unknown
  readonly message?: unknown
  readonly data?: {
    readonly TxnId?: unknown
    readonly amount?: unknown
    readonly transactionStatus?: unknown
    readonly transactionDate?: unknown
    readonly sessionId?: unknown
  }
}

const MAXIMUM_RETRY_DELAY_MS = 2_000
const MAXIMUM_FAILURE_MESSAGE = 200

/** Direct transfer response codes, per VFD_WALLET.md §15. */
const TRANSFER_PENDING_CODES = new Set(["01", "09", "25", "94", "96", "500"])
const TRANSFER_SUCCESS_CODES = new Set(["00"])
const TRANSACTION_QUERY_SUCCESS_CODES = new Set(["00", "26"])
const TRANSACTION_QUERY_PENDING_CODES = new Set([
  "01",
  "02",
  "09",
  "25",
  "94",
  "96",
  "500",
])

function defaultSleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function failure(
  code: PaymentProviderErrorCode,
  message: string,
  retryable: boolean,
): PaymentProviderError {
  return new PaymentProviderError(code, message, { retryable })
}

function stringOf(value: unknown): string | null {
  if (typeof value === "string" && value.trim().length > 0) return value.trim()
  if (typeof value === "number" && Number.isFinite(value)) return String(value)
  return null
}

function safeMessage(value: unknown): string | null {
  if (typeof value !== "string") return null
  const trimmed = value.trim()
  if (trimmed.length === 0) return null
  return trimmed.slice(0, MAXIMUM_FAILURE_MESSAGE)
}

function parseVendorDate(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw failure(
      "PROVIDER_INVALID_PAYLOAD",
      "VFD returned no transaction date.",
      false,
    )
  }
  // The documented form is `YYYY-MM-DD HH:mm:ss.s`. The vendor does not state a
  // zone; the ledger stores UTC and the ambiguity is recorded for EP-02-045.
  const normalised = value.trim().replace(" ", "T")
  const parsed = new Date(
    /(?:Z|[+-]\d{2}:?\d{2})$/.test(normalised) ? normalised : `${normalised}Z`,
  )
  if (Number.isNaN(parsed.getTime())) {
    throw failure(
      "PROVIDER_INVALID_PAYLOAD",
      "VFD returned an unreadable transaction date.",
      false,
    )
  }
  return parsed.toISOString()
}

function fingerprintOf(input: PayoutRequest): string {
  return JSON.stringify({
    reference: input.reference,
    amount: input.amount,
    currency: input.currency,
    bankCode: input.bankCode,
    accountLast4: input.accountNumber.slice(-4),
    accountName: input.accountName,
  })
}

export class VfdPayoutClient implements VfdPayoutPort {
  readonly provider = "vfd"

  private readonly fetchImpl: typeof fetch
  private readonly sleep: (milliseconds: number) => Promise<void>
  private readonly now: () => number
  private readonly attempts: Map<string, {
    readonly fingerprint: string
    readonly result: PayoutResult
  }> = new Map()

  constructor(
    private readonly auth: VfdAuthClient,
    private readonly accountNames: VfdAccountNameClient,
    private readonly options: VfdPayoutOptions,
    dependencies: VfdPayoutDependencies = {},
  ) {
    this.fetchImpl = dependencies.fetchImpl ?? fetch
    this.sleep = dependencies.sleep ?? defaultSleep
    this.now = dependencies.now ?? Date.now
  }

  async resolveAccountName(
    input: AccountNameEnquiryRequest,
  ): Promise<AccountNameEnquiry> {
    return this.accountNames.resolveAccountName(input)
  }

  async initiatePayout(
    input: PayoutRequest,
    context: ProviderOperationContext,
  ): Promise<PayoutResult> {
    const amountMinor = this.validatePayout(input)

    const sourceAccountNumber = this.options.sourceAccountNumber
    if (!sourceAccountNumber) {
      throw failure(
        "PROVIDER_AUTH_FAILED",
        "VFD source account is not configured.",
        false,
      )
    }
    const signer = this.options.signer ?? new VfdSha512TransferSigner()

    const fingerprint = fingerprintOf(input)
    const replay = this.attempts.get(context.idempotencyKey)
    if (replay) {
      if (replay.fingerprint !== fingerprint) {
        throw failure(
          "PROVIDER_DUPLICATE",
          "That idempotency key already describes a different payout.",
          false,
        )
      }
      return replay.result
    }

    const source = await this.accountNames.enquireSource(sourceAccountNumber)
    const recipient = await this.accountNames.enquireRecipient({
      bankCode: input.bankCode,
      accountNumber: input.accountNumber,
    })
    const toClientId = recipient.clientId
    const toSession = recipient.accountId
    if (!toClientId || !toSession) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "VFD did not return the beneficiary identifiers a transfer needs.",
        false,
      )
    }

    const amount = minorUnitsToMoney(amountMinor)
    const signature = signer.sign({
      fromAccount: source.accountNumber,
      toAccount: input.accountNumber,
      reference: input.reference,
      amount,
    })

    const envelope = await this.send<VfdTransferEnvelope>({
      method: "POST",
      path: "/transfer",
      body: {
        fromAccount: source.accountNumber,
        uniqueSenderAccountId: "",
        fromClientId: source.clientId,
        fromClient: source.clientName,
        fromSavingsId: source.savingsId,
        toClientId,
        toClient: recipient.accountName,
        toSession,
        toSavingsId: "",
        ...(recipient.bvn ? { toBvn: recipient.bvn } : {}),
        toAccount: input.accountNumber,
        toBank: input.bankCode,
        signature,
        amount,
        remark: input.narration?.trim() || "Hivorr payout",
        transferType: VFD_TRANSFER_TYPE,
        reference: input.reference,
      },
    })

    const result = this.transferResult(input, envelope)
    this.attempts.set(context.idempotencyKey, { fingerprint, result })
    return result
  }

  async getPaymentStatus(query: PaymentStatusQuery): Promise<PaymentStatus> {
    const reference = query.reference ?? query.providerReference
    if (!reference) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A status query needs a reference.",
        false,
      )
    }

    const envelope = await this.send<VfdStatusEnvelope>({
      method: "GET",
      path: "/transactions",
      query: { reference },
    })

    if (envelope.status !== "00") {
      if (envelope.status === "108") {
        throw failure(
          "PROVIDER_NOT_FOUND",
          "VFD does not know that reference.",
          false,
        )
      }
      throw failure(
        "PROVIDER_REJECTED",
        "VFD rejected the status query.",
        false,
      )
    }

    const data = envelope.data
    const code = stringOf(data?.transactionStatus)
    if (!code) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "VFD returned no transaction status.",
        false,
      )
    }

    const amountMinor = moneyToMinorUnits(stringOf(data?.amount) ?? "")
    if (amountMinor === null) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "VFD returned an unreadable amount.",
        false,
      )
    }

    const status: PaymentStatus["status"] = TRANSACTION_QUERY_SUCCESS_CODES.has(
      code,
    )
      ? "paid"
      : TRANSACTION_QUERY_PENDING_CODES.has(code)
        ? "pending"
        : "failed"

    return {
      provider: this.provider,
      reference: query.reference ?? null,
      providerReference:
        stringOf(data?.TxnId) ?? stringOf(data?.sessionId) ?? reference,
      status,
      amount: minorUnitsToMoney(amountMinor),
      // The documented TSQ response has no currency field. The VFD wallet is
      // NGN and the adapter refuses any other payout currency.
      currency: "NGN",
      occurredAt: parseVendorDate(data?.transactionDate),
    }
  }

  private validatePayout(input: PayoutRequest): bigint {
    if (!input.reference.trim() || input.reference.length > 120) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout reference is one to 120 characters.",
        false,
      )
    }
    if (!currencyCodeSchema.safeParse(input.currency).success) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout currency is invalid.",
        false,
      )
    }
    if (input.currency !== "NGN") {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "The VFD wallet supports NGN payouts only.",
        false,
      )
    }
    const amountMinor = moneyToMinorUnits(input.amount)
    if (amountMinor === null) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout amount must be a positive numeric(20,4) value.",
        false,
      )
    }
    if (!/^[0-9]{3,10}$/.test(input.bankCode)) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout bank code is three to ten digits.",
        false,
      )
    }
    if (!/^[0-9]{10}$/.test(input.accountNumber)) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout account number is ten digits.",
        false,
      )
    }
    if (
      input.accountName.trim().length === 0 ||
      input.accountName.trim().length > 160
    ) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout account name is one to 160 characters.",
        false,
      )
    }
    return amountMinor
  }

  private transferResult(
    input: PayoutRequest,
    envelope: VfdTransferEnvelope,
  ): PayoutResult {
    const status = stringOf(envelope.status)
    if (!status) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "VFD returned an unreadable transfer response.",
        false,
      )
    }

    if (status === "98") {
      throw failure(
        "PROVIDER_DUPLICATE",
        "VFD already has a transfer with that reference.",
        false,
      )
    }
    // The vendor table also lists 02 as a pending status, but the transfer
    // failure table defines it as a signature mismatch. Treat it as a refusal.
    if (status === "02") {
      throw failure(
        "PROVIDER_AUTH_FAILED",
        "VFD rejected the transfer signature.",
        false,
      )
    }

    const providerReference =
      stringOf(envelope.data?.txnId) ??
      stringOf(envelope.data?.sessionId) ??
      stringOf(envelope.data?.reference) ??
      input.reference
    const now = new Date(this.now()).toISOString()

    if (TRANSFER_SUCCESS_CODES.has(status)) {
      return {
        provider: this.provider,
        reference: input.reference,
        providerReference,
        status: "pending",
        failureCode: null,
        failureMessage: null,
        occurredAt: now,
      }
    }

    if (TRANSFER_PENDING_CODES.has(status)) {
      return {
        provider: this.provider,
        reference: input.reference,
        providerReference,
        status: "processing",
        failureCode: null,
        failureMessage: null,
        occurredAt: now,
      }
    }

    return {
      provider: this.provider,
      reference: input.reference,
      providerReference,
      status: "failed",
      failureCode: `VFD_${status}`,
      failureMessage:
        safeMessage(envelope.message) ?? "VFD reported a failed transfer.",
      occurredAt: now,
    }
  }

  private async send<T,>(request: {
    readonly method: "GET" | "POST"
    readonly path: string
    readonly query?: Readonly<Record<string, string>>
    readonly body?: unknown
  }): Promise<T> {
    const url = new URL(
      `${VFD_WALLET_BASE_URLS[this.auth.mode]}${request.path}`,
    )
    for (const [key, value] of Object.entries(request.query ?? {})) {
      url.searchParams.set(key, value)
    }

    let lastError: PaymentProviderError | null = null

    for (let attempt = 0; attempt <= this.options.maxRetries; attempt += 1) {
      if (attempt > 0) {
        const delay = Math.min(
          this.options.retryBaseMs * 2 ** (attempt - 1),
          MAXIMUM_RETRY_DELAY_MS,
        )
        await this.sleep(delay)
      }

      const token = await this.auth.getToken()
      const controller = new AbortController()
      const timer = setTimeout(
        () => controller.abort(),
        this.options.requestTimeoutMs,
      )

      try {
        const response = await this.fetchImpl(url, {
          method: request.method,
          headers: {
            accept: "application/json",
            ...(request.body ? { "content-type": "application/json" } : {}),
            AccessToken: token,
          },
          ...(request.body ? { body: JSON.stringify(request.body) } : {}),
          signal: controller.signal,
        })

        if (response.status === 401 || response.status === 403) {
          this.auth.invalidate()
          throw failure(
            "PROVIDER_AUTH_FAILED",
            "VFD rejected the access token.",
            false,
          )
        }

        if (response.status === 429 || response.status >= 500) {
          lastError = failure(
            "PROVIDER_UNAVAILABLE",
            "VFD is unavailable.",
            true,
          )
          continue
        }

        if (!response.ok) {
          throw failure("PROVIDER_REJECTED", "VFD rejected the request.", false)
        }

        const payload = (await response.json().catch(() => null)) as T | null
        if (!payload) {
          throw failure(
            "PROVIDER_INVALID_PAYLOAD",
            "VFD returned an unreadable response.",
            false,
          )
        }
        return payload
      } catch (error) {
        if (error instanceof PaymentProviderError) {
          if (!error.retryable) throw error
          lastError = error
          continue
        }
        if (controller.signal.aborted) {
          lastError = failure(
            "PROVIDER_TIMEOUT",
            "VFD did not answer in time.",
            true,
          )
          continue
        }
        lastError = failure(
          "PROVIDER_UNAVAILABLE",
          "The VFD request failed.",
          true,
        )
      } finally {
        clearTimeout(timer)
      }
    }

    throw (
      lastError ?? failure("PROVIDER_UNAVAILABLE", "VFD is unavailable.", true)
    )
  }
}
