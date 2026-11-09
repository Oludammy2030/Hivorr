/**
 * Transactional-outbox worker.
 *
 * The API writes an event to `platform.outbox` inside the same transaction as
 * the state change. The worker claims a lease, dispatches the event to one
 * registered handler, and records success or failure. Delivery is
 * **at-least-once**, so every handler must be idempotent and keyed by the event
 * id. A handler that throws is retried with exponential backoff until the
 * attempt limit, then dead-lettered for inspection.
 */

export interface OutboxEvent {
  readonly id: string
  readonly eventType: string
  readonly aggregateType: string
  readonly aggregateId: string
  readonly payload: unknown
  readonly occurredAt: string
  /** Attempts already consumed before this delivery. */
  readonly attempts: number
}

export interface OutboxHandlerContext {
  /** Aborted when the worker is shutting down. Long calls should honour it. */
  readonly signal: AbortSignal
  /** Attempt number for this delivery, starting at 1. */
  readonly attempt: number
}

export type OutboxHandler = (
  event: OutboxEvent,
  context: OutboxHandlerContext,
) => Promise<void>

export interface OutboxLogger {
  info(entry: Record<string, unknown>): void
  warn(entry: Record<string, unknown>): void
  error(entry: Record<string, unknown>): void
}

export interface HandlerRegistry {
  get(eventType: string): OutboxHandler | undefined
}

/** A simple registry. Handlers are registered by event type, never by payload. */
export class OutboxHandlers implements HandlerRegistry {
  private readonly handlers = new Map<string, OutboxHandler>()

  register(eventType: string, handler: OutboxHandler): this {
    if (!eventType.trim()) throw new Error("event type is required")
    if (this.handlers.has(eventType)) {
      throw new Error(`handler already registered for ${eventType}`)
    }
    this.handlers.set(eventType, handler)
    return this
  }

  get(eventType: string): OutboxHandler | undefined {
    return this.handlers.get(eventType)
  }

  types(): readonly string[] {
    return [...this.handlers.keys()].sort()
  }
}

/**
 * Exponential backoff without jitter, so retries are deterministic and their
 * timing can be asserted. `attempts` is the number already consumed.
 */
export function retryDelayMs(
  attempts: number,
  baseMs: number,
  capMs = 60 * 60 * 1000,
): number {
  const exponent = Math.max(0, attempts)
  const delay = baseMs * 2 ** Math.min(exponent, 20)
  return Math.min(delay, capMs)
}
