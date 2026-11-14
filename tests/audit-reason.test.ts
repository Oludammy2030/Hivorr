import type { PoolClient } from "pg"
import { describe, expect, it } from "vitest"

import { appendAudit, requiresReason } from "../server/src/modules/platform"

/**
 * A client that records whether it was touched. The reason check must happen
 * before any write: an append that reaches the database without a reason has
 * already defeated the purpose.
 */
interface RecordingClient {
  readonly client: PoolClient
  readonly calls: () => number
}

function recordingClient(): RecordingClient {
  let calls = 0
  const client = {
    query: async () => {
      calls += 1
      return { rows: [] }
    },
  } as unknown as PoolClient
  return { client, calls: () => calls }
}

const baseEntry = {
  actorType: "admin" as const,
  actorId: "00000000-0000-0000-0000-000000000001",
  actorAudience: "control",
  environment: "staging",
  targetType: "user",
  targetId: "00000000-0000-0000-0000-000000000002",
}

describe("audit reason enforcement", () => {
  it("marks governed changes as reason-required", () => {
    expect(requiresReason("identity.role_assigned")).toBe(true)
    expect(requiresReason("identity.role_revoked")).toBe(true)
    expect(requiresReason("admin.access_denied")).toBe(true)
    expect(requiresReason("admin.staff_status_changed")).toBe(true)
    expect(requiresReason("account.closed")).toBe(true)
    expect(requiresReason("case.status_changed")).toBe(true)
  })

  it("does not require a reason for reads and authentication", () => {
    expect(requiresReason("admin.users_listed")).toBe(false)
    expect(requiresReason("admin.audit_read")).toBe(false)
    expect(requiresReason("identity.sign_in")).toBe(false)
    expect(requiresReason("case.note_added")).toBe(false)
  })

  it("refuses to append a governed change without a reason", async () => {
    const { client, calls } = recordingClient()

    await expect(
      appendAudit(client, {
        ...baseEntry,
        action: "identity.role_assigned",
      }),
    ).rejects.toThrow(/reason required/)

    expect(calls()).toBe(0)
  })

  it("refuses a reason that is only whitespace", async () => {
    const { client } = recordingClient()

    await expect(
      appendAudit(client, {
        ...baseEntry,
        action: "account.closed",
        reason: "   ",
      }),
    ).rejects.toThrow(/reason required/)
  })

  it("accepts a governed change with a reason and writes the row", async () => {
    const { client, calls } = recordingClient()

    await appendAudit(client, {
      ...baseEntry,
      action: "case.status_changed",
      reason: "Evidence received",
    })

    expect(calls()).toBe(1)
  })
})
