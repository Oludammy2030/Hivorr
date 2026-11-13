import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"

export interface ApprovalRequestView {
  readonly id: string
  readonly reference: string
  readonly actionType: string
  readonly targetType: string
  readonly targetId: string
  readonly status: string
  readonly reason: string
  readonly requesterUserId: string
  readonly requesterName: string | null
  readonly requesterEmail: string | null
  readonly createdAt: string
  readonly decidedAt: string | null
}

interface ApprovalRow {
  id: string
  reference: string
  action_type: string
  target_type: string
  target_id: string
  status: string
  reason: string
  requester_user_id: string
  requester_name: string | null
  requester_email: string | null
  created_at: string
  decided_at: string | null
}

function toView(row: ApprovalRow): ApprovalRequestView {
  return {
    id: row.id,
    reference: row.reference,
    actionType: row.action_type,
    targetType: row.target_type,
    targetId: row.target_id,
    status: row.status,
    reason: row.reason,
    requesterUserId: row.requester_user_id,
    requesterName: row.requester_name,
    requesterEmail: row.requester_email,
    createdAt: row.created_at,
    decidedAt: row.decided_at,
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function messageOf(error: unknown): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as { message?: unknown }).message)
  }
  return ""
}

function mapApprovalError(error: unknown): never {
  const message = messageOf(error)
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        message.includes("self_decision")
          ? "You cannot decide your own approval request."
          : "You do not have permission to work with approvals.",
        403,
      )
    case "P0002":
      throw new ApiError(
        "NOT_FOUND",
        "The request or target was not found.",
        404,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "A pending request already exists for this action and target.",
        409,
      )
    case "23514":
      throw new ApiError(
        "CONFLICT",
        "The request has already been decided.",
        409,
      )
    case "22023":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The request is not valid for this approval action.",
        400,
      )
    case "22P02":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The target id is not valid.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The approval action failed.")
  }
}

@Injectable()
export class ApprovalsService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async list(input: {
    accountId: string
    userId: string
  }): Promise<readonly ApprovalRequestView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<ApprovalRow>(
            "select * from admin.list_approval_requests($1)",
            [input.userId],
          )
          return result.rows.map(toView)
        },
      )
    } catch (error) {
      mapApprovalError(error)
    }
  }

  async request(input: {
    accountId: string
    userId: string
    actionType: string
    targetType: string
    targetId: string
    reason?: string
    context: RequestContext
  }): Promise<ApprovalRequestView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 5) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason of at least five characters is required.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<ApprovalRow>(
            "select * from admin.request_approval($1, $2, $3, $4, $5)",
            [
              input.userId,
              input.actionType,
              input.targetType,
              input.targetId,
              reason,
            ],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "approval.requested",
            targetType: "user",
            targetId: input.targetId,
            afterSummary: {
              requestId: row.id,
              actionType: row.action_type,
              reference: row.reference,
            },
            reason,
            capability: "admin.user.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toView(row)
        },
      )
    } catch (error) {
      mapApprovalError(error)
    }
  }

  async decide(input: {
    accountId: string
    userId: string
    requestId: string
    decision: string
    reason?: string
    context: RequestContext
  }): Promise<ApprovalRequestView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 5) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason of at least five characters is required.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<ApprovalRow>(
            "select * from admin.decide_approval($1, $2, $3, $4)",
            [input.userId, input.requestId, input.decision, reason],
          )
          const row = result.rows[0]

          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action:
              input.decision === "approve"
                ? "approval.approved"
                : "approval.rejected",
            targetType: "user",
            targetId: row.target_id,
            afterSummary: {
              requestId: row.id,
              reference: row.reference,
              status: row.status,
            },
            reason,
            capability: "admin.approval.decide",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })

          if (
            input.decision === "approve" &&
            row.action_type === "account.closure"
          ) {
            await appendAudit(transaction.client, {
              actorType: "admin",
              actorId: input.userId,
              actorAudience: input.context.audience,
              environment: input.context.environment,
              action: "account.closed",
              targetType: "user",
              targetId: row.target_id,
              afterSummary: { requestId: row.id, reference: row.reference },
              reason: row.reason,
              capability: "admin.approval.decide",
              ip: input.context.ip,
              userAgent: input.context.userAgent,
              correlationId: input.context.correlationId,
            })
          }

          return toView(row)
        },
      )
    } catch (error) {
      mapApprovalError(error)
    }
  }
}
