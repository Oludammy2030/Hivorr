export type ApiErrorCode = "UNAUTHENTICATED" | "FORBIDDEN" | "VALIDATION_FAILED" | "NOT_FOUND" | "CONFLICT" | "RATE_LIMITED" | "SERVICE_UNAVAILABLE" | "INTERNAL_ERROR"

export class ApiError extends Error {
  constructor(
    readonly code: ApiErrorCode,
    message: string,
    readonly statusCode: number,
  ) {
    super(message)
    this.name = "ApiError"
  }
}

export interface ApiErrorBody {
  readonly error: {
    readonly code: ApiErrorCode
    readonly message: string
    readonly correlationId?: string
  }
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
