import { Controller, Get, Inject, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { API_CONFIG, type ApiConfig } from "../config"
import { PartnerPortalService } from "../modules/admin/partner-portal.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

@Controller()
@Audience("partner")
export class PartnerController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(PartnerPortalService)
    private readonly partners: PartnerPortalService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("partner/organisations")
  async organisations(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.partners.organisations({
      accountId: session.accountId,
      userId: session.userId,
    })
  }
}
