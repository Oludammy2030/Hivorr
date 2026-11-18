import { z } from "zod"

import { activityIdSchema } from "./activities.js"

/**
 * Ledger, wallet, escrow and payout vocabulary.
 *
 * The ledger is the source of truth for Hivorr's internal obligations. It is
 * append-only and double-entry; a wallet balance is derived, never stored
 * (`ARCHITECTURE.md` §9.10, database rules §12.9). Money is a decimal string
 * with at most four fractional digits, never a JavaScript float.
 */
export const LEDGER_ACCOUNT_KINDS = [
  "user_wallet",
  "escrow",
  "platform_clearing",
  "fee_revenue",
  "payout_payable",
  "commission_payable",
  "adjustment",
] as const

export type LedgerAccountKind = typeof LEDGER_ACCOUNT_KINDS[number]

export const POSTING_DIRECTIONS = ["debit", "credit"] as const

export type PostingDirection = typeof POSTING_DIRECTIONS[number]

/**
 * Entry kinds the ledger accepts. The list is shared with the `finance`
 * database check constraint so a new kind is introduced in one place, not two.
 */
export const JOURNAL_ENTRY_KINDS = [
  "deposit",
  "withdrawal",
  "escrow_hold",
  "escrow_release",
  "escrow_refund",
  "payout",
  "payout_reversal",
  "adjustment",
  "reversal",
] as const

export type JournalEntryKind = typeof JOURNAL_ENTRY_KINDS[number]

/**
 * Escrow states as stored by `finance.escrow_accounts`. Transitions are
 * `EP-02-033`; this list only prevents a second vocabulary.
 */
export const ESCROW_STATES = [
  "held",
  "released",
  "refunded",
  "disputed",
  "cancelled",
] as const

export type EscrowState = typeof ESCROW_STATES[number]

export const PAYOUT_ACCOUNT_STATES = [
  "pending",
  "verified",
  "rejected",
  "disabled",
] as const

export type PayoutAccountState = typeof PAYOUT_ACCOUNT_STATES[number]

export const PAYOUT_STATES = [
  "REQUESTED",
  "APPROVED",
  "RESERVED",
  "PROCESSING",
  "PAID",
  "FAILED",
  "CANCELLED",
] as const

export type PayoutState = typeof PAYOUT_STATES[number]

export const DEPOSIT_MATCH_STATES = [
  "MATCHED",
  "MISMATCH",
  "PENDING_REVIEW",
] as const

export type DepositMatchState = typeof DEPOSIT_MATCH_STATES[number]

export const ledgerAccountKindSchema = z.enum(LEDGER_ACCOUNT_KINDS)
export const postingDirectionSchema = z.enum(POSTING_DIRECTIONS)
export const journalEntryKindSchema = z.enum(JOURNAL_ENTRY_KINDS)
export const escrowStateSchema = z.enum(ESCROW_STATES)
export const payoutAccountStateSchema = z.enum(PAYOUT_ACCOUNT_STATES)
export const payoutStateSchema = z.enum(PAYOUT_STATES)
export const depositMatchStateSchema = z.enum(DEPOSIT_MATCH_STATES)

/**
 * ISO-4217-shaped currency code. The currency model is open; the ledger carries
 * the dimension, but this package does not decide which currencies are enabled.
 */
export const currencyCodeSchema = z.string().regex(/^[A-Z]{3}$/)

export type CurrencyCode = z.infer<typeof currencyCodeSchema>

/**
 * `numeric(20,4)`-shaped amount. A string avoids floating-point drift in the
 * contract; the server converts to the database numeric.
 */
export const moneyAmountSchema = z
  .string()
  .regex(/^(0|[1-9]\d{0,19})(\.\d{1,4})?$/)

export type MoneyAmount = z.infer<typeof moneyAmountSchema>

/**
 * Money is held in integer minor units (1/10,000) so sums never depend on
 * floating point. `numeric(20,4)` has room for 16 integer digits, so the
 * largest representable amount is `9999999999999999.9999`.
 */
export const MONEY_SCALE = 4

export const MONEY_MINOR_FACTOR = 10n ** BigInt(MONEY_SCALE)

export const MONEY_MINOR_LIMIT = 10n ** 20n

/**
 * Parses a contract amount into minor units. Returns `null` for a value the
 * database would reject: more than 16 integer digits, more than four
 * fractional digits, a zero amount, or a non-canonical form.
 */
export function moneyToMinorUnits(amount: string): bigint | null {
  if (!moneyAmountSchema.safeParse(amount).success) return null
  const [whole = "0", fraction = ""] = amount.split(".")
  if (whole.length > 16) return null
  const minor =
    BigInt(whole) * MONEY_MINOR_FACTOR +
    BigInt(fraction.padEnd(MONEY_SCALE, "0"))
  if (minor <= 0n || minor >= MONEY_MINOR_LIMIT) return null
  return minor
}

/** Renders minor units in the canonical `numeric(20,4)` form. */
export function minorUnitsToMoney(minor: bigint): MoneyAmount {
  const sign = minor < 0n ? "-" : ""
  const absolute = minor < 0n ? -minor : minor
  const whole = absolute / MONEY_MINOR_FACTOR
  const fraction = (absolute % MONEY_MINOR_FACTOR)
    .toString()
    .padStart(MONEY_SCALE, "0")
  return `${sign}${whole}.${fraction}`
}

export const ledgerAccountSchema = z.strictObject({
  id: z.string().uuid(),
  kind: ledgerAccountKindSchema,
  currency: currencyCodeSchema,
  ownerType: z.enum(["account", "activity", "platform"]),
  ownerId: z.string().uuid().nullable(),
  createdAt: z.string().datetime(),
})

