export interface ErrorContext {
  readonly correlationId?: string | undefined
  readonly method?: string | undefined
  /** Path only; a query string is never captured. */
  readonly route?: string | undefined
  readonly status?: number | undefined
}

export interface CapturedError {
  readonly error: unknown
  readonly context: ErrorContext
  readonly capturedAt: string
}

export interface ErrorTracker {
  capture(error: unknown, context?: ErrorContext): void
}

export const ERROR_TRACKER = "HIVORR_ERROR_TRACKER" as const

/**
 * Capture-only error tracker. It holds the raw error and context in memory and
 * performs no network call, so a vendor can be selected later without changing
 * the API. The raw error is never serialised into a log or a response.
 */
export class CaptureErrorTracker implements ErrorTracker {
  private readonly events: CapturedError[] = []

  capture(error: unknown, context: ErrorContext = {}): void {
    this.events.push({
      error,
      context,
      capturedAt: new Date().toISOString(),
    })
  }

  captured(): readonly CapturedError[] {
    return [...this.events]
  }

  clear(): void {
    this.events.length = 0
  }
}
