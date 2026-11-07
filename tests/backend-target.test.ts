import { describe, expect, it } from "vitest"

import { verifyBackendTarget } from "../scripts/lib/backend-target-policy.mjs"

const stagingRef = "abcdefghijklmnopqrst"
const productionRef = "zyxwvutsrqponmlkjihg"
const fakeUrl = (ref) =>
  `postgresql://postgres:fake@db.${ref}.supabase.co:5432/postgres`

const base = {
  HIVORR_ENV: "staging",
  BACKEND_ENVIRONMENT: "staging",
  SUPABASE_PROJECT_REF: stagingRef,
  EXPECTED_SUPABASE_PROJECT_REF: stagingRef,
  STAGING_SUPABASE_PROJECT_REF: stagingRef,
  PRODUCTION_SUPABASE_PROJECT_REF: productionRef,
  DATABASE_URL: fakeUrl(stagingRef),
}

describe("backend target isolation", () => {
  it("accepts a correctly targeted staging deployment", () => {
    expect(verifyBackendTarget(base)).toMatchObject({
      ok: true,
      environment: "staging",
      projectRef: stagingRef,
    })
  })

  it("rejects a staging deployment pointed at production", () => {
    const result = verifyBackendTarget({
      ...base,
      SUPABASE_PROJECT_REF: productionRef,
      EXPECTED_SUPABASE_PROJECT_REF: productionRef,
      DATABASE_URL: fakeUrl(productionRef),
    })
    expect(result.ok).toBe(false)
    expect(result.issues.join(" ")).toContain("other environment")
  })

  it("rejects a database URL from another project", () => {
    const result = verifyBackendTarget({
      ...base,
      DATABASE_URL: fakeUrl(productionRef),
    })
    expect(result.ok).toBe(false)
    expect(result.issues.join(" ")).toContain("DATABASE_URL")
  })

  it("rejects a missing expected reference", () => {
    const result = verifyBackendTarget({
      ...base,
      EXPECTED_SUPABASE_PROJECT_REF: "",
    })
    expect(result.ok).toBe(false)
  })

  it("rejects a shared project across environments", () => {
    const result = verifyBackendTarget({
      ...base,
      PRODUCTION_SUPABASE_PROJECT_REF: stagingRef,
    })
    expect(result.ok).toBe(false)
    expect(result.issues.join(" ")).toContain("must not share")
  })
})
