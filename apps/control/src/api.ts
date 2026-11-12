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
  readonly grantType: string
  readonly scope: string
  readonly environment: string
  readonly grantedBy: string | null
  readonly expiresAt: string | null
  readonly revokedAt: string | null
  readonly createdAt: string
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

export interface CreateGrantInput {
  readonly email: string
  readonly grantType: string
  readonly scope: string
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
  createGrant: (input: CreateGrantInput) =>
    request<Grant>("/control/grants", {
      method: "POST",
      body: JSON.stringify(input),
    }),
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
