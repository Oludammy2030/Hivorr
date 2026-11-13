import { describe, expect, it } from "vitest"

import { HealthController } from "../server/src/health/health.controller"
import { GrantsController } from "../server/src/modules/identity/grants/grants.controller"
import { IdentityController } from "../server/src/modules/identity/identity.controller"
import { SessionController } from "../server/src/modules/identity/session.controller"
import { ActivityController } from "../server/src/api/activity.controller"
import { AuditController } from "../server/src/api/audit.controller"
import { ControlAuthorityController } from "../server/src/api/control-authority.controller"
import { UsersController } from "../server/src/api/users.controller"
import { StaffController } from "../server/src/api/staff.controller"
import { StaffInviteController } from "../server/src/api/staff-invite.controller"
import { RolesController } from "../server/src/api/roles.controller"
import { buildDocument } from "../server/src/openapi/build"
import { scanControllerRoutes } from "../server/src/openapi/scan"

/**
 * The contract and the controllers must describe the same surface. This test
 * imports the controllers, so it runs on Linux where the argon2 binding loads.
 */
describe("OpenAPI route coverage", () => {
  it("documents every controller route and nothing else", () => {
    const scanned = [
      HealthController,
      IdentityController,
      SessionController,
      ActivityController,
      AuditController,
      ControlAuthorityController,
      UsersController,
      StaffController,
      StaffInviteController,
      RolesController,
      GrantsController,
    ]
      .flatMap((controller) => scanControllerRoutes(controller))
      .map((route) => `${route.method} ${route.path}`)
      .sort()

    const document = buildDocument()
    const documented = Object.entries(document.paths)
      .flatMap(([operationPath, pathItem]) =>
        Object.keys(pathItem).map((method) => `${method} ${operationPath}`),
      )
      .sort()

    expect(documented).toEqual(scanned)
  })
})
