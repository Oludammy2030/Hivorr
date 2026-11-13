import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"

export interface EvidenceView {
  readonly id: string
  readonly fileName: string
  readonly mimeType: string | null
  readonly sizeBytes: number | null
  readonly sha256: string | null
  readonly classification: string
  readonly status: string
  readonly supersedesId: string | null
  readonly uploadedByName: string | null
  readonly uploadedByEmail: string | null
  readonly uploadedAt: string
}

interface EvidenceRow {
  id: string
  file_name: string
  mime_type: string | null
  size_bytes: string | number | null
  sha256: string | null
  classification: string
  status: string
  supersedes_id: string | null
  uploaded_by_name: string | null
  uploaded_by_email: string | null
  uploaded_at: string
}

function toView(row: EvidenceRow): EvidenceView {
  return {
    id: row.id,
    fileName: row.file_name,
    mimeType: row.mime_type,
    sizeBytes: row.size_bytes === null ? null : Number(row.size_bytes),
    sha256: row.sha256,
    classification: row.classification,
    status: row.status,
    supersedesId: row.supersedes_id,
    uploadedByName: row.uploaded_by_name,
    uploadedByEmail: row.uploaded_by_email,
    uploadedAt: row.uploaded_at,
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function mapEvidenceError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to work with case evidence.",
        403,
      )
    case "P0002":
      throw new ApiError(
        "NOT_FOUND",
        "The case or evidence was not found.",
        404,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "That storage key already belongs to another evidence record.",
        409,
      )
    case "22023":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The evidence metadata is not valid.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The evidence operation failed.")
  }
}

@Injectable()
export class EvidenceService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async list(input: {
    accountId: string
    userId: string
    caseId: string
  }): Promise<readonly EvidenceView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<EvidenceRow>(
            "select * from admin.list_case_evidence($1, $2)",
            [input.userId, input.caseId],
          )
          return result.rows.map(toView)
        },
      )
    } catch (error) {
      mapEvidenceError(error)
    }
  }

  async add(input: {
    accountId: string
    userId: string
    caseId: string
    storageKey: string
    fileName: string
    mimeType?: string
    sizeBytes?: number
    sha256?: string
    classification?: string
    reason?: string
    context: RequestContext
  }): Promise<EvidenceView> {
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
          const result = await transaction.query<EvidenceRow>(
            "select * from admin.add_case_evidence($1, $2, $3, $4, $5, $6, $7, $8, $9)",
            [
              input.userId,
              input.caseId,
              input.storageKey,
              input.fileName,
              input.mimeType ?? null,
              input.sizeBytes ?? null,
              input.sha256 ?? null,
              input.classification ?? null,
              reason,
            ],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "case.evidence_added",
            targetType: "case",
            targetId: input.caseId,
            afterSummary: {
              evidenceId: row.id,
              fileName: row.file_name,
              sha256: row.sha256,
            },
            reason,
            capability: "admin.case.assign",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toView(row)
        },
      )
    } catch (error) {
      mapEvidenceError(error)
    }
  }

  async supersede(input: {
    accountId: string
    userId: string
    evidenceId: string
    replacementId: string
    reason?: string
    context: RequestContext
  }): Promise<EvidenceView> {
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
          const result = await transaction.query<EvidenceRow>(
            "select * from admin.supersede_case_evidence($1, $2, $3, $4)",
            [input.userId, input.evidenceId, input.replacementId, reason],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "case.evidence_superseded",
            targetType: "case_evidence",
            targetId: input.evidenceId,
            afterSummary: {
              replacementId: input.replacementId,
              supersedesId: row.supersedes_id,
            },
            reason,
            capability: "admin.case.assign",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toView(row)
        },
      )
    } catch (error) {
      mapEvidenceError(error)
    }
  }

  async recordAccess(input: {
    accountId: string
    userId: string
    evidenceId: string
    purpose: string
  }): Promise<void> {
    try {
      await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          await transaction.query(
            "select admin.record_evidence_access($1, $2, $3)",
            [input.userId, input.evidenceId, input.purpose],
          )
        },
      )
    } catch (error) {
      mapEvidenceError(error)
    }
  }
}
