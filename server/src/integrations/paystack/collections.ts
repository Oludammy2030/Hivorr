import { createHmac, timingSafeEqual } from "node:crypto"

import { minorUnitsToMoney } from "@hivorr/shared"

import {
  PaymentProviderError,
  type CollectionAccount,
  type CollectionAccountRequest,
  type DepositEvent,
  type PaymentProviderErrorCode,
  type ProviderOperationContext,
} from "../payments/payment-provider"
import type {
  PaystackPayoutDependencies,
  PaystackPayoutOptions,
} from "./payouts"

/**
 * Paystack collections adapter (EP-02-042/044, provider switch 2026-11-26).
 *
 * A wallet is funded through a dedicated virtual account (DVA) created for the
 * account. The webhook is treated as a trigger only: the adapter verifies the
 * transaction with Paystack and the signature before a deposit can post.
 *
 * Amounts: Paystack reports kobo; the port uses NGN numeric(20,4). The adapter
 * multiplies kobo by 100, never using floating point.
 *
 * No key, account number or raw payload is logged.
 */
export interface PaystackCollectionsOptions extends PaystackPayoutOptions {
  readonly preferredBank: string
}

export interface PaystackCollections {
  provisionCollectionAccount(
    input: CollectionAccountRequest,
    context: ProviderOperationContext,
  ): Promise<CollectionAccount>

  normaliseDepositEvent(payload: unknown): DepositEvent

  verifyTransaction(reference: string): Promise<DepositEvent>
}

interface PaystackCustomerData {
  readonly customer_code?: unknown
}

interface PaystackDedicatedAccountData {
  readonly account_number?: unknown
  readonly account_name?: unknown
  readonly bank?: { readonly name?: unknown }
}

interface PaystackTransactionData {
  readonly reference?: unknown
  readonly amount?: unknown
  readonly currency?: unknown
  readonly status?: unknown
  readonly paid_at?: unknown
  readonly created_at?: unknown
  readonly customer?: {
    readonly email?: unknown
    readonly customer_code?: unknown
  }
  readonly authorization?: {
    readonly sender_name?: unknown
    readonly sender_bank_account_number?: unknown
    readonly receiver_bank_account_number?: unknown
  }
  readonly dedicated_account?: {
    readonly account_number?: unknown
  }
}

interface PaystackEnvelope<T> {
  readonly status?: unknown
  readonly message?: unknown
  readonly data?: T
}

const MAXIMUM_RETRY_DELAY_MS = 2_000

function failure(
  code: PaymentProviderErrorCode,
  message: string,
  retryable: boolean,
): PaymentProviderError {
  return new PaymentProviderError(code, message, { retryable })
}

function defaultSleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function valueOf(value: unknown): string | null {
  if (typeof value === "string" && value.trim()) return value.trim()
  if (typeof value === "number" && Number.isFinite(value)) return String(value)
  return null
}

function koboToMoney(value: unknown): string {
  const kobo =
    typeof value === "number" && Number.isFinite(value)
      ? BigInt(Math.trunc(value))
      : typeof value === "string" && /^[0-9]+$/.test(value)
        ? BigInt(value)
        : null
  if (kobo === null) {
    throw failure(
      "PROVIDER_INVALID_PAYLOAD",
      "Paystack returned an unreadable amount.",
      false,
    )
  }
  // 1 NGN = 100 kobo; the port uses 1/10,000 NGN.
  return minorUnitsToMoney(kobo * 100n)
}

export function verifyPaystackSignature(
  rawBody: Buffer,
  signature: string,
  secretKey: string,
): boolean {
  if (!signature || !secretKey) return false
  const expected = createHmac("sha512", secretKey).update(rawBody).digest("hex")
  const given = Buffer.from(signature.trim().toLowerCase(), "hex")
  const wanted = Buffer.from(expected, "hex")
  if (given.length !== wanted.length) return false
  return timingSafeEqual(given, wanted)
}

export class PaystackCollectionsClient implements PaystackCollections {
  readonly provider = "paystack"

  private readonly fetchImpl: typeof fetch
  private readonly sleep: (milliseconds: number) => Promise<void>

  constructor(
    private readonly options: PaystackCollectionsOptions,
    dependencies: PaystackPayoutDependencies = {},
  ) {
    this.fetchImpl = dependencies.fetchImpl ?? fetch
    this.sleep = dependencies.sleep ?? defaultSleep
  }

