import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const tables = readFileSync(
  path.join(
    root,
    "supabase/migrations/20261111000100_admin_create_authorization_tables.sql",
  ),
  "utf8",
)
const functions = readFileSync(
  path.join(
    root,
    "supabase/migrations/20261111000200_admin_create_user_read_functions.sql",
  ),
  "utf8",
)
const seed = readFileSync(
  path.join(
    root,
    "supabase/migrations/20261111000300_admin_seed_governance_roles.sql",
  ),
  "utf8",
)

const ADMIN_TABLES = [
  "permissions",
  "roles",
  "role_permissions",
  "role_assignments",
  "permission_grants",
  "access_denials",
]

describe("administrative authorization schema", () => {
  it("creates every governance table in the admin schema", () => {
    for (const table of ADMIN_TABLES) {
      expect(tables, table).toMatch(new RegExp(`create table admin\\.${table}`))
    }
  })

  it("enables and forces RLS on every governance table", () => {
    for (const table of ADMIN_TABLES) {
      expect(tables, table).toMatch(
        new RegExp(`alter table admin\\.${table} enable row level security`),
      )
      expect(tables, table).toMatch(
        new RegExp(`alter table admin\\.${table} force row level security`),
      )
    }
  })

  it("scopes self-service reads to the current user", () => {
    expect(tables).toMatch(
      /role_assignments_select_own on admin\.role_assignments[\s\S]*?user_id = platform\.current_user_id\(\)/,
    )
    expect(tables).toMatch(
      /permission_grants_select_own on admin\.permission_grants[\s\S]*?user_id = platform\.current_user_id\(\)/,
    )
    expect(tables).toMatch(
      /access_denials_select_own on admin\.access_denials[\s\S]*?user_id = platform\.current_user_id\(\)/,
    )
  })

  it("expresses the scope shape in a constraint", () => {
    expect(tables).toMatch(
      /role_assignments_scope_shape check \(\s*\(scope_type = 'platform' and scope_id is null\)/,
    )
    expect(tables).toMatch(
      /permission_grants_scope_shape check \(\s*\(scope_type = 'platform' and scope_id is null\)/,
    )
    expect(tables).toMatch(/access_denials_scope_shape check \(/)
  })

  it("does not grant write access to the API role", () => {
    for (const table of ADMIN_TABLES) {
      expect(tables, table).not.toMatch(
        new RegExp(`grant (insert|update|delete)[^;]*on admin\\.${table}`),
      )
    }
  })

  it("uses an empty search path for the governance functions", () => {
    const definerBlocks = functions.split("security definer").slice(1)
    expect(definerBlocks.length).toBeGreaterThanOrEqual(2)
    for (const block of definerBlocks) {
      expect(block).toMatch(/set search_path = ''/)
    }
  })

  it("checks a platform-scoped permission before listing users", () => {
    expect(functions).toMatch(
      /admin\.actor_has_platform_permission\('admin\.user\.read'\)/,
    )
    expect(functions).toMatch(/raise exception 'user_directory_forbidden'/i)
    expect(functions).toMatch(/limit v_limit/)
  })

  it("seeds system permissions and roles without creating an assignment", () => {
    expect(seed).toMatch(/insert into admin\.permissions/)
    expect(seed).toMatch(/insert into admin\.roles/)
    expect(seed).toMatch(/insert into admin\.role_permissions/)
    expect(seed).not.toMatch(/insert into admin\.role_assignments/)
    expect(seed).not.toMatch(/insert into identity\.users/)
  })
})
