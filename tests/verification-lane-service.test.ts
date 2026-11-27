import { describe, expect, it } from "vitest"

import type { DatabaseService } from "../server/src/db/database.service"
import { VerificationLaneService } from "../server/src/modules/profile/verification.service"

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111"
const USER_ID = "22222222-2222-4222-8222-222222222222"
const CASE_ID = "33333333-3333-4333-8333-333333333333"
const SUBMISSION_ID = "44444444-4444-4444-8444-444444444444"

const context = {
  audience: "app" as const,
  environment: "staging" as const,
  correlationId: "corr-lane",
}

interface QueryCall {
  readonly text: string
  readonly values?: readonly unknown[]
}

interface Options {
  readonly caseState?: string | null
  readonly openSubmission?: { id: string; state: string } | null
  readonly evidence?: number
  readonly readyEvidence?: number
  readonly claim?: "claimed" | "replay" | "conflict"
  readonly storedHash?: string
  readonly storedBody?: unknown
}

function harness(options: Options = {}) {
  const queries: QueryCall[] = []
  const audits: unknown[][] = []
  const idempotencyWrites: unknown[][] = []
  const updates: { table: string; values?: readonly unknown[] }[] = []

  const transaction = {
    client: {
      async query(text: string, values?: readonly unknown[]) {
        if (text.includes("platform.audit_log")) audits.push(values ?? [])
        if (text.includes("insert into platform.idempotency_keys")) {
          return { rows: [], rowCount: options.claim === "claimed" ? 1 : 0 }
        }
        if (text.includes("from platform.idempotency_keys")) {
          return {
            rows: [
              {
                request_hash: options.storedHash ?? "",
                response_status: 200,
                response_body: options.storedBody ?? null,
              },
            ],
          }
        }
        if (text.includes("update platform.idempotency_keys")) {
          idempotencyWrites.push(values ?? [])
        }
        return { rows: [], rowCount: 1 }
      },
    },
    async query(text: string, values?: readonly unknown[]) {
      queries.push({ text, values })

      if (text.includes("insert into profile.verification_cases")) {
        return { rows: [], rowCount: 0 }
      }
      if (text.includes("from profile.verification_cases") && text.includes("for update")) {
        const state = options.caseState ?? null
        return {
          rows: state
            ? [
                {
                  id: CASE_ID,
                  lane: "identity",
                  state,
                  reason_code: null,
                  state_changed_at: new Date("2026-11-27T00:00:00.000Z"),
                },
              ]
            : [],
        }
      }
      if (
        text.includes("from profile.verification_cases") &&
        text.includes("select id, lane, state, reason_code")
      ) {
        const state = options.caseState ?? null
        return {
          rows: state
            ? [
                {
                  id: CASE_ID,
                  lane: "identity",
                  state,
                  reason_code: null,
                  state_changed_at: "2026-11-27T00:00:00.000Z",
                },
              ]
            : [],
        }
      }
      if (text.includes("insert into profile.verification_submissions")) {
        return { rows: [], rowCount: 1 }
      }
      if (text.includes("from profile.verification_submissions") && text.includes("for update")) {
        return { rows: options.openSubmission ? [options.openSubmission] : [] }
      }
      if (text.includes("from profile.verification_submissions") && text.includes("limit 1")) {
        return { rows: options.openSubmission ? [options.openSubmission] : [] }
      }
      if (text.includes("from profile.verification_evidence e")) {
        return { rows: [{ count: options.evidence ?? 0 }] }
      }
      if (text.includes("from profile.verification_evidence")) {
        const total = options.evidence ?? 0
        return {
          rows: [{ total, ready: options.readyEvidence ?? total }],
        }
      }
      if (text.includes("update profile.verification_submissions")) {
        updates.push({ table: "submissions", values })
        return { rows: [], rowCount: 1 }
      }
      if (text.includes("update profile.verification_cases")) {
        updates.push({ table: "cases", values })
        return { rows: [], rowCount: 1 }
      }
      return { rows: [], rowCount: 0 }
    },
  }

  const database = {
    withTransaction: async (
      _options: unknown,
      work: (value: typeof transaction) => Promise<unknown>,
    ) => work(transaction),
  } as unknown as DatabaseService

  return {
    service: new VerificationLaneService(database),
    queries,
    audits,
    idempotencyWrites,
    updates,
  }
}

function input(overrides: Record<string, unknown> = {}) {
  return {
    accountId: ACCOUNT_ID,
    userId: USER_ID,
    lane: "identity",
    context,
    ...overrides,
  }
}

describe("verification lane service â€” start", () => {
  it("opens a draft attempt and audits the change", async () => {
    const { service, updates, audits } = harness({ caseState: "NOT_STARTED" })

    const view = await service.start(input())

    expect(view.state).toBe("DRAFT")
    expect(view.hasActiveSubmission).toBe(true)
    expect(updates.map((entry) => entry.table)).toEqual(["cases"])
    expect(audits).toHaveLength(1)
    expect(audits[0]).toContain("profile.verification_started")
  })

  it("restarts a rejected lane", async () => {
    const { service, audits } = harness({ caseState: "REJECTED" })

    const view = await service.start(input())

    expect(view.state).toBe("DRAFT")
    expect(audits).toHaveLength(1)
  })

  it("refuses to reopen an approved lane", async () => {
    const { service, audits } = harness({ caseState: "APPROVED" })

    await expect(service.start(input())).rejects.toMatchObject({
      code: "CONFLICT",
    })
    expect(audits).toHaveLength(0)
  })

  it("refuses a second open attempt", async () => {
    const { service } = harness({
      caseState: "DRAFT",
      openSubmission: { id: SUBMISSION_ID, state: "DRAFT" },
    })

    await expect(service.start(input())).rejects.toMatchObject({
      code: "CONFLICT",
    })
  })

  it("refuses an unknown lane before touching the database", async () => {
    const { service, queries } = harness()

    await expect(service.start(input({ lane: "address" }))).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    expect(queries).toHaveLength(0)
  })
})

