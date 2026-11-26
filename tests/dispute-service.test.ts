import { randomUUID } from "node:crypto"

import { describe, expect, it } from "vitest"

import type { DatabaseService } from "../server/src/db/database.service"
import type { EvidenceService } from "../server/src/modules/admin/evidence.service"
import type { OpenDisputeInput } from "../server/src/modules/admin/dispute.service"
import { DisputeService } from "../server/src/modules/admin/dispute.service"

interface Call {
  readonly text: string
  readonly values?: readonly unknown[]
}

interface Row {
  id: string
  reference: string
  case_id: string
  case_reference: string
  case_status: string
  escrow_id: string | null
  activity_id: string
  activity_ref: string
  opened_by_account_id: string
  respondent_account_id: string | null
  currency: string
  claimed_amount: string
  status: string
  created_at: Date
  updated_at: Date
}

function row(overrides: Partial<Row> = {}): Row {
  return {
    id: randomUUID(),
    reference: "DSP-ABC123456",
    case_id: randomUUID(),
    case_reference: "CASE-ABC123456",
    case_status: "OPEN",
    escrow_id: null,
    activity_id: "market.buy",
    activity_ref: randomUUID(),
    opened_by_account_id: randomUUID(),
    respondent_account_id: randomUUID(),
    currency: "NGN",
    claimed_amount: "500.0000",
    status: "OPENED",
    created_at: new Date("2026-11-19T00:00:00.000Z"),
    updated_at: new Date("2026-11-19T00:00:00.000Z"),
    ...overrides,
  }
}

class FakeTransaction {
  readonly calls: Call[] = []
  resultRow: Row = row()
  failCode: string | undefined
  failMessage: string | undefined

  query = async (text: string, values?: readonly unknown[]) => {
    this.calls.push({ text, values })

    if (text.includes("insert into platform.audit_log")) {
      return { rows: [], rowCount: 1 }
    }

    if (this.failCode) {
      const error = new Error(this.failMessage ?? "admin function failed") as Error & {
        code?: string
      }
      error.code = this.failCode
      throw error
    }

    if (
      text.includes("admin.open_dispute") ||
      text.includes("admin.dispute_view") ||
      text.includes("admin.list_disputes") ||
      text.includes("admin.set_dispute_status")
    ) {
      return { rows: [this.resultRow], rowCount: 1 }
    }

    return { rows: [], rowCount: 1 }
  }

  readonly client = { query: this.query }
}

const evidenceList = async () => [
  {
    id: randomUUID(),
    fileName: "damage.pdf",
    mimeType: "application/pdf",
    sizeBytes: 1024,
    sha256: "a".repeat(64),
    classification: "sensitive",
    status: "active",
    supersedesId: null,
    uploadedByName: "Reviewer",
    uploadedByEmail: "reviewer@example.test",
    uploadedAt: "2026-11-19T00:00:00.000Z",
  },
]

function serviceWith(transaction: FakeTransaction): DisputeService {
  const database = {
    withTransaction: async (
      _options: unknown,
      work: (context: FakeTransaction) => Promise<unknown>,
    ) => work(transaction),
  } as unknown as DatabaseService
  const evidence = { list: evidenceList } as unknown as EvidenceService
  return new DisputeService(database, evidence)
}

const requestContext = {
  audience: "control" as const,
  environment: "test" as const,
  correlationId: "corr-dispute-1",
}

function openInput(overrides: Partial<OpenDisputeInput> = {}): OpenDisputeInput {
  return {
    accountId: randomUUID(),
    userId: randomUUID(),
    caseId: randomUUID(),
    activityId: "market.buy",
    activityRef: randomUUID(),
    openedByAccountId: randomUUID(),
    respondentAccountId: null,
    currency: "NGN",
    claimedAmount: "500",
    reason: "buyer reports a damaged item",
    context: requestContext,
    ...overrides,
  }
}

