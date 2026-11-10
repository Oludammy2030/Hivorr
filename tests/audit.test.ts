import { describe, expect, it } from "vitest"

import {
  appendAudit,
  listAuditEntries,
} from "../server/src/modules/platform/audit"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

class FakeClient {
  readonly calls: Call[] = []
  rows: unknown[] = []
  fail = false

  async query(text: string, values?: readonly unknown[]) {
    this.calls.push({ text, values })
    if (this.fail) throw new Error("audit insert failed")
    return { rows: this.rows, rowCount: this.rows.length }
  }
}

describe("audit service", () => {
  it("writes actor, audience, correlation, target and summaries", async () => {
    const client = new FakeClient()
    await appendAudit(client as never, {
      actorType: "user",
      actorId: "user-1",
      actorAudience: "app",
      environment: "staging",
      action: "profile.activity_activated",
      targetType: "activity",
      targetId: "market.sell",
      beforeSummary: { state: "INACTIVE" },
      afterSummary: { state: "ACTIVE" },
      correlationId: "correlation-1",
    })

    expect(client.calls).toHaveLength(1)
    const values = client.calls[0]?.values ?? []
    expect(values[0]).toBe("user")
    expect(values[1]).toBe("user-1")
    expect(values[2]).toBe("app")
    expect(values[3]).toBe("staging")
    expect(values[4]).toBe("profile.activity_activated")
    expect(values[5]).toBe("activity")
    expect(values[6]).toBe("market.sell")
    expect(values[7]).toBe(JSON.stringify({ state: "INACTIVE" }))
    expect(values[8]).toBe(JSON.stringify({ state: "ACTIVE" }))
    expect(values[11]).toBe("correlation-1")
  })

  it("propagates an audit failure to the caller's transaction", async () => {
    const client = new FakeClient()
    client.fail = true
    await expect(
      appendAudit(client as never, {
        actorType: "system",
        actorId: "system",
        actorAudience: "system",
        environment: "test",
        action: "test.action",
        targetType: "test",
        targetId: "test-1",
      }),
    ).rejects.toThrow("audit insert failed")
  })

  it("returns the review fields and summaries", async () => {
    const client = new FakeClient()
    client.rows = [
      {
        id: "audit-1",
        occurred_at: "2026-11-09T00:00:00.000Z",
        actor_type: "user",
        actor_id: "user-1",
        actor_audience: "app",
        environment: "staging",
        action: "profile.activity_activated",
        target_type: "activity",
        target_id: "market.sell",
        before_summary: { state: "INACTIVE" },
        after_summary: { state: "ACTIVE" },
        correlation_id: "correlation-1",
      },
    ]

    const entries = await listAuditEntries(client as never, 500)
    expect(client.calls[0]?.values).toEqual([200])
    expect(entries).toEqual([
      {
        id: "audit-1",
        occurredAt: "2026-11-09T00:00:00.000Z",
        actorType: "user",
        actorId: "user-1",
        actorAudience: "app",
        environment: "staging",
        action: "profile.activity_activated",
        targetType: "activity",
        targetId: "market.sell",
        beforeSummary: { state: "INACTIVE" },
        afterSummary: { state: "ACTIVE" },
        correlationId: "correlation-1",
      },
    ])
  })
})
