import {
  API_ERROR_CODES,
  ESCROW_STATES,
  KYC_TIERS,
  LEDGER_ACCOUNT_KINDS,
  VERIFICATION_LANES,
  VERIFICATION_STATES,
  currencyCodeSchema,
  evidenceReferenceSchema,
  isKycTier,
  isVerificationLane,
  journalEntrySchema,
  kycTierSchema,
  minorUnitsToMoney,
  moneyAmountSchema,
  moneyToMinorUnits,
  payoutAccountSchema,
  verificationLaneSchema,
  verificationSubmissionSchema,
  walletBalanceViewSchema,
  walletStatementEntrySchema,
} from "@hivorr/shared"
import { describe, expect, it } from "vitest"

describe("EP-02 shared verification contracts", () => {
  it("owns the six independent lanes and the approved states", () => {
    expect(VERIFICATION_LANES).toEqual([
      "identity",
      "kyc",
      "trade",
      "seller",
      "logistics",
      "business",
    ])
    expect(VERIFICATION_STATES).toContain("UNDER_REVIEW")
    expect(KYC_TIERS).toEqual(["tier_0", "tier_1"])
    expect(isVerificationLane("trade")).toBe(true)
    expect(isVerificationLane("discover")).toBe(false)
    expect(isKycTier("tier_1")).toBe(true)
    expect(isKycTier("tier_9")).toBe(false)
  })

  it("rejects an unknown lane, unknown state and unknown field", () => {
    expect(
      verificationSubmissionSchema.safeParse({
        lane: "discover",
        state: "SUBMITTED",
        evidence: [],
      }).success,
    ).toBe(false)
    expect(
      verificationSubmissionSchema.safeParse({
        lane: "identity",
        state: "PENDING",
        evidence: [],
      }).success,
    ).toBe(false)
    expect(
      verificationSubmissionSchema.safeParse({
        lane: "identity",
        state: "SUBMITTED",
        evidence: [],
        clientApproved: true,
      }).success,
    ).toBe(false)
  })

  it("rejects an evidence reference without a valid digest or scan state", () => {
    const base = {
      id: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b",
      objectKey: "private-documents/kyc/abc.pdf",
      contentType: "application/pdf",
      sizeBytes: 1024,
      sha256:
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      scanState: "CLEAN" as const,
      uploadedAt: "2026-11-15T00:00:00.000Z",
    }
    expect(evidenceReferenceSchema.safeParse(base).success).toBe(true)
    expect(
      evidenceReferenceSchema.safeParse({ ...base, sha256: "abc" }).success,
    ).toBe(false)
    expect(
      evidenceReferenceSchema.safeParse({ ...base, scanState: "UNKNOWN" })
        .success,
    ).toBe(false)
  })
})

