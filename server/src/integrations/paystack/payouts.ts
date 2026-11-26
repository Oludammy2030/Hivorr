import { minorUnitsToMoney, moneyToMinorUnits } from "@hivorr/shared"

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

/**
 * Paystack payout adapter (EP-02-043, provider switch 2026-11-26).
 *
 * Paystack is the active provider for fast integration. This is the payout slice
 * of `PaymentProvider`: account-name resolution, recipient creation, a single
 * transfer and transfer-status verification. Collections (dedicated virtual
 * accounts/webhooks) belong to `EP-02-042`/`044`.
 *
 * Amounts: the port uses NGN with four decimal places. Paystack uses kobo, so
 * the adapter divides the minor-unit amount by 100 and refuses a sub-kobo
 * amount rather than rounding money.
 *
 * The secret key is supplied by the deployment secret store, never by the
 * control portal. The adapter fails closed when the key for the active mode is
 * absent. It never logs the key, the account number or the response body.
 */
export const PAYSTACK_BASE_URL = "https://api.paystack.co"

export type PaystackMode = "test" | "live"

export type PaystackPayoutPort = Pick<PaymentProvider, "provider" | "initiatePayout" | "getPaymentStatus" | "resolveAccountName">

export interface PaystackPayoutOptions {
  readonly baseUrl: string
  readonly mode: PaystackMode
  readonly secretKey: string | undefined
  readonly requestTimeoutMs: number
  readonly maxRetries: number
  readonly retryBaseMs: number
}

export interface PaystackPayoutDependencies {
  readonly fetchImpl?: typeof fetch
  readonly sleep?: (milliseconds: number) => Promise<void>
  readonly now?: () => number
}

interface PaystackEnvelope<T> {
  readonly status?: unknown
  readonly message?: unknown
  readonly data?: T
}

interface PaystackResolveData {
  readonly account_number?: unknown
  readonly account_name?: unknown
}

interface PaystackRecipientData {
  readonly recipient_code?: unknown
}

interface PaystackTransferData {
  readonly reference?: unknown
  readonly transfer_code?: unknown
  readonly status?: unknown
  readonly amount?: unknown
  readonly currency?: unknown
  readonly created_at?: unknown
  readonly transferred_at?: unknown
}

const MAXIMUM_RETRY_DELAY_MS = 2_000
const MAXIMUM_FAILURE_MESSAGE = 200

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

function safeMessage(value: unknown): string | null {
  if (typeof value !== "string") return null
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed.slice(0, MAXIMUM_FAILURE_MESSAGE) : null
}

function statusOf(value: unknown): string {
  return typeof value === "string" ? value.toLowerCase() : ""
}

function paystackKobo(amount: string): bigint {
  const minor = moneyToMinorUnits(amount)
  if (minor === null) {
    throw failure(
      "PROVIDER_INVALID_PAYLOAD",
      "A payout amount must be a positive numeric(20,4) value.",
      false,
    )
  }
  if (minor % 100n !== 0n) {
    throw failure(
      "PROVIDER_INVALID_PAYLOAD",
      "The payout amount has sub-kobo precision.",
      false,
    )
  }
  return minor / 100n
}

export class PaystackPayoutClient implements PaystackPayoutPort {
  readonly provider = "paystack"

  private readonly fetchImpl: typeof fetch
  private readonly sleep: (milliseconds: number) => Promise<void>
  private readonly now: () => number

  constructor(
    private readonly options: PaystackPayoutOptions,
    dependencies: PaystackPayoutDependencies = {},
  ) {
    this.fetchImpl = dependencies.fetchImpl ?? fetch
    this.sleep = dependencies.sleep ?? defaultSleep
    this.now = dependencies.now ?? Date.now
  }

