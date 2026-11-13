import { Inject, Injectable } from "@nestjs/common"

import { DatabaseService } from "../../db/database.service"

export interface OwnPartnerOrganisationView {
  readonly organisationId: string
  readonly legalName: string
  readonly tradingName: string | null
  readonly status: string
  readonly role: string
  readonly effectiveFrom: string
}

interface OwnOrganisationRow {
  organisation_id: string
  legal_name: string
  trading_name: string | null
  status: string
  representative_role: string
  effective_from: string
}

/**
 * Partner-facing reads. The organisation is derived from the authenticated user,
 * so a partner cannot ask for another organisation by id.
 */
@Injectable()
export class PartnerPortalService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async organisations(input: {
    accountId: string
    userId: string
  }): Promise<readonly OwnPartnerOrganisationView[]> {
    return this.database.withTransaction(
      { identity: { accountId: input.accountId, userId: input.userId } },
      async (transaction) => {
        const result = await transaction.query<OwnOrganisationRow>(
          "select * from admin.list_own_partner_organisations($1)",
          [input.userId],
        )
        return result.rows.map((row) => ({
          organisationId: row.organisation_id,
          legalName: row.legal_name,
          tradingName: row.trading_name,
          status: row.status,
          role: row.representative_role,
          effectiveFrom: row.effective_from,
        }))
      },
    )
  }
}
