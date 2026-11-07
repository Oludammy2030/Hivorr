import { z } from "zod"

export const DEPLOYMENT_ENVIRONMENTS = [
  "development",
  "test",
  "staging",
  "production",
] as const

export type DeploymentEnvironment = typeof DEPLOYMENT_ENVIRONMENTS[number]

const logLevels = [
  "fatal",
  "error",
  "warn",
  "info",
  "debug",
  "trace",
  "silent",
] as const

const configSchema = z
  .object({
    HIVORR_ENV: z.enum(DEPLOYMENT_ENVIRONMENTS),
    API_PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    API_HOST: z.string().min(1).default("0.0.0.0"),
    LOG_LEVEL: z.enum(logLevels).default("info"),
    SESSION_ISSUER: z.string().min(1).optional(),
    DATABASE_URL: z.string().min(1).optional(),
    CORS_ALLOWED_ORIGINS: z.string().optional(),
    TRUST_PROXY: z
      .enum(["true", "false"])
      .default("false")
      .transform((value) => value === "true"),
  })
  .superRefine((value, context) => {
    if (value.HIVORR_ENV !== "staging" && value.HIVORR_ENV !== "production")
      return

    if (!value.DATABASE_URL) {
      context.addIssue({
        code: "custom",
        path: ["DATABASE_URL"],
        message: "DATABASE_URL is required in staging and production",
      })
    }
    if (!value.SESSION_ISSUER) {
      context.addIssue({
        code: "custom",
        path: ["SESSION_ISSUER"],
        message: "SESSION_ISSUER is required in staging and production",
      })
    }
  })

export const API_CONFIG = "HIVORR_API_CONFIG" as const

export interface ApiConfig {
  readonly environment: DeploymentEnvironment
  readonly port: number
  readonly host: string
  readonly logLevel: typeof logLevels[number]
  readonly sessionIssuer: string
  readonly databaseUrl: string | undefined
  readonly corsAllowedOrigins: readonly string[]
  readonly trustProxy: boolean
}

export class ConfigurationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = "ConfigurationError"
  }
}

/**
 * Parses configuration without ever including a supplied value in the error.
 * A missing or malformed secret must not be echoed to a log or an operator.
 */
export function parseConfig(environment: NodeJS.ProcessEnv): ApiConfig {
  const result = configSchema.safeParse(environment)
  if (!result.success) {
    const fields = result.error.issues.map(
      (issue) => issue.path.join(".") || "config",
    )
    throw new ConfigurationError(
      `Invalid API configuration: ${[...new Set(fields)].join(", ")}`,
    )
  }

  const value = result.data
  return {
    environment: value.HIVORR_ENV,
    port: value.API_PORT,
    host: value.API_HOST,
    logLevel: value.LOG_LEVEL,
    sessionIssuer: value.SESSION_ISSUER ?? `hivorr-${value.HIVORR_ENV}`,
    databaseUrl: value.DATABASE_URL,
    corsAllowedOrigins: (value.CORS_ALLOWED_ORIGINS ?? "")
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
    trustProxy: value.TRUST_PROXY,
  }
}

export function loadConfig(): ApiConfig {
  return parseConfig(process.env)
}
