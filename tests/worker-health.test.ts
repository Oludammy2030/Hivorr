import { afterEach, describe, expect, it } from "vitest"

import type { OutboxLogger } from "../server/src/worker/outbox"
import type { OutboxRepository } from "../server/src/worker/outbox-repository"
import {
  startWorkerHealthServer,
  stopWorkerHealthServer,
  type WorkerHealthServer,
} from "../server/src/worker/health"

const silentLogger: OutboxLogger = {
  info: () => undefined,
  warn: () => undefined,
  error: () => undefined,
}

let started: WorkerHealthServer | undefined

afterEach(async () => {
  if (started) {
    await stopWorkerHealthServer(started.server, silentLogger)
    started = undefined
  }
})

async function start(health: () => Promise<unknown>) {
  const server = await startWorkerHealthServer({
    repository: { health } as unknown as OutboxRepository,
    environment: "test",
    host: "127.0.0.1",
    port: 0,
    logger: silentLogger,
  })
  started = server
  return server.url
}

describe("worker health endpoints", () => {
  it("reports liveness without touching the database", async () => {
    const url = await start(async () => {
      throw new Error("must not be called")
    })
    const response = await fetch(`${url}/health/live`)
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({
      status: "ok",
      environment: "test",
    })
  })

  it("reports queue depth without exposing event data", async () => {
    const url = await start(async () => ({
      pending: 4,
      leased: 1,
      deadLettered: 2,
      oldestPendingAt: "2026-11-09T00:00:00.000Z",
    }))
    const response = await fetch(`${url}/health/queue`)
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({
      status: "ok",
      environment: "test",
      pending: 4,
      leased: 1,
      deadLettered: 2,
      oldestPendingAt: "2026-11-09T00:00:00.000Z",
    })
  })

  it("fails closed when the queue cannot be read", async () => {
    const url = await start(async () => {
      throw new Error("database unavailable")
    })
    const response = await fetch(`${url}/health/ready`)
    expect(response.status).toBe(503)
    expect(await response.json()).toEqual({
      status: "unavailable",
      environment: "test",
    })
  })

  it("rejects an unknown path and a non-GET method", async () => {
    const url = await start(async () => ({
      pending: 0,
      leased: 0,
      deadLettered: 0,
      oldestPendingAt: null,
    }))
    expect((await fetch(`${url}/nope`)).status).toBe(404)
    expect(
      (
        await fetch(`${url}/health/live`, {
          method: "POST",
        })
      ).status,
    ).toBe(405)
  })
})
