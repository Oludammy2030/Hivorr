import { createHash } from "node:crypto"

/**
 * Pure comparison between the migration files on disk and the applied history.
 * Kept free of `pg` so it can be tested without a database.
 */
export function migrationChecksum(sql) {
  return createHash("sha256").update(sql).digest("hex")
}

export function verifyMigrationHistory({ files, applied }) {
  const issues = []
  const appliedByFile = new Map(
    applied.map((row) => [row.filename, row.checksum]),
  )
  const fileNames = new Set(files.map((file) => file.filename))

  for (const file of files) {
    const recorded = appliedByFile.get(file.filename)
    if (recorded === undefined) {
      issues.push(`missing from history: ${file.filename}`)
    } else if (recorded !== file.checksum) {
      issues.push(`checksum changed after apply: ${file.filename}`)
    }
  }

  for (const row of applied) {
    if (!fileNames.has(row.filename)) {
      issues.push(`applied but not in the repository: ${row.filename}`)
    }
  }

  return {
    ok: issues.length === 0,
    issues,
    files: files.length,
    applied: applied.length,
  }
}

/**
 * Pre-application plan. Unlike the post-apply verifier, a not-yet-applied file
 * is expected. It refuses checksum drift, history entries missing from the
 * repository, and a pending file that sorts before an applied file (a gap that
 * would apply history out of order).
 */
export function planMigrations({ files, applied }) {
  const issues = []
  const appliedByFile = new Map(
    applied.map((row) => [row.filename, row.checksum]),
  )
  const fileNames = new Set(files.map((file) => file.filename))
  const sorted = [...files].sort((left, right) =>
    left.filename.localeCompare(right.filename),
  )

  for (const row of applied) {
    if (!fileNames.has(row.filename)) {
      issues.push(`applied but not in the repository: ${row.filename}`)
    }
  }

  for (const file of sorted) {
    const recorded = appliedByFile.get(file.filename)
    if (recorded !== undefined && recorded !== file.checksum) {
      issues.push(`checksum changed after apply: ${file.filename}`)
    }
  }

  const appliedNames = [...appliedByFile.keys()].sort()
  const lastApplied = appliedNames.at(-1)
  const pending = sorted
    .filter((file) => !appliedByFile.has(file.filename))
    .map((file) => file.filename)

  if (lastApplied) {
    for (const filename of pending) {
      if (filename.localeCompare(lastApplied) < 0) {
        issues.push(
          `pending migration sorts before the last applied migration: ${filename}`,
        )
      }
    }
  }

  return {
    ok: issues.length === 0,
    issues,
    files: files.length,
    applied: appliedByFile.size,
    pending,
  }
}
