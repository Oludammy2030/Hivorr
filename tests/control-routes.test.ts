import { describe, expect, it } from "vitest"

import {
  NAV_GROUPS,
  SECTION_PATHS,
  canSee,
  isKnownPath,
  sectionFromPath,
} from "../apps/control/src/routes"

const allItems = NAV_GROUPS.flatMap((group) => group.items)

describe("control portal route manifest", () => {
  it("maps every known path to exactly one section", () => {
    const sections = SECTION_PATHS.map((entry) => entry.section)
    expect(new Set(sections).size).toBe(SECTION_PATHS.length)
    expect(sectionFromPath("/")).toBe("overview")
    expect(sectionFromPath("/users")).toBe("users")
    expect(sectionFromPath("/grants")).toBe("grants")
    expect(sectionFromPath("/audit")).toBe("audit")
  })

  it("treats unknown and trailing-slash paths as unknown", () => {
    expect(isKnownPath("/")).toBe(true)
    expect(isKnownPath("/users")).toBe(true)
    expect(isKnownPath("/users/")).toBe(false)
    expect(isKnownPath("/nope")).toBe(false)
    expect(sectionFromPath("/nope")).toBe("overview")
  })

  it("has no navigation item without a reachable path", () => {
    for (const item of allItems) {
      expect(isKnownPath(item.path), item.label).toBe(true)
    }
    expect(new Set(allItems.map((item) => item.id)).size).toBe(allItems.length)
  })

  it("always shows an item without a capability requirement", () => {
    expect(canSee(allItems[0]!, [])).toBe(true)
  })

  it("requires at least one matching capability for a guarded item", () => {
    const users = allItems.find((item) => item.id === "users")!
    expect(canSee(users, [])).toBe(false)
    expect(canSee(users, ["admin.user.read"])).toBe(true)
    expect(canSee(users, ["admin.grant.read"])).toBe(false)
  })

  it("lets either grant capability reveal the grants item", () => {
    const grants = allItems.find((item) => item.id === "grants")!
    expect(canSee(grants, ["admin.grant.read"])).toBe(true)
    expect(canSee(grants, ["admin.grant.manage"])).toBe(true)
    expect(canSee(grants, ["admin.user.read"])).toBe(false)
  })
})
