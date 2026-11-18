/**
 * Public interface of the shared platform module.
 *
 * Other modules import from this file only. Direct access to `platform.*`
 * tables is enforced against by `scripts/lint-boundaries.mjs`.
 */
export { appendAudit, listAuditEntries, requiresReason } from "./audit"
export type { AuditEntry, AuditEntryView, AuditPage, AuditQuery } from "./audit"
export { claimIdempotency, completeIdempotency } from "./idempotency"
export type { IdempotencyClaim, IdempotencyClaimInput } from "./idempotency"
export {
  TAXONOMY_ATTRIBUTE_TYPES,
  TAXONOMY_KINDS,
  TAXONOMY_LEVELS,
  TAXONOMY_LEVELS_BY_KIND,
  createsCycle,
  expectedParentLevel,
  isRootLevel,
  isTaxonomyKind,
  isTaxonomyLevel,
  validateTaxonomyAttribute,
  validateTaxonomyNode,
} from "./taxonomy"
export type {
  TaxonomyAttributeInput,
  TaxonomyAttributeType,
  TaxonomyAttributeValidationCode,
  TaxonomyAttributeValidationError,
  TaxonomyKind,
  TaxonomyLevel,
  TaxonomyNodeInput,
  TaxonomyParent,
  TaxonomyValidationCode,
  TaxonomyValidationError,
} from "./taxonomy"
