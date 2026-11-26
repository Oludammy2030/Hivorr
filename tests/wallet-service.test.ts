import { randomUUID } from "node:crypto"

import { describe, expect, it } from "vitest"

import type { DatabaseService } from "../server/src/db/database.service"
import type {
  WalletReadContext,
  WalletStatementQuery,
} from "../server/src/modules/finance/wallet.service"
import { WalletService } from "../server/src/modules/finance/wallet.service"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

class FakeTransaction {
  readonly calls: Call[] = []
  balanceRows: unknown[] = []
  statementRows: unknown[] = []

  query = async (text: string, values?: readonly unknown[]) => {
    this.calls.push({ text, values })
    if (text.includes("from finance.wallet_statement")) {
      return { rows: this.statementRows, rowCount: this.statementRows.length }
    }
    if (text.includes("from finance.wallet_balances")) {
      return { rows: this.balanceRows, rowCount: this.balanceRows.length }
    }
    return { rows: [], rowCount: 0 }
  }
}

function serviceWith(transaction: FakeTransaction): WalletService {
  const database = {
    withTransaction: async (
      _options: unknown,
      work: (context: FakeTransaction) => Promise<unknown>,
    ) => work(transaction),
  } as unknown as DatabaseService
  return new WalletService(database)
}

function context(): WalletReadContext {
  return { accountId: randomUUID(), userId: randomUUID() }
}

function balanceRow(overrides: Record<string, string> = {}) {
  return {
    currency: "NGN",
    available: "400.0000",
    pending: "300.0000",
    total: "700.0000",
    withdrawable: "400.0000",
    ...overrides,
  }
}

describe("wallet read model", () => {
  it("reads zero for an account with no ledger history", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    const result = await service.balance(context(), "NGN")

    expect(result).toEqual({
      currency: "NGN",
      total: "0.0000",
      available: "0.0000",
      pending: "0.0000",
      withdrawable: "0.0000",
    })
  })

  it("maps the derived figures from the balancing view", async () => {
    const transaction = new FakeTransaction()
    transaction.balanceRows = [balanceRow()]
    const service = serviceWith(transaction)

    const result = await service.balance(context(), "NGN")

    expect(result).toEqual({
      currency: "NGN",
      total: "700.0000",
      available: "400.0000",
      pending: "300.0000",
      withdrawable: "400.0000",
    })
    expect(transaction.calls[0]?.values).toEqual([expect.any(String), "NGN"])
  })

  it("lists every currency the account holds", async () => {
    const transaction = new FakeTransaction()
    transaction.balanceRows = [balanceRow(), balanceRow({ currency: "USD", available: "1.0000" })]
    const service = serviceWith(transaction)

    const result = await service.balances(context())

    expect(result.map((row) => row.currency)).toEqual(["NGN", "USD"])
    expect(result[1]?.available).toBe("1.0000")
  })

  it("maps statement rows with activity attribution and a stable cursor", async () => {
    const transaction = new FakeTransaction()
    const postingId = randomUUID()
    transaction.statementRows = [
      {
        posting_id: postingId,
        entry_id: randomUUID(),
        reference: "DEP-1",
        entry_kind: "deposit",
        currency: "NGN",
        direction: "debit",
        amount: "100.0000",
        signed_amount: "100.0000",
        activity_id: "market.buy",
        occurred_at: new Date("2026-11-18T00:00:00.000Z"),
      },
      {
        posting_id: randomUUID(),
        entry_id: randomUUID(),
        reference: "HOLD-1",
        entry_kind: "escrow_hold",
        currency: "NGN",
        direction: "credit",
        amount: "30.0000",
        signed_amount: "-30.0000",
        activity_id: "services.hire",
        occurred_at: "2026-11-17T00:00:00.000Z",
      },
    ]
    const service = serviceWith(transaction)

    const query: WalletStatementQuery = {
      currency: "NGN",
      activityId: "market.buy",
      before: "2026-11-18T00:00:00.000Z",
      beforeId: postingId,
      limit: 10,
    }
    const result = await service.statement(context(), query)

    expect(result).toHaveLength(2)
    expect(result[0]).toMatchObject({
      reference: "DEP-1",
      entryKind: "deposit",
      direction: "debit",
      amount: "100.0000",
      signedAmount: "100.0000",
      activityId: "market.buy",
      occurredAt: "2026-11-18T00:00:00.000Z",
    })
    expect(result[1]?.signedAmount).toBe("-30.0000")

    const call = transaction.calls[0]
    expect(call?.values?.slice(1)).toEqual([
      "NGN",
      "market.buy",
      "2026-11-18T00:00:00.000Z",
      postingId,
      10,
    ])
  })

  it("defaults the statement page to 50 rows", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    await service.statement(context())

    expect(transaction.calls[0]?.values?.[5]).toBe(50)
  })

  it("rejects a bad currency, page size, activity and cursor", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)
    const read = context()

    await expect(service.balance(read, "naira")).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    await expect(service.statement(read, { limit: 101 })).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    await expect(service.statement(read, { activityId: "market.discover" })).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    await expect(
      service.statement(read, { before: "2026-11-18T00:00:00.000Z" }),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
    await expect(
      service.statement(read, {
        before: "not-a-date",
        beforeId: randomUUID(),
      }),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
    await expect(
      service.statement(read, {
        before: "2026-11-18T00:00:00.000Z",
        beforeId: "not-a-uuid",
      }),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })

    expect(transaction.calls).toHaveLength(0)
  })
})
