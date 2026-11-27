/**
 * Payment provider port (EP-02-040).
 *
 * This is the only payment vocabulary the rest of Hivorr sees. No VFD type,
 * endpoint, header or envelope belongs here: an adapter translates between this
 * port and one provider, and a second adapter can be added without a schema
 * change beyond `finance.provider_references`.
 *
 * The port moves no money by itself. `normaliseDepositEvent` interprets a raw
 * event; `initiatePayout` asks a provider to move funds. The service layer
 * decides when either is allowed.
 */
export interface ProviderOperationContext {
  /** Stable key for this operation; the adapter must not create two effects. */
  readonly idempotencyKey: string
  readonly correlationId?: string
}

export interface CollectionAccountRequest {
  /** Hivorr's stable reference for the account that owns the wallet. */
  readonly reference: string
  readonly accountName: string
  readonly currency: string
  readonly email?: string
  readonly phone?: string
}

export interface CollectionAccount {
  readonly provider: string
  readonly reference: string
  /** Virtual account number used for deposits. Never a card number. */
  readonly accountNumber: string
  readonly accountName: string
  readonly bankName: string | null
  readonly currency: string
  readonly status: "active" | "pending"
}

export interface DepositEvent {
  readonly provider: string
  /** Provider-side reference for this deposit. */
  readonly reference: string
  readonly collectionAccountReference: string
  readonly amount: string
  readonly currency: string
  readonly payerName: string
  readonly payerAccountLast4: string | null
  readonly status: "received" | "pending" | "failed" | "reversed"
  readonly occurredAt: string
}

export interface PayoutRequest {
  readonly reference: string
  readonly amount: string
  readonly currency: string
  readonly bankCode: string
  /**
   * Plain account number, supplied only at call time from the encrypted payout
   * record. An adapter must never log, persist or echo it.
   */
  readonly accountNumber: string
  readonly accountName: string
  readonly narration?: string
}

export interface PayoutResult {
  readonly provider: string
  readonly reference: string
  readonly providerReference: string
  readonly status: "pending" | "processing" | "paid" | "failed"
  readonly failureCode: string | null
  readonly failureMessage: string | null
  readonly occurredAt: string
}

export interface PaymentStatusQuery {
  readonly providerReference: string
  readonly reference?: string
}

export interface PaymentStatus {
  readonly provider: string
  readonly reference: string | null
  readonly providerReference: string
  readonly status: "pending" | "processing" | "paid" | "failed" | "reversed"
  readonly amount: string
  readonly currency: string
  readonly occurredAt: string
}

export interface AccountNameEnquiryRequest {
  readonly bankCode: string
  readonly accountNumber: string
}

export interface AccountNameEnquiry {
  readonly accountName: string
  readonly bankCode: string
  /** The only account-number material an adapter may return. */
  readonly accountNumberLast4: string
}

export interface PaymentProvider {
  /** Stable lowercase provider key, stored with every reference. */
  readonly provider: string

  provisionCollectionAccount(
    input: CollectionAccountRequest,
    context: ProviderOperationContext,
  ): Promise<CollectionAccount>

  /** Maps a raw provider event into the neutral deposit shape, or throws. */
  normaliseDepositEvent(payload: unknown): DepositEvent

  initiatePayout(input: PayoutRequest, context: ProviderOperationContext): Promise<PayoutResult>

  getPaymentStatus(query: PaymentStatusQuery): Promise<PaymentStatus>

  resolveAccountName(input: AccountNameEnquiryRequest): Promise<AccountNameEnquiry>
}

export const PAYMENT_PROVIDER_ERROR_CODES = [
  "PROVIDER_UNAVAILABLE",
  "PROVIDER_TIMEOUT",
  "PROVIDER_AUTH_FAILED",
  "PROVIDER_REJECTED",
  "PROVIDER_DUPLICATE",
  "PROVIDER_NOT_FOUND",
  "PROVIDER_INVALID_PAYLOAD",
] as const

export type PaymentProviderErrorCode = (typeof PAYMENT_PROVIDER_ERROR_CODES)[number]

const RETRYABLE: ReadonlySet<PaymentProviderErrorCode> = new Set([
  "PROVIDER_UNAVAILABLE",
  "PROVIDER_TIMEOUT",
])

/**
 * A provider failure with a stable code. Callers decide whether to retry from
 * `retryable`, never from an HTTP status in a vendor envelope.
 */
export class PaymentProviderError extends Error {
  readonly code: PaymentProviderErrorCode
  readonly retryable: boolean
  readonly providerReference: string | null
  readonly originalError: unknown

  constructor(
    code: PaymentProviderErrorCode,
    message: string,
    options: {
      readonly retryable?: boolean
      readonly providerReference?: string | null
      readonly cause?: unknown
    } = {},
  ) {
    super(message)
    this.name = "PaymentProviderError"
    this.code = code
    this.retryable = options.retryable ?? RETRYABLE.has(code)
    this.providerReference = options.providerReference ?? null
    this.originalError = options.cause ?? null
  }
}

export function isPaymentProviderError(value: unknown): value is PaymentProviderError {
  return value instanceof PaymentProviderError
}
