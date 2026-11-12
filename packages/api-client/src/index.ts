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

export type SessionResponse = { "sessionId": string; "accountId": string; "userId": string; "email": string; "audience": "app" | "control" | "staff" | "partner"; "environment": "production" | "staging"; "expiresAt": string; "idleExpiresAt": string; "account": { "id": string; "email": string; "displayName": string | null; "status": string }; "activities": ({ "id": "market.buy" | "services.hire" | "errands.request" | "market.sell" | "services.offer" | "logistics.provide"; "state": "ACTIVE" | "RESTRICTED" | "SUSPENDED" })[]; "capabilities": ("session.read" | "profile.read.self" | "profile.update.self" | "activity.activate" | "activity.deactivate" | "market.catalog.browse" | "market.cart.manage" | "market.order.place" | "market.order.cancel" | "market.order.dispute" | "services.job.post" | "services.job.post.business" | "services.application.review" | "services.engagement.fund" | "services.job.apply" | "services.service.publish" | "services.engagement.deliver" | "services.earnings.receive" | "errands.request.create" | "errands.request.cancel" | "errands.request.track" | "market.product.draft" | "market.product.publish" | "market.inventory.manage" | "market.order.fulfil" | "market.invoice.issue" | "market.earnings.receive" | "logistics.pool.browse" | "logistics.assignment.accept" | "logistics.delivery.progress" | "logistics.delivery.complete" | "logistics.earnings.receive" | "business.create" | "business.verification.submit" | "business.update" | "wallet.read" | "wallet.withdraw" | "wallet.payout_account.bind" | "wallet.convert" | "messaging.thread.read" | "messaging.message.send" | "notification.read" | "admin.verification.review" | "admin.payment.review" | "admin.dispute.resolve" | "admin.account.suspend" | "admin.configuration.write" | "admin.configuration.read" | "admin.audit.read" | "admin.grant.read" | "admin.grant.manage" | "admin.user.read" | "admin.user.manage" | "admin.role.read" | "admin.role.manage" | "admin.case.read" | "admin.case.assign" | "admin.case.investigate" | "admin.case.recommend" | "admin.case.approve" | "admin.evidence.read" | "admin.report.read" | "admin.report.export" | "staff.support.handle" | "partner.referral.read" | "platform.engineering.access")[] }

export type ListSessionsResponse = ({ "sessionId": string; "current": boolean; "audience": "app" | "control" | "staff" | "partner"; "environment": "production" | "staging"; "deviceName": string | null; "createdAt": string; "lastSeenAt": string; "idleExpiresAt": string; "expiresAt": string; "mfaSatisfied": boolean })[]

export type RevokeOtherSessionsResponse = { "revoked": number }

export type RevokeSessionResponse = void

export type SignOutResponse = void

export type ListActivitiesResponse = ({ "id": "market.buy" | "services.hire" | "errands.request" | "market.sell" | "services.offer" | "logistics.provide"; "state": "INACTIVE" | "ACTIVE" | "RESTRICTED" | "SUSPENDED" })[]

export type ActivateActivityResponse = { "id": "market.buy" | "services.hire" | "errands.request" | "market.sell" | "services.offer" | "logistics.provide"; "state": "INACTIVE" | "ACTIVE" | "RESTRICTED" | "SUSPENDED" }

export type DeactivateActivityResponse = { "id": "market.buy" | "services.hire" | "errands.request" | "market.sell" | "services.offer" | "logistics.provide"; "state": "INACTIVE" | "ACTIVE" | "RESTRICTED" | "SUSPENDED" }

export type ListAuditResponse = ({ "id": string; "occurredAt": string; "actorType": string; "actorId": string | null; "actorAudience": string | null; "environment": string; "action": string; "targetType": string | null; "targetId": string | null; "beforeSummary": { [key: string]: unknown } | null; "afterSummary": { [key: string]: unknown } | null; "correlationId": string | null; "sessionId"?: string | null; "reason"?: string | null; "approvalReference"?: string | null; "actorDisplayName"?: string | null; "actorEmail"?: string | null; "actorRoleKeys"?: (string)[]; "actorRoleScopes"?: ({ "roleKey": string; "scopeType"?: string | null; "scopeId"?: string | null })[]; "capability"?: string | null })[]

export type ListUsersResponse = ({ "id": string; "accountId": string; "email": string; "displayName": string | null; "status": string; "emailVerified": boolean; "confirmedFactors": number; "createdAt": string })[]

