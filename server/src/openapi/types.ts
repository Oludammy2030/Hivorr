export interface OpenApiParameter {
  readonly name: string
  readonly in: string
  readonly required?: boolean
  readonly schema?: unknown
}

export interface OpenApiMediaType {
  readonly schema?: unknown
}

export interface OpenApiResponse {
  readonly description?: string
  readonly content?: Record<string, OpenApiMediaType>
}

export interface OpenApiOperation {
  readonly operationId: string
  readonly summary?: string
  readonly tags?: readonly string[]
  readonly responses: Record<string, OpenApiResponse>
  readonly requestBody?: {
    readonly required?: boolean
    readonly description?: string
    readonly content?: Record<string, OpenApiMediaType>
  }
  readonly parameters?: readonly OpenApiParameter[]
  readonly security?: readonly Record<string, readonly string[]>[]
  readonly "x-hivorr-audience"?: readonly string[]
  readonly "x-hivorr-expected"?: readonly number[]
}

export interface OpenApiDocument {
  readonly openapi: string
  readonly info: Record<string, unknown>
  readonly servers?: readonly Record<string, unknown>[]
  readonly paths: Record<string, Record<string, OpenApiOperation>>
  readonly components?: Record<string, unknown>
}
