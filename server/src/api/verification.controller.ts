import {
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
  Param,
  Post,
  Query,
  Req,
} from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import { verificationDecisionRequest } from "../contracts/schemas"
import { VerificationService } from "../modules/admin/verification.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

@Controller()
export class VerificationController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(VerificationService)
    private readonly verification: VerificationService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  private async session(request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return { context, session }
  }

  @Get("control/verification")
  @Audience("control")
  async queue(
    @Query("status") status: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const { session } = await this.session(request)
    return this.verification.queue({
      accountId: session.accountId,
      userId: session.userId,
      status: status ?? "",
    })
  }

  @Post("control/verification/:id/decision")
  @HttpCode(200)
  @Audience("control")
  async decide(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(verificationDecisionRequest, body)
    const { context, session } = await this.session(request)
    return this.verification.decide({
      accountId: session.accountId,
      userId: session.userId,
      caseId: id,
      decision: input.decision,
      reason: input.reason,
      context,
    })
  }
}
