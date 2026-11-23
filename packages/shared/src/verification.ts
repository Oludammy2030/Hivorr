import { z } from "zod"

/**
 * Verification and KYC vocabulary.
 *
 * The six lanes are independent. A lane state is not an account status and one
 * lane never implies another (`matrix` §7). The authoritative transition table
 * and persistence live in `profile`; this module owns the shared identifiers and
 * the transport shapes.
 */
export const VERIFICATION_LANES = [
  "identity",
  "kyc",
  "trade",
  "seller",
  "logistics",
  "business",
] as const

export type VerificationLane = typeof VERIFICATION_LANES[number]

export const VERIFICATION_STATES = [
  "NOT_STARTED",
  "DRAFT",
  "SUBMITTED",
  "UNDER_REVIEW",
  "APPROVED",
  "REJECTED",
  "EXPIRED",
] as const

export type VerificationState = typeof VERIFICATION_STATES[number]

/**
 * CBN 3-tier model, decided 23 November 2026. `tier_0` is unverified and cannot
 * move money; `tier_1` is CBN Level 1, `tier_2` is Level 2 and `tier_3` is
 * Level 3. Deposits are not CBN-capped because Hivorr is not a bank; the limits
 * are withdrawal limits.
 */
export const KYC_TIERS = ["tier_0", "tier_1", "tier_2", "tier_3"] as const

export type KycTier = typeof KYC_TIERS[number]

/** Tiers that may perform a financial action. `tier_0` is always denied. */
export const FINANCIALLY_ELIGIBLE_KYC_TIERS = [
  "tier_1",
  "tier_2",
  "tier_3",
] as const

export type FinanciallyEligibleKycTier = typeof FINANCIALLY_ELIGIBLE_KYC_TIERS[number]

export const VERIFICATION_DECISIONS = ["APPROVED", "REJECTED"] as const

export type VerificationDecision = typeof VERIFICATION_DECISIONS[number]

export const EVIDENCE_SCAN_STATES = [
  "PENDING",
  "CLEAN",
  "INFECTED",
  "FAILED",
] as const

export type EvidenceScanState = typeof EVIDENCE_SCAN_STATES[number]

export const verificationLaneSchema = z.enum(VERIFICATION_LANES)
export const verificationStateSchema = z.enum(VERIFICATION_STATES)
export const kycTierSchema = z.enum(KYC_TIERS)
export const verificationDecisionSchema = z.enum(VERIFICATION_DECISIONS)
export const evidenceScanStateSchema = z.enum(EVIDENCE_SCAN_STATES)

/**
 * A private-object reference. The database holds the reference, never the
 * document. `objectKey` is never a public URL.
 */
export const evidenceReferenceSchema = z.strictObject({
  id: z.string().uuid(),
  objectKey: z.string().min(1).max(512),
  contentType: z.string().min(1).max(120),
  sizeBytes: z
    .number()
    .int()
    .positive()
    .max(25 * 1024 * 1024),
  sha256: z.string().regex(/^[a-f0-9]{64}$/),
  scanState: evidenceScanStateSchema,
  uploadedAt: z.string().datetime(),
})

export type EvidenceReference = z.infer<typeof evidenceReferenceSchema>

export const verificationSubmissionSchema = z.strictObject({
  lane: verificationLaneSchema,
  state: verificationStateSchema,
  evidence: z.array(evidenceReferenceSchema).max(20),
  reasonCode: z.string().min(1).max(64).optional(),
  submittedAt: z.string().datetime().optional(),
})

export type VerificationSubmission = z.infer<typeof verificationSubmissionSchema>

export const verificationDecisionRecordSchema = z.strictObject({
  lane: verificationLaneSchema,
  decision: verificationDecisionSchema,
  reasonCode: z.string().min(1).max(64),
  reason: z.string().min(5).max(1000),
  evidenceIds: z.array(z.string().uuid()).max(20),
  decidedAt: z.string().datetime(),
})

export type VerificationDecisionRecord = z.infer<typeof verificationDecisionRecordSchema>

export const laneStatusSchema = z.strictObject({
  lane: verificationLaneSchema,
  state: verificationStateSchema,
  reasonCode: z.string().max(64).nullable(),
  hasActiveSubmission: z.boolean(),
  updatedAt: z.string().datetime(),
})

export type LaneStatus = z.infer<typeof laneStatusSchema>

export const kycStatusSchema = z.strictObject({
  tier: kycTierSchema,
  updatedAt: z.string().datetime(),
})

export type KycStatus = z.infer<typeof kycStatusSchema>

export function isVerificationLane(value: string): value is VerificationLane {
  return (VERIFICATION_LANES as readonly string[]).includes(value)
}

export function isVerificationState(value: string): value is VerificationState {
  return (VERIFICATION_STATES as readonly string[]).includes(value)
}

export function isKycTier(value: string): value is KycTier {
  return (KYC_TIERS as readonly string[]).includes(value)
}
