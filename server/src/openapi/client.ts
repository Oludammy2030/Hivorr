import type {
  OpenApiDocument,
  OpenApiOperation,
  OpenApiParameter,
} from "./types"

const METHODS = ["get", "post", "put", "patch", "delete"] as const

function pascal(value: string): string {
  return value.length > 0
    ? `${value[0]?.toUpperCase()}${value.slice(1)}`
    : value
}

/**
 * Convert the JSON Schema subset this contract uses into a TypeScript type.
 * It covers objects, arrays, enums, unions, literals and nullables; a `$ref`
 * is not produced because the generator inlines every schema.
 */
function tsType(schema: unknown): string {
  if (!schema || typeof schema !== "object") return "unknown"
  const value = schema as Record<string, unknown>

  if (value.const !== undefined) return JSON.stringify(value.const)
  if (Array.isArray(value.enum)) {
    return (
      value.enum.map((entry) => JSON.stringify(entry)).join(" | ") || "never"
    )
  }
  if (Array.isArray(value.anyOf)) {
    return value.anyOf.map(tsType).join(" | ")
  }
  if (Array.isArray(value.oneOf)) {
    return value.oneOf.map(tsType).join(" | ")
  }
  if (Array.isArray(value.allOf)) {
    return value.allOf.map(tsType).join(" & ")
  }

  const type = value.type
  if (Array.isArray(type)) {
    return type.map((entry) => tsType({ ...value, type: entry })).join(" | ")
  }

  switch (type) {
    case "string":
      return "string"
    case "integer":
    case "number":
      return "number"
    case "boolean":
      return "boolean"
    case "null":
      return "null"
    case "array":
      return `(${tsType(value.items)})[]`
    case "object":
      return objectType(value)
    default:
      return "unknown"
  }
}

function objectType(schema: Record<string, unknown>): string {
  const properties =
    schema.properties && typeof schema.properties === "object"
      ? schema.properties as Record<string, unknown>
      : {}
  const required = new Set(
    Array.isArray(schema.required) ? schema.required as string[] : [],
  )

  const fields = Object.entries(properties).map(([name, property]) => {
    const optional = required.has(name) ? "" : "?"
    return `${JSON.stringify(name)}${optional}: ${tsType(property)}`
  })

  if (
    schema.additionalProperties &&
    typeof schema.additionalProperties === "object"
  ) {
    fields.push(`[key: string]: ${tsType(schema.additionalProperties)}`)
  }

  return fields.length > 0
    ? `{ ${fields.join("; ")} }`
    : "Record<string, unknown>"
}

function responseStatuses(operation: OpenApiOperation): number[] {
  const statuses = Object.keys(operation.responses).filter((status) =>
    status.startsWith("2"),
  )
  for (const expected of operation["x-hivorr-expected"] ?? []) {
    const key = String(expected)
    if (!statuses.includes(key)) statuses.push(key)
  }
  return statuses.map(Number)
}

function responseType(operation: OpenApiOperation): string {
  const types = responseStatuses(operation)
    .map(
      (status) =>
        operation.responses[String(status)]?.content?.["application/json"]
          ?.schema,
    )
    .filter((schema): schema is unknown => schema !== undefined)
    .map(tsType)

  const unique = [...new Set(types)]
  if (unique.length === 0) return "void"
  return unique.join(" | ")
}

function requestType(operation: OpenApiOperation): string | undefined {
  const schema = operation.requestBody?.content?.["application/json"]?.schema
  return schema === undefined ? undefined : tsType(schema)
}

function pathExpression(
  path: string,
  parameters: readonly OpenApiParameter[],
): string {
  if (parameters.length === 0) return JSON.stringify(path)
  const expression = path.replace(
    /\{([^}]+)\}/g,
    (_match, name: string) => `\${encodeURIComponent(params.${name})}`,
  )
  return `\`${expression}\``
}

/**
 * Generate the typed client from the document. The output is deterministic and
 * committed; `tests/openapi-contract.test.ts` fails when it drifts.
 */
