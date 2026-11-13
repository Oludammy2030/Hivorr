export type Section = "overview" | "users" | "staff" | "grants" | "audit" | "roles"

export interface SectionLink {
  readonly id: Section
  readonly label: string
  readonly path: string
  /** Paths that keep this item highlighted, such as the sibling tab. */
  readonly activePaths?: readonly string[]
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
    ],
  },
  {
    label: "Security",
    items: [
      {
        id: "roles",
        label: "Access",
        path: "/access/roles",
        activePaths: ["/access/grants"],
        capabilities: [
          "admin.role.read",
          "admin.role.manage",
          "admin.grant.read",
          "admin.grant.manage",
        ],
      },
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
  { section: "roles", path: "/access/roles" },
  { section: "grants", path: "/access/grants" },
  { section: "audit", path: "/audit" },
]

/**
 * Section headings are independent of the navigation on purpose: Grants is
 * reached contextually and is not a nav item, but it is still a real section
 * and must carry its own title.
 */
export const SECTION_TITLES: Readonly<Record<Section, string>> = {
  overview: "Overview",
  users: "Users",
  staff: "Staff",
  grants: "Grants",
  roles: "Roles",
  audit: "Audit",
}

export function sectionTitle(section: Section): string {
  return SECTION_TITLES[section]
}

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
