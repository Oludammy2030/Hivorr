import { Controller, Get, HttpCode, Inject, Param, Post, Req } from "@nestjs/common"
import type { LaneStatus } from "@hivorr/shared"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { ApiError } from "../common/errors"
import { requestFingerprint, requireIdempotencyKey } from "../common/idempotency"
import { FixedWindowRateLimiter } from "../common/rate-limiter"
import { API_CONFIG, type ApiConfig } from "../config"
import { IdentityService, accessToken, requestContext } from "../modules/identity"
import { VerificationLaneService, type LaneView } from "../modules/profile"

/**
 * Verification submission and status API (EP-02-013).
 *
 * The subject side only: read a lane, start an attempt, submit it and withdraw
 * it. Evidence upload is `EP-02-012` and is not exposed here, so a submission
 * needs evidence recorded by that path before it can pass.
 *
 * The control-portal reviewer controller is a different class at
 * `api/verification.controller.ts`; this one is the account's own view.
 *
 * The account always comes from the session. The lane comes from the path and is
 * validated by the service against the shared vocabulary.
 */

const LIMITS = {
  start: { windowMs: 15 * 60 * 1_000, max: 10 },
  submit: { windowMs: 15 * 60 * 1_000, max: 10 },
  withdraw: { windowMs: 15 * 60 * 1_000, max: 20 },
} as const

function toStatus(view: LaneView): LaneStatus {
  return {
    lane: view.lane,
    state: view.state,
    reasonCode: view.reasonCode,
    hasActiveSubmission: view.hasActiveSubmission,
    updatedAt: view.stateChangedAt,
  }
}

@Controller("verification")
@Audience("app")
export class VerificationLaneController {
  private readonly limiter = new FixedWindowRateLimiter()

  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(VerificationLaneService) private readonly lanes: VerificationLaneService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get(":lane/status")
  async status(@Param("lane") lane: string, @Req() request: FastifyRequest): Promise<LaneStatus> {
    const { session, context } = await this.loadSession(request)
    const view = await this.lanes.status({
      accountId: session.accountId,
      userId: session.userId,
      lane,
      context,
    })
    return toStatus(view)
  }

  @Post(":lane/start")
  @HttpCode(200)
  async start(@Param("lane") lane: string, @Req() request: FastifyRequest): Promise<LaneStatus> {
    const { session, context } = await this.loadSession(request)
    this.limit(session.userId, "start")
    const view = await this.lanes.start({
      accountId: session.accountId,
      userId: session.userId,
      lane,
      context,
    })
    return toStatus(view)
  }

  @Post(":lane/submit")
  @HttpCode(200)
  async submit(@Param("lane") lane: string, @Req() request: FastifyRequest): Promise<LaneStatus> {
    const { session, context } = await this.loadSession(request)
    this.limit(session.userId, "submit")
    const idempotencyKey = requireIdempotencyKey(request)
    const view = await this.lanes.submit({
      accountId: session.accountId,
      userId: session.userId,
      lane,
      context,
      idempotencyKey,
      requestHash: requestFingerprint("POST", `/v1/verification/${lane}/submit`, {}),
    })
    return toStatus(view)
  }

  @Post(":lane/withdraw")
  @HttpCode(200)
  async withdraw(@Param("lane") lane: string, @Req() request: FastifyRequest): Promise<LaneStatus> {
    const { session, context } = await this.loadSession(request)
    this.limit(session.userId, "withdraw")
    const view = await this.lanes.withdraw({
      accountId: session.accountId,
      userId: session.userId,
      lane,
      context,
    })
    return toStatus(view)
  }

  private limit(userId: string, action: keyof typeof LIMITS): void {
    const result = this.limiter.check(`${userId}:${action}`, LIMITS[action])
    if (!result.allowed) {
      throw new ApiError("RATE_LIMITED", "Too many verification attempts. Try again later.", 429, {
        "retry-after": String(result.retryAfterSeconds),
      })
    }
  }

  private async loadSession(request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(accessToken(request, context), context)
    return { session, context }
  }
}
