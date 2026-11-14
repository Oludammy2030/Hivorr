import { Inject, Injectable } from "@nestjs/common"

import { ApiError, rateLimited } from "../../common/errors"
import { FixedWindowRateLimiter } from "../../common/rate-limiter"
import {
  API_CONFIG,
  type ApiConfig,
  type DeploymentEnvironment,
} from "../../config"
import { DatabaseService } from "../../db/database.service"
import {
  EMAIL_ADAPTER,
  type EmailAdapter,
} from "../../integrations/email/email.adapter"
import { buildStaffInviteEmail } from "../../integrations/email/templates/staff-invite"
import { hivorrMarkAttachment } from "../../integrations/email/assets/hivorr-mark"
import {
  createSessionToken,
  hashPassword,
  hashSessionToken,
  type RequestContext,
} from "../identity"
import { appendAudit } from "../platform"

export interface StaffView {
  readonly id: string
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly jobTitle: string | null
  readonly departmentKey: string | null
  readonly departmentName: string | null
  readonly engagementStatus: string
  readonly startedOn: string | null
  readonly endedOn: string | null
  readonly confirmedFactors: number
  readonly createdAt: string
}

export interface StaffInviteResult {
  readonly id: string
  /** Official company address that becomes the account on acceptance. */
  readonly email: string
  /** Personal address the invitation was delivered to. */
  readonly deliveryEmail: string
  readonly departmentKey: string | null
  readonly expiresAt: string
  readonly token: string
  readonly emailSent: boolean
}

export interface StaffInviteDetails {
  readonly email: string
  readonly jobTitle: string | null
  readonly departmentKey: string | null
  readonly expiresAt: string
}

export interface StaffStatusResult {
  readonly userId: string
  readonly engagementStatus: string
  readonly sessionsRevoked: number
  readonly grantsRevoked: number
  readonly permissionGrantsRevoked: number
}

export interface StaffDepartmentResult {
  readonly userId: string
  readonly departmentKey: string | null
}

export interface AttachStaffProfileResult {
  readonly userId: string
  readonly staffProfileId: string
  readonly email: string
  readonly departmentKey: string | null
}

function pgCode(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

interface DatabaseErrorMessages {
  readonly notFound?: string
  readonly conflict?: string
}

function mapDatabaseError(
  error: unknown,
  messages: DatabaseErrorMessages = {},
): never {
  switch (pgCode(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to manage staff.",
        403,
      )
    case "P0002":
      throw new ApiError(
        "NOT_FOUND",
        messages.notFound ?? "The staff record or invitation was not found.",
        404,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        messages.conflict ??
          "A pending invitation or account already exists for this email.",
        409,
      )
    case "22023":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The request is not valid for this staff change.",
        400,
      )
    default:
      throw error
  }
}

