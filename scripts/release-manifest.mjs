#!/usr/bin/env node
// Build the release manifest for one commit.
//
// Usage:
//   node scripts/release-manifest.mjs --sha <40-hex> --ref staging|main
//                                    [--dist dist] [--server server/src]
//                                    [--migrations supabase/migrations]
//                                    [--output release-manifest.json]
//
// The manifest records a digest of each of the four application bundles, the
// backend source tree, the API and worker entry points, and the migration set.

import { writeFileSync } from "node:fs"

import { createReleaseManifest } from "./lib/release-manifest.mjs"

function valueOf(flag, fallback) {
  const index = process.argv.indexOf(flag)
  if (index !== -1 && process.argv[index + 1]) return process.argv[index + 1]
  return fallback
}

const releaseSha = valueOf("--sha", process.env.GITHUB_SHA)
const releaseRef = valueOf("--ref", process.env.GITHUB_REF_NAME)
const output = valueOf("--output", "release-manifest.json")

try {
  const manifest = createReleaseManifest({
    releaseSha,
    releaseRef,
    distDir: valueOf("--dist", "dist"),
    serverDir: valueOf("--server", "server/src"),
    migrationsDir: valueOf("--migrations", "supabase/migrations"),
  })

  writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`)
  console.log(
    `release-manifest: wrote ${output} for ${manifest.releaseSha.slice(0, 7)} (${manifest.releaseRef})`,
  )
  for (const [name, bundle] of Object.entries(manifest.bundles)) {
    console.log(`  ${name.padEnd(8)} ${bundle.digest}  ${bundle.files} file(s)`)
  }
  console.log(`  backend  ${manifest.backend.digest}`)
  console.log(
    `  migrate  ${manifest.migrations.digest}  ${manifest.migrations.files} file(s)`,
  )
} catch (error) {
  console.error(
    `release-manifest: FAILED — ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exit(1)
}
