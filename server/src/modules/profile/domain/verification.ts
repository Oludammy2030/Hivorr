import { isVerificationLane, type VerificationLane, type VerificationState } from "@hivorr/shared"

/**
 * Verification lane state machine (EP-02-011).
 *
 * Seven states, six lanes. The transitions are identical for every lane: a lane
 * is not an account status and approving one never implies another. The database
 * enforces the same table in `profile.verification_transition_allowed`; this
 * module is the domain half and the two must stay in step.
 *
 * Subject actions only. The reviewer path (start review, approve, reject) is
 * EP-02-015's and is deliberately absent here.
 */

const CASE_TRANSITIONS: Readonly<Record<VerificationState, readonly VerificationState[]>> = {
  NOT_STARTED: ["DRAFT"],
  DRAFT: ["SUBMITTED", "NOT_STARTED"],
  SUBMITTED: ["UNDER_REVIEW", "DRAFT", "EXPIRED"],
  UNDER_REVIEW: ["APPROVED", "REJECTED"],
  APPROVED: ["EXPIRED"],
  REJECTED: ["DRAFT"],
  EXPIRED: ["DRAFT"],
}

/**
 * A submission is one review attempt. It never exists in `NOT_STARTED`; the
 * remaining transitions match the case so the two rows cannot disagree.
 */
const SUBMISSION_TRANSITIONS: Readonly<Record<VerificationState, readonly VerificationState[]>> = {
  ...CASE_TRANSITIONS,
  NOT_STARTED: [],
}

export function canTransitionLane(from: VerificationState, to: VerificationState): boolean {
  return from === to || CASE_TRANSITIONS[from].includes(to)
}

export function canTransitionSubmission(from: VerificationState, to: VerificationState): boolean {
  return from === to || SUBMISSION_TRANSITIONS[from].includes(to)
}

/** A lane reopens only from a rejected or expired attempt, never from approved. */
export function isReopenable(state: VerificationState): boolean {
  return state === "REJECTED" || state === "EXPIRED"
}

export function isOpenSubmission(state: VerificationState): boolean {
  return state === "DRAFT" || state === "SUBMITTED" || state === "UNDER_REVIEW"
}

export const SUBJECT_EVENTS = ["start", "submit", "withdraw"] as const

export type SubjectEvent = (typeof SUBJECT_EVENTS)[number]

interface EventRule {
  readonly to: VerificationState
  readonly from: readonly VerificationState[]
}

const EVENT_RULES: Readonly<Record<SubjectEvent, EventRule>> = {
  // Starting or restarting: a fresh attempt from not-started, rejected or expired.
  start: { to: "DRAFT", from: ["NOT_STARTED", "REJECTED", "EXPIRED"] },
  submit: { to: "SUBMITTED", from: ["DRAFT"] },
  // Withdrawal returns the attempt to draft; the case follows. Under review is
  // not withdrawable — the reviewer owns the row at that point.
  withdraw: { to: "DRAFT", from: ["SUBMITTED"] },
}

export function canApplyEvent(event: SubjectEvent, from: VerificationState): boolean {
  const rule = EVENT_RULES[event]
  return rule.from.includes(from) && canTransitionLane(from, rule.to)
}

export function targetStateFor(event: SubjectEvent): VerificationState {
  return EVENT_RULES[event].to
}

export function assertLane(value: string): asserts value is VerificationLane {
  if (!isVerificationLane(value)) {
    throw new Error(`unknown verification lane ${value}`)
  }
}

/** Exposed for the drift test against the database function. */
export function laneTransitionPairs(): readonly (readonly [
  VerificationState,
  VerificationState,
])[] {
  const pairs: [VerificationState, VerificationState][] = []
  for (const [from, targets] of Object.entries(CASE_TRANSITIONS)) {
    for (const to of targets) pairs.push([from as VerificationState, to])
  }
  return pairs
}
