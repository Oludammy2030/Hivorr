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
import { z } from "zod"

import { ApiError } from "../../common/errors"
import { API_CONFIG, type ApiConfig } from "../../config"
import { accessToken, requestContext } from "../identity/request-context"
import {
  GRANT_TYPES,
  GrantsService,
  type CreateGrantInput,
} from "./grants.service"

const createGrantSchema = z.object({
  email: z.string().min(3).max(254),
  grantType: z.enum(GRANT_TYPES as [string, ...string[]]),
  scope: z.string().min(1).max(80),
  expiresAt: z
    .string()
    .min(1)
    .max(40)
    .refine((value) => !Number.isNaN(Date.parse(value)), "invalid date")
    .optional(),
})

function parseCreateGrant(body: unknown): CreateGrantInput {
  const result = createGrantSchema.safeParse(body)
  if (!result.success) {
    throw new ApiError("VALIDATION_FAILED", "The request body is invalid.", 400)
  }
  return result.data as CreateGrantInput
}

@Controller()
export class GrantsController {
  constructor(
    @Inject(GrantsService) private readonly grants: GrantsService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("grants")
  async own(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    return this.grants.own(accessToken(request, context), context)
  }

  @Get("control/grants")
  async list(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    return this.grants.listForAdmin(accessToken(request, context), context)
  }

  @Post("control/grants")
  async create(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseCreateGrant(body)
    const context = requestContext(this.config, request)
    return this.grants.create(accessToken(request, context), input, context)
  }

  @Post("control/grants/:id/revoke")
  @HttpCode(200)
  async revoke(@Param("id") id: string, @Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    return this.grants.revoke(accessToken(request, context), id, context)
  }
}
