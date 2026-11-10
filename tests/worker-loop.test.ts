import { describe, expect, it } from "vitest"

import {
  OutboxHandlers,
  type OutboxEvent,
  type OutboxLogger,
} from "../server/src/worker/outbox"
import type { OutboxRepository } from "../server/src/worker/outbox-repository"
import { OutboxWorker } from "../server/src/worker/outbox-worker"

const silentLogger: OutboxLogger = {
  info: () => undefined,
  warn: () => undefined,
  error: () => undefined,
}

function event(overrides: Partial<OutboxEvent> = {}): OutboxEvent {
  return {
    id: "event-1",
    eventType: "test.event",
    aggregateType: "test",
    aggregateId: "aggregate-1",
    payload: { value: 1 },
    occurredAt: "2026-11-09T00:00:00.000Z",
    attempts: 0,
    ...overrides,
  }
}

class FakeRepository {
  claimed: OutboxEvent[] = []
  completed: string[] = []
  failed: string[] = []
  deadLettered: string[] = []
  maxAttempts = 3
  loseLease = false

  async claim(limit: number): Promise<readonly OutboxEvent[]> {
    return this.claimed.slice(0, limit)
  }

  async complete(id: string): Promise<boolean> {
    this.completed.push(id)
    return !this.loseLease
  }

  async fail(failedEvent: OutboxEvent, message: string): Promise<{
    attempts: number
    deadLettered: boolean
  }> {
    this.failed.push(message)
    const attempts = failedEvent.attempts + 1
    return { attempts, deadLettered: attempts >= this.maxAttempts }
  }

  async deadLetter(deadEvent: OutboxEvent, message: string): Promise<boolean> {
    this.deadLettered.push(`${deadEvent.id}:${message}`)
    return true
  }
}

function workerWith(
  repository: FakeRepository,
  handlers: OutboxHandlers,
): OutboxWorker {
  return new OutboxWorker(repository as unknown as OutboxRepository, handlers, {
    batchSize: 10,
    pollIntervalMs: 1_000,
    logger: silentLogger,
  })
}

describe("outbox worker loop", () => {
  it("claims, dispatches and completes an event", async () => {
    const repository = new FakeRepository()
    repository.claimed = [event()]
    const handlers = new OutboxHandlers().register(
      "test.event",
      async () => undefined,
    )
    const worker = workerWith(repository, handlers)

    const result = await worker.runOnce()
    expect(result).toEqual({
      claimed: 1,
      processed: 1,
      failed: 0,
      deadLettered: 0,
    })
    expect(repository.completed).toEqual(["event-1"])
  })

  it("replays a redelivered event without duplicating its effect", async () => {
    const repository = new FakeRepository()
    const effects = new Set<string>()
    const handlers = new OutboxHandlers().register(
      "test.event",
      async (event) => {
        effects.add(event.id)
      },
    )
    const worker = workerWith(repository, handlers)

    repository.claimed = [event()]
    await worker.runOnce()
    repository.claimed = [event()]
    await worker.runOnce()

    expect(repository.completed).toEqual(["event-1", "event-1"])
    expect(effects.size).toBe(1)
  })

  it("dead-letters on the attempt that exhausts the budget", async () => {
    const repository = new FakeRepository()
    const handlers = new OutboxHandlers().register("test.event", async () => {
      throw new Error("provider unavailable")
    })
    const worker = workerWith(repository, handlers)

    repository.claimed = [event({ attempts: 0 })]
    expect((await worker.runOnce()).deadLettered).toBe(0)

    repository.claimed = [event({ attempts: 1 })]
    expect((await worker.runOnce()).deadLettered).toBe(0)

    repository.claimed = [event({ attempts: 2 })]
    const last = await worker.runOnce()
    expect(last.failed).toBe(1)
    expect(last.deadLettered).toBe(1)
    expect(repository.failed).toHaveLength(3)
  })

  it("dead-letters an event with no registered handler", async () => {
    const repository = new FakeRepository()
    repository.claimed = [event({ eventType: "not.handled" })]
    const worker = workerWith(repository, new OutboxHandlers())

    const result = await worker.runOnce()
    expect(result.deadLettered).toBe(1)
    expect(repository.deadLettered[0]).toContain("no handler registered")
  })

  it("does not count a completion when the lease was lost", async () => {
    const repository = new FakeRepository()
    repository.loseLease = true
    repository.claimed = [event()]
    const handlers = new OutboxHandlers().register(
      "test.event",
      async () => undefined,
    )
    const worker = workerWith(repository, handlers)

    const result = await worker.runOnce()
    expect(result.claimed).toBe(1)
    expect(result.processed).toBe(0)
  })

  it("returns an empty result when nothing is claimable", async () => {
    const repository = new FakeRepository()
    const worker = workerWith(repository, new OutboxHandlers())
    expect(await worker.runOnce()).toEqual({
      claimed: 0,
      processed: 0,
      failed: 0,
      deadLettered: 0,
    })
  })
})
