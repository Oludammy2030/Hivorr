import type { PoolClient } from "pg"

/**
 * The platform module owns `platform.audit_log`. Other modules write audit
 * records through this function and pass the client that holds their
 * transaction, so the record commits or rolls back with the change it
 * describes.
 *
 * The audit trail is append-only. No update or delete path exists.
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
  readonly sessionId?: string | undefined
  readonly reason?: string | undefined
  readonly approvalReference?: string | undefined
  readonly capability?: string | undefined
}

export async function appendAudit(
  client: PoolClient,
  entry: AuditEntry,
): Promise<void> {
  const actorType =
    entry.actorType === "user" && entry.actorAudience === "control"
      ? "admin"
      : entry.actorType === "user" && entry.actorAudience === "staff"
        ? "staff"
        : entry.actorType === "user" && entry.actorAudience === "partner"
          ? "partner"
          : entry.actorType

  await client.query(
    `insert into platform.audit_log
       (actor_type, actor_id, actor_audience, environment, action, target_type, target_id,
        before_summary, after_summary, ip, user_agent, correlation_id, session_id,
        reason, approval_reference, actor_display_name, actor_email, actor_role_keys,
        actor_role_scopes, capability)
     select $1, $2::uuid, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15,
            s.display_name, s.email, coalesce(s.role_keys, '{}'::text[]),
            coalesce(s.role_scopes, '[]'::jsonb), $16
       from (select 1) as anchor
       left join platform.resolve_audit_actor($2::text) s on true`,
    [
      actorType,
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
      entry.sessionId ?? null,
      entry.reason ?? null,
      entry.approvalReference ?? null,
      entry.capability ?? null,
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
  readonly sessionId: string | null
  readonly reason: string | null
  readonly approvalReference: string | null
  readonly actorDisplayName: string | null
  readonly actorEmail: string | null
  readonly actorRoleKeys: readonly string[]
  readonly actorRoleScopes: readonly AuditActorRoleScope[]
  readonly capability: string | null
}

/**
 * A role and the scope it was held at when the action was recorded. The scope
 * distinguishes, for example, a Support Officer for one queue from one with
 * platform-wide scope.
 */
export interface AuditActorRoleScope {
  readonly roleKey: string
  readonly scopeType: string | null
  readonly scopeId: string | null
}

export interface AuditQuery {
  readonly limit?: number
  readonly actorId?: string | null
  readonly action?: string | null
  readonly targetType?: string | null
  readonly targetId?: string | null
  readonly from?: string | null
  readonly to?: string | null
  readonly before?: string | null
  readonly beforeId?: string | null
}

export interface AuditPage {
  readonly items: readonly AuditEntryView[]
  readonly nextCursor: string | null
}

interface AuditRow {
  id: string
  occurred_at: string | Date
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
  session_id: string | null
  reason: string | null
  approval_reference: string | null
  actor_display_name: string | null
  actor_email: string | null
  actor_role_keys: string[] | null
  actor_role_scopes: unknown
  capability: string | null
}

function toRoleScopes(value: unknown): AuditActorRoleScope[] {
  if (!Array.isArray(value)) return []
  const scopes: AuditActorRoleScope[] = []
  for (const entry of value) {
    if (typeof entry !== "object" || entry === null) continue
    const record = entry as Record<string, unknown>
    if (typeof record.roleKey !== "string") continue
    scopes.push({
      roleKey: record.roleKey,
      scopeType: typeof record.scopeType === "string" ? record.scopeType : null,
      scopeId: typeof record.scopeId === "string" ? record.scopeId : null,
    })
  }
  return scopes
}

/**
 * Bounded, filtered audit read. The caller must already hold
 * `admin.audit.read`; the controller writes a second audit record for the read.
 */
export async function listAuditEntries(
  client: PoolClient,
  query: AuditQuery = {},
): Promise<AuditPage> {
  const bounded = Math.max(1, Math.min(100, Math.trunc(query.limit ?? 50)))
  const result = await client.query<AuditRow>(
    `select id, occurred_at, actor_type, actor_id, actor_audience,
            environment, action, target_type, target_id,
            before_summary, after_summary, correlation_id, session_id,
            reason, approval_reference, actor_display_name, actor_email,
            actor_role_keys, actor_role_scopes, capability
       from platform.audit_log
      where ($1::uuid is null or actor_id = $1)
        and ($2::text is null or action = $2)
        and ($3::text is null or target_type = $3)
        and ($4::text is null or target_id = $4)
        and ($5::timestamptz is null or occurred_at >= $5)
        and ($6::timestamptz is null or occurred_at <= $6)
        and ($7::timestamptz is null or (occurred_at, id) < ($7, $8))
      order by occurred_at desc, id desc
      limit $9`,
    [
      query.actorId ?? null,
      query.action ?? null,
      query.targetType ?? null,
      query.targetId ?? null,
      query.from ?? null,
      query.to ?? null,
      query.before ?? null,
      query.beforeId ?? null,
      bounded + 1,
    ],
  )

  const visible = result.rows.slice(0, bounded)
  const last = visible[visible.length - 1]
  return {
    items: visible.map((row) => ({
      id: row.id,
      occurredAt:
        row.occurred_at instanceof Date
          ? row.occurred_at.toISOString()
          : row.occurred_at,
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
      sessionId: row.session_id,
      reason: row.reason,
      approvalReference: row.approval_reference,
      actorDisplayName: row.actor_display_name,
      actorEmail: row.actor_email,
      actorRoleKeys: row.actor_role_keys ?? [],
      actorRoleScopes: toRoleScopes(row.actor_role_scopes),
      capability: row.capability,
    })),
    nextCursor:
      result.rows.length > bounded && last
        ? `${
            last.occurred_at instanceof Date
              ? last.occurred_at.toISOString()
              : last.occurred_at
          }|${last.id}`
        : null,
  }
}
