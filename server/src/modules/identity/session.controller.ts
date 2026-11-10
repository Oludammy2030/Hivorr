import { Controller, Get, Inject, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../../common/audience"
import { API_CONFIG, type ApiConfig } from "../../config"
import { IdentityService } from "./identity.service"
import { accessToken, requestContext } from "./request-context"

/**
 * The session endpoint is mounted at the API root (`/v1/session`), not under
 * `/v1/auth`, so clients read the current identity without implying an auth
 * command.
 */
@Controller()
@Audience("app", "control", "staff", "partner")
export class SessionController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("session")
  async session(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    return this.identity.getSession(accessToken(request, context), context)
  }
}
