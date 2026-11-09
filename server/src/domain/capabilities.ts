import type { EnvironmentId, PortalId } from "@hivorr/shared"

export const CAPABILITY_IDS = [
  "session.read",
  "activity.activate",
  "admin.audit.read",
  "admin.grant.read",
  "admin.grant.manage",
  "staff.support.handle",
  "partner.referral.read",
  "platform.engineering.access",
] as const

export type CapabilityId = typeof CAPABILITY_IDS[number]

export type GrantId = "admin.audit.read" | "admin.grant.read" | "admin.grant.manage" | "staff.support.handle" | "partner.referral.read" | "platform.engineering"

export interface AccessContext {
  readonly authenticated: boolean
  readonly audience: PortalId
  readonly environment: EnvironmentId
  readonly grants: readonly GrantId[]
}

/**
 * Pure, default-deny capability computation.
 *
 * EP-01 owns only the inputs below. Capabilities that need a verification lane,
 * KYC tier, or a later-phase domain state are not granted here; they deny until
 * the owning phase supplies that input. No request body can widen this set.
 */
export function computeCapabilities(
  context: AccessContext,
): ReadonlySet<CapabilityId> {
  const capabilities = new Set<CapabilityId>()
  if (!context.authenticated) return capabilities

  capabilities.add("session.read")

  if (context.audience === "app") {
    capabilities.add("activity.activate")
  }

  if (
    context.audience === "control" &&
    context.grants.includes("admin.audit.read")
  ) {
    capabilities.add("admin.audit.read")
  }

  if (
    context.audience === "control" &&
    context.grants.includes("admin.grant.read")
  ) {
    capabilities.add("admin.grant.read")
  }

  if (
    context.audience === "control" &&
    context.grants.includes("admin.grant.manage")
  ) {
    capabilities.add("admin.grant.manage")
  }

  if (
    context.audience === "staff" &&
    context.grants.includes("staff.support.handle")
  ) {
    capabilities.add("staff.support.handle")
  }

  if (
    context.audience === "partner" &&
    context.grants.includes("partner.referral.read")
  ) {
    capabilities.add("partner.referral.read")
  }

  if (
    context.audience === "control" &&
    context.grants.includes("platform.engineering")
  ) {
    capabilities.add("platform.engineering.access")
  }

  return capabilities
}

export function can(context: AccessContext, capability: CapabilityId): boolean {
  return computeCapabilities(context).has(capability)
}
