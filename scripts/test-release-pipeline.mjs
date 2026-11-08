#!/usr/bin/env node
// Tests for the release manifest and founder-approval policy.
//
// Builds a throwaway artifact tree under the OS temp directory, generates a
// manifest, verifies it, then proves that tampering is detected. Also exercises
// the approval decision logic without touching GitHub.

import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"

import {
  createReleaseManifest,
  verifyReleaseManifest,
} from "./lib/release-manifest.mjs"
import {
  evaluateFounderApproval,
  parseApprovalCommand,
} from "./lib/founder-approval.mjs"

const SHA = "0123456789abcdef0123456789abcdef01234567"
const OTHER_SHA = "fedcba9876543210fedcba9876543210fedcba98"
const temp = mkdtempSync(path.join(tmpdir(), "hivorr-release-test-"))
const failures = []

function check(name, condition, detail = "") {
  if (condition) {
    console.log(`PASS  ${name}`)
  } else {
    console.log(`FAIL  ${name}${detail ? `\n${detail}` : ""}`)
    failures.push(name)
  }
}

function write(relative, contents) {
  const full = path.join(temp, relative)
  mkdirSync(path.dirname(full), { recursive: true })
  writeFileSync(full, contents)
}

function fixture() {
  write("dist/index.html", "<!doctype html><title>Hivorr</title>")
  write("dist/assets/app.js", "console.log('main')\n")
  write(
    "dist/portals/control/index.html",
    "<!doctype html><title>Control</title>",
  )
  write("dist/portals/control/assets/control.js", "console.log('control')\n")
  write("dist/portals/staff/index.html", "<!doctype html><title>Staff</title>")
  write("dist/portals/staff/assets/staff.js", "console.log('staff')\n")
  write(
    "dist/portals/partner/index.html",
    "<!doctype html><title>Partner</title>",
  )
  write("dist/portals/partner/assets/partner.js", "console.log('partner')\n")
  write("server/src/main.ts", "export const entry = 'api'\n")
  write("server/src/worker.ts", "export const entry = 'worker'\n")
  write("server/src/db/pool.ts", "export const pool = true\n")
  write(
    "supabase/migrations/001_init.sql",
    "create schema if not exists test;\n",
  )
  write("supabase/migrations/002_more.sql", "create table test.t (id int);\n")
}

