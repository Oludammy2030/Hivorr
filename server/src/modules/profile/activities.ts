import type { PoolClient } from "pg"

export interface ActivationView {
  readonly id: string
  readonly state: string
}

/**
 * Public profile interface for the activity switcher. Identity calls this
 * instead of reading `profile.activity_activations` directly; the schema stays
 * owned by the profile module.
 */
interface ActivityRow {
  activity_id: string
  state: string
}

export async function listActiveActivities(
  client: PoolClient,
  accountId: string,
): Promise<ActivationView[]> {
  const result = await client.query<ActivityRow>(
    `select activity_id, state
     from profile.activity_activations
     where account_id = $1 and state <> 'INACTIVE'
     order by activity_id`,
    [accountId],
  )
  return result.rows.map((row) => ({
    id: row.activity_id,
    state: row.state,
  }))
}
