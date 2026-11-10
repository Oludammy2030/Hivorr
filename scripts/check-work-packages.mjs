#!/usr/bin/env node
// Work-package governance gate (EES §8.1).
//
// Enforces the identifier allocation rule so a phase plan and the task folder
// cannot drift apart:
// - one plan per phase, one identifier per package;
// - identifiers match EP-<phase>-<nnn> and stay inside their phase;
// - EP-00 is contiguous (000..max); EP-01 uses ten-wide stage blocks;
// - every document under documents/Task-Implementation belongs to a plan item,
//   so a package added during execution must be added to the plan in the same
//   change.
//
// Usage:
//   node scripts/check-work-packages.mjs
//   node scripts/check-work-packages.mjs --root <fixture>   # negative tests

import { readdirSync, readFileSync, statSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const args = process.argv.slice(2)
const rootArgument = args.indexOf("--root")
const root =
  rootArgument >= 0
    ? path.resolve(args[rootArgument + 1] ?? "")
    : path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const planDirectory = path.join(
  root,
  "documents/Engineering-Execution/Engineering-Phase-Plan",
)
const taskDirectory = path.join(root, "documents/Task-Implementation")

// EP-00 predates the block scheme and was allocated contiguously. EP-01 is the
// documented ten-wide stage-block exception. New phases default to contiguous.
const schemes = new Map([
  ["EP-00", "contiguous"],
  ["EP-01", "stage-blocks"],
])

const errors = []

function fail(message) {
  errors.push(message)
}

function relative(file) {
  return path.relative(root, file).replaceAll("\\", "/")
}

function markdownFiles(directory) {
  return readdirSync(directory)
    .filter((name) => name.endsWith(".md"))
    .map((name) => path.join(directory, name))
}

function padding(number) {
  return String(number).padStart(3, "0")
}

const planIds = new Map()
const phasePlans = new Map()

for (const file of markdownFiles(planDirectory)) {
  const phaseMatch = /^(EP-\d{2})\b/.exec(path.basename(file))
  if (!phaseMatch) continue

  const phase = phaseMatch[1]
  if (phasePlans.has(phase)) {
    fail(`${relative(file)}: second phase plan for ${phase}`)
    continue
  }

  const entries = []
  let stage = null
  const lines = readFileSync(file, "utf8").split(/\r?\n/)

  lines.forEach((line, index) => {
    const stageMatch = /^###\s+Stage\s+([A-Z])\b/.exec(line)
    if (stageMatch) stage = stageMatch[1]

    const itemMatch = /^####\s+(EP-\d{2}-\d{3})\b/.exec(line)
    if (!itemMatch) return

    const id = itemMatch[1]
    const idPhase = id.slice(0, 5)
    if (idPhase !== phase)
      fail(
        `${relative(file)}:${index + 1}: ${id} belongs to ${idPhase}, not ${phase}`,
      )
    if (planIds.has(id))
      fail(
        `${relative(file)}:${index + 1}: duplicate ${id}, already in ${relative(
          planIds.get(id),
        )}`,
      )

    planIds.set(id, file)
    entries.push({
      id,
      number: Number(id.slice(6)),
      stage,
      line: index + 1,
    })
  })

  if (entries.length === 0)
    fail(`${relative(file)}: no work-package headings found`)

  phasePlans.set(phase, { file, entries })
}

for (const [phase, { file, entries }] of phasePlans) {
  const scheme = schemes.get(phase) ?? "contiguous"
  const numbers = [...new Set(entries.map((entry) => entry.number))].sort(
    (a, b) => a - b,
  )

  if (scheme === "contiguous") {
    const min = numbers[0]
    const max = numbers.at(-1)
    const present = new Set(numbers)
    const missing = []
    for (let number = min; number <= max; number += 1)
      if (!present.has(number)) missing.push(padding(number))

    if (missing.length)
      fail(
        `${relative(file)}: ${phase} is contiguous but missing ${missing.join(", ")}`,
      )
    continue
  }

  for (const entry of entries) {
    if (!entry.stage) {
      fail(
        `${relative(file)}:${entry.line}: ${entry.id} is outside a Stage heading`,
      )
      continue
    }

    const stageIndex = entry.stage.charCodeAt(0) - "A".charCodeAt(0)
    const block = Math.floor(entry.number / 10)
    if (stageIndex !== block)
      fail(
        `${relative(file)}:${entry.line}: ${entry.id} is in Stage ${
          entry.stage
        } but belongs to block ${padding(block * 10)}–${padding(block * 10 + 9)}`,
      )
  }
}

function walk(directory) {
  const files = []
  for (const name of readdirSync(directory)) {
    const file = path.join(directory, name)
    if (statSync(file).isDirectory()) files.push(...walk(file))
    else files.push(file)
  }
  return files
}

for (const file of walk(taskDirectory)) {
  const match = /^(EP-\d{2}-\d{3})\b/.exec(path.basename(file))
  if (!match) continue

  const id = match[1]
  if (!planIds.has(id))
    fail(`${relative(file)}: ${id} has no heading in its phase plan`)
}

if (errors.length) {
  console.error("work-package governance: FAIL")
  for (const error of errors) console.error(`  - ${error}`)
  process.exit(1)
}

const total = [...phasePlans.values()].reduce(
  (sum, plan) => sum + plan.entries.length,
  0,
)
console.log(
  `work-package governance: PASS (${phasePlans.size} phase plans, ${total} allocated identifiers)`,
)
