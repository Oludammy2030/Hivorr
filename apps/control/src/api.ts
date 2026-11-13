/**
 * Minimal same-origin client for the identity API.
 *
 * The browser never holds a token: the API sets host-only cookies, and the
 * edge proxy forwards them. `credentials: "same-origin"` is explicit so a
 * future refactor cannot silently drop them.
 */

export interface Session {
  readonly sessionId: string
  readonly accountId: string
  readonly userId: string
  readonly email: string
  readonly audience: "app" | "control" | "staff" | "partner"
  readonly environment: "staging" | "production"
  readonly expiresAt: string
  readonly idleExpiresAt: string
}

export interface MfaChallenge {
  readonly mfaRequired: true
  readonly challengeToken: string
  readonly expiresAt: string
}

export interface Grant {
  readonly id: string
  readonly userId: string
  readonly email: string | null
  readonly userName: string | null
  readonly grantType: string
  readonly scope: string
  readonly environment: string
  readonly grantedBy: string | null
  readonly expiresAt: string | null
  readonly revokedAt: string | null
  readonly createdAt: string
  readonly departmentKey: string | null
  readonly departmentName: string | null
}

export interface Department {
  readonly key: string
  readonly name: string
}

export interface Role {
  readonly key: string
  readonly name: string
  readonly description: string | null
  readonly system: boolean
  readonly permissions: readonly string[]
  readonly activeAssignments: number
}

export interface RoleAssignment {
  readonly id: string
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly roleKey: string
  readonly roleName: string
  readonly scopeType: string
  readonly scopeId: string | null
  readonly expiresAt: string | null
  readonly revokedAt: string | null
  readonly createdAt: string
  readonly grantedBy: string | null
  readonly reason: string | null
}

export interface RoleScopeTarget {
  readonly id: string
  readonly name: string
}

export interface AssignableStaff {
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly departmentKey: string | null
  readonly departmentName: string | null
}

export type RoleScopeType = "platform" | "department" | "organisation"

export interface AssignRoleInput {
  readonly email: string
  readonly roleKey: string
  readonly scopeType: RoleScopeType
  readonly scopeId?: string
  readonly expiresAt?: string
  readonly reason: string
}

export interface OwnGrants {
  readonly grants: readonly Grant[]
  readonly capabilities: readonly string[]
}

export interface ControlAuthority extends OwnGrants {
  readonly roles: readonly string[]
  readonly permissions: readonly string[]
  readonly deniedPermissions: readonly string[]
}

export interface AuditEntry {
  readonly id: string
  readonly occurredAt: string
  readonly actorType: string
  readonly actorId: string | null
  readonly actorAudience: string | null
  readonly environment: string
  readonly action: string
  readonly targetType: string | null
  readonly targetId: string | null
  readonly correlationId: string | null
  readonly sessionId: string | null
  readonly reason: string | null
  readonly approvalReference: string | null
  readonly actorDisplayName: string | null
  readonly actorEmail: string | null
  readonly actorRoleKeys: readonly string[]
  readonly actorRoleScopes: readonly AuditActorRoleScope[]
  readonly capability: string | null
}

export interface AuditActorRoleScope {
  readonly roleKey: string
  readonly scopeType: string | null
  readonly scopeId: string | null
}

export interface AuditPage {
  readonly items: readonly AuditEntry[]
  readonly nextCursor: string | null
}

export interface UserSummary {
  readonly id: string
  readonly accountId: string
  readonly email: string
  readonly displayName: string | null
  readonly status: string
  readonly emailVerified: boolean
  readonly confirmedFactors: number
  readonly createdAt: string
}

export interface UserList {
  readonly items: readonly UserSummary[]
  readonly nextCursor: string | null
}

export interface StaffMember {
  readonly id: string
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly jobTitle: string | null
  readonly departmentKey: string | null
  readonly departmentName: string | null
  readonly engagementStatus: string
  readonly startedOn: string | null
  readonly endedOn: string | null
  readonly confirmedFactors: number
  readonly createdAt: string
}

export interface StaffInvite {
  readonly id: string
  /** Official company address that becomes the account. */
  readonly email: string
  /** Personal address the invitation was delivered to. */
  readonly deliveryEmail?: string
  readonly departmentKey: string | null
  readonly expiresAt: string
  readonly token: string
  readonly emailSent?: boolean
}

export interface StaffStatusResult {
  readonly userId: string
  readonly engagementStatus: string
  readonly sessionsRevoked: number
  readonly grantsRevoked: number
}

export interface AttachedStaffProfile {
  readonly userId: string
  readonly staffProfileId: string
  readonly email: string
  readonly departmentKey: string | null
}

export interface StaffDepartmentResult {
  readonly userId: string
  readonly departmentKey: string | null
}

export interface CreateGrantInput {
  readonly email: string
  readonly grantType: string
  readonly scope: string
  readonly departmentKey: string
  readonly reason: string
  readonly expiresAt?: string
}

export class ApiError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly status: number,
    readonly retryAfterSeconds: number,
  ) {
    super(message)
    this.name = "ApiError"
  }
}

interface ApiErrorDetail {
  code?: string
  message?: string
}

interface ApiErrorBody {
  error?: ApiErrorDetail
}

interface ApiResponse<T> {
  body: T
  response: Response
}

interface Page<T> {
  items: T
  nextCursor: string | null
}

