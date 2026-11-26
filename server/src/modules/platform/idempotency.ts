import type { PoolClient } from "pg"

/**
 * Idempotency record store (EP-02-034).
 *
 * The platform module owns `platform.idempotency_keys`. A money-moving service
 * claims a key before it writes, completes the record with the response, and
 * replays that response when the same key and request arrive again.
 *
 * `claimIdempotency` holds a row lock while another transaction is completing
 * the same key, so a concurrent retry waits and then reads the stored result
 * instead of posting a second entry.
 */
export interface IdempotencyClaimInput {
  readonly key: string
  readonly scope: string
  readonly requestHash: string
  /** ISO timestamp or `infinity` for a record that must never expire. */
  readonly expiresAt: string
}

export type IdempotencyClaim =
  | { readonly status: "claimed" }
  | {
      readonly status: "replay"
      readonly responseStatus: number
      readonly responseBody: unknown
    }
  | { readonly status: "conflict" }

interface IdempotencyRow {
  request_hash: string
  response_status: number | null
  response_body: unknown
}

export async function claimIdempotency(
  client: PoolClient,
  input: IdempotencyClaimInput,
): Promise<IdempotencyClaim> {
  const inserted = await client.query(
    `insert into platform.idempotency_keys (key, scope, request_hash, expires_at)
     values ($1, $2, $3, $4::timestamptz)
     on conflict (key) do nothing`,
    [input.key, input.scope, input.requestHash, input.expiresAt],
  )

  if ((inserted.rowCount ?? 0) === 1) return { status: "claimed" }

  const existing = await client.query<IdempotencyRow>(
    `select request_hash, response_status, response_body
       from platform.idempotency_keys
      where key = $1
      for update`,
    [input.key],
  )
  const row = existing.rows[0]

  if (!row) {
    throw new Error("The idempotency record disappeared during the claim.")
  }

  if (row.request_hash !== input.requestHash) return { status: "conflict" }
  if (row.response_status === null) {
    throw new Error("The idempotency record has no completed response.")
  }

  return {
    status: "replay",
    responseStatus: row.response_status,
    responseBody: row.response_body,
  }
}

export async function completeIdempotency(
  client: PoolClient,
  input: {
    readonly key: string
    readonly responseStatus: number
    readonly responseBody: unknown
  },
): Promise<void> {
  await client.query(
    `update platform.idempotency_keys
        set response_status = $2,
            response_body = $3::jsonb
      where key = $1`,
    [input.key, input.responseStatus, JSON.stringify(input.responseBody)],
  )
}
