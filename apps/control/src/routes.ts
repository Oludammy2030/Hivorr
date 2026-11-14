export type Section = "overview" | "users" | "staff" | "grants" | "audit" | "roles" | "denials" | "approvals" | "partners" | "cases" | "verification"

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
      {
        id: "partners",
        label: "Partners",
        path: "/partners",
        capabilities: ["admin.partner.read", "admin.partner.manage"],
      },
      {
        id: "cases",
        label: "Cases",
        path: "/cases",
        capabilities: ["admin.case.read", "admin.case.assign"],
      },
      {
        id: "verification",
        label: "Verification",
        path: "/verification",
        capabilities: ["admin.verification.review"],
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
        activePaths: ["/access/grants", "/access/denials"],
        capabilities: [
          "admin.role.read",
          "admin.role.manage",
          "admin.grant.read",
          "admin.grant.manage",
        ],
      },
      {
        id: "approvals",
        label: "Approvals",
        path: "/approvals",
        capabilities: ["admin.approval.read", "admin.approval.decide"],
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
  { section: "partners", path: "/partners" },
  { section: "cases", path: "/cases" },
  { section: "verification", path: "/verification" },
  { section: "roles", path: "/access/roles" },
  { section: "grants", path: "/access/grants" },
  { section: "denials", path: "/access/denials" },
  { section: "approvals", path: "/approvals" },
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
  partners: "Partners",
  cases: "Cases",
  verification: "Verification",
  grants: "Grants",
  roles: "Roles",
  denials: "Denials",
  approvals: "Approvals",
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
