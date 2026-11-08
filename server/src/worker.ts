import { ConfigurationError, loadConfig } from "./config"
import { createDatabasePool } from "./db/pool"
import { OutboxHandlers, type OutboxLogger } from "./worker/outbox"
import { OutboxRepository } from "./worker/outbox-repository"
import { OutboxWorker } from "./worker/outbox-worker"
import {
  startWorkerHealthServer,
  stopWorkerHealthServer,
} from "./worker/health"

/**
 * Worker entry point.
 *
 * No provider handlers are registered yet. Until a handler lands, an event of
 * that type is dead-lettered with a clear error rather than silently dropped.
 * Register handlers in `createHandlerRegistry` when the notification, payment,
 * or storage adapters exist.
 */
export const consoleLogger: OutboxLogger = {
  info: (entry) => console.log(JSON.stringify({ level: "info", ...entry })),
  warn: (entry) => console.warn(JSON.stringify({ level: "warn", ...entry })),
  error: (entry) => console.error(JSON.stringify({ level: "error", ...entry })),
}

export function createHandlerRegistry(): OutboxHandlers {
  return new OutboxHandlers()
}

async function bootstrap(): Promise<void> {
  const config = loadConfig()
  if (!config.worker.databaseUrl) {
    throw new ConfigurationError(
      "WORKER_DATABASE_URL or DATABASE_URL is required for the worker",
    )
  }

  const pool = createDatabasePool(config, {
    applicationName: `hivorr-worker-${config.environment}`,
    databaseUrl: config.worker.databaseUrl,
  })
  const repository = new OutboxRepository(pool, {
    workerId: config.worker.workerId,
    leaseMs: config.worker.leaseMs,
    maxAttempts: config.worker.maxAttempts,
    retryBaseMs: config.worker.retryBaseMs,
  })
  const worker = new OutboxWorker(repository, createHandlerRegistry(), {
    batchSize: config.worker.batchSize,
    pollIntervalMs: config.worker.pollIntervalMs,
    logger: consoleLogger,
  })

  const health = await startWorkerHealthServer({
    repository,
    environment: config.environment,
    host: config.worker.healthHost,
    port: config.worker.healthPort,
    logger: consoleLogger,
  })

  worker.start()
  consoleLogger.info({
    message: "worker started",
    environment: config.environment,
    workerId: config.worker.workerId,
    health: health.url,
  })

  const shutdown = async (signal: string): Promise<void> => {
    consoleLogger.info({ message: "worker stopping", signal })
    await worker.stop()
    await stopWorkerHealthServer(health.server, consoleLogger)
    await pool.end()
    process.exit(0)
  }

  process.once("SIGTERM", () => void shutdown("SIGTERM"))
  process.once("SIGINT", () => void shutdown("SIGINT"))
}

bootstrap().catch((error: unknown) => {
  const message =
    error instanceof Error ? error.message : "unknown startup failure"
  console.error(`hivorr-worker: failed to start: ${message}`)
  process.exit(1)
})