describe("EP-02 shared finance contracts", () => {
  it("owns the ledger account kinds and escrow states", () => {
    expect(LEDGER_ACCOUNT_KINDS).toContain("user_wallet")
    expect(LEDGER_ACCOUNT_KINDS).toContain("escrow")
    expect(ESCROW_STATES).toContain("held")
    expect(ESCROW_STATES).toContain("released")
    expect(ESCROW_STATES).toContain("cancelled")
  })

  it("accepts a decimal money string and rejects floats, negatives and excess precision", () => {
    expect(moneyAmountSchema.safeParse("0").success).toBe(true)
    expect(moneyAmountSchema.safeParse("20000.0000").success).toBe(true)
    expect(moneyAmountSchema.safeParse(20000).success).toBe(false)
    expect(moneyAmountSchema.safeParse("-1").success).toBe(false)
    expect(moneyAmountSchema.safeParse("1.00001").success).toBe(false)
  })

  it("accepts an ISO-shaped currency and rejects an unknown one", () => {
    expect(currencyCodeSchema.safeParse("NGN").success).toBe(true)
    expect(currencyCodeSchema.safeParse("ngn").success).toBe(false)
    expect(currencyCodeSchema.safeParse("N").success).toBe(false)
  })

  it("rejects a wallet view with a float or a missing derived figure", () => {
    const view = {
      currency: "NGN",
      total: "80000.0000",
      available: "20000.0000",
      pending: "60000.0000",
      withdrawable: "20000.0000",
    }
    expect(walletBalanceViewSchema.safeParse(view).success).toBe(true)
    expect(
      walletBalanceViewSchema.safeParse({ ...view, available: 20000 }).success,
    ).toBe(false)
    const { withdrawable: _withdrawable, ...missing } = view
    expect(walletBalanceViewSchema.safeParse(missing).success).toBe(false)
  })

  it("rejects a payout account that leaks a full account number field", () => {
    const account = {
      id: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b",
      bankCode: "999999",
      accountNumberMasked: "******1234",
      accountName: "Test User",
      state: "verified",
      boundAt: "2026-11-15T00:00:00.000Z",
    }
    expect(payoutAccountSchema.safeParse(account).success).toBe(true)
    expect(
      payoutAccountSchema.safeParse({
        ...account,
        accountNumber: "0123456789",
      }).success,
    ).toBe(false)
  })

  it("requires a journal entry to carry at least two postings", () => {
    const entry = {
      id: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b",
      kind: "deposit",
      reference: "dep-1",
      currency: "NGN",
      idempotencyKey: "idem-1",
      postings: [
        {
          accountId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7c",
          direction: "debit",
          amount: "100.0000",
          currency: "NGN",
        },
      ],
      createdAt: "2026-11-15T00:00:00.000Z",
    }
    expect(journalEntrySchema.safeParse(entry).success).toBe(false)
    expect(
      journalEntrySchema.safeParse({
        ...entry,
        postings: [
          ...entry.postings,
          {
            accountId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7d",
            direction: "credit",
            amount: "100.0000",
            currency: "NGN",
          },
        ],
      }).success,
    ).toBe(true)
  })

  it("rejects a journal entry that does not balance to zero", () => {
    const entry = {
      id: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b",
      kind: "deposit",
      reference: "dep-2",
      currency: "NGN",
      idempotencyKey: "idem-2",
      postings: [
        {
          accountId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7c",
          direction: "debit",
          amount: "100.0000",
          currency: "NGN",
        },
        {
          accountId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7d",
          direction: "credit",
          amount: "99.9999",
          currency: "NGN",
        },
      ],
      createdAt: "2026-11-15T00:00:00.000Z",
    }
    expect(journalEntrySchema.safeParse(entry).success).toBe(false)
    expect(
      journalEntrySchema.safeParse({
        ...entry,
        postings: [
          entry.postings[0],
          { ...entry.postings[1], currency: "USD" },
        ],
      }).success,
    ).toBe(false)
  })

  it("round-trips money through integer minor units", () => {
    expect(moneyToMinorUnits("100.0000")).toBe(1_000_000n)
    expect(minorUnitsToMoney(1_000_000n)).toBe("100.0000")
    expect(minorUnitsToMoney(-1n)).toBe("-0.0001")
    expect(moneyToMinorUnits("0")).toBeNull()
    expect(moneyToMinorUnits("1.00001")).toBeNull()
    expect(moneyToMinorUnits("10000000000000000.0000")).toBeNull()
  })

  it("describes a statement row with a signed display amount", () => {
    const entry = {
      postingId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b",
      entryId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7c",
      reference: "DEP-1",
      entryKind: "deposit",
      currency: "NGN",
      direction: "debit",
      amount: "100.0000",
      signedAmount: "100.0000",
      activityId: "market.buy",
      occurredAt: "2026-11-18T00:00:00.000Z",
    }
    expect(walletStatementEntrySchema.safeParse(entry).success).toBe(true)
    expect(
      walletStatementEntrySchema.safeParse({
        ...entry,
        signedAmount: "-30.0000",
        activityId: null,
        direction: "credit",
      }).success,
    ).toBe(true)
    expect(
      walletStatementEntrySchema.safeParse({
        ...entry,
        signedAmount: "100.00001",
      }).success,
    ).toBe(false)
    expect(
      walletStatementEntrySchema.safeParse({
        ...entry,
        activityId: "market.discover",
      }).success,
    ).toBe(false)
  })

  it("keeps the new API error codes stable", () => {
    expect(API_ERROR_CODES).toEqual(
      expect.arrayContaining([
        "VERIFICATION_REQUIRED",
        "KYC_REQUIRED",
        "PAYOUT_ACCOUNT_REQUIRED",
        "INSUFFICIENT_FUNDS",
        "LIMIT_EXCEEDED",
        "DUPLICATE_REQUEST",
        "PROVIDER_ERROR",
      ]),
    )
  })

  it("does not invent a KYC tier above tier_1", () => {
    expect(kycTierSchema.safeParse("tier_2").success).toBe(false)
    expect(verificationLaneSchema.safeParse("trade").success).toBe(true)
  })
})
