import {
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
  Param,
  Post,
  Query,
  Req,
} from "@nestjs/common"
import type { FastifyRequest } from "fastify"

import { Audience } from "../common/audience"
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import { assignRoleRequest, roleReasonRequest } from "../contracts/schemas"
import { RolesService } from "../modules/admin/roles.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

@Controller()
export class RolesController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(RolesService) private readonly roles: RolesService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Get("control/roles")
  @Audience("control")
  async list(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.roles.listRoles({
      accountId: session.accountId,
      userId: session.userId,
      environment: context.environment,
    })
  }

  @Get("control/role-assignments")
  @Audience("control")
  async assignments(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.roles.listAssignments({
      accountId: session.accountId,
      userId: session.userId,
      environment: context.environment,
    })
  }

  @Get("control/roles/scope-targets")
  @Audience("control")
  async scopeTargets(
    @Query("type") type: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.roles.scopeTargets({
      accountId: session.accountId,
      userId: session.userId,
      scopeType: type ?? "",
    })
  }

  @Post("control/role-assignments")
  @Audience("control")
  async assign(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(assignRoleRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.roles.assign({
      accountId: session.accountId,
      userId: session.userId,
      email: input.email,
      roleKey: input.roleKey,
      scopeType: input.scopeType,
      scopeId: input.scopeId ?? null,
      expiresAt: input.expiresAt ?? null,
      reason: input.reason,
      environment: context.environment,
      context,
    })
  }

  @Post("control/role-assignments/:id/revoke")
  @HttpCode(200)
  @Audience("control")
  async revoke(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(roleReasonRequest, body)
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return this.roles.revoke({
      accountId: session.accountId,
      userId: session.userId,
      assignmentId: id,
      reason: input.reason,
      environment: context.environment,
      context,
    })
  }
}
