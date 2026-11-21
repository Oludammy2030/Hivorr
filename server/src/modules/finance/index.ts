/**
 * Public interface of the finance module.
 *
 * Owns the `finance` schema: ledger accounts, journal entries, escrow,
 * payouts, limits, reconciliation and commission. Other modules import from
 * this file only. `EP-02-031` adds the posting domain and write path;
 * `EP-02-032` adds the derived wallet and statement reads.
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
export {
  DEFAULT_STATEMENT_LIMIT,
  MAXIMUM_STATEMENT_LIMIT,
  WalletService,
} from "./wallet.service"
export type { WalletReadContext, WalletStatementQuery } from "./wallet.service"
export { ESCROW_ACTIVITIES, EscrowService } from "./escrow.service"
export type {
  EscrowTransitionInput,
  EscrowView,
  EscrowWriteContext,
  OpenEscrowInput,
} from "./escrow.service"
export {
  LEDGER_IDEMPOTENCY_SCOPE,
  hashLedgerEntry,
  ledgerIdempotencyKey,
} from "./idempotency"
export { ProviderReferenceService } from "./provider-reference.service"
export type {
  LinkProviderReferenceInput,
  ProviderReferenceContext,
  ProviderReferenceView,
  RecordProviderReferenceInput,
  RecordProviderReferenceResult,
} from "./provider-reference.service"
export {
  FINANCE_LIMIT_PERIODS,
  FINANCE_LIMIT_TYPES,
  FINANCIALLY_ELIGIBLE_TIERS,
  evaluateFinanceLimit,
  financeLimitPeriodStart,
  selectFinanceLimit,
} from "./limits"
export type {
  FinanceLimitDecision,
  FinanceLimitDenialReason,
  FinanceLimitEvaluation,
  FinanceLimitPeriod,
  FinanceLimitRule,
  FinanceLimitSelection,
  FinanceLimitType,
} from "./limits"
export { FinanceLimitService } from "./limit.service"
export type {
  FinanceLimitCheckInput,
  FinanceLimitView,
  SetFinanceLimitInput,
} from "./limit.service"
