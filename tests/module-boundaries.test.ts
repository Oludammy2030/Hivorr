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

  it("keeps the six activity modules as boundaries with no code", () => {
    for (const module of ACTIVITY_MODULES) {
      expect(sourceFiles(path.join(modulesRoot, module))).toEqual(["index.ts"])
    }
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

  it("has no tables in the activity schemas yet", () => {
    const migrations = path.join(root, "supabase", "migrations")
    const pattern = new RegExp(
      `create\\s+table\\s+(?:if\\s+not\\s+exists\\s+)?(?:${ACTIVITY_MODULES.join("|")})\\.`,
      "i",
    )
    for (const file of readdirSync(migrations).filter((entry) =>
      entry.endsWith(".sql"),
    )) {
      const sql = readFileSync(path.join(migrations, file), "utf8")
      expect(sql, file).not.toMatch(pattern)
    }
  })
})
