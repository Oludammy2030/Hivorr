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

export const ROLE_SCOPE_VALUES = [
  "platform",
  "department",
  "organisation",
] as const

export const assignRoleRequest = z.strictObject({
  email: z.string().min(3).max(254),
  roleKey: z.string().min(1).max(64),
  scopeType: z.enum(ROLE_SCOPE_VALUES),
  scopeId: z.string().uuid().optional(),
  expiresAt: z
    .string()
    .min(1)
    .max(40)
    .refine((value) => !Number.isNaN(Date.parse(value)), "invalid date")
    .optional(),
  reason: z.string().min(3).max(500).optional(),
})

export const roleReasonRequest = z.strictObject({
  reason: z.string().min(3).max(500).optional(),
})

export const createAccessDenialRequest = z.strictObject({
  email: z.string().min(3).max(254),
  permissionKey: z.string().min(1).max(128),
  scopeType: z.enum(ROLE_SCOPE_VALUES),
  scopeId: z.string().uuid().optional(),
  expiresAt: z
    .string()
    .min(1)
    .max(40)
    .refine((value) => !Number.isNaN(Date.parse(value)), "invalid date")
    .optional(),
  reason: z.string().min(3).max(500).optional(),
})

export const accountReasonRequest = z.strictObject({
  reason: z.string().min(3).max(500).optional(),
})

export const addAccountNoteRequest = z.strictObject({
  body: z.string().min(3).max(2000),
})

export const createApprovalRequest = z.strictObject({
  actionType: z.string().min(3).max(64),
  targetType: z.string().min(2).max(32),
  targetId: z.string().min(1).max(64),
  reason: z.string().min(3).max(500).optional(),
})

export const decideApprovalRequest = z.strictObject({
  decision: z.enum(["approve", "reject"]),
  reason: z.string().min(3).max(500).optional(),
})

export const caseDecisionRequest = z.strictObject({
  outcome: z.string().min(3).max(500),
  reason: z.string().min(3).max(500).optional(),
})

export const createPartnerRequest = z.strictObject({
  legalName: z.string().min(2).max(200),
  tradingName: z.string().min(1).max(200).optional(),
  category: z.string().min(1).max(80).optional(),
  country: z.string().min(1).max(80).optional(),
  reason: z.string().min(3).max(500).optional(),
})

export const partnerStatusRequest = z.strictObject({
  status: z.enum(["active", "suspended", "terminated"]),
  reason: z.string().min(3).max(500).optional(),
})

export const addPartnerRepresentativeRequest = z.strictObject({
  email: z.string().min(3).max(254),
  role: z.enum(["owner", "admin", "member", "viewer"]),
  reason: z.string().min(3).max(500).optional(),
})

export const CASE_TYPE_VALUES = [
  "support",
  "complaint",
  "dispute",
  "investigation",
  "incident",
  "verification_review",
  "financial_exception",
  "security_incident",
  "staff_conduct",
  "partner_conduct",
] as const

export const createCaseRequest = z.strictObject({
  caseType: z.enum(CASE_TYPE_VALUES),
  title: z.string().min(3).max(200),
  description: z.string().max(4000).optional(),
  priority: z.enum(["low", "normal", "high", "urgent"]),
  severity: z.enum(["low", "medium", "high", "critical"]),
  queueKey: z.string().min(1).max(64).optional(),
  reason: z.string().min(3).max(500).optional(),
})

export const caseNoteRequest = z.strictObject({
  summary: z.string().min(3).max(2000),
})

export const assignCaseRequest = z.strictObject({
  email: z.string().min(3).max(254).optional(),
  queueKey: z.string().min(1).max(64).optional(),
})

export const caseStatusRequest = z.strictObject({
  status: z.enum([
    "TRIAGED",
    "OPEN",
    "INVESTIGATING",
    "PENDING_INFORMATION",
    "ESCALATED",
    "REVIEW",
    "DECIDED",
    "ACTION_PENDING",
    "CLOSED",
    "REOPENED",
    "ARCHIVED",
  ]),
  reason: z.string().min(3).max(500).optional(),
})