  async provisionCollectionAccount(
    input: CollectionAccountRequest,
    _context: ProviderOperationContext,
  ): Promise<CollectionAccount> {
    if (!input.email) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "Paystack needs an email to create a collection account.",
        false,
      )
    }
    if (!input.reference.trim()) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A collection account needs a reference.",
        false,
      )
    }

    const customer = await this.send<PaystackCustomerData>({
      method: "POST",
      path: "/customer",
      body: {
        email: input.email,
        first_name: input.accountName,
      },
    })
    const customerCode = valueOf(customer.data?.customer_code)
    if (customer.status !== true || !customerCode) {
      throw failure(
        "PROVIDER_REJECTED",
        "Paystack did not create a customer.",
        false,
      )
    }

    const account = await this.send<PaystackDedicatedAccountData>({
      method: "POST",
      path: "/dedicated_account",
      body: {
        customer: customerCode,
        preferred_bank: this.options.preferredBank,
      },
    })
    const accountNumber = valueOf(account.data?.account_number)
    const accountName = valueOf(account.data?.account_name)
    if (account.status !== true || !accountNumber || !accountName) {
      throw failure(
        "PROVIDER_REJECTED",
        "Paystack did not create a dedicated virtual account.",
        false,
      )
    }

    return {
      provider: this.provider,
      reference: input.reference,
      accountNumber,
      accountName,
      bankName: valueOf(account.data?.bank?.name),
      currency: input.currency,
      status: "active",
    }
  }

  normaliseDepositEvent(payload: unknown): DepositEvent {
    if (!payload || typeof payload !== "object") {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A deposit event must be an object.",
        false,
      )
    }
    const envelope = payload as {
      event?: unknown
      data?: PaystackTransactionData
    }
    if (envelope.event !== undefined && envelope.event !== "charge.success") {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "That Paystack event is not a successful charge.",
        false,
      )
    }
    const data = envelope.data
    const reference = valueOf(data?.reference)
    if (!data || !reference) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A Paystack deposit is missing its reference.",
        false,
      )
    }

    const collectionAccountReference =
      valueOf(data.dedicated_account?.account_number) ??
      valueOf(data.authorization?.receiver_bank_account_number) ??
      valueOf(data.customer?.customer_code)
    if (!collectionAccountReference) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A Paystack deposit is not linked to a collection account.",
        false,
      )
    }

    const status =
      data.status === "success"
        ? "received"
        : data.status === "failed" || data.status === "reversed"
          ? "failed"
          : "pending"
    const last4Raw = valueOf(data.authorization?.sender_bank_account_number)
    const payerAccountLast4 =
      last4Raw && /^[0-9]{4,}$/.test(last4Raw) ? last4Raw.slice(-4) : null

    return {
      provider: this.provider,
      reference,
      collectionAccountReference,
      amount: koboToMoney(data.amount),
      currency: valueOf(data.currency) ?? "NGN",
      payerName:
        valueOf(data.authorization?.sender_name) ??
        valueOf(data.customer?.email) ??
        "PAYSTACK CUSTOMER",
      payerAccountLast4,
      status,
      occurredAt:
        valueOf(data.paid_at) ??
        valueOf(data.created_at) ??
        new Date().toISOString(),
    }
  }

  async verifyTransaction(reference: string): Promise<DepositEvent> {
    if (!reference.trim()) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A transaction reference is required.",
        false,
      )
    }
    const envelope = await this.send<PaystackTransactionData>({
      method: "GET",
      path: `/transaction/verify/${encodeURIComponent(reference)}`,
    })
    if (envelope.status !== true || !envelope.data) {
      throw failure(
        "PROVIDER_NOT_FOUND",
        "Paystack could not verify that transaction.",
        false,
      )
    }
    return this.normaliseDepositEvent({
      event: "charge.success",
      data: envelope.data,
    })
  }

  private async send<T,>(request: {
    readonly method: "GET" | "POST"
    readonly path: string
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
          const message =
            typeof payload?.message === "string" ? payload.message : undefined
          if (/duplicate|already/i.test(message ?? "")) {
            throw failure(
              "PROVIDER_DUPLICATE",
              "Paystack already has that record.",
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
