import {
  TAXONOMY_KINDS,
  TAXONOMY_LEVELS,
  TAXONOMY_LEVELS_BY_KIND,
  type TaxonomyAttributeType,
  type TaxonomyKind,
  type TaxonomyLevel,
} from "@hivorr/shared"

/**
 * Taxonomy hierarchy domain (EP-02-020).
 *
 * Pure validation for the two approved taxonomies. Persistence and admin writes
 * belong to the `platform` repository/API; this module never imports the
 * database, HTTP or a client.
 */
export {
  TAXONOMY_ATTRIBUTE_TYPES,
  TAXONOMY_KINDS,
  TAXONOMY_LEVELS,
  TAXONOMY_LEVELS_BY_KIND,
} from "@hivorr/shared"
export type {
  TaxonomyAttributeType,
  TaxonomyKind,
  TaxonomyLevel,
} from "@hivorr/shared"

export type TaxonomyNodeInput = {
  readonly id?: string
  readonly taxonomy: TaxonomyKind
  readonly level: TaxonomyLevel
  readonly parentId: string | null
  readonly slug: string
  readonly name: string
}

export type TaxonomyValidationCode = "TAXONOMY_UNKNOWN" | "TAXONOMY_LEVEL_INVALID" | "TAXONOMY_ROOT_LEVEL_INVALID" | "TAXONOMY_PARENT_REQUIRED" | "TAXONOMY_PARENT_LEVEL_INVALID" | "TAXONOMY_PARENT_TAXONOMY_MISMATCH" | "TAXONOMY_CYCLE" | "TAXONOMY_SLUG_INVALID" | "TAXONOMY_NAME_REQUIRED"

export interface TaxonomyValidationError {
  readonly code: TaxonomyValidationCode
  readonly message: string
}

export interface TaxonomyParent {
  readonly id: string
  readonly taxonomy: TaxonomyKind
  readonly level: TaxonomyLevel
}

const SLUG_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/

export function isTaxonomyKind(value: string): value is TaxonomyKind {
  return (TAXONOMY_KINDS as readonly string[]).includes(value)
}

export function isTaxonomyLevel(value: string): value is TaxonomyLevel {
  return (TAXONOMY_LEVELS as readonly string[]).includes(value)
}

export function isRootLevel(level: TaxonomyLevel): boolean {
  return level === "industry" || level === "vertical"
}

export function expectedParentLevel(
  taxonomy: TaxonomyKind,
  level: TaxonomyLevel,
): TaxonomyLevel | null {
  if (!TAXONOMY_LEVELS_BY_KIND[taxonomy].includes(level)) return null
  if (isRootLevel(level)) return null
  if (taxonomy === "profession" && level === "profession") return "industry"
  if (taxonomy === "product" && level === "category") return "vertical"
  if (taxonomy === "product" && level === "subcategory") return "category"
  if (taxonomy === "product" && level === "product_type") return "subcategory"
  return null
}

/**
 * Detects a cycle by walking the existing ancestor chain from the proposed
 * parent. `ancestors` maps every node id to its current parent id.
 */
export function createsCycle(
  nodeId: string | undefined,
  parentId: string | null,
  ancestors: ReadonlyMap<string, string | null>,
): boolean {
  if (!nodeId || !parentId) return false
  let current: string | null = parentId
  let guard = 0
  while (current) {
    if (current === nodeId) return true
    current = ancestors.get(current) ?? null
    guard += 1
    if (guard > 1000) return true
  }
  return false
}

