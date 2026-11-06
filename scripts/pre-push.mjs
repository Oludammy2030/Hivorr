#!/usr/bin/env node
// Pre-push policy gate.
//
// Runs two controls in order:
//   1. protected-branch policy: reject direct pushes, deletes and force-pushes;
//   2. secret scan: reject credential-shaped content.
//
// The hook is a cooperative control. It stops accidental pushes from local
// developers and AI agents. It cannot stop a user who disables the hook or
// pushes through the GitHub API; see BRANCH_PROTECTION.md.

import { execFileSync } from "node:child_process"
import { readFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import {
  evaluatePush,
  formatViolations,
  parsePushInput,
} from "./lib/push-policy.mjs"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const config = JSON.parse(
  readFileSync(path.join(root, "scripts", "protected-branches.json"), "utf8"),
)
const protectedBranches = Array.isArray(config.protected)
  ? config.protected
  : []

function isAncestor(ancestor, descendant) {
  if (!ancestor || !descendant) return false
  try {
    execFileSync("git", ["merge-base", "--is-ancestor", ancestor, descendant], {
      cwd: root,
      stdio: "ignore",
    })
    return true
  } catch {
    return false
  }
}

function fail(message, code = 1) {
  console.error(message)
  process.exit(code)
}

let entries
try {
  entries = parsePushInput(readFileSync(0, "utf8"))
} catch (error) {
  fail(
    `pre-push: cannot parse the push description; refusing to continue.\n${
      error instanceof Error ? error.message : String(error)
    }`,
    2,
  )
}

const violations = evaluatePush(entries, protectedBranches, isAncestor)
if (violations.length) {
  fail(formatViolations(violations, config), 1)
}

try {
  execFileSync(
    process.execPath,
    [path.join(root, "scripts", "secret-scan.mjs")],
    {
      cwd: root,
      stdio: "inherit",
    },
  )
} catch {
  fail("pre-push: push blocked by the local secret scan.", 1)
}

console.log("pre-push: policy checks passed")
