import { currencyCodeSchema, minorUnitsToMoney, moneyToMinorUnits } from "@hivorr/shared"

import {
  PaymentProviderError,
  type AccountNameEnquiry,
  type AccountNameEnquiryRequest,
  type CollectionAccount,
  type CollectionAccountRequest,
  type DepositEvent,
  type PaymentProvider,
  type PaymentProviderErrorCode,
  type PaymentStatus,
  type PaymentStatusQuery,
  type PayoutRequest,
  type PayoutResult,
  type ProviderOperationContext,
} from "./payment-provider"

/**
 * In-memory provider used by the port contract suite and by service tests.
 *
 * It behaves like a provider, not like a mock: accounts and payouts are
 * idempotent by reference and key, unknown statuses are not found, and a
 * malformed event is rejected with a typed error. It persists no full account
 * number and logs nothing.
 */
export class FakePaymentProvider implements PaymentProvider {
  readonly provider: string

  private readonly accounts = new Map<string, CollectionAccount>()
  private readonly payouts = new Map<
    string,
    {
      readonly fingerprint: string
      readonly result: PayoutResult
    }
  >()
  private readonly statuses = new Map<string, PaymentStatus>()
  private sequence = 0
  private pendingFailure: PaymentProviderErrorCode | null = null

  constructor(
    private readonly options: {
      readonly accountName?: string
      readonly providerName?: string
    } = {},
  ) {
    this.provider = options.providerName ?? "fake"
  }

  /** Test hook: the next payout throws this code exactly once. */
  failNextPayout(code: PaymentProviderErrorCode): void {
    this.pendingFailure = code
  }

  async provisionCollectionAccount(
    input: CollectionAccountRequest,
    _context: ProviderOperationContext,
  ): Promise<CollectionAccount> {
    if (!input.reference.trim()) {
      throw new PaymentProviderError(
        "PROVIDER_INVALID_PAYLOAD",
        "A collection account needs a reference.",
      )
    }
    if (!currencyCodeSchema.safeParse(input.currency).success) {
      throw new PaymentProviderError(
        "PROVIDER_INVALID_PAYLOAD",
        "A collection account needs a currency.",
      )
    }

    const existing = this.accounts.get(input.reference)
    if (existing) return existing

    this.sequence += 1
    const account: CollectionAccount = {
      provider: this.provider,
      reference: input.reference,
      accountNumber: `99${String(this.sequence).padStart(8, "0")}`,
      accountName: input.accountName,
      bankName: "Fake Bank",
      currency: input.currency,
      status: "active",
    }
    this.accounts.set(input.reference, account)
    return account
  }

  normaliseDepositEvent(payload: unknown): DepositEvent {
    if (!payload || typeof payload !== "object") {
      throw new PaymentProviderError(
        "PROVIDER_INVALID_PAYLOAD",
        "A deposit event must be an object.",
      )
    }
    const record = payload as Record<string, unknown>
    const required = [
      "reference",
      "collectionAccountReference",
      "amount",
      "currency",
      "payerName",
      "occurredAt",
    ] as const

    for (const key of required) {
      if (typeof record[key] !== "string" || !record[key]) {
        throw new PaymentProviderError(
          "PROVIDER_INVALID_PAYLOAD",
          `A deposit event is missing ${key}.`,
        )
      }
    }

    if (record.event !== undefined && record.event !== "deposit") {
      throw new PaymentProviderError("PROVIDER_INVALID_PAYLOAD", "That event is not a deposit.")
    }

    const amount = moneyToMinorUnits(record.amount as string)
    if (amount === null) {
      throw new PaymentProviderError(
        "PROVIDER_INVALID_PAYLOAD",
        "A deposit amount must be a positive numeric(20,4) value.",
      )
    }
    if (!currencyCodeSchema.safeParse(record.currency).success) {
      throw new PaymentProviderError("PROVIDER_INVALID_PAYLOAD", "A deposit currency is invalid.")
    }

    const status = record.status ?? "received"
    if (!["received", "pending", "failed", "reversed"].includes(String(status))) {
      throw new PaymentProviderError("PROVIDER_INVALID_PAYLOAD", "A deposit status is invalid.")
    }

    const last4 = record.payerAccountLast4
    if (
      last4 !== undefined &&
      last4 !== null &&
      (typeof last4 !== "string" || !/^[0-9]{4}$/.test(last4))
    ) {
      throw new PaymentProviderError(
        "PROVIDER_INVALID_PAYLOAD",
        "A payer account suffix is four digits.",
      )
    }

    return {
      provider: this.provider,
      reference: record.reference as string,
      collectionAccountReference: record.collectionAccountReference as string,
      amount: minorUnitsToMoney(amount),
      currency: record.currency as string,
      payerName: record.payerName as string,
      payerAccountLast4: (last4 as string | null | undefined) ?? null,
      status: status as DepositEvent["status"],
      occurredAt: record.occurredAt as string,
    }
  }

