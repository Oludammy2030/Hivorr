/**
 * Framework-free shared contracts for every Hivorr portal.
 *
 * This package must not import React, Node, the server, or another workspace
 * package. It is the single source for portal and environment identifiers used
 * by the applications, the API, and the release tooling.
 */

export const ENVIRONMENT_IDS = ["production", "staging"] as const

export type EnvironmentId = typeof ENVIRONMENT_IDS[number]

export interface EnvironmentDefinition {
  readonly id: EnvironmentId
  readonly label: string
  /** True when the environment is the live business environment. */
  readonly live: boolean
}

export const ENVIRONMENTS: Readonly<Record<EnvironmentId, EnvironmentDefinition>> =
  {
    production: { id: "production", label: "Production", live: true },
    staging: { id: "staging", label: "Staging", live: false },
  }

export const PORTAL_IDS = ["app", "control", "staff", "partner"] as const

export type PortalId = typeof PORTAL_IDS[number]

export interface PortalDefinition {
  readonly id: PortalId
  readonly name: string
  /** Session audience. One per portal, never shared. */
  readonly audience: PortalId
  readonly hosts: Readonly<Record<EnvironmentId, string>>
  /** True when the portal is not publicly indexable. */
  readonly noindex: boolean
}

export const PORTALS: Readonly<Record<PortalId, PortalDefinition>> = {
  app: {
    id: "app",
    name: "Main Hivorr platform",
    audience: "app",
    hosts: { production: "hivorr.com", staging: "staging.hivorr.com" },
    noindex: false,
  },
  control: {
    id: "control",
    name: "Control portal",
    audience: "control",
    hosts: {
      production: "control.hivorr.com",
      staging: "control.staging.hivorr.com",
    },
    noindex: true,
  },
  staff: {
    id: "staff",
    name: "Staff portal",
    audience: "staff",
    hosts: {
      production: "staff.hivorr.com",
      staging: "staff.staging.hivorr.com",
    },
    noindex: true,
  },
  partner: {
    id: "partner",
    name: "Partner portal",
    audience: "partner",
    hosts: {
      production: "partner.hivorr.com",
      staging: "partner.staging.hivorr.com",
    },
    noindex: true,
  },
}

export function getPortal(id: PortalId): PortalDefinition {
  return PORTALS[id]
}

export function getPortalByHost(
  host: string,
  environment: EnvironmentId,
): PortalDefinition | undefined {
  const normalized = host.trim().toLowerCase().split(":")[0]
  return Object.values(PORTALS).find(
    (portal) => portal.hosts[environment] === normalized,
  )
}

export const RELEASE_MANIFEST_VERSION = 1 as const

export interface ReleaseArtifact {
  readonly name: string
  readonly digest: string
}

export interface ReleaseManifest {
  readonly manifestVersion: typeof RELEASE_MANIFEST_VERSION
  readonly releaseTag: string
  readonly commitSha: string
  readonly builtAt: string
  readonly artifacts: readonly ReleaseArtifact[]
  readonly migrationHash: string
}

export function isProductionHost(host: string): boolean {
  return getPortalByHost(host, "production") !== undefined
}
