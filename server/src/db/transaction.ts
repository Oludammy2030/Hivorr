import type { Pool, PoolClient, QueryResult, QueryResultRow } from "pg"

export interface TransactionIdentity {
  readonly accountId: string
  readonly userId: string
}

export interface TransactionOptions {
  /** Set before the work runs. A caller may set it again inside the work. */
  readonly identity?: TransactionIdentity
}

export interface TransactionContext {
  readonly client: PoolClient
  /** Parameterised query. Values are never interpolated into SQL. */
  query<T extends QueryResultRow = QueryResultRow>(
    text: string,
    values?: readonly unknown[],
  ): Promise<QueryResult<T>>
  /** Sets the transaction-local RLS context. */
  setIdentity(identity: TransactionIdentity): Promise<void>
}

/**
 * Unit of work (EP-01-026).
 *
 * One connection, one explicit transaction, one release. The RLS context is
 * set before the work when supplied, and can be set again inside the work when
 * a new account/user is created. A throw rolls back; the error is re-thrown
 * unchanged so the service can map it.
 */
export async function withTransaction<T>(
  pool: Pool,
  options: TransactionOptions,
  work: (transaction: TransactionContext) => Promise<T>,
): Promise<T> {
  const client = await pool.connect()

  const transaction: TransactionContext = {
    client,
    async query<R extends QueryResultRow = QueryResultRow,>(
      text: string,
      values?: readonly unknown[],
    ): Promise<QueryResult<R>> {
      return client.query<R>(text, values as unknown[] | undefined)
    },
    async setIdentity(identity) {
      await client.query("select platform.set_identity_context($1, $2)", [
        identity.accountId,
        identity.userId,
      ])
    },
  }

  try {
    await client.query("begin")
    if (options.identity) {
      await transaction.setIdentity(options.identity)
    }
    const result = await work(transaction)
    await client.query("commit")
    return result
  } catch (error) {
    await client.query("rollback").catch(() => undefined)
    throw error
  } finally {
    client.release()
  }
}
