import {
  Body,
  Controller,
  Get,
  HttpCode,
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
  createTaxonomyAttributeRequest,
  createTaxonomyNodeRequest,
  updateTaxonomyAttributeRequest,
  updateTaxonomyNodeRequest,
} from "../contracts/schemas"
import {
  IdentityService,
  accessToken,
  requestContext,
} from "../modules/identity"
import { TaxonomyAdminService } from "../modules/platform/taxonomy.service"

@Controller()
export class TaxonomyController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(TaxonomyAdminService)
    private readonly taxonomy: TaxonomyAdminService,
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

  @Get("control/taxonomy")
  @Audience("control")
  async list(
    @Query("taxonomy") taxonomy: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const { session } = await this.session(request)
    return this.taxonomy.list({
      accountId: session.accountId,
      userId: session.userId,
      taxonomy,
    })
  }

  @Post("control/taxonomy/nodes")
  @HttpCode(201)
  @Audience("control")
  async createNode(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(createTaxonomyNodeRequest, body)
    const { context, session } = await this.session(request)
    return this.taxonomy.createNode({
      accountId: session.accountId,
      userId: session.userId,
      taxonomy: input.taxonomy,
      level: input.level,
      parentId: input.parentId ?? null,
      slug: input.slug,
      name: input.name,
      description: input.description,
      version: input.version,
      effectiveFrom: input.effectiveFrom,
      reason: input.reason,
      context,
    })
  }

  @Patch("control/taxonomy/nodes/:id")
  @HttpCode(200)
  @Audience("control")
  async updateNode(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(updateTaxonomyNodeRequest, body)
    const { context, session } = await this.session(request)
    return this.taxonomy.updateNode({
      accountId: session.accountId,
      userId: session.userId,
      id,
      name: input.name,
      description: input.description,
      version: input.version,
      effectiveFrom: input.effectiveFrom,
      effectiveTo: input.effectiveTo,
      isActive: input.isActive,
      reason: input.reason,
      context,
    })
  }

  @Post("control/taxonomy/attributes")
  @HttpCode(201)
  @Audience("control")
  async createAttribute(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(createTaxonomyAttributeRequest, body)
    const { context, session } = await this.session(request)
    return this.taxonomy.createAttribute({
      accountId: session.accountId,
      userId: session.userId,
      nodeId: input.nodeId,
      key: input.key,
      label: input.label,
      dataType: input.dataType,
      isRequired: input.isRequired,
      enumValues: input.enumValues,
      unit: input.unit,
      sortOrder: input.sortOrder,
      reason: input.reason,
      context,
    })
  }

  @Patch("control/taxonomy/attributes/:id")
  @HttpCode(200)
  @Audience("control")
  async updateAttribute(
    @Param("id") id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const input = parseBody(updateTaxonomyAttributeRequest, body)
    const { context, session } = await this.session(request)
    return this.taxonomy.updateAttribute({
      accountId: session.accountId,
      userId: session.userId,
      id,
      label: input.label,
      dataType: input.dataType,
      isRequired: input.isRequired,
      enumValues: input.enumValues,
      unit: input.unit,
      sortOrder: input.sortOrder,
      reason: input.reason,
      context,
    })
  }
}
