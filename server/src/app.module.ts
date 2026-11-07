import { type DynamicModule, Module } from "@nestjs/common"

import { API_CONFIG, type ApiConfig } from "./config"
import { DatabaseService } from "./db/database.service"
import { HealthController } from "./modules/health/health.controller"
import { IdentityController } from "./modules/identity/identity.controller"
import { IdentityService } from "./modules/identity/identity.service"

@Module({})
export class AppModule {
  static register(config: ApiConfig): DynamicModule {
    return {
      module: AppModule,
      controllers: [HealthController, IdentityController],
      providers: [
        { provide: API_CONFIG, useValue: config },
        DatabaseService,
        IdentityService,
      ],
    }
  }
}