  async initiatePayout(
    input: PayoutRequest,
    context: ProviderOperationContext,
  ): Promise<PayoutResult> {
    if (this.pendingFailure) {
      const code = this.pendingFailure
      this.pendingFailure = null
      throw new PaymentProviderError(code, "The provider is unavailable.")
    }

    const amount = moneyToMinorUnits(input.amount)
    if (amount === null) {
      throw new PaymentProviderError(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout amount must be a positive numeric(20,4) value.",
      )
    }
    if (!currencyCodeSchema.safeParse(input.currency).success) {
      throw new PaymentProviderError("PROVIDER_INVALID_PAYLOAD", "A payout currency is invalid.")
    }
    if (!/^[0-9]{10}$/.test(input.accountNumber)) {
      throw new PaymentProviderError(
        "PROVIDER_INVALID_PAYLOAD",
        "A payout account number is ten digits.",
      )
    }
    if (!/^[0-9]{3,10}$/.test(input.bankCode)) {
      throw new PaymentProviderError("PROVIDER_INVALID_PAYLOAD", "A payout bank code is invalid.")
    }

    const fingerprint = JSON.stringify({
      reference: input.reference,
      amount: minorUnitsToMoney(amount),
      currency: input.currency,
      bankCode: input.bankCode,
      accountLast4: input.accountNumber.slice(-4),
      accountName: input.accountName,
    })

    const existing = this.payouts.get(context.idempotencyKey)
    if (existing) {
      if (existing.fingerprint !== fingerprint) {
        throw new PaymentProviderError(
          "PROVIDER_DUPLICATE",
          "That idempotency key already describes a different payout.",
          { providerReference: existing.result.providerReference },
        )
      }
      return existing.result
    }

    this.sequence += 1
    const providerReference = `FP-${String(this.sequence).padStart(8, "0")}`
    const occurredAt = new Date().toISOString()
    const result: PayoutResult = {
      provider: this.provider,
      reference: input.reference,
      providerReference,
      status: "pending",
      failureCode: null,
      failureMessage: null,
      occurredAt,
    }

    this.payouts.set(context.idempotencyKey, { fingerprint, result })
    this.statuses.set(providerReference, {
      provider: this.provider,
      reference: input.reference,
      providerReference,
      status: "pending",
      amount: minorUnitsToMoney(amount),
      currency: input.currency,
      occurredAt,
    })

    return result
  }

  async getPaymentStatus(query: PaymentStatusQuery): Promise<PaymentStatus> {
    const status = this.statuses.get(query.providerReference)
    if (!status) {
      throw new PaymentProviderError(
        "PROVIDER_NOT_FOUND",
        "The provider does not know that reference.",
      )
    }
    return status
  }

  async resolveAccountName(input: AccountNameEnquiryRequest): Promise<AccountNameEnquiry> {
    if (!/^[0-9]{3,10}$/.test(input.bankCode) || !/^[0-9]{10}$/.test(input.accountNumber)) {
      throw new PaymentProviderError(
        "PROVIDER_INVALID_PAYLOAD",
        "A name enquiry needs a bank code and a ten-digit account number.",
      )
    }
    if (input.accountNumber === "0000000000") {
      throw new PaymentProviderError("PROVIDER_NOT_FOUND", "The account could not be resolved.")
    }

    return {
      accountName: this.options.accountName ?? "TEST ACCOUNT",
      bankCode: input.bankCode,
      accountNumberLast4: input.accountNumber.slice(-4),
    }
  }
}
