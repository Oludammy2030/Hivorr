import type { ApiErrorBody, ApiErrorCode, CapabilityId } from "@hivorr/shared"

/**
 * Error codes and the error body shape are owned by `@hivorr/shared`. This
 * module owns the server-side error class and its serialisation.
 */
export type { ApiErrorBody, ApiErrorCode } from "@hivorr/shared"

export class ApiError extends Error {
  constructor(
    readonly code: ApiErrorCode,
    message: string,
    readonly statusCode: number,
    readonly headers?: Readonly<Record<string, string>>,
  ) {
    super(message)
    this.name = "ApiError"
  }
}

/**
 * An account that has not activated the activity required for the action.
 * This is a denial, not a validation failure: the request was well formed and
 * the caller is authenticated.
 */
export function activityInactive(
  message = "This activity is not active for the account.",
): ApiError {
  return new ApiError("ACTIVITY_INACTIVE", message, 403)
}

/**
 * A stable rate-limit denial that carries `Retry-After`. The value is seconds,
 * as RFC 9110 requires.
 */
export function rateLimited(
  retryAfterSeconds: number,
  message = "Too many attempts. Try again later.",
): ApiError {
  return new ApiError("RATE_LIMITED", message, 429, {
    "retry-after": String(Math.max(1, Math.ceil(retryAfterSeconds))),
  })
}

export function toErrorBody(
  error: ApiError,
  correlationId?: string,
): ApiErrorBody {
  return {
    error: {
      code: error.code,
      message: error.message,
      ...(correlationId ? { correlationId } : {}),
    },
  }
}

/**
 * Stable capability denial (EP-01-035). The caller must have evaluated the
 * capability inside the same transaction as the write or guarded read.
 */
export function requireCapability(
  capabilities: ReadonlySet<CapabilityId>,
  capability: CapabilityId,
): void {
  if (!capabilities.has(capability)) {
    throw new ApiError(
      "FORBIDDEN",
      "You do not have permission to perform this action.",
      403,
    )
  }
}
