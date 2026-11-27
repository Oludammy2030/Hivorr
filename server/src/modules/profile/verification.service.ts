import { Inject, Injectable } from "@nestjs/common"
import { isVerificationLane, type VerificationLane, type VerificationState } from "@hivorr/shared"

import { ApiError } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import type { TransactionContext } from "../../db/transaction"
import { appendAudit, claimIdempotency, completeIdempotency } from "../platform"
import {
  canApplyEvent,
  isOpenSubmission,
  isReopenable,
  targetStateFor,
} from "./domain/verification"
import type { ActivityContext } from "./profile.service"

/**
 * Submission domain for the verification lanes (EP-02-011).
 *
 * Subject actions only: start an attempt, submit it, withdraw it. The reviewer
 * path (begin review, approve, reject) is EP-02-015's.
 *
 * Every state change is validated three times: here against the domain table,
 * by the database transition trigger, and by RLS on the row's account. A lane
 * approval never touches another lane because nothing here updates a second
 * case.
 */

export interface LaneView {
  readonly lane: VerificationLane
  readonly state: VerificationState
  readonly reasonCode: string | null
  readonly hasActiveSubmission: boolean
  readonly evidenceCount: number
  readonly stateChangedAt: string
}

export interface LaneInput {
  readonly accountId: string
  readonly userId: string
  readonly lane: string
  readonly context: ActivityContext
}

/** The kyc lane must ask for a tier; every other lane must not. */
export interface StartInput extends LaneInput {
  readonly requestedTier?: string | undefined
}

/** A submit may be retried by a client; the key makes the replay safe. */
export interface SubmitInput extends LaneInput {
  readonly idempotencyKey?: string | undefined
  readonly requestHash?: string | undefined
}

export const VERIFICATION_SUBMIT_SCOPE = "profile.verification.submit"
const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1_000

interface CaseRow {
  id: string
  lane: string
  state: string
  reason_code: string | null
  state_changed_at: string | Date
}

interface SubmissionRow {
  id: string
  state: string
}

function toIso(value: string | Date): string {
  return value instanceof Date ? value.toISOString() : value
}

function assertLane(value: string): VerificationLane {
  if (!isVerificationLane(value)) {
    throw new ApiError("VALIDATION_FAILED", "The verification lane is not valid.", 400)
  }
  return value
}

@Injectable()
export class VerificationLaneService {
  constructor(@Inject(DatabaseService) private readonly database: DatabaseService) {}

  /** Read the lane's case, its active attempt and the evidence count. */
  async status(input: LaneInput): Promise<LaneView> {
    const lane = assertLane(input.lane)

    return this.database.withTransaction(
      { identity: { accountId: input.accountId, userId: input.userId } },
      async (transaction) => {
        const result = await transaction.query<CaseRow>(
          `select id, lane, state, reason_code, state_changed_at
             from profile.verification_cases
            where account_id = $1 and lane = $2`,
          [input.accountId, lane],
        )
        const row = result.rows[0]
        if (!row) {
          return {
            lane,
            state: "NOT_STARTED" as const,
            reasonCode: null,
            hasActiveSubmission: false,
            evidenceCount: 0,
            stateChangedAt: new Date(0).toISOString(),
          }
        }

        const submission = await transaction.query<{ id: string; state: string }>(
          `select id, state from profile.verification_submissions
            where account_id = $1 and lane = $2
              and state in ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW')
            limit 1`,
          [input.accountId, lane],
        )
        const evidence = await transaction.query<{ count: number }>(
          `select count(*)::int as count
             from profile.verification_evidence e
             join profile.verification_submissions s on s.id = e.submission_id
            where s.account_id = $1 and s.lane = $2`,
          [input.accountId, lane],
        )

        return {
          lane,
          state: row.state as VerificationState,
          reasonCode: row.reason_code,
          hasActiveSubmission: Boolean(submission.rows[0]),
          evidenceCount: evidence.rows[0]?.count ?? 0,
          stateChangedAt: toIso(row.state_changed_at),
        }
      },
    )
  }

