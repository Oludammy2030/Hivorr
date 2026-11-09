import { hostname } from "node:os"

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
    MFA_ENCRYPTION_KEY: z.string().min(1).optional(),
    DATABASE_URL: z.string().min(1).optional(),
    WORKER_DATABASE_URL: z.string().min(1).optional(),
    WORKER_POLL_INTERVAL_MS: z.coerce
      .number()
      .int()
      .min(50)
      .max(60_000)
      .default(1_000),
    WORKER_BATCH_SIZE: z.coerce.number().int().min(1).max(100).default(20),
    WORKER_LEASE_MS: z.coerce.number().int().min(5_000).default(60_000),
    WORKER_MAX_ATTEMPTS: z.coerce.number().int().min(1).max(50).default(5),
    WORKER_RETRY_BASE_MS: z.coerce.number().int().min(100).default(5_000),
    WORKER_HEALTH_PORT: z.coerce.number().int().min(1).max(65535).default(3001),
    WORKER_HEALTH_HOST: z.string().min(1).default("0.0.0.0"),
    WORKER_ID: z.string().min(1).max(120).optional(),
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
    if (!value.MFA_ENCRYPTION_KEY) {
      context.addIssue({
        code: "custom",
        path: ["MFA_ENCRYPTION_KEY"],
        message: "MFA_ENCRYPTION_KEY is required in staging and production",
      })
    } else if (mfaKeyLength(value.MFA_ENCRYPTION_KEY) !== 32) {
      context.addIssue({
        code: "custom",
        path: ["MFA_ENCRYPTION_KEY"],
        message: "MFA_ENCRYPTION_KEY must be 32 bytes encoded as base64",
      })
    }
    if (
      value.WORKER_DATABASE_URL &&
      value.SUPABASE_PROJECT_REF &&
      !databaseUrlMatchesProjectRef(
        value.WORKER_DATABASE_URL,
        value.SUPABASE_PROJECT_REF,
      )
    ) {
      context.addIssue({
        code: "custom",
        path: ["WORKER_DATABASE_URL"],
        message:
          "WORKER_DATABASE_URL does not belong to SUPABASE_PROJECT_REF; backend environments must not be mixed",
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
export function mfaKeyLength(value: string): number {
  return Buffer.from(value, "base64").length
}

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

export interface WorkerConfig {
  /** Least-privilege worker role when provisioned; falls back to DATABASE_URL. */
  readonly databaseUrl: string | undefined
  readonly pollIntervalMs: number
  readonly batchSize: number
  readonly leaseMs: number
  readonly maxAttempts: number
  readonly retryBaseMs: number
  readonly healthPort: number
  readonly healthHost: string
  readonly workerId: string
}

export interface ApiConfig {
  readonly environment: DeploymentEnvironment
  readonly backendEnvironment: DeploymentEnvironment
  readonly supabaseProjectRef: string | undefined
  readonly port: number
  readonly host: string
  readonly logLevel: typeof logLevels[number]
  readonly sessionIssuer: string
  readonly mfaEncryptionKey?: string
  readonly databaseUrl: string | undefined
  readonly corsAllowedOrigins: readonly string[]
  readonly trustProxy: boolean
  readonly worker: WorkerConfig
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
    mfaEncryptionKey: value.MFA_ENCRYPTION_KEY,
    databaseUrl: value.DATABASE_URL,
    corsAllowedOrigins: (value.CORS_ALLOWED_ORIGINS ?? "")
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
    trustProxy: value.TRUST_PROXY,
    worker: {
      databaseUrl: value.WORKER_DATABASE_URL ?? value.DATABASE_URL,
      pollIntervalMs: value.WORKER_POLL_INTERVAL_MS,
      batchSize: value.WORKER_BATCH_SIZE,
      leaseMs: value.WORKER_LEASE_MS,
      maxAttempts: value.WORKER_MAX_ATTEMPTS,
      retryBaseMs: value.WORKER_RETRY_BASE_MS,
      healthPort: value.WORKER_HEALTH_PORT,
      healthHost: value.WORKER_HEALTH_HOST,
      workerId:
        value.WORKER_ID ??
        `hivorr-worker-${value.HIVORR_ENV}-${hostname()}-${process.pid}`,
    },
  }
}

export function loadConfig(): ApiConfig {
  return parseConfig(process.env)
}
