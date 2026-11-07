import { Inject, Injectable, type OnApplicationShutdown } from "@nestjs/common"
import { Pool } from "pg"

import { API_CONFIG, type ApiConfig } from "../config"

@Injectable()
export class DatabaseService implements OnApplicationShutdown {
  readonly pool: Pool

  constructor(@Inject(API_CONFIG) config: ApiConfig) {
    const remote =
      config.environment === "staging" || config.environment === "production"
    let local = false
    if (config.databaseUrl) {
      try {
        const host = new URL(config.databaseUrl).hostname
        local = host === "127.0.0.1" || host === "localhost"
      } catch {
        local = false
      }
    }
    this.pool = new Pool({
      connectionString: config.databaseUrl,
      max: 10,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
      application_name: `hivorr-api-${config.environment}`,
      ssl: remote && !local ? { rejectUnauthorized: true } : undefined,
    })
  }

  async onApplicationShutdown(): Promise<void> {
    await this.pool.end()
  }
}