  /**
   * Start, or restart, an attempt. Refused while another attempt is open and
   * while the lane is approved: an approval is never silently reopened.
   */
  async start(input: StartInput): Promise<LaneView> {
    const lane = assertLane(input.lane)
    const requestedTier = input.requestedTier?.trim() || undefined
    if (lane === "kyc") {
      if (!requestedTier || !["tier_1", "tier_2", "tier_3"].includes(requestedTier)) {
        throw new ApiError(
          "VALIDATION_FAILED",
          "The kyc lane must name the tier being requested.",
          400,
        )
      }
    } else if (requestedTier !== undefined) {
      throw new ApiError("VALIDATION_FAILED", "Only the kyc lane requests a tier.", 400)
    }

    return this.database.withTransaction(
      { identity: { accountId: input.accountId, userId: input.userId } },
      async (transaction) => {
        await transaction.query(
          `insert into profile.verification_cases (account_id, lane)
           values ($1, $2)
           on conflict (account_id, lane) do nothing`,
          [input.accountId, lane],
        )

        const current = await transaction.query<CaseRow>(
          `select id, lane, state, reason_code, state_changed_at
             from profile.verification_cases
            where account_id = $1 and lane = $2
            for update`,
          [input.accountId, lane],
        )
        const row = current.rows[0]
        if (!row) {
          throw new ApiError("INTERNAL_ERROR", "The verification case could not be created.", 500)
        }

        const from = row.state as VerificationState
        if (from === "APPROVED") {
          throw new ApiError("CONFLICT", "This lane is approved and cannot be reopened.", 409)
        }
        if (!canApplyEvent("start", from)) {
          throw new ApiError(
            "CONFLICT",
            isReopenable(from) || from === "NOT_STARTED"
              ? "This lane cannot be started from its current state."
              : "An attempt is already open for this lane.",
            409,
          )
        }

        const open = await transaction.query<{ id: string; state: string }>(
          `select id, state from profile.verification_submissions
            where account_id = $1 and lane = $2
              and state in ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW')
            limit 1`,
          [input.accountId, lane],
        )
        if (open.rows[0]) {
          throw new ApiError("CONFLICT", "An attempt is already open for this lane.", 409)
        }

        const to = targetStateFor("start")
        await transaction.query(
          `update profile.verification_cases
              set state = $3, reason_code = null, state_changed_at = now(),
                  updated_at = now()
            where account_id = $1 and lane = $2`,
          [input.accountId, lane, to],
        )
        await transaction.query(
          `insert into profile.verification_submissions
             (case_id, account_id, lane, state, requested_kyc_tier)
           values ($1, $2, $3, 'DRAFT', $4)`,
          [row.id, input.accountId, lane, requestedTier ?? null],
        )

        await this.audit(transaction, input, "profile.verification_started", {
          lane,
          from,
          to,
        })

        return this.viewFromState(lane, to, null, true, 0)
      },
    )
  }

  /** Submit a draft attempt. At least one usable evidence reference is required. */
  async submit(input: SubmitInput): Promise<LaneView> {
    const lane = assertLane(input.lane)
    const idempotencyKey = input.idempotencyKey
      ? `${VERIFICATION_SUBMIT_SCOPE}:${input.accountId}:${input.idempotencyKey}`
      : undefined

    return this.database.withTransaction(
      { identity: { accountId: input.accountId, userId: input.userId } },
      async (transaction) => {
        if (idempotencyKey) {
          const claim = await claimIdempotency(transaction.client, {
            key: idempotencyKey,
            scope: VERIFICATION_SUBMIT_SCOPE,
            requestHash: input.requestHash ?? "",
            expiresAt: new Date(Date.now() + IDEMPOTENCY_TTL_MS).toISOString(),
          })
          if (claim.status === "conflict") {
            throw new ApiError(
              "CONFLICT",
              "That idempotency key was used for a different request.",
              409,
            )
          }
          if (claim.status === "replay") {
            return claim.responseBody as LaneView
          }
        }

        const submission = await this.openSubmission(transaction, input.accountId, lane)
        const from = submission.state as VerificationState
        if (from !== "DRAFT" || !canApplyEvent("submit", from)) {
          throw new ApiError("CONFLICT", "Only a draft attempt can be submitted.", 409)
        }

        const evidence = await transaction.query<{
          total: number
          ready: number
        }>(
          `select count(*)::int as total,
                  count(*) filter (where scan_state = 'CLEAN')::int as ready
             from profile.verification_evidence
            where submission_id = $1`,
          [submission.id],
        )
        const total = evidence.rows[0]?.total ?? 0
        const ready = evidence.rows[0]?.ready ?? 0
        if (total === 0) {
          throw new ApiError(
            "VALIDATION_FAILED",
            "Attach at least one evidence file before submitting.",
            400,
          )
        }
        // Only a clean file is usable: a pending or failed scan must not reach a
        // reviewer, and this is the rule that keeps it out.
        if (ready !== total) {
          throw new ApiError(
            "VALIDATION_FAILED",
            "Every evidence file must finish scanning clean before submitting.",
            400,
          )
        }

        const to = targetStateFor("submit")
        await transaction.query(
          `update profile.verification_submissions
              set state = $2, submitted_at = now(), updated_at = now()
            where id = $1`,
          [submission.id, to],
        )
        await transaction.query(
          `update profile.verification_cases
              set state = $3, reason_code = null, state_changed_at = now(),
                  updated_at = now()
            where account_id = $1 and lane = $2`,
          [input.accountId, lane, to],
        )

        await this.audit(transaction, input, "profile.verification_submitted", {
          lane,
          from,
          to,
          evidence: total,
        })

        await transaction.query("select * from admin.open_verification_review($1, $2, $3, $4)", [
          input.userId,
          input.accountId,
          submission.id,
          `${lane} verification`,
        ])

        const view = this.viewFromState(lane, to, null, true, total)
        if (idempotencyKey) {
          await completeIdempotency(transaction.client, {
            key: idempotencyKey,
            responseStatus: 200,
            responseBody: view,
          })
        }
        return view
      },
    )
  }

