import { type DynamicModule, Module } from "@nestjs/common"

import { API_CONFIG, type ApiConfig } from "./config"
import { DatabaseService } from "./db/database.service"
import { HealthController } from "./modules/health/health.controller"
import { GrantsController } from "./modules/grants/grants.controller"
import { GrantsService } from "./modules/grants/grants.service"
import { IdentityController } from "./modules/identity/identity.controller"
import { IdentityService } from "./modules/identity/identity.service"

@Module({})
export class AppModule {
  static register(config: ApiConfig): DynamicModule {
    return {
      module: AppModule,
      controllers: [HealthController, IdentityController, GrantsController],
      providers: [
        { provide: API_CONFIG, useValue: config },
        DatabaseService,
        IdentityService,
        GrantsService,
      ],
    }
  }
}
