import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const read = (relative: string) =>
  readFileSync(path.join(root, relative), "utf8")

const service = read("server/src/modules/identity/identity.service.ts")
const adapter = read("server/src/integrations/email/email.adapter.ts")

describe("credential and token policy", () => {
  it("uses the OWASP Argon2id minimum parameters", () => {
    expect(service).toMatch(/memoryCost:\s*19_456/)
    expect(service).toMatch(/timeCost:\s*2/)
    expect(service).toMatch(/parallelism:\s*1/)
    expect(service).toMatch(/algorithm:\s*2/)
  })

  it("defines short, explicit recovery token lifetimes", () => {
    expect(service).toMatch(/PASSWORD_RESET_TTL_MS = 30 \* 60 \* 1000/)
    expect(service).toMatch(
      /EMAIL_VERIFICATION_TTL_MS = 24 \* 60 \* 60 \* 1000/,
    )
  })

  it("hashes recovery tokens before storage and never logs them", () => {
    expect(service).toMatch(/hashSessionToken\(token\)/)
    expect(service).toMatch(/token_hash/)
    expect(service).not.toMatch(/console\.\w+\([^)]*token/i)
    expect(adapter).not.toMatch(/console\.\w+\(/)
  })

  it("consumes a reset token exactly once", () => {
    expect(service).toMatch(/consumed_at is null and expires_at > now\(\)/)
    expect(service).toMatch(/purpose = 'password_reset'/)
  })

  it("revokes active sessions when the password changes", () => {
    expect(service).toMatch(
      /set revoked_at = now\(\), revoked_reason = 'password_reset'/,
    )
  })
})
