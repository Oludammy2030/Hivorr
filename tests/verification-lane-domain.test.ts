import { describe, expect, it } from "vitest"

import {
  canApplyEvent,
  canTransitionLane,
  canTransitionSubmission,
  isOpenSubmission,
  isReopenable,
  laneTransitionPairs,
  targetStateFor,
} from "../server/src/modules/profile/domain/verification"

/** The approved table. The database function is asserted against the same list. */
const APPROVED_PAIRS: readonly (readonly [string, string])[] = [
  ["NOT_STARTED", "DRAFT"],
  ["DRAFT", "SUBMITTED"],
  ["DRAFT", "NOT_STARTED"],
  ["SUBMITTED", "UNDER_REVIEW"],
  ["SUBMITTED", "DRAFT"],
  ["SUBMITTED", "EXPIRED"],
  ["UNDER_REVIEW", "APPROVED"],
  ["UNDER_REVIEW", "REJECTED"],
  ["APPROVED", "EXPIRED"],
  ["REJECTED", "DRAFT"],
  ["EXPIRED", "DRAFT"],
]

function sorted(pairs: readonly (readonly [string, string])[]): string[] {
  return pairs.map(([from, to]) => `${from}->${to}`).sort()
}

describe("verification lane transitions", () => {
  it("matches the approved transition table exactly", () => {
    expect(sorted(laneTransitionPairs())).toEqual(sorted(APPROVED_PAIRS))
  })

  it("allows every approved pair and refuses the rest", () => {
    const approved = new Set(sorted(APPROVED_PAIRS))
    const states = [
      "NOT_STARTED",
      "DRAFT",
      "SUBMITTED",
      "UNDER_REVIEW",
      "APPROVED",
      "REJECTED",
      "EXPIRED",
    ] as const

    for (const from of states) {
      for (const to of states) {
        const expected = from === to || approved.has(`${from}->${to}`)
        expect(canTransitionLane(from, to), `${from} -> ${to}`).toBe(expected)
      }
    }
  })

  it("never reopens an approved lane", () => {
    expect(canTransitionLane("APPROVED", "DRAFT")).toBe(false)
    expect(canTransitionLane("APPROVED", "SUBMITTED")).toBe(false)
    expect(isReopenable("APPROVED")).toBe(false)
    expect(isReopenable("REJECTED")).toBe(true)
    expect(isReopenable("EXPIRED")).toBe(true)
  })

  it("does not let a submission start from NOT_STARTED", () => {
    expect(canTransitionSubmission("NOT_STARTED", "DRAFT")).toBe(false)
    expect(canTransitionSubmission("DRAFT", "SUBMITTED")).toBe(true)
    expect(canTransitionSubmission("SUBMITTED", "UNDER_REVIEW")).toBe(true)
  })

  it("applies only the subject events from their own states", () => {
    expect(canApplyEvent("start", "NOT_STARTED")).toBe(true)
    expect(canApplyEvent("start", "REJECTED")).toBe(true)
    expect(canApplyEvent("start", "EXPIRED")).toBe(true)
    expect(canApplyEvent("start", "APPROVED")).toBe(false)
    expect(canApplyEvent("start", "DRAFT")).toBe(false)

    expect(canApplyEvent("submit", "DRAFT")).toBe(true)
    expect(canApplyEvent("submit", "SUBMITTED")).toBe(false)

    expect(canApplyEvent("withdraw", "SUBMITTED")).toBe(true)
    expect(canApplyEvent("withdraw", "UNDER_REVIEW")).toBe(false)
    expect(canApplyEvent("withdraw", "DRAFT")).toBe(false)

    expect(targetStateFor("start")).toBe("DRAFT")
    expect(targetStateFor("submit")).toBe("SUBMITTED")
    expect(targetStateFor("withdraw")).toBe("DRAFT")
  })

  it("treats draft, submitted and under review as open", () => {
    expect(isOpenSubmission("DRAFT")).toBe(true)
    expect(isOpenSubmission("SUBMITTED")).toBe(true)
    expect(isOpenSubmission("UNDER_REVIEW")).toBe(true)
    expect(isOpenSubmission("APPROVED")).toBe(false)
    expect(isOpenSubmission("REJECTED")).toBe(false)
    expect(isOpenSubmission("EXPIRED")).toBe(false)
  })
})
