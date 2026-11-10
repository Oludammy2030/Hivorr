import type {
  ActivityId,
  EnvironmentId,
  GrantId,
  PortalId,
} from "@hivorr/shared"
import type { PoolClient } from "pg"

import type { AccessContext } from "../../domain/capabilities"
import { listActiveActivities } from "../profile"
import { grantIsActive } from "./domain/identity"

interface GrantRow {
  scope: string
  environment: string
  expires_at: string | null
  revoked_at: string | null
}

interface ActivityRow {
  id: string
}

export interface AccessContextInputs {
  readonly audience: PortalId
  readonly environment: EnvironmentId
  readonly activities: readonly ActivityRow[]
  readonly grants: readonly GrantRow[]
}

/**
 * Pure mapping from the authoritative rows to the capability inputs. The same
 * function is used by the session view and by the guarded audit probe.
 */
export function buildAccessContext(inputs: AccessContextInputs): AccessContext {
  return {
    authenticated: true,
    audience: inputs.audience,
    environment: inputs.environment,
    grants: inputs.grants
      .filter(
        (grant) =>
          grant.environment === inputs.environment &&
          grantIsActive({
            expiresAt: grant.expires_at,
            revokedAt: grant.revoked_at,
          }),
      )
      .map((grant) => grant.scope as GrantId),
    activities: inputs.activities.map((activity) => activity.id as ActivityId),
  }
}

export interface LoadAccessContextInput {
  readonly accountId: string
  readonly userId: string
  readonly audience: PortalId
  readonly environment: EnvironmentId
}

/**
 * Reads the identity grants and profile activities inside the caller's
 * transaction. Used where the capability check and the protected operation must
 * share one snapshot.
 */
export async function loadAccessContext(
  client: PoolClient,
  input: LoadAccessContextInput,
): Promise<AccessContext> {
  const grants = await client.query<GrantRow>(
    `select scope, environment, expires_at, revoked_at
     from identity.grants where user_id = $1`,
    [input.userId],
  )
  const activities = await listActiveActivities(client, input.accountId)
  return buildAccessContext({
    audience: input.audience,
    environment: input.environment,
    activities,
    grants: grants.rows,
  })
}
