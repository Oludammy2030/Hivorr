import { describe, expect, it } from "vitest"

import { ApiError } from "../server/src/common/errors"
import type { ApiConfig } from "../server/src/config"
import type { DatabaseService } from "../server/src/db/database.service"
import { CaptureEmailAdapter } from "../server/src/integrations/email/email.adapter"
import { StaffService } from "../server/src/modules/admin/staff.service"

function serviceWithIpLimit(max: number): StaffService {
  const database = {
    withTransaction: async () => {
      throw new Error("the database should not be reached")
    },
  } as unknown as DatabaseService
  const config = {
    auth: { rateLimitWindowMs: 60_000, ipMax: max },
    mail: {
      token: undefined,
      apiUrl: "https://api.zeptomail.com/v1.1/email",
      fromAddress: undefined,
      fromName: "Hivorr",
      appOrigin: undefined,
      staffEmailDomain: "hivorr.com",
    },
  } as unknown as ApiConfig
  return new StaffService(database, config, new CaptureEmailAdapter())
}

const input = {
  environment: "test" as const,
  token: "a".repeat(64),
  password: "correct-horse-battery-staple",
  ip: "203.0.113.7",
}

describe("staff invite acceptance rate limit", () => {
  it("rejects further attempts from the same address before hashing", async () => {
    const service = serviceWithIpLimit(1)

    await expect(service.acceptInvite(input)).rejects.toThrow(
      "the database should not be reached",
    )

    const error = await service.acceptInvite(input).catch((value) => value)
    expect(error).toBeInstanceOf(ApiError)
    expect((error as ApiError).statusCode).toBe(429)
  })

  it("shares the budget with the invitation lookup", async () => {
    const service = serviceWithIpLimit(1)

    await expect(service.inviteDetails(input.token, input.ip)).rejects.toThrow(
      "the database should not be reached",
    )

    const error = await service
      .inviteDetails(input.token, input.ip)
      .catch((value) => value)
    expect(error).toBeInstanceOf(ApiError)
    expect((error as ApiError).statusCode).toBe(429)
  })
})

describe("official staff address", () => {
  it("refuses an account outside the company domain before touching the database", async () => {
    const service = serviceWithIpLimit(5)

    const error = await service
      .invite({
        accountId: "account",
        userId: "user",
        context: {
          audience: "control",
          environment: "test",
          ip: "203.0.113.7",
        } as never,
        email: "candidate@gmail.com",
        deliveryEmail: "candidate@gmail.com",
        reason: "New operations hire",
      })
      .catch((value) => value)

    expect(error).toBeInstanceOf(ApiError)
    expect((error as ApiError).statusCode).toBe(400)
    expect((error as ApiError).message).toContain("@hivorr.com")
  })
})
