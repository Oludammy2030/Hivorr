/**
 * Typed route manifest for the EP-01 slice (EP-01-052).
 *
 * `@hivorr/shared` owns the approved route vocabulary and paths. This module
 * selects the slice subset: the only paths the EP-01 frontend may reach. Every
 * other approved family stays declared in the contract but is not registered
 * yet, so it cannot be reached by accident.
 */

import {
  ROUTES,
  ROUTE_IDS,
  type RouteDefinition,
  type RouteId,
} from "@hivorr/shared"

/** Every approved route family, for coverage checks and the future shells. */
export const APPROVED_ROUTE_IDS = ROUTE_IDS
export type ApprovedRouteId = RouteId

/** The EP-01 slice: auth, onboarding, session bootstrap and activity switch. */
export const SLICE_ROUTE_IDS = [
  "home",
  "login",
  "signup",
  "onboarding",
  "forgot-password",
  "reset-password",
  "verify-email",
  "activities",
] as const

export type SliceRouteId = typeof SLICE_ROUTE_IDS[number]

export const SLICE_ROUTES: readonly RouteDefinition[] = SLICE_ROUTE_IDS.map(
  (id) => ROUTES[id],
)

const SLICE_BY_PATH = new Map<string, RouteDefinition>(
  SLICE_ROUTES.map((route) => [route.path, route]),
)

export function isSliceRouteId(value: string): value is SliceRouteId {
  return (SLICE_ROUTE_IDS as readonly string[]).includes(value)
}

/**
 * Resolve a pathname to a slice route. Query strings and fragments are the
 * caller's responsibility; this accepts a pathname only. Trailing slashes are
 * ignored, except for `/` itself.
 */
export function matchSlicePath(pathname: string): RouteDefinition | undefined {
  const normalized =
    pathname === "/" ? "/" : pathname.replace(/\/+$/, "") || "/"
  return SLICE_BY_PATH.get(normalized)
}

/** True when the path is a declared route family outside the slice. */
export function isApprovedButUnreachable(pathname: string): boolean {
  const normalized =
    pathname === "/" ? "/" : pathname.replace(/\/+$/, "") || "/"
  if (SLICE_BY_PATH.has(normalized)) return false
  return APPROVED_ROUTE_IDS.some((id) => {
    const pattern = ROUTES[id].path
    if (!pattern.includes(":")) return pattern === normalized
    const prefix = pattern.slice(0, pattern.indexOf(":"))
    return normalized.startsWith(prefix)
  })
}
