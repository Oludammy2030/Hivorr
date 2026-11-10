#!/usr/bin/env node
// Seeded-failure proofs for every blocking gate (EP-01-004).
//
// A gate that has never failed is not evidence. This script runs each gate
// against a deliberately bad fixture and asserts a non-zero exit, then against
// a good fixture and asserts zero. It covers typecheck, contract, migration,
// OpenAPI, visual and secret scanning.
//
// The fixtures are created under the OS temp directory and removed afterwards.
// The contract fixture needs Vitest's root resolution, so it is created inside
// `tests/` with a unique name and removed in `finally`.
//
// Usage:
//   node scripts/test-ci-gates.mjs

import { randomBytes } from "node:crypto"
import { spawnSync } from "node:child_process"
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"

import { encodePng } from "./lib/png.mjs"

const root = process.cwd()
const temp = mkdtempSync(path.join(tmpdir(), "hivorr-gates-"))
const contractFixture = path.join(
  root,
  "tests",
  `__gate_selftest_${process.pid}.test.ts`,
)

const results = []

function run(command, args, options = {}) {
  return spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    ...options,
  })
}

function nodeRun(script, args, options) {
  return run(process.execPath, [path.join(root, script), ...args], options)
}

function tscRun(args, options) {
  return run(
    process.execPath,
    [path.join(root, "node_modules", "typescript", "bin", "tsc"), ...args],
    options,
  )
}

function vitestRun(args) {
  return run(process.execPath, [
    path.join(root, "node_modules", "vitest", "vitest.mjs"),
    "run",
    ...args,
  ])
}

function assert(condition, message) {
  if (!condition) throw new Error(message)
}

function expectExit(result, expected, label) {
  const detail =
    `${label}: expected exit ${expected}, got ${result.status}` +
    (result.error ? ` (${result.error.message})` : "")
  assert(result.status === expected, detail)
}

function check(name, fn) {
  try {
    fn()
    results.push({ name, ok: true })
    console.log(`PASS  ${name}`)
  } catch (error) {
    results.push({
      name,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    })
    console.error(`FAIL  ${name}`)
    console.error(`      ${error instanceof Error ? error.message : error}`)
  }
}

function write(file, contents) {
  mkdirSync(path.dirname(file), { recursive: true })
  writeFileSync(file, contents)
}

// --- Secret scan -----------------------------------------------------------

check("secret gate blocks a committed token", () => {
  const clean = path.join(temp, "secret-clean.txt")
  const leak = path.join(temp, "secret-leak.txt")
  write(clean, "nothing sensitive here\n")
  write(leak, `token = ghp_${"A".repeat(36)}\n`)
  expectExit(
    nodeRun("scripts/secret-scan.mjs", [clean]),
    0,
    "secret scan on clean file",
  )
  expectExit(
    nodeRun("scripts/secret-scan.mjs", [leak]),
    1,
    "secret scan on leaked token",
  )
})

// --- Configuration contract ------------------------------------------------

function configurationContractFixture(name, secretPlaceholder) {
  const directory = path.join(temp, name)
  write(
    path.join(directory, "config", "configuration-contract.json"),
    JSON.stringify({
      schemaVersion: 1,
      keys: [
        {
          name: "HIVORR_ENV",
          source: "config",
          classification: "public",
          requiredIn: [],
          description: "The deployment environment.",
        },
        {
          name: "DATABASE_URL",
          source: "config",
          classification: "secret",
          requiredIn: [],
          description: "The runtime database connection.",
        },
      ],
    }),
  )
  write(
    path.join(directory, ".env.example"),
    `HIVORR_ENV=development\nDATABASE_URL=${secretPlaceholder}\n`,
  )
  write(
    path.join(directory, "config", "environments.json"),
    JSON.stringify({
      environments: { staging: { requiredSecrets: ["DATABASE_URL"] } },
    }),
  )
  return directory
}

check("configuration contract accepts a clean template", () => {
  expectExit(
    nodeRun("scripts/check-configuration-contract.mjs", [
      "--root",
      configurationContractFixture("config-contract-good", ""),
    ]),
    0,
    "clean configuration contract",
  )
})

