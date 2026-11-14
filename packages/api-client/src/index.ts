// AUTO-GENERATED from openapi/openapi.json by server/src/openapi/client.ts.
// Do not edit by hand. Run `pnpm openapi:generate`.

export interface ApiErrorBody {
  error: {
    code: string
    message: string
    correlationId?: string
  }
}

export class ApiClientError extends Error {
  readonly status: number
  readonly code: string
  readonly correlationId?: string

  constructor(status: number, body: ApiErrorBody) {
    super(body.error.message)
    this.name = "ApiClientError"
    this.status = status
    this.code = body.error.code
    if (body.error.correlationId) this.correlationId = body.error.correlationId
  }
}

export interface HivorrClientOptions {
  readonly baseUrl: string
  readonly fetch?: typeof globalThis.fetch
  readonly credentials?: RequestCredentials
}

type HttpMethod = "GET" | "POST" | "PUT" | "PATCH" | "DELETE"

export type HealthResponse = { "status": "ok"; "service": "hivorr-api"; "version": "v1"; "environment": "development" | "test" | "staging" | "production"; "releaseSha": string | null; "releaseDigest": string | null; "time": string }

export type HealthLiveResponse = { "status": "ok"; "service": "hivorr-api"; "version": "v1"; "environment": "development" | "test" | "staging" | "production"; "releaseSha": string | null; "releaseDigest": string | null; "time": string }

export type HealthReadyResponse = { "status": "not_ready"; "service": "hivorr-api"; "checks": { "configuration": "ok"; "database": "not_implemented" } }

export type RegisterRequest = { "email": string; "password": string; "displayName"?: string }

export type RegisterResponse = { "accountId": string; "userId": string; "email": string }

export type RequestPasswordResetRequest = { "email": string }

export type RequestPasswordResetResponse = void

export type CompletePasswordResetRequest = { "token": string; "password": string }

export type CompletePasswordResetResponse = void

export type RequestEmailVerificationResponse = void

export type CompleteEmailVerificationRequest = { "token": string }

export type CompleteEmailVerificationResponse = void

export type SignInRequest = { "email": string; "password": string }

export type SignInResponse = { "sessionId": string; "accountId": string; "userId": string; "email": string; "audience": "app" | "control" | "staff" | "partner"; "environment": "production" | "staging"; "expiresAt": string; "idleExpiresAt": string } | { "mfaRequired": true; "challengeToken": string; "expiresAt": string }

export type VerifyMfaRequest = { "challengeToken": string; "code": string }

export type VerifyMfaResponse = { "sessionId": string; "accountId": string; "userId": string; "email": string; "audience": "app" | "control" | "staff" | "partner"; "environment": "production" | "staging"; "expiresAt": string; "idleExpiresAt": string }

export type EnrollTotpResponse = { "factorId": string; "secret": string; "otpauthUri": string }

export type ConfirmTotpRequest = { "factorId": string; "code": string }

export type ConfirmTotpResponse = { "recoveryCodes": (string)[] }

export type StepUpRequest = { "code": string }

export type StepUpResponse = { "sessionId": string; "accountId": string; "userId": string; "email": string; "audience": "app" | "control" | "staff" | "partner"; "environment": "production" | "staging"; "expiresAt": string; "idleExpiresAt": string }

export type RefreshResponse = { "sessionId": string; "accountId": string; "userId": string; "email": string; "audience": "app" | "control" | "staff" | "partner"; "environment": "production" | "staging"; "expiresAt": string; "idleExpiresAt": string }

export type SessionResponse = { "sessionId": string; "accountId": string; "userId": string; "email": string; "audience": "app" | "control" | "staff" | "partner"; "environment": "production" | "staging"; "expiresAt": string; "idleExpiresAt": string; "account": { "id": string; "email": string; "displayName": string | null; "status": string }; "activities": ({ "id": "market.buy" | "services.hire" | "errands.request" | "market.sell" | "services.offer" | "logistics.provide"; "state": "ACTIVE" | "RESTRICTED" | "SUSPENDED" })[]; "capabilities": ("session.read" | "profile.read.self" | "profile.update.self" | "activity.activate" | "activity.deactivate" | "market.catalog.browse" | "market.cart.manage" | "market.order.place" | "market.order.cancel" | "market.order.dispute" | "services.job.post" | "services.job.post.business" | "services.application.review" | "services.engagement.fund" | "services.job.apply" | "services.service.publish" | "services.engagement.deliver" | "services.earnings.receive" | "errands.request.create" | "errands.request.cancel" | "errands.request.track" | "market.product.draft" | "market.product.publish" | "market.inventory.manage" | "market.order.fulfil" | "market.invoice.issue" | "market.earnings.receive" | "logistics.pool.browse" | "logistics.assignment.accept" | "logistics.delivery.progress" | "logistics.delivery.complete" | "logistics.earnings.receive" | "business.create" | "business.verification.submit" | "business.update" | "wallet.read" | "wallet.withdraw" | "wallet.payout_account.bind" | "wallet.convert" | "messaging.thread.read" | "messaging.message.send" | "notification.read" | "admin.verification.review" | "admin.payment.review" | "admin.dispute.resolve" | "admin.account.suspend" | "admin.configuration.write" | "admin.configuration.read" | "admin.audit.read" | "admin.grant.read" | "admin.grant.manage" | "admin.user.read" | "admin.user.manage" | "admin.role.read" | "admin.role.manage" | "admin.case.read" | "admin.case.assign" | "admin.case.investigate" | "admin.case.recommend" | "admin.case.approve" | "admin.evidence.read" | "admin.report.read" | "admin.report.export" | "admin.partner.read" | "admin.partner.manage" | "staff.support.handle" | "partner.referral.read" | "platform.engineering.access")[] }

