/**
 * Public interface of the profiles and verification module.
 *
 * Other modules call this file only; the `profile` schema stays private to the
 * module and is enforced by `scripts/lint-boundaries.mjs`.
 */
export { listActiveActivities } from "./activities"
export type { ActivationView } from "./activities"
export { ProfileService } from "./profile.service"
export type { ActivityStateView } from "./profile.service"
