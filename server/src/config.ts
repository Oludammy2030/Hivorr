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

const baseConfigSchema = z.object({
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
  RELEASE_SHA: z
    .string()
    .regex(/^[0-9a-f]{40}$/)
    .optional(),
  RELEASE_DIGEST: z
    .string()
    .regex(/^sha256:[0-9a-f]{64}$/)
    .optional(),
  DATABASE_URL: z.string().min(1).optional(),
  DATABASE_SSL_CA: z.string().min(1).optional(),
  EDGE_SHARED_SECRET: z.string().min(1).optional(),
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
  // Sentry DSN. Optional: without it errors stay in memory and nothing is sent.
  SENTRY_DSN: z
    .string()
    .regex(/^https:\/\/[0-9a-f]+@[^/]+\/\d+$/)
    .optional(),
  ZEPTOMAIL_TOKEN: z.string().min(1).optional(),
  ZEPTOMAIL_API_URL: z
    .string()
    .regex(/^https:\/\/\S+$/)
    .default("https://cpaas.zoho.com/v1.1/email"),
  MAIL_FROM_ADDRESS: z.string().min(3).max(254).optional(),
  MAIL_FROM_NAME: z.string().min(1).max(120).default("Hivorr"),
  PUBLIC_APP_ORIGIN: z
    .string()
    .regex(/^https?:\/\/\S+$/)
    .optional(),
  STAFF_EMAIL_DOMAIN: z
    .string()
    .regex(
      /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$/i,
    )
    .default("hivorr.com"),
  AUTH_RATE_LIMIT_WINDOW_MS: z.coerce
    .number()
    .int()
    .min(1_000)
    .max(3_600_000)
    .default(60_000),
  AUTH_RATE_LIMIT_IDENTIFIER_MAX: z.coerce
    .number()
    .int()
    .min(1)
    .max(10_000)
    .default(10),
  AUTH_RATE_LIMIT_IP_MAX: z.coerce
    .number()
    .int()
    .min(1)
    .max(100_000)
    .default(30),
  AUTH_LOCKOUT_ATTEMPTS: z.coerce.number().int().min(1).max(100).default(5),
  AUTH_LOCKOUT_MS: z.coerce
    .number()
    .int()
    .min(1_000)
    .max(86_400_000)
    .default(15 * 60 * 1_000),
  TRUST_PROXY: z
    .enum(["true", "false"])
    .default("false")
    .transform((value) => value === "true"),
  // VFD provider. Test is the default everywhere; live requires production and
  // a real credential pair. A non-expiring token is never requested.
  VFD_MODE: z.enum(["test", "live"]).default("test"),
  VFD_CONSUMER_KEY: z.string().min(1).optional(),
  VFD_CONSUMER_SECRET: z.string().min(1).optional(),
  VFD_TOKEN_VALIDITY_MINUTES: z.coerce
    .number()
    .int()
    .min(5)
    .max(60)
    .default(30),
  VFD_REQUEST_TIMEOUT_MS: z.coerce
    .number()
    .int()
    .min(500)
    .max(30_000)
    .default(5_000),
  VFD_MAX_RETRIES: z.coerce.number().int().min(0).max(5).default(2),
  VFD_RETRY_BASE_MS: z.coerce.number().int().min(50).max(5_000).default(250),
  /**
   * The wallet account that funds a payout. Optional: the adapter refuses to
   * send while it is unset. Never a credential, but financial data, so it is
   * classified secret in the configuration contract.
   */
  VFD_SOURCE_ACCOUNT: z.preprocess(
    (value) => (value === "" || value === undefined ? undefined : value),
    z
      .string()
      .regex(/^[0-9]{10}$/)
      .optional(),
  ),
  // Payout-account encryption. The account number is encrypted with AES-256-GCM
  // under a managed key; the fingerprint uses a separate HMAC key. Neither key
  // may be the other, and neither is ever logged or projected.
  PAYOUT_ENCRYPTION_KEY: z.string().min(1).optional(),
  PAYOUT_ENCRYPTION_KEY_ID: z
    .string()
    .min(1)
    .max(120)
    .regex(/^[a-zA-Z0-9._-]+$/)
    .default("v1"),
  PAYOUT_FINGERPRINT_KEY: z.string().min(1).optional(),
  // The approved number of destinations is not decided. Unset means binding is
  // refused rather than a number being invented in code. An empty template
  // value is treated as unset.
  PAYOUT_ACCOUNT_MAX_ACTIVE: z.preprocess(
    (value) => (value === "" || value === undefined ? undefined : value),
    z.coerce.number().int().min(1).max(100).optional(),
  ),
})

/**
 * Every environment key the API reads. This is the single source of truth for
 * the configuration contract (EP-01-043); `pnpm config:check` fails when the
 * committed contract and this list drift apart.
 */
