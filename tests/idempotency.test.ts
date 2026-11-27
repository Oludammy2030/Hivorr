import { describe, expect, it } from "vitest"

import { claimIdempotency, completeIdempotency } from "../server/src/modules/platform/idempotency"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

class FakeClient {
  readonly calls: Call[] = []
  insertRowCount = 1
  existingRow: {
    request_hash: string
    response_status: number | null
    response_body: unknown
  } | null = null

  async query(text: string, values?: readonly unknown[]) {
    this.calls.push({ text, values })
    if (text.includes("insert into platform.idempotency_keys")) {
      return { rows: [], rowCount: this.insertRowCount }
    }
    if (text.includes("select request_hash")) {
      return {
        rows: this.existingRow ? [this.existingRow] : [],
        rowCount: this.existingRow ? 1 : 0,
      }
    }
    return { rows: [], rowCount: 1 }
  }
}

const input = {
  key: "finance.ledger.post:account-1:key-0001",
  scope: "finance.ledger.post",
  requestHash: "hash-1",
  expiresAt: "infinity",
}

describe("idempotency store", () => {
  it("claims a new key", async () => {
    const client = new FakeClient()

    const result = await claimIdempotency(
      client as unknown as Parameters<typeof claimIdempotency>[0],
      input,
    )

    expect(result).toEqual({ status: "claimed" })
    expect(client.calls[0]?.values).toEqual([input.key, input.scope, input.requestHash, "infinity"])
  })

  it("replays the stored response for the same request", async () => {
    const client = new FakeClient()
    client.insertRowCount = 0
    client.existingRow = {
      request_hash: "hash-1",
      response_status: 201,
      response_body: { id: "entry-1" },
    }

    const result = await claimIdempotency(
      client as unknown as Parameters<typeof claimIdempotency>[0],
      input,
    )

    expect(result).toEqual({
      status: "replay",
      responseStatus: 201,
      responseBody: { id: "entry-1" },
    })
    expect(client.calls[1]?.text).toContain("for update")
  })

  it("refuses a reused key with a different request", async () => {
    const client = new FakeClient()
    client.insertRowCount = 0
    client.existingRow = {
      request_hash: "hash-2",
      response_status: 201,
      response_body: { id: "entry-1" },
    }

    const result = await claimIdempotency(
      client as unknown as Parameters<typeof claimIdempotency>[0],
      input,
    )

    expect(result).toEqual({ status: "conflict" })
  })

  it("refuses a record with no completed response", async () => {
    const client = new FakeClient()
    client.insertRowCount = 0
    client.existingRow = {
      request_hash: "hash-1",
      response_status: null,
      response_body: null,
    }

    await expect(
      claimIdempotency(client as unknown as Parameters<typeof claimIdempotency>[0], input),
    ).rejects.toThrow("no completed response")
  })

  it("completes the record with the response", async () => {
    const client = new FakeClient()

    await completeIdempotency(client as unknown as Parameters<typeof completeIdempotency>[0], {
      key: input.key,
      responseStatus: 201,
      responseBody: { id: "entry-1" },
    })

    expect(client.calls[0]?.values).toEqual([input.key, 201, JSON.stringify({ id: "entry-1" })])
  })
})
