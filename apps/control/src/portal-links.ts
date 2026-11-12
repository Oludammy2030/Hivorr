/**
 * The main portal owns the staff invitation page. The control portal runs on a
 * sibling host: `control-staging.hivorr.com` beside `staging.hivorr.com`, and
 * `control.hivorr.com` beside `hivorr.com` (config/environments.json). Building
 * the link from the control origin would send invitees to the wrong portal, so
 * strip the `control-` or `control.` prefix instead.
 */
export interface PortalLocation {
  readonly protocol: string
  readonly hostname: string
  readonly origin: string
}

export function mainPortalOrigin(location: PortalLocation): string {
  const mainHostname = location.hostname.replace(/^control[-.]/, "")
  if (mainHostname === location.hostname) return location.origin
  return `${location.protocol}//${mainHostname}`
}

export function staffInviteLink(
  location: PortalLocation,
  token: string,
): string {
  return `${mainPortalOrigin(location)}/invite.html?token=${encodeURIComponent(token)}`
}
