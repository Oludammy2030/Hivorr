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
import {
  assignCaseRequest,
  caseNoteRequest,
  caseStatusRequest,
  createCaseRequest,
} from "../contracts/schemas"
import { CasesService } from "../modules/admin/cases.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

@Controller()
export class CasesController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(CasesService) private readonly cases: CasesService,
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

  @Get("control/cases")
  @Audience("control")
  async list(
    @Query("status") status: string | undefined,
    @Query("type") type: string | undefined,
    @Query("q") query: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const { session } = await this.session(request)
    return this.cases.list({
      accountId: session.accountId,
      userId: session.userId,
      status: status ?? "",
      caseType: type ?? "",
      query: query ?? "",
    })
  }

  @Post("control/cases")
  @HttpCode(201)
  @Audience("control")
  async create(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(createCaseRequest, body)
    const { context, session } = await this.session(request)
    return this.cases.create({
      accountId: session.accountId,
      userId: session.userId,
      caseType: input.caseType,
      title: input.title,
      description: input.description,
      priority: input.priority,
      severity: input.severity,
      queueKey: input.queueKey,
      reason: input.reason,
      context,
    })
  }

  @Get("control/cases/:id/events")
  @Audience("control")
  async events(@Param("id") id: string, @Req() request: FastifyRequest) {
    const { session } = await this.session(request)
    return this.cases.events({
      accountId: session.accountId,
      userId: session.userId,
      caseId: id,
    })
  }

  @Post("control/cases/:id/events")
  @HttpCode(201)
  @Audience("control")
  async addEvent(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(caseNoteRequest, body)
    const { context, session } = await this.session(request)
    return this.cases.addEvent({
      accountId: session.accountId,
      userId: session.userId,
      caseId: id,
      summary: input.summary,
      context,
    })
  }

  @Post("control/cases/:id/assign")
  @HttpCode(200)
  @Audience("control")
  async assign(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(assignCaseRequest, body)
    const { context, session } = await this.session(request)
    return this.cases.assign({
      accountId: session.accountId,
      userId: session.userId,
      caseId: id,
      email: input.email,
      queueKey: input.queueKey,
      context,
    })
  }

  @Post("control/cases/:id/status")
  @HttpCode(200)
  @Audience("control")
  async setStatus(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(caseStatusRequest, body)
    const { context, session } = await this.session(request)
    return this.cases.setStatus({
      accountId: session.accountId,
      userId: session.userId,
      caseId: id,
      status: input.status,
      reason: input.reason,
      context,
    })
  }
}