export type ListSessionsResponse = ({ "sessionId": string; "current": boolean; "audience": "app" | "control" | "staff" | "partner"; "environment": "production" | "staging"; "deviceName": string | null; "createdAt": string; "lastSeenAt": string; "idleExpiresAt": string; "expiresAt": string; "mfaSatisfied": boolean })[]

export type RevokeOtherSessionsResponse = { "revoked": number }

export type RevokeSessionResponse = void

export type SignOutResponse = void

export type ListActivitiesResponse = ({ "id": "market.buy" | "services.hire" | "errands.request" | "market.sell" | "services.offer" | "logistics.provide"; "state": "INACTIVE" | "ACTIVE" | "RESTRICTED" | "SUSPENDED" })[]

export type ActivateActivityResponse = { "id": "market.buy" | "services.hire" | "errands.request" | "market.sell" | "services.offer" | "logistics.provide"; "state": "INACTIVE" | "ACTIVE" | "RESTRICTED" | "SUSPENDED" }

export type DeactivateActivityResponse = { "id": "market.buy" | "services.hire" | "errands.request" | "market.sell" | "services.offer" | "logistics.provide"; "state": "INACTIVE" | "ACTIVE" | "RESTRICTED" | "SUSPENDED" }

export type ListAuditResponse = ({ "id": string; "occurredAt": string; "actorType": string; "actorId": string | null; "actorAudience": string | null; "environment": string; "action": string; "targetType": string | null; "targetId": string | null; "beforeSummary": { [key: string]: unknown } | null; "afterSummary": { [key: string]: unknown } | null; "correlationId": string | null; "sessionId"?: string | null; "reason"?: string | null; "approvalReference"?: string | null; "actorDisplayName"?: string | null; "actorEmail"?: string | null; "actorRoleKeys"?: (string)[]; "actorRoleScopes"?: ({ "roleKey": string; "scopeType"?: string | null; "scopeId"?: string | null })[]; "capability"?: string | null })[]

export type ListUsersResponse = ({ "id": string; "accountId": string; "email": string; "displayName": string | null; "status": string; "emailVerified": boolean; "confirmedFactors": number; "createdAt": string })[]

