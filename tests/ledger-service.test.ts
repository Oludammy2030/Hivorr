import { randomUUID } from "node:crypto"

import { describe, expect, it } from "vitest"

import { ApiError } from "../server/src/common/errors"
import type { DatabaseService } from "../server/src/db/database.service"
import { hashLedgerEntry } from "../server/src/modules/finance/idempotency"
import type { LedgerPostingContext } from "../server/src/modules/finance/ledger.service"
import { LedgerService } from "../server/src/modules/finance/ledger.service"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

interface ReversalRow {
  entry_currency: string
  ledger_account_id: string
  direction: string
  amount: string
  currency: string
  activity_id: string | null
}

class FakeTransaction {
  readonly calls: Call[] = []
  reversalRows: ReversalRow[] = []
  failEntryCode: string | undefined
  idempotencyClaimed = true
  idempotencyRow: {
    request_hash: string
    response_status: number | null
    response_body: unknown
  } | null = null

  private readonly entryId = randomUUID()

  query = async (text: string, values?: readonly unknown[]) => {
    this.calls.push({ text, values })

    if (text.includes("insert into platform.idempotency_keys")) {
      return { rows: [], rowCount: this.idempotencyClaimed ? 1 : 0 }
    }

    if (text.includes("select request_hash")) {
      return {
        rows: this.idempotencyRow ? [this.idempotencyRow] : [],
        rowCount: this.idempotencyRow ? 1 : 0,
      }
    }

    if (text.includes("update platform.idempotency_keys")) {
      return { rows: [], rowCount: 1 }
    }

    if (text.includes("je.currency as entry_currency")) {
      return { rows: this.reversalRows, rowCount: this.reversalRows.length }
    }

    if (text.startsWith("insert into finance.journal_entries")) {
      if (this.failEntryCode) {
        const error = new Error("database rejected the insert") as Error & {
          code?: string
        }
        error.code = this.failEntryCode
        throw error
      }
      return {
        rows: [
          {
            id: this.entryId,
            created_at: new Date("2026-11-18T00:00:00.000Z"),
          },
        ],
        rowCount: 1,
      }
    }

    return { rows: [], rowCount: 0 }
  }

  readonly client = { query: this.query }
}

function serviceWith(transaction: FakeTransaction): LedgerService {
  const database = {
    withTransaction: async (
      _options: unknown,
      work: (context: FakeTransaction) => Promise<unknown>,
    ) => work(transaction),
  } as unknown as DatabaseService
  return new LedgerService(database)
}

function context(): LedgerPostingContext {
  return {
    accountId: randomUUID(),
    userId: randomUUID(),
    audience: "app",
    environment: "test",
    correlationId: "corr-ledger-1",
  }
}

function balancedInput() {
  return {
    kind: "deposit" as const,
    reference: "DEP-SERVICE-1",
    currency: "NGN",
    idempotencyKey: "idem-service-0001",
    postings: [
      {
        accountId: randomUUID(),
        direction: "debit" as const,
        amount: "100.0000",
        currency: "NGN",
      },
      {
        accountId: randomUUID(),
        direction: "credit" as const,
        amount: "100.0000",
        currency: "NGN",
      },
    ],
  }
}

function findCall(calls: readonly Call[], fragment: string): Call {
  const call = calls.find((entry) => entry.text.includes(fragment))
  if (!call) throw new Error(`missing call containing ${fragment}`)
  return call
}

