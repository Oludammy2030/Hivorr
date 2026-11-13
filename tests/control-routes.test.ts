import { describe, expect, it } from "vitest"

import {
  NAV_GROUPS,
  SECTION_PATHS,
  SECTION_TITLES,
  canSee,
  isKnownPath,
  sectionFromPath,
  sectionTitle,
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

  it("keeps grants routable without a navigation item", () => {
    // Grants is reached contextually from the people and overview screens.
    // The URL must keep working even though it no longer occupies the nav.
    expect(isKnownPath("/grants")).toBe(true)
    expect(sectionFromPath("/grants")).toBe("grants")
    expect(allItems.some((item) => item.id === "grants")).toBe(false)
  })

  it("titles every section independently of the navigation", () => {
    for (const entry of SECTION_PATHS) {
      expect(sectionTitle(entry.section)).toBe(SECTION_TITLES[entry.section])
      expect(sectionTitle(entry.section).length).toBeGreaterThan(0)
    }
    expect(sectionTitle("grants")).toBe("Grants")
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
})
