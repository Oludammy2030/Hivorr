import { describe, expect, it } from "vitest"

import {
  composeAuthority,
  permissionScopes,
  platformPermissions,
  type GovernanceAuthority,
} from "../server/src/modules/admin"

const baseRow = {
  source: "role" as const,
  role_key: "investigator",
  permission_key: "admin.case.investigate",
  scope_type: "case" as const,
  scope_id: "case-1",
  expires_at: null,
}

const baseDenial = {
  permission_key: "admin.case.investigate",
  scope_type: "case" as const,
  scope_id: "case-1",
  expires_at: null,
}

describe("governance authority composition", () => {
  it("unions role permissions and individual grants", () => {
    const authority = composeAuthority(
      [
        baseRow,
        {
          source: "grant",
          role_key: null,
          permission_key: "admin.report.read",
          scope_type: "platform",
          scope_id: null,
          expires_at: null,
        },
      ],
      [],
    )

    expect(authority.roles).toEqual(["investigator"])
    expect(authority.permissions).toEqual([
      "admin.case.investigate",
      "admin.report.read",
    ])
    expect(authority.deniedPermissions).toEqual([])
  })

  it("removes a permission when its only scope is denied", () => {
    const authority = composeAuthority([baseRow], [baseDenial])

    expect(authority.permissions).toEqual([])
    expect(authority.deniedPermissions).toEqual(["admin.case.investigate"])
    expect(permissionScopes(authority, "admin.case.investigate")).toEqual([])
  })

  it("keeps the scope attached to each permission", () => {
    const authority = composeAuthority([baseRow], [])
    const scopes = permissionScopes(authority, "admin.case.investigate")
    expect(scopes).toHaveLength(1)
    expect(scopes[0]).toMatchObject({
      scopeType: "case",
      scopeId: "case-1",
      roleKey: "investigator",
    })
  })

  it("returns no authority for an empty input", () => {
    const authority: GovernanceAuthority = composeAuthority([], [])
    expect(authority).toEqual({
      roles: [],
      permissions: [],
      deniedPermissions: [],
      assignments: [],
      denials: [],
    })
    expect(permissionScopes(authority, "admin.user.read")).toEqual([])
  })

  it("does not let a denial of one permission suppress another", () => {
    const authority = composeAuthority(
      [
        baseRow,
        {
          ...baseRow,
          permission_key: "admin.case.recommend",
        },
      ],
      [baseDenial],
    )

    expect(authority.permissions).toEqual(["admin.case.recommend"])
    expect(permissionScopes(authority, "admin.case.recommend")).toHaveLength(1)
  })

  it("removes only the denied scope when another scope still allows", () => {
    const authority = composeAuthority(
      [
        baseRow,
        {
          ...baseRow,
          scope_id: "case-2",
        },
      ],
      [baseDenial],
    )

    expect(authority.permissions).toEqual(["admin.case.investigate"])
    expect(authority.deniedPermissions).toEqual([])
    const scopes = permissionScopes(authority, "admin.case.investigate")
    expect(scopes).toHaveLength(1)
    expect(scopes[0]?.scopeId).toBe("case-2")
  })

  it("lets a platform denial remove every scope", () => {
    const authority = composeAuthority(
      [
        baseRow,
        {
          ...baseRow,
          scope_id: "case-2",
        },
      ],
      [
        {
          ...baseDenial,
          scope_type: "platform",
          scope_id: null,
        },
      ],
    )

    expect(authority.permissions).toEqual([])
    expect(authority.deniedPermissions).toEqual(["admin.case.investigate"])
    expect(permissionScopes(authority, "admin.case.investigate")).toEqual([])
  })
})

describe("platform permissions for the session view", () => {
  it("keeps platform assignments and drops scoped ones", () => {
    const authority = composeAuthority(
      [
        {
          ...baseRow,
          permission_key: "admin.role.manage",
          scope_type: "platform",
          scope_id: null,
        },
        {
          ...baseRow,
          permission_key: "admin.case.read",
          scope_type: "department",
          scope_id: "dept-1",
        },
      ],
      [],
    )

    expect(platformPermissions(authority)).toEqual(["admin.role.manage"])
  })

  it("removes a permission denied at platform scope", () => {
    const authority = composeAuthority(
      [
        {
          ...baseRow,
          permission_key: "admin.role.manage",
          scope_type: "platform",
          scope_id: null,
        },
      ],
      [
        {
          ...baseDenial,
          permission_key: "admin.role.manage",
          scope_type: "platform",
          scope_id: null,
        },
      ],
    )

    expect(platformPermissions(authority)).toEqual([])
  })
})