describe("ledger service", () => {
  it("writes the entry, postings and audit inside one transaction", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    const result = await service.postEntry(balancedInput(), context())

    expect(result.reference).toBe("DEP-SERVICE-1")
    expect(result.createdAt).toBe("2026-11-18T00:00:00.000Z")
    expect(result.effects).toHaveLength(2)

    const entryInsert = findCall(transaction.calls, "insert into finance.journal_entries")
    expect(entryInsert.values?.slice(0, 3)).toEqual(["deposit", "DEP-SERVICE-1", "NGN"])

    const postingInsert = findCall(transaction.calls, "insert into finance.postings")
    expect(postingInsert.values).toHaveLength(12)
    expect(postingInsert.text).toContain("$12")

    const auditInsert = findCall(transaction.calls, "insert into platform.audit_log")
    expect(auditInsert.values?.[4]).toBe("finance.entry_posted")
    expect(auditInsert.values?.[2]).toBe("app")
    expect(auditInsert.values?.[3]).toBe("test")
  })

  it("rejects an unbalanced entry before any ledger insert", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)
    const input = balancedInput()

    await expect(
      service.postEntry(
        {
          ...input,
          postings: [input.postings[0]!, { ...input.postings[1]!, amount: "99.9999" }],
        },
        context(),
      ),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED", statusCode: 400 })

    expect(
      transaction.calls.some((call) => call.text.includes("insert into finance.journal_entries")),
    ).toBe(false)
  })

  it("maps a duplicate reference or key to a conflict", async () => {
    const transaction = new FakeTransaction()
    transaction.failEntryCode = "23505"
    const service = serviceWith(transaction)

    await expect(service.postEntry(balancedInput(), context())).rejects.toMatchObject({
      code: "CONFLICT",
      statusCode: 409,
    })
  })

  it("maps a missing account to a validation failure", async () => {
    const transaction = new FakeTransaction()
    transaction.failEntryCode = "23503"
    const service = serviceWith(transaction)

    await expect(service.postEntry(balancedInput(), context())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
      statusCode: 400,
    })
  })

  it("posts an exact reversal and refuses a partial one", async () => {
    const originalId = randomUUID()
    const originalPostings = [
      {
        accountId: randomUUID(),
        direction: "debit" as const,
        amount: "40.0000",
        currency: "NGN",
      },
      {
        accountId: randomUUID(),
        direction: "credit" as const,
        amount: "40.0000",
        currency: "NGN",
      },
    ]

    const transaction = new FakeTransaction()
    transaction.reversalRows = originalPostings.map((posting) => ({
      entry_currency: "NGN",
      ledger_account_id: posting.accountId,
      direction: posting.direction,
      amount: posting.amount,
      currency: posting.currency,
      activity_id: null,
    }))

    const service = serviceWith(transaction)

    const reversal = {
      kind: "reversal" as const,
      reference: "REV-SERVICE-1",
      currency: "NGN",
      reversesEntryId: originalId,
      idempotencyKey: "idem-reversal-0001",
      postings: originalPostings.map((posting) => ({
        ...posting,
        direction: posting.direction === "debit" ? ("credit" as const) : ("debit" as const),
      })),
    }

    const result = await service.postEntry(reversal, context())
    expect(result.kind).toBe("reversal")

    await expect(
      service.postEntry(
        {
          ...reversal,
          reference: "REV-SERVICE-2",
          postings: reversal.postings.map((posting) => ({
            ...posting,
            amount: "39.9999",
          })),
        },
        context(),
      ),
    ).rejects.toBeInstanceOf(ApiError)
  })

  it("returns not found when the reversal target is invisible or absent", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    await expect(
      service.postEntry(
        {
          kind: "reversal",
          reference: "REV-SERVICE-3",
          currency: "NGN",
          idempotencyKey: "idem-reversal-0003",
          reversesEntryId: randomUUID(),
          postings: [
            {
              accountId: randomUUID(),
              direction: "debit",
              amount: "1.0000",
              currency: "NGN",
            },
            {
              accountId: randomUUID(),
              direction: "credit",
              amount: "1.0000",
              currency: "NGN",
            },
          ],
        },
        context(),
      ),
    ).rejects.toMatchObject({ code: "NOT_FOUND", statusCode: 404 })
  })

  it("replays the stored entry for the same idempotency key and request", async () => {
    const transaction = new FakeTransaction()
    const input = balancedInput()
    transaction.idempotencyClaimed = false
    transaction.idempotencyRow = {
      request_hash: hashLedgerEntry(input),
      response_status: 201,
      response_body: {
        id: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b",
        kind: "deposit",
        reference: "DEP-SERVICE-1",
        currency: "NGN",
        createdAt: "2026-11-18T00:00:00.000Z",
        effects: [],
      },
    }
    const service = serviceWith(transaction)

    const result = await service.postEntry(input, context())

    expect(result.id).toBe("018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b")
    expect(
      transaction.calls.some((call) => call.text.includes("insert into finance.journal_entries")),
    ).toBe(false)
    expect(
      transaction.calls.some((call) => call.text.includes("insert into finance.postings")),
    ).toBe(false)
  })

  it("refuses a reused key with a different request", async () => {
    const transaction = new FakeTransaction()
    transaction.idempotencyClaimed = false
    transaction.idempotencyRow = {
      request_hash: "a".repeat(64),
      response_status: 201,
      response_body: { id: "entry-1" },
    }
    const service = serviceWith(transaction)

    await expect(service.postEntry(balancedInput(), context())).rejects.toMatchObject({
      code: "CONFLICT",
      statusCode: 409,
    })

    expect(
      transaction.calls.some((call) => call.text.includes("insert into finance.journal_entries")),
    ).toBe(false)
  })

  it("requires an idempotency key before it opens a transaction", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)
    const { idempotencyKey: _key, ...withoutKey } = balancedInput()

    await expect(service.postEntry(withoutKey, context())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
      statusCode: 400,
    })

    expect(transaction.calls).toHaveLength(0)
  })
})
