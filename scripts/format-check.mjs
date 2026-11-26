#!/usr/bin/env node
// Changed-files format gate (EP-00-004).
//
// The prototype is the visual authority and must not be reformatted. The gate
// therefore checks only files changed relative to the base commit. A file that
// is never touched is never checked, which keeps the 3,814-line App.tsx out of
// an unreviewable reformat without disabling the rule.
//
// The selection lives in `format-files.mjs` so `pnpm format` and this gate can
// never disagree about which files are in scope.

import { spawnSync } from "node:child_process"

import { OXFMT, changedFormattableFiles } from "./format-files.mjs"

const { base, files } = changedFormattableFiles()

if (files.length === 0) {
  console.log(`format:check: no changed formattable files relative to ${base}`)
  process.exit(0)
}

// Run the package's Node entry point directly. It is portable and avoids the
// Windows .cmd shim, which Node 22 refuses to spawn without a shell.
const result = spawnSync(process.execPath, [OXFMT, "--check", ...files], {
  encoding: "utf8",
  stdio: "pipe",
})

const output = `${result.stdout || ""}${result.stderr || ""}`.trim()
if (result.error) {
  console.error(`format:check: cannot run oxfmt: ${result.error.message}`)
  process.exit(2)
}
if (result.status !== 0) {
  console.error(`format:check: FAILED — ${files.length} changed file(s) checked`)
  if (output) console.error(output)
  console.error("Run `pnpm format` on the changed files and commit the result.")
  process.exit(result.status || 1)
}

console.log(`format:check: OK — ${files.length} changed file(s) formatted`)
