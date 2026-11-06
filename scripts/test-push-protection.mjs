#!/usr/bin/env node
// Integration test for the protected-branch pre-push hook.
//
// Creates a throwaway bare remote and working clone under the OS temp directory.
// It never touches the real repository or its remote.

import { execFileSync, spawnSync } from "node:child_process"
import { cpSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const temp = mkdtempSync(path.join(tmpdir(), "hivorr-push-protection-"))
const remote = path.join(temp, "remote.git")
const work = path.join(temp, "work")
const failures = []

function git(args, cwd = work, allowFailure = false) {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" })
  if (!allowFailure && result.status !== 0) {
    throw new Error(
      `git ${args.join(" ")} failed:\n${result.stdout}${result.stderr}`,
    )
  }
  return result
}

function check(name, condition, detail = "") {
  if (condition) {
    console.log(`PASS  ${name}`)
  } else {
    console.log(`FAIL  ${name}${detail ? `\n${detail}` : ""}`)
    failures.push(name)
  }
}

try {
  execFileSync("git", ["init", "--bare", remote], { stdio: "ignore" })
  execFileSync("git", ["init", "--initial-branch=main", work], {
    stdio: "ignore",
  })
  git(["config", "user.name", "EP-00 push test"])
  git(["config", "user.email", "push-test@example.invalid"])
  writeFileSync(path.join(work, "README.md"), "# push protection test\n")
  git(["add", "README.md"])
  git(["commit", "-m", "seed"])
  git(["remote", "add", "origin", remote])
  git(["push", "origin", "main"])
  git(["push", "origin", "main:staging"])

  for (const file of [
    ".githooks/pre-push",
    "scripts/pre-push.mjs",
    "scripts/lib/push-policy.mjs",
    "scripts/protected-branches.json",
    "scripts/secret-scan.mjs",
  ]) {
    cpSync(path.join(root, file), path.join(work, file), { recursive: true })
  }
  git(["config", "core.hooksPath", ".githooks"])

  git(["checkout", "-b", "feature/test"])
  writeFileSync(path.join(work, "feature.txt"), "feature work\n")
  git(["add", "feature.txt"])
  git(["commit", "-m", "feature change"])
  let result = git(["push", "origin", "feature/test"], work, true)
  check("permitted feature push succeeds", result.status === 0, result.stderr)

  git(["checkout", "main"])
  writeFileSync(path.join(work, "main.txt"), "direct main change\n")
  git(["add", "main.txt"])
  git(["commit", "-m", "direct main change"])
  result = git(["push", "origin", "main"], work, true)
  check(
    "direct main push is rejected",
    result.status !== 0 && /BLOCKED/.test(result.stderr),
    result.stderr,
  )

  git(["push", "--force", "origin", "main"], work, true)
  result = git(["push", "--force", "origin", "main"], work, true)
  check(
    "force push to main is rejected",
    result.status !== 0 && /BLOCKED/.test(result.stderr),
    result.stderr,
  )

  result = git(["push", "origin", ":main"], work, true)
  check(
    "deleting main is rejected",
    result.status !== 0 && /BLOCKED/.test(result.stderr),
    result.stderr,
  )

  git(["checkout", "-b", "staging", "origin/staging"])
  writeFileSync(path.join(work, "staging.txt"), "direct staging change\n")
  git(["add", "staging.txt"])
  git(["commit", "-m", "direct staging change"])
  result = git(["push", "origin", "staging"], work, true)
  check(
    "direct staging push is rejected",
    result.status !== 0 && /BLOCKED/.test(result.stderr),
    result.stderr,
  )

  git(["checkout", "feature/test"])
  const fakeToken = `ghp_${"0".repeat(36)}`
  writeFileSync(path.join(work, "leak.txt"), `token = ${fakeToken}\n`)
  git(["add", "leak.txt"])
  git(["commit", "-m", "seeded secret"])
  result = git(["push", "origin", "feature/test"], work, true)
  check(
    "secret-shaped content is rejected on a feature push",
    result.status !== 0 && /secret-scan: blocked/.test(result.stderr),
    result.stderr,
  )
} catch (error) {
  console.error(error instanceof Error ? error.stack : String(error))
  failures.push("integration harness")
} finally {
  rmSync(temp, { recursive: true, force: true })
}

if (failures.length) {
  console.error(`\n${failures.length} push-protection check(s) failed.`)
  process.exit(1)
}

console.log("\nAll push-protection checks passed.")
