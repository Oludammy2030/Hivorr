import type { Page } from "@hivorr/shared"

import { ApiError } from "./errors"

/**
 * Server half of the cursor pagination contract. The cursor is opaque to the
 * client and encodes the stable sort position of the last returned row.
 *
 * Callers fetch `limit + 1` rows; `toPage` decides whether another page exists
 * and never returns the extra row.
 */
export function encodeCursor(value: string): string {
  return Buffer.from(value, "utf8").toString("base64url")
}

export function decodeCursor(cursor: string): string {
  let decoded = ""
  try {
    decoded = Buffer.from(cursor, "base64url").toString("utf8")
  } catch {
    decoded = ""
  }
  if (!decoded || encodeCursor(decoded) !== cursor) {
    throw new ApiError(
      "VALIDATION_FAILED",
      "The pagination cursor is invalid.",
      400,
    )
  }
  return decoded
}

export function toPage<T>(
  rows: readonly T[],
  limit: number,
  cursorOf: (row: T) => string,
): Page<T> {
  const hasMore = rows.length > limit
  const data = rows.slice(0, limit)
  const last = data[data.length - 1]
  return {
    data,
    page: {
      hasMore,
      nextCursor:
        hasMore && last !== undefined ? encodeCursor(cursorOf(last)) : null,
    },
  }
}
