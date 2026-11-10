import { z } from "zod"

/**
 * Cursor pagination contract (ARCHITECTURE.md §9.9).
 *
 * Collection endpoints return a bounded page and an opaque cursor. The cursor
 * encodes the stable sort position of the last row; it is not an offset and it
 * never contains a record the caller cannot read.
 */
export const DEFAULT_PAGE_SIZE = 20
export const MAX_PAGE_SIZE = 100

export const paginationQuerySchema = z.strictObject({
  limit: z.coerce
    .number()
    .int()
    .min(1)
    .max(MAX_PAGE_SIZE)
    .default(DEFAULT_PAGE_SIZE),
  cursor: z.string().min(1).max(1024).optional(),
})

export type PaginationQuery = z.infer<typeof paginationQuerySchema>

export interface PageInfo {
  readonly hasMore: boolean
  readonly nextCursor: string | null
}

export interface Page<T> {
  readonly data: readonly T[]
  readonly page: PageInfo
}
