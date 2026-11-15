import { describe, expect, it } from "vitest"

import {
  createsCycle,
  expectedParentLevel,
  validateTaxonomyAttribute,
  validateTaxonomyNode,
} from "../server/src/modules/platform/taxonomy"

describe("taxonomy hierarchy domain", () => {
  it("maps every non-root level to its required parent", () => {
    expect(expectedParentLevel("profession", "profession")).toBe("industry")
    expect(expectedParentLevel("product", "category")).toBe("vertical")
    expect(expectedParentLevel("product", "subcategory")).toBe("category")
    expect(expectedParentLevel("product", "product_type")).toBe("subcategory")
    expect(expectedParentLevel("profession", "industry")).toBeNull()
    expect(expectedParentLevel("product", "vertical")).toBeNull()
  })

  it("accepts a profession chain and a product chain", () => {
    expect(
      validateTaxonomyNode(
        {
          taxonomy: "profession",
          level: "profession",
          parentId: "industry-1",
          slug: "electrician",
          name: "Electrician",
        },
        { id: "industry-1", taxonomy: "profession", level: "industry" },
      ),
    ).toEqual([])

    expect(
      validateTaxonomyNode(
        {
          taxonomy: "product",
          level: "product_type",
          parentId: "subcategory-1",
          slug: "wireless-headphones",
          name: "Wireless headphones",
        },
        {
          id: "subcategory-1",
          taxonomy: "product",
          level: "subcategory",
        },
      ),
    ).toEqual([])
  })

  it("rejects a root with a parent, a missing parent and a wrong parent level", () => {
    const root = validateTaxonomyNode(
      {
        taxonomy: "product",
        level: "vertical",
        parentId: "parent-1",
        slug: "food",
        name: "Food",
      },
      null,
    )
    expect(root.map((error) => error.code)).toContain(
      "TAXONOMY_ROOT_LEVEL_INVALID",
    )

    const missing = validateTaxonomyNode(
      {
        taxonomy: "product",
        level: "category",
        parentId: null,
        slug: "grocery",
        name: "Grocery",
      },
      null,
    )
    expect(missing.map((error) => error.code)).toContain(
      "TAXONOMY_PARENT_REQUIRED",
    )

    const wrongLevel = validateTaxonomyNode(
      {
        taxonomy: "product",
        level: "category",
        parentId: "category-1",
        slug: "grocery",
        name: "Grocery",
      },
      { id: "category-1", taxonomy: "product", level: "category" },
    )
    expect(wrongLevel.map((error) => error.code)).toContain(
      "TAXONOMY_PARENT_LEVEL_INVALID",
    )
  })

  it("rejects a parent from the other taxonomy and an invalid level", () => {
    const mismatch = validateTaxonomyNode(
      {
        taxonomy: "profession",
        level: "profession",
        parentId: "industry-1",
        slug: "electrician",
        name: "Electrician",
      },
      { id: "industry-1", taxonomy: "product", level: "industry" },
    )
    expect(mismatch.map((error) => error.code)).toContain(
      "TAXONOMY_PARENT_TAXONOMY_MISMATCH",
    )

    const invalidLevel = validateTaxonomyNode(
      {
        taxonomy: "profession",
        level: "category",
        parentId: "industry-1",
        slug: "electrician",
        name: "Electrician",
      },
      { id: "industry-1", taxonomy: "profession", level: "industry" },
    )
    expect(invalidLevel.map((error) => error.code)).toContain(
      "TAXONOMY_LEVEL_INVALID",
    )
  })

  it("rejects a bad slug, an empty name and a self-parent cycle", () => {
    const errors = validateTaxonomyNode(
      {
        id: "node-1",
        taxonomy: "product",
        level: "category",
        parentId: "node-1",
        slug: "Not A Slug",
        name: " ",
      },
      { id: "node-1", taxonomy: "product", level: "vertical" },
    )
    const codes = errors.map((error) => error.code)
    expect(codes).toContain("TAXONOMY_SLUG_INVALID")
    expect(codes).toContain("TAXONOMY_NAME_REQUIRED")
    expect(codes).toContain("TAXONOMY_CYCLE")
  })

  it("detects a cycle in an existing ancestor chain", () => {
    const ancestors = new Map<string, string | null>([
      ["a", null],
      ["b", "a"],
      ["c", "b"],
    ])
    expect(createsCycle("a", "c", ancestors)).toBe(true)
    expect(createsCycle("d", "c", ancestors)).toBe(false)
    expect(createsCycle(undefined, "c", ancestors)).toBe(false)
  })

  it("rejects attributes on the wrong level and an empty enum", () => {
    expect(
      validateTaxonomyAttribute({
        nodeLevel: "category",
        key: "size",
        label: "Size",
        dataType: "text",
        isRequired: false,
      }).map((error) => error.code),
    ).toContain("TAXONOMY_ATTRIBUTE_LEVEL_INVALID")

    expect(
      validateTaxonomyAttribute({
        nodeLevel: "product_type",
        key: "colour",
        label: "Colour",
        dataType: "enum",
        isRequired: true,
        enumValues: [],
      }).map((error) => error.code),
    ).toContain("TAXONOMY_ATTRIBUTE_ENUM_REQUIRED")
  })

  it("accepts a typed product-type attribute", () => {
    expect(
      validateTaxonomyAttribute({
        nodeLevel: "product_type",
        key: "colour",
        label: "Colour",
        dataType: "enum",
        isRequired: true,
        enumValues: ["black", "white"],
      }),
    ).toEqual([])
  })
})
