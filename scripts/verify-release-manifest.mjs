#!/usr/bin/env node
// Verify that artifacts and source on disk match a release manifest.
//
// Usage:
//   node scripts/verify-release-manifest.mjs --manifest <file> [--sha <hex>]
//                                            [--dist dist] [--server server/src]
//                                            [--migrations supabase/migrations]
//
// Any added, removed, renamed, or edited file changes a digest and fails the
// check. Production runs this on the downloaded staging artifact and refuses to
// continue on a mismatch.

import { readFileSync } from "node:fs"

import { verifyReleaseManifest } from "./lib/release-manifest.mjs"

function valueOf(flag, fallback) {
  const index = process.argv.indexOf(flag)
  if (index !== -1 && process.argv[index + 1]) return process.argv[index + 1]
  return fallback
}

const manifestPath = valueOf("--manifest", "release-manifest.json")

let manifest
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"))
} catch (error) {
  console.error(
    `verify-release-manifest: FAILED — cannot read ${manifestPath}: ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exit(2)
}

const result = verifyReleaseManifest(manifest, {
  releaseSha: valueOf("--sha", undefined),
  releaseRef: valueOf("--ref", undefined),
  distDir: valueOf("--dist", "dist"),
  serverDir: valueOf("--server", "server/src"),
  migrationsDir: valueOf("--migrations", "supabase/migrations"),
})

if (!result.ok) {
  console.error("verify-release-manifest: REFUSED")
  for (const issue of result.issues) console.error(`- ${issue}`)
  process.exit(1)
}

console.log(
  `verify-release-manifest: OK — ${result.summary.releaseSha} (${result.summary.releaseRef}), bundles: ${result.summary.bundles.join(", ")}`,
)
