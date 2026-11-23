import { existsSync, readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const MODULES = [
  "identity",
  "profile",
  "market",
  "services",
  "errands",
  "logistics",
  "finance",
  "messaging",
  "admin",
  "platform",
] as const

const ACTIVITY_MODULES = [
  "market",
  "services",
  "errands",
  "logistics",
  "finance",
  "messaging",
] as const

const root = process.cwd()
const modulesRoot = path.join(root, "server", "src", "modules")

function sourceFiles(directory: string, prefix = ""): string[] {
  const found: string[] = []
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name
    if (entry.isDirectory()) {
      found.push(...sourceFiles(path.join(directory, entry.name), relative))
    } else if (entry.name.endsWith(".ts")) {
      found.push(relative)
    }
  }
  return found
}

describe("ten-module skeleton", () => {
  it("contains exactly the ten architecture modules", () => {
    const directories = readdirSync(modulesRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort()
    expect(directories).toEqual([...MODULES].sort())
  })

  it("gives every module one public index.ts", () => {
    for (const module of MODULES) {
      expect(
        existsSync(path.join(modulesRoot, module, "index.ts")),
        `${module}/index.ts`,
      ).toBe(true)
    }
  })

  it("keeps activity modules without an owning phase as boundaries with no code", () => {
    const dormantModules = ACTIVITY_MODULES.filter(
      (module) => module !== "finance",
    )
    for (const module of dormantModules) {
      expect(sourceFiles(path.join(modulesRoot, module)), module).toEqual([
        "index.ts",
      ])
    }
  })

  it("exposes the finance posting, wallet, escrow, provider and limit domains", () => {
    expect(sourceFiles(path.join(modulesRoot, "finance"))).toEqual([
      "deposit-eligibility.service.ts",
      "escrow.service.ts",
      "idempotency.ts",
      "index.ts",
      "ledger.service.ts",
      "ledger.ts",
      "limit.service.ts",
      "limits.ts",
      "payout-account-crypto.ts",
      "payout-account.service.ts",
      "payout-execution.service.ts",
      "payout-request.service.ts",
      "provider-reference.service.ts",
      "wallet.service.ts",
    ])
  })

  it("does not export a controller from a module's public interface", () => {
    for (const module of MODULES) {
      const index = readFileSync(
        path.join(modulesRoot, module, "index.ts"),
        "utf8",
      )
      expect(index, `${module}/index.ts`).not.toContain(".controller")
    }
  })

  it("exposes the identity and platform public interfaces", () => {
    expect(
      readFileSync(path.join(modulesRoot, "identity", "index.ts"), "utf8"),
    ).toContain("IdentityService")
    expect(
      readFileSync(path.join(modulesRoot, "platform", "index.ts"), "utf8"),
    ).toContain("appendAudit")
  })

  it("has no tables in activity schemas that have not reached their owning phase", () => {
    const migrations = path.join(root, "supabase", "migrations")
    const dormantModules = ACTIVITY_MODULES.filter(
      (module) => module !== "finance",
    )
    const pattern = new RegExp(
      `create\\s+table\\s+(?:if\\s+not\\s+exists\\s+)?(?:${dormantModules.join("|")})\\.`,
      "i",
    )
    for (const file of readdirSync(migrations).filter((entry) =>
      entry.endsWith(".sql"),
    )) {
      const sql = readFileSync(path.join(migrations, file), "utf8")
      expect(sql, file).not.toMatch(pattern)
    }
  })

  it("creates finance tables only in the approved EP-02 migrations", () => {
    const migrations = path.join(root, "supabase", "migrations")
    const pattern = /create\s+table\s+(?:if\s+not\s+exists\s+)?finance\./i
    const creators = readdirSync(migrations)
      .filter((entry) => entry.endsWith(".sql"))
      .filter((file) =>
        pattern.test(readFileSync(path.join(migrations, file), "utf8")),
      )
    expect(creators).toEqual([
      "20261118000100_finance_create_ledger_tables.sql",
      "20261123000200_finance_add_payout_requests.sql",
    ])
  })
})
