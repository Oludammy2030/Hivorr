import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"

export interface CaseView {
  readonly id: string
  readonly reference: string
  readonly caseType: string
  readonly title: string
  readonly description: string | null
  readonly priority: string
  readonly severity: string
  readonly status: string
  readonly queueKey: string | null
  readonly assigneeId: string | null
  readonly assigneeName: string | null
  readonly assigneeEmail: string | null
  readonly departmentName: string | null
  readonly createdAt: string
  readonly updatedAt: string
  readonly closedAt: string | null
}

export interface CaseEventView {
  readonly id: string
  readonly eventType: string
  readonly summary: string
  readonly actorName: string | null
  readonly actorEmail: string | null
  readonly occurredAt: string
}

interface CaseRow {
  id: string
  reference: string
  case_type: string
  title: string
  description: string | null
  priority: string
  severity: string
  status: string
  queue_key: string | null
  assignee_id: string | null
  assignee_name: string | null
  assignee_email: string | null
  department_name: string | null
  created_at: string
  updated_at: string
  closed_at: string | null
}

interface EventRow {
  id: string
  event_type: string
  summary: string
  actor_name: string | null
  actor_email: string | null
  occurred_at: string
}

function toCase(row: CaseRow): CaseView {
  return {
    id: row.id,
    reference: row.reference,
    caseType: row.case_type,
    title: row.title,
    description: row.description,
    priority: row.priority,
    severity: row.severity,
    status: row.status,
    queueKey: row.queue_key,
    assigneeId: row.assignee_id,
    assigneeName: row.assignee_name,
    assigneeEmail: row.assignee_email,
    departmentName: row.department_name,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    closedAt: row.closed_at,
  }
}

function toEvent(row: EventRow): CaseEventView {
  return {
    id: row.id,
    eventType: row.event_type,
    summary: row.summary,
    actorName: row.actor_name,
    actorEmail: row.actor_email,
    occurredAt: row.occurred_at,
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function mapCaseError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to work with cases.",
        403,
      )
    case "P0002":
      throw new ApiError(
        "NOT_FOUND",
        "The case or the account was not found.",
        404,
      )
    case "22023":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The case request is not valid.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The case operation failed.")
  }
}

@Injectable()
export class CasesService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async list(input: {
    accountId: string
    userId: string
    status: string
    caseType: string
    query: string
  }): Promise<readonly CaseView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<CaseRow>(
            "select * from admin.list_cases($1, $2, $3, $4)",
            [input.userId, input.status, input.caseType, input.query],
          )
          return result.rows.map(toCase)
        },
      )
    } catch (error) {
      mapCaseError(error)
    }
  }

  async create(input: {
    accountId: string
    userId: string
    caseType: string
    title: string
    description?: string
    priority: string
    severity: string
    queueKey?: string
    reason?: string
    context: RequestContext
  }): Promise<CaseView> {
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
          const result = await transaction.query<CaseRow>(
            "select * from admin.create_case($1, $2, $3, $4, $5, $6, $7, $8)",
            [
              input.userId,
              input.caseType,
              input.title,
              input.description ?? null,
              input.priority,
              input.severity,
              input.queueKey ?? null,
              reason,
            ],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "case.created",
            targetType: "case",
            targetId: row.id,
            afterSummary: {
              reference: row.reference,
              caseType: row.case_type,
              priority: row.priority,
            },
            reason,
            capability: "admin.case.assign",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toCase(row)
        },
      )
    } catch (error) {
      mapCaseError(error)
    }
  }

  async events(input: {
    accountId: string
    userId: string
    caseId: string
  }): Promise<readonly CaseEventView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<EventRow>(
            "select * from admin.list_case_events($1, $2)",
            [input.userId, input.caseId],
          )
          return result.rows.map(toEvent)
        },
      )
    } catch (error) {
      mapCaseError(error)
    }
  }

  async addEvent(input: {
    accountId: string
    userId: string
    caseId: string
    summary: string
    context: RequestContext
  }): Promise<CaseEventView> {
    const summary = input.summary.trim()
    if (summary.length < 3) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A case note needs at least three characters.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<EventRow>(
            "select * from admin.add_case_event($1, $2, 'note', $3)",
            [input.userId, input.caseId, summary],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "case.note_added",
            targetType: "case",
            targetId: input.caseId,
            afterSummary: { eventId: row.id },
            reason: undefined,
            capability: "admin.case.assign",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toEvent(row)
        },
      )
    } catch (error) {
      mapCaseError(error)
    }
  }

  async assign(input: {
    accountId: string
    userId: string
    caseId: string
    email?: string
    queueKey?: string
    context: RequestContext
  }): Promise<CaseView> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<CaseRow>(
            "select * from admin.assign_case($1, $2, $3, $4)",
            [
              input.userId,
              input.caseId,
              input.email ?? null,
              input.queueKey ?? null,
            ],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "case.assigned",
            targetType: "case",
            targetId: row.id,
            afterSummary: {
              assigneeEmail: row.assignee_email,
              queueKey: row.queue_key,
            },
            reason: undefined,
            capability: "admin.case.assign",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toCase(row)
        },
      )
    } catch (error) {
      mapCaseError(error)
    }
  }

  async setStatus(input: {
    accountId: string
    userId: string
    caseId: string
    status: string
    reason?: string
    context: RequestContext
  }): Promise<CaseView> {
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
          const result = await transaction.query<CaseRow>(
            "select * from admin.set_case_status($1, $2, $3, $4)",
            [input.userId, input.caseId, input.status, reason],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "case.status_changed",
            targetType: "case",
            targetId: row.id,
            afterSummary: { status: row.status },
            reason,
            capability: "admin.case.assign",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toCase(row)
        },
      )
    } catch (error) {
      mapCaseError(error)
    }
  }
}
