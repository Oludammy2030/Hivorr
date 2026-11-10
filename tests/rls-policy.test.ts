import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const migrationsDirectory = path.join(root, "supabase", "migrations")
const migrationFiles = readdirSync(migrationsDirectory)
  .filter((file) => file.endsWith(".sql"))
  .sort()
const migrations = migrationFiles
  .map((file) => readFileSync(path.join(migrationsDirectory, file), "utf8"))
  .join("\n")

const IDENTITY_TABLES = [
  "accounts",
  "users",
  "credentials",
  "memberships",
  "grants",
  "devices",
  "sessions",
  "mfa_factors",
  "recovery_codes",
  "tokens",
  "mfa_challenges",
  "refresh_tokens",
]

const PROFILE_TABLES = ["profiles", "activity_activations"]

const EXPECTED_POLICIES: Record<string, string[]> = {
  accounts: ["SELECT", "INSERT", "UPDATE"],
  users: ["SELECT", "INSERT", "UPDATE"],
  credentials: ["SELECT", "INSERT", "UPDATE"],
  memberships: ["SELECT", "INSERT", "UPDATE"],
  grants: ["SELECT"],
  devices: ["SELECT", "INSERT", "UPDATE"],
  sessions: ["SELECT", "INSERT", "UPDATE"],
  mfa_factors: ["SELECT", "INSERT", "UPDATE"],
  recovery_codes: ["SELECT", "INSERT", "UPDATE", "DELETE"],
  tokens: ["SELECT", "INSERT", "UPDATE", "DELETE"],
  mfa_challenges: ["SELECT", "INSERT", "UPDATE"],
  refresh_tokens: ["SELECT", "INSERT", "UPDATE"],
  profiles: ["SELECT", "INSERT", "UPDATE"],
  activity_activations: ["SELECT", "INSERT", "UPDATE"],
}

describe("RLS policy pattern", () => {
  it("never uses auth.uid()", () => {
    expect(migrations).not.toMatch(/auth\.uid\(\)/)
  })

  it("puts the policy helpers in the private schema", () => {
    for (const helper of [
      "current_account_id",
      "current_user_id",
      "set_identity_context",
    ]) {
      expect(migrations, helper).toMatch(
        new RegExp(`function private\\.${helper}\\(`),
      )
    }
    expect(migrations).toMatch(
      /create or replace function platform\.current_account_id\(\)[\s\S]*?select private\.current_account_id\(\)/,
    )
    expect(migrations).toMatch(/security definer/)
  })

  it("forces row level security on every identity and profile table", () => {
    for (const table of IDENTITY_TABLES) {
      expect(migrations, table).toMatch(
        new RegExp(`alter table identity\\.${table} force row level security`),
      )
    }
    for (const table of PROFILE_TABLES) {
      expect(migrations, table).toMatch(
        new RegExp(`alter table profile\\.${table} force row level security`),
      )
    }
  })

  it("declares one policy per intended operation", () => {
    const found: Record<string, Set<string>> = {}
    for (const match of migrations.matchAll(
      /create policy \w+ on (identity|profile)\.([a-z_]+)\s+for (select|insert|update|delete)/gi,
    )) {
      const table = match[2]
      const operation = match[3].toUpperCase()
      found[table] ??= new Set()
      found[table].add(operation)
    }

    for (const [table, operations] of Object.entries(EXPECTED_POLICIES)) {
      expect(found[table], table).toEqual(new Set(operations))
    }
  })

  it("scopes profile policies to the API and readonly roles", () => {
    expect(migrations).toMatch(
      /create policy profiles_select on profile\.profiles\s+for select to hivorr_api, hivorr_readonly/,
    )
    expect(migrations).toMatch(
      /create policy profiles_insert on profile\.profiles\s+for insert to hivorr_api/,
    )
    expect(migrations).toMatch(
      /create policy activity_activations_select on profile\.activity_activations\s+for select to hivorr_api, hivorr_readonly/,
    )
  })

  it("fails closed when the identity context is unset", () => {
    // Every policy compares against the helper, which returns null when unset.
    const policyBlocks = [
      ...migrations.matchAll(/create policy [\s\S]*?(?=create policy|$)/g),
    ]
      .map((match) => match[0])
      .filter((block) => /on (identity|profile)\./.test(block))
      .join("\n")

    expect(policyBlocks).toMatch(/platform\.current_account_id\(\)/)
    expect(policyBlocks).toMatch(/platform\.current_user_id\(\)/)
  })
})
