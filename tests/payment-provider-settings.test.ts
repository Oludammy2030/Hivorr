import { describe, expect, it } from "vitest"

import { parseConfig } from "../server/src/config"
import { PaymentProviderSettingsService } from "../server/src/modules/platform"

const ACTOR_ID = "11111111-1111-4111-8111-111111111111"

const context = {
  audience: "control" as const,
  environment: "test" as const,
  correlationId: "corr-1",
}

function config(overrides: Record<string, string> = {}) {
  return parseConfig({
    HIVORR_ENV: "test",
    PAYSTACK_SECRET_KEY_TEST: "sk_test_fake_key",
    ...overrides,
  })
}

function harness(
  options: {
    readonly row?: Record<string, unknown>
    readonly error?: Error & { code?: string }
  } = {},
) {
  const audits: unknown[][] = []
  const transaction = {
    client: {
      async query(text: string, values?: readonly unknown[]) {
        if (text.includes("platform.audit_log")) {
          audits.push(values ? [...values] : [])
        }
        return { rows: [], rowCount: 1 }
      },
    },
    async query(text: string) {
      if (text.includes("get_payment_provider")) {
        return {
          rows: [
            options.row ?? {
              active_provider: "paystack",
              active_mode: "test",
              updated_at: "2026-11-26T10:00:00.000Z",
            },
          ],
        }
      }
      if (text.includes("from platform.payment_provider_setting")) {
        return {
          rows: [{ active_provider: "vfd", active_mode: "test" }],
        }
      }
      if (text.includes("set_payment_provider")) {
        if (options.error) throw options.error
        return {
          rows: [
            {
              active_provider: "paystack",
              active_mode: "test",
              updated_at: "2026-11-26T10:00:00.000Z",
            },
          ],
        }
      }
      throw new Error(`unexpected query: ${text}`)
    },
  }

  const database = {
    async withTransaction(_options: unknown, work: (tx: unknown) => Promise<unknown>) {
      return work(transaction)
    },
  }

  return {
    service: new PaymentProviderSettingsService(database as never, config()),
    audits,
  }
}

function input(overrides: Record<string, unknown> = {}) {
  return {
    actorUserId: ACTOR_ID,
    provider: "paystack",
    mode: "test",
    reason: "Paystack integration approved for fast launch",
    context,
    ...overrides,
  }
}

describe("payment provider settings", () => {
  it("reads the active setting and reports configured modes", async () => {
    const test = harness()
    const view = await test.service.get(ACTOR_ID)

    expect(view).toMatchObject({
      provider: "paystack",
      mode: "test",
    })
    expect(view.configured.paystack.test).toBe(true)
    expect(view.configured.paystack.live).toBe(false)
  })

  it("switches the provider and audits the change", async () => {
    const test = harness()
    const view = await test.service.set(input())

    expect(view.provider).toBe("paystack")
    expect(test.audits).toHaveLength(1)
    expect(JSON.stringify(test.audits[0])).toContain("platform.payment_provider_changed")
  })

  it("refuses a provider whose selected mode key is missing", async () => {
    const test = harness()
    // The service was built with a test key only; live is unconfigured.
    await expect(test.service.set(input({ mode: "live" }))).rejects.toMatchObject({
      code: "SERVICE_UNAVAILABLE",
      statusCode: 503,
    })
  })

  it("refuses a VFD mode that does not match VFD_MODE", async () => {
    const test = harness()
    await expect(test.service.set(input({ provider: "vfd", mode: "live" }))).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
      statusCode: 400,
    })
  })

  it("maps a missing configuration permission to forbidden", async () => {
    const denied = Object.assign(new Error("denied"), { code: "42501" })
    const test = harness({ error: denied })

    await expect(test.service.set(input())).rejects.toMatchObject({
      code: "FORBIDDEN",
      statusCode: 403,
    })
  })
})
