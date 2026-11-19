import { beforeEach, describe, expect, it } from "vitest"

import {
  PaymentProviderError,
  type AccountNameEnquiryRequest,
  type CollectionAccountRequest,
  type PaymentProvider,
  type PayoutRequest,
} from "../../server/src/integrations/payments"

/**
 * The contract every `PaymentProvider` adapter must satisfy.
 *
 * It is deliberately provider-neutral: a real adapter supplies its own raw
 * deposit payload, bank code and account number. Running the same suite against
 * a second adapter is the proof that adding one needs no schema change.
 */
export interface PaymentProviderContractHarness {
  readonly provider: PaymentProvider
  readonly collectionAccount: CollectionAccountRequest
  readonly depositPayload: unknown
  readonly invalidDepositPayload: unknown
  readonly payout: PayoutRequest
  readonly unknownBankAccount: AccountNameEnquiryRequest
  readonly expectedProviderErrorOnUnknownStatus: "PROVIDER_NOT_FOUND"
}

export type PaymentProviderHarnessFactory = (() => PaymentProviderContractHarness) | (() => Promise<PaymentProviderContractHarness>)

export function describePaymentProviderContract(
  label: string,
  createHarness: PaymentProviderHarnessFactory,
): void {
  describe(label, () => {
    let harness: PaymentProviderContractHarness

    beforeEach(async () => {
      harness = await createHarness()
    })

    it("declares a stable lowercase provider key", () => {
      expect(harness.provider.provider).toMatch(/^[a-z][a-z0-9_-]{1,39}$/)
    })

    it("provisions one collection account per reference", async () => {
      const first = await harness.provider.provisionCollectionAccount(
        harness.collectionAccount,
        { idempotencyKey: "provision-1" },
      )
      const second = await harness.provider.provisionCollectionAccount(
        harness.collectionAccount,
        { idempotencyKey: "provision-1" },
      )

      expect(first.provider).toBe(harness.provider.provider)
      expect(first.reference).toBe(harness.collectionAccount.reference)
      expect(first.accountNumber).toMatch(/^[0-9]{10}$/)
      expect(second.accountNumber).toBe(first.accountNumber)
      expect(first.currency).toBe(harness.collectionAccount.currency)

      const other = await harness.provider.provisionCollectionAccount(
        { ...harness.collectionAccount, reference: "another-reference" },
        { idempotencyKey: "provision-2" },
      )
      expect(other.accountNumber).not.toBe(first.accountNumber)
    })

    it("normalises a deposit event and rejects an unknown payload", () => {
      const event = harness.provider.normaliseDepositEvent(
        harness.depositPayload,
      )

      expect(event.provider).toBe(harness.provider.provider)
      expect(event.amount).toMatch(/^\d+\.\d{4}$/)
      expect(event.currency).toMatch(/^[A-Z]{3}$/)
      expect(event.payerName.length).toBeGreaterThan(0)
      expect(event.occurredAt.length).toBeGreaterThan(0)

      expect(() =>
        harness.provider.normaliseDepositEvent(harness.invalidDepositPayload),
      ).toThrow(PaymentProviderError)

      try {
        harness.provider.normaliseDepositEvent(harness.invalidDepositPayload)
      } catch (error) {
        expect(error).toBeInstanceOf(PaymentProviderError)
        expect((error as PaymentProviderError).code).toBe(
          "PROVIDER_INVALID_PAYLOAD",
        )
      }
    })

    it("applies a payout once per idempotency key", async () => {
      const first = await harness.provider.initiatePayout(harness.payout, {
        idempotencyKey: "payout-1",
      })
      const replay = await harness.provider.initiatePayout(harness.payout, {
        idempotencyKey: "payout-1",
      })

      expect(first.providerReference).toBe(replay.providerReference)
      expect(first.status).toBe(replay.status)
      expect(first.reference).toBe(harness.payout.reference)

      await expect(
        harness.provider.initiatePayout(
          { ...harness.payout, amount: "51.0000" },
          { idempotencyKey: "payout-1" },
        ),
      ).rejects.toMatchObject({ code: "PROVIDER_DUPLICATE" })
    })

    it("reports a payout status and refuses an unknown reference", async () => {
      const payout = await harness.provider.initiatePayout(harness.payout, {
        idempotencyKey: "payout-2",
      })
      const status = await harness.provider.getPaymentStatus({
        providerReference: payout.providerReference,
      })

      expect(status.providerReference).toBe(payout.providerReference)
      expect(status.reference).toBe(harness.payout.reference)
      expect(["pending", "processing", "paid"]).toContain(status.status)

      await expect(
        harness.provider.getPaymentStatus({
          providerReference: "does-not-exist",
        }),
      ).rejects.toMatchObject({
        code: harness.expectedProviderErrorOnUnknownStatus,
        retryable: false,
      })
    })

    it("resolves an account name without returning the full number", async () => {
      const enquiry = await harness.provider.resolveAccountName({
        bankCode: harness.payout.bankCode,
        accountNumber: harness.payout.accountNumber,
      })

      expect(enquiry.accountName.length).toBeGreaterThan(0)
      expect(enquiry.accountNumberLast4).toBe(
        harness.payout.accountNumber.slice(-4),
      )
      expect(enquiry).not.toHaveProperty("accountNumber")

      await expect(
        harness.provider.resolveAccountName(harness.unknownBankAccount),
      ).rejects.toMatchObject({ code: "PROVIDER_NOT_FOUND" })
    })

    it("rejects an invalid payout amount with a typed error", async () => {
      await expect(
        harness.provider.initiatePayout(
          { ...harness.payout, amount: "1.00001" },
          { idempotencyKey: "payout-bad-amount" },
        ),
      ).rejects.toMatchObject({ code: "PROVIDER_INVALID_PAYLOAD" })
    })

    it("marks only transport failures as retryable", async () => {
      const notFound = new PaymentProviderError("PROVIDER_NOT_FOUND", "missing")
      const timeout = new PaymentProviderError("PROVIDER_TIMEOUT", "timeout")

      expect(notFound.retryable).toBe(false)
      expect(timeout.retryable).toBe(true)
    })
  })
}
