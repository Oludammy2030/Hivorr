import type { EnvironmentId, PortalId } from "@hivorr/shared"

import type { ApiConfig } from "../../config"

const HOSTS: Readonly<Record<EnvironmentId, Readonly<Record<PortalId, string>>>> =
  {
    production: {
      app: "hivorr.com",
      control: "control.hivorr.com",
      staff: "staff.hivorr.com",
      partner: "partner.hivorr.com",
    },
    staging: {
      app: "staging.hivorr.com",
      control: "control-staging.hivorr.com",
      staff: "staff-staging.hivorr.com",
      partner: "partner-staging.hivorr.com",
    },
  }

/**
 * The audience is derived from the host, not from a client-provided field.
 * The API only runs in staging or production. A development/test API has no
 * portal host and must not serve a session endpoint.
 */
export function resolveAudience(
  hostHeader: string | undefined,
  environment: ApiConfig["environment"],
): PortalId | undefined {
  if (environment !== "staging" && environment !== "production") return
  if (!hostHeader) return

  const env: EnvironmentId = environment
  const host = hostHeader.toLowerCase().split(":")[0]
  const hosts = HOSTS[env]
  return (Object.keys(hosts) as PortalId[]).find(
    (audience) => hosts[audience] === host,
  )
}
