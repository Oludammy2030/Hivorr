import { taxonomyAttributeSchema, taxonomyNodeSchema, taxonomyRegistrySchema } from "@hivorr/shared"
import { describe, expect, it } from "vitest"

const node = {
  id: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b",
  taxonomy: "profession" as const,
  level: "profession" as const,
  parentId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7c",
  slug: "electrician",
  name: "Electrician",
  description: null,
  version: 1,
  effectiveFrom: "2026-11-15T00:00:00.000Z",
  effectiveTo: null,
  isActive: true,
  createdAt: "2026-11-15T00:00:00.000Z",
  updatedAt: "2026-11-15T00:00:00.000Z",
}

const attribute = {
  id: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7d",
  nodeId: node.id,
  key: "licence_number",
  label: "Licence number",
  dataType: "text" as const,
  isRequired: true,
  enumValues: null,
  unit: null,
  sortOrder: 0,
  createdAt: "2026-11-15T00:00:00.000Z",
  updatedAt: "2026-11-15T00:00:00.000Z",
}

describe("taxonomy read contract", () => {
  it("accepts a profession node and a product node", () => {
    expect(taxonomyNodeSchema.safeParse(node).success).toBe(true)
    expect(
      taxonomyNodeSchema.safeParse({
        ...node,
        taxonomy: "product",
        level: "product_type",
        parentId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7e",
        slug: "wireless-headphones",
        name: "Wireless headphones",
      }).success,
    ).toBe(true)
  })

  it("rejects an invalid level and a zero version", () => {
    expect(taxonomyNodeSchema.safeParse({ ...node, level: "discover" }).success).toBe(false)
    expect(taxonomyNodeSchema.safeParse({ ...node, version: 0 }).success).toBe(false)
  })

  it("accepts an attribute and rejects a negative sort order", () => {
    expect(taxonomyAttributeSchema.safeParse(attribute).success).toBe(true)
    expect(taxonomyAttributeSchema.safeParse({ ...attribute, sortOrder: -1 }).success).toBe(false)
  })

  it("wraps both taxonomies in one registry response", () => {
    expect(
      taxonomyRegistrySchema.safeParse({
        nodes: [node],
        attributes: [attribute],
      }).success,
    ).toBe(true)
    expect(taxonomyRegistrySchema.safeParse({ nodes: [node], attributes: [{}] }).success).toBe(
      false,
    )
  })
})
