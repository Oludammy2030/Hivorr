import { Controller, Get, Inject, Query, Req, Res } from "@nestjs/common"
import type { FastifyReply, FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { ApiError, requireCapability } from "../common/errors"
import { API_CONFIG, type ApiConfig } from "../config"
import { DatabaseService } from "../db/database.service"
import { computeCapabilities } from "../domain/capabilities"
import {
  IdentityService,
  accessToken,
  loadAccessContext,
  requestContext,
} from "../modules/identity"
import { appendAudit, listAuditEntries } from "../modules/platform"

const AUDIT_PAGE_SIZE = 50

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

function optionalDate(value: string | undefined, field: string): string | null {
  const text = (value ?? "").trim()
  if (!text) return null
  if (Number.isNaN(Date.parse(text))) {
    throw new ApiError(
      "VALIDATION_FAILED",
      `The ${field} filter is not a valid date.`,
      400,
    )
  }
  return text
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function optionalUuid(value: string | undefined, field: string): string | null {
  const text = (value ?? "").trim()
  if (!text) return null
  if (!UUID_PATTERN.test(text)) {
    throw new ApiError(
      "VALIDATION_FAILED",
      `The ${field} filter is not a valid identifier.`,
      400,
    )
  }
  return text
}

function optionalText(value: string | undefined, field: string): string | null {
  const text = (value ?? "").trim()
  if (text.length > 200) {
    throw new ApiError(
      "VALIDATION_FAILED",
      `The ${field} filter is too long.`,
      400,
    )
  }
  return text.length > 0 ? text : null
}

/**
 * Guarded audit read (CP-005). The capability is evaluated inside the same
 * transaction as the read, and the read itself is audited.
 */
@Controller("control/audit")
@Audience("control")
export class AuditController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get()
  async list(
    @Query("actorId") actorId: string | undefined,
    @Query("action") action: string | undefined,
    @Query("targetType") targetType: string | undefined,
    @Query("targetId") targetId: string | undefined,
    @Query("from") from: string | undefined,
    @Query("to") to: string | undefined,
    @Query("cursor") cursor: string | undefined,
    @Req() request: FastifyRequest,
    @Res({ passthrough: true }) reply: FastifyReply,
  ) {
    const page = parseCursor(cursor)
    const filters = {
      actorId: optionalUuid(actorId, "actorId"),
      action: optionalText(action, "action"),
      targetType: optionalText(targetType, "targetType"),
      targetId: optionalText(targetId, "targetId"),
      from: optionalDate(from, "from"),
      to: optionalDate(to, "to"),
    }
    if (
      filters.from !== null &&
      filters.to !== null &&
      Date.parse(filters.from) > Date.parse(filters.to)
    ) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The from filter must not be after the to filter.",
        400,
      )
    }

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
        requireCapability(computeCapabilities(access), "admin.audit.read")

        const result = await listAuditEntries(transaction.client, {
          ...filters,
          before: page.before,
          beforeId: page.beforeId,
          limit: AUDIT_PAGE_SIZE,
        })

        await appendAudit(transaction.client, {
          actorType: "admin",
          actorId: session.userId,
          actorAudience: context.audience,
          environment: context.environment,
          action: "admin.audit_read",
          targetType: "audit_log",
          targetId: "platform",
          capability: "admin.audit.read",
          afterSummary: {
            ...filters,
            count: result.items.length,
            cursor: page.before !== null,
          },
          ip: context.ip,
          userAgent: context.userAgent,
          correlationId: context.correlationId,
          sessionId: session.sessionId,
        })

        if (result.nextCursor) {
          reply.header("x-next-cursor", result.nextCursor)
        }

        return result.items
      },
    )
  }
}
