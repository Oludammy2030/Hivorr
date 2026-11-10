import type { QueryResult, QueryResultRow } from "pg"

import type { TransactionContext } from "../../../db/transaction"
import { normalizeEmail } from "../domain/identity"

const OTHER_MODULE_SCHEMA =
  /\b(profile|market|services|errands|logistics|finance|messaging|admin)\./i

/**
 * Repositories in this module may read and write only the identity schema
 * (plus shared platform functions). A generated query cannot wander into
 * another module's tables.
 */
export function assertIdentitySchemaSql(sql: string): void {
  const match = OTHER_MODULE_SCHEMA.exec(sql)
  if (match) {
    throw new Error(`identity repository may not access the ${match[1]} schema`)
  }
}

export interface RegistrationRecord {
  readonly accountId: string
  readonly userId: string
  readonly email: string
  readonly displayName: string | null
  readonly passwordHash: string
}

export interface AccountRecord {
  readonly id: string
  readonly status: string
  readonly legalName: string | null
  readonly createdAt: string
  readonly updatedAt: string
}

export interface UserRecord {
  readonly id: string
  readonly accountId: string
  readonly email: string
  readonly displayName: string | null
  readonly status: string
}

export interface MembershipRecord {
  readonly id: string
  readonly userId: string
  readonly accountId: string
  readonly role: string
  readonly createdAt: string
}

export interface GrantRecord {
  readonly id: string
  readonly userId: string
  readonly grantType: string
  readonly scope: string
  readonly environment: string
  readonly expiresAt: string | null
  readonly revokedAt: string | null
  readonly createdAt: string
}

export interface DeviceRecord {
  readonly id: string
  readonly userId: string
  readonly name: string | null
  readonly fingerprintHash: string | null
  readonly lastSeenAt: string | null
  readonly createdAt: string
}

/**
 * Identity-scoped repository (EP-01-030). It accepts a transaction, never a
 * pool, so every mutation shares the caller's unit of work and RLS context.
 */
export class IdentityRepository {
  constructor(private readonly transaction: TransactionContext) {}

  async createAccountWithOwner(record: RegistrationRecord): Promise<void> {
    await this.query("insert into identity.accounts (id) values ($1)", [
      record.accountId,
    ])
    await this.query(
      "insert into identity.users (id, account_id, email, display_name) values ($1, $2, $3, $4)",
      [
        record.userId,
        record.accountId,
        normalizeEmail(record.email),
        record.displayName,
      ],
    )
    await this.query(
      "insert into identity.credentials (user_id, password_hash) values ($1, $2)",
      [record.userId, record.passwordHash],
    )
    await this.query(
      "insert into identity.memberships (user_id, account_id, role) values ($1, $2, 'owner')",
      [record.userId, record.accountId],
    )
  }

  async findAccount(accountId: string): Promise<AccountRecord | undefined> {
    const result = await this.query<{
      id: string
      status: string
      legal_name: string | null
      created_at: string
      updated_at: string
    }>(
      "select id, status, legal_name, created_at, updated_at from identity.accounts where id = $1",
      [accountId],
    )
    const row = result.rows[0]
    return row
      ? {
          id: row.id,
          status: row.status,
          legalName: row.legal_name,
          createdAt: row.created_at,
          updatedAt: row.updated_at,
        }
      : undefined
  }

  async findUser(userId: string): Promise<UserRecord | undefined> {
    const result = await this.query<{
      id: string
      account_id: string
      email: string
      display_name: string | null
      status: string
    }>(
      "select id, account_id, email, display_name, status from identity.users where id = $1",
      [userId],
    )
    const row = result.rows[0]
    return row
      ? {
          id: row.id,
          accountId: row.account_id,
          email: row.email,
          displayName: row.display_name,
          status: row.status,
        }
      : undefined
  }

  async findUserByEmail(email: string): Promise<UserRecord | undefined> {
    const result = await this.query<{
      id: string
      account_id: string
      email: string
      display_name: string | null
      status: string
    }>(
      "select id, account_id, email, display_name, status from identity.users where lower(email) = lower($1) limit 1",
      [normalizeEmail(email)],
    )
    const row = result.rows[0]
    return row
      ? {
          id: row.id,
          accountId: row.account_id,
          email: row.email,
          displayName: row.display_name,
          status: row.status,
        }
      : undefined
  }

  async listMemberships(accountId: string): Promise<MembershipRecord[]> {
    const result = await this.query<{
      id: string
      user_id: string
      account_id: string
      role: string
      created_at: string
    }>(
      "select id, user_id, account_id, role, created_at from identity.memberships where account_id = $1 order by created_at",
      [accountId],
    )
    return result.rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      accountId: row.account_id,
      role: row.role,
      createdAt: row.created_at,
    }))
  }

  async listGrants(userId: string): Promise<GrantRecord[]> {
    const result = await this.query<{
      id: string
      user_id: string
      grant_type: string
      scope: string
      environment: string
      expires_at: string | null
      revoked_at: string | null
      created_at: string
    }>(
      "select id, user_id, grant_type, scope, environment, expires_at, revoked_at, created_at from identity.grants where user_id = $1 order by created_at",
      [userId],
    )
    return result.rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      grantType: row.grant_type,
      scope: row.scope,
      environment: row.environment,
      expiresAt: row.expires_at,
      revokedAt: row.revoked_at,
      createdAt: row.created_at,
    }))
  }

  async listDevices(userId: string): Promise<DeviceRecord[]> {
    const result = await this.query<{
      id: string
      user_id: string
      name: string | null
      fingerprint_hash: string | null
      last_seen_at: string | null
      created_at: string
    }>(
      "select id, user_id, name, fingerprint_hash, last_seen_at, created_at from identity.devices where user_id = $1 order by created_at",
      [userId],
    )
    return result.rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      name: row.name,
      fingerprintHash: row.fingerprint_hash,
      lastSeenAt: row.last_seen_at,
      createdAt: row.created_at,
    }))
  }

  private async query<T extends QueryResultRow = QueryResultRow,>(
    text: string,
    values?: readonly unknown[],
  ): Promise<QueryResult<T>> {
    assertIdentitySchemaSql(text)
    return this.transaction.query<T>(text, values)
  }
}
