import type { PortalId } from "@hivorr/shared"

export interface SessionPolicy {
  /** Hard upper bound on the whole session, regardless of activity. */
  readonly absoluteMs: number
  /** Inactivity bound, extended on each authenticated request. */
  readonly idleMs: number
  /** Lifetime of one access token. Refresh is used to obtain the next one. */
  readonly accessMs: number
}

const PRIVILEGED: ReadonlySet<PortalId> = new Set([
  "control",
  "staff",
  "partner",
])

const REFRESH_COOKIE_PATH = "/v1/auth"

export function sessionPolicy(audience: PortalId): SessionPolicy {
  if (PRIVILEGED.has(audience)) {
    return {
      absoluteMs: 8 * 60 * 60 * 1000,
      idleMs: 15 * 60 * 1000,
      accessMs: 15 * 60 * 1000,
    }
  }
  return {
    absoluteMs: 12 * 60 * 60 * 1000,
    idleMs: 30 * 60 * 1000,
    accessMs: 30 * 60 * 1000,
  }
}

export function sessionCookieName(audience: PortalId): string {
  return `__Host-hivorr_${audience}_sid`
}

/**
 * The refresh cookie is deliberately not `__Host-` because the prefix requires
 * `Path=/`. Scoping it to the auth endpoints keeps it off ordinary API calls.
 */
export function refreshCookieName(audience: PortalId): string {
  return `hivorr_${audience}_rt`
}

export function buildSessionCookie(
  name: string,
  token: string,
  maxAgeSeconds: number,
): string {
  return `${name}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAgeSeconds}`
}

export function buildRefreshCookie(
  name: string,
  token: string,
  maxAgeSeconds: number,
): string {
  return `${name}=${token}; Path=${REFRESH_COOKIE_PATH}; HttpOnly; Secure; SameSite=Strict; Max-Age=${maxAgeSeconds}`
}

export function clearSessionCookie(name: string): string {
  return `${name}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`
}

export function clearRefreshCookie(name: string): string {
  return `${name}=; Path=${REFRESH_COOKIE_PATH}; HttpOnly; Secure; SameSite=Strict; Max-Age=0`
}
