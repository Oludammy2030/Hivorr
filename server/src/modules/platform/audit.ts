import type { PoolClient } from "pg"

/**
 * The platform module owns `platform.audit_log`. Other modules write audit
 * records through this function and pass the client that holds their
 * transaction, so the record commits or rolls back with the change it
 * describes.
 *
 * This is the public interface for the one platform write EP-01 needs. The
 * full audit read model, retention and integrity checks belong to EP-01-036.
 */
export interface AuditEntry {
  readonly actorType: "user" | "staff" | "admin" | "partner" | "developer" | "system"
  readonly actorId: string
  readonly actorAudience: string
  readonly environment: string
  readonly action: string
  readonly targetType: string
  readonly targetId: string
  readonly beforeSummary?: Record<string, unknown> | undefined
  readonly afterSummary?: Record<string, unknown> | undefined
  readonly ip?: string | undefined
  readonly userAgent?: string | undefined
  readonly correlationId?: string | undefined
}

export async function appendAudit(
  client: PoolClient,
  entry: AuditEntry,
): Promise<void> {
  await client.query(
    `insert into platform.audit_log
       (actor_type, actor_id, actor_audience, environment, action, target_type, target_id,
        before_summary, after_summary, ip, user_agent, correlation_id)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
    [
      entry.actorType,
      entry.actorId,
      entry.actorAudience,
      entry.environment,
      entry.action,
      entry.targetType,
      entry.targetId,
      entry.beforeSummary ? JSON.stringify(entry.beforeSummary) : null,
      entry.afterSummary ? JSON.stringify(entry.afterSummary) : null,
      entry.ip ?? null,
      entry.userAgent ?? null,
      entry.correlationId ?? null,
    ],
  )
}

export interface AuditEntryView {
  readonly id: string
  readonly occurredAt: string
  readonly actorType: string
  readonly actorId: string | null
  readonly actorAudience: string | null
  readonly environment: string
  readonly action: string
  readonly targetType: string | null
  readonly targetId: string | null
  readonly beforeSummary: Record<string, unknown> | null
  readonly afterSummary: Record<string, unknown> | null
  readonly correlationId: string | null
}

/**
 * Guarded read model for the control audit probe. It returns the review fields
 * only and never includes before/after payloads.
 */
export async function listAuditEntries(
  client: PoolClient,
  limit = 100,
): Promise<AuditEntryView[]> {
  const bounded = Math.max(1, Math.min(200, Math.trunc(limit)))
  const result = await client.query<{
    id: string
    occurred_at: string
    actor_type: string
    actor_id: string | null
    actor_audience: string | null
    environment: string
    action: string
    target_type: string | null
    target_id: string | null
    before_summary: Record<string, unknown> | null
    after_summary: Record<string, unknown> | null
    correlation_id: string | null
  }>(
    `select id, occurred_at, actor_type, actor_id, actor_audience,
            environment, action, target_type, target_id,
            before_summary, after_summary, correlation_id
     from platform.audit_log
     order by occurred_at desc
     limit $1`,
    [bounded],
  )
  return result.rows.map((row) => ({
    id: row.id,
    occurredAt: row.occurred_at,
    actorType: row.actor_type,
    actorId: row.actor_id,
    actorAudience: row.actor_audience,
    environment: row.environment,
    action: row.action,
    targetType: row.target_type,
    targetId: row.target_id,
    beforeSummary: row.before_summary,
    afterSummary: row.after_summary,
    correlationId: row.correlation_id,
  }))
}
