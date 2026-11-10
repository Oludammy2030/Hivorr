import {
  ACTIVITY_ACTIVATION_STATES,
  type ActivityActivationState,
} from "@hivorr/shared"

/**
 * Persisted activation states. `INACTIVE` is a stored row state, not a
 * dashboard state: a deactivated activity keeps its row and history.
 */
export const PERSISTED_ACTIVATION_STATES = [
  "INACTIVE",
  ...ACTIVITY_ACTIVATION_STATES,
] as const

export type PersistedActivationState = typeof PERSISTED_ACTIVATION_STATES[number]

const TRANSITIONS: Readonly<Record<PersistedActivationState, readonly PersistedActivationState[]>> =
  {
    INACTIVE: ["ACTIVE"],
    ACTIVE: ["INACTIVE", "RESTRICTED", "SUSPENDED"],
    RESTRICTED: ["ACTIVE", "INACTIVE"],
    SUSPENDED: ["ACTIVE", "INACTIVE"],
  }

export function canTransitionActivation(
  from: PersistedActivationState,
  to: PersistedActivationState,
): boolean {
  return from === to || TRANSITIONS[from].includes(to)
}

export function assertActivationTransition(
  from: PersistedActivationState,
  to: PersistedActivationState,
): void {
  if (!canTransitionActivation(from, to)) {
    throw new Error(`invalid activity activation transition ${from} -> ${to}`)
  }
}

export function isVisibleActivation(state: PersistedActivationState): boolean {
  return state !== "INACTIVE"
}

/** A newly inserted activation is either not yet shown or active. */
export function canStartActivation(
  state: PersistedActivationState,
): state is "INACTIVE" | "ACTIVE" {
  return state === "INACTIVE" || state === "ACTIVE"
}

export type { ActivityActivationState }
