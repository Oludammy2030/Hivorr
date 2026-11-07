import type { PortalId } from "@hivorr/shared"

export interface SessionPolicy {
  readonly absoluteMs: number
  readonly idleMs: number
}

const PRIVILEGED: ReadonlySet<PortalId> = new Set([
  "control",
  "staff",
  "partner",
])

export function sessionPolicy(audience: PortalId): SessionPolicy {
  if (PRIVILEGED.has(audience)) {
    return { absoluteMs: 8 * 60 * 60 * 1000, idleMs: 15 * 60 * 1000 }
  }
  return { absoluteMs: 12 * 60 * 60 * 1000, idleMs: 30 * 60 * 1000 }
}

export function sessionCookieName(audience: PortalId): string {
  return `__Host-hivorr_${audience}_sid`
}

export function buildSessionCookie(
  name: string,
  token: string,
  maxAgeSeconds: number,
): string {
  return `${name}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAgeSeconds}`
}

export function clearSessionCookie(name: string): string {
  return `${name}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`
}