async function requestResponse<T>(
  path: string,
  init?: RequestInit,
): Promise<ApiResponse<T>> {
  const response = await fetch(`/api/v1${path}`, {
    ...init,
    credentials: "same-origin",
    headers: {
      "content-type": "application/json",
      ...(init?.headers ?? {}),
    },
  })

  if (response.status === 204) {
    return { body: undefined as T, response }
  }

  const body = (await response
    .json()
    .catch(() => null)) as T & ApiErrorBody | null

  if (!response.ok) {
    throw new ApiError(
      body?.error?.message ?? "The request could not be completed.",
      body?.error?.code ?? "UNKNOWN",
      response.status,
      Number(response.headers.get("retry-after") ?? 0),
    )
  }

  return { body: body as T, response }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const { body } = await requestResponse<T>(path, init)
  return body
}

async function requestPage<T>(
  path: string,
  init?: RequestInit,
): Promise<Page<T>> {
  const { body, response } = await requestResponse<T>(path, init)
  return {
    items: body,
    nextCursor: response.headers.get("x-next-cursor"),
  }
}

export const api = {
  session: () => request<Session>("/session"),
  signIn: (email: string, password: string) =>
    request<Session | MfaChallenge>("/auth/sign-in", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    }),
  verifyMfa: (challengeToken: string, code: string) =>
    request<Session>("/auth/mfa/verify", {
      method: "POST",
      body: JSON.stringify({ challengeToken, code }),
    }),
  signOut: () =>
    request<void>("/auth/sign-out", {
      method: "POST",
    }),
  ownGrants: () => request<OwnGrants>("/grants"),
  authority: () => request<ControlAuthority>("/control/authority"),
  listUsers: (query: string, status: string, cursor?: string | null) => {
    const params = new URLSearchParams()
    if (query.trim()) params.set("q", query.trim())
    if (status.trim()) params.set("status", status.trim())
    if (cursor) params.set("cursor", cursor)
    const suffix = params.toString()
    return requestPage<readonly UserSummary[]>(
      `/control/users${suffix ? `?${suffix}` : ""}`,
    )
  },
  listGrants: () => request<readonly Grant[]>("/control/grants"),
  listDepartments: () => request<readonly Department[]>("/control/departments"),
  createGrant: (input: CreateGrantInput) =>
    request<Grant>("/control/grants", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  setGrantDepartment: (id: string, departmentKey: string, reason: string) =>
    request<Grant>(`/control/grants/${encodeURIComponent(id)}/department`, {
      method: "PATCH",
      body: JSON.stringify({ departmentKey, reason }),
    }),
  listRoles: () => request<readonly Role[]>("/control/roles"),
  listRoleAssignments: () =>
    request<readonly RoleAssignment[]>("/control/role-assignments"),
  listRoleScopeTargets: (scopeType: RoleScopeType) =>
    request<readonly RoleScopeTarget[]>(
      `/control/roles/scope-targets?type=${encodeURIComponent(scopeType)}`,
    ),
  listAssignableStaff: () =>
    request<readonly AssignableStaff[]>("/control/roles/assignable-staff"),
  assignRole: (input: AssignRoleInput) =>
    request<RoleAssignment>("/control/role-assignments", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  revokeRole: (id: string, reason: string) =>
    request<RoleAssignment>(
      `/control/role-assignments/${encodeURIComponent(id)}/revoke`,
      {
        method: "POST",
        body: JSON.stringify({ reason }),
      },
    ),
  revokeGrant: (id: string, reason: string) =>
    request<Grant>(`/control/grants/${encodeURIComponent(id)}/revoke`, {
      method: "POST",
      body: JSON.stringify({ reason }),
    }),
  listAudit: (cursor?: string | null) => {
    const params = new URLSearchParams()
    if (cursor) params.set("cursor", cursor)
    const suffix = params.toString()
    return requestPage<readonly AuditEntry[]>(
      `/control/audit${suffix ? `?${suffix}` : ""}`,
    )
  },
  listStaff: (query: string, status: string) => {
    const params = new URLSearchParams()
    if (query.trim()) params.set("q", query.trim())
    if (status.trim()) params.set("status", status.trim())
    const suffix = params.toString()
    return request<readonly StaffMember[]>(
      `/control/staff${suffix ? `?${suffix}` : ""}`,
    )
  },
  inviteStaff: (input: {
    email: string
    deliveryEmail?: string
    departmentKey?: string
    jobTitle?: string
    reason: string
  }) =>
    request<StaffInvite>("/control/staff/invites", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  attachStaffProfile: (input: {
    email: string
    departmentKey?: string
    jobTitle?: string
    reason: string
  }) =>
    request<AttachedStaffProfile>("/control/staff/attach", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  setStaffStatus: (
    userId: string,
    action: "suspend" | "reactivate" | "offboard",
    reason: string,
  ) =>
    request<StaffStatusResult>(
      `/control/staff/${encodeURIComponent(userId)}/${action}`,
      {
        method: "POST",
        body: JSON.stringify({ reason }),
      },
    ),
  setStaffDepartment: (userId: string, departmentKey: string, reason: string) =>
    request<StaffDepartmentResult>(
      `/control/staff/${encodeURIComponent(userId)}/department`,
      {
        method: "PATCH",
        body: JSON.stringify({ departmentKey, reason }),
      },
    ),
}

export function isMfaChallenge(
  result: Session | MfaChallenge,
): result is MfaChallenge {
  return "mfaRequired" in result
}

export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status === 429 && error.retryAfterSeconds > 0) {
      return `${error.message} Try again in ${error.retryAfterSeconds} seconds.`
    }
    return error.message
  }
  return "Something went wrong. Please try again."
}
