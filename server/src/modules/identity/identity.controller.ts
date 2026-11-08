import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Inject,
  Param,
  Post,
  Req,
  Res,
} from "@nestjs/common"
import type { FastifyReply, FastifyRequest } from "fastify"
import { z } from "zod"

import { ApiError } from "../../common/errors"
import { API_CONFIG, type ApiConfig } from "../../config"
import {
  IdentityService,
  isMfaChallenge,
  type IssuedSession,
  type MfaChallenge,
  type RequestContext,
  type SessionResult,
  type SignInResult,
} from "./identity.service"
import { resolveAudience } from "./portal"
import {
  buildRefreshCookie,
  buildSessionCookie,
  clearRefreshCookie,
  clearSessionCookie,
  refreshCookieName,
  sessionCookieName,
} from "./session-policy"

const registerSchema = z.object({
  email: z.string().min(3).max(254),
  password: z.string().min(12).max(128),
  displayName: z.string().min(1).max(80).optional(),
})

const signInSchema = z.object({
  email: z.string().min(3).max(254),
  password: z.string().min(1).max(128),
})

const totpConfirmSchema = z.object({
  factorId: z.string().min(1).max(64),
  code: z.string().min(6).max(20),
})

const mfaVerifySchema = z.object({
  challengeToken: z.string().min(20).max(200),
  code: z.string().min(6).max(20),
})

const codeSchema = z.object({
  code: z.string().min(6).max(20),
})

function parseBody<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = schema.safeParse(body)
  if (!result.success) {
    throw new ApiError("VALIDATION_FAILED", "The request body is invalid.", 400)
  }
  return result.data
}

function sessionBody(session: SessionResult): SessionResult {
  return {
    sessionId: session.sessionId,
    accountId: session.accountId,
    userId: session.userId,
    email: session.email,
    audience: session.audience,
    environment: session.environment,
    expiresAt: session.expiresAt,
    idleExpiresAt: session.idleExpiresAt,
  }
}

