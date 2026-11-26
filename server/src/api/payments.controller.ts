import {
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
  Post,
  Req,
} from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import { paymentProviderSettingRequest } from "../contracts/schemas"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"
import { PaymentProviderSettingsService } from "../modules/platform"

/**
 * Control-portal payment provider switch (2026-11-26).
 *
 * Secrets are not accepted here: the deployment secret store owns them. The
 * endpoint switches provider/mode and reports whether each key is configured.
 */
@Controller("control/payments")
@Audience("control")
export class PaymentsController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(PaymentProviderSettingsService)
    private readonly settings: PaymentProviderSettingsService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("provider")
  async get(@Req() request: FastifyRequest) {
    const session = await this.loadSession(request)
    return this.settings.get(session.userId)
  }

  @Post("provider")
  @HttpCode(200)
  async set(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(paymentProviderSettingRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )

    return this.settings.set({
      actorUserId: session.userId,
      provider: input.provider,
      mode: input.mode,
      reason: input.reason,
      context,
    })
  }

  private async loadSession(request: FastifyRequest) {
    const context = requestContext(this.config, request)
    return this.identity.getSession(accessToken(request, context), context)
  }
}
