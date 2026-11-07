import { randomUUID } from "node:crypto"

const SAFE_CORRELATION_ID = /^[A-Za-z0-9._-]{8,128}$/

export function resolveCorrelationId(value: string | undefined): string {
  return value && SAFE_CORRELATION_ID.test(value) ? value : randomUUID()
}
