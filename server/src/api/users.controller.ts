import { Controller, Get, Inject, Query, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { ApiError, requireCapability } from "../common/errors"
import { API_CONFIG, type ApiConfig } from "../config"
import { DatabaseService } from "../db/database.service"
import { computeCapabilities } from "../domain/capabilities"
import { loadAdminAuthority } from "../modules/admin"
import {
  IdentityService,
  accessToken,
  loadAccessContext,
  requestContext,
} from "../modules/identity"
import { appendAudit } from "../modules/platform"

const USER_PAGE_SIZE = 50

function parseCursor(
  value: string | undefined,
): {
  readonly before: string | null
  readonly beforeId: string | null
} {
  const cursor = (value ?? "").trim()
  if (!cursor) return { before: null, beforeId: null }
  const separator = cursor.indexOf("|")
  if (separator <= 0) {
    throw new ApiError("VALIDATION_FAILED", "The cursor is not valid.", 400)
  }
  const before = cursor.slice(0, separator)
  const beforeId = cursor.slice(separator + 1)
  if (
    Number.isNaN(Date.parse(before)) ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      beforeId,
    )
  ) {
    throw new ApiError("VALIDATION_FAILED", "The cursor is not valid.", 400)
  }
  return { before, beforeId }
}

/**
 * Read-only user directory for the control portal (CP-004).
 *
 * Gated by `admin.user.read`, not by a grant-management capability. The read
 * goes through `admin.list_users`, a narrow security-definer function that
 * re-checks the platform-scoped permission inside the database. Account-scoped
 * RLS is not relaxed; the function is the explicit, audited exception.
 */
@Controller("control/users")
@Audience("control")
export class UsersController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get()
  async list(
    @Query("q") query: string | undefined,
    @Query("status") status: string | undefined,
    @Query("cursor") cursor: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const page = parseCursor(cursor)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )

    return this.database.withTransaction(
      {
        identity: {
          accountId: session.accountId,
          userId: session.userId,
        },
      },
      async (transaction) => {
        const access = await loadAccessContext(transaction.client, {
          accountId: session.accountId,
          userId: session.userId,
          audience: context.audience,
          environment: context.environment,
        })
        const authority = await loadAdminAuthority(
          transaction.client,
          session.userId,
        )
        requireCapability(
          computeCapabilities({
            ...access,
            adminPermissions: authority.permissions,
            deniedPermissions: authority.deniedPermissions,
          }),
          "admin.user.read",
        )

        const search = (query ?? "").trim()
        const statusFilter = (status ?? "").trim()

        const result = await transaction.query<{
          id: string
          account_id: string
          email: string
          display_name: string | null
          status: string
          email_verified_at: string | null
          created_at: string
          confirmed_factors: string
        }>("select * from admin.list_users($1, $2, $3, $4, $5)", [
          search,
          statusFilter,
          page.before,
          page.beforeId,
          USER_PAGE_SIZE + 1,
        ])

        const visible = result.rows.slice(0, USER_PAGE_SIZE)
        const last = visible[visible.length - 1]
        const nextCursor =
          result.rows.length > USER_PAGE_SIZE && last
            ? `${new Date(last.created_at).toISOString()}|${last.id}`
            : null

        await appendAudit(transaction.client, {
          actorType: "admin",
          actorId: session.userId,
          actorAudience: context.audience,
          environment: context.environment,
          action: "admin.users_listed",
          targetType: "user_directory",
          targetId: "platform",
          afterSummary: {
            query: search,
            status: statusFilter,
            count: visible.length,
            cursor: page.before !== null,
          },
          ip: context.ip,
          userAgent: context.userAgent,
          correlationId: context.correlationId,
        })

        return {
          items: visible.map((row) => ({
            id: row.id,
            accountId: row.account_id,
            email: row.email,
            displayName: row.display_name,
            status: row.status,
            emailVerified: row.email_verified_at !== null,
            confirmedFactors: Number(row.confirmed_factors),
            createdAt: row.created_at,
          })),
          nextCursor,
        }
      },
    )
  }
}