export function validateTaxonomyNode(
  input: TaxonomyNodeInput,
  parent: TaxonomyParent | null,
): TaxonomyValidationError[] {
  const errors: TaxonomyValidationError[] = []
  const levels = TAXONOMY_LEVELS_BY_KIND[input.taxonomy]

  if (!levels) {
    errors.push({
      code: "TAXONOMY_UNKNOWN",
      message: "The taxonomy must be profession or product.",
    })
    return errors
  }

  if (!levels.includes(input.level)) {
    errors.push({
      code: "TAXONOMY_LEVEL_INVALID",
      message: `${input.level} is not a level of the ${input.taxonomy} taxonomy.`,
    })
  }

  if (!SLUG_PATTERN.test(input.slug)) {
    errors.push({
      code: "TAXONOMY_SLUG_INVALID",
      message: "The slug must be lower-case kebab-case.",
    })
  }

  if (!input.name.trim()) {
    errors.push({
      code: "TAXONOMY_NAME_REQUIRED",
      message: "A taxonomy node needs a name.",
    })
  }

  const expected = expectedParentLevel(input.taxonomy, input.level)

  if (expected === null) {
    if (!isRootLevel(input.level)) {
      errors.push({
        code: "TAXONOMY_ROOT_LEVEL_INVALID",
        message: "Only industry and vertical are root levels.",
      })
    }
    if (input.parentId !== null) {
      errors.push({
        code: "TAXONOMY_ROOT_LEVEL_INVALID",
        message: "A root node must not have a parent.",
      })
    }
    return errors
  }

  if (input.parentId === null) {
    errors.push({
      code: "TAXONOMY_PARENT_REQUIRED",
      message: `A ${input.level} node needs a ${expected} parent.`,
    })
    return errors
  }

  if (!parent) {
    errors.push({
      code: "TAXONOMY_PARENT_REQUIRED",
      message: "The parent node was not found.",
    })
    return errors
  }

  if (parent.taxonomy !== input.taxonomy) {
    errors.push({
      code: "TAXONOMY_PARENT_TAXONOMY_MISMATCH",
      message: "The parent belongs to the other taxonomy.",
    })
  }

  if (parent.level !== expected) {
    errors.push({
      code: "TAXONOMY_PARENT_LEVEL_INVALID",
      message: `A ${input.level} node must hang from a ${expected} node.`,
    })
  }

  if (input.id && input.id === parent.id) {
    errors.push({
      code: "TAXONOMY_CYCLE",
      message: "A node cannot be its own parent.",
    })
  }

  return errors
}

export interface TaxonomyAttributeInput {
  readonly nodeLevel: TaxonomyLevel
  readonly key: string
  readonly label: string
  readonly dataType: TaxonomyAttributeType
  readonly isRequired: boolean
  readonly enumValues?: readonly string[]
}

export type TaxonomyAttributeValidationCode = "TAXONOMY_ATTRIBUTE_LEVEL_INVALID" | "TAXONOMY_ATTRIBUTE_KEY_INVALID" | "TAXONOMY_ATTRIBUTE_LABEL_REQUIRED" | "TAXONOMY_ATTRIBUTE_ENUM_REQUIRED"

export interface TaxonomyAttributeValidationError {
  readonly code: TaxonomyAttributeValidationCode
  readonly message: string
}

const ATTRIBUTE_KEY_PATTERN = /^[a-z][a-z0-9_]*$/

export function validateTaxonomyAttribute(
  input: TaxonomyAttributeInput,
): TaxonomyAttributeValidationError[] {
  const errors: TaxonomyAttributeValidationError[] = []

  if (input.nodeLevel !== "profession" && input.nodeLevel !== "product_type") {
    errors.push({
      code: "TAXONOMY_ATTRIBUTE_LEVEL_INVALID",
      message: "Attributes attach only to a profession or product-type node.",
    })
  }

  if (!ATTRIBUTE_KEY_PATTERN.test(input.key)) {
    errors.push({
      code: "TAXONOMY_ATTRIBUTE_KEY_INVALID",
      message: "The attribute key must be lower snake case.",
    })
  }

  if (!input.label.trim()) {
    errors.push({
      code: "TAXONOMY_ATTRIBUTE_LABEL_REQUIRED",
      message: "An attribute needs a label.",
    })
  }

  if (
    input.dataType === "enum" &&
    (!input.enumValues || input.enumValues.length === 0)
  ) {
    errors.push({
      code: "TAXONOMY_ATTRIBUTE_ENUM_REQUIRED",
      message: "An enum attribute needs at least one value.",
    })
  }

  return errors
}
