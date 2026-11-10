import { createHash, randomBytes } from "node:crypto"

import { Inject, Injectable } from "@nestjs/common"
import { hash, verify } from "@node-rs/argon2"
import type { EnvironmentId, PortalId } from "@hivorr/shared"
import type { PoolClient } from "pg"

import { ApiError, rateLimited } from "../../common/errors"
import { FixedWindowRateLimiter } from "../../common/rate-limiter"
import { API_CONFIG, type ApiConfig } from "../../config"
import { DatabaseService } from "../../db/database.service"
import {
  computeCapabilities,
  type CapabilityId,
} from "../../domain/capabilities"
import {
  EMAIL_ADAPTER,
  CaptureEmailAdapter,
  type EmailAdapter,
} from "../../integrations/email/email.adapter"
import { appendAudit } from "../platform"
import { listActiveActivities } from "../profile"
import { buildAccessContext } from "./access"
import { normalizeEmail } from "./domain/identity"
import { IdentityRepository } from "./repositories/identity.repository"
import {
  generateRecoveryCodes,
  hashRecoveryCode,
  MfaCipher,
} from "./mfa-crypto"
import { sessionPolicy } from "./session-policy"
import { generateTotpSecret, totpUri, verifyTotp } from "./totp"

const ARGON2_OPTIONS = {
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
  // 2 is Argon2id in @node-rs/argon2. The const enum cannot be read under
  // isolatedModules, so the documented numeric value is used.
  algorithm: 2,
} as const

const DUMMY_PASSWORD_HASH = hash(
  "hivorr-dummy-password-not-a-real-account",
  ARGON2_OPTIONS,
)

export interface RequestContext {
  readonly audience: PortalId
  readonly environment: EnvironmentId
  readonly ip?: string
  readonly userAgent?: string
  readonly correlationId?: string
}

export interface RegisterInput {
  readonly email: string
  readonly password: string
  readonly displayName?: string
}

export interface SignInInput {
  readonly email: string
  readonly password: string
  readonly deviceName?: string
}

export interface RegistrationResult {
  readonly accountId: string
  readonly userId: string
  readonly email: string
}

export interface SessionResult {
  readonly sessionId: string
  readonly accountId: string
  readonly userId: string
  readonly email: string
  readonly audience: PortalId
  readonly environment: EnvironmentId
  readonly expiresAt: string
  readonly idleExpiresAt: string
}

export interface SessionActivityView {
  readonly id: string
  readonly state: string
}

export interface CurrentSession extends SessionResult {
  readonly account: {
    readonly id: string
    readonly email: string
    readonly displayName: string | null
    readonly status: string
  }
  readonly activities: readonly SessionActivityView[]
  readonly capabilities: readonly CapabilityId[]
}

export interface IssuedSession
  extends SessionResult {
  /** Short-lived access token, sent in the host-only session cookie. */
  /** Long-lived refresh token, sent only to the auth endpoints. */
  readonly token: string
  readonly refreshToken: string
  readonly maxAgeSeconds: number
  readonly refreshMaxAgeSeconds: number
  readonly accessExpiresAt: string
}

/** A refresh token presented within this window of first use is a retry, not a breach. */
export const REFRESH_REUSE_LEEWAY_MS = 10 * 1000

export interface MfaChallenge {
  readonly mfaRequired: true
  readonly challengeToken: string
  readonly expiresAt: string
}

interface RecoveryRow {
  user_id: string
  account_id: string
  email: string
}

export type SignInResult = IssuedSession | MfaChallenge

export interface MfaEnrollment {
  readonly factorId: string
  readonly secret: string
  readonly otpauthUri: string
}

export interface RecoveryCodeSet {
  readonly recoveryCodes: readonly string[]
}

export interface TotpConfirmationInput {
  readonly factorId: string
  readonly code: string
}

export interface MfaVerificationInput {
  readonly challengeToken: string
  readonly code: string
}

export interface SessionSummary {
  readonly sessionId: string
  readonly current: boolean
  readonly audience: PortalId
  readonly environment: EnvironmentId
  readonly deviceName: string | null
  readonly createdAt: string
  readonly lastSeenAt: string
  readonly idleExpiresAt: string
  readonly expiresAt: string
  readonly mfaSatisfied: boolean
}

export const MFA_CHALLENGE_TTL_MS = 5 * 60 * 1000
export const MFA_MAX_ATTEMPTS = 5
export const PASSWORD_RESET_TTL_MS = 30 * 60 * 1000
export const EMAIL_VERIFICATION_TTL_MS = 24 * 60 * 60 * 1000

export function isMfaChallenge(result: SignInResult): result is MfaChallenge {
  return "mfaRequired" in result
}

interface SessionRow {
  session_id: string
  user_id: string
  account_id: string
  audience: PortalId
  environment: EnvironmentId
  expires_at: string
  idle_expires_at: string
  revoked_at: string | null
  mfa_satisfied_at: string | null
  email: string
}

interface ChallengeRow {
  challenge_id: string
  user_id: string
  account_id: string
  audience: PortalId
  environment: EnvironmentId
  device_name: string | null
  attempts: number
  expires_at: string
  consumed_at: string | null
}

interface RefreshRow {
  refresh_id: string
  session_id: string
  user_id: string
  account_id: string
  audience: PortalId
  environment: EnvironmentId
  email: string
  token_expires_at: string
  session_expires_at: string
  session_idle_expires_at: string
  session_revoked_at: string | null
  used_at: string | null
  replaced_by: string | null
}

export { normalizeEmail } from "./domain/identity"

export function hashSessionToken(token: string): string {
  return createHash("sha256").update(token).digest("hex")
}

export function createSessionToken(): string {
  return randomBytes(32).toString("base64url")
}

export async function hashPassword(password: string): Promise<string> {
  return hash(password, ARGON2_OPTIONS)
}

