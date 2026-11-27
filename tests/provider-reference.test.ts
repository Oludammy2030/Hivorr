import { randomUUID } from "node:crypto"

import { describe, expect, it } from "vitest"

import type { DatabaseService } from "../server/src/db/database.service"
import type {
  ProviderReferenceContext,
  RecordProviderReferenceInput,
} from "../server/src/modules/finance/provider-reference.service"
import { ProviderReferenceService } from "../server/src/modules/finance/provider-reference.service"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

interface Row {
  id: string
  account_id: string
  provider: string
  provider_reference: string
  direction: string
  status: string
  amount: string
  currency: string
  journal_entry_id: string | null
  created_at: Date
  updated_at: Date
}

function row(overrides: Partial<Row> = {}): Row {
  return {
    id: randomUUID(),
    account_id: randomUUID(),
    provider: "vfd",
    provider_reference: "VFD-1",
    direction: "deposit",
    status: "received",
    amount: "100.0000",
    currency: "NGN",
    journal_entry_id: null,
    created_at: new Date("2026-11-18T00:00:00.000Z"),
    updated_at: new Date("2026-11-18T00:00:00.000Z"),
    ...overrides,
  }
}

class FakeTransaction {
  readonly calls: Call[] = []
  insertRow: Row | null = row()
  existingRow: Row | null = null
  entryCurrency: string | null = "NGN"

  query = async (text: string, values?: readonly unknown[]) => {
    this.calls.push({ text, values })

    if (text.includes("select platform.uuidv7()")) {
      return { rows: [{ id: randomUUID() }], rowCount: 1 }
    }
    if (text.startsWith("insert into finance.provider_references")) {
      return {
        rows: this.insertRow ? [this.insertRow] : [],
        rowCount: this.insertRow ? 1 : 0,
      }
    }
    if (text.includes("from finance.provider_references")) {
      return {
        rows: this.existingRow ? [this.existingRow] : [],
        rowCount: this.existingRow ? 1 : 0,
      }
    }
    if (text.includes("select currency from finance.journal_entries")) {
      return {
        rows: this.entryCurrency ? [{ currency: this.entryCurrency }] : [],
        rowCount: this.entryCurrency ? 1 : 0,
      }
    }
    if (text.startsWith("update finance.provider_references")) {
      if (!this.existingRow) return { rows: [], rowCount: 0 }
      this.existingRow = {
        ...this.existingRow,
        status: "posted",
        journal_entry_id: String(values?.[2]),
        updated_at: new Date("2026-11-18T00:05:00.000Z"),
      }
      return { rows: [this.existingRow], rowCount: 1 }
    }

    return { rows: [], rowCount: 0 }
  }

  readonly client = { query: this.query }
}

function serviceWith(transaction: FakeTransaction): ProviderReferenceService {
  const database = {
    withTransaction: async (
      _options: unknown,
      work: (context: FakeTransaction) => Promise<unknown>,
    ) => work(transaction),
  } as unknown as DatabaseService
  return new ProviderReferenceService(database)
}

function context(): ProviderReferenceContext {
  return {
    accountId: randomUUID(),
    userId: randomUUID(),
    audience: "app",
    environment: "test",
    correlationId: "corr-provider-1",
  }
}

function input(
  overrides: Partial<RecordProviderReferenceInput> = {},
): RecordProviderReferenceInput {
  return {
    provider: "vfd",
    providerReference: "VFD-1",
    direction: "deposit",
    amount: "100",
    currency: "NGN",
    ...overrides,
  }
}

