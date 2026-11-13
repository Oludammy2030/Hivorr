import type { PortalId } from "@hivorr/shared"
import type { z } from "zod"

import {
  accountActionResponse,
  accountNoteListResponse,
  accountNoteViewResponse,
  accountReasonRequest,
  accountTimelineListResponse,
  activityListResponse,
  approvalRequestListResponse,
  approvalRequestViewResponse,
  activityViewSchema,
  assignRoleRequest,
  auditEntryListResponse,
  codeRequest,
  createGrantRequest,
  controlAuthorityResponse,
  createApprovalRequest,
  decideApprovalRequest,
  departmentListResponse,
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
  setGrantDepartmentRequest,
  readinessResponse,
  recoveryCodesResponse,
  registerRequest,
  registrationResponse,
  revokedSessionsResponse,
  sessionListResponse,
  sessionResponse,
  currentSessionResponse,
  acceptStaffInviteRequest,
  addAccountNoteRequest,
  acceptStaffInviteResponse,
  attachStaffProfileRequest,
  attachStaffProfileResponse,
  createStaffInviteRequest,
  createStaffInviteResponse,
  setStaffDepartmentRequest,
  setStaffDepartmentResponse,
  signInRequest,
  assignableStaffListResponse,
  roleAssignmentListResponse,
  roleAssignmentViewResponse,
  roleListResponse,
  roleReasonRequest,
  roleScopeTargetListResponse,
  staffListResponse,
  staffInviteDetailsResponse,
  staffReasonRequest,
  staffStatusResponse,
  totpConfirmRequest,
  userListResponse,
} from "../contracts/schemas"

