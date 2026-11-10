import { ACTIVITY_IDS } from "@hivorr/shared"
import { describe, expect, it } from "vitest"

import {
  PERSISTED_ACTIVATION_STATES,
  assertActivationTransition,
  canStartActivation,
  canTransitionActivation,
  isVisibleActivation,
  type PersistedActivationState,
} from "../server/src/modules/profile/domain/activation"

describe("activity activation state machine", () => {
  it("declares the six activity IDs once", () => {
    expect(ACTIVITY_IDS).toHaveLength(6)
    expect(new Set(ACTIVITY_IDS).size).toBe(6)
  })

  it("allows every approved transition", () => {
    const allowed: Array<[PersistedActivationState, PersistedActivationState]> =
      [
        ["INACTIVE", "ACTIVE"],
        ["ACTIVE", "INACTIVE"],
        ["ACTIVE", "RESTRICTED"],
        ["ACTIVE", "SUSPENDED"],
        ["RESTRICTED", "ACTIVE"],
        ["RESTRICTED", "INACTIVE"],
        ["SUSPENDED", "ACTIVE"],
        ["SUSPENDED", "INACTIVE"],
      ]
    for (const [from, to] of allowed) {
      expect(canTransitionActivation(from, to), `${from} -> ${to}`).toBe(true)
      expect(() => assertActivationTransition(from, to)).not.toThrow()
    }
  })

  it("rejects every unapproved transition", () => {
    const denied: Array<[PersistedActivationState, PersistedActivationState]> =
      [
        ["INACTIVE", "RESTRICTED"],
        ["INACTIVE", "SUSPENDED"],
        ["RESTRICTED", "SUSPENDED"],
        ["SUSPENDED", "RESTRICTED"],
      ]
    for (const [from, to] of denied) {
      expect(canTransitionActivation(from, to), `${from} -> ${to}`).toBe(false)
      expect(() => assertActivationTransition(from, to)).toThrow(
        /invalid activity activation transition/,
      )
    }
  })

  it("treats a same-state update as an idempotent no-op", () => {
    for (const state of PERSISTED_ACTIVATION_STATES) {
      expect(canTransitionActivation(state, state)).toBe(true)
    }
  })

  it("a new row may start only INACTIVE or ACTIVE", () => {
    expect(canStartActivation("INACTIVE")).toBe(true)
    expect(canStartActivation("ACTIVE")).toBe(true)
    expect(canStartActivation("RESTRICTED")).toBe(false)
    expect(canStartActivation("SUSPENDED")).toBe(false)
  })

  it("hides only INACTIVE from the switcher", () => {
    expect(isVisibleActivation("INACTIVE")).toBe(false)
    expect(isVisibleActivation("ACTIVE")).toBe(true)
    expect(isVisibleActivation("RESTRICTED")).toBe(true)
    expect(isVisibleActivation("SUSPENDED")).toBe(true)
  })
})
