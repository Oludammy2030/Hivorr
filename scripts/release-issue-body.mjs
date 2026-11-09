#!/usr/bin/env node
// Render the release-request Issue body from a manifest.
//
// Environment:
//   RELEASE_SHA       commit under release
//   STAGING_RUN_URL   link to the successful staging workflow run
//   MANIFEST_PATH     path to release-manifest.json (default ./release-manifest.json)
//
// Only digests, counts and public run links are printed. No secret value and no
// connection string ever reaches an issue.

import { readFileSync } from "node:fs"

const releaseSha = process.env.RELEASE_SHA
const runUrl = process.env.STAGING_RUN_URL ?? "not recorded"
const manifestPath = process.env.MANIFEST_PATH ?? "release-manifest.json"

if (!releaseSha) {
  console.error("release-issue-body: RELEASE_SHA is required")
  process.exit(2)
}

let manifest
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"))
} catch (error) {
  console.error(
    `release-issue-body: cannot read ${manifestPath}: ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exit(2)
}

const lines = [
  "## Release request",
  "",
  `- **Release SHA:** \`${releaseSha}\``,
  `- **Staging verified by:** ${runUrl}`,
  `- **Manifest schema:** ${manifest.schemaVersion}`,
  `- **Generated at:** ${manifest.generatedAt}`,
  "",
  "### Application bundles",
  "",
  "| Bundle | Path | Files | Digest |",
  "| --- | --- | --- | --- |",
]

for (const [name, bundle] of Object.entries(manifest.bundles ?? {})) {
  lines.push(
    `| ${name} | \`${bundle.path}\` | ${bundle.files} | \`${bundle.digest}\` |`,
  )
}

lines.push(
  "",
  "### Backend and migrations",
  "",
  "| Component | Digest |",
  "| --- | --- |",
  `| API source (\`${manifest.backend?.path}\`) | \`${manifest.backend?.digest}\` |`,
  `| API entry point | \`${manifest.backend?.apiEntry?.digest}\` |`,
  `| Worker entry point | \`${manifest.backend?.workerEntry?.digest}\` |`,
  `| Migrations (\`${manifest.migrations?.path}\`) | \`${manifest.migrations?.digest}\` |`,
  "",
  "### Founder approval",
  "",
  "Production promotes the exact artifact above. It does not rebuild.",
  "",
  "To approve this release, comment on this issue from the founder account with exactly:",
  "",
  "```",
  `/approve-release ${releaseSha}`,
  "```",
)

process.stdout.write(`${lines.join("\n")}\n`)
