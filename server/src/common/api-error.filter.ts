import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
} from "@nestjs/common"
import type { FastifyReply, FastifyRequest } from "fastify"

import { ApiError, toErrorBody, type ApiErrorCode } from "./errors"

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
export class ApiErrorFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const context = host.switchToHttp()
    const reply = context.getResponse<FastifyReply>()
    const request = context.getRequest<FastifyRequest & {
      correlationId?: string
    }>()
    const correlationId = request.correlationId

    if (exception instanceof ApiError) {
      reply
        .status(exception.statusCode)
        .send(toErrorBody(exception, correlationId))
      return
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus()
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

    reply.status(500).send({
      error: {
        code: "INTERNAL_ERROR",
        message: "An unexpected error occurred.",
        ...(correlationId ? { correlationId } : {}),
      },
    })
  }
}
