#!/usr/bin/env node
// Install the repository hooks for this clone/worktree.
//
// The hooks are committed under .githooks; this command only points git at
// them. It is idempotent and does not change global git configuration.

import { execFileSync } from "node:child_process"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")

execFileSync("git", ["config", "--local", "core.hooksPath", ".githooks"], {
  cwd: root,
  stdio: "inherit",
})

const configured = execFileSync(
  "git",
  ["config", "--local", "--get", "core.hooksPath"],
  {
    cwd: root,
    encoding: "utf8",
  },
).trim()

if (configured !== ".githooks") {
  console.error(`hooks:install: FAILED - core.hooksPath is "${configured}"`)
  process.exit(1)
}

console.log("hooks:install: OK - core.hooksPath=.githooks")
console.log(
  "hooks:install: pre-push now blocks direct pushes to main and staging.",
)
