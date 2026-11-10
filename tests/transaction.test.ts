import type { Pool } from "pg"
import { describe, expect, it } from "vitest"

import { withTransaction } from "../server/src/db/transaction"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

class FakeClient {
  readonly calls: Call[] = []
  released = false
  failOnCommit = false

  async query(text: string, values?: readonly unknown[]) {
    this.calls.push({ text, values })
    if (text === "commit" && this.failOnCommit) {
      throw new Error("commit failed")
    }
    return { rows: [], rowCount: 0 }
  }

  release() {
    this.released = true
  }
}

function poolWith(client: FakeClient): Pool {
  return { connect: async () => client } as unknown as Pool
}

function texts(client: FakeClient): string[] {
  return client.calls.map((call) => call.text)
}

describe("unit of work", () => {
  it("opens, sets context, commits and releases", async () => {
    const client = new FakeClient()
    const result = await withTransaction(
      poolWith(client),
      { identity: { accountId: "account-1", userId: "user-1" } },
      async (transaction) => {
        await transaction.query("select 1")
        return "done"
      },
    )

    expect(result).toBe("done")
    expect(texts(client)).toEqual([
      "begin",
      "select platform.set_identity_context($1, $2)",
      "select 1",
      "commit",
    ])
    expect(client.calls[1]?.values).toEqual(["account-1", "user-1"])
    expect(client.released).toBe(true)
  })

  it("does not set a context when none is requested", async () => {
    const client = new FakeClient()
    await withTransaction(poolWith(client), {}, async () => undefined)
    expect(texts(client)).toEqual(["begin", "commit"])
    expect(client.released).toBe(true)
  })

  it("rolls back and rethrows a work failure", async () => {
    const client = new FakeClient()
    await expect(
      withTransaction(poolWith(client), {}, async () => {
        throw new Error("business failure")
      }),
    ).rejects.toThrow("business failure")

    expect(texts(client)).toEqual(["begin", "rollback"])
    expect(client.released).toBe(true)
  })

  it("can set the context again after creating an account", async () => {
    const client = new FakeClient()
    await withTransaction(poolWith(client), {}, async (transaction) => {
      await transaction.setIdentity({
        accountId: "new-account",
        userId: "new-user",
      })
    })

    expect(
      client.calls.filter(
        (call) => call.text === "select platform.set_identity_context($1, $2)",
      ),
    ).toHaveLength(1)
  })

  it("rolls back when commit fails and still releases", async () => {
    const client = new FakeClient()
    client.failOnCommit = true
    await expect(
      withTransaction(poolWith(client), {}, async () => "ignored"),
    ).rejects.toThrow("commit failed")

    expect(texts(client)).toEqual(["begin", "commit", "rollback"])
    expect(client.released).toBe(true)
  })

  it("passes parameters through without interpolation", async () => {
    const client = new FakeClient()
    await withTransaction(poolWith(client), {}, async (transaction) => {
      await transaction.query("select * from t where id = $1", [
        "id'; drop table t; --",
      ])
    })

    const query = client.calls.find((call) => call.text.includes("where id"))
    expect(query?.values).toEqual(["id'; drop table t; --"])
    expect(query?.text).not.toContain("drop table")
  })

  it("does not share a connection between transactions", async () => {
    const clients: FakeClient[] = []
    const pool = {
      connect: async () => {
        const client = new FakeClient()
        clients.push(client)
        return client
      },
    } as unknown as Pool

    await withTransaction(
      pool,
      { identity: { accountId: "account-a", userId: "user-a" } },
      async () => undefined,
    )
    await withTransaction(
      pool,
      { identity: { accountId: "account-b", userId: "user-b" } },
      async () => undefined,
    )

    expect(clients).toHaveLength(2)
    expect(clients[0]).not.toBe(clients[1])
    expect(
      clients[0]?.calls.find((call) => call.text.includes("set_identity"))
        ?.values,
    ).toEqual(["account-a", "user-a"])
    expect(
      clients[1]?.calls.find((call) => call.text.includes("set_identity"))
        ?.values,
    ).toEqual(["account-b", "user-b"])
  })
})
