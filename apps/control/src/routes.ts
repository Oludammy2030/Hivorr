export type Section = "overview" | "users" | "staff" | "grants" | "audit"

export interface SectionLink {
  readonly id: Section
  readonly label: string
  readonly path: string
  /** Any one of these capabilities reveals the item. Omitted means always visible. */
  readonly capabilities?: readonly string[]
}

export interface NavGroup {
  readonly label: string
  readonly items: readonly SectionLink[]
}

export const NAV_GROUPS: readonly NavGroup[] = [
  {
    label: "Governance",
    items: [{ id: "overview", label: "Overview", path: "/" }],
  },
  {
    label: "People",
    items: [
      {
        id: "users",
        label: "Users",
        path: "/users",
        capabilities: ["admin.user.read"],
      },
      {
        id: "staff",
        label: "Staff",
        path: "/staff",
        capabilities: ["admin.user.read"],
      },
      {
        id: "grants",
        label: "Grants",
        path: "/grants",
        capabilities: ["admin.grant.read", "admin.grant.manage"],
      },
    ],
  },
  {
    label: "Security",
    items: [
      {
        id: "audit",
        label: "Audit",
        path: "/audit",
        capabilities: ["admin.audit.read"],
      },
    ],
  },
]

interface SectionPath {
  section: Section
  path: string
}

export const SECTION_PATHS: readonly SectionPath[] = [
  { section: "overview", path: "/" },
  { section: "users", path: "/users" },
  { section: "staff", path: "/staff" },
  { section: "grants", path: "/grants" },
  { section: "audit", path: "/audit" },
]

export function sectionFromPath(pathname: string): Section {
  return (
    SECTION_PATHS.find((entry) => entry.path === pathname)?.section ??
    "overview"
  )
}

export function isKnownPath(pathname: string): boolean {
  return SECTION_PATHS.some((entry) => entry.path === pathname)
}

export function canSee(
  item: SectionLink,
  capabilities: readonly string[],
): boolean {
  if (!item.capabilities) return true
  return item.capabilities.some((capability) =>
    capabilities.includes(capability),
  )
}
