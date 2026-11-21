/**
 * VFD integration boundary.
 *
 * `auth.ts` is documented and tested; the product adapters (`EP-02-042` to
 * `EP-02-044`) are not built. No VFD type crosses into the finance domain.
 */
export { VFD_TOKEN_URLS, VfdAuthClient } from "./auth"
export type { VfdAuthDependencies, VfdAuthOptions, VfdMode } from "./auth"

export const VFD_AUTH = "HIVORR_VFD_AUTH" as const
