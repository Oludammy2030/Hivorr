import { z } from "zod"

/**
 * Stable API error codes shared by the server and every client.
 *
 * A client must be able to distinguish unauthenticated, unauthorised,
 * activity-inactive, validation and not-found outcomes without reading prose.
 */
export const API_ERROR_CODES = [
  "UNAUTHENTICATED",
  "FORBIDDEN",
  "ACTIVITY_INACTIVE",
  "VALIDATION_FAILED",
  "NOT_FOUND",
  "CONFLICT",
  "RATE_LIMITED",
  "SERVICE_UNAVAILABLE",
  "INTERNAL_ERROR",
] as const

export type ApiErrorCode = typeof API_ERROR_CODES[number]

export interface ApiErrorBody {
  readonly error: {
    readonly code: ApiErrorCode
    readonly message: string
    readonly correlationId?: string
  }
}

export const apiErrorCodeSchema = z.enum(API_ERROR_CODES)

export const apiErrorBodySchema = z.object({
  error: z.object({
    code: apiErrorCodeSchema,
    message: z.string().min(1),
    correlationId: z.string().min(1).optional(),
  }),
})

export function isApiErrorCode(value: string): value is ApiErrorCode {
  return (API_ERROR_CODES as readonly string[]).includes(value)
}
