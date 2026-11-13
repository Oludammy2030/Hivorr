import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"

export interface RoleView {
  readonly key: string
  readonly name: string
  readonly description: string | null
  readonly system: boolean
  readonly permissions: readonly string[]
  readonly activeAssignments: number
}

export type RoleScopeType = "platform" | "department" | "organisation"

export const ROLE_SCOPE_TYPES: readonly RoleScopeType[] = [
  "platform",
  "department",
  "organisation",
]

export interface RoleAssignmentView {
  readonly id: string
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly roleKey: string
  readonly roleName: string
  readonly scopeType: string
  readonly scopeId: string | null
  readonly expiresAt: string | null
  readonly revokedAt: string | null
  readonly createdAt: string
  readonly grantedBy: string | null
  readonly reason: string | null
}

export interface RoleScopeTarget {
  readonly id: string
  readonly name: string
}

export interface AssignableStaff {
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly departmentKey: string | null
  readonly departmentName: string | null
}

interface RoleRow {
  key: string
  name: string
  description: string | null
  system: boolean
  permissions: string[] | null
  active_assignments: string | number
}

interface AssignmentRow {
  id: string
  user_id: string
  email: string
  display_name: string | null
  role_key: string
  role_name: string
  scope_type: string
  scope_id: string | null
  expires_at: string | null
  revoked_at: string | null
  created_at: string
  granted_by: string | null
  reason: string | null
}

export interface AssignRoleInput {
  readonly email: string
  readonly roleKey: string
  readonly scopeType: RoleScopeType
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

function toRoleView(row: RoleRow): RoleView {
  return {
    key: row.key,
    name: row.name,
    description: row.description,
    system: row.system,
    permissions: row.permissions ?? [],
    activeAssignments: Number(row.active_assignments),
  }
}

function toAssignmentView(row: AssignmentRow): RoleAssignmentView {
  return {
    id: row.id,
    userId: row.user_id,
    email: row.email,
    displayName: row.display_name,
    roleKey: row.role_key,
    roleName: row.role_name,
    scopeType: row.scope_type,
    scopeId: row.scope_id,
    expiresAt: row.expires_at,
    revokedAt: row.revoked_at,
    createdAt: row.created_at,
    grantedBy: row.granted_by,
    reason: row.reason,
  }
}

function mapRoleError(error: unknown): never {
  const message = errorMessage(error)
  switch (errorCode(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        message.includes("self_role_change")
          ? "You cannot change your own role assignments."
          : "You do not have permission to manage roles.",
        403,
      )
    case "P0002":
      if (message.includes("role_user_not_found")) {
        throw new ApiError("NOT_FOUND", "No account matches that email.", 404)
      }
      if (message.includes("role_assignment_not_found")) {
        throw new ApiError(
          "NOT_FOUND",
          "The role assignment was not found or is already revoked.",
          404,
        )
      }
      throw new ApiError("NOT_FOUND", "The role was not found.", 404)
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "That role is already assigned to this person at the same scope.",
        409,
      )
    case "23514":
      throw new ApiError(
        "CONFLICT",
        "The last active role manager cannot be removed.",
        409,
      )
    case "22023":
      if (message.includes("role_reason_required")) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "A reason is required to change a role.",
          400,
        )
      }
      throw new ApiError(
        "VALIDATION_FAILED",
        "The role, scope or expiry is not valid.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The role operation failed.")
  }
}

@Injectable()
export class RolesService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async listRoles(input: {
    accountId: string
    userId: string
    environment: string
  }): Promise<readonly RoleView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<RoleRow>(
            "select * from admin.list_roles($1, $2)",
            [input.userId, input.environment],
          )
          return result.rows.map(toRoleView)
        },
      )
    } catch (error) {
      mapRoleError(error)
    }
  }

  async listAssignments(input: {
    accountId: string
    userId: string
    environment: string
  }): Promise<readonly RoleAssignmentView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<AssignmentRow>(
            "select * from admin.list_role_assignments($1, $2)",
            [input.userId, input.environment],
          )
          return result.rows.map(toAssignmentView)
        },
      )
    } catch (error) {
      mapRoleError(error)
    }
  }

  async scopeTargets(input: {
    accountId: string
    userId: string
    scopeType: string
  }): Promise<readonly RoleScopeTarget[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<RoleScopeTarget>(
            "select id, name from admin.list_role_scope_targets($1, $2)",
            [input.userId, input.scopeType],
          )
          return result.rows.map((row) => ({ id: row.id, name: row.name }))
        },
      )
    } catch (error) {
      mapRoleError(error)
    }
  }

  async listAssignableStaff(input: {
    accountId: string
    userId: string
  }): Promise<readonly AssignableStaff[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<{
            user_id: string
            email: string
            display_name: string | null
            department_key: string | null
            department_name: string | null
          }>("select * from admin.list_assignable_staff($1)", [input.userId])
          return result.rows.map((row) => ({
            userId: row.user_id,
            email: row.email,
            displayName: row.display_name,
            departmentKey: row.department_key,
            departmentName: row.department_name,
          }))
        },
      )
    } catch (error) {
      mapRoleError(error)
    }
  }

  async assign(
    input: AssignRoleInput & {
      accountId: string
      userId: string
      environment: string
      context: RequestContext
    },
  ): Promise<RoleAssignmentView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 3) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason is required to change a role.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<AssignmentRow>(
            "select * from admin.assign_role($1, $2, $3, $4, $5, $6, $7, $8)",
            [
              input.userId,
              input.email,
              input.roleKey,
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
            action: "identity.role_assigned",
            targetType: "role_assignment",
            targetId: row.id,
            afterSummary: {
              roleKey: row.role_key,
              scopeType: row.scope_type,
              scopeId: row.scope_id,
              userId: row.user_id,
              expiresAt: row.expires_at,
            },
            reason,
            capability: "admin.role.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toAssignmentView(row)
        },
      )
    } catch (error) {
      mapRoleError(error)
    }
  }

  async revoke(input: {
    accountId: string
    userId: string
    assignmentId: string
    reason?: string
    environment: string
    context: RequestContext
  }): Promise<RoleAssignmentView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 3) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason is required to change a role.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<AssignmentRow>(
            "select * from admin.revoke_role($1, $2, $3, $4)",
            [input.userId, input.assignmentId, reason, input.environment],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "identity.role_revoked",
            targetType: "role_assignment",
            targetId: row.id,
            beforeSummary: { revokedAt: null },
            afterSummary: {
              roleKey: row.role_key,
              scopeType: row.scope_type,
              revokedAt: row.revoked_at,
            },
            reason,
            capability: "admin.role.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toAssignmentView(row)
        },
      )
    } catch (error) {
      mapRoleError(error)
    }
  }
}
