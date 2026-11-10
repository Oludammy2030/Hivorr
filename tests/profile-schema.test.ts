import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

import { ACTIVITY_ACTIVATION_STATES, ACTIVITY_IDS } from "@hivorr/shared"

const root = process.cwd()
const sql = readFileSync(
  path.join(
    root,
    "supabase/migrations/20261109000300_profile_create_profile_tables.sql",
  ),
  "utf8",
)

function quotedList(block: string): string[] {
  return [...block.matchAll(/'([^']+)'/g)].map((match) => match[1])
}

describe("profile and activity schema", () => {
  it("creates one shared profile and one activation table", () => {
    expect(sql).toMatch(/create table profile\.profiles/)
    expect(sql).toMatch(/create table profile\.activity_activations/)
    expect(sql).toMatch(
      /account_id uuid primary key references identity\.accounts/,
    )
  })

  it("constrains exactly the six shared activity IDs", () => {
    const match = sql.match(/activity_id in \(([\s\S]*?)\)/)
    expect(match).not.toBeNull()
    expect(quotedList(match![1])).toEqual([...ACTIVITY_IDS])
  })

  it("constrains the four activation states", () => {
    const match = sql.match(/state in \(([\s\S]*?)\)/)
    expect(match).not.toBeNull()
    expect(quotedList(match![1])).toEqual([
      "INACTIVE",
      ...ACTIVITY_ACTIVATION_STATES,
    ])
  })

  it("makes activation idempotent at the database level", () => {
    expect(sql).toMatch(/unique \(account_id, activity_id\)/)
  })

  it("indexes the RLS and policy filter columns", () => {
    expect(sql).toMatch(
      /create index activity_activations_account_state_idx\s+on profile\.activity_activations \(account_id, state\)/,
    )
    expect(sql).toMatch(
      /create index activity_activations_activity_state_idx\s+on profile\.activity_activations \(activity_id, state\)/,
    )
  })

  it("uses UUIDv7 and timestamptz conventions", () => {
    expect(sql).toMatch(/id uuid primary key default platform\.uuidv7\(\)/)
    expect(sql).toMatch(/state_changed_at timestamptz not null/)
    expect(sql).toMatch(/created_at timestamptz not null default now\(\)/)
    expect(sql).toMatch(/updated_at timestamptz not null default now\(\)/)
  })

  it("enables RLS and declares select, insert and update policies", () => {
    for (const table of ["profiles", "activity_activations"]) {
      expect(sql, table).toMatch(
        new RegExp(`alter table profile\\.${table} enable row level security`),
      )
      expect(sql, table).toMatch(
        new RegExp(`${table}_select on profile\\.${table}`),
      )
      expect(sql, table).toMatch(
        new RegExp(`${table}_insert on profile\\.${table}`),
      )
      expect(sql, table).toMatch(
        new RegExp(`${table}_update on profile\\.${table}`),
      )
    }
    expect(sql).toMatch(/platform\.current_account_id\(\)/)
  })

  it("grants the API write access and readonly read access", () => {
    expect(sql).toMatch(
      /grant select, insert, update on profile\.profiles to hivorr_api/,
    )
    expect(sql).toMatch(
      /grant select, insert, update on profile\.activity_activations to hivorr_api/,
    )
    expect(sql).toMatch(
      /grant select on profile\.activity_activations to hivorr_readonly/,
    )
    expect(sql).toMatch(
      /grant execute on function platform\.current_account_id\(\) to hivorr_readonly/,
    )
  })

  it("comments both tables", () => {
    expect(sql).toMatch(/comment on table profile\.profiles is/)
    expect(sql).toMatch(/comment on table profile\.activity_activations is/)
  })
})
