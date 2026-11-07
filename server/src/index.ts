/**
 * API and worker boundary.
 *
 * EP-01-010 bootstraps the NestJS + Fastify API here, and EP-01-014 adds the
 * worker. This package exists from EP-01-002 so the server cannot be imported
 * by a portal bundle and so the workspace graph is real before the API is
 * implemented.
 */

export const SERVER_PACKAGE_NAME = "@hivorr/server" as const
export const API_VERSION = "v1" as const

export { createApplication } from "./app"
export {
  loadConfig,
  parseConfig,
  ConfigurationError,
  API_CONFIG,
} from "./config"
export type { ApiConfig, DeploymentEnvironment } from "./config"
export { can, computeCapabilities, CAPABILITY_IDS } from "./domain/capabilities"
export type {
  AccessContext,
  CapabilityId,
  GrantId,
} from "./domain/capabilities"
export { ApiError, toErrorBody } from "./common/errors"
export type { ApiErrorBody, ApiErrorCode } from "./common/errors"
export { resolveCorrelationId } from "./common/correlation"
