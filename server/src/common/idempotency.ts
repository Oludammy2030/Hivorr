import { createHash } from "node:crypto"

import type { FastifyRequest } from "fastify"
import { z } from "zod"

import { ApiError } from "./errors"

/**
 * Idempotency primitives (ARCHITECTURE.md §9.9, API-08).
 *
 * A money-moving or retryable endpoint requires an `Idempotency-Key` header.
 * The fingerprint binds the key to the request shape, so replaying a key with a
 * different payload is a conflict rather than a silent second mutation.
 *
 * Durable replay against `platform.idempotency_keys` belongs to the endpoints
 * that own a transaction; this module owns the header and fingerprint contract.
 */
export const IDEMPOTENCY_HEADER = "idempotency-key"

export const IDEMPOTENCY_KEY_TTL_MS = 24 * 60 * 60 * 1_000

export const idempotencyKeySchema = z
  .string()
  .min(16)
  .max(128)
  .regex(/^[A-Za-z0-9._:-]+$/)

export function requireIdempotencyKey(request: FastifyRequest): string {
  const header = request.headers[IDEMPOTENCY_HEADER]
  const value = Array.isArray(header) ? header[0] : header
  if (value === undefined) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "An Idempotency-Key header is required.",
      400,
    )
  }
  const result = idempotencyKeySchema.safeParse(value)
  if (!result.success) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "The Idempotency-Key header is invalid.",
      400,
    )
  }
  return result.data
}

export function requestFingerprint(
  method: string,
  path: string,
  body: unknown,
): string {
  return createHash("sha256")
    .update(`${method.toUpperCase()} ${path}\n${stableJson(body)}`)
    .digest("hex")
}

function stableJson(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value) ?? "null"
  }
  if (Array.isArray(value)) {
    return `[${value.map(stableJson).join(",")}]`
  }
  const record = value as Record<string, unknown>
  return `{${Object.keys(record)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${stableJson(record[key])}`)
    .join(",")}}`
}
