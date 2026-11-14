/**
 * Administration and governance module boundary.
 *
 * Owns the `admin` schema: governance roles, assignments, staff, departments,
 * partner organisations, cases, evidence, approvals, configuration, reporting
 * read models and audit access policy. Other modules import from this file
 * only; the boundary linter enforces it.
 */
export {
  EMPTY_AUTHORITY,
  composeAuthority,
  loadAdminAuthority,
  permissionScopes,
  platformPermissions,
  withPlatformAuthority,
} from "./authorization"
export type {
  GovernanceAssignment,
  GovernanceAuthority,
  GovernanceDenial,
  GovernanceScopeType,
} from "./authorization"
