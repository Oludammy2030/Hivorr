import { Inject, Injectable, type OnApplicationShutdown } from "@nestjs/common"
import type { Pool } from "pg"

import { API_CONFIG, type ApiConfig } from "../config"
import { createDatabasePool } from "./pool"

@Injectable()
export class DatabaseService implements OnApplicationShutdown {
  readonly pool: Pool

  constructor(@Inject(API_CONFIG) config: ApiConfig) {
    this.pool = createDatabasePool(config, {
      applicationName: `hivorr-api-${config.environment}`,
    })
  }

  async onApplicationShutdown(): Promise<void> {
    await this.pool.end()
  }
}
