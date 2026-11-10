import { Controller, Get, Inject, Req } from "@nestjs/common"
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
import { listAuditEntries } from "../modules/platform"

/**
 * Guarded audit-read probe (EP-01-035). The capability is evaluated inside the
 * same transaction as the read, so a revoked grant cannot race the response.
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
  async list(@Req() request: FastifyRequest) {
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
        return listAuditEntries(transaction.client, 100)
      },
    )
  }
}
