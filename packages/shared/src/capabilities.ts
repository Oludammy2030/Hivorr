import { z } from "zod"

/**
 * Capability and grant vocabulary.
 *
 * This module owns the identifiers only. The authoritative computation lives in
 * `server/src/domain/capabilities.ts`, because authorisation is a server
 * decision and never a client one (`AGENTS.md` Rule 4). Clients receive the
 * capability list for presentation only.
 *
 * The list is the full matrix (`matrix` §9.3) plus the privileged grant
 * capabilities. A capability that requires an activity, a verification lane,
 * KYC or an admin role is registered now and denies until the owning phase
 * supplies that input.
 */
export const CAPABILITY_IDS = [
  "session.read",
  "profile.read.self",
  "profile.update.self",
  "activity.activate",
  "activity.deactivate",
  "market.catalog.browse",
  "market.cart.manage",
  "market.order.place",
  "market.order.cancel",
  "market.order.dispute",
  "services.job.post",
  "services.job.post.business",
  "services.application.review",
  "services.engagement.fund",
  "services.job.apply",
  "services.service.publish",
  "services.engagement.deliver",
  "services.earnings.receive",
  "errands.request.create",
  "errands.request.cancel",
  "errands.request.track",
  "market.product.draft",
  "market.product.publish",
  "market.inventory.manage",
  "market.order.fulfil",
  "market.invoice.issue",
  "market.earnings.receive",
  "logistics.pool.browse",
  "logistics.assignment.accept",
  "logistics.delivery.progress",
  "logistics.delivery.complete",
  "logistics.earnings.receive",
  "business.create",
  "business.verification.submit",
  "business.update",
  "wallet.read",
  "wallet.withdraw",
  "wallet.payout_account.bind",
  "wallet.convert",
  "messaging.thread.read",
  "messaging.message.send",
  "notification.read",
  "admin.verification.review",
  "admin.payment.review",
  "admin.dispute.resolve",
  "admin.account.suspend",
  "admin.configuration.write",
  "admin.audit.read",
  "admin.grant.read",
  "admin.grant.manage",
  "staff.support.handle",
  "partner.referral.read",
  "platform.engineering.access",
] as const

export type CapabilityId = typeof CAPABILITY_IDS[number]

/**
 * Orthogonal privileged grants. A grant never activates an activity and never
 * implies another grant.
 */
export const GRANT_IDS = [
  "admin.audit.read",
  "admin.grant.read",
  "admin.grant.manage",
  "staff.support.handle",
  "partner.referral.read",
  "platform.engineering",
] as const

export type GrantId = typeof GRANT_IDS[number]

export const capabilityIdSchema = z.enum(CAPABILITY_IDS)

export const grantIdSchema = z.enum(GRANT_IDS)

export function isCapabilityId(value: string): value is CapabilityId {
  return (CAPABILITY_IDS as readonly string[]).includes(value)
}

export function isGrantId(value: string): value is GrantId {
  return (GRANT_IDS as readonly string[]).includes(value)
}
