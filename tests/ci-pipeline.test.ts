import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const read = (relative: string) =>
  readFileSync(path.join(root, relative), "utf8").replace(/\r\n/g, "\n")

const ci = read(".github/workflows/ci.yml")
const manifest = JSON.parse(read("package.json")) as {
  scripts: Record<string, string>
}

const GATE_JOBS = [
  "install",
  "lint",
  "typecheck",
  "test",
  "gates",
  "openapi",
  "visual",
  "database",
  "build",
  "security",
]

const REQUIRED_COMMANDS = [
  "pnpm install --frozen-lockfile",
  "pnpm check:toolchain",
  "pnpm lint",
  "pnpm lint:boundaries",
  "pnpm lint:migrations",
  "pnpm format:check",
  "pnpm typecheck",
  "pnpm test",
  "pnpm test:contracts",
  "pnpm test:push-protection",
  "pnpm test:release",
  "pnpm test:topology",
  "pnpm test:gates",
  "pnpm migrations:apply",
  "pnpm migrations:verify",
  "pnpm db:snapshot",
  "pnpm db:diff",
  "pnpm db:check",
  "pnpm openapi:check",
  "pnpm openapi:diff",
  "pnpm visual:check",
  "pnpm security:secrets",
  "pnpm security:deps",
  "pnpm build:all",
  "pnpm build:server",
  "pnpm test:api",
  "pnpm test:worker-smoke",
]

describe("CI pipeline contract", () => {
  it("declares every required gate job", () => {
    for (const job of [...GATE_JOBS, "ci-complete"]) {
      expect(ci).toMatch(new RegExp(`^  ${job}:`, "m"))
    }
  })

  it("runs every required command", () => {
    for (const command of REQUIRED_COMMANDS) {
      expect(ci).toContain(command)
    }
  })

  it("keeps the gate scripts wired to their implementations", () => {
    expect(manifest.scripts["test:contracts"]).toBe(
      "vitest run tests/workspace-contracts.test.ts",
    )
    expect(manifest.scripts["lint:migrations"]).toBe(
      "node scripts/lint-migrations.mjs",
    )
    expect(manifest.scripts["db:snapshot"]).toBe(
      "node scripts/db-schema-snapshot.mjs",
    )
    expect(manifest.scripts["db:diff"]).toBe("node scripts/db-schema-diff.mjs")
    expect(manifest.scripts["openapi:diff"]).toBe(
      "node scripts/openapi-diff.mjs",
    )
    expect(manifest.scripts["visual:check"]).toBe(
      "node scripts/visual-diff.mjs",
    )
    expect(manifest.scripts["test:gates"]).toBe(
      "node scripts/test-ci-gates.mjs",
    )
  })

  it("makes ci-complete depend on every gate job", () => {
    const block = ci.split("  ci-complete:")[1] ?? ""
    const needs = block.split("needs:")[1]?.split("runs-on:")[0] ?? ""
    for (const job of GATE_JOBS) {
      expect(needs).toContain(`- ${job}`)
    }
  })

  it("stays read-only and introduces no new unpinned action", () => {
    expect(ci).toContain("permissions:\n  contents: read")
    expect(ci).not.toMatch(/permissions:[\s\S]*?\bwrite\b/)

    const actions = [...ci.matchAll(/uses:\s*(\S+)/g)].map((match) => match[1])
    expect(actions.length).toBeGreaterThan(0)
    for (const action of actions) {
      expect(action).toMatch(
        /^(?:actions\/(?:checkout|setup-node)|pnpm\/action-setup)@[0-9a-f]{40}$/,
      )
    }
  })

  it("runs the pipeline on pull requests and both protected branches", () => {
    expect(ci).toContain("pull_request:")
    expect(ci).toContain("      - main")
    expect(ci).toContain("      - staging")
  })

  it("proves the migration gate against a real Postgres service", () => {
    expect(ci).toContain("image: postgres:17")
    expect(ci).toContain('--health-cmd "pg_isready -U postgres"')
  })
})
