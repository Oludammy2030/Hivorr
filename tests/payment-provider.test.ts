import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

import {
  FakePaymentProvider,
  type PayoutRequest,
} from "../server/src/integrations/payments"
import {
  describePaymentProviderContract,
  type PaymentProviderContractHarness,
} from "./support/payment-provider-contract"

const accountNumber = "0123456789"
const bankCode = "058"

function harness(providerName = "fake"): PaymentProviderContractHarness {
  return {
    provider: new FakePaymentProvider({ providerName }),
    collectionAccount: {
      reference: "account-reference-1",
      accountName: "Test User",
      currency: "NGN",
    },
    depositPayload: {
      event: "deposit",
      reference: "deposit-1",
      collectionAccountReference: "account-reference-1",
      amount: "100.1",
      currency: "NGN",
      payerName: "TEST USER",
      payerAccountLast4: "1234",
      status: "received",
      occurredAt: "2026-11-19T00:00:00.000Z",
    },
    invalidDepositPayload: { event: "deposit" },
    payout: {
      reference: "payout-1",
      amount: "50.0000",
      currency: "NGN",
      bankCode,
      accountNumber,
      accountName: "TEST USER",
    },
    unknownBankAccount: {
      bankCode,
      accountNumber: "0000000000",
    },
    expectedProviderErrorOnUnknownStatus: "PROVIDER_NOT_FOUND",
  }
}

describePaymentProviderContract("fake payment provider", () => harness())

describePaymentProviderContract("second provider adapter", () =>
  harness("fake_two"),
)

describe("payment provider port", () => {
  const payout: PayoutRequest = {
    reference: "payout-1",
    amount: "50.0000",
    currency: "NGN",
    bankCode,
    accountNumber,
    accountName: "TEST USER",
  }

  it("fails once with a retryable code and succeeds on retry", async () => {
    const provider = new FakePaymentProvider()
    provider.failNextPayout("PROVIDER_TIMEOUT")

    await expect(
      provider.initiatePayout(payout, { idempotencyKey: "payout-retry" }),
    ).rejects.toMatchObject({
      code: "PROVIDER_TIMEOUT",
      retryable: true,
    })

    const result = await provider.initiatePayout(payout, {
      idempotencyKey: "payout-retry",
    })
    expect(result.providerReference).toMatch(/^FP-/)
  })

  it("keeps VFD out of the domain and ledger", () => {
    const files = [
      "server/src/modules/finance/ledger.ts",
      "server/src/modules/finance/ledger.service.ts",
      "server/src/modules/finance/wallet.service.ts",
      "server/src/modules/finance/escrow.service.ts",
      "server/src/modules/finance/idempotency.ts",
      "server/src/modules/finance/provider-reference.service.ts",
      "server/src/modules/admin/dispute.service.ts",
    ]

    for (const file of files) {
      const contents = readFileSync(path.join(process.cwd(), file), "utf8")
      expect(contents.toLowerCase(), file).not.toContain("vfd")
    }
  })

  it("does not persist a full payout account number", async () => {
    const provider = new FakePaymentProvider()
    await provider.initiatePayout(payout, { idempotencyKey: "payout-1" })

    const status = await provider.getPaymentStatus({
      providerReference: "FP-00000001",
    })
    expect(JSON.stringify(status)).not.toContain(accountNumber)

    const name = await provider.resolveAccountName({
      bankCode,
      accountNumber,
    })
    expect(JSON.stringify(name)).not.toContain(accountNumber)
  })
})
