/**
 * Public interface of the finance module.
 *
 * Owns the `finance` schema: ledger accounts, journal entries, escrow,
 * payouts, limits, reconciliation and commission. Other modules import from
 * this file only. `EP-02-031` adds the posting domain and write path.
 */
export {
  LedgerValidationError,
  MAXIMUM_IDEMPOTENCY_KEY_LENGTH,
  MAXIMUM_POSTINGS,
  MAXIMUM_REFERENCE_LENGTH,
  MINIMUM_IDEMPOTENCY_KEY_LENGTH,
  MINIMUM_POSTINGS,
  MINIMUM_REFERENCE_LENGTH,
  deriveAccountEffects,
  validateJournalEntry,
} from "./ledger"
export type {
  LedgerAccountEffect,
  LedgerEntryInput,
  LedgerEntryValidationOptions,
  LedgerPostingInput,
  LedgerReversalTarget,
  LedgerValidationCode,
  ValidatedEntry,
  ValidatedPosting,
} from "./ledger"
export { LedgerService } from "./ledger.service"
export type { LedgerPostingContext, PostedJournalEntry } from "./ledger.service"
