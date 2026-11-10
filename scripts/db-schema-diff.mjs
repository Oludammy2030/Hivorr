#!/usr/bin/env node
// Schema diff review artefact (EP-01-004).
//
// Compares two `db-schema-snapshot.mjs` outputs and writes a markdown report.
// It is a review aid, not a migration runner and not a second source of truth.
// With `--fail-on-change` it exits non-zero when any schema line was added or
// removed, which lets CI treat an unreviewed schema change as a stop.
//
// Usage:
//   node scripts/db-schema-diff.mjs --base <file> --head <file> --out <file>
//   node scripts/db-schema-diff.mjs --base <file> --head <file> --fail-on-change

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import path from "node:path"

const args = process.argv.slice(2)
let base = ""
let head = ""
let out = ""
let failOnChange = false

for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--base" && args[index + 1]) {
    base = args[index + 1]
    index += 1
  } else if (args[index] === "--head" && args[index + 1]) {
    head = args[index + 1]
    index += 1
  } else if (args[index] === "--out" && args[index + 1]) {
    out = args[index + 1]
    index += 1
  } else if (args[index] === "--fail-on-change") {
    failOnChange = true
  }
}

if (!base || !head) {
  console.error("db:diff: --base and --head are required")
  process.exit(2)
}

if (!existsSync(base)) {
  const note = [
    "# Database schema diff",
    "",
    `No base snapshot at \`${base}\`. A schema baseline is not yet committed;`,
    "the head snapshot is published for review on its own.",
    "",
  ].join("\n")
  if (out) {
    mkdirSync(path.dirname(path.resolve(out)), { recursive: true })
    writeFileSync(out, note)
  }
  console.log(note)
  process.exit(0)
}

if (!existsSync(head)) {
  console.error(`db:diff: head snapshot not found at ${head}`)
  process.exit(2)
}

function counts(lines) {
  const map = new Map()
  for (const line of lines) {
    // Section counts change whenever any row changes; keep the header stable so
    // the diff shows the rows, not the counter.
    const normalized = line.replace(/^(## .*?) \(\d+\)$/, "$1")
    map.set(normalized, (map.get(normalized) ?? 0) + 1)
  }
  return map
}

const baseLines = readFileSync(base, "utf8").split(/\r?\n/)
const headLines = readFileSync(head, "utf8").split(/\r?\n/)
const baseCounts = counts(baseLines)
const headCounts = counts(headLines)

const removed = []
const added = []
for (const [line, count] of baseCounts) {
  const remaining = headCounts.get(line) ?? 0
  for (let index = 0; index < count - remaining; index += 1) removed.push(line)
}
for (const [line, count] of headCounts) {
  const existing = baseCounts.get(line) ?? 0
  for (let index = 0; index < count - existing; index += 1) added.push(line)
}

const report = [
  "# Database schema diff",
  "",
  `- Base: \`${base}\``,
  `- Head: \`${head}\``,
  `- Removed lines: **${removed.length}**`,
  `- Added lines: **${added.length}**`,
  "",
  "> Derived review artefact. Migrations remain the source of truth.",
  "",
  "## Removed",
  "",
  ...(removed.length ? removed.map((line) => `- \`${line}\``) : ["_None._"]),
  "",
  "## Added",
  "",
  ...(added.length ? added.map((line) => `- \`${line}\``) : ["_None._"]),
  "",
].join("\n")

if (out) {
  mkdirSync(path.dirname(path.resolve(out)), { recursive: true })
  writeFileSync(out, report)
  console.log(`db:diff: wrote ${out}`)
} else {
  process.stdout.write(report)
}

if (removed.length || added.length) {
  if (failOnChange) {
    console.error(
      `db:diff: schema changed (${removed.length} removed, ${added.length} added)`,
    )
    process.exit(1)
  }
  console.log(
    `db:diff: schema changed (${removed.length} removed, ${added.length} added) — review required`,
  )
} else {
  console.log("db:diff: no schema change")
}
