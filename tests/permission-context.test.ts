import { describe, expect, it } from "vitest"

import { databasePermissionDenial } from "../server/src/common/errors"
import {
  computeCapabilities,
  type AccessContext,
} from "../server/src/domain/capabilities"
import {
  composeAuthority,
  withPlatformAuthority,
} from "../server/src/modules/admin"

const access: AccessContext = {
  authenticated: true,
  audience: "control",
  environment: "staging",
  grants: [],
}

function assignment(
  permissionKey: string,
  scopeType: "platform" | "department",
) {
  return {
    source: "role" as const,
    role_key: "governance_administrator",
    permission_key: permissionKey,
    scope_type: scopeType,
    scope_id: scopeType === "platform" ? null : "department-1",
    expires_at: null,
  }
}

describe("governance capability context", () => {
  it("does not turn a department-scoped permission into a capability", () => {
    const authority = composeAuthority(
      [assignment("admin.user.read", "department")],
      [],
    )

    const context = withPlatformAuthority(access, authority)

    expect(context.adminPermissions).toEqual([])
    expect(computeCapabilities(context).has("admin.user.read")).toBe(false)
  })

  it("keeps a platform-scoped permission as a capability", () => {
    const authority = composeAuthority(
      [assignment("admin.user.read", "platform")],
      [],
    )

    const context = withPlatformAuthority(access, authority)

    expect(context.adminPermissions).toEqual(["admin.user.read"])
    expect(computeCapabilities(context).has("admin.user.read")).toBe(true)
  })

  it("carries a platform denial through to the capability set", () => {
    const authority = composeAuthority(
      [assignment("admin.user.read", "platform")],
      [
        {
          permission_key: "admin.user.read",
          scope_type: "platform",
          scope_id: null,
          expires_at: null,
        },
      ],
    )

    const context = withPlatformAuthority(access, authority)

    expect(context.deniedPermissions).toEqual(["admin.user.read"])
    expect(computeCapabilities(context).has("admin.user.read")).toBe(false)
  })
})

describe("database permission denial mapping", () => {
  it("maps SQLSTATE 42501 to a stable 403", () => {
    const mapped = databasePermissionDenial(
      Object.assign(new Error("user_directory_forbidden"), { code: "42501" }),
    )

    expect(mapped).toMatchObject({ code: "FORBIDDEN", statusCode: 403 })
  })

  it("leaves other driver errors and non-errors alone", () => {
    expect(
      databasePermissionDenial(
        Object.assign(new Error("boom"), { code: "23505" }),
      ),
    ).toBeUndefined()
    expect(databasePermissionDenial(null)).toBeUndefined()
    expect(databasePermissionDenial("42501")).toBeUndefined()
  })
})
