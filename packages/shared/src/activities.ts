import { z } from "zod"

/**
 * The six approved activities.
 *
 * These are capabilities an account can activate, never account types
 * (`Unified-Account-and-Activity-Permission-Matrix.md` §A1). The IDs are dotted
 * so they read the same in the database, the API and telemetry. The activation
 * state machine, tables and endpoints belong to EP-01-024 and EP-01-033; this
 * module owns only the vocabulary.
 */
export const ACTIVITY_IDS = [
  "market.buy",
  "services.hire",
  "errands.request",
  "market.sell",
  "services.offer",
  "logistics.provide",
] as const

export type ActivityId = typeof ACTIVITY_IDS[number]

export type ActivityDirection = "explore" | "earn"

export interface ActivityDefinition {
  readonly id: ActivityId
  readonly label: string
  readonly direction: ActivityDirection
  /** Dashboard label used by the prototype; a presentation label, not a role. */
  readonly dashboard: string
  /** Approved URL family from ARCHITECTURE.md §4.2. */
  readonly routePath: string
}

export const ACTIVITIES: Readonly<Record<ActivityId, ActivityDefinition>> = {
  "market.buy": {
    id: "market.buy",
    label: "Buy",
    direction: "explore",
    dashboard: "Local Market",
    routePath: "/explore/market",
  },
  "services.hire": {
    id: "services.hire",
    label: "Hire",
    direction: "explore",
    dashboard: "Client",
    routePath: "/explore/hire",
  },
  "errands.request": {
    id: "errands.request",
    label: "Errand",
    direction: "explore",
    dashboard: "Errand requester",
    routePath: "/explore/errands",
  },
  "market.sell": {
    id: "market.sell",
    label: "Sell",
    direction: "earn",
    dashboard: "Seller",
    routePath: "/earn/sell",
  },
  "services.offer": {
    id: "services.offer",
    label: "Offer services",
    direction: "earn",
    dashboard: "Professional",
    routePath: "/earn/services",
  },
  "logistics.provide": {
    id: "logistics.provide",
    label: "Provide logistics",
    direction: "earn",
    dashboard: "Logistics provider",
    routePath: "/earn/logistics",
  },
}

/**
 * Activation states an activity row can hold. The permitted transitions are
 * owned by EP-01-033 and are deliberately not encoded here.
 */
export const ACTIVITY_ACTIVATION_STATES = [
  "ACTIVE",
  "RESTRICTED",
  "SUSPENDED",
] as const

export type ActivityActivationState = typeof ACTIVITY_ACTIVATION_STATES[number]

export const activityIdSchema = z.enum(ACTIVITY_IDS)

export const activityActivationStateSchema = z.enum(ACTIVITY_ACTIVATION_STATES)

export function isActivityId(value: string): value is ActivityId {
  return (ACTIVITY_IDS as readonly string[]).includes(value)
}

export function getActivity(id: ActivityId): ActivityDefinition {
  return ACTIVITIES[id]
}
