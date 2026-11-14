import type { PoolClient } from "pg"

import type { AccessContext } from "../../domain/capabilities"

/**
 * Governance authority (CP-002/CP-003).
 *
 * Roles are collections of permissions. Assignments carry a resource scope and
 * an optional expiry. Individual permission grants are supported but expected
 * to be rare.
 *
 * Explicit denials are scope-aware:
 *   - a platform/global denial removes the permission everywhere;
 *   - a case/department/organisation denial removes it only for that scope.
 *
 * This module owns no SQL table outside the `admin` schema. It is read-only for
 * the actor; administrative mutation paths arrive with CP-012.
 */
export type GovernanceScopeType = "platform" | "department" | "organisation" | "activity" | "case" | "team" | "queue"

export interface GovernanceAssignment {
  readonly source: "role" | "grant"
  readonly roleKey: string | null
  readonly permissionKey: string
  readonly scopeType: GovernanceScopeType
  readonly scopeId: string | null
  readonly expiresAt: string | null
}

export interface GovernanceDenial {
  readonly permissionKey: string
  readonly scopeType: GovernanceScopeType | null
  readonly scopeId: string | null
  readonly expiresAt: string | null
}

export interface GovernanceAuthority {
  readonly roles: readonly string[]
  readonly permissions: readonly string[]
  /** Permissions denied globally, or denied in every scope the actor holds. */
  readonly deniedPermissions: readonly string[]
  readonly assignments: readonly GovernanceAssignment[]
  readonly denials: readonly GovernanceDenial[]
}

interface AuthorityRow {
  source: "role" | "grant"
  role_key: string | null
  permission_key: string
  scope_type: GovernanceScopeType
  scope_id: string | null
  expires_at: string | null
}

interface DenialRow {
  permission_key: string
  scope_type: GovernanceScopeType | null
  scope_id: string | null
  expires_at: string | null
}

export const EMPTY_AUTHORITY: GovernanceAuthority = {
  roles: [],
  permissions: [],
  deniedPermissions: [],
  assignments: [],
  denials: [],
}

function isGlobalDenial(denial: GovernanceDenial): boolean {
  return denial.scopeType === null || denial.scopeType === "platform"
}

function denialMatchesAssignment(
  denial: GovernanceDenial,
  assignment: GovernanceAssignment,
): boolean {
  if (denial.permissionKey !== assignment.permissionKey) return false
  if (isGlobalDenial(denial)) return true
  return (
    denial.scopeType === assignment.scopeType &&
    denial.scopeId === assignment.scopeId
  )
}

/**
 * Pure composition. Exported so the allow/deny behaviour is table-tested
 * without a database.
 */
export function composeAuthority(
  rows: readonly AuthorityRow[],
  denialRows: readonly DenialRow[],
): GovernanceAuthority {
  const roles = new Set<string>()
  const assignments: GovernanceAssignment[] = []
  const denials: GovernanceDenial[] = denialRows.map((denial) => ({
    permissionKey: denial.permission_key,
    scopeType: denial.scope_type,
    scopeId: denial.scope_id,
    expiresAt: denial.expires_at,
  }))

  for (const row of rows) {
    if (row.role_key) roles.add(row.role_key)
    assignments.push({
      source: row.source,
      roleKey: row.role_key,
      permissionKey: row.permission_key,
      scopeType: row.scope_type,
      scopeId: row.scope_id,
      expiresAt: row.expires_at,
    })
  }

  const byPermission = new Map<string, GovernanceAssignment[]>()
  for (const assignment of assignments) {
    const current = byPermission.get(assignment.permissionKey) ?? []
    current.push(assignment)
    byPermission.set(assignment.permissionKey, current)
  }

  const permissions: string[] = []
  const denied: string[] = []

  for (const [permission, scopedAssignments] of byPermission) {
    const allowed = scopedAssignments.filter(
      (assignment) =>
        !denials.some((denial) => denialMatchesAssignment(denial, assignment)),
    )
    if (allowed.length > 0) {
      permissions.push(permission)
    } else if (denials.some((denial) => denial.permissionKey === permission)) {
      denied.push(permission)
    }
  }

  return {
    roles: [...roles].sort(),
    permissions: permissions.sort(),
    deniedPermissions: denied.sort(),
    assignments,
    denials,
  }
}

/**
 * Builds the capability inputs for a governance caller.
 *
 * Only platform-scoped assignments may become capabilities, so this function —
 * not `authority.permissions` — is the correct input for `computeCapabilities`.
 * Folding the raw union in would turn a department-, case- or
 * organisation-scoped role into a platform-wide capability and let a controller
 * gate pass a check the database is about to refuse.
 */
export function withPlatformAuthority(
  context: AccessContext,
  authority: GovernanceAuthority,
): AccessContext {
  return {
    ...context,
    adminPermissions: platformPermissions(authority),
    deniedPermissions: authority.deniedPermissions,
  }
}

/**
 * Loads the actor's own governance authority inside the caller's transaction.
 * RLS restricts the read to the current user; the service still re-checks the
 * capability before the protected operation.
 */
export async function loadAdminAuthority(
  client: PoolClient,
  userId: string,
): Promise<GovernanceAuthority> {
  const rows = await client.query<AuthorityRow>(
    `select 'role'::text as source,
            r.key as role_key,
            rp.permission_key,
            ra.scope_type,
            ra.scope_id,
            ra.expires_at
       from admin.role_assignments ra
       join admin.roles r on r.id = ra.role_id
       join admin.role_permissions rp on rp.role_id = ra.role_id
      where ra.user_id = $1
        and ra.revoked_at is null
        and (ra.expires_at is null or ra.expires_at > now())
     union all
     select 'grant'::text as source,
            null::text as role_key,
            pg.permission_key,
            pg.scope_type,
            pg.scope_id,
            pg.expires_at
       from admin.permission_grants pg
      where pg.user_id = $1
        and pg.revoked_at is null
        and (pg.expires_at is null or pg.expires_at > now())
      order by scope_type, scope_id nulls first`,
    [userId],
  )

  const denials = await client.query<DenialRow>(
    `select permission_key, scope_type, scope_id, expires_at
       from admin.access_denials
      where user_id = $1
        and (expires_at is null or expires_at > now())`,
    [userId],
  )

  return composeAuthority(rows.rows, denials.rows)
}

/**
 * Returns the scopes in which the actor holds a permission. A denial removes
 * the matching scope only; a platform/global denial removes every scope.
 */
export function permissionScopes(
  authority: GovernanceAuthority,
  permission: string,
): readonly GovernanceAssignment[] {
  return authority.assignments.filter((assignment) => {
    if (assignment.permissionKey !== permission) return false
    return !authority.denials.some((denial) =>
      denialMatchesAssignment(denial, assignment),
    )
  })
}

/**
 * Permissions the actor holds across the whole platform, with platform/global
 * denials removed. Department- or organisation-scoped assignments are excluded
 * on purpose: a scoped role must not become a platform-wide capability in the
 * generic session view.
 */
export function platformPermissions(
  authority: GovernanceAuthority,
): readonly string[] {
  const denied = new Set(
    authority.denials
      .filter((denial) => isGlobalDenial(denial))
      .map((denial) => denial.permissionKey),
  )
  const permissions = new Set<string>()
  for (const assignment of authority.assignments) {
    if (assignment.scopeType !== "platform") continue
    if (denied.has(assignment.permissionKey)) continue
    permissions.add(assignment.permissionKey)
  }
  return [...permissions]
}
