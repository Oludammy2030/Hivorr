/**
 * Presentation labels for capability and grant identifiers.
 *
 * These strings are display only. Authorisation never depends on them: the
 * capability keys in `capabilities.ts` stay the contract, and the server
 * remains the only place that decides what a caller may do.
 *
 * Every portal imports this module, so the same authority is described the same
 * way in the control, staff and partner shells.
 */

const CAPABILITY_LABELS: Readonly<Record<string, string>> = {
  "session.read": "Use your signed-in session",
  "profile.read.self": "See your own profile",
  "profile.update.self": "Edit your own profile",
  "activity.activate": "Turn on an activity",
  "activity.deactivate": "Turn off an activity",
  "admin.audit.read": "Read the audit log",
  "admin.grant.read": "See grants",
  "admin.grant.manage": "Create and revoke grants",
  "admin.user.read": "See the user directory",
  "admin.user.manage": "Manage user accounts",
  "admin.role.read": "See governance roles",
  "admin.role.manage": "Assign governance roles",
  "admin.verification.review": "Review verification evidence",
  "admin.payment.review": "Review payment exceptions",
  "admin.dispute.resolve": "Resolve disputes",
  "admin.account.suspend": "Suspend accounts",
  "admin.configuration.read": "Read configuration",
  "admin.configuration.write": "Change configuration",
  "admin.case.read": "See cases",
  "admin.case.assign": "Assign cases",
  "admin.case.investigate": "Investigate cases",
  "admin.case.recommend": "Recommend a case decision",
  "admin.case.approve": "Approve or reject a case decision",
  "admin.evidence.read": "Read case evidence",
  "admin.report.read": "Read governance reports",
  "admin.report.export": "Export governance reports",
  "staff.support.handle": "Handle support cases",
  "partner.referral.read": "See partner referrals",
  "platform.engineering": "Platform engineering access",
}

const GRANT_TYPE_LABELS: Readonly<Record<string, string>> = {
  admin: "Administrator",
  staff: "Staff",
  partner: "Partner",
  platform_engineering: "Engineering",
}

function humanise(key: string): string {
  const words = key.split(".").join(" ").split("_").join(" ").trim()
  if (!words) return key
  return words.charAt(0).toUpperCase() + words.slice(1)
}

/** Plain-language description of a capability or grant scope. */
export function capabilityLabel(key: string): string {
  return CAPABILITY_LABELS[key] ?? humanise(key)
}

export function grantTypeLabel(type: string): string {
  return GRANT_TYPE_LABELS[type] ?? humanise(type)
}
