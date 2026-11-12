import { describe, expect, it } from "vitest"

import {
  mainPortalOrigin,
  staffInviteLink,
} from "../apps/control/src/portal-links"

describe("control portal links", () => {
  it("points staging control at the staging main portal", () => {
    expect(
      mainPortalOrigin({
        protocol: "https:",
        hostname: "control-staging.hivorr.com",
        origin: "https://control-staging.hivorr.com",
      }),
    ).toBe("https://staging.hivorr.com")
  })

  it("points production control at the production main portal", () => {
    expect(
      mainPortalOrigin({
        protocol: "https:",
        hostname: "control.hivorr.com",
        origin: "https://control.hivorr.com",
      }),
    ).toBe("https://hivorr.com")
  })

  it("keeps local development on the current origin", () => {
    expect(
      mainPortalOrigin({
        protocol: "http:",
        hostname: "localhost",
        origin: "http://localhost:8443",
      }),
    ).toBe("http://localhost:8443")
  })

  it("builds the invite page URL with an encoded token", () => {
    expect(
      staffInviteLink(
        {
          protocol: "https:",
          hostname: "control-staging.hivorr.com",
          origin: "https://control-staging.hivorr.com",
        },
        "token value/with+chars",
      ),
    ).toBe(
      "https://staging.hivorr.com/invite.html?token=token%20value%2Fwith%2Bchars",
    )
  })
})