  async resolveAccountName(
    input: AccountNameEnquiryRequest,
  ): Promise<AccountNameEnquiry> {
    if (
      !/^[0-9]{3,10}$/.test(input.bankCode) ||
      !/^[0-9]{10}$/.test(input.accountNumber)
    ) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A name enquiry needs a bank code and a ten-digit account number.",
        false,
      )
    }

    const envelope = await this.send<PaystackResolveData>({
      method: "GET",
      path: "/bank/resolve",
      query: {
        account_number: input.accountNumber,
        bank_code: input.bankCode,
      },
    })

    const name = envelope.data?.account_name
    if (envelope.status !== true || typeof name !== "string" || !name.trim()) {
      throw failure(
        "PROVIDER_NOT_FOUND",
        "Paystack could not resolve that account.",
        false,
      )
    }

    return {
      accountName: name.trim(),
      bankCode: input.bankCode,
      accountNumberLast4: input.accountNumber.slice(-4),
    }
  }

  async initiatePayout(
    input: PayoutRequest,
    _context: ProviderOperationContext,
  ): Promise<PayoutResult> {
    this.validatePayout(input)
    const amount = paystackKobo(input.amount)

    const recipient = await this.send<PaystackRecipientData>({
      method: "POST",
      path: "/transferrecipient",
      body: {
        type: "nuban",
        name: input.accountName.trim(),
        account_number: input.accountNumber,
        bank_code: input.bankCode,
        currency: "NGN",
      },
    })
    const recipientCode = recipient.data?.recipient_code
    if (
      recipient.status !== true ||
      typeof recipientCode !== "string" ||
      recipientCode.length === 0
    ) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "Paystack did not create a transfer recipient.",
        false,
      )
    }

    const transfer = await this.send<PaystackTransferData>({
      method: "POST",
      path: "/transfer",
      body: {
        source: "balance",
        amount: Number(amount),
        recipient: recipientCode,
        reason: input.narration?.trim() || "Hivorr payout",
        reference: input.reference,
      },
    })

    const data = transfer.data
    const state = statusOf(data?.status)
    const providerReference =
      typeof data?.transfer_code === "string"
        ? data.transfer_code
        : typeof data?.reference === "string"
          ? data.reference
          : input.reference

    if (transfer.status !== true) {
      const message = safeMessage(transfer.message)
      if (/duplicate|already/i.test(message ?? "")) {
        throw failure(
          "PROVIDER_DUPLICATE",
          "Paystack already has a transfer with that reference.",
          false,
        )
      }
      throw failure(
        "PROVIDER_REJECTED",
        message ?? "Paystack rejected the transfer.",
        false,
      )
    }

    if (state === "success") {
      return {
        provider: this.provider,
        reference: input.reference,
        providerReference,
        status: "paid",
        failureCode: null,
        failureMessage: null,
        occurredAt: this.nowIso(),
      }
    }

    if (
      state === "pending" ||
      state === "processing" ||
      state === "otp" ||
      state === "received"
    ) {
      return {
        provider: this.provider,
        reference: input.reference,
        providerReference,
        status: "processing",
        failureCode: null,
        failureMessage: null,
        occurredAt: this.nowIso(),
      }
    }

    return {
      provider: this.provider,
      reference: input.reference,
      providerReference,
      status: "failed",
      failureCode: `PAYSTACK_${(state || "UNKNOWN").toUpperCase()}`,
      failureMessage:
        safeMessage(transfer.message) ?? "Paystack reported a failed transfer.",
      occurredAt: this.nowIso(),
    }
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

    const envelope = await this.send<PaystackTransferData>({
      method: "GET",
      path: `/transfer/verify/${encodeURIComponent(reference)}`,
    })

    if (envelope.status !== true || !envelope.data) {
      const message = safeMessage(envelope.message)
      if (/not\s*found|no\s*transfer/i.test(message ?? "")) {
        throw failure(
          "PROVIDER_NOT_FOUND",
          "Paystack does not know that reference.",
          false,
        )
      }
      throw failure(
        "PROVIDER_REJECTED",
        message ?? "Paystack rejected the status query.",
        false,
      )
    }

    const data = envelope.data
    const state = statusOf(data.status)
    const amountKobo =
      typeof data.amount === "number" && Number.isFinite(data.amount)
        ? BigInt(Math.trunc(data.amount))
        : typeof data.amount === "string" && /^[0-9]+$/.test(data.amount)
          ? BigInt(data.amount)
          : null
    if (amountKobo === null) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "Paystack returned an unreadable amount.",
        false,
      )
    }

    const status: PaymentStatus["status"] =
      state === "success"
        ? "paid"
        : state === "pending" ||
            state === "processing" ||
            state === "otp" ||
            state === "received"
          ? "pending"
          : "failed"

    return {
      provider: this.provider,
      reference: query.reference ?? null,
      providerReference:
        typeof data.transfer_code === "string"
          ? data.transfer_code
          : typeof data.reference === "string"
            ? data.reference
            : reference,
      status,
      amount: minorUnitsToMoney(amountKobo * 100n),
      currency: "NGN",
      occurredAt: this.isoOf(data.transferred_at ?? data.created_at),
    }
  }

  private validatePayout(input: PayoutRequest): void {
    if (!input.reference.trim() || input.reference.length > 100) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout reference is one to 100 characters.",
        false,
      )
    }
    if (input.currency !== "NGN") {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "Paystack payouts are NGN only.",
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
  }

  private nowIso(): string {
    return new Date(this.now()).toISOString()
  }

  private isoOf(value: unknown): string {
    if (typeof value === "string" && value.trim()) {
      const parsed = new Date(value)
      if (!Number.isNaN(parsed.getTime())) return parsed.toISOString()
    }
    return this.nowIso()
  }

  private async send<T,>(request: {
    readonly method: "GET" | "POST"
    readonly path: string
    readonly query?: Readonly<Record<string, string>>
    readonly body?: unknown
  }): Promise<PaystackEnvelope<T>> {
    const key = this.options.secretKey
    if (!key) {
      throw failure(
        "PROVIDER_AUTH_FAILED",
        "Paystack is not configured for the active mode.",
        false,
      )
    }

    const url = new URL(`${this.options.baseUrl}${request.path}`)
    for (const [name, value] of Object.entries(request.query ?? {})) {
      url.searchParams.set(name, value)
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
            authorization: `Bearer ${key}`,
            ...(request.body ? { "content-type": "application/json" } : {}),
          },
          ...(request.body ? { body: JSON.stringify(request.body) } : {}),
          signal: controller.signal,
        })

        if (response.status === 401 || response.status === 403) {
          throw failure(
            "PROVIDER_AUTH_FAILED",
            "Paystack rejected the secret key.",
            false,
          )
        }
        if (response.status === 429 || response.status >= 500) {
          lastError = failure(
            "PROVIDER_UNAVAILABLE",
            "Paystack is unavailable.",
            true,
          )
          continue
        }
        if (!response.ok) {
          const payload = (await response
            .json()
            .catch(() => null)) as PaystackEnvelope<T> | null
          const message = safeMessage(payload?.message)
          if (/duplicate|already/i.test(message ?? "")) {
            throw failure(
              "PROVIDER_DUPLICATE",
              "Paystack already has a transfer with that reference.",
              false,
            )
          }
          if (/not\s*found/i.test(message ?? "")) {
            throw failure(
              "PROVIDER_NOT_FOUND",
              message ?? "Paystack could not find the resource.",
              false,
            )
          }
          throw failure(
            "PROVIDER_REJECTED",
            message ?? "Paystack rejected the request.",
            false,
          )
        }

        const payload = (await response
          .json()
          .catch(() => null)) as PaystackEnvelope<T> | null
        if (!payload) {
          throw failure(
            "PROVIDER_INVALID_PAYLOAD",
            "Paystack returned an unreadable response.",
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
            "Paystack did not answer in time.",
            true,
          )
          continue
        }
        lastError = failure(
          "PROVIDER_UNAVAILABLE",
          "The Paystack request failed.",
          true,
        )
      } finally {
        clearTimeout(timer)
      }
    }

    throw (
      lastError ??
      failure("PROVIDER_UNAVAILABLE", "Paystack is unavailable.", true)
    )
  }
}
