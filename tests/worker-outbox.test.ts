import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { Client, Pool } from "pg"
import { afterAll, beforeAll, describe, expect, it } from "vitest"

import { OutboxHandlers, type OutboxLogger } from "../server/src/worker/outbox"
import { OutboxRepository } from "../server/src/worker/outbox-repository"
import { OutboxWorker } from "../server/src/worker/outbox-worker"

const baseUrl = process.env.WORKER_TEST_DATABASE_URL
const describeIntegration = baseUrl ? describe : describe.skip
const databaseName = `hivorr_worker_test_${Date.now()}`

const silentLogger: OutboxLogger = {
  info: () => undefined,
  warn: () => undefined,
  error: () => undefined,
}

describeIntegration("outbox worker integration", () => {
  let admin: Client
  let setup: Client
  let pool: Pool
  let repository: OutboxRepository

  async function insertEvent(
    eventType = "test.event",
    payload: Record<string, unknown> = { value: 1 },
  ): Promise<string> {
    const result = await setup.query(
      `insert into platform.outbox (event_type, aggregate_type, aggregate_id, payload)
       values ($1, 'test', 'aggregate', $2) returning id`,
      [eventType, JSON.stringify(payload)],
    )
    return result.rows[0].id
  }

  async function makeAvailable(id: string): Promise<void> {
    await setup.query(
      "update platform.outbox set available_at = now() where id = $1",
      [id],
    )
  }

  async function row(id: string) {
    const result = await setup.query(
      "select * from platform.outbox where id = $1",
      [id],
    )
    return result.rows[0]
  }

  beforeAll(async () => {
    admin = new Client({ connectionString: baseUrl })
    await admin.connect()
    await admin.query(`create database "${databaseName}"`)

    const url = new URL(baseUrl!)
    url.pathname = `/${databaseName}`
    const testUrl = url.toString()

    setup = new Client({ connectionString: testUrl })
    await setup.connect()

    const migrationsDirectory = path.join(
      process.cwd(),
      "supabase",
      "migrations",
    )
    for (const file of readdirSync(migrationsDirectory)
      .filter((entry) => entry.endsWith(".sql"))
      .sort()) {
      await setup.query(
        readFileSync(path.join(migrationsDirectory, file), "utf8"),
      )
    }

    pool = new Pool({ connectionString: testUrl, max: 4 })
    repository = new OutboxRepository(pool, {
      workerId: "worker-a",
      leaseMs: 60_000,
      maxAttempts: 3,
      retryBaseMs: 1_000,
    })
  }, 30_000)

  afterAll(async () => {
    if (pool) await pool.end()
    if (setup) await setup.end()
    if (admin) {
      await admin.query(
        `drop database if exists "${databaseName}" with (force)`,
      )
      await admin.end()
    }
  })

  it("claims, delivers, and does not reclaim a completed event", async () => {
    const id = await insertEvent()
    const claimed = await repository.claim(10)
    expect(claimed.map((event) => event.id)).toContain(id)
    expect(await repository.complete(id)).toBe(true)

    const processed = await row(id)
    expect(processed.processed_at).toBeTruthy()
    expect(processed.locked_at).toBeNull()

    const again = await repository.claim(10)
    expect(again.map((event) => event.id)).not.toContain(id)
  })

  it("retries with backoff and dead-letters after the attempt budget", async () => {
    const id = await insertEvent()
    let events = await repository.claim(10)
    let event = events.find((candidate) => candidate.id === id)!
    expect(event).toBeTruthy()

    const first = await repository.fail(event, "provider unavailable")
    expect(first).toEqual({ attempts: 1, deadLettered: false })
    const scheduled = await row(id)
    expect(new Date(scheduled.available_at).getTime()).toBeGreaterThan(
      Date.now() + 500,
    )

    expect((await repository.claim(10)).map((e) => e.id)).not.toContain(id)

    await makeAvailable(id)
    events = await repository.claim(10)
    event = events.find((candidate) => candidate.id === id)!
    expect((await repository.fail(event, "still unavailable")).attempts).toBe(2)

    await makeAvailable(id)
    events = await repository.claim(10)
    event = events.find((candidate) => candidate.id === id)!
    const last = await repository.fail(event, "final failure")
    expect(last).toEqual({ attempts: 3, deadLettered: true })

    const dead = await row(id)
    expect(dead.dead_lettered_at).toBeTruthy()
    expect(dead.last_error).toBe("final failure")
    expect((await repository.claim(10)).map((e) => e.id)).not.toContain(id)
  })

  it("reclaims an event whose lease expired", async () => {
    const id = await insertEvent()
    const claimed = await repository.claim(10)
    expect(claimed.map((event) => event.id)).toContain(id)

    await setup.query(
      "update platform.outbox set locked_at = now() - interval '2 minutes' where id = $1",
      [id],
    )

    const reclaimed = await repository.claim(10)
    expect(reclaimed.map((event) => event.id)).toContain(id)
    await repository.complete(id)
  })

  it("dead-letters an event with no registered handler", async () => {
    const id = await insertEvent("not.handled")
    const worker = new OutboxWorker(repository, new OutboxHandlers(), {
      batchSize: 10,
      pollIntervalMs: 1_000,
      logger: silentLogger,
    })

    const result = await worker.runOnce()
    expect(result.claimed).toBeGreaterThanOrEqual(1)
    expect(result.deadLettered).toBeGreaterThanOrEqual(1)

    const dead = await row(id)
    expect(dead.dead_lettered_at).toBeTruthy()
    expect(dead.last_error).toContain("no handler registered")
  })

  it("delivers again on replay and stays idempotent when keyed by event id", async () => {
    const id = await insertEvent("test.idempotent")
    let calls = 0
    const effects = new Set<string>()
    const handlers = new OutboxHandlers().register(
      "test.idempotent",
      async (event) => {
        calls += 1
        effects.add(event.id)
      },
    )
    const worker = new OutboxWorker(repository, handlers, {
      batchSize: 10,
      pollIntervalMs: 1_000,
      logger: silentLogger,
    })

    await worker.runOnce()
    expect(calls).toBe(1)
    expect(effects.size).toBe(1)
    expect((await row(id)).processed_at).toBeTruthy()

    // Simulate an at-least-once redelivery of the same event id.
    await setup.query(
      "update platform.outbox set processed_at = null, locked_at = null, locked_by = null where id = $1",
      [id],
    )
    await worker.runOnce()

    expect(calls).toBe(2)
    expect(effects.size).toBe(1)
    expect(effects.has(id)).toBe(true)
  })

  it("retries a throwing handler and dead-letters it at the limit", async () => {
    const id = await insertEvent("test.always_fails")
    const handlers = new OutboxHandlers().register(
      "test.always_fails",
      async () => {
        throw new Error("handler exploded")
      },
    )
    const worker = new OutboxWorker(repository, handlers, {
      batchSize: 10,
      pollIntervalMs: 1_000,
      logger: silentLogger,
    })

    const first = await worker.runOnce()
    expect(first.failed).toBeGreaterThanOrEqual(1)
    await makeAvailable(id)
    await worker.runOnce()
    await makeAvailable(id)
    await worker.runOnce()

    const dead = await row(id)
    expect(dead.dead_lettered_at).toBeTruthy()
    expect(dead.attempts).toBe(3)
  })

  it("reports queue health", async () => {
    const health = await repository.health()
    expect(health.pending).toBeGreaterThanOrEqual(0)
    expect(health.deadLettered).toBeGreaterThanOrEqual(1)
    expect(typeof health.leased).toBe("number")
  })
})