@Controller("auth")
export class IdentityController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Post("register")
  async register(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(registerSchema, body)
    const context = this.requestContext(request)
    return this.identity.register(input, context)
  }

  @Post("sign-in")
  @HttpCode(200)
  async signIn(
    @Body() body: unknown,
    @Req() request: FastifyRequest,
    @Res({ passthrough: true }) reply: FastifyReply,
  ): Promise<SessionResult | MfaChallenge> {
    const input = parseBody(signInSchema, body)
    const context = this.requestContext(request)
    const result: SignInResult = await this.identity.signIn(
      {
        ...input,
        deviceName:
          typeof request.headers["user-agent"] === "string"
            ? request.headers["user-agent"]
            : undefined,
      },
      context,
    )

    if (isMfaChallenge(result)) {
      reply.status(202)
      return result
    }

    this.setSessionCookies(reply, result)
    return sessionBody(result)
  }

  @Post("mfa/verify")
  @HttpCode(200)
  async verifyMfa(
    @Body() body: unknown,
    @Req() request: FastifyRequest,
    @Res({ passthrough: true }) reply: FastifyReply,
  ): Promise<SessionResult> {
    const input = parseBody(mfaVerifySchema, body)
    const context = this.requestContext(request)
    const session = await this.identity.verifyMfa(input, context)

    this.setSessionCookies(reply, session)
    return sessionBody(session)
  }

  @Post("mfa/totp/enroll")
  async enrollTotp(
    @Req() request: FastifyRequest,
    @Res({ passthrough: true }) reply: FastifyReply,
  ) {
    const context = this.requestContext(request)
    const token = this.sessionToken(request, context)
    const enrollment = await this.identity.enrollTotp(token, context)
    reply.status(201)
    return enrollment
  }

  @Post("mfa/totp/confirm")
  @HttpCode(200)
  async confirmTotp(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(totpConfirmSchema, body)
    const context = this.requestContext(request)
    const token = this.sessionToken(request, context)
    return this.identity.confirmTotp(token, input, context)
  }

  @Post("mfa/step-up")
  @HttpCode(200)
  async stepUp(
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ): Promise<SessionResult> {
    const input = parseBody(codeSchema, body)
    const context = this.requestContext(request)
    const token = this.sessionToken(request, context)
    return this.identity.stepUp(token, input.code, context)
  }

  @Post("refresh")
  @HttpCode(200)
  async refresh(
    @Req() request: FastifyRequest,
    @Res({ passthrough: true }) reply: FastifyReply,
  ): Promise<SessionResult> {
    const context = this.requestContext(request)
    const refreshToken = request.cookies?.[refreshCookieName(context.audience)]
    if (!refreshToken) {
      this.clearSessionCookies(reply, context.audience)
      throw new ApiError(
        "UNAUTHENTICATED",
        "A valid refresh token is required.",
        401,
      )
    }

    try {
      const session = await this.identity.refresh(refreshToken, context)
      this.setSessionCookies(reply, session)
      return sessionBody(session)
    } catch (error) {
      this.clearSessionCookies(reply, context.audience)
      throw error
    }
  }

  @Get("session")
  async session(@Req() request: FastifyRequest): Promise<SessionResult> {
    const context = this.requestContext(request)
    return this.identity.getSession(
      this.sessionToken(request, context),
      context,
    )
  }

  @Get("sessions")
  async sessions(@Req() request: FastifyRequest) {
    const context = this.requestContext(request)
    return this.identity.listSessions(
      this.sessionToken(request, context),
      context,
    )
  }

  @Delete("sessions/:id")
  @HttpCode(204)
  async revokeSession(
    @Param("id") id: string,
    @Req() request: FastifyRequest,
  ): Promise<void> {
    const context = this.requestContext(request)
    await this.identity.revokeSession(
      this.sessionToken(request, context),
      id,
      context,
    )
  }

  @Delete("sessions")
  @HttpCode(200)
  async revokeOtherSessions(@Req() request: FastifyRequest) {
    const context = this.requestContext(request)
    const revoked = await this.identity.revokeOtherSessions(
      this.sessionToken(request, context),
      context,
    )
    return { revoked }
  }

  @Post("sign-out")
  @HttpCode(204)
  async signOut(
    @Req() request: FastifyRequest,
    @Res({ passthrough: true }) reply: FastifyReply,
  ): Promise<void> {
    const context = this.requestContext(request)
    const accessToken = request.cookies?.[sessionCookieName(context.audience)]
    const refreshToken = request.cookies?.[refreshCookieName(context.audience)]

    if (accessToken) {
      await this.identity.signOut(accessToken, context)
    } else if (refreshToken) {
      await this.identity.signOutByRefresh(refreshToken, context)
    }
    this.clearSessionCookies(reply, context.audience)
  }

  private setSessionCookies(reply: FastifyReply, session: IssuedSession): void {
    reply.header("set-cookie", [
      buildSessionCookie(
        sessionCookieName(session.audience),
        session.token,
        session.maxAgeSeconds,
      ),
      buildRefreshCookie(
        refreshCookieName(session.audience),
        session.refreshToken,
        session.refreshMaxAgeSeconds,
      ),
    ])
  }

  private clearSessionCookies(
    reply: FastifyReply,
    audience: RequestContext["audience"],
  ): void {
    reply.header("set-cookie", [
      clearSessionCookie(sessionCookieName(audience)),
      clearRefreshCookie(refreshCookieName(audience)),
    ])
  }

  private sessionToken(
    request: FastifyRequest,
    context: RequestContext,
  ): string {
    const token = request.cookies?.[sessionCookieName(context.audience)]
    if (!token) {
      throw new ApiError("UNAUTHENTICATED", "A valid session is required.", 401)
    }
    return token
  }

  private requestContext(request: FastifyRequest): RequestContext {
    const audience = resolveAudience(
      request.headers.host,
      this.config.environment,
    )
    if (!audience) {
      throw new ApiError(
        "FORBIDDEN",
        "This host is not a recognised Hivorr portal.",
        403,
      )
    }
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

    return {
      audience,
      environment: this.config.environment,
      ip: request.ip,
      userAgent:
        typeof request.headers["user-agent"] === "string"
          ? request.headers["user-agent"]
          : undefined,
      correlationId: (request as FastifyRequest & { correlationId?: string })
        .correlationId,
    }
  }
}
