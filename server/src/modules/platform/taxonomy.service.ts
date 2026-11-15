import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import { appendAudit } from "./audit"

export interface TaxonomyAuditContext {
  readonly audience: string
  readonly environment: string
  readonly ip?: string
  readonly userAgent?: string
  readonly correlationId?: string
}

export interface TaxonomyNodeView {
  readonly id: string
  readonly taxonomy: string
  readonly level: string
  readonly parentId: string | null
  readonly slug: string
  readonly name: string
  readonly description: string | null
  readonly version: number
  readonly effectiveFrom: string
  readonly effectiveTo: string | null
  readonly isActive: boolean
  readonly createdAt: string
  readonly updatedAt: string
}

export interface TaxonomyAttributeView {
  readonly id: string
  readonly nodeId: string
  readonly key: string
  readonly label: string
  readonly dataType: string
  readonly isRequired: boolean
  readonly enumValues: readonly string[] | null
  readonly unit: string | null
  readonly sortOrder: number
  readonly createdAt: string
  readonly updatedAt: string
}

interface NodeRow {
  id: string
  taxonomy: string
  level: string
  parent_id: string | null
  slug: string
  name: string
  description: string | null
  version: number
  effective_from: string
  effective_to: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

interface AttributeRow {
  id: string
  node_id: string
  key: string
  label: string
  data_type: string
  is_required: boolean
  enum_values: string[] | null
  unit: string | null
  sort_order: number
  created_at: string
  updated_at: string
}

function toNodeView(row: NodeRow): TaxonomyNodeView {
  return {
    id: row.id,
    taxonomy: row.taxonomy,
    level: row.level,
    parentId: row.parent_id,
    slug: row.slug,
    name: row.name,
    description: row.description,
    version: row.version,
    effectiveFrom: row.effective_from,
    effectiveTo: row.effective_to,
    isActive: row.is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

function toAttributeView(row: AttributeRow): TaxonomyAttributeView {
  return {
    id: row.id,
    nodeId: row.node_id,
    key: row.key,
    label: row.label,
    dataType: row.data_type,
    isRequired: row.is_required,
    enumValues: row.enum_values,
    unit: row.unit,
    sortOrder: row.sort_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function mapTaxonomyError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to change the taxonomy.",
        403,
      )
    case "P0002":
      throw new ApiError("NOT_FOUND", "The taxonomy record was not found.", 404)
    case "23514":
      throw new ApiError(
        "CONFLICT",
        "The taxonomy change is not valid for this hierarchy.",
        409,
      )
    case "23503":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The parent taxonomy node does not exist.",
        400,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "That slug or attribute key already exists.",
        409,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The taxonomy operation failed.")
  }
}

@Injectable()
export class TaxonomyAdminService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async list(input: {
    accountId: string
    userId: string
    taxonomy?: string
  }): Promise<{
    readonly nodes: readonly TaxonomyNodeView[]
    readonly attributes: readonly TaxonomyAttributeView[]
  }> {
    return this.database.withTransaction(
      { identity: { accountId: input.accountId, userId: input.userId } },
      async (transaction) => {
        const nodes = await transaction.query<NodeRow>(
          `select id, taxonomy, level, parent_id, slug, name, description,
                  version, effective_from, effective_to, is_active,
                  created_at, updated_at
             from platform.taxonomy_nodes
            where ($1::text is null or taxonomy = $1)
            order by taxonomy, level, name`,
          [input.taxonomy?.trim() || null],
        )
        const attributes = await transaction.query<AttributeRow>(
          `select id, node_id, key, label, data_type, is_required,
                  enum_values, unit, sort_order, created_at, updated_at
             from platform.taxonomy_attributes
            order by node_id, sort_order, key`,
        )
        return {
          nodes: nodes.rows.map(toNodeView),
          attributes: attributes.rows.map(toAttributeView),
        }
      },
    )
  }

  async createNode(input: {
    accountId: string
    userId: string
    taxonomy: string
    level: string
    parentId: string | null
    slug: string
    name: string
    description?: string
    version?: number
    effectiveFrom?: string
    reason: string
    context: TaxonomyAuditContext
  }): Promise<TaxonomyNodeView> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<NodeRow>(
            `select * from platform.create_taxonomy_node($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
            [
              input.userId,
              input.taxonomy,
              input.level,
              input.parentId,
              input.slug,
              input.name,
              input.description ?? null,
              input.version ?? 1,
              input.effectiveFrom ?? null,
            ],
          )
          const view = toNodeView(result.rows[0]!)
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "taxonomy.node_created",
            targetType: "taxonomy_node",
            targetId: view.id,
            afterSummary: {
              taxonomy: view.taxonomy,
              level: view.level,
              slug: view.slug,
              name: view.name,
              version: view.version,
            },
            reason: input.reason,
            capability: "admin.configuration.write",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return view
        },
      )
    } catch (error) {
      mapTaxonomyError(error)
    }
  }

  async updateNode(input: {
    accountId: string
    userId: string
    id: string
    name: string
    description?: string
    version?: number
    effectiveFrom?: string
    effectiveTo?: string | null
    isActive?: boolean
    reason: string
    context: TaxonomyAuditContext
  }): Promise<TaxonomyNodeView> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const before = await transaction.query<NodeRow>(
            `select id, taxonomy, level, parent_id, slug, name, description,
                    version, effective_from, effective_to, is_active,
                    created_at, updated_at
               from platform.taxonomy_nodes where id = $1`,
            [input.id],
          )
          const result = await transaction.query<NodeRow>(
            `select * from platform.update_taxonomy_node($1, $2, $3, $4, $5, $6, $7, $8)`,
            [
              input.userId,
              input.id,
              input.name,
              input.description ?? null,
              input.version ?? null,
              input.effectiveFrom ?? null,
              input.effectiveTo ?? null,
              input.isActive ?? null,
            ],
          )
          const view = toNodeView(result.rows[0]!)
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "taxonomy.node_updated",
            targetType: "taxonomy_node",
            targetId: view.id,
            beforeSummary: before.rows[0]
              ? {
                  name: before.rows[0].name,
                  version: before.rows[0].version,
                  isActive: before.rows[0].is_active,
                }
              : undefined,
            afterSummary: {
              name: view.name,
              version: view.version,
              isActive: view.isActive,
            },
            reason: input.reason,
            capability: "admin.configuration.write",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return view
        },
      )
    } catch (error) {
      mapTaxonomyError(error)
    }
  }

  async createAttribute(input: {
    accountId: string
    userId: string
    nodeId: string
    key: string
    label: string
    dataType: string
    isRequired?: boolean
    enumValues?: readonly string[] | null
    unit?: string
    sortOrder?: number
    reason: string
    context: TaxonomyAuditContext
  }): Promise<TaxonomyAttributeView> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<AttributeRow>(
            `select * from platform.create_taxonomy_attribute($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
            [
              input.userId,
              input.nodeId,
              input.key,
              input.label,
              input.dataType,
              input.isRequired ?? false,
              input.enumValues ?? null,
              input.unit ?? null,
              input.sortOrder ?? 0,
            ],
          )
          const view = toAttributeView(result.rows[0]!)
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "taxonomy.attribute_created",
            targetType: "taxonomy_attribute",
            targetId: view.id,
            afterSummary: {
              nodeId: view.nodeId,
              key: view.key,
              dataType: view.dataType,
            },
            reason: input.reason,
            capability: "admin.configuration.write",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return view
        },
      )
    } catch (error) {
      mapTaxonomyError(error)
    }
  }

  async updateAttribute(input: {
    accountId: string
    userId: string
    id: string
    label: string
    dataType: string
    isRequired?: boolean
    enumValues?: readonly string[] | null
    unit?: string
    sortOrder?: number
    reason: string
    context: TaxonomyAuditContext
  }): Promise<TaxonomyAttributeView> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<AttributeRow>(
            `select * from platform.update_taxonomy_attribute($1, $2, $3, $4, $5, $6, $7, $8)`,
            [
              input.userId,
              input.id,
              input.label,
              input.dataType,
              input.isRequired ?? null,
              input.enumValues ?? null,
              input.unit ?? null,
              input.sortOrder ?? null,
            ],
          )
          const view = toAttributeView(result.rows[0]!)
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "taxonomy.attribute_updated",
            targetType: "taxonomy_attribute",
            targetId: view.id,
            afterSummary: {
              nodeId: view.nodeId,
              key: view.key,
              dataType: view.dataType,
            },
            reason: input.reason,
            capability: "admin.configuration.write",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return view
        },
      )
    } catch (error) {
      mapTaxonomyError(error)
    }
  }
}