describe("dispute service", () => {
  it("opens a typed dispute and records the reason in the audit trail", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)
    const input = openInput()

    const result = await service.open(input)

    expect(result.reference).toMatch(/^DSP-/)
    expect(result.claimedAmount).toBe("500.0000")
    expect(result.status).toBe("OPENED")
    expect(result.caseReference).toBe("CASE-ABC123456")

    const call = transaction.calls.find((entry) => entry.text.includes("admin.open_dispute"))
    expect(call?.values?.[1]).toBe(input.caseId)
    expect(call?.values?.[9]).toBe(input.reason)

    const audit = transaction.calls.find((entry) =>
      entry.text.includes("insert into platform.audit_log"),
    )
    expect(audit?.values?.[4]).toBe("admin.dispute_opened")
  })

  it("lists and reads disputes through the scoped functions", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)

    const list = await service.list({
      accountId: randomUUID(),
      userId: randomUUID(),
      caseId: randomUUID(),
    })
    const one = await service.get({
      accountId: randomUUID(),
      userId: randomUUID(),
      disputeId: randomUUID(),
    })

    expect(list).toHaveLength(1)
    expect(one.status).toBe("OPENED")
  })

  it("applies a procedural status change", async () => {
    const transaction = new FakeTransaction()
    transaction.resultRow = row({ status: "UNDER_REVIEW" })
    const service = serviceWith(transaction)

    const result = await service.setStatus({
      accountId: randomUUID(),
      userId: randomUUID(),
      disputeId: randomUUID(),
      status: "UNDER_REVIEW",
      reason: "review started",
      context: requestContext,
    })

    expect(result.status).toBe("UNDER_REVIEW")
    const audit = transaction.calls.find((entry) =>
      entry.text.includes("insert into platform.audit_log"),
    )
    expect(audit?.values?.[4]).toBe("admin.dispute_status_changed")
  })

  it("maps a denied function to a forbidden error", async () => {
    const transaction = new FakeTransaction()
    transaction.failCode = "42501"
    const service = serviceWith(transaction)

    await expect(
      service.list({ accountId: randomUUID(), userId: randomUUID() }),
    ).rejects.toMatchObject({ code: "FORBIDDEN", statusCode: 403 })
  })

  it("maps a missing dispute to not found and a duplicate case to a conflict", async () => {
    const missing = new FakeTransaction()
    missing.failCode = "P0002"
    await expect(
      serviceWith(missing).get({
        accountId: randomUUID(),
        userId: randomUUID(),
        disputeId: randomUUID(),
      }),
    ).rejects.toMatchObject({ code: "NOT_FOUND", statusCode: 404 })

    const duplicate = new FakeTransaction()
    duplicate.failCode = "23505"
    await expect(serviceWith(duplicate).open(openInput())).rejects.toMatchObject({
      code: "CONFLICT",
      statusCode: 409,
    })
  })

  it("reads evidence metadata for the dispute's case", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)
    const input = {
      accountId: randomUUID(),
      userId: randomUUID(),
      disputeId: randomUUID(),
    }

    const evidence = await service.listEvidence(input)

    expect(evidence).toHaveLength(1)
    expect(evidence[0]?.fileName).toBe("damage.pdf")
  })

  it("records dispute evidence access in the audit trail", async () => {
    const transaction = new FakeTransaction()
    const service = serviceWith(transaction)
    const evidenceId = randomUUID()

    await service.recordEvidenceAccess({
      accountId: randomUUID(),
      userId: randomUUID(),
      disputeId: randomUUID(),
      evidenceId,
      purpose: "review",
      context: requestContext,
    })

    const access = transaction.calls.find((entry) =>
      entry.text.includes("admin.record_dispute_evidence_access"),
    )
    expect(access?.values?.[2]).toBe(evidenceId)
    const audit = transaction.calls.find((entry) =>
      entry.text.includes("insert into platform.audit_log"),
    )
    expect(audit?.values?.[4]).toBe("admin.dispute_evidence_accessed")
    expect(audit?.values?.[6]).toBe(evidenceId)
  })
})
