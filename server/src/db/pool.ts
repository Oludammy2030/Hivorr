import { Pool, type PoolConfig } from "pg"

import type { ApiConfig } from "../config"

function isLocalHost(databaseUrl: string | undefined): boolean {
  if (!databaseUrl) return false
  try {
    const host = new URL(databaseUrl).hostname
    return host === "127.0.0.1" || host === "localhost"
  } catch {
    return false
  }
}

export interface DatabasePoolOptions {
  readonly applicationName: string
  readonly max?: number
  /** Override when a process uses a dedicated least-privilege role. */
  readonly databaseUrl?: string
}

/**
 * One pool factory for every process. Managed staging and production databases
 * require TLS; a local container on loopback does not. The application name is
 * set so a provider session list shows which process owns a connection.
 */
export function createDatabasePool(
  config: ApiConfig,
  options: DatabasePoolOptions,
): Pool {
  const databaseUrl = options.databaseUrl ?? config.databaseUrl
  const remote =
    config.environment === "staging" || config.environment === "production"

  // Supabase's shared pooler presents a chain rooted in a project certificate.
  // When that certificate is supplied, verify it. Otherwise the connection is
  // still encrypted, matching libpq's sslmode=require, but the server is not
  // authenticated. Set DATABASE_SSL_CA to close that gap.
  const ssl =
    remote && !isLocalHost(databaseUrl)
      ? config.databaseSslCa
        ? { ca: config.databaseSslCa, rejectUnauthorized: true }
        : { rejectUnauthorized: false }
      : undefined

  const poolConfig: PoolConfig = {
    connectionString: databaseUrl,
    max: options.max ?? 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    application_name: options.applicationName,
    ssl,
  }
  return new Pool(poolConfig)
}
