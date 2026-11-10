#!/usr/bin/env node
// Migration lint (EP-01-004).
//
// Applies the structural rules in
// `Database-Migration-and-Supabase-Data-API-Rules.md` §9 to the migration set.
//
// The eleven migrations already applied before this gate existed are listed
// below and exempt from the naming and self-containment rules. Applied
// migrations must never be renamed or edited (§9.3), so grandfathering is the
// only correct treatment. New files are held to the full rule.
//
// Usage:
//   node scripts/lint-migrations.mjs
//   node scripts/lint-migrations.mjs --dir <path>   # used by the seeded proof

import { readdirSync, readFileSync, statSync } from "node:fs"
import path from "node:path"

const root = process.cwd()

const LEGACY_APPLIED = new Set([
  "20261107000100_initial_schemas.sql",
  "20261107000200_platform_tables.sql",
  "20261107000300_roles_and_grants.sql",
  "20261107000400_uuidv7.sql",
  "20261107000500_identity_tables.sql",
  "20261107000600_identity_rls.sql",
  "20261107000700_session_lookup.sql",
  "20261107000800_mfa_challenges.sql",
  "20261107000900_refresh_tokens.sql",
  "20261107001000_grant_management.sql",
  "20261107001100_outbox_delivery.sql",
])

const NAME_PATTERN =
  /^(\d{14})_([a-z0-9]+)_(create|add|alter|drop|backfill|grant|policy|seed)_[a-z0-9_]+\.sql$/
const DESTRUCTIVE = [
  { id: "drop-table", re: /\bdrop\s+table\b/i },
  { id: "drop-column", re: /\bdrop\s+column\b/i },
  { id: "truncate", re: /\btruncate\b/i },
  { id: "alter-type", re: /\balter\s+column\s+\S+\s+type\b/i },
]

const args = process.argv.slice(2)
let directory = path.join(root, "supabase", "migrations")
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--dir" && args[index + 1]) {
    directory = path.resolve(root, args[index + 1])
    index += 1
  }
}

const isRepositoryMigrations =
  directory === path.join(root, "supabase", "migrations")

function stripComments(source) {
  return source.replace(/\/\*[\s\S]*?\*\//g, " ").replace(/--[^\n\r]*/g, " ")
}

function fail(file, rule, message) {
  problems.push(`${file} [${rule}] ${message}`)
}

let files
try {
  files = readdirSync(directory)
    .filter((file) => file.endsWith(".sql"))
    .sort()
} catch {
  console.error(
    `lint:migrations: cannot read ${path.relative(root, directory)}`,
  )
  process.exit(2)
}

const problems = []
const warnings = []
const timestamps = new Map()
const sequenced = []
let strictCount = 0
let legacyCount = 0

for (const file of files) {
  const full = path.join(directory, file)
  if (!statSync(full).isFile()) continue
  const source = readFileSync(full, "utf8")
  const code = stripComments(source)
  const legacy = isRepositoryMigrations && LEGACY_APPLIED.has(file)

  if (legacy) legacyCount += 1
  else strictCount += 1

  if (/_down\.sql$|rollback/i.test(file)) {
    fail(file, "forward-only", "down/rollback migrations are not permitted")
  }

  const match = NAME_PATTERN.exec(file)
  if (!match) {
    if (legacy) {
      warnings.push(`${file} [legacy] name predates §9.3 and cannot be renamed`)
    } else {
      fail(
        file,
        "naming",
        "expected <14-digit timestamp>_<module>_<verb>_<object>.sql",
      )
    }
  } else {
    const timestamp = match[1]
    sequenced.push({ file, timestamp })
    if (timestamps.has(timestamp)) {
      fail(
        file,
        "timestamp",
        `duplicate timestamp also used by ${timestamps.get(timestamp)}`,
      )
    } else {
      timestamps.set(timestamp, file)
    }
  }

  const approvedComment = /--\s*destructive-approved:\s*\S+/i.test(source)
  for (const rule of DESTRUCTIVE) {
    if (rule.re.test(code) && !approvedComment) {
      fail(
        file,
        rule.id,
        "destructive statement requires `-- destructive-approved: <reason>`",
      )
    }
  }

  if (legacy) continue

  const creates = [
    ...code.matchAll(
      /create\s+table\s+(?:if\s+not\s+exists\s+)?([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)/gi,
    ),
  ].map((entry) => entry[1].toLowerCase())

  const unqualified =
    /create\s+table\s+(?:if\s+not\s+exists\s+)?(?!\w+\.)[a-z_][a-z0-9_]*/i.test(
      code,
    )
  if (unqualified) {
    fail(
      file,
      "schema-qualified",
      "every created table must be schema-qualified",
    )
  }

  for (const table of creates) {
    const escaped = table.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    const enable = new RegExp(
      `alter\\s+table\\s+${escaped}\\s+enable\\s+row\\s+level\\s+security`,
      "i",
    )
    if (!enable.test(code)) {
      fail(
        file,
        "self-contained-rls",
        `new table ${table} must enable row level security in the same migration (§9.4)`,
      )
    }
  }

  const altersExisting =
    /\balter\s+table\s+\S+\s+(add|drop|alter|rename)\b/i.test(code)
  if (altersExisting && !/\block_timeout\b/i.test(code)) {
    fail(
      file,
      "lock-timeout",
      "a migration that alters an existing table must set `lock_timeout` (§9.5)",
    )
  }
}

for (let index = 1; index < sequenced.length; index += 1) {
  if (sequenced[index].timestamp <= sequenced[index - 1].timestamp) {
    problems.push(
      `${sequenced[index].file} [order] timestamp is not after ${sequenced[index - 1].file}`,
    )
  }
}

for (const warning of warnings)
  console.warn(`lint:migrations: warning: ${warning}`)

if (problems.length) {
  console.error(`lint:migrations: FAILED — ${problems.length} problem(s)`)
  for (const problem of problems) console.error(`  - ${problem}`)
  process.exit(1)
}

console.log(
  `lint:migrations: OK — ${files.length} migration(s) checked ` +
    `(${strictCount} strict, ${legacyCount} legacy-applied)`,
)
