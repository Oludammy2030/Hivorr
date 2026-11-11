import { Controller, Get, Inject, Query, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { requireCapability } from "../common/errors"
import { API_CONFIG, type ApiConfig } from "../config"
import { DatabaseService } from "../db/database.service"
import { computeCapabilities } from "../domain/capabilities"
import {
  IdentityService,
  accessToken,
  loadAccessContext,
  requestContext,
} from "../modules/identity"

/**
 * Read-only user directory for the control portal.
 *
 * Gated by `admin.grant.read` for now: an administrator who may inspect grants
 * may also inspect the accounts those grants point at. A dedicated user
 * capability can replace this without changing the route.
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
    @Req() request: FastifyRequest,
  ) {
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
        requireCapability(computeCapabilities(access), "admin.grant.read")

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
        }>(
          `select u.id, u.account_id, u.email, u.display_name, u.status,
                  u.email_verified_at, u.created_at,
                  (select count(*) from identity.mfa_factors f
                   where f.user_id = u.id and f.confirmed_at is not null) as confirmed_factors
           from identity.users u
           where ($1 = '' or u.email ilike '%' || $1 || '%'
                  or coalesce(u.display_name, '') ilike '%' || $1 || '%')
             and ($2 = '' or u.status = $2)
           order by u.created_at desc
           limit 100`,
          [search, statusFilter],
        )

        return result.rows.map((row) => ({
          id: row.id,
          accountId: row.account_id,
          email: row.email,
          displayName: row.display_name,
          status: row.status,
          emailVerified: row.email_verified_at !== null,
          confirmedFactors: Number(row.confirmed_factors),
          createdAt: row.created_at,
        }))
      },
    )
  }
}
