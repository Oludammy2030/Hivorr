import { describe, expect, it } from "vitest"
import type { LaneStatus } from "@hivorr/shared"
import type { FastifyRequest } from "fastify"

import type { ApiConfig } from "../server/src/config"
import { VerificationLaneController } from "../server/src/api/verification-lane.controller"
import type { IdentityService } from "../server/src/modules/identity"
import type {
  LaneView,
  VerificationLaneService,
} from "../server/src/modules/profile/verification.service"

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111"
const USER_ID = "22222222-2222-4222-8222-222222222222"

const view: LaneView = {
  lane: "identity",
  state: "DRAFT",
  reasonCode: null,
  hasActiveSubmission: true,
  evidenceCount: 2,
  stateChangedAt: "2026-11-27T00:00:00.000Z",
}

function request(headers: Record<string, string> = {}): FastifyRequest {
  return {
    audience: "app",
    headers,
    cookies: { "__Host-hivorr_app_sid": "session-token" },
    id: "request-1",
    ip: "127.0.0.1",
    url: "/v1/verification/identity/status",
    method: "POST",
    socket: { remoteAddress: "127.0.0.1" },
  } as unknown as FastifyRequest
}

function harness() {
  const calls: { method: string; input: Record<string, unknown> }[] = []

  const identity = {
    getSession: async () => ({
      accountId: ACCOUNT_ID,
      userId: USER_ID,
      kycTier: "tier_1",
      email: "user@example.test",
      account: { displayName: "Test User" },
    }),
  } as unknown as IdentityService

  const lanes = {
    status: async (input: Record<string, unknown>) => {
      calls.push({ method: "status", input })
      return view
    },
    start: async (input: Record<string, unknown>) => {
      calls.push({ method: "start", input })
      return view
    },
    submit: async (input: Record<string, unknown>) => {
      calls.push({ method: "submit", input })
      return { ...view, state: "SUBMITTED" }
    },
    withdraw: async (input: Record<string, unknown>) => {
      calls.push({ method: "withdraw", input })
      return view
    },
  } as unknown as VerificationLaneService

  const config = {
    environment: "staging",
    logLevel: "silent",
  } as unknown as ApiConfig

  return {
    controller: new VerificationLaneController(identity, lanes, config),
    calls,
  }
}

function statusOf(value: LaneStatus | Promise<LaneStatus>): Promise<LaneStatus> {
  return Promise.resolve(value)
}

describe("verification lane API", () => {
  it("returns the shared lane status shape for the session's account", async () => {
    const { controller, calls } = harness()

    const result = await statusOf(controller.status("identity", request()))

    expect(result).toEqual({
      lane: "identity",
      state: "DRAFT",
      reasonCode: null,
      hasActiveSubmission: true,
      updatedAt: "2026-11-27T00:00:00.000Z",
    })
    expect(calls[0]?.input).toMatchObject({
      accountId: ACCOUNT_ID,
      userId: USER_ID,
      lane: "identity",
    })
    expect(calls[0]?.input).not.toHaveProperty("accountId", "other")
  })

  it("starts an attempt for the session account", async () => {
    const { controller, calls } = harness()

    await controller.start("trade", undefined, request())

    expect(calls[0]?.method).toBe("start")
    expect(calls[0]?.input).toMatchObject({ lane: "trade", accountId: ACCOUNT_ID })
  })

  it("requires an idempotency key for a submission", async () => {
    const { controller, calls } = harness()

    await expect(controller.submit("identity", request())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    expect(calls).toHaveLength(0)
  })

  it("passes a stable request hash with the submission key", async () => {
    const { controller, calls } = harness()

    await controller.submit("identity", request({ "idempotency-key": "verification-submit-0001" }))

    expect(calls[0]?.method).toBe("submit")
    expect(calls[0]?.input).toMatchObject({
      idempotencyKey: "verification-submit-0001",
      lane: "identity",
    })
    expect(typeof calls[0]?.input.requestHash).toBe("string")
    expect(String(calls[0]?.input.requestHash)).toHaveLength(64)
  })

  it("withdraws a submitted attempt", async () => {
    const { controller, calls } = harness()

    await controller.withdraw("identity", request())

    expect(calls[0]?.method).toBe("withdraw")
  })

  it("rate limits repeated starts per user", async () => {
    const { controller } = harness()

    for (let attempt = 0; attempt < 10; attempt += 1) {
      await controller.start("identity", undefined, request())
    }

    await expect(controller.start("identity", undefined, request())).rejects.toMatchObject({
      code: "RATE_LIMITED",
      statusCode: 429,
      headers: { "retry-after": expect.any(String) },
    })
  })

  it("does not spend another user's rate-limit budget", async () => {
    const { controller } = harness()

    for (let attempt = 0; attempt < 10; attempt += 1) {
      await controller.start("identity", undefined, request())
    }

    const identity = {
      getSession: async () => ({
        accountId: "99999999-9999-4999-8999-999999999999",
        userId: "88888888-8888-4888-8888-888888888888",
        kycTier: "tier_1",
        email: "other@example.test",
        account: { displayName: "Other" },
      }),
    } as unknown as IdentityService
    const lanes = {
      start: async () => view,
    } as unknown as VerificationLaneService
    const other = new VerificationLaneController(identity, lanes, {
      environment: "staging",
      logLevel: "silent",
    } as unknown as ApiConfig)

    await expect(other.start("identity", undefined, request())).resolves.toBeTruthy()
  })
})
