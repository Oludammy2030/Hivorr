import {
  CAPABILITY_IDS,
  isCapabilityId,
  type ActivityId,
  type CapabilityId,
  type EnvironmentId,
  type GrantId,
  type PortalId,
} from "@hivorr/shared"

/**
 * Capability identifiers are owned by `@hivorr/shared` so the API and every
 * client cannot drift. This module owns only the authoritative computation and
 * the requirement table.
 */
export { CAPABILITY_IDS } from "@hivorr/shared"
export type { CapabilityId, GrantId } from "@hivorr/shared"

export const CAPABILITY_DENY_REASONS = [
  "UNAUTHENTICATED",
  "WRONG_AUDIENCE",
  "MISSING_GRANT",
  "MISSING_PERMISSION",
  "EXPLICIT_DENY",
  "MISSING_ADMIN_ROLE",
  "MEMBERSHIP_REQUIRED",
  "BUSINESS_STATE",
  "ACTIVITY_INACTIVE",
  "VERIFICATION_REQUIRED",
  "KYC_REQUIRED",
  "PAYOUT_ACCOUNT_REQUIRED",
  "UNKNOWN_CAPABILITY",
] as const

export type CapabilityDenyReason = typeof CAPABILITY_DENY_REASONS[number]

export type CapabilityDecision = { readonly allowed: true } | {
  readonly allowed: false
  readonly reason: CapabilityDenyReason
}

export type VerificationLane = "identity" | "trade" | "seller" | "logistics" | "business"

/**
 * The financial ladder is OPEN beyond tier_1; the capability engine only needs
 * to distinguish unverified (tier_0) from verified (tier_1 and above).
 */
export type KycTier = "tier_0" | "tier_1"

export type AdminRole = "verification.review" | "payment.review" | "dispute.resolve" | "account.manage" | "configuration.write"

export interface AccessContext {
  readonly authenticated: boolean
  readonly audience: PortalId
  readonly environment: EnvironmentId
  readonly grants: readonly GrantId[]
  /** Activities whose state is ACTIVE, RESTRICTED or SUSPENDED. */
  readonly activities?: readonly ActivityId[]
  readonly verification?: Partial<Record<VerificationLane, boolean>>
  readonly kycTier?: KycTier
  /** Effective governance permissions composed from roles and individual grants. */
  readonly adminPermissions?: readonly string[]
  /** Explicit governance denials. An active denial always overrides an allow. */
  readonly deniedPermissions?: readonly string[]
  /** @deprecated Roles are collections of permissions; use `adminPermissions`. */
  readonly adminRoles?: readonly AdminRole[]
  readonly member?: boolean
  /** True once the business verification is approved; updates are frozen. */
  readonly businessApproved?: boolean
  readonly payoutAccountBound?: boolean
}

export interface CapabilityRule {
  readonly audience: readonly PortalId[] | "any"
  readonly activity?: ActivityId
  readonly verification?: VerificationLane
  readonly kyc?: boolean
  readonly grant?: GrantId
  /** Governance permission required by the capability. */
  readonly permission?: string
  /** @deprecated Use `permission`; roles are collections, not capability gates. */
  readonly adminRole?: AdminRole
  readonly requiresMember?: boolean
  readonly requiresBusinessUnapproved?: boolean
  readonly requiresPayoutAccount?: boolean
}

const ANY = "any" as const
const APP = ["app"] as const
const CONTROL = ["control"] as const
const STAFF = ["staff"] as const
const PARTNER = ["partner"] as const

/**
 * The full matrix (`matrix` §9.3). A rule is evaluated only from the typed
 * context; no request body can add a capability.
 */
