#!/usr/bin/env node
// Formats exactly the files the gate checks: those changed relative to the base
// commit. Running `oxfmt` with no arguments would reformat the whole tree,
// including the prototype, which is the visual authority and must not change.
//
// Explicit paths are honoured when supplied:
//   pnpm format src/features/wallet/screens.tsx

import { spawnSync } from "node:child_process"

import { OXFMT, changedFormattableFiles } from "./format-files.mjs"

const explicit = process.argv.slice(2)
const { base, files } = changedFormattableFiles()
const targets = explicit.length > 0 ? explicit : files

if (targets.length === 0) {
  console.log(`format: no changed formattable files relative to ${base}`)
  process.exit(0)
}

// Run the package's Node entry point directly. It is portable and avoids the
// Windows .cmd shim, which Node 22 refuses to spawn without a shell.
const result = spawnSync(process.execPath, [OXFMT, ...targets], {
  stdio: "inherit",
})

process.exit(result.status ?? 1)
