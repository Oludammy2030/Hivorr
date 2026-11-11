import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { CAPABILITY_IDS } from "@hivorr/shared"
import { describe, expect, it } from "vitest"

import {
  CAPABILITY_RULES,
  evaluateCapability,
  type AccessContext,
} from "../server/src/domain/capabilities"

const root = process.cwd()
const migrationsDirectory = path.join(root, "supabase", "migrations")
const migrationSql = readdirSync(migrationsDirectory)
  .filter((file) => file.endsWith(".sql"))
  .sort()
  .map((file) => readFileSync(path.join(migrationsDirectory, file), "utf8"))
  .join("\n")

const base: AccessContext = {
  authenticated: true,
  audience: "control",
  environment: "staging",
  grants: [],
}

const ADMIN_TABLES = [
  "permissions",
  "roles",
  "role_permissions",
  "role_assignments",
  "permission_grants",
  "access_denials",
  "departments",
  "staff_profiles",
  "department_members",
  "partner_organisations",
  "partner_representatives",
  "partner_applications",
  "partner_agreements",
  "partner_scopes",
  "approval_requests",
  "approval_steps",
  "approval_decisions",
  "cases",
  "case_events",
  "case_links",
  "case_evidence",
  "case_findings",
  "case_recommendations",
  "case_decisions",
  "case_actions",
  "case_assignments",
  "case_team_members",
  "work_items",
  "configuration_entries",
  "configuration_versions",
]

describe("P0 control-portal authorization matrix", () => {
  it("keeps every admin capability in the control audience", () => {
    for (const capability of CAPABILITY_IDS) {
      if (!capability.startsWith("admin.")) continue
      const rule = CAPABILITY_RULES[capability]
      expect(rule.audience, capability).toEqual(["control"])
    }
  })

  it("requires a permission or grant for every admin capability", () => {
    for (const capability of CAPABILITY_IDS) {
      if (!capability.startsWith("admin.")) continue
      const rule = CAPABILITY_RULES[capability]
      expect(
        Boolean(rule.permission ?? rule.grant),
        `${capability} must require a permission or grant`,
      ).toBe(true)
    }
  })

  it("denies every admin capability without its requirement", () => {
    for (const capability of CAPABILITY_IDS) {
      if (!capability.startsWith("admin.")) continue
      expect(evaluateCapability(base, capability).allowed, capability).toBe(
        false,
      )
    }
  })

  it("allows a permission-based admin capability only with the permission", () => {
    for (const capability of CAPABILITY_IDS) {
      if (!capability.startsWith("admin.")) continue
      const rule = CAPABILITY_RULES[capability]
      if (!rule.permission) continue
      expect(
        evaluateCapability(
          {
            ...base,
            adminPermissions: [rule.permission],
          },
          capability,
        ).allowed,
        capability,
      ).toBe(true)
      expect(
        evaluateCapability(
          {
            ...base,
            adminPermissions: [rule.permission],
            deniedPermissions: [rule.permission],
          },
          capability,
        ),
        capability,
      ).toEqual({ allowed: false, reason: "EXPLICIT_DENY" })
    }
  })

  it("seeds every permission-based admin capability", () => {
    for (const capability of CAPABILITY_IDS) {
      if (!capability.startsWith("admin.")) continue
      const rule = CAPABILITY_RULES[capability]
      if (!rule.permission) continue
      expect(migrationSql, capability).toContain(`('${rule.permission}'`)
    }
  })
})

describe("P0 control-portal RLS and audit matrix", () => {
  it("enables and forces RLS on every admin table", () => {
    for (const table of ADMIN_TABLES) {
      expect(migrationSql, table).toMatch(
        new RegExp(`alter table admin\\.${table} enable row level security`),
      )
      expect(migrationSql, table).toMatch(
        new RegExp(`alter table admin\\.${table} force row level security`),
      )
    }
  })

  it("does not grant API write access to any admin table", () => {
    for (const table of ADMIN_TABLES) {
      expect(migrationSql, table).not.toMatch(
        new RegExp(`grant (insert|update|delete)[^;]*on admin\\.${table}`),
      )
    }
  })

  it("keeps the audit trail append-only and extended", () => {
    expect(migrationSql).toMatch(
      /create trigger audit_log_no_update[\s\S]*?before update or delete on platform\.audit_log/,
    )
    expect(migrationSql).toMatch(/add column reason text/)
    expect(migrationSql).toMatch(/add column approval_reference text/)
    expect(migrationSql).toMatch(/add column session_id uuid/)
    expect(migrationSql).not.toMatch(
      /alter table platform\.audit_log[\s\S]*?drop column/,
    )
  })

  it("guards the user directory inside the database", () => {
    expect(migrationSql).toMatch(
      /admin\.actor_has_platform_permission\('admin\.user\.read'\)/,
    )
    expect(migrationSql).toMatch(/platform\.current_user_id\(\)/)
    expect(migrationSql).toMatch(/set search_path = ''/)
  })

  it("does not use auth.uid()", () => {
    expect(migrationSql).not.toMatch(/auth\.uid\(\)/)
  })
})
