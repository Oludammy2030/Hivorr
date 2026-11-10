import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const read = (relative: string) =>
  readFileSync(path.join(root, relative), "utf8")
const migrationFiles = readdirSync(
  path.join(root, "supabase", "migrations"),
).filter((file) => file.endsWith(".sql"))

const roles = read("supabase/migrations/20261107000300_roles_and_grants.sql")
const defaults = read(
  "supabase/migrations/20261109000100_platform_alter_default_privileges.sql",
)

const APPLICATION_ROLES = [
  "hivorr_api",
  "hivorr_worker",
  "hivorr_readonly",
  "hivorr_migrator",
  "hivorr_breakglass",
]

const MODULE_SCHEMAS = [
  "platform",
  "identity",
  "profile",
  "market",
  "services",
  "errands",
  "logistics",
  "finance",
  "messaging",
  "admin",
]

describe("database role policy", () => {
  it("creates five nologin application roles", () => {
    for (const role of APPLICATION_ROLES) {
      expect(roles, role).toMatch(new RegExp(`create role ${role} nologin`))
    }
    expect(roles).not.toMatch(/\bsuperuser\b/i)
    expect(roles).not.toMatch(/\bbypassrls\b/i)
    expect(roles).not.toMatch(/\bcreatedb\b/i)
    expect(roles).not.toMatch(/\bcreaterole\b/i)
  })

  it("closes default table, sequence and function privileges", () => {
    expect(defaults).toMatch(
      /alter default privileges revoke all on tables from public/,
    )
    expect(defaults).toMatch(
      /alter default privileges revoke all on sequences from public/,
    )
    expect(defaults).toMatch(
      /alter default privileges revoke execute on functions from public/,
    )
  })

  it("revokes PUBLIC execution on every module schema", () => {
    for (const schema of MODULE_SCHEMAS) {
      expect(defaults, schema).toMatch(
        new RegExp(
          `revoke all on all functions in schema ${schema} from public`,
        ),
      )
    }
  })

  it("closes the public and private schemas", () => {
    expect(defaults).toMatch(/revoke create on schema public from public/)
    expect(defaults).toMatch(/revoke all on schema private from public/)
  })

  it("uses a forward-only, correctly named migration", () => {
    const defaultsFile = migrationFiles.find((file) =>
      file.includes("alter_default_privileges"),
    )
    expect(defaultsFile).toBeDefined()
    expect(defaultsFile).toMatch(/^\d{14}_platform_alter_[a-z0-9_]+\.sql$/)
    expect(defaults).not.toMatch(/\bdrop\s+table\b/i)
    expect(defaults).not.toMatch(/\btruncate\b/i)
  })

  it("grants API access to audit append but never update", () => {
    expect(roles).toMatch(
      /grant select, insert on platform\.audit_log to hivorr_api/,
    )
    expect(roles).toMatch(
      /revoke update, delete on platform\.audit_log from public/,
    )
  })
})
