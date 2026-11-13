import {
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
  Param,
  Post,
  Req,
} from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import {
  createApprovalRequest,
  decideApprovalRequest,
  caseDecisionRequest,
} from "../contracts/schemas"
import { ApprovalsService } from "../modules/admin/approvals.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

@Controller()
export class ApprovalsController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(ApprovalsService) private readonly approvals: ApprovalsService,
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

  @Get("control/approvals")
  @Audience("control")
  async list(@Req() request: FastifyRequest) {
    const { session } = await this.session(request)
    return this.approvals.list({
      accountId: session.accountId,
      userId: session.userId,
    })
  }

  @Post("control/approvals")
  @HttpCode(201)
  @Audience("control")
  async create(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(createApprovalRequest, body)
    const { context, session } = await this.session(request)
    return this.approvals.request({
      accountId: session.accountId,
      userId: session.userId,
      actionType: input.actionType,
      targetType: input.targetType,
      targetId: input.targetId,
      reason: input.reason,
      context,
    })
  }

  @Post("control/approvals/:id/decide")
  @HttpCode(200)
  @Audience("control")
  async decide(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(decideApprovalRequest, body)
    const { context, session } = await this.session(request)
    return this.approvals.decide({
      accountId: session.accountId,
      userId: session.userId,
      requestId: id,
      decision: input.decision,
      reason: input.reason,
      context,
    })
  }

  @Post("control/cases/:id/decision")
  @HttpCode(201)
  @Audience("control")
  async requestCaseDecision(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(caseDecisionRequest, body)
    const { context, session } = await this.session(request)
    return this.approvals.requestCaseDecision({
      accountId: session.accountId,
      userId: session.userId,
      caseId: id,
      outcome: input.outcome,
      reason: input.reason,
      context,
    })
  }
}
