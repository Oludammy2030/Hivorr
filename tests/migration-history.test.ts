import { describe, expect, it } from "vitest"

import {
  migrationChecksum,
  verifyMigrationHistory,
} from "../scripts/lib/migration-history.mjs"

const files = [
  { filename: "001_a.sql", checksum: "aaa" },
  { filename: "002_b.sql", checksum: "bbb" },
]

describe("migration history verification", () => {
  it("accepts a complete history with matching checksums", () => {
    expect(
      verifyMigrationHistory({
        files,
        applied: [
          { filename: "001_a.sql", checksum: "aaa" },
          { filename: "002_b.sql", checksum: "bbb" },
        ],
      }),
    ).toEqual({ ok: true, issues: [], files: 2, applied: 2 })
  })

  it("refuses a migration that was not applied", () => {
    const verdict = verifyMigrationHistory({
      files,
      applied: [{ filename: "001_a.sql", checksum: "aaa" }],
    })
    expect(verdict.ok).toBe(false)
    expect(verdict.issues).toContain("missing from history: 002_b.sql")
  })

  it("refuses an applied migration that was edited afterwards", () => {
    const verdict = verifyMigrationHistory({
      files,
      applied: [
        { filename: "001_a.sql", checksum: "aaa" },
        { filename: "002_b.sql", checksum: "changed" },
      ],
    })
    expect(verdict.ok).toBe(false)
    expect(verdict.issues).toContain("checksum changed after apply: 002_b.sql")
  })

  it("refuses an applied row that no longer exists in the repository", () => {
    const verdict = verifyMigrationHistory({
      files,
      applied: [
        { filename: "001_a.sql", checksum: "aaa" },
        { filename: "002_b.sql", checksum: "bbb" },
        { filename: "003_deleted.sql", checksum: "ccc" },
      ],
    })
    expect(verdict.ok).toBe(false)
    expect(verdict.issues).toContain(
      "applied but not in the repository: 003_deleted.sql",
    )
  })

  it("hashes the exact file contents", () => {
    expect(migrationChecksum("select 1;\n")).toBe(
      migrationChecksum("select 1;\n"),
    )
    expect(migrationChecksum("select 1;\n")).not.toBe(
      migrationChecksum("select 1;\r\n"),
    )
  })
})
