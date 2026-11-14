import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"

/**
 * Access denials (F-A-02).
 *
 * A denial removes one governance permission from one person in one scope. It
 * is the negative of a role assignment and is revoked, never deleted, so the
 * row keeps its history.
 */
export interface AccessDenialView {
  readonly id: string
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly permissionKey: string
  readonly scopeType: string | null
  readonly scopeId: string | null
  readonly reason: string
  readonly expiresAt: string | null
  readonly createdAt: string
  readonly createdBy: string | null
  readonly revokedAt: string | null
  readonly revokedReason: string | null
}

export type DenialScopeType = "platform" | "department" | "organisation"

interface DenialRow {
  id: string
  user_id: string
  email: string
  display_name: string | null
  permission_key: string
  scope_type: string | null
  scope_id: string | null
  reason: string
  expires_at: string | null
  created_at: string
  created_by: string | null
  revoked_at: string | null
  revoked_reason: string | null
}

export interface CreateDenialInput {
  readonly email: string
  readonly permissionKey: string
  readonly scopeType: DenialScopeType
  readonly scopeId?: string | null
  readonly expiresAt?: string | null
  readonly reason?: string
}

function errorMessage(error: unknown): string {
  if (typeof error === "object" && error !== null && "message" in error) {
    return String((error as { message?: unknown }).message)
  }
  return ""
}

function errorCode(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function toDenialView(row: DenialRow): AccessDenialView {
  return {
    id: row.id,
    userId: row.user_id,
    email: row.email,
    displayName: row.display_name,
    permissionKey: row.permission_key,
    scopeType: row.scope_type,
    scopeId: row.scope_id,
    reason: row.reason,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    createdBy: row.created_by,
    revokedAt: row.revoked_at,
    revokedReason: row.revoked_reason,
  }
}

function mapDenialError(error: unknown): never {
  const message = errorMessage(error)
  switch (errorCode(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        message.includes("self_denial")
          ? "You cannot change your own access denials."
          : "You do not have permission to manage access denials.",
        403,
      )
    case "P0002":
      if (message.includes("denial_user_not_found")) {
        throw new ApiError("NOT_FOUND", "No account matches that email.", 404)
      }
      if (message.includes("denial_permission_not_found")) {
        throw new ApiError("NOT_FOUND", "That permission was not found.", 404)
      }
      throw new ApiError(
        "NOT_FOUND",
        "The denial was not found or is already revoked.",
        404,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "That permission is already denied for this person at the same scope.",
        409,
      )
    case "23514":
      throw new ApiError(
        "CONFLICT",
        "The last platform holder of that permission cannot be denied.",
        409,
      )
    case "22023":
      if (message.includes("denial_reason_required")) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "A reason is required to deny or lift a permission.",
          400,
        )
      }
      throw new ApiError(
        "VALIDATION_FAILED",
        "The permission, scope or expiry is not valid.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The access denial operation failed.")
  }
}

@Injectable()
export class DenialsService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async list(input: {
    accountId: string
    userId: string
    environment: string
  }): Promise<readonly AccessDenialView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<DenialRow>(
            "select * from admin.list_access_denials($1, $2)",
            [input.userId, input.environment],
          )
          return result.rows.map(toDenialView)
        },
      )
    } catch (error) {
      mapDenialError(error)
    }
  }

  async create(
    input: CreateDenialInput & {
      accountId: string
      userId: string
      environment: string
      context: RequestContext
    },
  ): Promise<AccessDenialView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 3) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason is required to deny or lift a permission.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<DenialRow>(
            "select * from admin.create_access_denial($1, $2, $3, $4, $5, $6, $7, $8)",
            [
              input.userId,
              input.email,
              input.permissionKey,
              input.scopeType,
              input.scopeId ?? null,
              input.expiresAt ?? null,
              reason,
              input.environment,
            ],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.access_denied",
            targetType: "access_denial",
            targetId: row.id,
            afterSummary: {
              userId: row.user_id,
              permissionKey: row.permission_key,
              scopeType: row.scope_type,
              scopeId: row.scope_id,
              expiresAt: row.expires_at,
            },
            reason,
            capability: "admin.role.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toDenialView(row)
        },
      )
    } catch (error) {
      mapDenialError(error)
    }
  }

  async revoke(input: {
    accountId: string
    userId: string
    denialId: string
    reason?: string
    environment: string
    context: RequestContext
  }): Promise<AccessDenialView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 3) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason is required to deny or lift a permission.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<DenialRow>(
            "select * from admin.revoke_access_denial($1, $2, $3, $4)",
            [input.userId, input.denialId, reason, input.environment],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "admin.access_denial_revoked",
            targetType: "access_denial",
            targetId: row.id,
            beforeSummary: { revokedAt: null },
            afterSummary: {
              userId: row.user_id,
              permissionKey: row.permission_key,
              scopeType: row.scope_type,
              revokedAt: row.revoked_at,
              revokedReason: row.revoked_reason,
            },
            reason,
            capability: "admin.role.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toDenialView(row)
        },
      )
    } catch (error) {
      mapDenialError(error)
    }
  }
}