export type ControlAuthorityResponse = { "grants": ({ "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null })[]; "roles": (string)[]; "permissions": (string)[]; "deniedPermissions": (string)[]; "capabilities": ("session.read" | "profile.read.self" | "profile.update.self" | "activity.activate" | "activity.deactivate" | "market.catalog.browse" | "market.cart.manage" | "market.order.place" | "market.order.cancel" | "market.order.dispute" | "services.job.post" | "services.job.post.business" | "services.application.review" | "services.engagement.fund" | "services.job.apply" | "services.service.publish" | "services.engagement.deliver" | "services.earnings.receive" | "errands.request.create" | "errands.request.cancel" | "errands.request.track" | "market.product.draft" | "market.product.publish" | "market.inventory.manage" | "market.order.fulfil" | "market.invoice.issue" | "market.earnings.receive" | "logistics.pool.browse" | "logistics.assignment.accept" | "logistics.delivery.progress" | "logistics.delivery.complete" | "logistics.earnings.receive" | "business.create" | "business.verification.submit" | "business.update" | "wallet.read" | "wallet.withdraw" | "wallet.payout_account.bind" | "wallet.convert" | "messaging.thread.read" | "messaging.message.send" | "notification.read" | "admin.verification.review" | "admin.payment.review" | "admin.dispute.resolve" | "admin.account.suspend" | "admin.configuration.write" | "admin.configuration.read" | "admin.audit.read" | "admin.grant.read" | "admin.grant.manage" | "admin.user.read" | "admin.user.manage" | "admin.role.read" | "admin.role.manage" | "admin.case.read" | "admin.case.assign" | "admin.case.investigate" | "admin.case.recommend" | "admin.case.approve" | "admin.evidence.read" | "admin.report.read" | "admin.report.export" | "staff.support.handle" | "partner.referral.read" | "platform.engineering.access")[] }

export type OwnGrantsResponse = { "grants": ({ "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null })[]; "capabilities": ("session.read" | "profile.read.self" | "profile.update.self" | "activity.activate" | "activity.deactivate" | "market.catalog.browse" | "market.cart.manage" | "market.order.place" | "market.order.cancel" | "market.order.dispute" | "services.job.post" | "services.job.post.business" | "services.application.review" | "services.engagement.fund" | "services.job.apply" | "services.service.publish" | "services.engagement.deliver" | "services.earnings.receive" | "errands.request.create" | "errands.request.cancel" | "errands.request.track" | "market.product.draft" | "market.product.publish" | "market.inventory.manage" | "market.order.fulfil" | "market.invoice.issue" | "market.earnings.receive" | "logistics.pool.browse" | "logistics.assignment.accept" | "logistics.delivery.progress" | "logistics.delivery.complete" | "logistics.earnings.receive" | "business.create" | "business.verification.submit" | "business.update" | "wallet.read" | "wallet.withdraw" | "wallet.payout_account.bind" | "wallet.convert" | "messaging.thread.read" | "messaging.message.send" | "notification.read" | "admin.verification.review" | "admin.payment.review" | "admin.dispute.resolve" | "admin.account.suspend" | "admin.configuration.write" | "admin.configuration.read" | "admin.audit.read" | "admin.grant.read" | "admin.grant.manage" | "admin.user.read" | "admin.user.manage" | "admin.role.read" | "admin.role.manage" | "admin.case.read" | "admin.case.assign" | "admin.case.investigate" | "admin.case.recommend" | "admin.case.approve" | "admin.evidence.read" | "admin.report.read" | "admin.report.export" | "staff.support.handle" | "partner.referral.read" | "platform.engineering.access")[] }

export type ListGrantsResponse = ({ "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null })[]

export type CreateGrantRequest = { "email": string; "grantType": "admin" | "staff" | "partner" | "platform_engineering"; "scope": string; "departmentKey"?: string; "reason"?: string; "expiresAt"?: string }

export type CreateGrantResponse = { "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null }

export type RevokeGrantResponse = { "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null }

export type ListDepartmentsResponse = ({ "key": string; "name": string })[]

export type SetGrantDepartmentRequest = { "departmentKey": string; "reason"?: string }

export type SetGrantDepartmentResponse = { "id": string; "userId": string; "email": string | null; "userName"?: string | null; "grantType": string; "scope": string; "environment": "production" | "staging"; "grantedBy": string | null; "expiresAt": string | null; "revokedAt": string | null; "createdAt": string; "departmentKey"?: string | null; "departmentName"?: string | null }

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
  }
}
