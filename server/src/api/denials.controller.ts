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
  createAccessDenialRequest,
  roleReasonRequest,
} from "../contracts/schemas"
import { DenialsService } from "../modules/admin/denials.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

/**
 * Access denials: the negative of a role assignment.
 *
 * Four-eyes is inherent here — an operator cannot deny or un-deny their own
 * authority, and a platform denial cannot empty the last administration seat.
 * Both rules are enforced inside the database functions, not just here.
 */
@Controller()
export class DenialsController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(DenialsService) private readonly denials: DenialsService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("control/denials")
  @Audience("control")
  async list(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.denials.list({
      accountId: session.accountId,
      userId: session.userId,
      environment: context.environment,
    })
  }

  @Post("control/denials")
  @Audience("control")
  async create(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(createAccessDenialRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.denials.create({
      accountId: session.accountId,
      userId: session.userId,
      email: input.email,
      permissionKey: input.permissionKey,
      scopeType: input.scopeType,
      scopeId: input.scopeId ?? null,
      expiresAt: input.expiresAt ?? null,
      reason: input.reason,
      environment: context.environment,
      context,
    })
  }

  @Post("control/denials/:id/revoke")
  @HttpCode(200)
  @Audience("control")
  async revoke(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(roleReasonRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.denials.revoke({
      accountId: session.accountId,
      userId: session.userId,
      denialId: id,
      reason: input.reason,
      environment: context.environment,
      context,
    })
  }
}
