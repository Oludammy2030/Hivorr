/**
 * Session and capability presentation state (EP-01-052).
 *
 * The session endpoint is the only source. This mapping is deliberately pure so
 * the "capabilities are presentation-only" rule is testable: nothing here
 * writes, persists or treats a capability as authorisation. The API re-checks
 * every capability inside the transaction.
 */

import { ApiClientError, type SessionResponse } from "@hivorr/api-client"

export type CapabilityId = SessionResponse["capabilities"][number]

export type SessionStatus = "loading" | "authenticated" | "anonymous" | "error"

export interface SessionState {
  readonly status: SessionStatus
  readonly session: SessionResponse | null
  /** Capabilities the UI may use to hide or label a control. Never authority. */
  readonly presentedCapabilities: readonly CapabilityId[]
  readonly canPresent: (capability: CapabilityId) => boolean
}

export interface SessionQuerySnapshot {
  readonly isPending: boolean
  readonly isError: boolean
  readonly data: SessionResponse | undefined
  readonly error: unknown
}

export const ANONYMOUS_SESSION: SessionState = Object.freeze({
  status: "anonymous",
  session: null,
  presentedCapabilities: [],
  canPresent: () => false,
})

export const LOADING_SESSION: SessionState = Object.freeze({
  status: "loading",
  session: null,
  presentedCapabilities: [],
  canPresent: () => false,
})

export function sessionStateFrom(snapshot: SessionQuerySnapshot): SessionState {
  if (snapshot.isPending) return LOADING_SESSION

  if (snapshot.isError) {
    if (
      snapshot.error instanceof ApiClientError &&
      snapshot.error.status === 401
    ) {
      return ANONYMOUS_SESSION
    }
    return {
      status: "error",
      session: null,
      presentedCapabilities: [],
      canPresent: () => false,
    }
  }

  if (!snapshot.data) return ANONYMOUS_SESSION

  const presentedCapabilities = Object.freeze([...snapshot.data.capabilities])
  const presented = new Set(presentedCapabilities)
  return {
    status: "authenticated",
    session: snapshot.data,
    presentedCapabilities,
    canPresent: (capability) => presented.has(capability),
  }
}
