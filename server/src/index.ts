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
export { createDatabasePool } from "./db/pool"
export {
  loadConfig,
  parseConfig,
  ConfigurationError,
  API_CONFIG,
  databaseUrlMatchesProjectRef,
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
export {
  createSessionToken,
  hashSessionToken,
  hashPassword,
  verifyPassword,
  isMfaChallenge,
  IdentityService,
  MFA_CHALLENGE_TTL_MS,
  MFA_MAX_ATTEMPTS,
  REFRESH_REUSE_LEEWAY_MS,
} from "./modules/identity/identity.service"
export type {
  IssuedSession,
  MfaChallenge,
  MfaEnrollment,
  RecoveryCodeSet,
  RegisterInput,
  RegistrationResult,
  RequestContext,
  SessionResult,
  SessionSummary,
  SignInInput,
  SignInResult,
} from "./modules/identity/identity.service"
export {
  generateRecoveryCodes,
  hashRecoveryCode,
  MfaCipher,
  normalizeRecoveryCode,
} from "./modules/identity/mfa-crypto"
export {
  base32Decode,
  base32Encode,
  currentTimeStep,
  generateTotpSecret,
  totpCode,
  totpUri,
  verifyTotp,
} from "./modules/identity/totp"
export {
  buildRefreshCookie,
  buildSessionCookie,
  clearRefreshCookie,
  clearSessionCookie,
  refreshCookieName,
  sessionCookieName,
  sessionPolicy,
} from "./modules/identity/session-policy"
export { resolveAudience } from "./modules/identity/portal"
export { OutboxHandlers, retryDelayMs } from "./worker/outbox"
export type {
  HandlerRegistry,
  OutboxEvent,
  OutboxHandler,
  OutboxHandlerContext,
  OutboxLogger,
} from "./worker/outbox"
export { OutboxRepository } from "./worker/outbox-repository"
export type {
  FailResult,
  OutboxHealth,
  OutboxRepositoryOptions,
} from "./worker/outbox-repository"
export { OutboxWorker } from "./worker/outbox-worker"
export type { OutboxWorkerOptions, RunResult } from "./worker/outbox-worker"
export {
  startWorkerHealthServer,
  stopWorkerHealthServer,
} from "./worker/health"
