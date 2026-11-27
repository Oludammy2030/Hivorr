import type { EvidenceScanState } from "@hivorr/shared"

/**
 * Evidence scan state machine (EP-02-012, scanning slice).
 *
 * A reference starts `PENDING`. One scan decides it: `CLEAN`, `INFECTED` or
 * `FAILED`. Every one of those is terminal — a rescan is a new reference, so a
 * bad object can never be laundered into a clean one by another update.
 *
 * Only `CLEAN` evidence is usable: a pending or failed file must not reach a
 * reviewer, and a submission cannot leave draft with one.
 */
const SCAN_TRANSITIONS: Readonly<Record<EvidenceScanState, readonly EvidenceScanState[]>> = {
  PENDING: ["CLEAN", "INFECTED", "FAILED"],
  CLEAN: [],
  INFECTED: [],
  FAILED: [],
}

export function canTransitionScan(from: EvidenceScanState, to: EvidenceScanState): boolean {
  return from === to || SCAN_TRANSITIONS[from].includes(to)
}

export function isUsableEvidence(state: EvidenceScanState): boolean {
  return state === "CLEAN"
}

/** Exposed for the drift test against the database function. */
export function scanTransitionPairs(): readonly (readonly [
  EvidenceScanState,
  EvidenceScanState,
])[] {
  const pairs: [EvidenceScanState, EvidenceScanState][] = []
  for (const [from, targets] of Object.entries(SCAN_TRANSITIONS)) {
    for (const to of targets) pairs.push([from as EvidenceScanState, to])
  }
  return pairs
}
