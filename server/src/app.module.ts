import { type DynamicModule, Module } from "@nestjs/common"
import { APP_FILTER, APP_GUARD, Reflector } from "@nestjs/core"

import { ApiErrorFilter } from "./common/api-error.filter"
import { AudienceGuard } from "./common/audience"
import { ERROR_TRACKER, CaptureErrorTracker } from "./common/error-tracker"
import { LOGGER, createLogger } from "./common/logger"
import { API_CONFIG, type ApiConfig } from "./config"
import { DatabaseService } from "./db/database.service"
import {
  EMAIL_ADAPTER,
  CaptureEmailAdapter,
} from "./integrations/email/email.adapter"
import { HealthController } from "./health/health.controller"
import { GrantsController } from "./modules/identity/grants/grants.controller"
import { GrantsService } from "./modules/identity/grants/grants.service"
import { IdentityController } from "./modules/identity/identity.controller"
import { IdentityService } from "./modules/identity/identity.service"
import { SessionController } from "./modules/identity/session.controller"
import { ActivityController } from "./api/activity.controller"
import { AuditController } from "./api/audit.controller"
import { UsersController } from "./api/users.controller"
import { ProfileService } from "./modules/profile/profile.service"

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
        UsersController,
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
        { provide: ERROR_TRACKER, useClass: CaptureErrorTracker },
        { provide: EMAIL_ADAPTER, useClass: CaptureEmailAdapter },
        DatabaseService,
        IdentityService,
        ProfileService,
        GrantsService,
      ],
    }
  }
}
