import {
  ACTIVITY_IDS,
  JOURNAL_ENTRY_KINDS,
  POSTING_DIRECTIONS,
  minorUnitsToMoney,
  moneyToMinorUnits,
  type JournalEntryKind,
  type PostingDirection,
} from "@hivorr/shared"

/**
 * Pure ledger posting domain (EP-02-031).
 *
 * The engine validates a journal entry before any row is written. It owns no
 * database, HTTP or client import: an invalid entry cannot reach the write
 * path, and the same rules run in tests with generated inputs.
 *
 * Money is compared in integer minor units (1/10,000), never as a float. The
 * database enforces the same invariants at commit; this module is the first
 * line, not a substitute for the constraint.
 */
export const MINIMUM_POSTINGS = 2
export const MAXIMUM_POSTINGS = 100
export const MAXIMUM_REFERENCE_LENGTH = 64
export const MINIMUM_REFERENCE_LENGTH = 3
export const MINIMUM_IDEMPOTENCY_KEY_LENGTH = 8
export const MAXIMUM_IDEMPOTENCY_KEY_LENGTH = 200

export const LEDGER_ACTIVITY_IDS = ACTIVITY_IDS

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const CURRENCY_PATTERN = /^[A-Z]{3}$/

export type LedgerValidationCode =
  | "LEDGER_ENTRY_KIND_INVALID"
  | "LEDGER_REFERENCE_INVALID"
  | "LEDGER_CURRENCY_INVALID"
  | "LEDGER_IDEMPOTENCY_KEY_INVALID"
  | "LEDGER_ACTIVITY_INVALID"
  | "LEDGER_POSTING_COUNT_INVALID"
  | "LEDGER_ACCOUNT_INVALID"
  | "LEDGER_DIRECTION_INVALID"
  | "LEDGER_AMOUNT_INVALID"
  | "LEDGER_POSTING_CURRENCY_MISMATCH"
  | "LEDGER_ENTRY_UNBALANCED"
  | "LEDGER_REVERSAL_TARGET_MISSING"
  | "LEDGER_REVERSAL_TARGET_INVALID"
  | "LEDGER_REVERSAL_MISMATCH"

export class LedgerValidationError extends Error {
  readonly code: LedgerValidationCode

  constructor(code: LedgerValidationCode, message: string) {
    super(message)
    this.name = "LedgerValidationError"
    this.code = code
  }
}

export interface LedgerPostingInput {
  readonly accountId: string
  readonly direction: string
  readonly amount: string
  readonly currency: string
  readonly activityId?: string | null
}

export interface LedgerEntryInput {
  readonly kind: string
  readonly reference: string
  readonly currency: string
  readonly idempotencyKey?: string | null
  readonly activityId?: string | null
  readonly reversesEntryId?: string | null
  readonly postings: readonly LedgerPostingInput[]
}

export interface ValidatedPosting {
  readonly accountId: string
  readonly direction: PostingDirection
  readonly amount: string
  readonly amountMinor: bigint
  readonly currency: string
  readonly activityId: string | null
}

export interface ValidatedEntry {
  readonly kind: JournalEntryKind
  readonly reference: string
  readonly currency: string
  readonly idempotencyKey: string | null
  readonly activityId: string | null
  readonly reversesEntryId: string | null
  readonly postings: readonly ValidatedPosting[]
}

/**
 * An existing entry loaded for a reversal. The service reads it from the
 * ledger; the engine refuses anything that is not an exact inversion.
 */
export interface LedgerReversalTarget {
  readonly currency: string
  readonly postings: readonly LedgerPostingInput[]
}

export interface LedgerEntryValidationOptions {
  readonly reversalTarget?: LedgerReversalTarget
}

export interface LedgerAccountEffect {
  readonly accountId: string
  readonly currency: string
  readonly debit: string
  readonly credit: string
  /** debit − credit; negative when the account is credited. */
  readonly net: string
}

function invalid(code: LedgerValidationCode, message: string): never {
  throw new LedgerValidationError(code, message)
}

function isActivityId(value: string): boolean {
  return (ACTIVITY_IDS as readonly string[]).includes(value)
}

