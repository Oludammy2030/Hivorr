import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"

export interface VerificationReviewView {
  readonly caseId: string
  readonly reference: string
  readonly title: string
  readonly lane: string
  readonly reviewStatus: string
  readonly caseStatus: string
  readonly priority: string
  readonly subjectType: string | null
  readonly subjectId: string | null
  readonly assigneeEmail: string | null
  readonly evidenceCount: number
  readonly createdAt: string
}

interface ReviewRow {
  case_id: string
  reference: string
  title: string
  lane: string
  review_status: string
  case_status: string
  priority: string
  subject_type: string | null
  subject_id: string | null
  assignee_email: string | null
  evidence_count: string | number
  created_at: string
}

function toView(row: ReviewRow): VerificationReviewView {
  return {
    caseId: row.case_id,
    reference: row.reference,
    title: row.title,
    lane: row.lane,
    reviewStatus: row.review_status,
    caseStatus: row.case_status,
    priority: row.priority,
    subjectType: row.subject_type,
    subjectId: row.subject_id,
    assigneeEmail: row.assignee_email,
    evidenceCount: Number(row.evidence_count),
    createdAt: row.created_at,
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function mapVerificationError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to review verification cases.",
        403,
      )
    case "P0002":
      throw new ApiError(
        "NOT_FOUND",
        "The verification case was not found.",
        404,
      )
    case "23514":
      throw new ApiError(
        "CONFLICT",
        "A verification decision needs at least one active evidence record.",
        409,
      )
    case "22023":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The verification decision is not valid.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The verification operation failed.")
  }
}

@Injectable()
export class VerificationService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async queue(input: {
    accountId: string
    userId: string
    status: string
  }): Promise<readonly VerificationReviewView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<ReviewRow>(
            "select * from admin.list_verification_queue($1, $2)",
            [input.userId, input.status],
          )
          return result.rows.map(toView)
        },
      )
    } catch (error) {
      mapVerificationError(error)
    }
  }

  async decide(input: {
    accountId: string
    userId: string
    caseId: string
    decision: string
    reason?: string
    context: RequestContext
  }): Promise<VerificationReviewView> {
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
          const result = await transaction.query<ReviewRow>(
            "select * from admin.record_verification_decision($1, $2, $3, $4)",
            [input.userId, input.caseId, input.decision, reason],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: `verification.${row.review_status}`,
            targetType: "case",
            targetId: input.caseId,
            afterSummary: {
              reference: row.reference,
              reviewStatus: row.review_status,
              caseStatus: row.case_status,
              evidenceCount: Number(row.evidence_count),
            },
            reason,
            capability: "admin.verification.review",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toView(row)
        },
      )
    } catch (error) {
      mapVerificationError(error)
    }
  }
}
