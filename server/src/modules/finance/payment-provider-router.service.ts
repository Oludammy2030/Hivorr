import { Inject, Injectable } from "@nestjs/common"
import type {
  AccountNameEnquiry,
  AccountNameEnquiryRequest,
  PaymentStatus,
  PaymentStatusQuery,
  PayoutRequest,
  PayoutResult,
  ProviderOperationContext,
} from "../../integrations/payments/payment-provider"
import {
  PaystackPayoutClient,
  type PaystackMode,
} from "../../integrations/paystack"
import { VFD_PAYOUTS } from "../../integrations/vfd"
import type { VfdPayoutClient } from "../../integrations/vfd"
import {
  API_CONFIG,
  type ApiConfig,
  type PaymentMode,
  type PaymentProviderKey,
} from "../../config"
import { PaymentProviderSettingsService } from "../platform"
import type { PayoutProviderPort } from "./payout-execution.service"

/**
 * Active-provider router (founder decision 2026-11-26).
 *
 * Paystack is the active provider; VFD is paused behind the same port. The
 * control panel writes `platform.payment_provider_setting`; this router reads
 * that row per call so a switch takes effect without a redeploy. Secrets are
 * read from configuration only.
 *
 * The VFD client is configured by `VFD_MODE`; the setting's mode must match it.
 * Paystack constructs a client for the selected mode from its test/live key.
 */
@Injectable()
export class PaymentProviderRouter implements PayoutProviderPort {
  /** Not used for routing; the result carries the concrete provider. */
  readonly provider = "router"

  constructor(
    @Inject(PaymentProviderSettingsService)
    private readonly settings: PaymentProviderSettingsService,
    @Inject(API_CONFIG) private readonly config: ApiConfig,
    @Inject(VFD_PAYOUTS) private readonly vfd: VfdPayoutClient,
  ) {}

  async initiatePayout(
    input: PayoutRequest,
    context: ProviderOperationContext,
  ): Promise<PayoutResult> {
    const active = await this.activeSetting()
    if (active.provider === "vfd") {
      return this.vfd.initiatePayout(input, context)
    }
    return this.paystack(active.mode).initiatePayout(input, context)
  }

  async getPaymentStatus(query: PaymentStatusQuery): Promise<PaymentStatus> {
    const active = await this.activeSetting()
    if (active.provider === "vfd") {
      return this.vfd.getPaymentStatus(query)
    }
    return this.paystack(active.mode).getPaymentStatus(query)
  }

  async resolveAccountName(
    input: AccountNameEnquiryRequest,
  ): Promise<AccountNameEnquiry> {
    const active = await this.activeSetting()
    if (active.provider === "vfd") {
      return this.vfd.resolveAccountName(input)
    }
    return this.paystack(active.mode).resolveAccountName(input)
  }

  private async activeSetting(): Promise<{
    readonly provider: PaymentProviderKey
    readonly mode: PaymentMode
  }> {
    return this.settings.activeSetting()
  }

  private paystack(mode: PaystackMode): PaystackPayoutClient {
    const paystack = this.config.paystack
    return new PaystackPayoutClient({
      baseUrl: paystack.baseUrl,
      mode,
      secretKey:
        mode === "live" ? paystack.secretKeyLive : paystack.secretKeyTest,
      requestTimeoutMs: this.config.vfd.requestTimeoutMs,
      maxRetries: this.config.vfd.maxRetries,
      retryBaseMs: this.config.vfd.retryBaseMs,
    })
  }
}
