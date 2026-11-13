import {
  ACTIVITY_ACTIVATION_STATES,
  ACTIVITY_IDS,
  CAPABILITY_IDS,
  ENVIRONMENT_IDS,
  PORTAL_IDS,
  activityIdSchema,
  apiErrorBodySchema,
} from "@hivorr/shared"
import { z } from "zod"

/**
 * The HTTP contract, expressed once in zod.
 *
 * Controllers validate with these schemas and the OpenAPI generator converts
 * them to JSON Schema. There is no second hand-written contract.
 *
 * Requests are strict: unknown fields are rejected (SEC-23). Responses are
 * open: an added response field is not a breaking change for a client.
 */

export const portalSchema = z.enum(PORTAL_IDS)
export const environmentSchema = z.enum(ENVIRONMENT_IDS)
export const deploymentEnvironmentSchema = z.enum([
  "development",
  "test",
  "staging",
  "production",
])
export const capabilitySchema = z.enum(CAPABILITY_IDS)

export const errorResponse = apiErrorBodySchema

// --- Requests ---------------------------------------------------------------

export const registerRequest = z.strictObject({
  email: z.string().min(3).max(254),
  password: z.string().min(12).max(128),
  displayName: z.string().min(1).max(80).optional(),
})

export const signInRequest = z.strictObject({
  email: z.string().min(3).max(254),
  password: z.string().min(1).max(128),
})

export const mfaVerifyRequest = z.strictObject({
  challengeToken: z.string().min(20).max(200),
  code: z.string().min(6).max(20),
})

export const totpConfirmRequest = z.strictObject({
  factorId: z.string().min(1).max(64),
  code: z.string().min(6).max(20),
})

export const codeRequest = z.strictObject({
  code: z.string().min(6).max(20),
})

export const passwordResetRequest = z.strictObject({
  email: z.string().min(3).max(254),
})

export const passwordResetCompleteRequest = z.strictObject({
  token: z.string().min(20).max(200),
  password: z.string().min(12).max(128),
})

export const emailVerificationCompleteRequest = z.strictObject({
  token: z.string().min(20).max(200),
})

export const GRANT_TYPE_VALUES = [
  "admin",
  "staff",
  "partner",
  "platform_engineering",
] as const

export const createGrantRequest = z.strictObject({
  email: z.string().min(3).max(254),
  grantType: z.enum(GRANT_TYPE_VALUES),
  scope: z.string().min(1).max(80),
  departmentKey: z.string().min(1).max(64).optional(),
  reason: z.string().min(3).max(500).optional(),
  expiresAt: z
    .string()
    .min(1)
    .max(40)
    .refine((value) => !Number.isNaN(Date.parse(value)), "invalid date")
    .optional(),
})

export const setGrantDepartmentRequest = z.strictObject({
  departmentKey: z.string().min(1).max(64),
  reason: z.string().min(3).max(500).optional(),
})

export const revokeGrantRequest = z.strictObject({
  reason: z.string().min(3).max(500).optional(),
})

// --- Responses --------------------------------------------------------------

export const registrationResponse = z.object({
  accountId: z.string(),
  userId: z.string(),
  email: z.string(),
})

export const sessionResponse = z.object({
  sessionId: z.string(),
  accountId: z.string(),
  userId: z.string(),
  email: z.string(),
  audience: portalSchema,
  environment: environmentSchema,
  expiresAt: z.string(),
  idleExpiresAt: z.string(),
})

export const sessionActivitySchema = z.object({
  id: z.enum(ACTIVITY_IDS),
  state: z.enum(ACTIVITY_ACTIVATION_STATES),
})

export const persistedActivationStateSchema = z.enum([
  "INACTIVE",
  ...ACTIVITY_ACTIVATION_STATES,
])

export const activityViewSchema = z.object({
  id: activityIdSchema,
  state: persistedActivationStateSchema,
})

export const activityListResponse = z.array(activityViewSchema)

export const auditEntrySchema = z.object({
  id: z.string(),
  occurredAt: z.string(),
  actorType: z.string(),
  actorId: z.string().nullable(),
  actorAudience: z.string().nullable(),
  environment: z.string(),
  action: z.string(),
  targetType: z.string().nullable(),
  targetId: z.string().nullable(),
  beforeSummary: z.record(z.string(), z.unknown()).nullable(),
  afterSummary: z.record(z.string(), z.unknown()).nullable(),
  correlationId: z.string().nullable(),
  sessionId: z.string().nullable().optional(),
  reason: z.string().nullable().optional(),
  approvalReference: z.string().nullable().optional(),
  actorDisplayName: z.string().nullable().optional(),
  actorEmail: z.string().nullable().optional(),
  actorRoleKeys: z.array(z.string()).optional(),
  actorRoleScopes: z
    .array(
      z.object({
        roleKey: z.string(),
        scopeType: z.string().nullable().optional(),
        scopeId: z.string().nullable().optional(),
      }),
    )
    .optional(),
  capability: z.string().nullable().optional(),
})

export const auditEntryListResponse = z.array(auditEntrySchema)

export const currentSessionResponse = sessionResponse.extend({
  account: z.object({
    id: z.string(),
    email: z.string(),
    displayName: z.string().nullable(),
    status: z.string(),
  }),
  activities: z.array(sessionActivitySchema),
  capabilities: z.array(capabilitySchema),
})

export const mfaChallengeResponse = z.object({
  mfaRequired: z.literal(true),
  challengeToken: z.string(),
  expiresAt: z.string(),
})

