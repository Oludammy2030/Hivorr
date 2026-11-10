import type { z } from "zod"

import { ApiError } from "./errors"

/**
 * One validation entry point for the HTTP trust boundary (SEC-22, SEC-23).
 *
 * The schema is allowlist-based: strict object schemas reject unknown fields.
 * The error names the offending fields and never repeats the internal zod
 * reason (SEC-27).
 */
function fieldsFrom(error: z.ZodError): string[] {
  const fields = new Set<string>()
  for (const issue of error.issues) {
    if (issue.code === "unrecognized_keys") {
      for (const key of issue.keys) fields.add(key)
      continue
    }
    const path = issue.path.join(".")
    if (path) fields.add(path)
  }
  return [...fields]
}

export function invalidRequest(error: z.ZodError): ApiError {
  const fields = fieldsFrom(error)
  return new ApiError(
    "VALIDATION_FAILED",
    fields.length
      ? `Invalid or unknown field(s): ${fields.join(", ")}.`
      : "The request is invalid.",
    400,
  )
}

export function parseBody<T extends z.ZodType>(
  schema: T,
  body: unknown,
): z.output<T> {
  const result = schema.safeParse(body)
  if (!result.success) throw invalidRequest(result.error)
  return result.data
}

export function parseQuery<T extends z.ZodType>(
  schema: T,
  query: unknown,
): z.output<T> {
  const result = schema.safeParse(query)
  if (!result.success) throw invalidRequest(result.error)
  return result.data
}
