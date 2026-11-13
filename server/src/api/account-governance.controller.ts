import {
  Body,
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
import { parseBody } from "../common/validation"
import { API_CONFIG, type ApiConfig } from "../config"
import {
  accountReasonRequest,
  addAccountNoteRequest,
} from "../contracts/schemas"
import {
  AccountGovernanceService,
  type AccountAction,
} from "../modules/admin/account-governance.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

function parseReason(body: unknown): { reason?: string } {
  return parseBody(accountReasonRequest, body) as { reason?: string }
}

function parseNote(body: unknown): { body: string } {
  return parseBody(addAccountNoteRequest, body) as { body: string }
}

@Controller()
export class AccountGovernanceController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(AccountGovernanceService)
    private readonly accounts: AccountGovernanceService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  private async session(request: FastifyRequest) {
    const context = requestContext(this.config, request)
    const session = await this.identity.getSession(
      accessToken(request, context),
      context,
    )
    return { context, session }
  }

  private async action(
    request: FastifyRequest,
    targetUserId: string,
    action: AccountAction,
    body: unknown,
  ) {
    const input = parseReason(body)
    const { context, session } = await this.session(request)
    return this.accounts.govern({
      accountId: session.accountId,
      userId: session.userId,
      targetUserId,
      action,
      reason: input.reason,
      context,
    })
  }

  @Post("control/users/:id/suspend")
  @HttpCode(200)
  @Audience("control")
  async suspend(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    return this.action(request, id, "suspend", body)
  }

  @Post("control/users/:id/reactivate")
  @HttpCode(200)
  @Audience("control")
  async reactivate(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    return this.action(request, id, "reactivate", body)
  }

  @Post("control/users/:id/close")
  @HttpCode(200)
  @Audience("control")
  async close(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    return this.action(request, id, "close", body)
  }

  @Post("control/users/:id/revoke-sessions")
  @HttpCode(200)
  @Audience("control")
  async revokeSessions(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    return this.action(request, id, "revoke_sessions", body)
  }

  @Get("control/users/:id/notes")
  @Audience("control")
  async notes(@Param("id") id: string, @Req() request: FastifyRequest) {
    const { session } = await this.session(request)
    return this.accounts.listNotes({
      accountId: session.accountId,
      userId: session.userId,
      targetUserId: id,
    })
  }

  @Post("control/users/:id/notes")
  @HttpCode(201)
  @Audience("control")
  async addNote(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseNote(body)
    const { context, session } = await this.session(request)
    return this.accounts.addNote({
      accountId: session.accountId,
      userId: session.userId,
      targetUserId: id,
      body: input.body,
      context,
    })
  }

  @Get("control/users/:id/timeline")
  @Audience("control")
  async timeline(@Param("id") id: string, @Req() request: FastifyRequest) {
    const { session } = await this.session(request)
    return this.accounts.timeline({
      accountId: session.accountId,
      userId: session.userId,
      targetUserId: id,
    })
  }
}
