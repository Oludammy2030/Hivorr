import { describe, expect, it } from "vitest"

import { parseConfig } from "../server/src/config"
import { IdentityService } from "../server/src/modules/identity"

const ACTOR_ID = "11111111-1111-4111-8111-111111111111"
const ACCOUNT_ID = "22222222-2222-4222-8222-222222222222"

const context = {
  audience: "control" as const,
  environment: "test" as const,
  correlationId: "corr-1",
}

function harness(
  options: {
    readonly previous?: string
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
    async query(text: string, values?: readonly unknown[]) {
      if (text.includes("select kyc_tier from identity.accounts")) {
        return { rows: [{ kyc_tier: options.previous ?? "tier_0" }] }
      }
      if (text.includes("identity.set_kyc_tier")) {
        if (options.error) throw options.error
        return {
          rows: [
            {
              account_id: values?.[1],
              kyc_tier: values?.[2],
              updated_at: "2026-11-23T10:00:00.000Z",
            },
          ],
        }
      }
      throw new Error(`unexpected query: ${text}`)
    },
  }

  const database = {
    async withTransaction(
      _options: unknown,
      work: (tx: unknown) => Promise<unknown>,
    ) {
      return work(transaction)
    },
  }

  const service = new IdentityService(
    database as never,
    parseConfig({ HIVORR_ENV: "test" }),
  )

  return { service, audits }
}

function input(overrides: Record<string, unknown> = {}) {
  return {
    actorUserId: ACTOR_ID,
    accountId: ACCOUNT_ID,
    tier: "tier_1",
    reason: "CBN tier one documents reviewed",
    context,
    ...overrides,
  }
}

describe("KYC tier assignment", () => {
  it("assigns tier_1 and audits the previous and new tier", async () => {
    const test = harness({ previous: "tier_0" })
    const view = await test.service.setKycTier(input())

    expect(view).toEqual({
      accountId: ACCOUNT_ID,
      tier: "tier_1",
      updatedAt: "2026-11-23T10:00:00.000Z",
    })
    expect(test.audits).toHaveLength(1)
    const audit = JSON.stringify(test.audits[0])
    expect(audit).toContain("identity.kyc_tier_changed")
    expect(audit).toContain("tier_0")
    expect(audit).toContain("tier_1")
  })

  it("refuses a tier outside the approved contract", async () => {
    const test = harness()

    await expect(
      test.service.setKycTier(input({ tier: "tier_2" })),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED", statusCode: 400 })
    expect(test.audits).toHaveLength(0)
  })

  it("requires a reason", async () => {
    const test = harness()

    await expect(
      test.service.setKycTier(input({ reason: "no" })),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED", statusCode: 400 })
  })

  it("maps a missing verifier permission to forbidden", async () => {
    const denied = Object.assign(new Error("denied"), { code: "42501" })
    const test = harness({ error: denied })

    await expect(test.service.setKycTier(input())).rejects.toMatchObject({
      code: "FORBIDDEN",
      statusCode: 403,
    })
  })

  it("maps an unknown account to not found", async () => {
    const missing = Object.assign(new Error("missing"), { code: "P0002" })
    const test = harness({ error: missing })

    await expect(test.service.setKycTier(input())).rejects.toMatchObject({
      code: "NOT_FOUND",
      statusCode: 404,
    })
  })
})
