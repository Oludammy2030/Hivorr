import { describe, expect, it } from "vitest"

import {
  canTransitionScan,
  isUsableEvidence,
  scanTransitionPairs,
} from "../server/src/modules/profile/domain/evidence"

/** The approved scan table. The database function is asserted against the same list. */
const APPROVED_PAIRS: readonly (readonly [string, string])[] = [
  ["PENDING", "CLEAN"],
  ["PENDING", "INFECTED"],
  ["PENDING", "FAILED"],
]

describe("evidence scan transitions", () => {
  it("matches the approved scan table exactly", () => {
    expect(
      scanTransitionPairs()
        .map(([from, to]) => `${from}->${to}`)
        .sort(),
    ).toEqual(APPROVED_PAIRS.map(([from, to]) => `${from}->${to}`).sort())
  })

  it("decides a pending file once and never re-decides it", () => {
    const states = ["PENDING", "CLEAN", "INFECTED", "FAILED"] as const
    const approved = new Set(APPROVED_PAIRS.map(([from, to]) => `${from}->${to}`))

    for (const from of states) {
      for (const to of states) {
        const expected = from === to || approved.has(`${from}->${to}`)
        expect(canTransitionScan(from, to), `${from} -> ${to}`).toBe(expected)
      }
    }
  })

  it("treats only a clean file as usable", () => {
    expect(isUsableEvidence("CLEAN")).toBe(true)
    expect(isUsableEvidence("PENDING")).toBe(false)
    expect(isUsableEvidence("INFECTED")).toBe(false)
    expect(isUsableEvidence("FAILED")).toBe(false)
  })
})
