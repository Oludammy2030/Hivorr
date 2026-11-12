import type { PortalId } from "@hivorr/shared"
import type { z } from "zod"

import {
  activityListResponse,
  activityViewSchema,
  auditEntryListResponse,
  codeRequest,
  createGrantRequest,
  controlAuthorityResponse,
  emailVerificationCompleteRequest,
  grantListResponse,
  grantViewResponse,
  healthResponse,
  mfaChallengeResponse,
  mfaEnrollmentResponse,
  mfaVerifyRequest,
  ownGrantsResponse,
  passwordResetCompleteRequest,
  passwordResetRequest,
  readinessResponse,
  recoveryCodesResponse,
  registerRequest,
  registrationResponse,
  revokeGrantRequest,
  revokedSessionsResponse,
  sessionListResponse,
  sessionResponse,
  currentSessionResponse,
  signInRequest,
  totpConfirmRequest,
  userListResponse,
} from "../contracts/schemas"

export type ApiAudience = PortalId | "public"
export type ApiMethod = "get" | "post" | "delete"

export interface ApiSuccessResponse {
  readonly status: number
  readonly description: string
  readonly schema?: z.ZodType
}

export interface ApiOperation {
  readonly id: string
  readonly method: ApiMethod
  readonly path: string
  readonly summary: string
  readonly tag: "health" | "auth" | "grants" | "activities" | "audit" | "users"
  readonly audience: readonly ApiAudience[]
  readonly request?: {
    readonly schema: z.ZodType
    readonly description: string
  }
  readonly success: readonly ApiSuccessResponse[]
  /** Non-2xx statuses the client should treat as a normal response. */
  readonly expected?: readonly number[]
  readonly pathParams?: readonly string[]
}

const ALL_PORTALS: readonly ApiAudience[] = [
  "app",
  "control",
  "staff",
  "partner",
]

/**
 * Every implemented API endpoint. `tests/openapi-route-coverage.test.ts`
 * compares this list with the Nest controller metadata, so an endpoint cannot
 * exist without a contract or a contract without an endpoint.
 */
