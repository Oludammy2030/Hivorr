import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const read = (relative: string) =>
  readFileSync(path.join(root, relative), "utf8")

const tables = read("supabase/migrations/20261107000500_identity_tables.sql")
const rls = read("supabase/migrations/20261107000600_identity_rls.sql")
const mfa = read("supabase/migrations/20261107000800_mfa_challenges.sql")
const refresh = read("supabase/migrations/20261107000900_refresh_tokens.sql")
const comments = read(
  "supabase/migrations/20261109000200_identity_alter_table_comments.sql",
)
const schema = `${tables}\n${rls}\n${mfa}\n${refresh}\n${comments}`

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

function tableBlock(table: string): string {
  const match = schema.match(
    new RegExp(`create table identity\\.${table} \\(([\\s\\S]*?)\\n\\);`, "i"),
  )
  return match?.[1] ?? ""
}

describe("identity schema", () => {
  it("creates every identity table", () => {
    for (const table of IDENTITY_TABLES) {
      expect(tableBlock(table), table).not.toBe("")
    }
  })

  it("uses UUIDv7 identifiers and timestamptz timestamps", () => {
    for (const table of IDENTITY_TABLES) {
      const block = tableBlock(table)
      if (table === "credentials") {
        expect(block).toContain(
          "user_id uuid primary key references identity.users",
        )
      } else {
        expect(block, table).toContain(
          "id uuid primary key default platform.uuidv7()",
        )
      }
      expect(block, table).toContain("timestamptz")
    }
  })

  it("declares the state constraints", () => {
    expect(tableBlock("accounts")).toMatch(/status .*check \(status in/)
    expect(tableBlock("users")).toMatch(/status .*check \(status in/)
    expect(tableBlock("memberships")).toMatch(/role .*check \(role in/)
    expect(tableBlock("grants")).toMatch(/grant_type .*check \(grant_type in/)
    expect(tableBlock("sessions")).toMatch(/audience .*check \(audience in/)
    expect(tableBlock("sessions")).toMatch(
      /environment .*check \(environment in/,
    )
    expect(tableBlock("mfa_factors")).toMatch(
      /factor_type .*check \(factor_type in/,
    )
    expect(tableBlock("tokens")).toMatch(/purpose .*check \(purpose in/)
  })

  it("declares foreign keys to the identity spine", () => {
    for (const table of IDENTITY_TABLES.filter((name) => name !== "accounts")) {
      expect(tableBlock(table), table).toMatch(/references identity\.[a-z_]+/)
    }
  })

  it("enables row-level security on every table", () => {
    for (const table of IDENTITY_TABLES) {
      expect(schema, table).toMatch(
        new RegExp(
          `alter table identity\\.${table} enable row level security`,
          "i",
        ),
      )
    }
  })

  it("comments every table", () => {
    for (const table of IDENTITY_TABLES) {
      expect(schema, table).toMatch(
        new RegExp(`comment on table identity\\.${table} is`, "i"),
      )
    }
  })

  it("grants the API explicit table privileges", () => {
    for (const table of IDENTITY_TABLES) {
      expect(schema, table).toMatch(
        new RegExp(`grant [^;]+ on identity\\.${table} to hivorr_api`, "i"),
      )
    }
  })
})
