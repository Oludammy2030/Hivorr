import { afterEach, describe, expect, it, vi } from "vitest"

import type { ApiConfig } from "../server/src/config"
import type {
  AccountNameEnquiry,
  PaymentStatus,
  PayoutResult,
} from "../server/src/integrations/payments/payment-provider"
import type { VfdPayoutClient } from "../server/src/integrations/vfd"
import { PaymentProviderRouter } from "../server/src/modules/finance/payment-provider-router.service"
import type { PaymentProviderSettingsService } from "../server/src/modules/platform"

const TEST_KEY = "sk_test_router"
const LIVE_KEY = "sk_live_router"

function config(): ApiConfig {
  return {
    environment: "test",
    paystack: {
      baseUrl: "https://api.paystack.test",
      secretKeyTest: TEST_KEY,
      secretKeyLive: LIVE_KEY,
      preferredBank: "titan-paystack",
    },
    vfd: {
      requestTimeoutMs: 500,
      maxRetries: 0,
      retryBaseMs: 1,
    },
  } as unknown as ApiConfig
}

interface FetchCall {
  readonly url: string
  readonly authorization: string
  readonly method: string
}

function stubPaystack(): FetchCall[] {
  const calls: FetchCall[] = []
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const target = String(url)
      calls.push({
        url: target,
        authorization: String(
          (init?.headers as Record<string, string> | undefined)
            ?.authorization ?? "",
        ),
        method: String(init?.method ?? "GET"),
      })
      const body = target.endsWith("/transferrecipient")
        ? { status: true, data: { recipient_code: "RCP_1" } }
        : target.endsWith("/transfer")
          ? {
              status: true,
              data: { transfer_code: "TRF_1", status: "pending" },
            }
          : target.includes("/bank/resolve")
            ? { status: true, data: { account_name: "KUTI SEMA" } }
            : {
                status: true,
                data: {
                  status: "success",
                  transfer_code: "TRF_1",
                  amount: 5000,
                  currency: "NGN",
                  transferred_at: "2026-11-26T10:00:00.000Z",
                },
              }
      return new Response(JSON.stringify(body), {
        status: 200,
        headers: { "content-type": "application/json" },
      })
    }),
  )
  return calls
}

interface ActiveSetting {
  readonly provider: "paystack" | "vfd"
  readonly mode: "test" | "live"
}

function harness(
  setting: ActiveSetting = {
    provider: "paystack",
    mode: "test",
  },
) {
  const vfdCalls: string[] = []
  const vfd = {
    provider: "vfd",
    initiatePayout: async (input: {
      reference: string
    }): Promise<PayoutResult> => {
      vfdCalls.push("initiatePayout")
      return {
        provider: "vfd",
        reference: input.reference,
        providerReference: "VFD-1",
        status: "processing",
        failureCode: null,
        failureMessage: null,
        occurredAt: "2026-11-26T10:00:00.000Z",
      }
    },
    getPaymentStatus: async (): Promise<PaymentStatus> => {
      vfdCalls.push("getPaymentStatus")
      return {
        provider: "vfd",
        reference: "payout-1",
        providerReference: "VFD-1",
        status: "paid",
        amount: "50.0000",
        currency: "NGN",
        occurredAt: "2026-11-26T10:00:00.000Z",
      }
    },
    resolveAccountName: async (input: {
      bankCode: string
    }): Promise<AccountNameEnquiry> => {
      vfdCalls.push("resolveAccountName")
      return {
        accountName: "KUTI SEMA",
        bankCode: input.bankCode,
        accountNumberLast4: "7890",
      }
    },
  } as unknown as VfdPayoutClient

  let active = setting
  const settings = {
    activeSetting: async () => active,
  } as unknown as PaymentProviderSettingsService

  const router = new PaymentProviderRouter(settings, config(), vfd)

  return {
    router,
    vfdCalls,
    switchTo: (next: ActiveSetting) => {
      active = next
    },
  }
}

const payout = {
  reference: "payout-1",
  amount: "50.0000",
  currency: "NGN",
  bankCode: "058",
  accountNumber: "0123456789",
  accountName: "KUTI SEMA",
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("payment provider router", () => {
  it("routes a payout to Paystack and returns its result", async () => {
    const calls = stubPaystack()
    const { router, vfdCalls } = harness()

    const result = await router.initiatePayout(payout, {
      idempotencyKey: "payout-key-1",
    })

    expect(result).toMatchObject({
      provider: "paystack",
      providerReference: "TRF_1",
      status: "processing",
    })
    expect(vfdCalls).toHaveLength(0)
    expect(calls.map((call) => call.url)).toEqual([
      "https://api.paystack.test/transferrecipient",
      "https://api.paystack.test/transfer",
    ])
    expect(
      calls.every((call) => call.authorization === `Bearer ${TEST_KEY}`),
    ).toBe(true)
  })

  it("uses the live key when the setting is live", async () => {
    const calls = stubPaystack()
    const { router } = harness({ provider: "paystack", mode: "live" })

    await router.initiatePayout(payout, { idempotencyKey: "payout-key-2" })

    expect(
      calls.every((call) => call.authorization === `Bearer ${LIVE_KEY}`),
    ).toBe(true)
  })

  it("routes every operation to VFD when VFD is active", async () => {
    const calls = stubPaystack()
    const { router, vfdCalls } = harness({ provider: "vfd", mode: "test" })

    await router.initiatePayout(payout, { idempotencyKey: "payout-key-3" })
    await router.getPaymentStatus({ reference: "payout-1" })
    await router.resolveAccountName({
      bankCode: "058",
      accountNumber: "0123456789",
    })

    expect(vfdCalls).toEqual([
      "initiatePayout",
      "getPaymentStatus",
      "resolveAccountName",
    ])
    expect(calls).toHaveLength(0)
  })

  it("reads the active provider on every call", async () => {
    const calls = stubPaystack()
    const { router, vfdCalls, switchTo } = harness()

    await router.initiatePayout(payout, { idempotencyKey: "payout-key-4" })
    switchTo({ provider: "vfd", mode: "test" })
    await router.initiatePayout(payout, { idempotencyKey: "payout-key-5" })

    expect(vfdCalls).toEqual(["initiatePayout"])
    expect(calls).toHaveLength(2)
  })

  it("resolves a name through Paystack's bank-resolve endpoint", async () => {
    const calls = stubPaystack()
    const { router } = harness()

    const result = await router.resolveAccountName({
      bankCode: "058",
      accountNumber: "0123456789",
    })

    expect(result).toEqual({
      accountName: "KUTI SEMA",
      bankCode: "058",
      accountNumberLast4: "6789",
    })
    expect(calls[0]?.url).toContain("/bank/resolve")
    expect(calls[0]?.url).toContain("account_number=0123456789")
  })

  it("reads a payout status through Paystack", async () => {
    stubPaystack()
    const { router } = harness()

    const result = await router.getPaymentStatus({ reference: "payout-1" })

    expect(result).toMatchObject({
      provider: "paystack",
      status: "paid",
      amount: "50.0000",
      currency: "NGN",
    })
  })
})
