#!/usr/bin/env node
// Enforce the import and module-ownership boundaries from ARCHITECTURE.md §9.2,
// §9.3 and §14.
//
// Two classes of rule:
//   1. Workspace: a portal may not import another portal or the server; the
//      shared package stays framework-free.
//   2. Server modules: exactly ten modules, one public `index.ts` each, no
//      cross-module repository or table access, no cycles, and activity
//      modules carry no code until their owning phase.
//
// Usage:
//   node scripts/lint-boundaries.mjs
//   node scripts/lint-boundaries.mjs --root <fixture-dir>   # seeded proofs

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs"
import path from "node:path"

const rootArgument = process.argv.indexOf("--root")
const root =
  rootArgument !== -1 && process.argv[rootArgument + 1]
    ? path.resolve(process.argv[rootArgument + 1])
    : process.cwd()

const sourceExtensions = new Set([".ts", ".tsx", ".mts", ".cts"])

const MODULES = [
  "identity",
  "profile",
  "market",
  "services",
  "errands",
  "logistics",
  "finance",
  "messaging",
  "admin",
  "platform",
]

/**
 * Modules allowed to contain code during EP-01. The six activity modules are
 * boundaries only: no tables, no endpoints and no implementation until their
 * owning phase. Adding code to one of them is a reviewed change to this list,
 * not an accident.
 */
const CODE_MODULES = new Set(["identity", "profile", "platform", "admin"])

const modulesRoot = path.join(root, "server", "src", "modules")

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
    message: "the api-client may not import the server or an app",
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
          `${path.relative(root, file)}:${index + 1} - ${rule.message}\n    ${line.trim()}`,
        )
      }
    })
  }
}

// --- Server module boundaries ------------------------------------------------

function relativeToModules(absolute) {
  const relative = path
    .relative(modulesRoot, absolute)
    .split(path.sep)
    .join("/")
  if (relative.startsWith("..") || path.isAbsolute(relative)) return undefined
  return relative
}

function moduleOf(absolute) {
  const relative = relativeToModules(absolute)
  if (relative === undefined) return undefined
  const [name] = relative.split("/")
  return name || undefined
}

function lineOf(contents, index) {
  return contents.slice(0, index).split("\n").length
}

function isModuleIndex(absolute, module) {
  const relative = path
    .relative(path.join(modulesRoot, module), absolute)
    .split(path.sep)
    .join("/")
  return relative === "" || relative === "index" || relative === "index.ts"
}

function isRepositoryPath(relative) {
  return /(^|\/)repository(\/|$)|\.repository(\.|$)/.test(relative)
}

const SERVER_MODULES_EXIST = existsSync(modulesRoot)

if (existsSync(path.join(root, "server"))) {
  if (!SERVER_MODULES_EXIST) {
    violations.push(
      "server/src/modules: missing; the ten module boundaries are required",
    )
  } else {
    const present = readdirSync(modulesRoot).filter((entry) =>
      statSync(path.join(modulesRoot, entry)).isDirectory(),
    )

    for (const module of MODULES) {
      const directory = path.join(modulesRoot, module)
      if (!present.includes(module)) {
        violations.push(
          `server/src/modules/${module}: missing module folder (ARCHITECTURE.md §9.2)`,
        )
        continue
      }
      if (!existsSync(path.join(directory, "index.ts"))) {
        violations.push(`server/src/modules/${module}: missing public index.ts`)
      }
    }

    for (const entry of present) {
      if (!MODULES.includes(entry)) {
        violations.push(
          `server/src/modules/${entry}: unknown module folder; the architecture defines ten`,
        )
      }
    }

    const edges = new Map(MODULES.map((module) => [module, new Set()]))

    for (const file of files) {
      const module = moduleOf(file)
      if (!module) continue

      const contents = readFileSync(file, "utf8")
      const relativeFile = path.relative(root, file).split(path.sep).join("/")
      const relativeWithinModule = path
        .relative(path.join(modulesRoot, module), file)
        .split(path.sep)
        .join("/")

      if (!CODE_MODULES.has(module) && relativeWithinModule !== "index.ts") {
        violations.push(
          `${relativeFile} - module "${module}" is a boundary only during EP-01; it may contain index.ts and nothing else`,
        )
      }

      for (const match of contents.matchAll(/from\s+["']([^"']+)["']/g)) {
        const specifier = match[1]
        if (!specifier.startsWith(".")) continue

        const target = path.resolve(path.dirname(file), specifier)
        const targetModule = moduleOf(target)
        if (!targetModule || targetModule === module) continue

        const relativeTarget = path
          .relative(path.join(modulesRoot, targetModule), target)
          .split(path.sep)
          .join("/")
        const line = lineOf(contents, match.index ?? 0)

        if (isRepositoryPath(relativeTarget)) {
          violations.push(
            `${relativeFile}:${line} - module "${module}" may not import another module's repository; use "${targetModule}/index.ts"\n    ${specifier}`,
          )
          continue
        }

        if (!isModuleIndex(target, targetModule)) {
          violations.push(
            `${relativeFile}:${line} - module "${module}" may only import "${targetModule}" through its public index\n    ${specifier}`,
          )
          continue
        }

        edges.get(module)?.add(targetModule)
      }

      if (relativeFile.endsWith(".controller.ts")) {
        if (/\.query\s*\(/.test(contents)) {
          violations.push(
            `${relativeFile} - a controller may not execute SQL; move the query to the service or repository`,
          )
        }
        for (const match of contents.matchAll(/from\s+["']([^"']+)["']/g)) {
          if (isRepositoryPath(match[1])) {
            violations.push(
              `${relativeFile} - a controller may not import a repository`,
            )
          }
        }
      }

      const tablePattern =
        /\b(?:insert\s+into|update|delete\s+from|from|join)\s+(identity|profile|market|services|errands|logistics|finance|messaging|admin|platform)\.([a-z_][a-z0-9_]*)/gi
      let tableMatch
      while ((tableMatch = tablePattern.exec(contents)) !== null) {
        const [statement, schema, table] = tableMatch
        // `schema.function(` is a public function call, not table access.
        if (contents[tableMatch.index + statement.length] === "(") continue
        if (schema.toLowerCase() === module) continue
        violations.push(
          `${relativeFile}:${lineOf(contents, tableMatch.index)} - module "${module}" may not access ${schema}.${table} directly; call the "${schema}" module interface`,
        )
      }
    }

    const cycle = findCycle(edges)
    if (cycle) {
      violations.push(
        `server/src/modules: dependency cycle ${cycle.join(" -> ")}; replace one edge with a domain event (ARCHITECTURE.md §9.3)`,
      )
    }
  }
}

function findCycle(edges) {
  const state = new Map()
  const stack = []
  let cycle

  function visit(node) {
    if (cycle) return
    state.set(node, 1)
    stack.push(node)
    for (const next of edges.get(node) ?? []) {
      if (state.get(next) === 1) {
        cycle = [...stack.slice(stack.indexOf(next)), next]
        return
      }
      if (!state.get(next)) visit(next)
    }
    stack.pop()
    state.set(node, 2)
  }

  for (const node of MODULES) {
    if (!state.get(node)) visit(node)
  }
  return cycle
}

if (violations.length > 0) {
  console.error("lint:boundaries: found boundary violations\n")
  for (const violation of violations) console.error(violation)
  process.exit(1)
}

console.log(
  `lint:boundaries: OK - ${files.length} workspace source file(s) and ${MODULES.length} module(s) checked`,
)
