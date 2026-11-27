import type { ApiConfig } from "../config"

export const LOG_LEVELS = ["fatal", "error", "warn", "info", "debug", "trace", "silent"] as const

export type LogLevel = (typeof LOG_LEVELS)[number]

export type LogFields = Record<string, unknown>

export interface Logger {
  error(event: string, fields?: LogFields): void
  warn(event: string, fields?: LogFields): void
  info(event: string, fields?: LogFields): void
  debug(event: string, fields?: LogFields): void
}

export const LOGGER = "HIVORR_LOGGER" as const

export interface LoggerOptions {
  readonly service: string
  readonly environment: ApiConfig["environment"]
  readonly level: LogLevel
  readonly sink?: (line: string) => void
}

const PRIORITY: Record<LogLevel, number> = {
  fatal: 0,
  error: 1,
  warn: 2,
  info: 3,
  debug: 4,
  trace: 5,
  silent: 99,
}

/**
 * Keys whose values are never written to a log. Matching is case-insensitive
 * and applies at every depth. IP, user agent, email and display name are
 * personal data and are redacted with the credentials.
 */
const SENSITIVE_KEYS = new Set([
  "password",
  "passwordhash",
  "token",
  "accesstoken",
  "refreshtoken",
  "challengetoken",
  "authorization",
  "cookie",
  "setcookie",
  "secret",
  "mfakey",
  "mfaencryptionkey",
  "apikey",
  "code",
  "email",
  "phone",
  "ip",
  "useragent",
  "displayname",
  "legalname",
])

const REDACTED = "[redacted]"

const EMAIL_PATTERN = /\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b/g
const URL_PATTERN = /\bhttps?:\/\/[^\s"'<>]+/gi
const PHONE_PATTERN = /(?:\+?\d[\d\s().-]{7,}\d)/g
const LONG_TOKEN_PATTERN = /\b[A-Za-z0-9]{32,}\b/g
const API_KEY_PATTERN = /\bsk_[A-Za-z0-9_]{16,}\b/g

/**
 * Free-text fields can carry PII the key-based redaction cannot see: a provider
 * error may echo an email, a URL with a token, or a phone number. Scrub those
 * shapes before the value reaches the sink. UUIDs keep their hyphens and are not
 * matched by the long-token rule.
 */
export function scrubText(value: string): string {
  return value
    .replace(EMAIL_PATTERN, "[redacted-email]")
    .replace(URL_PATTERN, "[redacted-url]")
    .replace(API_KEY_PATTERN, "[redacted-key]")
    .replace(PHONE_PATTERN, "[redacted-phone]")
    .replace(LONG_TOKEN_PATTERN, "[redacted-token]")
}

export function redact(value: unknown, seen = new WeakSet<object>()): unknown {
  if (typeof value === "string") return scrubText(value)
  if (value === null || typeof value !== "object") return value
  if (seen.has(value)) return "[circular]"
  seen.add(value)

  if (Array.isArray(value)) {
    return value.map((entry) => redact(entry, seen))
  }

  const result: Record<string, unknown> = {}
  for (const [key, entry] of Object.entries(value)) {
    const normalized = key.toLowerCase().replace(/[_-]/g, "")
    result[key] = SENSITIVE_KEYS.has(normalized) ? REDACTED : redact(entry, seen)
  }
  return result
}

/**
 * Structured JSON logger. It writes one line per event and never serialises a
 * raw Error object, so a stack or a provider message cannot carry a secret into
 * the log. The sink is injectable for tests.
 */
export function createLogger(options: LoggerOptions): Logger {
  const sink =
    options.sink ??
    ((line: string) => {
      process.stdout.write(`${line}\n`)
    })

  function write(level: LogLevel, event: string, fields?: LogFields): void {
    if (PRIORITY[level] > PRIORITY[options.level]) return
    const record = {
      ...(redact(fields ?? {}) as Record<string, unknown>),
      timestamp: new Date().toISOString(),
      level,
      service: options.service,
      environment: options.environment,
      event,
    }
    sink(JSON.stringify(record))
  }

  return {
    error: (event, fields) => write("error", event, fields),
    warn: (event, fields) => write("warn", event, fields),
    info: (event, fields) => write("info", event, fields),
    debug: (event, fields) => write("debug", event, fields),
  }
}
