import {
  CaptureErrorTracker,
  type ErrorContext,
  type ErrorTracker,
} from "./error-tracker"

/**
 * Sentry error sink (`D-P0-3`).
 *
 * Deliberately small and dependency-free: it posts a Sentry envelope over
 * `fetch`, so selecting the vendor adds no package or supply-chain surface. The
 * payload carries only what `ErrorContext` already allows — correlation id,
 * method, path without query string, status — plus the error type and a scrubbed
 * message and stack. Request bodies and query strings are never available here,
 * and text is scrubbed before it leaves the process because a driver error can
 * embed an address or a connection string.
 *
 * Reporting is best effort: a transport failure must never fail the request that
 * produced the error, so `capture` never throws and never blocks.
 */
export interface SentryEnvelope {
  readonly url: string
  readonly auth: string
}

export interface SentryTransportRequest {
  readonly url: string
  readonly method: "POST"
  readonly headers: Readonly<Record<string, string>>
  readonly body: string
}

export type SentryTransport = (
  request: SentryTransportRequest,
) => Promise<unknown>

export interface SentryTrackerOptions {
  readonly dsn: string
  readonly environment: string
  readonly release?: string | null
  readonly transport?: SentryTransport
  readonly now?: () => Date
}

const SENTRY_VERSION = "7"
const SENTRY_CLIENT = "hivorr-api/1.0"
const MAX_TEXT_LENGTH = 500

/** Turns a DSN into the envelope endpoint and its auth header. */
export function parseSentryDsn(dsn: string): SentryEnvelope | undefined {
  const match = /^https:\/\/([0-9a-f]+)@([^/]+)\/(\d+)$/.exec(dsn.trim())
  if (!match) return undefined

  const [, key, host, project] = match
  if (!key || !host || !project) return undefined

  return {
    url: `https://${host}/api/${project}/envelope/`,
    auth: `Sentry sentry_version=${SENTRY_VERSION}, sentry_key=${key}, sentry_client=${SENTRY_CLIENT}`,
  }
}

/**
 * Removes the shapes that can carry a person or a credential out of free text:
 * e-mail addresses, anything resembling a URL with userinfo, and bearer or
 * password assignments.
 */
export function scrubSentryText(value: string): string {
  return value
    .replace(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/g, "[redacted-email]")
    .replace(/\b[a-z][a-z0-9+.-]*:\/\/[^\s"'<>]+/gi, "[redacted-url]")
    .replace(
      /\b(password|token|secret|authorization)\s*[=:]\s*\S+/gi,
      "$1=[redacted]",
    )
    .slice(0, MAX_TEXT_LENGTH)
}

interface SentryErrorDetails {
  readonly type: string
  readonly value: string
}

function errorDetails(error: unknown): SentryErrorDetails {
  if (error instanceof Error) {
    return {
      type: error.name || "Error",
      value: scrubSentryText(error.message || "(no message)"),
    }
  }
  if (typeof error === "string") {
    return { type: "Error", value: scrubSentryText(error) }
  }
  return { type: "Error", value: "non-error value captured" }
}

function errorStack(error: unknown): string | undefined {
  if (!(error instanceof Error) || !error.stack) return undefined
  return scrubSentryText(error.stack)
}

export class SentryErrorTracker implements ErrorTracker {
  private readonly envelope: SentryEnvelope
  private readonly transport: SentryTransport
  private readonly now: () => Date
  private pending: Promise<void> = Promise.resolve()

  constructor(private readonly options: SentryTrackerOptions) {
    const envelope = parseSentryDsn(options.dsn)
    if (!envelope) throw new Error("SENTRY_DSN is not a valid Sentry DSN")
    this.envelope = envelope
    this.transport = options.transport ?? defaultTransport
    this.now = options.now ?? (() => new Date())
  }

  capture(error: unknown, context: ErrorContext = {}): void {
    let body: string
    try {
      body = this.buildEnvelope(error, context)
    } catch {
      return
    }

    // Fire and forget; keep the promise so tests and shutdown can await it.
    this.pending = this.pending
      .then(() =>
        this.transport({
          url: this.envelope.url,
          method: "POST",
          headers: {
            "content-type": "application/x-sentry-envelope",
            "x-sentry-auth": this.envelope.auth,
          },
          body,
        }),
      )
      .then(
        () => undefined,
        () => undefined,
      )
  }

  /** Resolves when every queued report has been attempted. */
  flush(): Promise<void> {
    return this.pending
  }

  private buildEnvelope(error: unknown, context: ErrorContext): string {
    const { type, value } = errorDetails(error)
    const eventId = crypto.randomUUID().replace(/-/g, "")
    const sentAt = this.now()

    const event = {
      event_id: eventId,
      timestamp: sentAt.toISOString(),
      platform: "node",
      level: "error",
      environment: this.options.environment,
      ...(this.options.release ? { release: this.options.release } : {}),
      ...(context.route ? { transaction: scrubSentryText(context.route) } : {}),
      tags: {
        ...(context.method ? { method: context.method } : {}),
        ...(context.status ? { status: String(context.status) } : {}),
        ...(context.correlationId
          ? { correlationId: context.correlationId }
          : {}),
      },
      exception: {
        values: [
          {
            type,
            value,
            ...(errorStack(error)
              ? { stacktrace: { raw: errorStack(error) } }
              : {}),
          },
        ],
      },
    }

    const header = {
      event_id: eventId,
      sent_at: sentAt.toISOString(),
      dsn: this.options.dsn,
    }

    return `${JSON.stringify(header)}\n${JSON.stringify({ type: "event" })}\n${JSON.stringify(event)}\n`
  }
}

async function defaultTransport(
  request: SentryTransportRequest,
): Promise<unknown> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 2_000)
  try {
    return await fetch(request.url, {
      method: request.method,
      headers: request.headers,
      body: request.body,
      signal: controller.signal,
    })
  } finally {
    clearTimeout(timeout)
  }
}

/**
 * Chooses the sink. Without a DSN nothing leaves the process, which is the
 * local, test and staging default.
 */
export function createErrorTracker(options: {
  readonly dsn?: string | undefined
  readonly environment: string
  readonly release?: string | null
  readonly transport?: SentryTransport
  readonly now?: () => Date
}): ErrorTracker {
  if (!options.dsn) return new CaptureErrorTracker()
  if (!parseSentryDsn(options.dsn)) return new CaptureErrorTracker()

  return new SentryErrorTracker({
    dsn: options.dsn,
    environment: options.environment,
    release: options.release,
    ...(options.transport ? { transport: options.transport } : {}),
    ...(options.now ? { now: options.now } : {}),
  })
}
