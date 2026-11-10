/**
 * Public interface of the shared platform module.
 *
 * Other modules import from this file only. Direct access to `platform.*`
 * tables is enforced against by `scripts/lint-boundaries.mjs`.
 */
export { appendAudit, listAuditEntries } from "./audit"
export type { AuditEntry, AuditEntryView } from "./audit"
