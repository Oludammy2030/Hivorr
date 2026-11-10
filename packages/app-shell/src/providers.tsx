import { useState, type ReactNode } from "react"

import { QueryClient, QueryClientProvider } from "@tanstack/react-query"

import { SessionProvider, type SessionClient } from "./session-context"

/**
 * Server state defaults: no retry (the API is explicit about failure), no
 * refetch on window focus, and a small stale window. Session state is not
 * persisted anywhere.
 */
export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        refetchOnWindowFocus: false,
        staleTime: 30_000,
      },
    },
  })
}

export interface AppProvidersProps {
  readonly client: SessionClient
  readonly children: ReactNode
  /** Injected in tests and in the server-rendered shell. */
  readonly queryClient?: QueryClient
}

export function AppProviders({
  client,
  children,
  queryClient,
}: AppProvidersProps) {
  const [fallbackClient] = useState(() => queryClient ?? createQueryClient())

  return (
    <QueryClientProvider client={queryClient ?? fallbackClient}>
      <SessionProvider client={client}>{children}</SessionProvider>
    </QueryClientProvider>
  )
}
