import type { FastifyRequest } from "fastify"

import type { PortalId } from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { resolveRequestAudience } from "../../common/audience"
import type { ApiConfig } from "../../config"
import type { RequestContext } from "./identity.service"
import { sessionCookieName } from "./session-policy"

/**
 * Derives the audience and environment from the Host header and the running
 * deployment. A client can never widen either by sending a field.
 *
 * The audience guard resolves and stores the audience before the handler runs.
 * The fallback keeps direct service-level callers honest.
 */
export function requestContext(
  config: ApiConfig,
  request: FastifyRequest,
): RequestContext {
  const attached = (request as FastifyRequest & { audience?: PortalId })
    .audience
  const audience = attached ?? resolveRequestAudience(config, request)

  if (!audience) {
    throw new ApiError(
      "FORBIDDEN",
      "This host is not a recognised Hivorr portal.",
      403,
    )
  }
  if (config.environment !== "staging" && config.environment !== "production") {
    throw new ApiError(
      "SERVICE_UNAVAILABLE",
      "Session endpoints are not available in this environment.",
      503,
    )
  }

  return {
    audience,
    environment: config.environment,
    ip: request.ip,
    userAgent:
      typeof request.headers["user-agent"] === "string"
        ? request.headers["user-agent"]
        : undefined,
    correlationId: (request as FastifyRequest & { correlationId?: string })
      .correlationId,
  }
}

export function accessToken(
  request: FastifyRequest,
  context: RequestContext,
): string {
  const token = request.cookies?.[sessionCookieName(context.audience)]
  if (!token) {
    throw new ApiError("UNAUTHENTICATED", "A valid session is required.", 401)
  }
  return token
}
