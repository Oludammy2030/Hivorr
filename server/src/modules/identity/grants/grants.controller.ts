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

import { Audience } from "../../../common/audience"
import { parseBody } from "../../../common/validation"
import { API_CONFIG, type ApiConfig } from "../../../config"
import {
  createGrantRequest,
  revokeGrantRequest,
} from "../../../contracts/schemas"
import { accessToken, requestContext } from "../request-context"
import { GrantsService, type CreateGrantInput } from "./grants.service"

function parseCreateGrant(body: unknown): CreateGrantInput {
  return parseBody(createGrantRequest, body) as CreateGrantInput
}

function parseRevokeGrant(body: unknown): { reason?: string } {
  return parseBody(revokeGrantRequest, body) as { reason?: string }
}

@Controller()
export class GrantsController {
  constructor(
    @Inject(GrantsService) private readonly grants: GrantsService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("grants")
  @Audience("app", "control", "staff", "partner")
  async own(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    return this.grants.own(accessToken(request, context), context)
  }

  @Get("control/grants")
  @Audience("control")
  async list(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    return this.grants.listForAdmin(accessToken(request, context), context)
  }

  @Post("control/grants")
  @Audience("control")
  async create(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseCreateGrant(body)
    const context = requestContext(this.config, request)
    return this.grants.create(accessToken(request, context), input, context)
  }

  @Post("control/grants/:id/revoke")
  @HttpCode(200)
  @Audience("control")
  async revoke(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseRevokeGrant(body)
    const context = requestContext(this.config, request)
    return this.grants.revoke(
      accessToken(request, context),
      id,
      input.reason,
      context,
    )
  }
}