export type ApiAudience = PortalId | "public"
export type ApiMethod = "get" | "post" | "patch" | "delete"

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
  readonly tag: "health" | "auth" | "grants" | "activities" | "audit" | "users" | "staff" | "roles"
  readonly audience: readonly ApiAudience[]
  readonly request?: {
    readonly schema: z.ZodType
    readonly description: string
  }
  readonly success: readonly ApiSuccessResponse[]
  /** Non-2xx statuses the client should treat as a normal response. */
  readonly expected?: readonly number[]
  readonly pathParams?: readonly string[]
  /** Required query parameters, declared in the published contract. */
  readonly queryParams?: readonly string[]
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
    success: [
      {
        status: 200,
        description: "The revoked grant",
        schema: grantViewResponse,
      },
    ],
  },
  {
    id: "listDepartments",
    method: "get",
    path: "/v1/control/departments",
    summary: "List the departments that own grants",
    tag: "grants",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "Active departments for a caller holding admin.grant.read or admin.grant.manage",
        schema: departmentListResponse,
      },
    ],
  },
  {
    id: "setGrantDepartment",
    method: "patch",
    path: "/v1/control/grants/{id}/department",
    summary: "Record the department that owns a grant",
    tag: "grants",
    audience: ["control"],
    pathParams: ["id"],
    request: {
      schema: setGrantDepartmentRequest,
      description: "Department and reason",
    },
    success: [
      {
        status: 200,
        description: "The grant with its recorded department",
        schema: grantViewResponse,
      },
    ],
  },
  {
    id: "listStaff",
    method: "get",
    path: "/v1/control/staff",
    summary: "List staff records",
    tag: "staff",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "Staff directory for a caller holding admin.user.read; supports q and status filters",
        schema: staffListResponse,
      },
    ],
  },
  {
    id: "createStaffInvite",
    method: "post",
    path: "/v1/control/staff/invites",
    summary: "Invite a staff member",
    tag: "staff",
    audience: ["control"],
    request: {
      schema: createStaffInviteRequest,
      description: "Email, optional department and job title, and a reason",
    },
    success: [
      {
        status: 201,
        description: "The pending invitation and its single-use token",
        schema: createStaffInviteResponse,
      },
    ],
  },
  {
    id: "attachStaffProfile",
    method: "post",
    path: "/v1/control/staff/attach",
    summary: "Attach a staff profile to an existing account",
    tag: "staff",
    audience: ["control"],
    request: {
      schema: attachStaffProfileRequest,
      description:
        "Email of an existing account, optional department and job title, and a reason",
    },
    success: [
      {
        status: 201,
        description: "The created staff profile for the existing account",
        schema: attachStaffProfileResponse,
      },
    ],
  },
  {
    id: "suspendStaff",
    method: "post",
    path: "/v1/control/staff/{userId}/suspend",
    summary: "Suspend a staff member and revoke their sessions",
    tag: "staff",
    audience: ["control"],
    pathParams: ["userId"],
    request: {
      schema: staffReasonRequest,
      description: "Reason",
    },
    success: [
      {
        status: 200,
        description: "The new engagement status and revocation counts",
        schema: staffStatusResponse,
      },
    ],
  },
  {
    id: "reactivateStaff",
    method: "post",
    path: "/v1/control/staff/{userId}/reactivate",
    summary: "Reactivate a staff member",
    tag: "staff",
    audience: ["control"],
    pathParams: ["userId"],
    request: {
      schema: staffReasonRequest,
      description: "Reason",
    },
    success: [
      {
        status: 200,
        description: "The new engagement status",
        schema: staffStatusResponse,
      },
    ],
  },
  {
    id: "offboardStaff",
    method: "post",
    path: "/v1/control/staff/{userId}/offboard",
    summary: "Offboard a staff member and revoke access immediately",
    tag: "staff",
    audience: ["control"],
    pathParams: ["userId"],
    request: {
      schema: staffReasonRequest,
      description: "Reason",
    },
    success: [
      {
        status: 200,
        description:
          "The offboarded status, revoked sessions and revoked grants",
        schema: staffStatusResponse,
      },
    ],
  },
  {
    id: "setStaffDepartment",
    method: "patch",
    path: "/v1/control/staff/{userId}/department",
    summary: "Assign a staff member to a department",
    tag: "staff",
    audience: ["control"],
    pathParams: ["userId"],
    request: {
      schema: setStaffDepartmentRequest,
      description: "Department key and reason",
    },
    success: [
      {
        status: 200,
        description: "The staff member and the new department",
        schema: setStaffDepartmentResponse,
      },
    ],
  },
  {
    id: "staffInviteDetails",
    method: "get",
    path: "/v1/auth/staff-invite",
    summary: "Read a pending staff invitation",
    tag: "staff",
    audience: ["app"],
    queryParams: ["token"],
    success: [
      {
        status: 200,
        description:
          "The official address the invitation reserves, so the page can show it",
        schema: staffInviteDetailsResponse,
      },
    ],
  },
  {
    id: "acceptStaffInvite",
    method: "post",
    path: "/v1/auth/staff-invite/accept",
    summary: "Accept a staff invitation",
    tag: "staff",
    audience: ["app"],
    request: {
      schema: acceptStaffInviteRequest,
      description: "Invitation token, new password and optional display name",
    },
    success: [
      {
        status: 201,
        description: "The account created for the invitation",
        schema: acceptStaffInviteResponse,
      },
    ],
  },
  {
    id: "listRoles",
    method: "get",
    path: "/v1/control/roles",
    summary: "List the governance role catalogue",
    tag: "roles",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "Seeded roles with their permission keys and active assignment count, for a caller holding admin.role.read or admin.role.manage",
        schema: roleListResponse,
      },
    ],
  },
  {
    id: "listRoleAssignments",
    method: "get",
    path: "/v1/control/role-assignments",
    summary: "List role assignments",
    tag: "roles",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "Every role assignment with its holder, scope and lifecycle",
        schema: roleAssignmentListResponse,
      },
    ],
  },
  {
    id: "listRoleScopeTargets",
    method: "get",
    path: "/v1/control/roles/scope-targets",
    summary: "List the targets a role assignment may use",
    tag: "roles",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "Active departments or partner organisations for the requested scope type; pass type=department or type=organisation",
        schema: roleScopeTargetListResponse,
      },
    ],
  },
  {
    id: "listAssignableStaff",
    method: "get",
    path: "/v1/control/roles/assignable-staff",
    summary: "List the staff who may receive a governance role",
    tag: "roles",
    audience: ["control"],
    success: [
      {
        status: 200,
        description:
          "Active staff with an accepted engagement for a caller holding admin.role.manage",
        schema: assignableStaffListResponse,
      },
    ],
  },
  {
    id: "assignRole",
    method: "post",
    path: "/v1/control/role-assignments",
    summary: "Assign a seeded role",
    tag: "roles",
    audience: ["control"],
    request: {
      schema: assignRoleRequest,
      description: "Holder, role, scope, optional expiry and reason",
    },
    success: [
      {
        status: 201,
        description: "The created role assignment",
        schema: roleAssignmentViewResponse,
      },
    ],
  },
  {
    id: "revokeRole",
    method: "post",
    path: "/v1/control/role-assignments/{id}/revoke",
    summary: "Revoke a role assignment",
    tag: "roles",
    audience: ["control"],
    pathParams: ["id"],
    request: {
      schema: roleReasonRequest,
      description: "Reason for the revocation",
    },
    success: [
      {
        status: 200,
        description: "The revoked role assignment",
        schema: roleAssignmentViewResponse,
      },
    ],
  },
  {
    id: "suspendAccount",
    method: "post",
    path: "/v1/control/users/{id}/suspend",
    summary: "Suspend an account and revoke its sessions",
    tag: "users",
    audience: ["control"],
    pathParams: ["id"],
    request: { schema: accountReasonRequest, description: "Reason" },
    success: [
      {
        status: 200,
        description: "The account status and what was revoked",
        schema: accountActionResponse,
      },
    ],
  },
  {
    id: "reactivateAccount",
    method: "post",
    path: "/v1/control/users/{id}/reactivate",
    summary: "Reactivate a suspended account",
    tag: "users",
    audience: ["control"],
    pathParams: ["id"],
    request: { schema: accountReasonRequest, description: "Reason" },
    success: [
      {
        status: 200,
        description: "The account status",
        schema: accountActionResponse,
      },
    ],
  },
  {
    id: "closeAccount",
    method: "post",
    path: "/v1/control/users/{id}/close",
    summary: "Close an account (deprecated: use approvals)",
    tag: "users",
    audience: ["control"],
    pathParams: ["id"],
    request: { schema: accountReasonRequest, description: "Reason" },
    success: [
      {
        status: 200,
        description:
          "Deprecated. Closure now requires an approval request; this route answers 409 APPROVAL_REQUIRED.",
        schema: accountActionResponse,
      },
    ],
    expected: [409],
  },
  {
    id: "revokeUserSessions",
    method: "post",
    path: "/v1/control/users/{id}/revoke-sessions",
    summary: "Revoke every active session for an account",
    tag: "users",
    audience: ["control"],
    pathParams: ["id"],
    request: { schema: accountReasonRequest, description: "Reason" },
    success: [
      {
        status: 200,
        description: "The number of sessions revoked",
        schema: accountActionResponse,
      },
    ],
  },
  {
    id: "listAccountNotes",
    method: "get",
    path: "/v1/control/users/{id}/notes",
    summary: "List the operator notes for an account",
    tag: "users",
    audience: ["control"],
    pathParams: ["id"],
    success: [
      {
        status: 200,
        description: "Notes, newest first",
        schema: accountNoteListResponse,
      },
    ],
  },
  {
    id: "addAccountNote",
    method: "post",
    path: "/v1/control/users/{id}/notes",
    summary: "Add an operator note to an account",
    tag: "users",
    audience: ["control"],
    pathParams: ["id"],
    request: { schema: addAccountNoteRequest, description: "Note body" },
    success: [
      {
        status: 201,
        description: "The created note",
        schema: accountNoteViewResponse,
      },
    ],
  },
  {
    id: "accountTimeline",
    method: "get",
    path: "/v1/control/users/{id}/timeline",
    summary: "Read the recent audit timeline for an account",
    tag: "users",
    audience: ["control"],
    pathParams: ["id"],
    success: [
      {
        status: 200,
        description: "The fifty most recent audit entries for this account",
        schema: accountTimelineListResponse,
      },
    ],
  },
  {
    id: "listApprovals",
    method: "get",
    path: "/v1/control/approvals",
    summary: "List approval requests",
    tag: "users",
    audience: ["control"],
    success: [
      {
        status: 200,
        description: "Pending requests first, then recent decisions",
        schema: approvalRequestListResponse,
      },
    ],
  },
  {
    id: "createApproval",
    method: "post",
    path: "/v1/control/approvals",
    summary: "Request a sensitive action",
    tag: "users",
    audience: ["control"],
    request: {
      schema: createApprovalRequest,
      description: "Action, target and reason",
    },
    success: [
      {
        status: 201,
        description: "The pending request",
        schema: approvalRequestViewResponse,
      },
    ],
  },
  {
    id: "decideApproval",
    method: "post",
    path: "/v1/control/approvals/{id}/decide",
    summary: "Approve or reject a request",
    tag: "users",
    audience: ["control"],
    pathParams: ["id"],
    request: {
      schema: decideApprovalRequest,
      description: "Decision and reason",
    },
    success: [
      {
        status: 200,
        description: "The decided request",
        schema: approvalRequestViewResponse,
      },
    ],
  },
]
