/**
 * Public interface of the identity module.
 *
 * Grants live inside identity because the architecture assigns them to it.
 * Other modules import from this file only; controllers, repositories and
 * implementation files stay private to the module.
 */
export {
  IdentityService,
  MFA_CHALLENGE_TTL_MS,
  MFA_MAX_ATTEMPTS,
  REFRESH_REUSE_LEEWAY_MS,
  createSessionToken,
  hashPassword,
  hashSessionToken,
  isMfaChallenge,
  verifyPassword,
} from "./identity.service"
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
} from "./identity.service"
export { accessToken, requestContext } from "./request-context"
export { resolveAudience, resolveRequestAudience } from "./portal"
export { buildAccessContext, loadAccessContext } from "./access"
export type { AccessContextInputs, LoadAccessContextInput } from "./access"
export {
  buildRefreshCookie,
  buildSessionCookie,
  clearRefreshCookie,
  clearSessionCookie,
  refreshCookieName,
  sessionCookieName,
  sessionPolicy,
} from "./session-policy"
export { GrantsService } from "./grants/grants.service"
export type {
  CreateGrantInput,
  GrantView,
  OwnGrantsView,
} from "./grants/grants.service"