export const CAPABILITY_RULES: Readonly<Record<CapabilityId, CapabilityRule>> =
  {
    "session.read": { audience: ANY },
    "profile.read.self": { audience: ANY },
    "profile.update.self": { audience: ANY },
    "activity.activate": { audience: APP },
    "activity.deactivate": { audience: APP },

    "market.catalog.browse": { audience: ANY },
    "market.cart.manage": { audience: APP, activity: "market.buy" },
    "market.order.place": {
      audience: APP,
      activity: "market.buy",
      kyc: true,
    },
    "market.order.cancel": { audience: APP, activity: "market.buy" },
    "market.order.dispute": { audience: APP, activity: "market.buy" },

    "services.job.post": { audience: APP, activity: "services.hire" },
    "services.job.post.business": {
      audience: APP,
      activity: "services.hire",
      verification: "business",
    },
    "services.application.review": {
      audience: APP,
      activity: "services.hire",
    },
    "services.engagement.fund": {
      audience: APP,
      activity: "services.hire",
      kyc: true,
    },
    "services.job.apply": {
      audience: APP,
      activity: "services.offer",
      verification: "identity",
    },
    "services.service.publish": {
      audience: APP,
      activity: "services.offer",
      verification: "trade",
    },
    "services.engagement.deliver": {
      audience: APP,
      activity: "services.offer",
      verification: "identity",
    },
    "services.earnings.receive": {
      audience: APP,
      activity: "services.offer",
      verification: "trade",
      kyc: true,
    },

    "errands.request.create": { audience: APP, activity: "errands.request" },
    "errands.request.cancel": { audience: APP, activity: "errands.request" },
    "errands.request.track": { audience: APP, activity: "errands.request" },

    "market.product.draft": { audience: APP, activity: "market.sell" },
    "market.product.publish": {
      audience: APP,
      activity: "market.sell",
      verification: "seller",
    },
    "market.inventory.manage": {
      audience: APP,
      activity: "market.sell",
      verification: "seller",
    },
    "market.order.fulfil": {
      audience: APP,
      activity: "market.sell",
      verification: "seller",
    },
    "market.invoice.issue": {
      audience: APP,
      activity: "market.sell",
      verification: "seller",
    },
    "market.earnings.receive": {
      audience: APP,
      activity: "market.sell",
      verification: "seller",
      kyc: true,
    },

    "logistics.pool.browse": {
      audience: APP,
      activity: "logistics.provide",
    },
    "logistics.assignment.accept": {
      audience: APP,
      activity: "logistics.provide",
      verification: "logistics",
      kyc: true,
    },
    "logistics.delivery.progress": {
      audience: APP,
      activity: "logistics.provide",
      verification: "logistics",
    },
    "logistics.delivery.complete": {
      audience: APP,
      activity: "logistics.provide",
      verification: "logistics",
    },
    "logistics.earnings.receive": {
      audience: APP,
      activity: "logistics.provide",
      verification: "logistics",
      kyc: true,
    },

    "business.create": { audience: ANY },
    "business.verification.submit": { audience: ANY, requiresMember: true },
    "business.update": {
      audience: ANY,
      requiresMember: true,
      requiresBusinessUnapproved: true,
    },

    "wallet.read": { audience: ANY },
    "wallet.withdraw": {
      audience: ANY,
      kyc: true,
      requiresPayoutAccount: true,
    },
    "wallet.payout_account.bind": { audience: ANY, kyc: true },
    "wallet.convert": { audience: ANY, kyc: true },

    "messaging.thread.read": { audience: ANY },
    "messaging.message.send": { audience: ANY },
    "notification.read": { audience: ANY },

    "admin.verification.review": {
      audience: CONTROL,
      permission: "admin.verification.review",
    },
    "admin.payment.review": {
      audience: CONTROL,
      permission: "admin.payment.review",
    },
    "admin.dispute.resolve": {
      audience: CONTROL,
      permission: "admin.dispute.resolve",
    },
    "admin.account.suspend": {
      audience: CONTROL,
      permission: "admin.account.suspend",
    },
    "admin.configuration.write": {
      audience: CONTROL,
      permission: "admin.configuration.write",
    },
    "admin.configuration.read": {
      audience: CONTROL,
      permission: "admin.configuration.read",
    },
    "admin.audit.read": {
      audience: CONTROL,
      grant: "admin.audit.read",
    },
    "admin.grant.read": {
      audience: CONTROL,
      grant: "admin.grant.read",
    },
    "admin.grant.manage": {
      audience: CONTROL,
      grant: "admin.grant.manage",
    },
    "admin.user.read": {
      audience: CONTROL,
      permission: "admin.user.read",
    },
    "admin.user.manage": {
      audience: CONTROL,
      permission: "admin.user.manage",
    },
    "admin.role.read": {
      audience: CONTROL,
      permission: "admin.role.read",
    },
    "admin.role.manage": {
      audience: CONTROL,
      permission: "admin.role.manage",
    },
    "admin.case.read": {
      audience: CONTROL,
      permission: "admin.case.read",
    },
    "admin.case.assign": {
      audience: CONTROL,
      permission: "admin.case.assign",
    },
    "admin.case.investigate": {
      audience: CONTROL,
      permission: "admin.case.investigate",
    },
    "admin.case.recommend": {
      audience: CONTROL,
      permission: "admin.case.recommend",
    },
    "admin.case.approve": {
      audience: CONTROL,
      permission: "admin.case.approve",
    },
    "admin.evidence.read": {
      audience: CONTROL,
      permission: "admin.evidence.read",
    },
    "admin.report.read": {
      audience: CONTROL,
      permission: "admin.report.read",
    },
    "admin.report.export": {
      audience: CONTROL,
      permission: "admin.report.export",
    },
    "staff.support.handle": {
      audience: STAFF,
      grant: "staff.support.handle",
    },
    "partner.referral.read": {
      audience: PARTNER,
      grant: "partner.referral.read",
    },
    "platform.engineering.access": {
      audience: CONTROL,
      grant: "platform.engineering",
    },
  }