function normaliseActivity(value: string | null | undefined): string | null {
  if (value === undefined || value === null) return null
  const trimmed = value.trim()
  if (trimmed.length === 0) return null
  if (!isActivityId(trimmed)) {
    invalid("LEDGER_ACTIVITY_INVALID", `Unknown activity: ${trimmed}`)
  }
  return trimmed
}

function validatePosting(
  posting: LedgerPostingInput,
  entryCurrency: string,
  index: number,
): ValidatedPosting {
  if (!UUID_PATTERN.test(posting.accountId)) {
    invalid("LEDGER_ACCOUNT_INVALID", `Posting ${index} does not name a ledger account.`)
  }

  if (!(POSTING_DIRECTIONS as readonly string[]).includes(posting.direction)) {
    invalid("LEDGER_DIRECTION_INVALID", `Posting ${index} has an unknown direction.`)
  }

  if (!CURRENCY_PATTERN.test(posting.currency)) {
    invalid("LEDGER_CURRENCY_INVALID", `Posting ${index} does not carry a currency code.`)
  }

  if (posting.currency !== entryCurrency) {
    invalid(
      "LEDGER_POSTING_CURRENCY_MISMATCH",
      `Posting ${index} currency differs from the entry currency.`,
    )
  }

  const amountMinor = moneyToMinorUnits(posting.amount)
  if (amountMinor === null) {
    invalid(
      "LEDGER_AMOUNT_INVALID",
      `Posting ${index} amount must be a positive numeric(20,4) value.`,
    )
  }

  return {
    accountId: posting.accountId,
    direction: posting.direction as PostingDirection,
    amount: minorUnitsToMoney(amountMinor),
    amountMinor,
    currency: entryCurrency,
    activityId: normaliseActivity(posting.activityId),
  }
}

function postingKey(posting: ValidatedPosting): string {
  return [posting.accountId, posting.currency, posting.amount, posting.direction].join("|")
}

function assertReversalMatches(
  entry: readonly ValidatedPosting[],
  target: LedgerReversalTarget,
): void {
  if (target.currency !== entry[0]?.currency) {
    invalid("LEDGER_REVERSAL_MISMATCH", "A reversal must use the original entry currency.")
  }

  if (target.postings.length !== entry.length) {
    invalid(
      "LEDGER_REVERSAL_MISMATCH",
      "A reversal must invert every posting of the original entry.",
    )
  }

  const expected = new Map<string, number>()
  for (const posting of entry) {
    const opposite: PostingDirection = posting.direction === "debit" ? "credit" : "debit"
    const key = postingKey({ ...posting, direction: opposite })
    expected.set(key, (expected.get(key) ?? 0) + 1)
  }

  for (const targetPosting of target.postings) {
    const minor = moneyToMinorUnits(targetPosting.amount)
    if (minor === null) {
      invalid("LEDGER_REVERSAL_TARGET_INVALID", "The original entry contains an invalid amount.")
    }
    const direction = targetPosting.direction as PostingDirection
    const key = [
      targetPosting.accountId,
      targetPosting.currency,
      minorUnitsToMoney(minor),
      direction,
    ].join("|")
    const remaining = expected.get(key) ?? 0
    if (remaining === 0) {
      invalid("LEDGER_REVERSAL_MISMATCH", "Every reversal posting must mirror the original entry.")
    }
    expected.set(key, remaining - 1)
  }
}

/**
 * Validates an entry and returns the canonical form the writer persists.
 *
 * @throws LedgerValidationError with a stable code; the message is for logs
 * and never returned to a client unchanged.
 */
