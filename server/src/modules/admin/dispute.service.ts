import { Inject, Injectable } from "@nestjs/common"
import type { Dispute, DisputeStatus } from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"
import { EvidenceService, type EvidenceView } from "./evidence.service"

/**
 * Typed dispute record (EP-02-036).
 *
 * The table belongs to the admin module, matching the schema ownership in the
 * database rules and ARCHITECTURE §9.13. Reads and writes go through the
 * permission-checked `admin.*` functions; the API role has no table grant.
 *
 * Statuses are procedural only. There is no resolved, refunded or closed state
 * and no method that moves money: those outcomes are BD-D03.
 */
export interface OpenDisputeInput {
  readonly accountId: string
  readonly userId: string
  readonly caseId: string
  readonly activityId: string
  readonly activityRef: string
  readonly openedByAccountId: string
  readonly respondentAccountId?: string | null
  readonly currency: string
  readonly claimedAmount: string | number
  readonly escrowId?: string | null
  readonly reason: string
  readonly context: RequestContext
}

export interface DisputeStatusInput {
  readonly accountId: string
  readonly userId: string
  readonly disputeId: string
  readonly status: string
  readonly reason: string
  readonly context: RequestContext
}

export interface DisputeEvidenceAccessInput {
  readonly accountId: string
  readonly userId: string
  readonly disputeId: string
  readonly evidenceId: string
  readonly purpose: string
  readonly context: RequestContext
}

interface DisputeRow {
  id: string
  reference: string
  case_id: string
  case_reference: string
  case_status: string
  escrow_id: string | null
  activity_id: string
  activity_ref: string
  opened_by_account_id: string
  respondent_account_id: string | null
  currency: string
  claimed_amount: string | number
  status: string
  created_at: string
  updated_at: string
}

function toDispute(row: DisputeRow): Dispute {
  return {
    id: row.id,
    reference: row.reference,
    caseId: row.case_id,
    caseReference: row.case_reference,
    caseStatus: row.case_status,
    escrowId: row.escrow_id,
    activityId: row.activity_id as Dispute["activityId"],
    activityRef: row.activity_ref,
    openedByAccountId: row.opened_by_account_id,
    respondentAccountId: row.respondent_account_id,
    currency: row.currency,
    claimedAmount: String(row.claimed_amount),
    status: row.status as DisputeStatus,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function messageOf(error: unknown): string | undefined {
  return error instanceof Error ? error.message : undefined
}

function mapDisputeError(error: unknown): never {
  const message = messageOf(error)
  if (message?.includes("dispute_status_transition_invalid")) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "That dispute status transition is not defined.",
      400,
    )
  }
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to work this dispute.",
        403,
      )
    case "P0002":
      throw new ApiError("NOT_FOUND", "The dispute was not found.", 404)
    case "22023":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The dispute request is not valid.",
        400,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "A dispute already exists for this case.",
        409,
      )
    case "23503":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The case, account, escrow or staff member does not exist.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The dispute operation failed.")
  }
}

@Injectable()
export class DisputeService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(EvidenceService) private readonly evidence: EvidenceService,
  ) {}

  async open(input: OpenDisputeInput): Promise<Dispute> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<DisputeRow>(
            `select * from admin.open_dispute(
               $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
             )`,
            [
              input.userId,
              input.caseId,
              input.activityId,
              input.activityRef,
              input.openedByAccountId,
              input.respondentAccountId ?? null,
              input.currency,
              input.claimedAmount,
              input.escrowId ?? null,
              input.reason,
            ],
          )
          const row = result.rows[0]
          if (!row) throw new Error("The dispute insert returned no row.")
          const dispute = toDispute(row)

          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.dispute_opened",
            targetType: "dispute",
            targetId: dispute.id,
            afterSummary: {
              reference: dispute.reference,
              caseId: dispute.caseId,
              activityId: dispute.activityId,
              currency: dispute.currency,
              claimedAmount: dispute.claimedAmount,
              status: dispute.status,
            },
            reason: input.reason,
            capability: "admin.dispute.resolve",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })

          return dispute
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapDisputeError(error)
    }
  }

  async list(input: {
    accountId: string
    userId: string
    caseId?: string
  }): Promise<Dispute[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<DisputeRow>(
            "select * from admin.list_disputes($1, $2)",
            [input.userId, input.caseId ?? null],
          )
          return result.rows.map(toDispute)
        },
      )
    } catch (error) {
      mapDisputeError(error)
    }
  }

  async get(input: {
    accountId: string
    userId: string
    disputeId: string
  }): Promise<Dispute> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<DisputeRow>(
            "select * from admin.dispute_view($1, $2)",
            [input.userId, input.disputeId],
          )
          const row = result.rows[0]
          if (!row) {
            throw new ApiError("NOT_FOUND", "The dispute was not found.", 404)
          }
          return toDispute(row)
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapDisputeError(error)
    }
  }

  async setStatus(input: DisputeStatusInput): Promise<Dispute> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<DisputeRow>(
            "select * from admin.set_dispute_status($1, $2, $3, $4)",
            [input.userId, input.disputeId, input.status, input.reason],
          )
          const row = result.rows[0]
          if (!row) throw new Error("The dispute update returned no row.")
          const dispute = toDispute(row)

          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.dispute_status_changed",
            targetType: "dispute",
            targetId: dispute.id,
            afterSummary: {
              reference: dispute.reference,
              status: dispute.status,
            },
            reason: input.reason,
            capability: "admin.dispute.resolve",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })

          return dispute
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapDisputeError(error)
    }
  }

  /** Evidence metadata for the dispute's case, read through CP-017. */
  async listEvidence(input: {
    accountId: string
    userId: string
    disputeId: string
  }): Promise<readonly EvidenceView[]> {
    const dispute = await this.get(input)
    return this.evidence.list({
      accountId: input.accountId,
      userId: input.userId,
      caseId: dispute.caseId,
    })
  }

  /**
   * Records that a staff member accessed one evidence item through this dispute.
   * The object URL is not issued here; signed access remains `EP-02-012`.
   */
  async recordEvidenceAccess(input: DisputeEvidenceAccessInput): Promise<void> {
    try {
      await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          await transaction.query(
            "select admin.record_dispute_evidence_access($1, $2, $3, $4)",
            [input.userId, input.disputeId, input.evidenceId, input.purpose],
          )
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.dispute_evidence_accessed",
            targetType: "case_evidence",
            targetId: input.evidenceId,
            afterSummary: { disputeId: input.disputeId },
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
        },
      )
    } catch (error) {
      if (error instanceof ApiError) throw error
      mapDisputeError(error)
    }
  }
}
