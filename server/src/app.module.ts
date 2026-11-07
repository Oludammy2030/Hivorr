import { type DynamicModule, Module } from "@nestjs/common"

import { HealthController } from "./modules/health/health.controller"
import { API_CONFIG, type ApiConfig } from "./config"

@Module({})
export class AppModule {
  static register(config: ApiConfig): DynamicModule {
    return {
      module: AppModule,
      controllers: [HealthController],
      providers: [{ provide: API_CONFIG, useValue: config }],
    }
  }
}
