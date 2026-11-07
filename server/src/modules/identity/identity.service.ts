import { createHash, randomBytes } from "node:crypto"

import { Inject, Injectable } from "@nestjs/common"
import { hash, verify } from "@node-rs/argon2"
import type { EnvironmentId, PortalId } from "@hivorr/shared"
import type { PoolClient } from "pg"

import { ApiError } from "../../common/errors"
import { API_CONFIG, type ApiConfig } from "../../config"
import { DatabaseService } from "../../db/database.service"
import { sessionPolicy } from "./session-policy"

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
  ): Promise<IssuedSession> {
    // The privileged portals require MFA. MFA verification is not implemented
    // yet, so they must not receive a session that could be mistaken for a
    // fully authenticated one.
    if (context.audience !== "app") {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        "Privileged sign-in is not available until MFA is implemented.",
        503,
      )
    }

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

      const token = createSessionToken()
      const tokenHash = hashSessionToken(token)
      const policy = sessionPolicy(context.audience)
      const now = Date.now()
      const expiresAt = new Date(now + policy.absoluteMs)
      const idleExpiresAt = new Date(now + policy.idleMs)

      await client.query("begin")
      await client.query("select platform.set_identity_context($1, $2)", [
        row.account_id,
        row.user_id,
      ])
      await client.query(
        "update identity.credentials set failed_attempts = 0, locked_until = null where user_id = $1",
        [row.user_id],
      )

      let deviceId: string | null = null
      if (input.deviceName) {
        const device = await client.query<{ id: string }>(
          "insert into identity.devices (user_id, name) values ($1, $2) returning id",
          [row.user_id, input.deviceName],
        )
        deviceId = device.rows[0].id
      }

      const session = await client.query<{ id: string }>(
        `insert into identity.sessions
           (user_id, device_id, audience, environment, refresh_token_hash, idle_expires_at, expires_at)
         values ($1, $2, $3, $4, $5, $6, $7)
         returning id`,
        [
          row.user_id,
          deviceId,
          context.audience,
          context.environment,
          tokenHash,
          idleExpiresAt.toISOString(),
          expiresAt.toISOString(),
        ],
      )
      const sessionId = session.rows[0].id

      await this.audit(client, context, {
        actorType: "user",
        actorId: row.user_id,
        action: "identity.sign_in",
        targetType: "session",
        targetId: sessionId,
      })

      await client.query("commit")

      return {
        token,
        sessionId,
        accountId: row.account_id,
        userId: row.user_id,
        email,
        audience: context.audience,
        environment: context.environment,
        expiresAt: expiresAt.toISOString(),
        idleExpiresAt: idleExpiresAt.toISOString(),
        maxAgeSeconds: Math.floor(policy.absoluteMs / 1000),
      }
    } finally {
      client.release()
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
