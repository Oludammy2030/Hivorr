import {
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
import { API_CONFIG, type ApiConfig } from "../config"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"
import { ProfileService } from "../modules/profile"

/**
 * Composition endpoint for the activity switcher. It joins the identity
 * session with the profile activity module at the API edge, so the two modules
 * do not import each other.
 */
@Controller("activities")
@Audience("app")
export class ActivityController {
  constructor(
    @Inject(ProfileService) private readonly profile: ProfileService,
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get()
  async list(@Req() request: FastifyRequest) {
    const { session } = await this.loadSession(request)
    return this.profile.list(session.accountId, session.userId)
  }

  @Post(":id/activate")
  @HttpCode(200)
  async activate(@Param("id") id: string, @Req() request: FastifyRequest) {
    const { session, context } = await this.loadSession(request)
    return this.profile.activate(
      session.accountId,
      session.userId,
      id,
      new Set(session.capabilities),
      context,
    )
  }

  @Post(":id/deactivate")
  @HttpCode(200)
  async deactivate(@Param("id") id: string, @Req() request: FastifyRequest) {
    const { session, context } = await this.loadSession(request)
    return this.profile.deactivate(
      session.accountId,
      session.userId,
      id,
      new Set(session.capabilities),
      context,
    )
  }

  private async loadSession(request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return { session, context }
  }
}
