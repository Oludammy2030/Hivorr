/**
 * VFD integration boundary.
 *
 * `auth.ts` is documented and tested; the product adapters (`EP-02-042` to
 * `EP-02-044`) are not built. No VFD type crosses into the finance domain.
 */
export { VFD_TOKEN_URLS, VfdAuthClient } from "./auth"
export type { VfdAuthDependencies, VfdAuthOptions, VfdMode } from "./auth"
export { VFD_WALLET_BASE_URLS, VfdAccountNameClient } from "./account-name"
export type {
  VfdAccountNameDependencies,
  VfdAccountNameOptions,
  VfdRecipientDetails,
  VfdSourceDetails,
} from "./account-name"
export { VFD_TRANSFER_TYPE, VfdPayoutClient, VfdSha512TransferSigner } from "./payouts"
export type {
  VfdPayoutDependencies,
  VfdPayoutOptions,
  VfdPayoutPort,
  VfdTransferSignatureInput,
  VfdTransferSigner,
} from "./payouts"

export const VFD_AUTH = "HIVORR_VFD_AUTH" as const
export const VFD_ACCOUNT_NAME = "HIVORR_VFD_ACCOUNT_NAME" as const
export const VFD_PAYOUTS = "HIVORR_VFD_PAYOUTS" as const
