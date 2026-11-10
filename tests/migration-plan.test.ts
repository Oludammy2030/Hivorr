import { describe, expect, it } from "vitest"

import {
  planMigrations,
  verifyMigrationHistory,
} from "../scripts/lib/migration-history.mjs"

function file(filename: string, checksum = `checksum-${filename}`) {
  return { filename, checksum }
}

describe("migration plan", () => {
  it("plans every file for a fresh database", () => {
    const files = [file("001_a.sql"), file("002_b.sql"), file("003_c.sql")]
    const plan = planMigrations({ files, applied: [] })
    expect(plan.ok).toBe(true)
    expect(plan.pending).toEqual(["001_a.sql", "002_b.sql", "003_c.sql"])
    expect(plan.applied).toBe(0)
  })

  it("plans only the pending files in filename order", () => {
    const files = [file("003_c.sql"), file("001_a.sql"), file("002_b.sql")]
    const plan = planMigrations({
      files,
      applied: [
        { filename: "001_a.sql", checksum: "checksum-001_a.sql" },
        { filename: "002_b.sql", checksum: "checksum-002_b.sql" },
      ],
    })
    expect(plan.ok).toBe(true)
    expect(plan.pending).toEqual(["003_c.sql"])
    expect(plan.applied).toBe(2)
  })

  it("refuses a checksum that changed after apply", () => {
    const plan = planMigrations({
      files: [file("001_a.sql", "changed")],
      applied: [{ filename: "001_a.sql", checksum: "original" }],
    })
    expect(plan.ok).toBe(false)
    expect(plan.issues).toContain("checksum changed after apply: 001_a.sql")
  })

  it("refuses an applied migration that is not in the repository", () => {
    const plan = planMigrations({
      files: [],
      applied: [{ filename: "old.sql", checksum: "x" }],
    })
    expect(plan.ok).toBe(false)
    expect(plan.issues).toContain("applied but not in the repository: old.sql")
  })

  it("refuses a pending migration that sorts before the last applied one", () => {
    const plan = planMigrations({
      files: [file("001_a.sql"), file("002_b.sql")],
      applied: [{ filename: "002_b.sql", checksum: "checksum-002_b.sql" }],
    })
    expect(plan.ok).toBe(false)
    expect(plan.issues).toContain(
      "pending migration sorts before the last applied migration: 001_a.sql",
    )
  })

  it("reports the plan even when it is refused", () => {
    const plan = planMigrations({
      files: [file("001_a.sql")],
      applied: [{ filename: "missing.sql", checksum: "x" }],
    })
    expect(plan.pending).toEqual(["001_a.sql"])
    expect(plan.ok).toBe(false)
  })
})

describe("post-apply history", () => {
  it("accepts a complete, matching history", () => {
    const files = [file("001_a.sql"), file("002_b.sql")]
    const verdict = verifyMigrationHistory({
      files,
      applied: files.map((entry) => ({ ...entry })),
    })
    expect(verdict.ok).toBe(true)
  })

  it("refuses a file that was not applied", () => {
    const verdict = verifyMigrationHistory({
      files: [file("001_a.sql")],
      applied: [],
    })
    expect(verdict.ok).toBe(false)
    expect(verdict.issues).toContain("missing from history: 001_a.sql")
  })
})
