import { createHivorrClient } from "@hivorr/api-client"

/**
 * One client per bundle. The base URL is injected at build time; the default is
 * the same-origin `/api` edge rewrite. No environment branching in source.
 */
export const apiClient = createHivorrClient({
  baseUrl: import.meta.env.VITE_API_BASE_URL ?? "/api",
  credentials: "include",
})
