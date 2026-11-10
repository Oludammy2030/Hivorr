#!/usr/bin/env node
// Visual-regression comparison gate (EP-01-004).
//
// Compares a baseline directory of PNG screenshots with the current run and
// reports added, removed, resized and pixel-changed images. EP-01-050 owns the
// screenshot harness and the first baseline; until `visual/baseline` exists the
// gate is dormant and says so.
//
// Usage:
//   node scripts/visual-diff.mjs
//   node scripts/visual-diff.mjs --baseline <dir> --current <dir> --fail-on-diff
//   node scripts/visual-diff.mjs --threshold 0.001 --pixel-tolerance 2

import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs"
import path from "node:path"

import { decodePng } from "./lib/png.mjs"

const args = process.argv.slice(2)
let baselineDirectory = path.join("visual", "baseline")
let currentDirectory = path.join("visual", "current")
let out = ""
let threshold = 0.001
let pixelTolerance = 0
let failOnDiff = false

for (let index = 0; index < args.length; index += 1) {
  const next = args[index + 1]
  if (args[index] === "--baseline" && next) {
    baselineDirectory = next
    index += 1
  } else if (args[index] === "--current" && next) {
    currentDirectory = next
    index += 1
  } else if (args[index] === "--out" && next) {
    out = next
    index += 1
  } else if (args[index] === "--threshold" && next) {
    threshold = Number(next)
    index += 1
  } else if (args[index] === "--pixel-tolerance" && next) {
    pixelTolerance = Number(next)
    index += 1
  } else if (args[index] === "--fail-on-diff") {
    failOnDiff = true
  }
}

if (!Number.isFinite(threshold) || threshold < 0) {
  console.error("visual:check: --threshold must be a non-negative number")
  process.exit(2)
}
if (!Number.isFinite(pixelTolerance) || pixelTolerance < 0) {
  console.error("visual:check: --pixel-tolerance must be a non-negative number")
  process.exit(2)
}

function imagesIn(directory) {
  if (!existsSync(directory)) return new Map()
  const found = new Map()
  for (const entry of readdirSync(directory, { recursive: true })) {
    if (!entry.toLowerCase().endsWith(".png")) continue
    const relative = entry.split(path.sep).join("/")
    found.set(relative, path.join(directory, entry))
  }
  return found
}

const baseline = imagesIn(baselineDirectory)
const current = imagesIn(currentDirectory)

function reportAndExit(markdown) {
  console.log(markdown)
  if (out) {
    mkdirSync(path.dirname(path.resolve(out)), { recursive: true })
    writeFileSync(out, `${markdown}\n`)
    console.log(`visual:check: wrote ${out}`)
  }
}

if (baseline.size === 0) {
  reportAndExit(
    [
      "# Visual regression",
      "",
      `No baseline images at \`${baselineDirectory}\`.`,
      "The gate is **dormant** until EP-01-050 publishes the first baseline.",
      "",
    ].join("\n"),
  )
  process.exit(0)
}

const removed = []
const added = []
const changed = []

for (const [name, file] of baseline) {
  if (!current.has(name)) {
    removed.push(name)
    continue
  }

  const left = decodePng(readFileSync(file))
  const right = decodePng(readFileSync(current.get(name)))

  if (left.width !== right.width || left.height !== right.height) {
    changed.push({
      name,
      reason: `size ${left.width}x${left.height} -> ${right.width}x${right.height}`,
      ratio: 1,
    })
    continue
  }
  if (left.channels !== right.channels) {
    changed.push({
      name,
      reason: `channel count ${left.channels} -> ${right.channels}`,
      ratio: 1,
    })
    continue
  }

  const pixels = left.width * left.height
  let differing = 0
  for (let index = 0; index < pixels; index += 1) {
    const offset = index * left.channels
    let different = false
    for (let channel = 0; channel < left.channels; channel += 1) {
      if (
        Math.abs(left.data[offset + channel] - right.data[offset + channel]) >
        pixelTolerance
      ) {
        different = true
        break
      }
    }
    if (different) differing += 1
  }

  const ratio = differing / pixels
  if (ratio > threshold) {
    changed.push({
      name,
      reason: `${differing} of ${pixels} pixels differ (${(ratio * 100).toFixed(3)}%)`,
      ratio,
    })
  }
}

for (const name of current.keys()) {
  if (!baseline.has(name)) added.push(name)
}

const differences = removed.length + added.length + changed.length

const report = [
  "# Visual regression",
  "",
  `- Baseline: \`${baselineDirectory}\` (${baseline.size} image(s))`,
  `- Current: \`${currentDirectory}\` (${current.size} image(s))`,
  `- Threshold: ${(threshold * 100).toFixed(3)}% of pixels, tolerance ${pixelTolerance}/channel`,
  `- Differences: **${differences}**`,
  "",
  "## Removed from the current run",
  "",
  ...(removed.length ? removed.map((name) => `- \`${name}\``) : ["_None._"]),
  "",
  "## Added without a baseline",
  "",
  ...(added.length ? added.map((name) => `- \`${name}\``) : ["_None._"]),
  "",
  "## Changed",
  "",
  ...(changed.length
    ? changed.map((entry) => `- \`${entry.name}\` — ${entry.reason}`)
    : ["_None._"]),
  "",
].join("\n")

reportAndExit(report)

if (differences) {
  if (failOnDiff) {
    console.error(
      `visual:check: ${differences} visual difference(s) fail the gate`,
    )
    process.exit(1)
  }
  console.log(
    `visual:check: ${differences} visual difference(s) — review required`,
  )
} else {
  console.log("visual:check: no visual change")
}
