/**
 * Pure identity domain rules (EP-01-030).
 *
 * No HTTP, Nest, database driver or provider SDK. A repository or service may
 * call these; these functions never call outward.
 */

export const ACCOUNT_STATUSES = ["active", "suspended", "closed"] as const
export type AccountStatus = typeof ACCOUNT_STATUSES[number]

export const USER_STATUSES = ["active", "suspended", "closed"] as const
export type UserStatus = typeof USER_STATUSES[number]

export const MEMBERSHIP_ROLES = ["owner", "member"] as const
export type MembershipRole = typeof MEMBERSHIP_ROLES[number]

export const GRANT_SCOPES = {
  admin: ["admin.audit.read", "admin.grant.read", "admin.grant.manage"],
  staff: ["staff.support.handle"],
  partner: ["partner.referral.read"],
  platform_engineering: ["platform.engineering"],
} as const

export type GrantType = keyof typeof GRANT_SCOPES

export const GRANT_TYPES = Object.keys(GRANT_SCOPES) as GrantType[]

/**
 * Registration creates an account, a user, a credential and an owner
 * membership. It never creates a grant or an activity activation.
 */
export const REGISTRATION_CREATES_GRANTS = false as const
export const REGISTRATION_CREATES_ACTIVITIES = false as const

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase()
}

export function grantScopeIsValid(
  grantType: string,
  scope: string,
): grantType is GrantType {
  if (!(grantType in GRANT_SCOPES)) return false
  return (GRANT_SCOPES[(grantType as GrantType)] as readonly string[]).includes(
    scope,
  )
}

export interface GrantLifecycle {
  readonly revokedAt?: string | null
  readonly expiresAt?: string | null
}

export function grantIsActive(
  grant: GrantLifecycle,
  now: Date = new Date(),
): boolean {
  if (grant.revokedAt) return false
  if (!grant.expiresAt) return true
  const expiry = Date.parse(grant.expiresAt)
  return Number.isFinite(expiry) && expiry > now.getTime()
}

/** An account has one owner at most; multiple members are allowed. */
export function assertSingleOwner(roles: readonly MembershipRole[]): void {
  const owners = roles.filter((role) => role === "owner").length
  if (owners > 1) {
    throw new Error("an account has at most one owner membership")
  }
}

export function isAccountStatus(value: string): value is AccountStatus {
  return (ACCOUNT_STATUSES as readonly string[]).includes(value)
}

export function isUserStatus(value: string): value is UserStatus {
  return (USER_STATUSES as readonly string[]).includes(value)
}
