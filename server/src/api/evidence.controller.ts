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
  addEvidenceRequest,
  evidenceAccessRequest,
  supersedeEvidenceRequest,
} from "../contracts/schemas"
import { EvidenceService } from "../modules/admin/evidence.service"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"

@Controller()
export class EvidenceController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(EvidenceService) private readonly evidence: EvidenceService,
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

  @Get("control/cases/:id/evidence")
  @Audience("control")
  async list(@Param("id") id: string, @Req() request: FastifyRequest) {
    const { session } = await this.session(request)
    return this.evidence.list({
      accountId: session.accountId,
      userId: session.userId,
      caseId: id,
    })
  }

  @Post("control/cases/:id/evidence")
  @HttpCode(201)
  @Audience("control")
  async add(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(addEvidenceRequest, body)
    const { context, session } = await this.session(request)
    return this.evidence.add({
      accountId: session.accountId,
      userId: session.userId,
      caseId: id,
      storageKey: input.storageKey,
      fileName: input.fileName,
      mimeType: input.mimeType,
      sizeBytes: input.sizeBytes,
      sha256: input.sha256,
      classification: input.classification,
      reason: input.reason,
      context,
    })
  }

  @Post("control/cases/:id/evidence/:evidenceId/access")
  @HttpCode(200)
  @Audience("control")
  async access(
    @Param("evidenceId") evidenceId: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(evidenceAccessRequest, body)
    const { session } = await this.session(request)
    await this.evidence.recordAccess({
      accountId: session.accountId,
      userId: session.userId,
      evidenceId,
      purpose: input.purpose ?? "",
    })
    return { recorded: true }
  }

  @Post("control/evidence/:id/supersede")
  @HttpCode(200)
  @Audience("control")
  async supersede(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(supersedeEvidenceRequest, body)
    const { context, session } = await this.session(request)
    return this.evidence.supersede({
      accountId: session.accountId,
      userId: session.userId,
      evidenceId: id,
      replacementId: input.replacementId,
      reason: input.reason,
      context,
    })
  }
}
