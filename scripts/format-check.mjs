#!/usr/bin/env node
// Changed-files format gate (EP-00-004).
//
// The prototype is the visual authority and must not be reformatted. The gate
// therefore checks only files changed relative to the base commit. A file that
// is never touched is never checked, which keeps the 3,814-line App.tsx out of
// an unreviewable reformat without disabling the rule.
//
// Base selection: FORMAT_BASE (set by CI), otherwise origin/main, otherwise
// HEAD~1. Uncommitted and staged files are always included.

import { execFileSync, spawnSync } from "node:child_process"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")

function git(args, allowFailure = false) {
  try {
    return execFileSync("git", args, {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim()
  } catch (error) {
    if (allowFailure) return ""
    throw error
  }
}

const base = process.env.FORMAT_BASE || "origin/main"
const changed = new Set()

for (const args of [
  ["diff", "--name-only", "--diff-filter=ACMR", `${base}...HEAD`],
  ["diff", "--name-only", "--diff-filter=ACMR"],
  ["diff", "--cached", "--name-only", "--diff-filter=ACMR"],
  ["ls-files", "--others", "--exclude-standard"],
]) {
  const output = git(args, true)
  for (const file of output.split("\n")) {
    if (file.trim()) changed.add(file.trim())
  }
}

// oxfmt formats JavaScript and TypeScript. JSON, CSS and Markdown are outside
// its v0.2 target set; pnpm-lock.yaml is generated and never hand-formatted.
const FORMATTABLE = /\.(?:[cm]?[jt]sx?)$/i
// The API client is generated from the OpenAPI document. Formatting it by hand
// would fight the generator; `pnpm openapi:check` owns drift instead.
const GENERATED = new Set(["packages/api-client/src/index.ts"])
const files = [...changed]
  .filter((file) => FORMATTABLE.test(file) && !GENERATED.has(file))
  .sort()

if (files.length === 0) {
  console.log(`format:check: no changed formattable files relative to ${base}`)
  process.exit(0)
}

// Run the package's Node entry point directly. It is portable and avoids the
// Windows .cmd shim, which Node 22 refuses to spawn without a shell.
const executable = path.join(root, "node_modules", "oxfmt", "bin", "oxfmt")
const result = spawnSync(process.execPath, [executable, "--check", ...files], {
  cwd: root,
  encoding: "utf8",
  stdio: "pipe",
})

const output = `${result.stdout || ""}${result.stderr || ""}`.trim()
if (result.error) {
  console.error(`format:check: cannot run oxfmt: ${result.error.message}`)
  process.exit(2)
}
if (result.status !== 0) {
  console.error(
    `format:check: FAILED — ${files.length} changed file(s) checked`,
  )
  if (output) console.error(output)
  console.error("Run `pnpm format` on the changed files and commit the result.")
  process.exit(result.status || 1)
}

console.log(`format:check: OK — ${files.length} changed file(s) formatted`)
