/**
 * The host-to-audience mapping and resolution live in `common/audience`, next
 * to the guard that enforces them. This module keeps the identity import path
 * stable and gives the identity module one source of truth.
 */
export { resolveAudience, resolveRequestAudience } from "../../common/audience"
