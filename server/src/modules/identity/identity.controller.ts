import {
  Body,
  Controller,
  Get,
  HttpCode,
  Inject,
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
  type RequestContext,
  type SessionResult,
} from "./identity.service"
import { resolveAudience } from "./portal"
import {
  buildSessionCookie,
  clearSessionCookie,
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

function parseBody<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = schema.safeParse(body)
  if (!result.success) {
    throw new ApiError("VALIDATION_FAILED", "The request body is invalid.", 400)
  }
  return result.data
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
  ): Promise<SessionResult> {
    const input = parseBody(signInSchema, body)
    const context = this.requestContext(request)
    const session = await this.identity.signIn(
      {
        ...input,
        deviceName:
          typeof request.headers["user-agent"] === "string"
            ? request.headers["user-agent"]
            : undefined,
      },
      context,
    )

    reply.header(
      "set-cookie",
      buildSessionCookie(
        sessionCookieName(session.audience),
        session.token,
        session.maxAgeSeconds,
      ),
    )

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

  @Get("session")
  async session(@Req() request: FastifyRequest): Promise<SessionResult> {
    const context = this.requestContext(request)
    const token = request.cookies?.[sessionCookieName(context.audience)]
    if (!token) {
      throw new ApiError("UNAUTHENTICATED", "A valid session is required.", 401)
    }
    return this.identity.getSession(token, context)
  }

  @Post("sign-out")
  @HttpCode(204)
  async signOut(
    @Req() request: FastifyRequest,
    @Res({ passthrough: true }) reply: FastifyReply,
  ): Promise<void> {
    const context = this.requestContext(request)
    const token = request.cookies?.[sessionCookieName(context.audience)]
    if (token) await this.identity.signOut(token, context)
    reply.header(
      "set-cookie",
      clearSessionCookie(sessionCookieName(context.audience)),
    )
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
