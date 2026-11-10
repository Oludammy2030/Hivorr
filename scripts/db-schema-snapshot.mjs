#!/usr/bin/env node
// Deterministic database schema snapshot (EP-01-004).
//
// Produces the review artefact for `ARCHITECTURE.md` §12.2 stage 9 and
// `Database-Migration-and-Supabase-Data-API-Rules.md` §11.1 item 5. The output
// contains schema objects only: no rows, no secrets, no connection string.
//
// Usage:
//   node scripts/db-schema-snapshot.mjs --out artifacts/db-schema.txt
//   DATABASE_URL=postgres://... node scripts/db-schema-snapshot.mjs
//
// In CI the caller sets DATABASE_URL to the ephemeral service. Locally the
// default matches the Supabase container used by the migration runner.

import { writeFileSync, mkdirSync } from "node:fs"
import path from "node:path"

import { Client } from "pg"

const args = process.argv.slice(2)
let out = ""
let url = process.env.DATABASE_URL ?? ""

for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--out" && args[index + 1]) {
    out = args[index + 1]
    index += 1
  } else if (args[index] === "--url" && args[index + 1]) {
    url = args[index + 1]
    index += 1
  }
}

if (!url) {
  console.error(
    "db:snapshot: DATABASE_URL is not set; point it at a migrated database",
  )
  process.exit(2)
}

const QUERIES = [
  {
    section: "schemas",
    sql: `select nspname as name
          from pg_namespace
          where nspname not in ('pg_catalog','information_schema')
            and nspname not like 'pg_temp_%'
            and nspname not like 'pg_toast%'
          order by 1`,
    columns: ["name"],
  },
  {
    section: "tables",
    sql: `select schemaname as schema, tablename as name
          from pg_tables
          where schemaname not in ('pg_catalog','information_schema')
          order by 1, 2`,
    columns: ["schema", "name"],
  },
  {
    section: "columns",
    sql: `select table_schema as schema, table_name as table_name,
                 column_name as name, data_type as data_type,
                 udt_name as udt, is_nullable as nullable,
                 coalesce(column_default, '-') as default_value
          from information_schema.columns
          where table_schema not in ('pg_catalog','information_schema')
          order by 1, 2, ordinal_position`,
    columns: [
      "schema",
      "table_name",
      "name",
      "data_type",
      "udt",
      "nullable",
      "default_value",
    ],
  },
  {
    section: "constraints",
    sql: `select n.nspname as schema, c.relname as table_name,
                 con.conname as name, con.contype as kind,
                 pg_get_constraintdef(con.oid, true) as definition
          from pg_constraint con
          join pg_class c on c.oid = con.conrelid
          join pg_namespace n on n.oid = c.relnamespace
          where n.nspname not in ('pg_catalog','information_schema')
          order by 1, 2, 3`,
    columns: ["schema", "table_name", "name", "kind", "definition"],
  },
  {
    section: "indexes",
    sql: `select schemaname as schema, tablename as table_name,
                 indexname as name, indexdef as definition
          from pg_indexes
          where schemaname not in ('pg_catalog','information_schema')
          order by 1, 2, 3`,
    columns: ["schema", "table_name", "name", "definition"],
  },
  {
    section: "row-level-security",
    sql: `select n.nspname as schema, c.relname as table_name,
                 c.relrowsecurity as enabled, c.relforcerowsecurity as forced
          from pg_class c
          join pg_namespace n on n.oid = c.relnamespace
          where c.relkind in ('r','p')
            and n.nspname not in ('pg_catalog','information_schema')
          order by 1, 2`,
    columns: ["schema", "table_name", "enabled", "forced"],
  },
  {
    section: "policies",
    sql: `select schemaname as schema, tablename as table_name,
                 policyname as name, permissive, roles::text as roles,
                 cmd, coalesce(qual, '-') as using_expression,
                 coalesce(with_check, '-') as check_expression
          from pg_policies
          where schemaname not in ('pg_catalog','information_schema')
          order by 1, 2, 3`,
    columns: [
      "schema",
      "table_name",
      "name",
      "permissive",
      "roles",
      "cmd",
      "using_expression",
      "check_expression",
    ],
  },
  {
    section: "table-grants",
    sql: `select table_schema as schema, table_name as table_name,
                 grantee, privilege_type as privilege, is_grantable as grantable
          from information_schema.role_table_grants
          where table_schema not in ('pg_catalog','information_schema')
          order by 1, 2, 3, 4`,
    columns: ["schema", "table_name", "grantee", "privilege", "grantable"],
  },
  {
    section: "functions",
    sql: `select n.nspname as schema, p.proname as name,
                 pg_get_function_identity_arguments(p.oid) as arguments,
                 p.prosecdef as security_definer,
                 p.provolatile as volatility,
                 coalesce(array_to_string(p.proconfig, ','), '-') as config
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname not in ('pg_catalog','information_schema')
          order by 1, 2, 3`,
    columns: [
      "schema",
      "name",
      "arguments",
      "security_definer",
      "volatility",
      "config",
    ],
  },
  {
    section: "roles",
    sql: `select rolname as name, rolsuper as superuser,
                 rolinherit as inherit, rolcreaterole as create_role,
                 rolcreatedb as create_db, rolcanlogin as login,
                 rolbypassrls as bypass_rls
          from pg_roles
          where rolname not like 'pg\\_%'
          order by 1`,
    columns: [
      "name",
      "superuser",
      "inherit",
      "create_role",
      "create_db",
      "login",
      "bypass_rls",
    ],
  },
  {
    section: "extensions",
    sql: `select extname as name, extversion as version
          from pg_extension
          order by 1`,
    columns: ["name", "version"],
  },
]

function cell(value) {
  if (value === null || value === undefined) return "-"
  if (typeof value === "boolean") return value ? "true" : "false"
  return String(value).replace(/\s+/g, " ").trim()
}

const client = new Client({ connectionString: url })
const lines = [
  "# Hivorr database schema snapshot",
  "# Derived output. Migrations remain the source of truth (DB rules §9.1).",
  "# Contains schema objects only: no rows, secrets or connection details.",
  "",
]

try {
  await client.connect()
  for (const query of QUERIES) {
    const result = await client.query(query.sql)
    lines.push(`## ${query.section} (${result.rowCount})`)
    for (const row of result.rows) {
      lines.push(query.columns.map((column) => cell(row[column])).join(" | "))
    }
    lines.push("")
  }
} catch (error) {
  console.error(
    `db:snapshot: ${error instanceof Error ? error.message : String(error)}`,
  )
  process.exitCode = 1
} finally {
  await client.end().catch(() => {})
}

if (process.exitCode) process.exit(process.exitCode)

const output = `${lines.join("\n").trimEnd()}\n`
if (out) {
  mkdirSync(path.dirname(path.resolve(out)), { recursive: true })
  writeFileSync(out, output)
  console.log(`db:snapshot: wrote ${out}`)
} else {
  process.stdout.write(output)
}
