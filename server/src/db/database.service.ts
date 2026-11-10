import { Inject, Injectable, type OnApplicationShutdown } from "@nestjs/common"
import type { Pool } from "pg"

import { API_CONFIG, type ApiConfig } from "../config"
import { createDatabasePool } from "./pool"
import {
  withTransaction,
  type TransactionContext,
  type TransactionOptions,
} from "./transaction"

@Injectable()
export class DatabaseService implements OnApplicationShutdown {
  readonly pool: Pool

  constructor(@Inject(API_CONFIG) config: ApiConfig) {
    this.pool = createDatabasePool(config, {
      applicationName: `hivorr-api-${config.environment}`,
    })
  }

  /** One connection, one transaction, one release. */
  withTransaction<T,>(
    options: TransactionOptions,
    work: (transaction: TransactionContext) => Promise<T>,
  ): Promise<T> {
    return withTransaction(this.pool, options, work)
  }

  async onApplicationShutdown(): Promise<void> {
    await this.pool.end()
  }
}
