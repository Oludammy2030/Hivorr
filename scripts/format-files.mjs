// Shared changed-file selection for the format gate and the format command.
//
// The prototype is the visual authority and must not be reformatted. Both
// scripts therefore consider only files changed relative to the base commit, so
// `pnpm format` can never rewrite an untouched file (EP-00-004).

import { execFileSync } from "node:child_process"
import path from "node:path"
import { fileURLToPath } from "node:url"

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")

export const OXFMT = path.join(root, "node_modules", "oxfmt", "bin", "oxfmt")

/** oxfmt formats JavaScript and TypeScript; JSON, CSS and Markdown are not gated. */
export const FORMATTABLE = /\.(?:[cm]?[jt]sx?)$/i

/** The API client is generated from OpenAPI; `openapi:check` owns its drift. */
export const GENERATED = new Set(["packages/api-client/src/index.ts"])

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

/**
 * Base selection: FORMAT_BASE (set by CI), otherwise origin/main, otherwise
 * HEAD~1. Uncommitted and staged files are always included.
 */
export function changedFormattableFiles() {
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

  const files = [...changed].filter((file) => FORMATTABLE.test(file) && !GENERATED.has(file)).sort()

  return { base, files }
}