export function buildClient(document: OpenApiDocument): string {
  const aliases: string[] = []
  const methods: string[] = []

  for (const [path, pathItem] of Object.entries(document.paths)) {
    for (const method of METHODS) {
      const operation = pathItem[method]
      if (!operation) continue

      const name = pascal(operation.operationId)
      const request = requestType(operation)
      if (request) {
        aliases.push(`export type ${name}Request = ${request}`)
      }
      aliases.push(`export type ${name}Response = ${responseType(operation)}`)

      const parameters = (operation.parameters ?? []).filter(
        (parameter) => parameter.in === "path",
      )
      const args: string[] = []
      if (parameters.length > 0) {
        args.push(
          `params: { ${parameters
            .map((parameter) => `${parameter.name}: string`)
            .join("; ")} }`,
        )
      }
      if (request) args.push(`input: ${name}Request`)

      const statuses = responseStatuses(operation).join(", ")
      methods.push(
        [
          `    ${operation.operationId}: (${args.join(", ")}) =>`,
          `      request<${name}Response>(`,
          `        "${method.toUpperCase()}",`,
          `        ${pathExpression(path, parameters)},`,
          `        ${request ? "input" : "undefined"},`,
          `        [${statuses}],`,
          `      ),`,
        ].join("\n"),
      )
    }
  }

  return [
    "// AUTO-GENERATED from openapi/openapi.json by server/src/openapi/client.ts.",
    "// Do not edit by hand. Run `pnpm openapi:generate`.",
    "",
    "export interface ApiErrorBody {",
    "  error: {",
    "    code: string",
    "    message: string",
    "    correlationId?: string",
    "  }",
    "}",
    "",
    "export class ApiClientError extends Error {",
    "  readonly status: number",
    "  readonly code: string",
    "  readonly correlationId?: string",
    "",
    "  constructor(status: number, body: ApiErrorBody) {",
    "    super(body.error.message)",
    '    this.name = "ApiClientError"',
    "    this.status = status",
    "    this.code = body.error.code",
    "    if (body.error.correlationId) this.correlationId = body.error.correlationId",
    "  }",
    "}",
    "",
    "export interface HivorrClientOptions {",
    "  readonly baseUrl: string",
    "  readonly fetch?: typeof globalThis.fetch",
    "  readonly credentials?: RequestCredentials",
    "}",
    "",
    'type HttpMethod = "GET" | "POST" | "PUT" | "PATCH" | "DELETE"',
    "",
    ...aliases.flatMap((alias) => [alias, ""]),
    "export function createHivorrClient(options: HivorrClientOptions) {",
    "  const fetchImpl = options.fetch ?? globalThis.fetch",
    '  const baseUrl = options.baseUrl.replace(/\\/+$/, "")',
    '  const credentials = options.credentials ?? "include"',
    "",
    "  async function request<T>(",
    "    method: HttpMethod,",
    "    path: string,",
    "    body: unknown,",
    "    expected: readonly number[],",
    "  ): Promise<T> {",
    "    const response = await fetchImpl(`${baseUrl}${path}`, {",
    "      method,",
    "      credentials,",
    '      headers: body === undefined ? undefined : { "content-type": "application/json" },',
    "      ...(body === undefined ? {} : { body: JSON.stringify(body) }),",
    "    })",
    "",
    "    const text = await response.text()",
    "    let parsed: unknown",
    "    if (text) {",
    "      try {",
    "        parsed = JSON.parse(text)",
    "      } catch {",
    "        parsed = undefined",
    "      }",
    "    }",
    "",
    "    if (!response.ok && !expected.includes(response.status)) {",
    "      const envelope = parsed as ApiErrorBody | undefined",
    "      const message =",
    "        envelope?.error?.message ??",
    "        `Hivorr API request failed with status ${response.status}`",
    "      throw new ApiClientError(response.status, {",
    "        error: {",
    '          code: envelope?.error?.code ?? "INTERNAL_ERROR",',
    "          message,",
    "          ...(envelope?.error?.correlationId",
    "            ? { correlationId: envelope.error.correlationId }",
    "            : {}),",
    "        },",
    "      })",
    "    }",
    "",
    "    return parsed as T",
    "  }",
    "",
    "  return {",
    ...methods,
    "  }",
    "}",
    "",
  ].join("\n")
}
