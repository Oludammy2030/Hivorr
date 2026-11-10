import {
  type CanActivate,
  type ExecutionContext,
  Inject,
  Injectable,
  SetMetadata,
} from "@nestjs/common"
import { PATH_METADATA } from "@nestjs/common/constants"
import { Reflector } from "@nestjs/core"
import { getPortalByHost, type PortalId } from "@hivorr/shared"
import type { FastifyRequest } from "fastify"

import { API_CONFIG, type ApiConfig } from "../config"
import { ApiError } from "./errors"

/**
 * Audience declaration and enforcement (ARCHITECTURE.md §9.9, API-04).
 *
 * `public` is reserved for infrastructure routes that are not part of a portal
 * surface, such as health probes. Every other route must name one or more
 * portal audiences.
 */
export type RouteAudience = PortalId | "public"

export const AUDIENCE_METADATA = "hivorr:audience"

export const Audience = (...audiences: readonly RouteAudience[]) =>
  SetMetadata(AUDIENCE_METADATA, Object.freeze([...audiences]))

export function declaredAudiences(
  target: object,
): readonly RouteAudience[] | undefined {
  return Reflect.getMetadata(AUDIENCE_METADATA, target)
}

/**
 * True when a controller prototype member carries a Nest route decorator.
 * Kept here so tests do not need to resolve `@nestjs/common` from the root
 * workspace, which has no server dependency.
 */
export function isRoutedMethod(value: unknown): boolean {
  return (
    typeof value === "function" &&
    Reflect.getMetadata(PATH_METADATA, value) !== undefined
  )
}

/**
 * Resolves the portal audience from the browser host. The edge proxy may
 * forward the original host, but only when it presents the shared secret; a
 * direct caller cannot choose a portal by spoofing a header.
 */
export function resolveRequestAudience(
  config: ApiConfig,
  request: FastifyRequest,
): PortalId | undefined {
  const forwardedHost = request.headers["x-hivorr-origin-host"]
  const edgeSecret = request.headers["x-hivorr-edge-secret"]
  const trustedForward =
    config.edgeSharedSecret !== undefined &&
    typeof edgeSecret === "string" &&
    edgeSecret === config.edgeSharedSecret &&
    typeof forwardedHost === "string"
  const host = trustedForward ? forwardedHost : request.headers.host
  return resolveAudience(host, config.environment)
}

export function resolveAudience(
  hostHeader: string | undefined,
  environment: ApiConfig["environment"],
): PortalId | undefined {
  if (environment !== "staging" && environment !== "production") return
  if (!hostHeader) return
  return getPortalByHost(hostHeader, environment)?.id
}

@Injectable()
export class AudienceGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const declared = this.reflector.getAllAndOverride<readonly RouteAudience[]>(
      AUDIENCE_METADATA,
      [context.getHandler(), context.getClass()],
    )

    if (!declared || declared.length === 0) {
      // A route without a declaration was never reviewed for audience exposure.
      throw new ApiError(
        "INTERNAL_ERROR",
        "This endpoint does not declare an audience.",
        500,
      )
    }

    if (declared.includes("public")) return true

    if (
      this.config.environment !== "staging" &&
      this.config.environment !== "production"
    ) {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        "Session endpoints are not available in this environment.",
        503,
      )
    }

    const request = context.switchToHttp().getRequest<FastifyRequest>()
    const audience = resolveRequestAudience(this.config, request)

    if (!audience) {
      throw new ApiError(
        "FORBIDDEN",
        "This host is not a recognised Hivorr portal.",
        403,
      )
    }
    if (!declared.includes(audience)) {
      throw new ApiError(
        "FORBIDDEN",
        "This audience may not call this endpoint.",
        403,
      )
    }
    ;(request as FastifyRequest & { audience?: PortalId }).audience = audience
    return true
  }
}
