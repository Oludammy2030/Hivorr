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
import { requireIdempotencyKey } from "../common/idempotency"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import { withdrawRequest } from "../contracts/schemas"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"
import {
  PayoutExecutionService,
  PayoutRequestService,
} from "../modules/finance"
import { CollectionAccountService } from "../modules/finance"

/**
 * Self-service withdrawal (EP-02-053).
 *
 * A user withdraws their own funds; there is no staff approval. The service
 * applies KYC, destination, limit and balance checks. An unverified account is
 * refused with `KYC_REQUIRED`; no tier is inferred at the API edge.
 */
@Controller("wallet")
@Audience("app")
export class WalletController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(PayoutRequestService)
    private readonly requests: PayoutRequestService,
    @Inject(PayoutExecutionService)
    private readonly execution: PayoutExecutionService,
    @Inject(CollectionAccountService)
    private readonly collections: CollectionAccountService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("payouts")
  async list(@Req() request: FastifyRequest) {
    const { session } = await this.loadSession(request)
    return this.requests.list({
      accountId: session.accountId,
      userId: session.userId,
    })
  }

  @Get("collection-account")
  async collection(@Req() request: FastifyRequest) {
    const { session } = await this.loadSession(request)
    return this.collections.get({
      accountId: session.accountId,
      userId: session.userId,
    })
  }

  @Post("collection-account")
  @HttpCode(201)
  async createCollection(@Req() request: FastifyRequest) {
    const { session, context } = await this.loadSession(request)
    return this.collections.create({
      accountId: session.accountId,
      userId: session.userId,
      email: session.email,
      accountName: session.account.displayName ?? session.email,
      context,
    })
  }

  @Post("withdrawals")
  @HttpCode(201)
  async withdraw(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(withdrawRequest, body)
    const idempotencyKey = requireIdempotencyKey(request)
    const { session, context } = await this.loadSession(request)

    const created = await this.requests.request({
      accountId: session.accountId,
      userId: session.userId,
      tier: session.kycTier,
      payoutAccountId: input.payoutAccountId,
      amount: input.amount,
      currency: input.currency,
      idempotencyKey,
      context,
    })

    return this.execution.execute({
      accountId: session.accountId,
      userId: session.userId,
      tier: session.kycTier,
      requestId: created.id,
      context,
    })
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
