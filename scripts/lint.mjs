#!/usr/bin/env node
// Lint gate with a written baseline (EP-00-004).
//
// `eslint` runs over the whole tree. Any violation not listed in
// `.lint-baseline.json` fails the gate. The baseline is not a disable comment:
// every entry names its file, rule, line and message, and the file carries a
// removal condition and an expiry. Stale entries are reported so the baseline
// shrinks when the prototype is extracted in EP-01.
//
// Usage:
//   node scripts/lint.mjs                  # gate
//   node scripts/lint.mjs --write-baseline # maintainer action; review the diff

import { ESLint } from "eslint"
import { readFileSync, writeFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const baselinePath = path.join(root, ".lint-baseline.json")
const writeBaseline = process.argv.includes("--write-baseline")

const eslint = new ESLint({ cwd: root })
const results = await eslint.lintFiles(["."])

const violations = []
for (const result of results) {
  const file = path.relative(root, result.filePath).split(path.sep).join("/")
  for (const message of result.messages) {
    if (!message.ruleId) continue
    violations.push({
      file,
      rule: message.ruleId,
      line: message.line ?? 0,
      message: message.message,
    })
  }
}

const keyOf = (entry) =>
  `${entry.file}|${entry.rule}|${entry.line}|${entry.message}`

if (writeBaseline) {
  const payload = {
    expires: "2026-12-31",
    removalCondition:
      "Remove an entry when its file is extracted or refactored in EP-01; the whole baseline is removed when App.tsx is decomposed.",
    entries: violations
      .map(({ file, rule, line, message }) => ({ file, rule, line, message }))
      .sort((a, b) => keyOf(a).localeCompare(keyOf(b))),
  }
  writeFileSync(baselinePath, `${JSON.stringify(payload, null, 2)}\n`, "utf8")
  console.log(
    `lint: baseline written with ${payload.entries.length} entry(ies)`,
  )
  process.exit(0)
}

let baseline
try {
  baseline = JSON.parse(readFileSync(baselinePath, "utf8"))
} catch (error) {
  console.error("lint: FAILED — .lint-baseline.json is missing or invalid")
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(2)
}

const expiry = new Date(`${baseline.expires}T23:59:59Z`)
if (Number.isNaN(expiry.getTime())) {
  console.error("lint: FAILED — baseline has no valid expiry date")
  process.exit(2)
}
if (Date.now() > expiry.getTime()) {
  console.error(`lint: FAILED — the baseline expired on ${baseline.expires}`)
  console.error("Fix the listed violations or record a new approved baseline.")
  process.exit(1)
}

const known = new Set((baseline.entries || []).map(keyOf))
const current = new Set(violations.map(keyOf))
const unexpected = violations.filter(
  (violation) => !known.has(keyOf(violation)),
)
const stale = (baseline.entries || []).filter(
  (entry) => !current.has(keyOf(entry)),
)

if (unexpected.length) {
  console.error(`lint: FAILED — ${unexpected.length} new violation(s)`)
  for (const violation of unexpected) {
    console.error(
      `  ${violation.file}:${violation.line}  ${violation.rule}  ${violation.message}`,
    )
  }
  console.error(
    "Fix the violation. Do not add it to the baseline without review.",
  )
  process.exit(1)
}

console.log(
  `lint: OK — ${violations.length} known baseline violation(s), 0 new; ${stale.length} stale`,
)
if (stale.length) {
  console.log("lint: stale baseline entries (remove on next touch):")
  for (const entry of stale) {
    console.log(`  ${entry.file}:${entry.line}  ${entry.rule}`)
  }
}
