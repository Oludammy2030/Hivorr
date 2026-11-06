import { describe, expect, it } from "vitest"
import {
  evaluatePush,
  formatViolations,
  parsePushInput,
  protectedBranchOf,
} from "../scripts/lib/push-policy.mjs"

const protectedBranches = ["main", "staging"]
const isAncestor = (ancestor: string, descendant: string) =>
  ancestor === "a".repeat(40) && descendant === "b".repeat(40)

function entry(
  remoteRef: string,
  localSha = "b".repeat(40),
  remoteSha = "a".repeat(40),
) {
  return {
    localRef: remoteRef,
    localSha,
    remoteRef,
    remoteSha,
  }
}

describe("protected branch push policy", () => {
  it("allows a feature branch push", () => {
    const violations = evaluatePush(
      [entry("refs/heads/feature/test")],
      protectedBranches,
      isAncestor,
    )
    expect(violations).toEqual([])
  })

  it("blocks a direct update to main", () => {
    const violations = evaluatePush(
      [entry("refs/heads/main")],
      protectedBranches,
      isAncestor,
    )
    expect(violations.map((v) => v.kind)).toEqual(["direct-push"])
  })

  it("blocks a direct update to staging", () => {
    const violations = evaluatePush(
      [entry("refs/heads/staging")],
      protectedBranches,
      isAncestor,
    )
    expect(violations.map((v) => v.kind)).toEqual(["direct-push"])
  })

  it("blocks deleting a protected branch", () => {
    const violations = evaluatePush(
      [entry("refs/heads/main", "0".repeat(40))],
      protectedBranches,
      isAncestor,
    )
    expect(violations.map((v) => v.kind)).toEqual(["delete"])
  })

  it("blocks creating a protected branch by push", () => {
    const violations = evaluatePush(
      [entry("refs/heads/staging", "b".repeat(40), "0".repeat(40))],
      protectedBranches,
      isAncestor,
    )
    expect(violations.map((v) => v.kind)).toEqual(["create"])
  })

  it("blocks a non-fast-forward update to a protected branch", () => {
    const violations = evaluatePush(
      [entry("refs/heads/main", "c".repeat(40), "a".repeat(40))],
      protectedBranches,
      () => false,
    )
    expect(violations.map((v) => v.kind)).toEqual(["non-fast-forward"])
  })

  it("allows tags because they are not branches", () => {
    const violations = evaluatePush(
      [entry("refs/tags/v1.0.0")],
      protectedBranches,
      isAncestor,
    )
    expect(violations).toEqual([])
  })

  it("recognises protected branch names exactly", () => {
    expect(protectedBranchOf("refs/heads/main", protectedBranches)).toBe("main")
    expect(
      protectedBranchOf("refs/heads/mainline", protectedBranches),
    ).toBeNull()
    expect(protectedBranchOf("refs/tags/main", protectedBranches)).toBeNull()
  })

  it("parses the pre-push stdin format", () => {
    const entries = parsePushInput(
      `refs/heads/feature/x ${"b".repeat(40)} refs/heads/feature/x ${"a".repeat(40)}\n`,
    )
    expect(entries).toHaveLength(1)
    expect(entries[0]?.remoteRef).toBe("refs/heads/feature/x")
  })

  it("reports the flow in the rejection message", () => {
    const message = formatViolations(
      [
        {
          branch: "main",
          kind: "direct-push",
          entry: entry("refs/heads/main"),
        },
      ],
      { flow: "feature/* -> PR -> staging -> PR -> main" },
    )
    expect(message).toContain("BLOCKED")
    expect(message).toContain("feature/* -> PR -> staging -> PR -> main")
  })
})
