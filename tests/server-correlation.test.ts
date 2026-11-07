import { describe, expect, it } from "vitest"

import { resolveCorrelationId } from "../server/src/common/correlation"

describe("correlation ids", () => {
  it("preserves a safe caller value", () => {
    expect(resolveCorrelationId("req-12345678")).toBe("req-12345678")
  })

  it("replaces unsafe or missing values", () => {
    const generated = resolveCorrelationId("not valid <script>")
    expect(generated).not.toContain("<")
    expect(generated).toMatch(/^[A-Za-z0-9._-]{8,128}$/)
    expect(resolveCorrelationId(undefined)).toMatch(/^[A-Za-z0-9._-]{8,128}$/)
  })
})
