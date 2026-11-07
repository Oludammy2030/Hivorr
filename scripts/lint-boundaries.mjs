#!/usr/bin/env node
// Enforce the workspace import boundaries from ARCHITECTURE.md §14.
//
// These are structural checks, not a type system. They fail fast on the two
// mistakes that matter most: one portal importing another, and a portal or
// shared package importing the server.

import { readdirSync, readFileSync, statSync } from "node:fs"
import path from "node:path"

const root = process.cwd()
const sourceExtensions = new Set([".ts", ".tsx", ".mts", ".cts"])

function walk(directory) {
  const entries = readdirSync(directory)
  for (const entry of entries) {
    if (entry === "node_modules" || entry === "dist" || entry.startsWith("."))
      continue
    const full = path.join(directory, entry)
    const stat = statSync(full)
    if (stat.isDirectory()) {
      walk(full)
    } else if (sourceExtensions.has(path.extname(full))) {
      files.push(full)
    }
  }
}

const files = []
for (const directory of ["apps", "packages", "server"]) {
  const full = path.join(root, directory)
  try {
    if (statSync(full).isDirectory()) walk(full)
  } catch {
    // A workspace folder may not exist yet; nothing to check.
  }
}

function areaOf(file) {
  const relative = path.relative(root, file).split(path.sep).join("/")
  if (relative.startsWith("apps/")) return "app"
  if (relative.startsWith("server/")) return "server"
  if (relative.startsWith("packages/shared/")) return "shared"
  if (relative.startsWith("packages/design/")) return "design"
  if (relative.startsWith("packages/api-client/")) return "api-client"
  return "other"
}

const rules = [
  {
    area: "app",
    pattern: /from\s+['"](@hivorr\/app-|@hivorr\/server)/,
    message: "an app may not import another app or the server",
  },
  {
    area: "app",
    pattern: /from\s+['"](?:\.\.?\/)+(?:\.\.\/)*(?:apps|server)\//,
    message: "an app may not import another app or the server by path",
  },
  {
    area: "app",
    pattern: /from\s+['"](?:\.\.?\/)+(?:\.\.\/)*src\//,
    message:
      "an app may not import the prototype source by path; use @hivorr/design",
  },
  {
    area: "server",
    pattern: /from\s+['"](@hivorr\/app-|(?:\.\.?\/)+(?:\.\.\/)*apps\/)/,
    message: "the server may not import a portal application",
  },
  {
    area: "shared",
    pattern: /from\s+['"](react|react-dom|@hivorr\/|node:)/,
    message: "the shared package must stay framework-free and server-free",
  },
  {
    area: "design",
    pattern: /from\s+['"](@hivorr\/server|@hivorr\/app-)/,
    message: "the design package may not import the server or an app",
  },
  {
    area: "api-client",
    pattern: /from\s+['"](@hivorr\/server|@hivorr\/app-)/,
    message: "the API client may not import the server or an app",
  },
]

const violations = []

for (const file of files) {
  const area = areaOf(file)
  const contents = readFileSync(file, "utf8")
  const lines = contents.split("\n")
  for (const rule of rules) {
    if (rule.area !== area) continue
    lines.forEach((line, index) => {
      if (rule.pattern.test(line)) {
        violations.push(
          `${path.relative(root, file)}:${index + 1} — ${rule.message}\n    ${line.trim()}`,
        )
      }
    })
  }
}

if (violations.length > 0) {
  console.error("lint:boundaries: found workspace boundary violations\n")
  for (const violation of violations) console.error(violation)
  process.exit(1)
}

console.log(
  `lint:boundaries: OK — ${files.length} workspace source file(s) checked`,
)
