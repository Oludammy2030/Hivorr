import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const organisation = readFileSync(
  path.join(
    root,
    "supabase/migrations/20261111000500_admin_create_organisation_tables.sql",
  ),
  "utf8",
)
const cases = readFileSync(
  path.join(
    root,
    "supabase/migrations/20261111000600_admin_create_case_and_approval_tables.sql",
  ),
  "utf8",
)

const ORGANISATION_TABLES = [
  "departments",
  "staff_profiles",
  "department_members",
  "partner_organisations",
  "partner_representatives",
  "partner_applications",
  "partner_agreements",
  "partner_scopes",
]

const CASE_TABLES = [
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

describe("administrative organisation schema", () => {
  it("creates the organisation tables", () => {
    for (const table of ORGANISATION_TABLES) {
      expect(organisation, table).toMatch(
        new RegExp(`create table admin\\.${table}`),
      )
    }
  })

  it("forces RLS on every organisation table", () => {
    for (const table of ORGANISATION_TABLES) {
      expect(organisation, table).toMatch(
        new RegExp(`alter table admin\\.${table} enable row level security`),
      )
      expect(organisation, table).toMatch(
        new RegExp(`alter table admin\\.${table} force row level security`),
      )
    }
  })

  it("keeps partner access tied to a representative row", () => {
    expect(organisation).toMatch(
      /partner_representatives_select_self on admin\.partner_representatives[\s\S]*?user_id = platform\.current_user_id\(\)/,
    )
    expect(organisation).toMatch(
      /organisation_id uuid not null references admin\.partner_organisations/,
    )
  })

  it("allows only one active partner application and one active scope", () => {
    expect(organisation).toMatch(
      /partner_applications_active_unique[\s\S]*?where status in \('submitted', 'under_review'\)/,
    )
    expect(organisation).toMatch(
      /partner_scopes_active_unique[\s\S]*?where revoked_at is null/,
    )
  })

  it("does not grant API write access to organisation tables", () => {
    for (const table of ORGANISATION_TABLES) {
      expect(organisation, table).not.toMatch(
        new RegExp(`grant (insert|update|delete)[^;]*on admin\\.${table}`),
      )
    }
  })
})

describe("case, approval and configuration schema", () => {
  it("creates every case and governance table", () => {
    for (const table of CASE_TABLES) {
      expect(cases, table).toMatch(new RegExp(`create table admin\\.${table}`))
    }
  })

  it("forces RLS on every case and governance table", () => {
    for (const table of CASE_TABLES) {
      expect(cases, table).toMatch(
        new RegExp(`alter table admin\\.${table} enable row level security`),
      )
      expect(cases, table).toMatch(
        new RegExp(`alter table admin\\.${table} force row level security`),
      )
    }
  })

  it("uses one case spine with typed cases and parent links", () => {
    expect(cases).toMatch(/case_type text not null check \(case_type in \(/)
    expect(cases).toMatch(/parent_case_id uuid references admin\.cases/)
    expect(cases).toMatch(/case_links/)
    expect(cases).toMatch(
      /unique \(case_id, entity_type, entity_id, link_role\)/,
    )
  })

  it("makes the case timeline, decisions and configuration versions append-only", () => {
    expect(cases).toMatch(
      /case_events_no_mutation[\s\S]*?before update or delete on admin\.case_events/,
    )
    expect(cases).toMatch(
      /approval_decisions_no_mutation[\s\S]*?before update or delete on admin\.approval_decisions/,
    )
    expect(cases).toMatch(
      /case_decisions_no_mutation[\s\S]*?before update or delete on admin\.case_decisions/,
    )
    expect(cases).toMatch(
      /configuration_versions_no_mutation[\s\S]*?before update or delete on admin\.configuration_versions/,
    )
  })

  it("records evidence integrity and supersession", () => {
    expect(cases).toMatch(/sha256 text check/)
    expect(cases).toMatch(/supersedes_id uuid references admin\.case_evidence/)
    expect(cases).toMatch(/storage_key text not null unique/)
  })

  it("supports maker-checker without a generic workflow engine", () => {
    expect(cases).toMatch(/approval_requests/)
    expect(cases).toMatch(/approval_steps/)
    expect(cases).toMatch(/approval_decisions/)
    expect(cases).toMatch(/requester_user_id uuid not null/)
    expect(cases).toMatch(
      /required_permission text not null references admin\.permissions/,
    )
    expect(cases).toMatch(
      /approval_requests_currency check \(\s*amount is null or currency is not null/,
    )
  })

  it("versions configuration with an effective window", () => {
    expect(cases).toMatch(/configuration_versions/)
    expect(cases).toMatch(/effective_from timestamptz not null/)
    expect(cases).toMatch(/change_reason text not null/)
    expect(cases).toMatch(/unique \(entry_id, version\)/)
  })

  it("does not grant API write access to case tables", () => {
    for (const table of CASE_TABLES) {
      expect(cases, table).not.toMatch(
        new RegExp(`grant (insert|update|delete)[^;]*on admin\\.${table}`),
      )
    }
  })
})
