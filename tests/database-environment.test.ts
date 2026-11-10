import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const read = (relative: string) =>
  readFileSync(path.join(root, relative), "utf8")
const readJson = (relative: string) => JSON.parse(read(relative))

describe("environment database contract", () => {
  it("keeps staging and production on separate projects", () => {
    const projects = readJson("config/backend-projects.json") as {
      staging: { projectRef: string }
      production: { projectRef: string }
      retired: Record<string, string>
    }

    expect(projects.staging.projectRef).not.toBe(projects.production.projectRef)
    const retired = Object.values(projects.retired)
    expect(retired).not.toContain(projects.staging.projectRef)
    expect(retired).not.toContain(projects.production.projectRef)
  })

  it("matches the topology manifest to the project manifest", () => {
    const projects = readJson("config/backend-projects.json") as {
      staging: { projectRef: string }
      production: { projectRef: string }
    }
    const topology = readJson("config/environments.json") as {
      environments: Record<string, { supabaseProjectRef: string }>
    }

    expect(topology.environments.staging.supabaseProjectRef).toBe(
      projects.staging.projectRef,
    )
    expect(topology.environments.production.supabaseProjectRef).toBe(
      projects.production.projectRef,
    )
  })

  it("declares database and worker credentials per environment", () => {
    const topology = readJson("config/environments.json") as {
      environments: Record<string, { requiredSecrets: string[] }>
    }

    for (const environment of ["staging", "production"]) {
      expect(topology.environments[environment].requiredSecrets).toEqual(
        expect.arrayContaining([
          "DATABASE_URL",
          "WORKER_DATABASE_URL",
          "MFA_ENCRYPTION_KEY",
        ]),
      )
    }
  })

  it("configures local container parity with the managed major version", () => {
    const config = read("supabase/config.toml")

    expect(config).toContain('project_id = "hivorr"')
    expect(config).toMatch(/^port = 54322$/m)
    expect(config).toMatch(/^major_version = 17$/m)
    expect(config).toMatch(/^shadow_port = 54320$/m)
  })

  it("documents the connection and worker variables without a credential", () => {
    const example = read(".env.example")

    for (const key of [
      "DATABASE_URL=",
      "DATABASE_SSL_CA=",
      "WORKER_DATABASE_URL=",
      "MFA_ENCRYPTION_KEY=",
    ]) {
      expect(example, key).toContain(key)
    }

    expect(example).not.toMatch(/postgres(?:ql)?:\/\/[^\s:]+:[^\s@]+@/)
  })

  it("creates nologin roles with least-privilege grants", () => {
    const sql = read("supabase/migrations/20261107000300_roles_and_grants.sql")

    for (const role of [
      "hivorr_api",
      "hivorr_worker",
      "hivorr_readonly",
      "hivorr_migrator",
      "hivorr_breakglass",
    ]) {
      expect(sql, role).toMatch(new RegExp(`create role ${role} nologin`))
    }

    expect(sql).toMatch(
      /grant select, insert, update on platform\.outbox to hivorr_worker/,
    )
    expect(sql).toMatch(
      /grant select on platform\.audit_log to hivorr_readonly/,
    )
    expect(sql).toMatch(
      /revoke update, delete on platform\.audit_log from public/,
    )
  })

  it("points the staging runbook at the declared project", () => {
    const runbook = read(
      "documents/Engineering-Execution/STAGING_PROVISIONING.md",
    )
    const projects = readJson("config/backend-projects.json") as {
      staging: { projectRef: string }
    }

    expect(runbook).toContain(projects.staging.projectRef)
    expect(runbook).toContain("DATABASE_SSL_CA")
  })
})