export type ControlAuthorityResponse = { "grants": ({ "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null })[]; "roles": (string)[]; "permissions": (string)[]; "deniedPermissions": (string)[]; "capabilities": ("session.read" | "profile.read.self" | "profile.update.self" | "activity.activate" | "activity.deactivate" | "market.catalog.browse" | "market.cart.manage" | "market.order.place" | "market.order.cancel" | "market.order.dispute" | "services.job.post" | "services.job.post.business" | "services.application.review" | "services.engagement.fund" | "services.job.apply" | "services.service.publish" | "services.engagement.deliver" | "services.earnings.receive" | "errands.request.create" | "errands.request.cancel" | "errands.request.track" | "market.product.draft" | "market.product.publish" | "market.inventory.manage" | "market.order.fulfil" | "market.invoice.issue" | "market.earnings.receive" | "logistics.pool.browse" | "logistics.assignment.accept" | "logistics.delivery.progress" | "logistics.delivery.complete" | "logistics.earnings.receive" | "business.create" | "business.verification.submit" | "business.update" | "wallet.read" | "wallet.withdraw" | "wallet.payout_account.bind" | "wallet.convert" | "messaging.thread.read" | "messaging.message.send" | "notification.read" | "admin.verification.review" | "admin.payment.review" | "admin.dispute.resolve" | "admin.account.suspend" | "admin.configuration.write" | "admin.configuration.read" | "admin.audit.read" | "admin.grant.read" | "admin.grant.manage" | "admin.user.read" | "admin.user.manage" | "admin.role.read" | "admin.role.manage" | "admin.case.read" | "admin.case.assign" | "admin.case.investigate" | "admin.case.recommend" | "admin.case.approve" | "admin.evidence.read" | "admin.report.read" | "admin.report.export" | "admin.partner.read" | "admin.partner.manage" | "staff.support.handle" | "partner.referral.read" | "platform.engineering.access")[] }

export type OwnGrantsResponse = { "grants": ({ "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null })[]; "capabilities": ("session.read" | "profile.read.self" | "profile.update.self" | "activity.activate" | "activity.deactivate" | "market.catalog.browse" | "market.cart.manage" | "market.order.place" | "market.order.cancel" | "market.order.dispute" | "services.job.post" | "services.job.post.business" | "services.application.review" | "services.engagement.fund" | "services.job.apply" | "services.service.publish" | "services.engagement.deliver" | "services.earnings.receive" | "errands.request.create" | "errands.request.cancel" | "errands.request.track" | "market.product.draft" | "market.product.publish" | "market.inventory.manage" | "market.order.fulfil" | "market.invoice.issue" | "market.earnings.receive" | "logistics.pool.browse" | "logistics.assignment.accept" | "logistics.delivery.progress" | "logistics.delivery.complete" | "logistics.earnings.receive" | "business.create" | "business.verification.submit" | "business.update" | "wallet.read" | "wallet.withdraw" | "wallet.payout_account.bind" | "wallet.convert" | "messaging.thread.read" | "messaging.message.send" | "notification.read" | "admin.verification.review" | "admin.payment.review" | "admin.dispute.resolve" | "admin.account.suspend" | "admin.configuration.write" | "admin.configuration.read" | "admin.audit.read" | "admin.grant.read" | "admin.grant.manage" | "admin.user.read" | "admin.user.manage" | "admin.role.read" | "admin.role.manage" | "admin.case.read" | "admin.case.assign" | "admin.case.investigate" | "admin.case.recommend" | "admin.case.approve" | "admin.evidence.read" | "admin.report.read" | "admin.report.export" | "admin.partner.read" | "admin.partner.manage" | "staff.support.handle" | "partner.referral.read" | "platform.engineering.access")[] }

export type ListGrantsResponse = ({ "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null })[]

export type CreateGrantRequest = { "email": string; "grantType": "admin" | "staff" | "partner" | "platform_engineering"; "scope": string; "departmentKey"?: string; "reason"?: string; "expiresAt"?: string }

export type CreateGrantResponse = { "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null }

export type RevokeGrantResponse = { "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null }

export type ListDepartmentsResponse = ({ "key": string; "name": string })[]

export type SetGrantDepartmentRequest = { "departmentKey": string; "reason"?: string }

export type SetGrantDepartmentResponse = { "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null }

export type ListStaffResponse = ({ "id": string; "userId": string; "email": string; "displayName": string | null; "jobTitle": string | null; "departmentKey": string | null; "departmentName": string | null; "engagementStatus": string; "startedOn": string | null; "endedOn": string | null; "confirmedFactors": number; "createdAt": string })[]

export type CreateStaffInviteRequest = { "email": string; "deliveryEmail"?: string; "departmentKey"?: string; "jobTitle"?: string; "reason": string }

export type CreateStaffInviteResponse = { "id": string; "email": string; "deliveryEmail"?: string; "departmentKey": string | null; "expiresAt": string; "token": string; "emailSent"?: boolean }

export type AttachStaffProfileRequest = { "email": string; "departmentKey"?: string; "jobTitle"?: string; "reason": string }

export type AttachStaffProfileResponse = { "userId": string; "staffProfileId": string; "email": string; "departmentKey": string | null }

export type SuspendStaffRequest = { "reason": string }

export type SuspendStaffResponse = { "userId": string; "engagementStatus": string; "sessionsRevoked": number; "grantsRevoked": number }

export type ReactivateStaffRequest = { "reason": string }

export type ReactivateStaffResponse = { "userId": string; "engagementStatus": string; "sessionsRevoked": number; "grantsRevoked": number }

export type OffboardStaffRequest = { "reason": string }

export type OffboardStaffResponse = { "userId": string; "engagementStatus": string; "sessionsRevoked": number; "grantsRevoked": number }

export type SetStaffDepartmentRequest = { "departmentKey": string; "reason": string }

export type SetStaffDepartmentResponse = { "userId": string; "departmentKey": string | null }

export type StaffInviteDetailsResponse = { "email": string; "jobTitle": string | null; "departmentKey": string | null; "expiresAt": string }

export type AcceptStaffInviteRequest = { "token": string; "password": string; "displayName"?: string }

export type AcceptStaffInviteResponse = { "email": string }

export type ListRolesResponse = ({ "key": string; "name": string; "description"?: string | null; "system": boolean; "permissions"?: (string)[]; "activeAssignments"?: number })[]

export type ListRoleAssignmentsResponse = ({ "id": string; "userId": string; "email": string; "displayName"?: string | null; "roleKey": string; "roleName": string; "scopeType": string; "scopeId"?: string | null; "expiresAt"?: string | null; "revokedAt"?: string | null; "createdAt": string; "grantedBy"?: string | null; "reason"?: string | null })[]

export type AssignRoleRequest = { "email": string; "roleKey": string; "scopeType": "platform" | "department" | "organisation"; "scopeId"?: string; "expiresAt"?: string; "reason"?: string }

export type AssignRoleResponse = { "id": string; "userId": string; "email": string; "displayName"?: string | null; "roleKey": string; "roleName": string; "scopeType": string; "scopeId"?: string | null; "expiresAt"?: string | null; "revokedAt"?: string | null; "createdAt": string; "grantedBy"?: string | null; "reason"?: string | null }

export type ListRoleScopeTargetsResponse = ({ "id": string; "name": string })[]

export type ListAssignableStaffResponse = ({ "userId": string; "email": string; "displayName"?: string | null; "departmentKey"?: string | null; "departmentName"?: string | null })[]

export type RevokeRoleRequest = { "reason"?: string }

export type RevokeRoleResponse = { "id": string; "userId": string; "email": string; "displayName"?: string | null; "roleKey": string; "roleName": string; "scopeType": string; "scopeId"?: string | null; "expiresAt"?: string | null; "revokedAt"?: string | null; "createdAt": string; "grantedBy"?: string | null; "reason"?: string | null }

export type ListAccessDenialsResponse = ({ "id": string; "userId": string; "email": string; "displayName"?: string | null; "permissionKey": string; "scopeType"?: string | null; "scopeId"?: string | null; "reason": string; "expiresAt"?: string | null; "createdAt": string; "createdBy"?: string | null; "revokedAt"?: string | null; "revokedReason"?: string | null })[]

export type CreateAccessDenialRequest = { "email": string; "permissionKey": string; "scopeType": "platform" | "department" | "organisation"; "scopeId"?: string; "expiresAt"?: string; "reason"?: string }

export type CreateAccessDenialResponse = { "id": string; "userId": string; "email": string; "displayName"?: string | null; "permissionKey": string; "scopeType"?: string | null; "scopeId"?: string | null; "reason": string; "expiresAt"?: string | null; "createdAt": string; "createdBy"?: string | null; "revokedAt"?: string | null; "revokedReason"?: string | null }

export type RevokeAccessDenialRequest = { "reason"?: string }

export type RevokeAccessDenialResponse = { "id": string; "userId": string; "email": string; "displayName"?: string | null; "permissionKey": string; "scopeType"?: string | null; "scopeId"?: string | null; "reason": string; "expiresAt"?: string | null; "createdAt": string; "createdBy"?: string | null; "revokedAt"?: string | null; "revokedReason"?: string | null }

export type SuspendAccountRequest = { "reason"?: string }

export type SuspendAccountResponse = { "userId": string; "status": string; "sessionsRevoked": number; "grantsRevoked": number; "rolesRevoked": number }

export type ReactivateAccountRequest = { "reason"?: string }

export type ReactivateAccountResponse = { "userId": string; "status": string; "sessionsRevoked": number; "grantsRevoked": number; "rolesRevoked": number }

export type CloseAccountRequest = { "reason"?: string }

export type CloseAccountResponse = { "userId": string; "status": string; "sessionsRevoked": number; "grantsRevoked": number; "rolesRevoked": number } | { "error": { "code": "UNAUTHENTICATED" | "FORBIDDEN" | "ACTIVITY_INACTIVE" | "VALIDATION_FAILED" | "NOT_FOUND" | "CONFLICT" | "RATE_LIMITED" | "SERVICE_UNAVAILABLE" | "INTERNAL_ERROR"; "message": string; "correlationId"?: string } }

export type RevokeUserSessionsRequest = { "reason"?: string }

export type RevokeUserSessionsResponse = { "userId": string; "status": string; "sessionsRevoked": number; "grantsRevoked": number; "rolesRevoked": number }

export type ListAccountNotesResponse = ({ "id": string; "body": string; "authorName"?: string | null; "authorEmail"?: string | null; "createdAt": string })[]

export type AddAccountNoteRequest = { "body": string }

export type AddAccountNoteResponse = { "id": string; "body": string; "authorName"?: string | null; "authorEmail"?: string | null; "createdAt": string }

export type AccountTimelineResponse = ({ "occurredAt": string; "action": string; "reason"?: string | null; "actorName"?: string | null; "actorEmail"?: string | null })[]

export type ListApprovalsResponse = ({ "id": string; "reference": string; "actionType": string; "targetType": string; "targetId": string; "status": string; "reason": string; "requesterUserId": string; "requesterName"?: string | null; "requesterEmail"?: string | null; "createdAt": string; "decidedAt"?: string | null })[]

export type CreateApprovalRequest = { "actionType": string; "targetType": string; "targetId": string; "reason"?: string }

export type CreateApprovalResponse = { "id": string; "reference": string; "actionType": string; "targetType": string; "targetId": string; "status": string; "reason": string; "requesterUserId": string; "requesterName"?: string | null; "requesterEmail"?: string | null; "createdAt": string; "decidedAt"?: string | null }

export type DecideApprovalRequest = { "decision": "approve" | "reject"; "reason"?: string }

export type DecideApprovalResponse = { "id": string; "reference": string; "actionType": string; "targetType": string; "targetId": string; "status": string; "reason": string; "requesterUserId": string; "requesterName"?: string | null; "requesterEmail"?: string | null; "createdAt": string; "decidedAt"?: string | null }

export type RequestCaseDecisionRequest = { "outcome": string; "reason"?: string }

export type RequestCaseDecisionResponse = { "id": string; "reference": string; "actionType": string; "targetType": string; "targetId": string; "status": string; "reason": string; "requesterUserId": string; "requesterName"?: string | null; "requesterEmail"?: string | null; "createdAt": string; "decidedAt"?: string | null }

export type ListVerificationQueueResponse = ({ "caseId": string; "reference": string; "title": string; "lane": string; "reviewStatus": string; "caseStatus": string; "priority": string; "subjectType"?: string | null; "subjectId"?: string | null; "assigneeEmail"?: string | null; "evidenceCount"?: number; "createdAt": string })[]

export type RecordVerificationDecisionRequest = { "decision": "approve" | "reject" | "request_information"; "reason"?: string }

export type RecordVerificationDecisionResponse = { "caseId": string; "reference": string; "title": string; "lane": string; "reviewStatus": string; "caseStatus": string; "priority": string; "subjectType"?: string | null; "subjectId"?: string | null; "assigneeEmail"?: string | null; "evidenceCount"?: number; "createdAt": string }

export type ListPartnersResponse = ({ "id": string; "legalName": string; "tradingName"?: string | null; "category"?: string | null; "country"?: string | null; "status": string; "representatives"?: number; "agreements"?: number; "createdAt": string })[]

export type CreatePartnerRequest = { "legalName": string; "tradingName"?: string; "category"?: string; "country"?: string; "reason"?: string }

export type CreatePartnerResponse = { "id": string; "legalName": string; "tradingName"?: string | null; "category"?: string | null; "country"?: string | null; "status": string; "representatives"?: number; "agreements"?: number; "createdAt": string }

export type SetPartnerStatusRequest = { "status": "active" | "suspended" | "terminated"; "reason"?: string }

export type SetPartnerStatusResponse = { "id": string; "legalName": string; "tradingName"?: string | null; "category"?: string | null; "country"?: string | null; "status": string; "representatives"?: number; "agreements"?: number; "createdAt": string }

export type ListPartnerRepresentativesResponse = ({ "id": string; "userId": string; "email": string; "displayName"?: string | null; "role": string; "effectiveFrom": string; "effectiveTo"?: string | null })[]

export type AddPartnerRepresentativeRequest = { "email": string; "role": "owner" | "admin" | "member" | "viewer"; "reason"?: string }

export type AddPartnerRepresentativeResponse = { "id": string; "userId": string; "email": string; "displayName"?: string | null; "role": string; "effectiveFrom": string; "effectiveTo"?: string | null }

export type PartnerOrganisationsResponse = ({ "organisationId": string; "legalName": string; "tradingName"?: string | null; "status": string; "role": string; "effectiveFrom": string })[]

export type ListCasesResponse = ({ "id": string; "reference": string; "caseType": string; "title": string; "description"?: string | null; "priority": string; "severity": string; "status": string; "queueKey"?: string | null; "assigneeId"?: string | null; "assigneeName"?: string | null; "assigneeEmail"?: string | null; "departmentName"?: string | null; "createdAt": string; "updatedAt": string; "closedAt"?: string | null })[]

export type CreateCaseRequest = { "caseType": "support" | "complaint" | "dispute" | "investigation" | "incident" | "verification_review" | "financial_exception" | "security_incident" | "staff_conduct" | "partner_conduct"; "title": string; "description"?: string; "priority": "low" | "normal" | "high" | "urgent"; "severity": "low" | "medium" | "high" | "critical"; "queueKey"?: string; "reason"?: string }

export type CreateCaseResponse = { "id": string; "reference": string; "caseType": string; "title": string; "description"?: string | null; "priority": string; "severity": string; "status": string; "queueKey"?: string | null; "assigneeId"?: string | null; "assigneeName"?: string | null; "assigneeEmail"?: string | null; "departmentName"?: string | null; "createdAt": string; "updatedAt": string; "closedAt"?: string | null }

export type ListCaseEventsResponse = ({ "id": string; "eventType": string; "summary": string; "actorName"?: string | null; "actorEmail"?: string | null; "occurredAt": string })[]

export type AddCaseEventRequest = { "summary": string }

export type AddCaseEventResponse = { "id": string; "eventType": string; "summary": string; "actorName"?: string | null; "actorEmail"?: string | null; "occurredAt": string }

export type AssignCaseRequest = { "email"?: string; "queueKey"?: string }

export type AssignCaseResponse = { "id": string; "reference": string; "caseType": string; "title": string; "description"?: string | null; "priority": string; "severity": string; "status": string; "queueKey"?: string | null; "assigneeId"?: string | null; "assigneeName"?: string | null; "assigneeEmail"?: string | null; "departmentName"?: string | null; "createdAt": string; "updatedAt": string; "closedAt"?: string | null }

export type SetCaseStatusRequest = { "status": "TRIAGED" | "OPEN" | "INVESTIGATING" | "PENDING_INFORMATION" | "ESCALATED" | "REVIEW" | "DECIDED" | "ACTION_PENDING" | "CLOSED" | "REOPENED" | "ARCHIVED"; "reason"?: string }

export type SetCaseStatusResponse = { "id": string; "reference": string; "caseType": string; "title": string; "description"?: string | null; "priority": string; "severity": string; "status": string; "queueKey"?: string | null; "assigneeId"?: string | null; "assigneeName"?: string | null; "assigneeEmail"?: string | null; "departmentName"?: string | null; "createdAt": string; "updatedAt": string; "closedAt"?: string | null }

export type ListCaseEvidenceResponse = ({ "id": string; "fileName": string; "mimeType"?: string | null; "sizeBytes"?: number | null; "sha256"?: string | null; "classification": string; "status": string; "supersedesId"?: string | null; "uploadedByName"?: string | null; "uploadedByEmail"?: string | null; "uploadedAt": string })[]

export type AddCaseEvidenceRequest = { "storageKey": string; "fileName": string; "mimeType"?: string; "sizeBytes"?: number; "sha256"?: string; "classification"?: "standard" | "sensitive" | "critical"; "reason"?: string }

export type AddCaseEvidenceResponse = { "id": string; "fileName": string; "mimeType"?: string | null; "sizeBytes"?: number | null; "sha256"?: string | null; "classification": string; "status": string; "supersedesId"?: string | null; "uploadedByName"?: string | null; "uploadedByEmail"?: string | null; "uploadedAt": string }

export type AccessCaseEvidenceRequest = { "purpose"?: string }

export type AccessCaseEvidenceResponse = { "recorded": boolean }

export type SupersedeCaseEvidenceRequest = { "replacementId": string; "reason"?: string }

export type SupersedeCaseEvidenceResponse = { "id": string; "fileName": string; "mimeType"?: string | null; "sizeBytes"?: number | null; "sha256"?: string | null; "classification": string; "status": string; "supersedesId"?: string | null; "uploadedByName"?: string | null; "uploadedByEmail"?: string | null; "uploadedAt": string }

export function createHivorrClient(options: HivorrClientOptions) {
  const fetchImpl = options.fetch ?? globalThis.fetch
  const baseUrl = options.baseUrl.replace(/\/+$/, "")
  const credentials = options.credentials ?? "include"

  async function request<T>(
    method: HttpMethod,
    path: string,
    body: unknown,
    expected: readonly number[],
  ): Promise<T> {
    const response = await fetchImpl(`${baseUrl}${path}`, {
      method,
      credentials,
      headers: body === undefined ? undefined : { "content-type": "application/json" },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    })

    const text = await response.text()
    let parsed: unknown
    if (text) {
      try {
        parsed = JSON.parse(text)
      } catch {
        parsed = undefined
      }
    }

    if (!response.ok && !expected.includes(response.status)) {
      const envelope = parsed as ApiErrorBody | undefined
      const message =
        envelope?.error?.message ??
        `Hivorr API request failed with status ${response.status}`
      throw new ApiClientError(response.status, {
        error: {
          code: envelope?.error?.code ?? "INTERNAL_ERROR",
          message,
          ...(envelope?.error?.correlationId
            ? { correlationId: envelope.error.correlationId }
            : {}),
        },
      })
    }

    return parsed as T
  }

  return {
    health: () =>
      request<HealthResponse>(
        "GET",
        "/v1/health",
        undefined,
        [200],
      ),
    healthLive: () =>
      request<HealthLiveResponse>(
        "GET",
        "/v1/health/live",
        undefined,
        [200],
      ),
    healthReady: () =>
      request<HealthReadyResponse>(
        "GET",
        "/v1/health/ready",
        undefined,
        [503],
      ),
    register: (input: RegisterRequest) =>
      request<RegisterResponse>(
        "POST",
        "/v1/auth/register",
        input,
        [201],
      ),
    requestPasswordReset: (input: RequestPasswordResetRequest) =>
      request<RequestPasswordResetResponse>(
        "POST",
        "/v1/auth/password-reset/request",
        input,
        [202],
      ),
    completePasswordReset: (input: CompletePasswordResetRequest) =>
      request<CompletePasswordResetResponse>(
        "POST",
        "/v1/auth/password-reset/complete",
        input,
        [204],
      ),
    requestEmailVerification: () =>
      request<RequestEmailVerificationResponse>(
        "POST",
        "/v1/auth/email-verification/request",
        undefined,
        [202],
      ),
    completeEmailVerification: (input: CompleteEmailVerificationRequest) =>
      request<CompleteEmailVerificationResponse>(
        "POST",
        "/v1/auth/email-verification/complete",
        input,
        [204],
      ),
    signIn: (input: SignInRequest) =>
      request<SignInResponse>(
        "POST",
        "/v1/auth/sign-in",
        input,
        [200, 202],
      ),
    verifyMfa: (input: VerifyMfaRequest) =>
      request<VerifyMfaResponse>(
        "POST",
        "/v1/auth/mfa/verify",
        input,
        [200],
      ),
    enrollTotp: () =>
      request<EnrollTotpResponse>(
        "POST",
        "/v1/auth/mfa/totp/enroll",
        undefined,
        [201],
      ),
    confirmTotp: (input: ConfirmTotpRequest) =>
      request<ConfirmTotpResponse>(
        "POST",
        "/v1/auth/mfa/totp/confirm",
        input,
        [200],
      ),
    stepUp: (input: StepUpRequest) =>
      request<StepUpResponse>(
        "POST",
        "/v1/auth/mfa/step-up",
        input,
        [200],
      ),
    refresh: () =>
      request<RefreshResponse>(
        "POST",
        "/v1/auth/refresh",
        undefined,
        [200],
      ),
    session: () =>
      request<SessionResponse>(
        "GET",
        "/v1/session",
        undefined,
        [200],
      ),
    listSessions: () =>
      request<ListSessionsResponse>(
        "GET",
        "/v1/auth/sessions",
        undefined,
        [200],
      ),
    revokeOtherSessions: () =>
      request<RevokeOtherSessionsResponse>(
        "DELETE",
        "/v1/auth/sessions",
        undefined,
        [200],
      ),
    revokeSession: (params: { id: string }) =>
      request<RevokeSessionResponse>(
        "DELETE",
        `/v1/auth/sessions/${encodeURIComponent(params.id)}`,
        undefined,
        [204],
      ),
    signOut: () =>
      request<SignOutResponse>(
        "POST",
        "/v1/auth/sign-out",
        undefined,
        [204],
      ),
    listActivities: () =>
      request<ListActivitiesResponse>(
        "GET",
        "/v1/activities",
        undefined,
        [200],
      ),
    activateActivity: (params: { id: string }) =>
      request<ActivateActivityResponse>(
        "POST",
        `/v1/activities/${encodeURIComponent(params.id)}/activate`,
        undefined,
        [200],
      ),
    deactivateActivity: (params: { id: string }) =>
      request<DeactivateActivityResponse>(
        "POST",
        `/v1/activities/${encodeURIComponent(params.id)}/deactivate`,
        undefined,
        [200],
      ),
    listAudit: () =>
      request<ListAuditResponse>(
        "GET",
        "/v1/control/audit",
        undefined,
        [200],
      ),
    listUsers: () =>
      request<ListUsersResponse>(
        "GET",
        "/v1/control/users",
        undefined,
        [200],
      ),
    controlAuthority: () =>
      request<ControlAuthorityResponse>(
        "GET",
        "/v1/control/authority",
        undefined,
        [200],
      ),
    ownGrants: () =>
      request<OwnGrantsResponse>(
        "GET",
        "/v1/grants",
        undefined,
        [200],
      ),
    listGrants: () =>
      request<ListGrantsResponse>(
        "GET",
        "/v1/control/grants",
        undefined,
        [200],
      ),
    createGrant: (input: CreateGrantRequest) =>
      request<CreateGrantResponse>(
        "POST",
        "/v1/control/grants",
        input,
        [201],
      ),
    revokeGrant: (params: { id: string }) =>
      request<RevokeGrantResponse>(
        "POST",
        `/v1/control/grants/${encodeURIComponent(params.id)}/revoke`,
        undefined,
        [200],
      ),
    listDepartments: () =>
      request<ListDepartmentsResponse>(
        "GET",
        "/v1/control/departments",
        undefined,
        [200],
      ),
    setGrantDepartment: (params: { id: string }, input: SetGrantDepartmentRequest) =>
      request<SetGrantDepartmentResponse>(
        "PATCH",
        `/v1/control/grants/${encodeURIComponent(params.id)}/department`,
        input,
        [200],
      ),
    listStaff: () =>
      request<ListStaffResponse>(
        "GET",
        "/v1/control/staff",
        undefined,
        [200],
      ),
    createStaffInvite: (input: CreateStaffInviteRequest) =>
      request<CreateStaffInviteResponse>(
        "POST",
        "/v1/control/staff/invites",
        input,
        [201],
      ),
    attachStaffProfile: (input: AttachStaffProfileRequest) =>
      request<AttachStaffProfileResponse>(
        "POST",
        "/v1/control/staff/attach",
        input,
        [201],
      ),
    suspendStaff: (params: { userId: string }, input: SuspendStaffRequest) =>
      request<SuspendStaffResponse>(
        "POST",
        `/v1/control/staff/${encodeURIComponent(params.userId)}/suspend`,
        input,
        [200],
      ),
    reactivateStaff: (params: { userId: string }, input: ReactivateStaffRequest) =>
      request<ReactivateStaffResponse>(
        "POST",
        `/v1/control/staff/${encodeURIComponent(params.userId)}/reactivate`,
        input,
        [200],
      ),
    offboardStaff: (params: { userId: string }, input: OffboardStaffRequest) =>
      request<OffboardStaffResponse>(
        "POST",
        `/v1/control/staff/${encodeURIComponent(params.userId)}/offboard`,
        input,
        [200],
      ),
    setStaffDepartment: (params: { userId: string }, input: SetStaffDepartmentRequest) =>
      request<SetStaffDepartmentResponse>(
        "PATCH",
        `/v1/control/staff/${encodeURIComponent(params.userId)}/department`,
        input,
        [200],
      ),
    staffInviteDetails: () =>
      request<StaffInviteDetailsResponse>(
        "GET",
        "/v1/auth/staff-invite",
        undefined,
        [200],
      ),
    acceptStaffInvite: (input: AcceptStaffInviteRequest) =>
      request<AcceptStaffInviteResponse>(
        "POST",
        "/v1/auth/staff-invite/accept",
        input,
        [201],
      ),
    listRoles: () =>
      request<ListRolesResponse>(
        "GET",
        "/v1/control/roles",
        undefined,
        [200],
      ),
    listRoleAssignments: () =>
      request<ListRoleAssignmentsResponse>(
        "GET",
        "/v1/control/role-assignments",
        undefined,
        [200],
      ),
    assignRole: (input: AssignRoleRequest) =>
      request<AssignRoleResponse>(
        "POST",
        "/v1/control/role-assignments",
        input,
        [201],
      ),
    listRoleScopeTargets: () =>
      request<ListRoleScopeTargetsResponse>(
        "GET",
        "/v1/control/roles/scope-targets",
        undefined,
        [200],
      ),
    listAssignableStaff: () =>
      request<ListAssignableStaffResponse>(
        "GET",
        "/v1/control/roles/assignable-staff",
        undefined,
        [200],
      ),
    revokeRole: (params: { id: string }, input: RevokeRoleRequest) =>
      request<RevokeRoleResponse>(
        "POST",
        `/v1/control/role-assignments/${encodeURIComponent(params.id)}/revoke`,
        input,
        [200],
      ),
    listAccessDenials: () =>
      request<ListAccessDenialsResponse>(
        "GET",
        "/v1/control/denials",
        undefined,
        [200],
      ),
    createAccessDenial: (input: CreateAccessDenialRequest) =>
      request<CreateAccessDenialResponse>(
        "POST",
        "/v1/control/denials",
        input,
        [201],
      ),
    revokeAccessDenial: (params: { id: string }, input: RevokeAccessDenialRequest) =>
      request<RevokeAccessDenialResponse>(
        "POST",
        `/v1/control/denials/${encodeURIComponent(params.id)}/revoke`,
        input,
        [200],
      ),
    suspendAccount: (params: { id: string }, input: SuspendAccountRequest) =>
      request<SuspendAccountResponse>(
        "POST",
        `/v1/control/users/${encodeURIComponent(params.id)}/suspend`,
        input,
        [200],
      ),
    reactivateAccount: (params: { id: string }, input: ReactivateAccountRequest) =>
      request<ReactivateAccountResponse>(
        "POST",
        `/v1/control/users/${encodeURIComponent(params.id)}/reactivate`,
        input,
        [200],
      ),
    closeAccount: (params: { id: string }, input: CloseAccountRequest) =>
      request<CloseAccountResponse>(
        "POST",
        `/v1/control/users/${encodeURIComponent(params.id)}/close`,
        input,
        [200, 409],
      ),
    revokeUserSessions: (params: { id: string }, input: RevokeUserSessionsRequest) =>
      request<RevokeUserSessionsResponse>(
        "POST",
        `/v1/control/users/${encodeURIComponent(params.id)}/revoke-sessions`,
        input,
        [200],
      ),
    listAccountNotes: (params: { id: string }) =>
      request<ListAccountNotesResponse>(
        "GET",
        `/v1/control/users/${encodeURIComponent(params.id)}/notes`,
        undefined,
        [200],
      ),
    addAccountNote: (params: { id: string }, input: AddAccountNoteRequest) =>
      request<AddAccountNoteResponse>(
        "POST",
        `/v1/control/users/${encodeURIComponent(params.id)}/notes`,
        input,
        [201],
      ),
    accountTimeline: (params: { id: string }) =>
      request<AccountTimelineResponse>(
        "GET",
        `/v1/control/users/${encodeURIComponent(params.id)}/timeline`,
        undefined,
        [200],
      ),
    listApprovals: () =>
      request<ListApprovalsResponse>(
        "GET",
        "/v1/control/approvals",
        undefined,
        [200],
      ),
    createApproval: (input: CreateApprovalRequest) =>
      request<CreateApprovalResponse>(
        "POST",
        "/v1/control/approvals",
        input,
        [201],
      ),
    decideApproval: (params: { id: string }, input: DecideApprovalRequest) =>
      request<DecideApprovalResponse>(
        "POST",
        `/v1/control/approvals/${encodeURIComponent(params.id)}/decide`,
        input,
        [200],
      ),
    requestCaseDecision: (params: { id: string }, input: RequestCaseDecisionRequest) =>
      request<RequestCaseDecisionResponse>(
        "POST",
        `/v1/control/cases/${encodeURIComponent(params.id)}/decision`,
        input,
        [201],
      ),
    listVerificationQueue: () =>
      request<ListVerificationQueueResponse>(
        "GET",
        "/v1/control/verification",
        undefined,
        [200],
      ),
    recordVerificationDecision: (params: { id: string }, input: RecordVerificationDecisionRequest) =>
      request<RecordVerificationDecisionResponse>(
        "POST",
        `/v1/control/verification/${encodeURIComponent(params.id)}/decision`,
        input,
        [200],
      ),
    listPartners: () =>
      request<ListPartnersResponse>(
        "GET",
        "/v1/control/partners",
        undefined,
        [200],
      ),
    createPartner: (input: CreatePartnerRequest) =>
      request<CreatePartnerResponse>(
        "POST",
        "/v1/control/partners",
        input,
        [201],
      ),
    setPartnerStatus: (params: { id: string }, input: SetPartnerStatusRequest) =>
      request<SetPartnerStatusResponse>(
        "POST",
        `/v1/control/partners/${encodeURIComponent(params.id)}/status`,
        input,
        [200],
      ),
    listPartnerRepresentatives: (params: { id: string }) =>
      request<ListPartnerRepresentativesResponse>(
        "GET",
        `/v1/control/partners/${encodeURIComponent(params.id)}/representatives`,
        undefined,
        [200],
      ),
    addPartnerRepresentative: (params: { id: string }, input: AddPartnerRepresentativeRequest) =>
      request<AddPartnerRepresentativeResponse>(
        "POST",
        `/v1/control/partners/${encodeURIComponent(params.id)}/representatives`,
        input,
        [201],
      ),
    partnerOrganisations: () =>
      request<PartnerOrganisationsResponse>(
        "GET",
        "/v1/partner/organisations",
        undefined,
        [200],
      ),
    listCases: () =>
      request<ListCasesResponse>(
        "GET",
        "/v1/control/cases",
        undefined,
        [200],
      ),
    createCase: (input: CreateCaseRequest) =>
      request<CreateCaseResponse>(
        "POST",
        "/v1/control/cases",
        input,
        [201],
      ),
    listCaseEvents: (params: { id: string }) =>
      request<ListCaseEventsResponse>(
        "GET",
        `/v1/control/cases/${encodeURIComponent(params.id)}/events`,
        undefined,
        [200],
      ),
    addCaseEvent: (params: { id: string }, input: AddCaseEventRequest) =>
      request<AddCaseEventResponse>(
        "POST",
        `/v1/control/cases/${encodeURIComponent(params.id)}/events`,
        input,
        [201],
      ),
    assignCase: (params: { id: string }, input: AssignCaseRequest) =>
      request<AssignCaseResponse>(
        "POST",
        `/v1/control/cases/${encodeURIComponent(params.id)}/assign`,
        input,
        [200],
      ),
    setCaseStatus: (params: { id: string }, input: SetCaseStatusRequest) =>
      request<SetCaseStatusResponse>(
        "POST",
        `/v1/control/cases/${encodeURIComponent(params.id)}/status`,
        input,
        [200],
      ),
    listCaseEvidence: (params: { id: string }) =>
      request<ListCaseEvidenceResponse>(
        "GET",
        `/v1/control/cases/${encodeURIComponent(params.id)}/evidence`,
        undefined,
        [200],
      ),
    addCaseEvidence: (params: { id: string }, input: AddCaseEvidenceRequest) =>
      request<AddCaseEvidenceResponse>(
        "POST",
        `/v1/control/cases/${encodeURIComponent(params.id)}/evidence`,
        input,
        [201],
      ),
    accessCaseEvidence: (params: { id: string; evidenceId: string }, input: AccessCaseEvidenceRequest) =>
      request<AccessCaseEvidenceResponse>(
        "POST",
        `/v1/control/cases/${encodeURIComponent(params.id)}/evidence/${encodeURIComponent(params.evidenceId)}/access`,
        input,
        [200],
      ),
    supersedeCaseEvidence: (params: { id: string }, input: SupersedeCaseEvidenceRequest) =>
      request<SupersedeCaseEvidenceResponse>(
        "POST",
        `/v1/control/evidence/${encodeURIComponent(params.id)}/supersede`,
        input,
        [200],
      ),
  }
}
