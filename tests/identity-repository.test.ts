import { describe, expect, it } from "vitest"

import type { TransactionContext } from "../server/src/db/transaction"
import {
  IdentityRepository,
  assertIdentitySchemaSql,
} from "../server/src/modules/identity/repositories/identity.repository"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

class FakeTransaction {
  readonly calls: Call[] = []
  rows: unknown[] = []

  async query(text: string, values?: readonly unknown[]) {
    this.calls.push({ text, values })
    return { rows: this.rows, rowCount: this.rows.length }
  }

  async setIdentity() {
    return undefined
  }

  get client() {
    return {} as never
  }
}

function repositoryWith(transaction: FakeTransaction): IdentityRepository {
  return new IdentityRepository(transaction as unknown as TransactionContext)
}

describe("identity repository", () => {
  it("creates the account, user, credential and owner membership only", async () => {
    const transaction = new FakeTransaction()
    const repository = repositoryWith(transaction)

    await repository.createAccountWithOwner({
      accountId: "account-1",
      userId: "user-1",
      email: "Founder@Example.Test",
      displayName: "Founder",
      passwordHash: "argon2id-hash",
    })

    expect(transaction.calls).toHaveLength(4)
    const sql = transaction.calls.map((call) => call.text).join("\n")
    expect(sql).toContain("insert into identity.accounts")
    expect(sql).toContain("insert into identity.users")
    expect(sql).toContain("insert into identity.credentials")
    expect(sql).toContain("insert into identity.memberships")
    expect(sql).not.toContain("identity.grants")
    expect(sql).not.toContain("profile.activity_activations")
    expect(transaction.calls[1]?.values).toEqual([
      "user-1",
      "account-1",
      "founder@example.test",
      "Founder",
    ])
  })

  it("rejects SQL that reaches another module's schema", () => {
    expect(() =>
      assertIdentitySchemaSql("select * from market.orders"),
    ).toThrow(/market schema/)
    expect(() =>
      assertIdentitySchemaSql("select * from profile.profiles"),
    ).toThrow(/profile schema/)
    expect(() =>
      assertIdentitySchemaSql("select * from identity.users where id = $1"),
    ).not.toThrow()
    expect(() =>
      assertIdentitySchemaSql("select platform.uuidv7()"),
    ).not.toThrow()
  })

  it("maps a user row without leaking snake_case", async () => {
    const transaction = new FakeTransaction()
    transaction.rows = [
      {
        id: "user-1",
        account_id: "account-1",
        email: "founder@example.test",
        display_name: "Founder",
        status: "active",
      },
    ]
    const repository = repositoryWith(transaction)

    const user = await repository.findUser("user-1")
    expect(user).toEqual({
      id: "user-1",
      accountId: "account-1",
      email: "founder@example.test",
      displayName: "Founder",
      status: "active",
    })
    expect(transaction.calls[0]?.values).toEqual(["user-1"])
  })

  it("returns undefined when a lookup finds nothing", async () => {
    const repository = repositoryWith(new FakeTransaction())
    expect(await repository.findAccount("missing")).toBeUndefined()
    expect(
      await repository.findUserByEmail("missing@example.test"),
    ).toBeUndefined()
  })

  it("lists memberships, grants and devices with parameters", async () => {
    const transaction = new FakeTransaction()
    const repository = repositoryWith(transaction)

    await repository.listMemberships("account-1")
    await repository.listGrants("user-1")
    await repository.listDevices("user-1")

    expect(transaction.calls).toHaveLength(3)
    expect(transaction.calls.map((call) => call.values)).toEqual([
      ["account-1"],
      ["user-1"],
      ["user-1"],
    ])
    expect(
      transaction.calls.every((call) =>
        /from identity\.(memberships|grants|devices)/.test(call.text),
      ),
    ).toBe(true)
  })
})