describe("provider reference model", () => {
  it("records a new provider reference with an audit record", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    const result = await service.record(input(), context())

    expect(result.replayed).toBe(false)
    expect(result.reference.amount).toBe("100.0000")
    expect(result.reference.status).toBe("received")
    const insert = transaction.calls.find((call) =>
      call.text.includes("insert into finance.provider_references"),
    )
    expect(insert?.values?.[5]).toBe("100.0000")
    const audit = transaction.calls.find((call) =>
      call.text.includes("insert into platform.audit_log"),
    )
    expect(audit?.values?.[4]).toBe("finance.provider_reference_recorded")
  })

  it("replays the same provider event", async () => {
    const transaction = new FakeTransaction()
    const write = context()
    transaction.insertRow = null
    transaction.existingRow = row({ account_id: write.accountId })
    const service = serviceWith(transaction)

    const result = await service.record(input(), write)

    expect(result.replayed).toBe(true)
    expect(result.reference.providerReference).toBe("VFD-1")
  })

  it("refuses a different movement under the same provider reference", async () => {
    const transaction = new FakeTransaction()
    const write = context()
    transaction.insertRow = null
    transaction.existingRow = row({
      account_id: write.accountId,
      amount: "99.0000",
    })
    const service = serviceWith(transaction)

    await expect(service.record(input(), write)).rejects.toMatchObject({
      code: "CONFLICT",
      statusCode: 409,
    })
  })

  it("refuses an invalid provider, amount or currency before any write", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    await expect(service.record(input({ provider: "VFD" }), context())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    await expect(service.record(input({ amount: "0" }), context())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    await expect(service.record(input({ amount: "1.00001" }), context())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    await expect(service.record(input({ currency: "naira" }), context())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })

    expect(transaction.calls).toHaveLength(0)
  })

  it("links a provider reference to its journal entry", async () => {
    const transaction = new FakeTransaction()
    transaction.existingRow = row()
    const entryId = randomUUID()
    const service = serviceWith(transaction)

    const result = await service.linkEntry(
      {
        provider: "vfd",
        providerReference: "VFD-1",
        journalEntryId: entryId,
      },
      context(),
    )

    expect(result.status).toBe("posted")
    expect(result.journalEntryId).toBe(entryId)
    const audit = transaction.calls.find((call) =>
      call.text.includes("insert into platform.audit_log"),
    )
    expect(audit?.values?.[4]).toBe("finance.provider_reference_linked")
  })

  it("treats a repeated link to the same entry as a no-op", async () => {
    const transaction = new FakeTransaction()
    const entryId = randomUUID()
    transaction.existingRow = row({
      status: "posted",
      journal_entry_id: entryId,
    })
    const service = serviceWith(transaction)

    const result = await service.linkEntry(
      {
        provider: "vfd",
        providerReference: "VFD-1",
        journalEntryId: entryId,
      },
      context(),
    )

    expect(result.journalEntryId).toBe(entryId)
    expect(
      transaction.calls.some((call) => call.text.startsWith("update finance.provider_references")),
    ).toBe(false)
  })

  it("refuses a second link or a currency mismatch", async () => {
    const transaction = new FakeTransaction()
    transaction.existingRow = row({
      status: "posted",
      journal_entry_id: randomUUID(),
    })
    const service = serviceWith(transaction)

    await expect(
      service.linkEntry(
        {
          provider: "vfd",
          providerReference: "VFD-1",
          journalEntryId: randomUUID(),
        },
        context(),
      ),
    ).rejects.toMatchObject({ code: "CONFLICT" })

    const second = new FakeTransaction()
    second.existingRow = row()
    second.entryCurrency = "USD"
    await expect(
      serviceWith(second).linkEntry(
        {
          provider: "vfd",
          providerReference: "VFD-1",
          journalEntryId: randomUUID(),
        },
        context(),
      ),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
  })

  it("returns not found when the reference is invisible", async () => {
    const transaction = new FakeTransaction()
    transaction.existingRow = null
    const service = serviceWith(transaction)

    await expect(
      service.linkEntry(
        {
          provider: "vfd",
          providerReference: "VFD-2",
          journalEntryId: randomUUID(),
        },
        context(),
      ),
    ).rejects.toMatchObject({ code: "NOT_FOUND", statusCode: 404 })
  })
})
