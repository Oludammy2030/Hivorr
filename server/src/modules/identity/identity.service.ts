import { createHash, randomBytes } from "node:crypto"

import { Inject, Injectable } from "@nestjs/common"
import { hash, verify } from "@node-rs/argon2"
import type { EnvironmentId, PortalId } from "@hivorr/shared"
import type { PoolClient } from "pg"

import { ApiError } from "../../common/errors"
import { API_CONFIG, type ApiConfig } from "../../config"
import { DatabaseService } from "../../db/database.service"
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

export interface IssuedSession extends SessionResult {
  readonly token: string
  readonly maxAgeSeconds: number
}

export interface MfaChallenge {
  readonly mfaRequired: true
  readonly challengeToken: string
  readonly expiresAt: string
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

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase()
}

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
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  async register(
    input: RegisterInput,
    context: RequestContext,
  ): Promise<RegistrationResult> {
    const email = normalizeEmail(input.email)
    const passwordHash = await hashPassword(input.password)
    const client = await this.database.pool.connect()

    try {
      await client.query("begin")
      const ids = await client.query<{
        account_id: string
        user_id: string
      }>("select platform.uuidv7() as account_id, platform.uuidv7() as user_id")
      const accountId = ids.rows[0].account_id
      const userId = ids.rows[0].user_id

      await client.query("select platform.set_identity_context($1, $2)", [
        accountId,
        userId,
      ])

      await client.query("insert into identity.accounts (id) values ($1)", [
        accountId,
      ])
      await client.query(
        "insert into identity.users (id, account_id, email, display_name) values ($1, $2, $3, $4)",
        [userId, accountId, email, input.displayName ?? null],
      )
      await client.query(
        "insert into identity.credentials (user_id, password_hash) values ($1, $2)",
        [userId, passwordHash],
      )
      await client.query(
        "insert into identity.memberships (user_id, account_id, role) values ($1, $2, 'owner')",
        [userId, accountId],
      )

      await this.audit(client, context, {
        actorType: "user",
        actorId: userId,
        action: "identity.register",
        targetType: "account",
        targetId: accountId,
      })

      await client.query("commit")
      return { accountId, userId, email }
    } catch (error) {
      await client.query("rollback").catch(() => undefined)
      if (isUniqueViolation(error)) {
        throw new ApiError(
          "CONFLICT",
          "An account with this email already exists.",
          409,
        )
      }
      throw error
    } finally {
      client.release()
    }
  }

  async signIn(
    input: SignInInput,
    context: RequestContext,
  ): Promise<SignInResult> {
    const email = normalizeEmail(input.email)
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
        throw new ApiError("RATE_LIMITED", "Too many sign-in attempts.", 429)
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
    const token = createSessionToken()
    const tokenHash = hashSessionToken(token)
    const policy = sessionPolicy(input.context.audience)
    const now = Date.now()
    const expiresAt = new Date(now + policy.absoluteMs)
    const idleExpiresAt = new Date(now + policy.idleMs)

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
         (user_id, device_id, audience, environment, refresh_token_hash, idle_expires_at, expires_at)
       values ($1, $2, $3, $4, $5, $6, $7)
       returning id`,
      [
        input.userId,
        deviceId,
        input.context.audience,
        input.context.environment,
        tokenHash,
        idleExpiresAt.toISOString(),
        expiresAt.toISOString(),
      ],
    )

    return {
      token,
      sessionId: session.rows[0].id,
      accountId: input.accountId,
      userId: input.userId,
      email: input.email,
      audience: input.context.audience,
      environment: input.context.environment,
      expiresAt: expiresAt.toISOString(),
      idleExpiresAt: idleExpiresAt.toISOString(),
      maxAgeSeconds: Math.floor(policy.absoluteMs / 1000),
    }
  }

  async getSession(
    token: string,
    context: RequestContext,
  ): Promise<SessionResult> {
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
      }>("select * from identity.find_session($1)", [tokenHash])
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
      await client.query("select platform.set_identity_context($1, $2)", [
        session.account_id,
        session.user_id,
      ])
      await client.query(
        "update identity.sessions set last_seen_at = now(), idle_expires_at = $1 where id = $2",
        [idleExpiresAt.toISOString(), session.session_id],
      )
      await client.query("commit")

      return {
        sessionId: session.session_id,
        accountId: session.account_id,
        userId: session.user_id,
        email: session.email,
        audience: session.audience,
        environment: session.environment,
        expiresAt: session.expires_at,
        idleExpiresAt: idleExpiresAt.toISOString(),
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
      }>("select * from identity.find_session($1)", [tokenHash])
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
      })
      await client.query("commit")
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
        throw new ApiError(
          "RATE_LIMITED",
          "Too many verification attempts.",
          429,
        )
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
          throw new ApiError(
            "RATE_LIMITED",
            "Too many verification attempts.",
            429,
          )
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
      "select * from identity.find_session($1)",
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
               when failed_attempts + 1 >= 5 then now() + interval '15 minutes'
               else locked_until
             end
         where user_id = $1`,
        [userId],
      )
      await client.query("commit")
    } catch (error) {
      await client.query("rollback").catch(() => undefined)
      throw error
    }
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
    },
  ): Promise<void> {
    await client.query(
      `insert into platform.audit_log
         (actor_type, actor_id, actor_audience, environment, action, target_type, target_id, ip, user_agent, correlation_id)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        event.actorType,
        event.actorId,
        context.audience,
        context.environment,
        event.action,
        event.targetType,
        event.targetId,
        context.ip ?? null,
        context.userAgent ?? null,
        context.correlationId ?? null,
      ],
    )
  }
}
