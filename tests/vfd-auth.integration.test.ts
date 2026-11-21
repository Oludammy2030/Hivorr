import { describe, expect, it } from "vitest"

import { VfdAuthClient } from "../server/src/integrations/vfd"

/**
 * Runs only when the local environment holds a VFD test credential pair.
 * It never prints the token or the credential.
 */
const consumerKey = process.env.VFD_CONSUMER_KEY
const consumerSecret = process.env.VFD_CONSUMER_SECRET
const configured = Boolean(consumerKey && consumerSecret)

describe.skipIf(!configured)("VFD sandbox token (opt-in)", () => {
  it("issues a finite-lived token", async () => {
    const client = new VfdAuthClient({
      mode: "test",
      consumerKey,
      consumerSecret,
      tokenValidityMinutes: 5,
      requestTimeoutMs: 15_000,
      maxRetries: 1,
      retryBaseMs: 500,
    })

    const token = await client.getToken()

    expect(typeof token).toBe("string")
    expect(token.length).toBeGreaterThan(10)
  }, 30_000)
})
