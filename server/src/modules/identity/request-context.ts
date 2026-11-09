import type { FastifyRequest } from "fastify"

import { ApiError } from "../../common/errors"
import type { ApiConfig } from "../../config"
import type { RequestContext } from "./identity.service"
import { resolveAudience } from "./portal"
import { sessionCookieName } from "./session-policy"

/**
 * Derives the audience and environment from the Host header and the running
 * deployment. A client can never widen either by sending a field.
 */
export function requestContext(
  config: ApiConfig,
  request: FastifyRequest,
): RequestContext {
  // The browser host is forwarded by the edge proxy. It is trusted only when
  // the request carries the shared edge secret, so a direct caller cannot
  // choose a different portal by spoofing a header.
  const forwardedHost = request.headers["x-hivorr-origin-host"]
  const edgeSecret = request.headers["x-hivorr-edge-secret"]
  const trustedForward =
    config.edgeSharedSecret !== undefined &&
    typeof edgeSecret === "string" &&
    edgeSecret === config.edgeSharedSecret &&
    typeof forwardedHost === "string"
  const host = trustedForward ? forwardedHost : request.headers.host

  const audience = resolveAudience(host, config.environment)
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
