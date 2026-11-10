import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

import { BUNDLE_LAYOUT } from "../scripts/lib/release-manifest.mjs"

const PORTALS = ["control", "staff", "partner"] as const

function read(relative: string): string {
  return readFileSync(path.resolve(relative), "utf8")
}

describe("four application bundles", () => {
  it("records exactly the four release bundles", () => {
    expect(BUNDLE_LAYOUT.map((bundle) => bundle.name)).toEqual([
      "main",
      "control",
      "staff",
      "partner",
    ])
    expect(BUNDLE_LAYOUT.map((bundle) => bundle.relativeToDist)).toEqual([
      ".",
      "portals/control",
      "portals/staff",
      "portals/partner",
    ])
  })

  it("keeps the root web build as the noindex preview until the production target exists", () => {
    const site = JSON.parse(read(".figma/make/site.json")) as {
      robots?: { index?: boolean }
    }
    expect(site.robots?.index).toBe(false)
  })

  it("marks every privileged portal noindex, nofollow", () => {
    for (const portal of PORTALS) {
      const html = read(path.join("apps", portal, "index.html"))
      expect(html).toMatch(
        /<meta\s+name="robots"\s+content="noindex, nofollow"\s*\/?>/i,
      )
    }
  })

  it("builds each portal into its own output directory", () => {
    for (const portal of PORTALS) {
      const config = read(path.join("apps", portal, "vite.config.ts"))
      expect(config).toContain(`dist/portals/${portal}`)
      expect(config).toContain("emptyOutDir: true")
    }
  })

  it("keeps the portal workspace packages distinct and shared", () => {
    const names = new Set<string>()
    for (const portal of PORTALS) {
      const manifest = JSON.parse(
        read(path.join("apps", portal, "package.json")),
      ) as {
        name: string
        dependencies: Record<string, string>
      }
      expect(manifest.name).toBe(`@hivorr/app-${portal}`)
      expect(manifest.dependencies["@hivorr/shared"]).toBe("workspace:*")
      names.add(manifest.name)
    }
    expect(names.size).toBe(PORTALS.length)
  })

  it("builds all three portals from the shared build script", () => {
    const script = read("scripts/build-portals.mjs")
    for (const portal of PORTALS) {
      expect(script).toContain(`"${portal}"`)
    }
  })

  it("keeps the Figma Make preview entry", () => {
    expect(read("src/main.tsx")).toContain('import App from "./app/App"')
    expect(read("package.json")).toContain(
      "vite build --config vite.figma.config.ts",
    )
    expect(read("vite.figma.config.ts")).toContain(
      "import userConfig from './vite.config'",
    )
  })

  it("has no fourth portal left unbuilt", () => {
    expect(
      readdirSync("apps").filter((entry) => PORTALS.includes(entry as never)),
    ).toEqual([...PORTALS].sort())
  })
})
