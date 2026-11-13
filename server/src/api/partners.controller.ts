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
  addPartnerRepresentativeRequest,
  createPartnerRequest,
  partnerStatusRequest,
} from "../contracts/schemas"
import { PartnersService } from "../modules/admin/partners.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

@Controller()
export class PartnersController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(PartnersService) private readonly partners: PartnersService,
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

  @Get("control/partners")
  @Audience("control")
  async list(@Req() request: FastifyRequest) {
    const { session } = await this.session(request)
    return this.partners.list({
      accountId: session.accountId,
      userId: session.userId,
    })
  }

  @Post("control/partners")
  @HttpCode(201)
  @Audience("control")
  async create(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(createPartnerRequest, body)
    const { context, session } = await this.session(request)
    return this.partners.create({
      accountId: session.accountId,
      userId: session.userId,
      legalName: input.legalName,
      tradingName: input.tradingName,
      category: input.category,
      country: input.country,
      reason: input.reason,
      context,
    })
  }

  @Post("control/partners/:id/status")
  @HttpCode(200)
  @Audience("control")
  async setStatus(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(partnerStatusRequest, body)
    const { context, session } = await this.session(request)
    return this.partners.setStatus({
      accountId: session.accountId,
      userId: session.userId,
      organisationId: id,
      status: input.status,
      reason: input.reason,
      context,
    })
  }

  @Get("control/partners/:id/representatives")
  @Audience("control")
  async representatives(
    @Param("id") id: string,
    @Req() request: FastifyRequest,
  ) {
    const { session } = await this.session(request)
    return this.partners.representatives({
      accountId: session.accountId,
      userId: session.userId,
      organisationId: id,
    })
  }

  @Post("control/partners/:id/representatives")
  @HttpCode(201)
  @Audience("control")
  async addRepresentative(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(addPartnerRepresentativeRequest, body)
    const { context, session } = await this.session(request)
    return this.partners.addRepresentative({
      accountId: session.accountId,
      userId: session.userId,
      organisationId: id,
      email: input.email,
      role: input.role,
      reason: input.reason,
      context,
    })
  }
}
