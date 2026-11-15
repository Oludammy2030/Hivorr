import {
  createTaxonomyAttributeRequest,
  createTaxonomyNodeRequest,
  taxonomyAttributeView,
  taxonomyNodeView,
  updateTaxonomyNodeRequest,
} from "../server/src/contracts/schemas"
import { describe, expect, it } from "vitest"

const nodeId = "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7b"

describe("taxonomy administration contract", () => {
  it("accepts a product node request and rejects an unknown field", () => {
    const request = {
      taxonomy: "product",
      level: "category",
      parentId: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7c",
      slug: "audio",
      name: "Audio",
      description: "Sound equipment",
      version: 1,
      reason: "Initial product taxonomy",
    }
    expect(createTaxonomyNodeRequest.safeParse(request).success).toBe(true)
    expect(
      createTaxonomyNodeRequest.safeParse({
        ...request,
        clientApproved: true,
      }).success,
    ).toBe(false)
    expect(
      createTaxonomyNodeRequest.safeParse({
        ...request,
        level: "not-a-level",
      }).success,
    ).toBe(false)
  })

  it("requires a version-safe update request", () => {
    expect(
      updateTaxonomyNodeRequest.safeParse({
        name: "Audio",
        version: 2,
        isActive: true,
        reason: "Rename and keep active",
      }).success,
    ).toBe(true)
    expect(
      updateTaxonomyNodeRequest.safeParse({
        name: "Audio",
        version: 0,
        reason: "Bad version",
      }).success,
    ).toBe(false)
  })

  it("rejects an enum attribute without values and accepts one with values", () => {
    const base = {
      nodeId,
      key: "colour",
      label: "Colour",
      dataType: "enum",
      reason: "Needed for filtering",
    }
    expect(createTaxonomyAttributeRequest.safeParse(base).success).toBe(false)
    expect(
      createTaxonomyAttributeRequest.safeParse({
        ...base,
        enumValues: ["black", "white"],
      }).success,
    ).toBe(true)
  })

  it("validates the published node and attribute views", () => {
    const node = {
      id: nodeId,
      taxonomy: "product",
      level: "category",
      parentId: null,
      slug: "audio",
      name: "Audio",
      description: null,
      version: 1,
      effectiveFrom: "2026-11-15T00:00:00.000Z",
      effectiveTo: null,
      isActive: true,
      createdAt: "2026-11-15T00:00:00.000Z",
      updatedAt: "2026-11-15T00:00:00.000Z",
    }
    expect(taxonomyNodeView.safeParse(node).success).toBe(true)
    expect(taxonomyNodeView.safeParse({ ...node, version: 0 }).success).toBe(
      false,
    )
    expect(
      taxonomyAttributeView.safeParse({
        id: "018f7f5e-7c4a-7c2b-9a1f-2c3d4e5f6a7c",
        nodeId,
        key: "colour",
        label: "Colour",
        dataType: "enum",
        isRequired: true,
        enumValues: ["black", "white"],
        unit: null,
        sortOrder: 0,
        createdAt: "2026-11-15T00:00:00.000Z",
        updatedAt: "2026-11-15T00:00:00.000Z",
      }).success,
    ).toBe(true)
  })
})
