import { Controller, Get, Inject, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { API_CONFIG, type ApiConfig } from "../config"
import { DatabaseService } from "../db/database.service"
import { computeCapabilities } from "../domain/capabilities"
import { loadAdminAuthority } from "../modules/admin"
import {
  GrantsService,
  IdentityService,
  accessToken,
  loadAccessContext,
  requestContext,
} from "../modules/identity"

/**
 * Effective control-portal authority (CP-007).
 *
 * The session view is activity/grant oriented; the control shell needs the
 * composed view: privileged grants, governance roles, effective permissions,
 * explicit denials and the resulting presentation-only capability list.
 */
@Controller("control/authority")
@Audience("control")
export class ControlAuthorityController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(GrantsService) private readonly grants: GrantsService,
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get()
  async get(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const token = accessToken(request, context)
    const session = await this.identity.getSession(token, context)
    const own = await this.grants.own(token, context)

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
        const capabilities = [
          ...computeCapabilities({
            ...access,
            adminPermissions: authority.permissions,
            deniedPermissions: authority.deniedPermissions,
          }),
        ]

        return {
          grants: own.grants,
          roles: authority.roles,
          permissions: authority.permissions,
          deniedPermissions: authority.deniedPermissions,
          capabilities,
        }
      },
    )
  }
}
