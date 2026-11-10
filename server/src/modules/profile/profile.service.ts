import { Inject, Injectable } from "@nestjs/common"
import {
  ACTIVITY_IDS,
  isActivityId,
  type ActivityId,
  type CapabilityId,
} from "@hivorr/shared"

import { ApiError, requireCapability } from "../../common/errors"
import { DatabaseService } from "../../db/database.service"
import { appendAudit } from "../platform"
import type { PersistedActivationState } from "./domain/activation"

export interface ActivityContext {
  readonly audience: string
  readonly environment: string
  readonly ip?: string | undefined
  readonly userAgent?: string | undefined
  readonly correlationId?: string | undefined
}

export interface ActivityStateView {
  readonly id: ActivityId
  readonly state: PersistedActivationState
}

interface ActivationRow {
  activity_id: string
  state: string
}

/**
 * Activity registry and activation state (EP-01-033).
 *
 * Activation is a row, never an account type. Any of the six can be activated
 * in any order; deactivation keeps the row and its history. The database
 * trigger rejects transitions outside the approved table.
 */
@Injectable()
export class ProfileService {
  constructor(
    @Inject(DatabaseService) private readonly database: DatabaseService,
  ) {}

  async list(accountId: string, userId: string): Promise<ActivityStateView[]> {
    return this.database.withTransaction(
      { identity: { accountId, userId } },
      async (transaction) => {
        const rows = await transaction.query<ActivationRow>(
          `select activity_id, state
           from profile.activity_activations
           where account_id = $1`,
          [accountId],
        )
        const states = new Map(
          rows.rows.map((row) => [
            row.activity_id,
            row.state as PersistedActivationState,
          ]),
        )
        return ACTIVITY_IDS.map((id) => ({
          id,
          state: states.get(id) ?? "INACTIVE",
        }))
      },
    )
  }

  async activate(
    accountId: string,
    userId: string,
    activityId: string,
    capabilities: ReadonlySet<CapabilityId>,
    context: ActivityContext,
  ): Promise<ActivityStateView> {
    this.assertActivity(activityId)

    return this.database.withTransaction(
      { identity: { accountId, userId } },
      async (transaction) => {
        requireCapability(capabilities, "activity.activate")

        const previous = await transaction.query<{ state: string }>(
          `select state from profile.activity_activations
           where account_id = $1 and activity_id = $2`,
          [accountId, activityId],
        )
        const previousState = previous.rows[0]?.state ?? "INACTIVE"

        const result = await transaction.query<ActivationRow>(
          `insert into profile.activity_activations
             (account_id, activity_id, state, activated_at, state_changed_at)
           values ($1, $2, 'ACTIVE', now(), now())
           on conflict (account_id, activity_id) do update
             set state = 'ACTIVE',
                 activated_at = coalesce(
                   profile.activity_activations.activated_at, now()
                 ),
                 deactivated_at = null,
                 state_changed_at = now(),
                 updated_at = now()
             where profile.activity_activations.state <> 'ACTIVE'
           returning activity_id, state`,
          [accountId, activityId],
        )

        if (result.rows[0]) {
          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: userId,
            actorAudience: context.audience,
            environment: context.environment,
            action: "profile.activity_activated",
            targetType: "activity",
            targetId: activityId,
            beforeSummary: { state: previousState },
            afterSummary: { state: "ACTIVE" },
            ip: context.ip,
            userAgent: context.userAgent,
            correlationId: context.correlationId,
          })
        }

        return { id: activityId, state: "ACTIVE" }
      },
    )
  }

  async deactivate(
    accountId: string,
    userId: string,
    activityId: string,
    capabilities: ReadonlySet<CapabilityId>,
    context: ActivityContext,
  ): Promise<ActivityStateView> {
    this.assertActivity(activityId)

    return this.database.withTransaction(
      { identity: { accountId, userId } },
      async (transaction) => {
        requireCapability(capabilities, "activity.deactivate")

        const previous = await transaction.query<{ state: string }>(
          `select state from profile.activity_activations
           where account_id = $1 and activity_id = $2`,
          [accountId, activityId],
        )
        const previousState = previous.rows[0]?.state ?? "INACTIVE"

        const result = await transaction.query<ActivationRow>(
          `update profile.activity_activations
           set state = 'INACTIVE',
               deactivated_at = now(),
               state_changed_at = now(),
               updated_at = now()
           where account_id = $1 and activity_id = $2
             and state <> 'INACTIVE'
           returning activity_id, state`,
          [accountId, activityId],
        )

        if (result.rows[0]) {
          await appendAudit(transaction.client, {
            actorType: "user",
            actorId: userId,
            actorAudience: context.audience,
            environment: context.environment,
            action: "profile.activity_deactivated",
            targetType: "activity",
            targetId: activityId,
            beforeSummary: { state: previousState },
            afterSummary: { state: "INACTIVE" },
            ip: context.ip,
            userAgent: context.userAgent,
            correlationId: context.correlationId,
          })
        }

        return { id: activityId, state: "INACTIVE" }
      },
    )
  }

  private assertActivity(value: string): asserts value is ActivityId {
    if (!isActivityId(value)) {
      throw new ApiError("VALIDATION_FAILED", "Unknown activity.", 400)
    }
  }
}