check("configuration contract blocks a secret value in the template", () => {
  expectExit(
    nodeRun("scripts/check-configuration-contract.mjs", [
      "--root",
      configurationContractFixture(
        "config-contract-leak",
        "postgres://user:password@example.test/hivorr",
      ),
    ]),
    1,
    "secret value in .env.example",
  )
})

// --- Migration lint --------------------------------------------------------

check("migration lint blocks a malformed filename", () => {
  const directory = path.join(temp, "migrations-name")
  write(
    path.join(directory, "20260101000000_widget.sql"),
    "create table platform.widget (id uuid primary key);\n" +
      "alter table platform.widget enable row level security;\n",
  )
  expectExit(
    nodeRun("scripts/lint-migrations.mjs", ["--dir", directory]),
    1,
    "malformed migration name",
  )
})

check("migration lint blocks an unapproved destructive statement", () => {
  const directory = path.join(temp, "migrations-destructive")
  write(
    path.join(directory, "20260101000100_platform_drop_widget.sql"),
    "drop table platform.widget;\n",
  )
  expectExit(
    nodeRun("scripts/lint-migrations.mjs", ["--dir", directory]),
    1,
    "destructive migration",
  )
})

check("migration lint blocks a new table without RLS", () => {
  const directory = path.join(temp, "migrations-rls")
  write(
    path.join(directory, "20260101000200_platform_create_gadget.sql"),
    "create table platform.gadget (id uuid primary key);\n",
  )
  expectExit(
    nodeRun("scripts/lint-migrations.mjs", ["--dir", directory]),
    1,
    "table without RLS",
  )
})

check("migration lint accepts a compliant migration", () => {
  const directory = path.join(temp, "migrations-good")
  write(
    path.join(directory, "20260101000300_platform_create_widget.sql"),
    "create table platform.widget (id uuid primary key);\n" +
      "alter table platform.widget enable row level security;\n",
  )
  expectExit(
    nodeRun("scripts/lint-migrations.mjs", ["--dir", directory]),
    0,
    "compliant migration",
  )
})

// --- OpenAPI diff ----------------------------------------------------------

const baseSpec = {
  openapi: "3.1.0",
  info: { title: "Fixture", version: "1.0.0" },
  paths: {
    "/v1/things": {
      get: {
        responses: { 200: { description: "ok" } },
      },
    },
  },
}

check("OpenAPI gate blocks a removed operation", () => {
  const base = path.join(temp, "openapi-base.json")
  const head = path.join(temp, "openapi-breaking.json")
  write(base, JSON.stringify(baseSpec))
  write(
    head,
    JSON.stringify({
      ...baseSpec,
      paths: {},
    }),
  )
  expectExit(
    nodeRun("scripts/openapi-diff.mjs", [
      "--base",
      base,
      "--head",
      head,
      "--fail-on-breaking",
    ]),
    1,
    "removed operation",
  )
})

check("OpenAPI gate accepts an additive change", () => {
  const base = path.join(temp, "openapi-base-2.json")
  const head = path.join(temp, "openapi-additive.json")
  write(base, JSON.stringify(baseSpec))
  write(
    head,
    JSON.stringify({
      ...baseSpec,
      paths: {
        ...baseSpec.paths,
        "/v1/other": {
          get: { responses: { 200: { description: "ok" } } },
        },
      },
    }),
  )
  expectExit(
    nodeRun("scripts/openapi-diff.mjs", [
      "--base",
      base,
      "--head",
      head,
      "--fail-on-breaking",
    ]),
    0,
    "additive operation",
  )
})

// --- Visual diff -----------------------------------------------------------

function image(pixel) {
  return encodePng({
    width: 2,
    height: 2,
    channels: 4,
    data: new Uint8Array([...pixel, ...pixel, ...pixel, ...pixel]),
  })
}