export const addEvidenceRequest = z.strictObject({
  storageKey: z.string().min(3).max(512),
  fileName: z.string().min(1).max(255),
  mimeType: z.string().min(1).max(128).optional(),
  sizeBytes: z.number().int().min(0).optional(),
  sha256: z
    .string()
    .regex(/^[0-9a-f]{64}$/, "expected a lowercase SHA-256 hex digest")
    .optional(),
  classification: z.enum(["standard", "sensitive", "critical"]).optional(),
  reason: z.string().min(3).max(500).optional(),
})

export const evidenceAccessRequest = z.strictObject({
  purpose: z.string().min(1).max(200).optional(),
})

export const supersedeEvidenceRequest = z.strictObject({
  replacementId: z.string().min(1).max(64),
  reason: z.string().min(3).max(500).optional(),
})

export const verificationDecisionRequest = z.strictObject({
  decision: z.enum(["approve", "reject", "request_information"]),
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

export const roleViewResponse = z.object({
  key: z.string(),
  name: z.string(),
  description: z.string().nullable().optional(),
  system: z.boolean(),
  permissions: z.array(z.string()).optional(),
  activeAssignments: z.number().int().optional(),
})

export const roleListResponse = z.array(roleViewResponse)

export const accessDenialViewResponse = z.object({
  id: z.string(),
  userId: z.string(),
  email: z.string(),
  displayName: z.string().nullable().optional(),
  permissionKey: z.string(),
  scopeType: z.string().nullable().optional(),
  scopeId: z.string().nullable().optional(),
  reason: z.string(),
  expiresAt: z.string().nullable().optional(),
  createdAt: z.string(),
  createdBy: z.string().nullable().optional(),
  revokedAt: z.string().nullable().optional(),
  revokedReason: z.string().nullable().optional(),
})

export const accessDenialListResponse = z.array(accessDenialViewResponse)

export const roleAssignmentViewResponse = z.object({
  id: z.string(),
  userId: z.string(),
  email: z.string(),
  displayName: z.string().nullable().optional(),
  roleKey: z.string(),
  roleName: z.string(),
  scopeType: z.string(),
  scopeId: z.string().nullable().optional(),
  expiresAt: z.string().nullable().optional(),
  revokedAt: z.string().nullable().optional(),
  createdAt: z.string(),
  grantedBy: z.string().nullable().optional(),
  reason: z.string().nullable().optional(),
})

export const roleAssignmentListResponse = z.array(roleAssignmentViewResponse)

export const roleScopeTargetResponse = z.object({
  id: z.string(),
  name: z.string(),
})

export const roleScopeTargetListResponse = z.array(roleScopeTargetResponse)

export const accountActionResponse = z.object({
  userId: z.string(),
  status: z.string(),
  sessionsRevoked: z.number().int(),
  grantsRevoked: z.number().int(),
  rolesRevoked: z.number().int(),
})

export const accountNoteViewResponse = z.object({
  id: z.string(),
  body: z.string(),
  authorName: z.string().nullable().optional(),
  authorEmail: z.string().nullable().optional(),
  createdAt: z.string(),
})

export const accountNoteListResponse = z.array(accountNoteViewResponse)

export const accountTimelineEntryResponse = z.object({
  occurredAt: z.string(),
  action: z.string(),
  reason: z.string().nullable().optional(),
  actorName: z.string().nullable().optional(),
  actorEmail: z.string().nullable().optional(),
})

export const accountTimelineListResponse = z.array(accountTimelineEntryResponse)

export const approvalRequestViewResponse = z.object({
  id: z.string(),
  reference: z.string(),
  actionType: z.string(),
  targetType: z.string(),
  targetId: z.string(),
  status: z.string(),
  reason: z.string(),
  requesterUserId: z.string(),
  requesterName: z.string().nullable().optional(),
  requesterEmail: z.string().nullable().optional(),
  createdAt: z.string(),
  decidedAt: z.string().nullable().optional(),
})

export const approvalRequestListResponse = z.array(approvalRequestViewResponse)

export const partnerOrganisationResponse = z.object({
  id: z.string(),
  legalName: z.string(),
  tradingName: z.string().nullable().optional(),
  category: z.string().nullable().optional(),
  country: z.string().nullable().optional(),
  status: z.string(),
  representatives: z.number().int().optional(),
  agreements: z.number().int().optional(),
  createdAt: z.string(),
})

export const partnerOrganisationListResponse = z.array(
  partnerOrganisationResponse,
)

export const partnerRepresentativeResponse = z.object({
  id: z.string(),
  userId: z.string(),
  email: z.string(),
  displayName: z.string().nullable().optional(),
  role: z.string(),
  effectiveFrom: z.string(),
  effectiveTo: z.string().nullable().optional(),
})

export const partnerRepresentativeListResponse = z.array(
  partnerRepresentativeResponse,
)

export const ownPartnerOrganisationResponse = z.object({
  organisationId: z.string(),
  legalName: z.string(),
  tradingName: z.string().nullable().optional(),
  status: z.string(),
  role: z.string(),
  effectiveFrom: z.string(),
})

export const ownPartnerOrganisationListResponse = z.array(
  ownPartnerOrganisationResponse,
)

export const caseViewResponse = z.object({
  id: z.string(),
  reference: z.string(),
  caseType: z.string(),
  title: z.string(),
  description: z.string().nullable().optional(),
  priority: z.string(),
  severity: z.string(),
  status: z.string(),
  queueKey: z.string().nullable().optional(),
  assigneeId: z.string().nullable().optional(),
  assigneeName: z.string().nullable().optional(),
  assigneeEmail: z.string().nullable().optional(),
  departmentName: z.string().nullable().optional(),
  createdAt: z.string(),
  updatedAt: z.string(),
  closedAt: z.string().nullable().optional(),
})

export const caseListResponse = z.array(caseViewResponse)

export const caseEventViewResponse = z.object({
  id: z.string(),
  eventType: z.string(),
  summary: z.string(),
  actorName: z.string().nullable().optional(),
  actorEmail: z.string().nullable().optional(),
  occurredAt: z.string(),
})

export const caseEventListResponse = z.array(caseEventViewResponse)

export const evidenceViewResponse = z.object({
  id: z.string(),
  fileName: z.string(),
  mimeType: z.string().nullable().optional(),
  sizeBytes: z.number().int().nullable().optional(),
  sha256: z.string().nullable().optional(),
  classification: z.string(),
  status: z.string(),
  supersedesId: z.string().nullable().optional(),
  uploadedByName: z.string().nullable().optional(),
  uploadedByEmail: z.string().nullable().optional(),
  uploadedAt: z.string(),
})

export const evidenceListResponse = z.array(evidenceViewResponse)

export const evidenceAccessResponse = z.object({
  recorded: z.boolean(),
})

export const verificationReviewResponse = z.object({
  caseId: z.string(),
  reference: z.string(),
  title: z.string(),
  lane: z.string(),
  reviewStatus: z.string(),
  caseStatus: z.string(),
  priority: z.string(),
  subjectType: z.string().nullable().optional(),
  subjectId: z.string().nullable().optional(),
  assigneeEmail: z.string().nullable().optional(),
  evidenceCount: z.number().int().optional(),
  createdAt: z.string(),
})

export const verificationReviewListResponse = z.array(
  verificationReviewResponse,
)

export const assignableStaffResponse = z.object({
  userId: z.string(),
  email: z.string(),
  displayName: z.string().nullable().optional(),
  departmentKey: z.string().nullable().optional(),
  departmentName: z.string().nullable().optional(),
})

export const assignableStaffListResponse = z.array(assignableStaffResponse)

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
  /** Always returned by this API; optional so an added field is not a break. */
  deliveryEmail: z.string().optional(),
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
  permissionGrantsRevoked: z.number().int(),
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