export const API_OPERATIONS: readonly ApiOperation[] = [
  {
    id: "health",
    method: "get",
    path: "/v1/health",
    summary: "Liveness probe",
    tag: "health",
    audience: ["public"],
    success: [
      {
        status: 200,
        description: "The API process is alive",
        schema: healthResponse,
      },
    ],
  },
  {
    id: "healthLive",
    method: "get",
    path: "/v1/health/live",
    summary: "Liveness probe alias",
    tag: "health",
    audience: ["public"],
    success: [
      {
        status: 200,
        description: "The API process is alive",
        schema: healthResponse,
      },
    ],
  },
  {
    id: "healthReady",
    method: "get",
    path: "/v1/health/ready",
    summary: "Readiness probe",
    tag: "health",
    audience: ["public"],
    success: [
      {
        status: 503,
        description:
          "The API is not ready; the database-backed check is not implemented yet",
        schema: readinessResponse,
      },
    ],
    expected: [503],
  },
  {
    id: "register",
    method: "post",
    path: "/v1/auth/register",
    summary: "Register an account and its owner membership",
    tag: "auth",
    audience: ALL_PORTALS,
    request: { schema: registerRequest, description: "Account details" },
    success: [
      {
        status: 201,
        description: "The account was created",
        schema: registrationResponse,
      },
    ],
  },
  {
    id: "requestPasswordReset",
    method: "post",
    path: "/v1/auth/password-reset/request",
    summary: "Request a password reset token",
    tag: "auth",
    audience: ALL_PORTALS,
    request: {
      schema: passwordResetRequest,
      description: "The account email",
    },
    success: [
      {
        status: 202,
        description: "Accepted; a message is sent only when the account exists",
      },
    ],
  },
  {
    id: "completePasswordReset",
    method: "post",
    path: "/v1/auth/password-reset/complete",
    summary: "Complete a password reset and revoke every session",
    tag: "auth",
    audience: ALL_PORTALS,
    request: {
      schema: passwordResetCompleteRequest,
      description: "The single-use token and the new password",
    },
    success: [
      {
        status: 204,
        description: "The password changed and sessions were revoked",
      },
    ],
  },
  {
    id: "requestEmailVerification",
    method: "post",
    path: "/v1/auth/email-verification/request",
    summary: "Issue an email verification token for the current user",
    tag: "auth",
    audience: ALL_PORTALS,
    success: [
      {
        status: 202,
        description: "The token was issued and captured for delivery",
      },
    ],
  },
  {
    id: "completeEmailVerification",
    method: "post",
    path: "/v1/auth/email-verification/complete",
    summary: "Verify the email with a single-use token",
    tag: "auth",
    audience: ALL_PORTALS,
    request: {
      schema: emailVerificationCompleteRequest,
      description: "The single-use verification token",
    },
    success: [{ status: 204, description: "The email address is verified" }],
  },
  {
    id: "signIn",
    method: "post",
    path: "/v1/auth/sign-in",
    summary: "Sign in; returns a session or an MFA challenge",
    tag: "auth",
    audience: ALL_PORTALS,
    request: { schema: signInRequest, description: "Credentials" },
    success: [
      {
        status: 200,
        description: "A session was issued in host-only cookies",
        schema: sessionResponse,
      },
      {
        status: 202,
        description: "A second factor is required",
        schema: mfaChallengeResponse,
      },
    ],
  },
  {
    id: "verifyMfa",
    method: "post",
    path: "/v1/auth/mfa/verify",
    summary: "Complete an MFA challenge",
    tag: "auth",
    audience: ALL_PORTALS,
    request: { schema: mfaVerifyRequest, description: "Challenge and code" },
    success: [
      {
        status: 200,
        description: "The session is now MFA-satisfied",
        schema: sessionResponse,
      },
    ],
  },
  {
    id: "enrollTotp",
    method: "post",
    path: "/v1/auth/mfa/totp/enroll",
    summary: "Begin TOTP enrolment",
    tag: "auth",
    audience: ["app"],
    success: [
      {
        status: 201,
        description: "A TOTP secret and provisioning URI",
        schema: mfaEnrollmentResponse,
      },
    ],
  },
  {
    id: "confirmTotp",
    method: "post",
    path: "/v1/auth/mfa/totp/confirm",
    summary: "Confirm TOTP enrolment and receive recovery codes",
    tag: "auth",
    audience: ["app"],
    request: { schema: totpConfirmRequest, description: "Factor and code" },
    success: [
      {
        status: 200,
        description: "Recovery codes, shown once",
        schema: recoveryCodesResponse,
      },
    ],
  },
  {
    id: "stepUp",
    method: "post",
    path: "/v1/auth/mfa/step-up",
    summary: "Raise an existing session to MFA-satisfied",
    tag: "auth",
    audience: ALL_PORTALS,
    request: { schema: codeRequest, description: "TOTP or recovery code" },
    success: [
      {
        status: 200,
        description: "The session is now MFA-satisfied",
        schema: sessionResponse,
      },
    ],
  },
  {
    id: "refresh",
    method: "post",
    path: "/v1/auth/refresh",
    summary: "Rotate the refresh token and issue a new access token",
    tag: "auth",
    audience: ALL_PORTALS,
    success: [
      {
        status: 200,
        description: "A rotated session",
        schema: sessionResponse,
      },
    ],
  },
  {
    id: "session",
    method: "get",
    path: "/v1/session",
    summary: "Read the current session, account, activities and capabilities",
    tag: "auth",
    audience: ALL_PORTALS,
    success: [
      {
        status: 200,
        description:
          "The current session with account, activities and presentation-only capabilities",
        schema: currentSessionResponse,
      },
    ],
  },
  {
    id: "listSessions",
    method: "get",
    path: "/v1/auth/sessions",
    summary: "List the account's sessions",
    tag: "auth",
    audience: ALL_PORTALS,
    success: [
      {
        status: 200,
        description: "Every session for the account",
        schema: sessionListResponse,
      },
    ],
  },
  {
    id: "revokeSession",
    method: "delete",
    path: "/v1/auth/sessions/{id}",
    summary: "Revoke one session",
    tag: "auth",
    audience: ALL_PORTALS,
    pathParams: ["id"],
    success: [{ status: 204, description: "The session was revoked" }],
  },
  {
    id: "revokeOtherSessions",
    method: "delete",
    path: "/v1/auth/sessions",
    summary: "Revoke every other session",
    tag: "auth",
    audience: ALL_PORTALS,
    success: [
      {
        status: 200,
        description: "How many sessions were revoked",
        schema: revokedSessionsResponse,
      },
    ],
  },
  {
    id: "signOut",
    method: "post",
    path: "/v1/auth/sign-out",
    summary: "Sign out and clear the session cookies",
    tag: "auth",
    audience: ALL_PORTALS,
    success: [{ status: 204, description: "The session was ended" }],
  },
  {
    id: "listActivities",
    method: "get",
    path: "/v1/activities",
    summary: "List the six activities and their activation states",
    tag: "activities",
    audience: ["app"],
    success: [
      {
        status: 200,
        description: "All six activities, with INACTIVE when not activated",
        schema: activityListResponse,
      },
    ],
  },
  {
    id: "activateActivity",
    method: "post",
    path: "/v1/activities/{id}/activate",
    summary: "Activate one activity for the current account",
    tag: "activities",
    audience: ["app"],
    pathParams: ["id"],
    success: [
      {
        status: 200,
        description: "The activity is active",
        schema: activityViewSchema,
      },
    ],
  },
  {
    id: "deactivateActivity",
    method: "post",
    path: "/v1/activities/{id}/deactivate",
    summary: "Deactivate one activity, retaining its history",
    tag: "activities",
    audience: ["app"],
    pathParams: ["id"],
    success: [
      {
        status: 200,
        description: "The activity is inactive; the row is retained",
        schema: activityViewSchema,
      },
    ],
  },
  {
    id: "listAudit",
    method: "get",
    path: "/v1/control/audit",
    summary: "Read recent audit entries",
    tag: "audit",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "A bounded, filtered page of audit entries for a caller holding admin.audit.read; the read is itself audited; the next cursor is returned in x-next-cursor",
        schema: auditEntryListResponse,
      },
    ],
  },
  {
    id: "listUsers",
    method: "get",
    path: "/v1/control/users",
    summary: "List user accounts",
    tag: "users",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "A bounded page of users for a caller holding admin.user.read; supports q, status and cursor filters; the next cursor is returned in x-next-cursor",
        schema: userListResponse,
      },
    ],
  },
  {
    id: "controlAuthority",
    method: "get",
    path: "/v1/control/authority",
    summary: "Read the caller's effective control-portal authority",
    tag: "grants",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "Grants, governance roles, effective permissions and presentation-only capabilities",
        schema: controlAuthorityResponse,
      },
    ],
  },
  {
    id: "ownGrants",
    method: "get",
    path: "/v1/grants",
    summary: "Read the caller's grants and capabilities",
    tag: "grants",
    audience: ALL_PORTALS,
    success: [
      {
        status: 200,
        description: "The caller's grants and presentation-only capabilities",
        schema: ownGrantsResponse,
      },
    ],
  },
  {
    id: "listGrants",
    method: "get",
    path: "/v1/control/grants",
    summary: "List grants in the environment",
    tag: "grants",
    audience: ["control"],
    success: [
      { status: 200, description: "Grant records", schema: grantListResponse },
    ],
  },
  {
    id: "createGrant",
    method: "post",
    path: "/v1/control/grants",
    summary: "Create a grant",
    tag: "grants",
    audience: ["control"],
    request: { schema: createGrantRequest, description: "Grant details" },
    success: [
      {
        status: 201,
        description: "The created grant",
        schema: grantViewResponse,
      },
    ],
  },
  {
    id: "revokeGrant",
    method: "post",
    path: "/v1/control/grants/{id}/revoke",
    summary: "Revoke a grant",
    tag: "grants",
    audience: ["control"],
    pathParams: ["id"],
    request: {
      schema: revokeGrantRequest,
      description: "The reason for the revocation",
    },
    success: [
      {
        status: 200,
        description: "The revoked grant",
        schema: grantViewResponse,
      },
    ],
  },
]