export type LedgerAccount = z.infer<typeof ledgerAccountSchema>

export const postingSchema = z.strictObject({
  accountId: z.string().uuid(),
  direction: postingDirectionSchema,
  amount: moneyAmountSchema,
  currency: currencyCodeSchema,
})

export type Posting = z.infer<typeof postingSchema>

export const journalEntrySchema = z
  .strictObject({
    id: z.string().uuid(),
    kind: journalEntryKindSchema,
    reference: z.string().min(3).max(64),
    currency: currencyCodeSchema,
    idempotencyKey: z.string().min(1).max(200),
    postings: z.array(postingSchema).min(2).max(100),
    createdAt: z.string().datetime(),
  })
  .superRefine((entry, ctx) => {
    let debits = 0n
    let credits = 0n
    entry.postings.forEach((posting, index) => {
      if (posting.currency !== entry.currency) {
        ctx.addIssue({
          code: "custom",
          message: "posting currency must match the entry currency",
          path: ["postings", index, "currency"],
        })
        return
      }
      const minor = moneyToMinorUnits(posting.amount)
      if (minor === null) {
        ctx.addIssue({
          code: "custom",
          message: "posting amount must be a positive numeric(20,4) value",
          path: ["postings", index, "amount"],
        })
        return
      }
      if (posting.direction === "debit") debits += minor
      else credits += minor
    })
    if (debits !== credits) {
      ctx.addIssue({
        code: "custom",
        message: "a journal entry must balance to zero per currency",
        path: ["postings"],
      })
    }
  })

export type JournalEntry = z.infer<typeof journalEntrySchema>

export const walletBalanceViewSchema = z.strictObject({
  currency: currencyCodeSchema,
  total: moneyAmountSchema,
  available: moneyAmountSchema,
  pending: moneyAmountSchema,
  withdrawable: moneyAmountSchema,
})

export type WalletBalanceView = z.infer<typeof walletBalanceViewSchema>

/**
 * A statement amount carries a sign because a wallet credit and a wallet debit
 * are shown as opposite movements of the same figure.
 */
export const signedMoneyAmountSchema = z
  .string()
  .regex(/^-?(0|[1-9]\d{0,19})(\.\d{1,4})?$/)

export type SignedMoneyAmount = z.infer<typeof signedMoneyAmountSchema>

/**
 * One ledger posting as it appears on the owner's wallet statement. The amount
 * is always positive; `signedAmount` is the display figure, positive for a
 * wallet credit and negative for a wallet debit.
 */
export const walletStatementEntrySchema = z.strictObject({
  postingId: z.string().uuid(),
  entryId: z.string().uuid(),
  reference: z.string(),
  entryKind: journalEntryKindSchema,
  currency: currencyCodeSchema,
  direction: postingDirectionSchema,
  amount: moneyAmountSchema,
  signedAmount: signedMoneyAmountSchema,
  activityId: activityIdSchema.nullable(),
  occurredAt: z.string().datetime(),
})

export type WalletStatementEntry = z.infer<typeof walletStatementEntrySchema>

export const payoutAccountSchema = z.strictObject({
  id: z.string().uuid(),
  bankCode: z.string().min(1).max(20),
  accountNumberMasked: z.string().min(4).max(20),
  accountName: z.string().min(1).max(160),
  state: payoutAccountStateSchema,
  boundAt: z.string().datetime().nullable(),
})

export type PayoutAccount = z.infer<typeof payoutAccountSchema>

export const payoutRequestSchema = z.strictObject({
  payoutAccountId: z.string().uuid(),
  amount: moneyAmountSchema,
  currency: currencyCodeSchema,
  idempotencyKey: z.string().min(1).max(120),
})

export type PayoutRequest = z.infer<typeof payoutRequestSchema>

export const providerReferenceSchema = z.strictObject({
  provider: z.string().min(1).max(40),
  reference: z.string().min(1).max(120),
  status: z.string().min(1).max(40),
  createdAt: z.string().datetime(),
})

export type ProviderReference = z.infer<typeof providerReferenceSchema>

export const depositRecordSchema = z.strictObject({
  providerReference: providerReferenceSchema,
  amount: moneyAmountSchema,
  currency: currencyCodeSchema,
  payerName: z.string().min(1).max(160),
  matchState: depositMatchStateSchema,
  receivedAt: z.string().datetime(),
})

export type DepositRecord = z.infer<typeof depositRecordSchema>

export const escrowReservationSchema = z.strictObject({
  id: z.string().uuid(),
  accountId: z.string().uuid(),
  reference: z.string().min(1).max(120),
  amount: moneyAmountSchema,
  currency: currencyCodeSchema,
  state: escrowStateSchema,
  createdAt: z.string().datetime(),
})

export type EscrowReservation = z.infer<typeof escrowReservationSchema>

export function isLedgerAccountKind(value: string): value is LedgerAccountKind {
  return (LEDGER_ACCOUNT_KINDS as readonly string[]).includes(value)
}

export function isPostingDirection(value: string): value is PostingDirection {
  return (POSTING_DIRECTIONS as readonly string[]).includes(value)
}

export function isJournalEntryKind(value: string): value is JournalEntryKind {
  return (JOURNAL_ENTRY_KINDS as readonly string[]).includes(value)
}

export function isEscrowState(value: string): value is EscrowState {
  return (ESCROW_STATES as readonly string[]).includes(value)
}

export function isPayoutState(value: string): value is PayoutState {
  return (PAYOUT_STATES as readonly string[]).includes(value)
}
