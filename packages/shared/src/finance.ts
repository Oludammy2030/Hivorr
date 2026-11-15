import { z } from "zod"

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

export const ESCROW_STATES = [
  "PENDING",
  "HELD",
  "RELEASED",
  "REFUNDED",
  "DISPUTED",
] as const

export type EscrowState = typeof ESCROW_STATES[number]

export const PAYOUT_ACCOUNT_STATES = [
  "PENDING",
  "VERIFIED",
  "REJECTED",
  "DISABLED",
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

export const ledgerAccountSchema = z.strictObject({
  id: z.string().uuid(),
  kind: ledgerAccountKindSchema,
  currency: currencyCodeSchema,
  ownerType: z.enum(["account", "platform", "provider"]),
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

export const journalEntrySchema = z.strictObject({
  id: z.string().uuid(),
  kind: z.string().min(1).max(64),
  reference: z.string().min(1).max(120),
  currency: currencyCodeSchema,
  idempotencyKey: z.string().min(1).max(120),
  postings: z.array(postingSchema).min(2).max(100),
  createdAt: z.string().datetime(),
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

export function isEscrowState(value: string): value is EscrowState {
  return (ESCROW_STATES as readonly string[]).includes(value)
}

export function isPayoutState(value: string): value is PayoutState {
  return (PAYOUT_STATES as readonly string[]).includes(value)
}
