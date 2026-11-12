import {
  Body,
  Controller,
  Get,
  Inject,
  Param,
  Patch,
  Post,
  Query,
  Req,
} from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import {
  createStaffInviteRequest,
  setStaffDepartmentRequest,
  staffReasonRequest,
} from "../contracts/schemas"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"
import { StaffService } from "../modules/admin/staff.service"

@Controller("control/staff")
@Audience("control")
export class StaffController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(StaffService) private readonly staff: StaffService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get()
  async list(
    @Query("q") query: string | undefined,
    @Query("status") status: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )

    return this.staff.list({
      accountId: session.accountId,
      userId: session.userId,
      query: query ?? "",
      status: status ?? "",
    })
  }

  @Post("invites")
  async invite(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(createStaffInviteRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )

    return this.staff.invite({
      accountId: session.accountId,
      userId: session.userId,
      context,
      email: input.email,
      departmentKey: input.departmentKey,
      jobTitle: input.jobTitle,
      reason: input.reason,
    })
  }

  @Post(":userId/suspend")
  async suspend(
    @Param("userId") userId: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    return this.setStatus(request, userId, "suspended", body)
  }

  @Post(":userId/reactivate")
  async reactivate(
    @Param("userId") userId: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    return this.setStatus(request, userId, "active", body)
  }

  @Post(":userId/offboard")
  async offboard(
    @Param("userId") userId: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    return this.setStatus(request, userId, "offboarded", body)
  }

  @Patch(":userId/department")
  async setDepartment(
    @Param("userId") userId: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(setStaffDepartmentRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )

    return this.staff.setDepartment({
      accountId: session.accountId,
      userId: session.userId,
      targetUserId: userId,
      context,
      departmentKey: input.departmentKey,
      reason: input.reason,
    })
  }

  private async setStatus(
    request: FastifyRequest,
    userId: string,
    status: "suspended" | "active" | "offboarded",
    body: unknown,
  ) {
    const input = parseBody(staffReasonRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )

    return this.staff.setStatus({
      accountId: session.accountId,
      userId: session.userId,
      targetUserId: userId,
      context,
      status,
      reason: input.reason,
    })
  }
}
