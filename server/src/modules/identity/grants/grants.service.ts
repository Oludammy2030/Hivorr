import { Inject, Injectable } from "@nestjs/common"
import type { EnvironmentId } from "@hivorr/shared"
import type { PoolClient } from "pg"

import { ApiError } from "../../../common/errors"
import { DatabaseService } from "../../../db/database.service"
import {
  computeCapabilities,
  type CapabilityId,
  type GrantId,
} from "../../../domain/capabilities"
import { appendAudit } from "../../platform"
import {
  GRANT_SCOPES,
  GRANT_TYPES,
  grantScopeIsValid,
  type GrantType,
} from "../domain/identity"
import {
  IdentityService,
  type RequestContext,
  type SessionResult,
} from "../identity.service"

export { GRANT_SCOPES, GRANT_TYPES }
export type { GrantType }

export interface GrantView {
  readonly id: string
  readonly userId: string
  readonly email: string | null
  readonly grantType: string
  readonly scope: string
  readonly environment: EnvironmentId
  readonly grantedBy: string | null
  readonly expiresAt: string | null
  readonly revokedAt: string | null
  readonly createdAt: string
}

export interface OwnGrantsView {
  readonly grants: readonly GrantView[]
  readonly capabilities: readonly CapabilityId[]
}

export interface CreateGrantInput {
  readonly email: string
  readonly grantType: GrantType
  readonly scope: string
  readonly reason?: string
  readonly expiresAt?: string
}

interface GrantRow {
  id: string
  user_id: string
  email: string | null
  grant_type: string
  scope: string
  environment: EnvironmentId
  granted_by: string | null
  expires_at: string | null
  revoked_at: string | null
  created_at: string
}

interface Access {
  readonly session: SessionResult
  readonly grants: readonly GrantView[]
  readonly capabilities: ReadonlySet<CapabilityId>
}

function toGrantId(scope: string): GrantId | undefined {
  switch (scope) {
    case "admin.audit.read":
    case "admin.grant.read":
    case "admin.grant.manage":
    case "staff.support.handle":
    case "partner.referral.read":
    case "platform.engineering":
      return scope
    default:
      return undefined
  }
}

function isActive(grant: GrantView): boolean {
  if (grant.revokedAt) return false
  return !grant.expiresAt || new Date(grant.expiresAt).getTime() > Date.now()
}

function toView(row: GrantRow): GrantView {
  return {
    id: row.id,
    userId: row.user_id,
    email: row.email,
    grantType: row.grant_type,
    scope: row.scope,
    environment: row.environment,
    grantedBy: row.granted_by,
    expiresAt: row.expires_at,
    revokedAt: row.revoked_at,
    createdAt: row.created_at,
  }
}

function grantViewColumns(): string {
  return `id, user_id, null::text as email, grant_type, scope, environment,
          granted_by, expires_at, revoked_at, created_at`
}

function mapGrantError(error: unknown): Error {
  const code =
    typeof error === "object" && error !== null && "code" in error
      ? (error as { code?: string }).code
      : undefined
  switch (code) {
    case "42501":
      return new ApiError(
        "FORBIDDEN",
        "Grant management is not permitted.",
        403,
      )
    case "P0002":
      return new ApiError("NOT_FOUND", "The user or grant was not found.", 404)
    case "23505":
      return new ApiError(
        "CONFLICT",
        "An active grant already exists for this user and scope.",
        409,
      )
    case "23514":
      return new ApiError(
        "CONFLICT",
        "The last grant-management grant cannot be revoked.",
        409,
      )
    case "22023":
      return new ApiError(
        "VALIDATION_FAILED",
        "The grant type, scope or expiry is not valid.",
        400,
      )
    default:
      return error instanceof Error
        ? error
        : new Error("The grant operation failed.")
  }
}

