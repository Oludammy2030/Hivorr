import { type DynamicModule, Module } from "@nestjs/common"
import { APP_FILTER, APP_GUARD, Reflector } from "@nestjs/core"

import { ApiErrorFilter } from "./common/api-error.filter"
import { AudienceGuard } from "./common/audience"
import { ERROR_TRACKER } from "./common/error-tracker"
import { createErrorTracker } from "./common/sentry-error-tracker"
import { LOGGER, createLogger } from "./common/logger"
import { API_CONFIG, type ApiConfig } from "./config"
import { DatabaseService } from "./db/database.service"
import { EMAIL_ADAPTER } from "./integrations/email/email.adapter"
import { createEmailAdapter } from "./integrations/email/zeptomail.adapter"
import { HealthController } from "./health/health.controller"
import { GrantsController } from "./modules/identity/grants/grants.controller"
import { GrantsService } from "./modules/identity/grants/grants.service"
import { IdentityController } from "./modules/identity/identity.controller"
import { IdentityService } from "./modules/identity/identity.service"
import { SessionController } from "./api/session.controller"
import { ActivityController } from "./api/activity.controller"
import { AuditController } from "./api/audit.controller"
import { ControlAuthorityController } from "./api/control-authority.controller"
import { UsersController } from "./api/users.controller"
import { StaffController } from "./api/staff.controller"
import { StaffInviteController } from "./api/staff-invite.controller"
import { RolesController } from "./api/roles.controller"
import { DenialsController } from "./api/denials.controller"
import { AccountGovernanceController } from "./api/account-governance.controller"
import { ApprovalsController } from "./api/approvals.controller"
import { PartnersController } from "./api/partners.controller"
import { PartnerController } from "./api/partner.controller"
import { CasesController } from "./api/cases.controller"
import { EvidenceController } from "./api/evidence.controller"
import { VerificationController } from "./api/verification.controller"
import { TaxonomyController } from "./api/taxonomy.controller"
import { StaffService } from "./modules/admin/staff.service"
import { RolesService } from "./modules/admin/roles.service"
import { DenialsService } from "./modules/admin/denials.service"
import { AccountGovernanceService } from "./modules/admin/account-governance.service"
import { ApprovalsService } from "./modules/admin/approvals.service"
import { PartnersService } from "./modules/admin/partners.service"
import { PartnerPortalService } from "./modules/admin/partner-portal.service"
import { CasesService } from "./modules/admin/cases.service"
import { EvidenceService } from "./modules/admin/evidence.service"
import { VerificationService } from "./modules/admin/verification.service"
import { DisputeService } from "./modules/admin/dispute.service"
import { ProfileService } from "./modules/profile/profile.service"
import { LedgerService } from "./modules/finance/ledger.service"
import { EscrowService } from "./modules/finance/escrow.service"
import { FinanceLimitService } from "./modules/finance/limit.service"
import { ProviderReferenceService } from "./modules/finance/provider-reference.service"
import { WalletService } from "./modules/finance/wallet.service"
import { TaxonomyAdminService } from "./modules/platform/taxonomy.service"

@Module({})
export class AppModule {
  static register(config: ApiConfig): DynamicModule {
    return {
      module: AppModule,
      controllers: [
        HealthController,
        IdentityController,
        SessionController,
        ActivityController,
        AuditController,
        ControlAuthorityController,
        UsersController,
        StaffController,
        StaffInviteController,
        RolesController,
        DenialsController,
        AccountGovernanceController,
        ApprovalsController,
        PartnersController,
        PartnerController,
        CasesController,
        EvidenceController,
        VerificationController,
        TaxonomyController,
        GrantsController,
      ],
      providers: [
        { provide: API_CONFIG, useValue: config },
        {
          provide: APP_GUARD,
          useFactory: (apiConfig: ApiConfig) =>
            new AudienceGuard(new Reflector(), apiConfig),
          inject: [API_CONFIG],
        },
        { provide: APP_FILTER, useClass: ApiErrorFilter },
        {
          provide: LOGGER,
          useFactory: (apiConfig: ApiConfig) =>
            createLogger({
              service: "hivorr-api",
              environment: apiConfig.environment,
              level: apiConfig.logLevel,
            }),
          inject: [API_CONFIG],
        },
        {
          provide: ERROR_TRACKER,
          useFactory: (apiConfig: ApiConfig) =>
            createErrorTracker({
              dsn: apiConfig.sentryDsn,
              environment: apiConfig.environment,
              release: apiConfig.releaseDigest ?? apiConfig.releaseSha,
            }),
          inject: [API_CONFIG],
        },
        {
          provide: EMAIL_ADAPTER,
          useFactory: (apiConfig: ApiConfig) =>
            createEmailAdapter(apiConfig.mail),
          inject: [API_CONFIG],
        },
        DatabaseService,
        IdentityService,
        ProfileService,
        GrantsService,
        StaffService,
        RolesService,
        DenialsService,
        AccountGovernanceService,
        ApprovalsService,
        PartnersService,
        PartnerPortalService,
        CasesService,
        EvidenceService,
        VerificationService,
        DisputeService,
        TaxonomyAdminService,
        LedgerService,
        WalletService,
        EscrowService,
        ProviderReferenceService,
        FinanceLimitService,
      ],
    }
  }
}
