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
    BACKEND_ENVIRONMENT: z.enum(DEPLOYMENT_ENVIRONMENTS).optional(),
    SUPABASE_PROJECT_REF: z
      .string()
      .regex(/^[a-z0-9]{10,40}$/)
      .optional(),
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
    if (
      value.BACKEND_ENVIRONMENT &&
      value.BACKEND_ENVIRONMENT !== value.HIVORR_ENV
    ) {
      context.addIssue({
        code: "custom",
        path: ["BACKEND_ENVIRONMENT"],
        message: "BACKEND_ENVIRONMENT must match HIVORR_ENV",
      })
    }

    if (value.HIVORR_ENV !== "staging" && value.HIVORR_ENV !== "production")
      return

    if (!value.BACKEND_ENVIRONMENT) {
      context.addIssue({
        code: "custom",
        path: ["BACKEND_ENVIRONMENT"],
        message: "BACKEND_ENVIRONMENT is required in staging and production",
      })
    }
    if (!value.SUPABASE_PROJECT_REF) {
      context.addIssue({
        code: "custom",
        path: ["SUPABASE_PROJECT_REF"],
        message: "SUPABASE_PROJECT_REF is required in staging and production",
      })
    }
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
    if (
      value.DATABASE_URL &&
      value.SUPABASE_PROJECT_REF &&
      !databaseUrlMatchesProjectRef(
        value.DATABASE_URL,
        value.SUPABASE_PROJECT_REF,
      )
    ) {
      context.addIssue({
        code: "custom",
        path: ["DATABASE_URL"],
        message:
          "DATABASE_URL does not belong to SUPABASE_PROJECT_REF; backend environments must not be mixed",
      })
    }
  })

/**
 * A database URL must belong to the declared Supabase project. Supabase direct
 * connections use `db.<ref>.supabase.co`; pooler connections carry the project
 * reference in the username (for example `postgres.<ref>`).
 */
export function databaseUrlMatchesProjectRef(
  databaseUrl: string,
  projectRef: string,
): boolean {
  try {
    const url = new URL(databaseUrl)
    const ref = projectRef.toLowerCase()
    const host = url.hostname.toLowerCase()
    const username = decodeURIComponent(url.username).toLowerCase()
    return host === `db.${ref}.supabase.co` || username.includes(ref)
  } catch {
    return false
  }
}

export const API_CONFIG = "HIVORR_API_CONFIG" as const

export interface ApiConfig {
  readonly environment: DeploymentEnvironment
  readonly backendEnvironment: DeploymentEnvironment
  readonly supabaseProjectRef: string | undefined
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
    backendEnvironment: value.BACKEND_ENVIRONMENT ?? value.HIVORR_ENV,
    supabaseProjectRef: value.SUPABASE_PROJECT_REF,
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
