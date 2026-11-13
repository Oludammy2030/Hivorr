import { z } from "zod"

import { errorResponse } from "../contracts/schemas"
import { API_OPERATIONS, type ApiOperation } from "./operations"
import type {
  OpenApiDocument,
  OpenApiOperation,
  OpenApiResponse,
} from "./types"

const ERROR_RESPONSES: Readonly<Record<number, string>> = {
  400: "The request is invalid",
  401: "Authentication is required",
  403: "The caller is not allowed to perform this action",
  404: "The resource was not found",
  409: "The request conflicts with the current state",
  429: "Too many requests",
  500: "An unexpected error occurred",
  503: "The service is temporarily unavailable",
}

const SECURITY_SCHEMES = {
  appSession: cookieScheme("__Host-hivorr_app_sid", "app"),
  controlSession: cookieScheme("__Host-hivorr_control_sid", "control"),
  staffSession: cookieScheme("__Host-hivorr_staff_sid", "staff"),
  partnerSession: cookieScheme("__Host-hivorr_partner_sid", "partner"),
}

function cookieScheme(name: string, audience: string) {
  return {
    type: "apiKey",
    in: "cookie",
    name,
    description: `Host-only ${audience} portal session cookie. The API rejects a session issued for another audience.`,
  }
}

function jsonSchema(schema: z.ZodType): Record<string, unknown> {
  const converted = z.toJSONSchema(schema, {
    target: "draft-2020-12",
    io: "output",
  }) as Record<string, unknown>
  delete converted.$schema
  return converted
}

function content(schema: z.ZodType) {
  return { "application/json": { schema: jsonSchema(schema) } }
}

function operationObject(operation: ApiOperation): OpenApiOperation {
  const responses: Record<string, OpenApiResponse> = {}

  for (const [status, description] of Object.entries(ERROR_RESPONSES)) {
    responses[status] = {
      description,
      content: content(errorResponse),
    }
  }
  for (const success of operation.success) {
    responses[String(success.status)] = {
      description: success.description,
      ...(success.schema ? { content: content(success.schema) } : {}),
    }
  }

  return {
    operationId: operation.id,
    summary: operation.summary,
    tags: [operation.tag],
    "x-hivorr-audience": operation.audience,
    ...(operation.expected ? { "x-hivorr-expected": operation.expected } : {}),
    security: operation.audience.includes("public")
      ? []
      : operation.audience.map((audience) => ({
          [`${audience}Session`]: [],
        })),
    ...(operation.pathParams || operation.queryParams
      ? {
          parameters: [
            ...(operation.pathParams ?? []).map((name) => ({
              name,
              in: "path" as const,
              required: true,
              schema: { type: "string" as const },
            })),
            ...(operation.queryParams ?? []).map((name) => ({
              name,
              in: "query" as const,
              required: true,
              schema: { type: "string" as const },
            })),
          ],
        }
      : {}),
    ...(operation.request
      ? {
          requestBody: {
            required: true,
            description: operation.request.description,
            content: content(operation.request.schema),
          },
        }
      : {}),
    responses,
  }
}

/**
 * Build the OpenAPI 3.1 document from the operation registry. Deterministic:
 * the same source produces byte-identical JSON, so a committed file can be
 * compared with a fresh build.
 */
export function buildDocument(
  operations: readonly ApiOperation[] = API_OPERATIONS,
): OpenApiDocument {
  const paths: Record<string, Record<string, OpenApiOperation>> = {}
  for (const operation of operations) {
    const pathItem = (paths[operation.path] ??= {})
    pathItem[operation.method] = operationObject(operation)
  }

  return {
    openapi: "3.1.0",
    info: {
      title: "Hivorr API",
      version: "1.0.0",
      description:
        "The Hivorr platform API. Sessions are host-only cookies scoped to one portal audience; a session issued for one audience is rejected by another.",
    },
    servers: [
      { url: "https://staging.hivorr.com", description: "Staging" },
      { url: "https://hivorr.com", description: "Production" },
    ],
    paths,
    components: {
      securitySchemes: SECURITY_SCHEMES,
    },
  }
}
