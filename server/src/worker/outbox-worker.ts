import type { OutboxRepository } from "./outbox-repository"
import type { HandlerRegistry, OutboxLogger } from "./outbox"

export interface OutboxWorkerOptions {
  readonly batchSize: number
  readonly pollIntervalMs: number
  readonly logger: OutboxLogger
}

export interface RunResult {
  readonly claimed: number
  readonly processed: number
  readonly failed: number
  readonly deadLettered: number
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : "unknown handler failure"
}

/**
 * Pulls a batch, dispatches each event to its handler, and waits for the batch
 * before polling again. One worker process is single-batch at a time; scale out
 * with more processes, not with concurrent claims inside one process.
 */
export class OutboxWorker {
  private readonly abort = new AbortController()
  private timer: NodeJS.Timeout | undefined
  private inFlight: Promise<RunResult> | undefined
  private stopping = false

  constructor(
    private readonly repository: OutboxRepository,
    private readonly handlers: HandlerRegistry,
    private readonly options: OutboxWorkerOptions,
  ) {}

  async runOnce(): Promise<RunResult> {
    const events = await this.repository.claim(this.options.batchSize)
    let processed = 0
    let failed = 0
    let deadLettered = 0

    for (const event of events) {
      const handler = this.handlers.get(event.eventType)
      if (!handler) {
        const dead = await this.repository.deadLetter(
          event,
          `no handler registered for event type: ${event.eventType}`,
        )
        if (dead) deadLettered += 1
        this.options.logger.error({
          message: "outbox event has no handler",
          eventId: event.id,
          eventType: event.eventType,
          deadLettered: dead,
        })
        continue
      }

      try {
        await handler(event, {
          signal: this.abort.signal,
          attempt: event.attempts + 1,
        })
        const completed = await this.repository.complete(event.id)
        if (completed) {
          processed += 1
        } else {
          this.options.logger.warn({
            message: "outbox lease was lost before completion",
            eventId: event.id,
            eventType: event.eventType,
          })
        }
      } catch (error) {
        const result = await this.repository.fail(event, messageOf(error))
        failed += 1
        if (result.deadLettered) deadLettered += 1
        this.options.logger.warn({
          message: "outbox handler failed",
          eventId: event.id,
          eventType: event.eventType,
          attempts: result.attempts,
          deadLettered: result.deadLettered,
          error: messageOf(error),
        })
      }
    }

    return {
      claimed: events.length,
      processed,
      failed,
      deadLettered,
    }
  }

  start(): void {
    if (this.timer || this.inFlight) return
    this.stopping = false
    this.schedule(0)
  }

  private schedule(delayMs: number): void {
    this.timer = setTimeout(() => {
      this.timer = undefined
      void this.tick()
    }, delayMs)
  }

  private async tick(): Promise<void> {
    if (this.stopping) return
    this.inFlight = this.runOnce()
    let claimed = 0
    try {
      const result = await this.inFlight
      claimed = result.claimed
    } catch (error) {
      this.options.logger.error({
        message: "outbox poll failed",
        error: messageOf(error),
      })
    } finally {
      this.inFlight = undefined
    }
    if (this.stopping) return
    this.schedule(claimed === 0 ? this.options.pollIntervalMs : 0)
  }

  /**
   * Stops polling, signals in-flight handlers, and waits for the current batch
   * to settle. A handler that ignores the signal delays shutdown, not the lease
   * safety of the queue: its event is reclaimed after the lease expires.
   */
  async stop(): Promise<void> {
    this.stopping = true
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = undefined
    }
    this.abort.abort()
    if (this.inFlight) await this.inFlight.catch(() => undefined)
  }
}
