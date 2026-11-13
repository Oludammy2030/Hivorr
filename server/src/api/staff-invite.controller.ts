import {
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
  Post,
  Query,
  Req,
} from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { ApiError } from "../common/errors"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import { acceptStaffInviteRequest } from "../contracts/schemas"
import { StaffService } from "../modules/admin/staff.service"

/**
 * Invite acceptance is the only CP-010 surface that runs before a session
 * exists. It is bound to the app audience because the invitee completes TOTP
 * enrolment on the main portal, never on the staff portal.
 */
@Controller("auth")
@Audience("app")
export class StaffInviteController {
  constructor(
    @Inject(StaffService) private readonly staff: StaffService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  /**
   * Lets the invitation page show the official address the account will use,
   * so the invitee is never asked to type it and never registers with a
   * personal address. Only a live token resolves.
   */
  @Get("staff-invite")
  async details(
    @Query("token") token: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    if (!token || token.length < 20 || token.length > 200) {
      throw new ApiError(
        "NOT_FOUND",
        "This invitation is no longer valid.",
        404,
      )
    }

    return this.staff.inviteDetails(token, request.ip)
  }

  @Post("staff-invite/accept")
  @HttpCode(201)
  async accept(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(acceptStaffInviteRequest, body)

    return this.staff.acceptInvite({
      environment: this.config.environment,
      token: input.token,
      password: input.password,
      displayName: input.displayName,
      ip: request.ip,
      userAgent:
        typeof request.headers["user-agent"] === "string"
          ? request.headers["user-agent"]
          : undefined,
      correlationId: (request as FastifyRequest & { correlationId?: string })
        .correlationId,
    })
  }
}