export function validateJournalEntry(
  input: LedgerEntryInput,
  options: LedgerEntryValidationOptions = {},
): ValidatedEntry {
  if (!(JOURNAL_ENTRY_KINDS as readonly string[]).includes(input.kind)) {
    invalid("LEDGER_ENTRY_KIND_INVALID", "Unknown journal entry kind.")
  }

  const reference = input.reference.trim()
  if (reference.length < MINIMUM_REFERENCE_LENGTH || reference.length > MAXIMUM_REFERENCE_LENGTH) {
    invalid(
      "LEDGER_REFERENCE_INVALID",
      `A ledger reference is ${MINIMUM_REFERENCE_LENGTH}–${MAXIMUM_REFERENCE_LENGTH} characters.`,
    )
  }

  if (!CURRENCY_PATTERN.test(input.currency)) {
    invalid("LEDGER_CURRENCY_INVALID", "An entry must carry a currency code.")
  }

  let idempotencyKey: string | null = null
  if (input.idempotencyKey !== undefined && input.idempotencyKey !== null) {
    idempotencyKey = input.idempotencyKey.trim()
    if (
      idempotencyKey.length < MINIMUM_IDEMPOTENCY_KEY_LENGTH ||
      idempotencyKey.length > MAXIMUM_IDEMPOTENCY_KEY_LENGTH
    ) {
      invalid(
        "LEDGER_IDEMPOTENCY_KEY_INVALID",
        `An idempotency key is ${MINIMUM_IDEMPOTENCY_KEY_LENGTH}–${MAXIMUM_IDEMPOTENCY_KEY_LENGTH} characters.`,
      )
    }
  }

  const activityId = normaliseActivity(input.activityId)
  const reversesEntryId = input.reversesEntryId?.trim() || null

  if (reversesEntryId !== null && !UUID_PATTERN.test(reversesEntryId)) {
    invalid("LEDGER_REVERSAL_TARGET_INVALID", "A reversal must name a journal entry.")
  }

  if ((input.kind === "reversal") !== (reversesEntryId !== null)) {
    invalid(
      "LEDGER_REVERSAL_TARGET_INVALID",
      "kind = reversal and reversesEntryId must move together.",
    )
  }

  if (input.postings.length < MINIMUM_POSTINGS || input.postings.length > MAXIMUM_POSTINGS) {
    invalid(
      "LEDGER_POSTING_COUNT_INVALID",
      `An entry carries ${MINIMUM_POSTINGS}–${MAXIMUM_POSTINGS} postings.`,
    )
  }

  const postings = input.postings.map((posting, index) =>
    validatePosting(posting, input.currency, index),
  )

  let debits = 0n
  let credits = 0n
  for (const posting of postings) {
    if (posting.direction === "debit") debits += posting.amountMinor
    else credits += posting.amountMinor
  }

  if (debits === 0n || credits === 0n) {
    invalid("LEDGER_ENTRY_UNBALANCED", "An entry needs at least one debit and one credit.")
  }

  if (debits !== credits) {
    invalid("LEDGER_ENTRY_UNBALANCED", "An entry must balance to zero per currency.")
  }

  if (input.kind === "reversal") {
    const target = options.reversalTarget
    if (!target) {
      invalid(
        "LEDGER_REVERSAL_TARGET_MISSING",
        "The original entry is required to validate a reversal.",
      )
    }
    assertReversalMatches(postings, target)
  } else if (options.reversalTarget) {
    invalid(
      "LEDGER_REVERSAL_TARGET_INVALID",
      "A non-reversal entry cannot carry a reversal target.",
    )
  }

  return {
    kind: input.kind as JournalEntryKind,
    reference,
    currency: input.currency,
    idempotencyKey,
    activityId,
    reversesEntryId,
    postings,
  }
}

/**
 * Aggregates validated postings per account. The result is what the caller
 * reports as the effect of the entry inside the same transaction; it is not a
 * stored balance.
 */
interface AccountTotals {
  debit: bigint
  credit: bigint
}

export function deriveAccountEffects(
  postings: readonly ValidatedPosting[],
): readonly LedgerAccountEffect[] {
  const totals = new Map<string, AccountTotals>()
  for (const posting of postings) {
    const current = totals.get(posting.accountId) ?? { debit: 0n, credit: 0n }
    if (posting.direction === "debit") current.debit += posting.amountMinor
    else current.credit += posting.amountMinor
    totals.set(posting.accountId, current)
  }

  return [...totals.entries()]
    .map(([accountId, total]) => ({
      accountId,
      currency: postings[0]?.currency ?? "",
      debit: minorUnitsToMoney(total.debit),
      credit: minorUnitsToMoney(total.credit),
      net: minorUnitsToMoney(total.debit - total.credit),
    }))
    .sort((left, right) => left.accountId.localeCompare(right.accountId))
}
