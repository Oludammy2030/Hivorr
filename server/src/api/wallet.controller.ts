import { Body, Controller, Get, HttpCode, Inject, Param, Post, Query, Req } from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { requireIdempotencyKey } from "../common/idempotency"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import { withdrawRequest } from "../contracts/schemas"
import { bindPayoutAccountRequest, disablePayoutAccountRequest } from "../contracts/schemas"
import { IdentityService, accessToken, requestContext } from "../modules/identity"
import {
  PayoutAccountService,
  PayoutExecutionService,
  PayoutRequestService,
  WalletService,
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
    @Inject(PayoutAccountService)
    private readonly payoutAccounts: PayoutAccountService,
    @Inject(CollectionAccountService)
    private readonly collections: CollectionAccountService,
    @Inject(WalletService) private readonly wallet: WalletService,
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

  @Get("balance")
  async balance(@Req() request: FastifyRequest) {
    const { session } = await this.loadSession(request)
    return this.wallet.balances({
      accountId: session.accountId,
      userId: session.userId,
    })
  }

  /**
   * The caller's own statement, newest first. Filters and the keyset cursor are
   * optional; the service validates them. The account always comes from the
   * session, never from the query.
   */
  @Get("statement")
  async statement(
    @Query("currency") currency: string | undefined,
    @Query("activityId") activityId: string | undefined,
    @Query("before") before: string | undefined,
    @Query("beforeId") beforeId: string | undefined,
    @Query("limit") limit: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const { session } = await this.loadSession(request)
    return this.wallet.statement(
      { accountId: session.accountId, userId: session.userId },
      {
        currency,
        activityId,
        before,
        beforeId,
        limit: limit === undefined || limit === "" ? undefined : Number(limit),
      },
    )
  }

  @Get("payout-accounts")
  async listPayoutAccounts(@Req() request: FastifyRequest) {
    const { session } = await this.loadSession(request)
    return this.payoutAccounts.list({
      accountId: session.accountId,
      userId: session.userId,
    })
  }

  @Post("payout-accounts")
  @HttpCode(201)
  async bindPayoutAccount(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(bindPayoutAccountRequest, body)
    const { session, context } = await this.loadSession(request)
    return this.payoutAccounts.bind({
      accountId: session.accountId,
      userId: session.userId,
      tier: session.kycTier,
      bankCode: input.bankCode,
      bankName: input.bankName,
      accountNumber: input.accountNumber,
      reason: input.reason,
      context,
    })
  }

  @Post("payout-accounts/:id/disable")
  @HttpCode(200)
  async disablePayoutAccount(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(disablePayoutAccountRequest, body)
    const { session, context } = await this.loadSession(request)
    return this.payoutAccounts.disable({
      id,
      accountId: session.accountId,
      userId: session.userId,
      reason: input.reason,
      context,
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
    const session = await this.identity.getSession(accessToken(request, context), context)
    return { session, context }
  }
}