  /** Withdraw a submitted attempt, returning it to draft. Not while under review. */
  async withdraw(input: LaneInput): Promise<LaneView> {
    const lane = assertLane(input.lane)

    return this.database.withTransaction(
      { identity: { accountId: input.accountId, userId: input.userId } },
      async (transaction) => {
        const submission = await this.openSubmission(transaction, input.accountId, lane)
        const from = submission.state as VerificationState
        if (from !== "SUBMITTED" || !canApplyEvent("withdraw", from)) {
          throw new ApiError(
            "CONFLICT",
            from === "UNDER_REVIEW"
              ? "A submission under review cannot be withdrawn."
              : "Only a submitted attempt can be withdrawn.",
            409,
          )
        }

        const to = targetStateFor("withdraw")
        await transaction.query(
          `update profile.verification_submissions
              set state = $2, updated_at = now()
            where id = $1`,
          [submission.id, to],
        )
        await transaction.query(
          `update profile.verification_cases
              set state = $3, state_changed_at = now(), updated_at = now()
            where account_id = $1 and lane = $2`,
          [input.accountId, lane, to],
        )

        await this.audit(transaction, input, "profile.verification_withdrawn", {
          lane,
          from,
          to,
        })

        return this.viewFromState(lane, to, null, true, 0)
      },
    )
  }

  private async openSubmission(
    transaction: TransactionContext,
    accountId: string,
    lane: VerificationLane,
  ): Promise<SubmissionRow> {
    const result = await transaction.query<SubmissionRow>(
      `select id, state from profile.verification_submissions
        where account_id = $1 and lane = $2
          and state in ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW')
        for update`,
      [accountId, lane],
    )
    const row = result.rows[0]
    if (!row) {
      throw new ApiError("NOT_FOUND", "No attempt is open for this lane.", 404)
    }
    return row
  }

  private viewFromState(
    lane: VerificationLane,
    state: VerificationState,
    reasonCode: string | null,
    active: boolean,
    evidenceCount: number,
  ): LaneView {
    return {
      lane,
      state,
      reasonCode,
      hasActiveSubmission: active && isOpenSubmission(state),
      evidenceCount,
      stateChangedAt: new Date().toISOString(),
    }
  }

  private async audit(
    transaction: TransactionContext,
    input: LaneInput,
    action: string,
    summary: Readonly<Record<string, unknown>>,
  ): Promise<void> {
    await appendAudit(transaction.client, {
      actorType: "user",
      actorId: input.userId,
      actorAudience: input.context.audience,
      environment: input.context.environment,
      action,
      targetType: "verification_lane",
      targetId: input.lane,
      afterSummary: summary,
      ip: input.context.ip,
      userAgent: input.context.userAgent,
      correlationId: input.context.correlationId,
    })
  }
}