function deny(reason: CapabilityDenyReason): CapabilityDecision {
  return { allowed: false, reason }
}

/**
 * Pure, default-deny evaluation. The order is stable so a deny reason is
 * predictable and testable.
 */
export function evaluateCapability(
  context: AccessContext,
  capability: string,
): CapabilityDecision {
  if (!isCapabilityId(capability)) return deny("UNKNOWN_CAPABILITY")
  const rule = CAPABILITY_RULES[capability]

  if (!context.authenticated) return deny("UNAUTHENTICATED")
  if (rule.audience !== ANY && !rule.audience.includes(context.audience)) {
    return deny("WRONG_AUDIENCE")
  }
  if (rule.grant && !context.grants.includes(rule.grant)) {
    return deny("MISSING_GRANT")
  }
  if (
    rule.permission &&
    (context.deniedPermissions ?? []).includes(rule.permission)
  ) {
    return deny("EXPLICIT_DENY")
  }
  if (
    rule.permission &&
    !(context.adminPermissions ?? []).includes(rule.permission)
  ) {
    return deny("MISSING_PERMISSION")
  }
  if (rule.adminRole && !(context.adminRoles ?? []).includes(rule.adminRole)) {
    return deny("MISSING_ADMIN_ROLE")
  }
  if (rule.requiresMember && context.member !== true) {
    return deny("MEMBERSHIP_REQUIRED")
  }
  if (rule.requiresBusinessUnapproved && context.businessApproved !== false) {
    return deny("BUSINESS_STATE")
  }
  if (rule.activity && !(context.activities ?? []).includes(rule.activity)) {
    return deny("ACTIVITY_INACTIVE")
  }
  if (rule.verification && context.verification?.[rule.verification] !== true) {
    return deny("VERIFICATION_REQUIRED")
  }
  if (rule.kyc && context.kycTier !== "tier_1") {
    return deny("KYC_REQUIRED")
  }
  if (rule.requiresPayoutAccount && context.payoutAccountBound !== true) {
    return deny("PAYOUT_ACCOUNT_REQUIRED")
  }

  return { allowed: true }
}

export function computeCapabilities(
  context: AccessContext,
): ReadonlySet<CapabilityId> {
  const capabilities = new Set<CapabilityId>()
  for (const capability of CAPABILITY_IDS) {
    if (evaluateCapability(context, capability).allowed) {
      capabilities.add(capability)
    }
  }
  return capabilities
}

export function can(context: AccessContext, capability: CapabilityId): boolean {
  return evaluateCapability(context, capability).allowed
}
