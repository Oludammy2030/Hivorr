import { describe, expect, it } from "vitest"

import {
  declaredAudiences,
  isRoutedMethod,
  type RouteAudience,
} from "../server/src/common/audience"
import { GrantsController } from "../server/src/modules/identity/grants/grants.controller"
import { HealthController } from "../server/src/health/health.controller"
import { IdentityController } from "../server/src/modules/identity/identity.controller"
import { SessionController } from "../server/src/modules/identity/session.controller"
import { ActivityController } from "../server/src/api/activity.controller"
import { AuditController } from "../server/src/api/audit.controller"

const CONTROLLERS = [
  HealthController,
  IdentityController,
  SessionController,
  ActivityController,
  AuditController,
  GrantsController,
]

const VALID_AUDIENCES = new Set<RouteAudience>([
  "public",
  "app",
  "control",
  "staff",
  "partner",
])

/**
 * API-04: every endpoint declares its audience. This test reads the decorator
 * metadata directly, so it needs no database and no listening server.
 */
describe("audience declarations", () => {
  it("declares an audience on every routed method", () => {
    let routes = 0

    for (const controller of CONTROLLERS) {
      const classAudience = declaredAudiences(controller)

      for (const name of Object.getOwnPropertyNames(controller.prototype)) {
        if (name === "constructor") continue
        const descriptor = Object.getOwnPropertyDescriptor(
          controller.prototype,
          name,
        )
        if (!descriptor || !isRoutedMethod(descriptor.value)) continue

        routes += 1
        const declared = declaredAudiences(descriptor.value) ?? classAudience

        expect(declared, `${controller.name}.${name}`).toBeDefined()
        expect(declared!.length, `${controller.name}.${name}`).toBeGreaterThan(
          0,
        )
        for (const audience of declared!) {
          expect(
            VALID_AUDIENCES.has(audience),
            `${controller.name}.${name} declares ${audience}`,
          ).toBe(true)
        }
      }
    }

    expect(routes).toBeGreaterThan(0)
  })

  it("keeps infrastructure health public and control routes control-only", () => {
    expect(declaredAudiences(HealthController)).toEqual(["public"])

    const list = Object.getOwnPropertyDescriptor(
      GrantsController.prototype,
      "list",
    )!.value as (...args: never[]) => unknown
    expect(declaredAudiences(list)).toEqual(["control"])
  })
})
