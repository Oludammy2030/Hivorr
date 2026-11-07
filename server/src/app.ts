import "reflect-metadata"

import fastifyCookie from "@fastify/cookie"
import { NestFactory } from "@nestjs/core"
import {
  FastifyAdapter,
  type NestFastifyApplication,
} from "@nestjs/platform-fastify"

import { AppModule } from "./app.module"
import { ApiErrorFilter } from "./common/api-error.filter"
import { resolveCorrelationId } from "./common/correlation"
import { loadConfig, type ApiConfig } from "./config"

export interface CreatedApplication {
  readonly app: NestFastifyApplication
  readonly config: ApiConfig
}

export async function createApplication(
  config: ApiConfig = loadConfig(),
): Promise<CreatedApplication> {
  const adapter = new FastifyAdapter({
    trustProxy: config.trustProxy,
    bodyLimit: 1_048_576,
    requestTimeout: 15_000,
  })

  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule.register(config),
    adapter,
    { logger: config.logLevel === "silent" ? false : ["error", "warn"] },
  )

  await app.register(fastifyCookie)
  app.useGlobalFilters(new ApiErrorFilter())
  app.setGlobalPrefix("v1")

  if (config.corsAllowedOrigins.length > 0) {
    app.enableCors({
      origin: [...config.corsAllowedOrigins],
      credentials: true,
    })
  }

  const instance = app.getHttpAdapter().getInstance()
  instance.addHook("onRequest", (request, reply, done) => {
    const header = request.headers["x-correlation-id"]
    const candidate = Array.isArray(header) ? header[0] : header
    const correlationId = resolveCorrelationId(candidate)
    reply.header("x-correlation-id", correlationId)
    ;(request as typeof request & { correlationId: string }).correlationId =
      correlationId
    done()
  })

  app.enableShutdownHooks()
  return { app, config }
}
