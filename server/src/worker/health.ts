import { createServer, type Server } from "node:http"

import type { OutboxRepository } from "./outbox-repository"
import type { OutboxLogger } from "./outbox"

export interface WorkerHealthOptions {
  readonly repository: OutboxRepository
  readonly environment: string
  readonly host: string
  readonly port: number
  readonly logger: OutboxLogger
}

export interface WorkerHealthServer {
  readonly server: Server
  readonly url: string
}

function json(
  response: import("node:http").ServerResponse,
  status: number,
  body: Record<string, unknown>,
): void {
  const payload = JSON.stringify(body)
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  })
  response.end(payload)
}

/**
 * Liveness, readiness, and queue health. The payload never includes event
 * payloads, aggregate ids, or credentials: only counts and timestamps.
 */
export async function startWorkerHealthServer(
  options: WorkerHealthOptions,
): Promise<WorkerHealthServer> {
  const server = createServer(async (request, response) => {
    const path = (request.url ?? "/").split("?")[0]
    if (request.method !== "GET") {
      json(response, 405, { status: "method_not_allowed" })
      return
    }
    if (path === "/health/live") {
      json(response, 200, { status: "ok", environment: options.environment })
      return
    }
    if (path === "/health/ready" || path === "/health/queue") {
      try {
        const health = await options.repository.health()
        json(response, 200, {
          status: "ok",
          environment: options.environment,
          pending: health.pending,
          leased: health.leased,
          deadLettered: health.deadLettered,
          oldestPendingAt: health.oldestPendingAt,
        })
      } catch {
        json(response, 503, {
          status: "unavailable",
          environment: options.environment,
        })
      }
      return
    }
    json(response, 404, { status: "not_found" })
  })

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject)
    server.listen(options.port, options.host, () => {
      server.off("error", reject)
      resolve()
    })
  })

  const address = server.address()
  const port =
    address && typeof address === "object" ? address.port : options.port

  return {
    server,
    url: `http://${options.host}:${port}`,
  }
}

export async function stopWorkerHealthServer(
  server: Server,
  logger: OutboxLogger,
): Promise<void> {
  await new Promise<void>((resolve) => {
    server.close((error) => {
      if (error) {
        logger.warn({ message: "health server closed with an error" })
      }
      resolve()
    })
  })
}
