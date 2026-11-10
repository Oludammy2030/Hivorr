import { readFileSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

import { buildDocument } from "../server/src/openapi/build"
import { buildClient } from "../server/src/openapi/client"
import { API_OPERATIONS } from "../server/src/openapi/operations"

const root = process.cwd()
const read = (relative: string) =>
  readFileSync(path.join(root, relative), "utf8")
const normalize = (value: string) => value.replace(/\s+/g, "")

const document = buildDocument()
const committed = JSON.parse(
  read("openapi/openapi.json"),
) as ReturnType<typeof buildDocument>
const committedClient = read("packages/api-client/src/index.ts")

describe("OpenAPI 3.1 contract", () => {
  it("declares OpenAPI 3.1 and the platform servers", () => {
    expect(document.openapi).toBe("3.1.0")
    expect(document.info.title).toBe("Hivorr API")
    expect(document.servers?.map((server) => server.url)).toEqual([
      "https://staging.hivorr.com",
      "https://hivorr.com",
    ])
  })

  it("matches the committed document", () => {
    expect(committed).toEqual(JSON.parse(JSON.stringify(document)))
  })

  it("documents every registry operation exactly once", () => {
    const documented = Object.entries(document.paths).flatMap(
      ([operationPath, pathItem]) =>
        Object.keys(pathItem).map((method) => `${method} ${operationPath}`),
    )

    expect(new Set(API_OPERATIONS.map((operation) => operation.id)).size).toBe(
      API_OPERATIONS.length,
    )
    expect(documented).toHaveLength(API_OPERATIONS.length)

    for (const operation of API_OPERATIONS) {
      const documentedOperation =
        document.paths[operation.path]?.[operation.method]
      expect(
        documentedOperation,
        `${operation.method} ${operation.path}`,
      ).toBeDefined()
      expect(documentedOperation?.operationId).toBe(operation.id)
      expect(documentedOperation?.["x-hivorr-audience"]).toEqual(
        operation.audience,
      )
      expect(documentedOperation?.responses).toBeDefined()
    }
  })

  it("rejects unknown request fields in every request schema", () => {
    for (const operation of API_OPERATIONS) {
      if (!operation.request) continue
      const schema = document.paths[operation.path]?.[operation.method]
        ?.requestBody?.content?.["application/json"]
        ?.schema as Record<string, unknown> | undefined
      expect(schema, operation.id).toBeDefined()
      expect(schema?.additionalProperties, operation.id).toBe(false)
    }
  })

  it("uses the stable error envelope for client errors", () => {
    const response = document.paths["/v1/auth/register"]?.post?.responses["400"]
    const schema = response?.content?.["application/json"]?.schema as {
      properties?: Record<string, unknown>
    } | undefined
    expect(Object.keys(schema?.properties ?? {})).toContain("error")
  })

  it("declares one host-only cookie scheme per portal", () => {
    const schemes = document.components?.securitySchemes as Record<string, {
      name?: string
    }> | undefined
    expect(Object.keys(schemes ?? {}).sort()).toEqual([
      "appSession",
      "controlSession",
      "partnerSession",
      "staffSession",
    ])
    expect(schemes?.appSession?.name).toBe("__Host-hivorr_app_sid")
    expect(schemes?.controlSession?.name).toBe("__Host-hivorr_control_sid")
  })

  it("generates the committed client from the same document", () => {
    expect(normalize(buildClient(document))).toBe(normalize(committedClient))
  })
})
