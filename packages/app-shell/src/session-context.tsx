import { createContext, useContext, type ReactNode } from "react"

import type { SessionResponse } from "@hivorr/api-client"
import { useQuery } from "@tanstack/react-query"

import { sessionStateFrom, type SessionState } from "./session-state"

export const SESSION_QUERY_KEY = ["session"] as const

export interface SessionClient {
  readonly session: () => Promise<SessionResponse>
}

/** The single session query definition. Nothing persists or re-seeds it. */
export function sessionQueryOptions(client: SessionClient) {
  return {
    queryKey: SESSION_QUERY_KEY,
    queryFn: () => client.session(),
    retry: false,
  } as const
}

export interface SessionContextValue
  extends SessionState {
  /** Re-read the session after a sign-in, sign-out or activation change. */
  readonly refresh: () => void
}

const SessionContext = createContext<SessionContextValue | null>(null)

/**
 * Reads `GET /v1/session` through TanStack Query and exposes it as presentation
 * state. The query is not persisted: a reload re-reads it, and no capability is
 * ever treated as authority.
 */
export function SessionProvider({
  client,
  children,
}: {
  readonly client: SessionClient
  readonly children: ReactNode
}) {
  const query = useQuery(sessionQueryOptions(client))
  const state = sessionStateFrom(query)

  return (
    <SessionContext.Provider
      value={{
        ...state,
        refresh: () => {
          void query.refetch()
        },
      }}
    >
      {children}
    </SessionContext.Provider>
  )
}

export function useSession(): SessionContextValue {
  const value = useContext(SessionContext)
  if (!value) {
    throw new Error("useSession must be used inside SessionProvider")
  }
  return value
}