describe("verification lane service â€” submit", () => {
  it("requires at least one evidence reference", async () => {
    const { service, audits } = harness({
      openSubmission: { id: SUBMISSION_ID, state: "DRAFT" },
      evidence: 0,
    })

    await expect(service.submit(input())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
    expect(audits).toHaveLength(0)
  })

  it("refuses a submission with a failed scan", async () => {
    const { service } = harness({
      openSubmission: { id: SUBMISSION_ID, state: "DRAFT" },
      evidence: 2,
      readyEvidence: 1,
    })

    await expect(service.submit(input())).rejects.toMatchObject({
      code: "VALIDATION_FAILED",
    })
  })

  it("submits a draft with clean evidence", async () => {
    const { service, updates, audits } = harness({
      openSubmission: { id: SUBMISSION_ID, state: "DRAFT" },
      evidence: 2,
    })

    const view = await service.submit(input())

    expect(view.state).toBe("SUBMITTED")
    expect(updates.map((entry) => entry.table)).toEqual(["submissions", "cases"])
    expect(audits[0]).toContain("profile.verification_submitted")
  })

  it("refuses to submit without an open attempt", async () => {
    const { service } = harness({ openSubmission: null })

    await expect(service.submit(input())).rejects.toMatchObject({
      code: "NOT_FOUND",
    })
  })

  it("refuses to submit an already submitted attempt", async () => {
    const { service } = harness({
      openSubmission: { id: SUBMISSION_ID, state: "SUBMITTED" },
      evidence: 1,
    })

    await expect(service.submit(input())).rejects.toMatchObject({
      code: "CONFLICT",
    })
  })
})

describe("verification lane service â€” withdraw", () => {
  it("returns a submitted attempt to draft", async () => {
    const { service, updates, audits } = harness({
      openSubmission: { id: SUBMISSION_ID, state: "SUBMITTED" },
    })

    const view = await service.withdraw(input())

    expect(view.state).toBe("DRAFT")
    expect(updates.map((entry) => entry.table)).toEqual(["submissions", "cases"])
    expect(audits[0]).toContain("profile.verification_withdrawn")
  })

  it("refuses to withdraw while under review", async () => {
    const { service, updates } = harness({
      openSubmission: { id: SUBMISSION_ID, state: "UNDER_REVIEW" },
    })

    await expect(service.withdraw(input())).rejects.toMatchObject({
      code: "CONFLICT",
    })
    expect(updates).toHaveLength(0)
  })
})

describe("verification lane service â€” status", () => {
  it("reports a lane that was never started", async () => {
    const { service } = harness({ caseState: null })

    const view = await service.status(input())

    expect(view).toMatchObject({
      lane: "identity",
      state: "NOT_STARTED",
      hasActiveSubmission: false,
      evidenceCount: 0,
    })
  })

  it("reports the case, its attempt and its evidence", async () => {
    const { service } = harness({
      caseState: "SUBMITTED",
      openSubmission: { id: SUBMISSION_ID, state: "SUBMITTED" },
      evidence: 3,
    })

    const view = await service.status(input())

    expect(view).toMatchObject({
      state: "SUBMITTED",
      hasActiveSubmission: true,
      evidenceCount: 3,
    })
  })
})

describe("verification lane service — submit idempotency", () => {
  it("settles the key and records the response on a first submit", async () => {
    const { service, idempotencyWrites } = harness({
      openSubmission: { id: SUBMISSION_ID, state: "DRAFT" },
      evidence: 2,
      claim: "claimed",
    })

    const view = await service.submit({
      ...input(),
      idempotencyKey: "submit-key-0001",
      requestHash: "hash-1",
    })

    expect(view.state).toBe("SUBMITTED")
    expect(idempotencyWrites).toHaveLength(1)
    expect(idempotencyWrites[0]?.[1]).toBe(200)
  })

  it("replays the stored response without touching the lane", async () => {
    const stored = {
      lane: "identity",
      state: "SUBMITTED",
      reasonCode: null,
      hasActiveSubmission: true,
      evidenceCount: 1,
      stateChangedAt: "2026-11-27T00:00:00.000Z",
    }
    const { service, updates, audits } = harness({
      claim: "replay",
      storedHash: "hash-1",
      storedBody: stored,
    })

    const view = await service.submit({
      ...input(),
      idempotencyKey: "submit-key-0002",
      requestHash: "hash-1",
    })

    expect(view).toEqual(stored)
    expect(updates).toHaveLength(0)
    expect(audits).toHaveLength(0)
  })

  it("refuses a reused key with a different request", async () => {
    const { service } = harness({ claim: "conflict", storedHash: "other" })

    await expect(
      service.submit({
        ...input(),
        idempotencyKey: "submit-key-0003",
        requestHash: "hash-1",
      }),
    ).rejects.toMatchObject({ code: "CONFLICT" })
  })
})
