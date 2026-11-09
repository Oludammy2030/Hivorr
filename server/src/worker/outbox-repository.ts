import type { Pool, PoolClient } from "pg"

import { retryDelayMs, type OutboxEvent } from "./outbox"

export interface OutboxRepositoryOptions {
  readonly workerId: string
  readonly leaseMs: number
  readonly maxAttempts: number
  readonly retryBaseMs: number
}

export interface OutboxHealth {
  readonly pending: number
  readonly leased: number
  readonly deadLettered: number
  readonly oldestPendingAt: string | null
}

export interface FailResult {
  readonly attempts: number
  readonly deadLettered: boolean
}

interface OutboxRow {
  id: string
  event_type: string
  aggregate_type: string
  aggregate_id: string
  payload: unknown
  occurred_at: string
  attempts: number
}

function toEvent(row: OutboxRow): OutboxEvent {
  return {
    id: row.id,
    eventType: row.event_type,
    aggregateType: row.aggregate_type,
    aggregateId: row.aggregate_id,
    payload: row.payload,
    occurredAt: row.occurred_at,
    attempts: row.attempts,
  }
}

/**
 * Durable access to the transactional outbox. Claims are leases, not locks:
 * a worker that crashes stops refreshing `locked_at`, and the event becomes
 * claimable again after the lease expires.
 */
export class OutboxRepository {
  constructor(
    private readonly pool: Pool,
    private readonly options: OutboxRepositoryOptions,
  ) {}

  async claim(limit: number): Promise<readonly OutboxEvent[]> {
    if (!Number.isInteger(limit) || limit < 1) return []
    const client = await this.pool.connect()
    try {
      await client.query("begin")
      const rows = await this.lockClaimable(client, limit)
      if (rows.length > 0) {
        await client.query(
          `update platform.outbox
           set locked_at = now(), locked_by = $1
           where id = any($2::uuid[])`,
          [this.options.workerId, rows.map((row) => row.id)],
        )
      }
      await client.query("commit")
      return rows.map(toEvent)
    } catch (error) {
      await client.query("rollback").catch(() => undefined)
      throw error
    } finally {
      client.release()
    }
  }

  private async lockClaimable(
    client: PoolClient,
    limit: number,
  ): Promise<OutboxRow[]> {
    const result = await client.query<OutboxRow>(
      `select id, event_type, aggregate_type, aggregate_id, payload,
              occurred_at, attempts
       from platform.outbox
       where processed_at is null
         and dead_lettered_at is null
         and available_at <= now()
         and (
           locked_at is null
           or locked_at <= now() - ($1::int * interval '1 millisecond')
         )
       order by available_at, occurred_at
       limit $2
       for update skip locked`,
      [this.options.leaseMs, limit],
    )
    return result.rows
  }

  /** Marks the event delivered. Returns false if the lease was lost. */
  async complete(id: string): Promise<boolean> {
    const result = await this.pool.query(
      `update platform.outbox
       set processed_at = now(), locked_at = null, locked_by = null,
           last_error = null
       where id = $1 and processed_at is null and locked_by = $2`,
      [id, this.options.workerId],
    )
    return (result.rowCount ?? 0) === 1
  }

  /**
   * Dead-letters an event that cannot succeed, such as an event with no
   * registered handler. It is not retried.
   */
  async deadLetter(event: OutboxEvent, message: string): Promise<boolean> {
    const result = await this.pool.query(
      `update platform.outbox
       set attempts = attempts + 1,
           last_error = $3,
           locked_at = null,
           locked_by = null,
           dead_lettered_at = now()
       where id = $1 and processed_at is null and locked_by = $2`,
      [event.id, this.options.workerId, message.slice(0, 2_000)],
    )
    return (result.rowCount ?? 0) === 1
  }

  /**
   * Records a failed delivery. The event is rescheduled with exponential
   * backoff, or dead-lettered once it has consumed its attempt budget.
   */
  async fail(
    event: OutboxEvent,
    message: string,
    now = Date.now(),
  ): Promise<FailResult> {
    const attempts = event.attempts + 1
    const deadLettered = attempts >= this.options.maxAttempts
    const delayMs = retryDelayMs(event.attempts, this.options.retryBaseMs)
    const availableAt = new Date(now + delayMs).toISOString()
    const result = await this.pool.query<{
      attempts: number
      dead_lettered_at: string | null
    }>(
      `update platform.outbox
       set attempts = attempts + 1,
           last_error = $3,
           locked_at = null,
           locked_by = null,
           available_at = case when $4 then available_at else $5::timestamptz end,
           dead_lettered_at = case when $4 then now() else null end
       where id = $1 and processed_at is null and locked_by = $2
       returning attempts, dead_lettered_at`,
      [
        event.id,
        this.options.workerId,
        message.slice(0, 2_000),
        deadLettered,
        availableAt,
      ],
    )
    const row = result.rows[0]
    if (!row) return { attempts, deadLettered: false }
    return {
      attempts: row.attempts,
      deadLettered: row.dead_lettered_at !== null,
    }
  }

  async health(): Promise<OutboxHealth> {
    const result = await this.pool.query<{
      pending: string
      leased: string
      dead_lettered: string
      oldest_pending_at: string | null
    }>("select * from platform.outbox_health()")
    const row = result.rows[0]
    return {
      pending: Number(row?.pending ?? 0),
      leased: Number(row?.leased ?? 0),
      deadLettered: Number(row?.dead_lettered ?? 0),
      oldestPendingAt: row?.oldest_pending_at ?? null,
    }
  }
}