export const signInResponse = z.union([sessionResponse, mfaChallengeResponse])

export const mfaEnrollmentResponse = z.object({
  factorId: z.string(),
  secret: z.string(),
  otpauthUri: z.string(),
})

export const recoveryCodesResponse = z.object({
  recoveryCodes: z.array(z.string()),
})

export const sessionSummaryResponse = z.object({
  sessionId: z.string(),
  current: z.boolean(),
  audience: portalSchema,
  environment: environmentSchema,
  deviceName: z.string().nullable(),
  createdAt: z.string(),
  lastSeenAt: z.string(),
  idleExpiresAt: z.string(),
  expiresAt: z.string(),
  mfaSatisfied: z.boolean(),
})

export const sessionListResponse = z.array(sessionSummaryResponse)

export const revokedSessionsResponse = z.object({
  revoked: z.number().int(),
})

export const grantViewResponse = z.object({
  id: z.string(),
  userId: z.string(),
  email: z.string().nullable(),
  userName: z.string().nullable().optional(),
  grantType: z.string(),
  scope: z.string(),
  environment: environmentSchema,
  grantedBy: z.string().nullable(),
  expiresAt: z.string().nullable(),
  revokedAt: z.string().nullable(),
  createdAt: z.string(),
  departmentKey: z.string().nullable().optional(),
  departmentName: z.string().nullable().optional(),
})

export const grantListResponse = z.array(grantViewResponse)

export const departmentViewResponse = z.object({
  key: z.string(),
  name: z.string(),
})

export const departmentListResponse = z.array(departmentViewResponse)

export const userSummaryResponse = z.object({
  id: z.string(),
  accountId: z.string(),
  email: z.string(),
  displayName: z.string().nullable(),
  status: z.string(),
  emailVerified: z.boolean(),
  confirmedFactors: z.number().int(),
  createdAt: z.string(),
})

export const userListResponse = z.array(userSummaryResponse)

export const staffViewResponse = z.object({
  id: z.string(),
  userId: z.string(),
  email: z.string(),
  displayName: z.string().nullable(),
  jobTitle: z.string().nullable(),
  departmentKey: z.string().nullable(),
  departmentName: z.string().nullable(),
  engagementStatus: z.string(),
  startedOn: z.string().nullable(),
  endedOn: z.string().nullable(),
  confirmedFactors: z.number().int(),
  createdAt: z.string(),
})

export const staffListResponse = z.array(staffViewResponse)

export const createStaffInviteRequest = z.strictObject({
  /** Official company address that becomes the account. */
  email: z.string().min(3).max(254),
  /** Personal address the invitation is delivered to. Defaults to `email`. */
  deliveryEmail: z.string().min(3).max(254).optional(),
  departmentKey: z.string().min(1).max(64).optional(),
  jobTitle: z.string().max(120).optional(),
  reason: z.string().min(5).max(500),
})

export const createStaffInviteResponse = z.object({
  id: z.string(),
  email: z.string(),
  deliveryEmail: z.string(),
  departmentKey: z.string().nullable(),
  expiresAt: z.string(),
  token: z.string(),
  emailSent: z.boolean().optional(),
})

export const staffReasonRequest = z.strictObject({
  reason: z.string().min(5).max(500),
})

export const staffStatusResponse = z.object({
  userId: z.string(),
  engagementStatus: z.string(),
  sessionsRevoked: z.number().int(),
  grantsRevoked: z.number().int(),
})

export const setStaffDepartmentRequest = z.strictObject({
  departmentKey: z.string().min(1).max(64),
  reason: z.string().min(5).max(500),
})

export const setStaffDepartmentResponse = z.object({
  userId: z.string(),
  departmentKey: z.string().nullable(),
})

export const attachStaffProfileRequest = z.strictObject({
  email: z.string().min(3).max(254),
  departmentKey: z.string().min(1).max(64).optional(),
  jobTitle: z.string().max(120).optional(),
  reason: z.string().min(5).max(500),
})

export const attachStaffProfileResponse = z.object({
  userId: z.string(),
  staffProfileId: z.string(),
  email: z.string(),
  departmentKey: z.string().nullable(),
})

export const acceptStaffInviteRequest = z.strictObject({
  token: z.string().min(20).max(200),
  password: z.string().min(12).max(128),
  displayName: z.string().min(1).max(80).optional(),
})

export const acceptStaffInviteResponse = z.object({
  email: z.string(),
})

/** Why the invitation page can show the official address before registration. */
export const staffInviteDetailsResponse = z.object({
  email: z.string(),
  jobTitle: z.string().nullable(),
  departmentKey: z.string().nullable(),
  expiresAt: z.string(),
})

export const ownGrantsResponse = z.object({
  grants: grantListResponse,
  capabilities: z.array(capabilitySchema),
})

export const controlAuthorityResponse = z.object({
  grants: grantListResponse,
  roles: z.array(z.string()),
  permissions: z.array(z.string()),
  deniedPermissions: z.array(z.string()),
  capabilities: z.array(capabilitySchema),
})

export const healthResponse = z.object({
  status: z.literal("ok"),
  service: z.literal("hivorr-api"),
  version: z.literal("v1"),
  environment: deploymentEnvironmentSchema,
  releaseSha: z.string().nullable(),
  releaseDigest: z.string().nullable(),
  time: z.string(),
})

export const readinessResponse = z.object({
  status: z.literal("not_ready"),
  service: z.literal("hivorr-api"),
  checks: z.object({
    configuration: z.literal("ok"),
    database: z.literal("not_implemented"),
  }),
})