try {
  fixture()

  const manifest = createReleaseManifest({
    releaseSha: SHA,
    releaseRef: "staging",
    distDir: path.join(temp, "dist"),
    serverDir: path.join(temp, "server", "src"),
    migrationsDir: path.join(temp, "supabase", "migrations"),
    generatedAt: "2026-11-08T00:00:00.000Z",
  })

  check(
    "manifest covers four bundles",
    Object.keys(manifest.bundles).join(",") === "main,control,staff,partner",
  )
  check(
    "main bundle excludes nested portals",
    manifest.bundles.main.files === 2,
    `main had ${manifest.bundles.main.files} file(s)`,
  )
  check(
    "portal bundle records its own files",
    manifest.bundles.control.files === 2,
  )
  check(
    "migration set is represented",
    manifest.migrations.files === 2 &&
      manifest.migrations.digest.startsWith("sha256:"),
  )

  const options = {
    releaseSha: SHA,
    distDir: path.join(temp, "dist"),
    serverDir: path.join(temp, "server", "src"),
    migrationsDir: path.join(temp, "supabase", "migrations"),
  }

  const first = verifyReleaseManifest(manifest, options)
  check(
    "verification accepts the generated manifest",
    first.ok,
    first.issues.join("\n"),
  )

  const second = createReleaseManifest({
    releaseSha: SHA,
    releaseRef: "staging",
    distDir: path.join(temp, "dist"),
    serverDir: path.join(temp, "server", "src"),
    migrationsDir: path.join(temp, "supabase", "migrations"),
  })
  check(
    "digests are deterministic across runs",
    JSON.stringify(second.bundles) === JSON.stringify(manifest.bundles),
  )

  write("dist/portals/control/assets/control.js", "console.log('tampered')\n")
  const tampered = verifyReleaseManifest(manifest, options)
  check(
    "edited portal bundle is refused",
    !tampered.ok &&
      tampered.issues.some((issue) => issue.includes("control bundle digest")),
    tampered.issues.join("\n"),
  )
  write("dist/portals/control/assets/control.js", "console.log('control')\n")

  write("dist/assets/extra.js", "console.log('extra')\n")
  const extra = verifyReleaseManifest(manifest, options)
  check(
    "extra main bundle file is refused",
    !extra.ok &&
      extra.issues.some((issue) => issue.includes("main bundle digest")),
    extra.issues.join("\n"),
  )
  rmSync(path.join(temp, "dist", "assets", "extra.js"))

  write("server/src/main.ts", "export const entry = 'changed'\n")
  const sourceChanged = verifyReleaseManifest(manifest, options)
  check(
    "edited backend source is refused",
    !sourceChanged.ok &&
      sourceChanged.issues.some((issue) =>
        issue.includes("backend source digest"),
      ),
    sourceChanged.issues.join("\n"),
  )
  write("server/src/main.ts", "export const entry = 'api'\n")

  write("supabase/migrations/003_late.sql", "select 1;\n")
  const migrationChanged = verifyReleaseManifest(manifest, options)
  check(
    "extra migration is refused",
    !migrationChanged.ok &&
      migrationChanged.issues.some((issue) =>
        issue.includes("migration set digest"),
      ),
    migrationChanged.issues.join("\n"),
  )
  rmSync(path.join(temp, "supabase", "migrations", "003_late.sql"))

  const wrongSha = verifyReleaseManifest(manifest, {
    ...options,
    releaseSha: OTHER_SHA,
  })
  check(
    "a different requested SHA is refused",
    !wrongSha.ok &&
      wrongSha.issues.some((issue) =>
        issue.includes("does not match requested"),
      ),
  )

  const missingBundle = verifyReleaseManifest(manifest, {
    ...options,
    distDir: path.join(temp, "server"),
  })
  check("missing artifacts are refused", !missingBundle.ok)

  check(
    "approval command parses the exact form",
    parseApprovalCommand(`/approve-release ${SHA}`) === SHA,
  )
  check(
    "approval command rejects extra words",
    parseApprovalCommand(`/approve-release ${SHA} please`) === null,
  )
  check(
    "approval command rejects a short SHA",
    parseApprovalCommand("/approve-release 0123456") === null,
  )
  check(
    "approval command ignores later lines",
    parseApprovalCommand(`looks good\n/approve-release ${SHA}`) === null,
  )

  const baseIssue = {
    number: 42,
    body: `Release SHA: ${SHA}`,
    labels: [{ name: "release-candidate" }],
  }
  const founderComment = (sha, id, created = "2026-11-08T10:00:00Z") => ({
    id,
    body: sha ? `/approve-release ${sha}` : "looks good",
    created_at: created,
    user: { login: "founder" },
  })

  const approved = evaluateFounderApproval({
    issue: baseIssue,
    comments: [founderComment(SHA, 1)],
    founderLogin: "founder",
    releaseSha: SHA,
  })
  check(
    "founder approval of the exact SHA is accepted",
    approved.ok,
    approved.issues.join("\n"),
  )

  const notFounder = evaluateFounderApproval({
    issue: baseIssue,
    comments: [
      {
        id: 2,
        body: `/approve-release ${SHA}`,
        created_at: "2026-11-08T10:00:00Z",
        user: { login: "someone-else" },
      },
    ],
    founderLogin: "founder",
    releaseSha: SHA,
  })
  check("approval from another account is refused", !notFounder.ok)

  const wrongApproval = evaluateFounderApproval({
    issue: baseIssue,
    comments: [founderComment(OTHER_SHA, 3)],
    founderLogin: "founder",
    releaseSha: SHA,
  })
  check("approval of a different SHA is refused", !wrongApproval.ok)

  const superseded = evaluateFounderApproval({
    issue: baseIssue,
    comments: [
      founderComment(SHA, 4, "2026-11-08T10:00:00Z"),
      founderComment(OTHER_SHA, 5, "2026-11-08T11:00:00Z"),
    ],
    founderLogin: "founder",
    releaseSha: SHA,
  })
  check("a later approval for another SHA supersedes", !superseded.ok)

  const wrongLabel = evaluateFounderApproval({
    issue: { ...baseIssue, labels: [{ name: "bug" }] },
    comments: [founderComment(SHA, 6)],
    founderLogin: "founder",
    releaseSha: SHA,
  })
  check("an unlabelled issue is refused", !wrongLabel.ok)

  const wrongBody = evaluateFounderApproval({
    issue: { ...baseIssue, body: "Release SHA: unknown" },
    comments: [founderComment(SHA, 7)],
    founderLogin: "founder",
    releaseSha: SHA,
  })
  check("an issue for another release is refused", !wrongBody.ok)

  const noCommand = evaluateFounderApproval({
    issue: baseIssue,
    comments: [founderComment(null, 8)],
    founderLogin: "founder",
    releaseSha: SHA,
  })
  check("a plain approval comment is refused", !noCommand.ok)
} catch (error) {
  console.error(error instanceof Error ? error.stack : String(error))
  failures.push("test harness")
} finally {
  rmSync(temp, { recursive: true, force: true })
}

if (failures.length) {
  console.error(`\n${failures.length} release-pipeline check(s) failed.`)
  process.exit(1)
}

console.log("\nAll release-pipeline checks passed.")
