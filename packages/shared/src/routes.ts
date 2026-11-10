import { z } from "zod"

import type { PortalId } from "./index.js"

/**
 * Approved UI route identifiers from ARCHITECTURE.md §8.6 and §4.2.
 *
 * This module declares the vocabulary and the approved paths. It does not
 * implement routing; EP-01-052 owns the router, the route table and the
 * reachability rules for the EP-01 slice. Paths are stable contract values and
 * must not be renamed to suit a component.
 */
export const ROUTE_IDS = [
  "home",
  "login",
  "signup",
  "onboarding",
  "forgot-password",
  "reset-password",
  "verify-email",
  "activities",
  "explore-market",
  "explore-hire",
  "explore-errands",
  "earn-sell",
  "earn-services",
  "earn-logistics",
  "wallet",
  "messages",
  "profile",
  "product",
  "store",
  "admin",
] as const

export type RouteId = typeof ROUTE_IDS[number]

export interface RouteDefinition {
  readonly id: RouteId
  readonly portal: PortalId
  readonly path: string
  /** True only where the architecture requires a crawler-visible URL. */
  readonly indexable: boolean
  /** False only for the pre-authentication public routes. */
  readonly requiresAuth: boolean
}

export const ROUTES: Readonly<Record<RouteId, RouteDefinition>> = {
  home: {
    id: "home",
    portal: "app",
    path: "/",
    indexable: true,
    requiresAuth: false,
  },
  login: {
    id: "login",
    portal: "app",
    path: "/login",
    indexable: false,
    requiresAuth: false,
  },
  signup: {
    id: "signup",
    portal: "app",
    path: "/signup",
    indexable: false,
    requiresAuth: false,
  },
  onboarding: {
    id: "onboarding",
    portal: "app",
    path: "/onboarding",
    indexable: false,
    requiresAuth: true,
  },
  "forgot-password": {
    id: "forgot-password",
    portal: "app",
    path: "/forgot-password",
    indexable: false,
    requiresAuth: false,
  },
  "reset-password": {
    id: "reset-password",
    portal: "app",
    path: "/reset-password",
    indexable: false,
    requiresAuth: false,
  },
  "verify-email": {
    id: "verify-email",
    portal: "app",
    path: "/verify-email",
    indexable: false,
    requiresAuth: false,
  },
  activities: {
    id: "activities",
    portal: "app",
    path: "/activities",
    indexable: false,
    requiresAuth: true,
  },
  "explore-market": {
    id: "explore-market",
    portal: "app",
    path: "/explore/market",
    indexable: false,
    requiresAuth: true,
  },
  "explore-hire": {
    id: "explore-hire",
    portal: "app",
    path: "/explore/hire",
    indexable: false,
    requiresAuth: true,
  },
  "explore-errands": {
    id: "explore-errands",
    portal: "app",
    path: "/explore/errands",
    indexable: false,
    requiresAuth: true,
  },
  "earn-sell": {
    id: "earn-sell",
    portal: "app",
    path: "/earn/sell",
    indexable: false,
    requiresAuth: true,
  },
  "earn-services": {
    id: "earn-services",
    portal: "app",
    path: "/earn/services",
    indexable: false,
    requiresAuth: true,
  },
  "earn-logistics": {
    id: "earn-logistics",
    portal: "app",
    path: "/earn/logistics",
    indexable: false,
    requiresAuth: true,
  },
  wallet: {
    id: "wallet",
    portal: "app",
    path: "/wallet",
    indexable: false,
    requiresAuth: true,
  },
  messages: {
    id: "messages",
    portal: "app",
    path: "/messages",
    indexable: false,
    requiresAuth: true,
  },
  profile: {
    id: "profile",
    portal: "app",
    path: "/profile",
    indexable: false,
    requiresAuth: true,
  },
  product: {
    id: "product",
    portal: "app",
    path: "/p/:slug",
    indexable: true,
    requiresAuth: false,
  },
  store: {
    id: "store",
    portal: "app",
    path: "/store/:slug",
    indexable: true,
    requiresAuth: false,
  },
  admin: {
    id: "admin",
    portal: "control",
    path: "/admin",
    indexable: false,
    requiresAuth: true,
  },
}

export const routeIdSchema = z.enum(ROUTE_IDS)

export function getRoute(id: RouteId): RouteDefinition {
  return ROUTES[id]
}

export function isRouteId(value: string): value is RouteId {
  return (ROUTE_IDS as readonly string[]).includes(value)
}
