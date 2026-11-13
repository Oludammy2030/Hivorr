import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"

export type AccountAction = "suspend" | "reactivate" | "close" | "revoke_sessions"

export interface AccountActionView {
  readonly userId: string
  readonly status: string
  readonly sessionsRevoked: number
  readonly grantsRevoked: number
  readonly rolesRevoked: number
}

export interface AccountNoteView {
  readonly id: string
  readonly body: string
  readonly authorName: string | null
  readonly authorEmail: string | null
  readonly createdAt: string
}

export interface AccountTimelineEntry {
  readonly occurredAt: string
  readonly action: string
  readonly reason: string | null
  readonly actorName: string | null
  readonly actorEmail: string | null
}

interface ActionRow {
  user_id: string
  status: string
  sessions_revoked: number
  grants_revoked: number
  roles_revoked: number
}

interface NoteRow {
  id: string
  body: string
  author_name: string | null
  author_email: string | null
  created_at: string
}

interface TimelineRow {
  occurred_at: string
  action: string
  reason: string | null
  actor_name: string | null
  actor_email: string | null
}

const ACTION_LABELS: Readonly<Record<AccountAction, string>> = {
  suspend: "account.suspended",
  reactivate: "account.reactivated",
  close: "account.closed",
  revoke_sessions: "account.sessions_revoked",
}

function errorCode(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function errorMessageOf(error: unknown): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as { message?: unknown }).message)
  }
  return ""
}

function mapAccountError(error: unknown): never {
  const message = errorMessageOf(error)
  switch (errorCode(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        message.includes("self_account_action")
          ? "You cannot take this action on your own account."
          : "You do not have permission to govern accounts.",
        403,
      )
    case "P0002":
      throw new ApiError("NOT_FOUND", "The account was not found.", 404)
    case "23514":
      throw new ApiError(
        "CONFLICT",
        "The account is not in a state that allows this action.",
        409,
      )
    case "22023":
      if (message.includes("account_note_required")) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "A note needs at least three characters.",
          400,
        )
      }
      if (message.includes("account_reason_required")) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "A reason of at least five characters is required.",
          400,
        )
      }
      throw new ApiError(
        "VALIDATION_FAILED",
        "The requested account action is not valid.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The account action failed.")
  }
}

@Injectable()
export class AccountGovernanceService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async govern(input: {
    accountId: string
    userId: string
    targetUserId: string
    action: AccountAction
    reason?: string
    context: RequestContext
  }): Promise<AccountActionView> {
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
          const result = await transaction.query<ActionRow>(
            "select * from admin.govern_user($1, $2, $3, $4)",
            [input.userId, input.targetUserId, input.action, reason],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: ACTION_LABELS[input.action],
            targetType: "user",
            targetId: input.targetUserId,
            beforeSummary: undefined,
            afterSummary: {
              status: row.status,
              sessionsRevoked: row.sessions_revoked,
              grantsRevoked: row.grants_revoked,
              rolesRevoked: row.roles_revoked,
            },
            reason,
            capability: "admin.user.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return {
            userId: row.user_id,
            status: row.status,
            sessionsRevoked: row.sessions_revoked,
            grantsRevoked: row.grants_revoked,
            rolesRevoked: row.roles_revoked,
          }
        },
      )
    } catch (error) {
      mapAccountError(error)
    }
  }

  async addNote(input: {
    accountId: string
    userId: string
    targetUserId: string
    body: string
    context: RequestContext
  }): Promise<AccountNoteView> {
    const body = input.body.trim()
    if (body.length < 3) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A note needs at least three characters.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<{
            id: string
            body: string
            author_user_id: string | null
            created_at: string
          }>("select * from admin.add_user_note($1, $2, $3)", [
            input.userId,
            input.targetUserId,
            body,
          ])
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "account.note_added",
            targetType: "user",
            targetId: input.targetUserId,
            afterSummary: { noteId: row.id },
            reason: body,
            capability: "admin.user.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return {
            id: row.id,
            body: row.body,
            authorName: null,
            authorEmail: null,
            createdAt: row.created_at,
          }
        },
      )
    } catch (error) {
      mapAccountError(error)
    }
  }

  async listNotes(input: {
    accountId: string
    userId: string
    targetUserId: string
  }): Promise<readonly AccountNoteView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<NoteRow>(
            "select * from admin.list_user_notes($1, $2)",
            [input.userId, input.targetUserId],
          )
          return result.rows.map((row) => ({
            id: row.id,
            body: row.body,
            authorName: row.author_name,
            authorEmail: row.author_email,
            createdAt: row.created_at,
          }))
        },
      )
    } catch (error) {
      mapAccountError(error)
    }
  }

  async timeline(input: {
    accountId: string
    userId: string
    targetUserId: string
  }): Promise<readonly AccountTimelineEntry[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<TimelineRow>(
            "select * from admin.list_account_timeline($1, $2)",
            [input.userId, input.targetUserId],
          )
          return result.rows.map((row) => ({
            occurredAt: row.occurred_at,
            action: row.action,
            reason: row.reason,
            actorName: row.actor_name,
            actorEmail: row.actor_email,
          }))
        },
      )
    } catch (error) {
      mapAccountError(error)
    }
  }
}