check("visual gate blocks a changed pixel", () => {
  const baseline = path.join(temp, "visual-baseline")
  const same = path.join(temp, "visual-same")
  const changed = path.join(temp, "visual-changed")
  write(path.join(baseline, "page.png"), image([255, 0, 0, 255]))
  write(path.join(same, "page.png"), image([255, 0, 0, 255]))
  write(path.join(changed, "page.png"), image([0, 0, 255, 255]))

  expectExit(
    nodeRun("scripts/visual-diff.mjs", [
      "--baseline",
      baseline,
      "--current",
      same,
      "--fail-on-diff",
    ]),
    0,
    "identical screenshots",
  )
  expectExit(
    nodeRun("scripts/visual-diff.mjs", [
      "--baseline",
      baseline,
      "--current",
      changed,
      "--fail-on-diff",
    ]),
    1,
    "changed screenshot",
  )
})

check("visual gate blocks a single changed pixel", () => {
  const size = 40
  const baseline = path.join(temp, "pixel-baseline")
  const current = path.join(temp, "pixel-current")
  const data = new Uint8Array(size * size * 4).fill(255)
  const changedData = new Uint8Array(data)
  changedData[0] = 0
  changedData[1] = 0
  changedData[2] = 0
  write(
    path.join(baseline, "page.png"),
    encodePng({ width: size, height: size, channels: 4, data }),
  )
  write(
    path.join(current, "page.png"),
    encodePng({ width: size, height: size, channels: 4, data: changedData }),
  )

  expectExit(
    nodeRun("scripts/visual-diff.mjs", [
      "--baseline",
      baseline,
      "--current",
      current,
      "--threshold",
      "0",
      "--pixel-tolerance",
      "0",
      "--fail-on-diff",
    ]),
    1,
    "one changed pixel at zero tolerance",
  )
})

// --- Bundle targets --------------------------------------------------------

function bundleFixture(name, { noindexControl = true, payload } = {}) {
  const dist = path.join(temp, name)
  for (const app of ["main", "control", "staff", "partner"]) {
    const directory = app === "main" ? dist : path.join(dist, "portals", app)
    const noindex = app !== "main" && (app !== "control" || noindexControl)
    write(
      path.join(directory, "index.html"),
      `<html><head>${
        noindex ? '<meta name="robots" content="noindex, nofollow">' : ""
      }</head><body><script type="module" src="/assets/index.js"></script></body></html>`,
    )
    write(
      path.join(directory, "assets", "index.js"),
      payload ?? `console.log("${app}")`,
    )
  }
  return dist
}

check("bundle gate accepts four bundles", () => {
  expectExit(
    nodeRun("scripts/verify-bundles.mjs", [
      "--dist",
      bundleFixture("bundles-good"),
    ]),
    0,
    "four verified bundles",
  )
})

check("bundle gate blocks a privileged bundle without noindex", () => {
  expectExit(
    nodeRun("scripts/verify-bundles.mjs", [
      "--dist",
      bundleFixture("bundles-noindex", { noindexControl: false }),
    ]),
    1,
    "control bundle without noindex",
  )
})

check("bundle gate blocks an over-budget initial bundle", () => {
  expectExit(
    nodeRun("scripts/verify-bundles.mjs", [
      "--dist",
      bundleFixture("bundles-budget", {
        payload: randomBytes(260 * 1024),
      }),
    ]),
    1,
    "bundle over the gzip budget",
  )
})

// --- Typecheck -------------------------------------------------------------

check("typecheck gate blocks a type error", () => {
  const good = path.join(temp, "types-good")
  const bad = path.join(temp, "types-bad")
  write(
    path.join(good, "good.ts"),
    "const value: number = 1\nexport default value\n",
  )
  write(
    path.join(bad, "bad.ts"),
    'const value: number = "not a number"\nexport default value\n',
  )

  expectExit(
    tscRun(["--noEmit", "--strict", "--skipLibCheck", "good.ts"], {
      cwd: good,
    }),
    0,
    "valid TypeScript",
  )
  expectExit(
    tscRun(["--noEmit", "--strict", "--skipLibCheck", "bad.ts"], {
      cwd: bad,
    }),
    2,
    "invalid TypeScript",
  )
})

// --- Contract --------------------------------------------------------------

