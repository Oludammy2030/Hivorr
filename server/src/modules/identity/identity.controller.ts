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

import { Audience } from "../../common/audience"

import { ApiError } from "../../common/errors"

import { parseBody } from "../../common/validation"

import { API_CONFIG, type ApiConfig } from "../../config"

import {
  codeRequest,
  emailVerificationCompleteRequest,
  mfaVerifyRequest,
  passwordResetCompleteRequest,
  passwordResetRequest,
  registerRequest,
  signInRequest,
  totpConfirmRequest,
} from "../../contracts/schemas"

import {
  IdentityService,
  isMfaChallenge,
  type IssuedSession,
  type MfaChallenge,
  type RequestContext,
  type SessionResult,
  type SignInResult,
} from "./identity.service"

import { accessToken, requestContext } from "./request-context"

import {
  buildRefreshCookie,
  buildSessionCookie,
  clearRefreshCookie,
  clearSessionCookie,
  refreshCookieName,
  sessionCookieName,
} from "./session-policy"

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
@Audience("app", "control", "staff", "partner")
export class IdentityController {
  constructor(
    @Inject(IdentityService) private readonly identity: IdentityService,

    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  @Post("register")
  async register(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(registerRequest, body)

    const context = requestContext(this.config, request)

    return this.identity.register(input, context)
  }

  @Post("password-reset/request")
  @HttpCode(202)
  async requestPasswordReset(
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ): Promise<void> {
    const input = parseBody(passwordResetRequest, body)
    const context = requestContext(this.config, request)
    await this.identity.requestPasswordReset(input.email, context)
  }

  @Post("password-reset/complete")
  @HttpCode(204)
  async completePasswordReset(
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ): Promise<void> {
    const input = parseBody(passwordResetCompleteRequest, body)
    const context = requestContext(this.config, request)
    await this.identity.resetPassword(input.token, input.password, context)
  }

  @Post("email-verification/request")
  @HttpCode(202)
  async requestEmailVerification(
    @Req() request: FastifyRequest,
  ): Promise<void> {
    const context = requestContext(this.config, request)
    await this.identity.requestEmailVerification(
      accessToken(request, context),
      context,
    )
  }

  @Post("email-verification/complete")
  @HttpCode(204)
  async completeEmailVerification(
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ): Promise<void> {
    const input = parseBody(emailVerificationCompleteRequest, body)
    const context = requestContext(this.config, request)
    await this.identity.verifyEmail(input.token, context)
  }

  @Post("sign-in")

  @HttpCode(200)
  async signIn(
    @Body() body: unknown,

    @Req() request: FastifyRequest,

    @Res({ passthrough: true }) reply: FastifyReply,
  ): Promise<SessionResult | MfaChallenge> {
    const input = parseBody(signInRequest, body)

    const context = requestContext(this.config, request)

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
    const input = parseBody(mfaVerifyRequest, body)

    const context = requestContext(this.config, request)

    const session = await this.identity.verifyMfa(input, context)

    this.setSessionCookies(reply, session)

    return sessionBody(session)
  }

  @Post("mfa/totp/enroll")
  async enrollTotp(
    @Req() request: FastifyRequest,

    @Res({ passthrough: true }) reply: FastifyReply,
  ) {
    const context = requestContext(this.config, request)

    const token = accessToken(request, context)

    const enrollment = await this.identity.enrollTotp(token, context)

    reply.status(201)

    return enrollment
  }

  @Post("mfa/totp/confirm")

  @HttpCode(200)
  async confirmTotp(@Body() body: unknown, @Req() request: FastifyRequest) {
    const input = parseBody(totpConfirmRequest, body)

    const context = requestContext(this.config, request)

    const token = accessToken(request, context)

    return this.identity.confirmTotp(token, input, context)
  }

  @Post("mfa/step-up")

  @HttpCode(200)
  async stepUp(
    @Body() body: unknown,

    @Req() request: FastifyRequest,
  ): Promise<SessionResult> {
    const input = parseBody(codeRequest, body)

    const context = requestContext(this.config, request)

    const token = accessToken(request, context)

    return this.identity.stepUp(token, input.code, context)
  }

  @Post("refresh")

  @HttpCode(200)
  async refresh(
    @Req() request: FastifyRequest,

    @Res({ passthrough: true }) reply: FastifyReply,
  ): Promise<SessionResult> {
    const context = requestContext(this.config, request)

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

  @Get("sessions")
  async sessions(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)

    return this.identity.listSessions(accessToken(request, context), context)
  }

  @Delete("sessions/:id")

  @HttpCode(204)
  async revokeSession(
    @Param("id") id: string,

    @Req() request: FastifyRequest,
  ): Promise<void> {
    const context = requestContext(this.config, request)

    await this.identity.revokeSession(
      accessToken(request, context),

      id,

      context,
    )
  }

  @Delete("sessions")

  @HttpCode(200)
  async revokeOtherSessions(@Req() request: FastifyRequest) {
    const context = requestContext(this.config, request)

    const revoked = await this.identity.revokeOtherSessions(
      accessToken(request, context),

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
    const context = requestContext(this.config, request)

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
}
