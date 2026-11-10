/**
 * Shared client shell for the four Hivorr applications (EP-01-052).
 *
 * It owns the slice route table, the 404, the server-state client and the
 * presentation-only session/capability context. Screens are supplied by the
 * application; this package never imports one.
 */

export {
  APPROVED_ROUTE_IDS,
  SLICE_ROUTE_IDS,
  SLICE_ROUTES,
  isApprovedButUnreachable,
  isSliceRouteId,
  matchSlicePath,
  type ApprovedRouteId,
  type SliceRouteId,
} from "./route-manifest"
export { NotFound } from "./not-found"
export { SliceBrowserRouter, SliceRoutes, type SliceScreens } from "./routes"
export {
  ANONYMOUS_SESSION,
  LOADING_SESSION,
  sessionStateFrom,
  type CapabilityId,
  type SessionQuerySnapshot,
  type SessionState,
  type SessionStatus,
} from "./session-state"
export {
  SESSION_QUERY_KEY,
  SessionProvider,
  sessionQueryOptions,
  useSession,
  type SessionClient,
  type SessionContextValue,
} from "./session-context"
export {
  AppProviders,
  createQueryClient,
  type AppProvidersProps,
} from "./providers"
