import { randomUUID } from "node:crypto"

import { describe, expect, it } from "vitest"

import type { DatabaseService } from "../server/src/db/database.service"
import type {
  EscrowWriteContext,
  OpenEscrowInput,
} from "../server/src/modules/finance/escrow.service"
import { EscrowService } from "../server/src/modules/finance/escrow.service"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

interface EscrowRow {
  id: string
  ledger_account_id: string
  payer_account_id: string
  activity_id: string
  activity_ref: string
  currency: string
  state: string
  created_at: Date
  updated_at: Date
  resolved_at: Date | null
}

function escrowRow(overrides: Partial<EscrowRow> = {}): EscrowRow {
  return {
    id: randomUUID(),
    ledger_account_id: randomUUID(),
    payer_account_id: randomUUID(),
    activity_id: "services.hire",
    activity_ref: randomUUID(),
    currency: "NGN",
    state: "held",
    created_at: new Date("2026-11-18T00:00:00.000Z"),
    updated_at: new Date("2026-11-18T00:00:00.000Z"),
    resolved_at: null,
    ...overrides,
  }
}

class FakeTransaction {
  readonly calls: Call[] = []
  currentEscrow: EscrowRow | null = escrowRow()
  readonly ledgerAccountId = randomUUID()

  query = async (text: string, values?: readonly unknown[]) => {
    this.calls.push({ text, values })

    if (text.includes("select platform.uuidv7()")) {
      return { rows: [{ id: this.ledgerAccountId }], rowCount: 1 }
    }

    if (text.includes("insert into finance.ledger_accounts")) {
      return { rows: [], rowCount: 1 }
    }

    if (text.startsWith("insert into finance.escrow_accounts")) {
      const row = escrowRow({
        ledger_account_id: this.ledgerAccountId,
        payer_account_id: String(values?.[1]),
        state: "held",
      })
      return { rows: [row], rowCount: 1 }
    }

    if (
      text.includes("from finance.escrow_accounts") &&
      text.includes("for update")
    ) {
      return {
        rows: this.currentEscrow ? [this.currentEscrow] : [],
        rowCount: this.currentEscrow ? 1 : 0,
      }
    }

    if (text.startsWith("update finance.escrow_accounts")) {
      if (!this.currentEscrow) return { rows: [], rowCount: 0 }
      this.currentEscrow = {
        ...this.currentEscrow,
        state: String(values?.[1]),
        updated_at: new Date("2026-11-18T00:05:00.000Z"),
      }
      return { rows: [this.currentEscrow], rowCount: 1 }
    }

    return { rows: [], rowCount: 0 }
  }

  readonly client = { query: this.query }
}

function serviceWith(transaction: FakeTransaction): EscrowService {
  const database = {
    withTransaction: async (
      _options: unknown,
      work: (context: FakeTransaction) => Promise<unknown>,
    ) => work(transaction),
  } as unknown as DatabaseService
  return new EscrowService(database)
}

function context(): EscrowWriteContext {
  return {
    accountId: randomUUID(),
    userId: randomUUID(),
    audience: "app",
    environment: "test",
    correlationId: "corr-escrow-1",
  }
}

function openInput(overrides: Partial<OpenEscrowInput> = {}): OpenEscrowInput {
  return {
    activityId: "services.hire",
    activityRef: randomUUID(),
    currency: "NGN",
    ...overrides,
  }
}

describe("escrow service", () => {
  it("opens a reservation as its ledger account plus held metadata", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)
    const write = context()

    const result = await service.openEscrow(openInput(), write)

    expect(result.state).toBe("held")
    expect(result.payerAccountId).toBe(write.accountId)
    expect(result.ledgerAccountId).toBe(transaction.ledgerAccountId)

    const ledgerCall = transaction.calls.find((call) =>
      call.text.includes("insert into finance.ledger_accounts"),
    )
    expect(ledgerCall?.values).toEqual([
      transaction.ledgerAccountId,
      expect.any(String),
      "NGN",
    ])

    const auditCall = transaction.calls.find((call) =>
      call.text.includes("insert into platform.audit_log"),
    )
    expect(auditCall?.values?.[4]).toBe("finance.escrow_opened")
  })

  it("rejects an escrow on a non-fundable activity, bad reference or bad currency", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)
    const write = context()

    await expect(
      service.openEscrow(openInput({ activityId: "market.sell" }), write),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
    await expect(
      service.openEscrow(openInput({ activityRef: "job-1" }), write),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
    await expect(
      service.openEscrow(openInput({ currency: "naira" }), write),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })

    expect(transaction.calls).toHaveLength(0)
  })

  it("allows opening a dispute and records both states", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    const result = await service.transition(
      { escrowId: transaction.currentEscrow!.id, toState: "disputed" },
      context(),
    )

    expect(result.state).toBe("disputed")
    const auditCall = transaction.calls.find((call) =>
      call.text.includes("insert into platform.audit_log"),
    )
    expect(auditCall?.values?.[4]).toBe("finance.escrow_state_changed")
    expect(JSON.stringify(auditCall?.values)).toContain("held")
    expect(JSON.stringify(auditCall?.values)).toContain("disputed")
  })

  it("refuses release and refund while BD-D03 is open", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    for (const toState of ["released", "refunded", "cancelled"]) {
      await expect(
        service.transition(
          { escrowId: transaction.currentEscrow!.id, toState },
          context(),
        ),
      ).rejects.toMatchObject({ code: "CONFLICT", statusCode: 409 })
    }

    expect(
      transaction.calls.some((call) =>
        call.text.startsWith("update finance.escrow_accounts"),
      ),
    ).toBe(false)
  })

  it("rejects an undefined transition", async () => {
    const transaction = new FakeTransaction()
    transaction.currentEscrow = escrowRow({ state: "disputed" })
    const service = serviceWith(transaction)

    await expect(
      service.transition(
        { escrowId: transaction.currentEscrow.id, toState: "held" },
        context(),
      ),
    ).rejects.toMatchObject({ code: "VALIDATION_FAILED" })
  })

  it("returns not found for an escrow the caller cannot see", async () => {
    const transaction = new FakeTransaction()
    transaction.currentEscrow = null
    const service = serviceWith(transaction)

    await expect(
      service.transition(
        { escrowId: randomUUID(), toState: "disputed" },
        context(),
      ),
    ).rejects.toMatchObject({ code: "NOT_FOUND", statusCode: 404 })
  })
})
