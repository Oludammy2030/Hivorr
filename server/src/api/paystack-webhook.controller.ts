import { Controller, HttpCode, Inject, Post, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { ApiError } from "../common/errors"
import { DepositPostingService } from "../modules/finance"

/**
 * Paystack webhook intake (EP-02-044).
 *
 * Public route, authenticated by the `x-paystack-signature` HMAC over the raw
 * body. The service then verifies the transaction with Paystack; a valid
 * signature alone is not enough to credit a wallet.
 */
@Controller("webhooks")
@Audience("public")
export class PaystackWebhookController {
  constructor(
    @Inject(DepositPostingService)
    private readonly deposits: DepositPostingService,
  ) {}

  @Post("paystack")
  @HttpCode(200)
  async handle(@Req() request: FastifyRequest) {
    const rawBody = (request as FastifyRequest & { rawBody?: Buffer }).rawBody
    if (!rawBody) {
      throw new ApiError("VALIDATION_FAILED", "The webhook body is missing.", 400)
    }
    const header = request.headers["x-paystack-signature"]
    const signature = Array.isArray(header) ? header[0] : header
    if (!signature) {
      throw new ApiError("UNAUTHENTICATED", "The webhook signature is missing.", 401)
    }
    return this.deposits.handlePaystackWebhook(rawBody, signature)
  }
}