@Injectable()
export class StaffService {
  private readonly limiter = new FixedWindowRateLimiter()

  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
    @Inject(EMAIL_ADAPTER) private readonly email: EmailAdapter,
  ) {}

  async list(input: {
    accountId: string
    userId: string
    query: string
    status: string
    limit?: number
  }): Promise<readonly StaffView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<{
            id: string
            user_id: string
            email: string
            display_name: string | null
            job_title: string | null
            department_key: string | null
            department_name: string | null
            engagement_status: string
            started_on: string | null
            ended_on: string | null
            confirmed_factors: string
            created_at: string
          }>("select * from admin.list_staff($1, $2, $3)", [
            input.query,
            input.status,
            input.limit ?? 100,
          ])

          return result.rows.map((row) => ({
            id: row.id,
            userId: row.user_id,
            email: row.email,
            displayName: row.display_name,
            jobTitle: row.job_title,
            departmentKey: row.department_key,
            departmentName: row.department_name,
            engagementStatus: row.engagement_status,
            startedOn: row.started_on,
            endedOn: row.ended_on,
            confirmedFactors: Number(row.confirmed_factors),
            createdAt: row.created_at,
          }))
        },
      )
    } catch (error) {
      mapDatabaseError(error)
    }
  }

  async invite(input: {
    accountId: string
    userId: string
    context: RequestContext
    /** Official company address that becomes the account. */
    email: string
    /** Personal address for delivery. Defaults to the official address. */
    deliveryEmail?: string
    departmentKey?: string
    jobTitle?: string
    reason: string
  }): Promise<StaffInviteResult> {
    const token = createSessionToken()
    const tokenHash = hashSessionToken(token)
    const officialEmail = this.requireOfficialAddress(input.email)
    const deliveryEmail = (input.deliveryEmail ?? input.email)
      .trim()
      .toLowerCase()
    const domain = this.config.mail.staffEmailDomain
    try {
      const created = await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<{
            id: string
            email: string
            delivery_email: string
            department_key: string | null
            expires_at: string
          }>(
            "select * from admin.create_staff_invite($1, $2, $3, $4, $5, $6, null, $7)",
            [
              officialEmail,
              deliveryEmail,
              input.departmentKey ?? null,
              input.jobTitle ?? null,
              tokenHash,
              input.reason,
              domain,
            ],
          )
          const row = result.rows[0]

          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.staff_invite_created",
            targetType: "staff_invite",
            targetId: row.id,
            afterSummary: {
              email: row.email,
              deliveryEmail: row.delivery_email,
              departmentKey: row.department_key,
              expiresAt: row.expires_at,
            },
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
            reason: input.reason,
            capability: "admin.user.manage",
          })

          return {
            id: row.id,
            email: row.email,
            deliveryEmail: row.delivery_email,
            departmentKey: row.department_key,
            expiresAt: row.expires_at,
            token,
          }
        },
      )

      const emailSent = await this.deliverInvite(created, input.jobTitle)
      return { ...created, emailSent }
    } catch (error) {
      mapDatabaseError(error)
    }
  }

  /** Resolves a pending invitation for the acceptance page. */
  async inviteDetails(token: string, ip?: string): Promise<StaffInviteDetails> {
    this.limitInviteTraffic("lookup", ip)
    const row = await this.database.withTransaction({}, async (transaction) => {
      const result = await transaction.query<{
        email: string
        job_title: string | null
        department_key: string | null
        expires_at: string
      }>("select * from admin.get_staff_invite($1)", [hashSessionToken(token)])
      return result.rows[0]
    })

    if (!row) {
      throw new ApiError(
        "NOT_FOUND",
        "This invitation is no longer valid.",
        404,
      )
    }

    return {
      email: row.email,
      jobTitle: row.job_title,
      departmentKey: row.department_key,
      expiresAt: row.expires_at,
    }
  }

  /**
   * A staff identity must live on the domain Hivorr owns, so access can be
   * revoked by suspending the official mailbox. Personal addresses may only
   * receive the invitation.
   */
  private requireOfficialAddress(email: string): string {
    const normalized = email.trim().toLowerCase()
    const domain = this.config.mail.staffEmailDomain.toLowerCase()
    if (!normalized.endsWith(`@${domain}`)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        `A staff account must use an official @${domain} address. The personal address is only used to deliver the invitation.`,
        400,
      )
    }
    return normalized
  }

  /**
   * Delivery happens after the invitation commits. A provider failure must not
   * roll back the invitation or hide it: the control UI keeps the single-use
   * link so the administrator can still send it manually.
   */
  private async deliverInvite(
    invite: Omit<StaffInviteResult, "emailSent">,
    jobTitle?: string,
  ): Promise<boolean> {
    const { token, fromAddress, appOrigin } = this.config.mail
    if (!token || !fromAddress || !appOrigin) return false

    const link = `${appOrigin.replace(/\/$/, "")}/invite.html?token=${encodeURIComponent(invite.token)}`

    try {
      const email = buildStaffInviteEmail({
        to: invite.deliveryEmail,
        accountEmail: invite.email,
        link,
        expiresAt: invite.expiresAt,
        jobTitle,
      })

      await this.email.send({
        to: invite.deliveryEmail,
        subject: email.subject,
        text: email.text,
        html: email.html,
        images: [hivorrMarkAttachment()],
      })
      return true
    } catch {
      return false
    }
  }

  async setStatus(input: {
    accountId: string
    userId: string
    targetUserId: string
    context: RequestContext
    status: "suspended" | "active" | "offboarded"
    reason: string
  }): Promise<StaffStatusResult> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const before = await transaction.query<{ engagement_status: string }>(
            "select engagement_status from admin.staff_profiles where user_id = $1",
            [input.targetUserId],
          )
          const result = await transaction.query<{
            user_id: string
            engagement_status: string
            sessions_revoked: string
            grants_revoked: string
            permission_grants_revoked: string
          }>("select * from admin.set_staff_status($1, $2, $3)", [
            input.targetUserId,
            input.status,
            input.reason,
          ])
          const row = result.rows[0]

          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.staff_status_changed",
            targetType: "user",
            targetId: input.targetUserId,
            beforeSummary: before.rows[0] ?? undefined,
            afterSummary: {
              engagementStatus: row.engagement_status,
              sessionsRevoked: Number(row.sessions_revoked),
              grantsRevoked: Number(row.grants_revoked),
              permissionGrantsRevoked: Number(row.permission_grants_revoked),
            },
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
            reason: input.reason,
            capability: "admin.user.manage",
          })

          return {
            userId: row.user_id,
            engagementStatus: row.engagement_status,
            sessionsRevoked: Number(row.sessions_revoked),
            grantsRevoked: Number(row.grants_revoked),
            permissionGrantsRevoked: Number(row.permission_grants_revoked),
          }
        },
      )
    } catch (error) {
      mapDatabaseError(error)
    }
  }

  async setDepartment(input: {
    accountId: string
    userId: string
    targetUserId: string
    context: RequestContext
    departmentKey: string
    reason: string
  }): Promise<StaffDepartmentResult> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<{
            user_id: string
            department_key: string | null
          }>("select * from admin.set_staff_department($1, $2, $3)", [
            input.targetUserId,
            input.departmentKey,
            input.reason,
          ])
          const row = result.rows[0]

          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.staff_department_changed",
            targetType: "user",
            targetId: input.targetUserId,
            afterSummary: { departmentKey: row.department_key },
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
            reason: input.reason,
            capability: "admin.user.manage",
          })

          return {
            userId: row.user_id,
            departmentKey: row.department_key,
          }
        },
      )
    } catch (error) {
      mapDatabaseError(error)
    }
  }

  async attachExisting(input: {
    accountId: string
    userId: string
    context: RequestContext
    email: string
    departmentKey?: string
    jobTitle?: string
    reason: string
  }): Promise<AttachStaffProfileResult> {
    const officialEmail = this.requireOfficialAddress(input.email)

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<{
            user_id: string
            staff_profile_id: string
            email: string
            department_key: string | null
          }>("select * from admin.attach_staff_profile($1, $2, $3, $4)", [
            officialEmail,
            input.jobTitle ?? null,
            input.departmentKey ?? null,
            input.reason,
          ])
          const row = result.rows[0]

          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.staff_profile_attached",
            targetType: "user",
            targetId: row.user_id,
            afterSummary: {
              email: row.email,
              jobTitle: input.jobTitle ?? null,
              departmentKey: row.department_key,
            },
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
            reason: input.reason,
            capability: "admin.user.manage",
          })

          return {
            userId: row.user_id,
            staffProfileId: row.staff_profile_id,
            email: row.email,
            departmentKey: row.department_key,
          }
        },
      )
    } catch (error) {
      mapDatabaseError(error, {
        notFound: "No Hivorr account uses this email.",
        conflict: "This account is already a staff member.",
      })
    }
  }

  async acceptInvite(input: {
    environment: DeploymentEnvironment
    token: string
    password: string
    displayName?: string
    ip?: string
    userAgent?: string
    correlationId?: string
  }): Promise<{ email: string }> {
    this.limitInviteTraffic("accept", input.ip)

    const tokenHash = hashSessionToken(input.token)
    const passwordHash = await hashPassword(input.password)

    try {
      return await this.database.withTransaction({}, async (transaction) => {
        const result = await transaction.query<{
          user_id: string
          email: string
        }>("select * from admin.accept_staff_invite($1, $2, $3)", [
          tokenHash,
          passwordHash,
          input.displayName ?? null,
        ])
        const row = result.rows[0]

        await appendAudit(transaction.client, {
          actorType: "system",
          actorId: row.user_id,
          actorAudience: "app",
          environment: input.environment,
          action: "admin.staff_invite_accepted",
          targetType: "user",
          targetId: row.user_id,
          afterSummary: { email: row.email },
          ip: input.ip,
          userAgent: input.userAgent,
          correlationId: input.correlationId,
        })

        return { email: row.email }
      })
    } catch (error) {
      mapDatabaseError(error)
    }
  }

  /**
   * Invitation lookup and acceptance are unauthenticated, and acceptance hashes
   * the password before the token is checked, so an unbounded caller could force
   * expensive work. Apply the same per-IP authentication budget as sign-in.
   */
  private limitInviteTraffic(scope: string, ip: string | undefined): void {
    const result = this.limiter.check(
      `staff-invite:${scope}:ip:${ip ?? "unknown"}`,
      {
        windowMs: this.config.auth.rateLimitWindowMs,
        max: this.config.auth.ipMax,
      },
    )
    if (!result.allowed) {
      throw rateLimited(result.retryAfterSeconds)
    }
  }
}