export async function verifyPassword(
  passwordHash: string,
  password: string,
): Promise<boolean> {
  try {
    return await verify(passwordHash, password)
  } catch {
    return false
  }
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "23505"
  )
}

@Injectable()
export class IdentityService {
  private readonly limiter = new FixedWindowRateLimiter()

  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
    @Inject(EMAIL_ADAPTER)
    private readonly email: EmailAdapter = new CaptureEmailAdapter(),
  ) {}

  async register(
    input: RegisterInput,
    context: RequestContext,
  ): Promise<RegistrationResult> {
    const email = normalizeEmail(input.email)
    const passwordHash = await hashPassword(input.password)

    try {
      return await this.database.withTransaction({}, async (transaction) => {
        const ids = await transaction.query<{
          account_id: string
          user_id: string
        }>(
          "select platform.uuidv7() as account_id, platform.uuidv7() as user_id",
        )
        const accountId = ids.rows[0].account_id
        const userId = ids.rows[0].user_id

        await transaction.setIdentity({ accountId, userId })

        const repository = new IdentityRepository(transaction)
        await repository.createAccountWithOwner({
          accountId,
          userId,
          email,
          displayName: input.displayName ?? null,
          passwordHash,
        })

        await this.audit(transaction.client, context, {
          actorType: "user",
          actorId: userId,
          action: "identity.register",
          targetType: "account",
          targetId: accountId,
          afterSummary: { accountId, userId },
        })

        return { accountId, userId, email }
      })
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ApiError(
          "CONFLICT",
          "An account with this email already exists.",
          409,
        )
      }
      throw error
    }
  }

  async requestPasswordReset(
    email: string,
    context: RequestContext,
  ): Promise<void> {
    const normalized = normalizeEmail(email)
    this.limitReset(normalized, context)
    const token = createSessionToken()
    const tokenHash = hashSessionToken(token)

    const recipient = await this.database.withTransaction(
      {},
      async (transaction) => {
        const lookup = await transaction.query<{
          user_id: string
          account_id: string
        }>(
          "select user_id, account_id from identity.find_login_credential($1)",
          [normalized],
        )
        const row = lookup.rows[0]
        if (!row) return undefined

        await transaction.setIdentity({
          accountId: row.account_id,
          userId: row.user_id,
        })
        await transaction.query(
          `insert into identity.tokens (user_id, purpose, token_hash, expires_at)
           values ($1, 'password_reset', $2, now() + ($3::int * interval '1 millisecond'))`,
          [row.user_id, tokenHash, PASSWORD_RESET_TTL_MS],
        )
        await this.audit(transaction.client, context, {
          actorType: "user",
          actorId: row.user_id,
          action: "identity.password_reset_requested",
          targetType: "user",
          targetId: row.user_id,
        })
        return normalized
      },
    )

    if (!recipient) return
    await this.email.send({
      to: recipient,
      subject: "Reset your Hivorr password",
      text: `Use this single-use token within 30 minutes: ${token}`,
    })
  }

  async resetPassword(
    token: string,
    password: string,
    context: RequestContext,
  ): Promise<void> {
    const tokenHash = hashSessionToken(token)
    const passwordHash = await hashPassword(password)

    const completed = await this.database.withTransaction(
      {},
      async (transaction) => {
        const lookup = await transaction.query<RecoveryRow>(
          "select * from identity.find_password_reset_token($1)",
          [tokenHash],
        )
        const row = lookup.rows[0]
        if (!row) return false

        await transaction.setIdentity({
          accountId: row.account_id,
          userId: row.user_id,
        })
        const consumed = await transaction.query(
          `update identity.tokens
           set consumed_at = now()
           where token_hash = $1 and purpose = 'password_reset'
             and consumed_at is null and expires_at > now()
           returning id`,
          [tokenHash],
        )
        if ((consumed.rowCount ?? 0) !== 1) return false

        await transaction.query(
          `update identity.credentials
           set password_hash = $1, password_updated_at = now(),
               failed_attempts = 0, locked_until = null
           where user_id = $2`,
          [passwordHash, row.user_id],
        )
        await transaction.query(
          `update identity.sessions
           set revoked_at = now(), revoked_reason = 'password_reset'
           where user_id = $1 and revoked_at is null`,
          [row.user_id],
        )
        await this.audit(transaction.client, context, {
          actorType: "user",
          actorId: row.user_id,
          action: "identity.password_reset_completed",
          targetType: "user",
          targetId: row.user_id,
        })
        return true
      },
    )

    if (!completed) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "This reset token is invalid or has expired.",
        400,
      )
    }
  }

  async requestEmailVerification(
    accessToken: string,
    context: RequestContext,
  ): Promise<void> {
    const session = await this.getSession(accessToken, context)
    const token = createSessionToken()
    const tokenHash = hashSessionToken(token)

    await this.database.withTransaction(
      {
        identity: { accountId: session.accountId, userId: session.userId },
      },
      async (transaction) => {
        await transaction.query(
          `insert into identity.tokens (user_id, purpose, token_hash, expires_at)
           values ($1, 'email_verification', $2, now() + ($3::int * interval '1 millisecond'))`,
          [session.userId, tokenHash, EMAIL_VERIFICATION_TTL_MS],
        )
        await this.audit(transaction.client, context, {
          actorType: "user",
          actorId: session.userId,
          action: "identity.email_verification_requested",
          targetType: "user",
          targetId: session.userId,
        })
      },
    )

    await this.email.send({
      to: session.email,
      subject: "Verify your Hivorr email",
      text: `Use this single-use token within 24 hours: ${token}`,
    })
  }

  async verifyEmail(token: string, context: RequestContext): Promise<void> {
    const tokenHash = hashSessionToken(token)

    const completed = await this.database.withTransaction(
      {},
      async (transaction) => {
        const lookup = await transaction.query<RecoveryRow>(
          "select * from identity.find_email_verification_token($1)",
          [tokenHash],
        )
        const row = lookup.rows[0]
        if (!row) return false

        await transaction.setIdentity({
          accountId: row.account_id,
          userId: row.user_id,
        })
        const consumed = await transaction.query(
          `update identity.tokens
           set consumed_at = now()
           where token_hash = $1 and purpose = 'email_verification'
             and consumed_at is null and expires_at > now()
           returning id`,
          [tokenHash],
        )
        if ((consumed.rowCount ?? 0) !== 1) return false

        await transaction.query(
          "update identity.users set email_verified_at = now() where id = $1",
          [row.user_id],
        )
        await this.audit(transaction.client, context, {
          actorType: "user",
          actorId: row.user_id,
          action: "identity.email_verified",
          targetType: "user",
          targetId: row.user_id,
        })
        return true
      },
    )

    if (!completed) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "This verification token is invalid or has expired.",
        400,
      )
    }
  }

  async signIn(
    input: SignInInput,
    context: RequestContext,
  ): Promise<SignInResult> {
    const email = normalizeEmail(input.email)
    this.limitSignIn(email, context)
    const client = await this.database.pool.connect()

    try {
      const lookup = await client.query<{
        user_id: string
        account_id: string
        password_hash: string
        user_status: string
        locked_until: string | null
      }>("select * from identity.find_login_credential($1)", [email])
      const row = lookup.rows[0]

      if (!row) {
        await verifyPassword(await DUMMY_PASSWORD_HASH, input.password).catch(
          () => false,
        )
        throw new ApiError("UNAUTHENTICATED", "Invalid email or password.", 401)
      }

      if (row.user_status !== "active") {
        throw new ApiError("UNAUTHENTICATED", "Invalid email or password.", 401)
      }
      if (
        row.locked_until &&
        new Date(row.locked_until).getTime() > Date.now()
      ) {
        throw rateLimited(
          (new Date(row.locked_until).getTime() - Date.now()) / 1_000,
          "Too many sign-in attempts.",
        )
      }

      const valid = await verifyPassword(row.password_hash, input.password)
      if (!valid) {
        await this.recordFailedAttempt(client, row.account_id, row.user_id)
        throw new ApiError("UNAUTHENTICATED", "Invalid email or password.", 401)
      }

      if (context.audience !== "app") {
        return await this.beginMfaChallenge(
          client,
          row.user_id,
          row.account_id,
          input.deviceName,
          context,
        )
      }

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          row.account_id,
          row.user_id,
        ])
        await client.query(
          "update identity.credentials set failed_attempts = 0, locked_until = null where user_id = $1",
          [row.user_id],
        )

        const issued = await this.createSession(client, {
          accountId: row.account_id,
          userId: row.user_id,
          email,
          deviceName: input.deviceName,
          context,
        })

        await this.audit(client, context, {
          actorType: "user",
          actorId: row.user_id,
          action: "identity.sign_in",
          targetType: "session",
          targetId: issued.sessionId,
          afterSummary: {
            sessionId: issued.sessionId,
            audience: context.audience,
            environment: context.environment,
          },
        })

        await client.query("commit")
        return issued
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  private async beginMfaChallenge(
    client: PoolClient,
    userId: string,
    accountId: string,
    deviceName: string | undefined,
    context: RequestContext,
  ): Promise<MfaChallenge> {
    const token = createSessionToken()
    const tokenHash = hashSessionToken(token)
    const expiresAt = new Date(Date.now() + MFA_CHALLENGE_TTL_MS)

    await client.query("begin")
    try {
      await client.query("select platform.set_identity_context($1, $2)", [
        accountId,
        userId,
      ])

      const factor = await client.query(
        `select 1 from identity.mfa_factors
         where user_id = $1 and factor_type = 'totp'
           and confirmed_at is not null and revoked_at is null
         limit 1`,
        [userId],
      )
      if (factor.rowCount === 0) {
        throw new ApiError(
          "FORBIDDEN",
          "Enrol an authenticator on the main portal before using this portal.",
          403,
        )
      }

      await client.query(
        "update identity.credentials set failed_attempts = 0, locked_until = null where user_id = $1",
        [userId],
      )
      await client.query(
        `insert into identity.mfa_challenges
           (user_id, challenge_hash, audience, environment, device_name, expires_at)
         values ($1, $2, $3, $4, $5, $6)`,
        [
          userId,
          tokenHash,
          context.audience,
          context.environment,
          deviceName ?? null,
          expiresAt.toISOString(),
        ],
      )
      await this.audit(client, context, {
        actorType: "user",
        actorId: userId,
        action: "identity.mfa_challenge",
        targetType: "user",
        targetId: userId,
      })
      await client.query("commit")

      return {
        mfaRequired: true,
        challengeToken: token,
        expiresAt: expiresAt.toISOString(),
      }
    } catch (error) {
      await client.query("rollback").catch(() => undefined)
      throw error
    }
  }

  private async createSession(
    client: PoolClient,
    input: {
      accountId: string
      userId: string
      email: string
      deviceName?: string
      context: RequestContext
    },
  ): Promise<IssuedSession> {
    const accessToken = createSessionToken()
    const accessTokenHash = hashSessionToken(accessToken)
    const refreshToken = createSessionToken()
    const refreshTokenHash = hashSessionToken(refreshToken)
    const policy = sessionPolicy(input.context.audience)
    const now = Date.now()
    const expiresAt = new Date(now + policy.absoluteMs)
    const idleExpiresAt = new Date(now + policy.idleMs)
    const accessExpiresAt = new Date(
      Math.min(now + policy.accessMs, expiresAt.getTime()),
    )

    let deviceId: string | null = null
    if (input.deviceName) {
      const device = await client.query<{ id: string }>(
        "insert into identity.devices (user_id, name) values ($1, $2) returning id",
        [input.userId, input.deviceName],
      )
      deviceId = device.rows[0].id
    }

    const session = await client.query<{ id: string }>(
      `insert into identity.sessions
         (user_id, device_id, audience, environment, refresh_token_hash,
          access_token_hash, access_expires_at, idle_expires_at, expires_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       returning id`,
      [
        input.userId,
        deviceId,
        input.context.audience,
        input.context.environment,
        refreshTokenHash,
        accessTokenHash,
        accessExpiresAt.toISOString(),
        idleExpiresAt.toISOString(),
        expiresAt.toISOString(),
      ],
    )
    const sessionId = session.rows[0].id

    await client.query(
      `insert into identity.refresh_tokens (session_id, token_hash, expires_at)
       values ($1, $2, $3)`,
      [sessionId, refreshTokenHash, expiresAt.toISOString()],
    )

    return {
      token: accessToken,
      refreshToken,
      sessionId,
      accountId: input.accountId,
      userId: input.userId,
      email: input.email,
      audience: input.context.audience,
      environment: input.context.environment,
      expiresAt: expiresAt.toISOString(),
      idleExpiresAt: idleExpiresAt.toISOString(),
      accessExpiresAt: accessExpiresAt.toISOString(),
      maxAgeSeconds: Math.floor(policy.accessMs / 1000),
      refreshMaxAgeSeconds: Math.floor(policy.absoluteMs / 1000),
    }
  }

  async getSession(
    token: string,
    context: RequestContext,
  ): Promise<CurrentSession> {
    const tokenHash = hashSessionToken(token)
    const client = await this.database.pool.connect()

    try {
      const lookup = await client.query<{
        session_id: string
        user_id: string
        account_id: string
        audience: PortalId
        environment: EnvironmentId
        expires_at: string
        idle_expires_at: string
        revoked_at: string | null
        email: string
      }>("select * from identity.find_session_by_access($1)", [tokenHash])
      const session = lookup.rows[0]
      if (!session) {
        throw new ApiError(
          "UNAUTHENTICATED",
          "A valid session is required.",
          401,
        )
      }
      this.assertSessionIsUsable(session, context)

      const now = Date.now()
      const idleExpiresAt = new Date(
        now + sessionPolicy(context.audience).idleMs,
      )

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          session.account_id,
          session.user_id,
        ])

        const status = await client.query<{
          user_status: string
          account_status: string
          display_name: string | null
          email: string
        }>(
          `select u.status as user_status, a.status as account_status,
                  u.display_name, u.email
           from identity.users u
           join identity.accounts a on a.id = u.account_id
           where u.id = $1`,
          [session.user_id],
        )
        const profile = status.rows[0]

        if (
          !profile ||
          profile.user_status !== "active" ||
          profile.account_status !== "active"
        ) {
          await client.query(
            `update identity.sessions
             set revoked_at = now(), revoked_reason = 'user_suspended'
             where user_id = $1 and revoked_at is null`,
            [session.user_id],
          )
          await client.query("commit")
          throw new ApiError(
            "UNAUTHENTICATED",
            "A valid session is required.",
            401,
          )
        }

        await client.query(
          "update identity.sessions set last_seen_at = now(), idle_expires_at = $1 where id = $2",
          [idleExpiresAt.toISOString(), session.session_id],
        )

        const activities = await listActiveActivities(
          client,
          session.account_id,
        )

        const grants = await client.query<{
          scope: string
          environment: string
          expires_at: string | null
          revoked_at: string | null
        }>(
          `select scope, environment, expires_at, revoked_at
           from identity.grants where user_id = $1`,
          [session.user_id],
        )

        const capabilities = [
          ...computeCapabilities(
            buildAccessContext({
              audience: context.audience,
              environment: context.environment,
              activities,
              grants: grants.rows,
            }),
          ),
        ]

        await client.query("commit")

        return {
          sessionId: session.session_id,
          accountId: session.account_id,
          userId: session.user_id,
          email: profile.email,
          audience: session.audience,
          environment: session.environment,
          expiresAt: session.expires_at,
          idleExpiresAt: idleExpiresAt.toISOString(),
          account: {
            id: session.account_id,
            email: profile.email,
            displayName: profile.display_name,
            status: profile.account_status,
          },
          activities: activities.map((activity) => ({
            id: activity.id,
            state: activity.state,
          })),
          capabilities,
        }
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  async signOut(token: string, context: RequestContext): Promise<void> {
    const tokenHash = hashSessionToken(token)
    const client = await this.database.pool.connect()

    try {
      const lookup = await client.query<{
        session_id: string
        user_id: string
        account_id: string
        audience: PortalId
        environment: EnvironmentId
        expires_at?: string
        idle_expires_at?: string
        revoked_at?: string | null
      }>("select * from identity.find_session_by_access($1)", [tokenHash])
      const session = lookup.rows[0]
      if (!session) return
      this.assertSessionIsUsable(session, context, { includeExpiry: false })

      await client.query("begin")
      await client.query("select platform.set_identity_context($1, $2)", [
        session.account_id,
        session.user_id,
      ])
      await client.query(
        "update identity.sessions set revoked_at = now(), revoked_reason = 'sign_out' where id = $1",
        [session.session_id],
      )
      await this.audit(client, context, {
        actorType: "user",
        actorId: session.user_id,
        action: "identity.sign_out",
        targetType: "session",
        targetId: session.session_id,
        beforeSummary: { revoked: false },
        afterSummary: { revoked: true },
      })
      await client.query("commit")
    } finally {
      client.release()
    }
  }

  /**
   * Revokes the session that owns a refresh token. Used by sign-out when the
   * access cookie has already expired but the refresh cookie is still present.
   */
  async signOutByRefresh(
    refreshToken: string,
    context: RequestContext,
  ): Promise<void> {
    const client = await this.database.pool.connect()

    try {
      const lookup = await client.query<RefreshRow>(
        "select * from identity.find_refresh_token($1)",
        [hashSessionToken(refreshToken)],
      )
      const found = lookup.rows[0]
      if (!found) return
      if (
        found.audience !== context.audience ||
        found.environment !== context.environment
      ) {
        return
      }
      if (found.session_revoked_at) return

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          found.account_id,
          found.user_id,
        ])
        await client.query(
          "update identity.sessions set revoked_at = now(), revoked_reason = 'sign_out' where id = $1 and revoked_at is null",
          [found.session_id],
        )
        await this.audit(client, context, {
          actorType: "user",
          actorId: found.user_id,
          action: "identity.sign_out",
          targetType: "session",
          targetId: found.session_id,
          beforeSummary: { revoked: false },
          afterSummary: { revoked: true },
        })
        await client.query("commit")
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  /**
   * Rotates a refresh token. The old token is marked used inside the same
   * transaction that writes its replacement, so two concurrent successes are
   * impossible. A spent token presented outside the retry leeway is treated as
   * theft: the whole session is revoked and the event is audited.
   */
  async refresh(
    refreshToken: string,
    context: RequestContext,
  ): Promise<IssuedSession> {
    const client = await this.database.pool.connect()

    try {
      const lookup = await client.query<RefreshRow>(
        "select * from identity.find_refresh_token($1)",
        [hashSessionToken(refreshToken)],
      )
      const found = lookup.rows[0]
      if (!found) {
        throw new ApiError(
          "UNAUTHENTICATED",
          "The refresh token is invalid or has expired.",
          401,
        )
      }
      if (
        found.audience !== context.audience ||
        found.environment !== context.environment
      ) {
        throw new ApiError(
          "FORBIDDEN",
          "This refresh token belongs to another portal.",
          403,
        )
      }

      let committed = false
      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          found.account_id,
          found.user_id,
        ])

        const identityStatus = await client.query<{
          user_status: string
          account_status: string
        }>(
          `select u.status as user_status, a.status as account_status
           from identity.users u
           join identity.accounts a on a.id = u.account_id
           where u.id = $1`,
          [found.user_id],
        )
        const activeIdentity = identityStatus.rows[0]
        if (
          !activeIdentity ||
          activeIdentity.user_status !== "active" ||
          activeIdentity.account_status !== "active"
        ) {
          await client.query(
            `update identity.sessions
             set revoked_at = now(), revoked_reason = 'user_suspended'
             where user_id = $1 and revoked_at is null`,
            [found.user_id],
          )
          await client.query("commit")
          committed = true
          throw new ApiError(
            "UNAUTHENTICATED",
            "A valid session is required.",
            401,
          )
        }

        const locked = await client.query<{
          used_at: string | null
          expires_at: string
        }>(
          "select used_at, expires_at from identity.refresh_tokens where id = $1 for update",
          [found.refresh_id],
        )
        const token = locked.rows[0]
        if (!token) {
          throw new ApiError(
            "UNAUTHENTICATED",
            "The refresh token is invalid or has expired.",
            401,
          )
        }

        if (token.used_at) {
          const withinLeeway =
            Date.now() - new Date(token.used_at).getTime() <=
            REFRESH_REUSE_LEEWAY_MS
          if (!withinLeeway) {
            await client.query(
              `update identity.sessions
               set revoked_at = now(), revoked_reason = 'refresh_reuse'
               where id = $1 and revoked_at is null`,
              [found.session_id],
            )
            await this.audit(client, context, {
              actorType: "user",
              actorId: found.user_id,
              action: "identity.refresh_reuse_detected",
              targetType: "session",
              targetId: found.session_id,
            })
          }
          await client.query("commit")
          committed = true
          throw new ApiError(
            "UNAUTHENTICATED",
            "The refresh token has already been used.",
            401,
          )
        }

        const now = Date.now()
        const session = await client.query<{
          expires_at: string
          idle_expires_at: string
          revoked_at: string | null
        }>(
          `select expires_at, idle_expires_at, revoked_at
           from identity.sessions where id = $1 for update`,
          [found.session_id],
        )
        const current = session.rows[0]
        if (
          !current ||
          current.revoked_at ||
          new Date(current.expires_at).getTime() <= now ||
          new Date(current.idle_expires_at).getTime() <= now ||
          new Date(token.expires_at).getTime() <= now
        ) {
          throw new ApiError(
            "UNAUTHENTICATED",
            "The refresh token is invalid or has expired.",
            401,
          )
        }

        const policy = sessionPolicy(context.audience)
        const accessToken = createSessionToken()
        const accessTokenHash = hashSessionToken(accessToken)
        const nextRefreshToken = createSessionToken()
        const nextRefreshTokenHash = hashSessionToken(nextRefreshToken)
        const accessExpiresAt = new Date(
          Math.min(
            now + policy.accessMs,
            new Date(current.expires_at).getTime(),
          ),
        )
        const idleExpiresAt = new Date(
          Math.min(now + policy.idleMs, new Date(current.expires_at).getTime()),
        )

        const replacement = await client.query<{ id: string }>(
          `insert into identity.refresh_tokens
             (session_id, token_hash, expires_at)
           values ($1, $2, $3)
           returning id`,
          [found.session_id, nextRefreshTokenHash, current.expires_at],
        )
        await client.query(
          "update identity.refresh_tokens set used_at = now(), replaced_by = $1 where id = $2",
          [replacement.rows[0].id, found.refresh_id],
        )
        await client.query(
          `update identity.sessions
           set refresh_token_hash = $1,
               access_token_hash = $2,
               access_expires_at = $3,
               idle_expires_at = $4,
               last_seen_at = now()
           where id = $5`,
          [
            nextRefreshTokenHash,
            accessTokenHash,
            accessExpiresAt.toISOString(),
            idleExpiresAt.toISOString(),
            found.session_id,
          ],
        )
        await this.audit(client, context, {
          actorType: "user",
          actorId: found.user_id,
          action: "identity.refresh",
          targetType: "session",
          targetId: found.session_id,
          afterSummary: { sessionId: found.session_id, rotated: true },
        })
        await client.query("commit")
        committed = true

        return {
          token: accessToken,
          refreshToken: nextRefreshToken,
          sessionId: found.session_id,
          accountId: found.account_id,
          userId: found.user_id,
          email: found.email,
          audience: found.audience,
          environment: found.environment,
          expiresAt: current.expires_at,
          idleExpiresAt: idleExpiresAt.toISOString(),
          accessExpiresAt: accessExpiresAt.toISOString(),
          maxAgeSeconds: Math.floor(policy.accessMs / 1000),
          refreshMaxAgeSeconds: Math.max(
            0,
            Math.floor((new Date(current.expires_at).getTime() - now) / 1000),
          ),
        }
      } catch (error) {
        if (!committed) await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  async enrollTotp(
    token: string,
    context: RequestContext,
  ): Promise<MfaEnrollment> {
    if (context.audience !== "app") {
      throw new ApiError(
        "FORBIDDEN",
        "Enrol an authenticator on the main portal.",
        403,
      )
    }
    const cipher = this.cipher()
    const client = await this.database.pool.connect()

    try {
      const session = await this.requireSession(client, token, context)
      const secret = generateTotpSecret()
      const encrypted = cipher.encrypt(secret)

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          session.account_id,
          session.user_id,
        ])
        const factor = await client.query<{ id: string }>(
          `insert into identity.mfa_factors
             (user_id, factor_type, label, secret_ciphertext, key_version)
           values ($1, 'totp', 'Authenticator app', $2, $3)
           returning id`,
          [session.user_id, encrypted.ciphertext, encrypted.keyVersion],
        )
        await this.audit(client, context, {
          actorType: "user",
          actorId: session.user_id,
          action: "identity.mfa_enroll_started",
          targetType: "user",
          targetId: session.user_id,
        })
        await client.query("commit")

        return {
          factorId: factor.rows[0].id,
          secret,
          otpauthUri: totpUri(secret, session.email),
        }
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  async confirmTotp(
    token: string,
    input: TotpConfirmationInput,
    context: RequestContext,
  ): Promise<RecoveryCodeSet> {
    if (context.audience !== "app") {
      throw new ApiError(
        "FORBIDDEN",
        "Enrol an authenticator on the main portal.",
        403,
      )
    }
    const cipher = this.cipher()
    const client = await this.database.pool.connect()

    try {
      const session = await this.requireSession(client, token, context)

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          session.account_id,
          session.user_id,
        ])
        const factor = await client.query<{ secret_ciphertext: string }>(
          `select secret_ciphertext from identity.mfa_factors
           where id = $1 and user_id = $2
             and confirmed_at is null and revoked_at is null`,
          [input.factorId, session.user_id],
        )
        const pending = factor.rows[0]
        if (!pending) {
          throw new ApiError("NOT_FOUND", "The enrolment was not found.", 404)
        }

        const secret = cipher.decrypt(pending.secret_ciphertext)
        if (!verifyTotp(secret, input.code)) {
          throw new ApiError(
            "UNAUTHENTICATED",
            "The verification code is not valid.",
            401,
          )
        }

        const recoveryCodes = generateRecoveryCodes()
        await client.query(
          "update identity.mfa_factors set confirmed_at = now(), last_used_at = now() where id = $1",
          [input.factorId],
        )
        await client.query(
          "delete from identity.recovery_codes where user_id = $1",
          [session.user_id],
        )
        for (const code of recoveryCodes) {
          await client.query(
            "insert into identity.recovery_codes (user_id, code_hash) values ($1, $2)",
            [session.user_id, hashRecoveryCode(code)],
          )
        }
        await client.query(
          "update identity.sessions set mfa_satisfied_at = now() where id = $1",
          [session.session_id],
        )
        await this.audit(client, context, {
          actorType: "user",
          actorId: session.user_id,
          action: "identity.mfa_enrolled",
          targetType: "user",
          targetId: session.user_id,
        })
        await client.query("commit")

        return { recoveryCodes }
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  async verifyMfa(
    input: MfaVerificationInput,
    context: RequestContext,
  ): Promise<IssuedSession> {
    this.limitOtp(hashSessionToken(input.challengeToken), context)
    const client = await this.database.pool.connect()

    try {
      const lookup = await client.query<ChallengeRow>(
        "select * from identity.find_mfa_challenge($1)",
        [hashSessionToken(input.challengeToken)],
      )
      const challenge = lookup.rows[0]
      if (
        !challenge ||
        challenge.consumed_at ||
        new Date(challenge.expires_at).getTime() <= Date.now()
      ) {
        throw new ApiError(
          "UNAUTHENTICATED",
          "The verification challenge is invalid or has expired.",
          401,
        )
      }
      if (challenge.attempts >= MFA_MAX_ATTEMPTS) {
        throw rateLimited(60, "Too many verification attempts.")
      }
      if (
        challenge.audience !== context.audience ||
        challenge.environment !== context.environment
      ) {
        throw new ApiError(
          "FORBIDDEN",
          "This verification challenge belongs to another portal.",
          403,
        )
      }

      let committed = false
      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          challenge.account_id,
          challenge.user_id,
        ])
        const locked = await client.query<{
          attempts: number
          consumed_at: string | null
        }>(
          "select attempts, consumed_at from identity.mfa_challenges where id = $1 for update",
          [challenge.challenge_id],
        )
        const current = locked.rows[0]
        if (!current || current.consumed_at) {
          throw new ApiError(
            "UNAUTHENTICATED",
            "The verification challenge has already been used.",
            401,
          )
        }
        if (current.attempts >= MFA_MAX_ATTEMPTS) {
          throw rateLimited(60, "Too many verification attempts.")
        }

        const verified = await this.verifySecondFactor(
          client,
          challenge.user_id,
          input.code,
        )
        if (!verified) {
          await client.query(
            "update identity.mfa_challenges set attempts = attempts + 1 where id = $1",
            [challenge.challenge_id],
          )
          await client.query("commit")
          committed = true
          throw new ApiError(
            "UNAUTHENTICATED",
            "The verification code is not valid.",
            401,
          )
        }

        await client.query(
          "update identity.mfa_challenges set consumed_at = now() where id = $1",
          [challenge.challenge_id],
        )
        const user = await client.query<{ email: string }>(
          "select email from identity.users where id = $1",
          [challenge.user_id],
        )
        if (!user.rows[0]) {
          throw new ApiError(
            "UNAUTHENTICATED",
            "The verification challenge is invalid or has expired.",
            401,
          )
        }

        const issued = await this.createSession(client, {
          accountId: challenge.account_id,
          userId: challenge.user_id,
          email: user.rows[0].email,
          deviceName: challenge.device_name ?? undefined,
          context,
        })
        await client.query(
          "update identity.sessions set mfa_satisfied_at = now() where id = $1",
          [issued.sessionId],
        )
        await this.audit(client, context, {
          actorType: "user",
          actorId: challenge.user_id,
          action: "identity.mfa_verified",
          targetType: "session",
          targetId: issued.sessionId,
        })
        if (context.audience !== "app") {
          await this.audit(client, context, {
            actorType: "user",
            actorId: challenge.user_id,
            action: "identity.privileged_sign_in",
            targetType: "session",
            targetId: issued.sessionId,
            afterSummary: {
              audience: context.audience,
              environment: context.environment,
            },
          })
        }
        await client.query("commit")
        committed = true
        return issued
      } catch (error) {
        if (!committed) await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  async stepUp(
    token: string,
    code: string,
    context: RequestContext,
  ): Promise<SessionResult> {
    this.limitOtp(hashSessionToken(token), context)
    const client = await this.database.pool.connect()

    try {
      const session = await this.requireSession(client, token, context)

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          session.account_id,
          session.user_id,
        ])
        const verified = await this.verifySecondFactor(
          client,
          session.user_id,
          code,
        )
        if (!verified) {
          throw new ApiError(
            "UNAUTHENTICATED",
            "The verification code is not valid.",
            401,
          )
        }
        await client.query(
          "update identity.sessions set mfa_satisfied_at = now(), last_seen_at = now() where id = $1",
          [session.session_id],
        )
        await this.audit(client, context, {
          actorType: "user",
          actorId: session.user_id,
          action: "identity.mfa_step_up",
          targetType: "session",
          targetId: session.session_id,
        })
        await client.query("commit")

        return this.toSessionResult(session)
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  async listSessions(
    token: string,
    context: RequestContext,
  ): Promise<SessionSummary[]> {
    const client = await this.database.pool.connect()

    try {
      const session = await this.requireSession(client, token, context)

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          session.account_id,
          session.user_id,
        ])
        const rows = await client.query<{
          id: string
          audience: PortalId
          environment: EnvironmentId
          device_name: string | null
          issued_at: string
          last_seen_at: string
          idle_expires_at: string
          expires_at: string
          mfa_satisfied_at: string | null
        }>(
          `select s.id, s.audience, s.environment, d.name as device_name,
                  s.issued_at, s.last_seen_at, s.idle_expires_at, s.expires_at,
                  s.mfa_satisfied_at
           from identity.sessions s
           left join identity.devices d on d.id = s.device_id
           where s.user_id = $1 and s.revoked_at is null
           order by s.last_seen_at desc`,
          [session.user_id],
        )
        await client.query("commit")

        return rows.rows.map((row) => ({
          sessionId: row.id,
          current: row.id === session.session_id,
          audience: row.audience,
          environment: row.environment,
          deviceName: row.device_name,
          createdAt: row.issued_at,
          lastSeenAt: row.last_seen_at,
          idleExpiresAt: row.idle_expires_at,
          expiresAt: row.expires_at,
          mfaSatisfied: row.mfa_satisfied_at !== null,
        }))
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  async revokeSession(
    token: string,
    sessionId: string,
    context: RequestContext,
  ): Promise<void> {
    const client = await this.database.pool.connect()

    try {
      const session = await this.requireSession(client, token, context)

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          session.account_id,
          session.user_id,
        ])
        const updated = await client.query(
          `update identity.sessions
           set revoked_at = now(), revoked_reason = 'revoked_by_user'
           where id = $1 and user_id = $2 and revoked_at is null`,
          [sessionId, session.user_id],
        )
        if (updated.rowCount === 0) {
          throw new ApiError("NOT_FOUND", "The session was not found.", 404)
        }
        await this.audit(client, context, {
          actorType: "user",
          actorId: session.user_id,
          action: "identity.session_revoked",
          targetType: "session",
          targetId: sessionId,
        })
        await client.query("commit")
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  async revokeOtherSessions(
    token: string,
    context: RequestContext,
  ): Promise<number> {
    const client = await this.database.pool.connect()

    try {
      const session = await this.requireSession(client, token, context)

      await client.query("begin")
      try {
        await client.query("select platform.set_identity_context($1, $2)", [
          session.account_id,
          session.user_id,
        ])
        const updated = await client.query(
          `update identity.sessions
           set revoked_at = now(), revoked_reason = 'revoke_others'
           where user_id = $1 and id <> $2 and revoked_at is null`,
          [session.user_id, session.session_id],
        )
        await this.audit(client, context, {
          actorType: "user",
          actorId: session.user_id,
          action: "identity.sessions_revoked",
          targetType: "user",
          targetId: session.user_id,
        })
        await client.query("commit")
        return updated.rowCount ?? 0
      } catch (error) {
        await client.query("rollback").catch(() => undefined)
        throw error
      }
    } finally {
      client.release()
    }
  }

  private cipher(): MfaCipher {
    const cipher = MfaCipher.fromBase64(this.config.mfaEncryptionKey)
    if (!cipher) {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        "Multi-factor authentication is not configured in this environment.",
        503,
      )
    }
    return cipher
  }

  private async requireSession(
    client: PoolClient,
    token: string,
    context: RequestContext,
  ): Promise<SessionRow> {
    const lookup = await client.query<SessionRow>(
      "select * from identity.find_session_by_access($1)",
      [hashSessionToken(token)],
    )
    const session = lookup.rows[0]
    if (!session) {
      throw new ApiError("UNAUTHENTICATED", "A valid session is required.", 401)
    }
    this.assertSessionIsUsable(session, context)
    return session
  }

  private async verifySecondFactor(
    client: PoolClient,
    userId: string,
    code: string,
  ): Promise<boolean> {
    const factors = await client.query<{
      id: string
      secret_ciphertext: string
    }>(
      `select id, secret_ciphertext from identity.mfa_factors
       where user_id = $1 and factor_type = 'totp'
         and confirmed_at is not null and revoked_at is null
       order by created_at`,
      [userId],
    )
    const cipher = this.cipher()
    for (const factor of factors.rows) {
      try {
        if (verifyTotp(cipher.decrypt(factor.secret_ciphertext), code)) {
          await client.query(
            "update identity.mfa_factors set last_used_at = now() where id = $1",
            [factor.id],
          )
          return true
        }
      } catch {
        // An unreadable factor must not block another confirmed factor.
      }
    }

    const recovery = await client.query<{ id: string }>(
      `select id from identity.recovery_codes
       where user_id = $1 and code_hash = $2 and used_at is null`,
      [userId, hashRecoveryCode(code)],
    )
    const match = recovery.rows[0]
    if (match) {
      await client.query(
        "update identity.recovery_codes set used_at = now() where id = $1",
        [match.id],
      )
      return true
    }
    return false
  }

  private toSessionResult(session: SessionRow): SessionResult {
    return {
      sessionId: session.session_id,
      accountId: session.account_id,
      userId: session.user_id,
      email: session.email,
      audience: session.audience,
      environment: session.environment,
      expiresAt: session.expires_at,
      idleExpiresAt: session.idle_expires_at,
    }
  }

  private assertSessionIsUsable(
    session: {
      audience: PortalId
      environment: EnvironmentId
      expires_at?: string
      idle_expires_at?: string
      revoked_at?: string | null
    },
    context: RequestContext,
    options: { includeExpiry?: boolean } = {},
  ): void {
    if (session.revoked_at) {
      throw new ApiError("UNAUTHENTICATED", "A valid session is required.", 401)
    }
    if (session.audience !== context.audience) {
      throw new ApiError(
        "FORBIDDEN",
        "This session belongs to another portal.",
        403,
      )
    }
    if (session.environment !== context.environment) {
      throw new ApiError(
        "FORBIDDEN",
        "This session belongs to another environment.",
        403,
      )
    }
    if (options.includeExpiry === false) return

    const now = Date.now()
    if (
      !session.expires_at ||
      !session.idle_expires_at ||
      new Date(session.expires_at).getTime() <= now ||
      new Date(session.idle_expires_at).getTime() <= now
    ) {
      throw new ApiError("UNAUTHENTICATED", "The session has expired.", 401)
    }
  }

  private async recordFailedAttempt(
    client: PoolClient,
    accountId: string,
    userId: string,
  ): Promise<void> {
    await client.query("begin")
    try {
      await client.query("select platform.set_identity_context($1, $2)", [
        accountId,
        userId,
      ])
      await client.query(
        `update identity.credentials
         set failed_attempts = failed_attempts + 1,
             locked_until = case
               when failed_attempts + 1 >= $2
                 then now() + ($3::int * interval '1 millisecond')
               else locked_until
             end
         where user_id = $1`,
        [userId, this.config.auth.lockoutAttempts, this.config.auth.lockoutMs],
      )
      await client.query("commit")
    } catch (error) {
      await client.query("rollback").catch(() => undefined)
      throw error
    }
  }

  private limit(key: string, max: number): void {
    const result = this.limiter.check(key, {
      windowMs: this.config.auth.rateLimitWindowMs,
      max,
    })
    if (!result.allowed) {
      throw rateLimited(result.retryAfterSeconds)
    }
  }

  private limitSignIn(email: string, context: RequestContext): void {
    this.limit(`signin:id:${email}`, this.config.auth.identifierMax)
    this.limit(`signin:ip:${context.ip ?? "unknown"}`, this.config.auth.ipMax)
  }

  private limitReset(email: string, context: RequestContext): void {
    this.limit(`reset:id:${email}`, this.config.auth.identifierMax)
    this.limit(`reset:ip:${context.ip ?? "unknown"}`, this.config.auth.ipMax)
  }

  private limitOtp(identifier: string, context: RequestContext): void {
    this.limit(`otp:id:${identifier}`, this.config.auth.identifierMax)
    this.limit(`otp:ip:${context.ip ?? "unknown"}`, this.config.auth.ipMax)
  }

  private async audit(
    client: PoolClient,
    context: RequestContext,
    event: {
      actorType: "user" | "staff" | "admin" | "partner" | "developer" | "system"
      actorId: string
      action: string
      targetType: string
      targetId: string
      beforeSummary?: Record<string, unknown>
      afterSummary?: Record<string, unknown>
    },
  ): Promise<void> {
    await appendAudit(client, {
      actorType: event.actorType,
      actorId: event.actorId,
      actorAudience: context.audience,
      environment: context.environment,
      action: event.action,
      targetType: event.targetType,
      targetId: event.targetId,
      beforeSummary: event.beforeSummary,
      afterSummary: event.afterSummary,
      ip: context.ip,
      userAgent: context.userAgent,
      correlationId: context.correlationId,
    })
  }
}
