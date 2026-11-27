import { Body, Controller, HttpCode, Inject, Param, Post, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import { assignKycTierRequest } from "../contracts/schemas"
import { IdentityService, accessToken, requestContext } from "../modules/identity"

/**
 * Control-portal KYC tier assignment (EP-02-014, minimal increment).
 *
 * Only `tier_0` and `tier_1` are approved. The database function re-checks
 * `admin.verification.review`; this controller does not widen authority.
 */
@Controller("control/accounts")
@Audience("control")
export class KycController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Post(":id/kyc-tier")
  @HttpCode(200)
  async assign(@Param("id") id: string, @Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(assignKycTierRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(accessToken(request, context), context)

    return this.identity.setKycTier({
      actorUserId: session.userId,
      accountId: id,
      tier: input.tier,
      reason: input.reason,
      context,
    })
  }
}
