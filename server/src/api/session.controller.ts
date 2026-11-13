import { Controller, Get, Inject, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { API_CONFIG, type ApiConfig } from "../config"
import { DatabaseService } from "../db/database.service"
import { computeCapabilities } from "../domain/capabilities"
import { loadAdminAuthority, platformPermissions } from "../modules/admin"
import {
  IdentityService,
  accessToken,
  loadAccessContext,
  requestContext,
} from "../modules/identity"

/**
 * The session endpoint is mounted at the API root (`/v1/session`), not under
 * `/v1/auth`, so clients read the current identity without implying an auth
 * command.
 *
 * Capabilities are recomposed here so a governance role counts as authority in
 * every portal, not just the control portal. Only platform-scoped role
 * permissions are folded in: a department-scoped assignment must not become a
 * platform-wide capability.
 */
@Controller()
@Audience("app", "control", "staff", "partner")
export class SessionController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("session")
  async session(@Req() request: FastifyRequest) {
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
        return {
          ...session,
          capabilities: [
            ...computeCapabilities({
              ...access,
              adminPermissions: platformPermissions(authority),
              deniedPermissions: authority.deniedPermissions,
            }),
          ],
        }
      },
    )
  }
}
