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

export interface AccountAction {
  readonly userId: string
  readonly status: string
  readonly sessionsRevoked: number
  readonly grantsRevoked: number
  readonly rolesRevoked: number
}

export interface AccountNote {
  readonly id: string
  readonly body: string
  readonly authorName: string | null
  readonly authorEmail: string | null
  readonly createdAt: string
}

export interface AccountTimelineEntry {
  readonly occurredAt: string
  readonly action: string
  readonly reason: string | null
  readonly actorName: string | null
  readonly actorEmail: string | null
}

export interface ApprovalRequest {
  readonly id: string
  readonly reference: string
  readonly actionType: string
  readonly targetType: string
  readonly targetId: string
  readonly status: string
  readonly reason: string
  readonly requesterUserId: string
  readonly requesterName: string | null
  readonly requesterEmail: string | null
  readonly createdAt: string
  readonly decidedAt: string | null
}

export interface PartnerOrganisation {
  readonly id: string
  readonly legalName: string
  readonly tradingName: string | null
  readonly category: string | null
  readonly country: string | null
  readonly status: string
  readonly representatives: number
  readonly agreements: number
  readonly createdAt: string
}

export interface PartnerRepresentative {
  readonly id: string
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly role: string
  readonly effectiveFrom: string
  readonly effectiveTo: string | null
}

export interface CaseSummary {
  readonly id: string
  readonly reference: string
  readonly caseType: string
  readonly title: string
  readonly description: string | null
  readonly priority: string
  readonly severity: string
  readonly status: string
  readonly queueKey: string | null
  readonly assigneeId: string | null
  readonly assigneeName: string | null
  readonly assigneeEmail: string | null
  readonly departmentName: string | null
  readonly createdAt: string
  readonly updatedAt: string
  readonly closedAt: string | null
}

export interface CaseEvent {
  readonly id: string
  readonly eventType: string
  readonly summary: string
  readonly actorName: string | null
  readonly actorEmail: string | null
  readonly occurredAt: string
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
  suspendUser: (id: string, reason: string) =>
    request<AccountAction>(`/control/users/${encodeURIComponent(id)}/suspend`, {
      method: "POST",
      body: JSON.stringify({ reason }),
    }),
  reactivateUser: (id: string, reason: string) =>
    request<AccountAction>(
      `/control/users/${encodeURIComponent(id)}/reactivate`,
      { method: "POST", body: JSON.stringify({ reason }) },
    ),
  revokeUserSessions: (id: string, reason: string) =>
    request<AccountAction>(
      `/control/users/${encodeURIComponent(id)}/revoke-sessions`,
      { method: "POST", body: JSON.stringify({ reason }) },
    ),
  listUserNotes: (id: string) =>
    request<readonly AccountNote[]>(
      `/control/users/${encodeURIComponent(id)}/notes`,
    ),
  addUserNote: (id: string, body: string) =>
    request<AccountNote>(`/control/users/${encodeURIComponent(id)}/notes`, {
      method: "POST",
      body: JSON.stringify({ body }),
    }),
  userTimeline: (id: string) =>
    request<readonly AccountTimelineEntry[]>(
      `/control/users/${encodeURIComponent(id)}/timeline`,
    ),
  listApprovals: () =>
    request<readonly ApprovalRequest[]>("/control/approvals"),
  requestApproval: (input: {
    actionType: string
    targetType: string
    targetId: string
    reason: string
  }) =>
    request<ApprovalRequest>("/control/approvals", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  decideApproval: (
    id: string,
    decision: "approve" | "reject",
    reason: string,
  ) =>
    request<ApprovalRequest>(
      `/control/approvals/${encodeURIComponent(id)}/decide`,
      { method: "POST", body: JSON.stringify({ decision, reason }) },
    ),
  listPartners: () =>
    request<readonly PartnerOrganisation[]>("/control/partners"),
  createPartner: (input: {
    legalName: string
    tradingName?: string
    category?: string
    country?: string
    reason: string
  }) =>
    request<PartnerOrganisation>("/control/partners", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  setPartnerStatus: (id: string, status: string, reason: string) =>
    request<PartnerOrganisation>(
      `/control/partners/${encodeURIComponent(id)}/status`,
      { method: "POST", body: JSON.stringify({ status, reason }) },
    ),
  listPartnerRepresentatives: (id: string) =>
    request<readonly PartnerRepresentative[]>(
      `/control/partners/${encodeURIComponent(id)}/representatives`,
    ),
  addPartnerRepresentative: (
    id: string,
    email: string,
    role: string,
    reason: string,
  ) =>
    request<PartnerRepresentative>(
      `/control/partners/${encodeURIComponent(id)}/representatives`,
      { method: "POST", body: JSON.stringify({ email, role, reason }) },
    ),
  listCases: (status: string, caseType: string, query: string) => {
    const params = new URLSearchParams()
    if (status.trim()) params.set("status", status.trim())
    if (caseType.trim()) params.set("type", caseType.trim())
    if (query.trim()) params.set("q", query.trim())
    const suffix = params.toString()
    return request<readonly CaseSummary[]>(
      `/control/cases${suffix ? `?${suffix}` : ""}`,
    )
  },
  createCase: (input: {
    caseType: string
    title: string
    description?: string
    priority: string
    severity: string
    queueKey?: string
    reason: string
  }) =>
    request<CaseSummary>("/control/cases", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  listCaseEvents: (id: string) =>
    request<readonly CaseEvent[]>(
      `/control/cases/${encodeURIComponent(id)}/events`,
    ),
  addCaseEvent: (id: string, summary: string) =>
    request<CaseEvent>(`/control/cases/${encodeURIComponent(id)}/events`, {
      method: "POST",
      body: JSON.stringify({ summary }),
    }),
  assignCase: (id: string, email: string, queueKey: string) =>
    request<CaseSummary>(`/control/cases/${encodeURIComponent(id)}/assign`, {
      method: "POST",
      body: JSON.stringify({
        ...(email.trim() ? { email: email.trim() } : {}),
        ...(queueKey.trim() ? { queueKey: queueKey.trim() } : {}),
      }),
    }),
  setCaseStatus: (id: string, status: string, reason: string) =>
    request<CaseSummary>(`/control/cases/${encodeURIComponent(id)}/status`, {
      method: "POST",
      body: JSON.stringify({ status, reason }),
    }),
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