export const CONFIG_ENV_KEYS: readonly string[] = Object.freeze(
  Object.keys(baseConfigSchema.shape),
)

const configSchema = baseConfigSchema.superRefine((value, context) => {
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

  if (value.VFD_MODE === "live") {
    if (value.HIVORR_ENV !== "production") {
      context.addIssue({
        code: "custom",
        path: ["VFD_MODE"],
        message: "VFD live mode is permitted only in production",
      })
    }
    if (!value.VFD_CONSUMER_KEY || !value.VFD_CONSUMER_SECRET) {
      context.addIssue({
        code: "custom",
        path: ["VFD_CONSUMER_KEY"],
        message: "VFD live mode requires a consumer key and secret",
      })
    }
  } else if (
    Boolean(value.VFD_CONSUMER_KEY) !== Boolean(value.VFD_CONSUMER_SECRET)
  ) {
    context.addIssue({
      code: "custom",
      path: ["VFD_CONSUMER_KEY"],
      message: "VFD credentials are supplied as a key and secret pair",
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
  } else if (base64KeyLength(value.MFA_ENCRYPTION_KEY) !== 32) {
    context.addIssue({
      code: "custom",
      path: ["MFA_ENCRYPTION_KEY"],
      message: "MFA_ENCRYPTION_KEY must be 32 bytes encoded as base64",
    })
  }

  if (!value.PAYOUT_ENCRYPTION_KEY) {
    context.addIssue({
      code: "custom",
      path: ["PAYOUT_ENCRYPTION_KEY"],
      message: "PAYOUT_ENCRYPTION_KEY is required in staging and production",
    })
  } else if (base64KeyLength(value.PAYOUT_ENCRYPTION_KEY) !== 32) {
    context.addIssue({
      code: "custom",
      path: ["PAYOUT_ENCRYPTION_KEY"],
      message: "PAYOUT_ENCRYPTION_KEY must be 32 bytes encoded as base64",
    })
  }
  if (!value.PAYOUT_FINGERPRINT_KEY) {
    context.addIssue({
      code: "custom",
      path: ["PAYOUT_FINGERPRINT_KEY"],
      message: "PAYOUT_FINGERPRINT_KEY is required in staging and production",
    })
  } else if (base64KeyLength(value.PAYOUT_FINGERPRINT_KEY) !== 32) {
    context.addIssue({
      code: "custom",
      path: ["PAYOUT_FINGERPRINT_KEY"],
      message: "PAYOUT_FINGERPRINT_KEY must be 32 bytes encoded as base64",
    })
  }
  // Payout keys are a pair: the encryption key protects the account number and
  // the fingerprint key protects uniqueness. Supplying one without the other is
  // a configuration error, not a mode.
  if (
    Boolean(value.PAYOUT_ENCRYPTION_KEY) !==
    Boolean(value.PAYOUT_FINGERPRINT_KEY)
  ) {
    context.addIssue({
      code: "custom",
      path: ["PAYOUT_ENCRYPTION_KEY"],
      message: "Payout encryption and fingerprint keys are supplied as a pair",
    })
  }
  if (
    value.PAYOUT_ENCRYPTION_KEY &&
    base64KeyLength(value.PAYOUT_ENCRYPTION_KEY) !== 32
  ) {
    context.addIssue({
      code: "custom",
      path: ["PAYOUT_ENCRYPTION_KEY"],
      message: "PAYOUT_ENCRYPTION_KEY must be 32 bytes encoded as base64",
    })
  }
  if (
    value.PAYOUT_FINGERPRINT_KEY &&
    base64KeyLength(value.PAYOUT_FINGERPRINT_KEY) !== 32
  ) {
    context.addIssue({
      code: "custom",
      path: ["PAYOUT_FINGERPRINT_KEY"],
      message: "PAYOUT_FINGERPRINT_KEY must be 32 bytes encoded as base64",
    })
  }
  if (
    value.PAYOUT_ENCRYPTION_KEY &&
    value.PAYOUT_FINGERPRINT_KEY &&
    value.PAYOUT_ENCRYPTION_KEY === value.PAYOUT_FINGERPRINT_KEY
  ) {
    context.addIssue({
      code: "custom",
      path: ["PAYOUT_FINGERPRINT_KEY"],
      message: "The payout encryption and fingerprint keys must be different",
    })
  }
  // Production must verify the database certificate. Without the CA the driver
  // connects successfully and silently skips verification, which is worse than
  // failing to boot.
  if (value.HIVORR_ENV === "production" && !value.DATABASE_SSL_CA) {
    context.addIssue({
      code: "custom",
      path: ["DATABASE_SSL_CA"],
      message:
        "DATABASE_SSL_CA is required in production: the API must verify database TLS",
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
export function base64KeyLength(value: string): number {
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

export interface AuthAbuseConfig {
  readonly rateLimitWindowMs: number
  readonly identifierMax: number
  readonly ipMax: number
  readonly lockoutAttempts: number
  readonly lockoutMs: number
}

export interface MailConfig {
  /** ZeptoMail send-mail token. Delivery stays off while unset. */
  readonly token: string | undefined
  readonly apiUrl: string
  readonly fromAddress: string | undefined
  readonly fromName: string
  /** Public origin of the main portal, used to build invitation links. */
  readonly appOrigin: string | undefined
  /**
   * Domain of the official addresses Hivorr owns. A staff invitation may only
   * create an account on this domain; the personal address is delivery-only.
   */
  readonly staffEmailDomain: string
}

export interface VfdConfig {
  readonly mode: "test" | "live"
  readonly consumerKey: string | undefined
  readonly consumerSecret: string | undefined
  readonly tokenValidityMinutes: number
  readonly requestTimeoutMs: number
  readonly maxRetries: number
  readonly retryBaseMs: number
  /** Wallet account that funds a payout. Undefined refuses to send. */
  readonly sourceAccount: string | undefined
}

/**
 * Payout-account protection. The keys are required in staging and production
 * and are never logged, projected, or returned. The active-destination cap is
 * deliberately optional: while it is unset, binding is refused rather than a
 * number being invented.
 */
export interface PayoutConfig {
  readonly encryptionKey: string | undefined
  readonly encryptionKeyId: string
  readonly fingerprintKey: string | undefined
  readonly maxActiveAccounts: number | undefined
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
  /** Commit identity of the running artifact, when the deployment records it. */
  readonly releaseSha: string | null
  /** Release manifest digest of the running artifact, when recorded. */
  readonly releaseDigest: string | null
  readonly databaseUrl: string | undefined
  /** PEM root certificate for the database host, when supplied. */
  readonly databaseSslCa: string | undefined
  /** Sentry DSN for production error reporting. Undefined means capture-only. */
  readonly sentryDsn: string | undefined
  /** Shared secret the edge proxy must present for a forwarded host. */
  readonly edgeSharedSecret: string | undefined
  readonly corsAllowedOrigins: readonly string[]
  readonly trustProxy: boolean
  readonly mail: MailConfig
  readonly auth: AuthAbuseConfig
  readonly worker: WorkerConfig
  readonly vfd: VfdConfig
  readonly payout: PayoutConfig
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
    releaseSha: value.RELEASE_SHA ?? null,
    releaseDigest: value.RELEASE_DIGEST ?? null,
    databaseUrl: value.DATABASE_URL,
    databaseSslCa: value.DATABASE_SSL_CA,
    sentryDsn: value.SENTRY_DSN,
    edgeSharedSecret: value.EDGE_SHARED_SECRET,
    corsAllowedOrigins: (value.CORS_ALLOWED_ORIGINS ?? "")
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
    trustProxy: value.TRUST_PROXY,
    mail: {
      token: value.ZEPTOMAIL_TOKEN,
      apiUrl: value.ZEPTOMAIL_API_URL,
      fromAddress: value.MAIL_FROM_ADDRESS,
      fromName: value.MAIL_FROM_NAME,
      appOrigin: value.PUBLIC_APP_ORIGIN,
      staffEmailDomain: value.STAFF_EMAIL_DOMAIN,
    },
    auth: {
      rateLimitWindowMs: value.AUTH_RATE_LIMIT_WINDOW_MS,
      identifierMax: value.AUTH_RATE_LIMIT_IDENTIFIER_MAX,
      ipMax: value.AUTH_RATE_LIMIT_IP_MAX,
      lockoutAttempts: value.AUTH_LOCKOUT_ATTEMPTS,
      lockoutMs: value.AUTH_LOCKOUT_MS,
    },
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
    vfd: {
      mode: value.VFD_MODE,
      consumerKey: value.VFD_CONSUMER_KEY,
      consumerSecret: value.VFD_CONSUMER_SECRET,
      tokenValidityMinutes: value.VFD_TOKEN_VALIDITY_MINUTES,
      requestTimeoutMs: value.VFD_REQUEST_TIMEOUT_MS,
      maxRetries: value.VFD_MAX_RETRIES,
      retryBaseMs: value.VFD_RETRY_BASE_MS,
      sourceAccount: value.VFD_SOURCE_ACCOUNT,
    },
    payout: {
      encryptionKey: value.PAYOUT_ENCRYPTION_KEY,
      encryptionKeyId: value.PAYOUT_ENCRYPTION_KEY_ID,
      fingerprintKey: value.PAYOUT_FINGERPRINT_KEY,
      maxActiveAccounts: value.PAYOUT_ACCOUNT_MAX_ACTIVE,
    },
  }
}

export function loadConfig(): ApiConfig {
  return parseConfig(process.env)
}
