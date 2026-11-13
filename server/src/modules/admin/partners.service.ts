import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { RequestContext } from "../identity"
import { appendAudit } from "../platform"

export interface PartnerOrganisationView {
  readonly id: string
  readonly legalName: string
  readonly tradingName: string | null
  readonly category: string | null
  readonly country: string | null
  readonly status: string
  readonly representatives: number
  readonly agreements: number
  readonly createdAt: string
}

export interface PartnerRepresentativeView {
  readonly id: string
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly role: string
  readonly effectiveFrom: string
  readonly effectiveTo: string | null
}

interface OrganisationRow {
  id: string
  legal_name: string
  trading_name: string | null
  category: string | null
  country: string | null
  status: string
  representatives: string | number
  agreements: string | number
  created_at: string
}

interface RepresentativeRow {
  id: string
  user_id: string
  email: string
  display_name: string | null
  representative_role: string
  effective_from: string
  effective_to: string | null
}

function toOrganisation(row: OrganisationRow): PartnerOrganisationView {
  return {
    id: row.id,
    legalName: row.legal_name,
    tradingName: row.trading_name,
    category: row.category,
    country: row.country,
    status: row.status,
    representatives: Number(row.representatives),
    agreements: Number(row.agreements),
    createdAt: row.created_at,
  }
}

function toRepresentative(row: RepresentativeRow): PartnerRepresentativeView {
  return {
    id: row.id,
    userId: row.user_id,
    email: row.email,
    displayName: row.display_name,
    role: row.representative_role,
    effectiveFrom: row.effective_from,
    effectiveTo: row.effective_to,
  }
}

function codeOf(error: unknown): string | undefined {
  if (typeof error === "object" && error !== null && "code" in error) {
    const value = (error as { code?: unknown }).code
    return typeof value === "string" ? value : undefined
  }
  return undefined
}

function mapPartnerError(error: unknown): never {
  switch (codeOf(error)) {
    case "42501":
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to manage partners.",
        403,
      )
    case "P0002":
      throw new ApiError(
        "NOT_FOUND",
        "The partner organisation or account was not found.",
        404,
      )
    case "23505":
      throw new ApiError(
        "CONFLICT",
        "That person is already an active representative of this partner.",
        409,
      )
    case "23514":
      throw new ApiError(
        "CONFLICT",
        "The organisation is not in a state that allows this change.",
        409,
      )
    case "22023":
      throw new ApiError(
        "VALIDATION_FAILED",
        "The partner request is not valid.",
        400,
      )
    default:
      throw error instanceof Error
        ? error
        : new Error("The partner operation failed.")
  }
}

@Injectable()
export class PartnersService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async list(input: {
    accountId: string
    userId: string
  }): Promise<readonly PartnerOrganisationView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<OrganisationRow>(
            "select * from admin.list_partner_organisations($1)",
            [input.userId],
          )
          return result.rows.map(toOrganisation)
        },
      )
    } catch (error) {
      mapPartnerError(error)
    }
  }

  async create(input: {
    accountId: string
    userId: string
    legalName: string
    tradingName?: string
    category?: string
    country?: string
    reason?: string
    context: RequestContext
  }): Promise<PartnerOrganisationView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 5) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason of at least five characters is required.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<OrganisationRow>(
            "select * from admin.create_partner_organisation($1, $2, $3, $4, $5, $6)",
            [
              input.userId,
              input.legalName,
              input.tradingName ?? null,
              input.category ?? null,
              input.country ?? null,
              reason,
            ],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "partner.created",
            targetType: "partner_organisation",
            targetId: row.id,
            afterSummary: { legalName: row.legal_name, status: row.status },
            reason,
            capability: "admin.partner.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toOrganisation(row)
        },
      )
    } catch (error) {
      mapPartnerError(error)
    }
  }

  async setStatus(input: {
    accountId: string
    userId: string
    organisationId: string
    status: string
    reason?: string
    context: RequestContext
  }): Promise<PartnerOrganisationView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 5) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason of at least five characters is required.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<OrganisationRow>(
            "select * from admin.set_partner_status($1, $2, $3, $4)",
            [input.userId, input.organisationId, input.status, reason],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "partner.status_changed",
            targetType: "partner_organisation",
            targetId: row.id,
            afterSummary: { status: row.status },
            reason,
            capability: "admin.partner.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toOrganisation(row)
        },
      )
    } catch (error) {
      mapPartnerError(error)
    }
  }

  async representatives(input: {
    accountId: string
    userId: string
    organisationId: string
  }): Promise<readonly PartnerRepresentativeView[]> {
    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<RepresentativeRow>(
            "select * from admin.list_partner_representatives($1, $2)",
            [input.userId, input.organisationId],
          )
          return result.rows.map(toRepresentative)
        },
      )
    } catch (error) {
      mapPartnerError(error)
    }
  }

  async addRepresentative(input: {
    accountId: string
    userId: string
    organisationId: string
    email: string
    role: string
    reason?: string
    context: RequestContext
  }): Promise<PartnerRepresentativeView> {
    const reason = input.reason?.trim()
    if (!reason || reason.length < 5) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A reason of at least five characters is required.",
        400,
      )
    }

    try {
      return await this.database.withTransaction(
        { identity: { accountId: input.accountId, userId: input.userId } },
        async (transaction) => {
          const result = await transaction.query<RepresentativeRow>(
            "select * from admin.add_partner_representative($1, $2, $3, $4, $5)",
            [
              input.userId,
              input.organisationId,
              input.email,
              input.role,
              reason,
            ],
          )
          const row = result.rows[0]
          await appendAudit(transaction.client, {
            actorType: "admin",
            actorId: input.userId,
            actorAudience: input.context.audience,
            environment: input.context.environment,
            action: "partner.representative_added",
            targetType: "partner_organisation",
            targetId: input.organisationId,
            afterSummary: { email: row.email, role: row.representative_role },
            reason,
            capability: "admin.partner.manage",
            ip: input.context.ip,
            userAgent: input.context.userAgent,
            correlationId: input.context.correlationId,
          })
          return toRepresentative(row)
        },
      )
    } catch (error) {
      mapPartnerError(error)
    }
  }
}
