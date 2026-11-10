import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  Inject,
  Injectable,
} from "@nestjs/common"
import type { FastifyReply, FastifyRequest } from "fastify"

import { ERROR_TRACKER, type ErrorTracker } from "./error-tracker"
import { ApiError, toErrorBody, type ApiErrorCode } from "./errors"
import { LOGGER, type Logger } from "./logger"

function codeForStatus(status: number): ApiErrorCode {
  if (status === 401) return "UNAUTHENTICATED"
  if (status === 403) return "FORBIDDEN"
  if (status === 404) return "NOT_FOUND"
  if (status === 409) return "CONFLICT"
  if (status === 429) return "RATE_LIMITED"
  if (status === 503) return "SERVICE_UNAVAILABLE"
  if (status >= 500) return "INTERNAL_ERROR"
  return "VALIDATION_FAILED"
}

@Catch()
@Injectable()
export class ApiErrorFilter implements ExceptionFilter {
  constructor(
    @Inject(LOGGER) private readonly logger: Logger,
    @Inject(ERROR_TRACKER) private readonly tracker: ErrorTracker,
  ) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    const context = host.switchToHttp()
    const reply = context.getResponse<FastifyReply>()
    const request = context.getRequest<FastifyRequest & {
      correlationId?: string
    }>()
    const correlationId = request.correlationId

    if (exception instanceof ApiError) {
      if (exception.headers) reply.headers(exception.headers)
      if (exception.statusCode >= 500) {
        this.report(exception, request, correlationId, exception.statusCode)
      }
      reply
        .status(exception.statusCode)
        .send(toErrorBody(exception, correlationId))
      return
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus()
      if (status >= 500) {
        this.report(exception, request, correlationId, status)
      }
      const response = exception.getResponse()
      if (typeof response === "object" && response !== null) {
        reply.status(status).send(response)
        return
      }
      reply.status(status).send({
        error: {
          code: codeForStatus(status),
          message:
            typeof response === "string"
              ? response
              : "The request could not be completed.",
          ...(correlationId ? { correlationId } : {}),
        },
      })
      return
    }

    this.report(exception, request, correlationId, 500)
    reply.status(500).send({
      error: {
        code: "INTERNAL_ERROR",
        message: "An unexpected error occurred.",
        ...(correlationId ? { correlationId } : {}),
      },
    })
  }

  private report(
    exception: unknown,
    request: FastifyRequest,
    correlationId: string | undefined,
    status: number,
  ): void {
    const route = (request.url ?? "").split("?")[0]
    const context = {
      correlationId,
      method: request.method,
      route,
      status,
    }
    this.tracker.capture(exception, context)
    this.logger.error("http.unhandled_error", {
      ...context,
      errorName:
        exception instanceof Error ? exception.name : "UnknownException",
    })
  }
}
