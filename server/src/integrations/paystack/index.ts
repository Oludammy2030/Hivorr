/**
 * Paystack integration boundary.
 *
 * The payout adapter is active for the provider switch; the collections and
 * webhook adapters (`EP-02-042`/`044`) are not built yet. No Paystack type
 * crosses into the finance domain.
 */
export { PAYSTACK_BASE_URL, PaystackPayoutClient } from "./payouts"
export type {
  PaystackMode,
  PaystackPayoutDependencies,
  PaystackPayoutOptions,
  PaystackPayoutPort,
} from "./payouts"
export { PaystackCollectionsClient, verifyPaystackSignature } from "./collections"
export type { PaystackCollections, PaystackCollectionsOptions } from "./collections"

export const PAYSTACK_PAYOUTS = "HIVORR_PAYSTACK_PAYOUTS" as const
