import { RequestMethod } from "@nestjs/common"
import { METHOD_METADATA, PATH_METADATA } from "@nestjs/common/constants"

/**
 * Read a controller's route metadata without booting the Nest application.
 * Used only by the route-coverage test; the generator reads the registry.
 */
const METHOD_NAMES: Readonly<Record<number, string>> = {
  [RequestMethod.GET]: "get",
  [RequestMethod.POST]: "post",
  [RequestMethod.PUT]: "put",
  [RequestMethod.PATCH]: "patch",
  [RequestMethod.DELETE]: "delete",
}

function asPaths(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String)
  if (typeof value === "string") return [value]
  return [""]
}

export interface ScannedRoute {
  readonly method: string
  readonly path: string
}

export function scanControllerRoutes(
  controller: Function,
  prefix = "/v1",
): ScannedRoute[] {
  const controllerPaths = asPaths(
    Reflect.getMetadata(PATH_METADATA, controller),
  )
  const routes: ScannedRoute[] = []

  for (const name of Object.getOwnPropertyNames(controller.prototype)) {
    if (name === "constructor") continue
    const descriptor = Object.getOwnPropertyDescriptor(
      controller.prototype,
      name,
    )
    if (!descriptor || typeof descriptor.value !== "function") continue

    const methodPaths = Reflect.getMetadata(PATH_METADATA, descriptor.value)
    if (methodPaths === undefined) continue
    const requestMethod = Reflect.getMetadata(
      METHOD_METADATA,
      descriptor.value,
    ) as number | undefined
    const method =
      requestMethod === undefined ? undefined : METHOD_NAMES[requestMethod]
    if (!method) continue

    for (const controllerPath of controllerPaths) {
      for (const methodPath of asPaths(methodPaths)) {
        const full = `${prefix}/${controllerPath}/${methodPath}`
          .replace(/\/+/g, "/")
          .replace(/\/$/, "")
          .replace(/:([A-Za-z0-9_]+)/g, "{$1}")
        routes.push({ method, path: full || "/" })
      }
    }
  }

  return routes
}
