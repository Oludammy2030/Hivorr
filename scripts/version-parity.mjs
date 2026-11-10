#!/usr/bin/env node
// Toolchain parity gate (EP-00-002).
//
// The contract lives in package.json: `packageManager` and `engines`. This
// script makes a wrong Node or pnpm version fail loudly on a workstation and in
// CI instead of silently resolving a different tree.
//
// Usage:
//   node scripts/version-parity.mjs
//   node scripts/version-parity.mjs --node=20.0.0 --pnpm=10.34.3   # negative test

import { execFileSync } from "node:child_process"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import path from "node:path"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const manifest = JSON.parse(
  readFileSync(path.join(root, "package.json"), "utf8"),
)

const args = new Map(
  process.argv
    .slice(2)
    .filter((arg) => arg.startsWith("--"))
    .map((arg) => {
      const [key, value = ""] = arg.slice(2).split("=")
      return [key, value]
    }),
)

function commandVersion(command, commandArgs) {
  return execFileSync(command, commandArgs, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    // Windows cannot exec a .cmd shim without a shell.
    shell: process.platform === "win32",
  }).trim()
}

// Corepack and npm expose pnpm as `pnpm.cmd` on Windows; mise and other
// version managers expose `pnpm.exe`, which the shell resolves from `pnpm`.
// Try both so a correctly pinned toolchain is not reported as missing.
function pnpmVersionValue() {
  const override = args.get("pnpm")
  if (override) return override

  const candidates =
    process.platform === "win32" ? ["pnpm.cmd", "pnpm"] : ["pnpm"]
  const failures = []
  for (const command of candidates) {
    try {
      return commandVersion(command, ["--version"])
    } catch (error) {
      failures.push(error instanceof Error ? error.message : String(error))
    }
  }

  console.error(
    `toolchain: cannot read the pnpm version: ${failures.join("; ")}`,
  )
  process.exit(2)
}

function parseExact(value) {
  const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(value)
  return match ? match.slice(1).map(Number) : null
}

const nodeVersion = args.get("node") || process.version.replace(/^v/, "")
const pnpmVersion = pnpmVersionValue()

const expectedPnpm = String(manifest.packageManager || "").replace(/^pnpm@/, "")
const expectedNodeRange = String(manifest.engines?.node || "")
const nodeMajor = Number(String(nodeVersion).split(".")[0])
const expectedMajorMatch = /(?:>=|\^)?(\d+)\./.exec(expectedNodeRange)
const expectedNodeMajor = expectedMajorMatch
  ? Number(expectedMajorMatch[1])
  : null

const failures = []

if (!expectedPnpm) {
  failures.push("package.json has no packageManager field")
} else if (pnpmVersion !== expectedPnpm) {
  failures.push(`pnpm is ${pnpmVersion}; packageManager pins ${expectedPnpm}`)
}

if (!parseExact(nodeVersion)) {
  failures.push(`Node version "${nodeVersion}" is not a semver x.y.z value`)
} else if (expectedNodeMajor !== null && nodeMajor !== expectedNodeMajor) {
  failures.push(
    `Node is ${nodeVersion}; engines.node requires ${expectedNodeRange}`,
  )
}

if (failures.length) {
  console.error("toolchain: FAILED — the pinned contract is not satisfied")
  for (const failure of failures) console.error(`  - ${failure}`)
  console.error(
    "Install the pinned toolchain (see DEVELOPER_BOOTSTRAP.md) and retry.",
  )
  process.exit(1)
}

console.log(`toolchain: OK — node ${nodeVersion}, pnpm ${pnpmVersion}`)
console.log(
  `toolchain: contract node ${expectedNodeRange}, pnpm ${expectedPnpm}`,
)
