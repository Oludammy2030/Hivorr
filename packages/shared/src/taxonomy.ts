import { z } from "zod"

/**
 * Taxonomy read contracts.
 *
 * The registry is reference data. These shapes are shared by the API and every
 * client so a portal cannot invent a second taxonomy vocabulary. Taxonomy depth
 * is still open in `VISION.md`; the structural levels below are the approved
 * phase-scope model, and no production values are seeded by this package.
 */
export const TAXONOMY_KINDS = ["profession", "product"] as const

export type TaxonomyKind = (typeof TAXONOMY_KINDS)[number]

export const TAXONOMY_LEVELS = [
  "industry",
  "profession",
  "vertical",
  "category",
  "subcategory",
  "product_type",
] as const

export type TaxonomyLevel = (typeof TAXONOMY_LEVELS)[number]

export const TAXONOMY_LEVELS_BY_KIND: Readonly<Record<TaxonomyKind, readonly TaxonomyLevel[]>> = {
  profession: ["industry", "profession"],
  product: ["vertical", "category", "subcategory", "product_type"],
}

export const TAXONOMY_ATTRIBUTE_TYPES = ["text", "number", "boolean", "enum", "date"] as const

export type TaxonomyAttributeType = (typeof TAXONOMY_ATTRIBUTE_TYPES)[number]

export const taxonomyKindSchema = z.enum(TAXONOMY_KINDS)
export const taxonomyLevelSchema = z.enum(TAXONOMY_LEVELS)
export const taxonomyAttributeTypeSchema = z.enum(TAXONOMY_ATTRIBUTE_TYPES)

export const taxonomyNodeSchema = z.object({
  id: z.string().uuid(),
  taxonomy: taxonomyKindSchema,
  level: taxonomyLevelSchema,
  parentId: z.string().uuid().nullable(),
  slug: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  version: z.number().int().positive(),
  effectiveFrom: z.string(),
  effectiveTo: z.string().nullable(),
  isActive: z.boolean(),
  createdAt: z.string(),
  updatedAt: z.string(),
})

export type TaxonomyNode = z.infer<typeof taxonomyNodeSchema>

export const taxonomyAttributeSchema = z.object({
  id: z.string().uuid(),
  nodeId: z.string().uuid(),
  key: z.string(),
  label: z.string(),
  dataType: taxonomyAttributeTypeSchema,
  isRequired: z.boolean(),
  enumValues: z.array(z.string()).nullable(),
  unit: z.string().nullable(),
  sortOrder: z.number().int().nonnegative(),
  createdAt: z.string(),
  updatedAt: z.string(),
})

export type TaxonomyAttribute = z.infer<typeof taxonomyAttributeSchema>

export const taxonomyRegistrySchema = z.object({
  nodes: z.array(taxonomyNodeSchema),
  attributes: z.array(taxonomyAttributeSchema),
})

export type TaxonomyRegistry = z.infer<typeof taxonomyRegistrySchema>

export function isTaxonomyKind(value: string): value is TaxonomyKind {
  return (TAXONOMY_KINDS as readonly string[]).includes(value)
}

export function isTaxonomyLevel(value: string): value is TaxonomyLevel {
  return (TAXONOMY_LEVELS as readonly string[]).includes(value)
}