check("contract gate blocks drifted vocabulary", () => {
  write(
    contractFixture,
    [
      'import { expect, it } from "vitest"',
      'import { ACTIVITY_IDS } from "../packages/shared/src/index"',
      "",
      'it("seeded drift", () => {',
      "  expect(ACTIVITY_IDS.length).toBe(7)",
      "})",
      "",
    ].join("\n"),
  )
  try {
    expectExit(
      vitestRun([path.relative(root, contractFixture)]),
      1,
      "drifted contract test",
    )
  } finally {
    rmSync(contractFixture, { force: true })
  }
})

check("contract gate accepts the real vocabulary", () => {
  expectExit(
    vitestRun(["tests/workspace-contracts.test.ts"]),
    0,
    "real contract suite",
  )
})

// --- Module boundaries -----------------------------------------------------

const BOUNDARY_MODULES = [
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

function boundaryFixture(name) {
  const directory = path.join(temp, name)
  for (const module of BOUNDARY_MODULES) {
    write(
      path.join(directory, "server", "src", "modules", module, "index.ts"),
      "export {}\n",
    )
  }
  return directory
}

function modulePath(directory, module, file = "index.ts") {
  return path.join(directory, "server", "src", "modules", module, file)
}

check("module boundary accepts the ten-module skeleton", () => {
  expectExit(
    nodeRun("scripts/lint-boundaries.mjs", [
      "--root",
      boundaryFixture("boundary-good"),
    ]),
    0,
    "ten skeleton modules",
  )
})

check("module boundary blocks a cross-module internal import", () => {
  const directory = boundaryFixture("boundary-internal")
  write(
    modulePath(directory, "platform", "internal.ts"),
    "export const internal = 1\n",
  )
  write(
    modulePath(directory, "identity"),
    'export { internal } from "../platform/internal"\n',
  )
  expectExit(
    nodeRun("scripts/lint-boundaries.mjs", ["--root", directory]),
    1,
    "cross-module internal import",
  )
})

check("module boundary blocks a cross-module repository import", () => {
  const directory = boundaryFixture("boundary-repository")
  write(
    modulePath(directory, "platform", "repository/audit.ts"),
    "export const audit = 1\n",
  )
  write(
    modulePath(directory, "identity"),
    'export { audit } from "../platform/repository/audit"\n',
  )
  expectExit(
    nodeRun("scripts/lint-boundaries.mjs", ["--root", directory]),
    1,
    "cross-module repository import",
  )
})

check("module boundary blocks a dependency cycle", () => {
  const directory = boundaryFixture("boundary-cycle")
  write(
    modulePath(directory, "identity"),
    'export { platformValue } from "../platform"\nexport const identityValue = 1\n',
  )
  write(
    modulePath(directory, "platform"),
    'export const platformValue = 1\nexport { identityValue } from "../identity"\n',
  )
  expectExit(
    nodeRun("scripts/lint-boundaries.mjs", ["--root", directory]),
    1,
    "module dependency cycle",
  )
})

check("module boundary blocks code in an activity module", () => {
  const directory = boundaryFixture("boundary-activity")
  write(
    modulePath(directory, "market", "service.ts"),
    "export const market = 1\n",
  )
  expectExit(
    nodeRun("scripts/lint-boundaries.mjs", ["--root", directory]),
    1,
    "activity module code",
  )
})

check("module boundary blocks direct access to another module's table", () => {
  const directory = boundaryFixture("boundary-table")
  write(
    modulePath(directory, "identity", "service.ts"),
    'export const sql = "select * from market.orders"\n',
  )
  expectExit(
    nodeRun("scripts/lint-boundaries.mjs", ["--root", directory]),
    1,
    "cross-module table access",
  )
})

// --- Summary ---------------------------------------------------------------

rmSync(temp, { recursive: true, force: true })

const failed = results.filter((result) => !result.ok)
console.log("")
console.log(
  `test:gates: ${results.length - failed.length}/${results.length} proof(s) passed`,
)
if (failed.length) {
  console.error(
    `test:gates: FAILED — ${failed.length} seeded proof(s) did not behave as intended`,
  )
  process.exit(1)
}
if (existsSync(contractFixture)) {
  console.error("test:gates: temporary contract fixture was not removed")
  process.exit(1)
}
