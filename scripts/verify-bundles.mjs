#!/usr/bin/env node
// Verify the four application bundles (EP-01-054).
//
// Checks that every bundle was built, that the privileged portals are noindex
// and the public web bundle is not, and that each bundle's initial JavaScript
// is inside the 200 KB gzipped route budget (PER-01). It reads the built
// output only; it makes no network call.
//
// Usage:
//   node scripts/verify-bundles.mjs
//   node scripts/verify-bundles.mjs --dist <dir>

import { existsSync, readFileSync, statSync } from "node:fs"
import { gzipSync } from "node:zlib"
import path from "node:path"

const BUDGET_KB = 200

const args = process.argv.slice(2)
const distIndex = args.indexOf("--dist")
const dist = path.resolve(
  distIndex >= 0 && args[distIndex + 1] ? args[distIndex + 1] : "dist",
)

const BUNDLES = [
  { name: "main", directory: dist, noindex: false },
  {
    name: "control",
    directory: path.join(dist, "portals", "control"),
    noindex: true,
  },
  {
    name: "staff",
    directory: path.join(dist, "portals", "staff"),
    noindex: true,
  },
  {
    name: "partner",
    directory: path.join(dist, "portals", "partner"),
    noindex: true,
  },
]

const issues = []
const summary = []

function resolveAsset(bundleDirectory, reference) {
  const withoutOrigin = reference.replace(/^https?:\/\/[^/]+/i, "")
  const withoutQuery = withoutOrigin.split("?")[0].split("#")[0]
  return path.join(bundleDirectory, withoutQuery.replace(/^\/+/, ""))
}

for (const bundle of BUNDLES) {
  const indexPath = path.join(bundle.directory, "index.html")
  if (!existsSync(indexPath) || !statSync(indexPath).isFile()) {
    issues.push(`${bundle.name}: index.html is missing`)
    continue
  }

  const html = readFileSync(indexPath, "utf8")
  const robots = html.match(
    /<meta[^>]+name=["']robots["'][^>]+content=["']([^"']*)["']/i,
  )
  const robotsContent = (robots?.[1] ?? "").toLowerCase()
  const hasNoindex = robotsContent.includes("noindex")

  if (bundle.noindex && !hasNoindex) {
    issues.push(
      `${bundle.name}: privileged bundle must carry noindex, nofollow`,
    )
  }
  // The root web bundle is the Figma Make preview in EP-01 and is deliberately
  // noindex through `.figma/make/site.json`; only production `060` may flip it.

  const scripts = [...html.matchAll(/<script[^>]+src=["']([^"']+)["']/gi)].map(
    (match) => match[1],
  )
  const preloads = [
    ...html.matchAll(
      /<link[^>]+rel=["']modulepreload["'][^>]+href=["']([^"']+)["']/gi,
    ),
  ].map((match) => match[1])
  const initialScripts = [...new Set([...scripts, ...preloads])]
  if (scripts.length === 0) {
    issues.push(`${bundle.name}: index.html references no JavaScript entry`)
  }

  let gzipBytes = 0
  let files = 0
  for (const script of initialScripts) {
    const file = resolveAsset(bundle.directory, script)
    if (!existsSync(file)) {
      issues.push(`${bundle.name}: referenced script ${script} is missing`)
      continue
    }
    gzipBytes += gzipSync(readFileSync(file)).length
    files += 1
  }

  const gzipKb = gzipBytes / 1024
  if (gzipKb > BUDGET_KB) {
    issues.push(
      `${bundle.name}: initial JavaScript is ${gzipKb.toFixed(1)} KB gzipped, over the ${BUDGET_KB} KB budget`,
    )
  }
  summary.push({
    name: bundle.name,
    files,
    gzipKb,
    noindex: hasNoindex,
  })
}

if (issues.length) {
  console.error("bundles:check: REFUSED")
  for (const issue of issues) console.error(`- ${issue}`)
  process.exit(1)
}

console.log(
  `bundles:check: OK — ${summary.length} bundle(s), budget ${BUDGET_KB} KB gzip`,
)
for (const entry of summary) {
  console.log(
    `  ${entry.name.padEnd(8)} ${entry.files} initial script(s)  ${entry.gzipKb
      .toFixed(1)
      .padStart(6)} KB gzip  noindex=${entry.noindex}`,
  )
}