@Injectable()
export class GrantsService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(IdentityService) private readonly identity: IdentityService,
  ) {}

  async own(token: string, context: RequestContext): Promise<OwnGrantsView> {
    const access = await this.access(token, context)
    return {
      grants: access.grants,
      capabilities: [...access.capabilities],
    }
  }

  async listForAdmin(
    token: string,
    context: RequestContext,
  ): Promise<readonly GrantView[]> {
    const access = await this.access(token, context)
    this.requireAny(context, access.capabilities, [
      "admin.grant.read",
      "admin.grant.manage",
    ])

    const rows = await this.queryRows(
      "select * from identity.list_grants($1, $2)",
      [access.session.userId, context.environment],
    )
    return rows.map(toView)
  }

  async create(
    token: string,
    input: CreateGrantInput,
    context: RequestContext,
  ): Promise<GrantView> {
    const access = await this.access(token, context)
    this.require(context, access.capabilities, "admin.grant.manage")

    const reason = input.reason?.trim()
    if (!reason || reason.length < 3) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason is required to change a grant.",
        400,
      )
    }

    if (!grantScopeIsValid(input.grantType, input.scope)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The scope does not belong to the selected grant type.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        {
          identity: {
            accountId: access.session.accountId,
            userId: access.session.userId,
          },
        },
        async (transaction) => {
          const created = await transaction.query<GrantRow>(
            "select * from identity.create_grant($1, $2, $3, $4, $5, $6)",
            [
              access.session.userId,
              input.email,
              input.grantType,
              input.scope,
              context.environment,
              input.expiresAt ?? null,
            ],
          )
          await this.audit(
            transaction.client,
            context,
            access.session.userId,
            "identity.grant_created",
            created.rows[0].id,
            { exists: false },
            {
              grantType: created.rows[0].grant_type,
              scope: created.rows[0].scope,
              environment: created.rows[0].environment,
              revokedAt: null,
            },
            reason,
          )
          return toView(created.rows[0])
        },
      )
    } catch (error) {
      throw mapGrantError(error)
    }
  }

  async revoke(
    token: string,
    grantId: string,
    reasonInput: string | undefined,
    context: RequestContext,
  ): Promise<GrantView> {
    const access = await this.access(token, context)
    this.require(context, access.capabilities, "admin.grant.manage")

    const reason = reasonInput?.trim()
    if (!reason || reason.length < 3) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason is required to change a grant.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        {
          identity: {
            accountId: access.session.accountId,
            userId: access.session.userId,
          },
        },
        async (transaction) => {
          const revoked = await transaction.query<GrantRow>(
            "select * from identity.revoke_grant($1, $2, $3)",
            [access.session.userId, grantId, context.environment],
          )
          await this.audit(
            transaction.client,
            context,
            access.session.userId,
            "identity.grant_revoked",
            revoked.rows[0].id,
            { revokedAt: null },
            { revokedAt: revoked.rows[0].revoked_at },
            reason,
          )
          return toView(revoked.rows[0])
        },
      )
    } catch (error) {
      throw mapGrantError(error)
    }
  }

  private async access(
    token: string,
    context: RequestContext,
  ): Promise<Access> {
    const session = await this.identity.getSession(token, context)
    const grants = await this.readOwnGrants(session, context)
    const active = grants
      .filter(isActive)
      .map((grant) => toGrantId(grant.scope))
      .filter((grant): grant is GrantId => grant !== undefined)
    const capabilities = computeCapabilities({
      authenticated: true,
      audience: context.audience,
      environment: context.environment,
      grants: active,
    })
    return { session, grants, capabilities }
  }

  private require(
    context: RequestContext,
    capabilities: ReadonlySet<CapabilityId>,
    capability: CapabilityId,
  ): void {
    this.requireAny(context, capabilities, [capability])
  }

  private requireAny(
    context: RequestContext,
    capabilities: ReadonlySet<CapabilityId>,
    required: readonly CapabilityId[],
  ): void {
    const allowed =
      context.audience === "control" &&
      required.some((cap) => capabilities.has(cap))
    if (!allowed) {
      throw new ApiError(
        "FORBIDDEN",
        "This action requires an active control-portal grant.",
        403,
      )
    }
  }

  private async readOwnGrants(
    session: SessionResult,
    context: RequestContext,
  ): Promise<readonly GrantView[]> {
    const client = await this.database.pool.connect()
    try {
      await client.query("begin")
      await client.query("select platform.set_identity_context($1, $2)", [
        session.accountId,
        session.userId,
      ])
      const rows = await client.query<GrantRow>(
        `select ${grantViewColumns()}
         from identity.grants
         where user_id = $1 and environment = $2
         order by created_at desc`,
        [session.userId, context.environment],
      )
      await client.query("commit")
      return rows.rows.map((row) => ({
        ...toView(row),
        environment: row.environment,
        email: session.email,
      }))
    } catch (error) {
      await client.query("rollback").catch(() => undefined)
      throw error
    } finally {
      client.release()
    }
  }

  private async queryRows(
    text: string,
    values: readonly unknown[],
  ): Promise<GrantRow[]> {
    const client = await this.database.pool.connect()
    try {
      const result = await client.query<GrantRow>(text, [...values])
      return result.rows
    } finally {
      client.release()
    }
  }

  private async audit(
    client: PoolClient,
    context: RequestContext,
    actorId: string,
    action: string,
    targetId: string,
    beforeSummary?: Record<string, unknown>,
    afterSummary?: Record<string, unknown>,
    reason?: string,
  ): Promise<void> {
    await appendAudit(client, {
      actorType: "admin",
      actorId,
      actorAudience: context.audience,
      environment: context.environment,
      action,
      targetType: "grant",
      targetId,
      beforeSummary,
      afterSummary,
      reason,
      ip: context.ip,
      userAgent: context.userAgent,
      correlationId: context.correlationId,
    })
  }
}
