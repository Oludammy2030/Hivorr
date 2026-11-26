import { Inject, Injectable } from "@nestjs/common"

import { ApiError } from "../../common/errors"
import {
  API_CONFIG,
  type ApiConfig,
  type PaymentMode,
  type PaymentProviderKey,
} from "../../config"
import { DatabaseService } from "../../db/database.service"
import { appendAudit } from "./audit"

/**
 * Active payment-provider setting (2026-11-26).
 *
 * The control panel switches provider and mode. Secrets are never stored here:
 * `configured` reports whether the deployment secret store has the key for each
 * provider/mode, and the value itself is never read back.
 */
export interface PaymentProviderModes {
  readonly test: boolean
  readonly live: boolean
}

export interface PaymentProviderConfigured {
  readonly vfd: PaymentProviderModes
  readonly paystack: PaymentProviderModes
}

export interface PaymentProviderSettingView {
  readonly provider: PaymentProviderKey
  readonly mode: PaymentMode
  readonly updatedAt: string
  readonly configured: PaymentProviderConfigured
}

export interface SetPaymentProviderInput {
  readonly actorUserId: string
  readonly provider: string
  readonly mode: string
  readonly reason: string
  readonly context: {
    readonly audience: string
    readonly environment: string
    readonly ip?: string
    readonly userAgent?: string
    readonly correlationId?: string
  }
}

interface SettingRow {
  active_provider: string
  active_mode: string
  updated_at: string | Date
}

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : value
}

function isProvider(value: string): value is PaymentProviderKey {
  return value === "vfd" || value === "paystack"
}

function isMode(value: string): value is PaymentMode {
  return value === "test" || value === "live"
}

@Injectable()
export class PaymentProviderSettingsService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
  ) {}

  /** The active provider/mode without a control-portal permission check. */
  async activeSetting(): Promise<{
    readonly provider: PaymentProviderKey
    readonly mode: PaymentMode
  }> {
    const row = await this.database.withTransaction({}, async (transaction) => {
      const result = await transaction.query<{
        active_provider: string
        active_mode: string
      }>(
        "select active_provider, active_mode from platform.payment_provider_setting where id",
      )
      return result.rows[0]
    })
    return {
      provider: isProvider(row?.active_provider ?? "")
        ? row?.active_provider as PaymentProviderKey
        : "paystack",
      mode: isMode(row?.active_mode ?? "")
        ? row?.active_mode as PaymentMode
        : "test",
    }
  }

  async get(actorUserId: string): Promise<PaymentProviderSettingView> {
    try {
      const row = await this.database.withTransaction(
        {},
        async (transaction) => {
          const result = await transaction.query<SettingRow>(
            "select * from platform.get_payment_provider($1)",
            [actorUserId],
          )
          return result.rows[0]
        },
      )
      if (!row) {
        throw new Error("The payment provider setting is missing.")
      }
      return this.toView(row)
    } catch (error) {
      this.mapError(error)
    }
  }

  async set(
    input: SetPaymentProviderInput,
  ): Promise<PaymentProviderSettingView> {
    const reason = input.reason.trim()
    if (reason.length < 5) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "A provider change needs a reason of at least five characters.",
        400,
      )
    }
    if (!isProvider(input.provider)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The payment provider is not supported.",
        400,
      )
    }
    if (!isMode(input.mode)) {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The payment mode is not supported.",
        400,
      )
    }
    if (input.provider === "vfd" && input.mode !== this.config.vfd.mode) {
      throw new ApiError(
        "VALIDATION_FAILED",
        `VFD is configured for ${this.config.vfd.mode}; change VFD_MODE before selecting ${input.mode}.`,
        400,
      )
    }
    if (
      input.provider === "paystack" &&
      !(input.mode === "live"
        ? this.config.paystack.secretKeyLive
        : this.config.paystack.secretKeyTest)
    ) {
      throw new ApiError(
        "SERVICE_UNAVAILABLE",
        `The Paystack ${input.mode} secret key is not configured in the secret store.`,
        503,
      )
    }

    try {
      return await this.database.withTransaction({}, async (transaction) => {
        const before = await transaction.query<{
          active_provider: string
          active_mode: string
        }>(
          "select active_provider, active_mode from platform.payment_provider_setting where id",
        )
        const result = await transaction.query<SettingRow>(
          "select * from platform.set_payment_provider($1, $2, $3)",
          [input.actorUserId, input.provider, input.mode],
        )
        const row = result.rows[0]
        if (!row) {
          throw new Error("The payment provider update returned no row.")
        }

        await appendAudit(transaction.client, {
          actorType: "admin",
          actorId: input.actorUserId,
          actorAudience: input.context.audience,
          environment: input.context.environment,
          action: "platform.payment_provider_changed",
          targetType: "platform",
          targetId: "payment_provider_setting",
          beforeSummary: before.rows[0]
            ? {
                provider: before.rows[0].active_provider,
                mode: before.rows[0].active_mode,
              }
            : undefined,
          afterSummary: {
            provider: row.active_provider,
            mode: row.active_mode,
          },
          reason,
          capability: "admin.configuration.write",
          ip: input.context.ip,
          userAgent: input.context.userAgent,
          correlationId: input.context.correlationId,
        })

        return this.toView(row)
      })
    } catch (error) {
      if (error instanceof ApiError) throw error
      this.mapError(error)
    }
  }

  private toView(row: SettingRow): PaymentProviderSettingView {
    const vfdConfigured = Boolean(
      this.config.vfd.consumerKey && this.config.vfd.consumerSecret,
    )
    return {
      provider: isProvider(row.active_provider)
        ? row.active_provider
        : "paystack",
      mode: isMode(row.active_mode) ? row.active_mode : "test",
      updatedAt: toIso(row.updated_at),
      configured: {
        vfd: {
          test: vfdConfigured && this.config.vfd.mode === "test",
          live: vfdConfigured && this.config.vfd.mode === "live",
        },
        paystack: {
          test: Boolean(this.config.paystack.secretKeyTest),
          live: Boolean(this.config.paystack.secretKeyLive),
        },
      },
    }
  }

  private mapError(error: unknown): never {
    const code =
      typeof error === "object" && error !== null && "code" in error
        ? (error as { code?: unknown }).code
        : undefined
    if (code === "42501") {
      throw new ApiError(
        "FORBIDDEN",
        "You do not have permission to change the payment provider.",
        403,
      )
    }
    if (code === "22023") {
      throw new ApiError(
        "VALIDATION_FAILED",
        "The payment provider change is not valid.",
        400,
      )
    }
    throw error instanceof Error
      ? error
      : new Error("The payment provider operation failed.")
  }
}
